// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The sheet places an operation from a park as it is added, on its draft,
// and its save tells the repository not to decide it again
// (docs/design/locations.md, "Located by its references"). Both halves are
// wiring the rule's own tests cannot see: drop the draft's call and the
// operation is placed only after the sheet closes — or never, since the save
// opts out; drop the opt-out and a location the operator cleared comes back.

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/export_service.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/location_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';
import 'package:ham2k_logger/views/operation/operation_location_pin.dart';

import '../support/halo_test_support.dart';

const _parkControl = {
  'key': 'pota/activation',
  'label': 'Parks on the Air',
  'input': {'kind': 'refList', 'refType': 'pota'},
};

const _parkLocation = GridLocation(41.7135, -74.5278);

const _parkSuggestion = {
  'type': 'pota',
  'ref': 'US-0001',
  'label': 'POTA US-0001',
  'shortLabel': 'POTA US-0001',
  'name': 'Some Park',
  'lat': 41.7135,
  'lon': -74.5278,
};

class _ParkExtensions extends ExtensionServiceWithFakeHost {
  final Future<OperationLocationResult> Function(GridLocation, double)? resolveLocation;

  _ParkExtensions(this.resolveLocation)
    : super(
        FakeExtensionHost({
          'activity:*:suggest': [
            {
              'key': 'pota',
              'ok': true,
              'value': [_parkSuggestion],
            },
          ],
        }),
      );

  @override
  Future<ControlsResult> operationControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) async =>
      (controls: const <Map<String, dynamic>>[_parkControl], loadFailed: false);

  @override
  Future<Map<String, dynamic>> decorateRef(Map<String, dynamic> ref) async => ref;

  @override
  Future<OperationLocationResult> resolveOperationLocation(GridLocation fix, {required double accuracyMeters}) async =>
      await resolveLocation?.call(fix, accuracyMeters) ?? noOperationLocation;
}

Future<(HaLoServices, Operation)> _harness({
  LocationService? location,
  Future<OperationLocationResult> Function(GridLocation, double)? subdivisions,
  int qsoCount = 0,
  Map<String, dynamic> locationDetails = const {},
}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService(await SharedPreferences.getInstance());
  final services = HaLoServices(
    HaLoDatabase(NativeDatabase.memory()),
    settings,
    extensions: _ParkExtensions(subdivisions)..settings = settings,
    location: location,
  );
  // The row exists so the save has something to update; the sheet is handed
  // the bare shape the other activities tests use.
  final created = await services.operations.create(stationCall: 'N0DEV');
  return (services, Operation(uuid: created.uuid, data: {'refs': const [], ...locationDetails}, qsoCount: qsoCount));
}

Future<OperationSheetState> _pumpSheet(WidgetTester tester, HaLoServices services, Operation operation, {void Function(Operation)? onChanged}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: OperationSheet(services: services, operation: operation, onOperationChanged: onChanged),
        ),
      ),
    ),
  );
  await _pumpFrames(tester);
  return tester.state<OperationSheetState>(find.byType(OperationSheet));
}

Future<OperationSheetState> _pumpSheetAndAddPark(WidgetTester tester, HaLoServices services, Operation operation, {void Function(Operation)? onChanged}) async {
  final sheet = await _pumpSheet(tester, services, operation, onChanged: onChanged);
  await tester.tap(find.text('POTA US-0001').first);
  await _pumpFrames(tester);
  return sheet;
}

/// Frames, not pumpAndSettle: once a park or a fix places the operation, the
/// sheet searches again from there, and that search's progress bar keeps
/// animating while it waits on I/O a fake-async test never completes.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a park added in the sheet places the operation, and the save keeps it', (tester) async {
    final (services, operation) = await tester.runAsync(_harness) as (HaLoServices, Operation);
    final sheet = await _pumpSheetAndAddPark(tester, services, operation);

    await tester.runAsync(sheet.saveAndClose);

    final stored = (await tester.runAsync(() => services.operations.get(operation.uuid)))!;
    expect(stored.location, _parkLocation);
    expect(stored.data['gridSource'], refsGridSource);
  });

  testWidgets('a location cleared after adding the park stays cleared when the sheet closes', (tester) async {
    final (services, operation) = await tester.runAsync(_harness) as (HaLoServices, Operation);
    Operation? draft;
    final sheet = await _pumpSheetAndAddPark(tester, services, operation, onChanged: (op) => draft = op);
    expect(draft!.location, _parkLocation, reason: 'placed on the draft, before anything is saved');

    // What the Location screen's cleared fields merge into the draft.
    sheet.updateOperation(Operation(uuid: operation.uuid, data: {...draft!.data, 'grid': null, 'gridSource': null, 'lat': null, 'lon': null}));
    await _pumpFrames(tester);
    await tester.runAsync(sheet.saveAndClose);

    final stored = (await tester.runAsync(() => services.operations.get(operation.uuid)))!;
    expect(stored.refs.single['ref'], 'US-0001');
    expect(stored.location, isNull);
  });

  group('a live GPS fix', () {
    const fix = GridLocation(41.713456789, -74.527812345);
    const kent = GridLocation(41.700, -71.525);
    const boundary = GridLocation(41.76083, -71.43);
    const providence = GridLocation(41.78, -71.43);
    Future<OperationLocationResult> rhodeIsland(GridLocation fix, double _) async {
      return (
        state: 'RI',
        county: switch (fix) {
          boundary => null,
          providence => 'Providence',
          _ => 'Kent',
        },
        candidates: fix == boundary
            ? const <OperationLocationCandidate>[(state: 'RI', county: 'Kent'), (state: 'RI', county: 'Providence')]
            : const <OperationLocationCandidate>[],
      );
    }

    testWidgets('places an operation being set up, rounded, and the pill says GPS', (tester) async {
      final gps = FakeGpsLocation()..fix = fix;
      final (services, operation) = await tester.runAsync(() => _harness(location: gps)) as (HaLoServices, Operation);
      Operation? draft;
      final sheet = await _pumpSheet(tester, services, operation, onChanged: (op) => draft = op);

      expect(draft?.data['gridSource'], gpsGridSource);
      expect(draft!.data['lat'], 41.71346);
      expect(find.text('GPS'), findsOneWidget, reason: 'the source, not the square, is what a fix shows');
      expect(find.byIcon(gpsPillIcon), findsOneWidget, reason: 'the map-app dot, not a pin');

      await tester.runAsync(sheet.saveAndClose);
      final stored = (await tester.runAsync(() => services.operations.get(operation.uuid)))!;
      expect(stored.data['gridSource'], gpsGridSource);
    });

    testWidgets('saves GPS subdivisions for a new operation and includes them in upload ADIF', (tester) async {
      final gps = FakeGpsLocation()..fix = kent;
      final (services, operation) = await tester.runAsync(() => _harness(location: gps, subdivisions: rhodeIsland)) as (HaLoServices, Operation);
      Operation? draft;
      final sheet = await _pumpSheet(tester, services, operation, onChanged: (op) => draft = op);

      expect(draft!.data['grid'], gpsLocationData(kent)['grid']);
      expect(draft!.data['state'], 'RI');
      expect(draft!.data['county'], 'Kent');

      await tester.runAsync(sheet.saveAndClose);
      final stored = (await tester.runAsync(() => services.operations.get(operation.uuid)))!;
      expect(stored.data['state'], 'RI');
      expect(stored.data['county'], 'Kent');

      final adif = await tester.runAsync(() async {
        final extensions = ExtensionService();
        prepareExtensionServiceForTest(extensions);
        await extensions.start();
        final contact = await services.qsos.add(stored.uuid, {
          'their': {'call': 'W1AW'},
          'band': '20m',
          'mode': 'CW',
          'startAtMillis': DateTime.utc(2026, 7, 15, 12).millisecondsSinceEpoch,
        });
        final exports = ExportService(extensions: extensions, qsos: services.qsos, settings: services.settings);
        final records = await exports.adifRecordsByQso(stored, [contact], stationCall: 'N0DEV');
        return records[contact.uuid]!.join();
      });
      expect(adif, contains('<MY_STATE:2>RI'));
      expect(adif, contains('<MY_CNTY:7>RI,Kent'));
    });

    testWidgets('a sharper fix clears an inferred county when its radius crosses a county line', (tester) async {
      final gps = FakeGpsLocation()
        ..fix = kent
        ..accuracy = 400;
      final (services, operation) = await tester.runAsync(() => _harness(location: gps, subdivisions: rhodeIsland)) as (HaLoServices, Operation);
      Operation? draft;
      await _pumpSheet(tester, services, operation, onChanged: (op) => draft = op);
      expect(draft!.data['county'], 'Kent');

      // The Pawtuxet River divides Warwick in Kent County from Cranston in
      // Providence County. Both sides of this fix's radius are in Rhode Island.
      gps.setFix(boundary, accuracy: 200);
      await _pumpFrames(tester);

      expect(draft!.location, boundary);
      expect(draft!.data['state'], 'RI');
      expect((draft!.data['county'] as String?) ?? '', isEmpty);
      final reviewGps = find.text(AppLocale.en.buildSync().operationLocationScreen.reviewGps);
      expect(reviewGps, findsOneWidget);

      gps.setFix(providence, accuracy: 5);
      await _pumpFrames(tester);

      expect(draft!.data['state'], 'RI');
      expect(draft!.data['county'], 'Providence');
      expect(reviewGps, findsNothing, reason: 'a resolved fix supersedes the earlier boundary options');
    });

    testWidgets('the setup GPS pill opens the county choices and keeps the chosen county', (tester) async {
      final gps = FakeGpsLocation()..fix = boundary;
      final (services, operation) = await tester.runAsync(() => _harness(location: gps, subdivisions: rhodeIsland)) as (HaLoServices, Operation);
      Operation? draft;
      final sheet = await _pumpSheet(tester, services, operation, onChanged: (op) => draft = op);
      expect(draft!.data['state'], 'RI');
      expect(draft!.data['county'], isNull, reason: 'the operator can leave County blank');

      final t = AppLocale.en.buildSync();
      await tester.tap(find.text(t.operationLocationScreen.reviewGps));
      await _pumpFrames(tester);
      expect(find.text('Kent, RI'), findsOneWidget);
      await tester.tap(find.text('Providence, RI'));
      await _pumpFrames(tester);
      await tester.tap(find.text(t.common.save));
      await _pumpFrames(tester);

      expect(draft!.location, boundary);
      expect(draft!.data['state'], 'RI');
      expect(draft!.data['county'], 'Providence');
      expect(draft!.data['gpsCounty'], isNull, reason: 'a choice is the operator’s stated county');
      await tester.runAsync(sheet.saveAndClose);
      final stored = (await tester.runAsync(() => services.operations.get(operation.uuid)))!;
      expect(stored.data['county'], 'Providence');
    });

    testWidgets('a GPS fix preserves state and county the operator already entered', (tester) async {
      final gps = FakeGpsLocation()..fix = kent;
      // An older client can edit the value without clearing its GPS metadata.
      const edited = {'state': 'MA', 'county': 'Bristol', 'gpsState': 'RI', 'gpsCounty': 'Kent'};
      final (services, operation) =
          await tester.runAsync(() => _harness(location: gps, subdivisions: rhodeIsland, locationDetails: edited)) as (HaLoServices, Operation);
      Operation? draft;
      await _pumpSheet(tester, services, operation, onChanged: (op) => draft = op);

      expect(draft!.data['grid'], gpsLocationData(kent)['grid']);
      expect(draft!.data['state'], 'MA');
      expect(draft!.data['county'], 'Bristol');
    });

    testWidgets('a county the operator clears stays blank when a sharper fix arrives', (tester) async {
      final gps = FakeGpsLocation()
        ..fix = kent
        ..accuracy = 300;
      final (services, operation) = await tester.runAsync(() => _harness(location: gps, subdivisions: rhodeIsland)) as (HaLoServices, Operation);
      Operation? draft;
      await _pumpSheet(tester, services, operation, onChanged: (op) => draft = op);
      expect(draft!.data['county'], 'Kent');

      await tester.tap(find.text('GPS'));
      await _pumpFrames(tester);
      final county = find.widgetWithText(TextField, 'Kent');
      await tester.ensureVisible(county);
      await tester.enterText(county, '');
      await tester.tap(find.text(AppLocale.en.buildSync().common.save));
      await _pumpFrames(tester);

      gps.setFix(const GridLocation(41.701, -71.525), accuracy: 5);
      await _pumpFrames(tester);
      expect(draft!.data['state'], 'RI');
      expect(draft!.data['county'], '');
    });

    testWidgets('a lookup for an earlier fix cannot put its county onto the improved fix', (tester) async {
      final earlier = Completer<OperationLocationResult>();
      final later = Completer<OperationLocationResult>();
      Future<OperationLocationResult> subdivisions(GridLocation fix, double _) => fix == kent ? earlier.future : later.future;
      final gps = FakeGpsLocation()
        ..fix = kent
        ..accuracy = 300;
      final (services, operation) = await tester.runAsync(() => _harness(location: gps, subdivisions: subdivisions)) as (HaLoServices, Operation);
      Operation? draft;
      await _pumpSheet(tester, services, operation, onChanged: (op) => draft = op);

      expect(draft!.location, kent, reason: 'the grid is available before the county lookup finishes');
      gps.setFix(providence, accuracy: 5);
      later.complete((state: 'RI', county: 'Providence', candidates: const <OperationLocationCandidate>[]));
      await _pumpFrames(tester);
      expect(draft!.data['county'], 'Providence');

      earlier.complete((state: 'RI', county: null, candidates: [(state: 'RI', county: 'Kent'), (state: 'RI', county: 'Providence')]));
      await _pumpFrames(tester);
      expect(draft!.location, providence);
      expect(draft!.data['county'], 'Providence');
      expect(find.text(AppLocale.en.buildSync().operationLocationScreen.reviewGps), findsNothing);
    });

    // A log reopened somewhere else — at home, the day after — must not be
    // moved to wherever the device is now.
    testWidgets('leaves an operation that already has contacts unplaced', (tester) async {
      final gps = FakeGpsLocation()..fix = fix;
      final (services, operation) = await tester.runAsync(() => _harness(location: gps, qsoCount: 3)) as (HaLoServices, Operation);
      Operation? draft;
      await _pumpSheet(tester, services, operation, onChanged: (op) => draft = op);

      expect(draft, isNull, reason: 'nothing was written to the draft');
    });

    // A park picked before the fix arrived is the operator's statement; the
    // fix landing a moment later is not a reason to overrule it.
    testWidgets('never replaces a location the refs placed, and the pill shows its six characters', (tester) async {
      GridPrecision.configure(GridPrecision.eight);
      addTearDown(GridPrecision.reset);
      final gps = FakeGpsLocation();
      final (services, operation) = await tester.runAsync(() => _harness(location: gps)) as (HaLoServices, Operation);
      Operation? draft;
      await _pumpSheetAndAddPark(tester, services, operation, onChanged: (op) => draft = op);
      expect(draft!.data['gridSource'], refsGridSource);

      gps.setFix(fix);
      await _pumpFrames(tester);

      expect(draft!.data['gridSource'], refsGridSource);
      final grid = locationToGrid6(_parkLocation.latitude, _parkLocation.longitude);
      expect(find.text(grid), findsWidgets, reason: 'six characters at an eight-character Grid Precision');
    });

    // The common real path: the sheet opens, and the fix lands seconds later.
    testWidgets('arriving after the sheet opened is captured', (tester) async {
      final gps = FakeGpsLocation();
      final (services, operation) = await tester.runAsync(() => _harness(location: gps)) as (HaLoServices, Operation);
      Operation? draft;
      await _pumpSheet(tester, services, operation, onChanged: (op) => draft = op);
      expect(draft, isNull);

      gps.setFix(fix);
      await _pumpFrames(tester);

      expect(draft?.data['gridSource'], gpsGridSource);
    });

    // A receiver with nothing to report yet can read exactly 0,0. Captured,
    // its JJ00aa locator places the station at Null Island although every
    // reader refuses the pair.
    testWidgets('a 0,0 reading is not captured', (tester) async {
      final gps = FakeGpsLocation();
      final (services, operation) = await tester.runAsync(() => _harness(location: gps)) as (HaLoServices, Operation);
      Operation? draft;
      await _pumpSheet(tester, services, operation, onChanged: (op) => draft = op);

      gps.setFix(const GridLocation(0, 0));
      await _pumpFrames(tester);

      expect(draft, isNull);
    });

    // The service keeps its last position through a restart's `determining`
    // and a stream error. Read as live, it would place a new operation
    // wherever the device was hours ago.
    testWidgets('a remembered position is never captured', (tester) async {
      final gps = FakeGpsLocation()
        ..fix = fix
        ..statusOverride = LocationStatus.determining;
      final (services, operation) = await tester.runAsync(() => _harness(location: gps)) as (HaLoServices, Operation);
      Operation? draft;
      await _pumpSheet(tester, services, operation, onChanged: (op) => draft = op);

      expect(draft, isNull);
    });

    // A device's first answer is often its worst: a cached position, a Wi-Fi
    // estimate. Stored once and never revisited, it would ship in every export.
    testWidgets('is refined by a more accurate one while the sheet is open, and never by a vaguer one', (tester) async {
      const better = GridLocation(41.72, -74.53);
      const worse = GridLocation(41.8, -74.6);
      final gps = FakeGpsLocation()
        ..fix = fix
        ..accuracy = 300;
      final (services, operation) = await tester.runAsync(() => _harness(location: gps)) as (HaLoServices, Operation);
      Operation? draft;
      await _pumpSheet(tester, services, operation, onChanged: (op) => draft = op);
      expect(draft!.data['lat'], 41.71346);

      gps.setFix(better, accuracy: 10);
      await _pumpFrames(tester);
      expect(draft!.data['lat'], better.latitude, reason: 'a tighter fix replaces the one this session captured');

      gps.setFix(worse, accuracy: 50);
      await _pumpFrames(tester);
      expect(draft!.data['lat'], better.latitude, reason: 'a vaguer fix does not');
    });

    testWidgets('vaguer than half a kilometre is never stored', (tester) async {
      final gps = FakeGpsLocation()
        ..fix = fix
        ..accuracy = 2000;
      final (services, operation) = await tester.runAsync(() => _harness(location: gps)) as (HaLoServices, Operation);
      Operation? draft;
      await _pumpSheet(tester, services, operation, onChanged: (op) => draft = op);

      expect(draft, isNull, reason: 'an IP estimate can name the wrong town');
    });

    // Clearing the location is the operator's answer. Captured again on the
    // next position update, it would be impossible to leave a new operation
    // unlocated while GPS is allowed.
    testWidgets('a location the operator cleared in the sheet stays cleared', (tester) async {
      final gps = FakeGpsLocation()..fix = fix;
      final (services, operation) = await tester.runAsync(() => _harness(location: gps)) as (HaLoServices, Operation);
      Operation? draft;
      await _pumpSheet(tester, services, operation, onChanged: (op) => draft = op);
      expect(draft!.data['gridSource'], gpsGridSource);

      await tester.tap(find.text('GPS'));
      await _pumpFrames(tester);
      await tester.enterText(find.widgetWithText(TextField, gpsLocationData(fix)['grid'] as String), '');
      await tester.tap(find.text(AppLocale.en.buildSync().common.save));
      await _pumpFrames(tester);
      expect(draft!.location, isNull);

      gps.setFix(const GridLocation(41.72, -74.53), accuracy: 1);
      await _pumpFrames(tester);
      expect(draft!.location, isNull);
    });
  });
}

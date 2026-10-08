// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The sheet places an operation from a park as it is added, on its draft,
// and its save tells the repository not to decide it again
// (docs/design/locations.md, "Located by its references"). Both halves are
// wiring the rule's own tests cannot see: drop the draft's call and the
// operation is placed only after the sheet closes — or never, since the save
// opts out; drop the opt-out and a location the operator cleared comes back.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

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
  _ParkExtensions()
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
}

Future<(HaLoServices, Operation)> _harness() async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService(await SharedPreferences.getInstance());
  final services = HaLoServices(HaLoDatabase(NativeDatabase.memory()), settings, extensions: _ParkExtensions()..settings = settings);
  // The row exists so the save has something to update; the sheet is handed
  // the bare shape the other activities tests use.
  final created = await services.operations.create(stationCall: 'N0DEV');
  return (services, Operation(uuid: created.uuid, data: const {'refs': []}));
}

Future<OperationSheetState> _pumpSheetAndAddPark(WidgetTester tester, HaLoServices services, Operation operation, {void Function(Operation)? onChanged}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: OperationSheet(services: services, operation: operation, onOperationChanged: onChanged),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('POTA US-0001').first);
  await _pumpFrames(tester);
  return tester.state<OperationSheetState>(find.byType(OperationSheet));
}

/// Frames, not pumpAndSettle: once the park places the operation, the sheet
/// searches again from there, and that search's progress bar keeps animating
/// while it waits on I/O a fake-async test never completes.
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
}

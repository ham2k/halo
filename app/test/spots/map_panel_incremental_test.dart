// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Map pane derives each contact's marker and great-circle line once and
// keeps them until that contact changes. What these pin down is the boundary:
// an emission that changed nothing hands the backend the same objects (so its
// diff is empty and nothing crosses to the map), a contact that changed is the
// only one re-derived, and a pane nobody can see derives nothing until it is
// shown. Without the cache, each would redo the work for all of a long log on
// every emission.

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/geoshape_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/map/map_marker_data.dart';
import 'package:ham2k_logger/views/map/osm_map_view.dart';
import 'package:ham2k_logger/views/operation/map_panel.dart';

import '../support/map_tile_cache.dart';

Qso _contact(String uuid, {int? stamp, String grid = 'JO01aa', String call = 'G0AAA', String? ourGrid, GridLocation? ourLocation}) => Qso(
  uuid: uuid,
  operationUuid: 'op-map',
  data: {
    'uuid': uuid,
    'their': {'call': call, 'grid': grid},
    'our': {'grid': ?ourGrid, 'lat': ?ourLocation?.latitude, 'lon': ?ourLocation?.longitude},
    'band': '20m',
    'mode': 'SSB',
    'startAtMillis': 1000,
    'updatedAtMillis': ?stamp,
  },
);

Operation _operation({String grid = 'FN20ab'}) => Operation(uuid: 'op-map', data: {'grid': grid, 'refs': const []});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTempMapTileCache();

  late HaLoDatabase db;
  late SettingsService settings;
  late GeoshapeService geoshapes;
  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService(await SharedPreferences.getInstance());
    geoshapes = GeoshapeService(extensions: ExtensionService(), lookups: LookupRepository(db));
  });
  tearDown(() => db.close());

  /// On Linux the pane picks the OSM backend, which renders in a test; the GL
  /// ones need a webview. Restored inside the body: the binding checks the
  /// override before tearDown runs.
  Future<void> onLinux(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  Widget host(List<Qso> qsos, {Operation? operation, bool visible = true}) => TranslationProvider(
    child: MaterialApp(
      home: Scaffold(
        body: DockPaneVisibility(
          visible: visible,
          child: MapPanel(operation: operation ?? _operation(), qsos: qsos, settings: settings, geoshapes: geoshapes, activityControls: const []),
        ),
      ),
    ),
  );

  OsmMapView backend(WidgetTester tester) => tester.widget<OsmMapView>(find.byType(OsmMapView));
  List<MapLineData> linesOf(WidgetTester tester) => backend(tester).lines.where((l) => !l.highlight).toList();
  List<MapMarkerData> qsoMarkersOf(WidgetTester tester) => backend(tester).markers.where((m) => m.kind == MapMarkerKind.qso).toList();

  testWidgets(
    'an emission that changed nothing hands the backend the same objects',
    (tester) => onLinux(() async {
      await tester.pumpWidget(host([_contact('a', stamp: 1), _contact('b', stamp: 2)]));
      await tester.pumpAndSettle();
      final lines = linesOf(tester);
      final markers = qsoMarkersOf(tester);
      expect(lines, hasLength(2));

      // A new list instance with the same contacts and stamps: a score-cache
      // write, a sync flag — most of the emissions a logged contact causes.
      await tester.pumpWidget(host([_contact('a', stamp: 1), _contact('b', stamp: 2)]));
      await tester.pumpAndSettle();
      final again = linesOf(tester);
      expect(identical(again[0], lines[0]) && identical(again[1], lines[1]), isTrue, reason: 'nothing re-derived');
      final markersAgain = qsoMarkersOf(tester);
      expect(markersAgain.every((m) => markers.any((was) => identical(was, m))), isTrue);
    }),
  );

  testWidgets(
    'an appended contact is derived; the others are kept',
    (tester) => onLinux(() async {
      await tester.pumpWidget(host([_contact('a', stamp: 1)]));
      await tester.pumpAndSettle();
      final before = linesOf(tester).single;

      await tester.pumpWidget(host([_contact('a', stamp: 1), _contact('b', stamp: 2, grid: 'IO91wm', call: 'G4AAA')]));
      await tester.pumpAndSettle();
      final lines = linesOf(tester);
      expect(lines.map((l) => l.id), ['a/0', 'b/0']);
      expect(identical(lines[0], before), isTrue);
    }),
  );

  testWidgets(
    'an edited contact is the only one re-derived; a deleted one is gone',
    (tester) => onLinux(() async {
      await tester.pumpWidget(host([_contact('a', stamp: 1), _contact('b', stamp: 2)]));
      await tester.pumpAndSettle();
      final before = linesOf(tester);

      await tester.pumpWidget(host([_contact('a', stamp: 1), _contact('b', stamp: 3, grid: 'IO91wm')]));
      await tester.pumpAndSettle();
      final edited = linesOf(tester);
      expect(identical(edited[0], before[0]), isTrue, reason: 'a untouched');
      expect(identical(edited[1], before[1]), isFalse, reason: 'b re-derived under its new stamp');
      expect(edited[1].points.first.longitude, isNot(before[1].points.first.longitude), reason: 'and from its new grid');

      await tester.pumpWidget(host([_contact('a', stamp: 1)]));
      await tester.pumpAndSettle();
      expect(linesOf(tester).map((l) => l.id), ['a/0']);
    }),
  );

  testWidgets(
    'a change to what every contact shares re-derives them all',
    (tester) => onLinux(() async {
      await tester.pumpWidget(host([_contact('a', stamp: 1), _contact('b', stamp: 2)]));
      await tester.pumpAndSettle();
      final before = linesOf(tester);

      // The station moved: every line draws to the new QTH.
      await tester.pumpWidget(host([_contact('a', stamp: 1), _contact('b', stamp: 2)], operation: _operation(grid: 'EM12aa')));
      await tester.pumpAndSettle();
      final moved = linesOf(tester);
      expect(identical(moved[0], before[0]) || identical(moved[1], before[1]), isFalse);
      expect(moved[0].points.last.longitude, isNot(before[0].points.last.longitude));
    }),
  );

  // A QTH a contact draws to is placed by the first contact naming its grid:
  // a precise fix if that contact has one, the grid's centre otherwise. A
  // cached contact keeps its line to wherever the grid WAS placed, so a grid
  // whose placing changes has to reach every contact drawing to it — with
  // their stamps untouched.
  testWidgets(
    'a QTH grid whose placing moves re-derives the contacts that draw to it',
    (tester) => onLinux(() async {
      final fix = GridLocation(51.5, -0.1);
      // No operation location: the contacts' own grids place the QTH.
      final op = Operation(uuid: 'op-map', data: {'refs': const []});
      final placer = _contact('p', stamp: 1, ourGrid: 'IO91wm', ourLocation: fix);
      // The same DISPLAY grid as the placer's fix shows, so the two share a QTH.
      final follower = _contact('f', stamp: 2, ourGrid: placer.ourDisplayGrid!);
      expect(follower.ourDisplayGrid, placer.ourDisplayGrid, reason: 'the fixture only holds if both show the same grid');
      await tester.pumpWidget(host([placer, follower], operation: op));
      await tester.pumpAndSettle();
      final drawnToFix = linesOf(tester).firstWhere((l) => l.id == 'f/0');
      expect(drawnToFix.points.last.latitude, closeTo(fix.latitude, 1e-6), reason: 'the follower draws to the fix the placer placed');

      // The placer is deleted: the grid is now placed by the follower's own
      // grid centre, and its line has to move there — same stamp.
      await tester.pumpWidget(host([follower], operation: op));
      await tester.pumpAndSettle();
      final drawnToCentre = linesOf(tester).single;
      expect(identical(drawnToCentre, drawnToFix), isFalse);
      expect(drawnToCentre.points.last.latitude, isNot(closeTo(fix.latitude, 1e-6)), reason: 'the line follows the QTH');

      // The placer returns ahead of the follower in log order: the follower,
      // still unchanged, draws to the fix again.
      await tester.pumpWidget(host([placer, follower], operation: op));
      await tester.pumpAndSettle();
      expect(linesOf(tester).firstWhere((l) => l.id == 'f/0').points.last.latitude, closeTo(fix.latitude, 1e-6));
    }),
  );

  // Synced records from before stamps existed, and a peer's edit to one,
  // carry no stamp; the cache cannot tell them apart from unchanged, so it
  // must not keep them.
  testWidgets(
    'a contact with no stamp is derived on every emission',
    (tester) => onLinux(() async {
      await tester.pumpWidget(host([_contact('a')]));
      await tester.pumpAndSettle();
      final before = linesOf(tester).single;
      await tester.pumpWidget(host([_contact('a', grid: 'IO91wm')]));
      await tester.pumpAndSettle();
      final after = linesOf(tester).single;
      expect(identical(after, before), isFalse);
      expect(after.points.first.longitude, isNot(before.points.first.longitude), reason: 'the edit reached the map');
    }),
  );

  testWidgets(
    'a hidden pane derives nothing, and catches up when shown',
    (tester) => onLinux(() async {
      await tester.pumpWidget(host([_contact('a', stamp: 1)]));
      await tester.pumpAndSettle();
      final shown = linesOf(tester);

      await tester.pumpWidget(host([_contact('a', stamp: 1), _contact('b', stamp: 2, grid: 'IO91wm')], visible: false));
      await tester.pumpAndSettle();
      expect(linesOf(tester).map((l) => l.id), ['a/0'], reason: 'hidden: the new contact is not derived yet');
      expect(identical(linesOf(tester).single, shown.single), isTrue);

      await tester.pumpWidget(host([_contact('a', stamp: 1), _contact('b', stamp: 2, grid: 'IO91wm')], visible: true));
      await tester.pumpAndSettle();
      expect(linesOf(tester).map((l) => l.id), ['a/0', 'b/0'], reason: 'shown: caught up in one pass');
    }),
  );
}

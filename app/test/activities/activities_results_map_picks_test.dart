// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a tap on the Activities results map opens when several references lie
// under it: the reveal card pages through all of them, so a park hidden under
// a neighbour's dot or inside a bigger outline is still reachable — and a
// reference removed from its card stays on screen to be added back.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/map/osm_map_view.dart';
import 'package:ham2k_logger/views/operation/activities_results_map.dart';

import '../support/halo_test_support.dart';

// A couple of metres apart: one spot on any map. Listed out of reference
// order, so an order that merely followed the list would show.
const _second = {'type': 'pota', 'ref': 'US-0002', 'lat': 40.0, 'lon': -75.0};
const _first = {'type': 'pota', 'ref': 'US-0001', 'lat': 40.0, 'lon': -75.00002};
const _third = {'type': 'pota', 'ref': 'US-0003', 'lat': 40.0, 'lon': -75.00001};

// Far enough to be off any 20 pixels at the zoom the map fits these at.
const _far = {'type': 'pota', 'ref': 'US-0009', 'lat': 41.0, 'lon': -76.0};

const _added = {'type': 'potaActivation', 'ref': 'US-0005', 'lat': 40.5, 'lon': -75.5};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTempMapTileCache();

  Future<void> pump(WidgetTester tester, {required List<Map<String, dynamic>> suggestions, List<Map<String, dynamic>> refs = const []}) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: ActivitiesResultsMap(suggestions: suggestions, controls: const [], refs: refs, settings: settings, onAdd: (_) {}, onRemove: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  OsmMapView map(WidgetTester tester) => tester.widget<OsmMapView>(find.byType(OsmMapView));

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byWidgetPredicate((w) => w is Icon && w.semanticLabel == t.activitiesView.nextPick));
    await tester.pumpAndSettle();
  }

  testWidgets('a dot tapped among neighbours opens first, and the pager reaches every one of them', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await pump(tester, suggestions: const [_third, _second, _first, _far]);

      map(tester).onMarkerTap!('ref-pota/US-0002');
      await tester.pumpAndSettle();
      // The dot aimed at leads, even though it sorts second: opening a
      // neighbour's card instead reads as the tap missing.
      expect(find.text('US-0002'), findsOneWidget);
      expect(find.text(t.activitiesView.pickPosition(index: 1, count: 3)), findsOneWidget, reason: 'the far park is not under the tap');

      await next(tester);
      expect(find.text('US-0001'), findsOneWidget);
      await next(tester);
      expect(find.text('US-0003'), findsOneWidget);
      expect(find.text(t.activitiesView.pickPosition(index: 3, count: 3)), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a tap on the map itself opens the dots under it by reference, and a lone dot shows no pager', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await pump(tester, suggestions: const [_third, _second, _first, _far]);

      map(tester).onMapTap!(const GridLocation(40.0, -75.00001));
      await tester.pumpAndSettle();
      expect(find.text('US-0001'), findsOneWidget);
      expect(find.text(t.activitiesView.pickPosition(index: 1, count: 3)), findsOneWidget);

      map(tester).onMarkerTap!('ref-pota/US-0009');
      await tester.pumpAndSettle();
      expect(find.text('US-0009'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Icon && w.semanticLabel == t.activitiesView.nextPick), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a reference removed from its card stays open, offering Add again', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await pump(tester, suggestions: const [_far], refs: const [_added]);

      map(tester).onMarkerTap!('ref-potaActivation/US-0005');
      await tester.pumpAndSettle();
      expect(find.text(t.activitiesView.selected), findsOneWidget);

      // What the pane does on a removal: the reference leaves the operation
      // and comes back at the head of the suggestions, in a new list.
      await pump(tester, suggestions: const [_added, _far]);

      // Closed, the card would take the only undo for a mistaken tap with it.
      expect(find.text('US-0005'), findsOneWidget);
      expect(find.text(t.activitiesView.selected), findsNothing);
      expect(find.byType(FilledButton), findsOneWidget, reason: 'Add, in whichever length the width allows');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('an open card follows its park through a re-ranked, grown list, and closes once it is gone', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await pump(tester, suggestions: const [_far, _second]);
      map(tester).onMarkerTap!('ref-pota/US-0002');
      await tester.pumpAndSettle();
      expect(find.text('US-0002'), findsOneWidget);

      // Parks found later land ranked ahead of it: by position, the card would
      // now show whichever park moved into its place.
      await pump(tester, suggestions: const [_first, _third, _second, _far]);
      expect(find.text('US-0002'), findsOneWidget);

      await pump(tester, suggestions: const [_first, _far]);
      expect(find.text('US-0002'), findsNothing, reason: 'no longer listed, there is nothing for its card to offer');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the pager keeps what the tap found while it is still listed', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await pump(tester, suggestions: const [_third, _second, _first, _far]);
      map(tester).onMarkerTap!('ref-pota/US-0002');
      await tester.pumpAndSettle();
      expect(find.text(t.activitiesView.pickPosition(index: 1, count: 3)), findsOneWidget);

      await pump(tester, suggestions: const [_second, _first, _far]);
      expect(find.text('US-0002'), findsOneWidget);
      expect(find.text(t.activitiesView.pickPosition(index: 1, count: 2)), findsOneWidget, reason: 'one park dropped out; the rest are still under the tap');

      await pump(tester, suggestions: const [_second, _far]);
      expect(find.byWidgetPredicate((w) => w is Icon && w.semanticLabel == t.activitiesView.nextPick), findsNothing, reason: 'alone, it needs no pager');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

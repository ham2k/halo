// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Suggestions & Search map toggle: tapping it swaps the results LIST
// out (not just covers it — a stale list row must not still be tappable
// underneath), tapping a marker reveals the reference rather than adding it
// outright, and only the reveal card's own Add button writes the ref.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/views/map/map_popup.dart';
import 'package:ham2k_logger/views/map/osm_map_view.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

import '../support/halo_test_support.dart';

const _parkControl = {
  'key': 'pota/activation',
  'label': 'Parks on the Air',
  'input': {'kind': 'refList', 'refType': 'pota'},
};

const _parkSuggestion = {'type': 'pota', 'ref': 'US-0001', 'label': 'POTA US-0001', 'shortLabel': 'POTA US-0001', 'name': 'Some Park', 'grid': 'FN21ab'};

class _MapToggleExtensions extends ExtensionServiceWithFakeHost {
  _MapToggleExtensions()
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
      (controls: const [_parkControl], loadFailed: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTempMapTileCache();

  testWidgets('map toggle swaps the list for a map; a marker reveals, Add writes the ref', (tester) async {
    final HaLoHarness(:services) = await makeHaLoServices(extensions: _MapToggleExtensions());
    final operation = Operation(uuid: 'op-1', data: const {'refs': []});
    Operation? latest;

    // Forces the OSM backend (no webview probing needed) — the same seam
    // panel_html_platform_gate_test.dart uses for the Map tab. Reset in a
    // `finally`, not `addTearDown`: the binding asserts every debug
    // foundation var is back to null before the next test runs, and that
    // check fires before an `addTearDown` callback would.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: OperationSheet(services: services, operation: operation, onOperationChanged: (op) => latest = op),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('POTA US-0001'), findsOneWidget);
      expect(find.byType(OsmMapView), findsNothing);

      await tester.tap(find.byWidgetPredicate((w) => w is Icon && w.semanticLabel == t.activitiesView.showResultsMap));
      await tester.pumpAndSettle();

      expect(find.text('POTA US-0001'), findsNothing, reason: 'the list rows are swapped out, not just covered');
      expect(find.byType(OsmMapView), findsOneWidget);

      // Invoked directly rather than tapped at screen coordinates — the
      // marker's projected pixel position is an implementation detail of
      // flutter_map's camera fit, not something this test should pin down.
      final markerGesture = find.ancestor(of: find.byType(MapCircleMarker), matching: find.byType(GestureDetector));
      expect(markerGesture, findsOneWidget);
      tester.widget<GestureDetector>(markerGesture).onTap!();
      await tester.pumpAndSettle();

      expect(find.text('POTA US-0001'), findsOneWidget, reason: 'revealed in the popup card, not added yet');
      expect(latest, isNull, reason: 'a tap on the marker only reveals — it must not add by itself');

      await tester.tap(find.text(t.activitiesView.addToOperation));
      await tester.pumpAndSettle();

      expect(latest, isNotNull);
      expect(latest!.refs.where((r) => r['type'] == 'pota' && r['ref'] == 'US-0001'), hasLength(1));

      await tester.tap(find.byWidgetPredicate((w) => w is Icon && w.semanticLabel == t.activitiesView.showResultsList));
      await tester.pumpAndSettle();
      expect(find.byType(OsmMapView), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('toggling to the map keeps Current Activities visible, not just the results', (tester) async {
    final HaLoHarness(:services) = await makeHaLoServices(extensions: _MapToggleExtensions());
    // A ref already on the operation, distinct from the search suggestion —
    // proves the row surviving the toggle is the CURRENT ACTIVITIES one, not
    // a coincidental match against the suggestion's own text.
    final operation = Operation(
      uuid: 'op-1',
      data: const {
        'refs': [
          {'type': 'pota', 'ref': 'US-9999', 'shortLabel': 'POTA US-9999'},
        ],
      },
    );

    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: OperationSheet(services: services, operation: operation),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('POTA US-9999'), findsOneWidget);

      await tester.tap(find.byWidgetPredicate((w) => w is Icon && w.semanticLabel == t.activitiesView.showResultsMap));
      await tester.pumpAndSettle();

      expect(find.byType(OsmMapView), findsOneWidget);
      expect(find.text('POTA US-9999'), findsOneWidget, reason: 'the map only replaces the results area — refs already on the operation must stay visible');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Reporting a wrong outline from the notice under a map. The traps: a link
// offered where the report could never leave the device, or so far out that
// the operator cannot see the outline they are reporting; a report filed
// against a reference the operator did not pick; and a report that reaches
// whoever fixes outlines without the document, or the place, it is about.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/error_reporting_service.dart';
import 'package:ham2k_logger/views/map/map_marker_data.dart';
import 'package:ham2k_logger/views/map/map_zoom_controller.dart';
import 'package:ham2k_logger/views/map/outline_issue_dialog.dart';
import 'package:ham2k_logger/views/map/ref_shapes.dart';

import '../support/error_reporting_fakes.dart';

MapShapeData _shape(String refId, int index, {String label = 'POTA US-1234 · Catskill Park'}) => MapShapeData(
  id: '$refId/$index',
  rings: const [
    [GridLocation(0, 0), GridLocation(0, 1), GridLocation(1, 1)],
  ],
  color: Colors.green,
  sourceName: 'OSM',
  sourceUrl: 'https://services.ham2k.net/lookups/outlines/pota/US-1234.geojson',
  refLabel: label,
);

MapCameraSettled _camera(double zoom) =>
    (camera: MapCameraPosition(latitude: 42.1, longitude: -74.3, zoom: zoom), bounds: (south: 41.9, west: -74.6, north: 42.3, east: -74.0));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('each outlined reference is offered once, whatever pieces its outline is in', () {
    final candidates = outlineIssueCandidates([
      _shape('ref-potaActivation/US-1234', 0),
      _shape('ref-potaActivation/US-1234', 1),
      _shape('ref-sotaActivation/W2/GC-116', 0, label: 'SOTA W2/GC-116'),
    ]);
    // The SOTA summit's own slash stays in its id: only the piece index goes.
    expect(candidates.map((c) => c.refId), ['ref-potaActivation/US-1234', 'ref-sotaActivation/W2/GC-116']);
    expect(candidates.first.label, 'POTA US-1234 · Catskill Park');
  });

  test('only outlines inside the view are offered, and the one selected on the map', () {
    MapShapeData at(String refId, double lat, double lon) => MapShapeData(
      id: '$refId/0',
      rings: [
        [GridLocation(lat, lon), GridLocation(lat, lon + 0.1), GridLocation(lat + 0.1, lon + 0.1)],
      ],
      color: Colors.green,
      refLabel: refId,
    );
    final shapes = [at('in', 42.0, -74.3), at('far', 45.0, -70.0), at('selected', 30.0, -90.0), at('fiji', -17.0, 179.95)];
    List<String> ids(MapViewBounds view, {String? keep}) => [for (final c in outlineIssueCandidates(shapes, within: view, keep: keep)) c.refId];

    // Everything the map has loaded would be dozens of parks off-screen.
    expect(ids((south: 41.9, west: -74.6, north: 42.3, east: -74.0)), ['in']);
    expect(ids((south: 41.9, west: -74.6, north: 42.3, east: -74.0), keep: 'selected'), ['in', 'selected']);
    // West past east: the view spans 179°E..179°W.
    expect(ids((south: -18.0, west: 179.0, north: -16.0, east: -179.0)), ['fiji']);
  });

  test('a report names the reference, the document, the view and the operator', () {
    final candidate = outlineIssueCandidates([_shape('ref-potaActivation/US-1234', 0)]).single;
    const explanation = 'The east edge follows the road, not the park boundary.';
    final issue = (outline: candidate, severity: OutlineIssueSeverity.major, explanation: explanation);

    expect(outlineIssueTitle(issue), 'Outline issue (big deal): POTA US-1234 · Catskill Park');
    final body = outlineIssueBody(issue, (camera: _camera(11), operatorLocation: const GridLocation(42.0, -74.2), operatorGrid: 'FN22'));
    expect(body, contains('Source: OSM'));
    // What a reviewer opens to see the outline the operator saw.
    expect(body, contains('Outline: https://services.ham2k.net/lookups/outlines/pota/US-1234.geojson'));
    expect(body, contains('zoom 11.0'));
    expect(body, contains('Operator: FN22'));
    expect(body.trim().endsWith(explanation), isTrue);
  });

  group('the notice', () {
    final camera = ValueNotifier<MapCameraSettled?>(null);
    var opened = 0;

    Future<void> pump(WidgetTester tester, {TextScaler textScaler = TextScaler.noScaling}) async {
      opened = 0;
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
            home: Scaffold(
              body: MapOutlinesNotice(shapes: [_shape('ref-potaActivation/US-1234', 0)], camera: camera, onReportIssue: () => opened++),
            ),
          ),
        ),
      );
    }

    testWidgets('offer to report only close in, where the outline can be seen', (tester) async {
      await withErrorHooks(backend: FakeErrorReportingBackend(), () async {
        await pump(tester);
        camera.value = _camera(outlineIssuesFromZoom - 0.5);
        await tester.pump();
        expect(find.text('Issues?'), findsNothing);

        camera.value = _camera(outlineIssuesFromZoom);
        await tester.pump();
        await tester.tap(find.text('Issues?'));
        expect(opened, 1);
      });
      ErrorReportingService.resetForTesting();
    });

    testWidgets('offer nothing where a report could never leave the device', (tester) async {
      ErrorReportingService.resetForTesting();
      expect(ErrorReportingService.reportingEnabled, isFalse);
      await pump(tester);
      camera.value = _camera(outlineIssuesFromZoom + 2);
      await tester.pump();
      expect(find.text('Issues?'), findsNothing);
    });
  });

  group('the dialog', () {
    Future<void> open(WidgetTester tester, List<MapShapeData> shapes, {String? preselectedRefId}) async {
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => reportOutlineIssue(
                    context,
                    shapes: shapes,
                    preselectedRefId: preselectedRefId,
                    where: () => (camera: _camera(11), operatorLocation: null, operatorGrid: null),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    FilledButton send(WidgetTester tester) => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Send'));
    final explanation = find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == "What's wrong with it?");
    final referenceField = find.descendant(of: find.byType(DropdownMenu<String>), matching: find.byType(TextField));

    /// Types [filter] into the reference field and picks [label] from what
    /// is left of the list.
    Future<void> pick(WidgetTester tester, String filter, String label) async {
      await tester.tap(referenceField);
      await tester.pumpAndSettle();
      await tester.enterText(referenceField, filter);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    final twoOutlines = [_shape('ref-potaActivation/US-1234', 0), _shape('ref-sotaActivation/W2/GC-116', 0, label: 'SOTA W2/GC-116')];

    testWidgets('sends nothing until the outline, how bad and what is wrong are all said', (tester) async {
      final backend = FakeErrorReportingBackend();
      await withErrorHooks(backend: backend, () async {
        await open(tester, twoOutlines);
        // Two outlines and no card open: the operator picks — a guess would
        // file the report against the wrong park.
        await tester.tap(find.text('Big deal'));
        await tester.enterText(explanation, 'Misses the northern lake.');
        await tester.pump();
        expect(send(tester).onPressed, isNull);

        // Found by typing part of it, as in a list of dozens.
        await pick(tester, 'GC-1', 'SOTA W2/GC-116');
        expect(send(tester).onPressed, isNotNull);
        await tester.tap(find.text('Send'));
        await tester.pumpAndSettle();

        expect(backend.diagnostics.single.$1, 'Outline issue (big deal): SOTA W2/GC-116');
        expect(backend.diagnostics.single.$2, contains('Misses the northern lake.'));
        // Not "sent": the upload runs in the background and cannot say
        // whether it landed.
        expect(find.text('Sending your report — thanks'), findsOneWidget);
      });
      ErrorReportingService.resetForTesting();
    });

    testWidgets('the outline chosen is the one the field names', (tester) async {
      final backend = FakeErrorReportingBackend();
      await withErrorHooks(backend: backend, () async {
        await open(tester, twoOutlines);
        await tester.tap(find.text('Minor nit'));
        await tester.enterText(explanation, 'Off by a road.');
        await pick(tester, 'GC-1', 'SOTA W2/GC-116');
        expect(send(tester).onPressed, isNotNull);

        await tester.enterText(referenceField, 'Catsk');
        await tester.pumpAndSettle();
        expect(send(tester).onPressed, isNull, reason: 'the field no longer names the outline Send would file against');

        // Typed back out in full, without picking from the menu: the field
        // names it again, and a Send that stayed off would be a dead end.
        await tester.enterText(referenceField, 'POTA US-1234 · Catskill Park');
        await tester.pumpAndSettle();
        expect(send(tester).onPressed, isNotNull);
        await tester.tap(find.text('Send'));
        await tester.pumpAndSettle();
        expect(backend.diagnostics.single.$1, endsWith('POTA US-1234 · Catskill Park'));
      });
      ErrorReportingService.resetForTesting();
    });

    testWidgets('starts on the outline selected on the map', (tester) async {
      await withErrorHooks(backend: FakeErrorReportingBackend(), () async {
        await open(tester, twoOutlines, preselectedRefId: 'ref-sotaActivation/W2/GC-116');
        final field = tester.widget<TextField>(referenceField);
        expect(field.controller?.text, 'SOTA W2/GC-116');
      });
      ErrorReportingService.resetForTesting();
    });

    testWidgets('a report no backend took is kept for the operator to copy', (tester) async {
      await withErrorHooks(backend: FakeErrorReportingBackend(diagnosticThrows: true), () async {
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
          return null;
        });
        await open(tester, twoOutlines, preselectedRefId: 'ref-potaActivation/US-1234');
        await tester.tap(find.text('Minor nit'));
        await tester.enterText(explanation, 'The east edge is a road.');
        await tester.pump();
        await tester.tap(find.text('Send'));
        await tester.pumpAndSettle();

        // Still up long after a plain bar would have gone: reading it and
        // reaching for Copy takes longer than four seconds.
        await tester.pump(const Duration(seconds: 10));
        await tester.pumpAndSettle();
        expect(find.text("Couldn't send the report"), findsOneWidget);
        await tester.tap(find.text('Copy report'));
        await tester.pumpAndSettle();
        // Lost with the dialog, they would have to write it all again.
        expect(copied, allOf(contains('Outline issue (minor nit)'), contains('The east edge is a road.')));
        expect(find.text("Couldn't send the report"), findsNothing);
        expect(find.text('Report copied'), findsOneWidget);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });
      ErrorReportingService.resetForTesting();
    });
  });
}

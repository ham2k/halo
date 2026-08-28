// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Map tab draws the operation's own reference outlines — a summit's SOTA
// activation zone — alongside its QSOs. The same summit is drawn by the
// Activities pane's map too, and the two must agree: one publishing an outline
// while the other silently doesn't would read as a bug in whichever pane the
// operator looked at second.

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/geoshape_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/map/osm_map_view.dart';
import 'package:ham2k_logger/views/operation/map_panel.dart';

const _zone = '''
{"type":"FeatureCollection","features":[
  {"type":"Feature","geometry":{"type":"Polygon","coordinates":
    [[[-74.4,41.9],[-74.3,41.9],[-74.3,41.8],[-74.4,41.9]]]}}]}''';

// `refType` lives on the control's `input`, not at the top level — see
// halo_widgets' controlForRefType. A control shaped otherwise simply never
// matches, and the outline quietly takes the fallback color.
const _summitControl = {
  'key': 'sota/activation',
  'color': '#1B5E20',
  'input': {'refType': 'sotaActivation'},
};

/// Answers from a table rather than the network. Subclasses the real service
/// because that is what the panel holds — a loader taking some narrower
/// interface would be a seam this code doesn't have.
class _FakeGeoshapes extends GeoshapeService {
  _FakeGeoshapes(this.answers, {required super.lookups}) : super(extensions: ExtensionService());

  final Map<String, Geoshape> answers;
  final asked = <String>[];

  @override
  Future<Geoshape> shapeForRef(Map<String, dynamic> ref) async {
    final key = '${ref['ref']}';
    asked.add(key);
    return answers[key] ?? Geoshape.none;
  }
}

Operation _operationWith({String? grid, List<Map<String, dynamic>> refs = const []}) => Operation(
      uuid: 'op-shapes',
      data: {if (grid != null) 'grid': grid, 'refs': refs},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  setUp(() => db = HaLoDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<_FakeGeoshapes> pump(
    WidgetTester tester, {
    required Operation operation,
    required Map<String, Geoshape> answers,
    List<Map<String, dynamic>> controls = const [],
  }) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final geoshapes = _FakeGeoshapes(answers, lookups: LookupRepository(db));

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: MapPanel(
            operation: operation,
            qsos: const [],
            settings: settings,
            geoshapes: geoshapes,
            activityControls: controls,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return geoshapes;
  }

  testWidgets('the operation\'s summit is outlined, in its activity color', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await pump(
        tester,
        // A grid is what puts a marker on the map; with none the panel shows
        // its empty state and never reaches a backend at all.
        operation: _operationWith(grid: 'FN31pr', refs: const [
          {'type': 'sotaActivation', 'ref': 'W2/GC-099'}
        ]),
        answers: const {'W2/GC-099': Geoshape(_zone, resolved: true)},
        controls: const [_summitControl],
      );
      await tester.pumpAndSettle();

      final shapes = tester.widget<OsmMapView>(find.byType(OsmMapView)).shapes;
      expect(shapes, hasLength(1));
      expect(shapes.single.rings.first, hasLength(4));
      // The color its own row and its Activities-map dot wear — not a wash
      // invented here, or the same summit reads as two different things.
      expect(shapes.single.color, const Color(0xFF1B5E20));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a reference whose program publishes no outline draws nothing', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await pump(
        tester,
        operation: _operationWith(grid: 'FN31pr', refs: const [
          {'type': 'potaActivation', 'ref': 'US-0001'}
        ]),
        answers: const {},
      );
      await tester.pumpAndSettle();

      expect(tester.widget<OsmMapView>(find.byType(OsmMapView)).shapes, isEmpty);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('an operation with nothing to draw asks for no outlines at all', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      // No grid and no QSOs: the panel renders its empty state instead of a
      // map. Asking anyway would spend an activator's data on an outline
      // nothing is going to render.
      final geoshapes = await pump(
        tester,
        operation: _operationWith(refs: const [
          {'type': 'sotaActivation', 'ref': 'W2/GC-099'}
        ]),
        answers: const {'W2/GC-099': Geoshape(_zone, resolved: true)},
      );
      await tester.pumpAndSettle();

      expect(find.byType(OsmMapView), findsNothing);
      expect(geoshapes.asked, isEmpty);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

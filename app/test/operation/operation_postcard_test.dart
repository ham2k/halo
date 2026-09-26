// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Operation Postcard promises three things: the picture is the Map tab's
// own framing, not a fresh fit; the image is the preview at twice its logical
// size whatever size the preview happens to be drawn at; and a snapshot waits
// for a map that has actually finished drawing.
//
// The GL half runs the real map_gl_script.dart in QuickJS against a fake
// MapLibre that records what the script asks of it — which pins the script's
// decisions, not the library's rendering.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_quickjs/halo_quickjs.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/views/map/map_gl_script.dart' show mapGlScript;
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/map/map_marker_data.dart';
import 'package:ham2k_logger/views/map/map_zoom_controller.dart';
import 'package:ham2k_logger/views/operation/map_panel.dart' show retonedMapData;
import 'package:ham2k_logger/views/operation/operation_postcard.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/error_reporting_fakes.dart';

/// Just enough of a browser and of MapLibre for a framed `create`, a
/// `setMarkers` and a `snapshot`: timers on a clock the test advances, a map
/// whose events the test fires, and a canvas that says what pixel ratio it
/// was read at.
const _fakeBrowser = r'''
var window = globalThis;
var calls = [];
var now = 0;
var timers = [];
var nextTimer = 1;
function setTimeout(fn, ms) { var id = nextTimer++; timers.push({ id: id, at: now + (ms || 0), fn: fn }); return id; }
function clearTimeout(id) { timers = timers.filter(function (t) { return t.id !== id; }); }
function advance(ms) {
  var until = now + ms;
  for (;;) {
    var due = timers.filter(function (t) { return t.at <= until; }).sort(function (a, b) { return a.at - b.at; })[0];
    if (!due) break;
    clearTimeout(due.id);
    now = due.at;
    due.fn();
  }
  now = until;
}
window.addEventListener = function () {};
window.removeEventListener = function () {};
function ResizeObserver() {}
ResizeObserver.prototype.observe = function () {};
ResizeObserver.prototype.disconnect = function () {};
var document = {
  createElement: function () { return { style: {}, children: [], appendChild: function (c) { this.children.push(c); } }; },
  createTextNode: function (text) { return { text: text }; },
};
function LngLatBounds() { this.n = 0; }
LngLatBounds.prototype.extend = function () { this.n++; };
LngLatBounds.prototype.isEmpty = function () { return this.n === 0; };
var sourcesLoaded = true;
function FakeMap(options) {
  var listeners = {};
  var sources = {};
  var layers = {};
  var pixelRatio = null;
  this.options = options;
  this.on = function (type, fn) { (listeners[type] = listeners[type] || []).push({ fn: fn }); };
  this.once = function (type, fn) { (listeners[type] = listeners[type] || []).push({ fn: fn, once: true }); };
  this.fire = function (type) {
    var ls = listeners[type] || [];
    listeners[type] = ls.filter(function (l) { return !l.once; });
    ls.forEach(function (l) { l.fn({}); });
  };
  this.getSource = function (id) { return sources[id]; };
  this.addSource = function (id) { sources[id] = { setData: function () {} }; };
  this.getLayer = function (id) { return layers[id]; };
  this.addLayer = function (layer) { layers[layer.id] = layer; };
  this.fitBounds = function () { calls.push('fitBounds'); };
  this.loaded = function () { return sourcesLoaded; };
  this.isStyleLoaded = function () { return true; };
  this.setPixelRatio = function (r) { pixelRatio = r; calls.push('setPixelRatio ' + r); };
  this.triggerRepaint = function () {};
  this.getCanvas = function () { return { style: {}, toDataURL: function (type) { return 'data:' + type + ';ratio=' + pixelRatio + ';base64,AAAA'; } }; };
  this.getCenter = function () { return { lat: options.center[1], lng: options.center[0] }; };
  this.getZoom = function () { return options.zoom; };
  this.getBearing = function () { return options.bearing || 0; };
  this.getPitch = function () { return options.pitch || 0; };
  this.getContainer = function () { return options.container; };
  this.queryRenderedFeatures = function () { return window.hits || []; };
  this.remove = function () {};
  window.fakeMap = this;
}
function Popup() { this.open = false; }
Popup.prototype.setLngLat = function () { return this; };
Popup.prototype.setDOMContent = function () { return this; };
Popup.prototype.addTo = function () { this.open = true; return this; };
Popup.prototype.isOpen = function () { return this.open; };
Popup.prototype.remove = function () { this.open = false; return this; };
var maplibregl = { Map: FakeMap, LngLatBounds: LngLatBounds, AJAXError: function () {}, Popup: Popup };
''';

class _GlPage {
  final _js = HaloQuickJs();

  _GlPage({required bool framed}) {
    run(_fakeBrowser);
    run(mapGlScript);
    final frame = framed ? jsonEncode({'latitude': 41.5, 'longitude': -74.4, 'zoom': 9.25, 'bearing': 0, 'pitch': 0, 'width': 540, 'height': 960}) : 'null';
    run("var container = document.createElement('div'); container.clientWidth = 270; container.clientHeight = 480;");
    run("var handle = window.poloMapGl.create(container, 'light-style', 'dark-style', false, function () {}, false, $frame);");
  }

  String run(String code) {
    final result = _js.eval(code);
    if (!result.ok) fail('JS threw: ${result.text}');
    return result.text;
  }

  void pumpPromises() {
    while (_js.pump() > 0) {}
  }

  List<String> takeCalls() => (jsonDecode(run('var c = JSON.stringify(calls); calls = []; c')) as List).cast<String>();

  void dispose() => _js.dispose();
}

const _markers = "[{id: 'q1', latitude: 40, longitude: -74, kind: 'qso', color: '#ff0000', strokeColor: '#000000'}]";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a framed GL map', () {
    late _GlPage page;
    tearDown(() => page.dispose());

    test('keeps the camera it was given when its contacts arrive', () {
      page = _GlPage(framed: true);
      page.run('handle.setMarkers($_markers)');
      // The pane's map fits its contacts; a framed one refitting would throw
      // away the operator's framing, which is the whole point of reading it.
      expect(page.takeCalls(), isNot(contains('fitBounds')));
      expect(jsonDecode(page.run('JSON.stringify(handle.camera())')), containsPair('zoom', 9.25));
      expect(page.run('String(fakeMap.options.interactive)'), 'false', reason: 'a picture takes no gestures');
      expect(page.run('String(fakeMap.options.attributionControl)'), 'false', reason: 'the credit is drawn into the picture by the host instead');
    });

    test('is laid out at the frame size and scaled to the container, not resized to it', () {
      page = _GlPage(framed: true);
      // Laid out at the container's size, a 270-wide preview would show a
      // different extent and label density from the 540-wide picture.
      expect(page.run("fakeMap.options.container.style.width + ' ' + fakeMap.options.container.style.height"), '540px 960px');
      expect(page.run('fakeMap.options.container.style.transform'), 'scale(0.5)');
    });

    test("the Map tab's own map still fits its contacts", () {
      page = _GlPage(framed: false);
      page.run('handle.setMarkers($_markers)');
      expect(page.takeCalls(), contains('fitBounds'));
    });

    test("the Map tab's own map says whose popup is open over it", () {
      page = _GlPage(framed: false);
      page.run('handle.setMarkers($_markers)');
      Object? camera() => jsonDecode(page.run('JSON.stringify(handle.camera())'));
      expect(mapCameraViewFromJson(camera())?.popup, isNull);
      // A click on the dot, as the map reports one.
      page.run("window.hits = [{ properties: { id: 'q1' } }]; fakeMap.fire('click')");
      expect(mapCameraViewFromJson(camera())?.popup, 'q1', reason: 'a page element over the canvas, which a picture has to draw for itself');
      page.run("window.hits = []; fakeMap.fire('click')");
      expect(mapCameraViewFromJson(camera())?.popup, isNull, reason: 'closed by a click elsewhere');
    });

    test("the Map tab's own map says how big a window it looks through", () {
      page = _GlPage(framed: false);
      // Without the size, a zoom says nothing about how much ground the
      // operator framed.
      expect(mapCameraViewFromJson(jsonDecode(page.run('JSON.stringify(handle.camera())')))?.viewport, const Size(270, 480));
    });
  });

  group('a snapshot', () {
    late _GlPage page;
    tearDown(() => page.dispose());

    // Pumped: a snapshot starts when the one before it — if any — is done.
    void start() {
      page.run('var result = null, failure = null; handle.snapshot(2).then(function (d) { result = d; }, function (e) { failure = String(e); });');
      page.pumpPromises();
    }

    test('is read at the asked ratio from a frame drawn after the map went idle, then the ratio is given back', () {
      page = _GlPage(framed: true);
      page.run('handle.setMarkers($_markers)');
      page.takeCalls();
      start();
      expect(page.takeCalls(), ['setPixelRatio 2']);
      // A frame before 'idle' is one with tiles still missing.
      page.run("fakeMap.fire('render')");
      page.pumpPromises();
      expect(page.run('String(result)'), 'null');
      page.run("fakeMap.fire('idle')");
      page.run("fakeMap.fire('render')");
      page.pumpPromises();
      expect(page.run('result'), startsWith('data:image/png;ratio=2;'), reason: 'read before the ratio went back');
      expect(page.takeCalls(), ['setPixelRatio null'], reason: 'the preview is left at the device ratio');
    });

    test('waits out a source still parsing data applied in the same idle', () {
      page = _GlPage(framed: true);
      start();
      page.run("sourcesLoaded = false; fakeMap.fire('idle'); fakeMap.fire('render')");
      page.pumpPromises();
      expect(page.run('String(result)'), 'null', reason: 'that frame would be drawn without the contacts');
      page.run("sourcesLoaded = true; fakeMap.fire('idle'); fakeMap.fire('render')");
      page.pumpPromises();
      expect(page.run('result'), startsWith('data:image/png;'));
    });

    test("one at a time: a second waits for the first, whose ratio reset would clear the canvas under it", () {
      page = _GlPage(framed: true);
      page.run('var first = null, second = null; handle.snapshot(2).then(function (d) { first = d; }); handle.snapshot(3).then(function (d) { second = d; });');
      page.pumpPromises();
      expect(page.takeCalls(), ['setPixelRatio 2'], reason: 'the second has not started');
      page.run("fakeMap.fire('idle'); fakeMap.fire('render')");
      page.pumpPromises();
      expect(page.run('first'), startsWith('data:image/png;ratio=2;'));
      expect(page.takeCalls(), ['setPixelRatio null', 'setPixelRatio 3']);
      page.run("fakeMap.fire('idle'); fakeMap.fire('render')");
      page.pumpPromises();
      expect(page.run('second'), startsWith('data:image/png;ratio=3;'));
    });

    test('of a map taken down under it fails at once, not when its timeout comes round', () {
      page = _GlPage(framed: true);
      start();
      page.run('handle.remove()');
      page.pumpPromises();
      expect(isMapSnapshotOutcome(page.run('failure')), isTrue, reason: 'an outcome the pane tells, not a fault it reports');
    });

    test('of a map that never settles fails, and gives the ratio back', () {
      page = _GlPage(framed: true);
      start();
      page.takeCalls();
      page.run('advance(30000)');
      page.pumpPromises();
      expect(page.run('failure'), contains('did not settle'));
      expect(page.takeCalls(), ['setPixelRatio null']);
    });
  });

  group('the overlay text', () {
    Qso contact(String uuid, int startAtMillis, {String band = '20m'}) =>
        Qso(uuid: uuid, operationUuid: 'op', data: {'uuid': uuid, 'startAtMillis': startAtMillis, 'band': band});

    testWidgets('counts contacts only, and spans the first to the last whatever the list order', (tester) async {
      late PostcardText text;
      final t0 = DateTime.utc(2026, 8, 22, 22, 14).millisecondsSinceEpoch;
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                text = PostcardText.of(context, const Operation(uuid: 'op', data: {'stationCall': 'AE4XO'}), [
                  contact('b', t0 + 56 * 60000 + 51000),
                  // An event marker is a row in the log, not a contact.
                  contact('e', t0 + 3 * 3600000, band: 'event'),
                  contact('a', t0),
                ]);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(text.stats, '2 QSOs in 56m 51s');
      expect(text.date, '22:14z Aug 22, 2026');
      expect(text.title, startsWith('AE4XO '));
    });
  });

  group('the pane', () {
    final operation = const Operation(uuid: 'op', data: {'stationCall': 'N0CALL'});
    const text = PostcardText(title: 'N0CALL at US-1234', subtitle: 'A Park', stats: '12 QSOs in 56m', date: '22:14z Aug 22, 2026');

    Future<SettingsService> freshSettings() async {
      SharedPreferences.setMockInitialValues({});
      return SettingsService(await SharedPreferences.getInstance());
    }

    /// What the pane asked the Map tab to build, latest last.
    final built = <({MapFrame frame, MapStyle style})>[];

    Future<void> pumpPanel(
      WidgetTester tester,
      SettingsService settings, {
      required bool mapIsFlutter,
      double width = 420,
      double height = 760,
      MapCameraView view = (camera: const MapCameraPosition(latitude: 40, longitude: -74, zoom: 5), viewport: const Size(800, 600), popup: null),
      bool globe = false,
      List<PostcardMarker> markers = const [],
      MapMarkerData? callout,
      void Function(MapZoomController controller)? attach,
    }) async {
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  height: height,
                  child: OperationPostcardPanel(
                    // A fresh State per pump: what it starts in must come from
                    // the settings, not from a State that survived.
                    key: UniqueKey(),
                    operation: operation,
                    text: text,
                    view: view,
                    markers: markers,
                    callout: callout,
                    globe: globe,
                    mapIsFlutter: mapIsFlutter,
                    mapBuilder: (frame, controller, style) {
                      built.add((frame: frame, style: style));
                      // What a live backend hooks up as it comes up: an OSM
                      // map that says at once it has all its tiles, unless
                      // the test hooks up something else.
                      (attach ?? (c) => c.onSettled ??= () async {})(controller);
                      return const ColoredBox(color: Colors.teal);
                    },
                    settings: settings,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    setUp(built.clear);

    /// Real time, a bounded while: inside [WidgetTester.runAsync], where the
    /// pane's renders run.
    Future<void> until(bool Function() done, String what) async {
      for (var i = 0; i < 1000 && !done(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      if (!done()) fail('never: $what');
    }

    /// Copy, pressed, and let run to its outcome, shown.
    Future<void> copyOnce(WidgetTester tester, {Duration settle = const Duration(milliseconds: 300)}) async {
      await tester.runAsync(() async {
        await tester.tap(find.text('Copy'));
        await Future<void>.delayed(settle);
      });
      await tester.pumpAndSettle();
    }

    void mockClipboard(WidgetTester tester, Future<Object?> Function(MethodCall call) handler) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('ham2k/image_clipboard'), handler);
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('ham2k/image_clipboard'), null));
    }

    testWidgets("an OSM picture waits for the map's tiles, rather than keeping one with holes in it", (tester) async {
      final copies = <Object?>[];
      mockClipboard(tester, (call) async => copies.add(call.arguments));
      // Made when the pane asks, in the real zone its render runs in: one
      // made in the test's fake zone would deliver only at the next pump.
      Completer<void>? tiles;
      await pumpPanel(tester, await freshSettings(), mapIsFlutter: true, attach: (c) => c.onSettled ??= () => (tiles = Completer<void>()).future);
      await tester.runAsync(() async {
        await tester.tap(find.text('Copy'));
        await until(() => tiles != null, 'asked whether the tiles were in');
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(copies, isEmpty, reason: 'the tiles are still on their way');
        tiles!.complete();
        await until(() => copies.isNotEmpty, 'copied once the tiles arrived');
      });
    });

    testWidgets('Copy pressed as the pane opens waits for its map to come up', (tester) async {
      final copies = <Object?>[];
      mockClipboard(tester, (call) async => copies.add(call.arguments));
      late MapZoomController map;
      await pumpPanel(tester, await freshSettings(), mapIsFlutter: true, attach: (c) => map = c);
      await tester.runAsync(() async {
        await tester.tap(find.text('Copy'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
        // The backend hooks itself up only now, as a map still loading does.
        map.onSettled = () async {};
        await until(() => copies.isNotEmpty, 'copied once the map came up');
      });
    });

    testWidgets("says what went wrong in the ordinary way without reporting it — and reports what didn't", (tester) async {
      final backend = FakeErrorReportingBackend();
      await withErrorHooks(backend: backend, () async {
        await pumpPanel(
          tester,
          await freshSettings(),
          mapIsFlutter: false,
          attach: (c) => c.onSnapshot = (_) async => throw const MapSnapshotException('offline'),
        );
        await copyOnce(tester);
        expect(find.text("The map didn't finish loading. Check the connection and try again."), findsOneWidget);

        mockClipboard(tester, (call) async => throw PlatformException(code: 'copy_failed', message: 'held by another app'));
        await pumpPanel(tester, await freshSettings(), mapIsFlutter: true);
        await copyOnce(tester);
        expect(find.text("The clipboard didn't take the image. Try again."), findsOneWidget);
        expect(backend.exceptions, isEmpty, reason: 'answers, not faults: a crash report per retry would bury the real ones');

        // Android's own refusal is an answer; a malformed request is ours.
        final saves = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('ham2k/file_save'), (call) async {
          saves.add(call.method);
          throw PlatformException(code: saves.length == 1 ? 'save_failed' : 'bad_args', message: 'no room');
        });
        addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('ham2k/file_save'), null));
        Future<void> save() async {
          await tester.runAsync(() async {
            await tester.tap(find.text('Save'));
            await Future<void>.delayed(const Duration(milliseconds: 300));
          });
          await tester.pumpAndSettle();
        }

        await pumpPanel(tester, await freshSettings(), mapIsFlutter: true);
        await save();
        expect(find.text('Could not save the postcard: no room'), findsOneWidget);
        expect(backend.exceptions, isEmpty);
        await save();
        expect(backend.exceptions, hasLength(1), reason: 'bad_args is this side asking wrongly');
        backend.exceptions.clear();

        // The control: a failure nobody planned for still goes up.
        await pumpPanel(tester, await freshSettings(), mapIsFlutter: false, attach: (c) => c.onSnapshot = (_) async => throw StateError('broken'));
        await copyOnce(tester);
        expect(find.textContaining('Could not make the postcard'), findsOneWidget);
        expect(backend.exceptions, isNotEmpty);
      });
    });

    testWidgets('work the operator walked away from is not reported when it fails', (tester) async {
      final backend = FakeErrorReportingBackend();
      await withErrorHooks(backend: backend, () async {
        // Made when the pane asks, in the real zone its render runs in.
        Completer<Uint8List>? snapshot;
        await pumpPanel(tester, await freshSettings(), mapIsFlutter: false, attach: (c) => c.onSnapshot = (_) => (snapshot = Completer<Uint8List>()).future);
        await tester.runAsync(() async {
          await tester.tap(find.text('Copy'));
          await until(() => snapshot != null, 'the snapshot was asked for');
        });
        // Done: the pane closes, and its map with it.
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() async {
          snapshot!.completeError(StateError('The WKWebView was invalidated'));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        expect(backend.exceptions, isEmpty);
      });
    });

    testWidgets('an OSM postcard is light whatever style was saved, having no picker to change it with', (tester) async {
      final settings = await freshSettings();
      await settings.setPostcardMapStyle(MapStyle.darkMatter);
      await pumpPanel(tester, settings, mapIsFlutter: true);
      expect(built.last.style, MapStyle.liberty);
      expect(tester.widget<PostcardOverlay>(find.byType(PostcardOverlay)).isDark, isFalse);
    });

    Future<List<Map<Object?, Object?>>> copyEach(WidgetTester tester, List<PostcardShape?> shapes) async {
      final copies = <Map<Object?, Object?>>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('ham2k/image_clipboard'), (call) async {
        copies.add(call.arguments as Map<Object?, Object?>);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('ham2k/image_clipboard'), null));

      // Drawn far smaller than the image: the size must come from the shape,
      // not from the preview.
      await pumpPanel(tester, await freshSettings(), mapIsFlutter: true);
      for (final shape in shapes) {
        if (shape != null) {
          await tester.tap(
            find.text(switch (shape) {
              PostcardShape.portrait => 'Portrait',
              PostcardShape.landscape => 'Landscape',
              PostcardShape.square => 'Square',
            }),
          );
          await tester.pumpAndSettle();
        }
        final before = copies.length;
        await tester.runAsync(() async {
          await tester.tap(find.text('Copy'));
          await until(() => copies.length > before, 'the copy reached the clipboard');
        });
        await tester.pumpAndSettle();
      }
      return copies;
    }

    (int, int) pngSize(Object? bytes) {
      final data = ByteData.sublistView(bytes! as Uint8List);
      return (data.getUint32(16), data.getUint32(20));
    }

    testWidgets('makes the chosen shape at twice its logical size, whatever the preview is drawn at', (tester) async {
      final copies = await copyEach(tester, [null, PostcardShape.landscape, PostcardShape.square]);
      // One render per shape: a cache keyed on anything less would hand the
      // portrait picture to a landscape copy.
      expect([for (final copy in copies) pngSize(copy['png'])], [(1080, 1920), (1920, 1080), (1440, 1440)]);
    });

    testWidgets('hands the clipboards that take bitmaps the raw pixels too', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        final copies = await copyEach(tester, [null]);
        expect(copies.single['width'], 1080);
        expect(copies.single['height'], 1920);
        expect((copies.single['rgba']! as Uint8List).length, 1080 * 1920 * 4);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets("starts in Liberty whatever the Map tab's style, then in the shape and style last picked here", (tester) async {
      final settings = await freshSettings();
      await settings.setMapStyle(MapStyle.voyager);
      await pumpPanel(tester, settings, mapIsFlutter: false);
      expect(built.last.style, MapStyle.liberty, reason: "a postcard's look is its own, not the tab's");
      expect(built.last.frame.width, 540, reason: 'portrait until the operator picks otherwise');

      await tester.tap(find.text('Landscape'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Liberty'));
      await tester.pumpAndSettle();
      // Automatic follows the app's dark mode, which a postcard does not.
      expect(find.text('Automatic'), findsNothing);
      await tester.tap(find.text('Dark Matter').last);
      await tester.pumpAndSettle();
      expect(built.last.style, MapStyle.darkMatter);

      built.clear();
      await pumpPanel(tester, settings, mapIsFlutter: false);
      expect(built.first.style, MapStyle.darkMatter);
      expect(built.first.frame.width, 960);
      // A postcard in Dark Matter is no reason for the operator to log over one.
      expect(settings.mapStyle, MapStyle.voyager);
    });

    testWidgets("frames a marker below the header as it measures it", (tester) async {
      final settings = await freshSettings();
      await settings.setPostcardShape('landscape');
      const camera = MapCameraPosition(latitude: 40, longitude: -74, zoom: 5);
      // 290 of the tab's 300 pixels above its center: in a landscape fitted to
      // the tab's height, under the header.
      final marker = (latitude: camera.atMercatorY(MapCameraPosition.mercatorY(40) - 290 / (512 * math.pow(2, 5))).latitude, longitude: -74.0);
      await pumpPanel(tester, settings, mapIsFlutter: false, view: (camera: camera, viewport: const Size(800, 600), popup: null), markers: [marker]);
      final framed = built.last.frame.camera;
      final y = (MapCameraPosition.mercatorY(marker.latitude) - MapCameraPosition.mercatorY(framed.latitude)) * 512 * math.pow(2, framed.zoom) + 540 / 2;
      final band = tester.getSize(find.descendant(of: find.byType(PostcardOverlay), matching: find.byType(ColoredBox)).first).height;
      expect(band, greaterThan(40), reason: 'the band in the overlay, measured in its own pixels');
      expect(y, greaterThanOrEqualTo(band));
    });

    testWidgets("draws the tab's open popup with its tip on the marker — when the tab showed the marker", (tester) async {
      const camera = MapCameraPosition(latitude: 40, longitude: -74, zoom: 5);
      MapMarkerData dot(double latitude) => MapMarkerData(
        id: 'q1',
        latitude: latitude,
        longitude: -74,
        label: 'EA4IDR',
        kind: MapMarkerKind.qso,
        color: Colors.green,
        strokeColor: Colors.black,
        popupTitle: 'EA4IDR • 5,765 km',
      );
      final shown = dot(40);
      await pumpPanel(
        tester,
        await freshSettings(),
        mapIsFlutter: false,
        view: (camera: camera, viewport: const Size(800, 600), popup: 'q1'),
        markers: [(latitude: 40, longitude: -74)],
        callout: shown,
      );
      final overlay = tester.widget<PostcardOverlay>(find.byType(PostcardOverlay));
      expect(overlay.callout, shown);
      expect(overlay.calloutAt, postcardPoint(built.last.frame.camera, (latitude: 40, longitude: -74), PostcardShape.portrait.logicalSize, tileSize: 512));
      expect(find.text('EA4IDR • 5,765 km'), findsOneWidget);

      // Its marker off the tab: the popup followed it off, and the operator
      // never saw it.
      final gone = dot(camera.atMercatorY(MapCameraPosition.mercatorY(40) - 2000 / (512 * math.pow(2, 5))).latitude);
      await pumpPanel(
        tester,
        await freshSettings(),
        mapIsFlutter: false,
        view: (camera: camera, viewport: const Size(800, 600), popup: 'q1'),
        markers: [(latitude: gone.latitude, longitude: -74)],
        callout: gone,
      );
      expect(find.text('EA4IDR • 5,765 km'), findsNothing);
    });

    testWidgets('keeps a flat map off the pole, and leaves a globe where it is', (tester) async {
      const north = (camera: MapCameraPosition(latitude: 80, longitude: 0, zoom: 3), viewport: Size(540, 820), popup: null);
      await pumpPanel(tester, await freshSettings(), mapIsFlutter: false, view: north);
      expect(built.last.frame.camera.latitude, lessThan(80), reason: 'slid south, off the edge of the flat world');
      built.clear();
      await pumpPanel(tester, await freshSettings(), mapIsFlutter: false, view: north, globe: true);
      // Around a globe is space, drawn on purpose; slid, the operator's
      // framing would move for nothing.
      expect(built.last.frame.camera.latitude, 80);
    });

    testWidgets('puts the style picker beside the shapes where both fit, and under them where not', (tester) async {
      Offset shapesAt() => tester.getCenter(find.byType(SegmentedButton<PostcardShape>));
      Offset styleAt() => tester.getCenter(find.byType(DropdownButtonFormField<MapStyle>));

      // The dialog on a large screen: 650 wide.
      await pumpPanel(tester, await freshSettings(), mapIsFlutter: false, width: 650);
      expect(styleAt().dx, greaterThan(shapesAt().dx));
      expect((styleAt().dy - shapesAt().dy).abs(), lessThan(Space.xl), reason: 'one row');

      // A phone.
      await pumpPanel(tester, await freshSettings(), mapIsFlutter: false, width: 375);
      expect(styleAt().dy, greaterThan(shapesAt().dy + Space.xl), reason: 'stacked');
    });

    testWidgets('fits its shape labels to a phone, one line each', (tester) async {
      await pumpPanel(tester, await freshSettings(), mapIsFlutter: false, width: 320);
      final label = tester.renderObject<RenderParagraph>(find.text('Landscape'));
      // Wrapped instead, the selector grows a line and the preview shrinks.
      expect(label.maxLines, 1);
      expect(label.didExceedMaxLines, isTrue, reason: 'too narrow for the whole word — so this is the case being tested');
    });
  });

  group("the postcard's framing", () {
    const camera = MapCameraPosition(latitude: 40, longitude: -74, zoom: 5);
    double zoomFor(PostcardShape shape, Size viewport) =>
        postcardCamera((camera: camera, viewport: viewport, popup: null), shape.logicalSize, tileSize: 512).zoom;
    double log2(double x) => math.log(x) / math.ln2;

    /// How far below the Web Mercator world's top edge the image's top edge
    /// falls, in logical pixels — negative is blank above the pole.
    double topEdge(MapCameraPosition framed, PostcardShape shape) =>
        MapCameraPosition.mercatorY(framed.latitude) * 512 * math.pow(2, framed.zoom) - shape.logicalSize.height / 2;

    test("a portrait postcard from a wide tab spans the tab's width", () {
      expect(zoomFor(PostcardShape.portrait, const Size(800, 600)), closeTo(5 + log2(540 / 800), 1e-9));
    });

    test("from a phone's tall tab, it spans the tab's height — the header takes no room of its own", () {
      expect(zoomFor(PostcardShape.portrait, const Size(375, 800)), closeTo(5 + log2(960 / 800), 1e-9));
    });

    test('a landscape one spans the height', () {
      expect(zoomFor(PostcardShape.landscape, const Size(800, 600)), closeTo(5 + log2(540 / 600), 1e-9));
    });

    test("a square one is cut from the tab: the tab's shorter side spans its width", () {
      expect(zoomFor(PostcardShape.square, const Size(800, 600)), closeTo(5 + log2(720 / 600), 1e-9));
      expect(zoomFor(PostcardShape.square, const Size(400, 900)), closeTo(5 + log2(720 / 400), 1e-9));
    });

    test("keeps the tab's center", () {
      final framed = postcardCamera((camera: camera, viewport: const Size(800, 600), popup: null), PostcardShape.portrait.logicalSize, tileSize: 512);
      expect((framed.latitude, framed.longitude), (40, -74));
    });

    test('never reaches past the pole: the image ends where the world does, not in a blank strip', () {
      const north = MapCameraPosition(latitude: 80, longitude: 0, zoom: 3);
      const view = (camera: north, viewport: Size(540, 960), popup: null);
      final fitted = postcardCamera(view, PostcardShape.portrait.logicalSize, tileSize: 512, withinWorld: false);
      expect(topEdge(fitted, PostcardShape.portrait), lessThan(0), reason: 'the case being tested');
      final kept = postcardCamera(view, PostcardShape.portrait.logicalSize, tileSize: 512);
      expect(topEdge(kept, PostcardShape.portrait), closeTo(0, 1e-6));
      expect(kept.zoom, fitted.zoom, reason: 'slid, not zoomed');
    });

    /// Where [latitude] shows down the image, in logical pixels from its top.
    double frameY(MapCameraPosition framed, double latitude, PostcardShape shape) =>
        (MapCameraPosition.mercatorY(latitude) - MapCameraPosition.mercatorY(framed.latitude)) * 512 * math.pow(2, framed.zoom) + shape.logicalSize.height / 2;

    /// The latitude [pixels] logical pixels north of [camera]'s center on its map.
    double north(MapCameraPosition camera, double pixels) =>
        camera.atMercatorY(MapCameraPosition.mercatorY(camera.latitude) - pixels / (512 * math.pow(2, camera.zoom))).latitude;

    test("a square that would crop markers off both ends of the tab's long side zooms out just enough to keep them", () {
      const view = (camera: camera, viewport: Size(400, 900), popup: null);
      final top = (latitude: north(camera, 400), longitude: -74.0);
      final bottom = (latitude: north(camera, -400), longitude: -74.0);
      final cropped = postcardCamera(view, PostcardShape.square.logicalSize, tileSize: 512, header: 100);
      expect(frameY(cropped, top.latitude, PostcardShape.square), lessThan(0), reason: 'the case being tested');
      final kept = postcardCamera(view, PostcardShape.square.logicalSize, tileSize: 512, header: 100, markers: [top, bottom]);
      // Both clear — the top one of the header — and not a pixel further out.
      expect(frameY(kept, top.latitude, PostcardShape.square), closeTo(100 + postcardMarkerMargin, 1e-6));
      expect(frameY(kept, bottom.latitude, PostcardShape.square), closeTo(720 - postcardMarkerMargin, 1e-6));
    });

    test("one marker off the square's edge is panned in, not zoomed out for", () {
      const view = (camera: camera, viewport: Size(400, 900), popup: null);
      final top = (latitude: north(camera, 400), longitude: -74.0);
      final kept = postcardCamera(view, PostcardShape.square.logicalSize, tileSize: 512, header: 100, markers: [top]);
      expect(frameY(kept, top.latitude, PostcardShape.square), closeTo(100 + postcardMarkerMargin, 1e-6));
      expect(kept.zoom, closeTo(5 + log2(720 / 400), 1e-9));
    });

    test("half a dot at the tab's edge counts as shown", () {
      const view = (camera: camera, viewport: Size(400, 900), popup: null);
      // Its center 6 pixels past the tab's top edge; its dot still over it.
      final edge = (latitude: north(camera, 456), longitude: -74.0);
      final kept = postcardCamera(view, PostcardShape.square.logicalSize, tileSize: 512, header: 100, markers: [edge]);
      expect(frameY(kept, edge.latitude, PostcardShape.square), closeTo(100 + postcardMarkerMargin, 1e-6));
    });

    test("keeps the tab's open popup whole and clear of the header, not just its dot", () {
      const view = (camera: camera, viewport: Size(800, 600), popup: null);
      final marker = (latitude: north(camera, 250), longitude: -74.0);
      const card = Size(200, 60);
      final framed = postcardCamera(
        view,
        PostcardShape.landscape.logicalSize,
        tileSize: 512,
        header: 140,
        markers: [marker],
        callout: (at: marker, size: card),
      );
      final at = postcardPoint(framed, marker, PostcardShape.landscape.logicalSize, tileSize: 512);
      expect(at.dy - postcardCalloutGap - card.height, closeTo(140, 1e-6), reason: 'the card, not the dot, is what the header must clear');
      expect(framed.zoom, closeTo(5 + log2(540 / 600), 1e-9), reason: 'one popup: panned, not zoomed out for');
    });

    test("reckons what the tab showed with the tab's rotation, and comes out north-up", () {
      final east = (latitude: 40.0, longitude: -74 + 350 / (512 * math.pow(2, 5)) * 360);
      final turned = const MapCameraPosition(latitude: 40, longitude: -74, zoom: 5, bearing: 90);
      // East at the top: 350 pixels up a tab 400 tall is off it.
      final framed = postcardCamera(
        (camera: turned, viewport: const Size(800, 400), popup: null),
        PostcardShape.square.logicalSize,
        tileSize: 512,
        markers: [east],
      );
      expect(framed.longitude, -74, reason: 'not panned toward a marker the tab did not show');
      expect((framed.bearing, framed.pitch), (0, 0));
      // Unturned, the same marker was on the tab, and is kept.
      final flat = postcardCamera(
        (camera: camera, viewport: const Size(800, 400), popup: null),
        PostcardShape.square.logicalSize,
        tileSize: 512,
        markers: [east],
      );
      expect(flat.longitude, greaterThan(-74));
    });

    test('a marker the tab did not show does not pull the postcard out', () {
      final offScreen = (latitude: north(camera, 1000), longitude: -74.0);
      final framed = postcardCamera(
        (camera: camera, viewport: const Size(400, 900), popup: null),
        PostcardShape.square.logicalSize,
        tileSize: 512,
        markers: [offScreen],
      );
      expect(framed.zoom, closeTo(5 + log2(720 / 400), 1e-9));
      expect((framed.latitude, framed.longitude), (40, -74), reason: 'not panned toward it either');
    });

    test('a lone marker under the header is panned below it, not zoomed out for', () {
      const view = (camera: camera, viewport: Size(800, 600), popup: null);
      final marker = (latitude: north(camera, 290), longitude: -74.0);
      final framed = postcardCamera(view, PostcardShape.landscape.logicalSize, tileSize: 512, header: 140, markers: [marker]);
      expect(frameY(framed, marker.latitude, PostcardShape.landscape), closeTo(140 + postcardMarkerMargin, 1e-6));
      expect(framed.zoom, closeTo(5 + log2(540 / 600), 1e-9));
    });

    test('a whole-world portrait too narrow for its markers centers on them, still without a blank', () {
      const whole = MapCameraPosition(latitude: 10, longitude: 0, zoom: 0.577);
      final framed = postcardCamera(
        (camera: whole, viewport: const Size(503, 764), popup: null),
        PostcardShape.portrait.logicalSize,
        tileSize: 512,
        markers: [(latitude: 34, longitude: -118), (latitude: -32, longitude: 115)],
      );
      expect(512 * math.pow(2, framed.zoom), closeTo(960, 1e-6));
      expect(framed.longitude, closeTo(-1.5, 1e-6));
    });

    test('zooms in rather than leave the world shorter than the image', () {
      const whole = MapCameraPosition(latitude: 0, longitude: 0, zoom: 0.5);
      final kept = postcardCamera((camera: whole, viewport: const Size(400, 900), popup: null), PostcardShape.portrait.logicalSize, tileSize: 512);
      expect(512 * math.pow(2, kept.zoom), greaterThanOrEqualTo(960 - 1e-6));
      expect(topEdge(kept, PostcardShape.portrait), greaterThanOrEqualTo(-1e-6));
    });
  });

  group("the Map tab's contacts, redrawn for a postcard of the other tone", () {
    const lightRing = Color(0xFF1A1A1A);
    const darkRing = Color(0xFFF2F2F2);
    const lightLine = Color(0x99000000);
    const darkLine = Color(0x99FFFFFF);
    const band = Color(0xFF00AA00);

    MapMarkerData marker(String id, MapMarkerKind kind, Color stroke) =>
        MapMarkerData(id: id, latitude: 40, longitude: -74, label: id, kind: kind, color: band, strokeColor: stroke);

    test('swap the lines and the rings, and keep the band fills and the QTH ring', () {
      final retoned = retonedMapData(
        [marker('q1', MapMarkerKind.qso, lightRing), marker('qth', MapMarkerKind.qth, Colors.white)],
        [MapLineData(id: 'q1/0', points: const [], color: lightLine)],
        toDark: true,
      );
      expect([for (final m in retoned.markers) m.strokeColor], [darkRing, Colors.white]);
      expect([for (final m in retoned.markers) m.color], [band, band]);
      expect(retoned.lines.single.color, darkLine, reason: 'a dark line on a dark basemap is not there at all');

      final back = retonedMapData(retoned.markers, retoned.lines, toDark: false);
      expect(back.markers.first.strokeColor, lightRing);
      expect(back.lines.single.color, lightLine);
    });
  });
}

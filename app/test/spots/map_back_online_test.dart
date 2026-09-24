// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Neither map library retries what failed while the device was offline:
// MapLibre keeps a style it could not fetch as never loaded, flutter_map keeps
// a failed tile as failed. So a map opened offline stays blank however long
// the connection has been back, unless coming online reaches it.
//
// The GL half runs the real map_gl_script.dart in QuickJS against a fake
// MapLibre that records the setStyle and refreshTiles calls the script makes.
// A fake cannot show that MapLibre refetches as asked, so this pins the
// script's decisions, not the library's behaviour.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_quickjs/halo_quickjs.dart';
import 'package:http/http.dart' as http;
import 'package:ham2k_logger/services/connectivity_service.dart';
import 'package:ham2k_logger/services/map_error_reporter.dart';
import 'package:ham2k_logger/views/map/map_gl_script.dart' show mapDefaultStyleUrl, mapDefaultStyleUrlDark, mapGlScript;
import 'package:ham2k_logger/views/map/map_marker_data.dart';
import 'package:ham2k_logger/views/map/mapbox_webview_map_view.dart';
import 'package:ham2k_logger/views/map/osm_map_view.dart';

import '../support/map_tile_cache.dart';

/// Just enough of a browser and of MapLibre for `create` to run: timers on a
/// clock the test advances, `window` events, and a map whose style, errors
/// and source caches the test drives. Every call the script makes that
/// matters here lands in `calls`.
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
var windowListeners = {};
window.addEventListener = function (type, fn) { (windowListeners[type] = windowListeners[type] || []).push(fn); };
window.removeEventListener = function (type, fn) { windowListeners[type] = (windowListeners[type] || []).filter(function (f) { return f !== fn; }); };
function dispatch(type) { (windowListeners[type] || []).slice().forEach(function (fn) { fn({ type: type }); }); }
function ResizeObserver() {}
ResizeObserver.prototype.observe = function () {};
ResizeObserver.prototype.disconnect = function () {};

function AJAXError(status) { this.status = status; this.message = 'AJAXError (' + status + ')'; }
function SourceCache(id) { this.id = id; }
function FakeMap() {
  var listeners = {};
  this.style = { sourceCaches: {} };
  this.on = function (type, fn) { (listeners[type] = listeners[type] || []).push({ fn: fn }); };
  this.once = function (type, fn) { (listeners[type] = listeners[type] || []).push({ fn: fn, once: true }); };
  this.fire = function (type, e) {
    var ls = listeners[type] || [];
    listeners[type] = ls.filter(function (l) { return !l.once; });
    ls.forEach(function (l) { l.fn(e); });
  };
  // Like MapLibre, a new style starts with none of the old one's sources.
  this.setStyle = function (url) { calls.push('setStyle ' + url); this.style.sourceCaches = {}; };
  this.getSource = function (id) { return this.style.sourceCaches[id]; };
  this.refreshTiles = function (id, tiles) {
    calls.push('refresh ' + id + ' ' + tiles.map(function (t) { return t.z + '/' + t.x + '/' + t.y; }).join(','));
  };
  this.remove = function () {};
  window.fakeMap = this;
}
var maplibregl = { Map: FakeMap, AJAXError: AJAXError };

// The three shapes an unanswered request arrives in: the stylesheet or the
// sprite (neither source nor tile), a source's TileJSON (source, no tile), a
// tile (both).
function unanswered() { fakeMap.fire('error', { error: new AJAXError(0) }); }
function unansweredSource(id) { fakeMap.fire('error', { error: new AJAXError(0), sourceId: id }); }
function unansweredTile(id, z, x, y) {
  fakeMap.fire('error', { error: new AJAXError(0), sourceId: id, tile: { tileID: { canonical: { z: z, x: x, y: y } } } });
}
function loadStyle(sources) {
  fakeMap.style.sourceCaches = {};
  sources.forEach(function (id) { fakeMap.style.sourceCaches[id] = new SourceCache(id); });
  fakeMap.fire('style.load');
}
''';

class _GlPage {
  final _js = HaloQuickJs();

  _GlPage({bool dark = false}) {
    run(_fakeBrowser);
    run(mapGlScript);
    run("var handle = window.poloMapGl.create({}, 'light-style', 'dark-style', $dark, function () {}, false);");
  }

  String run(String code) {
    final result = _js.eval(code);
    if (!result.ok) fail('JS threw: ${result.text}');
    return result.text;
  }

  /// What the script asked of the map, since the last read.
  List<String> takeCalls() => (jsonDecode(run('var c = JSON.stringify(calls); calls = []; c')) as List).cast<String>();

  void dispose() => _js.dispose();
}

class _UnreachableHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => Future.error(const SocketException('Network is unreachable'));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Unreachable extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _UnreachableHttpClient();
}

final _marker = MapMarkerData(id: 'q1', latitude: 40, longitude: -74, label: 'W1AW', kind: MapMarkerKind.qso, color: Colors.red, strokeColor: Colors.black);

void main() {
  group('GL script', () {
    late _GlPage page;
    tearDown(() => page.dispose());

    test('a map opened offline asks for its style again once back online', () {
      page = _GlPage();
      page.run('unanswered()');
      page.run("dispatch('online'); advance(1999)");
      expect(page.takeCalls(), isEmpty, reason: 'a route appearing is not yet DNS; a reload sent into that gap fails and spends the signal');
      page.run('advance(1)');
      expect(page.takeCalls(), ['setStyle light-style']);
    });

    test('the refetched style is the tone the map was opened in', () {
      page = _GlPage(dark: true);
      page.run('unanswered()');
      page.run("dispatch('online'); advance(2000)");
      expect(page.takeCalls(), ['setStyle dark-style']);
    });

    test('a loaded map refetches only the tiles that failed, and keeps its style', () {
      page = _GlPage();
      page.run("loadStyle(['openmaptiles', 'polo-markers'])");
      page.run("unansweredTile('openmaptiles', 5, 9, 12); unansweredTile('openmaptiles', 5, 9, 12); unansweredTile('openmaptiles', 5, 10, 12)");
      page.run('handle.reload(); advance(2000)');
      // A style reload tears the style on screen down before its fetch; on a
      // network that raises 'online' and answers nothing, that blanks a map
      // that was only missing tiles.
      expect(page.takeCalls(), ['refresh openmaptiles 5/9/12,5/10/12']);
    });

    test('a loaded style missing a part is reloaded — a tile refetch cannot bring it back', () {
      page = _GlPage();
      page.run("loadStyle(['openmaptiles'])");
      // The TileJSON: without it the source has no tiles to refetch, so a
      // tile refresh would clear the failure and leave the basemap blank.
      page.run("unansweredSource('openmaptiles')");
      page.run('handle.reload(); advance(2000)');
      expect(page.takeCalls(), ['setStyle light-style']);
    });

    test('a map with nothing unanswered is left alone', () {
      page = _GlPage();
      page.run("loadStyle(['openmaptiles'])");
      page.run("dispatch('online'); handle.reload(); advance(5000)");
      expect(page.takeCalls(), isEmpty, reason: 'two signals per return online; each would otherwise refetch a healthy map');
    });

    test('an error a reload cannot fix does not arm one', () {
      page = _GlPage();
      page.run("loadStyle(['openmaptiles'])");
      page.run("fakeMap.fire('error', { error: new AJAXError(404) })");
      page.run("fakeMap.fire('error', { error: new Error('layer failed to evaluate') })");
      page.run("dispatch('online'); advance(5000)");
      expect(page.takeCalls(), isEmpty);
    });

    test('each signal restarts the wait, so the later one is what the reload waits behind', () {
      page = _GlPage();
      page.run('unanswered()');
      page.run("dispatch('online'); advance(1000); handle.reload(); advance(1999)");
      expect(page.takeCalls(), isEmpty, reason: "the page's event can fire before DNS; a reload timed from it fails and spends the app's verified edge too");
      page.run('advance(1)');
      expect(page.takeCalls(), ['setStyle light-style']);
    });

    test('a reload that fails again is re-armed for the next signal', () {
      page = _GlPage();
      page.run('unanswered()');
      page.run("dispatch('online'); advance(2000)");
      expect(page.takeCalls(), ['setStyle light-style']);
      page.run('unanswered()');
      page.run('handle.reload(); advance(2000)');
      expect(page.takeCalls(), ['setStyle light-style']);
    });

    test("a style swap drops the replaced style's failures", () {
      page = _GlPage();
      page.run("loadStyle(['openmaptiles'])");
      page.run("unansweredSource('openmaptiles'); unansweredTile('openmaptiles', 5, 9, 12)");
      page.run('handle.setDark(true)');
      expect(page.takeCalls(), ['setStyle dark-style']);
      page.run("dispatch('online'); advance(5000)");
      // The swap is already fetching the style that will be on screen; asking
      // again aborts that fetch and starts it over.
      expect(page.takeCalls(), isEmpty);
    });

    test('going offline again during the wait cancels the reload', () {
      page = _GlPage();
      page.run("loadStyle(['openmaptiles'])");
      page.run("unansweredSource('openmaptiles')");
      // A style reload tears down the style on screen, and offline its
      // replacement cannot come: an unfinished map would be left blank.
      page.run("dispatch('online'); advance(1000); dispatch('offline'); advance(5000)");
      expect(page.takeCalls(), isEmpty, reason: "the page's own 'offline' event");
      page.run('handle.reload(); advance(1000); handle.cancelReload(); advance(5000)');
      expect(page.takeCalls(), isEmpty, reason: "the app's offline edge");
      page.run("dispatch('online'); advance(2000)");
      expect(page.takeCalls(), ['setStyle light-style'], reason: 'what went unanswered is still owed a reload once the network is back');
    });

    test('a removed map stops listening', () {
      page = _GlPage();
      page.run('unanswered()');
      page.run("handle.remove(); dispatch('online'); advance(5000)");
      expect(page.takeCalls(), isEmpty);
    });
  });

  test('the webview page exposes the reload its online edge calls', () {
    final page = MapboxWebviewMapView.pageHtml(false, mapDefaultStyleUrl, mapDefaultStyleUrlDark, false, suppressWindowBlur: false, glSource: '', glCss: '');
    // The Dart side guards the call, so a page that lost this binding would
    // swallow every edge silently and the map opened offline stays blank.
    expect(page, contains('window.poloReload = handle.reload;'));
    expect(page, contains('window.poloCancelReload = handle.cancelReload;'));
  });

  group('OSM', () {
    useTempMapTileCache();
    tearDown(ConnectivityService.resetForTesting);
    // Tiles share their URLs across these tests, and a failure left in the
    // image cache is handed to the next map at once — before tilesFailed is
    // listening for it.
    setUp(() {
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
    });

    Widget host() => MaterialApp(
      home: Scaffold(body: OsmMapView(markers: [_marker], isDark: false)),
    );

    /// Every tile request fails to connect, the way it does with no network.
    /// The test binding's own client ANSWERS every request (400), which is
    /// the other case.
    void unreachable() {
      final previous = HttpOverrides.current;
      HttpOverrides.global = _Unreachable();
      addTearDown(() => HttpOverrides.global = previous);
    }

    Future<StreamController<List<ConnectivityResult>>> startOffline(WidgetTester tester) async {
      final results = StreamController<List<ConnectivityResult>>();
      ConnectivityService.start(changesSource: results.stream, check: () async => [ConnectivityResult.none]);
      await tester.pump();
      expect(ConnectivityService.isOffline, isTrue, reason: 'without the offline state there is no edge, and the test proves nothing');
      return results;
    }

    /// Waits until the tiles have failed. They run on real I/O, which the
    /// fake clock never waits for, and the test binding's own client answers
    /// on a fake-clock timer, so each round gives both a turn. Seen through MapErrorReporter's debug line
    /// for a repeated failure — every tile fails with the same message — so a
    /// test whose tiles never fail says so, rather than passing on an edge
    /// that had nothing to act on.
    Future<void> tilesFailed(WidgetTester tester) async {
      MapErrorReporter.resetForTesting();
      var failures = 0;
      final print = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null && message.startsWith('[map-osm] repeat:')) failures++;
      };
      try {
        for (var i = 0; i < 50 && failures == 0; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          await tester.pump(const Duration(milliseconds: 20));
        }
      } finally {
        debugPrint = print;
      }
      expect(failures, isPositive, reason: 'no tile failed, so the edge below has nothing to decide on');
    }

    Future<int Function()> countResets(WidgetTester tester) async {
      var resets = 0;
      final sub = tester.widget<TileLayer>(find.byType(TileLayer)).reset!.listen((_) => resets++);
      addTearDown(sub.cancel);
      return () => resets;
    }

    testWidgets('tiles that went unanswered reload once the app is back online, after the delay', (tester) async {
      unreachable();
      // Each tile that fails to connect is also reported by the image cache;
      // here those are the point, not a fault. Anything else still fails the
      // test.
      final onError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exception is! http.ClientException) onError?.call(details);
      };
      addTearDown(() => FlutterError.onError = onError);
      final results = await startOffline(tester);
      await tester.pumpWidget(host());
      final resets = await countResets(tester);
      await tilesFailed(tester);

      results.add([ConnectivityResult.wifi]);
      await tester.pump();
      expect(ConnectivityService.isOffline, isFalse);
      await tester.pump(OsmMapView.backOnlineDelay - const Duration(milliseconds: 1));
      expect(resets(), 0, reason: 'the edge can come before DNS answers; a reset into that gap fails every tile again');
      await tester.pump(const Duration(milliseconds: 1));
      expect(resets(), 1);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('tiles the server answered with an error are not reset', (tester) async {
      final results = await startOffline(tester);
      await tester.pumpWidget(host());
      final resets = await countResets(tester);
      await tilesFailed(tester);

      results.add([ConnectivityResult.wifi]);
      await tester.pump();
      expect(ConnectivityService.isOffline, isFalse);
      await tester.pump(OsmMapView.backOnlineDelay * 2);
      expect(resets(), 0, reason: 'a 404 or a 429 is no better after a reset, which drops every tile first and flashes a healthy map grey');

      await tester.pumpWidget(const SizedBox());
    });
  });
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The browser-engine side of the map — MapLibre GL JS — shared by the two
// backends that run it in a real browser engine: the webview
// (mapbox_webview_map_view.dart, which wraps this in its own HTML page) and
// Flutter web (mapbox_web_map_view.dart, which injects it into the app's own
// page and drives it through js_interop). One copy of the marker/line/popup/
// projection logic, so the two can't drift apart.
//
// Exposes `window.poloMapGl.create(container, style, styleDark, initialDark,
// onEvent, notifyClicks, frame)` returning a handle with `setMarkersJson`,
// `setLinesJson`, `setShapesJson`, `setOverlaysJson`, `setGraylineJson`, `setCreditLabelsJson`, `patchMarkersJson`, `patchLinesJson`,
// `setCreditsSide`, `setProjection`, `moveTo`, `fitToJson`, `refit`, `resetNorth`, `camera`, `snapshot`, `reload`/`cancelReload`
// (the host's word that the app is back online, or offline again), and
// `remove`. Data crosses as JSON strings —
// both callers already have the payload serialized, and strings keep the
// interop layer trivial on each side. A patch (`{upsert, removeIds}`, see
// `mapLinesPatchPayload`) is what a caller sends when a few of thousands of
// entries changed: the script keeps the last set and merges into it, so one
// logged contact costs one feature over the bridge rather than every contact's.
//
// `notifyClicks` (default false) is for a caller that wants to render its
// own reveal/action UI in Flutter instead of this script's built-in HTML
// popup: a marker click reports through `onEvent('marker-click', id)`
// rather than opening `showPopup`. The QSO map never sets it, so its popup
// behavior is unchanged.
//
// `frame` (default null) makes a picture rather than a map to explore — the
// Operation Postcard's (see MapFrame). The map is laid out at the frame's own
// logical size whatever the container's, and CSS-scaled to fit it, so the
// labels and the extent are the picture's and not the preview's: `snapshot`
// then renders that same layout at a higher pixel ratio. It holds the
// frame's camera — no gestures, no fit to the markers — and draws no
// attribution control, which the host lays over the picture itself.
//
// `onEvent(kind, message)` is the host's error channel: every failure this
// script can observe goes through it, so each backend can route into
// ErrorPolicy (via MapErrorReporter) instead of a console nobody reads in a
// release build. Kinds: 'gl-error' (the map's own error event),
// 'style-timeout' (the pending-payload watchdog — the "map stays blank"
// signal, and the ONLY kind here that means the operator has no map, so it
// is the one the backends also surface as their empty state),
// 'style-swap-timeout' (a swap that never completed, leaving the PREVIOUS
// style up with the data restored onto it — evidence, but the operator still
// has a working map, so it must never raise that empty state),
// 'recovered' (a payload applied after a style-timeout: not an error, it
// clears the empty state), 'deferred-update' and 'marker-drift'. Without a
// callback the script falls back to the console, which is where a bare
// devtools session still looks.

import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../services/settings_service.dart' show MapStyle;
import 'map_gl_camera_script.dart';
import 'map_gl_layers_script.dart';
import 'map_gl_overlays_script.dart';
import 'map_gl_pill_script.dart';
import 'map_gl_snapshot_script.dart';
import 'map_gl_spread_script.dart';
import 'map_marker_data.dart' show mapDimmedOpacity;
import 'map_zoom_controller.dart' show MapZoomController, mapSnapshotRemovedMessage;

/// MapLibre GL JS itself — needs no access token, unlike the commercial GL
/// libraries — vendored under `app/assets/maplibre/` rather than fetched from
/// a CDN. The library is a fixed, version-pinned asset, and the Map tab must
/// draw for an operator in a park with no signal; only the tiles and the
/// style genuinely need the network. Bundled, the first map draw also skips
/// about a megabyte of transfer that the pane's ready deadline was racing.
///
/// Update by replacing both files and `LICENSE.txt` beside them, from
/// `https://unpkg.com/maplibre-gl@<version>/dist/`.
const mapGlVersion = '5.6.0';
const mapGlScriptAsset = 'assets/maplibre/maplibre-gl.js';
const mapGlCssAsset = 'assets/maplibre/maplibre-gl.css';

/// The vendored library, read once by [preloadMapGlLibrary] and then read
/// synchronously by every page build.
///
/// Synchronous on purpose. Gating the web view's creation on an asset read
/// makes the map pane unbuildable under `testWidgets`, where fakeAsync never
/// advances real file I/O — so the page would wait forever for a library that
/// is sitting on disk. Empty until the preload lands: the host page reports
/// its own 'page-error' in that window, the same way it would for any missing
/// library, rather than the pane hanging.
String _glLibrarySource = '';
String _glLibraryCss = '';

String get mapGlLibrarySource => _glLibrarySource;
String get mapGlLibraryCss => _glLibraryCss;

/// Reads the vendored library into memory. Called once during startup, before
/// the Map tab can be opened; idempotent, so a second call costs nothing.
Future<void> preloadMapGlLibrary() async {
  if (_glLibrarySource.isNotEmpty) return;
  final source = await rootBundle.loadString(mapGlScriptAsset);
  final css = await rootBundle.loadString(mapGlCssAsset);
  _glLibrarySource = source;
  _glLibraryCss = css;
}

/// Stands in for the preload, for tests that need a page with a library in it
/// without waiting on I/O that a widget test cannot drive.
@visibleForTesting
void setMapGlLibraryForTests({required String source, required String css}) {
  _glLibrarySource = source;
  _glLibraryCss = css;
}

/// The automatic light/dark basemap — OpenFreeMap for light, since it ships
/// no dark style of its own, and CARTO's Dark Matter (also tokenless) for
/// dark. Used whenever [SettingsService.mapStyle] is [MapStyle.automatic];
/// a pinned style repoints both slots at [mapLibreStyleUrl] instead.
const mapDefaultStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';
const mapDefaultStyleUrlDark = 'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json';

/// A pinned MapLibre basemap's style URL — every option free and tokenless,
/// from the same two providers the automatic light/dark default already
/// uses (OpenFreeMap for the light-toned ones, CARTO for Voyager, which
/// OpenFreeMap doesn't have). Callers only reach this for a non-[MapStyle.automatic]
/// pick — automatic keeps using [mapDefaultStyleUrl]/[mapDefaultStyleUrlDark].
String mapLibreStyleUrl(MapStyle style) => switch (style) {
  MapStyle.automatic => mapDefaultStyleUrl,
  MapStyle.liberty => 'https://tiles.openfreemap.org/styles/liberty',
  MapStyle.bright => 'https://tiles.openfreemap.org/styles/bright',
  MapStyle.positron => 'https://tiles.openfreemap.org/styles/positron',
  MapStyle.voyager => 'https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json',
  MapStyle.darkMatter => mapDefaultStyleUrlDark,
};

/// The light and dark style URLs the GL backends are handed for [style]. A
/// pinned style fills both slots with itself, so the light/dark machinery in
/// the backends never has a reason to swap it.
({String light, String dark}) mapLibreStyleUrls(MapStyle style) =>
    style == MapStyle.automatic ? (light: mapDefaultStyleUrl, dark: mapDefaultStyleUrlDark) : (light: mapLibreStyleUrl(style), dark: mapLibreStyleUrl(style));

/// Whether the basemap actually on screen is dark-toned. Marker fills,
/// strokes and great-circle lines contrast against the TILES, not against
/// the app's chrome, so a pinned style carries its own tone whatever the
/// app's theme is doing; only [MapStyle.automatic] follows [appIsDark],
/// because that's the one pick whose tiles do.
bool mapStyleIsDark(MapStyle style, {required bool appIsDark}) => switch (style) {
  MapStyle.automatic => appIsDark,
  MapStyle.darkMatter => true,
  MapStyle.liberty || MapStyle.bright || MapStyle.positron || MapStyle.voyager => false,
};

/// A dark, starry backdrop for the MapLibre container div — CSS rather than
/// a GL style property, since MapLibre's globe has no style-level fog
/// property to paint what's beyond the sphere (see applySky in mapGlScript).
/// Shows through wherever the canvas itself is transparent, which is
/// everywhere the globe doesn't cover once it's zoomed out enough to see
/// past its edge. Harmless the rest of the time: mercator, and a
/// fully-zoomed-in globe, cover the whole canvas with map tiles and never
/// expose it. A fixed seed keeps the scatter stable across rebuilds instead
/// of jumping every time a map is created.
String mapLibreSpaceBackgroundCss() {
  final stars = _spaceStars()
      .map(
        (s) =>
            'radial-gradient(${s.size.toStringAsFixed(2)}px ${s.size.toStringAsFixed(2)}px at ${s.x.toStringAsFixed(2)}% '
            '${s.y.toStringAsFixed(2)}%, rgba(255, 255, 255, ${s.opacity.toStringAsFixed(2)}), transparent)',
      )
      .join(', ');
  return '$stars, linear-gradient(180deg, #0b0f1a 0%, #0d1526 100%)';
}

// The CSS gradient's two ends, for [paintMapSpaceBackground].
const _spaceTop = Color(0xFF0B0F1A);
const _spaceBottom = Color(0xFF0D1526);

/// Positions in percent of the backdrop, sizes in logical pixels.
List<({double x, double y, double size, double opacity})> _spaceStars() {
  final random = Random(1);
  return List.generate(80, (_) {
    final x = random.nextDouble() * 100;
    final y = random.nextDouble() * 100;
    final size = 0.5 + random.nextDouble() * 1.2;
    final opacity = 0.3 + random.nextDouble() * 0.6;
    return (x: x, y: y, size: size, opacity: opacity);
  });
}

/// [mapLibreSpaceBackgroundCss] painted onto a canvas [size] physical pixels
/// big, at [pixelRatio] physical pixels per logical one — what a snapshot of
/// a framed map is laid over, since the canvas it comes from is transparent
/// wherever the globe leaves space showing and the CSS backdrop is not in it.
void paintMapSpaceBackground(Canvas canvas, Size size, {required double pixelRatio}) {
  final rect = Offset.zero & size;
  canvas.drawRect(
    rect,
    Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_spaceTop, _spaceBottom]).createShader(rect),
  );
  for (final star in _spaceStars()) {
    final center = Offset(star.x / 100 * size.width, star.y / 100 * size.height);
    final radius = star.size * pixelRatio;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFFFFF).withValues(alpha: star.opacity),
            const Color(0x00FFFFFF),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }
}

/// The credit a picture of the map owes for the style at [styleUrl] — what
/// the GL library's own attribution control would show, which a framed map
/// does not draw (see `frame` in [mapGlScript]). Every style
/// [mapLibreStyleUrl] can name is OpenStreetMap data served by one of two
/// providers.
String mapGlAttribution(String styleUrl) {
  if (Uri.tryParse(styleUrl)?.host.endsWith('cartocdn.com') ?? false) return '© CARTO © OpenStreetMap contributors';
  return '© OpenFreeMap © OpenMapTiles © OpenStreetMap contributors';
}

/// JS that defines `window.poloMapGl`. Requires maplibre-gl.js (v5.x) to be
/// loaded first. Injecting it again replaces the definition: a Flutter web
/// hot restart re-injects it into the same page, and keeping the first copy
/// pairs the new Dart with a script missing every call added since.
const mapGlScript =
    '''
window.poloMapGl = {
  create: function (container, style, styleDark, initialDark, onEvent, notifyClicks, frame) {
    // A framed map lives in a fixed-size element of its own, scaled to the
    // container by fitFrame below. MapLibre sizes its canvas from
    // clientWidth/clientHeight, which a CSS transform leaves alone.
    let host = container;
    if (frame) {
      host = document.createElement('div');
      host.style.position = 'absolute';
      host.style.left = '0';
      host.style.top = '0';
      host.style.width = frame.width + 'px';
      host.style.height = frame.height + 'px';
      host.style.transformOrigin = '0 0';
      // The backdrop scales with the picture, as the snapshot's does (see
      // paintMapSpaceBackground).
      if (frame.background) host.style.background = frame.background;
      container.style.position = 'relative';
      container.style.overflow = 'hidden';
      container.appendChild(host);
    }
    const options = {
      container: host,
      // Picking the right style up front avoids setDark() having to swap
      // styles again the moment the map opens in dark mode, which would
      // race the very first setMarkers/setLines call against the reload it
      // triggers.
      style: initialDark ? styleDark : style,
      center: frame ? [frame.longitude, frame.latitude] : [0, 0],
      zoom: frame ? frame.zoom : 1,
      attributionControl: { compact: true },
    };
    if (frame) {
      options.bearing = frame.bearing || 0;
      options.pitch = frame.pitch || 0;
      options.interactive = false;
      options.attributionControl = false;
      // Labels drawn at full strength on the first frame they appear in,
      // rather than fading in over the frames a snapshot could land on.
      options.fadeDuration = 0;
      // A snapshot reads the canvas after the frame it asked for; without
      // this the browser is free to have cleared it by then.
      options.canvasContextAttributes = { preserveDrawingBuffer: true };
    }
    const map = new maplibregl.Map(options);

    // The credits: MapLibre's compact control, its ⓘ replaced by a line of
    // our own — the basemap's and the imagery's owners, always in view as
    // their terms ask ("© OpenStreetMap", "Powered by Esri"), and a link that
    // opens every source's credit in full. The short line is read off the
    // full one, so it names whatever the map is drawing.
    let creditLabels = { more: 'Full dataset credits', less: 'Fewer credits' };
    const attribution = host.querySelector('.maplibregl-ctrl-attrib');
    const renderCredits = attribution ? (function () {
      let css = document.getElementById('polo-credits-css');
      if (!css) {
        css = document.createElement('style');
        css.id = 'polo-credits-css';
        document.head.appendChild(css);
      }
      css.textContent =
        '.maplibregl-ctrl-attrib.maplibregl-compact .maplibregl-ctrl-attrib-button { display: none; }' +
        '.maplibregl-ctrl-attrib.maplibregl-compact, .maplibregl-ctrl-attrib.maplibregl-compact.maplibregl-compact-show { padding: 2px 8px; }' +
        '.maplibregl-ctrl-attrib .polo-credits-toggle { text-decoration: underline; cursor: pointer; }';
      const inner = attribution.querySelector('.maplibregl-ctrl-attrib-inner');
      const line = document.createElement('div');
      const short = document.createElement('span');
      const toggle = document.createElement('a');
      toggle.className = 'polo-credits-toggle';
      toggle.href = '#';
      toggle.addEventListener('click', function (e) {
        e.preventDefault();
        attribution.classList.toggle('maplibregl-compact-show');
        attribution.setAttribute('open', '');
      });
      line.append(short, toggle);
      attribution.appendChild(line);
      function render() {
        const open = attribution.classList.contains('maplibregl-compact-show');
        const full = inner ? inner.textContent : '';
        const owners = [
          /OpenStreetMap/.test(full) && '© OpenStreetMap',
          /CARTO/.test(full) && '© CARTO',
          /Esri/.test(full) && 'Powered by Esri',
        ].filter(Boolean);
        short.textContent = open || !owners.length ? '' : owners.join(' · ') + ' · ';
        toggle.textContent = open ? creditLabels.less : creditLabels.more;
      }
      if (inner) new MutationObserver(render).observe(inner, { childList: true, subtree: true, characterData: true });
      // MapLibre opens a compact control once its first credit arrives, and
      // keeps it open until the first drag; here it starts on the short line.
      const opening = new MutationObserver(function () {
        if (attribution.classList.contains('maplibregl-compact-show')) {
          opening.disconnect();
          attribution.classList.remove('maplibregl-compact-show');
        }
      });
      if (attribution.classList.contains('maplibregl-compact-show')) {
        attribution.classList.remove('maplibregl-compact-show');
      } else {
        opening.observe(attribution, { attributes: true, attributeFilter: ['class'] });
      }
      new MutationObserver(render).observe(attribution, { attributes: true, attributeFilter: ['class'] });
      render();
      return render;
    })() : function () {};

    function setCreditLabels(labels) {
      creditLabels = labels;
      renderCredits();
    }

    // The bottom corner the credits sit in: 'left' for a host whose own
    // controls hold the bottom-right one, 'right' (MapLibre's own) otherwise.
    function setCreditsSide(side) {
      if (!attribution) return;
      const corner = host.querySelector(side === 'left' ? '.maplibregl-ctrl-bottom-left' : '.maplibregl-ctrl-bottom-right');
      if (corner && attribution.parentElement !== corner) corner.appendChild(attribution);
    }

    // MapLibre's globe has no style-level fog property ('space-color'/
    // 'star-intensity') to paint what's beyond the sphere — its closest
    // equivalent, the 'sky' root property, only reaches a solid colour.
    // Paired with a CSS starfield behind the canvas (see
    // mapbox_webview_map_view.dart's/mapbox_web_map_view_web.dart's
    // container background, which shows through wherever the globe leaves
    // the canvas transparent), this at least keeps the horizon dark instead
    // of leaking the operator's light/dark theme colour into what's
    // supposed to be space. Reapplied after every style swap (setStyle
    // drops root properties along with sources and layers), not just on
    // first load.
    function applySky() {
      if (!map.setSky) return;
      map.setSky({
        'sky-color': '#0b0f1a',
        'horizon-color': '#0b0f1a',
        'fog-color': '#0b0f1a',
        'fog-ground-blend': 0.5,
        'horizon-fog-blend': 0.8,
        'sky-horizon-blend': 0.8,
        'atmosphere-blend': 0.8,
      });
    }
    map.on('load', applySky);

    const EMPTY = { type: 'FeatureCollection', features: [] };
    const MARKER_LAYERS = ['polo-markers', 'polo-markers-highlight', 'polo-marker-icons', 'polo-marker-pills', 'polo-marker-pills-highlight'];
    const FIT_MAX_ZOOM = ${MapZoomController.fitMaxZoom};

    // The marker data behind the rendered circles, by feature id — a click
    // gets properties back through the GL layer, and the popup wants the
    // original strings.
    let markersById = {};
    let popup = null;
    // Signature of the base markers at the last camera fit — so a keystroke
    // that only moves the current-QSO highlight doesn't refit the camera.
    let lastBaseSig = null;
    // What `refit` returns to: the base markers' bounds as last set.
    let lastBaseBounds = null;
    // What `fitTo` last framed, until `refit`. While it holds, the markers'
    // own fit stands aside — a contact logged or moved elsewhere would
    // otherwise pull the camera off the QSO being worked — except to frame it
    // on the first fit: a `fitTo` sent while the style loads runs before the
    // queued markers do.
    let lastFit = null;

    // The most recent data given to each setter, kept so a dark-mode style
    // swap (which throws the whole style away) can put the map back exactly
    // where it was — camera position included, since fitBounds is skipped
    // when setMarkers sees the same base signature.
    let lastMarkersData = null;
    let lastLinesData = null;
    let lastShapesData = null;
    let lastProjection = null;

    // Mutable so updateStyles (a pinned-style change, not a dark-mode
    // toggle) can repoint them without touching the `dark` argument setDark
    // was last called with.
    let activeStyle = style;
    let activeStyleDark = styleDark;
    let lastDark = initialDark;

    // The style URL actually on screen, so setDark can tell a real swap from
    // one that would land on the style already showing — see its guard.
    let appliedStyleUrl = initialDark ? styleDark : style;
    // Identifies the swap a watchdog belongs to, so a later swap's arrival
    // doesn't get torn down by an earlier one's timer.
    let styleSwapId = 0;
    let styleSwapTimer = null;

    // How long either watchdog waits before deciding a style is not coming.
    // One value, because the swap watchdog's own reasoning is that it gives
    // the same grace as the pending-payload one.
    const STYLE_GRACE_MS = 10000;

    // How long a regained connection gets to become a usable one before the
    // map reloads over it. The OSM backend waits the same (OsmMapView's
    // backOnlineDelay).
    const RELOAD_DELAY_MS = 2000;

    // Whether the style on screen has finished parsing. MapLibre's own
    // isStyleLoaded() also waits for every tile, so a map that lost a single
    // tile would read as one with no style at all.
    let styleLoaded = false;

    // What has gone unanswered — asked for with no network to answer — since
    // the style last loaded. MapLibre retries none of it: a map opened
    // offline stays blank, and one that lost coverage keeps its holes,
    // however long the connection has been back. Two kinds, because they
    // recover differently:
    //
    //  * the style's own parts — the stylesheet, a source's TileJSON, the
    //    sprite. None of them is ever fetched again short of reloading the
    //    style, and without them the basemap is blank or unfinished anyway.
    //  * tiles, by source, as the {x, y, z} refreshTiles takes. Refetched in
    //    place, the style and every tile that did arrive staying up.
    //
    // Only an unanswered request counts (status 0): a sprite that 404s or a
    // layer that fails to evaluate is no better after a reload, and arming on
    // it would refetch a working map on every later online signal.
    let styleFailed = false;
    let failedTiles = {};

    // True between setDark's setStyle call and its 'style.load' handler —
    // while true, setMarkers/setLines only update lastMarkersData/lastLinesData
    // and leave applying them to that handler, rather than also queuing
    // through the pending/idle flush below: two independent appliers racing
    // to be the one that actually lands the data is how a dark-mode toggle
    // could end up with the OLD colors stuck on screen.
    let styleSwapInFlight = false;

    // The latest payload each setter is waiting to apply, and whether a flush
    // is already queued. Latest-wins rather than one queued replay per call:
    // the highlight moves on every keystroke, and `idle` arrives at least a
    // frame after the style finishes loading, so a replay carrying the payload
    // it was queued with would put stale markers back over newer ones.
    let pendingMarkers = null;
    let pendingLines = null;
    let pendingShapes = null;
    let pendingProjection = null;
    let flushQueued = false;

    // Whether the watchdog has declared the style stuck — a later successful
    // apply emits 'recovered' exactly once, so the host's notice can clear.
    let styleTimedOut = false;

    // The event callback itself must not be able to break the map: it runs
    // inside the map's own listeners, which have no catch of their own. A
    // callback failure is named in the fallback line — a broken bridge that
    // silently demoted every event to the console would otherwise be
    // indistinguishable from a healthy channel.
    function report(kind, message) {
      if (onEvent) {
        try { onEvent(kind, message); return; } catch (err) {
          message = message + ' (onEvent failed: ' + err + ')';
        }
      }
      console.log('map ' + kind + ': ' + message);
    }

    // MapLibre's setProjection takes a spec object and THROWS until the
    // style is done loading, so its call waits in the same latest-wins flush
    // as the data.
    function applyProjection(name) {
      map.setProjection({ type: name });
      lastProjection = name;
    }

    // The OpenFreeMap style has no dark counterpart, so dark mode swaps in a
    // whole different style — which drops every source and layer, so
    // markers, lines and the projection have to go back up once the new one
    // lands.
    function setDark(dark) {
      lastDark = dark;
      const url = dark ? activeStyleDark : activeStyle;
      // The style on screen is already the one wanted — a pinned basemap
      // holds both slots, so an app light/dark flip asks for no swap at all.
      // Swapping anyway would be worse than wasteful: see the diff note
      // below.
      if (url === appliedStyleUrl) return;
      appliedStyleUrl = url;
      const swapId = ++styleSwapId;
      // 'style.load' (not 'idle', which the pending/flush machinery above
      // uses for the initial, possibly offline, load) fires as soon as the
      // new style itself is usable — addSource/addLayer don't need its
      // basemap tiles downloaded too, so waiting on a full idle here would
      // strand the markers for as long as the new tile server takes, or
      // forever if it never settles.
      styleSwapInFlight = true;
      // What the replaced style failed to fetch is no longer on screen to
      // recover; this swap's own failures re-arm the reload.
      styleLoaded = false;
      styleFailed = false;
      failedTiles = {};
      map.once('style.load', function () {
        // A newer swap (or the map's removal) owns the map now; this one's
        // data is stale, and applying it would paint over theirs. A swap the
        // watchdog gave up on still lands here, which is what puts the
        // layers back if its style loads late.
        if (swapId !== styleSwapId) return;
        clearTimeout(styleSwapTimer);
        styleSwapInFlight = false;
        restoreAfterStyle('the style swap');
        try {
          if (lastProjection) applyProjection(lastProjection);
        } catch (err) {
          report('deferred-update', 'the style swap could not put the projection back: ' + ((err && err.message) || err));
        }
      });
      // `diff: false` is what makes that handler arrive at all. MapLibre's
      // default is to diff the new stylesheet against the live one and mutate
      // it in place — which drops our own sources and layers (they are in no
      // stylesheet) and builds no new Style, so NO 'style.load' is ever
      // fired: the markers go, the swap never completes, and every payload
      // after it is dropped by the styleSwapInFlight guard until the map is
      // rebuilt from scratch.
      map.setStyle(url, { diff: false });
      // A style that never loads (offline, a dead tile server) would strand
      // that guard just as permanently, and nothing else would say so: the
      // payloads are waiting here, not in the pending slots the other
      // watchdog reads.
      styleSwapTimer = setTimeout(function () {
        if (!styleSwapInFlight || swapId !== styleSwapId) return;
        styleSwapInFlight = false;
        // So the operator's obvious recovery — picking that basemap again —
        // isn't swallowed by the guard above as "already showing".
        appliedStyleUrl = null;
        styleTimedOut = true;
        report('style-swap-timeout', 'a style swap never completed; putting the map data back on the style still up');
        restoreAfterStyle('the stuck style swap');
      }, STYLE_GRACE_MS);
    }

    /// Everything setStyle throws away, put back. Runs from a map listener
    /// and from a timer — outside any caller's stack, where an escape reaches
    /// no backend's Dart side and takes the event's remaining listeners with
    /// it (same reasoning as the deferred flush below).
    //
    // No projection here: applyProjection THROWS until the style has parsed,
    // and the caller that most needs this — the watchdog, firing on a style
    // that never finished — is exactly when it would. A style that lands
    // late still restores it through the 'style.load' handler above.
    function restoreAfterStyle(what) {
      try {
        applySky();
        ensureLayers();
        if (lastMarkersData) setMarkers(lastMarkersData);
        if (lastLinesData) setLines(lastLinesData);
        if (lastShapesData) setShapes(lastShapesData);
        applyOverlays();
      } catch (err) {
        report('deferred-update', what + ' could not put the map data back: ' + ((err && err.message) || err));
      }
      // Outside the try: it reports its own failures, and a grayline fixed at
      // a contact's time is never sent again, so one skipped here for
      // another part's failure would stay off the map.
      applyGrayline();
    }

    // A pinned-style change (the operator picked a different named basemap,
    // not a light/dark toggle) — repoints both slots and swaps through the
    // same style.load path as setDark.
    //
    // `dark` is passed rather than read from lastDark: the tone and the style
    // change in the same rebuild, and the backends deliberately send only
    // this call for it, so lastDark still holds the tone of the style being
    // replaced. Picking the slot with it strands the map on the wrong
    // basemap, and the guard in setDark then makes that permanent.
    function updateStyles(newStyle, newStyleDark, dark) {
      activeStyle = newStyle;
      activeStyleDark = newStyleDark;
      setDark(dark);
    }

    map.on('style.load', function () {
      styleLoaded = true;
      styleFailed = false;
      failedTiles = {};
    });

$mapGlOverlaysScript
    let reloadTimer = null;

    // Coming back online refetches what went unanswered, and nothing else.
    // Asked for from two places — the page's own 'online' event and the
    // app's connectivity edge — so a map with nothing unanswered is left
    // alone, and one whose reload fails again is re-armed by that failure for
    // whichever signal comes next.
    //
    // Delayed, because a route appearing is not yet a working one (DHCP,
    // DNS): a reload sent into that gap fails and spends the signal. Each
    // signal restarts the wait, so the later one — the app's edge, which the
    // sync probe may have verified — is the one the reload waits behind.
    //
    // A style that never loaded has nothing on screen to lose and is simply
    // asked for again. One that loaded but is missing a part goes through
    // setDark's swap, which puts the markers and lines back on the new copy.
    // Neither path is taken for tiles alone: a swap tears the style down
    // before fetching its replacement, and on a network that raises 'online'
    // but answers nothing — a captive portal, a hotspot with no upstream —
    // that would blank a map that was only missing tiles.
    function reload() {
      clearTimeout(reloadTimer);
      reloadTimer = setTimeout(function () {
        reloadTimer = null;
        // From a timer, outside any caller's stack: an escape reaches no
        // backend's Dart side (same reasoning as the deferred flush below).
        try {
          if (styleFailed) {
            styleFailed = false;
            failedTiles = {};
            if (!styleLoaded) {
              // A swap waiting on this same URL still lands: its 'style.load'
              // handler is keyed on the swap, not on the request.
              const url = lastDark ? activeStyleDark : activeStyle;
              appliedStyleUrl = url;
              map.setStyle(url, { diff: false });
            } else {
              // Past setDark's "already showing" guard.
              appliedStyleUrl = null;
              setDark(lastDark);
            }
            return;
          }
          const tiles = failedTiles;
          failedTiles = {};
          Object.keys(tiles).forEach(function (id) {
            if (!map.getSource(id)) return;
            map.refreshTiles(id, Object.keys(tiles[id]).map(function (key) { return tiles[id][key]; }));
          });
        } catch (err) {
          // A setStyle that threw inside setDark leaves the swap flagged in
          // flight with no watchdog set to clear it, and every payload after
          // it would be dropped by that guard.
          styleSwapInFlight = false;
          report('deferred-update', 'reloading what failed offline failed: ' + ((err && err.message) || err));
        }
      }, RELOAD_DELAY_MS);
    }

    // Going offline again before the wait is up: the reload would be sent to
    // no network, and for a style missing a part that means tearing it down
    // and asking for a replacement that cannot come. What went unanswered
    // stays recorded for the next time the network is back.
    function cancelReload() {
      clearTimeout(reloadTimer);
      reloadTimer = null;
    }
    window.addEventListener('online', reload);
    window.addEventListener('offline', cancelReload);

    function showPopup(m) {
      if (popup) popup.remove();
      const root = document.createElement('div');
      root.className = 'polo-popup';
      root.style.font = '13px Roboto, sans-serif';
      root.style.color = '#333';
      const title = document.createElement('div');
      title.style.fontWeight = '700';
      title.textContent = m.popupTitle || m.label;
      root.appendChild(title);
      if (m.popupDetailPrefix || m.popupBand || m.popupDetailSuffix) {
        const detail = document.createElement('div');
        detail.appendChild(document.createTextNode(m.popupDetailPrefix));
        const band = document.createElement('span');
        band.style.fontWeight = '700';
        band.style.color = m.color;
        band.textContent = m.popupBand;
        detail.appendChild(band);
        detail.appendChild(document.createTextNode(m.popupDetailSuffix));
        root.appendChild(detail);
      }
      popup = new maplibregl.Popup({ offset: 12, closeButton: false })
        .setLngLat([m.longitude, m.latitude])
        .setDOMContent(root)
        .addTo(map);
      popup.markerId = m.id;
    }

$mapGlLayersScript
$mapGlPillScript
    // setStyle throws away registered images along with sources and layers,
    // so this re-registers rather than trusting a flag: hasImage is the only
    // honest answer after a dark-mode swap.
    function ensureImage(image) {
      if (map.hasImage(image.id)) return true;
      try {
        const binary = atob(image.rgba);
        const bytes = new Uint8Array(binary.length);
        for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
        map.addImage(
          image.id,
          { width: image.width, height: image.height, data: bytes },
          { pixelRatio: image.pixelRatio }
        );
        return true;
      } catch (err) {
        // The marker still draws, as a plain circle. Deliberately no
        // operator-facing notice — a dot in the right place is not worth
        // interrupting an activation over — so this report IS the evidence,
        // and without it the missing glyph reads as a design choice.
        report('image-failed', 'could not register marker image ' + image.id + ': ' + ((err && err.message) || err));
        return false;
      }
    }

    function ensureLayer(layer) {
      if (!map.getLayer(layer.id)) map.addLayer(layer);
    }

    // Both sources and all four layers, created together and in this order.
    // Paint order is creation order, and that order is the whole point: the
    // current QSO's line has to cover every base marker. Leaving each setter to
    // create its own layers puts them in whichever order the two happen to be
    // called in — and the markers are applied first.
    //
    // Markers are GL circles rather than DOM marker elements for the same
    // reason. A DOM marker lives above the canvas, out of reach of any
    // layer, so no line can ever be drawn over one. No `slot` either, which
    // would place these behind the basemap's Place and Transit labels — the
    // other two backends draw both dots and lines over every label, and a city
    // name across the current QSO's dot is the same defect in miniature.
    //
    // Every step re-derives what exists rather than trusting a flag it set
    // earlier: without that, an addLayer that throws part way leaves the
    // sources behind, and every later call dies on "already a source with ID".
    function ensureLayers() {
      // addSource/addLayer throw until the style itself has finished parsing
      // — catching that, rather than pre-checking the stricter
      // map.isStyleLoaded() (which also waits for every tile of every source,
      // including the basemap's own), means markers can go back up as soon as
      // the style is usable rather than only once the last tile has downloaded.
      try {
        if (!map.getSource('polo-shapes')) map.addSource('polo-shapes', { type: 'geojson', data: EMPTY });
        if (!map.getSource('polo-lines')) map.addSource('polo-lines', { type: 'geojson', data: EMPTY });
        if (!map.getSource('polo-markers')) map.addSource('polo-markers', { type: 'geojson', data: EMPTY });
        if (!map.getSource('polo-marker-icons')) map.addSource('polo-marker-icons', { type: 'geojson', data: EMPTY });
        if (!map.getSource('polo-marker-pills')) {
          map.addSource('polo-marker-pills', { type: 'geojson', data: EMPTY });
          basePillsSent = null;
        }
        if (!map.getSource('polo-marker-pills-highlight')) map.addSource('polo-marker-pills-highlight', { type: 'geojson', data: EMPTY });
        if (!map.getSource('polo-leaders')) map.addSource('polo-leaders', { type: 'geojson', data: EMPTY });
      } catch (err) {
        return false;
      }
      // First, so an area never paints over the lines and dots inside it.
      shapeLayers().forEach(ensureLayer);
      ensureLayer(lineLayer('polo-lines', false, 1.5));
      // Under every marker, so a spread marker covers the end of its own line.
      leaderLayers().forEach(ensureLayer);
      // Under the dots, so a QTH is never buried under the contacts' pills.
      ensureLayer(pillLayer('polo-marker-pills', false));
      ensureLayer(circleLayer('polo-markers', false));
      ensureLayer(lineLayer('polo-lines-highlight', true, 6));
      ensureLayer(circleLayer('polo-markers-highlight', true));
      ensureLayer(pillLayer('polo-marker-pills-highlight', true));
      // Last, so a glyph marker is never buried under a plain dot that
      // happens to share its spot. Also what says the layers are fresh: the
      // paint below is the layers' own, set once when they are made, not on
      // every keystroke's data.
      const fresh = !map.getLayer('polo-marker-icons');
      ensureLayer(iconLayer());
      if (fresh) {
        applyOpacities();
        applyFocusOrder();
      }
      return true;
    }

    // What the host fades in with the zoom (map_marker_data.dart's
    // MapZoomFades). Paint expressions on the live zoom, so a fade follows a
    // pinch frame by frame; re-applied whenever the layers are (re)made,
    // since a style swap throws the paint away with them.
    let zoomFades = null;

    // Whether the markers hold a highlighted one: while they do, every other
    // marker and line steps back (map_marker_data.dart's mapDimmedOpacity).
    // Kept by setMarkers' own walk, so a keystroke costs no scan of its own.
    let highlighted = false;

    // Opacity arrives once for the whole set of lines (see mapLinesPayload).
    function lineOpacity() {
      return (lastLinesData ? lastLinesData.opacity : 1) * (highlighted ? $mapDimmedOpacity : 1);
    }

    // The highlight layers are never touched here: they keep the full
    // strength they were built with.
    function applyOpacities() {
      if (!map.getLayer('polo-lines') || !map.getLayer('polo-markers') || !map.getLayer('polo-marker-icons') || !map.getLayer('polo-marker-pills') || !map.getLayer('polo-shapes-dashed') || !map.getLayer('polo-shapes-fill')) return;
      function fading(band, full) {
        return band ? ['interpolate', ['linear'], ['zoom'], band.from, 0, band.to, full] : full;
      }
      // A steady marker keeps full strength (MapMarkerData.dimsBehindHighlight).
      const dimming = highlighted ? ['case', ['==', ['get', 'steady'], true], 1, $mapDimmedOpacity] : 1;
      const strength = focus ? ['*', dimming, ['case', ['in', ['get', 'id'], ['literal', focus.steady]], 1, focus.othersOpacity]] : dimming;
      map.setPaintProperty('polo-lines', 'line-opacity', lineOpacity());
      // The strength goes inside the interpolate: a zoom expression has to be
      // the outermost one, so it cannot be multiplied from out here.
      const markers = zoomFades && zoomFades.markers;
      const markerOpacity = markers
        ? ['interpolate', ['linear'], ['zoom'], markers.from, ['case', ['==', ['get', 'fades'], true], 0, strength], markers.to, strength]
        : strength;
      // A glyph marker fades like a dot: a map drawing every suggestion in
      // its program's icon would otherwise be a carpet of them zoomed out.
      map.setPaintProperty('polo-marker-icons', 'icon-opacity', markerOpacity);
      map.setPaintProperty('polo-marker-pills', 'icon-opacity', markerOpacity);
      map.setPaintProperty('polo-markers', 'circle-opacity', markerOpacity);
      map.setPaintProperty('polo-markers', 'circle-stroke-opacity', markerOpacity);
      map.setPaintProperty('polo-shapes-dashed', 'line-opacity', fading(zoomFades && zoomFades.dashedShapes, DASHED_OPACITY));
      const solid = zoomFades && zoomFades.solidShapes;
      map.setPaintProperty('polo-shapes-fill', 'fill-opacity', fading(solid, FILL_OPACITY));
      map.setPaintProperty('polo-shapes-outline', 'line-opacity', fading(solid, EDGE_OPACITY));
    }

    // The marker brought forward (map_marker_data.dart's MapMarkerFocus): a
    // paint and a sort key over the markers as they stand, so moving it
    // touches neither source.
    let focus = null;

    // Sort keys rather than source order: the focused marker would otherwise
    // have to move to the end of the data, and that is a whole new set.
    function applyFocusOrder() {
      if (!map.getLayer('polo-markers') || !map.getLayer('polo-marker-icons')) return;
      const key = focus ? ['case', ['==', ['get', 'id'], focus.id], 1, 0] : undefined;
      map.setLayoutProperty('polo-marker-icons', 'symbol-sort-key', key);
      map.setLayoutProperty('polo-markers', 'circle-sort-key', key);
    }

    function setFocus(data) {
      focus = data;
      applyOpacities();
      applyFocusOrder();
    }

    function setZoomFades(data) {
      zoomFades = data;
      applyOpacities();
    }

    // 'idle' (not 'load') because 'load' fires only once ever: a call landing
    // while isStyleLoaded() is transiently false after that would queue on an
    // event that never comes again.
    function flushWhenReady() {
      if (flushQueued) return;
      flushQueued = true;
      map.once('idle', function () {
        flushQueued = false;
        const markers = pendingMarkers;
        const lines = pendingLines;
        const shapes = pendingShapes;
        const projection = pendingProjection;
        pendingMarkers = null;
        pendingLines = null;
        pendingShapes = null;
        pendingProjection = null;
        // These run outside any caller's stack, so an escape reaches neither
        // backend's Dart side — and the GL library invokes its listeners
        // without a catch, so it would take the rest of this event's
        // listeners with it. The projection gets its own catch: the payloads
        // were already popped from the pending slots, so a projection throw
        // sharing their try would silently cost the map its markers and
        // lines too.
        try {
          if (projection) { applyProjection(projection); clearTimeoutState(); }
        } catch (err) {
          report('deferred-update', 'deferred projection change failed: ' + ((err && err.message) || err));
        }
        try {
          if (markers) setMarkers(markers);
          if (lines) setLines(lines);
          if (shapes) setShapes(shapes);
        } catch (err) {
          report('deferred-update', 'deferred map update failed: ' + ((err && err.message) || err));
        }
      });
      // 'idle' is fired from a render frame, and the loop schedules another
      // frame only while something is dirty. A style that stops half-loaded —
      // offline, a broken tile server — leaves nothing dirty and never goes
      // idle, so without this nudge the payload waits for a frame that never comes.
      map.triggerRepaint();
      setTimeout(function () {
        // Still holding a payload long after the nudge: the style never
        // finished. Nothing else would say so — the map just stays empty
        // (or, when only a projection waits, the toggle silently does
        // nothing while the button shows the new state).
        if (pendingMarkers || pendingLines || pendingShapes || pendingProjection) {
          styleTimedOut = true;
          report('style-timeout', 'the style never finished loading; markers and lines are still waiting');
        }
      }, STYLE_GRACE_MS);
    }

    // A successful apply after the watchdog fired means the style did load
    // in the end (the device came back into coverage, a slow link caught
    // up), so the "could not load" state the host is showing is stale.
    function clearTimeoutState() {
      if (!styleTimedOut) return;
      styleTimedOut = false;
      report('recovered', 'a payload applied after a style timeout');
    }

    // A patch is the set the host would otherwise resend, minus everything
    // that did not change: `removeIds` drops, `upsert` replaces an entry by
    // id in place or inserts a new one at its `indices` position in the
    // host's list. The host sends a patch only when the entries both lists
    // share kept their relative order, so this reproduces its list exactly —
    // draw order included. Merged here and applied through the set path, so
    // pending/replay state and the camera fit behave as for a set.
    function mergePatch(last, idOf, patch) {
      const removed = new Set(patch.removeIds || []);
      const kept = last.filter(function (e) { return !removed.has(idOf(e)); });
      const position = new Map(kept.map(function (e, i) { return [idOf(e), i]; }));
      const inserts = [];
      (patch.upsert || []).forEach(function (e, n) {
        const at = position.get(idOf(e));
        if (at !== undefined) kept[at] = e;
        else inserts.push({ index: (patch.indices || [])[n], entry: e });
      });
      inserts.sort(function (a, b) { return a.index - b.index; });
      inserts.forEach(function (ins) {
        const index = typeof ins.index === 'number' ? Math.min(ins.index, kept.length) : kept.length;
        kept.splice(index, 0, ins.entry);
      });
      return kept;
    }

    function patchMarkers(patch) {
      setMarkers(mergePatch(lastMarkersData || [], function (m) { return m.id; }, patch));
    }

    function patchLines(patch) {
      const last = lastLinesData || { opacity: 1.0, features: [] };
      setLines({ opacity: last.opacity, features: mergePatch(last.features, function (f) { return f.properties.id; }, patch) });
    }

$mapGlSpreadScript

    function setMarkers(data) {
      lastMarkersData = data;
      if (styleSwapInFlight) return;
      if (!ensureLayers()) { pendingMarkers = data; flushWhenReady(); return; }
      clearTimeoutState();
      if (popup) { popup.remove(); popup = null; }
      markersById = {};
      const baseBounds = new maplibregl.LngLatBounds();
      const baseSig = [];
      let fitKey = null;
      const iconFeatures = [];
      const pillFeatures = [];
      const usedPills = new Set();
      const features = [];
      const spreading = [];
      let anyHighlighted = false;
      data.forEach((m) => {
        markersById[m.id] = m;
        if (m.highlight) anyHighlighted = true;
        // The sizes are outer diameters. GL strokes outward from the radius
        // rather than inside the box, so the radius gives the stroke its room
        // and a dot keeps the width it had.
        // A marker that WANTED a glyph keeps the glyph's own diameter even
        // when its image could not be registered: at the plain kind size it
        // would be pixel-identical to a suggestion dot of the same colour,
        // and that size is the only thing separating "already on the
        // operation" from "tap to add".
        const glyphSize = m.image ? m.image.width / (m.image.pixelRatio || 1) : 0;
        const size = glyphSize || (m.kind === 'qth' ? 12 : 14 * (m.sizeFactor || 1));
        const strokeWidth = m.strokeWidth || (glyphSize ? 2 : (m.kind === 'qth' ? 2 : 1.5));
        // The camera fits the base markers only, and only when they change, so
        // typing a call (which moves the highlight marker) doesn't refit —
        // nor does a marker the operator's own panning brought in.
        if (!m.highlight && m.fit !== false) {
          // A contact whose line crosses the antimeridian counts on its
          // line's side of it (MapMarkerData.fitLongitude).
          const fitLongitude = m.fitLongitude !== undefined ? m.fitLongitude : m.longitude;
          baseBounds.extend([fitLongitude, m.latitude]);
          baseSig.push(fitLongitude, m.latitude);
          if (m.fitKey) fitKey = m.fitKey;
        }
        const geometry = { type: 'Point', coordinates: [m.longitude, m.latitude] };
        if (spreadOn && !m.highlight && m.kind !== 'qth') {
          const unit = toUnit(m.longitude, m.latitude);
          const offset = spreadOffsets.get(m.id) || [0, 0];
          spreading.push({
            id: m.id, geometry: geometry, size: size, color: m.color, strokeColor: m.strokeColor,
            lon: m.longitude, lat: m.latitude, ux: unit[0], uy: unit[1], ox: offset[0], oy: offset[1],
          });
        }
        // A marker whose image could not be registered falls back to the
        // plain circle: a dot in the right place beats no marker at all.
        if (m.image && ensureImage(m.image)) {
          iconFeatures.push({
            type: 'Feature',
            properties: { id: m.id, steady: m.steady === true, fades: m.fades === true, image: m.image.id },
            geometry: geometry,
          });
          return;
        }
        const pill = m.labelColor ? pillFeature(m, geometry, usedPills) : null;
        if (pill) {
          pillFeatures.push(pill);
          return;
        }
        features.push({
          type: 'Feature',
          properties: {
            id: m.id,
            steady: m.steady === true,
            highlight: m.highlight === true,
            fades: m.fades === true,
            color: m.color,
            radius: Math.max(size / 2 - strokeWidth, 1),
            strokeWidth: strokeWidth,
            strokeColor: m.strokeColor,
          },
          geometry: geometry,
        });
      });
      spreadable = spreading;
      spreadGroups = [];
      spreadIdle = false;
      if (spreadOn) {
        spreadTargets(SPREAD_FULL_ZOOM);
        // Each offset trimmed to what the full zoom itself needs: a ring is
        // as big as its most crowded member needs, and past the full zoom
        // each marker draws back to its own least (sharesAt) — untrimmed,
        // the markers would all jump inward the moment the zoom passed it.
        const fullScale = 512 * Math.pow(2, SPREAD_FULL_ZOOM);
        spreadGroups.forEach(function (group) {
          sharesAt(group, fullScale);
          group.forEach(function (e) {
            e.fx *= e.share;
            e.fy *= e.share;
          });
        });
        spreadOffsets = new Map();
        if (positionSpread()) spreadSoon();
      }
      lastMarkerFeatures = features;
      lastIconFeatures = iconFeatures;
      map.getSource('polo-markers').setData({ type: 'FeatureCollection', features: features });
      map.getSource('polo-marker-icons').setData({ type: 'FeatureCollection', features: iconFeatures });
      setPills(pillFeatures);
      releasePillImages(usedPills);
      if (anyHighlighted !== highlighted) {
        highlighted = anyHighlighted;
        applyOpacities();
      }
      // A host that keys its fit (MapMarkerData.fitKey) refits when the key
      // changes, however its markers come and go in between.
      lastBaseBounds = baseBounds.isEmpty() ? null : baseBounds;
      const sig = fitKey ? 'key:' + fitKey : baseSig.join(',');
      // A framed map keeps the camera it was given: it is the operator's
      // framing, taken from the map they were looking at.
      if (!frame && sig !== lastBaseSig && !baseBounds.isEmpty()) {
        const first = lastBaseSig === null;
        lastBaseSig = sig;
        if (!lastFit) map.fitBounds(baseBounds, { padding: 48, maxZoom: FIT_MAX_ZOOM, duration: 0 });
        else if (first) map.fitBounds(boundsOf(lastFit), { padding: 48, maxZoom: FIT_MAX_ZOOM, duration: 0 });
      }
    }

    function setLines(data) {
      lastLinesData = data;
      if (styleSwapInFlight) return;
      if (!ensureLayers()) { pendingLines = data; flushWhenReady(); return; }
      clearTimeoutState();
      map.getSource('polo-lines').setData({ type: 'FeatureCollection', features: data.features });
      map.setPaintProperty('polo-lines', 'line-opacity', lineOpacity());
    }

    function setShapes(data) {
      lastShapesData = data;
      if (styleSwapInFlight) return;
      if (!ensureLayers()) { pendingShapes = data; flushWhenReady(); return; }
      clearTimeoutState();
      map.getSource('polo-shapes').setData({ type: 'FeatureCollection', features: data.features });
      setCredit('polo-shapes', data.credit);
    }

$mapGlCameraScript

    map.on('click', function (e) {
      // Topmost first, so where the current QSO overlaps another station the
      // popup describes the dot the operator can actually see.
      // Querying a layer that does not exist yet fires a map error rather than
      // returning nothing.
      const ready = MARKER_LAYERS.every(function (id) { return map.getLayer(id); });
      const hits = ready ? map.queryRenderedFeatures(e.point, { layers: MARKER_LAYERS }) : [];
      const marker = hits.length ? markersById[hits[0].properties.id] : null;
      if (marker) {
        if (notifyClicks) { report('marker-click', marker.id); } else { showPopup(marker); }
        return;
      }
      if (hits.length) {
        // A rendered dot with no record means the source and markersById have
        // drifted apart; silently it just reads as a dead click.
        report('marker-drift', 'clicked feature ' + hits[0].properties.id + ' has no marker record');
      }
      if (popup) { popup.remove(); popup = null; }
      // Whatever else is under the tap — a reference's outline — is the
      // host's to decide; it has the shapes and knows what a hit means.
      if (notifyClicks) report('map-click', e.lngLat.lat + ',' + e.lngLat.lng);
    });

    // One mousemove delegate rather than mouseenter/mouseleave per layer:
    // per-layer registrations each run their own queryRenderedFeatures per
    // mousemove anyway, and their leave/enter can arrive in an order that
    // leaves the cursor wrong over a live dot.
    map.on('mousemove', function (e) {
      const ready = MARKER_LAYERS.every(function (id) { return map.getLayer(id); });
      const hits = ready ? map.queryRenderedFeatures(e.point, { layers: MARKER_LAYERS }) : [];
      map.getCanvas().style.cursor = hits.length ? 'pointer' : '';
    });

    // The GL library only watches window resizes on its own; when the
    // container is an embedded platform view (Flutter web) it starts out
    // unsized and resizes with the layout, so track it directly.
    // A framed map never resizes: the container changing size only rescales
    // the picture of it.
    function fitFrame() {
      const scale = Math.min(container.clientWidth / frame.width, container.clientHeight / frame.height);
      if (scale > 0) host.style.transform = 'scale(' + scale + ')';
    }
    const resizeObserver = new ResizeObserver(frame ? fitFrame : function () { map.resize(); });
    resizeObserver.observe(container);
    if (frame) fitFrame();

$mapGlSnapshotScript
    // The only signal the GL library gives for "why is the map blank" (a
    // style that won't load, a failed tile). JSON.stringify of an event with
    // no error commonly yields '{}' (its interesting fields are
    // non-enumerable), so name what is knowable.
    map.on('error', function (e) {
      if (e && e.error instanceof maplibregl.AJAXError && e.error.status === 0) {
        const tile = e.tile && e.tile.tileID && e.tile.tileID.canonical;
        if (tile && e.sourceId) {
          const byKey = failedTiles[e.sourceId] = failedTiles[e.sourceId] || {};
          byKey[tile.z + '/' + tile.x + '/' + tile.y] = { x: tile.x, y: tile.y, z: tile.z };
        } else {
          styleFailed = true;
        }
      }
      var message = e && e.error && e.error.message;
      if (!message) {
        message = ((e && e.sourceId) ? 'source ' + e.sourceId + ': ' : '') + JSON.stringify(e);
      }
      report('gl-error', message);
    });

    // LngLatBounds keeps a longitude past ±180 as given, so an arc across
    // the antimeridian frames as one span.
    function boundsOf(points) {
      const bounds = new maplibregl.LngLatBounds();
      points.forEach(function (p) { bounds.extend(p); });
      return bounds;
    }

    // A longitude by whole turns into -180..180: a fit across the
    // antimeridian leaves the camera's own centre past 180, which a host
    // would print, or hand to something that takes no longitude outside
    // ±180.
    function wrapLongitude(lon) { return ((lon + 180) % 360 + 360) % 360 - 180; }

    // A camera move, like moveTo.
    function fitTo(points) {
      if (!points.length) return;
      lastFit = points;
      map.fitBounds(boundsOf(points), { padding: 48, maxZoom: FIT_MAX_ZOOM, duration: 500 });
    }

    return {
      map: map,
      setMarkers: setMarkers,
      setLines: setLines,
      setShapes: setShapes,
      setZoomFades: setZoomFades,
      setFocus: setFocus,
      setCreditLabels: setCreditLabels,
      setCreditsSide: setCreditsSide,
      // JSON-string variants for callers on the far side of an interop
      // boundary (Flutter web's js_interop), where a string is the cheapest
      // thing to pass.
      setMarkersJson: function (json) { setMarkers(JSON.parse(json)); },
      setLinesJson: function (json) { setLines(JSON.parse(json)); },
      patchMarkers: patchMarkers,
      patchLines: patchLines,
      patchMarkersJson: function (json) { patchMarkers(JSON.parse(json)); },
      patchLinesJson: function (json) { patchLines(JSON.parse(json)); },
      setShapesJson: function (json) { setShapes(JSON.parse(json)); },
      setOverlays: setOverlays,
      setSpread: setSpread,
      setOverlaysJson: function (json) { setOverlays(JSON.parse(json)); },
      setGrayline: setGrayline,
      setGraylineJson: function (json) { setGrayline(JSON.parse(json)); },
      setZoomFadesJson: function (json) { setZoomFades(JSON.parse(json)); },
      setFocusJson: function (json) { setFocus(JSON.parse(json)); },
      setCreditLabelsJson: function (json) { setCreditLabels(JSON.parse(json)); },
      setProjection: function (name) {
        if (map.isStyleLoaded()) { applyProjection(name); return; }
        pendingProjection = name;
        flushWhenReady();
      },
      onLoad: function (callback) { map.on('load', callback); },
      resize: function () { map.resize(); },
      zoomIn: function () { map.zoomIn(); },
      // A camera move only — it changes nothing about the data, so it never
      // races the fit-to-markers in setMarkers.
      moveTo: function (lat, lon, zoom) { map.easeTo({ center: [lon, lat], zoom: zoom, duration: 500 }); },
      fitTo: fitTo,
      fitToJson: function (json) { fitTo(JSON.parse(json)); },
      refit: function () {
        lastFit = null;
        if (lastBaseBounds) map.fitBounds(lastBaseBounds, { padding: 48, maxZoom: FIT_MAX_ZOOM, duration: 500 });
      },
      zoomOut: function () { map.zoomOut(); },
      resetNorth: function () { map.resetNorthPitch({ duration: 500 }); },
      // Where the map is looking and through how big a window, for a
      // MapFrame to hold.
      camera: function () {
        const center = map.getCenter();
        const box = map.getContainer();
        return {
          latitude: center.lat, longitude: wrapLongitude(center.lng), zoom: map.getZoom(), bearing: map.getBearing(), pitch: map.getPitch(),
          width: box.clientWidth, height: box.clientHeight,
          // The marker whose popup is open — a page element over the canvas,
          // which a picture of the map has to draw for itself.
          popup: popup && popup.isOpen() ? popup.markerId : null,
        };
      },
      snapshot: snapshot,
      setDark: setDark,
      updateStyles: updateStyles,
      reload: reload,
      cancelReload: cancelReload,
      remove: function () {
        mapRemoved = true;
        Array.from(pendingSnapshots).forEach(function (finish) { finish(null, new Error('$mapSnapshotRemovedMessage')); });
        resizeObserver.disconnect();
        window.removeEventListener('online', reload);
        window.removeEventListener('offline', cancelReload);
        clearTimeout(reloadTimer);
        // Or a watchdog reports a style that never loaded, about a map that
        // was simply taken down while it was still loading — and the swap
        // one would go further and put markers back on a removed map.
        styleSwapId++;
        styleSwapInFlight = false;
        cancelAnimationFrame(spreadFrame);
        cancelAnimationFrame(orientationFrame);
        clearTimeout(styleSwapTimer);
        pendingMarkers = null;
        pendingLines = null;
        pendingShapes = null;
        pendingProjection = null;
        if (popup) popup.remove();
        map.remove();
      },
    };
  },
};
''';

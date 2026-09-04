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
// onEvent, notifyClicks)` returning a handle with `setMarkersJson`,
// `setLinesJson`, `setShapesJson`, `setProjection`, `moveTo`, and `remove`. Data crosses as JSON
// strings — both callers already have the payload serialized, and strings
// keep the interop layer trivial on each side.
//
// `notifyClicks` (default false) is for a caller that wants to render its
// own reveal/action UI in Flutter instead of this script's built-in HTML
// popup: a marker click reports through `onEvent('marker-click', id)`
// rather than opening `showPopup`. The QSO map never sets it, so its popup
// behavior is unchanged.
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

import '../../services/settings_service.dart' show MapStyle;

/// Where MapLibre GL JS itself comes from — needs no access token, unlike
/// the commercial GL libraries.
const mapGlScriptUrl = 'https://unpkg.com/maplibre-gl@5.6.0/dist/maplibre-gl.js';
const mapGlCssUrl = 'https://unpkg.com/maplibre-gl@5.6.0/dist/maplibre-gl.css';

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
  final random = Random(1);
  final stars = List.generate(80, (_) {
    final x = random.nextDouble() * 100;
    final y = random.nextDouble() * 100;
    final size = 0.5 + random.nextDouble() * 1.2;
    final opacity = 0.3 + random.nextDouble() * 0.6;
    return 'radial-gradient(${size.toStringAsFixed(2)}px ${size.toStringAsFixed(2)}px at ${x.toStringAsFixed(2)}% '
        '${y.toStringAsFixed(2)}%, rgba(255, 255, 255, ${opacity.toStringAsFixed(2)}), transparent)';
  }).join(', ');
  return '$stars, linear-gradient(180deg, #0b0f1a 0%, #0d1526 100%)';
}

/// JS that defines `window.poloMapGl`. Requires maplibre-gl.js (v5.x) to be
/// loaded first. Idempotent — safe to inject more than once.
const mapGlScript = '''
window.poloMapGl = window.poloMapGl || {
  create: function (container, style, styleDark, initialDark, onEvent, notifyClicks) {
    const options = {
      container: container,
      // Picking the right style up front avoids setDark() having to swap
      // styles again the moment the map opens in dark mode, which would
      // race the very first setMarkers/setLines call against the reload it
      // triggers.
      style: initialDark ? styleDark : style,
      center: [0, 0],
      zoom: 1,
    };
    const map = new maplibregl.Map(options);

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
    const MARKER_LAYERS = ['polo-markers', 'polo-markers-highlight', 'polo-marker-icons'];

    // The marker data behind the rendered circles, by feature id — a click
    // gets properties back through the GL layer, and the popup wants the
    // original strings.
    let markersById = {};
    let popup = null;
    // Signature of the base markers at the last camera fit — so a keystroke
    // that only moves the current-QSO highlight doesn't refit the camera.
    let lastBaseSig = null;

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
      } catch (err) {
        report('deferred-update', what + ' could not put the map data back: ' + ((err && err.message) || err));
      }
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
    }

    function lineLayer(id, highlight, width) {
      return {
        id: id,
        type: 'line',
        source: 'polo-lines',
        filter: [highlight ? '==' : '!=', ['get', 'highlight'], true],
        paint: {
          'line-color': ['coalesce', ['get', 'color'], '#000000'],
          'line-width': width,
          'line-opacity': 1,
        },
      };
    }

    // A reference's own footprint (map_marker_data.dart's MapShapeData) — a
    // translucent wash with a solid edge, so an activation zone reads as an
    // area without hiding the terrain the activator is standing on.
    function shapeLayers() {
      return [
        {
          id: 'polo-shapes-fill',
          type: 'fill',
          source: 'polo-shapes',
          paint: {
            'fill-color': ['coalesce', ['get', 'color'], '#000000'],
            'fill-opacity': 0.18,
          },
        },
        {
          id: 'polo-shapes-outline',
          type: 'line',
          source: 'polo-shapes',
          paint: {
            'line-color': ['coalesce', ['get', 'color'], '#000000'],
            'line-width': 2,
            'line-opacity': 0.9,
          },
        },
      ];
    }

    function circleLayer(id, highlight) {
      return {
        id: id,
        type: 'circle',
        source: 'polo-markers',
        filter: [highlight ? '==' : '!=', ['get', 'highlight'], true],
        paint: {
          // Per feature, so one layer covers the QTH dot, every band colour
          // and every signal-strength size.
          'circle-radius': ['get', 'radius'],
          'circle-color': ['coalesce', ['get', 'color'], '#000000'],
          'circle-stroke-width': ['get', 'strokeWidth'],
          'circle-stroke-color': ['get', 'strokeColor'],
        },
      };
    }

    // A marker that carries its own pixels (map_marker_data.dart's
    // MapMarkerImage) — fill, ring and glyph already drawn, because the GL
    // canvas has no access to the app's icon font.
    function iconLayer() {
      return {
        id: 'polo-marker-icons',
        type: 'symbol',
        source: 'polo-marker-icons',
        layout: {
          'icon-image': ['get', 'image'],
          // These markers mean something specific ("you are here", "this is
          // on the operation"), so they are never the one collision-based
          // placement drops.
          'icon-allow-overlap': true,
          'icon-ignore-placement': true,
          // Source order, not the default screen-position sort: the caller
          // puts the marker that must stay legible last, and a viewport sort
          // would instead bury it under whichever neighbour happens to sit
          // further south.
          'symbol-z-order': 'source',
        },
      };
    }

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
      } catch (err) {
        return false;
      }
      // First, so an area never paints over the lines and dots inside it.
      shapeLayers().forEach(ensureLayer);
      ensureLayer(lineLayer('polo-lines', false, 1.5));
      ensureLayer(circleLayer('polo-markers', false));
      ensureLayer(lineLayer('polo-lines-highlight', true, 6));
      ensureLayer(circleLayer('polo-markers-highlight', true));
      // Last, so a glyph marker is never buried under a plain dot that
      // happens to share its spot.
      ensureLayer(iconLayer());
      return true;
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

    function setMarkers(data) {
      lastMarkersData = data;
      if (styleSwapInFlight) return;
      if (!ensureLayers()) { pendingMarkers = data; flushWhenReady(); return; }
      clearTimeoutState();
      if (popup) { popup.remove(); popup = null; }
      markersById = {};
      const baseBounds = new maplibregl.LngLatBounds();
      const baseSig = [];
      const iconFeatures = [];
      const features = [];
      data.forEach((m) => {
        markersById[m.id] = m;
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
        const strokeWidth = glyphSize ? 2 : (m.kind === 'qth' ? 2 : 1.5);
        // The camera fits the base markers only, and only when they change, so
        // typing a call (which moves the highlight marker) doesn't refit.
        if (!m.highlight) {
          baseBounds.extend([m.longitude, m.latitude]);
          baseSig.push(m.longitude, m.latitude);
        }
        const geometry = { type: 'Point', coordinates: [m.longitude, m.latitude] };
        // A marker whose image could not be registered falls back to the
        // plain circle: a dot in the right place beats no marker at all.
        if (m.image && ensureImage(m.image)) {
          iconFeatures.push({
            type: 'Feature',
            properties: { id: m.id, image: m.image.id },
            geometry: geometry,
          });
          return;
        }
        features.push({
          type: 'Feature',
          properties: {
            id: m.id,
            highlight: m.highlight === true,
            color: m.color,
            radius: Math.max(size / 2 - strokeWidth, 1),
            strokeWidth: strokeWidth,
            strokeColor: m.strokeColor,
          },
          geometry: geometry,
        });
      });
      map.getSource('polo-markers').setData({ type: 'FeatureCollection', features: features });
      map.getSource('polo-marker-icons').setData({ type: 'FeatureCollection', features: iconFeatures });
      const sig = baseSig.join(',');
      if (sig !== lastBaseSig && !baseBounds.isEmpty()) {
        lastBaseSig = sig;
        map.fitBounds(baseBounds, { padding: 48, maxZoom: 11, duration: 0 });
      }
    }

    function setLines(data) {
      lastLinesData = data;
      if (styleSwapInFlight) return;
      if (!ensureLayers()) { pendingLines = data; flushWhenReady(); return; }
      clearTimeoutState();
      map.getSource('polo-lines').setData({ type: 'FeatureCollection', features: data.features });
      // Opacity arrives once for the whole set (see mapLinesPayload); the
      // highlight line keeps the full-strength opacity its layer was built
      // with, so only the base layer takes it.
      map.setPaintProperty('polo-lines', 'line-opacity', data.opacity);
    }

    function setShapes(data) {
      lastShapesData = data;
      if (styleSwapInFlight) return;
      if (!ensureLayers()) { pendingShapes = data; flushWhenReady(); return; }
      clearTimeoutState();
      map.getSource('polo-shapes').setData({ type: 'FeatureCollection', features: data.features });
    }

    map.on('click', function (e) {
      // Topmost first, so where the current QSO overlaps another station the
      // popup describes the dot the operator can actually see.
      // Querying a layer that does not exist yet fires a map error rather than
      // returning nothing.
      const ready = map.getLayer('polo-markers') && map.getLayer('polo-markers-highlight') && map.getLayer('polo-marker-icons');
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
    });

    // One mousemove delegate rather than mouseenter/mouseleave per layer:
    // per-layer registrations each run their own queryRenderedFeatures per
    // mousemove anyway, and their leave/enter can arrive in an order that
    // leaves the cursor wrong over a live dot.
    map.on('mousemove', function (e) {
      const ready = map.getLayer('polo-markers') && map.getLayer('polo-markers-highlight') && map.getLayer('polo-marker-icons');
      const hits = ready ? map.queryRenderedFeatures(e.point, { layers: MARKER_LAYERS }) : [];
      map.getCanvas().style.cursor = hits.length ? 'pointer' : '';
    });

    // The GL library only watches window resizes on its own; when the
    // container is an embedded platform view (Flutter web) it starts out
    // unsized and resizes with the layout, so track it directly.
    const resizeObserver = new ResizeObserver(function () { map.resize(); });
    resizeObserver.observe(container);

    // The only signal the GL library gives for "why is the map blank" (a
    // style that won't load, a failed tile). JSON.stringify of an event with
    // no error commonly yields '{}' (its interesting fields are
    // non-enumerable), so name what is knowable.
    map.on('error', function (e) {
      var message = e && e.error && e.error.message;
      if (!message) {
        message = ((e && e.sourceId) ? 'source ' + e.sourceId + ': ' : '') + JSON.stringify(e);
      }
      report('gl-error', message);
    });

    return {
      map: map,
      setMarkers: setMarkers,
      setLines: setLines,
      setShapes: setShapes,
      // JSON-string variants for callers on the far side of an interop
      // boundary (Flutter web's js_interop), where a string is the cheapest
      // thing to pass.
      setMarkersJson: function (json) { setMarkers(JSON.parse(json)); },
      setLinesJson: function (json) { setLines(JSON.parse(json)); },
      setShapesJson: function (json) { setShapes(JSON.parse(json)); },
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
      zoomOut: function () { map.zoomOut(); },
      setDark: setDark,
      updateStyles: updateStyles,
      remove: function () {
        resizeObserver.disconnect();
        // Or a watchdog reports a style that never loaded, about a map that
        // was simply taken down while it was still loading — and the swap
        // one would go further and put markers back on a removed map.
        styleSwapId++;
        styleSwapInFlight = false;
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

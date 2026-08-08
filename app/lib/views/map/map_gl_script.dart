// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The browser-engine side of the map — Mapbox GL JS or MapLibre GL JS —
// shared by the two backends that run it in a real browser engine: the
// webview (mapbox_webview_map_view.dart, which wraps this in its own HTML
// page) and Flutter web (mapbox_web_map_view.dart, which injects it into the
// app's own page and drives it through js_interop). One copy of the
// marker/line/popup/projection logic, so the two can't drift apart.
//
// Exposes `window.poloMapGl.create(container, engine, token, style, onEvent)`
// returning a handle with `setMarkersJson`, `setLinesJson`, `setProjection`,
// and `remove`. Data crosses as JSON strings — both callers already have the
// payload serialized, and strings keep the interop layer trivial on each side.
//
// `engine` is 'mapbox' or 'maplibre' (MapGlEngine.name) — the two libraries
// are near-identical descendants of the same codebase, so one script drives
// either; the engine is a per-call argument rather than sniffed from which
// global exists, because on Flutter web both libraries can end up loaded in
// the same page across an experiment toggle.
//
// `onEvent(kind, message)` is the host's error channel: every failure this
// script can observe goes through it, so each backend can route into
// ErrorPolicy (via MapErrorReporter) instead of a console nobody reads in a
// release build. Kinds: 'gl-error' (the map's own error event),
// 'style-timeout' (the pending-payload watchdog — the "map stays blank"
// signal, which backends also surface in-panel), 'recovered' (a payload
// applied after a style-timeout: not an error, it clears that notice),
// 'deferred-update' and 'marker-drift'. Without a callback the script falls
// back to the console, which is where a bare devtools session still looks.

/// Which GL library a browser-engine map runs on, and where its pieces come
/// from. Mapbox needs the access token from secrets; MapLibre + OpenFreeMap
/// need no token at all (see the MAPLIBRE experiment, experiments.yaml).
enum MapGlEngine {
  mapbox(
    scriptUrl: 'https://api.mapbox.com/mapbox-gl-js/v3.9.0/mapbox-gl.js',
    cssUrl: 'https://api.mapbox.com/mapbox-gl-js/v3.9.0/mapbox-gl.css',
    styleUrl: 'mapbox://styles/mapbox/standard',
  ),
  maplibre(
    scriptUrl: 'https://unpkg.com/maplibre-gl@5.6.0/dist/maplibre-gl.js',
    cssUrl: 'https://unpkg.com/maplibre-gl@5.6.0/dist/maplibre-gl.css',
    styleUrl: 'https://tiles.openfreemap.org/styles/liberty',
  );

  final String scriptUrl;
  final String cssUrl;
  final String styleUrl;

  const MapGlEngine({required this.scriptUrl, required this.cssUrl, required this.styleUrl});
}

/// JS that defines `window.poloMapGl`. Requires mapbox-gl.js (v3.x) or
/// maplibre-gl.js (v5.x) to be loaded first, matching the `engine` passed to
/// `create`. Idempotent — safe to inject more than once.
const mapGlScript = '''
window.poloMapGl = window.poloMapGl || {
  create: function (container, engine, token, style, onEvent) {
    const gl = engine === 'maplibre' ? maplibregl : mapboxgl;
    const options = {
      container: container,
      style: style,
      center: [0, 0],
      zoom: 1,
    };
    // MapLibre has no accessToken and takes its projection from the style
    // (mercator unless the style says otherwise); its setProjection also
    // wants a spec object where Mapbox takes a bare name — see below.
    if (engine !== 'maplibre') {
      gl.accessToken = token;
      options.projection = 'mercator';
    }
    const map = new gl.Map(options);

    const EMPTY = { type: 'FeatureCollection', features: [] };
    const MARKER_LAYERS = ['polo-markers', 'polo-markers-highlight'];

    // The marker data behind the rendered circles, by feature id — a click
    // gets properties back through the GL layer, and the popup wants the
    // original strings.
    let markersById = {};
    let popup = null;
    // Signature of the base markers at the last camera fit — so a keystroke
    // that only moves the current-QSO highlight doesn't refit the camera.
    let lastBaseSig = null;

    // The latest payload each setter is waiting to apply, and whether a flush
    // is already queued. Latest-wins rather than one queued replay per call:
    // the highlight moves on every keystroke, and `idle` arrives at least a
    // frame after the style finishes loading, so a replay carrying the payload
    // it was queued with would put stale markers back over newer ones.
    let pendingMarkers = null;
    let pendingLines = null;
    let pendingProjection = null;
    let flushQueued = false;

    // Whether the watchdog has declared the style stuck — a later successful
    // apply emits 'recovered' exactly once, so the host's notice can clear.
    let styleTimedOut = false;

    // The event callback itself must not be able to break the map: it runs
    // inside Mapbox's own listeners, which have no catch of their own. A
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

    // Mapbox takes a projection name and queues it itself if the style is
    // still loading; MapLibre takes a spec object and THROWS until the style
    // is done, so its call waits in the same latest-wins flush as the data.
    function applyProjection(name) {
      map.setProjection(engine === 'maplibre' ? { type: name } : name);
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
      popup = new gl.Popup({ offset: 12, closeButton: false })
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

    function ensureLayer(layer) {
      if (!map.getLayer(layer.id)) map.addLayer(layer);
    }

    // Both sources and all four layers, created together and in this order.
    // Paint order is creation order, and that order is the whole point: the
    // current QSO's line has to cover every base marker. Leaving each setter to
    // create its own layers puts them in whichever order the two happen to be
    // called in — and the markers are applied first.
    //
    // Markers are GL circles rather than mapboxgl.Marker DOM elements for the
    // same reason. A DOM marker lives above the canvas, out of reach of any
    // layer, so no line can ever be drawn over one. No `slot` either, which
    // would place these behind the basemap's Place and Transit labels — the
    // other two backends draw both dots and lines over every label, and a city
    // name across the current QSO's dot is the same defect in miniature.
    //
    // Every step re-derives what exists rather than trusting a flag it set
    // earlier: without that, an addLayer that throws part way leaves the
    // sources behind, and every later call dies on "already a source with ID".
    //
    // In GLOBE projection this order buys less than it looks: mapbox-gl 3.9
    // draws circle layers over line layers there whatever the order, so the
    // current QSO's line still passes under the other stations' dots. Moving
    // the layer or giving it a slot does not help — don't spend the time. Its
    // marker, and its precedence over the other lines, hold in both
    // projections, and mercator, the default, is exact.
    function ensureLayers() {
      // Adding a layer to a style that is still loading throws.
      if (!map.isStyleLoaded()) return false;
      if (!map.getSource('polo-lines')) map.addSource('polo-lines', { type: 'geojson', data: EMPTY });
      if (!map.getSource('polo-markers')) map.addSource('polo-markers', { type: 'geojson', data: EMPTY });
      ensureLayer(lineLayer('polo-lines', false, 1.5));
      ensureLayer(circleLayer('polo-markers', false));
      ensureLayer(lineLayer('polo-lines-highlight', true, 6));
      ensureLayer(circleLayer('polo-markers-highlight', true));
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
        const projection = pendingProjection;
        pendingMarkers = null;
        pendingLines = null;
        pendingProjection = null;
        // These run outside any caller's stack, so an escape reaches neither
        // backend's Dart side — and Mapbox invokes its listeners without a
        // catch, so it would take the rest of this event's listeners with it.
        // The projection gets its own catch: the payloads were already popped
        // from the pending slots, so a projection throw sharing their try
        // would silently cost the map its markers and lines too.
        try {
          if (projection) { applyProjection(projection); clearTimeoutState(); }
        } catch (err) {
          report('deferred-update', 'deferred projection change failed: ' + ((err && err.message) || err));
        }
        try {
          if (markers) setMarkers(markers);
          if (lines) setLines(lines);
        } catch (err) {
          report('deferred-update', 'deferred map update failed: ' + ((err && err.message) || err));
        }
      });
      // 'idle' is fired from a render frame, and the loop schedules another
      // frame only while something is dirty. A style that stops half-loaded —
      // offline, a rejected token — leaves nothing dirty and never goes idle,
      // so without this nudge the payload waits for a frame that never comes.
      map.triggerRepaint();
      setTimeout(function () {
        // Still holding a payload long after the nudge: the style never
        // finished. Nothing else would say so — the map just stays empty
        // (or, when only a projection waits, the toggle silently does
        // nothing while the button shows the new state).
        if (pendingMarkers || pendingLines || pendingProjection) {
          styleTimedOut = true;
          report('style-timeout', 'the style never finished loading; markers and lines are still waiting');
        }
      }, 10000);
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
      if (!ensureLayers()) { pendingMarkers = data; flushWhenReady(); return; }
      clearTimeoutState();
      if (popup) { popup.remove(); popup = null; }
      markersById = {};
      const baseBounds = new gl.LngLatBounds();
      const baseSig = [];
      const features = data.map((m) => {
        markersById[m.id] = m;
        // The sizes are outer diameters. GL strokes outward from the radius
        // rather than inside the box, so the radius gives the stroke its room
        // and a dot keeps the width it had.
        const size = m.kind === 'qth' ? 12 : 14 * (m.sizeFactor || 1);
        const strokeWidth = m.kind === 'qth' ? 2 : 1.5;
        // The camera fits the base markers only, and only when they change, so
        // typing a call (which moves the highlight marker) doesn't refit.
        if (!m.highlight) {
          baseBounds.extend([m.longitude, m.latitude]);
          baseSig.push(m.longitude, m.latitude);
        }
        return {
          type: 'Feature',
          properties: {
            id: m.id,
            highlight: m.highlight === true,
            color: m.color,
            radius: Math.max(size / 2 - strokeWidth, 1),
            strokeWidth: strokeWidth,
            strokeColor: m.kind === 'qth' ? '#ffffff' : 'rgba(0, 0, 0, 0.87)',
          },
          geometry: { type: 'Point', coordinates: [m.longitude, m.latitude] },
        };
      });
      map.getSource('polo-markers').setData({ type: 'FeatureCollection', features: features });
      const sig = baseSig.join(',');
      if (sig !== lastBaseSig && !baseBounds.isEmpty()) {
        lastBaseSig = sig;
        map.fitBounds(baseBounds, { padding: 48, maxZoom: 11, duration: 0 });
      }
    }

    function setLines(data) {
      if (!ensureLayers()) { pendingLines = data; flushWhenReady(); return; }
      clearTimeoutState();
      map.getSource('polo-lines').setData({ type: 'FeatureCollection', features: data.features });
      // Opacity arrives once for the whole set (see mapLinesPayload); the
      // highlight line keeps the full-strength opacity its layer was built
      // with, so only the base layer takes it.
      map.setPaintProperty('polo-lines', 'line-opacity', data.opacity);
    }

    map.on('click', function (e) {
      // Topmost first, so where the current QSO overlaps another station the
      // popup describes the dot the operator can actually see.
      // Querying a layer that does not exist yet fires a map error rather than
      // returning nothing.
      const ready = map.getLayer('polo-markers') && map.getLayer('polo-markers-highlight');
      const hits = ready ? map.queryRenderedFeatures(e.point, { layers: MARKER_LAYERS }) : [];
      const marker = hits.length ? markersById[hits[0].properties.id] : null;
      if (marker) { showPopup(marker); return; }
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
    // leaves the cursor wrong over a live dot. The layer-array form of
    // mouseenter would also tie the script to whichever engines support it —
    // a plain mousemove works identically on both.
    map.on('mousemove', function (e) {
      const ready = map.getLayer('polo-markers') && map.getLayer('polo-markers-highlight');
      const hits = ready ? map.queryRenderedFeatures(e.point, { layers: MARKER_LAYERS }) : [];
      map.getCanvas().style.cursor = hits.length ? 'pointer' : '';
    });

    // Mapbox GL only watches window resizes on its own; when the container
    // is an embedded platform view (Flutter web) it starts out unsized and
    // resizes with the layout, so track it directly.
    const resizeObserver = new ResizeObserver(function () { map.resize(); });
    resizeObserver.observe(container);

    // The only signal Mapbox gives for "why is the map blank" (an
    // invalid/expired token, a style that won't load, a failed tile).
    // JSON.stringify of an event with no error commonly yields '{}' (its
    // interesting fields are non-enumerable), so name what is knowable.
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
      // JSON-string variants for callers on the far side of an interop
      // boundary (Flutter web's js_interop), where a string is the cheapest
      // thing to pass.
      setMarkersJson: function (json) { setMarkers(JSON.parse(json)); },
      setLinesJson: function (json) { setLines(JSON.parse(json)); },
      setProjection: function (name) {
        if (engine !== 'maplibre' || map.isStyleLoaded()) { applyProjection(name); return; }
        pendingProjection = name;
        flushWhenReady();
      },
      onLoad: function (callback) { map.on('load', callback); },
      resize: function () { map.resize(); },
      remove: function () {
        resizeObserver.disconnect();
        // Or the pending-payload watchdog reports a style that never loaded,
        // about a map that was simply taken down while it was still loading.
        pendingMarkers = null;
        pendingLines = null;
        pendingProjection = null;
        if (popup) popup.remove();
        map.remove();
      },
    };
  },
};
''';

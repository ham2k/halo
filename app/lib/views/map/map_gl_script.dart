// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Mapbox GL JS side of the map, shared by the two backends that run it
// in a real browser engine: the desktop webview (mapbox_webview_map_view.dart,
// which wraps this in its own HTML page) and Flutter web
// (mapbox_web_map_view.dart, which injects it into the app's own page and
// drives it through js_interop). One copy of the marker/line/popup/projection
// logic, so the two can't drift apart.
//
// Exposes `window.poloMapGl.create(container, token)` returning a handle
// with `setMarkersJson`, `setLinesJson`, `setProjection`, and `remove`.
// Data crosses as JSON strings — both callers already have the payload
// serialized, and strings keep the interop layer trivial on each side.

/// JS that defines `window.poloMapGl`. Requires mapbox-gl.js (v3.x) to be
/// loaded first. Idempotent — safe to inject more than once.
const mapGlScript = '''
window.poloMapGl = window.poloMapGl || {
  create: function (container, token) {
    mapboxgl.accessToken = token;
    const map = new mapboxgl.Map({
      container: container,
      style: 'mapbox://styles/mapbox/standard',
      projection: 'mercator',
      center: [0, 0],
      zoom: 1,
    });

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
    let flushQueued = false;

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
      popup = new mapboxgl.Popup({ offset: 12, closeButton: false })
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
        pendingMarkers = null;
        pendingLines = null;
        // This runs outside any caller's stack, so an escape reaches neither
        // backend's Dart side — and Mapbox invokes its listeners without a
        // catch, so it would take the rest of this event's listeners with it.
        try {
          if (markers) setMarkers(markers);
          if (lines) setLines(lines);
        } catch (err) {
          console.log('map error: deferred map update failed: ' + ((err && err.message) || err));
        }
      });
      // 'idle' is fired from a render frame, and the loop schedules another
      // frame only while something is dirty. A style that stops half-loaded —
      // offline, a rejected token — leaves nothing dirty and never goes idle,
      // so without this nudge the payload waits for a frame that never comes.
      map.triggerRepaint();
      setTimeout(function () {
        // Still holding a payload long after the nudge: the style never
        // finished. Nothing else would say so — the map just stays empty.
        if (pendingMarkers || pendingLines) {
          console.log('map error: the style never finished loading; markers and lines are still waiting');
        }
      }, 10000);
    }

    function setMarkers(data) {
      if (!ensureLayers()) { pendingMarkers = data; flushWhenReady(); return; }
      if (popup) { popup.remove(); popup = null; }
      markersById = {};
      const baseBounds = new mapboxgl.LngLatBounds();
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
        console.log('map error: clicked feature ' + hits[0].properties.id + ' has no marker record');
      }
      if (popup) { popup.remove(); popup = null; }
    });

    // One delegate for both layers, not one per layer: each registration runs
    // its own queryRenderedFeatures on every mousemove, and their leave/enter
    // can arrive in an order that leaves the cursor wrong over a live dot.
    map.on('mouseenter', MARKER_LAYERS, function () { map.getCanvas().style.cursor = 'pointer'; });
    map.on('mouseleave', MARKER_LAYERS, function () { map.getCanvas().style.cursor = ''; });

    // Mapbox GL only watches window resizes on its own; when the container
    // is an embedded platform view (Flutter web) it starts out unsized and
    // resizes with the layout, so track it directly.
    const resizeObserver = new ResizeObserver(function () { map.resize(); });
    resizeObserver.observe(container);

    // Surfaced to each backend's own logging path — the only signal we get
    // for "why is the map blank" reports (e.g. an invalid/expired token).
    map.on('error', function (e) {
      console.log('map error: ' + (e && e.error ? e.error.message : JSON.stringify(e)));
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
      setProjection: function (name) { map.setProjection(name); },
      onLoad: function (callback) { map.on('load', callback); },
      resize: function () { map.resize(); },
      remove: function () {
        resizeObserver.disconnect();
        // Or the pending-payload watchdog reports a style that never loaded,
        // about a map that was simply taken down while it was still loading.
        pendingMarkers = null;
        pendingLines = null;
        if (popup) popup.remove();
        map.remove();
      },
    };
  },
};
''';

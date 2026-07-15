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

    let markers = [];
    let popup = null;

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

    function setMarkers(data) {
      markers.forEach((m) => m.remove());
      markers = [];
      if (popup) { popup.remove(); popup = null; }
      if (!data.length) return;
      const bounds = new mapboxgl.LngLatBounds();
      data.forEach((m) => {
        const el = document.createElement('div');
        const size = m.kind === 'qth' ? 12 : 14 * (m.sizeFactor || 1);
        el.style.borderRadius = '50%';
        el.style.border = m.kind === 'qth' ? '2px solid white' : '1.5px solid rgba(0, 0, 0, 0.87)';
        el.style.boxSizing = 'border-box';
        el.style.cursor = 'pointer';
        el.style.width = size + 'px';
        el.style.height = size + 'px';
        el.style.background = m.color;
        el.title = m.label;
        el.addEventListener('click', (e) => { e.stopPropagation(); showPopup(m); });
        markers.push(new mapboxgl.Marker({ element: el }).setLngLat([m.longitude, m.latitude]).addTo(map));
        bounds.extend([m.longitude, m.latitude]);
      });
      map.fitBounds(bounds, { padding: 48, maxZoom: 11, duration: 0 });
    }

    function setLines(data) {
      // Adding a layer to a style that is still loading throws — retry when
      // the map next settles. 'idle' (not 'load') because 'load' fires only
      // once ever: a call landing while isStyleLoaded() is transiently false
      // after that would queue on an event that never comes again.
      if (!map.isStyleLoaded()) { map.once('idle', () => setLines(data)); return; }
      const source = map.getSource('polo-lines');
      const collection = { type: 'FeatureCollection', features: data.features };
      if (source) {
        source.setData(collection);
      } else {
        map.addSource('polo-lines', { type: 'geojson', data: collection });
        map.addLayer({
          id: 'polo-lines',
          type: 'line',
          source: 'polo-lines',
          slot: 'top',
          paint: {
            'line-color': ['coalesce', ['get', 'color'], '#000000'],
            'line-width': 1.5,
            'line-opacity': data.opacity,
          },
        });
      }
      if (map.getLayer('polo-lines')) {
        map.setPaintProperty('polo-lines', 'line-opacity', data.opacity);
      }
    }

    map.on('click', function () {
      if (popup) { popup.remove(); popup = null; }
    });

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
        markers.forEach((m) => m.remove());
        if (popup) popup.remove();
        map.remove();
      },
    };
  },
};
''';

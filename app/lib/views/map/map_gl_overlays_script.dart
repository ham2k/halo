// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The part of map_gl_script.dart's `create` that lays imagery, boundaries
// and park facilities over the basemap — spliced into it verbatim, so it runs
// in the same closure and reads the same `map`, `report` and style state.

/// See map_gl_script.dart's `mapGlScript`, which includes this text whole.
const mapGlOverlaysScript = '''
    // The layers a host lays over the basemap (map_overlays.dart's
    // mapOverlaysPayload): imagery under the basemap's labels, boundaries,
    // and park facilities. Null, or every part off, is the basemap alone.
    // Cell bundles are fetched here rather than sent over the bridge: they
    // follow the camera, and only this side knows where it came to rest.
    let overlays = null;
    // The features last read for each bundled overlay, so a style swap puts
    // them straight back rather than waiting for the camera to move.
    let regionFeatures = [];
    let facilityFeatures = [];
    // Each bundle's fetch, by URL — a pan back over a cell asks nothing new.
    // A failed one is dropped, so the next move asks again. The most recently
    // used BUNDLES_KEPT only: the Maps view lives as long as the app, and a
    // pan across a country would otherwise keep every county it crossed.
    const bundleFetches = new Map();
    const BUNDLES_KEPT = 32;
    let regionsRequest = 0;
    let facilitiesRequest = 0;

    const BOUNDARY_LAYERS = ['polo-boundary-countries', 'polo-boundary-states', 'polo-boundary-counties'];
    const REGION_LAYERS = ['polo-region-counties', 'polo-region-labels-states', 'polo-region-labels-counties'];
    // The facility kinds the bundles carry, each with its icon and the zoom
    // it shows from — the busiest kinds last.
    const FACILITY_KINDS = [
      ['visitor_centre', 'mdiInformation', 11],
      ['parking', 'mdiParking', 12],
      ['ranger_station', 'mdiShieldAccount', 13.5],
      ['shelter', 'mdiHomeRoof', 13.5],
      ['picnic_site', 'mdiTableFurniture', 13.5],
      ['viewpoint', 'mdiBinoculars', 14.5],
      ['trailhead', 'mdiSignDirection', 14.5],
      ['campsite', 'mdiTent', 14.5],
      ['toilets', 'mdiToilet', 14.5],
      ['drinking_water', 'mdiWater', 14.5],
      ['picnic_table', 'mdiTableFurniture', 14.5],
      ['bbq', 'mdiGrill', 14.5],
      ['bench', 'mdiBench', 14.5],
    ];
    const FACILITIES_FROM_ZOOM = 11;
    const FACILITY_TIERS = Array.from(new Set(FACILITY_KINDS.map(function (k) { return k[2]; })));
    // Material Design Icons (@mdi/js 7.4.47, the set the app's own icon font
    // comes from), as 24-unit SVG paths. Drawn here rather than taken from
    // the basemap's sprite: each provider's sprite names its icons its own
    // way, and CARTO's has none of these, which leaves every facility the
    // same blank disc.
    const FACILITY_ICONS = {
      mdiInformation: 'M13,9H11V7H13M13,17H11V11H13M12,2A10,10 0 0,0 2,12A10,10 0 0,0 12,22A10,10 0 0,0 22,12A10,10 0 0,0 12,2Z',
      mdiParking: 'M13.2,11H10V7H13.2A2,2 0 0,1 15.2,9A2,2 0 0,1 13.2,11M13,3H6V21H10V15H13A6,6 0 0,0 19,9C19,5.68 16.31,3 13,3Z',
      mdiShieldAccount: 'M12,1L3,5V11C3,16.55 6.84,21.74 12,23C17.16,21.74 21,16.55 21,11V5L12,1M12,5A3,3 0 0,1 15,8A3,3 0 0,1 12,11A3,3 0 0,1 9,8A3,3 0 0,1 12,5M17.13,17C15.92,18.85 14.11,20.24 12,20.92C9.89,20.24 8.08,18.85 6.87,17C6.53,16.5 6.24,16 6,15.47C6,13.82 8.71,12.47 12,12.47C15.29,12.47 18,13.79 18,15.47C17.76,16 17.47,16.5 17.13,17Z',
      mdiHomeRoof: 'M19 16H22L12 7L2 16H5L12 9.69L19 16M7 8.81V7H4V11.5L7 8.81Z',
      mdiTableFurniture: 'M2 7H22V10H20L21 19H18.5L17.94 14H6.06L5.5 19H3L4 10H2V7M17.5 10H6.5L6.29 12H17.71L17.5 10Z',
      mdiBinoculars: 'M11,6H13V13H11V6M9,20A1,1 0 0,1 8,21H5A1,1 0 0,1 4,20V15L6,6H10V13A1,1 0 0,1 9,14V20M10,5H7V3H10V5M15,20V14A1,1 0 0,1 14,13V6H18L20,15V20A1,1 0 0,1 19,21H16A1,1 0 0,1 15,20M14,5V3H17V5H14Z',
      mdiSignDirection: 'M11,12H3.5L6,9.5L3.5,7H11V3L12,2L13,3V7H18L20.5,9.5L18,12H13V20A2,2 0 0,1 15,22H9A2,2 0 0,1 11,20V12Z',
      mdiTent: 'M4,6C4,7.19 4.39,8.27 5,9A3,3 0 0,1 2,6A3,3 0 0,1 5,3C4.39,3.73 4,4.81 4,6M2,21V19H4.76L12,4.78L19.24,19H22V21H2M12,9.19L7,19H17L12,9.19Z',
      mdiToilet: 'M9,22H17V19.5C19.41,17.87 21,15.12 21,12V4A2,2 0 0,0 19,2H15C13.89,2 13,2.9 13,4V12H3C3,15.09 5,18 9,19.5V22M5.29,14H18.71C18.14,15.91 16.77,17.5 15,18.33V20H11V18.33C9,18 5.86,15.91 5.29,14M15,4H19V12H15V4M16,5V8H18V5H16Z',
      mdiWater: 'M12,20A6,6 0 0,1 6,14C6,10 12,3.25 12,3.25C12,3.25 18,10 18,14A6,6 0 0,1 12,20Z',
      mdiGrill: 'M8.06,2C7.88,3.17 8.17,4.16 8.95,4.97C9.45,5.47 9.61,6.14 9.42,7H10.41C10.53,6.45 10.55,6 10.45,5.55C10.36,5.13 10.05,4.63 9.5,4.03C9.05,3.47 8.89,2.8 9.05,2H8.06M10.55,2C10.36,3.17 10.66,4.16 11.44,4.97C11.94,5.47 12.09,6.14 11.91,7H12.89C13,6.45 13.03,6 12.94,5.55C12.84,5.13 12.53,4.63 12,4.03C11.53,3.47 11.38,2.8 11.53,2H10.55M13.08,2C12.89,3.17 13.19,4.16 13.97,4.97C14.47,5.47 14.61,6.14 14.39,7H15.42C15.55,6.45 15.56,6 15.47,5.55C15.38,5.13 15.06,4.63 14.53,4.03C14.06,3.47 13.91,2.8 14.06,2H13.08M5,8C5,9.42 5.39,10.7 6.14,11.84C6.87,12.96 7.91,13.85 9.14,14.39L5.16,20.44C5.06,20.56 5,20.75 5,21C5,21.41 5.16,21.69 5.44,21.84C5.56,21.94 5.75,22 6,22C6.41,22 6.69,21.84 6.84,21.56L7.83,19.97H14.2C14.41,20.55 14.79,21.05 15.28,21.42C15.78,21.8 16.36,22 17,22C17.83,22 18.53,21.69 19.13,21.09C19.72,20.5 20,19.8 20,19C20,18.17 19.72,17.47 19.13,16.88C18.53,16.28 17.83,16 17,16C16.36,16 15.78,16.17 15.28,16.55C14.78,16.92 14.42,17.41 14.2,18H9.14L11.11,14.95C11.27,15 11.56,15 12,15C12.44,15 12.73,15 12.89,14.95L13.88,16.5C14.29,15.96 14.84,15.54 15.47,15.28L14.91,14.39C16.03,13.89 17,13 17.79,11.77C18.59,10.5 19,9.27 19,8H5M17,18C17.3,18 17.53,18.09 17.72,18.28C17.91,18.47 18,18.72 18,19C18,19.27 17.91,19.5 17.72,19.71C17.54,19.91 17.28,20 17,20C16.74,20 16.5,19.91 16.29,19.71C16.09,19.5 16,19.26 16,19C16,18.7 16.09,18.47 16.29,18.28C16.5,18.09 16.73,18 17,18Z',
      mdiBench: 'M23 13H1V15H3V19H5V15H19V19H21V15H23V13Z',
    };
    const FACILITY_IMAGE_PREFIX = 'polo-facility-';

    // A facility's icon, drawn the first time the map asks for it — after a
    // style swap too, which throws registered images away.
    map.on('styleimagemissing', function (e) {
      if (e.id.indexOf(FACILITY_IMAGE_PREFIX) !== 0 || map.hasImage(e.id)) return;
      const path = FACILITY_ICONS[e.id.slice(FACILITY_IMAGE_PREFIX.length)];
      if (!path) return;
      try {
        const canvas = document.createElement('canvas');
        canvas.width = canvas.height = 44;
        const ctx = canvas.getContext('2d');
        ctx.beginPath();
        ctx.arc(22, 22, 20.5, 0, 2 * Math.PI);
        ctx.fillStyle = '#ffffff';
        ctx.fill();
        ctx.lineWidth = 2;
        ctx.strokeStyle = '#9e9e9e';
        ctx.stroke();
        ctx.fillStyle = '#725a50';
        ctx.translate(8, 8);
        ctx.scale(28 / 24, 28 / 24);
        ctx.fill(new Path2D(path));
        map.addImage(e.id, ctx.getImageData(0, 0, 44, 44), { pixelRatio: 2 });
      } catch (err) {
        report('image-failed', 'could not draw facility icon ' + e.id + ': ' + ((err && err.message) || err));
      }
    });

    // The basemap's own first label layer: imagery and boundary lines go
    // under it, so place names stay legible over a photo.
    function firstLabelLayerId() {
      const layer = map.getStyle().layers.find(function (l) { return l.type === 'symbol' && l.id.indexOf('polo-') !== 0; });
      return layer && layer.id;
    }

    // What the host's own layers sit on — overlays go under the first of them.
    function firstHostLayerId() {
      return map.getLayer('polo-shapes-dashed') ? 'polo-shapes-dashed' : undefined;
    }

    // A label font the basemap's glyph server actually has: each provider
    // names its own, and a font it lacks draws no text at all.
    function styleFont() {
      const layer = map.getStyle().layers.find(function (l) {
        const font = l.type === 'symbol' && l.layout && l.layout['text-font'];
        return Array.isArray(font) && font.length && font.every(function (f) { return typeof f === 'string'; });
      });
      return layer ? layer.layout['text-font'] : ['Noto Sans Regular'];
    }

    // The vector source the basemap draws its boundaries from — OpenFreeMap
    // and CARTO both use the OpenMapTiles schema, under different names.
    function boundarySource() {
      const layer = map.getStyle().layers.find(function (l) { return l['source-layer'] === 'boundary'; });
      return layer && layer.source;
    }

    // The names of the grid cells covering the view: a field (20°×10°,
    // `FN`), a block (4°×2°, `FN20-31`) or a square (2°×1°, `FN31`) — the
    // names services.ham2k.net's bundles go by.
    function cellsInView(scale) {
      const size = { field: [20, 10], block: [4, 2], square: [2, 1] }[scale];
      const bounds = map.getBounds();
      const west = Math.max(bounds.getWest(), -180), east = Math.min(bounds.getEast(), 179.999);
      const south = Math.max(bounds.getSouth(), -90), north = Math.min(bounds.getNorth(), 89.999);
      const letter = function (n) { return String.fromCharCode(65 + n); };
      const cells = [];
      for (let x = Math.floor((west + 180) / size[0]); x <= Math.floor((east + 180) / size[0]); x++) {
        for (let y = Math.floor((south + 90) / size[1]); y <= Math.floor((north + 90) / size[1]); y++) {
          if (scale === 'field') { cells.push(letter(x) + letter(y)); continue; }
          const lon = x * size[0], lat = y * size[1];
          const field = letter(Math.floor(lon / 20)) + letter(Math.floor(lat / 10));
          const lonDigit = Math.floor((lon % 20) / 2), latDigit = lat % 10;
          cells.push(scale === 'square' ? field + lonDigit + latDigit : field + lonDigit + latDigit + '-' + (lonDigit + 1) + (latDigit + 1));
        }
      }
      return cells;
    }

    // Through the host's `window.poloFetchText` where it sets one: the
    // webview's page is served from an origin services.ham2k.net does not
    // answer cross-origin requests for, and the app's own client has no
    // origin to refuse. Null for a 4xx: a cell with no bundle is a cell with
    // nothing in it (ocean, a country no dataset covers), not a failure.
    function fetchText(url) {
      if (window.poloFetchText) return window.poloFetchText(url);
      return fetch(url).then(function (r) {
        if (r.status >= 400 && r.status < 500) return null;
        return r.ok ? r.text() : Promise.reject(new Error('HTTP ' + r.status));
      });
    }

    function fetchBundle(url) {
      let fetching = bundleFetches.get(url);
      if (fetching) {
        bundleFetches.delete(url);
      } else {
        fetching = fetchText(url)
          .then(function (text) { return text === null ? [] : JSON.parse(text).features || []; })
          .catch(function (err) {
            bundleFetches.delete(url);
            report('overlay-failed', url + ': ' + ((err && err.message) || err));
            return [];
          });
      }
      bundleFetches.set(url, fetching);
      while (bundleFetches.size > BUNDLES_KEPT) bundleFetches.delete(bundleFetches.keys().next().value);
      return fetching;
    }

    function setLayerVisible(id, visible) {
      if (map.getLayer(id)) map.setLayoutProperty(id, 'visibility', visible ? 'visible' : 'none');
    }

    // The tiles URL the imagery source on screen was made with — a style
    // swap takes the source with it, which the getSource check catches.
    let imageryTiles = null;

    function applyImagery() {
      const imagery = overlays && overlays.imagery;
      const source = map.getSource('polo-imagery');
      if (source && imagery && imageryTiles === imagery.tiles) return;
      if (map.getLayer('polo-imagery')) map.removeLayer('polo-imagery');
      if (source) map.removeSource('polo-imagery');
      imageryTiles = null;
      if (!imagery) return;
      imageryTiles = imagery.tiles;
      map.addSource('polo-imagery', { type: 'raster', tiles: [imagery.tiles], tileSize: 256, maxzoom: imagery.maxzoom, attribution: imagery.attribution });
      map.addLayer({ id: 'polo-imagery', type: 'raster', source: 'polo-imagery' }, imageryBeforeId());
    }

    // Under the bold boundary lines as well as the labels, whichever comes
    // first: added after them, the photo would cover them.
    function imageryBeforeId() {
      const layer = map.getStyle().layers.find(function (l) {
        return BOUNDARY_LAYERS.indexOf(l.id) >= 0 || l.id === 'polo-region-counties' || (l.type === 'symbol' && l.id.indexOf('polo-') !== 0);
      });
      return layer && layer.id;
    }

    // Boundaries: the basemap's own country and state lines, redrawn bold
    // in one colour in place of its faint ones, plus the regions bundles'
    // county lines and state and county names.
    // [text] as the attribution control's credit for the source [id]. The
    // control reads a source's attribution only when the source is made, or
    // when told its metadata changed — and takes HTML, so the text is escaped.
    // A source no visible layer draws is left out of the control by
    // MapLibre itself.
    function setCredit(id, text) {
      const source = map.getSource(id);
      if (!source) return;
      const credit = (text || '').replace(/[&<>"']/g, function (c) { return '&#' + c.charCodeAt(0) + ';'; });
      if ((source.attribution || '') === credit) return;
      source.attribution = credit || undefined;
      map.fire('sourcedata', { dataType: 'source', sourceDataType: 'metadata', sourceId: id });
    }

    function applyBoundaries() {
      const boundaries = overlays && overlays.boundaries;
      const colors = overlays && overlays.dark ? { line: '#c4a1ff', halo: '#1c1c22' } : { line: '#7e22ce', halo: '#ffffff' };
      const vector = boundarySource();
      if (vector && !map.getLayer('polo-boundary-countries')) {
        const level = ['get', 'admin_level'];
        const land = [['!=', ['get', 'maritime'], 1], ['!=', ['get', 'disputed'], 1]];
        const zoomed = function () { return ['interpolate', ['linear'], ['zoom']].concat(Array.from(arguments)); };
        const line = function (id, filter, width, minzoom, dashed) {
          const paint = { 'line-color': colors.line, 'line-width': width, 'line-opacity': 0.8 };
          if (dashed) paint['line-dasharray'] = [3, 2];
          return { id: id, type: 'line', source: vector, 'source-layer': 'boundary', minzoom: minzoom, filter: ['all'].concat(filter, land), layout: { 'line-join': 'round', visibility: 'none' }, paint: paint };
        };
        const before = firstLabelLayerId();
        map.addLayer(line('polo-boundary-counties', [['>=', level, 5], ['<=', level, 6]], zoomed(9, 0.9, 12, 1.5), 9, true), before);
        map.addLayer(line('polo-boundary-states', [['>=', level, 3], ['<=', level, 4]], zoomed(3, 0.8, 8, 1.8, 12, 2.6), 0, false), before);
        map.addLayer(line('polo-boundary-countries', [['==', level, 2]], zoomed(2, 1.6, 6, 2.8, 12, 4.5), 0, false), before);
      }
      if (!map.getSource('polo-regions')) {
        map.addSource('polo-regions', { type: 'geojson', data: { type: 'FeatureCollection', features: regionFeatures } });
        const of = function (kind, level) { return ['all', ['==', ['get', 'kind'], kind], ['==', ['get', 'level'], level]]; };
        const text = function (size) {
          return { visibility: 'none', 'text-field': ['get', 'name'], 'text-font': styleFont(), 'text-size': size, 'text-max-width': 8, 'symbol-sort-key': ['-', 0, ['get', 'areaKm2']] };
        };
        map.addLayer({ id: 'polo-region-counties', type: 'line', source: 'polo-regions', minzoom: 6, maxzoom: 9, filter: of('boundary', 2),
          layout: { 'line-join': 'round', visibility: 'none' },
          paint: { 'line-color': colors.line, 'line-width': ['interpolate', ['linear'], ['zoom'], 6, 0.6, 9, 0.9], 'line-opacity': 0.6, 'line-dasharray': [3, 2] } }, firstLabelLayerId());
        const labelPaint = { 'text-color': colors.line, 'text-halo-color': colors.halo, 'text-halo-width': 1.5, 'text-opacity': 0.85 };
        map.addLayer({ id: 'polo-region-labels-states', type: 'symbol', source: 'polo-regions', minzoom: 3, filter: of('label', 1),
          layout: Object.assign(text(12), { 'text-transform': 'uppercase', 'text-letter-spacing': 0.08 }), paint: labelPaint }, firstHostLayerId());
        map.addLayer({ id: 'polo-region-labels-counties', type: 'symbol', source: 'polo-regions', minzoom: 7.5, filter: of('label', 2),
          layout: text(11), paint: labelPaint }, firstHostLayerId());
      }
      BOUNDARY_LAYERS.forEach(function (id) { if (map.getLayer(id)) map.setPaintProperty(id, 'line-color', colors.line); });
      if (map.getLayer('polo-region-counties')) map.setPaintProperty('polo-region-counties', 'line-color', colors.line);
      ['polo-region-labels-states', 'polo-region-labels-counties'].forEach(function (id) {
        if (!map.getLayer(id)) return;
        map.setPaintProperty(id, 'text-color', colors.line);
        map.setPaintProperty(id, 'text-halo-color', colors.halo);
      });
      if (boundaries) setCredit('polo-regions', boundaries.attribution);
      BOUNDARY_LAYERS.concat(REGION_LAYERS).forEach(function (id) { setLayerVisible(id, !!boundaries); });
      // The basemap's own boundary lines step aside for the bold ones.
      map.getStyle().layers.forEach(function (l) {
        if (l['source-layer'] === 'boundary' && l.id.indexOf('polo-') !== 0) setLayerVisible(l.id, !boundaries);
      });
    }

    function applyFacilities() {
      const facilities = overlays && overlays.facilities;
      if (!map.getSource('polo-facilities')) {
        map.addSource('polo-facilities', { type: 'geojson', data: { type: 'FeatureCollection', features: facilityFeatures } });
        const kind = ['get', 'kind'];
        const icon = ['match', kind].concat(FACILITY_KINDS.reduce(function (all, k) { return all.concat([k[0], FACILITY_IMAGE_PREFIX + k[1]]); }, []), [FACILITY_IMAGE_PREFIX + 'mdiInformation']);
        FACILITY_TIERS.slice().reverse().forEach(function (tier) {
          map.addLayer({
            id: 'polo-facilities-' + tier, type: 'symbol', source: 'polo-facilities', minzoom: tier,
            filter: ['in', kind, ['literal', FACILITY_KINDS.filter(function (k) { return k[2] === tier; }).map(function (k) { return k[0]; })]],
            layout: {
              visibility: 'none', 'icon-image': icon,
              'text-field': ['coalesce', ['get', 'name'], ''], 'text-font': styleFont(), 'text-size': 11,
              'text-offset': [0, 1.1], 'text-anchor': 'top', 'text-optional': true, 'text-max-width': 8,
            },
            paint: { 'text-halo-width': 1.2 },
          }, firstHostLayerId());
        });
      }
      if (facilities) setCredit('polo-facilities', facilities.attribution);
      FACILITY_TIERS.forEach(function (tier) {
        const id = 'polo-facilities-' + tier;
        setLayerVisible(id, !!facilities);
        if (!map.getLayer(id)) return;
        map.setPaintProperty(id, 'text-color', overlays && overlays.dark ? '#e8e8e8' : '#3a3a3a');
        map.setPaintProperty(id, 'text-halo-color', overlays && overlays.dark ? '#1c1c22' : '#ffffff');
      });
    }

    // The bundles for the cells in view, for each overlay that is on and
    // close enough in to draw — latest-wins, so a slow answer for a view
    // already left never lands over the current one.
    function refreshOverlayData() {
      if (!overlays) return;
      const zoom = map.getZoom();
      if (overlays.boundaries && zoom >= 3) {
        const request = ++regionsRequest;
        const base = overlays.boundaries.base;
        Promise.all(cellsInView(zoom < 6 ? 'field' : 'block').map(function (cell) { return fetchBundle(base + cell + '.geojson'); })).then(function (all) {
          if (request !== regionsRequest) return;
          regionFeatures = [].concat.apply([], all);
          const source = map.getSource('polo-regions');
          if (source) source.setData({ type: 'FeatureCollection', features: regionFeatures });
        });
      }
      if (overlays.facilities && zoom >= FACILITIES_FROM_ZOOM) {
        const request = ++facilitiesRequest;
        const base = overlays.facilities.base;
        Promise.all(cellsInView('square').map(function (cell) { return fetchBundle(base + cell + '.geojson'); })).then(function (all) {
          if (request !== facilitiesRequest) return;
          facilityFeatures = [].concat.apply([], all);
          const source = map.getSource('polo-facilities');
          if (source) source.setData({ type: 'FeatureCollection', features: facilityFeatures });
        });
      }
    }
    map.on('moveend', function () {
      try { refreshOverlayData(); } catch (err) { report('deferred-update', 'overlay refresh failed: ' + ((err && err.message) || err)); }
    });

    // Like the data setters, but with no pending slot of its own: a call
    // that lands before the style has parsed is put up by the style's own
    // load, which restoreAfterStyle and the 'load' listener below share.
    function applyOverlays() {
      if (!overlays || styleSwapInFlight) return;
      try {
        applyImagery();
        applyBoundaries();
        applyFacilities();
      } catch (err) {
        // addSource/addLayer throw while the style is still parsing, and its
        // load puts the overlays up then. Past that, a throw is a defect.
        if (styleLoaded) report('deferred-update', 'overlays failed: ' + ((err && err.message) || err));
        return;
      }
      refreshOverlayData();
    }
    // After the listener above that sets styleLoaded. A swap's own load is
    // left to its handler (restoreAfterStyle), which runs after this one.
    map.on('style.load', function () {
      try { applyOverlays(); } catch (err) { report('deferred-update', 'overlays failed: ' + ((err && err.message) || err)); }
    });

    function setOverlays(data) {
      overlays = data;
      applyOverlays();
    }
''';

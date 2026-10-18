// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The part of map_gl_script.dart's `create` that draws the Show Callsigns
// pills — spliced into it verbatim, so it runs in the same closure and reads
// the same `map` and `report`.

import 'map_marker_data.dart' show mapMarkerFullAtZoom, mapMarkerSmallAtZoom, mapPillSmallScale;

/// See map_gl_script.dart's `mapGlScript`, which includes this text whole.
const mapGlPillScript =
    '''
    // A marker with a label colour (map_marker_data.dart's
    // MapMarkerData.labelColor): its label on a pill, drawn into an image of
    // its own — call and pill one picture. A symbol layer with the call as
    // text over a pill icon cannot stack: MapLibre draws a layer's icons and
    // then all of its text, so wherever pills overlap, every call shows
    // through every pill above it. Drawn in the system font, so the calls
    // need nothing from the style's glyph server.
    const PILL_TEXT_SIZE = 12;
    const PILL_PAD_X = 6;
    const PILL_PAD_Y = 2;
    const PILL_RING = 1.5;
    // The device's own density, so the call is not upscaled on a dense
    // screen — but never under the 2x an Operation Postcard is taken at.
    const PILL_RATIO = Math.min(Math.max(Math.ceil(window.devicePixelRatio || 1), 2), 3);
    const PILL_FONT = '700 ' + PILL_TEXT_SIZE + 'px system-ui, -apple-system, "Segoe UI", Roboto, sans-serif';
    let pillCanvas = null;
    // The pill images the markers last drew with, so the ones no marker uses
    // any more are released: the current QSO's call changes with every
    // keystroke, and each spelling would otherwise stay registered.
    let pillImages = new Set();

    function pillImageId(m) {
      return 'polo-pill-' + m.color + m.strokeColor + m.labelColor + '-' + m.label;
    }

    function ensurePillImage(m) {
      const id = pillImageId(m);
      if (map.hasImage(id)) return id;
      if (!pillCanvas) pillCanvas = document.createElement('canvas');
      const ctx = pillCanvas.getContext('2d');
      if (!ctx) throw new Error('no 2D canvas context to draw pills on');
      ctx.font = PILL_FONT;
      const metrics = ctx.measureText(m.label);
      const h = Math.ceil(PILL_TEXT_SIZE * 1.2 + 2 * PILL_PAD_Y);
      const w = Math.max(Math.ceil(metrics.width + 2 * PILL_PAD_X), h);
      // Resizing the canvas clears it and resets the context, font included.
      pillCanvas.width = w * PILL_RATIO;
      pillCanvas.height = h * PILL_RATIO;
      ctx.setTransform(PILL_RATIO, 0, 0, PILL_RATIO, 0, 0);
      // Inset by half the ring, which straddles the outline.
      const inset = PILL_RING / 2;
      const r = h / 2 - inset;
      ctx.beginPath();
      ctx.moveTo(h / 2, inset);
      ctx.lineTo(w - h / 2, inset);
      ctx.arc(w - h / 2, h / 2, r, -Math.PI / 2, Math.PI / 2);
      ctx.lineTo(h / 2, h - inset);
      ctx.arc(h / 2, h / 2, r, Math.PI / 2, Math.PI * 3 / 2);
      ctx.closePath();
      ctx.fillStyle = m.color;
      ctx.fill();
      ctx.lineWidth = PILL_RING;
      ctx.strokeStyle = m.strokeColor;
      ctx.stroke();
      ctx.font = PILL_FONT;
      ctx.fillStyle = m.labelColor;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'alphabetic';
      // Centred on the ink, not the line box: a call is capitals and
      // digits, which sit high in a line box that leaves room for descenders.
      const ascent = metrics.actualBoundingBoxAscent || PILL_TEXT_SIZE * 0.7;
      const descent = metrics.actualBoundingBoxDescent || 0;
      ctx.fillText(m.label, w / 2, h / 2 + (ascent - descent) / 2);
      map.addImage(id, ctx.getImageData(0, 0, pillCanvas.width, pillCanvas.height), { pixelRatio: PILL_RATIO });
      return id;
    }

    // [m]'s feature in the pills' source, its image named in [used] — or null
    // when the pill could not be drawn, and the marker falls back to the
    // plain circle, as a glyph that cannot register does.
    function pillFeature(m, geometry, used) {
      let image;
      try {
        image = ensurePillImage(m);
      } catch (err) {
        report('image-failed', 'could not draw the pill for ' + m.label + ': ' + ((err && err.message) || err));
        return null;
      }
      used.add(image);
      return {
        type: 'Feature',
        properties: { id: m.id, steady: m.steady === true, highlight: m.highlight === true, fades: m.fades === true, image: image },
        geometry: geometry,
      };
    }

    // The log's pills as last sent. The current QSO's pill has a source of its
    // own, so a keystroke — which moves only that one — leaves these alone:
    // MapLibre copies every image a tile names each time it parses the tile,
    // and at a low zoom one tile names every pill in the log.
    let basePillsSent = null;

    function setPills(features) {
      const base = features.filter(function (f) { return !f.properties.highlight; });
      const sent = JSON.stringify(base);
      if (sent !== basePillsSent) {
        map.getSource('polo-marker-pills').setData({ type: 'FeatureCollection', features: base });
        basePillsSent = sent;
      }
      map.getSource('polo-marker-pills-highlight').setData({
        type: 'FeatureCollection',
        features: features.filter(function (f) { return f.properties.highlight; }),
      });
    }

    function releasePillImages(used) {
      pillImages.forEach(function (id) {
        if (!used.has(id) && map.hasImage(id)) map.removeImage(id);
      });
      pillImages = used;
    }

    function pillLayer(id, highlight) {
      return {
        id: id,
        type: 'symbol',
        source: highlight ? 'polo-marker-pills-highlight' : 'polo-marker-pills',
        layout: {
          'icon-image': ['get', 'image'],
          // Shrinks less than a dot does (mapPillSmallScale): a call drawn
          // at half size is no longer one anyone can read.
          'icon-size': ['interpolate', ['linear'], ['zoom'], $mapMarkerSmallAtZoom, $mapPillSmallScale, $mapMarkerFullAtZoom, 1],
          // Every contact drawn, however crowded — a collision-placed pill
          // would take the contact itself off the map.
          'icon-allow-overlap': true,
          'icon-ignore-placement': true,
          // As iconLayer's: the host's order, smaller signals on top.
          'symbol-z-order': 'source',
        },
      };
    }
''';

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The part of map_gl_script.dart's `create` that defines the line, shape,
// leader, marker and icon layers — spliced into it verbatim, so it runs in
// the same closure. `leaderLayers` reads `SPREAD_FROM_ZOOM`, a `const` the
// spread piece (map_gl_spread_script.dart) declares further down: nothing
// may call it before that piece has run, or the read throws.

import 'map_marker_data.dart' show mapMarkerFullAtZoom, mapMarkerSmallAtZoom, mapMarkerSmallScale;

/// See map_gl_script.dart's `mapGlScript`, which includes this text whole.
const mapGlLayersScript =
    '''
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
    // area without hiding the terrain the activator is standing on. A trail
    // or river gets the edge alone: the fill is kept to polygons, so a line
    // is never closed into an area. A dashed shape — a suggestion nobody has
    // picked — is an edge alone, in its own layer first so it sits under
    // every solid one (line-dasharray cannot be set per feature).
    const DASHED_OPACITY = 0.8;
    const FILL_OPACITY = 0.18;
    const EDGE_OPACITY = 0.9;

    function shapeLayers() {
      return [
        {
          id: 'polo-shapes-dashed',
          type: 'line',
          source: 'polo-shapes',
          filter: ['==', ['get', 'dashed'], true],
          // Round caps on zero-length dashes are what make the dots: a
          // suggestion's edge is context, and any length of dash reads as a
          // boundary of its own.
          layout: { 'line-cap': 'round' },
          paint: {
            'line-color': ['coalesce', ['get', 'color'], '#000000'],
            'line-width': 1.25,
            'line-opacity': DASHED_OPACITY,
            // In line widths: a dot, then two widths of gap.
            'line-dasharray': [0, 2],
          },
        },
        {
          id: 'polo-shapes-fill',
          type: 'fill',
          source: 'polo-shapes',
          filter: ['all', ['==', ['geometry-type'], 'Polygon'], ['!=', ['get', 'dashed'], true]],
          paint: {
            'fill-color': ['coalesce', ['get', 'color'], '#000000'],
            'fill-opacity': FILL_OPACITY,
          },
        },
        {
          id: 'polo-shapes-outline',
          type: 'line',
          source: 'polo-shapes',
          filter: ['!=', ['get', 'dashed'], true],
          paint: {
            'line-color': ['coalesce', ['get', 'color'], '#000000'],
            'line-width': 2,
            'line-opacity': EDGE_OPACITY,
          },
        },
      ];
    }

    // Every marker shrinks as the map zooms out (map_marker_data.dart's
    // mapMarkerSmallAtZoom): a zoom expression, so the size follows a pinch
    // frame by frame.
    function scaledWithZoom(size) {
      return ['interpolate', ['linear'], ['zoom'],
        $mapMarkerSmallAtZoom, typeof size === 'number' ? size * $mapMarkerSmallScale : ['*', size, $mapMarkerSmallScale],
        $mapMarkerFullAtZoom, size];
    }

    // A spread marker's true place (setSpread): a small dot there, and a line
    // from it to the marker — shown as the markers part, from SPREAD_FROM_ZOOM.
    function leaderLayers() {
      const showing = ['interpolate', ['linear'], ['zoom'], SPREAD_FROM_ZOOM, 0, SPREAD_FROM_ZOOM + 0.5, 0.9];
      return [
        {
          id: 'polo-leader-lines',
          type: 'line',
          source: 'polo-leaders',
          filter: ['==', ['geometry-type'], 'LineString'],
          layout: { 'line-cap': 'round' },
          paint: { 'line-color': ['coalesce', ['get', 'color'], '#000000'], 'line-width': 3, 'line-opacity': showing },
        },
        {
          id: 'polo-leader-dots',
          type: 'circle',
          source: 'polo-leaders',
          filter: ['==', ['geometry-type'], 'Point'],
          paint: {
            // With the stroke, SPREAD_DOT across from the centre.
            'circle-radius': 3.5,
            'circle-color': ['coalesce', ['get', 'color'], '#000000'],
            'circle-stroke-width': 1,
            'circle-stroke-color': ['coalesce', ['get', 'strokeColor'], '#ffffff'],
            'circle-opacity': showing,
            'circle-stroke-opacity': showing,
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
          'circle-radius': scaledWithZoom(['get', 'radius']),
          'circle-color': ['coalesce', ['get', 'color'], '#000000'],
          'circle-stroke-width': scaledWithZoom(['get', 'strokeWidth']),
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
          'icon-size': scaledWithZoom(1),
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
''';

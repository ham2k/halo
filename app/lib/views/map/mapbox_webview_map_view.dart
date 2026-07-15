// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Mapbox backend for desktop (macOS today; Windows/Linux structurally
// supported by flutter_inappwebview but not yet scaffolded/verified in this
// project — see DESIGN.md §11). No official Mapbox Flutter SDK covers
// desktop, so this loads Mapbox GL JS (which does support globe projection)
// into a webview, bridged to Dart for marker/line data in and load/error
// status out via `window.flutter_inappwebview.callHandler`.
//
// QSOs are band-colored circle divs, the QTH a black one, connected by
// great-circle lines in a GeoJSON layer (pre-densified by the facade).
// Clicking a circle opens a mapboxgl.Popup with the QSO's details, styled
// to match the Flutter backends' MapPopupCard.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../config/mapbox_token.dart';
import 'map_marker_data.dart';

class MapboxWebviewMapView extends StatefulWidget {
  final List<MapMarkerData> markers;
  final List<MapLineData> lines;
  final MapProjection projection;

  const MapboxWebviewMapView({
    super.key,
    required this.markers,
    this.lines = const [],
    required this.projection,
  });

  @override
  State<MapboxWebviewMapView> createState() => _MapboxWebviewMapViewState();
}

class _MapboxWebviewMapViewState extends State<MapboxWebviewMapView> {
  InAppWebViewController? _controller;
  bool _mapReady = false;

  @override
  void didUpdateWidget(MapboxWebviewMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_mapReady) return;
    if (oldWidget.projection != widget.projection) _applyProjection();
    if (!listEquals(oldWidget.markers, widget.markers)) _applyMarkers();
    if (!listEquals(oldWidget.lines, widget.lines)) _applyLines();
  }

  Future<void> _applyProjection() async {
    await _controller?.evaluateJavascript(
      source: "window.poloSetProjection('${widget.projection.name}');",
    );
  }

  static String _hex(Color color) => '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

  Future<void> _applyMarkers() async {
    final data = jsonEncode([
      for (final m in widget.markers)
        {
          'id': m.id,
          'latitude': m.latitude,
          'longitude': m.longitude,
          'label': m.label,
          'kind': m.kind.name,
          'color': _hex(m.color),
          'sizeFactor': m.sizeFactor,
          'popupTitle': m.popupTitle,
          'popupDetailPrefix': m.popupDetailPrefix,
          'popupBand': m.popupBand,
          'popupDetailSuffix': m.popupDetailSuffix,
        },
    ]);
    await _controller?.evaluateJavascript(source: 'window.poloSetMarkers($data);');
  }

  Future<void> _applyLines() async {
    // Opacity travels separately — GL line-paint colors don't carry alpha.
    final opacity = widget.lines.isEmpty ? 1.0 : (widget.lines.first.color.a).clamp(0.0, 1.0);
    final data = jsonEncode({
      'opacity': opacity,
      'features': [
        for (final line in widget.lines)
          {
            'type': 'Feature',
            'properties': {'color': _hex(line.color)},
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                for (final p in line.points) [p.longitude, p.latitude],
              ],
            },
          },
      ],
    });
    await _controller?.evaluateJavascript(source: 'window.poloSetLines($data);');
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialData: InAppWebViewInitialData(
        data: _html(mapboxAccessToken),
        baseUrl: WebUri('https://ham2k.com/'),
      ),
      initialSettings: InAppWebViewSettings(transparentBackground: true),
      onConsoleMessage: (controller, message) => debugPrint('[map-webview] ${message.message}'),
      onWebViewCreated: (controller) {
        _controller = controller;
        controller.addJavaScriptHandler(
          handlerName: 'poloMapReady',
          callback: (args) {
            _mapReady = true;
            _applyProjection();
            _applyMarkers();
            _applyLines();
            return null;
          },
        );
      },
    );
  }

  static String _html(String token) => '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="initial-scale=1,maximum-scale=1,user-scalable=no" />
  <script src="https://api.mapbox.com/mapbox-gl-js/v3.9.0/mapbox-gl.js"></script>
  <link href="https://api.mapbox.com/mapbox-gl-js/v3.9.0/mapbox-gl.css" rel="stylesheet" />
  <style>
    body, html, #map { margin: 0; padding: 0; height: 100%; width: 100%; }
    .polo-circle {
      border-radius: 50%;
      border: 1.5px solid rgba(0, 0, 0, 0.87);
      box-sizing: border-box;
      cursor: pointer;
    }
    .polo-circle-qth { border: 2px solid white; }
    .polo-popup { font: 13px Roboto, sans-serif; color: #333; }
    .polo-popup .title { font-weight: 700; }
    .polo-popup .band { font-weight: 700; }
    .mapboxgl-popup-content { padding: 6px 10px; border-radius: 8px; }
  </style>
</head>
<body>
  <div id="map"></div>
  <script>
    mapboxgl.accessToken = '$token';
    const map = new mapboxgl.Map({
      container: 'map',
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
      const title = document.createElement('div');
      title.className = 'title';
      title.textContent = m.popupTitle || m.label;
      root.appendChild(title);
      if (m.popupDetailPrefix || m.popupBand || m.popupDetailSuffix) {
        const detail = document.createElement('div');
        detail.appendChild(document.createTextNode(m.popupDetailPrefix));
        const band = document.createElement('span');
        band.className = 'band';
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

    window.poloSetMarkers = function (data) {
      markers.forEach((m) => m.remove());
      markers = [];
      if (popup) { popup.remove(); popup = null; }
      if (!data.length) return;
      const bounds = new mapboxgl.LngLatBounds();
      data.forEach((m) => {
        const el = document.createElement('div');
        const size = m.kind === 'qth' ? 12 : 14 * (m.sizeFactor || 1);
        el.className = m.kind === 'qth' ? 'polo-circle polo-circle-qth' : 'polo-circle';
        el.style.width = size + 'px';
        el.style.height = size + 'px';
        el.style.background = m.color;
        el.title = m.label;
        el.addEventListener('click', (e) => { e.stopPropagation(); showPopup(m); });
        markers.push(new mapboxgl.Marker({ element: el }).setLngLat([m.longitude, m.latitude]).addTo(map));
        bounds.extend([m.longitude, m.latitude]);
      });
      map.fitBounds(bounds, { padding: 48, maxZoom: 11, duration: 0 });
    };

    window.poloSetLines = function (data) {
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
    };

    window.poloSetProjection = function (name) {
      map.setProjection(name);
    };

    map.on('click', function () {
      if (popup) { popup.remove(); popup = null; }
    });

    // Forwarded to Dart's debugPrint via onConsoleMessage — the only signal
    // we get out of this page for "why is the map blank" reports (e.g. an
    // invalid/expired token) without opening real devtools on it.
    map.on('error', function (e) {
      console.log('map error: ' + (e && e.error ? e.error.message : JSON.stringify(e)));
    });

    map.on('load', function () {
      window.flutter_inappwebview.callHandler('poloMapReady');
    });
  </script>
</body>
</html>
''';
}

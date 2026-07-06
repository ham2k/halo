// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Mapbox backend for desktop (macOS today; Windows/Linux structurally
// supported by flutter_inappwebview but not yet scaffolded/verified in this
// project — see DESIGN.md §11). No official Mapbox Flutter SDK covers
// desktop, so this loads Mapbox GL JS (which does support globe projection)
// into a webview, bridged to Dart for marker data in and load/error status
// out via `window.flutter_inappwebview.callHandler`.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../config/mapbox_token.dart';
import 'map_marker_data.dart';

class MapboxWebviewMapView extends StatefulWidget {
  final List<MapMarkerData> markers;
  final MapProjection projection;

  const MapboxWebviewMapView({super.key, required this.markers, required this.projection});

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
    if (oldWidget.markers != widget.markers) _applyMarkers();
  }

  Future<void> _applyProjection() async {
    await _controller?.evaluateJavascript(
      source: "window.poloSetProjection('${widget.projection.name}');",
    );
  }

  Future<void> _applyMarkers() async {
    final data = jsonEncode([
      for (final m in widget.markers)
        {
          'id': m.id,
          'latitude': m.latitude,
          'longitude': m.longitude,
          'label': m.label,
          'kind': m.kind.name,
        },
    ]);
    await _controller?.evaluateJavascript(source: 'window.poloSetMarkers($data);');
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialData: InAppWebViewInitialData(
        data: _html(mapboxAccessToken),
        baseUrl: WebUri('https://ham2k.com/'),
      ),
      initialSettings: InAppWebViewSettings(transparentBackground: true),
      onWebViewCreated: (controller) {
        _controller = controller;
        controller.addJavaScriptHandler(
          handlerName: 'poloMapReady',
          callback: (args) {
            _mapReady = true;
            _applyProjection();
            _applyMarkers();
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
    .polo-marker {
      background: white; border-radius: 4px; padding: 1px 4px;
      font: 700 11px monospace; border: 1px solid #333; white-space: nowrap;
    }
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

    window.poloSetMarkers = function (data) {
      markers.forEach((m) => m.remove());
      markers = [];
      if (!data.length) return;
      const bounds = new mapboxgl.LngLatBounds();
      data.forEach((m) => {
        let marker;
        if (m.kind === 'qth') {
          marker = new mapboxgl.Marker({ color: '#006783' });
        } else {
          const el = document.createElement('div');
          el.className = 'polo-marker';
          el.textContent = m.label;
          marker = new mapboxgl.Marker({ element: el });
        }
        marker.setLngLat([m.longitude, m.latitude]).addTo(map);
        markers.push(marker);
        bounds.extend([m.longitude, m.latitude]);
      });
      map.fitBounds(bounds, { padding: 48, maxZoom: 11, duration: 0 });
    };

    window.poloSetProjection = function (name) {
      map.setProjection(name);
    };

    map.on('load', function () {
      window.flutter_inappwebview.callHandler('poloMapReady');
    });
  </script>
</body>
</html>
''';
}

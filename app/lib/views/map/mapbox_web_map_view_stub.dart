// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Non-web stand-in for MapboxWebMapView — see mapbox_web_map_view.dart.
// Never constructed (map_panel.dart gates on kIsWeb); exists only so
// native builds don't compile the dart:ui_web/package:web implementation.

import 'package:flutter/widgets.dart';

import 'map_marker_data.dart';
import 'map_zoom_controller.dart';

class MapboxWebMapView extends StatelessWidget {
  final List<MapMarkerData> markers;
  final List<MapLineData> lines;
  final MapProjection projection;
  final bool isDark;
  final String styleUrl;
  final String styleUrlDark;
  final MapZoomController? zoomController;
  final ValueChanged<String>? onMarkerTap;

  const MapboxWebMapView(
      {super.key,
      required this.markers,
      this.lines = const [],
      required this.projection,
      required this.isDark,
      required this.styleUrl,
      required this.styleUrlDark,
      this.zoomController,
      this.onMarkerTap});

  @override
  Widget build(BuildContext context) => throw UnsupportedError('MapboxWebMapView is only available on the web');
}

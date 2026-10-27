// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// DEVMAPINFO's readout: where the map's zoom is and how much ground it shows,
// for tuning the zoom thresholds the maps act on (activities_results_map.dart's
// `…FromZoom` constants). A developer tool — not translated, and shown only
// while the setting is on.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../services/settings_service.dart';
import 'map_zoom_controller.dart';

/// The box for the corner holding a map's credit, bottom-right unless the
/// host moves it, placed by the map at [MapInfoBox.right]/[MapInfoBox.bottom]
/// (over the backend's own credit),
/// when [SettingsService.devMapInfo] is on — nothing at all otherwise. [camera] is the backend's last
/// settled report: a notifier rather than a rebuild of the pane, because
/// flutter_map reports every frame of a drag.
class MapInfoBox extends StatelessWidget {
  const MapInfoBox({super.key, required this.settings, required this.camera});

  final SettingsService settings;
  final ValueListenable<MapCameraSettled?> camera;

  /// Where a map puts it: clear of the credit both backends draw along the
  /// bottom edge.
  static const right = Space.sm;
  static const bottom = 36.0;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) {
      if (!settings.devMapInfo) return const SizedBox.shrink();
      final theme = Theme.of(context);
      return IgnorePointer(
        child: Material(
          color: theme.colorScheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs),
            child: ValueListenableBuilder(
              valueListenable: camera,
              builder: (context, settled, _) => Text(
                mapInfoText(settled, miles: settings.distanceUnits == DistanceUnits.miles),
                style: theme.textTheme.bodySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// "z 8.4 · 142 × 98 km": the GL-scale zoom, then the view's width at its
/// middle latitude by its height. Flat-earth arithmetic on the box, which is
/// what a developer reading a threshold needs, and exact enough at any zoom
/// where the thresholds apply.
String mapInfoText(MapCameraSettled? settled, {required bool miles}) {
  if (settled == null) return 'z – · waiting for the map';
  final (:camera, :bounds) = settled;
  const kmPerDegree = 111.32;
  var lonSpan = bounds.east - bounds.west;
  if (lonSpan < 0) lonSpan += 360;
  final midLat = (bounds.south + bounds.north) / 2;
  final widthKm = lonSpan * kmPerDegree * _cosDeg(midLat);
  final heightKm = (bounds.north - bounds.south) * kmPerDegree;
  final factor = miles ? 0.621371 : 1.0;
  String size(double km) {
    final value = km * factor;
    return value < 10 ? value.toStringAsFixed(1) : value.round().toString();
  }

  return 'z ${camera.zoom.toStringAsFixed(1)} · ${size(widthKm)} × ${size(heightKm)} ${miles ? 'mi' : 'km'}';
}

double _cosDeg(double degrees) => math.cos(degrees * math.pi / 180);

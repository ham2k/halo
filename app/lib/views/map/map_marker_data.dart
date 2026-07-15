// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The backend-agnostic contract every Map tab implementation (OSM, Mapbox
// native, Mapbox webview) accepts — built once by the facade
// (map_panel.dart) from `Qso`/`Operation` domain objects via halo_core's
// location resolution and great-circle math, so no backend widget touches
// halo_core's QSO shape directly or re-derives geo math. Markers are plain
// circles (band-colored for QSOs, black for the QTH) per
// ham2k/app-halo-dist#13; lines are pre-densified great-circle polylines,
// already split at the antimeridian.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:halo_core/halo_core.dart' show GridLocation;

enum MapMarkerKind { qso, qth }

enum MapProjection { mercator, globe }

@immutable
class MapMarkerData {
  /// `qso.uuid`, or `'qth-<grid>'` for a station marker — a stable key for
  /// widget/annotation identity and the webview JS bridge.
  final String id;
  final double latitude;
  final double longitude;

  /// Callsign, or the grid for a QTH marker — tooltip/accessibility text.
  final String label;
  final MapMarkerKind kind;

  /// Resolved once by the facade (HaLoColors.bandColor for QSOs, black for
  /// the QTH marker, same as app-polo) so backends never need theme/context
  /// access just to color a circle.
  final Color color;

  /// Signal-strength multiplier for the circle's base radius, 0.7–1.3
  /// (S5 = 1.0, same scaling as app-polo's map).
  final double sizeFactor;

  /// Popup first line, e.g. `AB6GS • 1,042 mi` or `QTH: CM97aa`.
  final String popupTitle;

  /// Popup second line, split in three so backends can color just the band
  /// with [color]: `51 • SSB • ` + `20m` + ` • 20:12z`. The facade owns the
  /// ` • ` separators — parts may be empty, but concatenating the three
  /// verbatim always yields the correct line (empty for QTH markers).
  final String popupDetailPrefix;
  final String popupBand;
  final String popupDetailSuffix;

  const MapMarkerData({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.kind,
    required this.color,
    this.sizeFactor = 1.0,
    this.popupTitle = '',
    this.popupDetailPrefix = '',
    this.popupBand = '',
    this.popupDetailSuffix = '',
  });

  /// Value equality so `didUpdateWidget`/`listEquals` checks can tell a
  /// same-content rebuild from an actual data change, rather than always
  /// seeing a "different" list because the facade rebuilds a fresh one.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MapMarkerData &&
          id == other.id &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          label == other.label &&
          kind == other.kind &&
          color == other.color &&
          sizeFactor == other.sizeFactor &&
          popupTitle == other.popupTitle &&
          popupDetailPrefix == other.popupDetailPrefix &&
          popupBand == other.popupBand &&
          popupDetailSuffix == other.popupDetailSuffix);

  @override
  int get hashCode => Object.hash(id, latitude, longitude, label, kind, color, sizeFactor, popupTitle,
      popupDetailPrefix, popupBand, popupDetailSuffix);
}

/// One contiguous polyline of a QSO's great-circle arc back to its QTH —
/// a single QSO contributes two of these when the arc crosses the
/// antimeridian (see halo_core's greatCirclePoints).
@immutable
class MapLineData {
  /// `<qso.uuid>/<segment index>` — stable identity, same role as
  /// [MapMarkerData.id].
  final String id;
  final List<GridLocation> points;
  final Color color;

  const MapLineData({required this.id, required this.points, required this.color});

  /// The interior points are a pure function of the endpoints (see
  /// greatCirclePoints), so comparing id + color + length + endpoints is
  /// equivalent to a deep compare — without the O(points) scan that would
  /// otherwise run per line on every `listEquals` in a backend's
  /// `didUpdateWidget`.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MapLineData &&
          id == other.id &&
          color == other.color &&
          points.length == other.points.length &&
          (points.isEmpty || (points.first == other.points.first && points.last == other.points.last)));

  @override
  int get hashCode =>
      Object.hash(id, color, points.length, points.isEmpty ? null : points.first, points.isEmpty ? null : points.last);
}

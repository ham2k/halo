// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The backend-agnostic contract every Map tab implementation (OSM, Mapbox
// native, Mapbox webview) accepts — built once by the facade
// (operation_map_tab.dart) from `Qso`/`Operation` domain objects via
// gridToLocation, so no backend widget touches polo_core's QSO shape
// directly or re-derives grid math.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;

enum MapMarkerKind { qso, qth }

enum MapProjection { mercator, globe }

@immutable
class MapMarkerData {
  /// `qso.uuid`, or `'qth'` for the operation's own station marker — a
  /// stable key for widget/annotation identity and the webview JS bridge.
  final String id;
  final double latitude;
  final double longitude;

  /// Callsign, or 'QTH' for the station marker.
  final String label;

  /// Their name, if known — null for the QTH marker.
  final String? sublabel;
  final MapMarkerKind kind;

  /// Resolved once by the facade (PoloColors.bandColor for QSOs, the theme's
  /// primary for the QTH marker) so backends never need theme/context access
  /// just to color a pin.
  final Color color;

  const MapMarkerData({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.kind,
    required this.color,
    this.sublabel,
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
          sublabel == other.sublabel &&
          kind == other.kind &&
          color == other.color);

  @override
  int get hashCode => Object.hash(id, latitude, longitude, label, sublabel, kind, color);
}

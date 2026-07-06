// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The backend-agnostic contract every Map tab implementation (OSM, Mapbox
// native, Mapbox webview) accepts — built once by the facade
// (operation_map_tab.dart) from `Qso`/`Operation` domain objects via
// gridToLocation, so no backend widget touches polo_core's QSO shape
// directly or re-derives grid math.

import 'package:flutter/foundation.dart';

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

  const MapMarkerData({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.kind,
    this.sublabel,
  });
}

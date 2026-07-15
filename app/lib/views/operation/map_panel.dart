// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Map tab facade (ham2k/app-halo-dist#13): builds the backend-agnostic
// marker and line lists once — a band-colored circle per QSO with any
// location (grid square, or guessed from state / DXCC entity prefix), a
// black circle per station QTH, and a great-circle line connecting each QSO
// back to its QTH — then picks a rendering backend:
//   - iOS/Android: MapboxNativeMapView (mapbox_maps_flutter)
//   - macOS/Windows/Linux: MapboxWebviewMapView (Mapbox GL JS in a webview)
//   - Web, or no Mapbox token configured yet: OsmMapView (flutter_map/OSM),
//     the zero-token fallback every platform can render.
// Owns the mercator/globe projection toggle — OsmMapView ignores it (no
// globe support), the Mapbox backends honor it.
//
// QTHs are resolved per QSO (`qso.our.grid`, falling back to the
// operation's grid) so an operation whose location changed across a break
// gets one QTH circle per spot, each QSO tethered to the right one —
// today HaLo never writes `our.grid`, so this collapses to a single QTH.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:intl/intl.dart';

import '../../config/mapbox_token.dart';
import '../../i18n/strings.g.dart';
import '../../services/settings_service.dart';
import '../map/map_marker_data.dart';
import '../map/mapbox_native_map_view.dart';
import '../map/mapbox_webview_map_view.dart';
import '../map/osm_map_view.dart';

class MapPanel extends StatefulWidget {
  final Operation operation;
  final List<Qso> qsos;
  final SettingsService settings;

  const MapPanel({super.key, required this.operation, required this.qsos, required this.settings});

  @override
  State<MapPanel> createState() => _MapPanelState();
}

class _MapPanelState extends State<MapPanel> {
  MapProjection _projection = MapProjection.mercator;

  // Lines are ~60% black at any zoom, splitting the difference on app-polo's
  // zoom-interpolated 50–90% opacity ramp (flat styling keeps the three
  // backends identical).
  static const _lineColor = Color(0x99000000);

  // Fill for a QSO whose band isn't in the theme's band table — app-polo's
  // '#FF0000' fallback. Deliberately NOT bandColor's own 'other' fallback
  // (black): that's the QTH circle's color, and an unknown-band QSO must
  // not be mistakable for the station itself.
  static const _unknownBandColor = Color(0xFFFF0000);

  /// Memoized facade output plus the inputs it was computed from — the QSO
  /// stream only emits a new list instance when data actually changes, so
  /// identical() on it (plus the scalar inputs) lets every other rebuild
  /// (unrelated settings notifications, tab switches, theme pokes) skip
  /// re-deriving hundreds of markers and 100-point great-circle lines.
  List<Qso>? _builtQsos;
  String? _builtGrid;
  bool? _builtMiles;
  HaLoColors? _builtColors;
  AppLocale? _builtLocale;
  List<MapMarkerData> _markers = const [];
  List<MapLineData> _lines = const [];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Rebuild when settings change (the km/miles preference shows up in
    // every QSO popup's distance).
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) => _buildMap(context, theme),
    );
  }

  Widget _buildMap(BuildContext context, ThemeData theme) {
    _ensureData(context);

    if (_markers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            context.t.map.emptyState,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    // Neither Mapbox backend covers web yet (mapbox_maps_flutter's web
    // support is prerelease-only) — TODO(map-web): revisit once it isn't.
    final usesMapbox = !kIsWeb && mapboxAccessToken.isNotEmpty;
    final isMobile = !kIsWeb && (Platform.isIOS || Platform.isAndroid);

    final Widget map = !usesMapbox
        ? OsmMapView(markers: _markers, lines: _lines)
        : isMobile
            ? MapboxNativeMapView(markers: _markers, lines: _lines, projection: _projection)
            : MapboxWebviewMapView(markers: _markers, lines: _lines, projection: _projection);

    return Stack(
      children: [
        Positioned.fill(child: map),
        if (usesMapbox)
          Positioned(
            top: 8,
            right: 8,
            child: SegmentedButton<MapProjection>(
              segments: const [
                ButtonSegment(value: MapProjection.mercator, icon: Icon(Icons.map_outlined), label: Text('Flat')),
                ButtonSegment(value: MapProjection.globe, icon: Icon(Icons.public), label: Text('Globe')),
              ],
              selected: {_projection},
              onSelectionChanged: (selection) => setState(() => _projection = selection.first),
            ),
          ),
      ],
    );
  }

  void _ensureData(BuildContext context) {
    final poloColors = HaLoColors.of(context);
    final miles = widget.settings.distanceUnits == DistanceUnits.miles;
    final locale = LocaleSettings.currentLocale;
    if (identical(_builtQsos, widget.qsos) &&
        _builtGrid == widget.operation.grid &&
        _builtMiles == miles &&
        _builtColors == poloColors &&
        _builtLocale == locale) {
      return;
    }
    _builtQsos = widget.qsos;
    _builtGrid = widget.operation.grid;
    _builtMiles = miles;
    _builtColors = poloColors;
    _builtLocale = locale;

    final qsoMarkers = <MapMarkerData>[];
    final lines = <MapLineData>[];
    // Distinct station spots, keyed by uppercased grid so case variants of
    // the same locator ('FN20ab' vs 'FN20AB') don't stack duplicate QTH
    // circles — one operation usually has one, but a per-QSO `our.grid`
    // (location change across a break) adds more.
    final qthGrids = <String, ({String display, GridLocation location})>{};

    void addQth(String grid, GridLocation location) =>
        qthGrids.putIfAbsent(grid.toUpperCase(), () => (display: grid, location: location));

    final operationGrid = widget.operation.grid;
    if (operationGrid != null) {
      if (gridToLocation(operationGrid) case final qth?) addQth(operationGrid, qth);
    }

    for (final qso in widget.qsos) {
      if (!qso.isRealContact) continue;
      final location = locationForQsoInfo(
        grid: qso.theirGrid,
        entityPrefix: qso.theirEntityPrefix,
        state: qso.theirState,
      );
      if (location == null) continue;

      final qthGrid = qso.ourGrid ?? operationGrid;
      GridLocation? qth;
      if (qthGrid != null) {
        qth = qthGrids[qthGrid.toUpperCase()]?.location ?? gridToLocation(qthGrid);
        if (qth != null) addQth(qthGrid, qth);
      }

      qsoMarkers.add(_markerForQso(qso, location, qth, poloColors, miles: miles));

      if (qth != null) {
        final segments = greatCirclePoints(location, qth);
        for (var i = 0; i < segments.length; i++) {
          lines.add(MapLineData(id: '${qso.uuid}/$i', points: segments[i], color: _lineColor));
        }
      }
    }

    // Weak-signal (smaller) circles draw last so they stay visible and
    // tappable on top of larger ones — same layering as app-polo — and the
    // QTH circles on top of everything.
    qsoMarkers.sort((a, b) => b.sizeFactor.compareTo(a.sizeFactor));
    _markers = [
      ...qsoMarkers,
      for (final entry in qthGrids.entries)
        MapMarkerData(
          id: 'qth-${entry.key}',
          latitude: entry.value.location.latitude,
          longitude: entry.value.location.longitude,
          label: entry.value.display,
          kind: MapMarkerKind.qth,
          color: poloColors.bandColor('other'),
          popupTitle: t.map.qthPopupTitle(grid: entry.value.display),
        ),
    ];
    _lines = lines;
  }

  /// "3.3 km" / "1,042 mi", with locale-aware separators (es: "1.042").
  static String _fmtDistance(double km, {required bool miles}) {
    final value = miles ? km / kmPerMile : km;
    final formatted =
        NumberFormat(value <= 5 ? '#,##0.0' : '#,##0', LocaleSettings.currentLocale.languageCode).format(value);
    return miles ? t.map.distanceMiles(distance: formatted) : t.map.distanceKm(distance: formatted);
  }

  MapMarkerData _markerForQso(Qso qso, GridLocation location, GridLocation? qth, HaLoColors poloColors,
      {required bool miles}) {
    final distanceStr = qth == null ? null : _fmtDistance(distanceOnEarthKm(location, qth), miles: miles);

    final startAt = qso.startAt;
    final timeStr = startAt == null
        ? null
        : '${startAt.hour.toString().padLeft(2, '0')}:${startAt.minute.toString().padLeft(2, '0')}z';

    // Detail line: `<report> • <mode> • <band> • <time>`, skipping whatever
    // is missing. Split around the band so backends can color just it (see
    // MapMarkerData.popupDetailPrefix).
    final band = qso.band ?? '';
    final leadParts = [if (qso.receivedRST != null) qso.receivedRST!, if (qso.mode != null) qso.mode!];
    final prefix = leadParts.isEmpty ? '' : leadParts.join(' • ') + (band.isEmpty ? '' : ' • ');
    final suffix = timeStr == null ? '' : (band.isEmpty && leadParts.isEmpty ? timeStr : ' • $timeStr');

    return MapMarkerData(
      id: qso.uuid,
      latitude: location.latitude,
      longitude: location.longitude,
      label: qso.theirCall,
      kind: MapMarkerKind.qso,
      color: poloColors.bands[qso.band] ?? _unknownBandColor,
      sizeFactor: _sizeFactorForQso(qso),
      popupTitle: distanceStr == null ? qso.theirCall : '${qso.theirCall} • $distanceStr',
      popupDetailPrefix: prefix,
      popupBand: band,
      popupDetailSuffix: suffix,
    );
  }

  /// Circle radius multiplier from the signal report we received — S5 is
  /// 1.0, S9 1.3, S1 0.7 (app-polo's strengthForQSO/_radiusForStrength).
  static double _sizeFactorForQso(Qso qso) {
    final report = int.tryParse(qso.receivedRST ?? '');
    int strength;
    switch (qso.mode) {
      case 'CW' || 'RTTY':
        strength = ((report ?? 555) ~/ 10) % 10; // RST — middle digit
      case 'FT8' || 'FT4':
        // dB SNR, typically -20..+10 — remap onto 1..9.
        final signal = report ?? -10;
        strength = ((signal + 20) * 8 / 30 + 1).round().clamp(1, 9);
      default:
        strength = (report ?? 55) % 10; // RS — strength digit
    }
    return 1 + (strength - 5) / 4 * 0.30;
  }
}

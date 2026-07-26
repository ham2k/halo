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

import '../../config/secrets.dart';
import '../../i18n/strings.g.dart';
import '../../services/settings_service.dart';
import '../../tools/distance_format.dart';
import '../map/map_marker_data.dart';
import '../map/mapbox_native_map_view.dart';
import '../map/mapbox_web_map_view.dart';
import '../map/mapbox_webview_map_view.dart';
import '../map/osm_map_view.dart';

class MapPanel extends StatefulWidget {
  final Operation operation;
  final List<Qso> qsos;
  final SettingsService settings;

  /// The call currently in the logging panel (new or being edited), if any —
  /// used to highlight that QSO on top of the map in the panel's accent
  /// colour (orange composing, blue editing). Null when nothing's being
  /// entered. Its `guess` carries the resolved location, `isEditing` the
  /// colour choice.
  final CallInfoData? callInfo;

  const MapPanel({super.key, required this.operation, required this.qsos, required this.settings, this.callInfo});

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
  /// re-deriving hundreds of markers and densified great-circle lines.
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

    // The current QSO's highlight is derived every build (it changes on every
    // keystroke, so it can't share `_ensureData`'s heavy memo) and appended
    // last, so backends draw it on top. Cheap: one location resolve plus one
    // great-circle.
    final highlight = _buildHighlight(theme);
    final markers = highlight.markers.isEmpty ? _markers : [..._markers, ...highlight.markers];
    final lines = highlight.lines.isEmpty ? _lines : [..._lines, ...highlight.lines];

    if (markers.isEmpty) {
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

    final Widget map;
    // No token is a supported state, not a broken build: a fresh checkout, a
    // fork, and every CI build without one fall back to OpenStreetMap below.
    var usesMapbox = (secrets['MAPBOX_ACCESS_TOKEN'] ?? '').isNotEmpty;
    if (usesMapbox && kIsWeb) {
      // The app already runs in a browser — Mapbox GL JS mounts directly on
      // a platform-view div, no webview needed.
      map = MapboxWebMapView(markers: markers, lines: lines, projection: _projection);
    } else if (usesMapbox && (Platform.isIOS || Platform.isAndroid)) {
      map = MapboxNativeMapView(markers: markers, lines: lines, projection: _projection);
    } else if (usesMapbox && (Platform.isMacOS || Platform.isWindows)) {
      map = MapboxWebviewMapView(markers: markers, lines: lines, projection: _projection);
    } else {
      // No token — or Linux, where no Mapbox path exists (flutter_inappwebview
      // ships no Linux implementation and mapbox_maps_flutter is
      // mobile-only), so the OSM backend is the real Linux map, not a
      // stopgap. It has markers/lines/callouts, just no globe projection.
      usesMapbox = false;
      map = OsmMapView(markers: markers, lines: lines);
    }

    return Stack(
      children: [
        Positioned.fill(child: map),
        if (usesMapbox)
          Positioned(
            // Clears the device's real top/right insets (notch, camera
            // cutout) so the toggle isn't drawn under them — the map tiles
            // themselves stay edge-to-edge (ham2k/app-halo-dist#205).
            top: 8 + PaneSafeArea.topOf(context),
            right: 8 + PaneSafeArea.rightOf(context),
            child: SegmentedButton<MapProjection>(
              segments: [
                ButtonSegment(value: MapProjection.mercator, icon: const Icon(Icons.map), label: Text(context.t.map.flat)),
                ButtonSegment(value: MapProjection.globe, icon: const Icon(Icons.public), label: Text(context.t.map.globe)),
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

  /// The current QSO's highlight, using the logging panel's accent colours —
  /// `colorScheme.tertiary` (orange) composing, `.secondary` (blue) editing.
  ({List<MapMarkerData> markers, List<MapLineData> lines}) _buildHighlight(ThemeData theme) => buildHighlightData(
        callInfo: widget.callInfo,
        operationGrid: widget.operation.grid,
        composingColor: mapHighlightColor(theme.colorScheme.tertiary),
        editingColor: mapHighlightColor(theme.colorScheme.secondary),
      );

  MapMarkerData _markerForQso(Qso qso, GridLocation location, GridLocation? qth, HaLoColors poloColors,
      {required bool miles}) {
    final distanceStr = qth == null ? null : fmtDistance(distanceOnEarthKm(location, qth), miles: miles);

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

/// A brighter, more vivid take on [base] for the map highlight: same hue,
/// pushed to full saturation and a punchy mid lightness so it pops over the
/// map tiles, rather than the theme's muted tertiary/secondary (light-mode
/// tertiary is a dark brownish orange). Keeps the alpha.
Color mapHighlightColor(Color base) {
  final hsl = HSLColor.fromColor(base);
  return hsl.withSaturation(1.0).withLightness(0.5).toColor();
}

/// Builds the current QSO's highlight marker and great-circle line from the
/// logging panel's [callInfo], or empty when nothing is being entered or its
/// location can't be resolved. [composingColor] is used for a new QSO and
/// [editingColor] when editing one (`CallInfoData.isEditing`) — the caller
/// passes `colorScheme.tertiary` / `.secondary` to match LoggingControls' own
/// accent. Both items are flagged `highlight: true` so each backend draws them
/// last, on top. Extracted (and public) so the colour/location logic is unit
/// testable without a live map backend.
({List<MapMarkerData> markers, List<MapLineData> lines}) buildHighlightData({
  required CallInfoData? callInfo,
  required String? operationGrid,
  required Color composingColor,
  required Color editingColor,
}) {
  const empty = (markers: <MapMarkerData>[], lines: <MapLineData>[]);
  final guess = callInfo?.guess;
  if (callInfo == null || guess == null) return empty;

  final location = locationForQsoInfo(
    grid: guess['grid'] as String?,
    entityPrefix: guess['entityPrefix'] as String?,
    state: guess['state'] as String?,
  );
  if (location == null) return empty;

  final accent = callInfo.isEditing ? editingColor : composingColor;

  final marker = MapMarkerData(
    id: 'current',
    latitude: location.latitude,
    longitude: location.longitude,
    label: callInfo.call,
    kind: MapMarkerKind.qso,
    color: accent,
    // Largest size, so it reads as the one you're working on.
    sizeFactor: 1.3,
    highlight: true,
    popupTitle: callInfo.call,
  );

  final lines = <MapLineData>[];
  final qth = operationGrid == null ? null : gridToLocation(operationGrid);
  if (qth != null) {
    final segments = greatCirclePoints(location, qth);
    for (var i = 0; i < segments.length; i++) {
      lines.add(MapLineData(id: 'current/$i', points: segments[i], color: accent, highlight: true));
    }
  }
  return (markers: [marker], lines: lines);
}

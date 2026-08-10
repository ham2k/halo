// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Map tab facade: builds the backend-agnostic
// marker and line lists once — a band-colored circle per QSO with any
// location (grid square, or guessed from state / DXCC entity prefix), a
// black circle per station QTH, and a great-circle line connecting each QSO
// back to its QTH — then picks a rendering backend:
//   - iOS/Android: MapboxNativeMapView (mapbox_maps_flutter)
//   - macOS/Windows: MapboxWebviewMapView (Mapbox GL JS in a webview)
//   - Web: MapboxWebMapView (Mapbox GL JS on a platform-view div)
//   - Linux, no Mapbox token configured, or Windows where no WebView2
//     environment can be created: OsmMapView (flutter_map/OSM), the
//     zero-token fallback every platform can render.
// The MAPLIBRE experiment reroutes every webview-capable platform — the
// three GL rows above, iOS/Android through the webview backend — to
// MapLibre GL JS + OpenFreeMap, token or not (see the build method).
// Owns the mercator/globe projection toggle — OsmMapView ignores it (no
// globe support), the GL backends honor it.
//
// QTHs are resolved per QSO (`qso.our.grid`, falling back to the
// operation's grid) so an operation whose location changed across a break
// gets one QTH circle per spot, each QSO tethered to the right one —
// today HaLo never writes `our.grid`, so this collapses to a single QTH.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../config/secrets.dart';
import '../../i18n/strings.g.dart';
import '../../services/settings_service.dart';
import '../../services/windows_webview.dart';
import '../../tools/distance_format.dart';
import '../map/map_gl_script.dart';
import '../map/map_marker_data.dart';
import '../map/map_zoom_controller.dart';
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

  /// Whether the desktop webview backend can run here — false on a Windows
  /// machine where no WebView2 environment can be created, and where routing
  /// to the webview would leave the map permanently blank instead of falling
  /// back to OSM. macOS starts true (WKWebView is part of the OS); Windows
  /// starts from the cached answer, pessimistically false the first time.
  /// That first answer costs a cold browser-process spawn, not a registry
  /// lookup, so the first map open of a session visibly shows OSM and then
  /// swaps to Mapbox — every later one goes straight to the cached answer.
  bool _webviewSupported = false;

  /// Backs the bottom-left zoom buttons (non-mobile only, alongside pinch/scroll
  /// zoom) — the live backend wires its own zoomIn/zoomOut into it each time it's
  /// built, so the buttons stay agnostic to which one is currently mounted.
  final _zoomController = MapZoomController();

  @override
  void initState() {
    super.initState();
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.macOS && defaultTargetPlatform != TargetPlatform.windows)) {
      return;
    }
    _webviewSupported = WindowsWebView.resolved ?? defaultTargetPlatform != TargetPlatform.windows;
    if (WindowsWebView.resolved == null) {
      WindowsWebView.isAvailable().then((ok) {
        if (mounted && ok != _webviewSupported) setState(() => _webviewSupported = ok);
      });
    }
  }

  // Lines are ~60% black (light) or ~60% white (dark) at any zoom, splitting
  // the difference on app-polo's zoom-interpolated 50–90% opacity ramp (flat
  // styling keeps the three backends identical) — a dark basemap needs the
  // inverted tone or the great-circle lines disappear into the tiles.
  static const _lineColorLight = Color(0x99000000);
  static const _lineColorDark = Color(0x99FFFFFF);

  // The ring around a QSO circle — opaque, so it survives mapColorToHex's
  // alpha-stripping unchanged for the GL backends. A dark stroke reads as a
  // hole in a light basemap; a light one does the same job on a dark one.
  static const _qsoStrokeLight = Color(0xFF1A1A1A);
  static const _qsoStrokeDark = Color(0xFFF2F2F2);
  static const _qthStroke = Colors.white;

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
  bool? _builtDark;
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
          padding: const EdgeInsets.all(Space.xxl),
          child: Text(
            context.t.map.emptyState,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final Widget map;
    // The MAPLIBRE experiment (experiments.yaml) routes every webview-capable
    // platform through MapLibre GL JS + OpenFreeMap, which needs no token —
    // including iOS/Android, where it replaces the native Mapbox SDK to
    // evaluate a webview map on mobile (MapLibre's own native SDK has no
    // globe projection). Off, Mapbox runs wherever a token is configured; no
    // token is a supported state, not a broken build: a fresh checkout, a
    // fork, and every CI build without one fall back to OpenStreetMap below.
    final isDark = theme.brightness == Brightness.dark;
    final useMapLibre = widget.settings.experimentEnabled('maplibre');
    final glEngine = useMapLibre
        ? MapGlEngine.maplibre
        : ((secrets['MAPBOX_ACCESS_TOKEN'] ?? '').isNotEmpty ? MapGlEngine.mapbox : null);
    var hasGlobe = glEngine != null;
    // A pinned MapLibre style (MAPLIBRE experiment only — see the map style
    // menu on this tab's header button) uses the same URL for both slots, so
    // the light/dark machinery in the GL backends just never has a reason to
    // swap it. Mapbox ignores the setting entirely (styled via lightPreset,
    // not a style URL — see MapGlEngine.styleUrlDark's doc).
    final pinnedStyle = widget.settings.mapStyle;
    final glStyleUrl = glEngine == MapGlEngine.maplibre && pinnedStyle != MapStyle.automatic
        ? mapLibreStyleUrl(pinnedStyle)
        : glEngine?.styleUrl ?? '';
    final glStyleUrlDark = glEngine == MapGlEngine.maplibre && pinnedStyle != MapStyle.automatic
        ? mapLibreStyleUrl(pinnedStyle)
        : glEngine?.styleUrlDark ?? '';
    // Keyed on the engine: both engines render through the same widget type
    // on web and desktop, and those States create their map (or webview page)
    // once — without the key, toggling the experiment mid-session reuses the
    // old State and the engine never actually switches.
    final glKey = ValueKey(glEngine);
    // Native mapbox_maps_flutter (iOS/Android, MAPLIBRE off) doesn't get a
    // zoom controller wired: it's mobile-only, and the buttons themselves are
    // hidden there (see hasZoomButtons below).
    if (glEngine == null) {
      map = OsmMapView(markers: markers, lines: lines, isDark: isDark, zoomController: _zoomController);
    } else if (kIsWeb) {
      // The app already runs in a browser — GL JS mounts directly on a
      // platform-view div, no webview needed.
      map = MapboxWebMapView(
          key: glKey,
          markers: markers,
          lines: lines,
          projection: _projection,
          engine: glEngine,
          isDark: isDark,
          styleUrl: glStyleUrl,
          styleUrlDark: glStyleUrlDark,
          zoomController: _zoomController);
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android) {
      map = useMapLibre
          ? MapboxWebviewMapView(
              key: glKey,
              markers: markers,
              lines: lines,
              projection: _projection,
              engine: glEngine,
              isDark: isDark,
              styleUrl: glStyleUrl,
              styleUrlDark: glStyleUrlDark)
          : MapboxNativeMapView(markers: markers, lines: lines, projection: _projection, isDark: isDark);
    } else if ((defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows) &&
        _webviewSupported) {
      // Named platform by platform, and through `defaultTargetPlatform` rather
      // than `dart:io`'s `Platform` (which no test can override), so that the
      // Linux exclusion is a rule a test holds down. Widening this branch to
      // Linux gives Linux a blank pane, not a map: no webview implementation
      // is registered there.
      map = MapboxWebviewMapView(
          key: glKey,
          markers: markers,
          lines: lines,
          projection: _projection,
          engine: glEngine,
          isDark: isDark,
          styleUrl: glStyleUrl,
          styleUrlDark: glStyleUrlDark,
          zoomController: _zoomController);
    } else {
      // Linux, where no webview map exists (no web view implementation is
      // registered there — see docs/quirks.md — and mapbox_maps_flutter is
      // mobile-only), so the OSM backend is the real Linux map. It has
      // markers/lines/callouts, just no globe projection. Windows without a
      // usable WebView2 environment lands here too.
      hasGlobe = false;
      if (useMapLibre) debugPrint('[map] MAPLIBRE experiment is on but no webview map exists here; using OSM');
      map = OsmMapView(markers: markers, lines: lines, isDark: isDark, zoomController: _zoomController);
    }

    // Mobile already zooms by pinch with no room to spare in the pane; the
    // buttons are for the platforms where a mouse/trackpad is the norm.
    final hasZoomButtons = !isMobilePlatform;

    return Stack(
      children: [
        Positioned.fill(child: map),
        if (hasGlobe)
          Positioned(
            // Clears the device's real top/right insets (notch, camera
            // cutout) so the toggle isn't drawn under them — the map tiles
            // themselves stay edge-to-edge.
            top: 8 + PaneSafeArea.topOf(context),
            right: 8 + PaneSafeArea.rightOf(context),
            child: _MapProjectionButton(
              projection: _projection,
              onPressed: () => setState(
                () => _projection = _projection == MapProjection.mercator ? MapProjection.globe : MapProjection.mercator,
              ),
            ),
          ),
        if (hasZoomButtons)
          Positioned(
            bottom: 8 + PaneSafeArea.bottomOf(context),
            left: 8 + PaneSafeArea.leftOf(context),
            child: _MapZoomButtons(controller: _zoomController),
          ),
      ],
    );
  }

  void _ensureData(BuildContext context) {
    final poloColors = HaLoColors.of(context);
    final miles = widget.settings.distanceUnits == DistanceUnits.miles;
    final locale = LocaleSettings.currentLocale;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (identical(_builtQsos, widget.qsos) &&
        _builtGrid == widget.operation.grid &&
        _builtMiles == miles &&
        _builtColors == poloColors &&
        _builtLocale == locale &&
        _builtDark == isDark) {
      return;
    }
    _builtQsos = widget.qsos;
    _builtGrid = widget.operation.grid;
    _builtMiles = miles;
    _builtColors = poloColors;
    _builtLocale = locale;
    _builtDark = isDark;

    final lineColor = isDark ? _lineColorDark : _lineColorLight;
    final qsoStroke = isDark ? _qsoStrokeDark : _qsoStrokeLight;

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

      qsoMarkers.add(_markerForQso(qso, location, qth, poloColors, miles: miles, strokeColor: qsoStroke));

      if (qth != null) {
        final segments = greatCirclePoints(location, qth);
        for (var i = 0; i < segments.length; i++) {
          lines.add(MapLineData(id: '${qso.uuid}/$i', points: segments[i], color: lineColor));
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
          strokeColor: _qthStroke,
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
        strokeColor: theme.brightness == Brightness.dark ? _qsoStrokeDark : _qsoStrokeLight,
      );

  MapMarkerData _markerForQso(Qso qso, GridLocation location, GridLocation? qth, HaLoColors poloColors,
      {required bool miles, required Color strokeColor}) {
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
      strokeColor: strokeColor,
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

/// A single toggle, not a segmented pair: the icon shown is always the
/// OTHER projection — tapping it is "switch to this" — so there's no
/// selected/unselected state to contrast against an arbitrary basemap.
/// A full circle, matching IconButton's own circular hover/ripple rather
/// than a rounded-square card fighting a round one.
class _MapProjectionButton extends StatelessWidget {
  final MapProjection projection;
  final VoidCallback onPressed;

  const _MapProjectionButton({required this.projection, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toGlobe = projection == MapProjection.mercator;
    return Material(
      color: theme.colorScheme.surface,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: IconButton(
        icon: Icon(
          toGlobe ? MdiIcons.earth : MdiIcons.map,
          semanticLabel: toGlobe ? context.t.map.globe : context.t.map.flat,
        ),
        onPressed: onPressed,
      ),
    );
  }
}

/// The bottom-left +/- zoom cluster, non-mobile only (see hasZoomButtons in
/// _MapPanelState._buildMap) — a mouse/trackpad has no pinch gesture, and
/// scroll-to-zoom isn't discoverable without them. One pill rather than two
/// separate cards, with a hairline between the two actions — clipped so
/// each IconButton's own hover/ripple stays inside the pill instead of
/// squaring off its corners.
class _MapZoomButtons extends StatelessWidget {
  final MapZoomController controller;

  const _MapZoomButtons({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(MdiIcons.plus, semanticLabel: context.t.map.zoomIn),
            onPressed: controller.zoomIn,
          ),
          // A bare Divider has no intrinsic width and Column's non-stretch
          // cross axis gives it none either, so it renders at zero width
          // without an explicit one — SizedBox is what gives it one.
          SizedBox(width: 40, child: Divider(height: 1, thickness: 1, color: theme.dividerColor)),
          IconButton(
            icon: Icon(MdiIcons.minus, semanticLabel: context.t.map.zoomOut),
            onPressed: controller.zoomOut,
          ),
        ],
      ),
    );
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
  required Color strokeColor,
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
    strokeColor: strokeColor,
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

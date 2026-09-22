// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Map tab facade: builds the backend-agnostic
// marker and line lists once — a band-colored circle per QSO with any
// location (grid square, or guessed from state / DXCC entity prefix), a
// black circle per station QTH, and a great-circle line connecting each QSO
// back to its QTH — then picks a rendering backend:
//   - macOS/Windows/iOS/Android: MapboxWebviewMapView (MapLibre GL JS in a
//     webview) — mobile uses this rather than a native map SDK because
//     MapLibre Native has no globe projection.
//   - Web: MapboxWebMapView (MapLibre GL JS on a platform-view div)
//   - Linux, or Windows where no WebView2 environment can be created:
//     OsmMapView (flutter_map/OSM), the backend every platform can render.
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

import 'package:halo_i18n/halo_i18n.dart';
import '../../services/geoshape_service.dart';
import '../../services/settings_service.dart';
import '../../tools/distance_format.dart';
import '../map/map_gl_script.dart';
import '../map/map_marker_data.dart';
import '../map/map_zoom_controller.dart';
import '../map/ref_shapes.dart';
import '../map/mapbox_web_map_view.dart';
import '../map/mapbox_webview_map_view.dart';
import '../map/osm_map_view.dart';
import '../map/webview_support_probe.dart';

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

  /// Where the operation's own references get their outlines — a summit's
  /// SOTA activation zone and the like. Null leaves the map exactly as it
  /// was, which is also what an operator sees for an operation whose programs
  /// publish no shapes.
  final GeoshapeService? geoshapes;

  /// The activity descriptors, only for the color each reference type wears —
  /// the same list the Information panel is given, so a zone here and the
  /// same zone on the Activities map are the same color rather than two
  /// unrelated washes. Empty is fine: the outline falls back to the theme's
  /// primary.
  final List<Map<String, dynamic>> activityControls;

  const MapPanel({
    super.key,
    required this.operation,
    required this.qsos,
    required this.settings,
    this.callInfo,
    this.geoshapes,
    this.activityControls = const [],
  });

  @override
  State<MapPanel> createState() => _MapPanelState();
}

class _MapPanelState extends State<MapPanel> with WebviewSupportProbe<MapPanel> {
  MapProjection _projection = MapProjection.mercator;

  /// The operation's reference outlines — see ref_shapes.dart, shared with the
  /// Activities pane's map so the same summit draws the same way in both.
  late final RefShapeLoader _shapeLoader = RefShapeLoader(
    geoshapes: widget.geoshapes,
    onChanged: () {
      if (mounted) setState(() {});
    },
  );

  /// Backs the bottom-left zoom buttons (non-mobile only, alongside pinch/scroll
  /// zoom) — the live backend wires its own zoomIn/zoomOut into it each time it's
  /// built, so the buttons stay agnostic to which one is currently mounted.
  final _zoomController = MapZoomController();

  @override
  void initState() {
    super.initState();
    initWebviewSupportProbe();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    maybeProbeWebviewSupport();
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

  // The operation's resolved coordinate, alongside its grid: with an exact
  // location stored, two positions inside one square are different maps, and
  // comparing the grid alone would serve the first one's markers for both.
  GridLocation? _builtQth;
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
    return ListenableBuilder(listenable: widget.settings, builder: (context, _) => _buildMap(context, theme));
  }

  Widget _buildMap(BuildContext context, ThemeData theme) {
    // The BASEMAP's tone, not the app's: everything drawn over the tiles has
    // to contrast against them, and a pinned style keeps its own whatever the
    // app's theme is doing. Derived once — the markers, the highlight and the
    // backend all have to agree on it. Also what the OSM backend picks its
    // tile source by, so its map and its markers agree too.
    final isDark = mapStyleIsDark(widget.settings.mapStyle, appIsDark: theme.brightness == Brightness.dark);
    _ensureData(context, isDark: isDark);

    // The current QSO's highlight is derived every build (it changes on every
    // keystroke, so it can't share `_ensureData`'s heavy memo) and appended
    // last, so backends draw it on top. Cheap: one location resolve plus one
    // great-circle.
    final highlight = _buildHighlight(theme, isDark: isDark);
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

    // Below the empty state deliberately: with no markers this pane draws no
    // map at all, and fetching an outline for it would spend an activator's
    // data on something nothing will render.
    //
    // Named after the reference rather than a marker, because this map draws
    // no dot for the operation's references — its markers are QSOs and QTHs —
    // so a shape id here has nothing to trace back to but the reference.
    final shapes = refShapes(
      widget.operation.refs,
      loader: _shapeLoader,
      controls: widget.activityControls,
      fallbackColor: theme.colorScheme.primary,
      markerIdFor: (ref) => 'ref-${ref['type']}/${ref['ref']}',
    );

    final Widget map;
    var hasGlobe = true;
    // A pinned style (see the map style menu on this tab's header button)
    // uses the same URL for both slots, so the light/dark machinery in the
    // GL backends just never has a reason to swap it.
    final pinnedStyle = widget.settings.mapStyle;
    final glStyleUrl = pinnedStyle != MapStyle.automatic ? mapLibreStyleUrl(pinnedStyle) : mapDefaultStyleUrl;
    final glStyleUrlDark = pinnedStyle != MapStyle.automatic ? mapLibreStyleUrl(pinnedStyle) : mapDefaultStyleUrlDark;
    if (kIsWeb) {
      // The app already runs in a browser — GL JS mounts directly on a
      // platform-view div, no webview needed.
      map = MapboxWebMapView(
        markers: markers,
        lines: lines,
        shapes: shapes,
        projection: _projection,
        isDark: isDark,
        styleUrl: glStyleUrl,
        styleUrlDark: glStyleUrlDark,
        zoomController: _zoomController,
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android) {
      // Nothing until the pane has actually been opened once. macOS/Windows
      // get here only through `webviewSupported`, which already waits for
      // that; mobile has no such gate of its own, so without this a Map pane
      // mounted hidden inside a dock group builds a full webview on launch —
      // GL script, style, a screen of tiles — for a map nobody has asked to
      // see.
      //
      // `expand`, not `shrink`: the placeholder stands in a pane sized by the
      // group, and a shrink-wrapping one would resize it.
      map = paneEverVisible
          // No zoom controller: mobile zooms by pinch, and the buttons
          // themselves are hidden there (see hasZoomButtons below).
          ? MapboxWebviewMapView(
              markers: markers,
              lines: lines,
              shapes: shapes,
              projection: _projection,
              isDark: isDark,
              styleUrl: glStyleUrl,
              styleUrlDark: glStyleUrlDark,
            )
          : const SizedBox.expand();
    } else if ((defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows) && webviewSupported) {
      // Named platform by platform, and through `defaultTargetPlatform` rather
      // than `dart:io`'s `Platform` (which no test can override), so that the
      // Linux exclusion is a rule a test holds down. Widening this branch to
      // Linux gives Linux a blank pane, not a map: no webview implementation
      // is registered there.
      map = MapboxWebviewMapView(
        markers: markers,
        lines: lines,
        shapes: shapes,
        projection: _projection,
        isDark: isDark,
        styleUrl: glStyleUrl,
        styleUrlDark: glStyleUrlDark,
        zoomController: _zoomController,
      );
    } else {
      // Linux, where no webview map exists (no web view implementation is
      // registered there — see docs/quirks.md), so the OSM backend is the
      // real Linux map. It has markers/lines/callouts, just no globe
      // projection. Windows without a usable WebView2 environment lands
      // here too.
      hasGlobe = false;
      map = OsmMapView(markers: markers, lines: lines, shapes: shapes, isDark: isDark, zoomController: _zoomController);
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
              onPressed: () => setState(() => _projection = _projection == MapProjection.mercator ? MapProjection.globe : MapProjection.mercator),
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

  void _ensureData(BuildContext context, {required bool isDark}) {
    final poloColors = HaLoColors.of(context);
    final miles = widget.settings.distanceUnits == DistanceUnits.miles;
    final locale = LocaleSettings.currentLocale;
    if (identical(_builtQsos, widget.qsos) &&
        _builtGrid == widget.operation.grid &&
        _builtQth == widget.operation.location &&
        _builtMiles == miles &&
        _builtColors == poloColors &&
        _builtLocale == locale &&
        _builtDark == isDark) {
      return;
    }
    _builtQsos = widget.qsos;
    _builtGrid = widget.operation.grid;
    _builtQth = widget.operation.location;
    _builtMiles = miles;
    _builtColors = poloColors;
    _builtLocale = locale;
    _builtDark = isDark;

    final lineColor = isDark ? _lineColorDark : _lineColorLight;
    final qsoStroke = isDark ? _qsoStrokeDark : _qsoStrokeLight;

    final qsoMarkers = <MapMarkerData>[];
    final lines = <MapLineData>[];
    // Distinct station spots, keyed by uppercased DISPLAY grid so case
    // variants of the same locator ('FN20ab' vs 'FN20AB') don't stack
    // duplicate QTH circles — one operation usually has one, but a per-QSO
    // `our.grid` (location change across a break) adds more. Keying by the
    // displayed locator rather than the raw coordinate also collapses the
    // metres of GPS jitter between two fixes taken from the same chair, which
    // would otherwise draw a circle each.
    final qthGrids = <String, ({String display, GridLocation location})>{};

    void addQth(String grid, GridLocation location) => qthGrids.putIfAbsent(grid.toUpperCase(), () => (display: grid, location: location));

    final operationGrid = widget.operation.displayGrid;
    if (operationGrid != null) {
      if (widget.operation.location case final qth?) addQth(operationGrid, qth);
    }

    for (final qso in widget.qsos) {
      if (!qso.isRealContact) continue;
      final location = locationForQsoInfo(exact: qso.theirExactLocation, grid: qso.theirGrid, entityPrefix: qso.theirEntityPrefix, state: qso.theirState);
      if (location == null) continue;

      final qthGrid = qso.ourDisplayGrid ?? operationGrid;
      GridLocation? qth;
      if (qthGrid != null) {
        qth = qthGrids[qthGrid.toUpperCase()]?.location ?? qso.ourLocation;
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
  ({List<MapMarkerData> markers, List<MapLineData> lines}) _buildHighlight(ThemeData theme, {required bool isDark}) => buildHighlightData(
    callInfo: widget.callInfo,
    operationLocation: widget.operation.location,
    composingColor: mapHighlightColor(theme.colorScheme.tertiary),
    editingColor: mapHighlightColor(theme.colorScheme.secondary),
    strokeColor: isDark ? _qsoStrokeDark : _qsoStrokeLight,
  );

  MapMarkerData _markerForQso(Qso qso, GridLocation location, GridLocation? qth, HaLoColors poloColors, {required bool miles, required Color strokeColor}) {
    final distanceStr = qth == null ? null : fmtDistance(distanceOnEarthKm(location, qth), miles: miles);

    final startAt = qso.startAt;
    final timeStr = startAt == null ? null : '${startAt.hour.toString().padLeft(2, '0')}:${startAt.minute.toString().padLeft(2, '0')}z';

    // Detail line: `<report> • <mode> • <band> • <time>`, skipping whatever
    // is missing. Split around the band so backends can color just it (see
    // MapMarkerData.popupDetailPrefix).
    final band = qso.band ?? '';
    // The mode as a list shows it ([displayMode]); the popup is plain text a
    // backend renders, so an unexpected sideband is spelled out uncolored.
    final leadParts = [if (qso.receivedRST != null) qso.receivedRST!, ?displayMode(qso.mode, freqKHz: qso.freq, band: qso.band)];
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
        icon: Icon(toGlobe ? MdiIcons.earth : MdiIcons.map, semanticLabel: toGlobe ? context.t.map.globe : context.t.map.flat),
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
          Divider(height: 1, thickness: 1, color: theme.dividerColor),
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
  required GridLocation? operationLocation,
  required Color composingColor,
  required Color editingColor,
  required Color strokeColor,
}) {
  const empty = (markers: <MapMarkerData>[], lines: <MapLineData>[]);
  final guess = callInfo?.guess;
  if (callInfo == null || guess == null) return empty;

  final location = locationForQsoInfo(
    exact: locationFromGuess(guess),
    grid: asQsonString(guess['grid']),
    entityPrefix: asQsonString(guess['entityPrefix']),
    state: asQsonString(guess['state']),
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
  if (operationLocation != null) {
    final segments = greatCirclePoints(location, operationLocation);
    for (var i = 0; i < segments.length; i++) {
      lines.add(MapLineData(id: 'current/$i', points: segments[i], color: accent, highlight: true));
    }
  }
  return (markers: [marker], lines: lines);
}

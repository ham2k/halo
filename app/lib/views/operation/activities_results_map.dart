// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Activities pane's "Suggestions & Search" map toggle: one marker per
// suggestion with a resolvable location, on the same rendering backend the
// Map tab picks per platform (map_panel.dart). The backend-selection branch
// and the webview-availability probing behind it (webview_support_probe.dart)
// are shared with map_panel.dart directly, so a fix to either can't land in
// one pane and silently miss the other; everything else here is its own —
// map_panel.dart's version is entangled with QSO/QTH specifics (great-circle
// lines, the current-QSO highlight, the globe toggle) this pane has no use
// for.
//
// Every backend's built-in click popup (map_gl_script.dart's HTML popup,
// OsmMapView's MapPopupCard) stays untouched here — each is given
// `onMarkerTap` instead, which routes a click to this pane's own reveal
// card with an Add button, so "reveal, then explicitly add" reads the same
// regardless of which backend rendered the dot.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../../services/extensions/extension_ref_results.dart';
import '../../services/error_reporting_service.dart';
import '../../services/geoshape_service.dart';
import '../../services/outline_grid_service.dart';
import '../../services/link_opener.dart';
import '../../services/settings_service.dart';
import '../../tools/distance_format.dart';
import '../map/map_gl_script.dart';
import '../map/map_marker_data.dart';
import '../map/map_info_box.dart';
import '../map/outline_issue_dialog.dart';
import '../map/map_marker_icon.dart';
import '../map/ref_shapes.dart';
import '../map/map_zoom_controller.dart';
import '../map/mapbox_web_map_view.dart';
import '../map/mapbox_webview_map_view.dart';
import '../map/osm_map_view.dart';
import '../map/webview_support_probe.dart';
import 'activities_view.dart' show ActivityRowChip, activityRowDetail, activityRowIsRetired, activityRowTitle;

/// The entry's own coordinate when the activity's lookup table has one
/// (tighter than decoding a 6-character grid square — see the SDK's `Ref.lat`
/// / `Ref.lon`, extensions/sdk/src/types.ts), otherwise the center of its
/// `grid`. Null when the entry has neither, same as a QSO with no
/// resolvable location on the Map tab.
GridLocation? locationForSuggestion(Map<String, dynamic> suggestion) =>
    // Read, not cast: an extension's answer, and a malformed one must not take
    // the map with it.
    locationFromLatLon(suggestion['lat'], suggestion['lon']) ?? gridToLocation(suggestion['grid'] is String ? suggestion['grid'] as String : null);

/// One marker per [suggestions] entry that is NOT already on the operation
/// and has a resolvable location (see [locationForSuggestion]) — entries
/// without one are silently omitted, the same treatment a location-less QSO
/// gets on the Map tab. The id is [selectedRefMarkerId], what the entry IS
/// rather than where it sits in the list: suggestions arrive late (a pan,
/// parks found by their outline) and are re-ranked, and an open card or a
/// tap's pager has to keep naming the same reference through that. One
/// marker per reference — the first of two that share one wins.
///
/// Unlike the list rows, this takes no "are these search results?" — the
/// rows keep an already-added search hit and fade it (`suggestionHidesAsAlreadyAdded`),
/// where the map has [activitySelectedRefMarkers] drawing that same point in
/// the reference's own icon, and two dots on one point read as two
/// references. Which is the whole justification for dropping it, so the drop
/// is conditional on that other marker actually existing: a reference the
/// operation stored WITHOUT a location gets none, and dropping its
/// suggestion too would take the only dot that reference had off the map.
List<MapMarkerData> activitySuggestionMarkers(
  List<Map<String, dynamic>> suggestions, {
  required List<Map<String, dynamic>> controls,
  required List<Map<String, dynamic>> refs,
  required Color defaultColor,
  required Color strokeColor,
}) {
  final markers = <MapMarkerData>[];
  final drawn = <String>{};
  for (final suggestion in suggestions) {
    final storedRef = refs.where((r) => r['type'] == suggestion['type'] && r['ref'] == suggestion['ref']).firstOrNull;
    if (storedRef != null && locationForSuggestion(storedRef) != null) continue;
    final location = locationForSuggestion(suggestion);
    if (location == null || !drawn.add(selectedRefMarkerId(suggestion))) continue;
    final control = controlForRefType(controls, suggestion['type'] as String?);
    final baseColor = colorForRefType(controls, suggestion['type'] as String?) ?? defaultColor;
    markers.add(
      MapMarkerData(
        id: selectedRefMarkerId(suggestion),
        latitude: location.latitude,
        longitude: location.longitude,
        label: activityRowTitle(control, suggestion),
        kind: MapMarkerKind.qso,
        // Faded when the operation already has it: this dot only survives the
        // drop above because the stored reference has no location of its own
        // to draw, and at full strength it would be indistinguishable from a
        // reference the operator can still add — which its card, offering no
        // Add button, then contradicts.
        color: storedRef == null ? baseColor : baseColor.withValues(alpha: 0.4),
        strokeColor: strokeColor,
      ),
    );
  }
  return markers;
}

/// What a reference is named by on the map — its marker, its card, a tap's
/// pager — whether it is on the operation or suggested.
String selectedRefMarkerId(Map<String, dynamic> ref) => 'ref-${ref['type']}/${ref['ref']}';

/// One marker per operation reference with a resolvable location, in the
/// reference type's own icon and color — the same pair the Current
/// Activities rows above the map use, so a dot and its row read as the same
/// object. Ids are [selectedRefMarkerId], the same a suggestion of that
/// reference carries: removed from the operation, a reference's card stays
/// open on the suggestion it becomes, now offering Add — the undo for a
/// removal made by mistake. Whether an id names one of the operation's own
/// references is a question for the refs, not for the id.
///
/// [glyphFor] returns null while a marker's pixels are still being drawn;
/// that reference falls back to a plain dot in its color for those frames
/// rather than vanishing from the map.
List<MapMarkerData> activitySelectedRefMarkers(
  List<Map<String, dynamic>> refs, {
  required List<Map<String, dynamic>> controls,
  required Color defaultColor,
  required Color strokeColor,
  required MapMarkerGlyph? Function(IconData icon, Color background) glyphFor,
}) {
  final markers = <MapMarkerData>[];
  for (final ref in refs) {
    final location = locationForSuggestion(ref);
    if (location == null) continue;
    final control = controlForRef(controls, type: ref['type'] as String?, code: ref['ref'] is String ? ref['ref'] as String : null);
    // With the code, like the control lookup above it: a reference answered
    // under a legacy type would otherwise take the default colour while the
    // row beside it wears its extension's.
    final color = colorForRefType(controls, ref['type'] as String?, code: refCodeOf(ref)) ?? defaultColor;
    markers.add(
      MapMarkerData(
        id: selectedRefMarkerId(ref),
        latitude: location.latitude,
        longitude: location.longitude,
        label: activityRowTitle(control, ref),
        kind: MapMarkerKind.qso,
        color: color,
        strokeColor: strokeColor,
        glyph: glyphFor(resolveIconName(control?['icon'] as String?), color),
      ),
    );
  }
  return markers;
}

class ActivitiesResultsMap extends StatefulWidget {
  final List<Map<String, dynamic>> suggestions;
  final List<Map<String, dynamic>> controls;
  final List<Map<String, dynamic>> refs;
  final SettingsService settings;

  /// Where a reference's own outline comes from. Null in a harness that has
  /// no database to cache one in — the map then draws its markers and no
  /// outlines, which is also what an operator sees for every program that
  /// publishes none.
  final GeoshapeService? geoshapes;

  /// Where POTA suggestions' outlines come from: the bundles for the cells in
  /// view, rather than each park's whole outline. Null draws every
  /// suggestion's outline whole.
  final OutlineGridService? outlineGrid;

  /// The camera, shared with the Current Activities rows above the map so a
  /// row and its own dot point the map at the same place. Owned by the pane
  /// that builds both (activities_view.dart) rather than by this widget: the
  /// rows are not this widget's children, and a controller created here would
  /// be out of their reach.
  final MapZoomController? camera;

  final ValueChanged<Map<String, dynamic>> onAdd;

  /// Takes an already-added reference back off the operation, from its card.
  final ValueChanged<Map<String, dynamic>>? onRemove;

  /// Where to read about a reference, for the reveal card's web button —
  /// null, or answering null, leaves the card without one.
  final Future<RefLink?> Function(Map<String, dynamic> ref)? linkFor;

  /// References found by panning, drawn after [suggestions] and never fitted
  /// by the camera — the operator is the one moving it. Map-only: the list
  /// above the map keeps answering the search it was asked.
  final List<Map<String, dynamic>> exploredSuggestions;

  /// What moves the camera while there is no [currentLocation] to open on:
  /// it refits to the markers when this changes, and only then (see
  /// [MapMarkerData.fitKey]). The pane changes it with each search it
  /// answers. Null fits once, when the map first has markers —
  /// never whenever they change, which on this map is the operator's own
  /// doing (a card opened, a reference added, a dot hidden by zooming out).
  final String? fitKey;

  /// Asks for the references in a view the operator took the map to, past
  /// [exploreFromZoom], answering whether every program answered it — the
  /// map asks again about a view that came back short. Null where the map has
  /// nothing more to find.
  final Future<bool> Function(MapViewBounds bounds)? onExplore;

  /// The search band's own location pill, mirrored onto the map as a dot —
  /// null exactly when the pill has nothing to show either (still
  /// determining, denied, or a grid the search can't place). See
  /// activities_view.dart's `currentLocation`.
  final GridLocation? currentLocation;

  /// The operation's own location and grid, as it stores them — what an
  /// outline issue report says about where the operator is. Not
  /// [currentLocation], which falls back to the device's live fix and would
  /// send it without the operation ever having said where it is.
  final GridLocation? operationLocation;
  final String? operationGrid;
  final Color? currentLocationColor;

  /// The pill's own glyph and its color, mirrored into the map's dot so the
  /// two read as the same object rather than as a button and an unrelated
  /// smudge. See activities_view.dart's `locationPin`.
  final IconData? currentLocationIcon;
  final Color? currentLocationIconColor;

  const ActivitiesResultsMap({
    super.key,
    required this.suggestions,
    required this.controls,
    required this.refs,
    required this.settings,
    this.geoshapes,
    this.outlineGrid,
    this.camera,
    required this.onAdd,
    this.onRemove,
    this.linkFor,
    this.exploredSuggestions = const [],
    this.onExplore,
    this.fitKey,
    this.currentLocation,
    this.operationLocation,
    this.operationGrid,
    this.currentLocationColor,
    this.currentLocationIcon,
    this.currentLocationIconColor,
  });

  /// The zoom, on the GL scale, from which the suggestions nobody has picked
  /// get their outlines too — the same as the Map tab's, see
  /// [refOutlinesFromZoom].
  static const suggestionOutlinesFromZoom = refOutlinesFromZoom;
  static const suggestionOutlinesOpaqueAtZoom = refOutlinesOpaqueAtZoom;

  /// The zoom, on the GL scale, from which panning brings in the references
  /// around the map's new centre — a pane some 150km across. Further out
  /// each program's nearest few would be a scatter across a region.
  static const exploreFromZoom = 7.0;

  /// Below this zoom, on the GL scale, the map shows only the operation's own
  /// references and "you are here": a country's worth of suggestions is a
  /// smear of dots, and the ones the operator chose get lost in it. From here
  /// they fade in, fully shown at [suggestionMarkersOpaqueAtZoom].
  static const suggestionMarkersFromZoom = 6.0;
  static const suggestionMarkersOpaqueAtZoom = 7.5;

  /// The two fades above, as the backends apply them.
  static const MapZoomFades zoomFades = (
    markers: (from: suggestionMarkersFromZoom, to: suggestionMarkersOpaqueAtZoom),
    dashedShapes: (from: suggestionOutlinesFromZoom, to: suggestionOutlinesOpaqueAtZoom),
    // The operation's own and the open card's, at every zoom: the operator
    // asked for these.
    solidShapes: null,
  );

  @override
  State<ActivitiesResultsMap> createState() => _ActivitiesResultsMapState();
}

class _ActivitiesResultsMapState extends State<ActivitiesResultsMap> with WebviewSupportProbe<ActivitiesResultsMap> {
  /// Which marker's reveal card is open, by [selectedRefMarkerId] — or the
  /// current-location dot, which reveals nothing and so just closes the
  /// card.
  String? _selectedMarkerId;

  /// The rasterized halves of this map's glyph markers.
  late final _glyphCache = MarkerGlyphCache(
    onLanded: () {
      if (mounted) setState(() {});
    },
  );

  /// Whether the map has closed in past
  /// [ActivitiesResultsMap.suggestionOutlinesFromZoom]. Kept as
  /// the crossing rather than the zoom itself, so a drag rebuilds this pane
  /// only when the answer changes, not on every frame of the gesture.
  bool _suggestionOutlines = false;

  /// The last zoom a backend reported, on the GL scale — what turns a tap's
  /// few pixels of slack into metres for [_onMapTap]. Not state: nothing
  /// draws from it.
  double? _zoom;

  /// The outlines on the map as last built, for [_onMapTap] to hit-test.
  List<MapShapeData> _shapes = const [];

  /// How far from a tap a dot, an edge or a trail still counts as under it.
  static const _pickRadiusPixels = 20.0;

  /// Everything the last tap found under it, in the order the card steps
  /// through them. The pager shows only while the open card is one of them,
  /// so a card opened any other way never carries a stale count.
  List<String> _picks = const [];

  /// How thick the chosen marker's ring is, against the 1.5–2 of the rest.
  static const _chosenRingWidth = 4.0;

  /// The marker whose card is open, drawn black inside a thick ring of its
  /// own colour — the colour moves to the ring, so it still says which
  /// program it is, and the black says "this one" against every other dot.
  /// A glyph marker gets its glyph redrawn the same way; until those pixels
  /// land it keeps its own.
  MapMarkerData _asChosen(MapMarkerData marker, {required Color glyphForeground, required double devicePixelRatio}) {
    const fill = Colors.black;
    final ring = marker.color;
    final glyph = marker.glyph;
    return marker.asChosen(
      fill: fill,
      ring: ring,
      ringWidth: _chosenRingWidth,
      // A plain dot grows, or the ring would leave almost no black to see.
      sizeFactor: glyph == null ? 1.4 : null,
      glyph: glyph == null
          ? null
          : _glyphCache.glyphFor(
              icon: glyph.icon,
              background: fill,
              foreground: glyphForeground,
              strokeColor: ring,
              devicePixelRatio: devicePixelRatio,
              strokeWidth: _chosenRingWidth,
            ),
    );
  }

  /// The views answered since the search changed, and the zoom each was
  /// answered at. A view inside one has nothing new to find — until the map
  /// is a whole zoom level closer: each program answers a view with its
  /// nearest few hundred, so a dense one leaves its corners to a closer look.
  /// Recorded only once an answer came back whole, so a failure is asked
  /// about again rather than remembered as an empty region.
  final List<({MapViewBounds bounds, double zoom})> _explored = [];
  Timer? _exploreDebounce;

  /// Bumped with each new search, so an answer for the last one is not
  /// recorded against this one.
  int _exploreGeneration = 0;

  /// The backend's last camera report, for DEVMAPINFO's box — which listens
  /// to it alone, so a drag does not rebuild the pane.
  final _cameraReport = ValueNotifier<MapCameraSettled?>(null);

  void _onCameraChanged(MapCameraSettled settled) {
    // After the frame when flutter_map reports from its own layout: the box
    // listening to it would otherwise rebuild during a build.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      _cameraReport.value = settled;
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cameraReport.value = settled;
      });
    }
    final (:camera, :bounds) = settled;
    _onZoomChanged(camera.zoom);
    _readGridFor(bounds, camera.zoom);
    final onExplore = widget.onExplore;
    if (onExplore == null || camera.zoom < ActivitiesResultsMap.exploreFromZoom) return;
    // flutter_map reports every frame of a drag; GL only where it came to
    // rest. Waiting for the camera to stay put asks once either way.
    _exploreDebounce?.cancel();
    _exploreDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted || _explored.any((done) => camera.zoom < done.zoom + 1 && _boundsContain(done.bounds, bounds))) return;
      final generation = _exploreGeneration;
      final whole = await onExplore(bounds);
      if (whole && mounted && generation == _exploreGeneration) _explored.add((bounds: bounds, zoom: camera.zoom));
    });
  }

  /// Whether [outer] holds all of [inner]. A view across the antimeridian is
  /// never counted as held: rare enough that asking again costs nothing.
  static bool _boundsContain(MapViewBounds outer, MapViewBounds inner) =>
      outer.west <= outer.east &&
      inner.west <= inner.east &&
      outer.south <= inner.south &&
      outer.north >= inner.north &&
      outer.west <= inner.west &&
      outer.east >= inner.east;

  /// Web Mercator at 512-pixel tiles, [zoom] on the GL scale.
  static double _metersPerPixel(GridLocation at, double zoom) => 40075016.686 * math.cos(at.latitude * math.pi / 180) / (512 * math.pow(2, zoom));

  /// The POTA parks in the outline bundles for the cells in view, and which
  /// cells those were.
  Map<String, OutlinePieces> _gridParks = const {};
  String _gridCells = '';
  String? _gridPending;

  /// Whether the last read of the cells in view was whole — null before one
  /// lands. Not whole (offline, with no copy kept), a POTA suggestion the
  /// bundles lack is drawn from whatever whole outline the device still
  /// holds, never downloaded ([_keptShapeLoader]); null, it waits.
  bool? _gridSettled;
  Timer? _gridDebounce;

  /// The outline bundles' areas for the parks drawn from them: tapped like
  /// any outline, never drawn — their sides along a cell's edge are seams.
  List<MapShapeData> _gridAreas = const [];

  /// From this zoom, on the GL scale, the 10 m square bundles; further out,
  /// the 500 m blocks. The public map at geo.ham2k.net switches at the same
  /// zoom.
  static const _gridSquaresFromZoom = 9.0;

  /// Reads the bundles for the cells in [bounds] once the camera has stayed
  /// there a moment — flutter_map reports every frame of a drag.
  void _readGridFor(MapViewBounds bounds, double zoom) {
    final grid = widget.outlineGrid;
    // Nothing to draw from them without a POTA suggestion on the map.
    if (grid == null || !_allSuggestions.any((suggestion) => suggestion['type'] == OutlineGridService.potaActivationType)) return;
    if (zoom < ActivitiesResultsMap.suggestionOutlinesFromZoom) {
      // Out past the bundles: what was read is for a view no longer shown,
      // and coming back in reads the cells then in view.
      _gridDebounce?.cancel();
      _gridCells = '';
      _gridPending = null;
      _gridSettled = null;
      return;
    }
    List<String> cellsAt(OutlineGridScale scale) =>
        OutlineGridService.cellsCovering(south: bounds.south, west: bounds.west, north: bounds.north, east: bounds.east, scale: scale);
    final squares = zoom >= _gridSquaresFromZoom;
    final cells = cellsAt(squares ? OutlineGridScale.square : OutlineGridScale.block);
    final key = cells.join(',');
    // Cancelled first, and an in-flight read disowned: back on the cells
    // already read, one of the cells just passed through would otherwise
    // land over them.
    _gridDebounce?.cancel();
    if (key == _gridCells) {
      _gridPending = null;
      return;
    }
    _gridDebounce = Timer(const Duration(milliseconds: 300), () async {
      _gridPending = key;
      try {
        var (:parks, :settled) = await grid.piecesIn(cells);
        // The detailed squares not on the device, the coarser blocks may be
        // — they are what a planned operation keeps there (prefetchFor).
        // Taken only whole: the squares that were read still draw better than
        // blocks that were not.
        final coarser = squares && !settled;
        if (coarser) {
          final blocks = await grid.piecesIn(cellsAt(OutlineGridScale.block));
          if (blocks.settled) (:parks, :settled) = blocks;
        }
        if (!mounted || key != _gridPending) return;
        // A cell that could not be read — or was read coarser than asked —
        // is asked about again on the next camera report, rather than taken
        // as having no parks.
        _gridCells = settled && !coarser ? key : '';
        setState(() {
          _gridParks = parks;
          _gridSettled = settled;
        });
      } catch (e, stack) {
        ErrorReportingService.report(e, stack, context: 'activities:outlineGrid');
      }
    });
  }

  /// The bundle pieces of each of [refs], as shapes named after its marker —
  /// the cell and piece in the id, so a map comparing shapes by id redraws
  /// when the cells in view change.
  List<MapShapeData> _gridShapes(Iterable<Map<String, dynamic>> refs, {required bool areas, required bool dashed, required Color fallbackColor}) => [
    for (final ref in refs)
      if (_gridParks[ref['ref']] case final park?)
        for (final piece in areas ? park.areas : park.lines)
          MapShapeData(
            id: '${selectedRefMarkerId(ref)}/${piece.id.replaceAll('/', ':')}',
            rings: piece.rings,
            color: colorForRefType(widget.controls, ref['type'] as String?, code: refCodeOf(ref)) ?? fallbackColor,
            isLine: piece.isLine,
            dashed: dashed,
            sourceName: piece.sourceName,
            sourceUrl: OutlineGridService.outlineUrlFor(ref['ref'] as String),
            refLabel: outlineRefLabel(ref),
          ),
  ];

  @override
  void dispose() {
    _exploreDebounce?.cancel();
    _gridDebounce?.cancel();
    _cameraReport.dispose();
    super.dispose();
  }

  /// The map's suggestions: the search's own, then the ones panning found —
  /// in that order, so a reference both list is drawn as the search's.
  List<Map<String, dynamic>> get _allSuggestions => [...widget.suggestions, ...widget.exploredSuggestions];

  /// Whether the map is close enough in for the suggestions' own markers —
  /// see [ActivitiesResultsMap.suggestionMarkersFromZoom]. Kept as the
  /// crossing, like [_suggestionOutlines].
  bool _suggestionMarkers = true;

  void _onZoomChanged(double zoom) {
    _zoom = zoom;
    final outlines = zoom >= ActivitiesResultsMap.suggestionOutlinesFromZoom;
    final markers = zoom >= ActivitiesResultsMap.suggestionMarkersFromZoom;
    if (outlines == _suggestionOutlines && markers == _suggestionMarkers) return;
    // flutter_map reports a position from its own layout (a resize refits
    // the camera), when a setState would be a build during a build.
    void apply() {
      if (!mounted || (outlines == _suggestionOutlines && markers == _suggestionMarkers)) return;
      setState(() {
        _suggestionOutlines = outlines;
        _suggestionMarkers = markers;
      });
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      apply();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) => apply());
    }
  }

  /// The outlines drawn for this pane's references — the caching and backoff
  /// rules live in ref_shapes.dart, shared with the Map tab so a summit whose
  /// zone shows in one pane can't quietly fail to show in the other.
  late final RefShapeLoader _shapeLoader = RefShapeLoader(
    geoshapes: widget.geoshapes,
    onChanged: () {
      if (mounted) setState(() {});
    },
  );

  /// For a POTA suggestion's outline when the bundles could not be read:
  /// whatever whole one the device still holds, and never a download of it.
  late final RefShapeLoader _keptShapeLoader = RefShapeLoader(
    geoshapes: widget.geoshapes,
    keptOnly: true,
    onChanged: () {
      if (mounted) setState(() {});
    },
  );

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

  @override
  void didUpdateWidget(ActivitiesResultsMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An open card follows its reference through whatever the lists do —
    // a late addition, a re-ranking, a search re-run on a GPS fix — and
    // closes only once nothing listed is that reference any more. The pager
    // keeps the rest of what the tap found, less what has gone.
    if (_selectedMarkerId != null && _markerEntry(_selectedMarkerId) == null) _selectedMarkerId = null;
    final picks = [
      for (final id in _picks)
        if (_markerEntry(id) != null) id,
    ];
    if (picks.length != _picks.length) _picks = picks.length > 1 ? picks : const [];
    // A POTA suggestion that arrives with the camera at rest still needs its
    // bundles: nothing else asks until the map moves.
    if (!identical(oldWidget.suggestions, widget.suggestions) || !identical(oldWidget.exploredSuggestions, widget.exploredSuggestions)) {
      if (_cameraReport.value case (:final camera, :final bounds)?) _readGridFor(bounds, camera.zoom);
    }
    // A new search starts the exploring over: what was found for the last
    // one is gone from the map. Its key, not the list: the same search's list
    // changes as late answers land, and that is no reason to ask again.
    if (oldWidget.fitKey != widget.fitKey) {
      _exploreDebounce?.cancel();
      _explored.clear();
      _exploreGeneration++;
    }
  }

  void _onMarkerTap(String id) {
    // Faded out, a suggestion is not there to tap; and a marker that stands
    // for no entry ("you are here") reveals nothing — it only closes a card.
    if (!_suggestionMarkers && !_isOwnRef(id) && _markerEntry(id) != null) return;
    final entry = _markerEntry(id);
    if (entry == null) {
      setState(() => _selectedMarkerId = null);
      return;
    }
    // Picked around the dot rather than the tap itself, which the backend
    // does not report: the two are a dot's radius apart at most.
    final location = locationForSuggestion(entry);
    // The dot the operator aimed at leads, the rest in their usual order.
    final picks = [id, if (location != null) ..._pickAt(location).where((pick) => pick != id)];
    _open(picks);
    // Only a reference already on the operation, alone under the tap, not a
    // suggestion: a suggestion's card offers Add, and flying the map away
    // from the search results the operator is comparing would answer a
    // question they did not ask — as would flying to the first of several
    // they are about to step through. Tapping the same reference's row does
    // the same thing — see activities_view.dart.
    if (_picks.isNotEmpty || !_isOwnRef(id) || _selectedMarkerId != id) return;
    if (location != null) widget.camera?.moveTo(location.latitude, location.longitude);
  }

  /// A tap on the map opens the card of what lies under it, as a tap on a
  /// marker does — the map's own references and its suggestions alike. The
  /// camera stays put even for the operation's own reference: the operator
  /// tapped something already in view.
  void _onMapTap(GridLocation point) {
    final picks = _pickAt(point);
    if (picks.isNotEmpty) _open(picks);
  }

  /// Opens the first of [picks], or — when its card is already open —
  /// closes it: a second tap on the same thing.
  void _open(List<String> picks) {
    setState(() {
      if (picks.first == _selectedMarkerId) {
        _selectedMarkerId = null;
      } else {
        _selectedMarkerId = picks.first;
      }
      _picks = picks.length > 1 ? picks : const [];
    });
  }

  /// The marker ids of every dot and outline within [_pickRadiusPixels] of
  /// [point], each reference once: dots first, then outlines from the
  /// smallest up — a summit's zone before the forest around it — and by
  /// reference within each size.
  List<String> _pickAt(GridLocation point) {
    final zoom = _zoom;
    // Web Mercator at 512-pixel tiles; without a zoom, only a tap inside an
    // area can land.
    final radius = _pickRadiusPixels * (zoom == null ? 0.0 : _metersPerPixel(point, zoom));
    final cosLat = math.cos(point.latitude * math.pi / 180);
    const metersPerDegree = 111320.0;
    final sizes = <String, double>{};
    final entries = <String, Map<String, dynamic>>{};
    void found(String? markerId, double size) {
      final entry = _markerEntry(markerId);
      if (markerId == null || entry == null || size >= (sizes[markerId] ?? double.infinity)) return;
      sizes[markerId] = size;
      entries[markerId] = entry;
    }

    // Measured before its marker id is looked up, which scans the lists:
    // the dots under a tap are a handful of the hundreds panning can bring in.
    bool under(Map<String, dynamic> entry) {
      final at = locationForSuggestion(entry);
      if (at == null) return false;
      final dx = (at.longitude - point.longitude) * cosLat * metersPerDegree, dy = (at.latitude - point.latitude) * metersPerDegree;
      return math.sqrt(dx * dx + dy * dy) <= radius;
    }

    for (final ref in widget.refs) {
      if (under(ref)) found(selectedRefMarkerId(ref), 0);
    }
    if (_suggestionMarkers) {
      for (final suggestion in _allSuggestions) {
        if (under(suggestion)) found(selectedRefMarkerId(suggestion), 0);
      }
    }
    for (final hit in shapesAt([..._shapes, ..._gridAreas], point, toleranceMeters: radius)) {
      found(markerIdOfShape(hit.shape), hit.size);
    }
    return sizes.keys.toList()..sort((a, b) {
      final bySize = sizes[a]!.compareTo(sizes[b]!);
      return bySize != 0 ? bySize : '${entries[a]!['ref'] ?? ''}'.compareTo('${entries[b]!['ref'] ?? ''}');
    });
  }

  /// Whether [id] names one of the operation's own references.
  bool _isOwnRef(String id) => widget.refs.any((ref) => selectedRefMarkerId(ref) == id);

  /// The open card's link, asked for once per card rather than once per
  /// build — every camera move rebuilds this pane.
  String? _linkMarkerId;
  Future<RefLink?>? _link;

  Future<RefLink?>? _linkForSelected(Map<String, dynamic> selected) {
    final id = selectedRefMarkerId(selected);
    if (id != _linkMarkerId) {
      _linkMarkerId = id;
      _link = widget.linkFor?.call(selected);
    }
    return _link;
  }

  /// The entry a marker id stands for — the operation's own reference first,
  /// then a suggestion of it — or null when it stands for none: the
  /// current-location dot, or a reference no longer listed anywhere.
  Map<String, dynamic>? _markerEntry(String? id) {
    if (id == null) return null;
    for (final entry in [...widget.refs, ..._allSuggestions]) {
      if (selectedRefMarkerId(entry) == id) return entry;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The BASEMAP's tone, not the app's — a pinned style keeps its own
    // whatever the app's theme is doing (see mapStyleIsDark).
    final isDark = mapStyleIsDark(widget.settings.mapStyle, appIsDark: theme.brightness == Brightness.dark);
    // Same stroke treatment as the Map tab's QSO circles: a dark ring reads
    // as a hole in a light basemap, a light one does the same job on a dark
    // one.
    final strokeColor = isDark ? const Color(0xFFF2F2F2) : const Color(0xFF1A1A1A);
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    // White, like the location pill's own icon: every glyph on this map sits
    // on a saturated fill, and one shared foreground is what makes the
    // chosen references and the "you are here" dot read as one family.
    const glyphForeground = Colors.white;
    final searched = {for (final suggestion in widget.suggestions) selectedRefMarkerId(suggestion)};
    final markers = [
      for (final marker in activitySuggestionMarkers(
        _allSuggestions,
        controls: widget.controls,
        refs: widget.refs,
        defaultColor: theme.colorScheme.primary,
        strokeColor: strokeColor,
      ))
        // What panning found is never fitted: each batch would snap the map
        // back from where the operator had just dragged it.
        marker.withFit(fitsCamera: searched.contains(marker.id), fadesWithZoom: true),
    ];
    final refMarkers = activitySelectedRefMarkers(
      widget.refs,
      controls: widget.controls,
      defaultColor: theme.colorScheme.primary,
      strokeColor: strokeColor,
      glyphFor: (icon, background) =>
          _glyphCache.glyphFor(icon: icon, background: background, foreground: glyphForeground, strokeColor: strokeColor, devicePixelRatio: devicePixelRatio),
    );

    // The hint is about a search that found nothing, so it must not stand in
    // front of references the operation already has, nor of the "you are
    // here" the map opens on: it shows only when there is nothing at all to
    // draw.
    if (markers.isEmpty && refMarkers.isEmpty && widget.currentLocation == null) {
      final t = context.t.activitiesView;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.xxl),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: t.mapEmptyState,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: '\n${t.mapEmptyStateHint}',
                  style: TextStyle(color: theme.colorScheme.outline),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // The "you are here" dot, in the search band's own pill color — given an
    // id that names no reference, so a tap on it reveals nothing and just
    // dismisses whatever card was open.
    final currentLocation = widget.currentLocation;
    final currentLocationIcon = widget.currentLocationIcon;
    final currentLocationColor = widget.currentLocationColor;
    final unkeyedMarkers = [
      // Hidden zoomed out, where they are a scatter over a region; the
      // operation's own references and "you are here" stay.
      // Always sent, and faded to nothing below the threshold by the backend
      // (fadesWithZoom): left out, a search answered while zoomed out would
      // fit the camera to everything but its own results.
      ...markers,
      ...refMarkers,
      if (currentLocation != null)
        MapMarkerData(
          id: 'current-location',
          latitude: currentLocation.latitude,
          longitude: currentLocation.longitude,
          label: 'current-location',
          kind: MapMarkerKind.qth,
          color: currentLocationColor ?? theme.colorScheme.primary,
          strokeColor: strokeColor,
          glyph: currentLocationIcon == null || currentLocationColor == null
              ? null
              : _glyphCache.glyphFor(
                  icon: currentLocationIcon,
                  background: currentLocationColor,
                  foreground: widget.currentLocationIconColor ?? glyphForeground,
                  strokeColor: strokeColor,
                  devicePixelRatio: devicePixelRatio,
                ),
        ),
    ];
    // With a "you are here", the camera fits that one dot, once: a lone
    // marker fits at MapZoomController.fitMaxZoom (10.5), so the map opens
    // centered on the operator at that zoom and stays wherever they take it.
    // Without one, every marker carries the search's key, so the camera
    // refits for a new search and for nothing else — not for a reference
    // added from a card, nor for suggestions hidden or shown by zooming.
    final opensOnHere = currentLocation != null;
    final allMarkers = [
      for (final marker in unkeyedMarkers)
        (marker.id == _selectedMarkerId ? _asChosen(marker, glyphForeground: glyphForeground, devicePixelRatio: devicePixelRatio) : marker).withFit(
          fitKey: opensOnHere ? 'current-location' : (widget.fitKey ?? 'once'),
          fitsCamera: opensOnHere ? marker.id == 'current-location' : null,
        ),
    ];

    // The operation's own references, plus the one whose reveal card is open
    // — the summit an operator is looking at is as worth an outline as one
    // they have already added.
    final revealed = switch (_markerEntry(_selectedMarkerId)) {
      final revealed? when !widget.refs.any((r) => selectedRefMarkerId(r) == selectedRefMarkerId(revealed)) => revealed,
      _ => null,
    };
    final shapeRefs = [...widget.refs, ?revealed];
    final solidIds = {for (final ref in shapeRefs) selectedRefMarkerId(ref)};
    // A POTA suggestion's outline is the bundles' pieces in view: kilobytes,
    // where a long trail's whole outline runs to megabytes. The operation's
    // own references keep theirs whole.
    bool fromGrid(Map<String, dynamic> ref) => widget.outlineGrid != null && ref['type'] == OutlineGridService.potaActivationType;
    // The open card's outline is drawn whole while the bundles in view have
    // none of it — zoomed out past them, or before they arrive.
    final revealedFromGrid = [if (revealed != null && fromGrid(revealed) && _suggestionOutlines && _gridParks.containsKey(revealed['ref'])) revealed];
    // Every other suggestion on the map, dashed, once the map is close enough
    // for a footprint to be worth its fetch. First in the list, so a backend
    // that stacks in list order agrees with the ones that layer by kind.
    // Named by the same marker id as the solid form, so opening a card reuses
    // the outline already fetched rather than asking again.
    final dashedRefs = [
      if (_suggestionOutlines)
        for (final suggestion in _allSuggestions)
          if (locationForSuggestion(suggestion) != null && !solidIds.contains(selectedRefMarkerId(suggestion))) suggestion,
    ];
    final fallbackColor = theme.colorScheme.primary;
    final dashedFromGrid = dashedRefs.where(fromGrid);
    final dashedKept = dashedRefs.where((ref) => fromGrid(ref) && _gridSettled == false && !_gridParks.containsKey(ref['ref']));
    _gridAreas = _gridShapes([...dashedFromGrid, ...revealedFromGrid], areas: true, dashed: false, fallbackColor: fallbackColor);
    final shapes = _shapes = [
      for (final shape in refShapes(
        dashedRefs.where((ref) => !fromGrid(ref)),
        loader: _shapeLoader,
        controls: widget.controls,
        fallbackColor: fallbackColor,
        markerIdFor: selectedRefMarkerId,
      ))
        shape.asDashed(),
      for (final shape in refShapes(
        dashedKept,
        loader: _keptShapeLoader,
        controls: widget.controls,
        fallbackColor: fallbackColor,
        markerIdFor: selectedRefMarkerId,
      ))
        shape.asDashed(),
      ..._gridShapes(dashedFromGrid, areas: false, dashed: true, fallbackColor: fallbackColor),
      ...refShapes(
        [...widget.refs, if (revealed != null && revealedFromGrid.isEmpty) revealed],
        loader: _shapeLoader,
        controls: widget.controls,
        fallbackColor: fallbackColor,
        markerIdFor: selectedRefMarkerId,
      ),
      ..._gridShapes(revealedFromGrid, areas: false, dashed: false, fallbackColor: fallbackColor),
    ];

    final pinnedStyle = widget.settings.mapStyle;
    final glStyleUrl = pinnedStyle != MapStyle.automatic ? mapLibreStyleUrl(pinnedStyle) : mapDefaultStyleUrl;
    final glStyleUrlDark = pinnedStyle != MapStyle.automatic ? mapLibreStyleUrl(pinnedStyle) : mapDefaultStyleUrlDark;

    final Widget map;
    if (kIsWeb) {
      map = MapboxWebMapView(
        markers: allMarkers,
        shapes: shapes,
        zoomController: widget.camera,
        projection: MapProjection.mercator,
        isDark: isDark,
        styleUrl: glStyleUrl,
        styleUrlDark: glStyleUrlDark,
        onMarkerTap: _onMarkerTap,
        onCameraChanged: _onCameraChanged,
        zoomFades: ActivitiesResultsMap.zoomFades,
        onMapTap: _onMapTap,
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android) {
      map = MapboxWebviewMapView(
        markers: allMarkers,
        shapes: shapes,
        zoomController: widget.camera,
        projection: MapProjection.mercator,
        isDark: isDark,
        styleUrl: glStyleUrl,
        styleUrlDark: glStyleUrlDark,
        onMarkerTap: _onMarkerTap,
        onCameraChanged: _onCameraChanged,
        zoomFades: ActivitiesResultsMap.zoomFades,
        onMapTap: _onMapTap,
      );
    } else if ((defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows) && webviewSupported) {
      map = MapboxWebviewMapView(
        markers: allMarkers,
        shapes: shapes,
        zoomController: widget.camera,
        projection: MapProjection.mercator,
        isDark: isDark,
        styleUrl: glStyleUrl,
        styleUrlDark: glStyleUrlDark,
        onMarkerTap: _onMarkerTap,
        onCameraChanged: _onCameraChanged,
        zoomFades: ActivitiesResultsMap.zoomFades,
        onMapTap: _onMapTap,
      );
    } else {
      // Linux, or Windows without a usable WebView2 environment — see
      // map_panel.dart's own fallback for the same reasoning.
      map = OsmMapView(
        markers: allMarkers,
        shapes: shapes,
        isDark: isDark,
        zoomController: widget.camera,
        onMarkerTap: _onMarkerTap,
        onCameraChanged: _onCameraChanged,
        zoomFades: ActivitiesResultsMap.zoomFades,
        onMapTap: _onMapTap,
      );
    }

    final selected = _markerEntry(_selectedMarkerId);

    return Stack(
      children: [
        // On web, `map` is always a platform view (the kIsWeb branch above
        // never reaches OsmMapView), and this pane sits inside a modal
        // route's own tap-outside-to-dismiss GestureDetector
        // (modal_pane.dart) — an ordinary Flutter ancestor gesture
        // recognizer stacked above a platform view on web silently
        // swallows the platform view's own click events before they reach
        // it. PlatformViewShield lays an element of the app's own under the
        // map, the browser's target wherever the map's own does not reach;
        // on every other platform it's the map alone.
        //
        // ExcludeSemantics on top of that: with accessibility on, Flutter
        // Web still generates a `role=button`/`group` DOM node for any
        // ANCESTOR that merges this subtree's geometry into its own — sized
        // to include the map's full rect, and (like the modal pane's own
        // barrier) positioned over it with `pointer-events: all`, right back
        // to swallowing clicks the shield just made reachable. The
        // map's dots carry no accessible labels of their own to lose here —
        // the reveal card below, a real sibling widget, is what a
        // screen-reader user actually needs, and it keeps its own semantics.
        Positioned.fill(
          child: ExcludeSemantics(child: PlatformViewShield(child: map)),
        ),
        Positioned(
          left: Space.sm,
          right: Space.sm,
          bottom: Space.sm,
          child: MapOutlinesNotice(
            shapes: shapes,
            camera: _cameraReport,
            onReportIssue: () => reportOutlineIssue(
              context,
              shapes: shapes,
              preselectedRefId: switch (_markerEntry(_selectedMarkerId)) {
                final entry? => selectedRefMarkerId(entry),
                null => null,
              },
              where: () => (camera: _cameraReport.value, operatorLocation: widget.operationLocation, operatorGrid: widget.operationGrid),
            ),
          ),
        ),
        Positioned(
          right: MapInfoBox.right,
          bottom: MapInfoBox.bottom,
          child: MapInfoBox(settings: widget.settings, camera: _cameraReport),
        ),
        // At the top, clear of the outline notice and the map's credit along
        // the bottom edge.
        if (selected != null)
          Positioned(
            left: Space.md,
            right: Space.md,
            top: Space.md,
            child: _CardDeck(
              behind: _picks.contains(_selectedMarkerId) ? math.min(_picks.length - 1, _CardDeck.maxBehind) : 0,
              child: _RevealCard(
                suggestion: selected,
                control: controlForRefType(widget.controls, selected['type'] as String?),
                controls: widget.controls,
                alreadyAdded: widget.refs.any((r) => r['type'] == selected['type'] && r['ref'] == selected['ref']),
                miles: widget.settings.distanceUnits == DistanceUnits.miles,
                link: _linkForSelected(selected),
                pickIndex: _picks.indexOf(_selectedMarkerId!),
                pickCount: _picks.length,
                onPick: (index) => setState(() => _selectedMarkerId = _picks[index]),
                onAdd: () {
                  widget.onAdd(selected);
                  setState(() => _selectedMarkerId = null);
                },
                // The card stays open, offering Add again — see didUpdateWidget.
                onRemove: widget.onRemove == null ? null : () => widget.onRemove!(selected),
                onDismiss: () => setState(() => _selectedMarkerId = null),
              ),
            ),
          ),
      ],
    );
  }
}

/// Cards stacked behind the open one with their left edges showing: the
/// hint that the tap found more than this card, before the pager is read.
class _CardDeck extends StatelessWidget {
  /// How many edges show — capped, since past three a deck reads as a
  /// border rather than a count.
  final int behind;
  final Widget child;

  const _CardDeck({required this.behind, required this.child});

  static const maxBehind = 3;

  /// How far each edge shows past the one in front, and how much shorter it
  /// is at top and bottom, so the stack recedes rather than reading as one
  /// thick border.
  static const _step = 5.0;
  static const _inset = 5.0;

  @override
  Widget build(BuildContext context) {
    if (behind == 0) return child;
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        for (var depth = behind; depth >= 1; depth--)
          Positioned(
            left: (behind - depth) * _step,
            top: depth * _inset,
            bottom: depth * _inset,
            right: 0,
            child: Material(color: Color.lerp(colors.surface, colors.onSurface, 0.06 * depth), borderRadius: BorderRadius.circular(12), elevation: 2),
          ),
        Padding(
          padding: EdgeInsets.only(left: behind * _step),
          child: child,
        ),
      ],
    );
  }
}

/// Bright enough to read as "done" at a glance on the card's surface.
const _selectedGreen = Color(0xFF00A43B);

/// What a marker tap reveals: the same title/detail a list row shows, plus
/// an explicit Add action — a stray tap on the map can't add the wrong
/// reference, unlike tapping the marker itself would.
class _RevealCard extends StatelessWidget {
  final Map<String, dynamic> suggestion;
  final Map<String, dynamic>? control;
  final List<Map<String, dynamic>> controls;
  final bool alreadyAdded;
  final bool miles;
  final Future<RefLink?>? link;

  /// Where this card stands among what the tap found, -1 when it is not one
  /// of them; the pager shows only for one of two or more.
  final int pickIndex;
  final int pickCount;
  final ValueChanged<int> onPick;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;
  final VoidCallback onDismiss;

  const _RevealCard({
    required this.suggestion,
    required this.control,
    required this.controls,
    required this.alreadyAdded,
    required this.miles,
    required this.link,
    required this.pickIndex,
    required this.pickCount,
    required this.onPick,
    required this.onAdd,
    required this.onRemove,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t.activitiesView;
    final title = activityRowTitle(control, suggestion);
    final detail = activityRowDetail(suggestion);
    final distance = suggestion['distance'] is num ? fmtDistance((suggestion['distance'] as num).toDouble(), miles: miles) : null;
    final narrow = !ShirtSize.of(context).isTwoPane;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.sm, Space.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                activityRefIcon(controls, suggestion['type'] as String?),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (activityRowIsRetired(suggestion))
                            Padding(
                              padding: const EdgeInsets.only(left: Space.md),
                              child: ActivityRowChip(label: t.retiredReference, unavailable: true),
                            ),
                        ],
                      ),
                      if (detail != null || distance != null)
                        Text(
                          [?detail, ?distance].join(' • '),
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // The same web button the list rows end with.
                FutureBuilder<RefLink?>(
                  // Keyed, or a card paged to the next reference keeps
                  // offering the last one's link until the new one answers.
                  key: ValueKey(selectedRefMarkerId(suggestion)),
                  future: link,
                  builder: (context, snapshot) => switch (snapshot.data) {
                    final link? => IconButton(
                      icon: Icon(MdiIcons.web, semanticLabel: t.openReferenceLink(name: link.label ?? title)),
                      onPressed: () => openExternalUrl(link.url),
                    ),
                    null => const SizedBox.shrink(),
                  },
                ),
                IconButton(
                  icon: Icon(MdiIcons.close, semanticLabel: context.t.common.close),
                  onPressed: onDismiss,
                ),
              ],
            ),
            Row(
              // The pager on the left, the action on the right: Add stays where
              // a lone card has it, whether or not the tap found more.
              children: [
                if (pickIndex >= 0 && pickCount > 1) ...[
                  IconButton(
                    icon: Icon(MdiIcons.arrowLeft, semanticLabel: t.previousPick),
                    onPressed: pickIndex > 0 ? () => onPick(pickIndex - 1) : null,
                  ),
                  Text(
                    t.pickPosition(index: pickIndex + 1, count: pickCount),
                    style: theme.textTheme.labelLarge,
                  ),
                  IconButton(
                    icon: Icon(MdiIcons.arrowRight, semanticLabel: t.nextPick),
                    onPressed: pickIndex < pickCount - 1 ? () => onPick(pickIndex + 1) : null,
                  ),
                ],
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(top: Space.xs, right: Space.xs),
                  child: alreadyAdded
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(MdiIcons.checkCircle, color: _selectedGreen),
                            const SizedBox(width: Space.xs),
                            Text(
                              t.selected,
                              style: theme.textTheme.labelLarge?.copyWith(color: _selectedGreen, fontWeight: FontWeight.bold),
                            ),
                            if (onRemove != null)
                              IconButton(
                                icon: Icon(MdiIcons.delete, semanticLabel: t.removeActivity),
                                onPressed: onRemove,
                              ),
                          ],
                        )
                      : FilledButton.tonal(onPressed: onAdd, child: Text(narrow ? t.addToOperationShort : t.addToOperation)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

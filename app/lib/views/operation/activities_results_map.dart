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
    locationFromLatLon(suggestion['lat'], suggestion['lon']) ?? gridToLocation(suggestion['grid'] as String?);

/// One marker per [suggestions] entry that is NOT already on the operation
/// and has a resolvable location (see [locationForSuggestion]) — entries
/// without one are silently omitted, the same treatment a location-less QSO
/// gets on the Map tab. The id is the entry's own index into [suggestions]
/// (stringified): all a tap handler needs to look the entry back up, and
/// stable enough across a rebuild since a fresh search always replaces the
/// whole list rather than mutating it in place. Contrast
/// [selectedRefMarkerId], which cannot be positional.
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
  for (var i = 0; i < suggestions.length; i++) {
    final suggestion = suggestions[i];
    final storedRef = refs.where((r) => r['type'] == suggestion['type'] && r['ref'] == suggestion['ref']).firstOrNull;
    if (storedRef != null && locationForSuggestion(storedRef) != null) continue;
    final location = locationForSuggestion(suggestion);
    if (location == null) continue;
    final control = controlForRefType(controls, suggestion['type'] as String?);
    final baseColor = colorForRefType(controls, suggestion['type'] as String?) ?? defaultColor;
    markers.add(
      MapMarkerData(
        id: '$i',
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

/// One marker per operation reference with a resolvable location, in the
/// reference type's own icon and color — the same pair the Current
/// Activities rows above the map use, so a dot and its row read as the same
/// object. Ids are `ref-<index>` so a tap can tell a chosen reference from a
/// suggestion, which is the difference between a card that offers Add and
/// one that says the reference is already on the operation.
///
/// [glyphFor] returns null while a marker's pixels are still being drawn;
/// that reference falls back to a plain dot in its color for those frames
/// rather than vanishing from the map.
String selectedRefMarkerId(Map<String, dynamic> ref) => 'ref-${ref['type']}/${ref['ref']}';

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

  /// The camera, shared with the Current Activities rows above the map so a
  /// row and its own dot point the map at the same place. Owned by the pane
  /// that builds both (activities_view.dart) rather than by this widget: the
  /// rows are not this widget's children, and a controller created here would
  /// be out of their reach.
  final MapZoomController? camera;

  final ValueChanged<Map<String, dynamic>> onAdd;

  /// The search band's own location pill, mirrored onto the map as a dot —
  /// null exactly when the pill has nothing to show either (still
  /// determining, denied, or a grid the search can't place). See
  /// activities_view.dart's `currentLocation`.
  final GridLocation? currentLocation;
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
    this.camera,
    required this.onAdd,
    this.currentLocation,
    this.currentLocationColor,
    this.currentLocationIcon,
    this.currentLocationIconColor,
  });

  @override
  State<ActivitiesResultsMap> createState() => _ActivitiesResultsMapState();
}

class _ActivitiesResultsMapState extends State<ActivitiesResultsMap> with WebviewSupportProbe<ActivitiesResultsMap> {
  /// Which marker's reveal card is open: a suggestion's index as a string,
  /// one of [selectedRefMarkerId]'s content-addressed `ref-` ids, or the
  /// current-location dot (which reveals nothing and so just closes the
  /// card).
  String? _selectedMarkerId;

  /// The rasterized halves of the glyph markers, keyed by every input that
  /// changes a pixel. Rasterizing goes through the engine and so is
  /// asynchronous: a marker draws as a plain dot for the frame or two before
  /// its pixels land rather than the map waiting for them. The cache grows
  /// with the reference types on screen times the themes and displays
  /// visited before this pane closes, which is small enough to leave
  /// unswept — the whole State goes with the pane.
  final Map<String, MapMarkerGlyph> _glyphs = {};
  final Set<String> _glyphsInFlight = {};

  /// The outlines drawn for this pane's references — the caching and backoff
  /// rules live in ref_shapes.dart, shared with the Map tab so a summit whose
  /// zone shows in one pane can't quietly fail to show in the other.
  late final RefShapeLoader _shapeLoader = RefShapeLoader(
    geoshapes: widget.geoshapes,
    onChanged: () {
      if (mounted) setState(() {});
    },
  );

  /// The glyph for these inputs if it has been drawn, otherwise null with a
  /// rasterization started — call it from `build`, and the `setState` that
  /// lands the pixels brings the marker in.
  MapMarkerGlyph? _glyphFor({
    required IconData icon,
    required Color background,
    required Color foreground,
    required Color strokeColor,
    required double devicePixelRatio,
  }) {
    // The font is part of the icon's identity, not decoration: extensions
    // name icons across two of them (halo_widgets' resolveIconName), so two
    // different glyphs can share a code point.
    final key =
        '${icon.fontFamily}/${icon.fontPackage}/${icon.codePoint}'
        '/${background.toARGB32()}/${foreground.toARGB32()}'
        '/${strokeColor.toARGB32()}/$devicePixelRatio';
    final ready = _glyphs[key];
    if (ready != null) return ready;
    if (!_glyphsInFlight.add(key)) return null;
    unawaited(() async {
      try {
        final image = await renderMarkerIconImage(
          icon: icon,
          background: background,
          foreground: foreground,
          strokeColor: strokeColor,
          devicePixelRatio: devicePixelRatio,
        );
        if (!mounted) return;
        setState(() => _glyphs[key] = MapMarkerGlyph(icon: icon, color: foreground, image: image));
      } finally {
        // In a finally, not after the await: a rasterization that throws
        // would otherwise leave its key claimed forever, and that marker
        // would be a plain dot for the rest of the session with nothing
        // saying why. Freeing it lets the next build try again, and the
        // throw itself goes on to ErrorPolicy rather than being swallowed
        // here.
        _glyphsInFlight.remove(key);
      }
    }());
    return null;
  }

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
    // A fresh search invalidates a revealed SUGGESTION — its id is an index,
    // which may now point at an unrelated result or past the end of the
    // list. A revealed reference is addressed by what it is, so a search
    // resolving underneath it (or the nearby list refreshing on a GPS fix)
    // says nothing about it and must not close its card.
    final revealedSuggestion = !(_selectedMarkerId?.startsWith('ref-') ?? true);
    if (revealedSuggestion && !identical(oldWidget.suggestions, widget.suggestions)) {
      setState(() => _selectedMarkerId = null);
    }
  }

  void _onMarkerTap(String id) {
    setState(() => _selectedMarkerId = id);
    // Only a reference already on the operation, not a suggestion: a
    // suggestion's card offers Add, and flying the map away from the search
    // results the operator is comparing would answer a question they did not
    // ask. Tapping the same reference's row does the same thing — see
    // activities_view.dart.
    if (!id.startsWith('ref-')) return;
    final location = locationForSuggestion(_markerEntry(id) ?? const {});
    if (location != null) widget.camera?.moveTo(location.latitude, location.longitude);
  }

  /// The entry a marker id stands for, or null when it stands for none — the
  /// current-location dot, or an index left over from a list that has since
  /// been replaced by a fresh search.
  Map<String, dynamic>? _markerEntry(String? id) {
    if (id == null) return null;
    if (id.startsWith('ref-')) {
      for (final ref in widget.refs) {
        if (selectedRefMarkerId(ref) == id) return ref;
      }
      // The operator removed it from the rows above while its card was open.
      return null;
    }
    final index = int.tryParse(id);
    // Lower bound too: the id makes a round trip through the backend's JS,
    // and this promises null for one that stands for no entry rather than a
    // RangeError.
    return index != null && index >= 0 && index < widget.suggestions.length ? widget.suggestions[index] : null;
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
    final markers = activitySuggestionMarkers(
      widget.suggestions,
      controls: widget.controls,
      refs: widget.refs,
      defaultColor: theme.colorScheme.primary,
      strokeColor: strokeColor,
    );
    final refMarkers = activitySelectedRefMarkers(
      widget.refs,
      controls: widget.controls,
      defaultColor: theme.colorScheme.primary,
      strokeColor: strokeColor,
      glyphFor: (icon, background) =>
          _glyphFor(icon: icon, background: background, foreground: glyphForeground, strokeColor: strokeColor, devicePixelRatio: devicePixelRatio),
    );

    // The hint is about a search that found nothing, so it must not stand in
    // front of references the operation already has: it shows only when
    // there is nothing at all to draw.
    if (markers.isEmpty && refMarkers.isEmpty) {
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
    // id that matches neither a suggestion index nor a `ref-` one, so a tap
    // on it reveals nothing and just dismisses whatever card was open.
    final currentLocation = widget.currentLocation;
    final currentLocationIcon = widget.currentLocationIcon;
    final currentLocationColor = widget.currentLocationColor;
    final allMarkers = [
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
              : _glyphFor(
                  icon: currentLocationIcon,
                  background: currentLocationColor,
                  foreground: widget.currentLocationIconColor ?? glyphForeground,
                  strokeColor: strokeColor,
                  devicePixelRatio: devicePixelRatio,
                ),
        ),
    ];

    // The operation's own references, plus the one whose reveal card is open
    // — the summit an operator is looking at is as worth an outline as one
    // they have already added.
    final shapeRefs = [
      ...widget.refs,
      if (_markerEntry(_selectedMarkerId) case final revealed? when !widget.refs.any((r) => selectedRefMarkerId(r) == selectedRefMarkerId(revealed))) revealed,
    ];
    final shapes = refShapes(
      shapeRefs,
      loader: _shapeLoader,
      controls: widget.controls,
      fallbackColor: theme.colorScheme.primary,
      markerIdFor: selectedRefMarkerId,
    );

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
      );
    } else {
      // Linux, or Windows without a usable WebView2 environment — see
      // map_panel.dart's own fallback for the same reasoning.
      map = OsmMapView(markers: allMarkers, shapes: shapes, isDark: isDark, zoomController: widget.camera, onMarkerTap: _onMarkerTap);
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
        if (selected != null)
          Positioned(
            left: Space.md,
            right: Space.md,
            bottom: Space.md,
            child: _RevealCard(
              suggestion: selected,
              control: controlForRefType(widget.controls, selected['type'] as String?),
              controls: widget.controls,
              alreadyAdded: widget.refs.any((r) => r['type'] == selected['type'] && r['ref'] == selected['ref']),
              miles: widget.settings.distanceUnits == DistanceUnits.miles,
              onAdd: () {
                widget.onAdd(selected);
                setState(() => _selectedMarkerId = null);
              },
              onDismiss: () => setState(() => _selectedMarkerId = null),
            ),
          ),
      ],
    );
  }
}

/// What a marker tap reveals: the same title/detail a list row shows, plus
/// an explicit Add action — a stray tap on the map can't add the wrong
/// reference, unlike tapping the marker itself would.
class _RevealCard extends StatelessWidget {
  final Map<String, dynamic> suggestion;
  final Map<String, dynamic>? control;
  final List<Map<String, dynamic>> controls;
  final bool alreadyAdded;
  final bool miles;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  const _RevealCard({
    required this.suggestion,
    required this.control,
    required this.controls,
    required this.alreadyAdded,
    required this.miles,
    required this.onAdd,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t.activitiesView;
    final detail = activityRowDetail(suggestion);
    final distance = suggestion['distance'] is num ? fmtDistance((suggestion['distance'] as num).toDouble(), miles: miles) : null;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.sm, Space.sm),
        child: Row(
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
                          activityRowTitle(control, suggestion),
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
            const SizedBox(width: Space.sm),
            if (alreadyAdded)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                child: Text(t.alreadySelected, style: theme.textTheme.labelSmall),
              )
            else
              FilledButton.tonal(onPressed: onAdd, child: Text(t.addToOperation)),
            IconButton(
              icon: Icon(MdiIcons.close, semanticLabel: context.t.common.close),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

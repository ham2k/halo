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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../i18n/strings.g.dart';
import '../../services/settings_service.dart';
import '../../tools/distance_format.dart';
import '../map/map_gl_script.dart';
import '../map/map_marker_data.dart';
import '../map/mapbox_web_map_view.dart';
import '../map/mapbox_webview_map_view.dart';
import '../map/osm_map_view.dart';
import '../map/webview_support_probe.dart';
import 'activities_view.dart'
    show ActivityRowChip, activityRowDetail, activityRowIsRetired, activityRowTitle, suggestionHidesAsAlreadyAdded;

/// The entry's own coordinate when the activity's lookup table has one
/// (tighter than decoding a 6-character grid square — see the SDK's `Ref.lat`
/// / `Ref.lon`, extensions/sdk/src/types.ts), otherwise the center of its
/// `grid`. Null when the entry has neither, same as a QSO with no
/// resolvable location on the Map tab.
GridLocation? locationForSuggestion(Map<String, dynamic> suggestion) =>
    locationFromLatLon(suggestion['lat'], suggestion['lon']) ?? gridToLocation(suggestion['grid'] as String?);

/// One marker per [suggestions] entry with a resolvable location (see
/// [locationForSuggestion]) — entries without one are silently omitted, the
/// same treatment a location-less QSO gets on the Map tab. The id is the
/// entry's own index into [suggestions] (stringified): all a tap handler
/// needs to look the entry back up, and stable enough across a rebuild since
/// a fresh search always replaces the whole list rather than mutating it in
/// place.
List<MapMarkerData> activitySuggestionMarkers(
  List<Map<String, dynamic>> suggestions, {
  required List<Map<String, dynamic>> controls,
  required List<Map<String, dynamic>> refs,
  required Color defaultColor,
  required Color strokeColor,
  required bool suggestionsAreSearchResults,
}) {
  final markers = <MapMarkerData>[];
  for (var i = 0; i < suggestions.length; i++) {
    final suggestion = suggestions[i];
    final alreadyAdded = refs.any((r) => r['type'] == suggestion['type'] && r['ref'] == suggestion['ref']);
    if (suggestionHidesAsAlreadyAdded(
      alreadyAdded: alreadyAdded,
      suggestionsAreSearchResults: suggestionsAreSearchResults,
    )) {
      continue;
    }
    final location = locationForSuggestion(suggestion);
    if (location == null) continue;
    final control = controlForRefType(controls, suggestion['type'] as String?);
    final baseColor = colorForRefType(controls, suggestion['type'] as String?) ?? defaultColor;
    markers.add(MapMarkerData(
      id: '$i',
      latitude: location.latitude,
      longitude: location.longitude,
      label: activityRowTitle(control, suggestion),
      kind: MapMarkerKind.qso,
      color: alreadyAdded ? baseColor.withValues(alpha: 0.4) : baseColor,
      strokeColor: strokeColor,
    ));
  }
  return markers;
}

class ActivitiesResultsMap extends StatefulWidget {
  final List<Map<String, dynamic>> suggestions;
  final List<Map<String, dynamic>> controls;
  final List<Map<String, dynamic>> refs;
  final SettingsService settings;
  final ValueChanged<Map<String, dynamic>> onAdd;

  /// Whether [suggestions] came from a typed search rather than the nearby
  /// list — see activities_view.dart's `_suggestionsAreSearchResults`, which
  /// this mirrors so an already-added nearby suggestion is dropped the same
  /// way the list rows drop it, rather than the map showing dots the list
  /// itself considers noise.
  final bool suggestionsAreSearchResults;

  /// The search band's own location pill, mirrored onto the map as a dot —
  /// null exactly when the pill has nothing to show either (still
  /// determining, denied, or a grid the search can't place). See
  /// activities_view.dart's `currentLocation`.
  final GridLocation? currentLocation;
  final Color? currentLocationColor;

  const ActivitiesResultsMap({
    super.key,
    required this.suggestions,
    required this.controls,
    required this.refs,
    required this.settings,
    required this.onAdd,
    required this.suggestionsAreSearchResults,
    this.currentLocation,
    this.currentLocationColor,
  });

  @override
  State<ActivitiesResultsMap> createState() => _ActivitiesResultsMapState();
}

class _ActivitiesResultsMapState extends State<ActivitiesResultsMap> with WebviewSupportProbe<ActivitiesResultsMap> {
  int? _selectedIndex;

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
    // A fresh search invalidates whichever entry was revealed — the index
    // may now point at an unrelated result, or past the end of the list.
    if (!identical(oldWidget.suggestions, widget.suggestions)) {
      setState(() => _selectedIndex = null);
    }
  }

  void _onMarkerTap(String id) => setState(() => _selectedIndex = int.tryParse(id));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Same stroke treatment as the Map tab's QSO circles: a dark ring reads
    // as a hole in a light basemap, a light one does the same job on a dark
    // one.
    final strokeColor = isDark ? const Color(0xFFF2F2F2) : const Color(0xFF1A1A1A);
    final markers = activitySuggestionMarkers(
      widget.suggestions,
      controls: widget.controls,
      refs: widget.refs,
      defaultColor: theme.colorScheme.primary,
      strokeColor: strokeColor,
      suggestionsAreSearchResults: widget.suggestionsAreSearchResults,
    );

    if (markers.isEmpty) {
      final t = context.t.activitiesView;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.xxl),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: t.mapEmptyState, style: const TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: '\n${t.mapEmptyStateHint}', style: TextStyle(color: theme.colorScheme.outline)),
            ]),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // The "you are here" dot, in the search band's own pill color — given a
    // non-numeric id so a tap on it parses to no suggestion index (see
    // `_onMarkerTap`) and just dismisses whatever reveal card was open,
    // rather than crashing or revealing a bogus one.
    final currentLocation = widget.currentLocation;
    final allMarkers = currentLocation == null
        ? markers
        : [
            ...markers,
            MapMarkerData(
              id: 'current-location',
              latitude: currentLocation.latitude,
              longitude: currentLocation.longitude,
              label: 'current-location',
              kind: MapMarkerKind.qth,
              color: widget.currentLocationColor ?? theme.colorScheme.primary,
              strokeColor: strokeColor,
            ),
          ];

    final pinnedStyle = widget.settings.mapStyle;
    final glStyleUrl = pinnedStyle != MapStyle.automatic ? mapLibreStyleUrl(pinnedStyle) : mapDefaultStyleUrl;
    final glStyleUrlDark =
        pinnedStyle != MapStyle.automatic ? mapLibreStyleUrl(pinnedStyle) : mapDefaultStyleUrlDark;

    final Widget map;
    if (kIsWeb) {
      map = MapboxWebMapView(
        markers: allMarkers,
        projection: MapProjection.mercator,
        isDark: isDark,
        styleUrl: glStyleUrl,
        styleUrlDark: glStyleUrlDark,
        onMarkerTap: _onMarkerTap,
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android) {
      map = MapboxWebviewMapView(
        markers: allMarkers,
        projection: MapProjection.mercator,
        isDark: isDark,
        styleUrl: glStyleUrl,
        styleUrlDark: glStyleUrlDark,
        onMarkerTap: _onMarkerTap,
      );
    } else if ((defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows) &&
        webviewSupported) {
      map = MapboxWebviewMapView(
        markers: allMarkers,
        projection: MapProjection.mercator,
        isDark: isDark,
        styleUrl: glStyleUrl,
        styleUrlDark: glStyleUrlDark,
        onMarkerTap: _onMarkerTap,
      );
    } else {
      // Linux, or Windows without a usable WebView2 environment — see
      // map_panel.dart's own fallback for the same reasoning.
      map = OsmMapView(markers: allMarkers, isDark: isDark, onMarkerTap: _onMarkerTap);
    }

    final selected = _selectedIndex == null || _selectedIndex! >= widget.suggestions.length
        ? null
        : widget.suggestions[_selectedIndex!];

    return Stack(
      children: [
        // On web, `map` is always a platform view (the kIsWeb branch above
        // never reaches OsmMapView), and this pane sits inside a modal
        // route's own tap-outside-to-dismiss GestureDetector
        // (modal_pane.dart) — an ordinary Flutter ancestor gesture
        // recognizer stacked above a platform view on web silently
        // swallows the platform view's own click events before they reach
        // it. PointerInterceptor opts this rectangle out of Flutter's own
        // hit-test routing so the browser delivers clicks to the map
        // directly; on every other platform it's a no-op passthrough (see
        // DefaultPointerInterceptor).
        //
        // ExcludeSemantics on top of that: with accessibility on, Flutter
        // Web still generates a `role=button`/`group` DOM node for any
        // ANCESTOR that merges this subtree's geometry into its own — sized
        // to include the map's full rect, and (like the modal pane's own
        // barrier) positioned over it with `pointer-events: all`, right back
        // to swallowing clicks PointerInterceptor just made reachable. The
        // map's dots carry no accessible labels of their own to lose here —
        // the reveal card below, a real sibling widget, is what a
        // screen-reader user actually needs, and it keeps its own semantics.
        Positioned.fill(child: ExcludeSemantics(child: PointerInterceptor(child: map))),
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
                setState(() => _selectedIndex = null);
              },
              onDismiss: () => setState(() => _selectedIndex = null),
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
    final distance = suggestion['distance'] is num
        ? fmtDistance((suggestion['distance'] as num).toDouble(), miles: miles)
        : null;

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

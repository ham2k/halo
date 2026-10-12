// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Maps destination: the whole window a map of the references around the
// operator, with their outlines, the same way the Activities sheet's results
// map draws them — that map, given no operation, is what this view shows. A
// tap reveals what lies under it, stepping through every reference there.
// The header searches the references and lays imagery, boundaries and park
// facilities over the basemap, as maps.ham2k.net does.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../services/error_reporting_service.dart';
import '../services/extensions/extension_service.dart';
import '../services/halo_services.dart';
import '../services/location_service.dart';
import '../services/settings_service.dart';
import 'app_shell/home_rail_state.dart';
import 'home_navigation_rail.dart';
import 'map/map_buttons.dart';
import 'map/map_overlays.dart';
import 'map/map_zoom_controller.dart';
import '../tools/distance_format.dart';
import '../tools/operation_title.dart';
import 'operation_view.dart';
import 'operation/activities_results_map.dart';
import 'operation/activity_rows.dart' show activityRowDetail, activityRowTitle, allowsMultipleRefsOfType, refsKeptWhenAdding;
import 'operation/activity_search_state.dart';

class MapsView extends StatefulWidget {
  final HaLoServices services;

  /// Whether the view is the destination on screen. It stays mounted while
  /// another one is up (see `HomeView`), so the location fix it keeps live
  /// follows this rather than the view's lifetime.
  final bool visible;

  const MapsView({super.key, required this.services, this.visible = true});

  @override
  State<MapsView> createState() => _MapsViewState();
}

class _MapsViewState extends State<MapsView> {
  static const _imageryKey = 'mapsImagery';
  static const _boundariesKey = 'mapsBoundaries';
  static const _facilitiesKey = 'mapsFacilities';
  static const _hiddenActivitiesKey = 'mapsHiddenActivities';

  /// The stand-in operation the extensions are asked about: nothing on it
  /// and no location of its own, so every answer is about where the device
  /// is, or where the map has been taken.
  late final _operation = Operation(uuid: '', data: {'stationCall': widget.services.settings.activeProfile.operatorCall});

  List<Map<String, dynamic>> _controls = const [];
  bool _controlsLoaded = false;

  late final ActivitySearchState _search = ActivitySearchState(
    services: widget.services,
    currentOperation: () => _operation,
    scopes: () => activityScopesOf(_controls),
    controlsLoaded: () => _controlsLoaded,
    onAnswered: (_, _) {},
  )..addListener(_onSearchChanged);

  final _camera = MapZoomController();
  final _selection = ActivitiesMapSelection();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  /// Where focus goes when the search is left — see [_leaveSearch].
  final _mapFocus = FocusNode(skipTraversal: true);

  /// The typed search's matches, listed under the field while it has focus
  /// and something typed — leaving the field puts them away, coming back to
  /// it brings the same ones back.
  final _resultsPortal = OverlayPortalController();
  final _resultsLink = LayerLink();

  /// How close the camera goes to a match picked from the list: a park some
  /// ten kilometres across fills the view.
  static const _matchZoom = 12.0;

  _Panel? _panel;
  late MapOverlays _overlays;

  /// The extension keys of the activities the operator has taken off the map
  /// and out of the search's list.
  late Set<String> _hiddenActivities;

  /// The extension keys of the activities whose references the map has had
  /// to draw — the ones worth a place in the activities list, which an
  /// activity with nothing to put on a map (a contest) never earns.
  final _mappedActivities = <String>{};

  /// The shown part of each list the map is given, the same list while
  /// neither it nor [_hiddenActivities] changes — the map redraws every
  /// marker for a list that is not identical to the last.
  var _shownLists = Map<List<Map<String, dynamic>>, List<Map<String, dynamic>>>.identity();

  bool _watchingLocation = false;

  /// Whether a search has been answered from a fix — see [_onLocationChanged].
  bool _searchedFromFix = false;

  @override
  void initState() {
    super.initState();
    final prefs = widget.services.settings.prefs;
    _overlays = MapOverlays(
      imagery: prefs.getBool(_imageryKey) ?? false,
      boundaries: prefs.getBool(_boundariesKey) ?? false,
      facilities: prefs.getBool(_facilitiesKey) ?? false,
    );
    _hiddenActivities = {...?prefs.getStringList(_hiddenActivitiesKey)};
    widget.services.settings.addListener(_onSettingsChanged);
    _searchFocus.addListener(_syncResults);
    _searchController.addListener(_syncResults);
    unawaited(_loadControls());
    _searchedFromFix = widget.services.location.position != null;
    unawaited(_search.search(''));
    if (widget.visible) _shown();
  }

  @override
  void didUpdateWidget(MapsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    widget.visible ? _shown() : _hidden();
  }

  @override
  void dispose() {
    if (_watchingLocation) _hidden();
    widget.services.settings.removeListener(_onSettingsChanged);
    _search.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _mapFocus.dispose();
    super.dispose();
  }

  void _shown() {
    widget.services.track('screen_viewed', {'screen': 'maps'});
    _watchingLocation = true;
    widget.services.location.start();
    widget.services.location.addListener(_onLocationChanged);
  }

  void _hidden() {
    _watchingLocation = false;
    widget.services.location.removeListener(_onLocationChanged);
    widget.services.location.stop();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  /// The first fix searches again, for the references around it. Later ones
  /// do not: every answer refits the camera and drops what panning found,
  /// which on a moving device would pull an operator looking elsewhere back
  /// every few seconds.
  void _onLocationChanged() {
    if (!mounted) return;
    setState(() {});
    if (_searchedFromFix || widget.services.location.position == null) return;
    _searchedFromFix = true;
    _search.searchSoon(_searchController.text);
  }

  void _onSearchChanged() {
    if (!mounted) return;
    _noteMappedActivities();
    setState(() {});
  }

  void _noteMappedActivities() {
    for (final ref in [..._search.suggestions, ..._search.exploredSuggestions]) {
      if (locationForSuggestion(ref) == null) continue;
      final control = controlForRef(_controls, type: ref['type'] as String?, code: refCodeOf(ref));
      if (control != null) _mappedActivities.add(_activityKeyOf(control));
    }
  }

  /// Shows or hides the matches list — from the listeners, never from a
  /// build, which an overlay may not be changed from.
  void _syncResults() {
    if (!mounted) return;
    // Back to the search: what was picked from it is put down.
    if (_searchFocus.hasFocus) _selection.clear();
    final showing = _searchFocus.hasFocus && _searchController.text.trim().isNotEmpty;
    if (showing == _resultsPortal.isShowing) return;
    showing ? _resultsPortal.show() : _resultsPortal.hide();
  }

  /// Puts the list away by giving focus to the map rather than dropping it:
  /// on the web a click can blur the browser's focus for a moment, and
  /// `ViewFocusGuard` answers that by restoring the node focused last — the
  /// map's, where nothing else would hold it, rather than the scope an
  /// unfocus leaves it on.
  void _leaveSearch() => _mapFocus.requestFocus();

  /// Takes the map to [match], opens its card and puts the list away, the
  /// text left in the field for coming back to.
  void _goTo(Map<String, dynamic> match) {
    final at = locationForSuggestion(match);
    _leaveSearch();
    _selection.select(match);
    if (at != null) _camera.moveTo(at.latitude, at.longitude, zoom: _matchZoom);
  }

  /// Blocks a second tap while [_startOperation] is in flight — see the
  /// Home view's own guard on its "+".
  bool _startingOperation = false;

  /// A new operation carrying [refs], opened the way the Home view's "+"
  /// opens one: on its Activities pane, where they are listed for the
  /// operator to check. A single-reference program keeps the last of its own
  /// ([refsKeptWhenAdding]), as adding them one by one would; the refs place
  /// the operation and name it as they would from the sheet.
  Future<void> _startOperation(List<Map<String, dynamic>> refs) async {
    if (_startingOperation) return;
    _startingOperation = true;
    final translations = context.t;
    final navigator = Navigator.of(context);
    final services = widget.services;
    try {
      var kept = <Map<String, dynamic>>[];
      for (final ref in refs) {
        final type = ref['type'] as String?;
        kept = [
          ...refsKeptWhenAdding(
            refs: kept,
            type: type,
            allowsMultiple: allowsMultipleRefsOfType(type, suggestion: ref, control: controlForRefType(_controls, type)),
          ),
          ref,
        ];
      }
      final created = await services.operations.create(stationCall: services.settings.activeProfile.operatorCall);
      final withRefs = Operation(uuid: created.uuid, data: {...created.data, 'refs': kept});
      final fragments = await services.operationTitles.suggestFragments(withRefs);
      await services.operations.saveData(
        fragments == null ? withRefs : Operation(uuid: created.uuid, data: {...withRefs.data, 'title': buildGeneratedTitle(translations, fragments)}),
      );
      services.track('operation_created', {'from': 'maps'});
      unawaited(services.settings.recordOnboardingShown(OnboardingFlows.newOperation));
      if (!mounted) {
        _startingOperation = false;
        return;
      }
      unawaited(
        navigator
            .push(slideInFromRight<void>((_) => OperationView(services: services, operationUuid: created.uuid, openActivities: true)))
            .whenComplete(() => _startingOperation = false),
      );
    } catch (_) {
      _startingOperation = false;
      rethrow;
    }
  }

  Future<void> _loadControls() async {
    ControlsResult result;
    try {
      await widget.services.extensions.start();
      result = await widget.services.extensions.operationControls(_operation.data);
    } on ExtensionHostException catch (e) {
      // An extension misbehaving: logged, never uploaded — see the
      // Activities sheet's own `_loadControls`.
      debugPrint('[maps] operationControls failed: $e');
      result = (controls: const <Map<String, dynamic>>[], loadFailed: true);
    } catch (e, stack) {
      ErrorReportingService.report(e, stack, context: 'maps:operationControls');
      result = (controls: const <Map<String, dynamic>>[], loadFailed: true);
    }
    if (!mounted) return;
    setState(() {
      _controls = result.controls;
      _controlsLoaded = true;
      _shownLists = Map.identity();
      _noteMappedActivities();
    });
  }

  /// One entry per activity running that has been on the map or is hidden
  /// from it, by its first operation control and named by its extension —
  /// in the controls' own order, the extensions' priority.
  List<({String key, String name, Map<String, dynamic> control})> get _activities {
    final seen = <String>{};
    final locale = LocaleSettings.currentLocale.languageCode;
    final extensions = widget.services.extensions.availableExtensions;
    return [
      for (final control in _controls)
        if (controlScopeWord(control) != null)
          if (_activityKeyOf(control) case final key when (_mappedActivities.contains(key) || _hiddenActivities.contains(key)) && seen.add(key))
            (
              key: key,
              name: extensions.where((info) => info.key == key).firstOrNull?.nameFor(locale) ?? (control['label'] as String?) ?? key,
              control: control,
            ),
    ];
  }

  static String _activityKeyOf(Map<String, dynamic> control) => ((control['key'] as String?) ?? '').split('/').first;

  /// Whether [ref] is of an activity the operator has not hidden. One that no
  /// running activity handles is shown, as the map would show it.
  bool _shows(Map<String, dynamic> ref) {
    if (_hiddenActivities.isEmpty) return true;
    final control = controlForRef(_controls, type: ref['type'] as String?, code: refCodeOf(ref));
    return control == null || !_hiddenActivities.contains(_activityKeyOf(control));
  }

  void _setActivityShown(String key, bool shown) {
    final hidden = {..._hiddenActivities};
    shown ? hidden.remove(key) : hidden.add(key);
    unawaited(widget.services.settings.prefs.setStringList(_hiddenActivitiesKey, hidden.toList()..sort()));
    setState(() {
      _hiddenActivities = hidden;
      _shownLists = Map.identity();
    });
  }

  Future<RefLink?> _linkFor(Map<String, dynamic> ref) async {
    try {
      final key = refLinkKey(ref);
      if (key == null) return null;
      return _search.links[key] ?? (await resolveRefLinks(widget.services, [ref]))[key];
    } catch (e, stack) {
      ErrorReportingService.report(e, stack, context: 'maps:linkForRef');
      return null;
    }
  }

  void _setOverlays(MapOverlays overlays) {
    final prefs = widget.services.settings.prefs;
    unawaited(prefs.setBool(_imageryKey, overlays.imagery));
    unawaited(prefs.setBool(_boundariesKey, overlays.boundaries));
    unawaited(prefs.setBool(_facilitiesKey, overlays.facilities));
    setState(() => _overlays = overlays);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t.mapsView;
    final location = widget.services.location;
    final here = location.status == LocationStatus.available ? location.location : null;
    final railWidth = HomeNavigationRail.widthFor(context, expanded: homeRail.expanded);
    final leadingWidth = HomeRailLogo.headerReserveOf(context, railWidth: railWidth);
    final activities = _activities;
    final leadActivity = activities.where((a) => !_hiddenActivities.contains(a.key)).firstOrNull ?? activities.firstOrNull;
    _shownLists = {
      for (final refs in [_search.suggestions, _search.exploredSuggestions])
        refs: _shownLists[refs] ?? (_hiddenActivities.isEmpty ? refs : refs.where(_shows).toList()),
    };
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        flexibleSpace: windowHeaderGestureArea(),
        leadingWidth: leadingWidth,
        leading: const SizedBox.shrink(),
        titleSpacing: Space.xl,
        // A height of its own: the app bar's title slot leaves it unbounded,
        // and this layout fills what it is given.
        title: SizedBox(
          height: 40,
          child: CustomMultiChildLayout(
            delegate: _HeaderLayout(center: MediaQuery.sizeOf(context).width / 2 - railWidth - leadingWidth - Space.xl),
            children: [
              LayoutId(id: _HeaderSlot.title, child: Text(t.title)),
              LayoutId(
                id: _HeaderSlot.search,
                child: OverlayPortal(
                  controller: _resultsPortal,
                  overlayChildBuilder: _matchesList,
                  child: CompositedTransformTarget(
                    link: _resultsLink,
                    child: SizedBox(height: 36, child: _searchField(context)),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [windowsCaptionSpacer(context)],
      ),
      body: Focus(
        focusNode: _mapFocus,
        child: Stack(
          children: [
            Positioned.fill(
              child: ActivitiesResultsMap(
                suggestions: _shownLists[_search.suggestions]!,
                exploredSuggestions: _shownLists[_search.exploredSuggestions]!,
                controls: _controls,
                refs: const [],
                settings: widget.services.settings,
                geoshapes: widget.services.geoshapes,
                outlineGrid: widget.services.outlineGrid,
                camera: _camera,
                linkFor: _linkFor,
                onExplore: _search.explore,
                fitKey: '${_search.answeredSearches}',
                currentLocation: here,
                currentLocationIsGps: true,
                overlays: _overlays,
                // The imagery's labels: the light basemap, whatever the setting
                // or the app's theme would pick.
                mapStyle: _overlays.imagery ? MapStyle.liberty : null,
                picksColumn: true,
                selection: _selection,
                onStartOperation: _startOperation,
                hintsWhenEmpty: false,
              ),
            ),
            // Down the right edge: zoom, the activities and layers, then back
            // to where the operator is.
            Positioned(
              top: Space.md,
              right: Space.md,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: Space.md,
                children: [
                  MapZoomButtons(controller: _camera),
                  if (leadActivity != null)
                    MapRoundButton(
                      icon: resolveIconName(leadActivity.control['icon'] as String?),
                      semanticLabel: t.activities,
                      onPressed: () => _toggle(_Panel.activities),
                    ),
                  MapRoundButton(
                    icon: _panel == _Panel.layers ? MdiIcons.layers : MdiIcons.layersOutline,
                    semanticLabel: t.layers,
                    onPressed: () => _toggle(_Panel.layers),
                  ),
                  MapRoundButton(
                    icon: MdiIcons.crosshairsGps,
                    semanticLabel: t.currentLocation,
                    onPressed: here == null ? null : () => _camera.moveTo(here.latitude, here.longitude),
                  ),
                ],
              ),
            ),
            // Beside the buttons rather than over them.
            if (_panel == _Panel.activities)
              Positioned(
                top: Space.md,
                right: Space.md + kMinInteractiveDimension + Space.md,
                child: PlatformViewShield(
                  child: _ActivitiesPanel(
                    controls: _controls,
                    activities: activities,
                    hidden: _hiddenActivities,
                    onShown: _setActivityShown,
                    onClose: () => setState(() => _panel = null),
                    theme: theme,
                  ),
                ),
              ),
            if (_panel == _Panel.layers)
              Positioned(
                top: Space.md,
                right: Space.md + kMinInteractiveDimension + Space.md,
                child: PlatformViewShield(
                  child: _LayersPanel(
                    style: widget.services.settings.mapStyle,
                    overlays: _overlays,
                    onStyle: (style) {
                      if (_overlays.imagery) _setOverlays(_overlays.copyWith(imagery: false));
                      unawaited(widget.services.settings.setMapStyle(style));
                    },
                    onOverlays: _setOverlays,
                    onClose: () => setState(() => _panel = null),
                    theme: theme,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _toggle(_Panel panel) => setState(() => _panel = _panel == panel ? null : panel);

  /// The typed search's matches, as wide as the field and hanging from it.
  /// Each one with a place to go to takes the map there; one without is
  /// listed, dimmed, so the list still says what the search found.
  Widget _matchesList(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t.mapsView;
    final matches = _search.areSearchResults ? _search.suggestions.where(_shows).toList() : const <Map<String, dynamic>>[];
    final miles = widget.services.settings.distanceUnits == DistanceUnits.miles;
    return CompositedTransformFollower(
      link: _resultsLink,
      targetAnchor: Alignment.bottomLeft,
      offset: const Offset(0, Space.xs),
      showWhenUnlinked: false,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: _resultsLink.leaderSize?.width,
          // Part of the field as far as a tap is concerned: a tap on a match
          // is not a tap outside it.
          child: TextFieldTapRegion(
            child: PlatformViewShield(
              child: Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                elevation: 4,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_search.loading) const LinearProgressIndicator(minHeight: 2),
                      if (matches.isEmpty && !_search.loading)
                        Padding(
                          padding: const EdgeInsets.all(Space.lg),
                          child: Text(
                            t.noMatches(text: _searchController.text.trim()),
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      if (matches.isNotEmpty)
                        // Out of focus's reach: with the accessibility DOM on,
                        // a click focuses the row, and the list closing takes
                        // it away — leaving the browser's focus on the page
                        // body, which `ViewFocusGuard` answers by focusing the
                        // view again and Flutter by focusing this search, its
                        // text selected and the list open again.
                        Flexible(
                          child: ExcludeFocus(
                            child: ListView(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: Space.sm),
                              children: [
                                for (final match in matches)
                                  ListTile(
                                    dense: true,
                                    enabled: locationForSuggestion(match) != null,
                                    leading: activityRefIcon(_controls, match['type'] as String?),
                                    title: Text(
                                      activityRowTitle(controlForRefType(_controls, match['type'] as String?), match),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: switch ([
                                      ?activityRowDetail(match),
                                      if (match['distance'] case final num distance) fmtDistance(distance.toDouble(), miles: miles),
                                    ]) {
                                      final parts when parts.isNotEmpty => Text(parts.join(' • '), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      _ => null,
                                    },
                                    onTap: () => _goTo(match),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The same filled pill as the Logs view's search.
  Widget _searchField(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: _searchController,
      builder: (context, _) => TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        // Every platform, not only touch: on a desktop the field would keep
        // its focus, and the list its place over the map, after a click
        // elsewhere.
        onTapOutside: (_) => _leaveSearch(),
        onChanged: _search.searchSoon,
        onSubmitted: (term) => unawaited(_search.search(term)),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: theme.colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg),
          prefixIcon: const Icon(MdiIcons.magnify),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(MdiIcons.close, semanticLabel: context.t.common.clear),
                  onPressed: () {
                    _searchController.clear();
                    unawaited(_search.search(''));
                  },
                ),
          hintText: context.t.mapsView.searchHint,
          hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.38)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}

enum _Panel { activities, layers }

enum _HeaderSlot { title, search }

/// The header's title at its start and the search field centred on the
/// window — [center] is the window's middle in the title's own box, which
/// starts past the rail and the mark's reserve. The field gives way rightward, then
/// narrows, rather than run into the title on a narrow window.
class _HeaderLayout extends MultiChildLayoutDelegate {
  _HeaderLayout({required this.center});

  final double center;

  static const _maxSearchWidth = 360.0;
  static const _minSearchWidth = 80.0;

  @override
  void performLayout(Size size) {
    final title = layoutChild(_HeaderSlot.title, BoxConstraints.loose(size));
    positionChild(_HeaderSlot.title, Offset(0, (size.height - title.height) / 2));
    final start = title.width + Space.xxl;
    final width = (size.width - start).clamp(_minSearchWidth, _maxSearchWidth);
    final left = (center - width / 2).clamp(start, (size.width - width).clamp(start, double.infinity));
    final search = layoutChild(_HeaderSlot.search, BoxConstraints.tightFor(width: width));
    positionChild(_HeaderSlot.search, Offset(left, (size.height - search.height) / 2));
  }

  @override
  bool shouldRelayout(_HeaderLayout oldDelegate) => oldDelegate.center != center;
}

/// The basemap and what lies over it, picked from a card over the map's
/// corner — every choice takes effect as it is made.
///
/// Satellite is a basemap here and only here: the operator's Map Style
/// setting, which every other map follows, offers the vector styles alone,
/// and picking Satellite leaves it as it was for the next pick to restore.
class _LayersPanel extends StatelessWidget {
  final MapStyle style;
  final MapOverlays overlays;
  final ValueChanged<MapStyle> onStyle;
  final ValueChanged<MapOverlays> onOverlays;
  final VoidCallback onClose;
  final ThemeData theme;

  static const _satellite = 'satellite';

  const _LayersPanel({
    required this.style,
    required this.overlays,
    required this.onStyle,
    required this.onOverlays,
    required this.onClose,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t.mapsView;
    final styles = context.t.settings.map.styleOpts;
    String label(MapStyle style) => switch (style) {
      MapStyle.automatic => styles.automatic,
      MapStyle.liberty => styles.liberty,
      MapStyle.bright => styles.bright,
      MapStyle.positron => styles.positron,
      MapStyle.voyager => styles.voyager,
      MapStyle.darkMatter => styles.darkMatter,
    };
    Widget check(String text, bool value, MapOverlays Function(bool) changed) => CheckboxListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(text),
      value: value,
      onChanged: (on) => onOverlays(changed(on ?? false)),
    );
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      child: SizedBox(
        width: 260,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: Space.lg),
                      child: Text(t.baseMap, style: theme.textTheme.titleSmall),
                    ),
                  ),
                  IconButton(
                    icon: Icon(MdiIcons.close, semanticLabel: context.t.common.close),
                    onPressed: onClose,
                  ),
                ],
              ),
              // Keyed by name, with Satellite beside the setting's own styles.
              RadioGroup<String>(
                groupValue: overlays.imagery ? _satellite : style.name,
                onChanged: (picked) {
                  if (picked == _satellite) {
                    onOverlays(overlays.copyWith(imagery: true));
                  } else if (MapStyle.values.asNameMap()[picked] case final style?) {
                    onStyle(style);
                  }
                },
                child: Column(
                  children: [
                    for (final option in MapStyle.values)
                      RadioListTile<String>(dense: true, visualDensity: VisualDensity.compact, value: option.name, title: Text(label(option))),
                    RadioListTile<String>(dense: true, visualDensity: VisualDensity.compact, value: _satellite, title: Text(t.satellite)),
                  ],
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.lg, Space.xs, Space.lg, Space.xs),
                child: Text(t.layers, style: theme.textTheme.titleSmall),
              ),
              check(t.boundaries, overlays.boundaries, (on) => overlays.copyWith(boundaries: on)),
              check(t.facilities, overlays.facilities, (on) => overlays.copyWith(facilities: on)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The running activities, each with a box that takes its references off the
/// map and out of the search's list — every change taking effect as it is
/// made, as the layers' do.
class _ActivitiesPanel extends StatelessWidget {
  final List<Map<String, dynamic>> controls;
  final List<({String key, String name, Map<String, dynamic> control})> activities;
  final Set<String> hidden;
  final void Function(String key, bool shown) onShown;
  final VoidCallback onClose;
  final ThemeData theme;

  const _ActivitiesPanel({
    required this.controls,
    required this.activities,
    required this.hidden,
    required this.onShown,
    required this.onClose,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      child: SizedBox(
        width: 260,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: Space.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: Space.lg),
                        child: Text(context.t.mapsView.activities, style: theme.textTheme.titleSmall),
                      ),
                    ),
                    IconButton(
                      icon: Icon(MdiIcons.close, semanticLabel: context.t.common.close),
                      onPressed: onClose,
                    ),
                  ],
                ),
                for (final activity in activities)
                  CheckboxListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Row(
                      spacing: Space.md,
                      children: [
                        activityRefIcon(controls, (activity.control['input'] as Map)['refType'] as String, iconSize: 14, avatarRadius: 12),
                        Expanded(child: Text(activity.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    value: !hidden.contains(activity.key),
                    onChanged: (on) => onShown(activity.key, on ?? false),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

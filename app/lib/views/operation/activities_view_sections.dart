// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

part of 'activities_view.dart';

/// Height of the search section's progress bar — reserved whether or not a
/// search is running, so the results below never shift. Matches
/// LinearProgressIndicator's own default thickness.
const _searchProgressHeight = 4.0;

/// Height of the search-field band (excluding the progress slot) at text
/// scale 1. A constant because the band rides in a pinned
/// SliverPersistentHeader, which needs an explicit extent it cannot measure:
/// 8px padding + a 44px dense field/button row + 8px. The OS text-scale
/// preference composes on top of the app's own Font Scale (ui-scaling.md
/// rule 3) and grows the field inside it, so callers scale this — see
/// [_PinnedSearchBand].
const _searchBandHeight = 60.0;

/// Material's single-line ListTile: a plain Activity Types row.
const _optionRowHeight = 56.0;

/// A two-line ListTile — an enable-extension row (title + hint), and the
/// result rows, which carry a detail line.
const _twoLineRowHeight = 72.0;

/// A row and a half, the height a peeking list is cut to. Half a row is the
/// point: a list cut mid-row reads as scrollable, where a whole number of
/// rows reads as the whole list.
const _peekRows = 1.5;

/// The collapsed Activity Types section's default height.
const _optionsPeekHeight = _optionRowHeight * _peekRows;

/// What the results list keeps for itself no matter how far Activity Types
/// grows — see [OperationSheetState._optionsPeekHeightFor].
const _resultsMinPeekHeight = _twoLineRowHeight * _peekRows;

/// The map presentation's own cap on "Current Activities": tall enough to
/// read as more than a sliver, bounded so the map — the reason the operator
/// switched views — still gets most of the height. A fractional row count, so
/// a second activity shows cut part-way and reads as "more below". Internally
/// scrollable past this, same as the list presentation's own peeking sections.
/// Counted in rows at the theme's visual density, which takes 8px off each
/// row on desktop: in bare pixels, two compact rows would fit whole.
const _currentActivitiesMapRows = 1.6;

/// The accordion header's own height: an IconButton (48, Material's minimum
/// tap target) inside [CollapsibleSection]'s `Space.sm` vertical padding.
/// Deliberately a fixed allowance rather than a measurement — it is only
/// ever subtracted, so erring high costs the peek a few pixels and erring
/// low would eat the results area it is there to protect.
const _accordionHeaderHeight = 48.0 + Space.sm * 2;

mixin _ActivitiesSections on State<OperationSheet>, _ActivitiesRefs, _ActivitiesExtensions, _ActivitiesEmptyStates {
  abstract bool _allOptionsFullyOpened;
  Map<String, RefLink> get _refLinks;
  ValueNotifier<bool> get _searchIsEmpty;
  Future<RefLink?> _linkForRef(Map<String, dynamic> ref);
  void _clearSearch();

  /// Whether the results/suggestions area shows the map toggle's map instead
  /// of the ordinary list — ephemeral per sheet open, not a persisted
  /// preference like [_allOptionsExpanded].
  @override
  bool _showResultsMap = false;

  /// The results map's camera, so a Current Activities row can point it at
  /// its own reference. Lives here rather than inside the map because the
  /// rows are this widget's, not the map's; whichever backend the platform
  /// picks wires itself into it when it mounts, and nothing is wired at all
  /// while the list is showing — which is why [_moveMapToRef] is null then.
  final MapZoomController _resultsCamera = MapZoomController();

  bool _isInvalidRef(Map<String, dynamic> entry) => activityRowIsInvalid(_controls, entry);

  /// A reference row's title line, in both lists.
  ///
  /// A reference is an identifier — half of one is not a shorter version of
  /// it, it is the wrong reference — so this shrinks rather than truncates,
  /// trying Roboto's condensed width before giving up any point size.
  /// [shrinkToFitText] reserves condensing for secondary lines; the trade is
  /// deliberately different here, where the line is a code rather than prose.
  /// Its 75% floor still stands: below that a code stops being readable, and
  /// an ellipsis is the better failure.
  Widget _activityRowTitleText(String title) => shrinkToFitText(Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), condensed: true);

  /// A search result's distance and its web button, or `null` when it has
  /// neither — an empty `Row` would still claim the tile's trailing slot and
  /// pull the title in from the edge.
  Widget? _suggestionTrailing(ThemeData theme, Map<String, dynamic> suggestion, {required RefLink? link, required Map<String, dynamic>? control}) {
    final distance = suggestion['distance'];
    if (distance is! num && link == null) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (distance is num)
          Text(
            fmtDistance(distance.toDouble(), miles: widget.services.settings.distanceUnits == DistanceUnits.miles),
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        if (link != null) ...[const SizedBox(width: Space.md), _refLinkButton(link, fallbackName: activityRowTitle(control, suggestion))],
      ],
    );
  }

  /// The web button both lists end with. [fallbackName] names the row for
  /// assistive technology when the extension offered no name of its own.
  Widget _refLinkButton(RefLink link, {required String fallbackName}) {
    return IconButton(
      icon: Icon(MdiIcons.web, semanticLabel: context.t.activitiesView.openReferenceLink(name: link.label ?? fallbackName)),
      onPressed: () => openExternalUrl(link.url),
    );
  }

  /// How tall the collapsed Activity Types section stands, given the height
  /// [available] to the results list and this section together.
  ///
  /// The default peek is a row and a half of the types already loaded — enough
  /// to read as a scrollable list. When the section is also carrying enable
  /// rows, that default can cut the first one in half, and those rows are the
  /// answer to the search the operator just typed. So it grows to hold them
  /// ALL, plus one ordinary row beneath: the extra row is what still says
  /// "there is more below" once the enable rows fill the window.
  ///
  /// Bounded, because the space comes out of the results list directly above —
  /// which keeps its own row and a half whatever this returns. On a window too
  /// short to honor both, the results win and this falls back to the default:
  /// the section can be opened by hand, while a results list squeezed to
  /// nothing has no such escape.
  double _optionsPeekHeightFor(BuildContext context, double available) {
    final scale = MediaQuery.textScalerOf(context);
    final floor = scale.scale(_optionsPeekHeight);
    final enableRows = _disabledMatches.length + _unhandledRefMatches.length + _catalogTier.matches.length + _catalogTier.refMatches.length;
    if (enableRows == 0) return floor;

    final wanted = scale.scale(enableRows * _twoLineRowHeight + _optionRowHeight);
    return clampDouble(wanted, floor, _optionsMaxHeightFor(context, available));
  }

  /// The tallest the Activity Types section may stand, peeking or opened, out
  /// of the [available] box it shares with the results list — which keeps its
  /// own row and a half plus the search band whatever this returns.
  ///
  /// Never below the default peek: on a window too short to honor both, the
  /// results win and the section falls back to peeking, because a section cut
  /// short can be opened by hand while a results list squeezed to nothing has
  /// no such escape.
  double _optionsMaxHeightFor(BuildContext context, double available) {
    final scale = MediaQuery.textScalerOf(context);
    return math.max(
      scale.scale(_optionsPeekHeight),
      available - scale.scale(_accordionHeaderHeight) - scale.scale(_searchBandHeight) - _searchProgressHeight - scale.scale(_resultsMinPeekHeight),
    );
  }

  String _allOptionsTitle(TranslationsEn t) {
    final refListControls = _controls.where((c) => (c['input'] as Map?)?['kind'] == 'refList' || (c['input'] as Map?)?['kind'] == 'form').toList();
    final labels = <String>[];
    for (final control in refListControls) {
      final extensionKey = controlExtensionKey(control);
      final extension = widget.services.extensions.availableExtensions.cast<ExtensionInfo?>().firstWhere(
        (info) => info?.key == extensionKey,
        orElse: () => null,
      );
      final label = extension?.effectiveShortName ?? (control['label'] as String?) ?? '';
      if (label.isNotEmpty && !labels.contains(label)) {
        labels.add(label);
      }
    }
    if (labels.isEmpty) return t.activitiesView.allOptions;
    if (labels.length == 1) {
      return t.activitiesView.activitiesTitle1(first: labels[0]);
    } else if (labels.length == 2) {
      return t.activitiesView.activitiesTitle2(first: labels[0], second: labels[1]);
    } else {
      return t.activitiesView.activitiesTitleMore(first: labels[0], second: labels[1], more: (labels.length - 2).toString());
    }
  }

  /// What tapping a reference's row does while the map is showing: point the
  /// camera at that reference, the same as tapping its own dot. Null leaves
  /// the row inert, exactly as it was before — see [refRowMapTarget] for
  /// when.
  VoidCallback? _moveMapToRef(Map<String, dynamic> ref) {
    final target = refRowMapTarget(ref, mapShowing: _showResultsMap);
    if (target == null) return null;
    return () => _resultsCamera.moveTo(target.latitude, target.longitude);
  }

  /// The "Current Activities" rows (plus the controls-failed notice, when
  /// relevant) — shared between the list presentation's `SliverList` and the
  /// map presentation's plain `Column`, so an operator toggling to the map
  /// doesn't lose sight of what's already on the operation.
  List<Widget> _currentActivityRows(ThemeData theme, Color rowColor) {
    final t = context.t.activitiesView;
    final refs = _operation.refs;
    return [
      if (_controlsState == ControlsLoadState.failed && refs.isNotEmpty) _controlsFailedNotice(theme),
      for (final ref in refs)
        Builder(
          builder: (context) {
            final control = controlForRef(_controls, type: ref['type'] as String?, code: refCodeOf(ref));
            final detail = activityRowDetail(ref);
            final linkKey = refLinkKey(ref);
            final link = linkKey == null ? null : _refLinks[linkKey];
            return Material(
              type: MaterialType.transparency,
              child: _flashableRow(
                ref,
                ListTile(
                  tileColor: _controlsUnreliable ? rowColor : (control == null ? theme.colorScheme.errorContainer.withValues(alpha: 0.4) : rowColor),
                  // Right padding matches the header rows' own horizontal
                  // inset, so the RIGHTMOST trailing button lines up under the
                  // search row's location button — same IconButton defaults
                  // (no custom size/padding) too. Any button added left of it
                  // hangs off that alignment rather than moving it, which is
                  // why the web button — the one every list here ends with —
                  // is the rightmost, and Remove sits inside it.
                  contentPadding: const EdgeInsets.only(left: Space.xl, right: Space.lg),
                  leading: _controlsUnreliable && control == null
                      ? const Icon(MdiIcons.toyBrick)
                      // With the code: a reference answered under a legacy type
                      // draws its extension's icon, not the unknown marker.
                      : activityRefIcon(_controls, ref['type'] as String?, code: refCodeOf(ref)),
                  title: Row(
                    children: [
                      Flexible(child: _activityRowTitleText(activityRowTitle(control, ref))),
                      if (_isInvalidRef(ref))
                        Padding(
                          padding: const EdgeInsets.only(left: Space.md),
                          child: ActivityRowChip(label: t.invalidReference, unavailable: true),
                        ),
                      if (activityRowIsRetired(ref))
                        Padding(
                          padding: const EdgeInsets.only(left: Space.md),
                          child: ActivityRowChip(label: t.retiredReference, unavailable: true),
                        ),
                    ],
                  ),
                  subtitle: detail == null ? null : Text(detail),
                  // Tappable only for a type that declares it has something to
                  // edit — a plain ref activity doesn't, so the row stays inert
                  // rather than offering to retype a code its own search
                  // already resolved.
                  // The editor wins where a type has one: the tune button
                  // beside it opens the same thing, but a form-configured
                  // reference has nothing else that does, and a row that
                  // panned the map instead would strand it.
                  onTap: refTypeIsEditable(control) ? () => _editRef(ref) : _moveMapToRef(ref),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The row has always opened the editor on tap, with
                      // nothing to say so. This is that affordance made
                      // visible, not a second way in — same condition as the
                      // tap above, so the two can never disagree about whether
                      // a row is configurable.
                      if (refTypeIsEditable(control))
                        IconButton(
                          icon: Icon(MdiIcons.tune, semanticLabel: t.editActivity),
                          onPressed: () => _editRef(ref),
                        ),
                      IconButton(
                        icon: Icon(MdiIcons.delete, semanticLabel: t.removeActivity),
                        onPressed: () => _deleteRef(ref),
                      ),
                      // Absent, not disabled, when the program has no page for
                      // this reference (and while the hook is still answering):
                      // a placeholder would be a dead control rather than free
                      // space. Its gap is wider than the one between the other
                      // buttons — leaving a reference and destroying one are
                      // different enough that they should not sit a thumb's
                      // width apart.
                      if (link != null) ...[const SizedBox(width: Space.md), _refLinkButton(link, fallbackName: activityRowTitle(control, ref))],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
    ];
  }

  Widget _resultsArea(BuildContext context, ThemeData theme, List<Map<String, dynamic>> refs, Color accordionColor, Color onAccordionColor, Color rowColor) {
    final locStatus = widget.services.location.status;
    final operationGrid = _operation.displayGrid;

    // Every variation is the same filled button: white icon and
    // label on a state color, rather than colored text on nothing.
    const onLocationColor = Colors.white;
    final Widget locationPin;
    final String label;
    final Color locationColor;
    // The glyph behind [locationPin], for the results map's own
    // dot — the pill's widget can't be handed to a map backend
    // that draws pixels rather than widgets.
    final IconData locationIcon;
    // A GPS location, stored or live: the map draws it as the
    // blue dot every map app uses rather than as the pill's own
    // glyph (see [gpsMapDot]).
    final bool locationIsGps;

    // The SAME question the empty state asks, so the two can't
    // contradict each other over a grid the search can't place:
    // a half-typed `FN` saved unvalidated must not label this
    // button "located" under a notice still saying it isn't.
    if (_hasOperationGrid) {
      // The same pin the Map tab puts on the operation's own marker.
      final pin = operationLocationPin(_operation, deviceGrid: widget.services.location.grid);
      locationIsGps = operationLocationIsGps(_operation, deviceGrid: widget.services.location.grid);
      locationIcon = pin.icon;
      locationPin = Icon(locationIcon, color: onLocationColor);
      // A fix says where the device is, and its locator is
      // the least of what it holds — the source is what the
      // operator needs to read off the pill.
      label = locationIsGps ? 'GPS' : operationGrid!;
      locationColor = pin.color;
    } else {
      if (locStatus == LocationStatus.unknown || locStatus == LocationStatus.determining) {
        // The pulse is an animation over the same glyph, and a
        // map marker takes one frame of it.
        locationIsGps = true;
        locationIcon = gpsPillIcon;
        locationPin = const PulsingGpsPin(color: onLocationColor);
        label = 'GPS…';
        locationColor = gpsDotColor;
      } else if (locStatus == LocationStatus.available && widget.services.location.displayGrid != null) {
        locationIsGps = true;
        locationIcon = gpsPillIcon;
        locationPin = Icon(locationIcon, color: onLocationColor);
        label = widget.services.location.displayGrid!;
        locationColor = gpsDotColor;
      } else if (locStatus == LocationStatus.available && widget.services.location.displayGrid == null) {
        locationIsGps = true;
        locationIcon = gpsPillIcon;
        locationPin = const PulsingGpsPin(color: onLocationColor);
        label = 'GPS…';
        locationColor = gpsDotColor;
      } else {
        locationIsGps = false;
        // The only variant that can end up with no label, so the
        // only one that would otherwise announce nothing — and it
        // is on screen exactly while the notice below tells the
        // operator to tap it. Named the way this app names an
        // icon-only button (see no_hover_tooltips_test).
        locationIcon = MdiIcons.mapMarkerOff;
        locationPin = Icon(locationIcon, color: onLocationColor, semanticLabel: context.t.operationLocationScreen.title);
        // A grid that got this far is one the search can't place.
        // Keeping it on the button, in the red state, says which
        // text is the problem; dropping it would leave the operator
        // wondering where what they typed went.
        label = operationGrid ?? '';
        locationColor = const Color(0xFFC62828);
      }
    }

    // The results map's own "you are here" dot — the same
    // coordinate and color as the pill above, computed by the
    // same two branches (operation grid first, then a live GPS
    // fix) so the dot and the pill can never disagree about
    // where "here" is. Null exactly when the pill has nothing to
    // show either (still determining, denied, or an unplaceable
    // grid) — there's nothing to plot in that state.
    final currentLocation = _hasOperationGrid ? _operation.location : (locStatus == LocationStatus.available ? widget.services.location.location : null);

    final searchBand = _searchBand(
      context,
      theme,
      accordionColor: accordionColor,
      onAccordionColor: onAccordionColor,
      label: label,
      locationPin: locationPin,
      locationColor: locationColor,
      onLocationColor: onLocationColor,
    );
    final resultRows = _resultRows(theme, refs, rowColor);

    // The map is a sibling of the scroll area, never a sliver
    // inside it: a platform-view-backed map backend (the GL
    // webview/web view — see activities_results_map.dart) loses
    // pointer events to the CustomScrollView's own drag
    // recognizer when embedded as one of its slivers, so every
    // tap on a marker is swallowed before the map ever sees it.
    // OsmMapView's pure-Flutter canvas isn't affected, but
    // routing every backend through the same sibling structure
    // keeps this one thing true regardless of which backend a
    // platform happens to pick.
    if (_showResultsMap) {
      final currentActivityRows = _currentActivityRows(theme, rowColor);
      return Column(
        children: [
          if (currentActivityRows.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.textScalerOf(context).scale((_twoLineRowHeight + theme.visualDensity.baseSizeAdjustment.dy) * _currentActivitiesMapRows),
              ),
              child: ScrollEdgeShadows(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(mainAxisSize: MainAxisSize.min, children: currentActivityRows),
                  ),
                ),
              ),
            ),
          searchBand,
          Expanded(
            child: ActivitiesResultsMap(
              suggestions: _searchState.suggestions,
              controls: _controls,
              refs: refs,
              settings: widget.services.settings,
              geoshapes: widget.services.geoshapes,
              outlineGrid: widget.services.outlineGrid,
              camera: _resultsCamera,
              onAdd: _addSuggestion,
              onRemove: _deleteRef,
              linkFor: _linkForRef,
              exploredSuggestions: _searchState.exploredSuggestions,
              onExplore: _searchState.explore,
              fitKey: '${_searchState.answeredSearches}',
              currentLocation: currentLocation,
              operationLocation: _operation.location,
              operationGrid: _operation.displayGrid,
              currentLocationColor: locationColor,
              currentLocationIcon: locationIcon,
              currentLocationIconColor: onLocationColor,
              currentLocationIsGps: locationIsGps,
            ),
          ),
        ],
      );
    }

    // One ink layer PER ROW: a ListTile's tileColor/splash ink
    // clips to the nearest Material's bounds, which must be the
    // row itself for rows scrolled out of this viewport to stop
    // painting.
    return CustomScrollView(
      slivers: [
        SliverList(delegate: SliverChildListDelegate(_currentActivityRows(theme, rowColor))),
        // The band pins below the sheet's header once the
        // activity rows above it scroll away; the results keep
        // scrolling underneath it.
        SliverPersistentHeader(
          pinned: true,
          delegate: _PinnedSearchBand(height: MediaQuery.textScalerOf(context).scale(_searchBandHeight) + _searchProgressHeight, child: searchBand),
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            if (resultRows.isEmpty && !_searchBusy)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.md),
                child: _suggestionsEmptyContent(theme),
              )
            else
              for (final row in resultRows) Material(type: MaterialType.transparency, child: row),
          ]),
        ),
      ],
    );
  }

  Widget _searchBand(
    BuildContext context,
    ThemeData theme, {
    required Color accordionColor,
    required Color onAccordionColor,
    required String label,
    required Widget locationPin,
    required Color locationColor,
    required Color onLocationColor,
  }) {
    final t = context.t.activitiesView;
    final searchBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: onAccordionColor.withValues(alpha: 0.25)),
    );

    final narrow = !ShirtSize.of(context).isTwoPane;
    return Material(
      color: accordionColor,
      child: Column(
        children: [
          SizedBox(
            height: MediaQuery.textScalerOf(context).scale(_searchBandHeight),
            child: Padding(
              padding: EdgeInsets.fromLTRB(narrow ? Space.md : Space.xl, Space.md, narrow ? Space.md : Space.lg, Space.md),
              child: Row(
                children: [
                  Expanded(
                    // Listens to _searchIsEmpty, not the controller
                    // directly nor the outer rebuild cycle:
                    // the search only notifies after its 400ms
                    // debounce fires, which would leave the clear
                    // button lagging a beat behind every keystroke
                    // instead of tracking the field live — and
                    // _searchIsEmpty only flips (so only rebuilds)
                    // when the button's own presence actually changes,
                    // not on every keystroke or caret move. The focus
                    // node rides along for the map button's label.
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_searchIsEmpty, _searchFocusNode]),
                      builder: (context, _) {
                        // A search being typed or read gets the band's
                        // width; the map button gives up its label for it.
                        // Never on the map, where the field is disabled and
                        // the label is how the operator finds the way back.
                        final mapButtonCompact = !_showResultsMap && (_searchFocusNode.hasFocus || !_searchIsEmpty.value);
                        return Row(
                          children: [
                            Expanded(
                              // A field focus comes to rest in, emptied —
                              // see keyboard_dismiss.dart.
                              child: TapToDismissEmptyField(
                                focusNode: _searchFocusNode,
                                controller: _searchController,
                                child: TextField(
                                  selectAllOnFocus: false,
                                  // The map answers where the operator is, not
                                  // what they typed: searching is the list's job.
                                  enabled: !_showResultsMap,
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  decoration: InputDecoration(
                                    hintText: t.searchHint,
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.only(left: Space.md, right: Space.sm),
                                      child: Icon(MdiIcons.magnify, color: onAccordionColor.withValues(alpha: 0.6)),
                                    ),
                                    prefixIconConstraints: const BoxConstraints(),
                                    suffixIcon: _searchIsEmpty.value || _showResultsMap
                                        ? null
                                        : IconButton(
                                            icon: Icon(MdiIcons.close, color: onAccordionColor.withValues(alpha: 0.6), semanticLabel: context.t.common.clear),
                                            onPressed: _clearSearch,
                                          ),
                                    filled: true,
                                    // Paler than the band it sits on, so the field
                                    // reads as a well rather than blending in.
                                    fillColor: theme.colorScheme.surface,
                                    border: searchBorder,
                                    // Contrast is against the field's own `surface`
                                    // fill, not the accordion band around it — the
                                    // indicator is drawn over the well.
                                    focusedBorder: haloFocusedBorder(searchBorder, context),
                                    isDense: true,
                                  ),
                                  onChanged: _searchState.searchSoon,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: narrow ? Space.xs : Space.md),
                              // Full-strength, unlike the magnify and clear icons
                              // inside the field: those decorate the well they sit
                              // in, while this is an action of its own alongside
                              // it, and dimming it reads as disabled.
                              child: TextButton(
                                style: TextButton.styleFrom(foregroundColor: onAccordionColor),
                                onPressed: () => setState(() => _showResultsMap = !_showResultsMap),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedSize(
                                      duration: const Duration(milliseconds: 200),
                                      curve: Curves.easeOut,
                                      child: mapButtonCompact
                                          ? const SizedBox.shrink()
                                          : Padding(
                                              padding: const EdgeInsets.only(right: Space.md),
                                              child: Text(_showResultsMap ? t.searchToggle : t.mapToggle, maxLines: 1, softWrap: false),
                                            ),
                                    ),
                                    Icon(
                                      _showResultsMap ? MdiIcons.formatListBulleted : MdiIcons.map,
                                      // Compact, the label that named the button is gone.
                                      semanticLabel: mapButtonCompact ? t.mapToggle : null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: narrow ? Space.xs : Space.md),
                    // With no grid to show there is no label, and
                    // TextButton.icon still reserves the 8px gap before
                    // one plus M3's wider trailing inset — which reads as
                    // the pin sitting off-centre in its own button. The
                    // plain button centres it, at the same size: both
                    // variants share one defaultStyleOf.
                    child: label.isEmpty
                        ? TextButton(
                            style: TextButton.styleFrom(backgroundColor: locationColor, foregroundColor: onLocationColor),
                            onPressed: _editLocation,
                            child: locationPin,
                          )
                        : TextButton.icon(
                            icon: locationPin,
                            label: Text(
                              label,
                              style: const TextStyle(fontFamily: 'RobotoMono', fontWeight: FontWeight.bold),
                            ),
                            style: TextButton.styleFrom(backgroundColor: locationColor, foregroundColor: onLocationColor),
                            onPressed: _editLocation,
                          ),
                  ),
                ],
              ),
            ),
          ),
          // The slot is always there, empty when idle: showing
          // and hiding the bar itself would move every row under
          // it by its height each time a search resolved.
          SizedBox(
            height: _searchProgressHeight,
            child: _searchBusy ? const LinearProgressIndicator(minHeight: _searchProgressHeight) : null,
          ),
        ],
      ),
    );
  }

  List<Widget> _resultRows(ThemeData theme, List<Map<String, dynamic>> refs, Color rowColor) {
    final t = context.t.activitiesView;
    return <Widget>[
      // Switched-off extensions that match are NOT here: they
      // answer "which activities exist", not "which reference do I
      // add", so they live in the Activity Types section below and
      // this list stays what the operator searched for.
      for (final suggestion in _searchState.suggestions)
        Builder(
          builder: (context) {
            final alreadySelected = refs.any((r) => r['type'] == suggestion['type'] && r['ref'] == suggestion['ref']);
            if (suggestionHidesAsAlreadyAdded(alreadyAdded: alreadySelected, suggestionsAreSearchResults: _searchState.areSearchResults)) {
              return const SizedBox.shrink();
            }
            final suggestionControl = controlForRefType(_controls, suggestion['type'] as String?);
            final suggestionLinkKey = refLinkKey(suggestion);
            final suggestionLink = suggestionLinkKey == null ? null : _searchState.links[suggestionLinkKey];
            return ListTile(
              tileColor: _controlsUnreliable
                  ? rowColor
                  : (isUnknownRefType(_controls, suggestion['type'] as String?) ? theme.colorScheme.errorContainer.withValues(alpha: 0.4) : rowColor),
              // Only a ref with NO control is ambiguous. A partial
              // failure leaves the hooks that did answer perfectly
              // usable, and blanking their icons too overstates the
              // damage.
              leading: _controlsUnreliable && suggestionControl == null
                  ? const Icon(MdiIcons.toyBrick)
                  : activityRefIcon(_controls, suggestion['type'] as String?),
              title: Row(
                children: [
                  // Not `spaceBetween` with a trailing `Spacer`: a
                  // Spacer is a flex child, so it would split the
                  // row's free space with the title's own `Flexible`
                  // and cap the reference at half the width before
                  // it had shrunk a single point. Laid out from the
                  // start, the chips take what they need and the
                  // reference takes the rest.
                  Flexible(child: _activityRowTitleText(activityRowTitle(suggestionControl, suggestion))),
                  if (_isInvalidRef(suggestion))
                    Padding(
                      padding: const EdgeInsets.only(left: Space.md),
                      child: ActivityRowChip(label: t.invalidReference, unavailable: true),
                    ),
                  if (activityRowIsRetired(suggestion))
                    Padding(
                      padding: const EdgeInsets.only(left: Space.md),
                      child: ActivityRowChip(label: t.retiredReference, unavailable: true),
                    ),
                  // Marked, not disabled: tapping still goes through
                  // `_addSuggestion`, which flashes the existing
                  // Current Activities row rather than adding a
                  // second copy.
                  if (alreadySelected)
                    Padding(
                      padding: const EdgeInsets.only(left: Space.md),
                      child: ActivityRowChip(label: t.alreadySelected),
                    ),
                ],
              ),
              subtitle: Text(activityRowDetail(suggestion) ?? ''),
              // Same inset as the Current Activities rows, so the
              // web button sits at the same distance from the edge
              // in both lists — clear of the scrollbar, and lined up
              // with the search row's location button above.
              contentPadding: const EdgeInsets.only(left: Space.xl, right: Space.lg),
              // The distance rides in the trailing group rather than
              // in the title row: `trailing` is centred against the
              // whole two-line tile, where the title row would pin it
              // to the first line. It stays LEFT of the button — the
              // edge belongs to the same web button the Current
              // Activities rows end with, whichever list a reference
              // is being read about from.
              trailing: _suggestionTrailing(theme, suggestion, link: suggestionLink, control: suggestionControl),
              onTap: () => _addSuggestion(suggestion),
            );
          },
        ),
    ];
  }

  Widget _allOptionsSection(
    ThemeData theme,
    Color accordionColor,
    Color onAccordionColor,
    Color rowColor, {
    required double optionsPeekHeight,
    required double optionsMaxHeight,
  }) {
    final t = context.t.activitiesView;
    return CollapsibleSection.band(
      title: Padding(
        padding: const EdgeInsets.only(right: Space.xl),
        child: Text(
          _allOptionsTitle(context.t),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(color: onAccordionColor, fontWeight: FontWeight.w600),
        ),
      ),
      expanded: _allOptionsExpanded,
      onToggle: () {
        setState(() {
          if (_allOptionsExpanded) {
            _allOptionsExpanded = false;
            widget.services.settings.prefs.setBool('activitiesAllOptionsHidden', true);
          } else {
            _allOptionsExpanded = true;
            _allOptionsFullyOpened = true;
            widget.services.settings.prefs.setBool('activitiesAllOptionsHidden', false);
          }
        });
      },
      headerColor: accordionColor,
      onHeaderColor: onAccordionColor,
      trailing: TextButton.icon(
        onPressed: _openExtensionsPanel,
        icon: Icon(MdiIcons.toyBrick, size: 18, color: onAccordionColor),
        label: Text(t.manage, style: TextStyle(color: onAccordionColor)),
        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: Space.lg)),
      ),
      child: () {
        final allOptionsContent = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // FIRST in the section, because this is the one row that
            // answers the search the operator just typed. The section
            // grows to hold these ([_optionsPeekHeightFor]) but is
            // bounded by the results list's own claim, so on a short
            // window they are the rows that have to fit; below the
            // loaded types they would be the rows that get cut.
            for (final info in _disabledMatches) _notRunningRow(info, hint: t.enableExtensionHint, scopeSearch: true),
            // Next, and for the same reason: the remedy for a red
            // "unknown" row in Current Activities.
            for (final info in _unhandledRefMatches) _notRunningRow(info, hint: t.enableExtensionForRefHint, scopeSearch: false),
            // Last of the three tiers, and last for a reason: what the
            // app already has is always the cheaper answer, so an
            // install is offered only under the rows that need no
            // download at all.
            for (final entry in [..._catalogTier.matches, ..._catalogTier.refMatches])
              InstallExtensionRow(entry: entry, onTap: () => unawaited(_installCatalogExtension(entry))),
            for (final control in _controls)
              if ((control['input'] as Map?)?['kind'] == 'refList' || (control['input'] as Map?)?['kind'] == 'form')
                ListTile(
                  tileColor: rowColor,
                  leading: _accentIcon(control['icon'] as String?, resolveExtensionColor(control['color'] as String?)),
                  title: Text((control['label'] as String?) ?? ''),
                  onTap: () => _scopeSearchTo(control),
                ),
          ],
        );
        return _allOptionsFullyOpened
            // Bounded and scrollable even when opened: this list holds
            // every loaded type AND every enable row a search turns up,
            // and as an unbounded Column beside the results list it
            // squeezes them out from under the operator as they type.
            // That failure is a RenderFlex overflow, which ErrorPolicy
            // treats as `logOnly` — release builds clip it silently, so
            // nothing would ever report it.
            ? ConstrainedBox(
                constraints: BoxConstraints(maxHeight: optionsMaxHeight),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  // Same ink-clipping reason as the peeking branch below.
                  child: Material(type: MaterialType.transparency, child: allOptionsContent),
                ),
              )
            : SizedBox(
                height: optionsPeekHeight,
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  // Its own ink layer, INSIDE the scroll view, so the
                  // viewport clips it along with the rows. A ListTile
                  // paints `tileColor` with `Ink`, onto the nearest
                  // ancestor Material — without this that's the
                  // sheet's root, above this scroll view, and ink is
                  // clipped to that Material's bounds rather than to
                  // the viewport in between, so
                  // rows scrolled out of this peeking window would still
                  // paint their backgrounds over the sections above.
                  // MaterialType.transparency: an ink layer, no
                  // surface of its own.
                  child: Material(type: MaterialType.transparency, child: allOptionsContent),
                ),
              );
      }(),
    );
  }
}

/// The search band's pinned-sliver delegate — fixed extent
/// ([_searchBandHeight] + [_searchProgressHeight]), since a
/// SliverPersistentHeader can't size itself to its child.
class _PinnedSearchBand extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _PinnedSearchBand({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  // A pinned sliver whose child paints shorter or taller than the extent it
  // declared throws ("layoutExtent exceeds paintExtent"), so the child is
  // held to exactly that box rather than trusted to match it.
  Widget _sized(Widget child) => SizedBox(height: height, child: child);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => _sized(child);

  // Always true: [child] is rebuilt fresh by the enclosing build, so the
  // comparison would never match anyway — and a false here would leave the
  // stale band on screen, since RenderSliverPersistentHeader only picks up a
  // new delegate when this says so.
  @override
  bool shouldRebuild(_PinnedSearchBand oldDelegate) => true;
}

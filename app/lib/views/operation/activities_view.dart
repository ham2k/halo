// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Activities pane, shown via showModalPane (docs/design/layouts.md —
// full screen on phones, a dialog on wide layouts) with `scrollable: false`
// since its sections divide the pane's height themselves: three accordion
// sections — "Current Activities" (title shows the count; one row per ref,
// tap to edit, delete button to remove; open by default), "Suggestions &
// Search" (the search field itself is the header; open by default and
// expands to fill the remaining space) and "All Options" (every active
// activity type, for adding one manually; closed by default).
// Start/break/end events are deferred — this pane is activities-only for
// now.
//
// A plain ExpansionTile can't "fill the remaining space" (it always sizes
// to its content inside a scrollable list), so the accordion here is a
// small custom widget instead: each section is either content-sized or,
// when marked `fill`, wrapped in Expanded with its own internally
// scrollable body.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../services/halo_services.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import '../../services/extensions/catalog_service.dart';
import '../../services/error_reporting_service.dart';
import '../../services/location_service.dart';
import '../../services/extensions/extension_service.dart';
import '../../services/link_opener.dart';
import '../../services/settings_service.dart';
import 'activities_catalog_tier.dart';
import 'activities_enable_tier.dart';
import 'operation_location_screen.dart';
import '../operation_dialogs.dart';
import '../extensions_panel.dart';
import 'package:halo_i18n/halo_i18n.dart';
import '../../tools/distance_format.dart';
import '../../tools/operation_title.dart';
import '../map/map_zoom_controller.dart';
import 'activities_results_map.dart';
import 'activity_rows.dart';
import 'activity_search_query.dart';
import 'activity_search_state.dart';
import 'operation_location_pin.dart';

export 'activity_rows.dart';
export 'activity_search_query.dart';

part 'activities_view_empty_states.dart';
part 'activities_view_extensions.dart';
part 'activities_view_header.dart';
part 'activities_view_refs.dart';
part 'activities_view_sections.dart';

/// An icon, circled in [color] at 60% opacity when the control declares an
/// accent — sparingly used, so a control with no color just
/// renders the bare icon.
Widget _accentIcon(String? iconName, Color? color) {
  final icon = Icon(resolveIconName(iconName));
  if (color == null) return icon;
  return CircleAvatar(backgroundColor: color.withValues(alpha: 0.6), child: icon);
}

/// The vaguest fix the setup sheet stores on its own: past this a position
/// is a Wi-Fi or IP estimate that can name the wrong town, and storing it
/// would put that town in every export.
const _maxCaptureAccuracyMeters = 500.0;

/// The operation sheet's body: the activities list and search, plus the
/// operation's own controls. Driven through its [OperationSheetState] by the
/// screen that presents it (saving, and pushing draft edits back in).
class OperationSheet extends StatefulWidget {
  final HaLoServices services;
  final Operation operation;
  final ValueChanged<Operation>? onOperationChanged;

  /// Opens the operation-details editor (callsign, title, notes) — owned by
  /// the presenting screen, which routes the result back in through
  /// [OperationSheetState.updateOperation].
  final VoidCallback? onEditDetails;

  /// True when [OperationSheetState.saveAndClose] starts — before it waits on
  /// the extension host for the title — and false again only if the save
  /// fails, so the presenting screen can show its accept control as busy for
  /// that wait.
  final ValueChanged<bool>? onClosingChanged;

  const OperationSheet({super.key, required this.services, required this.operation, this.onOperationChanged, this.onEditDetails, this.onClosingChanged});

  @override
  State<OperationSheet> createState() => OperationSheetState();
}

class OperationSheetState extends State<OperationSheet>
    with _ActivitiesHeader, _ActivitiesRefs, _ActivitiesExtensions, _ActivitiesEmptyStates, _ActivitiesSections {
  @override
  late Operation _operation;

  void updateOperation(Operation op) {
    if (mounted) {
      final before = _operation;
      setState(() => _operation = op);
      _reloadControlsIfRefsChanged(before, op);
      _researchIfLocationChanged(before, op);
    }
  }

  @override
  List<Map<String, dynamic>> _controls = const [];
  @override
  ControlsLoadState _controlsState = ControlsLoadState.loading;

  /// Where each of the operation's refs can be read about on the web, keyed by
  /// [refLinkKey]. Resolved for display only — a link is never written onto
  /// the ref, so it follows the extension rather than the saved operation.
  @override
  Map<String, RefLink> _refLinks = const {};
  int _refLinksRequest = 0;

  /// Whether the descriptors are good enough to judge a ref type by. Both
  /// non-loaded states say no: an absent control means "not loaded yet" or
  /// "the hook could not answer", and rendering either as the unknown-type
  /// treatment tells the operator an installed extension isn't there.
  @override
  bool get _controlsUnreliable => _controlsState != ControlsLoadState.loaded;
  int _controlsRequest = 0;

  @override
  final _searchController = TextEditingController();
  @override
  final _searchFocusNode = FocusNode();

  /// Flips only when [_searchController]'s text crosses empty/non-empty —
  /// not on every keystroke once it's non-empty, and not on a caret move at
  /// all — so the clear button's AnimatedBuilder rebuilds the search field
  /// only when whether the button shows actually changes, not on every
  /// notification the controller fires.
  @override
  late final ValueNotifier<bool> _searchIsEmpty;
  void _onSearchControllerChanged() {
    final isEmpty = _searchController.text.isEmpty;
    if (isEmpty != _searchIsEmpty.value) _searchIsEmpty.value = isEmpty;
  }

  /// The search box's and the results map's questions to the extensions,
  /// and their answers.
  @override
  late final ActivitySearchState _searchState = ActivitySearchState(
    services: widget.services,
    currentOperation: () => _operation,
    scopes: () => _activityScopes,
    controlsLoaded: () => _controlsState == ControlsLoadState.loaded,
    onAnswered: _onSearchAnswered,
  )..addListener(_onSearchStateChanged);
  void _onSearchStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  late bool _allOptionsExpanded;
  @override
  late bool _allOptionsFullyOpened;

  // Only watched when the operation itself has no grid — its own grid
  // always takes priority over live GPS (see ExtensionService.suggestActivities).
  bool _watchingLocation = false;

  @override
  void initState() {
    super.initState();
    _operation = widget.operation;
    _loadControls();
    _searchIsEmpty = ValueNotifier(_searchController.text.isEmpty);
    _searchController.addListener(_onSearchControllerChanged);

    final hidden = widget.services.settings.prefs.getBool('activitiesAllOptionsHidden') ?? false;
    _allOptionsExpanded = !hidden;
    _allOptionsFullyOpened = false;

    _watchingLocation = true;
    widget.services.location.start();
    widget.services.location.addListener(_onLocationChanged);
    widget.services.dataRevision.addListener(_onDataFilesChanged);
    _searchState.search('');
    // After the first frame: a fix already streaming for another view is
    // live now, and capturing it writes through `onOperationChanged` into a
    // parent that is mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeCaptureFix());
  }

  @override
  void dispose() {
    _searchState.dispose();
    _flashTimer?.cancel();
    _searchController.removeListener(_onSearchControllerChanged);
    widget.services.dataRevision.removeListener(_onDataFilesChanged);
    _searchIsEmpty.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    if (_watchingLocation) {
      widget.services.location.removeListener(_onLocationChanged);
      widget.services.location.stop();
    }
    super.dispose();
  }

  // Re-runs the current search once the device's first GPS fix comes in (or
  // its status otherwise changes), so nearby suggestions appear without the
  // user having to touch the search field themselves. Routed through the
  // same debounce as typed search — the position stream can otherwise fire
  // every few seconds while moving (e.g. driving), each one triggering a
  // fresh round of extension-hook lookups.
  void _onLocationChanged() {
    if (!mounted) return;
    _maybeCaptureFix();
    _searchState.searchSoon(_searchController.text);
  }

  /// Stores the device's live fix as the operation's location, for an
  /// operation being set up: no location yet and no contacts logged.
  ///
  /// `available` is a LIVE fix here, not a remembered one: this view started
  /// the service, and starting it puts a stopped stream back to `determining`
  /// until a new position arrives. A location already stated — by the
  /// operator, or by a park the refs placed — is never replaced; nor is one on
  /// an operation with contacts, which may be a log reopened far from where it
  /// was made.
  ///
  /// The first fix a device reports is often its worst — a cached position, a
  /// Wi-Fi or IP estimate — so while the sheet stays open, the fix THIS
  /// session captured is replaced by any more accurate one. A fix vaguer than
  /// [_maxCaptureAccuracyMeters] is never stored. Once the operator edits the
  /// location here, capturing stops: clearing it, or picking another, is
  /// their answer.
  void _maybeCaptureFix() {
    if (!mounted || _locationEditedHere) return;
    final location = widget.services.location;
    final position = location.position;
    final fix = location.location;
    if (location.status != LocationStatus.available || position == null || fix == null) return;
    if (_operation.qsoCount > 0) return;
    // Zero or less is a platform that does not report one, not a perfect fix.
    final accuracy = position.accuracy > 0 ? position.accuracy : null;
    if (accuracy != null && accuracy > _maxCaptureAccuracyMeters) return;
    final refining = _capturedAccuracy != null && _operation.data['gridSource'] == gpsGridSource;
    if (refining) {
      if (accuracy == null || accuracy >= _capturedAccuracy!) return;
    } else if (_operation.location != null) {
      return;
    }
    _capturedAccuracy = accuracy ?? double.infinity;
    _saveOperationData(gpsLocationData(fix));
  }

  /// The accuracy radius of the fix this session captured, or null when it
  /// has captured none. Infinite for one whose platform reported none, which
  /// any fix that does report one then refines.
  double? _capturedAccuracy;

  /// Set once the operator changes the location in this sheet, which ends
  /// capturing for the session.
  bool _locationEditedHere = false;

  @override
  Future<void> _loadControls() async {
    // Refs change faster than the host answers — adding two activities in a row
    // leaves two lookups in flight, and the slower one must not install the
    // descriptors for the earlier state.
    final request = ++_controlsRequest;
    ControlsResult result;
    try {
      // A runtime still booting has no host, which `_collectControls` reports
      // as a failure — correctly, but the sheet can open inside that window
      // (the onboarding auto-open fires on a ~300ms transition) and "could not
      // load" is a lie about a runtime that is merely starting. Idempotent, so
      // every call after the first costs nothing.
      await widget.services.extensions.start();
      if (!mounted) return;
      result = await widget.services.extensions.operationControls(_operation.data);
    } on ExtensionHostException catch (e) {
      // An extension misbehaving: logged, never uploaded. A report the
      // maintainer cannot act on is noise (docs/design/error-reporting.md).
      debugPrint('[extensions] operationControls failed: $e');
      result = (controls: const <Map<String, dynamic>>[], loadFailed: true);
    } catch (e, stack) {
      // Anything else reaching here is OUR bug, not an extension's, and a
      // bare catch would bury it for good. Uploaded without a notice: the
      // failed state below is what the operator needs to see.
      //
      // The state machine has to terminate on every path either way. Without
      // it the sheet sits on `loading` forever — the placeholder has no
      // terminal state of its own, and `_controlsUnreliable` suppresses the
      // very treatment that would show something is wrong.
      ErrorReportingService.report(e, stack, context: 'activities:operationControls');
      result = (controls: const <Map<String, dynamic>>[], loadFailed: true);
    }
    if (mounted && request == _controlsRequest) {
      setState(() {
        _controls = result.controls;
        _controlsState = result.loadFailed ? ControlsLoadState.failed : ControlsLoadState.loaded;
        _refreshUnhandledRefMatches();
      });
      // Links come from the same runtime the descriptors do, so they are
      // reloaded together rather than on triggers of their own. Enabling an
      // extension from Manage Extensions, retrying failed controls and a
      // restart after a failed boot all reload the descriptors — and each
      // one can change what `linkForRef` answers, for refs that never
      // changed.
      unawaited(_loadRefLinks());
    }
  }

  /// One ref's link, from what the lists already resolved when they hold it
  /// — a reference found by panning the map is in neither.
  ///
  /// Reported here, because the map's card reads it through a FutureBuilder,
  /// which keeps an error to itself and would show it as "no link".
  @override
  Future<RefLink?> _linkForRef(Map<String, dynamic> ref) async {
    try {
      final key = refLinkKey(ref);
      if (key == null) return null;
      return _searchState.links[key] ?? _refLinks[key] ?? (await resolveRefLinks(widget.services, [ref]))[key];
    } catch (e, stack) {
      ErrorReportingService.report(e, stack, context: 'activities:linkForRef');
      return null;
    }
  }

  /// Rebuilt from scratch on every reload rather than accumulated: a ref the
  /// operator removed must take its link with it, and so must one whose
  /// extension has just been switched off.
  Future<void> _loadRefLinks() async {
    final request = ++_refLinksRequest;
    final links = await resolveRefLinks(widget.services, _operation.refs);
    if (!mounted || request != _refLinksRequest) return;
    setState(() => _refLinks = links);
  }

  /// Rebuilds the descriptors when the operation's REFS change, from wherever
  /// `_operation` was replaced — a save, a revert, or a draft pushed in by the
  /// parent.
  ///
  /// A control's own form is allowed to depend on which refs the operation
  /// carries: State Parks asks Ohio for the park it is in, a power class and an
  /// entry category, Texas for a power class, and an operation with no event
  /// chosen for none of them. The refs are the only part of the operation a
  /// descriptor is built from, so a title or grid edit doesn't pay for a round
  /// trip.
  @override
  void _reloadControlsIfRefsChanged(Operation before, Operation after) {
    if (!_areRefsEqual(before.refs, after.refs)) _loadControls();
  }

  /// Re-runs the search when the operation's LOCATION changes, from wherever
  /// `_operation` was replaced.
  ///
  /// Nearby suggestions are computed from the grid
  /// ([ExtensionService.suggestActivities]), which outranks the device's own
  /// position — so a location the operator just typed has to produce results
  /// now, not on their next keystroke. The device's GPS has
  /// [_onLocationChanged] to lean on; a hand-typed grid has nothing, and in
  /// the states where the operator is invited to type one there is no fix
  /// coming to fire that listener.
  ///
  /// State and county count too. They are not part of `suggestActivities`'
  /// own `location` argument, but the whole operation map goes to the hooks,
  /// and a program whose references are administrative rather than geographic
  /// answers off exactly those — and the location editor returns all three
  /// together, so filling in only State is an ordinary thing to do.
  ///
  /// Guarded on a real change: every ref added re-enters here. Unset and blank
  /// are the same location — the editor returns `''` for a field never filled
  /// in, so comparing raw would make an unchanged Save pay for a fan-out.
  @override
  void _researchIfLocationChanged(Operation before, Operation after) {
    // `lat`/`lon` alongside the grid: adopting a ref's own coordinate moves
    // the search's centre by up to a few kilometres without the grid changing
    // at all, and a nearby search run from the wrong one of those two points
    // is exactly what this whole path exists to prevent.
    const keys = ['grid', 'lat', 'lon', 'state', 'county'];
    if (keys.every((key) => (before.data[key] ?? '') == (after.data[key] ?? ''))) return;
    unawaited(_searchState.search(_searchController.text));
  }

  bool _areRefsEqual(List<dynamic> a, List<dynamic> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final mapA = a[i] as Map?;
      final mapB = b[i] as Map?;
      if (mapA == null || mapB == null) {
        if (mapA != mapB) return false;
        continue;
      }
      if (!mapEquals(mapA, mapB)) return false;
    }
    return true;
  }

  @override
  void _clearSearch() {
    _searchController.clear();
    unawaited(_searchState.search(''));
    _searchFocusNode.requestFocus();
  }

  /// See [activityScopesOf].
  @override
  Map<String, List<String>> get _activityScopes => activityScopesOf(_controls, widget.services.extensions.availableExtensions);

  static String? _scopeWordOf(Map<String, dynamic> control) => controlScopeWord(control);

  /// Opens the operation's location editor and folds whatever it returns back
  /// into the operation. Shared by the search band's location pill and the
  /// empty state's hint, which point at the same thing.
  @override
  Future<void> _editLocation() async {
    final patch = await showHaloDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => OperationLocationScreen(services: widget.services, operation: _operation),
    );
    if (patch == null) return;
    if (!mounted) {
      // Not the same as cancelling: the operator entered a location and it is
      // going nowhere. Takes a route popping out from under the open editor.
      debugPrint('[activities] location edit discarded: the sheet unmounted while the editor was open');
      return;
    }
    _locationEditedHere = true;
    final updated = Operation(
      uuid: _operation.uuid,
      data: {..._operation.data, ...patch},
      qsoCount: _operation.qsoCount,
      startAtMillisMin: _operation.startAtMillisMin,
      startAtMillisMax: _operation.startAtMillisMax,
      localData: _operation.localData,
    );
    // A location arriving here re-runs the search — see
    // [_researchIfLocationChanged].
    updateOperation(updated);
    widget.onOperationChanged?.call(updated);
  }

  /// Whether the operation carries a location of its own, and so needs nothing
  /// from the device.
  ///
  /// Measured by what the SEARCH can do with it, not by the field being
  /// filled: `suggestActivities` runs the grid through [gridToLocation] and
  /// gets nothing for `''`, which still arrives through sync and import. The
  /// location editor now refuses a locator this can't place, so it is no
  /// longer a source of them — but it is not the only door into the field, and
  /// one read as a location would answer a muted "No suggestions" over a grid
  /// the hooks were never given: the "there is nothing near you" misreading
  /// this whole notice exists to prevent, reached by way of taking its advice.
  @override
  bool get _hasOperationGrid => _operation.location != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final refs = _operation.refs;
    // The same color the sheet's top row shows — matching it by hand would
    // drift the moment the pane's own banding changes.
    final accordionColor = haloDialogBandColorAt(context);
    final onAccordionColor = theme.colorScheme.onSurfaceVariant;
    // Rows paint an opaque color so they read distinctly from the pane's
    // gray/dark background (the ColoredBox below), which otherwise shows
    // straight through wherever a filling section has no row to draw. The
    // pane brings this background itself so both Modal Pane presentations
    // (full screen and dialog card) look the same. Shared with the Layout
    // Setup sheet through theme.dart — two list sheets a shade apart read
    // as a mistake.
    final listBgColor = haloSheetListBackground(context);
    final rowColor = haloSheetRowColor(context);

    // Escape, a system back and a tap outside the sheet (the pane's own
    // maybePop) save it before it closes, which is what the details editor's
    // own writes — contacts restamped, the position — count on. The save's
    // own pop is a Navigator.pop, which this does not hold back.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(saveOrLeave());
      },
      // No taps while [saveAndClose] runs: the save has already taken its
      // snapshot, so an edit made during the wait would look applied and
      // never be stored.
      child: AbsorbPointer(
        absorbing: _isClosing,
        child: Material(
          color: listBgColor,
          child: Column(
            children: [
              _headerBand(theme, refs, accordionColor, onAccordionColor),
              // The results list and Activity Types share what the header leaves,
              // and this LayoutBuilder is what measures it: the peek height below
              // is carved out of exactly this box, so the two cannot both claim
              // the same pixels. Measuring the results list itself instead would
              // be circular — its height is what the peek decides.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, sheetBody) {
                    final optionsPeekHeight = _optionsPeekHeightFor(context, sheetBody.maxHeight);
                    final optionsMaxHeight = _optionsMaxHeightFor(context, sheetBody.maxHeight);
                    return Column(
                      children: [
                        // Selected activities, the search field and its results live in
                        // ONE clipped scroll area — only Activity Types below keeps the
                        // accordion behavior.
                        Expanded(child: Builder(builder: (context) => _resultsArea(context, theme, refs, accordionColor, onAccordionColor, rowColor))),
                        if (!_showResultsMap)
                          _allOptionsSection(
                            theme,
                            accordionColor,
                            onAccordionColor,
                            rowColor,
                            optionsPeekHeight: optionsPeekHeight,
                            optionsMaxHeight: optionsMaxHeight,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

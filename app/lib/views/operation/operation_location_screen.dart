// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Operation Location screen, a port of app-polo's OperationLocationScreen:
// a "Selected Location" grid field, a "Suggested Locations" list (device GPS
// plus any current activity ref that already has its own grid — tapping
// either adopts that grid as the operation's), and "More Details" for the
// optional State/Province and County fields. Each field auto-saves on blur/
// submit, matching ActivitiesView's save-as-you-go style rather than a
// single dialog-style Save button.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_extension_host/halo_extension_host.dart';

import '../../services/halo_services.dart';
import '../../services/error_reporting_service.dart';
import '../../services/extensions/extension_service.dart';
import '../../services/location_service.dart';
import '../../services/us_subdivision_lookup.dart';
import '../../tools/operation_gps_subdivisions.dart';
import 'operation_location_pin.dart';
import 'package:halo_i18n/halo_i18n.dart';

class OperationLocationScreen extends StatefulWidget {
  final HaLoServices services;
  final Operation operation;
  final List<UsSubdivisionCandidate> gpsBoundaryChoices;

  const OperationLocationScreen({super.key, required this.services, required this.operation, this.gpsBoundaryChoices = const []});

  @override
  State<OperationLocationScreen> createState() => _OperationLocationScreenState();
}

/// A boundary choice only offers to fill missing or GPS-supplied details.
/// An empty string is an operator's explicit clear, just like it is for prefill.
List<UsSubdivisionCandidate> gpsBoundaryChoicesFor(Map<String, dynamic> data, List<UsSubdivisionCandidate> candidates) {
  final statedState = asQsonString(data['state']);
  final state = statedState?.trim().toUpperCase();
  final county = asQsonString(data['county'])?.trim().toUpperCase();
  final manualState = statedState != null && statedState != data['gpsState'];
  final manualCounty = county != null && !gpsSuppliedCounty(data);
  return candidates.where((candidate) {
    final candidateCounty = candidate.county?.trim().toUpperCase();
    final matchesState = state == candidate.state;
    final matchesCounty = county == candidateCounty;
    return (!manualState || matchesState) &&
        (!manualCounty || matchesCounty || (candidateCounty == null && county == '')) &&
        (!matchesState || (candidateCounty != null && !matchesCounty));
  }).toList();
}

class _OperationLocationScreenState extends State<OperationLocationScreen> {
  late final _gridController = TextEditingController(text: widget.operation.displayGrid ?? '');
  late final _stateController = TextEditingController(text: asQsonString(widget.operation.data['state']) ?? '');
  late final _countyController = TextEditingController(text: asQsonString(widget.operation.data['county']) ?? '');
  final _gridFocus = FocusNode();
  final _stateFocus = FocusNode();
  final _countyFocus = FocusNode();

  late final _subdivisions = <String, dynamic>{
    for (final key in const ['state', 'gpsState', 'county', 'gpsCounty'])
      if (widget.operation.data.containsKey(key)) key: widget.operation.data[key],
  };
  late List<UsSubdivisionCandidate> _gpsBoundaryChoices = gpsBoundaryChoicesFor(_subdivisions, widget.gpsBoundaryChoices);
  int _gpsRequest = 0;
  Future<void>? _pendingGpsSubdivisions;

  static final _twoLetterState = RegExp(r'^[A-Za-z]{2}$');

  String? _gridSource;

  /// The coordinate behind whatever is in the grid field, when it was adopted
  /// from something that knew one — the device's own fix, or a ref carrying
  /// its published position. Cleared the moment the operator types, so a
  /// hand-entered locator never ships with the precision of the suggestion it
  /// replaced (see [_onGridTextChanged]).
  ///
  /// Seeded from the operation like [_gridSource] is (in `initState`): this
  /// screen returns a patch that gets spread over the operation's data, so a
  /// field the operator never touched has to come back holding what it
  /// arrived with, or an untouched Save strips the stored fix.
  late GridLocation? _adoptedLocation = widget.operation.exactLocation;

  List<Map<String, dynamic>> _controls = const [];
  ControlsLoadState _controlsState = ControlsLoadState.loading;

  // While this is true, _controls is empty or incomplete — a ref whose
  // extension IS active would otherwise flash the unknown-type
  // red/question-mark treatment for a moment on every open, and wear it
  // permanently when a hook failed to answer (mirrors ActivitiesView's own
  // _controlsUnreliable).
  bool get _controlsUnreliable => _controlsState != ControlsLoadState.loaded;

  @override
  void initState() {
    super.initState();
    _gridSource = asQsonString(widget.operation.data['gridSource']);
    _gridController.addListener(_onGridTextChanged);
    _stateFocus.addListener(_onStateFocusChange);
    _loadControls();
    widget.services.location.start();
    widget.services.location.addListener(_onLocationChanged);
  }

  Future<void> _loadControls() async {
    ControlsResult result;
    try {
      // Wait for a booting runtime rather than calling its absence a failure
      // — see ActivitiesView._loadControls. Idempotent.
      await widget.services.extensions.start();
      if (!mounted) return;
      result = await widget.services.extensions.operationControls(widget.operation.data);
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] operationControls failed: $e');
      result = (controls: const <Map<String, dynamic>>[], loadFailed: true);
    } catch (e, stack) {
      // Ours, not an extension's — see ActivitiesView._loadControls. Every
      // path still has to reach a terminal state: an escaped exception
      // otherwise leaves the screen on `loading`, which suppresses the
      // unknown-type treatment indefinitely rather than showing anything.
      ErrorReportingService.report(e, stack, context: 'operationLocation:operationControls');
      result = (controls: const <Map<String, dynamic>>[], loadFailed: true);
    }
    if (mounted) {
      setState(() {
        _controls = result.controls;
        _controlsState = result.loadFailed ? ControlsLoadState.failed : ControlsLoadState.loaded;
      });
    }
  }

  @override
  void dispose() {
    _gridController.removeListener(_onGridTextChanged);
    _stateFocus.removeListener(_onStateFocusChange);
    widget.services.location.removeListener(_onLocationChanged);
    widget.services.location.stop();
    _gridController.dispose();
    _stateController.dispose();
    _countyController.dispose();
    _gridFocus.dispose();
    _stateFocus.dispose();
    _countyFocus.dispose();
    super.dispose();
  }

  void _onLocationChanged() {
    if (mounted) setState(() {});
  }

  void _onGridTextChanged() {
    // A replacement can keep the same locator text. The controller still
    // sees it, and the field now states the square instead of the old point.
    if (!_gridRejected && _gridSource == 'manual' && _adoptedLocation == null) return;
    setState(() {
      _gridRejected = false;
      _gridSource = 'manual';
      _adoptedLocation = null;
      _clearGpsSubdivisions();
    });
  }

  /// A 2-letter entry reads as an abbreviation ("CA"), not a proper noun
  /// with an oddly-capitalized second letter ("Ca") — full names ("New
  /// Brunswick") are left to whatever case the operator typed, since
  /// [CapitalizeFirstLetterTextFormatter] already handled the first letter
  /// live.
  String _normalizeState(String text) => _twoLetterState.hasMatch(text) ? text.toUpperCase() : text;

  /// Only on blur, not as-typed, so a state that's on its way to becoming a
  /// longer word doesn't get force-capitalized mid-keystroke. `_save` applies
  /// [_normalizeState] itself too — `onSubmitted` can reach it before this
  /// listener's own blur has fired, and the field must read correctly either
  /// way, not depend on which happened first.
  void _onStateFocusChange() {
    if (_stateFocus.hasFocus) return;
    _stateController.text = _normalizeState(_stateController.text.trim());
  }

  /// The device's fix, stored the way the setup sheet captures one
  /// ([gpsLocationData]): rounded, with the locator for the rounded point.
  void _adoptFix(GridLocation fix, double accuracy) {
    final data = gpsLocationData(fix);
    _adoptGrid(data['grid'] as String, gpsGridSource, location: GridLocation(data['lat'] as double, data['lon'] as double));
    if (widget.operation.qsoCount == 0 && accuracy > 0 && accuracy.isFinite) {
      _pendingGpsSubdivisions = _fillGpsSubdivisions(fix, accuracy, _gpsRequest);
    }
  }

  Future<void> _fillGpsSubdivisions(GridLocation fix, double accuracy, int request) async {
    final (:state, :county, :candidates) = await lookupGpsSubdivisions(widget.services.usSubdivisionLookup, fix, accuracy);
    if (!mounted || request != _gpsRequest) return;
    _pendingGpsSubdivisions = null;
    _applySubdivisionPatch(gpsSubdivisionPatch(_subdivisions, state: state, county: county));
    if (candidates.isNotEmpty) setState(() => _gpsBoundaryChoices = gpsBoundaryChoicesFor(_subdivisions, candidates));
  }

  void _applySubdivisionPatch(Map<String, dynamic> patch) {
    _subdivisions.addAll(patch);
    if (patch.containsKey('state')) _stateController.text = asQsonString(patch['state']) ?? '';
    if (patch.containsKey('county')) _countyController.text = asQsonString(patch['county']) ?? '';
  }

  void _clearGpsSubdivisions() {
    _gpsRequest++;
    _pendingGpsSubdivisions = null;
    _gpsBoundaryChoices = const [];
    _applySubdivisionPatch(gpsSubdivisionPatch(_subdivisions));
  }

  void _chooseGpsBoundary(UsSubdivisionCandidate choice) {
    // A state-only choice leaves an already entered county in that state
    // alone. A county chosen on the other side of a state line cannot stay.
    final previousState = asQsonString(_subdivisions['state'])?.trim().toUpperCase();
    final previousCounty = asQsonString(_subdivisions['county']);
    final changesCounty = choice.county != null || (previousState != choice.state && previousCounty != null && previousCounty.isNotEmpty);
    setState(() {
      _applySubdivisionPatch({'state': choice.state, 'gpsState': null, if (changesCounty) 'county': choice.county, if (changesCounty) 'gpsCounty': null});
    });
  }

  void _editState(String text) {
    if (gpsSuppliedCounty(_subdivisions) && text.trim().toUpperCase() != asQsonString(_subdivisions['state'])?.trim().toUpperCase()) {
      _applySubdivisionPatch({'county': null, 'gpsCounty': null});
    }
    _subdivisions['state'] = text;
    _subdivisions['gpsState'] = null;
    if (_gpsBoundaryChoices.isNotEmpty) setState(() => _gpsBoundaryChoices = gpsBoundaryChoicesFor(_subdivisions, _gpsBoundaryChoices));
  }

  void _editCounty(String text) {
    _subdivisions['county'] = text;
    _subdivisions['gpsCounty'] = null;
    if (_gpsBoundaryChoices.isNotEmpty) setState(() => _gpsBoundaryChoices = gpsBoundaryChoicesFor(_subdivisions, _gpsBoundaryChoices));
  }

  void _adoptGrid(String grid, String source, {GridLocation? location}) {
    setState(() {
      _gridSource = source;
      _adoptedLocation = location;
      _gridRejected = false;
      _gridController.removeListener(_onGridTextChanged);
      _gridController.text = grid;
      _gridController.addListener(_onGridTextChanged);
      _clearGpsSubdivisions();
    });
  }

  /// Set once a save has been refused, so the field explains itself. Not shown
  /// while typing: a locator is invalid for most of the time it takes to type
  /// one, and a field that goes red at the second keystroke is nagging.
  bool _gridRejected = false;

  void _save() {
    if (_pendingGpsSubdivisions case final pending?) {
      unawaited(_saveAfterLookup(pending));
      return;
    }
    // GridCaseTextFormatter already keeps the field in the conventional
    // mixed case (FN31pr) live; normalizeGrid here is a safety net for
    // anything that reached the controller some other way (pasted text
    // lands through the formatter too, but this stays cheap and correct
    // either way). It returns anything that isn't well-formed unchanged, so
    // this doesn't interfere with the rejection check below.
    final grid = normalizeGrid(_gridController.text.trim());
    // Not just _onStateFocusChange's job: onSubmitted (Enter in the field
    // itself) reaches here before that blur listener necessarily has,
    // and this must be correct regardless of which fires first.
    final state = _normalizeState(_stateController.text.trim());
    final county = _countyController.text.trim();

    // Nothing downstream validates this: the operation would carry a grid that
    // `gridToLocation` can't place, so nearby suggestions would silently
    // return nothing while every control claimed a location was set.
    if (grid.isNotEmpty && !isWellFormedGrid(grid)) {
      setState(() => _gridRejected = true);
      _gridFocus.requestFocus();
      return;
    }

    // [_adoptedLocation] is non-null exactly while the field still holds the
    // locator it was adopted with: every path that changes the text runs
    // [_onGridTextChanged], which clears it. Nothing re-checks that here —
    // a second guard on the same rule would be one this dialog can never
    // reach, and a defence that cannot fire is not a defence.
    //
    // A hand-typed locator falls back to its own square's center, so the
    // operation always carries a coordinate for everything that MEASURES
    // from one (docs/design/locations.md). It never lengthens what was
    // typed: `gridForDisplay` recognises a pair that is the stored grid's
    // own center and shows the grid as written.
    final location = _adoptedLocation ?? locationForStatedGrid(grid);
    Navigator.of(context).pop(<String, dynamic>{
      'grid': grid.isEmpty ? null : grid,
      'gridSource': grid.isEmpty ? null : _gridSource,
      'lat': location?.latitude,
      'lon': location?.longitude,
      ..._subdivisions,
      if (_subdivisions['state'] != null) 'state': state,
      if (_subdivisions['county'] != null) 'county': county,
    });
  }

  Future<void> _saveAfterLookup(Future<void> pending) async {
    await pending;
    if (mounted && ModalRoute.of(context)?.isCurrent == true) _save();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.operationLocationScreen;
    final theme = Theme.of(context);
    final location = widget.services.location;
    // A ref is offerable when it can place the operation the way the refs do
    // on their own (`locationFollowsRefs`). A `largeArea` ref is not offered:
    // its point stands for a whole trail, which is no place to put a station.
    // In the same order the rule reads them, so the first here is the one it
    // would choose.
    final refsWithGrid = [
      for (final ref in widget.operation.refs)
        if (ref['largeArea'] != true)
          if ((refGrid(ref), refLocation(ref)) case (final grid?, final location?)) (ref: ref, grid: grid, location: location),
    ];

    // The LOCAL problem stays visible under a serving peer fix: with the
    // grid alone, this screen would be the operator's last surface that
    // could say their own GPS is denied — until the peer walks away and it
    // fails with no warning given.
    final localProblem = location.positionIsFromPeer
        ? switch (location.localStatus) {
            LocationStatus.permissionDenied => t.permissionDenied,
            LocationStatus.permissionBlocked => t.permissionBlocked,
            LocationStatus.unavailable => t.gpsUnavailable,
            _ => null,
          }
        : null;
    // What tapping the row stores (`gpsLocationData`), so the line reads the
    // same as the location it would become: the square, and the rounded
    // coordinate behind it.
    // A reading of exactly 0,0 is a receiver with nothing to report yet
    // ([isPlaceholderLocation]); adopted, it would store a `JJ00aa` locator
    // that places the station at Null Island although the pair is refused.
    final fix = switch (location.location) {
      final fix? when !isPlaceholderLocation(fix) => fix,
      _ => null,
    };
    final fixData = fix == null ? null : gpsLocationData(fix);
    final accuracy = location.position?.accuracy ?? 0.0;
    final fixText = fixData == null
        ? ''
        : '${fixData['grid']} (${(fixData['lat'] as double).toStringAsFixed(capturedFixDecimals)}, ${(fixData['lon'] as double).toStringAsFixed(capturedFixDecimals)})';
    final gpsSubtitle = switch (location.status) {
      LocationStatus.available when fix == null => t.locating,
      LocationStatus.available => localProblem == null ? fixText : '$fixText — $localProblem',
      LocationStatus.unknown || LocationStatus.determining => t.locating,
      LocationStatus.permissionDenied => t.permissionDenied,
      LocationStatus.permissionBlocked => t.permissionBlocked,
      LocationStatus.unavailable => t.gpsUnavailable,
    };

    return HaloDialog(
      wide: true,
      scrollable: false,
      title: Text(t.title),
      // Rows and bands to the card's edges, contents inset — the same list
      // every other settings-shaped surface is (SettingsList).
      list: true,
      content: CustomScrollView(
        shrinkWrap: true,
        slivers: [
          SectionHeader.section(
            context,
            t.selectedLocation,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: haloDialogSideInset(context)),
                child: TextField(
                  selectAllOnFocus: false,
                  controller: _gridController,
                  focusNode: _gridFocus,
                  // Field pair/square uppercase, subsquare-on lowercase, live —
                  // see GridCaseTextFormatter.
                  inputFormatters: const [GridCaseTextFormatter()],
                  decoration: poloFieldDecoration(context, t.gridSquare, errorText: _gridRejected ? t.gridInvalid : null),
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(height: Space.md),
            ],
          ),
          if (_gpsBoundaryChoices.isNotEmpty)
            SectionHeader.section(
              context,
              t.nearBoundary,
              children: [
                for (final choice in _gpsBoundaryChoices)
                  ListTile(
                    title: Text(choice.county == null ? choice.state : t.boundaryChoice(county: choice.county!, state: choice.state)),
                    selected: _subdivisions['state'] == choice.state && (choice.county == null || _subdivisions['county'] == choice.county),
                    onTap: () => _chooseGpsBoundary(choice),
                  ),
                const SizedBox(height: Space.md),
              ],
            ),
          SectionHeader.section(
            context,
            t.suggestedLocations,
            children: [
              ListTile(
                // The size of the ref avatars below it, in the blue every GPS
                // location wears (`gpsDotColor`).
                leading: CircleAvatar(
                  backgroundColor: gpsDotColor,
                  child: Icon(gpsPillIcon, color: Colors.white),
                ),
                // A fix served on a peer's behalf is named as such — calling the
                // phone's position "Device GPS" would tell the operator this
                // machine can do something it cannot — and so is one from the
                // station's receiver, which the operator chose over this one.
                title: Text(switch ((location.peerPositionDeviceName, location.receiverName)) {
                  (final device?, _) => t.peerGps(device: device),
                  (null, final receiver?) => t.receiverGps(receiver: receiver),
                  (null, null) => t.deviceGps,
                }),
                subtitle: Text(gpsSubtitle),
                // Live fixes only: the service keeps its last position while it
                // says "Locating…" or that it was denied, and that one can be
                // hours old.
                onTap: location.status != LocationStatus.available || fix == null ? null : () => _adoptFix(fix, accuracy),
              ),
              for (final (index, suggestion) in refsWithGrid.indexed)
                ListTile(
                  tileColor: !_controlsUnreliable && isUnknownRefType(_controls, suggestion.ref['type'] as String?, code: refCodeOf(suggestion.ref))
                      ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
                      : null,
                  leading: _controlsUnreliable
                      ? Icon(MdiIcons.toyBrick)
                      : activityRefIcon(_controls, suggestion.ref['type'] as String?, code: refCodeOf(suggestion.ref)),
                  title: Text((suggestion.ref['shortLabel'] ?? suggestion.ref['ref'] ?? '?') as String),
                  subtitle: Text(suggestion.grid, style: const TextStyle(fontFamily: 'RobotoMono')),
                  // The first is the park the refs place the operation at
                  // anyway, and picking it keeps following them. Any other is
                  // a choice the refs would undo at their next edit — they
                  // always follow the first — so it is stored as the
                  // operator's own, and stays.
                  onTap: () => _adoptGrid(suggestion.grid, index == 0 ? refsGridSource : 'manual', location: suggestion.location),
                ),
              // Only worth saying when a ref is actually standing there without
              // its activity's icon and label — with no refs to explain, the
              // controls are of no consequence to this screen.
              if (_controlsState == ControlsLoadState.failed && refsWithGrid.isNotEmpty)
                ListTile(
                  leading: Icon(MdiIcons.alertCircleOutline, color: theme.colorScheme.error),
                  title: Text(t.controlsUnavailableTitle, style: TextStyle(color: theme.colorScheme.error)),
                  subtitle: Text(t.controlsUnavailableReason),
                  trailing: TextButton(
                    onPressed: () {
                      setState(() => _controlsState = ControlsLoadState.loading);
                      _loadControls();
                    },
                    child: Text(t.controlsUnavailableRetry),
                  ),
                ),
              const SizedBox(height: Space.md),
            ],
          ),
          SectionHeader.section(
            context,
            t.moreDetails,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: haloDialogSideInset(context)),
                child: Column(
                  children: [
                    TextField(
                      selectAllOnFocus: false,
                      controller: _stateController,
                      focusNode: _stateFocus,
                      // A 2-letter abbreviation goes fully uppercase on blur —
                      // see _onStateFocusChange.
                      inputFormatters: const [CapitalizeFirstLetterTextFormatter()],
                      decoration: poloFieldDecoration(context, t.stateOrProvince),
                      onChanged: _editState,
                      onSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: Space.md),
                    TextField(
                      selectAllOnFocus: false,
                      controller: _countyController,
                      focusNode: _countyFocus,
                      inputFormatters: const [CapitalizeFirstLetterTextFormatter()],
                      decoration: poloFieldDecoration(context, t.county),
                      onChanged: _editCounty,
                      onSubmitted: (_) => _save(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.xxl),
            ],
          ),
        ],
      ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(null), child: Text(context.t.common.cancel)),
      actions: [FilledButton(onPressed: _save, child: Text(context.t.common.save))],
    );
  }
}

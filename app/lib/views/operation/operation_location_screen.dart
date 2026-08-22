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

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_extension_host/halo_extension_host.dart';

import '../../main.dart';
import '../../services/error_reporting_service.dart';
import '../../services/extension_service.dart';
import '../../services/location_service.dart';
import '../../i18n/strings.g.dart';

class OperationLocationScreen extends StatefulWidget {
  final HaLoServices services;
  final Operation operation;

  const OperationLocationScreen({
    super.key,
    required this.services,
    required this.operation,
  });

  @override
  State<OperationLocationScreen> createState() => _OperationLocationScreenState();
}

class _OperationLocationScreenState extends State<OperationLocationScreen> {
  late final _gridController = TextEditingController(text: widget.operation.displayGrid ?? '');
  late final _stateController = TextEditingController(text: (widget.operation.data['state'] as String?) ?? '');
  late final _countyController = TextEditingController(text: (widget.operation.data['county'] as String?) ?? '');
  final _gridFocus = FocusNode();
  final _stateFocus = FocusNode();
  final _countyFocus = FocusNode();

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
    _gridSource = widget.operation.data['gridSource'] as String?;
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
    // Editing IS the response to being told the locator is wrong, so the
    // complaint goes away as soon as they act on it rather than surviving
    // until the next Save.
    if (_gridRejected) setState(() => _gridRejected = false);
    if (_gridSource != 'manual' || _adoptedLocation != null) {
      setState(() {
        _gridSource = 'manual';
        _adoptedLocation = null;
      });
    }
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

  void _adoptGrid(String grid, String source, {GridLocation? location}) {
    setState(() {
      _gridSource = source;
      _adoptedLocation = location;
      // Detached so the assignment doesn't read as manual typing — which also
      // means the listener's own clearing of [_gridRejected] doesn't run, and
      // a refused locator replaced by a suggested one would keep the
      // complaint underneath a field that no longer earns it.
      _gridRejected = false;
      _gridController.removeListener(_onGridTextChanged);
      _gridController.text = grid;
      _gridController.addListener(_onGridTextChanged);
    });
  }

  /// Set once a save has been refused, so the field explains itself. Not shown
  /// while typing: a locator is invalid for most of the time it takes to type
  /// one, and a field that goes red at the second keystroke is nagging.
  bool _gridRejected = false;

  void _save() {
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
    Navigator.of(context).pop(<String, dynamic>{
      'grid': grid.isEmpty ? null : grid,
      'gridSource': grid.isEmpty ? null : _gridSource,
      'lat': _adoptedLocation?.latitude,
      'lon': _adoptedLocation?.longitude,
      'state': state,
      'county': county,
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.operationLocationScreen;
    final theme = Theme.of(context);
    final location = widget.services.location;
    // A ref is offerable when it can name a location at all — its own
    // published coordinate (an 8-character locator, and the coordinate itself
    // is what gets adopted) or, for a program whose table has none, its grid.
    final refsWithGrid = [
      for (final ref in widget.operation.refs)
        if (gridForDisplay(lat: ref['lat'], lon: ref['lon'], grid: ref['grid'] as String?) case final grid?)
          (ref: ref, grid: grid, location: locationFromLatLon(ref['lat'], ref['lon'])),
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
    final gpsSubtitle = switch (location.status) {
      LocationStatus.available =>
        localProblem == null
            ? (location.displayGrid ?? '')
            : '${location.displayGrid ?? ''} — $localProblem',
      LocationStatus.unknown || LocationStatus.determining => t.locating,
      LocationStatus.permissionDenied => t.permissionDenied,
      LocationStatus.permissionBlocked => t.permissionBlocked,
      LocationStatus.unavailable => t.gpsUnavailable,
    };

    return HaloDialog(
      wide: true,
      scrollable: false,
      title: Text(t.title),
      contentPadding: EdgeInsets.zero,
      content: ListView(
        shrinkWrap: true,
        children: [
          SectionHeader(t.selectedLocation),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.xl),
            child: TextField(
              selectAllOnFocus: false,
              controller: _gridController,
              focusNode: _gridFocus,
              // Field pair/square uppercase, subsquare-on lowercase, live —
              // see GridCaseTextFormatter.
              inputFormatters: const [GridCaseTextFormatter()],
              decoration: poloFieldDecoration(
                context,
                t.gridSquare,
                errorText: _gridRejected ? t.gridInvalid : null,
              ),
              onSubmitted: (_) => _save(),
            ),
          ),
          const SizedBox(height: Space.md),
          SectionHeader(t.suggestedLocations),
          ListTile(
            leading: Icon(MdiIcons.crosshairsGps),
            // A fix served on a peer's behalf is named as such — calling the
            // phone's position "Device GPS" would tell the operator this
            // machine can do something it cannot.
            title: Text(switch (location.peerPositionDeviceName) {
              final device? => t.peerGps(device: device),
              null => t.deviceGps,
            }),
            subtitle: Text(gpsSubtitle),
            onTap: location.displayGrid == null
                ? null
                : () => _adoptGrid(location.displayGrid!, 'gps', location: location.location),
          ),
          for (final suggestion in refsWithGrid)
            ListTile(
              tileColor: !_controlsUnreliable && isUnknownRefType(_controls, suggestion.ref['type'] as String?)
                  ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
                  : null,
              leading: _controlsUnreliable
                  ? Icon(MdiIcons.toyBrick)
                  : activityRefIcon(_controls, suggestion.ref['type'] as String?),
              title: Text((suggestion.ref['shortLabel'] ?? suggestion.ref['ref'] ?? '?') as String),
              subtitle: Text(suggestion.grid, style: const TextStyle(fontFamily: 'RobotoMono')),
              onTap: () => _adoptGrid(suggestion.grid, 'manual', location: suggestion.location),
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
          SectionHeader(t.moreDetails),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.xl),
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
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: Space.md),
                TextField(
                  selectAllOnFocus: false,
                  controller: _countyController,
                  focusNode: _countyFocus,
                  inputFormatters: const [CapitalizeFirstLetterTextFormatter()],
                  decoration: poloFieldDecoration(context, t.county),
                  onSubmitted: (_) => _save(),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xxl),
        ],
      ),
      cancel: TextButton(
        onPressed: () => Navigator.of(context).pop(null),
        child: Text(context.t.common.cancel),
      ),
      actions: [
        FilledButton(
          onPressed: _save,
          child: Text(context.t.common.save),
        ),
      ],
    );
  }
}

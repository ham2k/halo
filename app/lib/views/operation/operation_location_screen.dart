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
  late final _gridController = TextEditingController(text: widget.operation.grid ?? '');
  late final _stateController = TextEditingController(text: (widget.operation.data['state'] as String?) ?? '');
  late final _countyController = TextEditingController(text: (widget.operation.data['county'] as String?) ?? '');
  final _gridFocus = FocusNode();
  final _stateFocus = FocusNode();
  final _countyFocus = FocusNode();

  static final _twoLetterState = RegExp(r'^[A-Za-z]{2}$');

  String? _gridSource;

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
    if (_gridSource != 'manual') {
      setState(() {
        _gridSource = 'manual';
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

  void _adoptGrid(String grid, String source) {
    setState(() {
      _gridSource = source;
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

    Navigator.of(context).pop(<String, dynamic>{
      'grid': grid.isEmpty ? null : grid,
      'gridSource': grid.isEmpty ? null : _gridSource,
      'state': state,
      'county': county,
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.operationLocationScreen;
    final theme = Theme.of(context);
    final location = widget.services.location;
    final refsWithGrid = widget.operation.refs.where((r) => (r['grid'] as String?)?.isNotEmpty == true).toList();

    final gpsSubtitle = switch (location.status) {
      LocationStatus.available => location.grid ?? '',
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
            title: Text(t.deviceGps),
            subtitle: Text(gpsSubtitle),
            onTap: location.grid == null ? null : () => _adoptGrid(location.grid!, 'gps'),
          ),
          for (final ref in refsWithGrid)
            ListTile(
              tileColor: !_controlsUnreliable && isUnknownRefType(_controls, ref['type'] as String?)
                  ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
                  : null,
              leading: _controlsUnreliable
                  ? Icon(MdiIcons.toyBrick)
                  : activityRefIcon(_controls, ref['type'] as String?),
              title: Text((ref['shortLabel'] ?? ref['ref'] ?? '?') as String),
              subtitle: Text(ref['grid'] as String, style: const TextStyle(fontFamily: 'RobotoMono')),
              onTap: () => _adoptGrid(ref['grid'] as String, 'manual'),
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

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

import '../../main.dart';
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

  String? _gridSource;

  List<Map<String, dynamic>> _controls = const [];
  // While this is true, _controls is still empty — a ref whose extension IS
  // active would otherwise flash the unknown-type red/question-mark
  // treatment for a moment on every open (mirrors ActivitiesView's own
  // _loadingControls).
  bool _loadingControls = true;

  @override
  void initState() {
    super.initState();
    _gridSource = widget.operation.data['gridSource'] as String?;
    _gridController.addListener(_onGridTextChanged);
    widget.services.extensions.operationControls(widget.operation.data).then((controls) {
      if (mounted) {
        setState(() {
          _controls = controls;
          _loadingControls = false;
        });
      }
    });
    widget.services.location.start();
    widget.services.location.addListener(_onLocationChanged);
  }

  @override
  void dispose() {
    _gridController.removeListener(_onGridTextChanged);
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
    final grid = _gridController.text.trim();
    final state = _stateController.text.trim();
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
              tileColor: !_loadingControls && isUnknownRefType(_controls, ref['type'] as String?)
                  ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
                  : null,
              leading: _loadingControls
                  ? Icon(MdiIcons.toyBrick)
                  : activityRefIcon(_controls, ref['type'] as String?),
              title: Text((ref['shortLabel'] ?? ref['ref'] ?? '?') as String),
              subtitle: Text(ref['grid'] as String, style: const TextStyle(fontFamily: 'RobotoMono')),
              onTap: () => _adoptGrid(ref['grid'] as String, 'manual'),
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
                  decoration: poloFieldDecoration(context, t.stateOrProvince),
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: Space.md),
                TextField(
                  selectAllOnFocus: false,
                  controller: _countyController,
                  focusNode: _countyFocus,
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

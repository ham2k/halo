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

import '../../main.dart';
import '../../services/activity_controls.dart';
import '../../services/location_service.dart';
import '../../i18n/strings.g.dart';

class OperationLocationScreen extends StatefulWidget {
  final HaLoServices services;
  final Operation operation;

  const OperationLocationScreen({super.key, required this.services, required this.operation});

  @override
  State<OperationLocationScreen> createState() => _OperationLocationScreenState();
}

class _OperationLocationScreenState extends State<OperationLocationScreen> {
  late Operation _operation;
  late final _gridController = TextEditingController(text: widget.operation.grid ?? '');
  late final _stateController = TextEditingController(text: (widget.operation.data['state'] as String?) ?? '');
  late final _countyController = TextEditingController(text: (widget.operation.data['county'] as String?) ?? '');
  final _gridFocus = FocusNode();
  final _stateFocus = FocusNode();
  final _countyFocus = FocusNode();

  List<Map<String, dynamic>> _controls = const [];

  @override
  void initState() {
    super.initState();
    _operation = widget.operation;
    widget.services.extensions.operationControls(_operation.data).then((controls) {
      if (mounted) setState(() => _controls = controls);
    });
    widget.services.location.start();
    widget.services.location.addListener(_onLocationChanged);
    _gridFocus.addListener(() {
      if (!_gridFocus.hasFocus) _saveGrid();
    });
    _stateFocus.addListener(() {
      if (!_stateFocus.hasFocus) _saveDetails();
    });
    _countyFocus.addListener(() {
      if (!_countyFocus.hasFocus) _saveDetails();
    });
  }

  @override
  void dispose() {
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

  Future<void> _save(Map<String, dynamic> patch) async {
    final updated = Operation(
      uuid: _operation.uuid,
      data: {..._operation.data, ...patch},
      qsoCount: _operation.qsoCount,
      startAtMillisMin: _operation.startAtMillisMin,
      startAtMillisMax: _operation.startAtMillisMax,
      localData: _operation.localData,
    );
    await widget.services.operations.saveData(updated);
    if (mounted) setState(() => _operation = updated);
  }

  Future<void> _saveGrid() async {
    final trimmed = _gridController.text.trim();
    if (trimmed == (_operation.grid ?? '')) return;
    // Clearing the field must actually unset the grid (null), not store ''
    // — ActivitiesView's GPS-fallback gate checks `operation.grid == null`,
    // and an empty string would satisfy that check forever.
    await _save({'grid': trimmed.isEmpty ? null : trimmed});
  }

  Future<void> _saveDetails() async {
    final state = _stateController.text.trim();
    final county = _countyController.text.trim();
    if (state == ((_operation.data['state'] as String?) ?? '') && county == ((_operation.data['county'] as String?) ?? '')) {
      return;
    }
    await _save({'state': state, 'county': county});
  }

  void _adoptGrid(String grid) {
    _gridController.text = grid;
    unawaited(_save({'grid': grid}));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.operationLocationScreen;
    final location = widget.services.location;
    final refsWithGrid = _operation.refs.where((r) => (r['grid'] as String?)?.isNotEmpty == true).toList();

    final gpsSubtitle = switch (location.status) {
      LocationStatus.available => location.grid ?? '',
      LocationStatus.unknown || LocationStatus.determining => t.locating,
      LocationStatus.permissionDenied => t.permissionDenied,
      LocationStatus.unavailable => t.gpsUnavailable,
    };

    return Scaffold(
      appBar: AppBar(
        leadingWidth: macOSAwareLeadingWidth,
        leading: macOSAwareBackButton(),
        title: Text(t.title),
      ),
      body: ListView(
        children: [
          SectionHeader(t.selectedLocation),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _gridController,
              focusNode: _gridFocus,
              decoration: poloFieldDecoration(context, t.gridSquare),
              onSubmitted: (_) => _saveGrid(),
            ),
          ),
          const SizedBox(height: 8),
          SectionHeader(t.suggestedLocations),
          ListTile(
            leading: Icon(resolveIconName('crosshairs-gps')),
            title: Text(t.deviceGps),
            subtitle: Text(gpsSubtitle),
            onTap: location.grid == null ? null : () => _adoptGrid(location.grid!),
          ),
          for (final ref in refsWithGrid)
            ListTile(
              leading: Icon(resolveIconName(iconForRefType(_controls, ref['type'] as String?))),
              title: Text((ref['shortLabel'] ?? ref['ref'] ?? '?') as String),
              subtitle: Text(ref['grid'] as String),
              onTap: () => _adoptGrid(ref['grid'] as String),
            ),
          const SizedBox(height: 8),
          SectionHeader(t.moreDetails),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                TextField(
                  controller: _stateController,
                  focusNode: _stateFocus,
                  decoration: poloFieldDecoration(context, t.stateOrProvince),
                  onSubmitted: (_) => _saveDetails(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _countyController,
                  focusNode: _countyFocus,
                  decoration: poloFieldDecoration(context, t.county),
                  onSubmitted: (_) => _saveDetails(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The logging view: four tabs, ported from app-polo's OperationView —
// "N QSOs" (list + logging panel; a wide-layout info side panel appears
// there too, the first step toward the module-docking layout of
// DESIGN.md §7), Spots (placeholder for now), Map, and Operation
// (settings/activities/data, a scoped-down OpSettingsTab).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../main.dart';
import 'operation_dialogs.dart';
import 'operation/activities_view.dart';
import 'operation/logging_panel.dart';
import 'operation/map_panel.dart';
import 'operation/operation_location_screen.dart';
import '../i18n/strings.g.dart';

class OperationView extends StatefulWidget {
  final HaLoServices services;
  final String operationUuid;

  const OperationView({super.key, required this.services, required this.operationUuid});

  @override
  State<OperationView> createState() => _OperationViewState();
}

class _OperationViewState extends State<OperationView> {
  Operation? _operation;
  List<Map<String, dynamic>> _loggingControls = const [];
  late bool _showRSTFields = widget.services.settings.showRSTFields;
  late bool _showStateField = widget.services.settings.showStateField;
  late bool _showGridField = widget.services.settings.showGridField;
  late bool _showDeletedQSOs = widget.services.settings.showDeletedQSOs;
  late bool _showQsoNumbers = widget.services.settings.showQsoNumbers;

  /// The station's own DXCC entity, resolved once per operation load (not
  /// per QSO — the station call essentially never changes DXCC entity
  /// mid-operation) so the QSO row can tell a DX contact from a domestic
  /// one. `online: false` skips network lookup hooks (QRZ/HamDB), running
  /// only the local, no-network callsign-annotation step that's all this
  /// needs — see extensions/core/lookups/src/annotate.ts.
  String? _ourEntityPrefix;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final operation = await widget.services.operations.get(widget.operationUuid);
    setState(() => _operation = operation);
    if (operation != null) {
      // Extension runtime may still be booting; controls appear when it answers.
      await widget.services.extensions.start();
      final controls = await widget.services.extensions.loggingControls(operation.data);
      if (mounted) setState(() => _loggingControls = controls);

      await _resolveOurEntityPrefix(operation);

      // Scores are cached per-QSO (DESIGN.md §4), so a rescore on open is
      // enough to keep them fresh without re-running on every keystroke.
      // TODO: debounce a rescore after each QSO add/edit/delete too, once
      // there's a safe way to do that without the score-cache write itself
      // re-triggering `watchForOperation`'s stream.
      //
      // Per-QSO scores stream in on their own via `watchForOperation`
      // (rescoring writes `score_cache`, which is a row in that table), but
      // the day/operation summary lives in `Operations.localData` — not
      // watched anywhere — so re-fetch and refresh `_operation` once
      // rescoring lands to pick that up.
      //
      // Only the freshly-scored `localData` gets applied onto whatever
      // `_operation` is current at that point, rather than replacing
      // `_operation` wholesale — this scoring call can take a few seconds,
      // and blindly overwriting would clobber a `data`/counter edit
      // (details, refs) the user made in-between with a stale snapshot.
      unawaited(widget.services.scoring.rescoreOperation(operation).then((_) async {
        if (!mounted) return;
        final rescored = await widget.services.operations.get(widget.operationUuid);
        final current = _operation;
        if (rescored != null && current != null && mounted) {
          setState(() => _operation = Operation(
                uuid: current.uuid,
                data: current.data,
                qsoCount: current.qsoCount,
                startAtMillisMin: current.startAtMillisMin,
                startAtMillisMax: current.startAtMillisMax,
                localData: rescored.localData,
              ));
        }
      }));
    }
  }

  Future<void> _editActivities(Operation operation) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ActivitiesView(services: widget.services, operation: operation)),
    );
    if (!mounted) return;
    final refreshed = await widget.services.operations.get(operation.uuid);
    if (refreshed != null && mounted) setState(() => _operation = refreshed);
  }

  Future<void> _editDetails(Operation operation) async {
    final updated = await editOperationDetails(context, widget.services.operations, operation);
    if (updated == null || !mounted) return;
    setState(() => _operation = updated);
    // The DX/State column's comparison goes stale otherwise — _load() only
    // resolves this once, on the initial open.
    if (updated.stationCall != operation.stationCall) await _resolveOurEntityPrefix(updated);
  }

  Future<void> _resolveOurEntityPrefix(Operation operation) async {
    final ourInfo = await widget.services.extensions.lookupCall(
      operation.stationCall,
      qso: const {},
      operation: operation.data,
      online: false,
    );
    final ourGuess = ourInfo?['guess'] as Map<String, dynamic>?;
    if (mounted) setState(() => _ourEntityPrefix = ourGuess?['entityPrefix'] as String?);
  }

  Future<void> _editLocation(Operation operation) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OperationLocationScreen(services: widget.services, operation: operation)),
    );
    if (!mounted) return;
    final refreshed = await widget.services.operations.get(operation.uuid);
    if (refreshed != null && mounted) setState(() => _operation = refreshed);
  }

  Future<void> _delete(Operation operation) async {
    final deleted = await confirmDeleteOperation(context, widget.services.operations, operation);
    if (deleted && mounted) Navigator.of(context).pop();
  }

  Future<void> _export(Operation operation) async {
    final t = context.t;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await widget.services.exports.exportOperation(operation);
      if (path != null) {
        messenger.showSnackBar(SnackBar(content: Text(t.operation.exportSuccess(path: path))));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(t.operation.exportFailed(error: e.toString()))));
    }
  }

  Future<void> _handleCommandAction(String action, [Map<String, dynamic>? params]) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = await widget.services.handleCommandAction(action, params);
    if (message != null) messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Flips one of the logging-view menu's toggles: updates the local mirror
  /// (`apply`) so the AppBar menu's checkmark and the widgets below react
  /// immediately, and persists via `persist` so it survives a restart.
  void _toggleMenuSetting({
    required bool current,
    required void Function(bool value) apply,
    required Future<void> Function(bool value) persist,
  }) {
    final value = !current;
    setState(() => apply(value));
    persist(value);
  }

  @override
  Widget build(BuildContext context) {
    final operation = _operation;
    if (operation == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<List<Qso>>(
      stream: widget.services.qsos.watchForOperation(operation.uuid, includeDeleted: _showDeletedQSOs),
      builder: (context, snapshot) {
        final qsos = snapshot.data ?? const <Qso>[];
        // Start/break/end markers ride the same list (for QsoList to render
        // them inline) but aren't real contacts — every QSO *count* shown to
        // the user excludes them, matching scoring/export.
        final realQsoCount = qsos.where((q) => q.isRealContact).length;
        final refsLine = operation.refs.map((r) => r['shortLabel'] ?? r['ref']).whereType<String>().join(' • ');

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              leadingWidth: macOSAwareLeadingWidth,
              leading: macOSAwareBackButton(),
              actions: [
                PopupMenuButton<VoidCallback>(
                  icon: Icon(resolveIconName('dots-vertical')),
                  onSelected: (toggle) => toggle(),
                  itemBuilder: (context) => [
                    CheckedPopupMenuItem<VoidCallback>(
                      checked: _showRSTFields,
                      value: () => _toggleMenuSetting(
                        current: _showRSTFields,
                        apply: (v) => _showRSTFields = v,
                        persist: widget.services.settings.setShowRSTFields,
                      ),
                      child: Text(context.t.operation.menu.showRstFields),
                    ),
                    CheckedPopupMenuItem<VoidCallback>(
                      checked: _showStateField,
                      value: () => _toggleMenuSetting(
                        current: _showStateField,
                        apply: (v) => _showStateField = v,
                        persist: widget.services.settings.setShowStateField,
                      ),
                      child: Text(context.t.operation.menu.showStateField),
                    ),
                    CheckedPopupMenuItem<VoidCallback>(
                      checked: _showGridField,
                      value: () => _toggleMenuSetting(
                        current: _showGridField,
                        apply: (v) => _showGridField = v,
                        persist: widget.services.settings.setShowGridField,
                      ),
                      child: Text(context.t.operation.menu.showGridField),
                    ),
                    CheckedPopupMenuItem<VoidCallback>(
                      checked: _showDeletedQSOs,
                      value: () => _toggleMenuSetting(
                        current: _showDeletedQSOs,
                        apply: (v) => _showDeletedQSOs = v,
                        persist: widget.services.settings.setShowDeletedQSOs,
                      ),
                      child: Text(context.t.operation.menu.showDeletedQsos),
                    ),
                    CheckedPopupMenuItem<VoidCallback>(
                      checked: _showQsoNumbers,
                      value: () => _toggleMenuSetting(
                        current: _showQsoNumbers,
                        apply: (v) => _showQsoNumbers = v,
                        persist: widget.services.settings.setShowQsoNumbers,
                      ),
                      child: Text(context.t.operation.menu.showQsoNumbers),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
              title: InkWell(
                onTap: () => _editActivities(operation),
                mouseCursor: SystemMouseCursors.click,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      operation.title.isEmpty ? operation.stationCall : '${operation.stationCall} ${operation.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (refsLine.isNotEmpty)
                      Text(
                        refsLine,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.85),
                            ),
                      ),
                  ],
                ),
              ),
              bottom: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorWeight: 4,
                tabs: [
                  Tab(text: context.t.operation.tabs.qsos(count: realQsoCount)),
                  Tab(text: context.t.operation.tabs.spots),
                  Tab(text: context.t.operation.tabs.map),
                  Tab(text: context.t.operation.tabs.operation),
                ],
              ),
            ),
            body: TabBarView(children: [
              _KeepAlive(
                child: LoggingPanel(
                  operation: operation,
                  services: widget.services,
                  qsos: qsos,
                  loggingControls: _loggingControls,
                  onCommandAction: _handleCommandAction,
                  showRSTFields: _showRSTFields,
                  showStateField: _showStateField,
                  showGridField: _showGridField,
                  showQsoNumbers: _showQsoNumbers,
                  ourEntityPrefix: _ourEntityPrefix,
                ),
              ),
              _PlaceholderTab(label: context.t.operation.tabs.spots),
              _KeepAlive(child: MapPanel(operation: operation, qsos: qsos)),
              OperationSettingsPanel(
                operation: operation,
                qsoCount: realQsoCount,
                onEditDetails: () => _editDetails(operation),
                onEditActivities: () => _editActivities(operation),
                onEditLocation: () => _editLocation(operation),
                onExport: realQsoCount == 0 ? null : () => _export(operation),
                onDelete: () => _delete(operation),
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// Keeps the QSO list + logging panel's state alive while another tab is
/// showing — a bare TabBarView disposes off-screen tabs by default, which
/// would silently drop whatever's mid-typed in the logging panel the
/// moment someone glances at the Map tab.
class _KeepAlive extends StatefulWidget {
  final Widget child;

  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _PlaceholderTab extends StatelessWidget {
  final String label;

  const _PlaceholderTab({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        context.t.operation.comingSoon(label: label),
        style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// Operation settings/activities/data, a scoped-down port of app-polo's
/// OpSettingsTab: just what this app already has actions for (editing
/// station/title, managing activity refs, location, ADIF export, delete)
/// rather than app-polo's full set (templates, Wavelog export, etc.), which
/// this app doesn't have the underlying data/features for yet.
class OperationSettingsPanel extends StatelessWidget {
  final Operation operation;
  final int qsoCount;
  final VoidCallback onEditDetails;
  final VoidCallback onEditActivities;
  final VoidCallback onEditLocation;
  final VoidCallback? onExport;
  final VoidCallback onDelete;

  const OperationSettingsPanel({
    super.key,
    required this.operation,
    required this.qsoCount,
    required this.onEditDetails,
    required this.onEditActivities,
    required this.onEditLocation,
    required this.onExport,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final refsLine = operation.refs.map((r) => r['shortLabel'] ?? r['ref']).whereType<String>().join(' • ');
    final locationLine = [operation.grid, operation.data['state'], operation.data['county']]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' • ');

    return ListView(
      children: [
        SectionHeader(context.t.operation.sections.stationOperator),
        ListTile(
          leading: Icon(MdiIcons.radioTower),
          title: Text(operation.stationCall.isEmpty ? context.t.operation.stationCallsignNone : operation.stationCall),
          subtitle: Text(operation.title.isEmpty ? context.t.operation.titleNone : operation.title),
          onTap: onEditDetails,
          mouseCursor: SystemMouseCursors.click,
        ),
        SectionHeader(context.t.operation.sections.activities),
        ListTile(
          leading: Icon(MdiIcons.pineTree),
          title: Text(context.t.operation.sections.activities),
          subtitle: Text(refsLine.isEmpty ? context.t.operation.activitiesNone : refsLine),
          onTap: onEditActivities,
          mouseCursor: SystemMouseCursors.click,
        ),
        SectionHeader(context.t.operation.sections.location),
        ListTile(
          leading: Icon(resolveIconName('map-marker-outline')),
          title: Text(context.t.operation.sections.location),
          subtitle: Text(locationLine.isEmpty ? context.t.operation.locationNone : locationLine),
          onTap: onEditLocation,
          mouseCursor: SystemMouseCursors.click,
        ),
        SectionHeader(context.t.operation.sections.operationData),
        ListTile(
          leading: Icon(MdiIcons.fileExportOutline),
          title: Text(context.t.operation.exportAdif),
          subtitle: Text(context.t.operation.tabs.qsos(count: qsoCount)),
          onTap: onExport,
          mouseCursor: SystemMouseCursors.click,
        ),
        SectionHeader(context.t.operation.sections.dangerZone, color: theme.colorScheme.error),
        ListTile(
          leading: Icon(MdiIcons.delete, color: theme.colorScheme.error),
          title: Text(context.t.operation.deleteOperation, style: TextStyle(color: theme.colorScheme.error)),
          onTap: onDelete,
          mouseCursor: SystemMouseCursors.click,
        ),
      ],
    );
  }
}

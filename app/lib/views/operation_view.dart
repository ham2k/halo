// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The logging view: four tabs, ported from app-polo's OperationView —
// "N QSOs" (list + logging panel; a wide-layout info side panel appears
// there too, the first step toward the module-docking layout of
// DESIGN.md §7), Spots (placeholder for now), Map, and Operation
// (settings/activities/data, a scoped-down OpSettingsTab).

import 'package:flutter/material.dart';
import 'package:polo_core/polo_core.dart';
import 'package:polo_widgets/polo_widgets.dart';

import '../main.dart';
import 'operation_dialogs.dart';
import 'operation/logging_panel.dart';
import 'operation/map_panel.dart';

class OperationView extends StatefulWidget {
  final PoloServices services;
  final String operationUuid;

  const OperationView({super.key, required this.services, required this.operationUuid});

  @override
  State<OperationView> createState() => _OperationViewState();
}

class _OperationViewState extends State<OperationView> {
  Operation? _operation;
  List<Map<String, dynamic>> _loggingControls = const [];

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
    }
  }

  Future<void> _editActivities(Operation operation) async {
    final controls = await widget.services.extensions.operationControls(operation.data);
    if (!mounted) return;
    if (controls.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No activities available (extension runtime still starting?)')));
      return;
    }

    var refs = operation.refs;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Activities'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final control in controls)
                  if ((control['input'] as Map?)?['kind'] == 'refList')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RefChipsInput(
                        refType: (control['input'] as Map)['refType'] as String,
                        label: (control['label'] as String?) ?? '',
                        placeholder: (control['input'] as Map)['placeholder'] as String?,
                        pattern: (control['input'] as Map)['pattern'] as String?,
                        refs: refs
                            .where((r) => r['type'] == (control['input'] as Map)['refType'])
                            .toList(),
                        onChanged: (updated) => setDialogState(() {
                          final refType = (control['input'] as Map)['refType'];
                          refs = [
                            ...refs.where((r) => r['type'] != refType),
                            ...updated,
                          ];
                        }),
                        decorate: widget.services.extensions.decorateRef,
                      ),
                    ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (saved == true) {
      final updated = Operation(
        uuid: operation.uuid,
        data: {...operation.data, 'refs': refs},
        qsoCount: operation.qsoCount,
        startAtMillisMin: operation.startAtMillisMin,
        startAtMillisMax: operation.startAtMillisMax,
      );
      await widget.services.operations.saveData(updated);
      if (mounted) setState(() => _operation = updated);
    }
  }

  Future<void> _editDetails(Operation operation) async {
    final updated = await editOperationDetails(context, widget.services.operations, operation);
    if (updated != null && mounted) setState(() => _operation = updated);
  }

  Future<void> _delete(Operation operation) async {
    final deleted = await confirmDeleteOperation(context, widget.services.operations, operation);
    if (deleted && mounted) Navigator.of(context).pop();
  }

  Future<void> _export(Operation operation) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await widget.services.exports.exportOperation(operation);
      if (path != null) {
        messenger.showSnackBar(SnackBar(content: Text('Exported to $path')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _handleCommandAction(String action) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = await widget.services.handleCommandAction(action);
    if (message != null) messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final operation = _operation;
    if (operation == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<List<Qso>>(
      stream: widget.services.qsos.watchForOperation(operation.uuid),
      builder: (context, snapshot) {
        final qsos = snapshot.data ?? const <Qso>[];
        final refsLine = operation.refs.map((r) => r['shortLabel'] ?? r['ref']).whereType<String>().join(' • ');

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              leadingWidth: isMacOSChromelessWindow ? 56 + macOSTrafficLightInset + macOSTrafficLightGap : null,
              leading: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: isMacOSChromelessWindow
                    ? const Padding(
                        padding: EdgeInsets.only(left: macOSTrafficLightInset + macOSTrafficLightGap),
                        child: BackButton(),
                      )
                    : const BackButton(),
              ),
              // Reserves trailing breathing room even though this AppBar has
              // no real action buttons — otherwise the title runs flush to
              // the window's right edge with no margin at all.
              actions: const [SizedBox(width: 16)],
              title: Column(
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
              bottom: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorWeight: 4,
                tabs: [
                  Tab(text: '${qsos.length} QSOS'),
                  const Tab(text: 'SPOTS'),
                  const Tab(text: 'MAP'),
                  const Tab(text: 'OPERATION'),
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
                ),
              ),
              const _PlaceholderTab(label: 'Spots'),
              _KeepAlive(child: MapPanel(operation: operation, qsos: qsos)),
              OperationSettingsPanel(
                operation: operation,
                qsoCount: qsos.length,
                onEditDetails: () => _editDetails(operation),
                onEditActivities: () => _editActivities(operation),
                onExport: qsos.isEmpty ? null : () => _export(operation),
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
        '$label — coming soon',
        style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// Operation settings/activities/data, a scoped-down port of app-polo's
/// OpSettingsTab: just what this app already has actions for (editing
/// station/title, managing activity refs, ADIF export, delete) rather than
/// app-polo's full set (location, templates, Wavelog export, etc.), which
/// this app doesn't have the underlying data/features for yet.
class OperationSettingsPanel extends StatelessWidget {
  final Operation operation;
  final int qsoCount;
  final VoidCallback onEditDetails;
  final VoidCallback onEditActivities;
  final VoidCallback? onExport;
  final VoidCallback onDelete;

  const OperationSettingsPanel({
    super.key,
    required this.operation,
    required this.qsoCount,
    required this.onEditDetails,
    required this.onEditActivities,
    required this.onExport,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final refsLine = operation.refs.map((r) => r['shortLabel'] ?? r['ref']).whereType<String>().join(' • ');

    return ListView(
      children: [
        _SectionHeader('Station & operator'),
        ListTile(
          leading: Icon(MdiIcons.radioTower),
          title: Text(operation.stationCall.isEmpty ? 'No station callsign' : operation.stationCall),
          subtitle: Text(operation.title.isEmpty ? 'No title' : operation.title),
          onTap: onEditDetails,
          mouseCursor: SystemMouseCursors.click,
        ),
        _SectionHeader('Activities'),
        ListTile(
          leading: Icon(MdiIcons.pineTree),
          title: const Text('Activities'),
          subtitle: Text(refsLine.isEmpty ? 'None set' : refsLine),
          onTap: onEditActivities,
          mouseCursor: SystemMouseCursors.click,
        ),
        _SectionHeader('Operation data'),
        ListTile(
          leading: Icon(MdiIcons.fileExportOutline),
          title: const Text('Export ADIF'),
          subtitle: Text('$qsoCount QSOs'),
          onTap: onExport,
          mouseCursor: SystemMouseCursors.click,
        ),
        _SectionHeader('Danger zone', color: theme.colorScheme.error),
        ListTile(
          leading: Icon(MdiIcons.delete, color: theme.colorScheme.error),
          title: Text('Delete operation', style: TextStyle(color: theme.colorScheme.error)),
          onTap: onDelete,
          mouseCursor: SystemMouseCursors.click,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color? color;

  const _SectionHeader(this.title, {this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(color: color ?? theme.colorScheme.primary),
      ),
    );
  }
}

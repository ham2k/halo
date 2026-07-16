// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Operation Exports Panel (ham2k/app-halo-dist#4): lists every export option
// suggested by extensions for this operation, a sync-status summary, and a
// bottom action bar to save (desktop) or share (mobile) the selected files.

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../main.dart';
import '../../i18n/strings.g.dart';

class OperationExportScreen extends StatefulWidget {
  final HaLoServices services;
  final Operation operation;

  const OperationExportScreen({super.key, required this.services, required this.operation});

  @override
  State<OperationExportScreen> createState() => _OperationExportScreenState();
}

class _OperationExportScreenState extends State<OperationExportScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _options = const [];
  final Map<String, bool> _selected = {};
  ({int total, int pending, int eventTotal, int eventPending})? _syncCounts;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.services.exports.getExportOptions(widget.operation),
        widget.services.qsos.syncCountsForOperation(widget.operation.uuid),
      ]);
      final options = (results[0] as List<Map<String, dynamic>>)
        ..sort((a, b) => ((b['priority'] as num?) ?? 0).compareTo((a['priority'] as num?) ?? 0));
      if (!mounted) return;
      setState(() {
        _options = options;
        _syncCounts = results[1] as ({int total, int pending, int eventTotal, int eventPending});
        for (final option in options) {
          _selected[_selectionKey(option)] = (option['selectedByDefault'] as bool?) ?? false;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// `exportType` is only unique within the hook that returned it (see
  /// ExportOption in the extension SDK) — pair it with `hookKey` so two
  /// hooks reusing the same exportType string don't collide in `_selected`.
  String _selectionKey(Map<String, dynamic> option) => '${option['hookKey']}:${option['exportType']}';

  List<Map<String, dynamic>> get _selectedOptions =>
      _options.where((o) => _selected[_selectionKey(o)] == true).toList();

  Future<void> _export() async {
    final t = context.t;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final files = await widget.services.exports.generateExports(widget.operation, _selectedOptions);
      if (isMobilePlatform) {
        await widget.services.exports.shareFiles(files);
      } else {
        final path = await widget.services.exports.saveToDisk(files);
        if (path != null) {
          messenger.showSnackBar(SnackBar(content: Text(t.operation.export.saveSuccess(path: path))));
        }
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(t.operation.export.exportFailed(error: e.toString()))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final syncCounts = _syncCounts;
    final hasSelection = _selectedOptions.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: macOSHeaderDoubleClickArea(),
        leadingWidth: macOSAwareLeadingWidth(context),
        leading: macOSAwareBackButton(context),
        title: Text(t.operation.export.title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(t.operation.export.exportFailed(error: _error!)))
              : ListView(
                  children: [
                    SectionHeader(t.operation.export.title),
                    ListTile(
                      leading: Icon(resolveIconName(widget.operation.synced ? 'cloud-check-outline' : 'cloud-alert-outline')),
                      title: Text(widget.operation.synced ? t.operation.export.syncedOperation : t.operation.export.unsyncedOperation),
                      subtitle: syncCounts == null
                          ? null
                          : Text(syncCounts.pending == 0
                              ? t.operation.export.qsosSynced(total: syncCounts.total)
                              : t.operation.export.qsosPending(pending: syncCounts.pending, total: syncCounts.total)),
                    ),
                    if (syncCounts != null && syncCounts.eventTotal > 0)
                      ListTile(
                        leading: Icon(resolveIconName('flag-outline')),
                        title: Text(syncCounts.eventPending == 0
                            ? t.operation.export.eventsSynced(total: syncCounts.eventTotal)
                            : t.operation.export.eventsPending(pending: syncCounts.eventPending, total: syncCounts.eventTotal)),
                      ),
                    if (_options.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(t.operation.export.noOptions, style: theme.textTheme.bodyMedium),
                      )
                    else
                      for (final option in _options)
                        CheckboxListTile(
                          secondary: Icon(resolveIconName(option['icon'] as String? ?? 'file-export-outline')),
                          title: Text(option['label'] as String? ?? option['exportType'] as String),
                          subtitle: option['filename'] == null ? null : Text(option['filename'] as String),
                          value: _selected[_selectionKey(option)] ?? false,
                          onChanged: (value) => setState(() => _selected[_selectionKey(option)] = value ?? false),
                        ),
                    const SizedBox(height: 24),
                  ],
                ),
      bottomNavigationBar: _loading || _error != null
          ? null
          : Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_busy)
                        const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        FilledButton(
                          onPressed: hasSelection ? _export : null,
                          child: Text(isMobilePlatform ? t.operation.export.share : t.common.save),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

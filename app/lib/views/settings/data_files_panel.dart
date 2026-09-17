// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Data Files: the offline reference datasets extensions declare, with
// their freshness and a way to refresh one by hand.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../../services/halo_services.dart';
import '../../services/data_file_manager.dart';

import 'extension_settings_panel.dart';

/// The Data Files panel: every data file the enabled extensions register
/// (POTA parks, SOTA summits, callsign notes…), each showing when it was
/// last downloaded and a Refresh button that forces a fresh fetch. The list
/// re-loads when the extension runtime restarts (a toggle changes which
/// files exist). Country data (Big CTY) is bundled, not a downloaded data
/// file, so it doesn't appear here.
class DataFilesPanel extends StatefulWidget {
  final HaLoServices services;

  /// A SLIVER — this panel shares one scroll view with its sibling in the
  /// Accounts, Services & Data Sources panel (settings_view.dart).
  const DataFilesPanel({super.key, required this.services});

  @override
  State<DataFilesPanel> createState() => _DataFilesPanelState();
}

class _DataFilesPanelState extends State<DataFilesPanel> {
  List<DataFileStatus>? _files;
  final Set<String> _refreshing = {};
  bool _updatingAll = false;

  /// Every registered settingsPanel (HALO-53). Starts empty rather than
  /// null: the section simply doesn't render until the first load rather
  /// than needing its own separate loading gate from [_files].
  List<Map<String, dynamic>> _extensionPanels = const [];

  /// The subset actually shown in this screen's own "Extensions" section:
  /// only panels that explicitly opted into it (`dataFilesSection: true`) —
  /// NOT every panel that merely opted out of the top-level sidebar. Those
  /// are independent settings (extensions/sdk/src/types.ts); keying this on
  /// `sidebar: false` would sweep in any sidebar-opt-out panel whatever its
  /// reason, whether or not it is about data files.
  List<Map<String, dynamic>> get _dataFileScopedPanels =>
      [for (final p in _extensionPanels) if (p['dataFilesSection'] == true) p];

  @override
  void initState() {
    super.initState();
    _load();
    widget.services.extensions.runtimeGeneration.addListener(_load);
  }

  @override
  void dispose() {
    widget.services.extensions.runtimeGeneration.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    await widget.services.extensions.start();
    final files = await widget.services.dataFiles.listDataFiles();
    final panels = await widget.services.extensions.getSettingsPanels();
    if (mounted) {
      setState(() {
        _files = files;
        _extensionPanels = panels;
      });
    }
  }

  /// Modal Pane (docs/design/layouts.md): a full screen on narrow windows,
  /// a centered dialog on wide ones — the same presentation every other
  /// settings-adjacent pane in the app uses, via [showModalPane].
  Future<void> _openExtensionPanel(BuildContext context, Map<String, dynamic> panel) => showModalPane<void>(
    context,
    title: (panel['title'] as String?) ?? (panel['panelKey'] as String?) ?? '',
    builder: (context) => ExtensionSettingsPanel(services: widget.services, descriptor: panel),
  );

  Future<void> _refresh(DataFileStatus file) async {
    setState(() => _refreshing.add(file.key));
    try {
      // The stamped time comes back from the refresh, so the row updates
      // from it directly — no second listDataFiles round-trip. A failure
      // needs no handling here: processDataFile raises the notice for
      // download/parse failures, and refreshDataFile itself raises one for
      // the no-definition null return — every failure path speaks for
      // itself before this catch sees it.
      final updatedAt = await widget.services.dataFiles.refreshDataFile(file.key);
      if (mounted && updatedAt != null) _applyUpdatedAt(file.key, updatedAt);
    } catch (_) {
      // Swallowed deliberately — see the comment above.
    } finally {
      if (mounted) setState(() => _refreshing.remove(file.key));
    }
  }

  // syncAllDataFiles catches and reports its own per-file failures (see
  // DataFileManager), so there's nothing left to surface here beyond
  // reloading the rows once it settles. Every row is marked as refreshing
  // too, so each shows its own live status-bar progress — the same view
  // an individual Refresh gives — instead of just the summary row above.
  Future<void> _updateAll() async {
    setState(() {
      _updatingAll = true;
      _refreshing.addAll(_files?.map((f) => f.key) ?? const []);
    });
    try {
      await widget.services.dataFiles.syncAllDataFiles(force: true);
      if (mounted) await _load();
    } finally {
      if (mounted) {
        setState(() {
          _updatingAll = false;
          _refreshing.clear();
        });
      }
    }
  }

  void _applyUpdatedAt(String key, DateTime updatedAt) {
    final files = _files;
    if (files == null) return;
    final index = files.indexWhere((f) => f.key == key);
    if (index < 0) return;
    setState(() => _files = [...files]..[index] = files[index].withUpdatedAt(updatedAt));
  }

  @override
  Widget build(BuildContext context) {
    final files = _files;
    // Nothing while loading: the accounts above already show the one
    // spinner, and a second stacked under it reads as a glitch.
    if (files == null) return const SliverToBoxAdapter();

    final children = <Widget>[
        SectionHeader(context.t.settings.offlineData.title),
        if (files.isEmpty)
          ListTile(
            title: Text(context.t.settings.offlineData.noFiles),
            subtitle: Text(context.t.settings.offlineData.noFilesDescription),
          )
        else ...[
          _buildUpdateAllRow(context),
          for (final file in files) _buildRow(context, file),
        ],
        if (_dataFileScopedPanels.isNotEmpty) ...[
          SectionHeader(context.t.settings.offlineData.extensionsSection),
          for (final panel in _dataFileScopedPanels) _buildExtensionPanelRow(context, panel),
        ],
    ];
    return SliverMainAxisGroup(slivers: sectionSlivers(context, children));
  }

  /// One row per [_dataFileScopedPanels] entry (HALO-53) — call-notes'
  /// builtin/custom-file toggles, and whichever other extensions declare a
  /// `dataFilesSection: true` panel of their own, live there (the same panel
  /// Settings would show), not in this generic status-and-refresh list.
  Widget _buildExtensionPanelRow(BuildContext context, Map<String, dynamic> panel) {
    final title = (panel['title'] as String?) ?? (panel['panelKey'] as String?) ?? '';
    return ListTile(
      leading: Icon(resolveIconName(panel['icon'] as String?)),
      title: Text(title),
      trailing: const Icon(MdiIcons.chevronRight),
      onTap: () => _openExtensionPanel(context, panel),
      mouseCursor: SystemMouseCursors.click,
    );
  }

  Widget _buildUpdateAllRow(BuildContext context) {
    if (_updatingAll) {
      return ListTile(
        leading: Icon(MdiIcons.refresh),
        title: Text(context.t.settings.offlineData.updateAll),
        subtitle: Text(context.t.settings.offlineData.updatingAll),
        trailing: const SizedBox(
          width: 24,
          height: 24,
          child: Padding(padding: EdgeInsets.all(Space.xxs), child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    return ListTile(
      leading: Icon(MdiIcons.refresh),
      title: Text(context.t.settings.offlineData.updateAll),
      onTap: _updateAll,
      mouseCursor: SystemMouseCursors.click,
    );
  }

  Widget _buildRow(BuildContext context, DataFileStatus file) {
    final icon = Icon(resolveIconName(file.icon, fallback: MdiIcons.fileDocumentOutline));

    // While refreshing, mirror this data file's live status-bar progress
    // item (keyed `dataFile:$key`, set by DataFileManager) as the subtitle —
    // the footer status bar isn't visible on this screen.
    if (_refreshing.contains(file.key)) {
      return ListenableBuilder(
        listenable: widget.services.statusBar,
        builder: (context, _) {
          final progress = widget.services.statusBar.itemForKey('dataFile:${file.key}');
          return ListTile(
            leading: icon,
            title: Text(file.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(progress?.text ?? context.t.settings.offlineData.refreshing),
                const SizedBox(height: Space.sm),
                LinearProgressIndicator(value: progress?.progressValue),
              ],
            ),
            trailing: const SizedBox(
              width: 24,
              height: 24,
              child: Padding(padding: EdgeInsets.all(Space.xxs), child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        },
      );
    }

    return ListTile(
      leading: icon,
      title: Text(file.name),
      subtitle: Text(_dataFileUpdatedLabel(file.updatedAt)),
      trailing: IconButton(
        icon: Icon(MdiIcons.refresh, semanticLabel: context.t.settings.offlineData.refresh),
        onPressed: () => _refresh(file),
        mouseCursor: SystemMouseCursors.click,
      ),
    );
  }
}

/// "Updated 2d 7h ago" / "Never downloaded" — the same day+hour granularity
/// app-polo's data settings use.
String _dataFileUpdatedLabel(DateTime? updatedAt) {
  if (updatedAt == null) return t.settings.offlineData.neverDownloaded;
  final diff = nowLocal().difference(updatedAt);
  if (diff.isNegative || diff.inSeconds < 60) return t.settings.offlineData.updatedJustNow;
  final days = diff.inDays;
  if (days > 0) {
    final hours = diff.inHours % 24;
    return hours == 0
        ? t.settings.offlineData.updatedDaysAgo(days: days)
        : t.settings.offlineData.updatedDaysHoursAgo(days: days, hours: hours);
  }
  final hours = diff.inHours;
  if (hours > 0) {
    final minutes = diff.inMinutes % 60;
    return minutes == 0
        ? t.settings.offlineData.updatedHoursAgo(hours: hours)
        : t.settings.offlineData.updatedHoursMinutesAgo(hours: hours, minutes: minutes);
  }
  return t.settings.offlineData.updatedMinutesAgo(minutes: diff.inMinutes);
}

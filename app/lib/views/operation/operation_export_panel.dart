// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Operation Exports Panel: every export option the
// extensions suggest for this operation, with a checkbox each and a button
// each, over a sync-status summary, under a settings gear.
//
// A Modal Pane rather than a pushed page (docs/design/layouts.md): this is a
// picker, not a place — the operator comes here to answer one question and
// leave. It is opened from the operation sheet, itself a pane, and a page
// pushed over a modal read as a change of address rather than a prompt. As a
// pane it presents as a dialog on a desktop window and a full screen on a
// phone from ONE route, so a window resize doesn't lose the ticks.
//
// Two ways to export, deliberately:
//   - tick several, press the one counted button — the common case, one save
//     dialog or one share sheet for the lot;
//   - press a single row's button — for the operator who wants just the POTA
//     file right now and doesn't want to disturb the ticks.
// app-polo conflated these: tapping a row's BODY exported it immediately,
// which made the row do two unrelated things and left Android with no
// per-row save at all.

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../main.dart';
import '../../i18n/strings.g.dart';
import '../../services/status_bar_service.dart';

/// What this platform calls getting a file out of the app, and how it does
/// it. The verbs are not interchangeable — "Save" on iOS would promise a
/// filesystem the operator can't see, and "Share" on a desktop would promise
/// a share sheet that isn't there.
enum ExportAction {
  /// A save dialog (one file) or a directory picker (several). Desktop, and
  /// Android's second button.
  save,

  /// The system share sheet. Android — and what iOS does under the name
  /// [export].
  share,

  /// iOS's name for the share sheet: on iOS "Export" is what the Files/share
  /// sheet is called in the operator's own vocabulary.
  export,

  /// A browser download, one per file.
  download,
}

/// The buttons the counted footer offers. Android is the only platform with
/// two: it genuinely distinguishes putting a file in Downloads from handing
/// it to another app, and operators use both (uploading to POTA vs. mailing
/// a Cabrillo).
///
/// [isWeb] and [platform] exist only so tests can cover the whole matrix:
/// `kIsWeb` is a compile-time false under `flutter test`, so the web branch
/// is otherwise unreachable.
List<ExportAction> bulkExportActions({bool? isWeb, TargetPlatform? platform}) {
  if (isWeb ?? isWebPlatform) return const [ExportAction.download];
  final target = platform ?? defaultTargetPlatform;
  if (target == TargetPlatform.iOS) return const [ExportAction.export];
  if (target == TargetPlatform.android) return const [ExportAction.save, ExportAction.share];
  return const [ExportAction.save];
}

/// The single action on each option's own row — the platform's primary verb,
/// except on Android where sharing one file is the thing operators actually
/// do (it is what app-polo's row tap did, and the only per-row action it
/// had).
ExportAction rowExportAction({bool? isWeb, TargetPlatform? platform}) {
  if (isWeb ?? isWebPlatform) return ExportAction.download;
  final target = platform ?? defaultTargetPlatform;
  if (target == TargetPlatform.iOS) return ExportAction.export;
  if (target == TargetPlatform.android) return ExportAction.share;
  return ExportAction.save;
}

IconData exportActionIcon(ExportAction action) => switch (action) {
      ExportAction.save => MdiIcons.contentSave,
      ExportAction.share => MdiIcons.shareVariant,
      ExportAction.export => MdiIcons.exportVariant,
      ExportAction.download => MdiIcons.download,
    };

/// Opens the Exports pane for [operation].
Future<void> showOperationExportPanel(
  BuildContext context, {
  required HaLoServices services,
  required Operation operation,
}) {
  final t = context.t;
  return showModalPane<void>(
    context,
    title: t.operation.export.title,
    closeLabel: t.common.close,
    // The option list scrolls; the action row stays pinned under it.
    scrollable: false,
    // The footer's Done is the way out — see haloDialogFooterBand.
    closeButton: false,
    headerActions: [
      // Route-level, so it sits in the pane's own header rather than in the
      // content. The panel below reloads itself when the setting changes —
      // it listens to SettingsService — so this doesn't need to reach into
      // the panel's State.
      Builder(
        builder: (context) => IconButton(
          icon: Icon(
            MdiIcons.tune,
            // No hover tooltips in this app — the accessible name is
            // the only name this button has.
            semanticLabel: t.operation.export.settingsButton,
          ),
          onPressed: () => showExportSettingsDialog(context, services: services),
        ),
      ),
    ],
    builder: (_) => OperationExportPanel(services: services, operation: operation),
  );
}

/// The gear's dialog. Also declared as a settings group
/// (`ExportsSettingsGroup`), so the same setting is reachable from All
/// Settings by someone who never opens this panel.
Future<void> showExportSettingsDialog(
  BuildContext context, {
  required HaLoServices services,
}) {
  final t = context.t;
  return showHaloDialog<void>(
    context: context,
    builder: (context) => HaloDialog(
      title: Text(t.operation.export.settingsTitle),
      contentPadding: const EdgeInsets.symmetric(vertical: Space.md),
      content: ListenableBuilder(
        listenable: services.settings,
        builder: (context, _) {
          final settings = services.settings;
          final names = context.t.operation.export.compactFileNames;
          final private = context.t.operation.export.includePrivateData;
          final theme = Theme.of(context);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                secondary: Icon(MdiIcons.fileCodeOutline),
                title: Text(names.title),
                subtitle: Text(settings.useCompactFileNames ? names.descriptionOn : names.descriptionOff),
                value: settings.useCompactFileNames,
                onChanged: settings.setUseCompactFileNames,
              ),
              SwitchListTile(
                secondary: Icon(MdiIcons.accountLock),
                title: Text(private.title),
                subtitle: Text(
                  settings.includePrivateData ? private.descriptionOn : private.descriptionOff,
                ),
                value: settings.includePrivateData,
                onChanged: settings.setIncludePrivateData,
              ),
              // Said once, here, rather than as a caveat on the switch: the
              // exemption is a property of that one export, and an operator
              // who turns this off would otherwise reasonably expect their
              // backup to be stripped too.
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.xxl, 0, Space.xxl, Space.md),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    private.note,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      // Export settings apply as each switch changes, so this closes rather
      // than confirms.
      cancel: TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(t.common.done),
      ),
    ),
  );
}

class OperationExportPanel extends StatefulWidget {
  final HaLoServices services;
  final Operation operation;

  const OperationExportPanel({super.key, required this.services, required this.operation});

  @override
  State<OperationExportPanel> createState() => _OperationExportPanelState();
}

class _OperationExportPanelState extends State<OperationExportPanel> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _options = const [];

  /// The operation's active activity controls, for their declared accent
  /// colors. An export names the `refType` it covers, so a park's file can
  /// wear the same green the POTA row wears in the operation sheet
  /// (`colorForRefType`) instead of a palette invented here.
  List<Map<String, dynamic>> _controls = const [];

  final Map<String, bool> _selected = {};
  ({int total, int pending, int eventTotal, int eventPending})? _syncCounts;
  bool _busy = false;

  /// The filename form the current [_options] were listed under. The hooks
  /// build their names from it, so flipping the setting in the gear's dialog
  /// makes every name on screen stale — this is what notices.
  ///
  /// Read eagerly in [initState], NOT as a `late` initializer: a `late` field
  /// evaluates on first ACCESS, which is inside the change listener, by which
  /// point the new value is already stored — so it would compare the setting
  /// against itself and never reload.
  bool _compactNames = false;

  /// Which [_load] is the current one. Flipping the filename setting twice in
  /// quick succession leaves two loads in flight — each now one bridge call
  /// per callsign — and the slower one must not install options listed under
  /// the older setting. Same guard, and the same reason, as
  /// `activities_view._controlsRequest`.
  int _loadRequest = 0;

  @override
  void initState() {
    super.initState();
    _compactNames = widget.services.settings.useCompactFileNames;
    widget.services.settings.addListener(_onSettingsChanged);
    _load();
  }

  @override
  void dispose() {
    widget.services.settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    final compact = widget.services.settings.useCompactFileNames;
    if (compact == _compactNames) return;
    _compactNames = compact;
    // Re-asks the extensions rather than rewriting the strings here: the
    // names are theirs to build (`exportFilename` in the SDK), and each hook
    // decides what its own compact form looks like.
    _load();
  }

  Future<void> _load() async {
    final request = ++_loadRequest;
    try {
      final results = await Future.wait([
        widget.services.exports.getExportOptions(widget.operation),
        widget.services.qsos.syncCountsForOperation(widget.operation.uuid),
        // Colors only. A runtime that can't answer must not cost the panel
        // its export list, so this one degrades to the theme accent rather
        // than failing the whole load.
        widget.services.extensions
            .operationControls(widget.operation.data)
            // Which is also why `loadFailed` is dropped here and acted on
            // everywhere else: a tint is not worth a notice.
            .then((result) => result.controls)
            .catchError((Object e) {
              debugPrint('[extensions] operationControls failed for the export panel: $e');
              return <Map<String, dynamic>>[];
            }),
      ]);
      final options = (results[0] as List<Map<String, dynamic>>)
        ..sort((a, b) => ((b['priority'] as num?) ?? 0).compareTo((a['priority'] as num?) ?? 0));
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _options = options;
        _syncCounts = results[1] as ({int total, int pending, int eventTotal, int eventPending});
        _controls = results[2] as List<Map<String, dynamic>>;
        for (final option in options) {
          // `putIfAbsent`, not assignment: a reload after the filename
          // setting changed must not throw away ticks the operator has
          // already made.
          _selected.putIfAbsent(_selectionKey(option), () => (option['selectedByDefault'] as bool?) ?? false);
        }
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// `exportType` is only unique within the hook that returned it (see
  /// ExportOption in the extension SDK) — pair it with `hookKey` so two
  /// hooks reusing the same exportType string don't collide in `_selected`,
  /// and with the station callsign, since a multi-operator operation offers
  /// the very same hook/exportType pair once per call.
  String _selectionKey(Map<String, dynamic> option) =>
      '${option['stationCall'] ?? ''}|${option['hookKey']}:${option['exportType']}';

  List<Map<String, dynamic>> get _selectedOptions =>
      _options.where((o) => _selected[_selectionKey(o)] == true).toList();

  /// The options grouped by the station callsign that owes them, in the order
  /// the calls were entered. One entry for a normal single-call operation —
  /// the panel only draws group headers when there is more than one.
  ///
  /// Ordered by the OPERATION's callsigns, not by first appearance in
  /// [_options]: that list is sorted by priority across every group, so the
  /// group that came first would be whichever call happened to own the
  /// highest-priority export — an order that could shuffle between reloads
  /// rather than matching what the operator typed.
  List<({String call, List<Map<String, dynamic>> options})> get _groups {
    final byCall = <String, List<Map<String, dynamic>>>{};
    for (final option in _options) {
      byCall.putIfAbsent(option['stationCall'] as String? ?? '', () => []).add(option);
    }
    return [
      // The operation's own order first…
      for (final call in widget.operation.stationCalls)
        if (byCall.containsKey(call)) (call: call, options: byCall.remove(call)!),
      // …then anything left over, so an option tagged with a call the
      // operation no longer carries is still shown rather than dropped.
      for (final entry in byCall.entries) (call: entry.key, options: entry.value),
    ];
  }

  String _filenameOf(Map<String, dynamic> option) =>
      option['filename'] as String? ?? option['label'] as String? ?? option['exportType'] as String;

  /// The counted verb. [combined] names the batch that spans EVERY callsign,
  /// which only exists when there is more than one — "Download 8 files" beside
  /// a group that offers 4 would read as that group's.
  String _bulkLabel(ExportAction action, int count, {bool combined = false}) {
    final s = context.t.operation.export;
    if (combined) {
      return switch (action) {
        ExportAction.save => s.saveCombined(count: count),
        ExportAction.share => s.shareCombined(count: count),
        ExportAction.export => s.exportCombined(count: count),
        ExportAction.download => s.downloadCombined(count: count),
      };
    }
    return switch (action) {
      ExportAction.save => s.saveFiles(count: count),
      ExportAction.share => s.shareFiles(count: count),
      ExportAction.export => s.exportFiles(count: count),
      ExportAction.download => s.downloadFiles(count: count),
    };
  }

  String _rowLabel(ExportAction action, String name) {
    final s = context.t.operation.export;
    return switch (action) {
      ExportAction.save => s.saveOne(name: name),
      ExportAction.share => s.shareOne(name: name),
      ExportAction.export => s.exportOne(name: name),
      ExportAction.download => s.downloadOne(name: name),
    };
  }

  Future<void> _run(ExportAction action, List<Map<String, dynamic>> options) async {
    if (options.isEmpty) return;
    final t = context.t;
    final exports = widget.services.exports;
    final statusBar = widget.services.statusBar;
    setState(() => _busy = true);
    try {
      // The iPad share sheet is a popover and needs an anchor rect; the
      // panel's own bounds serve for every share trigger in it. Captured
      // before the awaits: a layout change during the export leaves the rect
      // stale, which UIKit answers by clamping — a misplaced popover, not a
      // failure.
      final box = context.findRenderObject() as RenderBox?;
      final shareOrigin =
          box == null || !box.hasSize ? null : box.localToGlobal(Offset.zero) & box.size;
      final files = await exports.generateExports(widget.operation, options);
      widget.services.track('operation_exported', {
        'formats': options.map((o) => o['format'] ?? o['key'] ?? '?').join(','),
        'files': files.length,
        'action': action.name,
      });
      switch (action) {
        case ExportAction.save:
          final path = await exports.saveToDisk(files);
          // Null means the operator cancelled the picker — their choice, not
          // an outcome worth announcing.
          if (path != null) {
            statusBar.setMessage(
              key: 'export:status',
              text: t.operation.export.saveSuccess(path: path),
              dismissAfter: StatusBarService.completedDismissDelay,
            );
          }
        case ExportAction.share:
        case ExportAction.export:
          // Only when the operator actually shared. Reporting unconditionally
          // would announce a completed share for a sheet they dismissed —
          // asserting an outcome that didn't happen.
          if (await exports.shareFiles(files, sharePositionOrigin: shareOrigin)) {
            statusBar.setMessage(
              key: 'export:status',
              text: t.operation.export.shareSuccess(count: files.length),
              dismissAfter: StatusBarService.completedDismissDelay,
            );
          }
        case ExportAction.download:
          await exports.downloadFiles(files);
          statusBar.setMessage(
            key: 'export:status',
            text: t.operation.export.downloadSuccess(count: files.length),
            dismissAfter: StatusBarService.completedDismissDelay,
          );
      }
    } catch (e) {
      statusBar.setMessage(key: 'export:status', text: t.operation.export.exportFailed(error: e.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    // EVERY state keeps the footer under it, loading included. It is this
    // pane's only way out — the header carries no close button — so a body
    // that returns early takes the operator's exit with it, and a load
    // waiting on the extension host is not a single frame.
    return Column(
      children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(Space.xxl),
                      child: Center(child: Text(t.operation.export.exportFailed(error: _error!))),
                    )
                  : _buildList(context),
        ),
        _buildFooter(context),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final syncCounts = _syncCounts;
    final rowAction = rowExportAction();
    // Computed once: it walks every option, and the layout branches on its
    // length in three places below.
    final groups = _groups;

    return ListView(
      padding: const EdgeInsets.only(bottom: Space.md),
      children: [
        ListTile(
          leading: Icon(widget.operation.synced ? MdiIcons.cloudCheck : MdiIcons.cloudAlert),
          title: Text(widget.operation.synced
              ? t.operation.export.syncedOperation
              : t.operation.export.unsyncedOperation),
          subtitle: syncCounts == null
              ? null
              : Text(syncCounts.pending == 0
                  ? t.operation.export.qsosSynced(total: syncCounts.total)
                  : t.operation.export.qsosPending(pending: syncCounts.pending, total: syncCounts.total)),
        ),
        if (syncCounts != null && syncCounts.eventTotal > 0)
          ListTile(
            leading: Icon(MdiIcons.flag),
            title: Text(syncCounts.eventPending == 0
                ? t.operation.export.eventsSynced(total: syncCounts.eventTotal)
                : t.operation.export.eventsPending(
                    pending: syncCounts.eventPending, total: syncCounts.eventTotal)),
          ),
        const Divider(height: 1),
        // ONE callsign: the batch action sits above the list it acts on, not
        // in the footer — a button saying "Save 3 files" belongs next to the
        // three ticks it counted rather than a scroll away from them.
        //
        // SEVERAL: it doesn't go here at all. Each group carries its own, and
        // a whole-panel count sitting above the first group would read as
        // that group's.
        if (_options.isNotEmpty && groups.length == 1) ...[
          _buildBulkActions(context, _selectedOptions),
          const Divider(height: 1),
        ],
        if (_options.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: Text(
              // Two different empties, and saying the wrong one sends the
              // operator looking for a fault: a log with no contacts yet has
              // nothing to offer, where a log WITH contacts and no options
              // means the formats themselves never arrived.
              syncCounts != null && syncCounts.total == 0
                  ? t.operation.export.nothingLogged
                  : t.operation.export.noOptions,
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          for (final group in groups) ...[
            // A single-station operation is the common case and gets no
            // header at all — grouping chrome around one group is just noise.
            if (groups.length > 1) _buildGroupHeader(context, group),
            for (final option in group.options) _buildOptionRow(context, option, rowAction),
          ],
        // …and the everything-at-once batch closes the list instead, after the
        // callsigns it spans.
        if (groups.length > 1) _buildCombinedActions(context),
      ],
    );
  }

  /// The batch that spans every callsign, sitting under them all.
  ///
  /// Its own band, lighter than a group header's, so it reads as a footer to
  /// the whole list rather than as one more callsign; right-aligned, since it
  /// closes the list rather than labelling what follows.
  Widget _buildCombinedActions(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
      // Trailing inset matches the group headers' (8), so the combined
      // button sits on the same edge as the per-callsign ones above it.
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.md, Space.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [_buildBulkActions(context, _selectedOptions, dense: true, combined: true)],
      ),
    );
  }

  /// The callsign a group of exports belongs to, and its own batch button —
  /// a multi-operator operation owes each call its own submission, so "export
  /// what I ticked for W1AW" has to be sayable without unticking everyone
  /// else's.
  Widget _buildGroupHeader(
    BuildContext context,
    ({String call, List<Map<String, dynamic>> options}) group,
  ) {
    final theme = Theme.of(context);
    final colors = HaLoColors.of(context);
    final selected = group.options.where((o) => _selected[_selectionKey(o)] == true).toList();

    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.md, Space.lg),
      child: Row(
        children: [
          Icon(MdiIcons.radioTower, size: 20, color: colors.onSurfaceAccent),
          const SizedBox(width: Space.lg),
          Expanded(
            child: Text(
              // An operation with no callsign at all still groups; naming it
              // by its emptiness would read worse than the fallback.
              group.call.isEmpty ? context.t.operation.export.title : group.call,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.onSurfaceAccent,
              ),
            ),
          ),
          _buildBulkActions(context, selected, dense: true),
        ],
      ),
    );
  }

  /// One option, read left to right: what it is (the activity's own accented
  /// icon), what it will be called, the button that exports it alone, and the
  /// checkbox that adds it to the counted button's batch.
  ///
  /// Hand-built rather than a `CheckboxListTile`, for two reasons. The
  /// visual one: that widget only offers leading OR trailing for its control,
  /// so it can't put the icon first and the checkbox last with the per-row
  /// button between them. The load-bearing one: it wraps its whole subtree in
  /// `MergeSemantics`, which absorbs any button inside it — the row becomes a
  /// single checkbox named "ADIF Export … Download ADIF Export …", with no
  /// button in the tree at all and pointer taps landing on the checkbox. So
  /// the three controls stay siblings, each carrying its own name.
  Widget _buildOptionRow(BuildContext context, Map<String, dynamic> option, ExportAction rowAction) {
    final theme = Theme.of(context);
    final colors = HaLoColors.of(context);
    final key = _selectionKey(option);
    final filename = _filenameOf(option);
    final label = option['label'] as String? ?? option['exportType'] as String;
    final selected = _selected[key] ?? false;
    // The option's own declared accent wins — the whole-log ADIF asks for a
    // neutral grey precisely because it belongs to no activity. Failing that,
    // the activity's own accent when this export claims one of its refs;
    // failing that, the theme's on-surface accent, which is the vetted one
    // for foreground use (an extension's hex is a background color in the
    // sheet, and can't be trusted to contrast as text or as a bare glyph).
    final activityColor = resolveExtensionColor(option['color'] as String?) ??
        colorForRefType(_controls, option['refType'] as String?);

    void toggle() => setState(() => _selected[key] = !selected);

    return InkWell(
      // The row is a big tap target for the checkbox at its far end, but it
      // is NOT a second control: the checkbox already carries that meaning,
      // and announcing the row as a button too would just be a duplicate to
      // swipe past.
      onTap: _busy ? null : toggle,
      excludeFromSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.only(left: Space.xl, right: Space.xs),
          child: Row(
            children: [
              _optionIcon(option, activityColor, colors),
              const SizedBox(width: Space.xl),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.onSurfaceAccent,
                      ),
                    ),
                    if (option['filename'] != null)
                      Text(
                        filename,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  exportActionIcon(rowAction),
                  // Names the FILE, not just the verb: a column of identical
                  // "Download" buttons tells a screen-reader user nothing about
                  // which one they are on, and this app has no tooltips.
                  semanticLabel: _rowLabel(rowAction, filename),
                ),
                onPressed: _busy ? null : () => _run(rowAction, [option]),
              ),
              Checkbox(
                value: selected,
                onChanged: _busy ? null : (value) => setState(() => _selected[key] = value ?? false),
                // The row's text is excluded from semantics above, so this is
                // the only place the option is named to a screen reader.
                semanticLabel: label,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The option's icon, circled in the activity's accent when it has one —
  /// the same treatment the activity's own row gets in the operation sheet
  /// (`_accentIcon`), so the POTA export and the POTA row are
  /// recognisably the same thing.
  Widget _optionIcon(Map<String, dynamic> option, Color? activityColor, HaLoColors colors) {
    final icon = Icon(
      resolveIconName(option['icon'] as String?, fallback: MdiIcons.fileExport),
      color: activityColor == null ? colors.onSurfaceAccent : null,
    );
    if (activityColor == null) return icon;
    return CircleAvatar(backgroundColor: activityColor.withValues(alpha: 0.6), child: icon);
  }

  /// The batch action(s) for [selected] — everything ticked in the panel when
  /// it sits under the sync summary, or just one callsign's when [dense] puts
  /// it in a group header.
  Widget _buildBulkActions(
    BuildContext context,
    List<Map<String, dynamic>> selected, {
    bool dense = false,
    bool combined = false,
  }) {
    final actions = bulkExportActions();

    final buttons = <Widget>[
      if (_busy)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: Space.lg),
          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
        )
      else
        for (final (index, action) in actions.indexed)
          // The first is the platform's primary verb; anything after it (only
          // Android's Share) is an alternative, not a competing call to
          // action.
          index == 0
              ? FilledButton.icon(
                  onPressed: selected.isEmpty ? null : () => _run(action, selected),
                  icon: Icon(exportActionIcon(action), size: 18),
                  label: Text(_bulkLabel(action, selected.length, combined: combined)),
                )
              : OutlinedButton.icon(
                  onPressed: selected.isEmpty ? null : () => _run(action, selected),
                  icon: Icon(exportActionIcon(action), size: 18),
                  label: Text(_bulkLabel(action, selected.length, combined: combined)),
                ),
    ];

    // Wrap, not Row: on Android there are two buttons, and in a group header
    // beside a callsign they don't fit a phone's width side by side.
    if (dense) {
      return Wrap(spacing: 8, runSpacing: 4, alignment: WrapAlignment.end, children: buttons);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.lg),
      child: Wrap(spacing: 8, runSpacing: 4, children: buttons),
    );
  }

  /// Just the way out. Everything that DOES something lives in the list,
  /// so this stays a plain dismissal — nothing here is destructive or
  /// unsaved, and the exports have already happened by the time it's pressed.
  Widget _buildFooter(BuildContext context) => haloDialogFooterBand(
        context,
        // Everything that DOES something lives in the list above and has
        // already happened by the time this is pressed, so this is a way out
        // rather than a confirm: plain Done, in the cancel slot.
        cancel: TextButton(
          // maybePop, matching the pane's barrier.
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(context.t.common.done),
        ),
      );
}

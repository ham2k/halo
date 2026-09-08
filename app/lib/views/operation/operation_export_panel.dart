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

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../services/halo_services.dart';
import 'package:halo_i18n/halo_i18n.dart';
import '../../services/error_reporting_service.dart';
import '../../services/export_service.dart';
import '../../services/status_bar_service.dart';

/// The ground every band in this pane paints on — the callsign headers, the
/// batch that opens the list and the sync report that closes it. ONE
/// definition: three bands a shade apart read as three unrelated things
/// rather than as the frame around one list.
///
/// OPAQUE — the tint already blended into the pane's own surface rather than
/// laid over it. A pinned band has the list running underneath it, and a
/// half-transparent one shows the rows sliding through the callsign.
Color _bandColor(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return Color.alphaBlend(colors.surfaceContainerHighest.withValues(alpha: 0.5), colors.surface);
}

/// The callsign band's height at text scale 1: [Space.lg] above and below a
/// Material button's own 40, which is the tallest thing in it (the callsign
/// and the tower glyph are both shorter).
///
/// A constant because the band rides in a pinned [SliverPersistentHeader],
/// which cannot measure its child. The OS text-scale preference composes on
/// top of the app's own Font Scale (ui-scaling.md rule 3) and grows the
/// button inside the band, so the caller scales this rather than the band
/// being written against one scale.
const _groupHeaderHeight = Space.lg * 2 + 40;

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
/// (`ExportsSettingsGroup`), so the same setting is reachable from
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
        // Presentation only — the accent AND the icon a row inherits from
        // its activity (`_optionIcon`). A runtime that can't answer must not
        // cost the panel its export list, so this one degrades to the theme
        // accent and the generic file glyph rather than failing the whole
        // load; every option still names its own file and still exports it.
        widget.services.extensions
            .operationControls(widget.operation.data)
            // Which is also why `loadFailed` is dropped here and acted on
            // everywhere else: this panel has nothing to withhold on a bad
            // load the way a ref list does — a plainer row is the whole cost.
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
    setState(() => _busy = true);
    String? outcome;
    String? failure;
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
          final saved = await exports.saveToDisk(files);
          // Null means the operator cancelled the picker — their choice, not
          // an outcome worth announcing. The COUNT is the save's own, never
          // `files.length`: Android asks per file and takes a cancel partway,
          // so claiming the list's length names files that aren't there.
          if (saved != null) {
            // "to <path>" reads as a destination, which Android's answer is
            // not — there it is the list of names the platform gave back, and
            // the operator would be told their files went to their own
            // filenames.
            outcome = saved.namesFiles
                ? t.operation.export.saveSuccessNamed(count: saved.count, path: saved.location)
                : t.operation.export.saveSuccess(count: saved.count, path: saved.location);
          }
        case ExportAction.share:
        case ExportAction.export:
          // Only when the operator actually shared. Reporting unconditionally
          // would announce a completed share for a sheet they dismissed —
          // asserting an outcome that didn't happen.
          if (await exports.shareFiles(files, sharePositionOrigin: shareOrigin)) {
            outcome = t.operation.export.shareSuccess(count: files.length);
          }
        case ExportAction.download:
          await exports.downloadFiles(files);
          outcome = t.operation.export.downloadSuccess(count: files.length);
      }
    } catch (e, stack) {
      failure = e.toString();
      // The dialog is the operator's copy; this is the developer's. An export
      // that fails in the field leaves no other trace — the catch is where
      // the stack ends.
      debugPrint('[export] ${action.name} failed: $e\n$stack');
      // An ExportException is an OUTCOME of this flow — a runtime that isn't
      // up yet, a save the platform refused — reported to the operator and
      // spent. Uploading one would file an expected answer as a crash, the
      // way error-reporting.md rules out for `SyncEngine.onAuthError`.
      // Anything else got here by surprise and is worth the event.
      if (e is! ExportException) {
        ErrorReportingService.report(e, stack, context: 'export:${action.name}');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    final report = failure != null
        ? (title: t.operation.export.resultFailedTitle, body: failure)
        : outcome != null
            ? (title: t.operation.export.resultTitle, body: outcome)
            : null;
    if (report == null) return;
    // The pane can go while an export runs — its Done stays live, and the
    // barrier is dismissible — and the dialog needs a context this State
    // no longer has. The status bar outlives it, so the outcome still
    // reaches the operator rather than being dropped for having taken too
    // long.
    if (!mounted) {
      widget.services.statusBar.setMessage(
        key: 'export:status',
        // Titled: a bare "Extension runtime is not ready yet" persisting in
        // the footer names no doer, and the operator has already left the
        // pane that would have said "export".
        text: '${report.title}: ${report.body}',
        dismissAfter: failure == null ? StatusBarService.completedDismissDelay : null,
      );
      return;
    }
    await _showResult(report.title, report.body);
  }

  /// The outcome, as a dialog over the panel rather than a line in the status
  /// bar: exporting is the thing the operator opened this pane to do, and a
  /// message in a far corner of the window is missable at exactly the moment
  /// they need to know whether the files exist and where they landed.
  ///
  /// The pane stays open behind it — exporting one format and then another is
  /// ordinary, and dismissing the confirmation is not a request to leave.
  Future<void> _showResult(String title, String body) => showHaloDialog<void>(
        context: context,
        builder: (dialogContext) => HaloDialog(
          title: Text(title),
          content: Text(body),
          // Nothing to abandon and nothing left to confirm: Done, in the
          // cancel slot (docs/design/user-interface.md § Dialogs).
          cancel: TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.t.common.done),
          ),
        ),
      );

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
        // The sync report is pinned under the list rather than riding at the
        // end of it: it is a standing fact about the operation, not one more
        // thing to scroll to, and a long list of formats would bury it.
        if (!_loading && _error == null) ...[
          const Divider(height: 1),
          _buildSyncSummary(context, _syncCounts),
        ],
        _buildFooter(context),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final rowAction = rowExportAction();
    // Computed once: it walks every option, and the layout branches on its
    // length below.
    final groups = _groups;

    return CustomScrollView(
      slivers: [
        // The batch OPENS the list, whether it spans one callsign or six: a
        // button saying "Save 3 files" belongs with the ticks it counted, and
        // the operator who came to export everything should not have to reach
        // the end of the formats to find the button that does it.
        if (_options.isNotEmpty)
          SliverToBoxAdapter(child: _buildActionBand(context, combined: groups.length > 1)),
        if (_options.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(Space.xl),
              child: Text(
                // Two different empties, and saying the wrong one sends the
                // operator looking for a fault: a log with no contacts yet has
                // nothing to offer, where a log WITH contacts and no options
                // means the formats themselves never arrived.
                _syncCounts != null && _syncCounts!.total == 0
                    ? t.operation.export.nothingLogged
                    : t.operation.export.noOptions,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          )
        else
          for (final group in groups)
            // A single-station operation is the common case and gets no
            // header at all — grouping chrome around one group is just noise,
            // and with nothing to tell apart there is nothing to pin.
            if (groups.length > 1)
              SliverMainAxisGroup(slivers: [
                // Pinned: the callsign a row belongs to is the one thing a
                // multi-operator list cannot afford to scroll away, since
                // every group offers the same formats under a different call.
                // Only inside this group — pinned to the whole scroll view,
                // every callsign's band would stack up at the top.
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PinnedGroupHeader(
                    // Never BELOW the unscaled height: 40 of those pixels are
                    // a Material button's own floor, which an OS text scale
                    // under 1 does not shrink — scaled down, the band clamps
                    // the button instead of fitting it.
                    height: math.max(
                      _groupHeaderHeight,
                      MediaQuery.textScalerOf(context).scale(_groupHeaderHeight),
                    ),
                    child: _buildGroupHeader(context, group),
                  ),
                ),
                _optionRows(context, group.options, rowAction),
              ])
            else
              _optionRows(context, group.options, rowAction),
        const SliverToBoxAdapter(child: SizedBox(height: Space.md)),
      ],
    );
  }

  Widget _optionRows(
    BuildContext context,
    List<Map<String, dynamic>> options,
    ExportAction rowAction,
  ) =>
      SliverList(
        delegate: SliverChildListDelegate([
          for (final option in options) _buildOptionRow(context, option, rowAction),
        ]),
      );

  /// The operation's sync state, in ONE row. Event markers are counted on the
  /// same line rather than in a row of their own: a second tile would read as
  /// a second report to check on a routine "everything is synced", and would
  /// appear only when the operation has markers, moving everything under it.
  Widget _buildSyncSummary(
    BuildContext context,
    ({int total, int pending, int eventTotal, int eventPending})? counts,
  ) {
    final t = context.t.operation.export;
    final qsos = counts == null
        ? null
        : counts.pending == 0
            ? t.qsosSynced(total: counts.total)
            : t.qsosPending(pending: counts.pending, total: counts.total);
    final events = counts == null || counts.eventTotal == 0
        ? null
        : counts.eventPending == 0
            ? t.eventsSynced(total: counts.eventTotal)
            : t.eventsPending(pending: counts.eventPending, total: counts.eventTotal);
    return Container(
      // The same band the batch at the top of the list takes: the two are the
      // ends of one list, not a control at one end and a stray row at the
      // other.
      color: _bandColor(context),
      child: ListTile(
        leading: Icon(widget.operation.synced ? MdiIcons.cloudCheck : MdiIcons.cloudAlert),
        title: Text(widget.operation.synced ? t.syncedOperation : t.unsyncedOperation),
        subtitle: qsos == null ? null : Text([qsos, ?events].join(' · ')),
      ),
    );
  }

  /// The band the whole-panel batch sits in — the single-callsign panel's,
  /// and the one that spans every callsign.
  ///
  /// What it acts on, named on the left, and the button that does it on the
  /// right: a count of the log is the one thing that makes "Save 3 files"
  /// mean something before the operator has read the list. On the callsign
  /// bands' own ground, in the section title's face, so it and the sync
  /// report that closes the pane read as the two ends of one list.
  ///
  /// ONE band for both cases: a bare left-aligned button in the one-callsign
  /// panel and a banded right-aligned one in the many-callsign panel read as
  /// different controls.
  Widget _buildActionBand(BuildContext context, {bool combined = false}) {
    final counts = _syncCounts;
    // No count, no claim: the operator reads this band before the list, and
    // an empty log is what the empty state below already says.
    final count = counts == null || counts.total == 0
        ? null
        : Text(
            context.t.operation.export.qsosInOperation(count: counts.total),
            // The band's accent and slab at the ROW face's size, not
            // SectionHeader.titleStyle: that is the HEADING face, a step up,
            // and a count is a sentence, which at that size takes two lines
            // of a phone's band.
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontFamily: 'RobotoSlab',
                  fontWeight: FontWeight.w900,
                  color: HaLoColors.of(context).onSurfaceAccent,
                ),
          );
    return Container(
      color: _bandColor(context),
      // Trailing inset matches the group headers', and both stand one unit
      // clear of the edge: a scrollbar rides there, and a button under it is
      // one the operator has to aim around.
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, Space.lg),
      // An OverflowBar, not a Row: the buttons take their natural width and
      // whatever a Row gave the count would be the leftover — which on a
      // phone with two Android verbs is a few characters a line. Here the two
      // sit side by side while they both fit and STACK when they don't, the
      // buttons keeping the trailing edge on their own line. The dialog
      // footers use it for the same reason.
      child: OverflowBar(
        // With a count, the two take the band's two ends; with none, the
        // buttons still close it — `spaceBetween` would put a lone child at
        // the START and swing them across the band whenever the log is empty.
        alignment: count == null ? MainAxisAlignment.end : MainAxisAlignment.spaceBetween,
        overflowAlignment: OverflowBarAlignment.end,
        spacing: Space.md,
        overflowSpacing: Space.sm,
        children: [
          ?count,
          _buildBulkActions(context, _selectedOptions, combined: combined),
        ],
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
      color: _bandColor(context),
      // Trailing inset one unit clear of the edge, out from under the
      // scrollbar — see [_buildActionBand].
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, Space.lg),
      // The BAND's width, not the window's: this pane is a dialog on a
      // desktop, where `ShirtSize.of` reports a window wide enough for labels
      // that its dialog has no room for.
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Icon(MdiIcons.radioTower, size: 20, color: colors.onSurfaceAccent),
            const SizedBox(width: Space.lg),
            Expanded(
              child: Text(
                // An operation with no callsign at all still groups; naming it
                // by its emptiness would read worse than the fallback.
                group.call.isEmpty ? context.t.operation.export.title : group.call,
                // The band's height is declared up front, so nothing in it may
                // take a second line: the callsign gives way to the buttons.
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onSurfaceAccent,
                ),
              ),
            ),
            _buildBulkActions(
              context,
              selected,
              wrap: false,
              // The shared breakpoints, not one invented here (layouts.md):
              // S covers the 360 Android baseline, which is exactly where two
              // counted labels and a callsign stop fitting on one line.
              compact: ShirtSize.fromWidth(constraints.maxWidth).index <= ShirtSize.s.index,
            ),
          ],
        ),
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
    // The developer QSON dump belongs to no activity and declares no colour
    // of its own, so nothing here would circle it and it would read as the
    // one bare glyph in a column. It takes the dev-mode orange every other
    // developer-only surface is marked with instead.
    final activityColor = widget.services.exports.isQsonOption(option)
        ? colors.devMode
        : resolveExtensionColor(option['color'] as String?) ??
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
  ///
  /// An option that names no icon of its own but does name a `refType` wears
  /// that activity's icon, the same route its accent already takes
  /// (`colorForRefType`) — a contest's two files belong to the contest, and a
  /// generic file glyph would say only "an export", which every row is. A
  /// name that doesn't RESOLVE falls through the same way an unreadable
  /// `color` does, so a typo costs an option the glyph, not the inheritance.
  Widget _optionIcon(Map<String, dynamic> option, Color? activityColor, HaLoColors colors) {
    final icon = Icon(
      resolveIconName(
        option['icon'] as String?,
        fallback: resolveIconName(
          iconForRefType(_controls, option['refType'] as String?),
          fallback: MdiIcons.fileExport,
        ),
      ),
      color: activityColor == null ? colors.onSurfaceAccent : null,
    );
    if (activityColor == null) return icon;
    return CircleAvatar(backgroundColor: activityColor.withValues(alpha: 0.6), child: icon);
  }

  /// The batch action(s) for [selected] — everything ticked in the panel, in
  /// [_buildActionBand], or just one callsign's in its group header.
  Widget _buildBulkActions(
    BuildContext context,
    List<Map<String, dynamic>> selected, {
    bool combined = false,
    bool wrap = true,
    bool compact = false,
  }) {
    final actions = bulkExportActions();

    /// The count alone where the label won't fit — the icon already carries
    /// the verb, and "3" beside a save glyph is the same sentence shorter.
    /// The full label stays as the accessible name: a screen reader given "3"
    /// is told nothing, and this app has no tooltips to fall back on.
    Widget labelFor(ExportAction action) {
      final label = _bulkLabel(action, selected.length, combined: combined);
      return compact
          ? Text('${selected.length}', semanticsLabel: label)
          : Text(label);
    }

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
                  label: labelFor(action),
                )
              : OutlinedButton.icon(
                  onPressed: selected.isEmpty ? null : () => _run(action, selected),
                  icon: Icon(exportActionIcon(action), size: 18),
                  label: labelFor(action),
                ),
    ];

    // The pinned callsign band declares its height before its child is laid
    // out and cannot grow a second run, so its buttons stay on one line. On a
    // pane narrow enough that counted labels wouldn't fit beside a callsign,
    // [compact] is what makes the room — the ellipsis alone cannot, since a
    // Row lays a non-flex child out unbounded and the callsign is what gives
    // way first.
    if (!wrap) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, button) in buttons.indexed) ...[
            if (index > 0) const SizedBox(width: Space.md),
            button,
          ],
        ],
      );
    }
    // Wrap elsewhere: on Android there are two buttons, and on a phone at a
    // large font scale they don't fit a row side by side.
    return Wrap(spacing: 8, runSpacing: 4, alignment: WrapAlignment.end, children: buttons);
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

/// The callsign band's pinned-sliver delegate — a fixed [height], since a
/// SliverPersistentHeader can't size itself to its child.
class _PinnedGroupHeader extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _PinnedGroupHeader({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  // A pinned sliver whose child paints shorter or taller than the extent it
  // declared throws ("layoutExtent exceeds paintExtent"), so the child is
  // held to exactly that box rather than trusted to match it.
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      SizedBox(height: height, child: child);

  // Always true: [child] is rebuilt fresh by the enclosing build — it carries
  // the group's live tick count — so the comparison would never match anyway,
  // and a false here would leave a stale count banded on screen, since
  // RenderSliverPersistentHeader only picks up a new delegate when this says
  // so.
  @override
  bool shouldRebuild(_PinnedGroupHeader oldDelegate) => true;
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Logs view's ADIF drop: an import across every operation, from a file
// dropped anywhere on the view.

part of '../logs_view.dart';

mixin _LogsAdifDrop on State<LogsView> {
  // Owned by `_LogsViewState`.
  LogFilter get _filter;
  Future<bool> _settleAndClose();
  Future<void> _pickFilter(LogFilter filter);

  /// Stops watching the log for an import's write phase — see where
  /// [_runAdifDrop] calls it for why — and [_resumeLog] starts again on
  /// [filter] once the last chunk has landed.
  Future<void> _pauseLog();
  void _resumeLog(LogFilter filter);

  /// A deliberately simpler import than `operation/adif_import_flow.dart`'s:
  /// this reads straight from the parser, never stamping a record's own
  /// station callsign to match one target operation's (that's what
  /// `planAdifImport`'s `stationCall` param does, and what drives its
  /// "foreign station" warning and activation prompt — neither belongs to a
  /// cross-operation log). It still calls `planAdifImport` with
  /// `stationCall: null`, purely for the merge-vs-addition matching it does
  /// against EXISTING QSOs across every operation (broadened from that
  /// function's usual one-operation scope), so a record matching something
  /// already logged updates it in place instead of duplicating it.
  ///
  /// Anything left over lands with no operation at all (`operationUuid: ''`)
  /// — "loose", until an operator (or later, real operation-detection) puts
  /// it in one. A record that MERGES keeps whatever operation (or looseness)
  /// the matched QSO already had.
  Future<void> _handleAdifDrop(XFile file) async {
    final t = context.t.adifImport;
    // Same order `adif_import_flow.dart`'s entry points check these in — the
    // busy check first, so an identical drop reports identically regardless
    // of which view it lands on. Shared with those two entry points (see
    // that flag's own doc comment) — this plans across every operation, so a
    // second import racing it is the same stale-snapshot corruption with a
    // wider blast radius.
    if (adifImportInFlight) {
      await _showAdifNotice(t.busy);
      return;
    }
    if (!looksLikeAdif(file.name)) {
      await _showAdifNotice(t.notAdif(filename: file.name));
      return;
    }
    // Claimed before the editor is settled, not after: settling can wait on
    // a save in flight with no dialog up to disable the drop target, and a
    // second drop in that gap would pass the check above and race this one.
    adifImportInFlight = true;
    try {
      // The import takes the table down while it writes, and the editor
      // with it: an edit in progress is settled, and the editor closed,
      // before anything starts.
      if (!await _settleAndClose() || !mounted) return;
      await _runAdifDrop(file);
    } finally {
      adifImportInFlight = false;
    }
  }

  Future<void> _runAdifDrop(XFile file) async {
    final t = context.t.adifImport;
    final importT = context.t.home.logs.import;
    final title = ValueNotifier<String>(importT.readingTitle);
    final progress = ValueNotifier<double?>(0);
    final detail = ValueNotifier<String>('');
    void disposeNotifiers() {
      title.dispose();
      progress.dispose();
      detail.dispose();
    }

    // Captured now, while this is definitely still mounted, rather than
    // reading `Navigator.of(context)` at each pop site below — the import
    // can outlive this view (switching away mid-drop), and a `NavigatorState`
    // held directly stays poppable after that, unlike `context`, which
    // throws once the element backing it is gone. The dialog itself is
    // `PopScope(canPop: false)`, so as long as nothing else shows a competing
    // modal while this barrier is up, this is the only thing left to pop.
    final dialogNavigator = Navigator.of(context, rootNavigator: true);
    void closeProgressDialog() {
      if (dialogNavigator.mounted) dialogNavigator.pop();
    }

    unawaited(
      showHaloDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _AdifProgressDialog(title: title, progress: progress, detail: detail),
      ),
    );

    AdifLog log;
    AdifImportPlan plan;
    try {
      // Streamed rather than one `readAsBytes()` call, purely so this has
      // real bytes-read progress to show instead of an indeterminate spinner
      // for however long a large file takes.
      final total = await file.length();
      final builder = BytesBuilder(copy: false);
      var readSoFar = 0;
      await for (final chunk in file.openRead()) {
        builder.add(chunk);
        readSoFar += chunk.length;
        if (total > 0) progress.value = readSoFar / total;
        detail.value = importT.readingDetail(kb: formatNumber((readSoFar / 1024).round()));
      }
      // Parsing has no natural checkpoint to report progress from (a single
      // synchronous pass), but the ref-hook pass and the duplicate lookup
      // both already run in bounded batches/chunks — real per-record
      // progress for those, on one combined bar, rather than leaving the
      // whole stretch indeterminate. Each callback below reports progress
      // ABSOLUTE within its own phase; `checkTotal` covers both phases, so
      // the lookup's contribution is offset by the hooks phase's total
      // (already complete by the time lookup starts) rather than restarting
      // the bar at the boundary between them.
      title.value = importT.checkingTitle;
      detail.value = '';
      progress.value = null;
      log = parseAdifLogBytes(builder.takeBytes());
      // Normalized the same way `historyForCalls` normalizes its own `calls`
      // argument internally (trim + uppercase) — otherwise two records
      // differing only in case or stray whitespace count as two entries
      // here but collapse to one in `historyForCalls`'s own total, and the
      // combined progress bar below stalls just short of 100% because the
      // lookup phase can never report as many calls checked as this side
      // expects.
      final theirCalls = <String>{
        for (final record in log.qsos)
          if ((record.qso['their'] as Map?)?['call'] case final String call when call.isNotEmpty) call.trim().toUpperCase(),
      }..removeWhere((call) => call.isEmpty);
      final checkTotal = log.qsos.length + theirCalls.length;
      void reportChecked(int checked) {
        if (checkTotal > 0) progress.value = checked / checkTotal;
        detail.value = importT.checkingDetail(done: formatNumber(checked), total: formatNumber(checkTotal));
      }

      final hookOutcome = await AdifImportService(widget.services.extensions.host).applyHooks(log.qsos, onBatch: (done, total) => reportChecked(done));
      // One batched query rather than one per distinct counterparty — a
      // large file's callsigns run into the thousands, and a sequential
      // `historyForCall` per callsign turns that into thousands of
      // round trips with the progress bar stuck on indeterminate.
      final existing = await widget.services.qsos.historyForCalls(theirCalls, onChunk: (done, total) => reportChecked(log.qsos.length + done));
      // Threaded through to the plan the same way `adif_import_flow.dart`
      // does — dropping these silently degrades a ref-hook failure into a
      // clean-looking import with no references, indistinguishable from a
      // file that genuinely had none.
      plan = planAdifImport(
        filename: file.name,
        records: log.qsos,
        existing: existing,
        unusable: log.errors,
        failedHooks: hookOutcome.failedHooks,
        recordsUnreachable: hookOutcome.recordsUnreachable,
        recordsWithFailedHooks: hookOutcome.recordsWithFailedHooks,
      );
    } catch (e, stack) {
      disposeNotifiers();
      closeProgressDialog();
      ErrorReportingService.report(e, stack, context: 'logsAdifImport');
      if (mounted) await _showAdifNotice(t.failed(filename: file.name, error: e.toString()));
      return;
    }
    if (!mounted) {
      disposeNotifiers();
      closeProgressDialog();
      return;
    }
    closeProgressDialog();

    // Uppercased, like every other callsign path in this view — an ADIF
    // file's STATION_CALLSIGN case isn't guaranteed, and `_callsigns` (from
    // `watchDistinctOurCalls`) is always uppercase, so a mixed-case value
    // here would both double-count in this summary and fail to match an
    // entry in the picker after `_pickFilter` below.
    final calls = <String>{
      for (final record in log.qsos)
        if ((record.qso['our'] as Map?)?['call'] case final String call when call.isNotEmpty) call.toUpperCase(),
    }.toList()..sort();
    // Coerced through `qsoStartMillis` rather than cast directly — a JSON
    // number from `applyHooks`'s extension host can come back as a double,
    // and a raw `as int?` throws on that outside the try block above.
    final dateRange = _millisRange(log.qsos.map((record) => qsoStartMillis(record.qso)));
    final dateRangeLabel = dateRange == null ? null : _dateRangeLabel(dateRange.$1, dateRange.$2);
    if (!mounted) {
      disposeNotifiers();
      return;
    }
    final confirmed = await showHaloDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final importT = context.t.home.logs.import;
        final totalInFile = t.totalInFile(count: log.qsos.length, formatted: formatNumber(log.qsos.length));
        return HaloDialog(
          title: Text(t.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(importT.callsigns(calls: calls.join(', '))),
              const SizedBox(height: Space.sm),
              // Three separate counts, not one combined figure — a re-import
              // of a file already fully in the log matches every record and
              // imports none of them, and "0 QSOs" on its own reads as
              // nothing in the file was recognized rather than as "nothing
              // has changed since last time."
              Text(dateRangeLabel == null ? totalInFile : '$totalInFile ($dateRangeLabel)'),
              if (plan.alreadyLoggedCount > 0) Text(t.alreadyLogged(count: plan.alreadyLoggedCount, formatted: formatNumber(plan.alreadyLoggedCount))),
              Text(t.willImport(count: plan.importCount, formatted: formatNumber(plan.importCount))),
              if (plan.refusedCount > 0) ...[
                const SizedBox(height: Space.sm),
                Text(
                  plan.refusedCount == 1 ? importT.skippedOne : importT.skippedOther(count: formatNumber(plan.refusedCount)),
                  style: TextStyle(color: Theme.of(dialogContext).colorScheme.error),
                ),
              ],
              // Two separate sentences, not one shared count, for the same
              // reason `adif_import_flow.dart`'s summary keeps them apart:
              // nothing reaching the runtime means no references were
              // recovered at all, while one program's hook failing still
              // leaves every other hook's answer intact — the honest claim
              // for each kind of record is different.
              if (plan.recordsUnreachable > 0) ...[
                const SizedBox(height: Space.sm),
                Text(
                  t.missingRefs(count: plan.recordsUnreachable, formatted: formatNumber(plan.recordsUnreachable)),
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
              ],
              if (plan.recordsWithFailedHooks > 0) ...[
                const SizedBox(height: Space.sm),
                Text(
                  t.partialRefs(
                    programs: failedProgramNames(widget.services.extensions.availableExtensions, plan.failedHooks).join(', '),
                    count: plan.recordsWithFailedHooks,
                    formatted: formatNumber(plan.recordsWithFailedHooks),
                  ),
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
              ],
              // Truly nothing recognized — as opposed to a fully-matched
              // re-import, which still has `alreadyLoggedCount` to say so —
              // gets the same explicit line `adif_import_flow.dart`'s
              // summary shows for the same case.
              if (plan.isEmpty && plan.refusedCount == 0 && plan.alreadyLoggedCount == 0) Text(context.t.adifImport.nothingToImport),
            ],
          ),
          // Empty plans get no confirm action, the same way
          // `adif_import_flow.dart` handles them — nothing to write, so the
          // only thing to do is close the summary.
          actions: [if (!plan.isEmpty) FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(t.confirm))],
          cancel: TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(plan.isEmpty ? context.t.common.done : context.t.common.cancel),
          ),
        );
      },
    );
    if (confirmed != true || !mounted) {
      disposeNotifiers();
      return;
    }

    var written = 0;
    final totalPlanned = plan.importCount;
    title.value = importT.importingTitle;
    progress.value = 0;
    detail.value = importT.importingDetail(imported: formatNumber(written), total: formatNumber(totalPlanned));
    unawaited(
      showHaloDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _AdifProgressDialog(title: title, progress: progress, detail: detail),
      ),
    );

    // Unsubscribed for the write phase, not merely paused — a large import
    // commits dozens of chunks, and each commit makes a live Drift stream
    // re-run its query and re-decode the full result set REGARDLESS of
    // whether its listener is paused (pausing only withholds delivery, not
    // the underlying work). Nothing is watching either while this view sits
    // behind the non-dismissible progress dialog above, so cancel rather
    // than pause, and resubscribe once after the last chunk lands.
    final filterBeforeWrite = _filter;
    await _pauseLog();
    // Never allowed to throw — called right before the notifiers/dialog
    // cleanup on every exit path (success, write failure, unmount), and a
    // caller that skipped that cleanup because THIS threw would leave the
    // non-dismissible progress dialog stuck on screen with nothing able to
    // close it, and — on the write-failure path — the real error unreported
    // underneath whatever this raised instead.
    void resubscribe() {
      try {
        if (!mounted) return;
        _resumeLog(filterBeforeWrite);
      } catch (e, stack) {
        ErrorReportingService.report(e, stack, context: 'logsAdifImport:resubscribe');
      }
    }

    // `writeBatch` refuses a batch whose updates don't all share its
    // `operationUuid`, so each destination operation (or the loose bucket)
    // gets its own call — chunked, so `progress` moves as QSOs actually
    // land rather than jumping straight to done on one giant batch. 1000,
    // not something smaller: `writeBatch` compiles each chunk into one
    // `db.batch()` statement, so the per-chunk cost is now mostly the
    // transaction commit rather than per-row work, and a larger chunk still
    // leaves plenty of progress updates (tens of them) on a file large
    // enough for the chunking to matter at all.
    const chunkSize = 1000;
    // Each chunk skips `writeBatch`'s own counter refresh (`refreshCounters:
    // false`) — a large import writes the same operation across dozens of
    // chunks, and the counters only need to be right once writing to it is
    // done, not after every intermediate chunk. `refreshTouchedCounters`
    // below catches up whichever operations were actually written to, once,
    // regardless of whether the import completes or throws partway through.
    final touchedOperations = <String>{};
    Future<void> writeChunked(String operationUuid, {List<Map<String, dynamic>> inserts = const [], List<Qso> updates = const []}) async {
      if (operationUuid.isNotEmpty) touchedOperations.add(operationUuid);
      for (var i = 0; i < inserts.length; i += chunkSize) {
        final chunk = inserts.sublist(i, math.min(i + chunkSize, inserts.length));
        written += await widget.services.qsos.writeBatch(operationUuid: operationUuid, inserts: chunk, refreshCounters: false);
        if (totalPlanned > 0) progress.value = written / totalPlanned;
        detail.value = importT.importingDetail(imported: formatNumber(written), total: formatNumber(totalPlanned));
      }
      for (var i = 0; i < updates.length; i += chunkSize) {
        final chunk = updates.sublist(i, math.min(i + chunkSize, updates.length));
        // The whole plan's bases ride along with every chunk — writeBatch
        // only consults the uuids it is writing, and without them a row
        // that moved while the confirm dialog sat open is clobbered with
        // the stale plan-time fold (see `updateBases`).
        written += await widget.services.qsos.writeBatch(operationUuid: operationUuid, updates: chunk, updateBases: plan.mergeBases, refreshCounters: false);
        if (totalPlanned > 0) progress.value = written / totalPlanned;
        detail.value = importT.importingDetail(imported: formatNumber(written), total: formatNumber(totalPlanned));
      }
    }

    // Same "never throws" contract as `resubscribe` above, and for the same
    // reason — one operation's counter failing to refresh must not skip the
    // dialog cleanup, or bury the write failure the catch block below exists
    // to report.
    Future<void> refreshTouchedCounters() async {
      for (final operationUuid in touchedOperations) {
        try {
          await widget.services.qsos.refreshOperationCounters(operationUuid);
        } catch (e, stack) {
          ErrorReportingService.report(e, stack, context: 'logsAdifImport:refreshCounters');
        }
      }
    }

    final mergesByOperation = <String, List<Qso>>{};
    for (final qso in plan.merges) {
      mergesByOperation.putIfAbsent(qso.operationUuid, () => []).add(qso);
    }
    try {
      for (final entry in mergesByOperation.entries) {
        await writeChunked(entry.key, updates: entry.value);
      }
      if (plan.additions.isNotEmpty) {
        await writeChunked('', inserts: plan.additions);
      }
    } catch (e, stack) {
      await refreshTouchedCounters();
      resubscribe();
      disposeNotifiers();
      closeProgressDialog();
      ErrorReportingService.report(e, stack, context: 'logsAdifImport:write');
      // `written` still reflects whatever chunks landed before the throw —
      // some of the file may already be in the log, so this states that
      // rather than reading as a clean failure the operator would retry
      // whole.
      if (mounted) {
        await _showAdifNotice(
          written > 0
              ? '${t.failed(filename: file.name, error: e.toString())}\n\n'
                    '${importT.importingDetail(imported: formatNumber(written), total: formatNumber(totalPlanned))}'
              : t.failed(filename: file.name, error: e.toString()),
        );
      }
      return;
    }
    await refreshTouchedCounters();
    resubscribe();
    disposeNotifiers();
    closeProgressDialog();
    if (!mounted) return;
    widget.services.statusBar.setMessage(
      key: 'logsAdifImport:status',
      text: t.imported(count: written, filename: file.name, formatted: formatNumber(written)),
      dismissAfter: StatusBarService.completedDismissDelay,
    );
    // The repository counts rows actually affected, so a merge target
    // deleted while the confirm dialog was open shows up here — same
    // reconciliation `adif_import_flow.dart` does after its own write.
    if (written != plan.importCount) {
      widget.services.statusBar.showNotice(
        key: 'logsAdifImport:shortfall',
        text: t.shortfall(written: written, planned: plan.importCount),
      );
    }
    try {
      widget.services.track('adif_imported', {'count': written, 'merged': plan.merges.length, 'planned': plan.importCount, 'source': 'logs'});
    } catch (e, stack) {
      ErrorReportingService.report(e, stack, context: 'logsAdifImport:telemetry');
    }

    // The callsign with the most QSOs in the file, so a multi-callsign
    // import (e.g. a rover's log) lands the operator on the one they
    // probably came here for rather than wherever they happened to be.
    final callCounts = <String, int>{};
    for (final record in log.qsos) {
      if ((record.qso['our'] as Map?)?['call'] case final String call when call.isNotEmpty) {
        final upperCall = call.toUpperCase();
        callCounts[upperCall] = (callCounts[upperCall] ?? 0) + 1;
      }
    }
    String? winner;
    var winnerCount = -1;
    for (final entry in callCounts.entries) {
      if (entry.value > winnerCount) {
        winner = entry.key;
        winnerCount = entry.value;
      }
    }
    // All already shows the new QSOs, wherever they landed.
    if (winner != null && !_filter.allCalls) await _pickFilter(LogFilter(stationCall: winner));
  }

  Future<void> _showAdifNotice(String message) => showHaloDialog<void>(
    context: context,
    builder: (dialogContext) => HaloDialog(
      title: Text(context.t.adifImport.title),
      content: Text(message),
      cancel: TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(context.t.common.done)),
    ),
  );
}

/// A non-dismissible progress dialog for the ADIF import's two blocking
/// phases (reading the file, writing the batch) — popped by the caller once
/// that phase's work finishes, not by anything in here. [title] and [detail]
/// are `ValueNotifier`s rather than plain fields so the SAME dialog instance
/// can carry the caller through both phases — swapping the phase title,
/// resetting the bar, and updating the running count — instead of closing
/// and reopening one dialog per phase, which reads as a flicker rather than
/// one continuous import.
///
/// [progress] is `0..1` for a real fraction (bytes read, QSOs written so
/// far) or `null` for a stretch with no comparable unit to report (parsing,
/// the extension ref-hook pass) — the bar falls back to indeterminate for
/// exactly that stretch.
class _AdifProgressDialog extends StatelessWidget {
  final ValueListenable<String> title;
  final ValueListenable<double?> progress;
  final ValueListenable<String> detail;

  const _AdifProgressDialog({required this.title, required this.progress, required this.detail});

  @override
  Widget build(BuildContext context) => PopScope(
    // `barrierDismissible: false` on the call site keeps a tap outside
    // from closing this, but only the system back button/gesture goes
    // through `PopScope` — without this, that route is the one thing
    // able to pop the dialog out from under the code driving it, which
    // then pops whatever the NEXT topmost route happens to be instead.
    canPop: false,
    child: HaloDialog(
      title: ValueListenableBuilder<String>(valueListenable: title, builder: (context, value, _) => Text(value)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<double?>(
            valueListenable: progress,
            builder: (context, value, _) => LinearProgressIndicator(value: value),
          ),
          const SizedBox(height: Space.lg),
          ValueListenableBuilder<String>(valueListenable: detail, builder: (context, value, _) => Text(value)),
        ],
      ),
    ),
  );
}

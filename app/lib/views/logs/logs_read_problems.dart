// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Logs view's log when it cannot be read whole: QSOs whose stored data
// is damaged, left out of the list and named in one banner for the whole
// log, and a query that fails outright.

part of '../logs_view.dart';

mixin _LogsReadProblems on State<LogsView> {
  /// The spinner's only way out when the callsigns query fails.
  bool _callsignsFailed = false;

  /// The queries whose failure this visit has uploaded: a failing query
  /// fails again, with a new error, on every write to the table it watches.
  /// Per query, so the callsigns failing first cannot hide the QSOs failing.
  final _readFailuresReported = <String>{};

  /// The last read the QSO stream delivered. An error snapshot carries no
  /// data, and a table with none would close an open editor, edit and all.
  QsoLogRead? _lastRead;

  /// Whether Export refuses the log, and says why: without its damaged
  /// QSOs, or from a read older than the log, the file is short contacts
  /// nobody is told about (docs/design/error-reporting.md,
  /// `unreadable-qso-row`).
  bool _exportRefused(int unreadable, {required bool stale}) {
    if (unreadable == 0 && !stale) return false;
    final t = context.t;
    widget.services.statusBar.showNotice(
      key: 'logsExport:unreadable',
      title: t.operation.export.resultFailedTitle,
      text: stale ? t.home.logs.exportStale : t.home.logs.unreadable.exportRefused(count: unreadable, n: formatNumber(unreadable)),
    );
    return true;
  }

  /// [told] when the view says so itself, where the generic notice would.
  void _reportReadFailure(Object error, StackTrace stack, String context, {required bool told}) {
    if (!_readFailuresReported.add(context)) {
      debugPrint('[logs] $context failed again, not uploaded: $error');
      return;
    }
    ErrorReportingService.report(error, stack, context: context, told: told);
  }

  /// A StreamBuilder keeps a stream's error to itself, so it is reported
  /// on its way there; it still arrives, and the view says so. Clears the
  /// last read: a new stream is another list, and a failure on it must not
  /// show the old one.
  Stream<QsoLogRead>? _reporting(Stream<QsoLogRead>? stream) {
    _lastRead = null;
    return stream?.transform(
      StreamTransformer.fromHandlers(
        handleError: (error, stack, sink) {
          _reportReadFailure(error, stack, 'logs:qsos', told: true);
          sink.addError(error, stack);
        },
      ),
    );
  }

  /// The read to show, and whether this stream's latest read failed. A
  /// StreamBuilder given a new stream keeps the old one's data or error
  /// while it waits: shown, the old rows hold the table steady until the
  /// new ones come; kept as [_lastRead], they would stand in for a failed
  /// read of another callsign's log, and an old error would fail a read
  /// that has not happened yet.
  (QsoLogRead?, bool) _readFrom(AsyncSnapshot<QsoLogRead> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) return (snapshot.data, false);
    if (snapshot.hasData) _lastRead = snapshot.data;
    return snapshot.hasError ? (_lastRead, true) : (snapshot.data, false);
  }
}

/// One banner for the whole log, over the table: how many QSOs could not be
/// read, with the details a tap away, and whether the log is showing an
/// older read because a newer one failed.
class _LogsReadProblemsBanner extends StatelessWidget {
  const _LogsReadProblemsBanner({required this.services, required this.unreadable, required this.stale});

  final HaLoServices services;
  final List<UnreadableQso> unreadable;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t.home.logs;
    final style = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onTertiaryContainer);
    return Card(
      margin: const EdgeInsets.all(Space.md),
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.md),
        child: Row(
          children: [
            Icon(MdiIcons.alertOutline, color: theme.colorScheme.onTertiaryContainer),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (unreadable.isNotEmpty)
                    Text(
                      t.unreadable.banner(count: unreadable.length, n: formatNumber(unreadable.length)),
                      style: style,
                    ),
                  if (stale) Text(t.refreshFailed, style: style),
                ],
              ),
            ),
            if (unreadable.isNotEmpty)
              TextButton(onPressed: () => unawaited(_showUnreadableQsos(context, services, unreadable)), child: Text(t.unreadable.details)),
          ],
        ),
      ),
    );
  }
}

Future<void> _showUnreadableQsos(BuildContext context, HaLoServices services, List<UnreadableQso> rows) async {
  final t = context.t.home.logs.unreadable;
  final messenger = ScaffoldMessenger.maybeOf(context);
  // Looked up once for the dialog and the copy alike: an operation deleted
  // since, or never synced here, is named as missing rather than skipped.
  // Null when the lookup fails — whatever damaged the QSOs may have damaged
  // their operation too, and the report must still copy without it.
  final operations = services.operations
      .byUuids({for (final row in rows) row.operationUuid}.where((uuid) => uuid.isNotEmpty).toList())
      .then<Map<String, Operation>?>((found) => {for (final operation in found) operation.uuid: operation})
      .catchError((Object error, StackTrace stack) {
        ErrorReportingService.report(error, stack, context: 'logs:unreadableOperations');
        return null;
      });
  Future<void> copy() async {
    // Said either way: a copy that failed quietly leaves them pasting nothing.
    try {
      await Clipboard.setData(ClipboardData(text: _unreadableQsosReport(rows, await operations)));
      messenger?.showSnackBar(haloSnackBar(t.copied));
    } catch (error, stack) {
      ErrorReportingService.report(error, stack, context: 'logs:unreadableCopy', told: true);
      messenger?.showSnackBar(haloSnackBar(t.notCopied));
    }
  }

  await showHaloDialog<void>(
    context: context,
    builder: (dialogContext) => HaloDialog(
      title: Text(t.title),
      content: FutureBuilder<Map<String, Operation>?>(
        future: operations,
        builder: (context, snapshot) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.intro),
              for (final row in rows) _UnreadableQsoEntry(row: row, operations: snapshot),
            ],
          ),
        ),
      ),
      tools: TextButton(onPressed: () => unawaited(copy()), child: Text(context.t.common.copyDetails)),
      cancel: TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(context.t.common.done)),
    ),
  );
}

class _UnreadableQsoEntry extends StatelessWidget {
  const _UnreadableQsoEntry({required this.row, required this.operations});

  final UnreadableQso row;

  /// The operations lookup: no line while it runs, and a failed one (null
  /// once done) says so rather than calling the operation missing.
  final AsyncSnapshot<Map<String, Operation>?> operations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t.home.logs.unreadable;
    final at = row.startAtMillis;
    final headline = [
      at == null ? context.t.home.logs.groupBy.unknownDate : _utcStamp(at),
      [row.ourCall, row.theirCall].whereType<String>().where((call) => call.isNotEmpty).join(' → '),
      [row.band, row.mode].whereType<String>().where((part) => part.isNotEmpty).join(' '),
    ].where((part) => part.isNotEmpty).join(' · ');
    final found = operations.data;
    final op = found?[row.operationUuid];
    return Padding(
      padding: const EdgeInsets.only(top: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headline, style: theme.textTheme.titleSmall),
          if (row.operationUuid.isEmpty)
            Text(context.t.home.logs.noOperation)
          else if (operations.connectionState == ConnectionState.done)
            Text(switch ((found, op)) {
              (null, _) => t.operationLookupFailed,
              (_, final op?) => t.operation(title: displayTitleFor(context, op)),
              _ => t.unknownOperation,
            }),
          Text(switch (row.problem) {
            UnreadableQsoProblem.notJson => t.notJson(detail: row.detail),
            UnreadableQsoProblem.notAnObject => t.notAnObject(detail: row.detail),
          }),
          const SizedBox(height: Space.sm),
          Text(t.storedData(count: formatNumber(row.data.length)), style: theme.textTheme.labelMedium),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Space.md),
            color: theme.colorScheme.surfaceContainerHighest,
            child: SelectableText(row.data, style: haloMonoStyle(context, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// How many damaged rows fall in a period, by the rule `_inPeriod` keeps
/// QSOs by: a bounded period leaves out a row with no start time.
int _unreadableIn(List<UnreadableQso> rows, ({int? start, int? end}) bounds) {
  final (:start, :end) = bounds;
  if (start == null && end == null) return rows.length;
  return rows.where((row) {
    final at = row.startAtMillis;
    return at != null && (start == null || at >= start) && (end == null || at < end);
  }).length;
}

String _utcStamp(int millis) => '${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true))}Z';

/// Everything a row still holds, in plain text for a support request: what
/// someone reconstructing the contact, or tracing what damaged it, would
/// otherwise have to ask for. Field names stay in English, like the version
/// details above them — whoever reads it is debugging, not operating.
String _unreadableQsosReport(List<UnreadableQso> rows, Map<String, Operation>? operations) {
  final out = StringBuffer()
    ..writeln(ham2kAppName)
    ..writeln(versionDetailsText())
    ..writeln()
    ..writeln('${rows.length} QSO${rows.length == 1 ? '' : 's'} in this log could not be read.');
  for (final (index, row) in rows.indexed) {
    final operation = operations?[row.operationUuid];
    final operationLine = switch ((row.operationUuid.isEmpty, operations, operation)) {
      (true, _, _) => '(none)',
      (_, null, _) => '${row.operationUuid} (lookup failed)',
      (_, _, null) => '${row.operationUuid} (not found on this device)',
      (_, _, final found?) => '${row.operationUuid} (${found.stationCall}, ${found.userTitle})',
    };
    String stamp(int? millis) => millis == null ? '(none)' : '${_utcStamp(millis)} ($millis)';
    out
      ..writeln()
      ..writeln('--- QSO ${index + 1} of ${rows.length}')
      ..writeln('uuid: ${row.uuid}')
      ..writeln('operation: $operationLine')
      ..writeln('problem: ${row.problem.name}: ${row.detail}')
      ..writeln('our call: ${row.ourCall ?? '(none)'}')
      ..writeln('their call: ${row.theirCall ?? '(none)'}')
      ..writeln('band: ${row.band ?? '(none)'}, mode: ${row.mode ?? '(none)'}')
      ..writeln('start: ${stamp(row.startAtMillis)}')
      ..writeln('updated: ${stamp(row.updatedAtMillis)}')
      ..writeln('synced: ${row.synced}, deleted: ${row.deleted}')
      ..writeln('data (${row.data.length} characters):')
      ..writeln(row.data);
  }
  return out.toString();
}

import '../repo/operations_repository.dart';
import '../repo/qsos_repository.dart';

/// Server-reported sync progress, for the app layer to surface (status bar,
/// Settings). The counts come from the sync response's per-side meta
/// (`records_left` / `total_records`) — the server includes them even in
/// cooldown-gated responses that carry no records, so progress stays fresh
/// between real pages. [backfilling] flips false on the round that
/// completes the backfill, so the surface can finish and dismiss itself.
class SyncProgress {
  final bool backfilling;
  final int? qsosTotal;
  final int? qsosLeft;
  final int? operationsTotal;
  final int? operationsLeft;

  const SyncProgress({
    required this.backfilling,
    this.qsosTotal,
    this.qsosLeft,
    this.operationsTotal,
    this.operationsLeft,
  });
}

/// Merges a page of QSOs in [sliceSize] slices, reporting [onProgress]
/// after each — a backfill page is thousands of rows and seconds of merge,
/// and the surface only otherwise moves once per page. The counts are the
/// server's for this response, with the unmerged rest of the page added
/// back, so the last slice lands on the same number the round's own report
/// then confirms. One transaction per slice, not per page: the cursor is
/// only written after the whole page lands, so a crash mid-page re-pulls
/// it, and the merge is an upsert. With no listener (or a forward-mode
/// page, which reports nothing) the page merges in one call as before.
///
/// [abandoned] is read between slices: a reconciliation that wipes the
/// tables while a page is landing (`forceFullResync`, an account `replace`)
/// must not have the rest of that page — the old account's rows, marked
/// synced — inserted into the freshly cleared tables after it. The round
/// checks the same condition after the merge and discards the response.
Future<SyncWatermark> mergeQsosReportingProgress(
  QsosRepository qsos,
  List<Map<String, dynamic>> inbound,
  Map<String, dynamic> response, {
  required int sliceSize,
  required void Function(SyncProgress progress)? onProgress,
  required bool Function() abandoned,
}) async {
  if (onProgress == null || inbound.length <= sliceSize) return qsos.mergeFromSync(inbound);
  final meta = (response['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
  final counts = serverCounts(meta);
  final watermark = SyncWatermark();
  for (var start = 0; start < inbound.length && !abandoned(); start += sliceSize) {
    final end = start + sliceSize < inbound.length ? start + sliceSize : inbound.length;
    final slice = await qsos.mergeFromSync(inbound.sublist(start, end));
    watermark
      ..include(slice.earliestSyncedAtMillis)
      ..include(slice.latestSyncedAtMillis);
    if (end < inbound.length && counts.qsosTotal != null) {
      onProgress(SyncProgress(
        backfilling: true,
        qsosTotal: counts.qsosTotal,
        qsosLeft: (counts.qsosLeft ?? 0) + inbound.length - end,
        operationsTotal: counts.operationsTotal,
        operationsLeft: counts.operationsLeft,
      ));
    }
  }
  return watermark;
}

/// The per-side `records_left`/`total_records` of a response meta, either
/// spelling — present on real pages and cooldown responses alike.
({int? qsosLeft, int? qsosTotal, int? operationsLeft, int? operationsTotal}) serverCounts(
  Map<String, dynamic> meta,
) {
  int? count(String side, String camel, String snake) {
    final sideMeta = meta[side] as Map?;
    return ((sideMeta?[camel] ?? sideMeta?[snake]) as num?)?.toInt();
  }

  return (
    qsosLeft: count('qsos', 'recordsLeft', 'records_left'),
    qsosTotal: count('qsos', 'totalRecords', 'total_records'),
    operationsLeft: count('operations', 'recordsLeft', 'records_left'),
    operationsTotal: count('operations', 'totalRecords', 'total_records'),
  );
}

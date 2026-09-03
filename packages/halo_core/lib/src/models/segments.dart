// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Segments — an operation is not one set of refs (docs/design/contests.md
// §5.1.3). A `break`/`start` event row may carry `event.operation`, and from
// that point on the log belongs to a different operation: a second park, a
// rover's new grid, a contest that has ended.
//
// Segments REPLACE rather than merge, and they DO NOT carry forward from one
// another. A segment states what is true for the stretch that follows; an
// attribute it doesn't name falls back to the BASE operation, never to the
// previous segment.
//
// The base operation exists so an unsegmented log needs no segments at all —
// it is the default, not a running accumulator. Anything a user wants carried
// across segments (a grid, a contest definition) is written into each segment
// by whatever creates them, because only the user knows that "I moved to a
// second park" is not "I am now at two parks".
//
// One map per SEGMENT, never per QSO. Overrides are rare — a handful in a
// 5000-QSO log — so this stays a short list and a binary search rather than
// 5000 copies of an operation.

import 'dart:convert';

import 'models.dart';

/// What a `start`/`break` row restates about the operation — polo's
/// `captureOperationParameters`, plus the location keys HaLo carries
/// (docs/design/locations.md: a grid without a coordinate must clear the
/// pair, so `lat`/`lon` travel with `grid`).
const segmentOverrideKeys = ['refs', 'grid', 'gridSource', 'lat', 'lon', 'state', 'county'];

/// The override a new segment row carries for [operationData]. Every key is
/// present, absent ones as explicit nulls: a segment is a complete statement
/// of what was true, and an omitted key would fall back to the base
/// operation — which is exactly what a stretch "with a grid but no exact
/// fix" must not do.
Map<String, dynamic> segmentOverrideOf(Map<String, dynamic> operationData) => {
      for (final key in segmentOverrideKeys) key: operationData[key],
    };

/// Whether an edit from [before] to [after] changes anything a segment
/// restates — the test for whether the latest segment has to follow it.
bool segmentOverrideDiffers(Map<String, dynamic> before, Map<String, dynamic> after) =>
    jsonEncode(segmentOverrideOf(before)) != jsonEncode(segmentOverrideOf(after));

/// Whether an event row of [kind] opens a segment. `stop` (polo's kind for
/// the operation's end; `end` in older rows) closes the operation, so any
/// override it carries is ignored here — treating a stop as a boundary would
/// strand every QSO logged after it with no refs at all.
bool eventKindOpensSegment(String? kind) => kind == 'break' || kind == 'start';

/// One stretch of a log, and the operation that was true for it.
class OperationSegment {
  /// When this segment takes over. The first segment starts at the dawn of
  /// time so that a QSO logged before any event row still resolves.
  final int fromMillis;

  /// The full operation data for this stretch — the base operation with this
  /// segment's override applied. Not the previous segment's: overrides do not
  /// accumulate.
  final Map<String, dynamic> operation;

  const OperationSegment({required this.fromMillis, required this.operation});

  List<Map<String, dynamic>> get refs =>
      ((operation['refs'] as List?) ?? const []).whereType<Map<String, dynamic>>().toList();

  Set<String> get refTypes => {
        for (final ref in refs)
          if (ref['type'] case final String type) type,
      };
}

/// An operation resolved into its segments.
///
/// Built once per scoring pass or export and then queried — [effectiveAt] is
/// the hot path, called once per QSO.
class SegmentedOperation {
  final List<OperationSegment> segments;

  const SegmentedOperation._(this.segments);

  /// Folds every `break`/`start` override in [qsos] over [operation].
  ///
  /// [qsos] need not be sorted; event rows are ordered by `startAtMillis`
  /// here, because the caller's list may exclude or reorder real QSOs and the
  /// segment boundaries have to be right regardless.
  factory SegmentedOperation.from({
    required Map<String, dynamic> operation,
    required List<Qso> qsos,
  }) {
    final overrides = [
      for (final qso in qsos)
        if (qso.isEvent && !qso.deleted && eventKindOpensSegment(qso.eventKind))
          if (qso.event?['operation'] case final Map<String, dynamic> override)
            (at: qso.startAtMillis ?? 0, override: override),
    ]..sort((a, b) => a.at.compareTo(b.at));

    // The base operation covers everything before the first override — and the
    // whole log when there are none, which is the overwhelmingly common case.
    final segments = <OperationSegment>[
      OperationSegment(fromMillis: -1 << 62, operation: operation),
    ];
    for (final entry in overrides) {
      segments.add(OperationSegment(
        fromMillis: entry.at,
        // Over the BASE, not the previous segment. Each segment is an
        // independent statement of what was true; a grid set in segment one
        // does not leak into segment two just because two didn't mention it.
        operation: {...operation, ...entry.override},
      ));
    }
    return SegmentedOperation._(segments);
  }

  /// Whether this operation has any segment overrides at all. Callers use it
  /// to skip segment-aware work entirely on the common single-segment log.
  bool get isSegmented => segments.length > 1;

  /// The operation as it stood at [startAtMillis].
  Map<String, dynamic> effectiveAt(int? startAtMillis) {
    if (segments.length == 1 || startAtMillis == null) return segments.first.operation;

    // Rightmost segment whose boundary is at or before this instant. A QSO
    // sharing a timestamp with the event row that opens a segment belongs to
    // the NEW segment: the break is logged when the operator stops, so
    // anything at that instant is on the far side of it.
    var low = 0;
    var high = segments.length - 1;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (segments[mid].fromMillis <= startAtMillis) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return segments[low].operation;
  }

  /// The operation as it stands now — the last segment. What the logging panel
  /// gates its primary fields on, so a contest that ended at a break stops
  /// claiming the entry row.
  Map<String, dynamic> get current => segments.last.operation;

  /// The wire shape the scoring harness reads (`OperationSegmentPayload[]`).
  ///
  /// Worth sending only when [isSegmented] — the harness treats a single
  /// segment as no timeline at all, so a one-entry list is pure payload.
  List<Map<String, dynamic>> get payload => [
        for (final segment in segments) {'fromMillis': segment.fromMillis, 'operation': segment.operation},
      ];

  /// Every ref type on the base operation or any segment.
  ///
  /// Scorer selection uses this: a contest that only covers the back half of a
  /// log must still be invoked, and a scorer selected from the base operation
  /// alone never would be.
  Set<String> get allRefTypes => {
        for (final segment in segments) ...segment.refTypes,
      };

  /// Every reference carried by any segment — one export is offered per
  /// entry, since an activity that supports multiple references produces a
  /// separate submission for each (§5.1.4).
  ///
  /// Deduped on `(type, ref)`: the same park across three segments is one
  /// export, not three.
  List<Map<String, dynamic>> get allRefs {
    final byIdentity = <String, Map<String, dynamic>>{};
    for (final segment in segments) {
      for (final ref in segment.refs) {
        byIdentity.putIfAbsent('${ref['type']}\u0000${ref['ref']}', () => ref);
      }
    }
    return byIdentity.values.toList();
  }

  /// The QSOs belonging to segments carrying [ref] — an export's default view.
  ///
  /// Matched on the REFERENCE, not its type: an operation that visited two
  /// parks yields two POTA exports, and each must contain only its own park's
  /// QSOs. Claiming contacts made at the other park, or in a stretch at
  /// neither, is a bad submission.
  List<Qso> qsosFor(List<Qso> qsos, Map<String, dynamic> ref) {
    final identity = '${ref['type']}\u0000${ref['ref']}';
    return [
      for (final qso in qsos)
        if (_refIdentitiesAt(qso.startAtMillis).contains(identity)) qso,
    ];
  }

  Set<String> _refIdentitiesAt(int? startAtMillis) => {
        for (final ref in ((effectiveAt(startAtMillis)['refs'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>())
          '${ref['type']}\u0000${ref['ref']}',
      };
}

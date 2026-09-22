// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// Which operation was true for a given contact, on a log the operator changed
// under themselves — a rover's county, a station's call, a contest that ended
// at a `break` (docs/design/contests.md §5.1.3).
//
// The host resolves the segments once (`SegmentedOperation`) and sends them
// as `OperationSegmentPayload[]` on `ScoreQsosRequest` and `ExportRequest`;
// the scoring harness walks them with the fold, and this is the same answer
// for anything that is handed one QSO at a time.

import type { JSONValue, OperationSegmentPayload } from "./types.ts"

/// The segment-effective operation for [qso]: the last segment that had begun
/// by the contact's `startAtMillis`, or [base] on an unsegmented log (or for a
/// contact with no time, which the fold also reads as the epoch).
///
/// A QSO at exactly a segment's `fromMillis` belongs to that segment — the
/// same rule `SegmentedOperation.effectiveAt` applies on the host, so an
/// export and a rescore never disagree about a contact on a boundary.
export function operationForQso(
  base: Record<string, JSONValue>,
  qso: Record<string, JSONValue>,
  segments?: OperationSegmentPayload[],
): Record<string, JSONValue> {
  if (!segments || segments.length === 0) return base
  const at = typeof qso.startAtMillis === "number" ? qso.startAtMillis : 0
  let effective = base
  for (const segment of segments) {
    if (segment.fromMillis > at) break
    effective = segment.operation
  }
  return effective
}

/// [segments] with [transform] applied to every segment's operation — for an
/// export that reshapes the operation it hands the ADIF generator (filtering
/// the refs down to the one reference this file claims, marking a ref with
/// what the per-QSO hook needs) and has to reshape every segment the same
/// way, or the generator hands the hook the UNSHAPED segment operation for
/// every contact of a segmented log. Undefined in, undefined out.
export function segmentsWith(
  segments: OperationSegmentPayload[] | undefined,
  transform: (operation: Record<string, JSONValue>) => Record<string, JSONValue>,
): OperationSegmentPayload[] | undefined {
  return segments?.map((segment) => ({ ...segment, operation: transform(segment.operation) }))
}

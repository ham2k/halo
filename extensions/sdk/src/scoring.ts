// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The scoring harness: turns a `ContestScorer` (three pure functions) into the
// `ScoringHook` the kernel registers and the host invokes.
//
// Why a harness at all: batch scoring, incremental rescoring and live
// single-QSO scoring are the same primitive — *score one more QSO against the
// running scoresheet*. An append folds from the cached end-scoresheet, a
// mid-log edit folds forward from the nearest checkpoint, and the live
// candidate is folded and thrown away. Writing that once here is the whole
// point: otherwise all twelve contests re-derive checkpointing and the
// "don't score the record being edited against itself" rules, and get them
// subtly wrong (see docs/design/contests.md §5.2).
//
// The per-QSO loop runs HERE, inside the runtime, in one coarse bridge call —
// DESIGN.md §4's "score 500 QSOs in one call, not 500 calls". A per-QSO
// `scoreQso` method does not mean a per-QSO bridge crossing.
//
// Types come in by relative path, not the `@ham2k/halo-extension-sdk` alias, so
// this module's tests can run under plain `node --test` (which can't resolve
// that tsc/esbuild-only bare specifier) — the same constraint dxcc.ts documents.

import type {
  ContestScorer,
  DayScoreSummary,
  HookContext,
  JSONValue,
  OperationSegmentPayload,
  QsoScoreNotices,
  QsoScoreVerdict,
  ScoreQsoRequest,
  ScoreQsosRequest,
  ScoreQsosResult,
  ScoreTally,
  Scoresheet,
  ScoringHook,
  ScoringScope,
} from "./types.ts"

const DAY_IN_MILLIS = 1000 * 60 * 60 * 24

/// Scorers are allowed to mutate the scoresheet they're handed (see
/// `ContestScorer.scoreQso`) — copying accumulated state per QSO is quadratic.
/// So the harness takes exactly one copy of any checkpoint it's given, at the
/// boundary, and a scorer can never corrupt a cached scoresheet through it.
/// One O(state) copy per call keeps the fold O(N) overall.
function copyCheckpoint<S extends Scoresheet>(sheet: S): S {
  return JSON.parse(JSON.stringify(sheet)) as S
}

/// UTC calendar day a QSO falls in, following app-polo/web-lofi's convention.
function dayOf(qso: Record<string, JSONValue>): number {
  const millis = Number(qso.startAtMillis ?? 0)
  return millis - (millis % DAY_IN_MILLIS)
}

function chronological(qsos: Record<string, JSONValue>[]): Record<string, JSONValue>[] {
  return [...qsos].sort((a, b) => Number(a.startAtMillis ?? 0) - Number(b.startAtMillis ?? 0))
}

/// Event rows (`band == 'event'`) mark breaks/starts rather than contacts, so
/// they never score. Once segments land they'll also carry the operation
/// overrides the harness applies — see docs/design/contests.md §5.1.
function isEvent(qso: Record<string, JSONValue>): boolean {
  return qso.band === 'event'
}

export interface ContestScorerOptions {
  /// Which operations this scorer applies to. Read by the host *before*
  /// invoking, so an operation with no matching ref never crosses the bridge.
  /// Exposed as a plain data member on the hook, the same way `spots` hooks
  /// expose `sourceName`.
  scope?: ScoringScope
}

/// Wraps a `ContestScorer` into a registrable `ScoringHook`.
///
/// ```ts
/// registerHook('scoring', {
///   hook: contestScorer(SimpleContestScorer, { scope: { refTypes: ['simple-contest'] } }),
///   key: 'simple-contest',
/// })
/// ```
/// A QSO's timestamp, or 0 — a QSO with no time falls into the first segment,
/// which is the base operation and the safest place for it.
function startAtMillisOf(qso: Record<string, JSONValue>): number {
  const at = qso.startAtMillis
  return typeof at === 'number' ? at : 0
}

export function contestScorer<S extends Scoresheet = Scoresheet>(
  scorer: ContestScorer<S>,
  options: ContestScorerOptions = {},
): ScoringHook & { scope: ScoringScope } {
  const scope: ScoringScope = options.scope ?? 'always'
  const scopedRefTypes = typeof scope === 'object' && Array.isArray(scope.refTypes) ? scope.refTypes : undefined

  /// This scorer's own ref on a segment-effective operation, if it has one. A
  /// contest set up once and left running resolves the same object every time;
  /// a segment that restates it wins for that stretch. Undefined means the
  /// activity was not running then — segments replace rather than merge, so a
  /// segment naming other refs has genuinely dropped this one.
  function refOfScopedType(operation: Record<string, JSONValue>): Record<string, JSONValue> | undefined {
    if (!scopedRefTypes) return undefined
    const refs = (operation.refs as Record<string, JSONValue>[] | undefined) ?? []
    return refs.find((r) => typeof r?.type === 'string' && scopedRefTypes.includes(r.type as string))
  }

  /// Folds `qsos` into `scoresheet`, reporting each QSO's verdict and taking a
  /// day summary at every boundary. Shared by the batch pass and by the live
  /// path's rebuild-from-log fallback.
  function fold(
    scoresheet: S,
    qsos: Record<string, JSONValue>[],
    args: { operation: Record<string, JSONValue>; ref?: Record<string, JSONValue> },
    ctx: HookContext,
    onQso?: (uuid: string | undefined, score: QsoScoreVerdict) => void,
    onDayEnd?: (day: number, count: number, sheet: S) => void,
    segments?: OperationSegmentPayload[],
  ): S {
    let sheet = scoresheet
    let currentDay: number | undefined
    let dayCount = 0
    // Segments advance WITH the fold rather than being searched per QSO — the
    // loop is already chronological, so this is a pointer, not a lookup.
    const timeline = segments && segments.length > 1 ? segments : undefined
    let segmentIndex = 0

    for (const qso of qsos) {
      if (isEvent(qso)) continue

      let operation = args.operation
      let ref = args.ref
      if (timeline) {
        const at = startAtMillisOf(qso)
        while (segmentIndex + 1 < timeline.length && timeline[segmentIndex + 1].fromMillis <= at) segmentIndex += 1
        operation = timeline[segmentIndex].operation
        if (scopedRefTypes) {
          // A segment states what was true for its stretch, and one that carries
          // no ref of our types says this activity was not running — so the QSO
          // is not ours to score at all. Selection spans every segment, so a
          // contest confined to the back half of a log is invoked for the whole
          // of it; without this it would claim the front half too. It does not
          // even count toward the day tally: it is somebody else's contact.
          const segmentRef = refOfScopedType(operation)
          if (!segmentRef) continue
          ref = segmentRef
        }
      }

      const day = dayOf(qso)
      const isNewDay = currentDay !== day
      if (isNewDay) {
        // Summarize the day just ended BEFORE this QSO mutates the sheet.
        if (currentDay !== undefined) onDayEnd?.(currentDay, dayCount, sheet)
        currentDay = day
        dayCount = 0
      }
      dayCount += 1

      const result = scorer.scoreQso({ scoresheet: sheet, qso, operation, ref, isNewDay }, ctx)
      sheet = result.scoresheet
      onQso?.(typeof qso.uuid === 'string' ? qso.uuid : undefined, result.score)
    }
    if (currentDay !== undefined) onDayEnd?.(currentDay, dayCount, sheet)
    return sheet
  }

  return {
    scope,

    async scoreQsos(args: ScoreQsosRequest, ctx: HookContext): Promise<ScoreQsosResult> {
      const qsos = chronological(args.qsos)
      // `resumeFrom` means `qsos` is only the tail to replay from a checkpoint;
      // without one this is a full pass from a blank scoresheet.
      const start = args.resumeFrom !== undefined
        ? copyCheckpoint(args.resumeFrom as S)
        : scorer.startScoresheet({ operation: args.operation, ref: args.ref }, ctx)

      const qsoScores: Record<string, QsoScoreVerdict> = {}
      const daySections: DayScoreSummary[] = []

      const end = fold(
        start,
        qsos,
        args,
        ctx,
        (uuid, score) => {
          if (uuid) qsoScores[uuid] = score
        },
        (day, count, sheet) => {
          daySections.push({
            day,
            count,
            scores: scorer.summarizeScore({ scoresheet: sheet, operation: args.operation, ref: args.ref, scope: 'day' }, ctx),
          })
        },
        args.segments,
      )

      return {
        qsoScores,
        daySections,
        operationSummary: scorer.summarizeScore(
          { scoresheet: end, operation: args.operation, ref: args.ref, scope: 'operation' },
          ctx,
        ),
        scoresheet: end as JSONValue,
      }
    },

    /// Live path: score the candidate against the log so far and report only
    /// its notices/alerts. Nothing is recorded — the resulting scoresheet is
    /// discarded, which is exactly why one `scoreQso` can serve both paths.
    async scoreQso(args: ScoreQsoRequest, ctx: HookContext): Promise<QsoScoreNotices> {
      let sheet: S
      if (args.resumeFrom !== undefined) {
        // The cached end-of-log scoresheet — no whole-log read, which is the
        // point: this runs on every debounced keystroke. Copied because the
        // candidate is scored against it and then thrown away; the cache must
        // survive unchanged.
        sheet = copyCheckpoint(args.resumeFrom as S)
      } else {
        // Cold cache: rebuild from the log, skipping the record being edited so
        // it can't flag itself as its own duplicate.
        const uuid = typeof args.operation.uuid === 'string' ? args.operation.uuid : undefined
        const log = uuid ? ((await ctx.getQsos?.(uuid)) ?? []) : []
        const rest = chronological(log as Record<string, JSONValue>[]).filter(
          (q) => !args.excludeUuid || q.uuid !== args.excludeUuid,
        )
        // Segmented exactly as the batch pass folds it, so the candidate is
        // judged against the same history the score summary counted — without
        // this a contest that started mid-log would call a pre-contest contact
        // a duplicate.
        sheet = fold(
          scorer.startScoresheet({ operation: args.operation, ref: args.ref }, ctx),
          rest,
          args,
          ctx,
          undefined,
          undefined,
          args.segments,
        )
      }

      const { score } = scorer.scoreQso(
        { scoresheet: sheet, qso: args.qso, operation: args.operation, ref: args.ref, isNewDay: false },
        ctx,
      )
      return { notices: score.notices ?? [], alerts: score.alerts ?? [] }
    },
  }
}

/// Convenience for scorers building tallies — keeps the required fields
/// consistent without every contest repeating the literal.
export function tally(key: string, forScope: 'day' | 'operation', total: number, extra: Partial<ScoreTally> = {}): ScoreTally {
  return { key, for: forScope, total, ...extra }
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
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
// Types come in by relative path, not the `@ham2k/extension-sdk` alias, so
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
  ScoreCandidatesRequest,
  ScoreCandidatesResult,
  ScoreQsoRequest,
  ScoreQsosRequest,
  ScoreQsosResult,
  ScoreTally,
  Scoresheet,
  ScoringHook,
  ScoringScope,
} from "./types.ts"
import { copyOnWrite } from "./copyOnWrite.ts"

const DAY_IN_MILLIS = 1000 * 60 * 60 * 24

/// How many operations' checkpoints one scorer keeps. The app has one
/// operation open, the spots board and the logging panel ask about that one,
/// and a checkpoint is the size of the log's worked-call map — so a few, not
/// a history.
const HELD_CHECKPOINTS = 4

/// The error a live call gets when it names a checkpoint this runtime does not
/// hold — a restart, or one more operation than it keeps. The host answers by
/// sending the checkpoint itself; nothing else should ever read it.
export const RESUME_MISSING = "resume-missing"

/// The entry a `scoreCandidates` answer carries beside its candidates to say
/// the named checkpoint is held — the result is keyed by the caller's
/// candidate keys, so the flag rides under a key no caller uses. Its value is
/// `true`, never a verdict, and a host reading verdicts skips it.
export const CHECKPOINT_HELD_KEY = "$checkpointHeld"

/// Scorers are allowed to mutate the scoresheet they're handed (see
/// `ContestScorer.scoreQso`) — copying accumulated state per QSO is quadratic.
/// So the batch pass takes exactly one copy of the checkpoint it resumes from,
/// at the boundary, and a scorer can never corrupt a held checkpoint through
/// it. One O(state) copy per pass keeps the fold O(N) overall. The live paths
/// take no copy at all: they score against a copy-on-write view of the held
/// sheet (`copyOnWrite`), which a scorer may mutate just the same.
function copySheet<S extends Scoresheet>(sheet: S): S {
  return JSON.parse(JSON.stringify(sheet)) as S
}

/// A checkpoint the harness holds: an end-of-log sheet with the day it ends
/// on (`resumeDay`). The day has to travel with the sheet because the fold
/// cannot recover it: without it, the first contact replayed onto a checkpoint
/// reads as a new day whatever the time, and an activity that resets its
/// per-day worked maps on that flag then forgets every contact worked today.
type Checkpoint<S> = { key: string; sheet: S; day: number | undefined }

function operationUuidOf(operation: Record<string, JSONValue>): string {
  return typeof operation.uuid === "string" ? operation.uuid : ""
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
  return qso.band === "event"
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
  return typeof at === "number" ? at : 0
}

/// A not-yet-logged candidate judged as of NOW when it carries no time of its
/// own. The logging panel's draft omits `startAtMillis` while its time is
/// automatic, and a scorer that buckets by day would read the absence as the
/// epoch — a station worked earlier today then reads as `newDay` rather than
/// a duplicate. A candidate that states a time (a manual override, a QSO being
/// edited, a spot the panel stamped) keeps it. `Date` in the sandbox follows
/// the app clock, so this travels with `DEVTT`.
function candidateAsOfNow(qso: Record<string, JSONValue>): Record<string, JSONValue> {
  return typeof qso.startAtMillis === "number" ? qso : { ...qso, startAtMillis: Date.now() }
}

export function contestScorer<S extends Scoresheet = Scoresheet>(
  scorer: ContestScorer<S>,
  options: ContestScorerOptions = {},
): ScoringHook & { scope: ScoringScope } {
  const scope: ScoringScope = options.scope ?? "always"
  const scopedRefTypes = typeof scope === "object" && Array.isArray(scope.refTypes) ? scope.refTypes : undefined

  /// The checkpoints this runtime holds, one per operation, most recent last.
  /// A batch pass files its end sheet under the `checkpointKey` the host gave
  /// it, and a `resumeFrom` that arrives with a `resumeKey` is filed the same
  /// way — after which a live call names the checkpoint instead of shipping
  /// it, which on a long log is most of the call. A held sheet is never
  /// mutated: the batch pass copies it and the live paths view it.
  const held = new Map<string, Checkpoint<S>>()

  function hold(operationUuid: string, key: string, sheet: S, day: number | undefined): void {
    held.delete(operationUuid)
    held.set(operationUuid, { key, sheet, day })
    while (held.size > HELD_CHECKPOINTS) held.delete(held.keys().next().value as string)
  }

  /// The checkpoint a request resumes from, or undefined for a cold fold. A
  /// sheet that arrives is what it says; one that is only named must be
  /// here, and a name this runtime does not know is an error the host is
  /// built to answer — never a silent cold fold, which on every keystroke
  /// would be exactly the cost the name exists to avoid.
  function resolveCheckpoint(args: {
    operation: Record<string, JSONValue>
    resumeFrom?: JSONValue
    resumeDay?: number
    resumeKey?: string
  }): Checkpoint<S> | undefined {
    const operationUuid = operationUuidOf(args.operation)
    const key = typeof args.resumeKey === "string" ? args.resumeKey : undefined
    if (args.resumeFrom !== undefined) {
      const day = typeof args.resumeDay === "number" ? args.resumeDay : undefined
      const sheet = args.resumeFrom as S
      if (key !== undefined) hold(operationUuid, key, sheet, day)
      return { key: key ?? "", sheet, day }
    }
    if (key === undefined) return undefined
    const entry = held.get(operationUuid)
    if (entry === undefined || entry.key !== key) throw new Error(`${RESUME_MISSING}: ${key}`)
    return entry
  }

  /// This scorer's own ref on a segment-effective operation, if it has one. A
  /// contest set up once and left running resolves the same object every time;
  /// a segment that restates it wins for that stretch. Undefined means the
  /// activity was not running then — segments replace rather than merge, so a
  /// segment naming other refs has genuinely dropped this one.
  function refOfScopedType(operation: Record<string, JSONValue>): Record<string, JSONValue> | undefined {
    if (!scopedRefTypes) return undefined
    const refs = (operation.refs as Record<string, JSONValue>[] | undefined) ?? []
    return refs.find((r) => typeof r?.type === "string" && scopedRefTypes.includes(r.type as string))
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
    startDay?: number,
  ): { sheet: S; day: number | undefined } {
    let sheet = scoresheet
    // The day the checkpoint ended on, when resuming: a tail that continues it
    // must not open with `isNewDay`.
    let currentDay: number | undefined = startDay
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
      onQso?.(typeof qso.uuid === "string" ? qso.uuid : undefined, result.score)
    }
    if (currentDay !== undefined) onDayEnd?.(currentDay, dayCount, sheet)
    return { sheet, day: currentDay }
  }

  /// The log folded up to now, ready for a not-yet-logged candidate to be
  /// scored against and thrown away. Shared by both live paths.
  ///
  /// The returned sheet is always the harness's own — never the caller's
  /// cached checkpoint — so a scorer mutating it can't corrupt the cache.
  /// `day` is the day the sheet ends on, or undefined when nothing says (an
  /// empty log, a checkpoint with no day). The live verdicts never read it —
  /// `isNewDay` only ever moves a scorer's per-day tallies, which the live
  /// paths discard — but a replayed tail must not open a day mid-day.
  async function liveScoresheet(
    args: {
      operation: Record<string, JSONValue>
      ref?: Record<string, JSONValue>
      segments?: OperationSegmentPayload[]
      resumeFrom?: JSONValue
      resumeDay?: number
      qsos?: Record<string, JSONValue>[]
    },
    ctx: HookContext,
    excludeUuid?: string,
  ): Promise<{ sheet: S; day: number | undefined }> {
    const resumed = resolveCheckpoint(args)
    if (resumed !== undefined) {
      // The held end-of-log checkpoint — no whole-log read and no copy, which
      // is the point: this runs on every debounced keystroke. The view takes
      // the scorer's writes; `qsos` is the tail logged since the checkpoint,
      // replayed onto it. The host sends only contacts the checkpoint has not
      // folded (it has no way to un-fold one), so an edit or a delete arrives
      // as no checkpoint at all.
      const sheet = copyOnWrite(resumed.sheet)
      const tail = chronological(args.qsos ?? []).filter((q) => !excludeUuid || q.uuid !== excludeUuid)
      if (tail.length === 0) return { sheet, day: resumed.day }
      return fold(sheet, tail, args, ctx, undefined, undefined, args.segments, resumed.day)
    }
    // Cold cache: rebuild from the log, skipping the record being edited so
    // it can't flag itself as its own duplicate.
    const uuid = typeof args.operation.uuid === "string" ? args.operation.uuid : undefined
    const log = uuid ? ((await ctx.getQsos?.(uuid)) ?? []) : []
    const rest = chronological(log as Record<string, JSONValue>[]).filter((q) => !excludeUuid || q.uuid !== excludeUuid)
    // Segmented exactly as the batch pass folds it, so the candidate is
    // judged against the same history the score summary counted — without
    // this a contest that started mid-log would call a pre-contest contact
    // a duplicate.
    return fold(scorer.startScoresheet({ operation: args.operation, ref: args.ref }, ctx), rest, args, ctx, undefined, undefined, args.segments)
  }

  return {
    scope,

    async scoreQsos(args: ScoreQsosRequest, ctx: HookContext): Promise<ScoreQsosResult> {
      const qsos = chronological(args.qsos)
      // A checkpoint means `qsos` is only the tail to replay onto a COPY of
      // it — this fold mutates, and the held sheet must survive; without one
      // this is a full pass from a blank scoresheet.
      const resumed = resolveCheckpoint(args)
      const start = resumed !== undefined ? copySheet(resumed.sheet) : scorer.startScoresheet({ operation: args.operation, ref: args.ref }, ctx)

      const qsoScores: Record<string, QsoScoreVerdict> = {}
      const daySections: DayScoreSummary[] = []

      const { sheet: end, day: endDay } = fold(
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
            scores: scorer.summarizeScore({ scoresheet: sheet, operation: args.operation, ref: args.ref, scope: "day" }, ctx),
          })
        },
        args.segments,
        resumed?.day,
      )

      // The end sheet, held under the host's name for it: the next live call
      // can then name it rather than send it back. Held as is — nothing here
      // touches it again, and the host gets its own serialized copy.
      const checkpointHeld = typeof args.checkpointKey === "string"
      if (checkpointHeld) hold(operationUuidOf(args.operation), args.checkpointKey as string, end, endDay)

      return {
        qsoScores,
        daySections,
        operationSummary: scorer.summarizeScore({ scoresheet: end, operation: args.operation, ref: args.ref, scope: "operation" }, ctx),
        scoresheet: end as JSONValue,
        ...(endDay !== undefined && { scoresheetDay: endDay }),
        ...(checkpointHeld && { checkpointHeld: true }),
      }
    },

    /// Live path: score the candidate against the log so far and report only
    /// its notices/alerts. Nothing is recorded — the resulting scoresheet is
    /// discarded, which is exactly why one `scoreQso` can serve both paths.
    async scoreQso(args: ScoreQsoRequest, ctx: HookContext): Promise<QsoScoreNotices> {
      const { sheet } = await liveScoresheet(args, ctx, args.excludeUuid)
      const { score } = scorer.scoreQso({ scoresheet: sheet, qso: candidateAsOfNow(args.qso), operation: args.operation, ref: args.ref, isNewDay: false }, ctx)
      // `dupe` travels with them: it is how a scorer says its duplicate test
      // ran at all, which is what the host's priority merge reads (§5.1).
      // Dropping it here left the live paths judging on notices alone, so a
      // scorer's silence and its considered "not a duplicate" looked the same.
      // `checkpointHeld` tells the host the checkpoint it named (or sent with
      // a name) is here to be named next time — a harness without this cache
      // never says so, and the host keeps sending the sheet to it.
      const checkpointHeld = typeof args.resumeKey === "string"
      return {
        notices: score.notices ?? [],
        alerts: score.alerts ?? [],
        ...(score.dupe !== undefined && { dupe: score.dupe }),
        ...(checkpointHeld && { checkpointHeld: true }),
      }
    },

    /// The same live judgement as `scoreQso`, for many candidates at once —
    /// the Spots Panel annotating every spot on screen. The log is folded ONCE
    /// and each candidate scored against its own view of the result, so a
    /// candidate can neither see nor become a duplicate of another (both spots
    /// for the same unworked call read as unworked, which is what an operator
    /// scanning a band expects).
    ///
    /// The view is per candidate rather than per call because
    /// `ContestScorer.scoreQso` may mutate the scoresheet it is handed — the
    /// contract that makes the batch fold linear. Without it the first
    /// candidate's call would count as worked for every candidate after it. A
    /// view, not a copy: copying a long log's worked-call map forty times over
    /// was the cost of the whole pass.
    async scoreCandidates(args: ScoreCandidatesRequest, ctx: HookContext): Promise<ScoreCandidatesResult> {
      const { sheet: base } = await liveScoresheet(args, ctx)
      const result: ScoreCandidatesResult = {}
      if (typeof args.resumeKey === "string") result[CHECKPOINT_HELD_KEY as "$checkpointHeld"] = true
      for (const candidate of args.candidates) {
        const { score } = scorer.scoreQso(
          {
            scoresheet: copyOnWrite(base),
            qso: candidateAsOfNow(candidate.qso),
            operation: args.operation,
            ref: args.ref,
            isNewDay: false,
          },
          ctx,
        )
        result[candidate.key] = {
          notices: score.notices ?? [],
          alerts: score.alerts ?? [],
          ...(score.dupe !== undefined && { dupe: score.dupe }),
        }
      }
      return result
    },
  }
}

/// Convenience for scorers building tallies — keeps the required fields
/// consistent without every contest repeating the literal.
export function tally(key: string, forScope: "day" | "operation", total: number, extra: Partial<ScoreTally> = {}): ScoreTally {
  return { key, for: forScope, total, ...extra }
}

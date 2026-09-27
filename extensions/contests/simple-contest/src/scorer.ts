// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The simple-contest scorer: one point per contact, a contact being a dupe
// when the same callsign was already worked on the same band AND mode. Ported
// from app-polo's SimpleContestExtension `scoringForQSO`, but expressed as a
// `ContestScorer` — three pure functions the core drives (docs/design/contests.md
// §5.2), so batch scoring, incremental rescoring and the live in-progress QSO
// all come from the same `scoreQso`.
//
// The rule decomposition is deliberately private to the scoresheet: contests
// don't share a rule vocabulary, so only notices, alerts and points cross the
// boundary.
//
// Only *types* come from the SDK here (erased at runtime by
// --experimental-strip-types), so this module's tests run under plain
// `node --test` without resolving the tsc/esbuild-only package alias.

import type { ContestScorer, HookContext, JSONValue, QsoScoreVerdict } from "@ham2k/extension-sdk"
import { contestArithmetic, contestSummary } from "../../../sdk/src/contestSummary.ts"

import { tFor } from "./i18n.ts"

/// What the scorer accumulates while working through the log. A type alias
/// rather than an interface so it stays assignable to `Scoresheet` (JSONValue),
/// and every field is JSON — the core snapshots this as a checkpoint.
export type SimpleContestScoresheet = {
  /// call → the "band|mode" combinations already worked with it.
  worked: Record<string, string[]>
  qsos: number
  points: number
}

function str(value: JSONValue | undefined): string {
  return typeof value === "string" ? value : ""
}

function bandModeKey(qso: Record<string, JSONValue>): string {
  return `${str(qso.band)}|${str(qso.mode)}`
}

export const SimpleContestScorer: ContestScorer<SimpleContestScoresheet> = {
  startScoresheet(): SimpleContestScoresheet {
    return { worked: {}, qsos: 0, points: 0 }
  },

  // Mutates and returns the given scoresheet — see CoreScorer's note and
  // ContestScorer.scoreQso: per-QSO copying of accumulated state is quadratic,
  // and the harness copies any resume checkpoint at its boundary.
  scoreQso({ scoresheet, qso }) {
    const their = (qso.their as Record<string, JSONValue>) ?? {}
    const call = str(their.call)

    // Worked-call state is never reset: a dupe is a dupe across the whole
    // contest, whatever the day.
    const base = scoresheet

    if (!call) return { scoresheet: base, score: { value: 0 } }

    const key = bandModeKey(qso)
    const seen = base.worked[call] ?? []
    const isDupe = seen.includes(key)

    let score: QsoScoreVerdict
    if (isDupe) {
      score = { value: 0, dupe: true, alerts: ["duplicate"] }
    } else {
      // Worked before, but on a different band or mode — worth flagging, the
      // same notices app-polo raises.
      const notices: string[] = []
      if (seen.length > 0) {
        const band = str(qso.band)
        const mode = str(qso.mode)
        if (!seen.some((combo) => combo.endsWith(`|${mode}`))) notices.push("newMode")
        if (!seen.some((combo) => combo.startsWith(`${band}|`))) notices.push("newBand")
      }
      score = notices.length > 0 ? { value: 1, notices } : { value: 1 }
    }

    const points = score.value
    if (!isDupe) {
      if (seen.length > 0) seen.push(key)
      else base.worked[call] = [key]
    }
    base.qsos += 1
    base.points += points

    return { scoresheet: base, score }
  },

  summarizeScore({ scoresheet, ref, scope }, ctx) {
    return contestSummary(
      {
        key: "contest",
        scope,
        icon: "flag-checkered",
        title: contestTitle(ref, ctx),
        total: scoresheet.points,
        // One point a contact and no multipliers: the count of contacts IS the
        // arithmetic.
        arithmetic: contestArithmetic({ qsos: scoresheet.qsos }, ctx),
        extra: { count: scoresheet.qsos },
      },
      ctx,
    )
  },
}

/// The contest identifier the operator set up — the name the operation's
/// title gives the contest, which its summary repeats.
export function contestTitle(ref: Record<string, JSONValue> | undefined, ctx: HookContext): string {
  return str(ref?.contestIdentifier) || tFor(ctx)("defaultContestId")
}

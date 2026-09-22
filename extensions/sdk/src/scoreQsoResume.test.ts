// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// Resuming from a checkpoint. What these tests pin down is the two ways a
// resume can quietly lie: a tail that is accepted but not folded (the contact
// just logged is then "not a duplicate"), and a resumed fold that opens with
// `isNewDay` mid-day (every scorer resets its per-day tallies on that flag, so
// a day's count would restart at the tail).

import { test } from "node:test"
import assert from "node:assert/strict"

import { activityScorer } from "./activityScoring.ts"
import { contestScorer } from "./scoring.ts"
import type { HookContext, JSONValue } from "./types.ts"

const DAY = 1000 * 60 * 60 * 24
const DAY_1 = Date.UTC(2026, 6, 1)

const POTA = {
  label: "POTA",
  activationType: "potaActivation",
  huntingType: "pota",
  qsosToActivate: 10,
  allowsMultipleReferences: true,
  uniquePer: ["band", "mode", "day", "ref"] as const,
  activates: "daily" as const,
}

const ref: Record<string, JSONValue> = { type: "potaActivation", ref: "US-0001" }
const operation: Record<string, JSONValue> = { uuid: "op-1", refs: [ref] }

function qso(call: string, at: number, band = "20m"): Record<string, JSONValue> {
  return { uuid: `${call}-${at}-${band}`, their: { call }, band, mode: "SSB", startAtMillis: at }
}

/// A log the host can read back — the cold path — and the hook under test.
function hookOver(log: Record<string, JSONValue>[]) {
  const ctx: HookContext = { online: false, getQsos: async () => log }
  const hook = contestScorer(activityScorer(POTA), { scope: { refTypes: ["potaActivation", "pota"] } })
  return { hook, ctx }
}

test("a tail replayed onto the checkpoint makes its contact a duplicate", async () => {
  const { hook, ctx } = hookOver([])
  const folded = await hook.scoreQsos({ operation, ref, qsos: [qso("W1AAA", DAY_1)] }, ctx)
  const tail = [qso("W2BBB", DAY_1 + 3600_000)]
  const resume = { operation, ref, resumeFrom: folded.scoresheet!, resumeDay: folded.scoresheetDay }

  // The checkpoint alone knows nothing of W2BBB — this is the lie a resume
  // without the tail would tell, and the reason the tail exists.
  const without = await hook.scoreQso!({ ...resume, qso: qso("W2BBB", DAY_1 + 7200_000) }, ctx)
  assert.deepEqual(without.alerts, [])

  const withTail = await hook.scoreQso!({ ...resume, qsos: tail, qso: qso("W2BBB", DAY_1 + 7200_000) }, ctx)
  assert.deepEqual(withTail.alerts, ["duplicate"])
})

test("the contact being edited is dropped from the tail, not folded against itself", async () => {
  const { hook, ctx } = hookOver([])
  const folded = await hook.scoreQsos({ operation, ref, qsos: [qso("W1AAA", DAY_1)] }, ctx)
  const edited = qso("W2BBB", DAY_1 + 3600_000)
  const result = await hook.scoreQso!(
    { operation, ref, resumeFrom: folded.scoresheet!, resumeDay: folded.scoresheetDay, qsos: [edited], qso: edited, excludeUuid: edited.uuid as string },
    ctx,
  )
  assert.deepEqual(result.alerts, [])
})

test("a resumed pass continues the checkpoint's day instead of opening a new one", async () => {
  const { hook, ctx } = hookOver([])
  // Nine contacts, one short of activating; the tenth arrives as a tail on the
  // same day. POTA activates DAILY, so its day tally is what a mid-day reset
  // would zero: with the day carried over it reads 10, without it 1.
  const nine = Array.from({ length: 9 }, (_, i) => qso(`W${i}AAA`, DAY_1 + i * 60_000))
  const folded = await hook.scoreQsos({ operation, ref, qsos: nine }, ctx)
  assert.equal(folded.scoresheetDay, DAY_1, "the pass reports the day it ended on")

  const appended = await hook.scoreQsos(
    { operation, ref, resumeFrom: folded.scoresheet!, resumeDay: folded.scoresheetDay, qsos: [qso("W9AAA", DAY_1 + 3600_000)] },
    ctx,
  )
  assert.equal(appended.daySections.length, 1)
  assert.equal(appended.daySections[0].scores.activation?.total, 10)
  assert.equal(appended.scoresheetDay, DAY_1)
})

test("a pass that folds nothing reports no day", async () => {
  const { hook, ctx } = hookOver([])
  const empty = await hook.scoreQsos({ operation, ref, qsos: [] }, ctx)
  assert.equal(empty.scoresheetDay, undefined)
})

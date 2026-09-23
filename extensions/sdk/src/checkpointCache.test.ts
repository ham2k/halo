// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The checkpoint a harness holds by name. What these pin down: a name stands
// for the sheet only while the harness has it (a name it lacks is an error
// the host answers, never a silent cold fold), and nothing the live paths do
// to the held sheet — through the view they score against — ever reaches it.

import { test } from "node:test"
import assert from "node:assert/strict"

import { activityScorer } from "./activityScoring.ts"
import { contestScorer, RESUME_MISSING } from "./scoring.ts"
import type { HookContext, JSONValue } from "./types.ts"

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

/// A hook whose cold path would read an EMPTY log: any duplicate it reports
/// came from a checkpoint, not from the log.
function hook() {
  const ctx: HookContext = { online: false, getQsos: async () => [] }
  return { hook: contestScorer(activityScorer(POTA), { scope: { refTypes: ["potaActivation", "pota"] } }), ctx }
}

test("a batch pass holds its end sheet under the host's name, and a live call can name it", async () => {
  const { hook: h, ctx } = hook()
  const folded = await h.scoreQsos({ operation, ref, qsos: [qso("W1AAA", DAY_1)], checkpointKey: "k1" }, ctx)
  assert.equal(folded.checkpointHeld, true)

  const named = await h.scoreQso!({ operation, ref, resumeKey: "k1", qso: qso("W1AAA", DAY_1 + 3600_000) }, ctx)
  assert.deepEqual(named.alerts, ["duplicate"], "the named checkpoint knows the contact; the (empty) log does not")
  assert.equal(named.checkpointHeld, true)
})

test("a name the harness does not hold is an error, not a cold fold", async () => {
  const { hook: h, ctx } = hook()
  await assert.rejects(h.scoreQso!({ operation, ref, resumeKey: "never-sent", qso: qso("W1AAA", DAY_1) }, ctx), (error: Error) =>
    error.message.startsWith(RESUME_MISSING),
  )
  await assert.rejects(h.scoreCandidates!({ operation, ref, resumeKey: "never-sent", candidates: [] }, ctx), (error: Error) =>
    error.message.startsWith(RESUME_MISSING),
  )
  await assert.rejects(h.scoreQsos({ operation, ref, resumeKey: "never-sent", qsos: [] }, ctx), (error: Error) => error.message.startsWith(RESUME_MISSING))
})

test("a sheet that arrives with a name is held under it", async () => {
  const { hook: h, ctx } = hook()
  const folded = await h.scoreQsos({ operation, ref, qsos: [qso("W1AAA", DAY_1)] }, ctx)
  assert.equal(folded.checkpointHeld, undefined, "nothing was named, so nothing is held")

  const sent = await h.scoreQso!(
    { operation, ref, resumeKey: "k1", resumeFrom: folded.scoresheet!, resumeDay: folded.scoresheetDay, qso: qso("W1AAA", DAY_1 + 3600_000) },
    ctx,
  )
  assert.equal(sent.checkpointHeld, true)
  const named = await h.scoreQso!({ operation, ref, resumeKey: "k1", qso: qso("W1AAA", DAY_1 + 3600_000) }, ctx)
  assert.deepEqual(named.alerts, ["duplicate"])
})

test("a new name for the same operation replaces the old", async () => {
  const { hook: h, ctx } = hook()
  await h.scoreQsos({ operation, ref, qsos: [qso("W1AAA", DAY_1)], checkpointKey: "k1" }, ctx)
  await h.scoreQsos({ operation, ref, qsos: [qso("W2BBB", DAY_1 + 1000)], resumeKey: "k1", checkpointKey: "k2" }, ctx)
  await assert.rejects(h.scoreQso!({ operation, ref, resumeKey: "k1", qso: qso("W1AAA", DAY_1) }, ctx), (error: Error) =>
    error.message.startsWith(RESUME_MISSING),
  )
  const named = await h.scoreQso!({ operation, ref, resumeKey: "k2", qso: qso("W2BBB", DAY_1 + 3600_000) }, ctx)
  assert.deepEqual(named.alerts, ["duplicate"], "the appended pass's end sheet is what k2 names")
})

test("only the last few operations are held", async () => {
  const { hook: h, ctx } = hook()
  for (const n of [1, 2, 3, 4, 5]) {
    await h.scoreQsos({ operation: { ...operation, uuid: `op-${n}` }, ref, qsos: [qso("W1AAA", DAY_1)], checkpointKey: "k" }, ctx)
  }
  await assert.rejects(
    h.scoreQso!({ operation: { ...operation, uuid: "op-1" }, ref, resumeKey: "k", qso: qso("W1AAA", DAY_1) }, ctx),
    (error: Error) => error.message.startsWith(RESUME_MISSING),
    "the oldest operation's checkpoint has been let go",
  )
  const kept = await h.scoreQso!({ operation: { ...operation, uuid: "op-5" }, ref, resumeKey: "k", qso: qso("W1AAA", DAY_1) }, ctx)
  assert.deepEqual(kept.alerts, ["duplicate"])
})

test("neither live path writes into the held sheet", async () => {
  // The scorer records every candidate it scores into the sheet it is handed;
  // through the view, that must stay the candidate's own. A held sheet that
  // took the write would call the next keystroke's fresh call a duplicate.
  const { hook: h, ctx } = hook()
  const folded = await h.scoreQsos({ operation, ref, qsos: [qso("W1AAA", DAY_1)], checkpointKey: "k1" }, ctx)
  const before = JSON.stringify(folded.scoresheet)

  await h.scoreQso!({ operation, ref, resumeKey: "k1", qso: qso("W2BBB", DAY_1 + 3600_000) }, ctx)
  await h.scoreQso!({ operation, ref, resumeKey: "k1", qsos: [qso("W3CCC", DAY_1 + 1800_000)], qso: qso("W4DDD", DAY_1 + 3600_000) }, ctx)
  await h.scoreCandidates!(
    {
      operation,
      ref,
      resumeKey: "k1",
      candidates: [
        { key: "a", qso: qso("W5EEE", DAY_1 + 3600_000) },
        { key: "b", qso: qso("W5EEE", DAY_1 + 3600_000) },
      ],
    },
    ctx,
  )

  const fresh = await h.scoreQso!({ operation, ref, resumeKey: "k1", qso: qso("W2BBB", DAY_1 + 7200_000) }, ctx)
  assert.deepEqual(fresh.alerts, [], "a candidate scored earlier leaked into the held checkpoint")
  const replayed = await h.scoreQso!({ operation, ref, resumeKey: "k1", qso: qso("W3CCC", DAY_1 + 7200_000) }, ctx)
  assert.deepEqual(replayed.alerts, [], "a replayed tail leaked into the held checkpoint")
  assert.equal(JSON.stringify(folded.scoresheet), before, "the sheet the host was handed is the one that was held")
})

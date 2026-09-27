// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// These encode WHY the rules matter, not just what they compute: a dupe is
// what the contest sponsor rejects, so a same-band-and-mode repeat must score
// zero; but the same station on a NEW band is a fresh contact worth a point,
// which is the distinction operators actually rely on while running a band.

import { test } from "node:test"
import assert from "node:assert/strict"

import { SimpleContestScorer } from "./scorer.ts"
import type { JSONValue } from "@ham2k/extension-sdk"

const ctx = { online: false } as never
const op = { uuid: "op-1" }

function qso(call: string, band = "20m", mode = "SSB"): Record<string, JSONValue> {
  return { their: { call }, band, mode }
}

/// Folds QSOs the way the harness does, so these test the scorer under its
/// real usage rather than a hand-rolled loop.
function run(qsos: Record<string, JSONValue>[]) {
  let sheet = SimpleContestScorer.startScoresheet({ operation: op }, ctx)
  const scores = qsos.map((q) => {
    const result = SimpleContestScorer.scoreQso({ scoresheet: sheet, qso: q, operation: op, isNewDay: false }, ctx)
    sheet = result.scoresheet
    return result.score
  })
  return { sheet, scores }
}

test("a contact scores one point", () => {
  const { scores, sheet } = run([qso("W1AW")])
  assert.equal(scores[0].value, 1)
  assert.equal(sheet.points, 1)
})

test("the same call on the same band and mode is a dupe worth nothing", () => {
  const { scores, sheet } = run([qso("W1AW"), qso("W1AW")])
  assert.equal(scores[1].value, 0)
  assert.equal(scores[1].dupe, true)
  assert.deepEqual(scores[1].alerts, ["duplicate"])
  // The dupe must not inflate the score the operator reports.
  assert.equal(sheet.points, 1)
})

test("the same call on a new band still counts, and says so", () => {
  const { scores, sheet } = run([qso("W1AW", "20m"), qso("W1AW", "40m")])
  assert.equal(scores[1].value, 1)
  assert.equal(scores[1].dupe, undefined)
  assert.ok(scores[1].notices?.includes("newBand"))
  assert.equal(sheet.points, 2)
})

test("the same call on a new mode still counts, and says so", () => {
  const { scores } = run([qso("W1AW", "20m", "SSB"), qso("W1AW", "20m", "CW")])
  assert.equal(scores[1].value, 1)
  assert.ok(scores[1].notices?.includes("newMode"))
})

test("different calls never collide", () => {
  const { sheet } = run([qso("W1AW"), qso("K2ABC"), qso("N3XYZ")])
  assert.equal(sheet.points, 3)
  assert.equal(sheet.qsos, 3)
})

test("a QSO with no callsign is ignored rather than counted", () => {
  const { scores, sheet } = run([{ band: "20m", mode: "SSB", their: {} }])
  assert.equal(scores[0].value, 0)
  assert.equal(sheet.qsos, 0)
})

test("a new day does not reset dupe detection", () => {
  let sheet = SimpleContestScorer.startScoresheet({ operation: op }, ctx)
  sheet = SimpleContestScorer.scoreQso({ scoresheet: sheet, qso: qso("W1AW"), operation: op, isNewDay: false }, ctx).scoresheet
  const next = SimpleContestScorer.scoreQso({ scoresheet: sheet, qso: qso("W1AW"), operation: op, isNewDay: true }, ctx)

  // A station worked yesterday on this band+mode is still a dupe today.
  assert.equal(next.score.dupe, true)
  assert.equal(next.scoresheet.points, 1)
})

test("the summary names the contest by its identifier, with its points", () => {
  const { sheet } = run([qso("W1AW"), qso("K2ABC")])
  const operation = SimpleContestScorer.summarizeScore({ scoresheet: sheet, operation: op, ref: { contestIdentifier: "NEQP" }, scope: "operation" }, ctx)
  assert.equal(operation.contest.total, 2)
  assert.equal(operation.contest.label, "NEQP: 2 points")
  assert.equal(operation.contest.longSummary, "2 QSOs")
})

test("offers no per-day summary", () => {
  const { sheet } = run([qso("W1AW")])
  assert.deepEqual(SimpleContestScorer.summarizeScore({ scoresheet: sheet, operation: op, scope: "day" }, ctx), {})
})

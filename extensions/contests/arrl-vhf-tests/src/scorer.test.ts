// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Three scoring shapes share one scorer (points, distance, distanceAndPoints)
// — a bug in the branch selection silently applies the wrong contest's math to
// a valid QSO. The dupe rule is the other trap: a rover working the same call
// from a NEW grid must score again, not dupe.

import { test } from "node:test"
import assert from "node:assert/strict"

import { ARRLVHFScorer } from "./scorer.ts"
import type { JSONValue } from "@ham2k/extension-sdk"

const ctx = { online: false } as never

function qso(call: string, band: string, theirGrid?: string): Record<string, JSONValue> {
  return {
    their: { call },
    band,
    refs: theirGrid ? [{ type: "arrl-vhf-tests", grid: theirGrid }] : [],
  }
}

function run(qsos: Record<string, JSONValue>[], operation: Record<string, JSONValue>, ref: Record<string, JSONValue>) {
  let sheet = ARRLVHFScorer.startScoresheet({ operation, ref }, ctx)
  const scores = qsos.map((q) => {
    const r = ARRLVHFScorer.scoreQso({ scoresheet: sheet, qso: q, operation, ref, isNewDay: false }, ctx)
    sheet = r.scoresheet
    return r.score
  })
  return { sheet, scores }
}

test("points event: fixed value per band, no distance", () => {
  const operation = { grid: "FN31" }
  const ref = { type: "arrl-vhf-tests", ref: "ARRL-VHF-JAN" }
  const { scores } = run([qso("K1ABC", "6m", "FM18"), qso("K2DEF", "1.25m", "FM18")], operation, ref)
  assert.equal(scores[0].value, 1)
  assert.equal(scores[1].value, 2)
  assert.equal(scores[0].distance, undefined)
})

test("distance event: round(km) * band multiplier", () => {
  const operation = { grid: "FN31" }
  const ref = { type: "arrl-vhf-tests", ref: "ARRL-222" }
  const { scores } = run([qso("K1ABC", "1.25m", "FN20aa")], operation, ref)
  assert.ok(scores[0].value! > 0)
  assert.equal(scores[0].value, (scores[0].distance as number) * 2) // 1.25m multiplier is 2
})

test("distanceAndPoints event: distance formula plus a flat per-QSO bonus", () => {
  const operation = { grid: "FN31aa" }
  const ref = { type: "arrl-vhf-tests", ref: "ARRL-10G-AUG" }
  const { scores } = run([qso("K1ABC", "3cm", "FN20aa")], operation, ref)
  const distancePortion = (scores[0].distance as number) * 1 // 3cm multiplier is 1
  assert.equal(scores[0].value, distancePortion + 100)
})

test("same call, same band, same our-grid, same their-grid twice is a dupe", () => {
  const operation = { grid: "FN31" }
  const ref = { type: "arrl-vhf-tests", ref: "ARRL-VHF-JAN" }
  const { scores } = run([qso("K1ABC", "6m", "FM18"), qso("K1ABC", "6m", "FM18")], operation, ref)
  assert.equal(scores[0].value, 1)
  assert.equal(scores[1].value, 0)
  assert.equal(scores[1].dupe, true)
})

test("same call worked again on a DIFFERENT band is not a dupe", () => {
  const operation = { grid: "FN31" }
  const ref = { type: "arrl-vhf-tests", ref: "ARRL-VHF-JAN" }
  const { scores } = run([qso("K1ABC", "6m", "FM18"), qso("K1ABC", "2m", "FM18")], operation, ref)
  assert.equal(scores[0].value, 1)
  assert.equal(scores[1].value, 1)
})

test("a QSO with no recorded exchange grid scores zero, not a guess", () => {
  const operation = { grid: "FN31" }
  const ref = { type: "arrl-vhf-tests", ref: "ARRL-VHF-JAN" }
  const { scores } = run([qso("K1ABC", "6m")], operation, ref)
  assert.equal(scores[0].value, 0)
  assert.deepEqual(scores[0].alerts, ["missingExchange"])
})

test("no operation grid at all scores zero with an ourGrid alert", () => {
  const operation = {}
  const ref = { type: "arrl-vhf-tests", ref: "ARRL-VHF-JAN" }
  const { scores } = run([qso("K1ABC", "6m", "FM18")], operation, ref)
  assert.equal(scores[0].value, 0)
  assert.deepEqual(scores[0].alerts, ["ourGrid"])
})

test("a band outside the running event is rejected", () => {
  const operation = { grid: "FN31" }
  const ref = { type: "arrl-vhf-tests", ref: "ARRL-VHF-JAN" }
  const { scores } = run([qso("K1ABC", "10m", "FM18")], operation, ref) // HF isn't in the VHF+ band list
  assert.equal(scores[0].value, 0)
  assert.deepEqual(scores[0].alerts, ["invalidBand"])
})

test("a rover working the same call from a NEW grid is not a dupe — the trap the dupe key exists for", () => {
  const ref = { type: "arrl-vhf-tests", ref: "ARRL-VHF-JAN" }
  let sheet = ARRLVHFScorer.startScoresheet({ operation: {}, ref }, ctx)
  const first = ARRLVHFScorer.scoreQso({ scoresheet: sheet, qso: qso("K1ABC", "6m", "FM18"), operation: { grid: "FN31" }, ref, isNewDay: false }, ctx)
  sheet = first.scoresheet
  const second = ARRLVHFScorer.scoreQso({ scoresheet: sheet, qso: qso("K1ABC", "6m", "FM18"), operation: { grid: "FN20" }, ref, isNewDay: false }, ctx)
  assert.equal(first.score.value, 1)
  assert.equal(second.score.value, 1, "a different our-grid makes this a fresh contact, not a dupe")
  assert.equal(second.score.dupe, undefined)
})

test("a malformed operation grid scores zero rather than throwing (gridToLocation throws on bad input)", () => {
  const operation = { grid: "X" } // not a well-formed 4/6/8-char locator
  const ref = { type: "arrl-vhf-tests", ref: "ARRL-222" }
  const { scores } = run([qso("K1ABC", "1.25m", "FN20aa")], operation, ref)
  assert.equal(scores[0].value, 0)
  assert.deepEqual(scores[0].alerts, ["invalidExchange"])
})

// The 10 GHz rules (5.1–5.4): distance × band factor per contact, plus 100
// QSO points once per unique callsign per band — never multiplied, and not
// paid again when the same station is re-worked on that band from a new
// location. Each test below is one way of over- or under-paying those 100.

const TEN_GIG = { type: "arrl-vhf-tests", ref: "ARRL-10G-SEP" }

test("10 GHz: QSO points ride on top of the distance unmultiplied, even on a factor-5 band", () => {
  const { scores } = run([qso("KN2X", "2.5mm", "FN20aa")], { grid: "FN31aa" }, TEN_GIG)
  assert.ok((scores[0].distance as number) > 0)
  assert.equal(scores[0].value, (scores[0].distance as number) * 5 + 100)
})

test("10 GHz: submillimeter contacts take the top band factor rather than an invalidBand alert", () => {
  const { scores } = run([qso("KN2X", "submm", "FN20aa")], { grid: "FN31aa" }, TEN_GIG)
  assert.equal(scores[0].alerts, undefined)
  assert.equal(scores[0].value, (scores[0].distance as number) * 5 + 100)
})

test("10 GHz: a call re-worked on the same band from a NEW location earns distance only", () => {
  // A rover's move makes a fresh contact (not a dupe), but the 100 went to
  // the first one.
  const { scores, sheet } = run([qso("KN2X", "3cm", "FN20aa"), qso("KN2X", "3cm", "FN21bb")], { grid: "FN31aa" }, TEN_GIG)
  assert.equal(scores[1].dupe, undefined)
  assert.equal(scores[1].alerts, undefined)
  assert.equal(scores[1].value, scores[1].distance)
  assert.equal(sheet.qsoPoints, 100)
  assert.equal(sheet.distancePoints, (scores[0].distance as number) + (scores[1].distance as number))
})

test("10 GHz: the same call on a DIFFERENT band earns the QSO points again", () => {
  const { scores } = run([qso("KN2X", "3cm", "FN20aa"), qso("KN2X", "1.25cm", "FN20aa")], { grid: "FN31aa" }, TEN_GIG)
  assert.equal(scores[1].value, (scores[1].distance as number) * 2 + 100)
})

test("10 GHz: a grid shorter than the 6-character exchange is flagged, scores its distance, and neither takes nor uses up the QSO points", () => {
  const { scores, sheet } = run([qso("KN2X", "3cm", "FN20"), qso("KN2X", "3cm", "FN20aa")], { grid: "FN31aa" }, TEN_GIG)
  assert.deepEqual(scores[0].alerts, ["shortGrid"])
  assert.equal(scores[0].value, scores[0].distance)
  // The full-grid contact that follows is the one the 100 belongs to.
  assert.equal(scores[1].alerts, undefined)
  assert.equal(scores[1].value, (scores[1].distance as number) + 100)
  assert.equal(sheet.qsoPoints, 100)
})

test("10 GHz: the summary reports the distance and QSO halves separately", () => {
  const { sheet } = run([qso("KN2X", "3cm", "FN20aa"), qso("KN2X", "3cm", "FN21bb")], { grid: "FN31aa" }, TEN_GIG)
  const tally = ARRLVHFScorer.summarizeScore({ scoresheet: sheet, operation: {}, ref: TEN_GIG, scope: "operation" }, ctx)["arrl-vhf-tests"]
  assert.equal(tally.total, sheet.points)
  assert.match(tally.label!, /^ARRL 10G Sep: [\d,]+ points$/)
  assert.match(tally.longSummary!, /^2 QSOs, [\d,]+ pts, [\d,]+ km\n/)
  assert.match(tally.longSummary!, new RegExp(`${sheet.distancePoints} distance points \\+ 100 QSO points`))
})

// A points-only event computes no distance: a "Longest: 0 km" per band reads
// as a measurement nobody took.
test("a points-only event's summary names no distance", () => {
  const ref = { type: "arrl-vhf-tests", ref: "ARRL-VHF-JAN" }
  const { sheet } = run([qso("K1ABC", "6m", "FN20")], { grid: "FN31" }, ref)
  const tally = ARRLVHFScorer.summarizeScore({ scoresheet: sheet, operation: {}, ref, scope: "operation" }, ctx)["arrl-vhf-tests"]
  assert.doesNotMatch(tally.longSummary!, /km/)
  assert.match(tally.longSummary!, /\*\*6m\*\*: 1 QSOs$/m)
})

test("a 2-character grid is malformed, not short", () => {
  const ref = { type: "arrl-vhf-tests", ref: "ARRL-222" }
  const { scores } = run([qso("K1ABC", "1.25m", "FN")], { grid: "FN31aa" }, ref)
  // A 2-character grid can't be placed at all, so `invalidExchange` wins over
  // `shortGrid`: there is no distance to score.
  assert.deepEqual(scores[0].alerts, ["invalidExchange"])
})

test("10 GHz: a scoresheet persisted before the QSO-points fields existed still scores", () => {
  // The spots panel resumes from the cached end-of-log sheet; an older build's
  // sheet has no `qsoPointsTaken`/`distancePoints`/`qsoPoints`.
  const stale = {
    worked: {},
    bands: {},
    qsos: 0,
    points: 0,
    distanceTotal: 0,
    maxDistance: 0,
    maxDistancePerBand: {},
    dupeCount: 0,
    dayQsos: 0,
    dayPoints: 0,
  } as never
  const r = ARRLVHFScorer.scoreQso({ scoresheet: stale, qso: qso("KN2X", "3cm", "FN20aa"), operation: { grid: "FN31aa" }, ref: TEN_GIG, isNewDay: false }, ctx)
  assert.equal(r.score.value, (r.score.distance as number) + 100)
  assert.equal(r.scoresheet.qsoPoints, 100)
})

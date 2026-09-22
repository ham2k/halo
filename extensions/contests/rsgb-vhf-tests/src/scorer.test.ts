// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The two traps unique to RSGB, on top of everything r1-vhf-tests' scorer
// already proves: the same-grid-scores-50 floor (a plain great-circle
// formula would round this toward zero) and the bonus sets, which must grow
// from a QSO's OWN new key, not from a running total that could drift out of
// sync with what was actually seen.

import { test } from "node:test"
import assert from "node:assert/strict"

import { RSGBVHFScorer } from "./scorer.ts"
import type { JSONValue } from "@ham2k/extension-sdk"

const ctx = { online: false } as never

function qso(call: string, band: string, theirGrid?: string, location?: string): Record<string, JSONValue> {
  return {
    their: { call },
    band,
    refs: theirGrid ? [{ type: "rsgb-vhf-tests", grid: theirGrid, ...(location ? { location } : {}) }] : [],
  }
}

function run(qsos: Record<string, JSONValue>[], operation: Record<string, JSONValue>, ref: Record<string, JSONValue>) {
  let sheet = RSGBVHFScorer.startScoresheet({ operation, ref }, ctx)
  const scores = qsos.map((q) => {
    const r = RSGBVHFScorer.scoreQso({ scoresheet: sheet, qso: q, operation, ref, isNewDay: false }, ctx)
    sheet = r.scoresheet
    return r.score
  })
  return { sheet, scores }
}

test("same square as ours scores a flat 50, not the near-zero great-circle result", () => {
  const operation = { grid: "IO91wo" }
  const ref = { type: "rsgb-vhf-tests", ref: "RSGB-144-AFS" }
  const { scores } = run([qso("G4ABC", "2m", "IO91wo")], operation, ref)
  assert.equal(scores[0].distance, 50)
  assert.equal(scores[0].value, 50) // 2m multiplier is 1
})

test("a band with a bonus-carrying district exchange still uses the plain BAND_MULTIPLIERS table", () => {
  const operation = { grid: "IO91wo" }
  const ref = { type: "rsgb-vhf-tests", ref: "RSGB-BACKPACKERS-1" } // 2m, multiplier 1
  const { scores } = run([qso("G4ABC", "2m", "IO90ab", "M")], operation, ref)
  const distance = scores[0].distance as number
  assert.equal(scores[0].value, distance * 1)
})

test("a rover working the same call from a NEW our-grid is not a dupe", () => {
  const ref = { type: "rsgb-vhf-tests", ref: "RSGB-144-AFS" }
  let sheet = RSGBVHFScorer.startScoresheet({ operation: {}, ref }, ctx)
  const first = RSGBVHFScorer.scoreQso({ scoresheet: sheet, qso: qso("G4ABC", "2m", "IO91ab"), operation: { grid: "IO91wo" }, ref, isNewDay: false }, ctx)
  sheet = first.scoresheet
  const second = RSGBVHFScorer.scoreQso({ scoresheet: sheet, qso: qso("G4ABC", "2m", "IO91ab"), operation: { grid: "IO80xx" }, ref, isNewDay: false }, ctx)
  assert.equal(second.score.dupe, undefined, "a different our-grid makes this a fresh contact, not a dupe")
})

test("same call, same band, same our-grid, same their-grid twice is a dupe", () => {
  const operation = { grid: "IO91wo" }
  const ref = { type: "rsgb-vhf-tests", ref: "RSGB-144-AFS" }
  const { scores } = run([qso("G4ABC", "2m", "IO91ab"), qso("G4ABC", "2m", "IO91ab")], operation, ref)
  assert.ok(scores[0].value! > 0)
  assert.equal(scores[1].value, 0)
  assert.equal(scores[1].dupe, true)
})

test("no operation grid at all scores zero with an ourGrid alert", () => {
  const operation = {}
  const ref = { type: "rsgb-vhf-tests", ref: "RSGB-144-AFS" }
  const { scores } = run([qso("G4ABC", "2m", "IO91ab")], operation, ref)
  assert.equal(scores[0].value, 0)
  assert.deepEqual(scores[0].alerts, ["ourGrid"])
})

test("a QSO with no recorded exchange grid scores zero, not a guess", () => {
  const operation = { grid: "IO91wo" }
  const ref = { type: "rsgb-vhf-tests", ref: "RSGB-144-AFS" }
  const { scores } = run([qso("G4ABC", "2m")], operation, ref)
  assert.equal(scores[0].value, 0)
  assert.deepEqual(scores[0].alerts, ["missingExchange"])
})

test("a band outside the running event is rejected", () => {
  const operation = { grid: "IO91wo" }
  const ref = { type: "rsgb-vhf-tests", ref: "RSGB-50-AFS" } // 6m only
  const { scores } = run([qso("G4ABC", "2m", "IO91ab")], operation, ref)
  assert.equal(scores[0].value, 0)
  assert.deepEqual(scores[0].alerts, ["invalidBand"])
})

test("newGrid bonus grows only from a genuinely new band×grid4 key, not per QSO", () => {
  const operation = { grid: "IO91wo" }
  const ref = { type: "rsgb-vhf-tests", ref: "RSGB-BACKPACKERS-3" } // newGrid: 500, no district
  const { sheet } = run([qso("G4ABC", "2m", "IO91ab"), qso("G4XYZ", "2m", "IO91ab"), qso("G4DEF", "2m", "IO92cd")], operation, ref)
  // Two QSOs share grid4 "IO91" — only one new key each for IO91 and IO92.
  assert.equal(sheet.bonus, 1000)
})

test("newDistrict bonus requires a district exchange AND a known district code", () => {
  const operation = { grid: "IO91wo" }
  const ref = { type: "rsgb-vhf-tests", ref: "RSGB-BACKPACKERS-1" } // newDistrict: 200
  const { sheet: withKnown } = run([qso("G4ABC", "2m", "IO91ab", "M")], operation, ref)
  assert.ok(withKnown.bonus >= 200)

  const { sheet: withUnknown } = run([qso("G4ABC", "2m", "IO91ab", "ZZ")], operation, ref)
  assert.equal(Object.keys(withUnknown.districtsSeen).length, 0, "an unrecognized district code earns no bonus")
})

test("newDXCC bonus grows only from a genuinely new band×entity key", () => {
  const operation = { grid: "IO91wo" }
  const ref = { type: "rsgb-vhf-tests", ref: "RSGB-BACKPACKERS-2" } // newGrid + newDXCC, no district
  const { sheet } = run([qso("G4ABC", "2m", "IO91ab"), qso("G4XYZ", "2m", "IO92cd")], operation, ref)
  // Both G-calls are the same DXCC entity — the DXCC bonus fires once, the
  // grid bonus fires twice (IO91 and IO92 are different grid4 keys).
  assert.equal(Object.keys(sheet.entitiesSeen).length, 1)
  assert.equal(Object.keys(sheet.gridsSeen).length, 2)
})

test("a dupe never contributes a phantom bonus", () => {
  const operation = { grid: "IO91wo" }
  const ref = { type: "rsgb-vhf-tests", ref: "RSGB-BACKPACKERS-3" } // newGrid: 500
  const { sheet } = run([qso("G4ABC", "2m", "IO91ab"), qso("G4ABC", "2m", "IO91ab")], operation, ref)
  assert.equal(sheet.bonus, 500, "the dupe repeats the same grid4 key, so the bonus set does not grow")
})

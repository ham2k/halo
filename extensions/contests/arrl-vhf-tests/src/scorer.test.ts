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
    refs: theirGrid ? [{ type: 'arrl-vhf-tests', grid: theirGrid }] : [],
  }
}

function run(
  qsos: Record<string, JSONValue>[],
  operation: Record<string, JSONValue>,
  ref: Record<string, JSONValue>,
) {
  let sheet = ARRLVHFScorer.startScoresheet({ operation, ref }, ctx)
  const scores = qsos.map((q) => {
    const r = ARRLVHFScorer.scoreQso({ scoresheet: sheet, qso: q, operation, ref, isNewDay: false }, ctx)
    sheet = r.scoresheet
    return r.score
  })
  return { sheet, scores }
}

test('points event: fixed value per band, no distance', () => {
  const operation = { grid: 'FN31' }
  const ref = { type: 'arrl-vhf-tests', ref: 'ARRL-VHF-JAN' }
  const { scores } = run([qso('K1ABC', '6m', 'FM18'), qso('K2DEF', '1.25m', 'FM18')], operation, ref)
  assert.equal(scores[0].value, 1)
  assert.equal(scores[1].value, 2)
  assert.equal(scores[0].distance, undefined)
})

test('distance event: round(km) * band multiplier', () => {
  const operation = { grid: 'FN31' }
  const ref = { type: 'arrl-vhf-tests', ref: 'ARRL-222' }
  const { scores } = run([qso('K1ABC', '1.25m', 'FN20aa')], operation, ref)
  assert.ok(scores[0].value! > 0)
  assert.equal(scores[0].value, (scores[0].distance as number) * 2) // 1.25m multiplier is 2
})

test('distanceAndPoints event: distance formula plus a flat per-QSO bonus', () => {
  const operation = { grid: 'FN31aa' }
  const ref = { type: 'arrl-vhf-tests', ref: 'ARRL-10G-AUG' }
  const { scores } = run([qso('K1ABC', '3cm', 'FN20aa')], operation, ref)
  const distancePortion = (scores[0].distance as number) * 1 // 3cm multiplier is 1
  assert.equal(scores[0].value, distancePortion + 100)
})

test('same call, same band, same our-grid, same their-grid twice is a dupe', () => {
  const operation = { grid: 'FN31' }
  const ref = { type: 'arrl-vhf-tests', ref: 'ARRL-VHF-JAN' }
  const { scores } = run([qso('K1ABC', '6m', 'FM18'), qso('K1ABC', '6m', 'FM18')], operation, ref)
  assert.equal(scores[0].value, 1)
  assert.equal(scores[1].value, 0)
  assert.equal(scores[1].dupe, true)
})

test('same call worked again on a DIFFERENT band is not a dupe', () => {
  const operation = { grid: 'FN31' }
  const ref = { type: 'arrl-vhf-tests', ref: 'ARRL-VHF-JAN' }
  const { scores } = run([qso('K1ABC', '6m', 'FM18'), qso('K1ABC', '2m', 'FM18')], operation, ref)
  assert.equal(scores[0].value, 1)
  assert.equal(scores[1].value, 1)
})

test('a QSO with no recorded exchange grid scores zero, not a guess', () => {
  const operation = { grid: 'FN31' }
  const ref = { type: 'arrl-vhf-tests', ref: 'ARRL-VHF-JAN' }
  const { scores } = run([qso('K1ABC', '6m')], operation, ref)
  assert.equal(scores[0].value, 0)
  assert.deepEqual(scores[0].alerts, ['missingExchange'])
})

test('no operation grid at all scores zero with an ourGrid alert', () => {
  const operation = {}
  const ref = { type: 'arrl-vhf-tests', ref: 'ARRL-VHF-JAN' }
  const { scores } = run([qso('K1ABC', '6m', 'FM18')], operation, ref)
  assert.equal(scores[0].value, 0)
  assert.deepEqual(scores[0].alerts, ['ourGrid'])
})

test('a band outside the running event is rejected', () => {
  const operation = { grid: 'FN31' }
  const ref = { type: 'arrl-vhf-tests', ref: 'ARRL-VHF-JAN' }
  const { scores } = run([qso('K1ABC', '10m', 'FM18')], operation, ref) // HF isn't in the VHF+ band list
  assert.equal(scores[0].value, 0)
  assert.deepEqual(scores[0].alerts, ['invalidBand'])
})

test('a rover working the same call from a NEW grid is not a dupe — the trap the dupe key exists for', () => {
  const ref = { type: 'arrl-vhf-tests', ref: 'ARRL-VHF-JAN' }
  let sheet = ARRLVHFScorer.startScoresheet({ operation: {}, ref }, ctx)
  const first = ARRLVHFScorer.scoreQso(
    { scoresheet: sheet, qso: qso('K1ABC', '6m', 'FM18'), operation: { grid: 'FN31' }, ref, isNewDay: false },
    ctx,
  )
  sheet = first.scoresheet
  const second = ARRLVHFScorer.scoreQso(
    { scoresheet: sheet, qso: qso('K1ABC', '6m', 'FM18'), operation: { grid: 'FN20' }, ref, isNewDay: false },
    ctx,
  )
  assert.equal(first.score.value, 1)
  assert.equal(second.score.value, 1, 'a different our-grid makes this a fresh contact, not a dupe')
  assert.equal(second.score.dupe, undefined)
})

test('a malformed operation grid scores zero rather than throwing (gridToLocation throws on bad input)', () => {
  const operation = { grid: 'X' } // not a well-formed 4/6/8-char locator
  const ref = { type: 'arrl-vhf-tests', ref: 'ARRL-222' }
  const { scores } = run([qso('K1ABC', '1.25m', 'FN20aa')], operation, ref)
  assert.equal(scores[0].value, 0)
  assert.deepEqual(scores[0].alerts, ['invalidExchange'])
})

test('a band with no multiplier entry (a gap in the event data) scores zero with an alert, not a silent zero', () => {
  const operation = { grid: 'FN31aa' }
  const ref = { type: 'arrl-vhf-tests', ref: 'ARRL-10G-AUG' }
  // submm is in ARRL-10G-AUG's band list but not its multipliers map.
  const { scores } = run([qso('K1ABC', 'submm', 'FN20aa')], operation, ref)
  assert.equal(scores[0].value, 0)
  assert.deepEqual(scores[0].alerts, ['invalidBand'])
})

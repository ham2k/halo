// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// R1's rounding rule (floor(km) + 1) differs from ARRL's plain round(km) —
// a copy-pasted scorer that reused arrl-vhf-tests' rounding would silently
// under-credit every QSO by up to 1 point. The dupe rule is the same trap
// M7's scorer guards: a rover working the same call from a NEW grid must
// score again, not dupe.

import { test } from "node:test"
import assert from "node:assert/strict"

import { R1VHFScorer } from "./scorer.ts"
import type { JSONValue } from "@ham2k/extension-sdk"
import { distanceOnEarth, gridToLocation } from "@ham2k/lib-geo-tools"

const ctx = { online: false } as never

function qso(call: string, band: string, theirGrid?: string): Record<string, JSONValue> {
  return {
    their: { call },
    band,
    refs: theirGrid ? [{ type: 'r1-vhf-tests', grid: theirGrid }] : [],
  }
}

function run(
  qsos: Record<string, JSONValue>[],
  operation: Record<string, JSONValue>,
  ref: Record<string, JSONValue>,
) {
  let sheet = R1VHFScorer.startScoresheet({ operation, ref }, ctx)
  const scores = qsos.map((q) => {
    const r = R1VHFScorer.scoreQso({ scoresheet: sheet, qso: q, operation, ref, isNewDay: false }, ctx)
    sheet = r.scoresheet
    return r.score
  })
  return { sheet, scores }
}

test('distance is floor(km) + 1, not round(km) — R1s own rounding rule', () => {
  const operation = { grid: 'IO91wo' }
  const ref = { type: 'r1-vhf-tests', ref: 'R1-VHF-145-SEPTEMBER' }
  // IO91wo→IO92wo is ~111.19 km — floor+1 gives 112, plain round gives 111,
  // so this pair actually distinguishes the two rules (most pairs' raw km
  // lands close enough to a whole number that floor+1 and round agree).
  const { scores } = run([qso('G4ABC', '2m', 'IO92wo')], operation, ref)
  const distance = scores[0].distance as number

  const [lat1, lon1] = gridToLocation('IO91wo')
  const [lat2, lon2] = gridToLocation('IO92wo')
  const rawKm = distanceOnEarth({ lat: lat1, lon: lon1 }, { lat: lat2, lon: lon2 }) as number
  assert.equal(distance, Math.floor(rawKm) + 1)
  assert.notEqual(distance, Math.round(rawKm), 'this pair is chosen to be where floor+1 and round diverge')
  assert.equal(scores[0].value, distance * 1) // 2m multiplier is 1
})

test('a millimeter band multiplies the distance, unlike the 1x HF/VHF/UHF bands', () => {
  const operation = { grid: 'IO91wo' }
  const ref = { type: 'r1-vhf-tests', ref: 'R1-VHF-SUB1-MARCH' }
  const { scores } = run([qso('G4ABC', '1mm', 'IO90ab')], operation, ref)
  const distance = scores[0].distance as number
  assert.equal(scores[0].value, distance * 10)
})

test('a rover working the same call from a NEW grid is not a dupe', () => {
  const ref = { type: 'r1-vhf-tests', ref: 'R1-VHF-145-SEPTEMBER' }
  let sheet = R1VHFScorer.startScoresheet({ operation: {}, ref }, ctx)
  const first = R1VHFScorer.scoreQso(
    { scoresheet: sheet, qso: qso('G4ABC', '2m', 'IO91ab'), operation: { grid: 'IO91wo' }, ref, isNewDay: false },
    ctx,
  )
  sheet = first.scoresheet
  const second = R1VHFScorer.scoreQso(
    { scoresheet: sheet, qso: qso('G4ABC', '2m', 'IO91ab'), operation: { grid: 'IO80xx' }, ref, isNewDay: false },
    ctx,
  )
  assert.equal(second.score.dupe, undefined, 'a different our-grid makes this a fresh contact, not a dupe')
})

test('same call, same band, same our-grid, same their-grid twice is a dupe', () => {
  const operation = { grid: 'IO91wo' }
  const ref = { type: 'r1-vhf-tests', ref: 'R1-VHF-145-SEPTEMBER' }
  const { scores } = run([qso('G4ABC', '2m', 'IO91ab'), qso('G4ABC', '2m', 'IO91ab')], operation, ref)
  assert.ok(scores[0].value! > 0)
  assert.equal(scores[1].value, 0)
  assert.equal(scores[1].dupe, true)
})

test('no operation grid at all scores zero with an ourGrid alert', () => {
  const operation = {}
  const ref = { type: 'r1-vhf-tests', ref: 'R1-VHF-145-SEPTEMBER' }
  const { scores } = run([qso('G4ABC', '2m', 'IO91ab')], operation, ref)
  assert.equal(scores[0].value, 0)
  assert.deepEqual(scores[0].alerts, ['ourGrid'])
})

test('a QSO with no recorded exchange grid scores zero, not a guess', () => {
  const operation = { grid: 'IO91wo' }
  const ref = { type: 'r1-vhf-tests', ref: 'R1-VHF-145-SEPTEMBER' }
  const { scores } = run([qso('G4ABC', '2m')], operation, ref)
  assert.equal(scores[0].value, 0)
  assert.deepEqual(scores[0].alerts, ['missingExchange'])
})

test('a band outside the running event is rejected', () => {
  const operation = { grid: 'IO91wo' }
  const ref = { type: 'r1-vhf-tests', ref: 'R1-VHF-50-JUNE' } // 6m only
  const { scores } = run([qso('G4ABC', '2m', 'IO91ab')], operation, ref)
  assert.equal(scores[0].value, 0)
  assert.deepEqual(scores[0].alerts, ['invalidBand'])
})

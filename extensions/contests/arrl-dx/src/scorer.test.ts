// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ARRL DX is asymmetric — W/VE works DX and DX works W/VE — and almost every
// rule follows from that. These pin the asymmetry itself, since getting it
// backwards produces a log that scores plausibly and is entirely wrong.

import { test } from "node:test"
import assert from "node:assert/strict"

import { ARRLDXScorer, POWER_PATTERN, isWveCall, weAreWve } from "./scorer.ts"
import type { JSONValue } from "@ham2k/extension-sdk"

const ctx = { online: false } as never
const cwRef = { type: 'arrl-dx', mode: 'CW' }

const usOperation = { uuid: 'op', stationCall: 'N0DEV' }   // W/VE side
const dlOperation = { uuid: 'op', stationCall: 'DL0ABC' }  // DX side

function qso(call: string, band = '20m', exchange?: string): Record<string, JSONValue> {
  return {
    their: { call },
    band,
    mode: 'CW',
    ...(exchange ? { refs: [{ type: 'arrl-dx', theirExchange: exchange }] } : {}),
  }
}

function run(qsos: Record<string, JSONValue>[], operation = usOperation, ref: Record<string, JSONValue> = cwRef) {
  let sheet = ARRLDXScorer.startScoresheet({ operation, ref }, ctx)
  const scores = qsos.map((q) => {
    const r = ARRLDXScorer.scoreQso({ scoresheet: sheet, qso: q, operation, ref, isNewDay: false }, ctx)
    sheet = r.scoresheet
    return r.score
  })
  return { sheet, scores }
}

test('W/VE means the USA and Canada only — Alaska and Hawaii are DX', () => {
  assert.equal(isWveCall('W1AW'), true)
  assert.equal(isWveCall('VE3XYZ'), true);
  // Both are separate DXCC entities, so they count as DX in this contest even
  // though they are US callsigns.
  assert.equal(isWveCall('KL7AA'), false)
  assert.equal(isWveCall('KH6AA'), false)
  assert.equal(isWveCall('DL1ABC'), false)
})

test('our side is inferred from our callsign, and setup overrides it', () => {
  assert.equal(weAreWve(usOperation), true)
  assert.equal(weAreWve(dlOperation), false)
  // A US operator working portable from Europe says so at setup.
  assert.equal(weAreWve(usOperation, { type: 'arrl-dx', stationType: 'dx' }), false)
})

test('working our own side is not a contest QSO', () => {
  // The defining rule: W/VE may only work DX.
  const { scores, sheet } = run([qso('W1AW')])
  assert.equal(scores[0].value, 0)
  assert.deepEqual(scores[0].alerts, ['invalidCategory'])
  assert.equal(sheet.qsos, 0)

  // And symmetrically, DX may only work W/VE.
  const { scores: dxScores } = run([qso('EA4XYZ')], dlOperation)
  assert.deepEqual(dxScores[0].alerts, ['invalidCategory'])
})

test('every valid QSO is worth a flat 3 points', () => {
  // Unlike CQ WW, neither continent nor distance changes the value.
  const { scores, sheet } = run([qso('DL1ABC'), qso('JA1ABC'), qso('PY2ABC')])
  assert.deepEqual(scores.map((s) => s.value), [3, 3, 3])
  assert.equal(sheet.points, 9)
})

test('as a W/VE station our multipliers are their DXCC entities, per band', () => {
  const { sheet } = run([qso('DL1ABC', '20m'), qso('DL2ABC', '20m'), qso('DL3ABC', '40m')])
  // Two DL contacts on 20m are one multiplier; the third is a new band.
  assert.deepEqual(Object.keys(sheet.mults).sort(), ['20m|DL', '40m|DL'])
})

test('as a DX station our multipliers are the states and provinces they send', () => {
  const { sheet } = run(
    [qso('W1AW', '20m', 'MA'), qso('K2ABC', '20m', 'NY'), qso('W3XYZ', '20m', 'ma')],
    dlOperation,
  )
  // MA and NY — and the lowercase "ma" is the same multiplier as "MA".
  assert.deepEqual(Object.keys(sheet.mults).sort(), ['20m|MA', '20m|NY'])
})

test('a station repeats per band, not per contest', () => {
  const { scores, sheet } = run([qso('DL1ABC', '20m'), qso('DL1ABC', '20m'), qso('DL1ABC', '40m')])
  assert.equal(scores[1].dupe, true)
  assert.equal(scores[1].value, 0)
  assert.equal(scores[2].value, 3)
  assert.ok(scores[2].notices?.includes('newBand'))
  assert.equal(sheet.points, 6)
})

test('wrong mode or a WARC band does not count', () => {
  const phone = { type: 'arrl-dx', mode: 'Phone' }
  const { scores } = run([qso('DL1ABC', '20m')], usOperation, phone)
  assert.deepEqual(scores[0].alerts, ['invalidMode'])

  const { scores: warc } = run([qso('DL1ABC', '30m')])
  assert.deepEqual(warc[0].alerts, ['invalidBand'])
})

test('the power exchange accepts watts 1-1500 and the conventional abbreviations', () => {
  // Compiled the way the core does it: anchored and case-insensitive.
  const re = new RegExp(`^(?:${POWER_PATTERN})$`, 'i')

  for (const good of ['1', '5', '100', '999', '1000', '1499', '1500', 'K', 'KW', 'kw']) {
    assert.ok(re.test(good), `${good} should be a valid power`)
  }
  // CW cut numbers: N=9, T=0, A=1 — so NN is 99 and 1TT/ATT are both 100.
  for (const cut of ['NN', '1TT', 'ATT', 'att']) {
    assert.ok(re.test(cut), `${cut} is a conventional CW abbreviation`)
  }
  for (const bad of ['0', '1501', '2000', 'A', 'TT', '', 'ABC']) {
    assert.ok(!re.test(bad), `${bad} should not be a valid power`)
  }
})

test('the score is points times multipliers', () => {
  const { sheet } = run([qso('DL1ABC', '20m'), qso('JA1ABC', '20m'), qso('PY2ABC', '40m')])
  const summary = ARRLDXScorer.summarizeScore({ scoresheet: sheet, operation: usOperation, scope: 'operation' }, ctx)
  // 9 points, mults 20m|DL, 20m|JA, 40m|PY.
  assert.equal(summary.arrlDx.points, 9)
  assert.equal(summary.arrlDx.mults, 3)
  assert.equal(summary.arrlDx.total, 27)
})

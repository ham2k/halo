// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// NAQP's scoring is almost all multipliers: every QSO is one point, so the only
// thing that moves the score is which locations were worked on which bands.
// A mistake there produces a plausible number that is simply not what the
// sponsor will compute.
//
// Two rules do real work and are easy to lose in a port: `DX` is a valid QSO
// but not a multiplier, and a multiplier counts once PER BAND.

import { test } from "node:test"
import assert from "node:assert/strict"

import { normalizeLocation } from "./exchange.ts"
import { NAQPScorer } from "./scorer.ts"
import { VALID_LOCATIONS, isMultiplier } from "./locations.ts"
import type { JSONValue } from "@ham2k/halo-extension-sdk"

const ctx = { online: false } as never

const usOperation = { uuid: 'op', stationCall: 'N0DEV' }
const cwRef = { type: 'naqp', mode: 'CW', ourName: 'SEB', ourLocation: 'NY' }

function qso(call: string, band = '20m', location?: string, mode = 'CW'): Record<string, JSONValue> {
  return {
    their: { call },
    band,
    mode,
    ...(location ? { refs: [{ type: 'naqp', name: 'BOB', location }] } : {}),
  }
}

function run(
  qsos: Record<string, JSONValue>[],
  operation = usOperation,
  ref: Record<string, JSONValue> = cwRef,
) {
  let sheet = NAQPScorer.startScoresheet({ operation, ref }, ctx)
  const scores = qsos.map((q) => {
    const r = NAQPScorer.scoreQso({ scoresheet: sheet, qso: q, operation, ref, isNewDay: false }, ctx)
    sheet = r.scoresheet
    return r.score
  })
  return { sheet, scores }
}

test('the location set is the states, the provinces, the NA entities and DX', () => {
  assert.equal(VALID_LOCATIONS.size, 111)
  for (const code of ['NY', 'AK', 'HI', 'DC', 'ON', 'NU', 'XE', 'KP4', '4U1U', 'DX']) {
    assert.ok(VALID_LOCATIONS.has(code), `${code} should be a valid location`)
  }
  // Not a state, not a province, not a NA entity.
  for (const code of ['ZZ', 'DL', 'JA', '']) {
    assert.ok(!VALID_LOCATIONS.has(code), `${code} should not be valid`)
  }
})

test('DX is a valid exchange but never a multiplier', () => {
  // The rule most easily lost in a port: a DX station is a perfectly good
  // contact worth its point, and names no one place to multiply by.
  assert.ok(VALID_LOCATIONS.has('DX'))
  assert.equal(isMultiplier('DX'), false)
  assert.equal(isMultiplier('NY'), true)
  assert.equal(isMultiplier('ZZ'), false, 'unrecognized is not a multiplier either')

  const { scores, sheet } = run([qso('DL1ABC', '20m', 'DX')])
  assert.equal(scores[0].value, 1, 'still a point')
  assert.equal(Object.keys(sheet.mults).length, 0, 'but no multiplier')
})

test('every valid QSO is worth exactly one point', () => {
  const { scores } = run([
    qso('W1AW', '20m', 'CT'),
    qso('VE3XYZ', '20m', 'ON'),
    qso('DL1ABC', '20m', 'DX'),
  ])
  assert.deepEqual(scores.map((s) => s.value), [1, 1, 1])
})

test('a multiplier counts once per BAND, so the same state counts again on 15m', () => {
  const { sheet } = run([
    qso('W1AW', '20m', 'CT'),
    qso('K1ABC', '20m', 'CT'),
    qso('W1AW', '15m', 'CT'),
  ])
  assert.deepEqual(Object.keys(sheet.mults).sort(), ['15m|CT', '20m|CT'])

  const summary = NAQPScorer.summarizeScore(
    { scoresheet: sheet, operation: usOperation, ref: cwRef, scope: 'operation' },
    ctx,
  )
  assert.equal(summary.naqp.points, 3)
  assert.equal(summary.naqp.total, 6, '3 QSOs x 2 mults')
})

test('a station may be worked once per band', () => {
  const { scores } = run([qso('W1AW', '20m', 'CT'), qso('W1AW', '20m', 'CT'), qso('W1AW', '15m', 'CT')])
  assert.equal(scores[0].value, 1)
  assert.equal(scores[1].value, 0)
  assert.ok(scores[1].alerts?.includes('duplicate'))
  assert.equal(scores[2].value, 1, 'a new band is a fresh contact')
  assert.ok(scores[2].notices?.includes('newBand'))
})

test('a location the operator never sent costs the multiplier, not the QSO', () => {
  const { scores, sheet } = run([qso('W1AW', '20m')])
  assert.equal(scores[0].value, 1)
  assert.ok(scores[0].alerts?.includes('missingExchange'))
  assert.equal(Object.keys(sheet.mults).length, 0)
})

test('locations normalize, so "ny" and "NY" are one multiplier', () => {
  assert.equal(normalizeLocation('ny'), 'NY')
  assert.equal(normalizeLocation('  on '), 'ON')
  assert.equal(normalizeLocation(undefined), '')

  const { sheet } = run([qso('W1AW', '20m', 'ny'), qso('K1ABC', '20m', 'NY')])
  assert.equal(Object.keys(sheet.mults).length, 1)
})

test('a location that is not a NAQP exchange says so instead of failing quietly', () => {
  // Every state, province and NA entity is a multiplier, so an unrecognized
  // location is one going unclaimed — and a typo the operator could still fix.
  const { scores, sheet } = run([qso('W1AW', '20m', 'NYY')])
  assert.equal(scores[0].value, 1, 'still a contact')
  assert.equal(Object.keys(sheet.mults).length, 0)
  assert.deepEqual(scores[0].alerts, ['invalidExchange'])

  // DX is recognized and deliberately not a multiplier, so it is NOT an error.
  const { scores: dx } = run([qso('DL1ABC', '20m', 'DX')])
  assert.equal(dx[0].alerts, undefined)
})

test('Washington DC is a multiplier, not an invalid exchange', () => {
  // DC is not a state and IS a multiplier — NAQP's rules name it alongside the
  // fifty, and §5.3's table counts 111 locations, which only adds up with it.
  // Omitting it both dropped a real multiplier and made the new invalidExchange
  // alert accuse a perfectly good exchange.
  assert.ok(VALID_LOCATIONS.has('DC'))
  assert.equal(isMultiplier('DC'), true)

  const { scores, sheet } = run([qso('W3ABC', '20m', 'DC')])
  assert.equal(scores[0].alerts, undefined, 'nothing wrong with it')
  assert.deepEqual(Object.keys(sheet.mults), ['20m|DC'])
})

test('the RTTY running excludes 160m, which the other two allow', () => {
  const rttyRef = { type: 'naqp', mode: 'RTTY', ourName: 'SEB', ourLocation: 'NY' }
  const { scores } = run([qso('W1AW', '160m', 'CT', 'RTTY')], usOperation, rttyRef)
  assert.equal(scores[0].value, 0)
  assert.ok(scores[0].alerts?.includes('invalidBand'))

  // …and the CW running is unaffected.
  const { scores: cw } = run([qso('W1AW', '160m', 'CT')])
  assert.equal(cw[0].value, 1)
})

test('the RTTY running takes the generic DATA mode and RTTY submodes', () => {
  // halo's own mode picker offers a generic `DATA` entry beside `RTTY`, and
  // ADIF stores a SUBMODE as the mode when there is one — so an ordinary RTTY
  // contact can be logged as neither literal string. An exact compare zeroed
  // both.
  const rttyRef = { type: 'naqp', mode: 'RTTY', ourName: 'SEB', ourLocation: 'NY' }
  const { scores } = run(
    [qso('W1AW', '20m', 'CT', 'DATA'), qso('K1ABC', '20m', 'CT', 'ASCI'), qso('K2ABC', '20m', 'CT', 'FT8')],
    usOperation,
    rttyRef,
  )
  assert.equal(scores[0].value, 1, 'the operator picked the generic digital entry')
  assert.equal(scores[1].value, 1, 'ASCI is an ADIF submode of RTTY')
  assert.ok(scores[2].alerts?.includes('invalidMode'), 'FT8 is still not RTTY')
})

test('the RTTY running does not accept every digital mode', () => {
  // superModeForMode lumps RTTY in with FT8 and every other data mode, so
  // comparing families would let an FT8 contact into an RTTY log.
  const rttyRef = { type: 'naqp', mode: 'RTTY', ourName: 'SEB', ourLocation: 'NY' }
  const { scores } = run(
    [qso('W1AW', '20m', 'CT', 'FT8'), qso('K1ABC', '20m', 'CT', 'RTTY'), qso('K2ABC', '20m', 'CT', 'rtty')],
    usOperation,
    rttyRef,
  )
  assert.ok(scores[0].alerts?.includes('invalidMode'), 'FT8 is not RTTY')
  assert.equal(scores[1].value, 1)
  assert.equal(scores[2].value, 1, 'case of the logged mode does not matter')
})

test('a QSO with no mode at all is rejected, not assumed to be data', () => {
  // superModeForMode('') answers 'DATA', so a family comparison would make
  // every mode-less QSO — an ADIF import missing MODE — a valid RTTY contact.
  const rttyRef = { type: 'naqp', mode: 'RTTY', ourName: 'SEB', ourLocation: 'NY' }
  const { scores } = run([qso('W1AW', '20m', 'CT', '')], usOperation, rttyRef)
  assert.ok(scores[0].alerts?.includes('invalidMode'))
})

test('the contest is single-mode, so the other mode does not count', () => {
  // polo checks neither band nor mode here; both are checked on port (RFC §8's
  // fix-on-port decision). NAQP CW and NAQP SSB are separate contests.
  const { scores } = run([qso('W1AW', '20m', 'CT', 'SSB'), qso('K1ABC', '20m', 'CT', 'CW')])
  assert.ok(scores[0].alerts?.includes('invalidMode'))
  assert.equal(scores[1].value, 1)
})

test('a sideband QSO counts in the SSB contest', () => {
  // The radio reports USB or LSB; the sponsor only cares that it was phone.
  const ssbRef = { type: 'naqp', mode: 'SSB', ourName: 'SEB', ourLocation: 'NY' }
  const { scores } = run([qso('W1AW', '20m', 'CT', 'USB'), qso('K1ABC', '40m', 'CT', 'LSB')], usOperation, ssbRef)
  assert.deepEqual(scores.map((s) => s.value), [1, 1])
})

test('WARC bands are excluded by the rules', () => {
  const { scores } = run([qso('W1AW', '30m', 'CT')])
  assert.equal(scores[0].value, 0)
  assert.ok(scores[0].alerts?.includes('invalidBand'))
})

test('the day summary resets its counters but keeps the running multipliers', () => {
  let sheet = NAQPScorer.startScoresheet({ operation: usOperation, ref: cwRef }, ctx)
  const score = (q: Record<string, JSONValue>, isNewDay: boolean) => {
    const r = NAQPScorer.scoreQso({ scoresheet: sheet, qso: q, operation: usOperation, ref: cwRef, isNewDay }, ctx)
    sheet = r.scoresheet
  }
  score(qso('W1AW', '20m', 'CT'), false)
  score(qso('VE3XYZ', '20m', 'ON'), true)

  const day = NAQPScorer.summarizeScore(
    { scoresheet: sheet, operation: usOperation, ref: cwRef, scope: 'day' },
    ctx,
  )
  assert.equal(day.naqp.qsos, 1)
  assert.equal(day.naqp.points, 1)
  // …but multipliers are a contest-long tally, so the day is scored against
  // both of them.
  assert.equal(day.naqp.total, 2)
})

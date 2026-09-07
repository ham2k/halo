// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Run with `node --experimental-strip-types --test` (see package.json).

import { test } from "node:test"
import assert from "node:assert/strict"

import { EHF_BANDS, SHF_BANDS, UHF_BANDS, VHF_BANDS } from "@ham2k/lib-operation-data"

import { cabrilloFreq, qsonToCabrillo } from "./cabrillo.ts"

// Microwave operators routinely type the frequency in MHz ("10368.1"), which the app keeps
// as logged but still resolves to the right band. Decide the Cabrillo column on the frequency's
// magnitude instead of the band, and every one of those QSOs is reported as an HF frequency.
test("cabrilloFreq: microwave bands report an identifier, whatever units the frequency was logged in", () => {
  assert.equal(cabrilloFreq({ band: '3cm', freq: 10368.1 }), '10G')
  assert.equal(cabrilloFreq({ band: '3cm', freq: 10368100 }), '10G')
  assert.equal(cabrilloFreq({ band: '1.25cm', freq: 24192.1 }), '24G')
  assert.equal(cabrilloFreq({ band: '6mm', freq: 47088.5 }), '47G')
  assert.equal(cabrilloFreq({ band: '4mm' }), '75G')
})

test("cabrilloFreq: VHF and UHF bands report an identifier", () => {
  assert.equal(cabrilloFreq({ band: '2m', freq: 144200 }), '144')
  assert.equal(cabrilloFreq({ band: '1.25m', freq: 222100 }), '222')
  assert.equal(cabrilloFreq({ band: '70cm', freq: 432100 }), '432')
})

// Every band that reports an identifier needs a table entry, or its QSOs export as '0'.
// 1.25m and 5m were missing exactly this way, so 222 MHz — a core ARRL VHF band — exported
// as a zero. The two lists have to stay in step as the band list grows.
test("cabrilloFreq: every band reported by identifier has one", () => {
  const bands = [...VHF_BANDS, ...UHF_BANDS, ...SHF_BANDS, ...EHF_BANDS]
  const missing = bands.filter((band) => cabrilloFreq({ band }) === '0')
  assert.deepEqual(missing, [])
})

test("cabrilloFreq: HF reports kHz", () => {
  assert.equal(cabrilloFreq({ band: '20m', freq: 14074 }), '14074')
  assert.equal(cabrilloFreq({ band: '20m' }), '14000', "no frequency logged: the band's default")
})

// A QSO party's county line: one contact, several submitted lines, because the
// checker matches each pairing of counties against the other station's log
// separately. The date/time/frequency prefix repeats on every line — a row that
// carried only the exchange columns would be unreadable to a checker.
test("qsonToCabrillo: a QSO may produce several rows, each fully prefixed", () => {
  const content = qsonToCabrillo(
    [{ band: '20m', mode: 'CW', startAtMillis: Date.UTC(2026, 9, 17, 14, 30), their: { call: 'K1ABC' } }],
    {
      headers: [['CONTEST', 'NY-QSO-PARTY']],
      qsoParts: () => [['N0DEV', 'ALB', 'K1ABC', 'ERI'], ['N0DEV', 'REN', 'K1ABC', 'ERI']],
    },
  )
  const rows = content.split('\n').filter((line) => line.startsWith('QSO:'))
  assert.equal(rows.length, 2)
  for (const row of rows) assert.match(row, /^QSO: 14000 CW +2026-10-17 1430 /)
  assert.match(rows[0], /ALB/)
  assert.match(rows[1], /REN/)
})

// The single-row form every other contest uses has to keep working unchanged,
// and an empty answer means "don't claim this contact" rather than an empty line.
test("qsonToCabrillo: one row, or none at all", () => {
  const qso = { band: '20m', mode: 'CW', startAtMillis: 0, their: { call: 'K1ABC' } }
  const one = qsonToCabrillo([qso], { headers: [], qsoParts: () => ['N0DEV', 'K1ABC'] })
  assert.equal(one.split('\n').filter((line) => line.startsWith('QSO:')).length, 1)
  const none = qsonToCabrillo([qso], { headers: [], qsoParts: () => [] })
  assert.equal(none.split('\n').filter((line) => line.startsWith('QSO:')).length, 0)
})

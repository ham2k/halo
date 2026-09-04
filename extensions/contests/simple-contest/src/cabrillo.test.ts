// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Run with `node --experimental-strip-types --test` (see package.json).

import { test } from "node:test"
import assert from "node:assert/strict"

import { EHF_BANDS, SHF_BANDS, UHF_BANDS, VHF_BANDS } from "@ham2k/lib-operation-data"

import { cabrilloFreq } from "./cabrillo.ts"

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

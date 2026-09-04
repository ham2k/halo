// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Run with `node --experimental-strip-types --test` (see package.json).

import { test } from "node:test"
import assert from "node:assert/strict"

import { bandForFrequency } from "@ham2k/lib-operation-data"

import { BANDS_FOR_GIG_DESIGNATIONS, parseGigBandCommand } from "./parseGigBandCommand.ts"

test("parseGigBandCommand: a GHz designation names its band", () => {
  assert.deepEqual(parseGigBandCommand("10G"), { designation: '10G', band: '3cm' })
  assert.deepEqual(parseGigBandCommand("24G"), { designation: '24G', band: '1.25cm' })
  assert.deepEqual(parseGigBandCommand("47G"), { designation: '47G', band: '6mm' })
  assert.deepEqual(parseGigBandCommand("1.2G"), { designation: '1.2G', band: '23cm' })
  assert.deepEqual(parseGigBandCommand("241G"), { designation: '241G', band: '1mm' })
})

test("parseGigBandCommand: lowercase and a GHz suffix", () => {
  assert.deepEqual(parseGigBandCommand("10g"), { designation: '10G', band: '3cm' })
  assert.deepEqual(parseGigBandCommand("10GHz"), { designation: '10G', band: '3cm' })
  assert.deepEqual(parseGigBandCommand("  5.7ghz  "), { designation: '5.7G', band: '6cm' })
})

test("parseGigBandCommand: bands that go by two designations take either", () => {
  assert.equal(parseGigBandCommand("1.3G")?.band, '23cm')
  assert.equal(parseGigBandCommand("2.4G")?.band, '13cm')
  assert.equal(parseGigBandCommand("3.3G")?.band, '9cm')
  assert.equal(parseGigBandCommand("5.8G")?.band, '6cm')
  assert.equal(parseGigBandCommand("76G")?.band, '4mm')
  assert.equal(parseGigBandCommand("78G")?.band, '4mm')
  assert.equal(parseGigBandCommand("123G")?.band, '2.5mm')
})

// A designation names a frequency, so it has to land in the band it claims — otherwise the
// command quietly puts the operator on the wrong band. The designations sit close enough
// together to make that an easy typo, so every entry in the table is checked, not a sample.
test("parseGigBandCommand: every designation names a frequency inside the band it maps to", () => {
  for (const designation of Object.keys(BANDS_FOR_GIG_DESIGNATIONS)) {
    if (designation === '122G') continue // checked below: the label sits outside its own band
    const parsed = parseGigBandCommand(designation)
    assert.equal(parsed?.band, bandForFrequency(parseFloat(designation) * 1e6), designation)
  }
})

// 122G is the one designation the band table won't place: it is the label the ARRL uses,
// but the 2.5mm band starts at 122.25 GHz, so the sweep above can't check it.
test("parseGigBandCommand: 122G maps to the band its label belongs to", () => {
  assert.equal(parseGigBandCommand("122G")?.band, '2.5mm')
  assert.equal(bandForFrequency(122 * 1e6), 'other')
})

// Commands are typed into the callsign field, so a pattern that matches too eagerly swallows
// what the operator meant as a call. 119G and 142G name allocations that no longer exist.
test("parseGigBandCommand: unknown designations are left to be read as callsigns", () => {
  assert.equal(parseGigBandCommand("9G"), null)
  assert.equal(parseGigBandCommand("9G5XX"), null)
  assert.equal(parseGigBandCommand("4G"), null)
  assert.equal(parseGigBandCommand("119G"), null)
  assert.equal(parseGigBandCommand("142G"), null)
  assert.equal(parseGigBandCommand("20M"), null)
  assert.equal(parseGigBandCommand(""), null)
})

// app-polo also matches '1/2G', because its callsign field rewrites periods to slashes.
// HaLo's MobileDotToSlashFormatter gates on a callsign prefix that '1.' fails, so the period
// arrives intact and the slash spelling would only ever come from a stray keystroke.
test("parseGigBandCommand: the slash spelling is not a designation", () => {
  assert.equal(parseGigBandCommand("1/2G"), null)
})

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Run with `node --experimental-strip-types --test` (see package.json).

import { test } from "node:test"
import assert from "node:assert/strict"

import { EXTENDED_BANDS } from "@ham2k/lib-operation-data"

import { parseBandCommand } from "./parseBandCommand.ts"
import { parseGigBandCommand } from "./parseGigBandCommand.ts"

test("parseBandCommand: a metre band, with or without its unit", () => {
  assert.equal(parseBandCommand("20"), '20m')
  assert.equal(parseBandCommand("20M"), '20m')
  assert.equal(parseBandCommand("20m"), '20m')
  assert.equal(parseBandCommand("  160m  "), '160m')
  // Internal spaces go too, matching parseBandInput — the header claims the
  // two mirror each other, and '70 cm' resolving in one field and not the
  // other is exactly the divergence that claim is meant to rule out.
  assert.equal(parseBandCommand("70 cm"), '70cm')
})

// Every band the app offers has to be reachable, or the command silently
// stops at whatever subset it was first written with — which is how it sat at
// fifteen metre bands out of the thirty-three the app knows.
test("parseBandCommand: every band the app supports is recognized by name", () => {
  const bands = (EXTENDED_BANDS as readonly string[]).filter((band) => band !== 'other')
  const unrecognized = bands.filter((band) => parseBandCommand(band) !== band)
  assert.deepEqual(unrecognized, [])
})

test("parseBandCommand: centimetre and millimetre bands", () => {
  assert.equal(parseBandCommand("70CM"), '70cm')
  assert.equal(parseBandCommand("1.25CM"), '1.25cm')
  assert.equal(parseBandCommand("2MM"), '2mm')
  assert.equal(parseBandCommand("2.5mm"), '2.5mm')
  assert.equal(parseBandCommand("SUBMM"), 'submm')
})

// The unit the operator typed picks between two bands that share a number,
// so dropping it must not silently land them on the wrong one.
test("parseBandCommand: the unit decides between bands sharing a number", () => {
  assert.equal(parseBandCommand("1.25M"), '1.25m')
  assert.equal(parseBandCommand("1.25CM"), '1.25cm')
  assert.equal(parseBandCommand("2M"), '2m')
  assert.equal(parseBandCommand("2MM"), '2mm')
  assert.equal(parseBandCommand("6M"), '6m')
  assert.equal(parseBandCommand("6MM"), '6mm')
})

// A bare number means the metre band, and falls back to centimetres because
// there is no 70m band to prefer — the same rule as halo_core's
// parseBandInput. Millimetres are deliberately outside that fallback: "1"
// means 1mm to nobody, and typing it should set no band at all rather than
// the wrong one.
test("parseBandCommand: a bare number prefers metres, then centimetres, never millimetres", () => {
  assert.equal(parseBandCommand("6"), '6m', "6m and 6mm both exist; metres wins")
  assert.equal(parseBandCommand("70"), '70cm', "no 70m band to prefer")
  assert.equal(parseBandCommand("13"), '13cm')
  assert.equal(parseBandCommand("9"), '9cm')
  assert.equal(parseBandCommand("1"), null, "1mm is not reachable without its unit")
  assert.equal(parseBandCommand("2.5"), null, "2.5mm likewise")
})

// 75m is what the phone end of 80m is called on the air, and 2200m is the
// common name for the band this app's table calls 2190m. Typing '2200M' used
// to set the band to '2200m' — a string no other part of the app knows.
test("parseBandCommand: the aliases operators actually say", () => {
  assert.equal(parseBandCommand("75"), '80m')
  assert.equal(parseBandCommand("75M"), '80m')
  assert.equal(parseBandCommand("2200"), '2190m')
  assert.equal(parseBandCommand("2200M"), '2190m')
  assert.equal(parseBandCommand("2190"), '2190m', "the canonical name still works")
  assert.equal(parseBandCommand("75CM"), null, "the alias is the metre band, not a stray unit")
})

// Commands are typed into the callsign field, and the mode command shares
// this priority — a band pattern that claims 'AM' or 'FM' eats a mode.
test("parseBandCommand: modes, callsigns and other commands are left alone", () => {
  assert.equal(parseBandCommand("AM"), null)
  assert.equal(parseBandCommand("FM"), null)
  assert.equal(parseBandCommand("CW"), null)
  assert.equal(parseBandCommand("20WPM"), null)
  assert.equal(parseBandCommand("K1ABC"), null)
  assert.equal(parseBandCommand("M"), null)
  assert.equal(parseBandCommand("other"), null, "the band table's fallback is not a band anyone works")
  assert.equal(parseBandCommand(""), null)
})

// Both hooks sit at the same priority, so an input either one claims must not
// be claimed by the other — '10G' is the 3cm band, never the 10m one.
test("parseBandCommand: the GHz designations are not band names", () => {
  for (const designation of ['1.2G', '10G', '24G', '47G', '75G', '241G']) {
    assert.equal(parseBandCommand(designation), null, designation)
    assert.notEqual(parseGigBandCommand(designation), null, designation)
  }
})

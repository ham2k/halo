// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import { spotModeFor } from "./spotMode.ts"

test("spotModeFor passes through the modes SOTAwatch accepts, with its exact casing", () => {
  assert.equal(spotModeFor("CW"), "CW")
  assert.equal(spotModeFor("SSB"), "SSB")
  assert.equal(spotModeFor("FM"), "FM")
  assert.equal(spotModeFor("AM"), "AM")
  assert.equal(spotModeFor("DATA"), "Data")
  assert.equal(spotModeFor("DV"), "DV")
})

test("spotModeFor folds SSB submodes into SSB", () => {
  assert.equal(spotModeFor("USB"), "SSB")
  assert.equal(spotModeFor("LSB"), "SSB")
})

test("spotModeFor folds digital voice modes into DV", () => {
  assert.equal(spotModeFor("DIGITALVOICE"), "DV")
  assert.equal(spotModeFor("DSTAR"), "DV")
  assert.equal(spotModeFor("C4FM"), "DV")
})

test("spotModeFor guesses Data for digital modes and anything unknown", () => {
  assert.equal(spotModeFor("FT8"), "Data")
  assert.equal(spotModeFor("RTTY"), "Data")
  assert.equal(spotModeFor(undefined), "Data")
  assert.equal(spotModeFor(""), "Data")
})

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Run with `node --experimental-strip-types --test` (see package.json).

import { test } from "node:test"
import assert from "node:assert/strict"

import { parseSelfSpotCommand, isLastSpotCommand } from "./spotCommandParsing.ts"

test("parseSelfSpotCommand: bare SPOT has an empty comment", () => {
  assert.deepEqual(parseSelfSpotCommand("SPOT"), { comment: "" })
})

test("parseSelfSpotCommand: SPOTME, SPME, SELFSPOT all behave like SPOT", () => {
  for (const trigger of ["SPOTME", "SPME", "SELFSPOT"]) {
    assert.deepEqual(parseSelfSpotCommand(trigger), { comment: "" }, trigger)
  }
})

test("parseSelfSpotCommand: SPOT with free text carries it as the comment verbatim", () => {
  assert.deepEqual(parseSelfSpotCommand("SPOT good signal"), { comment: "good signal" })
})

test("parseSelfSpotCommand: a Q-code trigger becomes the first word of the comment", () => {
  assert.deepEqual(parseSelfSpotCommand("QRV"), { comment: "QRV" })
  assert.deepEqual(parseSelfSpotCommand("QRT ADIOS"), { comment: "QRT ADIOS" })
  assert.deepEqual(parseSelfSpotCommand("QSY up"), { comment: "QSY up" })
  assert.deepEqual(parseSelfSpotCommand("QRX brb"), { comment: "QRX brb" })
})

test("parseSelfSpotCommand: matching is case-insensitive, trigger normalizes to uppercase in the comment", () => {
  assert.deepEqual(parseSelfSpotCommand("qrt adios"), { comment: "QRT adios" })
  assert.deepEqual(parseSelfSpotCommand("spot"), { comment: "" })
})

test("parseSelfSpotCommand: a slash separator works the same as a space", () => {
  assert.deepEqual(parseSelfSpotCommand("SPOT/good signal"), { comment: "good signal" })
})

test("parseSelfSpotCommand: unrelated input doesn't match", () => {
  assert.equal(parseSelfSpotCommand("K1ABC"), null)
  assert.equal(parseSelfSpotCommand("SPOTLAST"), null) // handled by isLastSpotCommand instead
  assert.equal(parseSelfSpotCommand(""), null)
})

test("isLastSpotCommand: SPOTLAST, SPOTEM, SPOTTHEM, SPTHEM all match, case-insensitively", () => {
  for (const trigger of ["SPOTLAST", "SPOTEM", "SPOTTHEM", "SPTHEM", "spotlast"]) {
    assert.equal(isLastSpotCommand(trigger), true, trigger)
  }
})

test("isLastSpotCommand: doesn't accept trailing text (no comment support, per the issue)", () => {
  assert.equal(isLastSpotCommand("SPOTLAST typo"), false)
})

test("isLastSpotCommand: unrelated input doesn't match", () => {
  assert.equal(isLastSpotCommand("SPOT"), false)
  assert.equal(isLastSpotCommand("K1ABC"), false)
})

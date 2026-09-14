// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT

import { test } from "node:test"
import assert from "node:assert/strict"

import { isTestOperation } from "./testOperation.ts"

test("matches a /T or /TEST suffix, case-insensitively", () => {
  assert.equal(isTestOperation("KI2D/T"), true)
  assert.equal(isTestOperation("KI2D/TEST"), true)
  assert.equal(isTestOperation("ki2d/test"), true)
})

test("rejects a normal or portable call", () => {
  assert.equal(isTestOperation("KI2D"), false)
  assert.equal(isTestOperation("KI2D/P"), false)
  assert.equal(isTestOperation(undefined), false)
})

// Segments, not a suffix. `KI2D/TEST/OP1` is what a multi-station Test
// Operation self-spots under (`ExtensionService.spotCallForSelfSpot` appends
// the position after the test marker), and POTA decides between the K-TEST
// sandbox ref and the operation's REAL park from this answer — a suffix check
// says false there and puts a live spot on a park nobody is at.
test("a test marker counts wherever it sits in the call, not only at the end", () => {
  assert.equal(isTestOperation("KI2D/TEST/OP1"), true)
  assert.equal(isTestOperation("KI2D/T/OP2"), true)
  assert.equal(isTestOperation("KI2D/T/P"), true)
})

test("a call that merely contains the letters is not a test call", () => {
  assert.equal(isTestOperation("W1AW/TESTER"), false)
  assert.equal(isTestOperation("KI2D/OP1"), false)
})

// A multi-operator operation's stationCall is comma-separated — checking
// the joined string as one unit would hide a test call behind a real one
// earlier or later in the list.
test("checks every comma-separated call, not just the last one", () => {
  assert.equal(isTestOperation("W1AW/T, KI2D"), true)
  assert.equal(isTestOperation("KI2D, W1AW/T"), true)
})

test("no call anywhere in the list being a test call is false", () => {
  assert.equal(isTestOperation("KI2D, W1AW"), false)
})

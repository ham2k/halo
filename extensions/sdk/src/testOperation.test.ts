// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

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

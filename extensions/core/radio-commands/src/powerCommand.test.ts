// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Run with `node --experimental-strip-types --test` (see package.json).

import { test } from "node:test"
import assert from "node:assert/strict"

import { parsePowerCommand } from "./parsePowerCommand.ts"

test("parsePowerCommand: a bare wattage", () => {
  assert.equal(parsePowerCommand("5W"), 5)
})

test("parsePowerCommand: case-insensitive, decimals included", () => {
  assert.equal(parsePowerCommand("1w"), 1)
  assert.equal(parsePowerCommand("50W"), 50)
  assert.equal(parsePowerCommand("2.5W"), 2.5)
})

test("parsePowerCommand: surrounding whitespace is trimmed", () => {
  assert.equal(parsePowerCommand("  5W  "), 5)
})

test("parsePowerCommand: unrelated input doesn't match", () => {
  assert.equal(parsePowerCommand("K1ABC"), null)
  assert.equal(parsePowerCommand("20M"), null, "a band, not a wattage")
  assert.equal(parsePowerCommand("CW"), null)
  assert.equal(parsePowerCommand("W5"), null, "unit before the number")
  assert.equal(parsePowerCommand("5"), null, "no unit at all")
  assert.equal(parsePowerCommand(""), null)
})

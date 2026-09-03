// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Run with `node --experimental-strip-types --test` (see package.json).

import { test } from "node:test"
import assert from "node:assert/strict"

import { parseWpmCommand } from "./parseWpmCommand.ts"

test("parseWpmCommand: a bare speed", () => {
  assert.equal(parseWpmCommand("20WPM"), 20)
})

test("parseWpmCommand: case-insensitive, with or without a space", () => {
  assert.equal(parseWpmCommand("25wpm"), 25)
  assert.equal(parseWpmCommand("18 WPM"), 18)
  assert.equal(parseWpmCommand("  30WPM  "), 30)
})

test("parseWpmCommand: unrelated input doesn't match", () => {
  assert.equal(parseWpmCommand("K1ABC"), null)
  assert.equal(parseWpmCommand("20M"), null, "a band")
  assert.equal(parseWpmCommand("5W"), null, "a wattage")
  assert.equal(parseWpmCommand("WPM20"), null, "unit before the number")
  assert.equal(parseWpmCommand("20"), null, "no unit at all")
  assert.equal(parseWpmCommand("0WPM"), null, "a keyer cannot run at zero")
  assert.equal(parseWpmCommand("100WPM"), null, "three digits is not a keyer speed")
})

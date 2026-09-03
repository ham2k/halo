// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Run with `node --experimental-strip-types --test` (see package.json).

import { test } from "node:test"
import assert from "node:assert/strict"

import { parseKeyerCommand } from "./parseKeyerCommand.ts"

test("parseKeyerCommand: KEYER and MACROS, either case", () => {
  assert.equal(parseKeyerCommand("KEYER"), true)
  assert.equal(parseKeyerCommand("macros"), true)
  assert.equal(parseKeyerCommand("  Keyer "), true)
})

test("parseKeyerCommand: a prefix or a callsign is not the command", () => {
  assert.equal(parseKeyerCommand("KEY"), false)
  assert.equal(parseKeyerCommand("KEYER1"), false)
  assert.equal(parseKeyerCommand("K1ABC"), false)
  assert.equal(parseKeyerCommand(""), false)
})

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Run with `node --experimental-strip-types --test` (see package.json).

import { test } from "node:test"
import assert from "node:assert/strict"

import { parseSwapCommand } from "./parseSwapCommand.ts"

test("parseSwapCommand: SWAP, either case", () => {
  assert.equal(parseSwapCommand("SWAP"), true)
  assert.equal(parseSwapCommand("swap"), true)
  assert.equal(parseSwapCommand(" Swap "), true)
})

// A callsign or a longer word sharing the prefix must still log as typed.
test("parseSwapCommand: a prefix, a longer word or a callsign is not the command", () => {
  assert.equal(parseSwapCommand("SWA"), false)
  assert.equal(parseSwapCommand("SWAPS"), false)
  assert.equal(parseSwapCommand("SWAP A"), false)
  assert.equal(parseSwapCommand("K1ABC"), false)
  assert.equal(parseSwapCommand(""), false)
})

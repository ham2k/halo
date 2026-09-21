// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Run with `node --experimental-strip-types --test` (see package.json).

import { test } from "node:test"
import assert from "node:assert/strict"

import { parseEnterSendsCommand } from "./parseEnterSendsCommand.ts"

test("parseEnterSendsCommand: ESM switches it, leaving the side alone", () => {
  assert.deepEqual(parseEnterSendsCommand("ESM"), { on: true })
  assert.deepEqual(parseEnterSendsCommand("esm on"), { on: true })
  assert.deepEqual(parseEnterSendsCommand(" ESM OFF "), { on: false })
})

test("parseEnterSendsCommand: RUN and SP pick the side and switch it on", () => {
  assert.deepEqual(parseEnterSendsCommand("RUN"), { on: true, running: true })
  assert.deepEqual(parseEnterSendsCommand("sp"), { on: true, running: false })
  assert.deepEqual(parseEnterSendsCommand("S&P"), { on: true, running: false })
})

// SP is a Polish prefix: anything longer than the bare word is a callsign
// being typed and must reach the log, never this command.
test("parseEnterSendsCommand: callsigns and prefixes are not the command", () => {
  assert.equal(parseEnterSendsCommand("SP1ABC"), null)
  assert.equal(parseEnterSendsCommand("SP9"), null)
  assert.equal(parseEnterSendsCommand("RUNNER"), null)
  assert.equal(parseEnterSendsCommand("ESM MAYBE"), null)
  assert.equal(parseEnterSendsCommand(""), null)
})

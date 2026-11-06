// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Run with `node --experimental-strip-types --test` (see package.json).

import { test } from "node:test"
import assert from "node:assert/strict"

import { parseEnterSendsCommand } from "./parseEnterSendsCommand.ts"
import { parseStyleCommand } from "./parseStyleCommand.ts"

test("parseEnterSendsCommand: ESM switches it", () => {
  assert.deepEqual(parseEnterSendsCommand("ESM"), { on: true })
  assert.deepEqual(parseEnterSendsCommand("esm on"), { on: true })
  assert.deepEqual(parseEnterSendsCommand(" ESM OFF "), { on: false })
})

// RUN and SNP set the operating style, which outlives ESM: they must not
// switch ESM on behind an operator who only said how they are working.
test("parseEnterSendsCommand: RUN and SNP are not ESM's", () => {
  assert.equal(parseEnterSendsCommand("RUN"), null)
  assert.equal(parseEnterSendsCommand("SNP"), null)
  assert.equal(parseEnterSendsCommand("ESM MAYBE"), null)
})

test("parseStyleCommand: RUN runs, SNP, SP and S&P search and pounce", () => {
  assert.equal(parseStyleCommand("RUN"), "run")
  assert.equal(parseStyleCommand(" run "), "run")
  assert.equal(parseStyleCommand("SNP"), "normal")
  assert.equal(parseStyleCommand("sp"), "normal")
  assert.equal(parseStyleCommand("S&P"), "normal")
})

// SP and SN are Polish prefixes: anything longer than the bare word is a
// callsign being typed and must reach the log, never this command.
test("parseStyleCommand: callsigns and prefixes are not the command", () => {
  assert.equal(parseStyleCommand("SP1ABC"), null)
  assert.equal(parseStyleCommand("SNP1A"), null)
  assert.equal(parseStyleCommand("SP9"), null)
  assert.equal(parseStyleCommand("RUNNER"), null)
  assert.equal(parseStyleCommand(""), null)
})

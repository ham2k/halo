// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Run with `node --experimental-strip-types --test` (see package.json).
//
// UPDATE is typed into the call field, so a non-match is a callsign that must
// still log; and the reserved words are the only ones the hook decides — any
// other word has to reach the app untouched, since only it knows which data
// files answer to it.

import { test } from "node:test"
import assert from "node:assert/strict"

import { parseUpdateCommand } from "./updateCommandParsing.ts"

test("parseUpdateCommand: UPD is UPDATE", () => {
  assert.deepEqual(parseUpdateCommand("UPD APP"), parseUpdateCommand("UPDATE APP"))
  assert.deepEqual(parseUpdateCommand("upd ext"), { kind: "extensions" })
})

test("parseUpdateCommand: the reserved words", () => {
  assert.deepEqual(parseUpdateCommand("UPDATE DATA"), { kind: "data" })
  assert.deepEqual(parseUpdateCommand("UPDATE APP"), { kind: "app" })
  assert.deepEqual(parseUpdateCommand("UPDATE EXT"), { kind: "extensions" })
  assert.deepEqual(parseUpdateCommand("UPDATE extensions"), { kind: "extensions" })
  // RELOAD ALL's word, and the palette's keyword: either read as data-file
  // words would reach only the files whose names hold them.
  assert.deepEqual(parseUpdateCommand("UPDATE ALL"), { kind: "data" })
  assert.deepEqual(parseUpdateCommand("UPDATE data files"), { kind: "data" })
})

test("parseUpdateCommand: words split where a data file's key does", () => {
  // The app matches whole words of key, category and name, split on anything
  // not a letter or digit; a key typed whole must split the same way.
  assert.deepEqual(parseUpdateCommand("UPDATE ham2k-pota-all-parks"), { kind: "data", matching: ["HAM2K", "POTA", "ALL", "PARKS"] })
  assert.deepEqual(parseUpdateCommand("UPDATE call-notes"), { kind: "data", matching: ["CALL", "NOTES"] })
  assert.deepEqual(parseUpdateCommand("UPDATE élite"), { kind: "data", matching: ["ÉLITE"] })
})

test("parseUpdateCommand: any other words go to the app as data-file words, uppercased", () => {
  assert.deepEqual(parseUpdateCommand("UPDATE pota"), { kind: "data", matching: ["POTA"] })
  assert.deepEqual(parseUpdateCommand("UPD  call   notes "), { kind: "data", matching: ["CALL", "NOTES"] })
  // Reserved words decide only when alone: one found anywhere would make
  // "APP NOTES", a file's name, an app update.
  assert.deepEqual(parseUpdateCommand("UPDATE APP NOTES"), { kind: "data", matching: ["APP", "NOTES"] })
})

test("parseUpdateCommand: bare UPDATE waits for more", () => {
  assert.deepEqual(parseUpdateCommand("UPDATE"), { kind: "incomplete" })
  assert.deepEqual(parseUpdateCommand("UPD "), { kind: "incomplete" })
})

test("parseUpdateCommand: not UPDATE at all", () => {
  for (const input of ["UPDATES", "UPDX", "UP", "K1UPD", "W1AW"]) assert.equal(parseUpdateCommand(input), null, input)
})

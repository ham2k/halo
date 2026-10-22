// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Run with `node --experimental-strip-types --test` (see package.json).
//
// GO is typed into the call field like every other command, so a non-match
// here is a callsign that must still log, and a place that isn't turned on
// must not exist at all — the operator should never be sent toward a view
// the app is hiding from them.

import { test } from "node:test"
import assert from "node:assert/strict"

import { PLACES, availablePlaces, keywordsOf, parseGoCommand } from "./navigationCommandParsing.ts"

const everything = availablePlaces(["logs", "chase", "p2p"], true)
const plain = availablePlaces([], false)

test("parseGoCommand: a full place word goes there", () => {
  assert.deepEqual(parseGoCommand("GO MAPS", plain), { kind: "place", word: "MAPS", to: "maps" })
  assert.deepEqual(parseGoCommand("go/settings", plain), { kind: "place", word: "SETTINGS", to: "settings" })
})

test("parseGoCommand: an alias goes where its word goes", () => {
  assert.deepEqual(parseGoCommand("GO CAT", plain), { kind: "place", word: "CAT", to: "station" })
  assert.deepEqual(parseGoCommand("GO DATA", plain), { kind: "place", word: "DATA", to: "accounts" })
  assert.deepEqual(parseGoCommand("GO HUNT", everything), { kind: "place", word: "HUNT", to: "chase" })
})

test("parseGoCommand: the start of only one place's word is enough", () => {
  assert.deepEqual(parseGoCommand("GO MA", plain), { kind: "place", word: "MAPS", to: "maps" })
})

test("parseGoCommand: a start shared by several places waits for more", () => {
  // Not a guess: GO S running Settings would be a coin toss between three.
  const parsed = parseGoCommand("GO S", plain)
  assert.equal(parsed?.kind, "incomplete")
  assert.deepEqual(parsed?.kind === "incomplete" && parsed.candidates, ["SETTINGS", "STATION", "SYNC"])
})

test("parseGoCommand: bare GO is recognized with nothing to run yet", () => {
  // Not null: null would let Enter log "GO" as a contact.
  assert.equal(parseGoCommand("GO", plain)?.kind, "incomplete")
})

test("parseGoCommand: a word that is not GO is left alone", () => {
  // GOTO belongs to FIND, and a callsign starting with GO must still log.
  assert.equal(parseGoCommand("GOTO 12", plain), null)
  assert.equal(parseGoCommand("GO4ABC", plain), null)
})

test("parseGoCommand: a place behind an experiment does not exist until it is on", () => {
  assert.deepEqual(parseGoCommand("GO LOGS", plain), { kind: "unknown", text: "LOGS" })
  assert.deepEqual(parseGoCommand("GO HUNT", plain), { kind: "unknown", text: "HUNT" })
  assert.deepEqual(parseGoCommand("GO PEERS", plain), { kind: "unknown", text: "PEERS" })
  assert.deepEqual(parseGoCommand("GO LOGS", everything), { kind: "place", word: "LOGS", to: "logs" })
})

test("parseGoCommand: DEV needs developer mode", () => {
  assert.deepEqual(parseGoCommand("GO DEV", plain), { kind: "unknown", text: "DEV" })
  assert.deepEqual(parseGoCommand("GO DEV", everything), { kind: "place", word: "DEV", to: "developer" })
})

test("parseGoCommand: a hidden place does not make a visible one ambiguous", () => {
  // With Logs hidden, GO L can only mean nothing — never a prompt naming LOGS.
  assert.equal(parseGoCommand("GO L", plain)?.kind, "unknown")
})

test("keywordsOf: an alias is a keyword of the place it stands for", () => {
  // What lets typing CAT in the palette reach GO STATION.
  const station = PLACES.find((p) => p.word === "STATION")!
  assert.ok(keywordsOf(station, plain).includes("CAT"))
})

test("keywordsOf: a hidden alias is not offered", () => {
  const chase = PLACES.find((p) => p.word === "CHASE")!
  assert.ok(keywordsOf(chase, everything).includes("HUNT"))
  assert.ok(!keywordsOf(chase, plain).includes("HUNT"))
})

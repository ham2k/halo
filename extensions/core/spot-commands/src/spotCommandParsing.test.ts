// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Run with `node --experimental-strip-types --test` (see package.json).

import { test } from "node:test"
import assert from "node:assert/strict"

import { isClusterCommand, parseSelfSpotCommand, parseLastSpotCommand, parseRespotCommand } from "./spotCommandParsing.ts"

test("parseSelfSpotCommand: bare SPOT has an empty comment", () => {
  assert.deepEqual(parseSelfSpotCommand("SPOT"), { comment: "" })
})

test("parseSelfSpotCommand: SPOTME, SPME, SELFSPOT all behave like SPOT", () => {
  for (const trigger of ["SPOTME", "SPME", "SELFSPOT"]) {
    assert.deepEqual(parseSelfSpotCommand(trigger), { comment: "" }, trigger)
  }
})

test("parseSelfSpotCommand: SPOT with free text carries it as the comment verbatim", () => {
  assert.deepEqual(parseSelfSpotCommand("SPOT good signal"), { comment: "good signal" })
})

test("parseSelfSpotCommand: a Q-code trigger becomes the first word of the comment", () => {
  assert.deepEqual(parseSelfSpotCommand("QRV"), { comment: "QRV" })
  assert.deepEqual(parseSelfSpotCommand("QRT ADIOS"), { comment: "QRT ADIOS" })
  assert.deepEqual(parseSelfSpotCommand("QSY up"), { comment: "QSY up" })
  assert.deepEqual(parseSelfSpotCommand("QRX brb"), { comment: "QRX brb" })
})

test("parseSelfSpotCommand: matching is case-insensitive, trigger normalizes to uppercase in the comment", () => {
  assert.deepEqual(parseSelfSpotCommand("qrt adios"), { comment: "QRT adios" })
  assert.deepEqual(parseSelfSpotCommand("spot"), { comment: "" })
})

test("parseSelfSpotCommand: a slash separator works the same as a space", () => {
  assert.deepEqual(parseSelfSpotCommand("SPOT/good signal"), { comment: "good signal" })
})

// The source is the first word and its colon, nothing more: a colon later in
// the text is prose, or "SPOT back at 14:30" would look for a source "14".
test("parseSelfSpotCommand: a first word stuck to a colon names the source, and leaves the comment", () => {
  assert.deepEqual(parseSelfSpotCommand("SPOT discord: Hey guys"), { comment: "Hey guys", source: "discord" })
  assert.deepEqual(parseSelfSpotCommand("SPOT ki2d-discord-spotting:"), { comment: "", source: "ki2d-discord-spotting" })
  assert.deepEqual(parseSelfSpotCommand("spot/pota_spots: hi"), { comment: "hi", source: "pota_spots" })
  assert.deepEqual(parseSelfSpotCommand("SPOT back at 14:30"), { comment: "back at 14:30" })
  assert.deepEqual(parseSelfSpotCommand("SPOT Note: back soon"), { comment: "back soon", source: "Note" })
  assert.deepEqual(parseSelfSpotCommand("SPOT hey all: lunch"), { comment: "hey all: lunch" })
})

// The Q-code still leads the comment: the source is where it goes, not what
// it says.
test("parseSelfSpotCommand: a Q-code with a source keeps the Q-code as the comment's first word", () => {
  assert.deepEqual(parseSelfSpotCommand("QRV pota:park hunters first!"), { comment: "QRV park hunters first!", source: "pota" })
  assert.deepEqual(parseSelfSpotCommand("qrt discord:"), { comment: "QRT", source: "discord" })
})

test("parseSelfSpotCommand: unrelated input doesn't match", () => {
  assert.equal(parseSelfSpotCommand("K1ABC"), null)
  assert.equal(parseSelfSpotCommand("SPOTLAST"), null) // handled by parseLastSpotCommand instead
  assert.equal(parseSelfSpotCommand(""), null)
})

test("parseLastSpotCommand: SPOTLAST, SPOTEM, SPOTTHEM, SPTHEM all match bare, case-insensitively", () => {
  for (const trigger of ["SPOTLAST", "SPOTEM", "SPOTTHEM", "SPTHEM", "spotlast"]) {
    assert.deepEqual(parseLastSpotCommand(trigger), { comment: "" }, trigger)
  }
})

test("parseLastSpotCommand: text after a space or a slash is the comment, as SPOT's is", () => {
  assert.deepEqual(parseLastSpotCommand("SPOTTHEM nice signal"), { comment: "nice signal" })
  assert.deepEqual(parseLastSpotCommand("spotlast/QSB, try again"), { comment: "QSB, try again" })
})

test("parseLastSpotCommand: a source named first goes with the spot, as SPOT's does", () => {
  assert.deepEqual(parseLastSpotCommand("SPOTLAST sota: nice signal"), { comment: "nice signal", source: "sota" })
  assert.deepEqual(parseLastSpotCommand("SPOTTHEM/cluster:"), { comment: "", source: "cluster" })
  assert.deepEqual(parseLastSpotCommand("SPOTLAST QSB at 14:30"), { comment: "QSB at 14:30" })
})

test("parseLastSpotCommand: a call that merely starts with the word is not the command", () => {
  // SPOTEMX would otherwise spot the last QSO with comment "X".
  assert.equal(parseLastSpotCommand("SPOTEMX"), null)
  assert.equal(parseLastSpotCommand("SPOT"), null)
  assert.equal(parseLastSpotCommand("K1ABC"), null)
})

// Bare RESPOT leaves the interval to the app: a number here would override
// the operator's own setting, which only the app can read.
test("parseRespotCommand: bare RESPOT names no interval, a number is that many", () => {
  assert.deepEqual(parseRespotCommand("RESPOT"), {})
  assert.deepEqual(parseRespotCommand("respot 7"), { minutes: 7 })
  assert.deepEqual(parseRespotCommand("RESPOT 30"), { minutes: 30 })
})

// What the confirmation promises has to be what the app does, and the app
// holds RESPOT between five and sixty minutes.
test("parseRespotCommand: fewer than five minutes is five, more than sixty is sixty", () => {
  assert.deepEqual(parseRespotCommand("RESPOT 1"), { minutes: 5 })
  assert.deepEqual(parseRespotCommand("RESPOT 40000"), { minutes: 60 })
})

test("parseRespotCommand: OFF and 0 stop it", () => {
  assert.deepEqual(parseRespotCommand("RESPOT OFF"), { off: true })
  assert.deepEqual(parseRespotCommand("respot off"), { off: true })
  assert.deepEqual(parseRespotCommand("RESPOT 0"), { off: true })
})

// Recognized but wrong, so the operator is told how to use it rather than
// having "RESPOT FIVE" fall through to the callsign.
test("parseRespotCommand: any other parameter is invalid, anything else is not RESPOT", () => {
  assert.deepEqual(parseRespotCommand("RESPOT FIVE"), { invalid: true })
  assert.deepEqual(parseRespotCommand("RESPOT 5.5"), { invalid: true })
  assert.equal(parseRespotCommand("RESPOTS"), null)
  assert.equal(parseRespotCommand("SPOT"), null)
})

test("isClusterCommand: the whole word only, so a call starting with it still logs", () => {
  assert.equal(isClusterCommand("CLUSTER"), true)
  assert.equal(isClusterCommand(" cluster "), true)
  assert.equal(isClusterCommand("CLUSTERS"), false)
  assert.equal(isClusterCommand("CLUSTER SH/DX"), false)
})

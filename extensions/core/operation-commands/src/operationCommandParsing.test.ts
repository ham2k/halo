// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Run with `node --experimental-strip-types --test` (see package.json).
//
// Both commands are typed into the CALL field, so every non-match here is a
// callsign that must still log normally, and every match is a word that must
// not: "OPERATOR" left unrecognized is a QSO with a nonsense call in it.

import { test } from "node:test"
import assert from "node:assert/strict"

import { parseOperatorCommand, parsePositionCommand, parseSegmentCommand, positionValueFor } from "./operationCommandParsing.ts"

test("parseOperatorCommand: OPER and the longer OPERATOR both take a callsign", () => {
  assert.deepEqual(parseOperatorCommand("OPER KI2D"), { call: "KI2D" })
  assert.deepEqual(parseOperatorCommand("OPERATOR KI2D"), { call: "KI2D" })
})

test("parseOperatorCommand: a slash separator works the same as a space", () => {
  // What an operator already types when adding a suffix to a callsign.
  assert.deepEqual(parseOperatorCommand("OPER/KI2D"), { call: "KI2D" })
})

test("parseOperatorCommand: input is normalized to uppercase, like every other callsign", () => {
  assert.deepEqual(parseOperatorCommand("oper ki2d"), { call: "KI2D" })
})

test("parseOperatorCommand: the bare word is recognized with nothing to run yet", () => {
  // Not null: null would let Enter log "OPER" as a contact.
  assert.deepEqual(parseOperatorCommand("OPER"), { call: "" })
  assert.deepEqual(parseOperatorCommand("OPERATOR"), { call: "" })
})

test("parseOperatorCommand: a callsign that merely starts with the word is not the command", () => {
  assert.equal(parseOperatorCommand("OPERA"), null)
  assert.equal(parseOperatorCommand("K1ABC"), null)
  assert.equal(parseOperatorCommand(""), null)
})

test("parsePositionCommand: a number is taken as the position", () => {
  assert.deepEqual(parsePositionCommand("POSITION 2"), { position: "2", invalid: false })
  assert.deepEqual(parsePositionCommand("POSITION/2"), { position: "2", invalid: false })
})

test("parsePositionCommand: the bare word is recognized, with nothing to run yet", () => {
  assert.deepEqual(parsePositionCommand("POSITION"), { position: "", invalid: false })
})

test("parsePositionCommand: anything but a whole number is flagged, never guessed at", () => {
  // The value ends up inside a callsign on the air, so "POSITION LEFT" has to
  // be reported rather than coerced into some number.
  assert.deepEqual(parsePositionCommand("POSITION LEFT"), { position: "LEFT", invalid: true })
  assert.deepEqual(parsePositionCommand("POSITION 2.5"), { position: "2.5", invalid: true })
})

test("parsePositionCommand: a number too long to be a position is refused, not coerced", () => {
  // `String(Number("12345678901234567890"))` is a DIFFERENT number, and it
  // would go on the air as the operator's callsign.
  assert.equal(parsePositionCommand("POSITION 100")?.invalid, true)
  assert.equal(parsePositionCommand("POSITION 12345678901234567890")?.invalid, true)
})

test("parsePositionCommand: unrelated input doesn't match", () => {
  assert.equal(parsePositionCommand("POS 2"), null)
  assert.equal(parsePositionCommand("K1ABC"), null)
})

test("parseSegmentCommand: each word names its segment kind", () => {
  assert.deepEqual(parseSegmentCommand("START"), { kind: 'start', setLocation: false })
  assert.deepEqual(parseSegmentCommand("BREAK"), { kind: 'break', setLocation: false })
  assert.deepEqual(parseSegmentCommand("STOP"), { kind: 'stop', setLocation: false })
  // END is polo's alias for STOP, and writes the same `stop` row.
  assert.deepEqual(parseSegmentCommand("END"), { kind: 'stop', setLocation: false })
  assert.deepEqual(parseSegmentCommand("roverqth"), { kind: 'break', setLocation: true })
})

test("parseSegmentCommand: the whole word and nothing longer", () => {
  // A prefix match would swallow a callsign that starts with the word.
  assert.equal(parseSegmentCommand("ROVERQTH1"), null)
  assert.equal(parseSegmentCommand("STOPX"), null)
  assert.equal(parseSegmentCommand("ROVER"), null)
  assert.equal(parseSegmentCommand(""), null)
})

test("positionValueFor: 0 means no position, which is how a typed command undoes one", () => {
  assert.equal(positionValueFor("0"), "")
  assert.equal(positionValueFor("00"), "")
  assert.equal(positionValueFor("2"), "2")
  // Leading zeros normalize, so "/OP02" can't reach the air.
  assert.equal(positionValueFor("02"), "2")
})

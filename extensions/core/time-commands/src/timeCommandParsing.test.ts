// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Run with `node --experimental-strip-types --test` (see package.json).
//
// Typed into the CALL field: every non-match here is a callsign or a
// frequency that must still reach its own handler, and every match is text
// that must not log as a contact.

import { test } from "node:test"
import assert from "node:assert/strict"

import { clampDay, parseTimeCommand } from "./timeCommandParsing.ts"

const MINUTE = 60 * 1000

test("a signed number moves the time, in minutes unless it says otherwise", () => {
  assert.deepEqual(parseTimeCommand("+1"), { kind: "delta", deltaMillis: MINUTE, label: "+1m" })
  assert.deepEqual(parseTimeCommand("+1M"), { kind: "delta", deltaMillis: MINUTE, label: "+1m" })
  assert.deepEqual(parseTimeCommand("+30s"), { kind: "delta", deltaMillis: 30 * 1000, label: "+30s" })
  assert.deepEqual(parseTimeCommand("-1H"), { kind: "delta", deltaMillis: -60 * MINUTE, label: "-1h" })
  assert.deepEqual(parseTimeCommand("+3d"), { kind: "delta", deltaMillis: 3 * 24 * 60 * MINUTE, label: "+3d" })
})

test("the sign is required: a bare number is a frequency or a band", () => {
  assert.equal(parseTimeCommand("14285"), null)
  assert.equal(parseTimeCommand("20M"), null)
  assert.equal(parseTimeCommand("1M"), null)
})

test("a move past a century is refused here, before the app's Duration can wrap", () => {
  assert.deepEqual(parseTimeCommand("+40000d"), { kind: "error", error: "tooFar" })
})

test("HH:MM[:SS] sets the time, :MM the minutes only and ::SS the seconds only", () => {
  assert.deepEqual(parseTimeCommand("12:33"), { kind: "time", hour: 12, minute: 33 })
  assert.deepEqual(parseTimeCommand("7:05"), { kind: "time", hour: 7, minute: 5 })
  assert.deepEqual(parseTimeCommand("12:33:30"), { kind: "time", hour: 12, minute: 33, second: 30 })
  assert.deepEqual(parseTimeCommand(":34"), { kind: "minute", minute: 34 })
  assert.deepEqual(parseTimeCommand("::30"), { kind: "second", second: 30 })
})

test("an impossible time is an error, not a callsign", () => {
  assert.deepEqual(parseTimeCommand("25:00"), { kind: "error", error: "badTime" })
  assert.deepEqual(parseTimeCommand("12:60"), { kind: "error", error: "badTime" })
  assert.deepEqual(parseTimeCommand(":75"), { kind: "error", error: "badTime" })
  assert.deepEqual(parseTimeCommand("12:33:60"), { kind: "error", error: "badTime" })
  assert.deepEqual(parseTimeCommand("::60"), { kind: "error", error: "badTime" })
})

test("a time still being typed is not yet a command", () => {
  assert.equal(parseTimeCommand("12:3"), null)
  assert.equal(parseTimeCommand(":3"), null)
  assert.equal(parseTimeCommand("12:33:3"), null)
  assert.equal(parseTimeCommand("::3"), null)
  assert.equal(parseTimeCommand("+"), null)
})

test("a date reads in the device's order", () => {
  assert.deepEqual(parseTimeCommand("3/18", "mdy"), { kind: "date", month: 3, day: 18 })
  assert.deepEqual(parseTimeCommand("18/3", "dmy"), { kind: "date", month: 3, day: 18 })
  // A year-first region still writes the month before the day.
  assert.deepEqual(parseTimeCommand("3/18", "ymd"), { kind: "date", month: 3, day: 18 })
  // The same text, read the other way, is a different date — or none.
  assert.deepEqual(parseTimeCommand("3/4", "dmy"), { kind: "date", month: 4, day: 3 })
  assert.deepEqual(parseTimeCommand("3/18", "dmy"), { kind: "error", error: "badDate" })
})

test("a day the month does not have is an error; Feb 29 is left to the year", () => {
  assert.deepEqual(parseTimeCommand("4/31", "mdy"), { kind: "error", error: "badDate" })
  assert.deepEqual(parseTimeCommand("2/29", "mdy"), { kind: "date", month: 2, day: 29 })
})

test("a portable callsign is not a date", () => {
  assert.equal(parseTimeCommand("W1AW/3"), null)
  assert.equal(parseTimeCommand("3D2/W1AW"), null)
})

test("NOW, in any case", () => {
  assert.deepEqual(parseTimeCommand("now"), { kind: "now" })
  assert.deepEqual(parseTimeCommand("NOW"), { kind: "now" })
  assert.equal(parseTimeCommand("NOWA"), null)
})

test("a Feb 29 lands on the 28th only in a common year", () => {
  assert.equal(clampDay(2, 29, 2025), 28)
  assert.equal(clampDay(2, 29, 2024), 29)
  assert.equal(clampDay(2, 29, 2000), 29)
  assert.equal(clampDay(2, 29, 1900), 28)
  assert.equal(clampDay(3, 29, 2025), 29)
})

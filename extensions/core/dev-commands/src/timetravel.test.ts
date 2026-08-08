// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { describe, it } from "node:test"
import assert from "node:assert/strict"

import { describeTimeTravel, parseTimeTravelCommand } from "./timetravel.ts"

const HOUR = 60 * 60 * 1000
const DAY = 24 * HOUR

describe("parseTimeTravelCommand", () => {
  it("does not claim other commands", () => {
    // The trap: a greedy pattern that swallowed DEVTESTER would shadow a real
    // command, which reads as that command disappearing.
    for (const input of ["SEED 10", "DEVTESTER", "DEVMODE", "TT", "W1AW", ""]) {
      assert.equal(parseTimeTravelCommand(input), null, input)
    }
  })

  it("accepts both names, either case", () => {
    for (const input of ["DEVTT", "devtt", "DEVTIMETRAVEL", "DevTimeTravel"]) {
      assert.deepEqual(parseTimeTravelCommand(input), { kind: "reset" }, input)
    }
  })

  it("reads a signed offset in every unit", () => {
    assert.deepEqual(parseTimeTravelCommand("DEVTT +3h"), { kind: "travel", deltaMillis: 3 * HOUR, speed: null })
    assert.deepEqual(parseTimeTravelCommand("DEVTT -1d"), { kind: "travel", deltaMillis: -DAY, speed: null })
    assert.deepEqual(parseTimeTravelCommand("DEVTT 90m"), { kind: "travel", deltaMillis: 90 * 60000, speed: null })
    assert.deepEqual(parseTimeTravelCommand("DEVTT 30s"), { kind: "travel", deltaMillis: 30000, speed: null })
    assert.deepEqual(parseTimeTravelCommand("DEVTT 2w"), { kind: "travel", deltaMillis: 14 * DAY, speed: null })
  })

  it("treats an unsigned offset as forward", () => {
    assert.deepEqual(parseTimeTravelCommand("DEVTT 3h"), parseTimeTravelCommand("DEVTT +3h"))
  })

  it("accepts a fractional offset", () => {
    assert.deepEqual(parseTimeTravelCommand("DEVTT 1.5h"), { kind: "travel", deltaMillis: 1.5 * HOUR, speed: null })
  })

  it("reads a speed factor", () => {
    assert.deepEqual(parseTimeTravelCommand("DEVTT 2x"), { kind: "travel", deltaMillis: 0, speed: 2 })
    assert.deepEqual(parseTimeTravelCommand("DEVTT 0.5x"), { kind: "travel", deltaMillis: 0, speed: 0.5 })
  })

  it("combines an offset and a factor in either order", () => {
    const expected = { kind: "travel", deltaMillis: DAY, speed: 10 }
    assert.deepEqual(parseTimeTravelCommand("DEVTT +1d 10x"), expected)
    assert.deepEqual(parseTimeTravelCommand("DEVTT 10x +1d"), expected)
  })

  it("sums several offsets", () => {
    assert.deepEqual(parseTimeTravelCommand("DEVTT +1d +2h"), {
      kind: "travel",
      deltaMillis: DAY + 2 * HOUR,
      speed: null,
    })
    // Signs mix, so a correction doesn't need retyping the whole thing.
    assert.deepEqual(parseTimeTravelCommand("DEVTT +1d -2h"), {
      kind: "travel",
      deltaMillis: DAY - 2 * HOUR,
      speed: null,
    })
  })

  it("refuses a stopped or reversed clock", () => {
    // Not clamped and not ignored: everything downstream (elapsed labels,
    // sequence numbers, staleness) assumes forward motion, so this has to fail
    // where it can still be reported.
    for (const input of ["DEVTT 0x", "DEVTT -2x"]) {
      const result = parseTimeTravelCommand(input)
      assert.equal(result?.kind, "error", input)
    }
  })

  it("errors on a token it cannot read, rather than ignoring it", () => {
    // Silently dropping "+3hours" would run a bare DEVTT and RESET the clock —
    // the opposite of what was asked.
    for (const input of ["DEVTT +3hours", "DEVTT tomorrow", "DEVTT 3", "DEVTT x2"]) {
      assert.equal(parseTimeTravelCommand(input)?.kind, "error", input)
    }
  })

  it("refuses an offset beyond the clock's range, before it can wrap", () => {
    // The app receives MILLISECONDS and builds a Duration, whose int64
    // microsecond field wraps instead of throwing — so a number this size
    // arrives already wrapped and the app's own bound compares something
    // unrelated to what was typed. Here is the last place the real magnitude
    // exists.
    for (const input of ["DEVTT 99999999w", "DEVTT -99999999w", "DEVTT 40000d"]) {
      assert.equal(parseTimeTravelCommand(input)?.kind, "error", input)
    }
    // A century is the documented limit, so just inside it still parses.
    assert.equal(parseTimeTravelCommand("DEVTT 36000d")?.kind, "travel")
  })

  it("refuses a speed past the cap, naming it", () => {
    const result = parseTimeTravelCommand("DEVTT 5000x")
    assert.equal(result?.kind, "error")
    assert.match((result as { error: string }).error, /1000x/)
    assert.equal(parseTimeTravelCommand("DEVTT 1000x")?.kind, "travel", "the cap itself is allowed")
  })

  it("refuses two speeds rather than silently taking the last", () => {
    // Documented as "at most one speed factor"; quietly dropping one leaves the
    // operator believing the clock runs at a rate it doesn't.
    assert.equal(parseTimeTravelCommand("DEVTT 2x 3x")?.kind, "error")
  })

  it("errors on arguments that would silently reset", () => {
    assert.equal(parseTimeTravelCommand("DEVTT +0h")?.kind, "error")
  })

  it("ignores surrounding and repeated whitespace", () => {
    assert.deepEqual(parseTimeTravelCommand("  DEVTT   +3h    2x  "), {
      kind: "travel",
      deltaMillis: 3 * HOUR,
      speed: 2,
    })
  })
})

describe("describeTimeTravel", () => {
  it("describes each shape", () => {
    assert.equal(describeTimeTravel({ kind: "reset" }), "Return to real time?")
    assert.equal(
      describeTimeTravel({ kind: "travel", deltaMillis: 3 * HOUR, speed: null }),
      "Jump 3h forward?",
    )
    assert.equal(
      describeTimeTravel({ kind: "travel", deltaMillis: -DAY, speed: null }),
      "Jump 1d back?",
    )
    assert.equal(
      describeTimeTravel({ kind: "travel", deltaMillis: 0, speed: 2 }),
      "Run at 2x?",
    )
    assert.equal(
      describeTimeTravel({ kind: "travel", deltaMillis: DAY + 2 * HOUR, speed: 2 }),
      "Jump 1d 2h forward and run at 2x?",
    )
  })

  it("renders a sub-unit duration in the units it has", () => {
    assert.equal(
      describeTimeTravel({ kind: "travel", deltaMillis: 90 * 60000, speed: null }),
      "Jump 1h 30m forward?",
    )
    assert.equal(
      describeTimeTravel({ kind: "travel", deltaMillis: 30000, speed: null }),
      "Jump 30s forward?",
    )
  })
})

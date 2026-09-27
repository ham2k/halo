// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT

import { test } from "node:test"
import assert from "node:assert/strict"

import { contestArithmetic, contestSummary } from "./contestSummary.ts"

const ctx = { online: false } as never

test("the title names the contest and its score, and the arithmetic opens the detail", () => {
  const summary = contestSummary(
    {
      key: "cqwpx",
      scope: "operation",
      icon: "flag-checkered",
      title: "CQWPX SSB",
      total: 6,
      arithmetic: "2 QSOs, 2 pts × 3 mults",
      detail: "**20m**: 2 QSOs",
    },
    ctx,
  )
  assert.equal(summary.cqwpx.label, "CQWPX SSB: 6 points")
  // A blank line, so the arithmetic reads as its own paragraph above the
  // contest's tables rather than as their first row.
  assert.equal(summary.cqwpx.longSummary, "2 QSOs, 2 pts × 3 mults\n\n**20m**: 2 QSOs")
  assert.equal(summary.cqwpx.for, "operation")
})

test("one point is a point", () => {
  const summary = contestSummary({ key: "c", scope: "operation", icon: "star", title: "NYQP", total: 1, arithmetic: "" }, ctx)
  assert.equal(summary.c.label, "NYQP: 1 point")
})

// A contest's multipliers run the whole event; a day's share of the score is a
// number no sponsor defines, so no contest gets to publish one.
test("the day scope has no summary", () => {
  assert.deepEqual(contestSummary({ key: "c", scope: "day", icon: "star", title: "NYQP", total: 10, arithmetic: "" }, ctx), {})
})

test("points times multipliers, with the kinds of multiplier and a bonus on top", () => {
  assert.equal(
    contestArithmetic({ qsos: 45, points: 90, mults: 15, multParts: ["12 counties", "3 states"], bonus: 100 }, ctx),
    "45 QSOs, 90 pts × 15 mults (12 counties, 3 states) + 100 bonus",
  )
})

// Where the rules add the bonus before multiplying, writing it after would
// state a different, smaller score than the one shown in the title.
test("a bonus folded in before the multiplier is written inside it", () => {
  assert.equal(
    contestArithmetic({ qsos: 45, points: 90, mults: 15, bonus: 100, bonusFirst: true, factor: { count: 2, noun: "power" } }, ctx),
    "45 QSOs, (90 pts + 100 bonus) × 15 mults × 2 power",
  )
})

// Rounded to a whole number, 1.5 reads as 2 — an arithmetic line that no
// longer multiplies out to the title above it.
test("a fractional factor keeps its fraction", () => {
  assert.equal(contestArithmetic({ qsos: 1, points: 100, mults: 10, factor: { count: 1.5, noun: "power" } }, ctx), "1 QSO, 100 pts × 10 mults × 1.5 power")
})

test("a multiplier the contest names in its own words", () => {
  assert.equal(contestArithmetic({ qsos: 1, points: 1, mults: 2, multsNoun: "power" }, ctx), "1 QSO, 1 pt × 2 power")
})

test("a contest that scores only its contacts, or a distance, says so", () => {
  assert.equal(contestArithmetic({ qsos: 45 }, ctx), "45 QSOs")
  assert.equal(contestArithmetic({ qsos: 45, points: 1234, more: ["5,678 km"] }, ctx), "45 QSOs, 1,234 pts, 5,678 km")
})

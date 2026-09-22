// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Run with `node --experimental-strip-types --test` (see package.json).

import { test } from "node:test"
import assert from "node:assert/strict"

import { FALLBACK_CALLS, MAX_SEED_COUNT, existingStatsFromQsos, mutateCall, parseSeedCommand, randomRST, seedPlan, seedableCallsFrom } from "./seed.ts"

/// Deterministic "random" that cycles through the given values.
function fakeRandom(values: number[]): () => number {
  let i = 0
  return () => values[i++ % values.length]
}

test("parseSeedCommand: bare SEED defaults to 10, count and spread parse, garbage is not a command", () => {
  assert.deepEqual(parseSeedCommand("SEED"), { complete: true, count: 10 })
  assert.deepEqual(parseSeedCommand("seed 20"), { complete: true, count: 20 })
  assert.deepEqual(parseSeedCommand("SEED 15 3h"), {
    complete: true,
    count: 15,
    spreadMillis: 3 * 3_600_000,
    spreadLabel: "3H",
  })
  assert.equal(parseSeedCommand("SEED 5 90M")?.spreadMillis, 90 * 60_000)
  assert.equal(parseSeedCommand("SEED 5 2D")?.spreadMillis, 2 * 86_400_000)
  assert.equal(parseSeedCommand("SEED 5 0.5H")?.spreadMillis, 30 * 60_000)
  assert.equal(parseSeedCommand("SEEDS"), null)
  assert.equal(parseSeedCommand("SEED XYZ"), null)
  assert.equal(parseSeedCommand("W1AW"), null)
})

test("parseSeedCommand: spread amount without its unit yet is recognized but incomplete", () => {
  assert.equal(parseSeedCommand("SEED 15 3")?.complete, false)
  assert.equal(parseSeedCommand("SEED 15 3H")?.complete, true)
})

test("parseSeedCommand: count is clamped to a sane range", () => {
  assert.equal(parseSeedCommand("SEED 0")?.count, 1)
  assert.equal(parseSeedCommand("SEED 99999")?.count, MAX_SEED_COUNT)
})

test("parseSeedCommand: a zero spread is ignored rather than producing an empty window", () => {
  assert.deepEqual(parseSeedCommand("SEED 5 0H"), { complete: true, count: 5 })
})

test("existingStatsFromQsos: counts real contacts and finds the time range, skipping event markers", () => {
  const qsos = [
    { band: "event", startAtMillis: 500, event: { event: "start" } }, // must not anchor the window
    { band: "20m", startAtMillis: 2_000 },
    { band: "20m", startAtMillis: 1_000 },
    { band: "40m", startAtMillis: 3_000 },
    { band: "40m" }, // no timestamp — counted, but can't contribute to the range
  ]
  assert.deepEqual(existingStatsFromQsos(qsos), { count: 4, startAtMillisMin: 1_000, startAtMillisMax: 3_000 })
})

test("existingStatsFromQsos: an empty log yields count 0 and no range", () => {
  assert.deepEqual(existingStatsFromQsos([]), { count: 0, startAtMillisMin: undefined, startAtMillisMax: undefined })
})

test("seedPlan: with a spread, times are ascending and inside the window ending now", () => {
  const now = 1_700_000_000_000
  const spread = 3 * 3_600_000
  const plan = seedPlan({ count: 20, spreadMillis: spread, nowMillis: now, random: Math.random })
  assert.equal(plan.startTimes.length, 20)
  assert.equal(plan.beforeExisting, false)
  for (let i = 0; i < plan.startTimes.length; i++) {
    assert.ok(plan.startTimes[i] >= now - spread && plan.startTimes[i] <= now)
    if (i > 0) assert.ok(plan.startTimes[i] >= plan.startTimes[i - 1])
  }
})

test("seedPlan: window ends at the earliest existing QSO when the log spans under 1/3 of the spread", () => {
  const now = 1_700_000_000_000
  const spread = 3 * 3_600_000
  const earliest = now - 30 * 60_000
  // Existing log spans 10 minutes — far less than 1h (a third of 3h).
  const existing = { count: 5, startAtMillisMin: earliest, startAtMillisMax: earliest + 10 * 60_000 }
  const plan = seedPlan({ count: 15, spreadMillis: spread, nowMillis: now, existing, random: Math.random })
  assert.equal(plan.beforeExisting, true)
  for (const at of plan.startTimes) {
    assert.ok(at >= earliest - spread && at <= earliest)
  }
})

test("seedPlan: window stays anchored to now when the log already spans 1/3 of the spread or more", () => {
  const now = 1_700_000_000_000
  const spread = 3 * 3_600_000
  const existing = { count: 50, startAtMillisMin: now - 2 * 3_600_000, startAtMillisMax: now - 60_000 }
  const plan = seedPlan({ count: 15, spreadMillis: spread, nowMillis: now, existing, random: Math.random })
  assert.equal(plan.beforeExisting, false)
  for (const at of plan.startTimes) {
    assert.ok(at >= now - spread && at <= now)
  }
})

test("seedPlan: an empty log keeps the window anchored to now", () => {
  const now = 1_700_000_000_000
  const plan = seedPlan({ count: 5, spreadMillis: 3_600_000, nowMillis: now, existing: { count: 0 }, random: Math.random })
  assert.equal(plan.beforeExisting, false)
})

test("seedPlan: without a spread, times walk back from now with gaps of at least 5s", () => {
  const now = 1_700_000_000_000
  const plan = seedPlan({ count: 10, nowMillis: now, random: Math.random })
  assert.equal(plan.startTimes.length, 10)
  let previous = now
  for (const at of [...plan.startTimes].reverse()) {
    assert.ok(at <= previous - 5_000)
    previous = at
  }
})

test("randomRST: leans on 59/57/55 for phone modes and appends tone 9 for CW/RTTY", () => {
  // First random() picks strength (0 -> 9, the heaviest bucket).
  assert.equal(randomRST("SSB", fakeRandom([0])), "59")
  assert.equal(randomRST("SSB", fakeRandom([0.5])), "57") // past 9's 0.38, inside 7's 0.27
  assert.equal(randomRST("SSB", fakeRandom([0.7])), "55") // past 0.38 + 0.27, inside 5's 0.18
  assert.equal(randomRST("CW", fakeRandom([0])), "599")
  assert.equal(randomRST("RTTY", fakeRandom([0.4])), "579")
  // Weak strength (past 0.97 -> 2) drops readability to 3 or 4.
  assert.equal(randomRST("SSB", fakeRandom([0.995, 0])), "32")
  // Statistical sanity: most reports are 55/57/59.
  let leaning = 0
  for (let i = 0; i < 1000; i++) {
    const rst = randomRST("SSB")
    assert.match(rst, /^[3-5][2-9]$/)
    if (rst === "59" || rst === "57" || rst === "55") leaning++
  }
  assert.ok(leaning > 650, `expected most of 1000 RSTs to be 55/57/59, got ${leaning}`)
})

test("seedableCallsFrom: keeps callsign-shaped keys, drops keywords and compound calls", () => {
  const keys = ["KI2D", "W1AW", "9A1AA", "DAN", "HAMS", "EA3/KI2D", "N0CALL"]
  assert.deepEqual(seedableCallsFrom(keys), ["KI2D", "W1AW", "9A1AA", "N0CALL"])
})

test("mutateCall: replaces the digit or a suffix letter, never a no-op", () => {
  // random() < 0.5 -> digit branch: 2 + 1 + 0 -> 3
  assert.equal(mutateCall("KI2D", fakeRandom([0, 0])), "KI3D")
  // random() >= 0.5 -> suffix branch: index 0 of 'D', +1 -> 'E'
  assert.equal(mutateCall("KI2D", fakeRandom([0.9, 0, 0])), "KI2E")
  // Unparseable calls come back unchanged.
  assert.equal(mutateCall("EA3/KI2D", Math.random), "EA3/KI2D")
  for (let i = 0; i < 200; i++) {
    const mutated = mutateCall("LB4FH")
    assert.notEqual(mutated, "LB4FH")
    assert.match(mutated, /^[A-Z0-9]*\d[A-Z]+$/)
  }
})

test("FALLBACK_CALLS are themselves seedable", () => {
  assert.deepEqual(seedableCallsFrom(FALLBACK_CALLS), FALLBACK_CALLS)
})

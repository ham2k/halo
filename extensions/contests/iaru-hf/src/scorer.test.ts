// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// IARU HF's exchange is the part a port gets wrong quietly: one field carries
// three different kinds of value, and which kind it is decides both the points
// and the multiplier. A misclassification produces a plausible score that is
// simply not what the sponsor will compute. These encode WHY each value is
// what it is.
//
// Callsigns resolve against the bundled country file (no network). ITU zones,
// which are NOT the CQ zones the other contests use: N0DEV → K/NA 7, W1AW →
// K/NA 8, VE3XYZ → VE/NA 4, DL1ABC → DL/EU 28, JA1ABC → JA/AS 45.

import { test } from "node:test"
import assert from "node:assert/strict"

import { IARUHFScorer, normalizeZone, ourExchange, parseExchange } from "./scorer.ts"
import type { JSONValue } from "@ham2k/extension-sdk"

const ctx = { online: false } as never

/// A US station, so "our continent" is NA and our ITU zone is 8.
const usOperation = { uuid: "op", stationCall: "N0DEV" }
const mixedRef = { type: "iaru-hf", modeRestriction: "Mixed", stationType: "normal", zone: "8" }

function qso(call: string, band = "20m", mode = "CW", theirExchange?: string): Record<string, JSONValue> {
  return {
    their: { call },
    band,
    mode,
    ...(theirExchange ? { refs: [{ type: "iaru-hf", theirExchange }] } : {}),
  }
}

function run(qsos: Record<string, JSONValue>[], operation = usOperation, ref: Record<string, JSONValue> = mixedRef) {
  let sheet = IARUHFScorer.startScoresheet({ operation, ref }, ctx)
  const scores = qsos.map((q) => {
    const r = IARUHFScorer.scoreQso({ scoresheet: sheet, qso: q, operation, ref, isNewDay: false }, ctx)
    sheet = r.scoresheet
    return r.score
  })
  return { sheet, scores }
}

test("one exchange field, three kinds of value", () => {
  // The classification IS the rule. An office is letters-and-digits, a zone is
  // digits, a society is neither — and getting the order wrong turns R1 into a
  // society named R1.
  assert.deepEqual(parseExchange("R1"), { kind: "official", value: "R1" })
  assert.deepEqual(parseExchange("ac"), { kind: "official", value: "AC" })
  assert.deepEqual(parseExchange("08"), { kind: "zone", value: "8" })
  assert.deepEqual(parseExchange("8"), { kind: "zone", value: "8" })
  assert.deepEqual(parseExchange("arrl"), { kind: "hq", value: "ARRL" })
  assert.deepEqual(parseExchange(""), { kind: "none" })
  assert.deepEqual(parseExchange(undefined), { kind: "none" })
})

test("zones normalize so 08 and 8 are one multiplier, not two", () => {
  assert.equal(normalizeZone("08"), "8")
  assert.equal(normalizeZone(8), "8")
  assert.equal(normalizeZone("0"), "")
  assert.equal(normalizeZone("abc"), "")
  // Out of range is kept as a zone on purpose — see normalizeZone's comment.
  assert.equal(normalizeZone("99"), "99")

  const { sheet } = run([qso("DL1ABC", "20m", "CW", "28"), qso("DL2ABC", "20m", "CW", "028")])
  assert.equal(Object.keys(sheet.mults).length, 1, "one zone, however it was written")
})

test("points are 1 in our own zone, 3 on our continent, 5 across an ocean", () => {
  const { scores } = run([
    qso("W1AW", "20m", "CW", "8"), // our own ITU zone
    qso("VE3XYZ", "20m", "CW", "4"), // different zone, same continent
    qso("DL1ABC", "20m", "CW", "28"), // another continent
  ])
  assert.equal(scores[0].value, 1)
  assert.equal(scores[1].value, 3)
  assert.equal(scores[2].value, 5)
})

test("HQ and official stations are worth 1 wherever they are", () => {
  // The rule that reads oddly and is right: an HQ station across the world is
  // worth the same as one next door, because the HQ branch never asks about
  // zones or continents.
  const { scores } = run([qso("JA1ZLO", "20m", "CW", "JARL"), qso("W1AW", "15m", "CW", "ARRL"), qso("NU1AW", "20m", "CW", "AC")])
  assert.deepEqual(
    scores.map((s) => s.value),
    [1, 1, 1],
  )
})

test("a society and an office that share a name are different multipliers", () => {
  // Nothing stops a society abbreviating to "R1". Namespacing the HQ mult is
  // what keeps it from silently merging with the IARU Region 1 office.
  const { sheet } = run([qso("W1AW", "20m", "CW", "R1"), qso("DL1ABC", "20m", "CW", "ARRL")])
  assert.deepEqual(Object.keys(sheet.mults).sort(), ["20m|HQ:ARRL", "20m|R1"])
})

test("multipliers are per band, so the same zone counts again on 15m", () => {
  const { sheet } = run([qso("DL1ABC", "20m", "CW", "28"), qso("DL2ABC", "15m", "CW", "28")])
  assert.deepEqual(Object.keys(sheet.mults).sort(), ["15m|Z28", "20m|Z28"])
  assert.equal(sheet.points, 10, "two 5-point QSOs")

  const summary = IARUHFScorer.summarizeScore({ scoresheet: sheet, operation: usOperation, ref: mixedRef, scope: "operation" }, ctx)
  assert.equal(summary["iaru-hf"].total, 20, "10 points x 2 mults")
})

test("a station may be worked once per band PER MODE", () => {
  // This is where IARU differs from CQ WW, and it is worth real points: the
  // same station on the same band in the other mode is a fresh contact.
  const { scores } = run([qso("DL1ABC", "20m", "CW", "28"), qso("DL1ABC", "20m", "SSB", "28"), qso("DL1ABC", "20m", "CW", "28")])
  assert.equal(scores[0].value, 5)
  assert.equal(scores[1].value, 5, "phone is a separate contact from CW")
  assert.ok(scores[1].notices?.includes("newMode"))
  assert.equal(scores[2].value, 0)
  assert.ok(scores[2].alerts?.includes("duplicate"))
})

test("sub-modes count as their family, so USB and LSB are both phone", () => {
  const { scores } = run([qso("DL1ABC", "20m", "USB", "28"), qso("DL1ABC", "20m", "LSB", "28")])
  assert.equal(scores[0].value, 5)
  assert.equal(scores[1].value, 0, "LSB is the same phone contact as USB")
  assert.ok(scores[1].alerts?.includes("duplicate"))
})

test("digital never counts, even in the Mixed category", () => {
  // "Mixed" means CW and phone, not "anything" — an FT8 QSO is not an IARU
  // contact at all.
  const { scores } = run([qso("DL1ABC", "20m", "FT8", "28")])
  assert.equal(scores[0].value, 0)
  assert.ok(scores[0].alerts?.includes("invalidMode"))
})

test("the entry category restricts what scores", () => {
  const cwOnly = { type: "iaru-hf", modeRestriction: "CW", stationType: "normal", zone: "8" }
  const { scores } = run([qso("DL1ABC", "20m", "SSB", "28"), qso("DL2ABC", "20m", "CW", "28")], usOperation, cwOnly)
  assert.ok(scores[0].alerts?.includes("invalidMode"))
  assert.equal(scores[1].value, 5)

  const phoneOnly = { type: "iaru-hf", modeRestriction: "Phone", stationType: "normal", zone: "8" }
  const { scores: phone } = run([qso("DL1ABC", "20m", "CW", "28")], usOperation, phoneOnly)
  assert.ok(phone[0].alerts?.includes("invalidMode"))
})

test("WARC bands are excluded by the rules", () => {
  const { scores } = run([qso("DL1ABC", "30m", "CW", "28")])
  assert.equal(scores[0].value, 0)
  assert.ok(scores[0].alerts?.includes("invalidBand"))
})

test("an unsent exchange falls back to the country file rather than scoring nothing", () => {
  // A QSO logged in a hurry still counts, at the zone the callsign implies.
  const { scores, sheet } = run([qso("DL1ABC", "20m", "CW")])
  assert.equal(scores[0].value, 5, "DL is zone 28, another continent")
  assert.deepEqual(Object.keys(sheet.mults), ["20m|Z28"])
})

test("a QSO with no exchange still occupies its dupe slot", () => {
  // An unscored contact is still a contact. If the exchange-less QSO were
  // skipped outright, the station would never be registered as worked, and
  // working them again on the same band and mode would score full points and
  // claim a multiplier instead of reading as the duplicate it is.
  const noExchange = { their: { call: "QQ1XYZ" }, band: "20m", mode: "CW" } as Record<string, JSONValue>
  const { scores, sheet } = run([noExchange, { ...noExchange, refs: [{ type: "iaru-hf", theirExchange: "28" }] }])

  assert.equal(scores[0].value, 0, "nothing to score it against")
  assert.deepEqual(scores[0].alerts, ["missingExchange"])
  assert.equal(Object.keys(sheet.mults).length, 0, "and no multiplier")

  assert.equal(scores[1].value, 0)
  assert.ok(scores[1].alerts?.includes("duplicate"), "the second is a dupe, not a fresh QSO")
})

test("an exchange the operator deliberately emptied earns no multiplier", () => {
  // Same rule as cqww: an explicit blank is a decision, an absent field is not.
  const { scores, sheet } = run([{ their: { call: "DL1ABC" }, band: "20m", mode: "CW", refs: [{ type: "iaru-hf", theirExchange: "" }] }])
  assert.equal(scores[0].value, 0)
  assert.deepEqual(scores[0].alerts, ["missingExchange"])
  assert.equal(Object.keys(sheet.mults).length, 0)

  // …while a field nobody touched still gets the country file's zone.
  const { sheet: guessed } = run([qso("DL1ABC", "20m", "CW")])
  assert.deepEqual(Object.keys(guessed.mults), ["20m|Z28"])
})

test("our zone comes from setup, because an operator away from home needs it to", () => {
  // N0DEV is a US call, so the country file says zone 8. Operating from Germany
  // it must be possible to say so — and then German stations are the same-zone
  // 1-pointers, not 5.
  const fromGermany = { type: "iaru-hf", modeRestriction: "Mixed", stationType: "normal", zone: "28" }
  const { scores } = run([qso("DL1ABC", "20m", "CW", "28")], usOperation, fromGermany)
  assert.equal(scores[0].value, 1)
})

test("what we send depends on which kind of station we are", () => {
  assert.equal(ourExchange(usOperation, { type: "iaru-hf", stationType: "normal", zone: "8" }), "8")
  assert.equal(
    ourExchange(usOperation, { type: "iaru-hf", stationType: "hq", society: "arrl", zone: "8" }),
    "ARRL",
    "an HQ station sends its society even though a zone is still on the ref",
  )
  assert.equal(ourExchange(usOperation, { type: "iaru-hf", stationType: "official", official: "R2", zone: "8" }), "R2")
  // Hidden form fields keep their values, so reading by "first non-empty"
  // would send the wrong exchange. This pins reading by the discriminator.
  assert.equal(ourExchange(usOperation, { type: "iaru-hf", stationType: "hq", society: "RSGB", official: "AC", zone: "14" }), "RSGB")
  // Not set up yet: the country file's zone for our own call beats an empty
  // exchange in the export. N0DEV is ITU 7 — note the configured '8' the other
  // cases use is a deliberate override, which is the point of having one.
  assert.equal(ourExchange(usOperation, { type: "iaru-hf" }), "7")
})

test("the day summary resets its counters but keeps the running multipliers", () => {
  let sheet = IARUHFScorer.startScoresheet({ operation: usOperation, ref: mixedRef }, ctx)
  const score = (q: Record<string, JSONValue>, isNewDay: boolean) => {
    const r = IARUHFScorer.scoreQso({ scoresheet: sheet, qso: q, operation: usOperation, ref: mixedRef, isNewDay }, ctx)
    sheet = r.scoresheet
  }
  score(qso("DL1ABC", "20m", "CW", "28"), false)
  score(qso("JA1ABC", "20m", "CW", "45"), true)

  const day = IARUHFScorer.summarizeScore({ scoresheet: sheet, operation: usOperation, ref: mixedRef, scope: "day" }, ctx)
  assert.equal(day["iaru-hf"].qsos, 1, "the second day has one QSO")
  assert.equal(day["iaru-hf"].points, 5)
  // …but multipliers are a contest-long tally, so the day is scored against
  // both of them.
  assert.equal(day["iaru-hf"].total, 10)
})

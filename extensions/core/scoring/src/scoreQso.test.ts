// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import { dxccBreakdown, scoreQso, scoreQsos } from "./scoring.ts"
import type { HookContext, JSONValue } from "@ham2k/halo-extension-sdk"

// A minimal HookContext whose getQsos returns the given log — the only field
// scoreQso reads. All callsigns below resolve against the bundled country file
// (W* -> 'K'/US, DL* -> Germany, F* -> France).
function ctxWithLog(qsos: Record<string, JSONValue>[]): HookContext {
  return { online: false, getQsos: async () => qsos }
}

const op = { uuid: "op-1" }

function qso(call: string, band: string, mode: string, extra: Record<string, JSONValue> = {}) {
  return { their: { call }, band, mode, ...extra }
}

// The whole point of rule 3 becoming a tally: an operation's first QSO is new
// on every axis, and saying so about a station nobody has worked yet is noise.
test("scoreQso: the first QSO of an operation is newDXCC only, never newBand/newMode", async () => {
  const notices = await scoreQso(
    { operation: op, qso: qso("W1AW", "20m", "SSB") },
    ctxWithLog([]),
  )
  assert.deepEqual(notices.alerts, [])
  assert.deepEqual(notices.notices, ["newDXCC"])
})

test("scoreQso: a band nobody has worked is silent unless we worked THAT station elsewhere", async () => {
  const notices = await scoreQso(
    { operation: op, qso: qso("DL1ABC", "40m", "CW") },
    // 40m and CW are both new to the operation; DL1ABC is not in the log.
    ctxWithLog([qso("W1AW", "20m", "SSB", { uuid: "q1" })]),
  )
  assert.deepEqual(notices.notices, ["newDXCC"])
})

test("scoreQso: exact call+band+mode already worked is a duplicate", async () => {
  const notices = await scoreQso(
    { operation: op, qso: qso("W1AW", "20m", "SSB") },
    ctxWithLog([qso("W1AW", "20m", "SSB", { uuid: "q1" })]),
  )
  assert.deepEqual(notices.alerts, ["duplicate"])
  // A dupe is neither a new band nor a new mode nor a new entity.
  assert.deepEqual(notices.notices, [])
})

test("scoreQso: same call on a different band is New Band, not a dupe", async () => {
  const notices = await scoreQso(
    { operation: op, qso: qso("W1AW", "40m", "SSB") },
    // 20m already worked (by this and another call) so 40m is new to the op too.
    ctxWithLog([qso("W1AW", "20m", "SSB", { uuid: "q1" })]),
  )
  assert.deepEqual(notices.alerts, [])
  assert.ok(notices.notices.includes("newBand"))
  assert.ok(!notices.notices.includes("duplicate"))
  // Entity already worked — no newDXCC.
  assert.ok(!notices.notices.includes("newDXCC"))
})

test("scoreQso: same call, same band, different mode is New Mode", async () => {
  const notices = await scoreQso(
    { operation: op, qso: qso("W1AW", "20m", "CW") },
    ctxWithLog([qso("W1AW", "20m", "SSB", { uuid: "q1" })]),
  )
  assert.deepEqual(notices.alerts, [])
  assert.ok(notices.notices.includes("newMode"))
  assert.ok(!notices.notices.includes("duplicate"))
})

test("scoreQso: a brand-new entity on an already-worked band/mode is only newDXCC", async () => {
  const notices = await scoreQso(
    { operation: op, qso: qso("DL1ABC", "20m", "SSB") },
    ctxWithLog([qso("W1AW", "20m", "SSB", { uuid: "q1" })]),
  )
  assert.deepEqual(notices.alerts, [])
  assert.deepEqual(notices.notices, ["newDXCC"])
})

test("scoreQso: excludeUuid keeps an edited QSO from flagging itself as a dupe", async () => {
  const notices = await scoreQso(
    { operation: op, qso: qso("W1AW", "20m", "SSB"), excludeUuid: "q1" },
    ctxWithLog([qso("W1AW", "20m", "SSB", { uuid: "q1" })]),
  )
  // With q1 excluded, this candidate looks brand-new, not a dupe.
  assert.deepEqual(notices.alerts, [])
  assert.ok(notices.notices.includes("newDXCC"))
})

test("scoreQso: event markers in the log are ignored", async () => {
  const notices = await scoreQso(
    { operation: op, qso: qso("W1AW", "20m", "SSB") },
    ctxWithLog([{ their: {}, band: "event", mode: "", uuid: "ev" }]),
  )
  assert.ok(notices.notices.includes("newDXCC"))
})

test("scoreQso: no callsign yields no notices", async () => {
  const notices = await scoreQso(
    { operation: op, qso: { their: {}, band: "20m", mode: "SSB" } },
    ctxWithLog([]),
  )
  assert.deepEqual(notices, { notices: [], alerts: [] })
})

// --- Our own DXCC entity ---------------------------------------------------

const usOp = { uuid: "op-us", stationCall: "W1XYZ" }

test("scoreQso: our own entity never notifies, however new it is to the log", async () => {
  const notices = await scoreQso(
    { operation: usOp, qso: qso("W1AW", "20m", "SSB") },
    ctxWithLog([]),
  )
  assert.ok(!notices.notices.includes("newDXCC"))
})

test("scoreQso: another entity still notifies for the same operator", async () => {
  const notices = await scoreQso(
    { operation: usOp, qso: qso("DL1ABC", "20m", "SSB") },
    ctxWithLog([]),
  )
  assert.ok(notices.notices.includes("newDXCC"))
})

// Silent, not uncounted: the entity is worked and belongs in the tally, which
// is what the operation summary and any award export read.
test("scoreQsos: our own entity is counted even though it never notified", async () => {
  const result = await scoreQsos(
    { operation: usOp, qsos: [qso("W1AW", "20m", "SSB", { uuid: "q1" })] },
    ctxWithLog([]),
  )
  const sheet = result.scoresheet as { entities: Record<string, number> }
  assert.equal(sheet.entities.K, 1)
  assert.deepEqual(result.qsoScores.q1.notices ?? [], [])
})

// --- States and provinces --------------------------------------------------

const veOp = { uuid: "op-ve", stationCall: "VE3XYZ" }
const dxOp = { uuid: "op-dx", stationCall: "DL1XYZ" }

test("scoreQso: a US station's state is new the first time and quiet after", async () => {
  const first = await scoreQso(
    { operation: usOp, qso: qso("W1AW", "20m", "SSB", { their: { call: "W1AW", state: "CT" } }) },
    ctxWithLog([]),
  )
  assert.ok(first.notices.includes("newState"))

  const second = await scoreQso(
    { operation: usOp, qso: qso("K1ABC", "20m", "SSB", { their: { call: "K1ABC", state: "CT" } }) },
    ctxWithLog([qso("W1AW", "20m", "SSB", { uuid: "q1", their: { call: "W1AW", state: "CT" } })]),
  )
  assert.ok(!second.notices.includes("newState"))
})

// Both lists apply to either operator: a US op working Canada is told.
test("scoreQso: a Canadian province is newProvince, not newState", async () => {
  const notices = await scoreQso(
    { operation: usOp, qso: qso("VE3ABC", "20m", "SSB", { their: { call: "VE3ABC", state: "ON" } }) },
    ctxWithLog([]),
  )
  assert.ok(notices.notices.includes("newProvince"))
  assert.ok(!notices.notices.includes("newState"))
})

test("scoreQso: a Canadian operator is told about US states too", async () => {
  const notices = await scoreQso(
    { operation: veOp, qso: qso("W1AW", "20m", "SSB", { their: { call: "W1AW", state: "CT" } }) },
    ctxWithLog([]),
  )
  assert.ok(notices.notices.includes("newState"))
})

// The rule is about OUR station, not the one being worked.
test("scoreQso: a DX operator is never told about states or provinces", async () => {
  const notices = await scoreQso(
    { operation: dxOp, qso: qso("W1AW", "20m", "SSB", { their: { call: "W1AW", state: "CT" } }) },
    ctxWithLog([]),
  )
  assert.ok(!notices.notices.includes("newState"))
  assert.ok(!notices.notices.includes("newProvince"))
})

test("scoreQso: the lookup's guessed state counts when the operator typed none", async () => {
  const notices = await scoreQso(
    { operation: usOp, qso: qso("W1AW", "20m", "SSB", { their: { call: "W1AW", guess: { state: "ct" } } }) },
    ctxWithLog([]),
  )
  assert.ok(notices.notices.includes("newState"))
})

// Hawaii and Alaska are their own DXCC entities, so their stations carry no
// state of their own — the entity is the answer.
test("scoreQso: KL and KH6 stations resolve to AK and HI without a state field", async () => {
  const ak = await scoreQso({ operation: usOp, qso: qso("KL7RA", "20m", "SSB") }, ctxWithLog([]))
  assert.ok(ak.notices.includes("newState"))
  const hi = await scoreQso({ operation: usOp, qso: qso("KH6XYZ", "20m", "SSB") }, ctxWithLog([]))
  assert.ok(hi.notices.includes("newState"))
})

// A county, a Mexican state or a country-file artifact must never open a
// bucket in a tally the operator reads as "states worked".
test("scoreQso: a value that is not on either list is no state at all", async () => {
  const notices = await scoreQso(
    { operation: usOp, qso: qso("W1AW", "20m", "SSB", { their: { call: "W1AW", state: "Hartford" } }) },
    ctxWithLog([]),
  )
  assert.ok(!notices.notices.includes("newState"))
})

test("scoreQso: a duplicate carries no newState, like every other notice", async () => {
  const worked = qso("W1AW", "20m", "SSB", { uuid: "q1", their: { call: "W1AW", state: "CT" } })
  const notices = await scoreQso(
    { operation: usOp, qso: qso("W1AW", "20m", "SSB", { their: { call: "W1AW", state: "CT" } }) },
    ctxWithLog([worked]),
  )
  assert.deepEqual(notices.alerts, ["duplicate"])
  assert.deepEqual(notices.notices, [])
})

test("scoreQsos: states and provinces are tallied, and absent for a DX operator", async () => {
  const log = [
    qso("W1AW", "20m", "SSB", { uuid: "q1", their: { call: "W1AW", state: "CT" } }),
    qso("K5XYZ", "20m", "SSB", { uuid: "q2", their: { call: "K5XYZ", state: "TX" } }),
    qso("VE3ABC", "20m", "SSB", { uuid: "q3", their: { call: "VE3ABC", state: "ON" } }),
  ]
  const mine = await scoreQsos({ operation: usOp, qsos: log }, ctxWithLog([]))
  const sheet = mine.scoresheet as { states: Record<string, number>; provinces: Record<string, number> }
  assert.deepEqual(Object.keys(sheet.states).sort(), ["CT", "TX"])
  assert.deepEqual(Object.keys(sheet.provinces), ["ON"])
  assert.equal(mine.operationSummary.statesAndProvinces.total, 3)

  // Nothing tracked, so no badge with an empty label.
  const theirs = await scoreQsos({ operation: dxOp, qsos: log }, ctxWithLog([]))
  assert.equal(theirs.operationSummary.statesAndProvinces, undefined)
})

test("scoreQsos: the places grid checks off every worked state and province, in order", async () => {
  const result = await scoreQsos(
    {
      operation: usOp,
      qsos: [
        qso("W1AW", "20m", "SSB", { uuid: "q1", their: { call: "W1AW", state: "CT" } }),
        qso("VE3ABC", "20m", "SSB", { uuid: "q2", their: { call: "VE3ABC", state: "ON" } }),
      ],
    },
    ctxWithLog([]),
  )
  const grid = result.operationSummary.statesAndProvinces.longSummary as string
  // US_STATES order (Alabama, Alaska, Arizona, Arkansas, ...) with CT struck.
  assert.ok(grid.startsWith("AL  AK  AZ  AR  CA  CO  **~~CT~~**"))
  // The provinces grid follows as its own paragraph.
  assert.ok(grid.includes("**~~ON~~**"))
})

test("scoreQsos: the DXCC breakdown lists flag, name and count, busiest first", async () => {
  const result = await scoreQsos(
    {
      operation: usOp,
      qsos: [
        qso("W1AW", "20m", "SSB", { uuid: "q1" }),
        qso("DL1ABC", "20m", "SSB", { uuid: "q2" }),
        qso("DL2XYZ", "20m", "SSB", { uuid: "q3" }),
      ],
    },
    ctxWithLog([]),
  )
  assert.equal(
    result.operationSummary.dxcc.longSummary,
    "🇩🇪 Germany (2) 🇺🇸 United States",
  )
})

// entityPrefixForCall resolves against BIGCTY; DXCC_BY_PREFIX is a separate,
// independently-maintained table. Nothing enforces the two agree, so a
// prefix the first table produces and the second has never heard of must
// still show up — as its bare prefix — rather than silently shrinking the
// list below the header count.
test("dxccBreakdown: a prefix DXCC_BY_PREFIX has never heard of falls back to itself", () => {
  assert.equal(dxccBreakdown({ K: 2, ZZ99: 1 }), "🇺🇸 United States (2) ZZ99")
})

// A scoresheet cached before rule 4 landed has no `states`/`provinces` maps and
// no `ourEntity`. Scoring runs on every keystroke against exactly this cached
// checkpoint, so reading those unguarded takes the logging panel down.
test("scoreQso: a checkpoint from before states existed is filled in, not fatal", async () => {
  const legacy = {
    workedByCall: {}, entities: {}, bands: {}, modes: {},
    qsos: 0, points: 0, duplicates: 0, bandModeQsos: 0,
    dayQsos: 0, dayPoints: 0, dayDuplicates: 0,
  }
  const notices = await scoreQso(
    {
      operation: usOp,
      qso: qso("W1AW", "20m", "SSB", { their: { call: "W1AW", state: "CT" } }),
      resumeFrom: legacy,
    },
    ctxWithLog([]),
  )
  // Not merely "didn't throw": the rules the checkpoint predates are live.
  assert.ok(notices.notices.includes("newState"))
  assert.ok(!notices.notices.includes("newDXCC"))
})

// A checkpoint outlives the operation setup it was built from: correcting the
// station call has to move the own-entity suppression with it, or scoring stays
// pointed at the entity the operation started with.
test("scoreQso: correcting the station call re-derives our own entity", async () => {
  const fromUsOperation = {
    workedByCall: {}, entities: {}, bands: {}, modes: {}, states: {}, provinces: {},
    qsos: 0, points: 0, duplicates: 0, bandModeQsos: 0,
    dayQsos: 0, dayPoints: 0, dayDuplicates: 0,
    ourCall: "W1XYZ", ourEntity: "K",
  }
  const notices = await scoreQso(
    {
      operation: { uuid: "op-1", stationCall: "DL1XYZ" },
      qso: qso("W1AW", "20m", "SSB"),
      resumeFrom: fromUsOperation,
    },
    ctxWithLog([]),
  )
  // Now a DX operator: W1AW is no longer our own entity, so it notifies again.
  assert.ok(notices.notices.includes("newDXCC"))
})

// --- Per-band breakdown ----------------------------------------------------

test("scoreQsos: the bands/modes label always shows, singular for one of each", async () => {
  // The information panel uses this label as the section's own heading, so
  // a single-band single-mode operation still needs one, not just an empty
  // string once there are fewer than two of something.
  const result = await scoreQsos(
    { operation: usOp, qsos: [qso("W1AW", "20m", "SSB", { uuid: "q1" })] },
    ctxWithLog([]),
  )
  assert.equal(result.operationSummary.bandsAndModes.label, "1 Band, 1 Mode")
})

test("scoreQsos: operationSummary orders dxcc, then states/provinces, then bands/modes", async () => {
  // The information panel renders tallies in this object's own key order —
  // DXCC, then places, then the band/mode breakdown, last.
  const result = await scoreQsos(
    {
      operation: usOp,
      qsos: [qso("W1AW", "20m", "SSB", { uuid: "q1", their: { call: "W1AW", state: "CT" } })],
    },
    ctxWithLog([]),
  )
  assert.deepEqual(Object.keys(result.operationSummary), ["qsoCount", "dxcc", "statesAndProvinces", "bandsAndModes"])
})

test("scoreQsos: the band breakdown is one row per band worked, in band-plan order", async () => {
  const result = await scoreQsos(
    {
      operation: usOp,
      qsos: [
        qso("W1AW", "20m", "CW", { uuid: "q1" }),
        qso("K5XYZ", "20m", "SSB", { uuid: "q2" }),
        qso("K6ABC", "20m", "CW", { uuid: "q3" }),
        qso("DL1ABC", "40m", "SSB", { uuid: "q4" }),
      ],
    },
    ctxWithLog([]),
  )
  // 40m before 20m: band-plan order, not the order QSOs arrived. Modes within a
  // band are busiest-first, so 20m leads with CW.
  assert.equal(
    result.operationSummary.bandsAndModes.longSummary,
    "**40m**: 1 — SSB 1\n**20m**: 3 — CW 2, SSB 1",
  )
})

// A band's total counts every contact on it; a QSO logged with no mode has no
// column to sit in, so the mode numbers legitimately fall short of the total.
test("scoreQsos: a mode-less QSO still counts toward its band's total", async () => {
  const result = await scoreQsos(
    {
      operation: usOp,
      qsos: [
        qso("W1AW", "20m", "CW", { uuid: "q1" }),
        qso("K5XYZ", "20m", "", { uuid: "q2" }),
      ],
    },
    ctxWithLog([]),
  )
  assert.equal(result.operationSummary.bandsAndModes.longSummary, "**20m**: 2 — CW 1")
})

test("scoreQsos: a band the band plan doesn't list still gets a row, after the ones it does", async () => {
  const result = await scoreQsos(
    {
      operation: usOp,
      qsos: [
        qso("W1AW", "20m", "CW", { uuid: "q1" }),
        qso("K5XYZ", "wormhole", "CW", { uuid: "q2" }),
      ],
    },
    ctxWithLog([]),
  )
  const rows = (result.operationSummary.bandsAndModes.longSummary as string).split("\n")
  assert.deepEqual(rows, ["**20m**: 1 — CW 1", "**wormhole**: 1 — CW 1"])
})

test("scoreQsos: no QSOs means no rows, not an empty bullet", async () => {
  const result = await scoreQsos({ operation: usOp, qsos: [] }, ctxWithLog([]))
  assert.equal(result.operationSummary.bandsAndModes.longSummary, "")
})

// The bands and bandModes maps carry across the whole operation, so a day
// section's own tally must not carry a breakdown built from them — it would
// read as that day's while holding operation-to-date numbers.
test("scoreQsos: a day section's tally carries no band breakdown", async () => {
  const day1 = Date.UTC(2026, 0, 1, 12)
  const day2 = Date.UTC(2026, 0, 2, 12)
  const result = await scoreQsos(
    {
      operation: usOp,
      qsos: [
        qso("W1AW", "20m", "CW", { uuid: "q1", startAtMillis: day1 }),
        qso("K5XYZ", "40m", "SSB", { uuid: "q2", startAtMillis: day2 }),
      ],
    },
    ctxWithLog([]),
  )
  assert.equal(result.daySections.length, 2)
  for (const section of result.daySections) {
    assert.equal(section.scores.bandsAndModes.longSummary, undefined)
  }
  // The operation summary still has it.
  assert.equal(result.operationSummary.bandsAndModes.longSummary, "**40m**: 1 — SSB 1\n**20m**: 1 — CW 1")
})

// Duplicates count toward a band's total: the row is contacts logged, which is
// what the stats block above it counts, not the score, which drops them.
test("scoreQsos: a duplicate still counts toward its band's row", async () => {
  const result = await scoreQsos(
    {
      operation: usOp,
      qsos: [
        qso("W1AW", "20m", "CW", { uuid: "q1" }),
        qso("W1AW", "20m", "CW", { uuid: "q2" }),
      ],
    },
    ctxWithLog([]),
  )
  assert.equal(result.qsoScores.q2.dupe, true)
  assert.equal(result.operationSummary.bandsAndModes.longSummary, "**20m**: 2 — CW 2")
})

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import { scoreQso } from "./scoring.ts"
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

test("scoreQso: fresh call on a fresh band/entity flags newDXCC + newBand", async () => {
  const notices = await scoreQso(
    { operation: op, qso: qso("W1AW", "20m", "SSB") },
    ctxWithLog([]),
  )
  assert.deepEqual(notices.alerts, [])
  assert.ok(notices.notices.includes("newDXCC"))
  assert.ok(notices.notices.includes("newBand"))
  assert.ok(notices.notices.includes("newMode"))
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

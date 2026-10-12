// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// DXCC through its `chasing` hook, the way the app calls it. Callsigns resolve
// against the bundled country file: W1AW is the US (291), DL1ABC Germany
// (230), KI2D/VE2 is KI2D operating from Canada (1).

import { test } from "node:test"
import assert from "node:assert/strict"

import { loadExtension } from "../../../sdk/src/testing.ts"
import type { JSONValue } from "@ham2k/extension-sdk"

const extension = await loadExtension(() => import("./index.ts"))

function qso(uuid: string, extra: Record<string, JSONValue> = {}): Record<string, JSONValue> {
  return { uuid, our: { call: "KI2D" }, their: { call: "DL1ABC" }, band: "20m", mode: "CW", startAtMillis: 0, ...extra }
}

async function claims(...qsos: Record<string, JSONValue>[]): Promise<Record<string, Record<string, JSONValue>[]>> {
  return (await extension.runHook("chasing", "claimsForQsos", { qsos })) as Record<string, Record<string, JSONValue>[]>
}

test("the program describes itself as data, without being invoked", () => {
  const { hook, key } = extension.hooks.find((h) => h.category === "chasing")!
  assert.equal(key, "dxcc")
  assert.deepEqual(hook.program, { label: "DXCC", icon: "earth", version: 1, editions: "lifetime" })
})

// Mixed, band and mode are three checklists: working Germany on 40m after
// 20m is nothing new for Mixed and a new slot for 40m.
test("a contact claims its entity for Mixed, for its band and for its mode", async () => {
  const { q1 } = await claims(qso("q1"))
  assert.deepEqual(
    q1.map(({ band, mode }) => [band, mode]),
    [
      [null, null],
      ["20m", null],
      [null, "CW"],
    ],
  )
  assert.ok(q1.every((claim) => claim.ref === "230" && claim.label === "Fed. Rep. of Germany" && claim.level === "worked"))
})

test("modes group into the three DXCC mode awards, and an unknown mode claims no mode slot", async () => {
  const answer = await claims(qso("ssb", { mode: "USB" }), qso("ft8", { mode: "FT8" }), qso("other", { mode: "" }))
  const modes = (uuid: string) => answer[uuid].map((claim) => claim.mode).filter((mode) => mode !== null)
  assert.deepEqual(modes("ssb"), ["PHONE"])
  assert.deepEqual(modes("ft8"), ["DIGITAL"])
  assert.deepEqual(modes("other"), [], "superModeForMode calls an empty mode DATA; claiming it would invent a Digital contact")
})

// The holder decides whose checklist a contact lands on. Portable in the same
// entity is the same award; operating from another entity is a different one.
test("KI2D and KI2D/P share a checklist, and KI2D/VE2 keeps its own", async () => {
  const answer = await claims(qso("home"), qso("portable", { our: { call: "KI2D/P" } }), qso("abroad", { our: { call: "KI2D/VE2" } }))
  assert.equal(answer.home[0].holder, "KI2D@291")
  assert.equal(answer.portable[0].holder, "KI2D@291")
  assert.equal(answer.abroad[0].holder, "KI2D@1")
  assert.deepEqual(await extension.runHook("chasing", "holdersFor", { station: { call: "KI2D/P" } }), ["KI2D@291"])
})

test("LoTW and paper confirm, sponsor credit verifies, and eQSL counts for nothing", async () => {
  const answer = await claims(
    qso("lotw", { qsl: { received: true, lotw: { received: true } } }),
    qso("card", { qsl: { received: true, qsl: { received: true } } }),
    qso("eqsl", { qsl: { received: true, eqsl: { received: true } } }),
    qso("credited", { credits: { dxcc: { level: "verified", by: "lotw" } } }),
    qso("credited-somehow", { credits: { dxcc: { level: "verified" } } }),
  )
  assert.deepEqual([answer.lotw[0].level, answer.lotw[0].by], ["confirmed", "lotw"])
  assert.deepEqual([answer.card[0].level, answer.card[0].by], ["confirmed", "qsl"])
  assert.equal(answer.eqsl[0].level, "worked")
  assert.equal(answer.credited[0].level, "verified")
  assert.deepEqual(
    [answer["credited-somehow"][0].level, answer["credited-somehow"][0].by],
    ["verified", undefined],
    "a credit that names no medium is not LoTW's",
  )
})

// ARRL credits Mixed, band and mode separately: a contact credited only for
// 20m DXCC still needs a QSL to count as confirmed toward Mixed.
test("a credit that lists its awards verifies only the slots it was granted for", async () => {
  const answer = await claims(
    qso("band-only", { qsl: { lotw: { received: true } }, credits: { dxcc: { level: "verified", by: "lotw", awards: ["DXCC_BAND"] } } }),
  )
  assert.deepEqual(
    answer["band-only"].map((claim) => [claim.band ?? claim.mode ?? "mixed", claim.level]),
    [
      ["mixed", "confirmed"],
      ["20m", "verified"],
      ["CW", "confirmed"],
    ],
  )
})

test("a contact with no entity to claim, or no station to claim it for, claims nothing", async () => {
  const answer = await claims(qso("nocall", { their: {} }), qso("nostation", { our: {} }))
  assert.deepEqual(answer, { nocall: [], nostation: [] })
  assert.deepEqual(await extension.runHook("chasing", "holdersFor", { station: {} }), [], "a station with no call yet has no checklist, rather than a failure")
})

// A log made from Hawaii under a mainland call records 110 where the call
// says 291, and an imported contact with a deleted entity records it where
// the call resolves to its successor. Re-deriving from the calls would file
// both on the wrong checklist line.
test("the entity a contact records outranks the one its callsign resolves to, on both sides", async () => {
  const answer = await claims(
    qso("hawaii", { our: { call: "KI2D", dxccCode: 110 } }),
    qso("ddr", { their: { call: "DL1ABC", dxccCode: 229 } }),
    qso("looked-up", { their: { call: "DL1ABC", guess: { dxccCode: 81 } } }),
  )
  assert.equal(answer.hawaii[0].holder, "KI2D@110")
  assert.deepEqual(
    await extension.runHook("chasing", "holdersFor", { station: { call: "KI2D", dxccCode: 110 } }),
    ["KI2D@110"],
    "a station operated from Hawaii asks for the checklist its claims are filed under",
  )
  assert.equal(answer.ddr[0].ref, "229")
  assert.equal(answer.ddr[0].guess, undefined, "a recorded entity is not a guess")
  assert.equal(answer["looked-up"][0].ref, "81")
  assert.equal(answer["looked-up"][0].guess, true, "a lookup's entity is inferred, not reported")
})

// A marker's calls are placeholders — `EVENT` worked `START` — and resolve
// to real entities, so a marker passed along with a log would claim Sudan.
test("event markers, deleted contacts and contacts without a uuid claim nothing", async () => {
  const answer = await claims(qso("marker", { band: "event", our: { call: "EVENT" }, their: { call: "START" } }), qso("gone", { deleted: true }), qso(""))
  assert.deepEqual(answer, { marker: [], gone: [] })
})

// The tally counts entities, not slots: a band or mode slot is the same
// entity again, and counting it would multiply the Mixed total.
test("the summary counts Mixed entities, and confirmed includes verified", async () => {
  const slots = [
    { ref: "230", band: null, mode: null, level: "verified" },
    { ref: "230", band: "20m", mode: null, level: "verified" },
    { ref: "291", band: null, mode: null, level: "confirmed" },
    { ref: "1", band: null, mode: null, level: "worked" },
  ]
  const tallies = (await extension.runHook("chasing", "summarizeClaims", { holder: "KI2D@291", slots })) as Record<string, Record<string, JSONValue>>
  assert.equal(tallies.entities.total, 3)
  assert.equal(tallies.entities.label, "3 DXCC Entities")
  assert.equal(tallies.entities.summary, "2 confirmed")
})

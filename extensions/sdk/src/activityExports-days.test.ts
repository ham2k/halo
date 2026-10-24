// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// `splitByUtcDay`: one file per reference AND UTC day, for a program whose
// uploader refuses a log spanning two (PPOTA). What matters is that each day
// offered is a day its file will actually hold contacts for, and that the
// file holds that day and no other. In a file of its own because the SDK
// module, and what it remembers about activation, is one per process.

import { test } from "node:test"
import assert from "node:assert/strict"

import { activityExportHook, defineExtension } from "./index.ts"
import { loadExtension } from "./testing.ts"

const extension = await loadExtension(async () => {
  defineExtension({
    key: "utc-day-test",
    name: "UTC days",
    version: "0.0.1",
    onActivation({ registerHook }) {
      registerHook("export", {
        key: "split",
        hook: activityExportHook({ key: "flora", label: "FLORA", activationType: "floraActivation", splitByUtcDay: true }),
      })
      registerHook("export", {
        key: "whole",
        hook: activityExportHook({ key: "fauna", label: "FAUNA", activationType: "faunaActivation" }),
      })
    },
  })
  return {}
})

const delegated: Record<string, unknown>[] = []
const kernel = (globalThis as unknown as { __polo: Record<string, unknown> }).__polo
kernel.invokeLocal = async (_category: string, _method: string, args: Record<string, unknown>) => {
  delegated.push(args)
  return [{ key: "adif", ok: true, value: { content: "<EOH>\n" } }]
}

type Option = { exportKey: string; label: string; filename: string; qsoCount?: number; templateData: Record<string, unknown> }

const FLORA = { stationCall: "LU1ABC", refs: [{ type: "floraActivation", ref: "FF-0001" }] }

/// An evening in Argentina: 22:00 to 01:00 UTC-3 is 01:00 to 04:00 UTC — one
/// day — but 20:00 to 22:00 local is 23:00 to 01:00 UTC, two.
const JUL_1_2300 = Date.UTC(2026, 6, 1, 23, 0)
const JUL_2_0030 = Date.UTC(2026, 6, 2, 0, 30)

function contact(uuid: string, startAtMillis: number, extra: Record<string, unknown> = {}) {
  return { uuid, startAtMillis, their: { call: `LU${uuid}` }, ...extra }
}

async function options(operation: Record<string, unknown>, qsos: Record<string, unknown>[], extra: Record<string, unknown> = {}, key = "split") {
  return (await extension.runHook("export", "suggestExportOptions", { operation, qsos, ...extra }, { key })) as Option[]
}

async function generate(operation: Record<string, unknown>, qsos: Record<string, unknown>[], exportKey: string) {
  await extension.runHook("export", "generateExport", { operation, qsos, exportType: "floraActivation-adif", exportKey }, { key: "split" })
  return (delegated[delegated.length - 1]?.qsos as { uuid: string }[]).map((qso) => qso.uuid)
}

test("a log of one UTC day is offered exactly what it was without the split", async () => {
  const offered = await options(FLORA, [contact("1", JUL_1_2300), contact("2", JUL_1_2300 + 60_000)])
  assert.deepEqual(
    offered.map((o) => o.exportKey),
    ["flora-adif:FF-0001"],
  )
  assert.equal(offered[0].qsoCount, undefined)
})

test("a log across 00:00 UTC is offered one file per day, each counted and dated by its own", async () => {
  const offered = await options(FLORA, [contact("1", JUL_1_2300), contact("2", JUL_2_0030), contact("3", JUL_2_0030 + 60_000)])
  assert.deepEqual(
    offered.map((o) => o.exportKey),
    ["flora-adif@2026-07-01:FF-0001", "flora-adif@2026-07-02:FF-0001"],
  )
  assert.deepEqual(
    offered.map((o) => o.qsoCount),
    [1, 2],
  )
  assert.deepEqual(
    offered.map((o) => o.templateData.modifier),
    ["2026-07-01", "2026-07-02"],
  )
  assert.match(offered[0].label, /2026-07-01/)
  assert.notEqual(offered[0].filename, offered[1].filename)
})

test("each reference of an n-fer gets its own file per day", async () => {
  const twoFer = { ...FLORA, refs: [...FLORA.refs, { type: "floraActivation", ref: "FF-0002" }] }
  const offered = await options(twoFer, [contact("1", JUL_1_2300), contact("2", JUL_2_0030)])
  assert.equal(offered.length, 4)
})

test("a day holding only deleted contacts is no day; a contact with no time joins the first", async () => {
  const offered = await options(FLORA, [contact("1", 0), contact("2", JUL_1_2300), contact("3", JUL_2_0030, { deleted: true })])
  assert.deepEqual(
    offered.map((o) => o.exportKey),
    ["flora-adif:FF-0001"],
  )

  const split = await options(FLORA, [contact("1", 0), contact("2", JUL_1_2300), contact("3", JUL_2_0030)])
  assert.deepEqual(
    split.map((o) => o.qsoCount),
    [2, 1],
  )
})

test("a day spent only after the activity ended is not offered", async () => {
  // The activation ran until a break at 00:00 UTC; the contacts after it were
  // hunting, and the host hands this file none of them.
  const segments = [
    { fromMillis: 0, operation: FLORA },
    { fromMillis: Date.UTC(2026, 6, 2), operation: { ...FLORA, refs: [] } },
  ]
  const offered = await options(FLORA, [contact("1", JUL_1_2300), contact("2", JUL_2_0030)], { segments })
  assert.deepEqual(
    offered.map((o) => o.exportKey),
    ["flora-adif:FF-0001"],
  )
})

test("a park moved to at a break is offered only the days it was activated, and each file names its park", async () => {
  // FF-0001 across midnight UTC, then a break at 00:45 and FF-0002 after it.
  const twoParks = { ...FLORA, refs: [...FLORA.refs, { type: "floraActivation", ref: "FF-0002" }] }
  const segments = [
    { fromMillis: 0, operation: FLORA },
    { fromMillis: JUL_2_0030 + 15 * 60_000, operation: { ...FLORA, refs: [{ type: "floraActivation", ref: "FF-0002" }] } },
  ]
  const offered = await options(twoParks, [contact("1", JUL_1_2300), contact("2", JUL_2_0030), contact("3", JUL_2_0030 + 30 * 60_000)], { segments })
  assert.deepEqual(
    offered.map((o) => o.exportKey),
    ["flora-adif@2026-07-01:FF-0001", "flora-adif@2026-07-02:FF-0001", "flora-adif@2026-07-02:FF-0002"],
  )
  assert.deepEqual(
    offered.map((o) => o.qsoCount),
    [1, 1, 1],
  )
  assert.deepEqual(
    offered.map((o) => (o as Option & { ref?: string }).ref),
    ["FF-0001", "FF-0001", "FF-0002"],
  )
})

test("a park switched to with nothing logged yet keeps its one undated file", async () => {
  const twoParks = { ...FLORA, refs: [...FLORA.refs, { type: "floraActivation", ref: "FF-0002" }] }
  const segments = [
    { fromMillis: 0, operation: FLORA },
    { fromMillis: JUL_2_0030 + 15 * 60_000, operation: { ...FLORA, refs: [{ type: "floraActivation", ref: "FF-0002" }] } },
  ]
  const offered = await options(twoParks, [contact("1", JUL_1_2300), contact("2", JUL_2_0030)], { segments })
  assert.deepEqual(
    offered.map((o) => o.exportKey),
    ["flora-adif@2026-07-01:FF-0001", "flora-adif@2026-07-02:FF-0001", "flora-adif:FF-0002"],
  )
})

test("segments that never name the activity fall back to the whole log, as the host does", async () => {
  const segments = [{ fromMillis: 0, operation: { ...FLORA, refs: [] } }]
  const offered = await options(FLORA, [contact("1", JUL_1_2300), contact("2", JUL_2_0030)], { segments })
  assert.equal(offered.length, 2)
})

test("a day's file holds that day's contacts and no other's", async () => {
  const qsos = [contact("1", 0), contact("2", JUL_1_2300), contact("3", JUL_2_0030)]
  assert.deepEqual(await generate(FLORA, qsos, "flora-adif@2026-07-01:FF-0001"), ["1", "2"])
  assert.deepEqual(await generate(FLORA, qsos, "flora-adif@2026-07-02:FF-0001"), ["3"])
  assert.deepEqual(await generate(FLORA, qsos, "flora-adif:FF-0001"), ["1", "2", "3"])
})

test("a reference with a colon, or shaped like a day, reads back whole", async () => {
  const odd = { stationCall: "LU1ABC", refs: [{ type: "floraActivation", ref: "X:2026-07-01" }] }
  const qsos = [contact("1", JUL_1_2300), contact("2", JUL_2_0030)]
  const offered = await options(odd, qsos)
  assert.equal(offered[1].exportKey, "flora-adif@2026-07-02:X:2026-07-01")
  assert.deepEqual(await generate(odd, qsos, offered[1].exportKey), ["2"])
  assert.deepEqual(await generate(odd, qsos, "flora-adif:X:2026-07-01"), ["1", "2"])
})

test("a day whose contacts are gone by export time fails rather than writing an empty log", async () => {
  await assert.rejects(
    extension.runHook(
      "export",
      "generateExport",
      { operation: FLORA, qsos: [contact("1", JUL_1_2300)], exportType: "floraActivation-adif", exportKey: "flora-adif@2026-07-02:FF-0001" },
      { key: "split" },
    ),
    /no contacts on 2026-07-02/,
  )
})

test("a program that does not ask for the split gets one file across days", async () => {
  const fauna = { stationCall: "LU1ABC", refs: [{ type: "faunaActivation", ref: "FA-0001" }] }
  const offered = await options(fauna, [contact("1", JUL_1_2300), contact("2", JUL_2_0030)], {}, "whole")
  assert.deepEqual(
    offered.map((o) => o.exportKey),
    ["fauna-adif:FA-0001"],
  )
})

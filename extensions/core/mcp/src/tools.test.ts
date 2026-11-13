// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
import { test } from "node:test"
import assert from "node:assert/strict"
import type { HookContext, JSONValue } from "@ham2k/extension-sdk"
import { EventQueue } from "./events.ts"
import { answer } from "./mcp.ts"
import { changeTools, readTools } from "./tools.ts"

function station(calls: [string, unknown][], answers: Record<string, unknown> = {}) {
  const record =
    (name: string, value: unknown = answers[name] ?? { accepted: true }) =>
    async (...args: unknown[]) => {
      calls.push([name, args.length === 1 ? args[0] : args])
      return value
    }
  return {
    readRadio: record("readRadio", { id: "r1", frequencyHz: 14_074_000 }),
    listRadios: record("listRadios", []),
    listEquipment: record("listEquipment", []),
    setRadio: record("setRadio"),
    setAntenna: record("setAntenna"),
    setRotator: record("setRotator"),
    stopRotator: record("stopRotator"),
    updateDraft: record("updateDraft"),
    searchSettings: record("searchSettings", { found: false }),
    updateSetting: record("updateSetting"),
    fyi: { post: record("fyi.post"), clear: record("fyi.clear") },
    statusBar: { showNotice: record("statusBar.showNotice") },
    spots: { mark: record("spots.mark"), unmark: record("spots.unmark") },
    bandAnnotations: { put: record("bandAnnotations.put"), remove: record("bandAnnotations.remove") },
    layouts: { list: record("layouts.list", []), switch: record("layouts.switch"), focus: record("layouts.focus") },
  } as never
}

const ctx = {
  // The open ones, front first, only when asked for them: the whole list
  // would be the operator's every operation.
  listOperations: async (options?: { open?: boolean }) =>
    options?.open
      ? [{ uuid: "front", front: true }]
      : [
          { uuid: "back", front: false },
          { uuid: "front", front: true },
        ],
  getQsos: async (uuid: string) => (uuid === "front" ? [{ startAtMillis: 1 }, { startAtMillis: 2 }, { startAtMillis: 3 }] : null),
  getSpots: async (options: Record<string, unknown>) => [{ id: "s1", judgedBy: options.operationUuid ?? null }],
} as unknown as HookContext

function setup(answers: Record<string, unknown> = {}) {
  const calls: [string, unknown][] = []
  const queue = new EventQueue(0)
  const s = station(calls, answers)
  const tools = [...readTools(s, queue), ...changeTools(s)]
  const call = async (name: string, args: Record<string, JSONValue>, access: "watch" | "change" = "change") => {
    const [reply] = await answer(
      { connection: "c", client: { name: "t" }, access, message: { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name, arguments: args } } },
      ctx,
      {
        version: "0",
        tools,
      },
    )
    return reply
  }
  const result = async (name: string, args: Record<string, JSONValue>) =>
    ((await call(name, args)).result as Record<string, JSONValue>).structuredContent as Record<string, JSONValue>
  return { calls, tools, call, result, queue }
}

const errorOf = (reply: Record<string, JSONValue>) => String((reply.error as Record<string, JSONValue>).message)

// Watching includes saying something to the operator: FYI lines and
// notices are what any assistant may do without a permission.
test("an app allowed to watch may read and talk to the operator, and nothing else", () => {
  const { tools } = setup()
  const watching = tools.filter((t) => t.access === "watch").map((t) => t.name)
  for (const name of ["list_operations", "get_qsos", "get_radio", "get_spots", "wait_for_events", "post_fyi", "show_notice"])
    assert.ok(watching.includes(name), name)
  for (const name of ["update_draft", "set_radio", "set_antenna", "set_rotator", "mark_spots", "update_setting", "switch_layout"])
    assert.ok(!watching.includes(name), name)
})

test("a watch-only app calling a change tool is refused, and the station is not touched", async () => {
  const { calls, call } = setup()
  const reply = await call("set_radio", { frequencyHz: 7_074_000 }, "watch")
  assert.match(String((reply.error as Record<string, JSONValue>).message), /watch only/)
  assert.deepEqual(calls, [])
})

// "Never transmits" is the promise the Allow dialog makes: a tune is a
// carrier on the air, and an in-line tuner on a FlexRadio is one too.
test("set_radio refuses a setting that would transmit, and sets nothing", async () => {
  const { calls, call } = setup()
  const reply = await call("set_radio", { frequencyHz: 7_074_000, startTune: true })
  assert.match(errorOf(reply), /takes no `startTune`/)
  assert.deepEqual(calls, [])
})

// Read leniently, a missing callsign is searched for as the text
// "undefined", and the agent concludes the station was never worked.
test("a missing or mistyped argument is refused by name, before the station is asked", async () => {
  const { calls, call } = setup()
  assert.match(errorOf(await call("get_call_history", {})), /needs `call`/)
  assert.match(errorOf(await call("set_rotator", { id: "rot", azimuth: "north" })), /`azimuth` must be a number/)
  assert.match(errorOf(await call("post_fyi", { text: "hi", category: "shout" })), /one of alert/)
  assert.deepEqual(calls, [])
})

// "Every one" is what leaving the list out means; a list sent as a string
// must not mean it too.
test("unmark_spots takes every mark off only when no ids are given", async () => {
  const { calls, call } = setup()
  assert.match(errorOf(await call("unmark_spots", { ids: "s1" })), /a list of strings/)
  await call("unmark_spots", {})
  assert.deepEqual(calls, [["spots.unmark", undefined]])
})

// Read as a success, a refusal is what the agent tells the operator it did.
test("a change the station refuses fails, with the reason", async () => {
  const { call } = setup({ setAntenna: { accepted: false, reason: "transmitting" } })
  const reply = await call("set_antenna", { id: "sw", port: "A", antenna: "Yagi" })
  const result = reply.result as Record<string, JSONValue>
  assert.equal(result.isError, true)
  assert.match(String((result.content as Record<string, JSONValue>[])[0].text), /set_antenna was refused: transmitting/)
})

// The agent's call is handed no operation, so the spots would come back
// unjudged, and "not worked" is what a missing verdict reads as.
test("get_spots judges the spots against the operation in front", async () => {
  const { result } = setup()
  const answer = await result("get_spots", {})
  assert.equal(answer.judged, true)
  assert.deepEqual(answer.spots, [{ id: "s1", judgedBy: "front" }])
})

test("a tool about an operation reads the one in front unless told another", async () => {
  const { call } = setup()
  const reply = await call("get_qsos", { limit: 2 })
  const result = (reply.result as Record<string, JSONValue>).structuredContent as Record<string, JSONValue>
  assert.equal(result.operationUuid, "front")
  assert.deepEqual(result.qsos, [{ startAtMillis: 2 }, { startAtMillis: 3 }])
  assert.equal(result.total, 3)
  assert.equal(result.matched, 3)
})

test("update_draft hands the patch to the draft of the operation it names", async () => {
  const { calls, call } = setup()
  await call("update_draft", { patch: { their: { sent: "599" } }, operationUuid: "back" })
  assert.deepEqual(calls[calls.length - 1], ["updateDraft", [{ their: { sent: "599" } }, { replace: false, operationUuid: "back" }]])
})

test("an FYI line keeps to a key the host takes", async () => {
  const { calls, call } = setup()
  await call("post_fyi", { text: "Rate is dropping", key: "rate coach!" })
  assert.equal((calls[calls.length - 1]?.[1] as Record<string, JSONValue>).key, "rate-coach-")
})

// Held in a hook call instead, the wait would keep the extension engine
// pumping every few milliseconds for as long as an agent loops on it.
test("wait_for_events with nothing yet answers at once, asking the app to hold it and ask again from its cursor", async () => {
  const { call, queue } = setup()
  const reply = await call("wait_for_events", { timeoutSeconds: 20 })
  const result = reply.result as Record<string, JSONValue>
  assert.deepEqual((result._meta as Record<string, JSONValue>)["ham2k/hold"], { seconds: 20, arguments: { after: 0, timeoutSeconds: 20 } })
  queue.push({ type: "operationChanged", atMillis: 1 })
  const again = (await call("wait_for_events", { after: 0, timeoutSeconds: 20 })).result as Record<string, JSONValue>
  assert.equal(again._meta, undefined)
  assert.equal(((again.structuredContent as Record<string, JSONValue>).events as unknown[]).length, 1)
})

test("wait_for_events with no time to wait answers at once, held by nobody", async () => {
  const { call } = setup()
  const result = (await call("wait_for_events", { timeoutSeconds: 0 })).result as Record<string, JSONValue>
  assert.equal(result._meta, undefined)
})

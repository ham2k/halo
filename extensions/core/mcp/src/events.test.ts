// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
import { test } from "node:test"
import assert from "node:assert/strict"
import type { HookContext, JSONValue, ObserveArgs } from "@ham2k/extension-sdk"
import { EventQueue, eventsAssistant, MAX_EVENTS } from "./events.ts"

test("a read answers the events past its cursor, and the cursor to pass next", () => {
  const queue = new EventQueue(0)
  queue.push({ type: "operationChanged", atMillis: 1, operationUuid: "a" })
  queue.push({ type: "operationChanged", atMillis: 2, operationUuid: "b" })
  const result = queue.read(1)
  assert.deepEqual(
    result.events.map((e) => e.operationUuid),
    ["b"],
  )
  assert.equal(result.cursor, 2)
  assert.equal(result.missed, false)
})

test("an agent further behind than the queue holds is told it missed some", () => {
  const queue = new EventQueue(0)
  for (let i = 0; i < MAX_EVENTS + 5; i++) queue.push({ type: "operationChanged", atMillis: i })
  const result = queue.read(0)
  assert.equal(result.events.length, MAX_EVENTS)
  assert.equal(result.missed, true)
})

// The extension restarting starts a new queue; an agent still holding the
// old one's cursor would otherwise wait in silence until this queue reached it.
test("a cursor past the queue's own answers everything it holds, as missed", () => {
  const queue = new EventQueue(0)
  queue.push({ type: "operationChanged", atMillis: 1 })
  const result = queue.read(150)
  assert.equal(result.events.length, 1)
  assert.equal(result.cursor, 1)
  assert.equal(result.missed, true)
})

// A runtime that counted from zero would, once past an old cursor, answer
// from it and skip its own first events without saying so.
test("a cursor below the queue's start is from another runtime: everything it holds, as missed", () => {
  const queue = new EventQueue(5000)
  queue.push({ type: "operationChanged", atMillis: 1 })
  const result = queue.read(10)
  assert.equal(result.events.length, 1)
  assert.equal(result.missed, true)
})

function observeArgs(uuid: string, reasons: string[], operation: Record<string, JSONValue> = {}, realNowMillis = 1000): ObserveArgs {
  return {
    assistantKey: "events",
    operation: { uuid, stationCall: "N0DEV", userTitle: "Field Day", ...operation },
    qsoCount: 0,
    config: {},
    reasons,
    clock: { nowMillis: 1000, realNowMillis },
  } as unknown as ObserveArgs
}

const idle = { readRadio: async () => null, listEquipment: async () => [] }
const noLog = { getQsos: async () => [] } as unknown as HookContext
const callsOf = (event: Record<string, JSONValue | undefined>) =>
  (event.qsos as Record<string, JSONValue>[]).map((q) => (q.their as Record<string, JSONValue>).call)

test("an operation opening is an event; contacts logged after it come with the contacts", async () => {
  const queue = new EventQueue(0)
  const log: Record<string, JSONValue>[] = [{ uuid: "q1", their: { call: "K1AB" } }]
  const ctx = { getQsos: async () => log } as unknown as HookContext
  const assistant = eventsAssistant(queue, idle)
  await assistant.observe(observeArgs("op", ["open"]), ctx)
  log.push({ uuid: "q2", their: { call: "K2AB" } }, { uuid: "e1", band: "event" }, { uuid: "q3", their: { call: "K3AB" } })
  await assistant.observe(observeArgs("op", ["qsoLogged"]), ctx)
  const { events } = queue.read(0)
  assert.deepEqual(
    events.map((e) => e.type),
    ["operationOpened", "qsoLogged"],
  )
  assert.equal(events[0].title, "Field Day")
  assert.deepEqual(callsOf(events[1]), ["K2AB", "K3AB"])
})

// The log comes ordered by time: a contact backfilled from paper sorts into
// the middle, and the last one is a contact the agent was already told about.
test("a contact logged with an earlier time is the one reported", async () => {
  const queue = new EventQueue(0)
  const log: Record<string, JSONValue>[] = [{ uuid: "late", their: { call: "W1AW" } }]
  const ctx = { getQsos: async () => log } as unknown as HookContext
  const assistant = eventsAssistant(queue, idle)
  await assistant.observe(observeArgs("op", ["open"]), ctx)
  log.unshift({ uuid: "early", their: { call: "K1AB" } })
  await assistant.observe(observeArgs("op", ["qsoLogged"]), ctx)
  const { events } = queue.read(1)
  assert.deepEqual(callsOf(events[0]), ["K1AB"])
})

// Every open operation is told the radio changed; the agent hears it once.
test("the radio changing is one event however many operations are open, and none while it holds still", async () => {
  const queue = new EventQueue(0)
  let frequencyHz = 14_074_000
  const assistant = eventsAssistant(queue, {
    readRadio: async () => ({ id: "r", frequencyHz, mode: "FT8", status: "connected" }),
    listEquipment: async () => [],
  })
  await assistant.observe(observeArgs("a", ["open"]), noLog)
  await assistant.observe(observeArgs("b", ["open"]), noLog)
  for (const uuid of ["a", "b"]) await assistant.observe(observeArgs(uuid, ["radio"]), noLog)
  frequencyHz = 14_074_200
  await assistant.observe(observeArgs("a", ["radio"]), noLog)
  frequencyHz = 7_074_000
  await assistant.observe(observeArgs("b", ["radio"]), noLog)
  const { events } = queue.read(0)
  assert.deepEqual(
    events.filter((e) => e.type === "radio").map((e) => (e.radio as Record<string, JSONValue>).frequencyHz),
    [14_074_000, 7_074_000],
  )
})

// The assistant service folds what fired while a call was out into the next
// one, `open` included.
test("a radio change folded into the call that opens an operation still comes", async () => {
  const queue = new EventQueue(0)
  const assistant = eventsAssistant(queue, { readRadio: async () => ({ id: "r", frequencyHz: 7_074_000 }), listEquipment: async () => [] })
  await assistant.observe(observeArgs("op", ["open", "radio"]), noLog)
  const { events } = queue.read(0)
  assert.deepEqual(
    events.map((e) => e.type),
    ["operationOpened", "radio"],
  )
})

// The first contact makes the operation active, and the observe call carries
// its contacts' times beside its data; an agent told "the operation changed"
// by a contact learns nothing it was not told as `qsoLogged`. Anything the
// operator set does count, the assistance switch as much as the title.
test("an operation changes when what the operator set on it does, and not as contacts are logged", async () => {
  const queue = new EventQueue(0)
  const assistant = eventsAssistant(queue, idle)
  await assistant.observe(observeArgs("op", ["open"]), noLog)
  await assistant.observe(observeArgs("op", ["operation"], { qsoCount: 1, startAtMillisMax: 5000, status: "active" }), noLog)
  await assistant.observe(observeArgs("op", ["operation"], { qsoCount: 2, startAtMillisMax: 6000, status: "active", statusAtMillis: 6000 }), noLog)
  await assistant.observe(observeArgs("op", ["operation"], { qsoCount: 2, status: "active", assistance: false }), noLog)
  const { events } = queue.read(0)
  assert.equal(events.filter((e) => e.type === "operationChanged").length, 1)
})

// Paced by the app clock, a developer's time travel back would hold the next
// spots event until the clock came round again.
test("spots move at most once a minute of real time, whatever the app clock says", async () => {
  const queue = new EventQueue(0)
  const assistant = eventsAssistant(queue, idle)
  await assistant.observe(observeArgs("op", ["open"]), noLog)
  for (const realNowMillis of [100_000, 130_000, 161_000]) await assistant.observe(observeArgs("op", ["spots"], {}, realNowMillis), noLog)
  const { events } = queue.read(0)
  assert.equal(events.filter((e) => e.type === "spots").length, 2)
})

test("an operation the assistant hears opened again keeps its contacts to compare, so one logged meanwhile still comes", async () => {
  const queue = new EventQueue(0)
  const log: Record<string, JSONValue>[] = [{ uuid: "q1", their: { call: "K1AB" } }]
  const ctx = { getQsos: async () => log } as unknown as HookContext
  const assistant = eventsAssistant(queue, idle)
  await assistant.observe(observeArgs("op", ["open"]), ctx)
  log.push({ uuid: "q2", their: { call: "K2AB" } })
  await assistant.observe(observeArgs("op", ["open", "qsoLogged"]), ctx)
  const { events } = queue.read(0)
  const logged = events.filter((e) => e.type === "qsoLogged")
  assert.equal(logged.length, 1)
  assert.deepEqual(callsOf(logged[0]), ["K2AB"])
})

// Taken as an empty log, the next good read would report every contact in
// the operation as just logged.
test("an unreadable log changes nothing it knows", async () => {
  const queue = new EventQueue(0)
  let log: Record<string, JSONValue>[] | null = [{ uuid: "q1", their: { call: "K1AB" } }]
  const ctx = { getQsos: async () => log } as unknown as HookContext
  const assistant = eventsAssistant(queue, idle)
  await assistant.observe(observeArgs("op", ["open"]), ctx)
  const held = log
  log = null
  await assistant.observe(observeArgs("op", ["qsoLogged"]), ctx)
  log = held
  await assistant.observe(observeArgs("op", ["qsoLogged"]), ctx)
  const { events } = queue.read(0)
  assert.equal(events.filter((e) => e.type === "qsoLogged").length, 0)
})

test("an import of many contacts is one event with the first fifty and the count", async () => {
  const queue = new EventQueue(0)
  const log: Record<string, JSONValue>[] = []
  const ctx = { getQsos: async () => log } as unknown as HookContext
  const assistant = eventsAssistant(queue, idle)
  await assistant.observe(observeArgs("op", ["open"]), ctx)
  for (let i = 0; i < 300; i++) log.push({ uuid: `q${i}`, their: { call: `K${i}AB` } })
  await assistant.observe(observeArgs("op", ["qsoLogged"]), ctx)
  const { events } = queue.read(1)
  assert.equal((events[0].qsos as unknown[]).length, 50)
  assert.equal(events[0].count, 300)
  assert.equal(events[0].truncated, true)
})

// The service clears what fired once the call is made, so what a failed read
// took down with it would never come.
test("a radio that cannot be read still lets the spots and equipment of the same call through, and the failure is reported", async () => {
  const queue = new EventQueue(0)
  const assistant = eventsAssistant(queue, {
    readRadio: async () => {
      throw new Error("radio gone")
    },
    listEquipment: async () => [{ id: "sw" }],
  })
  await assistant.observe(observeArgs("op", ["open"]), noLog)
  await assert.rejects(assistant.observe(observeArgs("op", ["radio", "equipment", "spots"], {}, 500_000), noLog), /radio gone/)
  const { events } = queue.read(1)
  assert.deepEqual(events.map((e) => e.type).sort(), ["equipment", "spots"])
})

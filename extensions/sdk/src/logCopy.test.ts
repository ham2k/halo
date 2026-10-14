// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The shared log copy behind `ctx.getQsos`. The traps: a list staler than
// the call, one extension's write reaching another's QSOs, and a cursor that
// runs ahead of the rows it stands for.

import { test } from "node:test"
import assert from "node:assert/strict"

import { createLogCopies, type LogChanges, type LogSource } from "./logCopy.ts"

type Qso = Record<string, unknown>
const qso = (uuid: string, startAtMillis: number | null, extra: Qso = {}): Qso => ({ uuid, startAtMillis, their: { call: uuid.toUpperCase() }, ...extra })

/// A host holding one log per operation, answering by a write counter the
/// way the repository's ledger does.
function fakeHost() {
  const logs = new Map<string, Map<string, Qso>>()
  const writes: { operation: string; uuid: string }[] = []
  const asked: (string | undefined)[] = []
  let wholeReads = 0
  const host = {
    asked,
    get wholeReads() {
      return wholeReads
    },
    /// A write the host's ledger never records, as a writer past the repository would make.
    stranger(operation: string, row: Qso) {
      logs.get(operation)!.set(String(row.uuid), structuredClone(row))
    },
    write(operation: string, row: Qso | { uuid: string; removed: true }) {
      const log = logs.get(operation) ?? new Map()
      logs.set(operation, log)
      if ("removed" in row) log.delete(row.uuid)
      else log.set(String(row.uuid), structuredClone(row))
      writes.push({ operation, uuid: String(row.uuid) })
    },
    source: {
      async changes(operation, cursor): Promise<LogChanges | null> {
        asked.push(cursor)
        await Promise.resolve()
        const log = logs.get(operation)
        if (!log) return null
        const from = cursor === undefined ? -1 : Number(cursor)
        const next = String(writes.length)
        if (from < 0) return { cursor: next, reset: true, qsos: [...log.values()].map((q) => structuredClone(q)), removed: [], count: log.size }
        const touched = new Set(
          writes
            .slice(from)
            .filter((w) => w.operation === operation)
            .map((w) => w.uuid),
        )
        return {
          cursor: next,
          reset: false,
          qsos: [...touched].filter((uuid) => log.has(uuid)).map((uuid) => structuredClone(log.get(uuid)!)),
          removed: [...touched].filter((uuid) => !log.has(uuid)),
          count: log.size,
        }
      },
      async whole(operation) {
        wholeReads++
        const log = logs.get(operation)
        return log ? [...log.values()].map((q) => structuredClone(q)) : null
      },
    } satisfies LogSource,
  }
  return host
}

test("every read asks what changed, so a list is never staler than the call", async () => {
  const host = fakeHost()
  host.write("op", qso("a", 1000))
  const copies = createLogCopies(host.source)
  assert.deepEqual(
    (await copies.read("op", { frozen: true }))!.map((q) => q.uuid),
    ["a"],
  )

  host.write("op", qso("b", 2000))
  host.write("op", qso("a", 1000, { notes: "edited" }))
  const log = (await copies.read("op", { frozen: true }))!

  assert.deepEqual(
    log.map((q) => q.uuid),
    ["a", "b"],
  )
  assert.equal(log[0].notes, "edited")
  assert.deepEqual(host.asked, [undefined, "1"], "the second read sent the cursor the first one got")
})

test("pick hands over exactly the contacts named, in their order, from the same current copy", async () => {
  const host = fakeHost()
  for (const [uuid, at] of [
    ["a", 1000],
    ["b", 2000],
    ["c", 3000],
  ] as const)
    host.write("op", qso(uuid, at))
  const copies = createLogCopies(host.source)

  const frozen = (await copies.pick("op", ["c", "a", "gone"], { frozen: true }))!
  assert.deepEqual(
    frozen.map((q) => q.uuid),
    ["c", "a"],
    "a contact the copy no longer holds is left out",
  )
  assert.ok(Object.isFrozen(frozen[0]))

  const copied = (await copies.pick("op", ["a"], { frozen: false }))!
  copied[0].notes = "mine"
  assert.equal((await copies.read("op", { frozen: true }))![0].notes, undefined, "a copy is the caller's own")
  assert.equal(await copies.pick("unknown", ["a"], { frozen: true }), null)
})

test("removals leave the copy, and the log stays oldest first with unstamped contacts ahead", async () => {
  const host = fakeHost()
  host.write("op", qso("late", 3000))
  host.write("op", qso("early", 1000))
  const copies = createLogCopies(host.source)
  await copies.read("op", { frozen: true })

  host.write("op", qso("stampless", null))
  host.write("op", qso("middle", 2000))
  host.write("op", { uuid: "late", removed: true })

  assert.deepEqual(
    (await copies.read("op", { frozen: true }))!.map((q) => q.uuid),
    ["stampless", "early", "middle"],
  )
})

test("an extension at the frozen level shares QSOs it cannot change, in an array of its own", async () => {
  const host = fakeHost()
  host.write("op", qso("a", 1000))
  const copies = createLogCopies(host.source)
  const first = (await copies.read("op", { frozen: true }))!

  assert.ok(Object.isFrozen(first[0]) && Object.isFrozen(first[0].their))
  assert.throws(() => {
    ;(first[0] as Qso).notes = "mine"
  }, TypeError)
  first.push(qso("x", 5))
  first.sort(() => -1)
  assert.deepEqual(
    (await copies.read("op", { frozen: true }))!.map((q) => q.uuid),
    ["a"],
    "rearranging its array reaches nobody",
  )
})

test("an older extension gets copies, and what it changes reaches nobody else", async () => {
  // An extension built before the frozen level was promised it could mutate
  // what getQsos returns; freezing would turn that into a TypeError.
  const host = fakeHost()
  host.write("op", qso("a", 1000))
  const copies = createLogCopies(host.source)
  const old = (await copies.read("op", { frozen: false }))!
  ;(old[0].their as Qso).call = "CHANGED"
  old[0].notes = "mine"

  const shared = (await copies.read("op", { frozen: true }))!
  assert.equal((shared[0].their as Qso).call, "A")
  assert.equal(shared[0].notes, undefined)
  assert.equal(((await copies.read("op", { frozen: false }))![0].their as Qso).call, "A")
})

test("reads of one log at once are synced one after the other, each from the cursor the last one left", async () => {
  const host = fakeHost()
  host.write("op", qso("a", 1000))
  const copies = createLogCopies(host.source)
  await copies.read("op", { frozen: true })
  host.write("op", qso("b", 2000))

  const [first, second] = await Promise.all([copies.read("op", { frozen: true }), copies.read("op", { frozen: true })])

  assert.deepEqual(host.asked, [undefined, "1", "2"])
  assert.equal(first!.length, 2)
  assert.equal(second!.length, 2)
})

test("an operation the host does not know is null, and is asked about afresh next time", async () => {
  const host = fakeHost()
  const copies = createLogCopies(host.source)
  assert.equal(await copies.read("gone", { frozen: true }), null)
  host.write("gone", qso("a", 1))
  assert.equal((await copies.read("gone", { frozen: true }))!.length, 1)
  assert.deepEqual(host.asked, [undefined, undefined])
})

test("a host that does not answer getQsoChanges is read whole, as before, and not asked again", async () => {
  const host = fakeHost()
  host.write("op", qso("a", 1))
  const copies = createLogCopies({
    changes: async () => {
      throw new Error("Host call method getQsoChanges not implemented")
    },
    whole: host.source.whole,
  })
  assert.equal((await copies.read("op", { frozen: true }))!.length, 1)
  assert.equal((await copies.read("op", { frozen: true }))!.length, 1)
  assert.equal(host.wholeReads, 2)
})

test("a copy whose count disagrees with the log's asks for the whole log, rather than keep a copy it knows is wrong", async () => {
  const host = fakeHost()
  host.write("op", qso("a", 1000))
  const copies = createLogCopies(host.source)
  await copies.read("op", { frozen: true })

  host.stranger("op", qso("stranger", 2000))
  host.write("op", qso("b", 3000))

  assert.deepEqual(
    (await copies.read("op", { frozen: true }))!.map((q) => q.uuid),
    ["a", "stranger", "b"],
  )
  assert.deepEqual(host.asked, [undefined, "1", undefined], "the third ask, with no cursor, is the reset")
})

test("a failure that only mentions 'not implemented' is still the caller's", async () => {
  // Read as the host lacking the call, it would cost every later read the
  // whole log for the rest of the session, without a word.
  const copies = createLogCopies({
    changes: async () => {
      throw new Error("UnimplementedError: a database feature is not implemented on this platform")
    },
    whole: async () => assert.fail("not a host without getQsoChanges"),
  })
  await assert.rejects(copies.read("op", { frozen: true }), /database feature/)
})

test("any other failure is the caller's, as it was with a whole-log read", async () => {
  const copies = createLogCopies({
    changes: async () => {
      throw new Error("database is locked")
    },
    whole: async () => assert.fail("a real failure must not be papered over with another read"),
  })
  await assert.rejects(copies.read("op", { frozen: true }), /database is locked/)
})

test("only the most recently read logs are kept; an older one starts over from the whole log", async () => {
  const host = fakeHost()
  for (const op of ["a", "b", "c", "d"]) host.write(op, qso(`${op}1`, 1))
  const copies = createLogCopies(host.source, 3)
  for (const op of ["a", "b", "c", "d"]) await copies.read(op, { frozen: true })
  host.asked.length = 0

  await copies.read("d", { frozen: true })
  await copies.read("a", { frozen: true })

  assert.equal(host.asked[0], "4", "the newest log kept its cursor")
  assert.equal(host.asked[1], undefined, "the oldest was dropped")
})

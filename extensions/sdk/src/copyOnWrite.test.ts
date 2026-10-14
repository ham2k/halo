// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The one promise: whatever a scorer does to the view, the base sheet is
// exactly what it was. Each test mutates the way a real scorer does — a push
// into a nested worked list, a counter bumped, a map created then written —
// and then checks the base as much as the view.

import { test } from "node:test"
import assert from "node:assert/strict"

import { copyOnWrite } from "./copyOnWrite.ts"

type Sheet = {
  workedByCall: Record<string, string[]>
  entities: Record<string, number>
  bandModes: Record<string, Record<string, number>>
  qsos: number
  ourEntity?: string
}

function sheet(): Sheet {
  return {
    workedByCall: { W1AW: ["20m|SSB"] },
    entities: { K: 1 },
    bandModes: { "20m": { SSB: 1 } },
    qsos: 1,
  }
}

test("reads see the base", () => {
  const base = sheet()
  const view = copyOnWrite(base)
  assert.deepEqual(view.workedByCall.W1AW, ["20m|SSB"])
  assert.equal(view.qsos, 1)
  assert.equal(view.entities.K, 1)
  assert.equal("W1AW" in view.workedByCall, true)
})

test("a push into a nested list stays in the view", () => {
  const base = sheet()
  const view = copyOnWrite(base)
  const prior = view.workedByCall.W1AW
  prior.push("40m|CW")
  assert.deepEqual(view.workedByCall.W1AW, ["20m|SSB", "40m|CW"], "the reference a scorer kept and a fresh read agree")
  assert.equal(view.workedByCall.W1AW.length, 2)
  assert.deepEqual(base.workedByCall.W1AW, ["20m|SSB"])
})

test("a counter bumped and a map created then written stay in the view", () => {
  const base = sheet()
  const view = copyOnWrite(base)
  view.qsos += 1
  view.entities.DL = (view.entities.DL ?? 0) + 1
  const byMode = (view.bandModes["40m"] ??= {})
  byMode.CW = 1
  view.bandModes["20m"].SSB += 1
  view.ourEntity = "K"

  assert.equal(view.qsos, 2)
  assert.deepEqual(view.entities, { K: 1, DL: 1 })
  assert.deepEqual(view.bandModes, { "20m": { SSB: 2 }, "40m": { CW: 1 } })
  assert.equal(view.ourEntity, "K")

  assert.equal(base.qsos, 1)
  assert.deepEqual(base.entities, { K: 1 })
  assert.deepEqual(base.bandModes, { "20m": { SSB: 1 } })
  assert.equal(base.ourEntity, undefined)
})

test("a scorer that replaces a list wholesale gets its own list back", () => {
  const base = sheet()
  const view = copyOnWrite(base)
  view.workedByCall.K1ABC = ["20m|SSB"]
  view.workedByCall.W1AW = [...view.workedByCall.W1AW, "40m|CW"]
  assert.deepEqual(Object.keys(view.workedByCall).sort(), ["K1ABC", "W1AW"])
  assert.deepEqual(view.workedByCall.W1AW, ["20m|SSB", "40m|CW"])
  assert.deepEqual(Object.keys(base.workedByCall), ["W1AW"])
})

test("keys, entries and JSON reflect the view, not the base", () => {
  const base = sheet()
  const view = copyOnWrite(base)
  view.entities.DL = 1
  delete view.entities.K
  assert.deepEqual(Object.keys(view.entities), ["DL"])
  assert.deepEqual(Object.entries(view.entities), [["DL", 1]])
  assert.equal("K" in view.entities, false)
  assert.equal(JSON.stringify(view.entities), '{"DL":1}')
  assert.deepEqual(base.entities, { K: 1 })
})

test("array methods run against the view", () => {
  const base = { list: ["a"] }
  const view = copyOnWrite(base)
  view.list.push("b")
  assert.equal(
    view.list.some((x) => x === "b"),
    true,
  )
  assert.equal(view.list.includes("b"), true)
  assert.deepEqual([...view.list], ["a", "b"])
  assert.equal(Array.isArray(view.list), true)
  assert.deepEqual(base.list, ["a"])
})

test("a view over a view keeps each layer's writes apart", () => {
  // The spots pass wraps the folded (already viewed) sheet once more per
  // candidate: the candidate's writes must not reach the shared layer.
  const base = sheet()
  const shared = copyOnWrite(base)
  shared.workedByCall.W1AW.push("40m|CW")
  const first = copyOnWrite(shared)
  first.workedByCall.W1AW.push("80m|CW")
  first.qsos += 1
  const second = copyOnWrite(shared)
  assert.deepEqual(first.workedByCall.W1AW, ["20m|SSB", "40m|CW", "80m|CW"])
  assert.deepEqual(second.workedByCall.W1AW, ["20m|SSB", "40m|CW"], "the first candidate leaked into the second")
  assert.equal(second.qsos, 1)
  assert.deepEqual(base.workedByCall.W1AW, ["20m|SSB"])
})

test("a property defined on the view lands in the view", () => {
  // Object.defineProperty is the other way to write, and without a trap for
  // it the write goes straight to the base.
  const base = sheet()
  const view = copyOnWrite(base)
  Object.defineProperty(view, "ourEntity", { value: "DL", writable: true, enumerable: true, configurable: true })
  Object.defineProperty(view.workedByCall, "K1ABC", { value: ["20m|SSB"], writable: true, enumerable: true, configurable: true })
  assert.equal(view.ourEntity, "DL")
  assert.deepEqual(view.workedByCall.K1ABC, ["20m|SSB"])
  assert.equal(base.ourEntity, undefined)
  assert.equal("K1ABC" in base.workedByCall, false)
})

test("freezing the view is refused, and the base stays writable", () => {
  // A frozen base would lock every later view over it; the freeze must fail
  // loudly at the caller instead.
  const base = sheet()
  const view = copyOnWrite(base)
  assert.throws(() => Object.freeze(view), TypeError)
  assert.throws(() => Object.freeze(view.entities), TypeError)
  assert.equal(Object.isFrozen(base), false)
  assert.equal(Object.isFrozen(base.entities), false)
  const later = copyOnWrite(base)
  later.qsos += 1
  assert.equal(later.qsos, 2)
})

test("a sheet holding part of a frozen QSO is viewed like any other, and writes still reach only the view", () => {
  // A scorer at API 9 folds frozen QSOs and may keep a piece of one in its
  // sheet. A proxy cannot hand back a view of a frozen object's nested values,
  // so without a way around it the live paths throw on their first read.
  const refs = Object.freeze([Object.freeze({ type: "pota", ref: "K-0001" })])
  const base = { refsByCall: { K1ABC: refs } }
  const view = copyOnWrite(base) as unknown as { refsByCall: Record<string, { type: string; ref: string }[]> }
  assert.equal(view.refsByCall.K1ABC[0].ref, "K-0001")
  view.refsByCall.K1ABC[0].ref = "K-0002"
  view.refsByCall.K1ABC.push({ type: "sota", ref: "W1/AA-001" })
  assert.equal(view.refsByCall.K1ABC[0].ref, "K-0002")
  assert.equal(view.refsByCall.K1ABC.length, 2)
  assert.equal(refs[0].ref, "K-0001")
  assert.equal(refs.length, 1)
  assert.equal(copyOnWrite(Object.freeze({ a: 1 })).a, 1, "a frozen sheet itself is viewed too")
})

test("a primitive is handed back as it is", () => {
  assert.equal(copyOnWrite(3), 3)
  assert.equal(copyOnWrite(null), null)
})

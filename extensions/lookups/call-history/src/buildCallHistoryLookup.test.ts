// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import { buildCallHistoryTiers, mergeHistory } from "./buildCallHistoryLookup.ts"
import type { CallInfoLookup, JSONValue } from "@ham2k/halo-extension-sdk"

/// The photo rides along as an extra field `CallInfoLookup`'s fixed shape does
/// not declare, the same widening `flag` uses (annotate.ts) — so reading it
/// back in a test needs the same widening.
type WithImage = CallInfoLookup & { image?: string }

// `call` defaults to "KI2D" — the location guard requires the past QSO's OWN
// call to match the call being composed, so most fixtures need one to
// exercise anything past the name.
function qso(their: Record<string, JSONValue>, uuid = "uuid-1"): Record<string, JSONValue> {
  return { uuid, their: { call: "KI2D", ...their } }
}

test("no history contributes nothing to either tier", () => {
  assert.deepEqual(buildCallHistoryTiers("KI2D", []), { manual: [], guessed: [] })
})

test("uses the most recent QSO — history arrives newest first", () => {
  const { guessed } = buildCallHistoryTiers("KI2D", [
    qso({ guess: { name: "Newer Name" } }, "a"),
    qso({ guess: { name: "Older Name" } }, "b"),
  ])
  assert.equal(guessed[0].name, "Newer Name")
})

test("a manually-entered field lands in the manual tier, not the guessed one", () => {
  const { manual, guessed } = buildCallHistoryTiers("KI2D", [
    qso({ name: "Typed Name", guess: { name: "Guessed Name" } }),
  ])
  assert.equal(manual[0].name, "Typed Name")
  assert.equal(guessed.length, 0)
})

test("a guess-only field lands in the guessed tier, not the manual one", () => {
  const { manual, guessed } = buildCallHistoryTiers("KI2D", [qso({ guess: { name: "Guessed Name", state: "CA" } })])
  assert.equal(manual.length, 0)
  assert.equal(guessed[0].name, "Guessed Name")
  assert.equal(guessed[0].state, "CA")
})

test("one past QSO can split across both tiers — a corrected name, an unverified grid", () => {
  const { manual, guessed } = buildCallHistoryTiers("KI2D", [
    qso({ name: "Corrected Name", guess: { name: "Wrong Name", grid: "CM87", locationScope: "qth" } }),
  ])
  assert.equal(manual[0].name, "Corrected Name")
  assert.equal((manual[0] as Record<string, unknown>).grid, undefined)
  assert.equal(guessed[0].grid, "CM87")
  assert.equal((guessed[0] as Record<string, unknown>).name, undefined)
})

test("the photo comes forward from the last time the station was worked", () => {
  // Guessed tier, deliberately: it fills the slot when nothing live answered
  // — a call worked before shows a face with no network at all — while a
  // fresh QRZ answer still outranks it, so a changed profile picture is not
  // frozen at whatever URL that QSO happened to store.
  const { manual, guessed } = buildCallHistoryTiers("KI2D", [
    qso({ guess: { image: "https://qrz.test/ki2d.jpg" } }),
  ])
  assert.equal((guessed[0] as WithImage).image, "https://qrz.test/ki2d.jpg")
  assert.equal(manual.length, 0)
})

test("the photo is not a location field — a portable QSO still carries it", () => {
  // The location of a POTA/SOTA activation says nothing about where the
  // station lives, and is dropped; a photo describes the operator, not the
  // variant of their call, so it survives the same guard.
  const { guessed } = buildCallHistoryTiers("KI2D", [
    qso({ guess: { image: "https://qrz.test/ki2d.jpg", locationScope: "portable", grid: "FN31pr" } }),
  ])
  assert.equal((guessed[0] as WithImage).image, "https://qrz.test/ki2d.jpg")
  assert.equal(guessed[0].grid, undefined)
})

test("a home QTH location comes through", () => {
  const { guessed } = buildCallHistoryTiers("KI2D", [qso({ guess: { state: "CA", grid: "CM87", locationScope: "qth" } })])
  assert.equal(guessed[0].state, "CA")
  assert.equal(guessed[0].grid, "CM87")
  assert.equal(guessed[0].locationScope, "qth")
})

test("a portable (POTA/SOTA) location is dropped, but the name survives", () => {
  const { manual } = buildCallHistoryTiers("KI2D", [
    qso({ name: "Park Activator", guess: { state: "CA", grid: "CM87", locationScope: "portable" } }),
  ])
  assert.equal(manual[0].name, "Park Activator")
  assert.equal(manual[0].state, undefined)
  assert.equal(manual[0].grid, undefined)
  assert.equal(manual[0].locationScope, undefined)
})

test("a prefixed location is dropped the same way as portable", () => {
  const { guessed } = buildCallHistoryTiers("KI2D", [qso({ guess: { state: "TX", locationScope: "prefixed" } })])
  assert.equal(guessed.length, 0)
})

test("a base-call match (KI2D/P composing, KI2D history) carries the name but not the location", () => {
  // The caller (index.ts) widens the search to the base call and passes the
  // COMPOSED call through unchanged — the past QSO's own `their.call` is
  // still plain "KI2D", not "KI2D/P".
  const { guessed } = buildCallHistoryTiers("KI2D/P", [
    qso({ guess: { name: "Home Op", state: "CA", grid: "CM87", locationScope: "qth" } }),
  ])
  assert.equal(guessed[0].name, "Home Op")
  assert.equal(guessed[0].state, undefined)
  assert.equal(guessed[0].grid, undefined)
  assert.equal(guessed[0].locationScope, undefined)
})

test("an exact call match still gets the location even when composing a portable variant of someone else", () => {
  const { guessed } = buildCallHistoryTiers("KI2D/P", [
    qso({ call: "KI2D/P", guess: { state: "CA", grid: "CM87", locationScope: "qth" } }),
  ])
  assert.equal(guessed[0].state, "CA")
})

test("QSO-instance fields never ride along", () => {
  const { manual } = buildCallHistoryTiers("KI2D", [
    qso({ name: "Op Name", exchange: "599 42", sent: "599 43", notes: ["a note"] }),
  ])
  const result = manual[0] as Record<string, unknown>
  assert.equal(result.exchange, undefined)
  assert.equal(result.sent, undefined)
  assert.equal(result.notes, undefined)
})

test("the QSO being looked up is excluded from its own history", () => {
  assert.deepEqual(buildCallHistoryTiers("KI2D", [qso({ name: "Self" }, "self-uuid")], "self-uuid"), {
    manual: [],
    guessed: [],
  })
})

test("excluding the current QSO still finds an earlier one", () => {
  const { manual } = buildCallHistoryTiers(
    "KI2D",
    [qso({ name: "Current" }, "current-uuid"), qso({ name: "Earlier" }, "earlier-uuid")],
    "current-uuid",
  )
  assert.equal(manual[0].name, "Earlier")
})

test("never populates `history` on the manual tier — it would persist onto the QSO and compound on every repeat contact", () => {
  const { manual } = buildCallHistoryTiers("KI2D", [qso({ name: "A" }, "a"), qso({ name: "B" }, "b")])
  assert.equal(manual[0].history, undefined)
})

test("never populates `history` on the guessed tier either", () => {
  const { guessed } = buildCallHistoryTiers("KI2D", [qso({ guess: { name: "A" } }, "a"), qso({ guess: { name: "B" } }, "b")])
  assert.equal(guessed[0].history, undefined)
})

test("mergeHistory: the second list is skipped whole when empty, no allocation needed", () => {
  const a: Record<string, JSONValue>[] = [{ uuid: "a", startAtMillis: 1 }]
  assert.equal(mergeHistory(a, []), a)
})

test("mergeHistory: interleaves both lists by startAtMillis, newest first", () => {
  const merged = mergeHistory(
    [{ uuid: "a", startAtMillis: 3 }, { uuid: "b", startAtMillis: 1 }],
    [{ uuid: "c", startAtMillis: 2 }],
  )
  assert.deepEqual(merged.map((q) => q.uuid), ["a", "c", "b"])
})

test("mergeHistory: a QSO answering both queries is not duplicated", () => {
  const shared = { uuid: "shared", startAtMillis: 5 }
  const merged = mergeHistory([shared], [shared, { uuid: "other", startAtMillis: 1 }])
  assert.deepEqual(merged.map((q) => q.uuid), ["shared", "other"])
})

test("scope and call are set on both tiers; the manual tier's source is the plain label", () => {
  const { manual } = buildCallHistoryTiers("KI2D", [qso({ name: "Someone" })])
  assert.equal(manual[0].source, "Call History")
  assert.equal(manual[0].scope, "general")
  assert.equal(manual[0].call, "KI2D")
})

test("the guessed tier's source is a DISTINCT label — the stale-fetch guard in lookup_queue_service.dart tells tiers apart by `source` alone", () => {
  const { guessed } = buildCallHistoryTiers("KI2D", [qso({ guess: { name: "Someone" } })])
  assert.equal(guessed[0].source, "Call History (guess)")
  assert.notEqual(guessed[0].source, "Call History")
})

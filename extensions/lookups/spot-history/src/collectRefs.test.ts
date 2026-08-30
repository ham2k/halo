// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import { collectRefsFromSpots } from "./collectRefs.ts"
import type { Spot } from "@ham2k/extension-sdk"

function spot(refs: { type: string; ref: string }[], call = "KI2D"): Spot {
  return { their: { call }, refs, spot: { timeInMillis: 0, source: "test" } }
}

test("collects the reference a spot carries", () => {
  const refs = collectRefsFromSpots([spot([{ type: "potaHunter", ref: "US-1234" }])])
  assert.deepEqual(refs, [{ type: "potaHunter", ref: "US-1234" }])
})

test("a type already on the QSO is never re-proposed", () => {
  // The host only applies types the QSO lacks. Re-offering one would have
  // every lookup pass propose a ref that can never land — and, because
  // applying a ref re-fires the lookup, that is the shape of an endless loop.
  const refs = collectRefsFromSpots([spot([{ type: "potaHunter", ref: "US-1234" }])], ["potaHunter"])
  assert.deepEqual(refs, [])
})

test("the newest spot wins its type — an activator who moved parks contributes the current one", () => {
  // Spots arrive newest-first. Taking the last one instead would log the park
  // the activator has already left.
  const refs = collectRefsFromSpots([
    spot([{ type: "potaHunter", ref: "US-9999" }]),
    spot([{ type: "potaHunter", ref: "US-1234" }]),
  ])
  assert.deepEqual(refs, [{ type: "potaHunter", ref: "US-9999" }])
})

test("distinct types from different spots all come through — a park-and-summit twofer", () => {
  const refs = collectRefsFromSpots([
    spot([{ type: "potaHunter", ref: "US-1234" }]),
    spot([{ type: "sotaHunter", ref: "W2/GC-001" }]),
  ])
  assert.deepEqual(refs, [
    { type: "potaHunter", ref: "US-1234" },
    { type: "sotaHunter", ref: "W2/GC-001" },
  ])
})

test("refs missing a type or a ref value are dropped, not passed through as empty shells", () => {
  const refs = collectRefsFromSpots([
    spot([
      { type: "potaHunter", ref: "" },
      { type: "", ref: "US-1234" },
      { type: "wwffHunter", ref: "KFF-0001" },
    ] as { type: string; ref: string }[]),
  ])
  assert.deepEqual(refs, [{ type: "wwffHunter", ref: "KFF-0001" }])
})

test("a spot with no refs at all contributes nothing", () => {
  assert.deepEqual(collectRefsFromSpots([{ their: { call: "KI2D" }, spot: { timeInMillis: 0, source: "t" } }]), [])
})

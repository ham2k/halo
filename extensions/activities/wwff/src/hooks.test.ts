// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The extension through its HOOKS — what the app actually calls — with the
// lookups table stubbed at the host boundary, so the prefix the control
// learns from the directory is the one the directory actually carries.

import { test } from "node:test"
import assert from "node:assert/strict"

import { applyRefTransforms, fixtureOperation, fixtureQso, loadExtension } from "../../../sdk/src/testing.ts"

// One directory row per entity prefix asked for; a stray row filed under
// the wrong prefix, to prove the majority wins. Anything else is empty, as
// the table is before the directory syncs.
const directory: Record<string, string[]> = {
  UA: ["RFF-0001", "RFF-0002", "GFF-0999"],
  G: ["GFF-0001"],
}
const queries: Record<string, unknown>[] = []
const wwff = await loadExtension(() => import("./index.ts"), {
  hostCalls: {
    dbLookupSelectAll: (params) => {
      queries.push(params)
      return (directory[params.subCategory as string] ?? []).map((key) => ({ key, name: key }))
    },
  },
})

async function inputOf(method: "operationControls" | "loggingControls", qso?: Record<string, unknown>) {
  const controls = (await wwff.runHook("activity", method, { operation: fixtureOperation(), qso })) as any[]
  return controls[0].input as { placeholder: string; transforms: { pattern: string; replacement: string; flags?: string }[] }
}

test("the hunting control's prefix is the one the directory uses for the other station's entity", async () => {
  // Russia's references are "RFF", which no rule derives from the "UA"
  // entity prefix: it has to come from the directory, asked by that prefix.
  const russia = await inputOf("loggingControls", fixtureQso({ their: { call: "RA3ABC" } }))
  assert.equal(russia.placeholder, "RFF-...")
  assert.equal(applyRefTransforms("0001", russia.transforms), "RFF-0001")
  assert.equal(applyRefTransforms("RFF0001", russia.transforms), "RFF-0001")
  assert.deepEqual(queries[queries.length - 1], { category: "wwff", query: "", subCategory: "UA", activeOnly: undefined })
})

test("an entity the directory has nothing for falls back to its DXCC prefix", async () => {
  // Before the directory syncs, or for a country without references, the
  // field still autoformats — to "KFF" for a US call — rather than leaving
  // the number bare.
  const us = await inputOf("loggingControls", fixtureQso({ their: { call: "W1AW" } }))
  assert.equal(applyRefTransforms("0001", us.transforms), "KFF-0001")
})

test("a learned prefix is asked of the table once per entity, not once per control build", async () => {
  const before = queries.length
  await inputOf("loggingControls", fixtureQso({ their: { call: "G4ABC" } }))
  await inputOf("loggingControls", fixtureQso({ their: { call: "G0XYZ" } }))
  assert.equal(queries.length - before, 1)
})

test("the activation control follows our own station, whatever QSO is in progress", async () => {
  // KI2D, the fixture station, is a US call: "KFF" by fallback (the stubbed
  // directory has no "K" rows), not the "GFF" of the station being worked.
  const activation = await inputOf("operationControls", fixtureQso({ their: { call: "G4ABC" } }))
  assert.equal(activation.placeholder, "KFF-...")
})

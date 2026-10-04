// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// `allowsMultiple` is read by the UI (activities_view.dart's
// `allowsMultipleRefsOfType`) straight off the control descriptor this hook
// returns — a config that sets it and a control that doesn't echo it back
// would leave the award's n-fers unreachable from the logging panel with no
// error anywhere. This pins the wiring, not the award rules.

import { test } from "node:test"
import assert from "node:assert/strict"

import { referenceActivity } from "./referenceActivity.ts"
import type { HookContext, JSONValue } from "./types.ts"

const ctx: HookContext = { online: false }
const REGEX = /^X-[0-9]+$/i

function baseConfig(allowsMultiple?: boolean) {
  return {
    key: "test",
    label: "TEST",
    activationType: "testActivation",
    referenceRegex: REGEX,
    placeholder: "X-0001",
    tFor: () => (key: string) => key,
    ...(allowsMultiple === undefined ? {} : { allowsMultiple }),
  }
}

test("operationControls echoes allowsMultiple: true", async () => {
  const { activityHook } = referenceActivity(baseConfig(true))
  const controls = await (activityHook.operationControls as any)({ operation: {} as Record<string, JSONValue> }, ctx)
  assert.equal(controls[0].allowsMultiple, true)
})

test("operationControls defaults allowsMultiple to false when omitted", async () => {
  const { activityHook } = referenceActivity(baseConfig())
  const controls = await (activityHook.operationControls as any)({ operation: {} as Record<string, JSONValue> }, ctx)
  assert.equal(controls[0].allowsMultiple, false)
})

// The activation radius is per reference — a program whose rules differ by
// region answers per row — and a decoration REPLACES the stored ref, so a
// radius the new row lacks must go with the old row. Kept, it would circle a
// reference the operation no longer carries.
const ROWS: Record<string, Record<string, unknown>> = {
  "X-1": { key: "X-1", name: "Near", lat: 48, lon: 2, data: { region: "a" } },
  "X-2": { key: "X-2", name: "Far", lat: 49, lon: 3, data: { region: "b" } },
}
;(globalThis as Record<string, unknown>).__polo = {
  hostCall: async (method: string, params: Record<string, unknown>) => {
    if (method === "dbLookupSelectOne") return ROWS[params.key as string] ?? null
    if (method === "dbLookupSelectAll") return Object.values(ROWS)
    return null
  },
}

function radiusConfig() {
  return {
    ...baseConfig(),
    activationRadius: (row: { data?: unknown }) =>
      (row.data as { region?: string })?.region === "a" ? { activationRadiusInMeters: 1000 } : { activationRadiusInFeet: 500 },
  }
}

test("suggestions carry the radius the config answers for their own row", async () => {
  const { activityHook } = referenceActivity(radiusConfig())
  const suggestions = await (activityHook.suggest as any)({ operation: {}, searchTerm: "X" }, ctx)
  const byRef = Object.fromEntries(suggestions.map((s: any) => [s.ref, s]))
  assert.equal(byRef["X-1"].activationRadiusInMeters, 1000)
  assert.equal(byRef["X-2"].activationRadiusInFeet, 500)
  assert.equal(byRef["X-2"].activationRadiusInMeters, undefined)
})

test("a redecorated reference drops a radius its new row does not have", async () => {
  const { refHandler } = referenceActivity(radiusConfig())
  const decorated = await (refHandler.decorateRef as any)({ ref: { type: "testActivation", ref: "X-2", activationRadiusInMeters: 1000 } }, ctx)
  assert.equal(decorated.activationRadiusInFeet, 500)
  assert.equal(decorated.activationRadiusInMeters, undefined)

  const unknown = await (refHandler.decorateRef as any)({ ref: { type: "testActivation", ref: "X-9", activationRadiusInMeters: 1000 } }, ctx)
  assert.equal(unknown.activationRadiusInMeters, undefined)
})

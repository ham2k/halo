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
    key: 'test',
    label: 'TEST',
    activationType: 'testActivation',
    referenceRegex: REGEX,
    placeholder: 'X-0001',
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

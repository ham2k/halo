// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The hunting control through its HOOK — what the app actually calls — so a
// control that stops carrying its transforms fails here, not in the field.

import { test } from "node:test"
import assert from "node:assert/strict"

import { applyRefTransforms, fixtureOperation, loadExtension, typeRefText } from "../../../sdk/src/testing.ts"

const zlota = await loadExtension(() => import("./index.ts"))
const controls = (await zlota.runHook("activity", "loggingControls", { operation: fixtureOperation() })) as any[]
const { transforms } = controls[0].input

test("a scheme letter and its code typed bare come out as the full reference", () => {
  // Each scheme's own shape: parks and huts dash a number after letters,
  // beaches and lakes have no letters to dash after.
  assert.equal(typeRefText("POT1234", transforms), "ZLP/OT-1234")
  assert.equal(typeRefText("HAA001", transforms), "ZLH/AA-001")
  assert.equal(typeRefText("B123", transforms), "ZLB/123")
  assert.equal(typeRefText("L1234", transforms), "ZLL/1234")
  assert.equal(typeRefText("ZLPOT1234", transforms), "ZLP/OT-1234")
})

test("the end-anchored rules shape only the reference being typed", () => {
  assert.equal(typeRefText("ZLP/OT-1234,HAA001", transforms), "ZLP/OT-1234,ZLH/AA-001")
  assert.equal(applyRefTransforms("ZLP/OT-1234", transforms), "ZLP/OT-1234")
})

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The hunting control through its HOOK — what the app actually calls — so a
// control that stops carrying its transforms fails here, not in the field.

import { test } from "node:test"
import assert from "node:assert/strict"

import { applyRefTransforms, fixtureOperation, loadExtension, typeRefText } from "../../../sdk/src/testing.ts"

const tota = await loadExtension(() => import("./index.ts"))
const controls = (await tota.runHook("activity", "loggingControls", { operation: fixtureOperation() })) as any[]
const { transforms } = controls[0].input

test("a run-on tower reference gets its dash, whatever the country", () => {
  assert.equal(typeRefText("OKR0001", transforms), "OKR-0001")
  assert.equal(typeRefText("9AR0001", transforms), "9AR-0001")
  assert.equal(applyRefTransforms("OKR-0001, OKR0002", transforms), "OKR-0001, OKR-0002")
  assert.equal(applyRefTransforms("OKR-0001", transforms), "OKR-0001")
})

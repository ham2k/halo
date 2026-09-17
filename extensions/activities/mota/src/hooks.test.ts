// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The hunting control through its HOOK — what the app actually calls — so a
// control that stops carrying its transforms fails here, not in the field.

import { test } from "node:test"
import assert from "node:assert/strict"

import { applyRefTransforms, fixtureOperation, loadExtension, typeRefText } from "../../../sdk/src/testing.ts"

const mota = await loadExtension(() => import("./index.ts"))
const controls = (await mota.runHook("activity", "loggingControls", { operation: fixtureOperation() })) as any[]
const { transforms } = controls[0].input

test("a bare mill number takes its X, and so does the next one after a comma", () => {
  assert.equal(typeRefText("00001", transforms), "X00001")
  assert.equal(applyRefTransforms("X00001, 00002", transforms), "X00001, X00002")
  assert.equal(applyRefTransforms("X00001", transforms), "X00001")
})

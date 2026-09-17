// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The hunting control through its HOOK — what the app actually calls — so a
// control that stops carrying its transforms fails here, not in the field.

import { test } from "node:test"
import assert from "node:assert/strict"

import { applyRefTransforms, fixtureOperation, loadExtension, typeRefText } from "../../../sdk/src/testing.ts"

const siota = await loadExtension(() => import("./index.ts"))
const controls = (await siota.runHook("activity", "loggingControls", { operation: fixtureOperation() })) as any[]
const { transforms } = controls[0].input

test("a silo typed without its country or dash is completed as it is typed", () => {
  assert.equal(typeRefText("VKABC123", transforms), "VK-ABC123")
  // The country waits for a digit: put in front of the first three letters
  // typed, it would land in front of "VK" itself and read "VK-VK".
  assert.equal(typeRefText("ABC", transforms), "ABC")
  assert.equal(typeRefText("ABC123", transforms), "VK-ABC123")
  assert.equal(applyRefTransforms("VK-ABC123, DEF4", transforms), "VK-ABC123, VK-DEF4")
  assert.equal(applyRefTransforms("VK-ABC123", transforms), "VK-ABC123")
})

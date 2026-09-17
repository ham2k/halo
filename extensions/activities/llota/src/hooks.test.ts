// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The extension through its HOOKS — what the app actually calls — so a
// control that stops carrying its transforms fails here, not in the field.

import { test } from "node:test"
import assert from "node:assert/strict"

import { applyRefTransforms, fixtureOperation, fixtureQso, loadExtension } from "../../../sdk/src/testing.ts"

const llota = await loadExtension(() => import("./index.ts"))

async function inputOf(method: "operationControls" | "loggingControls", qso?: Record<string, unknown>) {
  const controls = (await llota.runHook("activity", method, { operation: fixtureOperation(), qso })) as any[]
  return controls[0].input as { placeholder: string; transforms: { pattern: string; replacement: string; flags?: string }[] }
}

test("a bare lake number typed into the hunting control takes the other station's country", async () => {
  // The prefix is "LL" plus the ISO country code of the OTHER station's
  // entity, not its DXCC prefix: an English call is "LLGB", a Puerto Rican
  // one "LLPR", a Hawaiian one plain "LLUS".
  const england = await inputOf("loggingControls", fixtureQso({ their: { call: "G4ABC" } }))
  assert.equal(england.placeholder, "LLGB-...")
  assert.equal(applyRefTransforms("0001", england.transforms), "LLGB-0001")
  assert.equal(applyRefTransforms("LLGB0001", england.transforms), "LLGB-0001")

  const puertoRico = await inputOf("loggingControls", fixtureQso({ their: { call: "KP4XYZ" } }))
  assert.equal(applyRefTransforms("0001", puertoRico.transforms), "LLPR-0001")

  const hawaii = await inputOf("loggingControls", fixtureQso({ their: { call: "KH6ABC" } }))
  assert.equal(applyRefTransforms("0001", hawaii.transforms), "LLUS-0001")
})

test("without a QSO the hunting control falls back to our own station, and the activation control always uses it", async () => {
  // The fixture station is KI2D; a hunting control built for the panel
  // before any callsign is typed must still autoformat.
  const hunting = await inputOf("loggingControls")
  assert.equal(applyRefTransforms("0001", hunting.transforms), "LLUS-0001")

  // The activation control describes OUR lake, whatever QSO is in progress.
  const activation = await inputOf("operationControls", fixtureQso({ their: { call: "G4ABC" } }))
  assert.equal(activation.placeholder, "LLUS-...")
  assert.equal(applyRefTransforms("0001", activation.transforms), "LLUS-0001")
})

test("a second lake after a comma is prefixed the same way", async () => {
  const { transforms } = await inputOf("loggingControls")
  assert.equal(applyRefTransforms("LLUS-0001, 0002", transforms), "LLUS-0001, LLUS-0002")
})

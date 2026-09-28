// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The setup form through the `activity` HOOK, the way the app asks for it: what
// the location field offers, which of its codes a county line may combine, and
// what an empty field starts as. The widget tests in halo_widgets run on a
// hand-written list; this is what the extension actually sends.

import { test } from "node:test"
import assert from "node:assert/strict"

import { fixtureOperation, loadExtension } from "../../../sdk/src/testing.ts"

const qp = await loadExtension(() => import("./index.ts"))

type Field = {
  key: string
  value?: string
  uppercase?: boolean
  suggestions?: { code: string; name?: string; standalone?: boolean }[]
  multiValue?: { separator: string; inheritPrefix?: number }
  transforms?: { pattern: string; replacement: string; flags?: string }[]
}

async function locationField(party: string, { stationCall = "N0DEV", location }: { stationCall?: string; location?: string } = {}): Promise<Field> {
  const ref = { type: "qp", ref: party, ...(location !== undefined ? { location } : {}) }
  const controls = (await qp.runHook("activity", "operationControls", { operation: fixtureOperation({ stationCall, refs: [ref] }) })) as {
    input: { form: { elements: Field[] } }
  }[]
  const field = controls[0].input.form.elements.find((element) => element.key === "location")
  assert.ok(field, "the setup form has a location field")
  return field
}

test("a county line combines the party's own counties, and nothing else", async () => {
  // Only counties may share a line: a state, a province or DX beside a county
  // would claim ground the station is not on. The field reads `standalone` to
  // keep them out of a list; without it, `ALB/NJ` passes as a county line.
  const field = await locationField("NY")
  const byCode = Object.fromEntries((field.suggestions ?? []).map((option) => [option.code, option]))
  assert.equal(byCode.ALB?.standalone, undefined)
  assert.equal(byCode.NJ?.standalone, true)
  assert.equal(byCode.ON?.standalone, true)
  assert.equal(byCode.DX?.standalone, true)
  // In the New York QSO Party nobody is in New York without a county.
  assert.equal(byCode.NY, undefined)
  assert.deepEqual(field.multiValue, { separator: "/" })
  assert.equal(field.uppercase, true)
  // The scorer reads `ALB,SCH` as a line; without the rewrite the field would
  // flag as unknown what the score counts.
  assert.deepEqual(field.transforms, [{ pattern: ",", replacement: "/", flags: "g" }])
})

test("a neighbouring party's county is valid on its own but never on our line", async () => {
  // 7QP's entrants also work neighbouring parties' counties (`otherCounties`),
  // which are exchanges they RECEIVE, not ground a 7QP station stands on.
  const field = await locationField("7QP")
  const standalone = new Set((field.suggestions ?? []).filter((option) => option.standalone).map((option) => option.code))
  assert.ok(!standalone.has("ORDES"))
  assert.ok(
    (field.suggestions ?? []).some((option) => standalone.has(option.code) && option.code.length > 4),
    "some other party's county",
  )
  // The multi-state shorthand, `ORDES/JEF` for `ORDES/ORJEF`.
  assert.equal(field.multiValue?.inheritPrefix, 2)
})

test("a party without county lines takes one location, with no separator", async () => {
  const field = await locationField("WI")
  assert.equal(field.multiValue, undefined)
  assert.equal(field.transforms, undefined)
})

test("a station outside the US and Canada starts out as DX", async () => {
  assert.equal((await locationField("NY", { stationCall: "DL1ABC" })).value, "DX")
  // Alaska is a US state that does not sign K.
  assert.equal((await locationField("NY", { stationCall: "KL7ABC" })).value, "")
  assert.equal((await locationField("NY", { stationCall: "VE3ABC" })).value, "")
  assert.equal((await locationField("NY")).value, "")
  // Only an empty location: what the operator said stands.
  assert.equal((await locationField("NY", { stationCall: "DL1ABC", location: "ALB" })).value, "ALB")
})

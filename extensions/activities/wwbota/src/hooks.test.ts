// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The extension through its HOOKS — what the app actually calls — rather than
// through the plain functions behind them. `loadExtension` activates the real
// module against a stand-in kernel, so a registration that stops happening,
// or a control that stops being offered, fails here (sdk/src/testing.ts).

import { test } from "node:test"
import assert from "node:assert/strict"

import { applyRefTransforms, fixtureOperation, fixtureQso, loadExtension, typeRefText } from "../../../sdk/src/testing.ts"
import manifest from "../manifest.json" with { type: "json" }

// The bunker list, one row per entity prefix a test asks about: Canada's
// bunkers are "B/CA", which no rule derives from the "VE" entity prefix.
const bunkers: Record<string, string[]> = { VE: ["B/CA-0001", "B/CA-0002"] }
const wwbota = await loadExtension(() => import("./index.ts"), {
  hostCalls: {
    dbLookupSelectAll: (params) => (bunkers[params.subCategory as string] ?? []).map((key) => ({ key, name: key })),
  },
})

const operationWith = (...refs: { type: string; ref: string }[]) => fixtureOperation({ refs })

async function controlRefTypes(operation: Record<string, unknown>): Promise<string[]> {
  const controls = [
    ...((await wwbota.runHook("activity", "operationControls", { operation })) as any[]),
    ...((await wwbota.runHook("activity", "loggingControls", { operation })) as any[]),
  ]
  return controls.map((control) => control?.input?.refType).filter(Boolean)
}

test("the legacy UKBOTA ref types are answered but never offered", async () => {
  // Both halves matter and they pull apart. The registrations keep old synced
  // references decorated; the manifest must NOT list them, because the host
  // reads that list to offer enabling this extension for an unhandled
  // reference — and there is no control for a legacy type, so the offer would
  // leave the row exactly as red. extensions/hook-check.mjs fails the build on
  // the mismatch; this says why the two differ on purpose.
  assert.ok(wwbota.categories().includes("ref:ukbotaActivation"), "legacy refs still resolve")
  assert.ok(wwbota.categories().includes("ref:ukbota"))
  assert.ok(!manifest.hooks.includes("ref:ukbotaActivation"), "and are not advertised to the host")
  assert.ok(!manifest.hooks.includes("ref:ukbota"))

  const offered = await controlRefTypes(operationWith({ type: "ukbotaActivation", ref: "B/GX-0001" }))
  assert.ok(!offered.includes("ukbotaActivation"), "no control clears a legacy row")
})

test("an operation activating a bunker is offered the controls that fill it in", async () => {
  const offered = await controlRefTypes(operationWith({ type: "wwbotaActivation", ref: "B/GX-0001" }))
  assert.deepEqual(offered.sort(), ["wwbota", "wwbotaActivation"])
})

test("Slovenia and North Macedonia activate at 10 contacts, everywhere else at 25", async () => {
  // The threshold is read off the reference's second segment, and getting it
  // wrong is silent: an activator is simply shown the wrong target. Scored
  // through the hook because that is where the operation's refs meet it.
  // One contact in, the tally reads "1/<target>" — the target IS what the
  // activator is shown, so asserting the rendered summary catches the wrong
  // threshold the way they would notice it, if they knew to.
  const progressFor = async (ref: string) => {
    const operation = operationWith({ type: "wwbotaActivation", ref })
    const result = (await wwbota.runHook("scoring", "scoreQsos", {
      operation,
      qsos: [fixtureQso()],
      ref: { type: "wwbotaActivation", ref },
    })) as { operationSummary: Record<string, { summary?: string }> }
    return Object.values(result.operationSummary)
      .map((tally) => tally.summary)
      .find((summary) => typeof summary === "string" && summary.includes("/"))
  }
  assert.equal(await progressFor("B/S5-0001"), "1/10", "Slovenia")
  assert.equal(await progressFor("B/Z3-0001"), "1/10", "North Macedonia")
  assert.equal(await progressFor("B/GX-0001"), "1/25", "everywhere else")
})

async function huntingInput(theirCall: string) {
  const qso = fixtureQso({ their: { call: theirCall } })
  const controls = (await wwbota.runHook("activity", "loggingControls", { operation: fixtureOperation(), qso })) as any[]
  return controls[0].input as { placeholder: string; transforms: { pattern: string; replacement: string; flags?: string }[] }
}

test("a bare bunker number takes the prefix the list uses for the other station's entity", async () => {
  const canada = await huntingInput("VE3ABC")
  assert.equal(canada.placeholder, "B/CA-...")
  assert.equal(applyRefTransforms("0001", canada.transforms), "B/CA-0001")
  assert.equal(applyRefTransforms("B/CA-0001,0002", canada.transforms), "B/CA-0001,B/CA-0002")

  // No rows for England in the stubbed list: the DXCC prefix stands in.
  const england = await huntingInput("G4ABC")
  assert.equal(applyRefTransforms("0001", england.transforms), "B/G-0001")
})

test("a reference typed without its scheme or dash is completed as it is typed", async () => {
  const { transforms } = await huntingInput("G4ABC")
  assert.equal(typeRefText("G-0001", transforms), "B/G-0001")
  assert.equal(typeRefText("G0001", transforms), "B/G-0001")
  assert.equal(typeRefText("B/G0001", transforms), "B/G-0001")
  // A country segment ending in a digit reads as "E" plus a number until the
  // fifth digit proves otherwise — the repair has to happen, and only then.
  assert.equal(typeRefText("E7000", transforms), "B/E-7000")
  assert.equal(typeRefText("E70001", transforms), "B/E7-0001")
  assert.equal(typeRefText("E7-0001", transforms), "B/E7-0001")
  assert.equal(typeRefText("9A0001", transforms), "B/9A-0001")
  // A finished reference is left alone.
  assert.equal(applyRefTransforms("B/G-0001", transforms), "B/G-0001")
})

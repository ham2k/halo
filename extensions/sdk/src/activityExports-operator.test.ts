// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// An activity's own exports ask the core `adif` generator for OPERATOR on every
// record when the program says its uploader needs it. The forward is the whole
// mechanism — OPERATOR identifies the contact, so no `adifFields` hook can
// supply it — and nothing else shows whether it happened. In a file of its own
// because the SDK module, and what it remembers about activation, is one per
// process.

import { test } from "node:test"
import assert from "node:assert/strict"

import { activityExportHook, defineExtension, huntingExportHook } from "./index.ts"
import { loadExtension } from "./testing.ts"

const extension = await loadExtension(async () => {
  defineExtension({
    key: "operator-fallback-test",
    name: "Operator fallback",
    version: "0.0.1",
    onActivation({ registerHook }) {
      registerHook("export", {
        key: "activation",
        hook: activityExportHook({ key: "flora", label: "FLORA", activationType: "floraActivation", operatorFallback: "base" }),
      })
      registerHook("export", {
        key: "hunter",
        hook: huntingExportHook({ key: "flora", label: "FLORA", huntingType: "flora", activationType: "floraActivation", operatorFallback: "station" }),
      })
      registerHook("export", {
        key: "plain",
        hook: activityExportHook({ key: "plain", label: "PLAIN", activationType: "plainActivation" }),
      })
    },
  })
  return {}
})

const delegated: Record<string, unknown>[] = []
const kernel = (globalThis as unknown as { __polo: Record<string, unknown> }).__polo
kernel.invokeLocal = async (_category: string, _method: string, args: Record<string, unknown>) => {
  delegated.push(args)
  return [{ key: "adif", ok: true, value: { content: "<EOH>\n" } }]
}

const qso = { uuid: "q", their: { call: "W1AW" }, refs: [{ type: "flora", ref: "FF-0002" }] }

test("an activation export forwards its operator fallback", async () => {
  await extension.runHook(
    "export",
    "generateExport",
    {
      operation: { stationCall: "KI2D/P", refs: [{ type: "floraActivation", ref: "FF-0001" }] },
      qsos: [qso],
      exportType: "floraActivation-adif",
      exportKey: "flora-adif:FF-0001",
    },
    { key: "activation" },
  )
  assert.equal(delegated[delegated.length - 1]?.operatorFallback, "base")
})

test("a hunter export forwards its operator fallback", async () => {
  await extension.runHook(
    "export",
    "generateExport",
    { operation: { stationCall: "KI2D", refs: [] }, qsos: [qso], exportType: "flora-hunter" },
    { key: "hunter" },
  )
  assert.equal(delegated[delegated.length - 1]?.operatorFallback, "station")
})

test("a program that asks for none forwards none", async () => {
  await extension.runHook(
    "export",
    "generateExport",
    {
      operation: { stationCall: "KI2D", refs: [{ type: "plainActivation", ref: "P-1" }] },
      qsos: [qso],
      exportType: "plainActivation-adif",
      exportKey: "plain-adif:P-1",
    },
    { key: "plain" },
  )
  assert.equal(delegated[delegated.length - 1]?.operatorFallback, undefined)
})

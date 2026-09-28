// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
import { test } from "node:test"
import assert from "node:assert/strict"
import type { HookContext, PanelRenderArgs } from "@ham2k/extension-sdk"
import { createScenePanels } from "./scenes.ts"

const ctx = {} as HookContext
const args = (instanceId = "one"): PanelRenderArgs => ({ panelKey: "radio", instanceId, operation: {}, qsoCount: 0, config: {}, reason: "test" })
test("simulated CAT distinguishes requested/reported values and isolates placements", async () => {
  let time = 1000
  const panel = createScenePanels(() => time)
  const event = { controlId: "tune", action: "tune", phase: "commit" as const, sequence: 1, value: 14200 }
  const result = await panel.onEvent!({ ...args(), event }, ctx)
  assert.equal(result.values.requested, 14200)
  assert.equal(result.values.reported, 14074)
  time += 2001
  const content = await panel.render(args(), ctx)
  assert.equal(content.kind, "scene")
  if (content.kind !== "scene") throw Error("scene expected")
  assert.equal(content.scene.values.reported, 14200)
  const other = await panel.render(args("two"), ctx)
  if (other.kind !== "scene") throw Error("scene expected")
  assert.equal(other.scene.values.reported, 14074)
  const disconnected = await panel.onEvent!({ ...args(), event: { ...event, action: "connect" } }, ctx)
  assert.equal(disconnected.values.connected, 0)
  await assert.rejects(panel.onEvent!({ ...args(), event }, ctx), /disconnected/)
})

// A text field commits a string, and the spot reads it back from state the
// event wrote — if the host sent `value` for a string control, or the panel
// read `event.value`, the callsign would never arrive.
test("native controls round-trip strings through onEvent", async () => {
  const panel = createScenePanels()
  const controls = (instanceId = "one"): PanelRenderArgs => ({ ...args(instanceId), panelKey: "controls" })
  const set = (controlId: string, text: string) => ({ controlId, action: "set", phase: "commit" as const, sequence: 1, text })
  await panel.onEvent!({ ...controls(), event: set("call", "k2hrc") }, ctx)
  await panel.onEvent!({ ...controls(), event: set("mode", "SSB") }, ctx)
  const spotted = await panel.onEvent!({ ...controls(), event: { controlId: "spot", action: "spot", phase: "activate", sequence: 2 } }, ctx)
  assert.equal(spotted.strings?.call, "K2HRC")
  assert.equal(spotted.strings?.status, "Spotted K2HRC on 20m SSB, 100 W")
  const other = await panel.render(controls("two"), ctx)
  if (other.kind !== "scene") throw Error("scene expected")
  assert.equal(other.scene.strings?.call, "")
  await assert.rejects(panel.onEvent!({ ...controls("two"), event: { controlId: "spot", action: "spot", phase: "activate", sequence: 1 } }, ctx), /No callsign/)
})

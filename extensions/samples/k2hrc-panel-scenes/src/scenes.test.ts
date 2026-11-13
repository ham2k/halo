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

// Every cell the board declares must be placed by its layout exactly once, or
// the host refuses the whole scene; a key added to the cells but not the grid
// is the mistake this catches before the host does.
test("the grid board places every cell once and answers its keys", async () => {
  const panel = createScenePanels()
  const grid: PanelRenderArgs = { ...args(), panelKey: "grid" }
  const content = await panel.render(grid, ctx)
  if (content.kind !== "scene") throw Error("scene expected")
  const placed: string[] = []
  const visit = (node: unknown) => {
    const n = node as Record<string, unknown>
    if (typeof n.cell === "string") placed.push(n.cell)
    for (const kind of ["grid", "row", "column", "wrap"]) for (const child of (n[kind] as unknown[] | undefined) ?? []) visit(child)
  }
  visit(content.scene.layout)
  assert.deepEqual(placed.sort(), content.scene.cells!.map((c) => c.id).sort())
  const press = (action: string) => ({ controlId: action, action, phase: "activate" as const, sequence: 1 })
  const atu = await panel.onEvent!({ ...grid, event: press("atu") }, ctx)
  assert.equal(atu.values.atu, 1)
  const mode = await panel.onEvent!({ ...grid, event: press("mode:FT8") }, ctx)
  assert.equal(mode.strings?.mode, "FT8")
})

// The map keeps the operator's view by giving back where a pan and a zoom
// settled: a render that drew `home` and `zoom.initial` from anything else
// would throw the operator back to the station on every render.
test("the contacts map gives back the operator's view and names the contact clicked", async () => {
  const panel = createScenePanels()
  const map = (config: Record<string, number | string> = {}): PanelRenderArgs => ({ ...args(), panelKey: "map", config })
  const commit = (gesture: "pan" | "zoom", extra: object) => ({ controlId: "map", action: "map", phase: "commit" as const, sequence: 1, gesture, ...extra })
  const panned = await panel.onEvent!({ ...map(), event: commit("pan", { at: { x: 1, y: 2, lat: 51, lon: 0 } }) }, ctx)
  assert.deepEqual(panned.config, { lat: 51, lon: 0 })
  const zoomed = await panel.onEvent!({ ...map(), event: commit("zoom", { value: 3 }) }, ctx)
  const content = await panel.render(map({ ...panned.config, ...zoomed.config, projection: "robinson" } as Record<string, number | string>), ctx)
  if (content.kind !== "scene") throw Error("scene expected")
  const control = content.scene.controls!.find((c) => c.kind === "map")!
  assert.deepEqual(control.home, { lat: 51, lon: 0 })
  assert.equal(control.zoom?.initial, 3)
  assert.equal(control.projection, "robinson")
  const clicked = await panel.onEvent!({ ...map(), event: { controlId: "map", action: "contact", phase: "activate", sequence: 2, layer: "G4XYZ" } }, ctx)
  assert.equal(clicked.strings?.picked, "G4XYZ, London")
})

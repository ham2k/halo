// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MIT
import { test } from "node:test"
import assert from "node:assert/strict"
import type { PanelEnvironment, PanelRadioSpectrum, PanelRadioState, PanelRenderArgs, PanelScene, PanelSceneLayoutNode } from "@ham2k/extension-sdk"
import type { HookContext } from "@ham2k/extension-sdk"
import { annotationsFor } from "../../band-plan/src/plan.ts"
import { createBandScope, scene, settingsFrom, type BandScopeHost } from "./band-scope.ts"

const spectrum: PanelRadioSpectrum = {
  problem: null,
  mode: "fixed",
  spanHz: 48000,
  lowHz: 13997000,
  highHz: 14093000,
  refLevelDb: 0,
  speed: "mid",
  spansHz: [12000, 24000, 48000],
  refMinDb: -30,
  refMaxDb: 30,
  refStepDb: 1,
  modes: ["fixed"],
  speeds: ["slow", "mid", "fast"],
}

function radio(overrides: Partial<PanelRadioSpectrum> = {}): PanelRadioState {
  return {
    id: "k4",
    name: "K4",
    status: "connected",
    stale: false,
    problem: null,
    frequencyHz: 14047440,
    mode: "CW",
    powerWatts: 10,
    transmitting: false,
    meters: {},
    canTune: true,
    spectrum: { ...spectrum, ...overrides },
  }
}

function placedControls(node: PanelSceneLayoutNode): string[] {
  if ("control" in node) return [node.control]
  if ("row" in node) return node.row.flatMap(placedControls)
  if ("column" in node) return node.column.flatMap(placedControls)
  if ("wrap" in node) return node.wrap.flatMap(placedControls)
  return []
}

/** These scene-contract violations reject the whole panel, not just a knob. */
function assertValidControls(panel: PanelScene) {
  const controls = panel.controls ?? []
  assert.deepEqual(
    placedControls(panel.layout!).sort(),
    controls.map((control) => control.id).sort(),
    "every native control, including each paired label, must be placed exactly once",
  )
  for (const control of controls) {
    if (control.kind === "nativeDropdown" || control.kind === "nativeSegmented") {
      assert.ok(control.options?.length, `${control.id} needs choices`)
      const value = panel.strings?.[control.value!]
      assert.ok(value === "" || control.options.some((option) => option.value === value), `${control.id} must select an advertised choice`)
    }
    if (control.kind === "nativeSlider") {
      assert.ok(control.min! < control.max!, `${control.id} needs a nonempty range`)
      assert.ok(control.step! > 0, `${control.id} needs a positive step`)
      const value = panel.values[control.value!]
      assert.ok(value >= control.min! && value <= control.max!, `${control.id} must start in range`)
    }
  }
}

const byId = (panel: PanelScene, id: string) => panel.controls!.find((control) => control.id === id)!
const key = (id: string, control: string) => `${encodeURIComponent(id)}-${control}`

test("the app tunes, zooms and pans: the scope names no step or gestures, and the scale is there to drag", () => {
  const panel = scene(radio())
  assertValidControls(panel)
  const scope = byId(panel, "spectrum")
  // A step or a gesture named here would take the app's own, which follow the zoom.
  assert.equal(scope.tuneStep, undefined)
  assert.equal(scope.gestures, undefined)
  assert.equal(scope.span, undefined, "the whole sweep until the operator zooms")
  assert.ok(scope.scale && scope.scale !== true, "the scale is the strip a drag zooms on")
  assert.equal(scope.follow, 0.15)
})

test("the scope is all the pane shows: its settings are behind the gear, with no toolbar and no readouts under it", async () => {
  const panel = scene(radio())
  assertValidControls(panel)
  assert.deepEqual(
    panel.controls!.map((control) => control.id),
    ["spectrum"],
  )
  assert.deepEqual(panel.layers ?? [], [])
  assert.ok(!JSON.stringify(panel.layout).includes('"scene"'), "no row left for the artwork")
  const [descriptor] = await createBandScope(
    fakeHost(
      () => [],
      () => radio(),
    ),
  ).getPanels({}, context)
  assert.deepEqual(
    descriptor.form!.map((field) => ("key" in field ? field.key : field.title)),
    // The view and the spots up front; what the scope draws and asks of the radio folded under a heading.
    ["display", "spots", "notes", "age", "spotLevel", "plan", "Band Scope Settings", "floor", "average", "fps", "rows", "ref", "speed"],
  )
  // Each select's default must be one of its choices, or the form opens on a blank.
  for (const field of descriptor.form!) {
    if (field.type === "field" && field.fieldType === "select") {
      assert.ok(Array.isArray(field.options) && field.options.some((option) => option.value === field.value), `${field.key} opens on a choice`)
      assert.deepEqual(settingsFrom({ [field.key]: field.value }), settingsFrom({}), `${field.key}'s default is the panel's own`)
    }
  }
})

test("the form values a pane holds draw its scope, brought into range, with blanks and unknowns as the defaults", () => {
  const drawn = (config: Parameters<typeof settingsFrom>[0]) => byId(scene(radio(), { settings: settingsFrom(config) }), "spectrum")
  const scope = drawn({ display: "waterfall", floor: "12", average: 80, fps: 20, rows: 5 })
  assert.deepEqual([scope.display, scope.floor, scope.average, scope.fps, scope.waterfallSpeed], ["waterfall", 12, 80, 20, 5])
  const wild = drawn({ display: "sideways", floor: 900, average: -4, fps: "fast", rows: "" })
  assert.deepEqual([wild.display, wild.floor, wild.average, wild.fps, wild.waterfallSpeed], ["both", 60, 0, 15, 10])
  assert.deepEqual(settingsFrom({ ref: "", speed: "radio" }), settingsFrom({}), "blank and the radio's own leave the radio alone")
  assert.equal(settingsFrom({ ref: "-5" }).ref, -5)
})

function dualRadios(deviceId = "k4-device", mainId = "k4", subId = "k4/sub"): [PanelRadioState, PanelRadioState] {
  return [
    { ...radio(), id: mainId, deviceId, channel: { key: "main", label: "Main" } },
    {
      ...radio(),
      id: subId,
      deviceId,
      channel: { key: "sub", label: "Sub" },
      frequencyHz: 7045000,
      mode: "USB",
      passband: { lowHz: 300, highHz: 2400 },
      spectrum: { ...spectrum, spanHz: 12000, spansHz: [3000, 6000, 12000], lowHz: 7033000, highHz: 7057000, refLevelDb: 5 },
    },
  ]
}

const args = (instanceId = "one", config: PanelRenderArgs["config"] = {}): PanelRenderArgs => ({
  instanceId,
  panelKey: "band-scope",
  operation: {},
  qsoCount: 0,
  config,
  reason: "initial",
})
/** 20 m's plan as the host hands it over. */
const context = {
  online: false,
  getBandAnnotations: async ({ band }: { band: string }) =>
    annotationsFor(band).map((a) => ({ ...a, band, importance: a.importance ?? "primary", source: "band-plan" })),
} as unknown as HookContext

/** The app tunes on a click, so this panel never tunes. */
const fakeHost = (radios: () => PanelRadioState[], designated: () => PanelRadioState): BandScopeHost => ({
  readRadio: async (id?: string) => (id ? (radios().find((receiver) => receiver.id === id) ?? null) : designated()),
  listRadios: async () => radios(),
  setRadioSpectrum: async () => ({ accepted: true, state: designated() }),
  setRadio: async () => ({ accepted: true, state: designated() }),
  suggestQso: async () => ({ accepted: true }),
})

test("with the receiver picked gone, the one the scene falls back to keeps its band plan", async () => {
  // The scene shows the radio's own receiver for a selection no longer there; marking only the
  // receiver selected, the panel would leave that pane bare.
  let radios: PanelRadioState[] = dualRadios()
  const hook = createBandScope(
    fakeHost(
      () => radios,
      () => radios[0],
    ),
  )
  const environment = { width: 600, height: 300, typography: { mono: {} } } as unknown as PanelEnvironment
  const render = { ...args("gone", { plan: "edges", spots: false }), environment }
  await hook.render(render, context)
  await hook.onEvent!({ ...render, event: { controlId: "radios", phase: "commit", sequence: 1, action: "select", text: "k4/sub" } }, context)
  radios = [radios[0]]
  const content = await hook.render(render, context)
  const controls = (content as { scene: PanelScene }).scene.controls ?? []
  const spectrum = controls.find((c) => c.id.endsWith("spectrum")) as { layers?: { id: string }[] }
  assert.ok(spectrum.layers?.some((l) => l.id.startsWith("plan:edge:")))
})

test("Main/Sub/Both pins two stable spectrum slots to logical radio IDs", () => {
  const radios = dualRadios()
  for (const selection of [radios[0].id!, radios[1].id!, "both"]) {
    // Host list order does not decide which receiver occupies the first pane.
    const panel = scene(radios[0], { selection }, [...radios].reverse())
    assertValidControls(panel)
    assert.deepEqual(byId(panel, "radios").options, [
      { label: "Main", value: "k4" },
      { label: "Sub", value: "k4/sub" },
      { label: "Both", value: "both" },
    ])
    assert.equal(panel.strings!.selection, selection)
    const layout = panel.layout!
    assert.ok("column" in layout)
    for (const [index, receiver] of radios.entries()) {
      const id = receiver.id!
      const visible = selection === "both" || selection === id
      const control = byId(panel, key(id, "spectrum"))
      assert.equal(control.radio, id)
      assert.equal(control.opacity, visible ? 1 : 0)
      const slot: PanelSceneLayoutNode = layout.column[index + 1]
      assert.ok("column" in slot)
      assert.ok(placedControls(slot).includes(key(id, "spectrum")))
      assert.equal(slot.height, visible ? undefined : 0)
      assert.equal(slot.flex, visible ? 1 : undefined)
      // The selector names the one receiver shown; with both, each pane names its own.
      assert.equal(!!byId(panel, key(id, "heading")), selection === "both")
    }
  }
  assert.equal(scene(radios[1], {}, radios).strings!.selection, radios[1].id, "the designated Sub endpoint is the initial selection")
})

test("each logical radio draws its own scope and passband, with the levels dragged on its own strip", () => {
  const radios = dualRadios()
  const panel = scene(radios[0], { selection: "both", settings: { display: "spectrum", floor: 3 }, views: { "k4/sub": { floor: -5, rows: 25 } } }, radios)
  assertValidControls(panel)
  const main = byId(panel, key("k4", "spectrum")),
    sub = byId(panel, key("k4/sub", "spectrum"))
  assert.deepEqual([main.display, main.floor, main.waterfallSpeed], ["spectrum", 3, 10])
  assert.deepEqual([sub.display, sub.floor, sub.waterfallSpeed], ["spectrum", -5, 25])
  assert.ok(sub.center?.spectrum)
  assert.deepEqual(sub.overlays, [{ from: 300, to: 2400, spectrum: { fill: "#262EC5F0", color: "#992EC5F0" } }])
  radios[1] = { ...radios[1], canTune: false, frequencyHz: null, passband: null }
  const unavailable = byId(scene(radios[0], { selection: "both" }, radios), key("k4/sub", "spectrum"))
  assert.deepEqual(unavailable.center, {})
  assert.deepEqual(unavailable.overlays, [])
})

test("single radios and unrelated devices retain the designated-radio view", () => {
  const [main, sub] = dualRadios()
  for (const [selected, available] of [
    [radio(), []],
    [main, [main, { ...sub, deviceId: "elsewhere" }]],
    [main, [main, sub, { ...sub, id: "third" }]],
  ] as [PanelRadioState, PanelRadioState[]][]) {
    const panel = scene(selected, { selection: "both" }, available)
    assertValidControls(panel)
    assert.equal(!!byId(panel, "radios"), false)
    assert.deepEqual(
      panel.controls!.filter((control) => control.kind === "bandScope").map((control) => control.id),
      ["spectrum"],
    )
    assert.equal(byId(panel, "spectrum").radio, selected.id)
  }
})

test("the zoom, the split and the levels the operator left are kept per radio and pane, and a double click gives the settings back", async (t) => {
  const radios = dualRadios()
  const host = fakeHost(
    () => radios,
    () => radios[0],
  )
  const scopeWrite = t.mock.method(host, "setRadioSpectrum", async () => {
    throw new Error("a kept zoom or level must not command the scope")
  })
  const hook = createBandScope(host)
  const config = { floor: 6, rows: 15 }
  const render = async (instanceId = "one") => {
    const content = await hook.render(args(instanceId, config), context)
    if (content.kind !== "scene") throw new Error("Expected scene")
    assertValidControls(content.scene)
    return content.scene
  }
  let panel = await render()
  const scope = key("k4", "spectrum")
  const told = async (gesture: "zoom" | "pan" | "split" | "floor" | "range" | "speed", value: number) => {
    await hook.onEvent!(
      { ...args("one", config), event: { controlId: scope, action: byId(panel, scope).event!, phase: "commit", sequence: 1, gesture, value } },
      context,
    )
    panel = await render()
  }
  await told("zoom", 36787.9)
  await told("split", 0.62)
  await told("pan", 14072992)
  // Past the form's own ranges but within the app's: kept as dragged, or the picture snaps back.
  await told("floor", 120)
  await told("range", 70)
  await told("speed", 45)
  assert.deepEqual(
    [byId(panel, scope).span, byId(panel, scope).split, byId(panel, scope).floor, byId(panel, scope).range, byId(panel, scope).waterfallSpeed],
    [36788, 0.62, 120, 70, 45],
  )
  await told("speed", 0.5)
  assert.equal(byId(panel, scope).waterfallSpeed, 0.5)
  assert.equal(byId(panel, key("k4/sub", "spectrum")).span, undefined, "each receiver keeps its own")
  assert.equal(byId(panel, key("k4/sub", "spectrum")).floor, 6, "one receiver's drag is not the other's")
  assert.equal(byId(await render("two"), scope).floor, 6, "one pane's drag is not another's")
  // A double click on the strip: the pane's settings back, not a floor of 0, a range of 0 or no waterfall at all.
  await told("floor", 0)
  await told("range", 0)
  await told("speed", 0)
  assert.deepEqual([byId(panel, scope).floor, byId(panel, scope).range, byId(panel, scope).waterfallSpeed], [6, undefined, 15])
  // Kept as span, the zoom is the scene's own: a reset that left it would put the zoom straight back.
  await told("zoom", 0)
  assert.equal(byId(panel, scope).span, undefined)
  // A tune the app could not make itself arrives as a commit with no gesture: not a zoom.
  await hook.onEvent!(
    { ...args("one", config), event: { controlId: scope, action: byId(panel, scope).event!, phase: "commit", sequence: 2, value: 14074000 } },
    context,
  )
  panel = await render()
  assert.equal(byId(panel, scope).span, undefined)
  assert.equal(byId(panel, scope).split, 0.62)
  assert.equal(scopeWrite.mock.callCount(), 0)
})

test("the form's reference level and speed reach each receiver once per change, so the radio's own knob is not fought", async (t) => {
  let radios = dualRadios(),
    designated = radios[0]
  const host = fakeHost(
    () => radios,
    () => designated,
  )
  const scopeWrite = t.mock.method(host, "setRadioSpectrum", async () => ({ accepted: true, state: designated }))
  const hook = createBandScope(host)
  const render = (config: PanelRenderArgs["config"]) => hook.render(args("one", config), context)
  const sent = () => scopeWrite.mock.calls.map((call) => call.arguments[0])
  await render({})
  await render({ speed: "radio", ref: "" })
  assert.deepEqual(sent(), [], "blank and the radio's own send nothing")
  // On the radio's step, within its range; Medium is one of its speeds.
  await render({ ref: "7.6", speed: "mid" })
  assert.deepEqual(sent(), [
    { id: "k4", selection: "k4", refLevelDb: 8, speed: "mid" },
    { id: "k4/sub", selection: "k4/sub", refLevelDb: 8, speed: "mid" },
  ])
  // Every render after holds the same form: the knob turned on the radio meanwhile stays where it was turned.
  await render({ ref: "7.6", speed: "mid" })
  await render({ ref: "7.6", speed: "mid" })
  assert.equal(sent().length, 2)
  await render({ ref: 99, speed: "mid" })
  assert.deepEqual(sent().slice(2), [
    { id: "k4", selection: "k4", refLevelDb: 30 },
    { id: "k4/sub", selection: "k4/sub", refLevelDb: 30 },
  ])
  // A radio without the speed, or whose scope is down, is not asked for it.
  radios = [
    { ...radios[0], spectrum: { ...spectrum, speeds: ["slow"] } },
    { ...radios[1], spectrum: { ...spectrum, problem: "Spectrum disconnected" } },
  ]
  designated = radios[0]
  await render({ ref: 99, speed: "fast" })
  assert.equal(sent().length, 4)
})

test("a reference level sent before the pane's scope runs goes out again once it does", async (t) => {
  const radios = [radio()]
  const host = fakeHost(
    () => radios,
    () => radios[0],
  )
  let running = false
  const scopeWrite = t.mock.method(host, "setRadioSpectrum", async () =>
    running ? { accepted: true, state: radios[0] } : { accepted: false, reason: "stopped" as const, state: radios[0] },
  )
  const hook = createBandScope(host)
  // The first render comes before the scope control has mounted and started the scope.
  await hook.render(args("one", { ref: -10, speed: "fast" }), context)
  running = true
  await hook.render(args("one", { ref: -10, speed: "fast" }), context)
  await hook.render(args("one", { ref: -10, speed: "fast" }), context)
  assert.equal(scopeWrite.mock.callCount(), 2, "sent again once running, then not again")
  assert.deepEqual(scopeWrite.mock.calls[1].arguments[0], { id: "k4", selection: "k4", refLevelDb: -10, speed: "fast" })
})

test("a reference level the radio could not be sent goes out again on the next render", async (t) => {
  const radios = [radio()]
  const host = fakeHost(
    () => radios,
    () => radios[0],
  )
  let down = true
  const scopeWrite = t.mock.method(host, "setRadioSpectrum", async () => {
    if (down) throw new Error("radio reconnecting")
    return { accepted: true, state: radios[0] }
  })
  const hook = createBandScope(host)
  // Recorded as sent before the call, a send that failed would never be tried again.
  await assert.rejects(hook.render(args("one", { ref: -10 }), context))
  down = false
  await hook.render(args("one", { ref: -10 }), context)
  await hook.render(args("one", { ref: -10 }), context)
  assert.deepEqual(
    scopeWrite.mock.calls.map((call) => call.arguments[0]),
    [
      { id: "k4", selection: "k4", refLevelDb: -10 },
      { id: "k4", selection: "k4", refLevelDb: -10 },
    ],
  )
})

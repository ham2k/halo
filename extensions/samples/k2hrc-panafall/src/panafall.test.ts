// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MIT
import { test } from "node:test"
import assert from "node:assert/strict"
import { host } from "@ham2k/extension-sdk"
import type { PanelRadioSpectrum, PanelRadioState, PanelRenderArgs, PanelScene, PanelSceneLayoutNode } from "@ham2k/extension-sdk"
import { createPanafall, scene } from "./panafall.ts"

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

test("fixed-mode K4 capabilities render span, local reference and all speeds", () => {
  const panel = scene(radio())
  assertValidControls(panel)
  const controls = new Map(panel.controls!.map((control) => [control.id, control]))
  assert.deepEqual(
    controls.get("span")!.options!.map((option) => option.value),
    ["12000", "24000", "48000"],
  )
  assert.deepEqual(
    controls.get("speed")!.options!.map((option) => option.value),
    ["slow", "mid", "fast"],
  )
  assert.equal(controls.get("ref")!.min, -30)
  assert.equal(controls.get("ref")!.max, 30)
  assert.equal(panel.strings!.span, "48000")
  assert.equal(panel.strings!.speed, "mid")
  assert.equal(controls.has("mode"), false)
  assert.equal(controls.has("center"), false)
})

test("each capability independently controls its knob and paired layout", () => {
  for (let mask = 0; mask < 8; mask++) {
    const span = (mask & 1) !== 0
    const ref = (mask & 2) !== 0
    const speed = (mask & 4) !== 0
    const panel = scene(radio({ spansHz: span ? spectrum.spansHz : [], refMaxDb: ref ? 30 : -30, speeds: speed ? spectrum.speeds : [] }))
    assertValidControls(panel)
    const ids = new Set(panel.controls!.map((control) => control.id))
    assert.equal(ids.has("span"), span)
    assert.equal(ids.has("ref"), ref)
    assert.equal(ids.has("label-Ref"), ref)
    assert.equal(ids.has("speed"), speed)
    assert.ok(ids.has("spectrum"))
    assert.ok(ids.has("floor"))
  }
})

test("a missing or unavailable spectrum keeps the local display controls usable", () => {
  for (const state of [null, radio({ problem: "Spectrum disconnected" })]) {
    const panel = scene(state, { views: { [state?.id ?? ""]: { display: "waterfall" } } })
    assertValidControls(panel)
    const ids = new Set(panel.controls!.map((control) => control.id))
    for (const id of ["span", "ref", "label-Ref", "speed"]) assert.equal(ids.has(id), false)
    for (const id of ["floor", "average", "fps", "rows", "display", "spectrum"]) assert.equal(ids.has(id), true)
    assert.equal(ids.has("step"), state?.canTune === true)
  }
})

test("a capability change cannot leave stale dropdown selections or an out-of-range reference", () => {
  const panel = scene(radio({ spansHz: [12000], speeds: ["slow"], refLevelDb: 42 }), { views: { k4: { display: "pan" } } })
  assertValidControls(panel)
  assert.equal(panel.strings!.span, "")
  assert.equal(panel.strings!.speed, "")
  assert.equal(panel.values.ref, 30)
  const unknownRef = scene(radio({ refLevelDb: null, refMinDb: 10 }))
  assertValidControls(unknownRef)
  assert.equal(unknownRef.values.ref, 10)
})

test("an unusable reference range omits both the slider and its label", () => {
  for (const overrides of [{ refMinDb: 31 }, { refStepDb: 0 }, { refStepDb: -1 }]) {
    const panel = scene(radio(overrides))
    assertValidControls(panel)
    assert.equal(
      panel.controls!.some((control) => control.id === "ref" || control.id === "label-Ref"),
      false,
    )
  }
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

const args = (instanceId = "one"): PanelRenderArgs => ({ instanceId, panelKey: "panafall", operation: {}, qsoCount: 0, config: {}, reason: "initial" })
const context = { online: false }
const key = (id: string, control: string) => `${encodeURIComponent(id)}-${control}`
const byId = (panel: PanelScene, id: string) => panel.controls!.find((control) => control.id === id)!

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
      assert.equal("channel" in control, false, "receiver identity belongs to radio, not a second spectrum selector")
      assert.equal(control.opacity, visible ? 1 : 0)
      const slot: PanelSceneLayoutNode = layout.column[index + 1]
      assert.ok("column" in slot)
      assert.ok(placedControls(slot).includes(key(id, "spectrum")))
      assert.equal(slot.height, visible ? undefined : 0)
      assert.equal(slot.flex, visible ? 1 : undefined)
      assert.equal(!!byId(panel, key(id, "floor")), selection === id)
    }
  }
  assert.equal(scene(radios[1], {}, radios).strings!.selection, radios[1].id, "the designated Sub endpoint is the initial selection")
})

test("Both reserves waterfall space with bounded span and reference toolbars", () => {
  for (let mask = 0; mask < 4; mask++) {
    const radios = dualRadios()
    for (const receiver of radios) {
      receiver.spectrum!.spansHz = mask & 1 ? spectrum.spansHz : []
      receiver.spectrum!.refMaxDb = mask & 2 ? 30 : -30
    }
    const panel = scene(radios[0], { selection: "both" }, radios)
    assertValidControls(panel)
    const layout = panel.layout!
    assert.ok("column" in layout)
    for (const [index, receiver] of radios.entries()) {
      const id = receiver.id!
      const slot: PanelSceneLayoutNode = layout.column[index + 1]
      assert.ok("column" in slot)
      assert.deepEqual(placedControls(slot), [
        key(id, "heading"),
        ...(mask & 1 ? [key(id, "span")] : []),
        ...(mask & 2 ? [key(id, "label-Ref"), key(id, "ref")] : []),
        key(id, "spectrum"),
      ])
      const toolbar: PanelSceneLayoutNode = slot.column[0]
      assert.ok("wrap" in toolbar)
      if (mask & 1) {
        const span: PanelSceneLayoutNode | undefined = toolbar.wrap.find((node: PanelSceneLayoutNode) => "control" in node && node.control === key(id, "span"))
        assert.equal(span?.width, 120)
      }
      assert.equal(slot.column[1].flex, 1, "the spectrum receives the rest of its pane")
    }
  }
})

test("each logical radio draws its own scope, filter and tuning affordances", () => {
  const radios = dualRadios()
  const panel = scene(
    radios[0],
    {
      selection: "both",
      views: {
        k4: { display: "pan", floor: 10 },
        "k4/sub": { display: "waterfall", floor: -5, rows: 25 },
      },
    },
    radios,
  )
  assertValidControls(panel)
  assert.equal(panel.strings![key("k4", "span")], "48000")
  assert.equal(panel.strings![key("k4/sub", "span")], "12000")
  assert.deepEqual(
    byId(panel, key("k4/sub", "span")).options!.map((option) => option.value),
    ["3000", "6000", "12000"],
  )
  assert.equal(panel.values[key("k4", "floor")], 10)
  assert.equal(panel.values[key("k4/sub", "floor")], -5)
  assert.equal(panel.values[key("k4/sub", "rows")], 25)
  const main = byId(panel, key("k4", "spectrum")),
    sub = byId(panel, key("k4/sub", "spectrum"))
  assert.equal(main.display, "pan")
  assert.equal(sub.display, "waterfall")
  assert.ok(main.event && sub.event && main.event !== sub.event)
  assert.equal(sub.tuneStep, 100)
  assert.ok(sub.center?.pan)
  assert.deepEqual(sub.overlays![0], { from: 300, to: 2400, pan: { fill: "#262EC5F0", color: "#992EC5F0" } })
  assert.ok(sub.annotations!.every((annotation) => annotation.event))
  radios[1] = { ...radios[1], canTune: false, frequencyHz: null, passband: null }
  const unavailable = byId(scene(radios[0], { selection: "both" }, radios), key("k4/sub", "spectrum"))
  assert.equal(unavailable.event, undefined)
  assert.equal(unavailable.tuneStep, undefined)
  assert.deepEqual(unavailable.center, {})
  assert.ok(unavailable.overlays!.every((overlay) => overlay.anchor === "absolute"))
  assert.ok(unavailable.annotations!.every((annotation) => annotation.event == null))
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
      panel.controls!.filter((control) => control.kind === "spectrum").map((control) => control.id),
      ["spectrum"],
    )
    assert.equal(byId(panel, "spectrum").radio, selected.id)
    assert.ok(byId(panel, "floor"))
  }
})

test("view preferences follow logical radio IDs across toggles, devices and panel instances", async (t) => {
  const hook = createPanafall()
  let radios = dualRadios(),
    designated = radios[0]
  t.mock.method(host, "readRadio", async (id?: string) => (id ? (radios.find((receiver) => receiver.id === id) ?? null) : designated))
  t.mock.method(host, "listRadios", async () => radios)
  const radioWrite = t.mock.method(host, "setRadio", async () => {
    throw new Error("local preferences must not tune")
  })
  const scopeWrite = t.mock.method(host, "setRadioSpectrum", async () => {
    throw new Error("local preferences must not change a scope")
  })
  const render = async (instanceId = "one") => {
    const content = await hook.render(args(instanceId), context)
    assert.equal(content.kind, "scene")
    if (content.kind !== "scene") throw new Error("Expected scene")
    assertValidControls(content.scene)
    return content.scene
  }
  let panel = await render()
  const event = async (controlId: string, payload: { value?: number; text?: string }) => {
    const control = byId(panel, controlId)
    assert.ok(control?.event, `${controlId} must be visible and actionable`)
    await hook.onEvent!({ ...args(), event: { controlId, action: control.event, phase: "commit", sequence: 1, ...payload } }, context)
    panel = await render()
  }
  await event(key("k4", "floor"), { value: 12 })
  await event(key("k4", "average"), { value: 80 })
  await event(key("k4", "fps"), { value: 8 })
  await event(key("k4", "display"), { text: "pan" })
  await event("radios", { text: "k4/sub" })
  await event(key("k4/sub", "floor"), { value: -8 })
  await event(key("k4/sub", "rows"), { value: 22 })
  await event(key("k4/sub", "step"), { text: "500" })
  await event(key("k4/sub", "display"), { text: "waterfall" })
  for (const selection of ["both", "k4", "k4/sub", "both"]) {
    await event("radios", { text: selection })
    assert.equal(panel.values[key("k4", "floor")], 12)
    assert.equal(panel.values[key("k4", "average")], 80)
    assert.equal(panel.values[key("k4", "fps")], 8)
    assert.equal(panel.values[key("k4/sub", "floor")], -8)
    assert.equal(panel.values[key("k4/sub", "rows")], 22)
    assert.equal(panel.strings![key("k4", "display")], "pan")
    assert.equal(panel.strings![key("k4/sub", "display")], "waterfall")
    assert.equal(byId(panel, key("k4/sub", "spectrum")).tuneStep, 500)
    for (const receiver of radios) {
      assert.equal(!!byId(panel, key(receiver.id!, "floor")), selection === receiver.id, "absent controls retain their preferences")
    }
  }
  const other = await render("two")
  assert.equal(other.strings!.selection, "k4")
  assert.equal(other.values[key("k4", "floor")], 0)
  assert.equal(other.values[key("k4/sub", "floor")], 0)
  radios = dualRadios("another-device", "another-main", "another-sub")
  designated = radios[0]
  panel = await render()
  assert.equal(panel.strings!.selection, "another-main")
  assert.equal(panel.values[key("another-main", "floor")], 0, "matching Main labels cannot share preferences across devices")
  radios = dualRadios()
  designated = radios[0]
  panel = await render()
  assert.equal(panel.values[key("k4", "floor")], 12)
  assert.equal(panel.values[key("k4/sub", "floor")], -8)
  designated = radios[1]
  panel = await render()
  assert.equal(panel.strings!.selection, "k4/sub", "a changed designated receiver remains the default selection")
  assert.equal(radioWrite.mock.callCount(), 0)
  assert.equal(scopeWrite.mock.callCount(), 0)
})

test("scope and tuning commands pin the exact logical radio and reject stale identities", async (t) => {
  const hook = createPanafall()
  let radios = dualRadios(),
    designated = radios[0]
  t.mock.method(host, "readRadio", async (id?: string) => (id ? (radios.find((receiver) => receiver.id === id) ?? null) : designated))
  t.mock.method(host, "listRadios", async () => radios)
  const scopeWrite = t.mock.method(host, "setRadioSpectrum", async () => ({ accepted: true, state: designated }))
  const radioWrite = t.mock.method(host, "setRadio", async () => ({ accepted: true, state: designated }))
  const render = async () => {
    const content = await hook.render(args(), context)
    if (content.kind !== "scene") throw new Error("Expected scene")
    return content.scene
  }
  let panel = await render()
  const send = async (action: string, payload: { value?: number; text?: string }) => {
    await hook.onEvent!({ ...args(), event: { controlId: "control", action, phase: "commit", sequence: 1, ...payload } }, context)
  }
  await send(byId(panel, key("k4", "span")).event!, { text: "24000" })
  await send(byId(panel, "radios").event!, { text: "k4/sub" })
  panel = await render()
  await send(byId(panel, key("k4/sub", "ref")).event!, { value: 8 })
  await send(byId(panel, key("k4/sub", "speed")).event!, { text: "slow" })
  assert.deepEqual(
    scopeWrite.mock.calls.map((call) => call.arguments[0]),
    [
      { id: "k4", selection: "k4", spanHz: 24000 },
      { id: "k4/sub", selection: "k4/sub", refLevelDb: 8 },
      { id: "k4/sub", selection: "k4/sub", speed: "slow" },
    ],
  )
  const sub = byId(panel, key("k4/sub", "spectrum"))
  await send(sub.event!, { value: 7045123 })
  await send(sub.annotations![0].event!, { value: 14070000 })
  assert.deepEqual(
    radioWrite.mock.calls.map((call) => call.arguments[0]),
    [
      { id: "k4/sub", selection: "k4/sub", frequencyHz: 7045123 },
      { id: "k4/sub", selection: "k4/sub", frequencyHz: 14070000 },
    ],
  )
  radios[1] = { ...radios[1], canTune: false }
  await send(sub.event!, { value: 7045000 })
  assert.equal(radioWrite.mock.callCount(), 2, "capability is checked again when a stale tuning event arrives")
  const staleScope = byId(panel, key("k4/sub", "ref")).event!
  radios = dualRadios("other-device", "other-main", "other-sub")
  designated = radios[0]
  await render()
  await send(staleScope, { value: 10 })
  assert.equal(scopeWrite.mock.callCount(), 3, "an old device's controls cannot affect the newly selected device")
})

// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MIT
import { test } from "node:test"
import assert from "node:assert/strict"
import type { PanelRadioSpectrum, PanelRadioState, PanelScene, PanelSceneLayoutNode } from "@ham2k/extension-sdk"
import { scene } from "./panafall.ts"

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
  const panel = scene(radio(), "both")
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
    const panel = scene(radio({ spansHz: span ? spectrum.spansHz : [], refMaxDb: ref ? 30 : -30, speeds: speed ? spectrum.speeds : [] }), "both")
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
    const panel = scene(state, "waterfall")
    assertValidControls(panel)
    const ids = new Set(panel.controls!.map((control) => control.id))
    for (const id of ["span", "ref", "label-Ref", "speed"]) assert.equal(ids.has(id), false)
    for (const id of ["floor", "average", "fps", "rows", "step", "display", "spectrum"]) assert.equal(ids.has(id), true)
  }
})

test("a capability change cannot leave stale dropdown selections or an out-of-range reference", () => {
  const panel = scene(radio({ spansHz: [12000], speeds: ["slow"], refLevelDb: 42 }), "pan")
  assertValidControls(panel)
  assert.equal(panel.strings!.span, "")
  assert.equal(panel.strings!.speed, "")
  assert.equal(panel.values.ref, 30)
  const unknownRef = scene(radio({ refLevelDb: null, refMinDb: 10 }), "both")
  assertValidControls(unknownRef)
  assert.equal(unknownRef.values.ref, 10)
})

test("an unusable reference range omits both the slider and its label", () => {
  for (const overrides of [{ refMinDb: 31 }, { refStepDb: 0 }, { refStepDb: -1 }]) {
    const panel = scene(radio(overrides), "both")
    assertValidControls(panel)
    assert.equal(
      panel.controls!.some((control) => control.id === "ref" || control.id === "label-Ref"),
      false,
    )
  }
})

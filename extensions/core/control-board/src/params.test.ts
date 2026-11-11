// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
import { test } from "node:test"
import assert from "node:assert/strict"
import type { PanelRadioSet, PanelRenderArgs } from "@ham2k/extension-sdk"
import type { BoardHost } from "./actions.ts"
import { BoardError, parseBoard } from "./board.ts"
import { compileBoard, stampOf } from "./compile.ts"
import { createBoardPanel } from "./panel.ts"
import { paramsForm } from "./params.ts"
import { sampleBoard } from "./sample.ts"

const board = `
params:
  rig: { type: radio, label: Transceiver }
  rot: { type: rotator }
  band: { type: choice, options: [40m, { value: 20m, label: Twenty }] }
sources:
  rig: { radio: "{{ params.rig }}" }
  rot: { rotator: "{{ params.rot }}" }
items:
  - { type: label, text: "{{ params.band }}" }
  - { type: button, label: Swap, onPress: { setParam: { rig: "{{ params.other }}", band: 20m } } }
  - { type: button, label: North, onPress: { turnRotator: { source: rot, azimuth: 0 } } }
`
const stamp = stampOf(board)

function fakeHost() {
  const calls: { call: string; args: unknown }[] = []
  const host: BoardHost = {
    readRadio: async (id?: string) => ({ id: id ?? "logging" }) as never,
    setRadio: async (args: PanelRadioSet) => (calls.push({ call: "setRadio", args }), { accepted: true }) as never,
    setRotator: async (args) => (calls.push({ call: "setRotator", args }), { accepted: true }) as never,
    stopRotator: async () => ({ accepted: true }) as never,
    setAntenna: async () => ({ accepted: true }) as never,
    showMessage: async (message) => void calls.push({ call: "showMessage", args: message }),
  }
  return { host, calls }
}

const args = (config: Record<string, unknown>, event?: Record<string, unknown>) =>
  ({
    panelKey: "board",
    instanceId: "board#1",
    operation: {},
    qsoCount: 0,
    reason: "test",
    config,
    ...(event ? { event: { controlId: "c", phase: "activate", sequence: 1, ...event } } : {}),
  }) as unknown as PanelRenderArgs & { event: never }

test("a board's params are the placement's own form, its pickers the station's own lists", () => {
  const form = paramsForm(parseBoard(board).params)!
  assert.equal(form.key, "params", "the values are one object under the key the descriptor declares in `config`")
  assert.deepEqual(
    form.elements.map((e) => [(e as { key: string }).key, (e as { options?: unknown }).options, (e as { none?: string }).none]),
    [
      // An unset radio is the designated one, and the picker says so; an unset rotator is none.
      ["rig", "$core.radios", "Designated radio"],
      ["rot", "$core.rotators", "None"],
      [
        "band",
        [
          { label: "40m", value: "40m" },
          { label: "Twenty", value: "20m" },
        ],
        undefined,
      ],
    ],
  )
  assert.equal(paramsForm(parseBoard("items: []").params), undefined, "a board with no params offers no form")
})

test("a source's id is Liquid on the params: an unset radio is the designated one, an unset rotator none at all", () => {
  const compile = (params: Record<string, string>) =>
    compileBoard(parseBoard(board), undefined, {}, (t) => t.replace(/\{\{ params\.(\w+) \}\}/g, (_, k) => params[k] ?? ""), "s").scene.sources
  assert.deepEqual(compile({ rig: "ic-7300", rot: "az-1" }), { rig: { radio: "ic-7300" }, rot: { rotator: "az-1" } })
  // The scene takes no empty id: an unset rotator names one nothing answers to, so its readings are missing.
  assert.deepEqual(compile({}), { rig: { radio: null }, rot: { rotator: "unset" } })
})

test("params are refused in words, before the board is drawn", () => {
  const refused = (text: string, pattern: RegExp) =>
    assert.throws(
      () => parseBoard(text),
      (e: unknown) => e instanceof BoardError && pattern.test(e.message),
    )
  refused("params: { rig: { type: transceiver } }", /type is one of radio, rotator/)
  refused("params: { pick: { type: choice, options: [a] } }", /a choice of 2 to 32 options/)
  refused("params: { rig: { type: radio, options: [a, b] } }", /takes `options` only as a choice/)
  refused("items:\n  - { type: button, label: x, onPress: { setParam: { nope: 1 } } }", /names a param the board does not have: `nope`/)
})

test("the placement's params render in its Liquid, and an unset one renders empty", async () => {
  const panel = createBoardPanel(fakeHost().host)
  const content = await panel.render(args({ board, params: { band: "20m" } }), {} as never)
  const scene = (content as { scene: { layers: { text?: { literal?: string; value?: string } }[] } }).scene
  assert.ok(JSON.stringify(scene.layers).includes('"20m"'), "the label shows the placement's band")
  assert.deepEqual((content as { form?: { key: string } }).form?.key, "params")
  assert.deepEqual((content as { menu?: unknown }).menu, [{ label: "Edit Board…", settings: true }])
})

test("setParam answers the placement's config, keeping only the board's own params", async () => {
  const { host } = fakeHost()
  const panel = createBoardPanel(host)
  const answer = await panel.onEvent!(args({ board, params: { rig: "a", band: "40m", stale: "x" } }, { action: `a:${stamp}:1` }), {} as never)
  // `params.other` is no param of this board: it renders empty, which for a radio is the designated one.
  assert.deepEqual(answer.config, { params: { rig: "", band: "20m" } })
})

test("an action after a setParam commands the equipment it just picked, not the one before", async () => {
  const swap = `
params:
  rig: { type: radio }
sources:
  rig: { radio: "{{ params.rig }}" }
items:
  - { type: button, label: Two, onPress: [{ setParam: { rig: radio2 } }, { setRadio: { source: rig, mode: CW } }] }
`
  const { host, calls } = fakeHost()
  const answer = await createBoardPanel(host).onEvent!(args({ board: swap, params: { rig: "radio1" } }, { action: `a:${stampOf(swap)}:0` }), {} as never)
  // Aimed by the params the event started with, CW would key the transmitter just switched away from.
  assert.deepEqual(calls, [{ call: "setRadio", args: { mode: "CW", id: "radio2", selection: "radio2" } }])
  assert.deepEqual(answer.config, { params: { rig: "radio2" } })
})

test("setParam keeps a choice's own value, a number where the board wrote one, and refuses one it does not offer", async () => {
  const steps = (to: string) => `
params:
  step: { type: choice, options: [10, 100] }
items:
  - { type: button, label: Fine, onPress: { setParam: { step: ${to} } } }
`
  const { host, calls } = fakeHost()
  const panel = createBoardPanel(host)
  // Kept as "100", Board Settings would show no option picked, and its Save would clear it.
  const kept = await panel.onEvent!(args({ board: steps("100") }, { action: `a:${stampOf(steps("100"))}:0` }), {} as never)
  assert.deepEqual(kept.config, { params: { step: 100 } })
  const refused = await panel.onEvent!(args({ board: steps("5") }, { action: `a:${stampOf(steps("5"))}:0` }), {} as never)
  assert.equal(refused.config, undefined)
  assert.match((calls[0].args as { text: string }).text, /`step` has no option 5/)
})

test("a rotator param left unset refuses its actions, saying where to pick one", async () => {
  const { host, calls } = fakeHost()
  const panel = createBoardPanel(host)
  await panel.onEvent!(args({ board }, { action: `a:${stamp}:2` }), {} as never)
  assert.deepEqual(calls, [{ call: "showMessage", args: { presentation: "status", text: "`rot` names no rotator; pick one in Board Settings" } }])
})

test("an imported file is kept with its params cleared; one that is no board is refused and kept out", async () => {
  const { host, calls } = fakeHost()
  const panel = createBoardPanel(host)
  const file = { controlId: "file", action: "file" }
  const kept = await panel.onEvent!(args({ board: "", params: { rig: "here" } }, { ...file, text: sampleBoard }), {} as never)
  // Another station's radio ids mean nothing here.
  assert.deepEqual(kept.config, { board: sampleBoard, params: {} })
  const refused = await panel.onEvent!(args({ board: "" }, { ...file, text: "items: [" }), {} as never)
  assert.equal(refused.config, undefined)
  assert.match((calls[0].args as { text: string }).text, /^That file is not a board this app can read: /)
  // Read as an empty board, a file event without its text would erase the pane's board.
  await assert.rejects(panel.onEvent!(args({ board: sampleBoard }, file), {} as never))
})

test("the Sample board starts each placement from its own copy, and draws as written", async () => {
  const panels = await createBoardPanel(fakeHost().host).getPanels({}, {} as never)
  const sample = panels.find((p) => p.key === "sample")!
  assert.deepEqual(sample.initialConfig, { board: sampleBoard })
  assert.deepEqual(sample.config, ["params"], "params are kept beside the board, and travel with it in a layout file")
  assert.deepEqual(sample.file, { key: "board", extension: "h2kboard" })
  const content = await createBoardPanel(fakeHost().host).render(args({ board: sampleBoard }), {} as never)
  assert.equal(content.kind, "scene", content.kind === "markdown" ? content.content : "")
})

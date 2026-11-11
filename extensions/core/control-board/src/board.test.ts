// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
import { test } from "node:test"
import assert from "node:assert/strict"
import type { PanelRadioSet, PanelRenderArgs } from "@ham2k/extension-sdk"
import { actionsFor, runActions, type BoardHost } from "./actions.ts"
import { BoardError, maxBoardItems, maxBoardNodes, parseBoard } from "./board.ts"
import { compileBoard, stampOf } from "./compile.ts"
import { createBoardPanel } from "./panel.ts"
import { resolveSources } from "./params.ts"

const words = (t: string) => t

const station = `
ham2k-board: 1
name: Station
sources:
  rig: { radio: null }
  rot: { rotator: rot-1 }
vars:
  drive: 40
  details: false
items:
  - { type: needle, value: rig.signalDbm, min: -130, max: -10, label: S }
  - { type: ledBar, value: rig.signalDbm, min: -130, max: -10, segments: 12, hold: 1000, zones: [[-40, error]] }
  - { type: frequency, value: rig.frequencyHz }
  - { type: segmented, value: rig.mode, options: [CW, USB], onSelect: { setRadio: { mode: $value } } }
  - { type: toggle, var: details, label: Details }
  - { type: knob, var: drive, min: 0, max: 100, onChange: { turnRotator: { source: rot, azimuth: $value } } }
  - type: group
    title: Rotator
    columns: 4
    items:
      - { type: readout, value: rot.azimuth, suffix: "°" }
      - { type: button, label: North, onPress: { turnRotator: { source: rot, azimuth: 0 } } }
      - { type: menuButton, label: Turn, items: [{ label: East, onSelect: { turnRotator: { source: rot, azimuth: 90 } } }] }
`
const stamp = stampOf(station)

test("a board's YAML is read with its sources, vars and nested groups", () => {
  const board = parseBoard(station)
  assert.equal(board.name, "Station")
  assert.deepEqual(board.sources, { rig: { radio: null }, rot: { rotator: "rot-1" } })
  assert.deepEqual(board.vars, { drive: 40, details: 0 }, "true and false are 1 and 0, as a toggle's lamp tests them")
  assert.equal((board.items[6] as unknown as { items: unknown[] }).items.length, 3)
  assert.deepEqual(board.items[3].options, [{ value: "CW" }, { value: "USB" }], "a bare option is its own value")
})

// Each refusal is one an operator can act on: it names what is wrong and where, before the app
// would refuse the scene with no more than "could not be displayed".
test("a board that cannot be drawn is refused in words that say where", () => {
  const refused = (text: string, pattern: RegExp) =>
    assert.throws(
      () => parseBoard(text),
      (e: unknown) => e instanceof BoardError && pattern.test(e.message),
      text,
    )
  const radio = "sources: { rig: { radio: null } }\nvars: { on: 1, word: x }\nitems:\n"
  refused("items: [", /not valid YAML/)
  refused(`${radio}  - { type: gauge }`, /item 1 has an unknown type `gauge`/)
  refused(`${radio}  - { type: needle, value: rig.signalDBm }`, /a radio gives no `signalDBm`/)
  refused(`${radio}  - { type: needle, value: rig.mode }`, /needs a number, and `rig.mode` is a word/)
  refused(`${radio}  - { type: button, label: Go, onpress: { setRadio: { mode: CW } } }`, /has no `onpress`/)
  refused(`${radio}  - { type: button, label: Go }`, /needs an `onPress`/)
  refused(`${radio}  - { type: label, text: x, color: red }`, /theme color/)
  refused(`${radio}  - { type: label, text: x, when: { value: var.on } }`, /exactly one test/)
  refused(`${radio}  - { type: label, text: x, when: { value: rig.mode, is: 7 } }`, /tests a word with `is: 7`/)
  refused(`${radio}  - { type: toggle, var: on, when: { value: var.on, is: 1 } }`, /lights by a condition of its own/)
  refused(`${radio}  - { type: group, when: { value: var.on, is: 1 }, items: [] }`, /has no `when`/)
  refused(`${radio}  - { type: toggle, var: word }`, /needs a number/)
  refused(`${radio}  - { type: button, label: Go, onPress: { setVar: { name: on, value: $value } } }`, /has no value to give it/)
  refused(`${radio}  - { type: knob, var: on, onChange: { setRadio: { startTune: true } } }`, /keys the radio, so it goes on a press/)
  refused(`${radio}  - { type: segmented, value: rig.mode, options: [20, 40], onSelect: { setRadio: { mode: $value } } }`, /options are words/)
  refused(`${radio}  - { type: ledBar, value: rig.powerOut, zones: [[80, error], [50, primary]] }`, /rise in order/)
  refused(`${radio}  - { type: knob, var: on, min: 5, max: 5 }`, /`max` \(5\) is not above its `min` \(5\)/)
  refused("sources: { var: { radio: null } }", /cannot name a source/)
  refused('sources: { rig: { radio: "" } }', /names no radio/)
  refused("vars: { constructor: 1 }\nitems:\n  - { type: toggle, var: toString }", /var the board does not have/)
  refused("ham2k-board: 2", /newer version/)
})

test("a review's second pass: what the app would refuse is refused first, by the board", () => {
  const radio = "sources: { rig: { radio: null } }\nvars: { on: 1 }\nitems:\n"
  // Text takes six digits only; eight would compile to a scene the app refuses whole.
  assert.throws(() => parseBoard(`${radio}  - { type: label, text: x, color: "#ff000080" }`), /theme color/)
  // A tune goes alone: beside a mode the host refuses it on every press.
  assert.throws(() => parseBoard(`${radio}  - { type: button, label: T, onPress: { setRadio: { mode: CW, startTune: true } } }`), /goes alone/)
  const compiled = (text: string) => compileBoard(parseBoard(text), undefined, {}, (t) => t.replace("{{ op.station }}", "N0DEV"), "s")
  assert.throws(() => compiled(`unit: [32, 32]\n${radio}  - { type: knob, var: on, span: [1, 1], label: Drive }`), /too small for its parts/)
  const many = Array.from({ length: 260 }, () => "  - { type: button, label: x, onPress: { setVar: { name: on, value: 1 } } }").join("\n")
  assert.throws(() => compiled(`${radio}${many}`), /The board draws \d+ (layers|controls), and a panel holds at most/)
  // Words a widget draws are Liquid wherever they appear, a readout's suffix too.
  const { scene } = compiled(`${radio}  - { type: readout, value: var.on, suffix: " {{ op.station }}" }`)
  assert.ok(scene.layers.some((l) => (l.text as { suffix?: string })?.suffix === " N0DEV"))
})

test("a frequency a knob turns is a dial turning, which the app settles as the radio's own", () => {
  const board = parseBoard(
    "vars: { f: 14074000 }\nitems:\n  - { type: knob, var: f, min: 14000000, max: 14350000, onChange: { setRadio: { frequencyHz: $value } } }",
  )
  assert.deepEqual((board.items[0].onChange as { setRadio: { dial?: boolean } }[])[0].setRadio.dial, true)
})

test("a path through an item that is not a group names nothing, said as the board's", () => {
  assert.throws(
    () => actionsFor(parseBoard(station), stamp, `a:${stamp}:0.1`, undefined),
    (e: unknown) => e instanceof BoardError && /no item 1.2/.test(e.message),
  )
})

test("an empty board is an empty board, not an error", () => {
  assert.deepEqual(parseBoard("").items, [])
})

test("aliases are counted each time they repeat, anywhere, so a few lines cannot make a board of millions", () => {
  // Each level doubles the one before: under items or under any key, millions of values to walk.
  for (const tail of ["items: [*a12]", "items:\n  - { type: label, text: x, when: { value: var.x, in: *a12 } }"]) {
    const lines = ["vars: { x: 1 }", "a0: &a0 [1, 2]"]
    for (let i = 1; i <= 12; i++) lines.push(`a${i}: &a${i} [*a${i - 1}, *a${i - 1}]`)
    lines.push(tail)
    assert.throws(
      () => parseBoard(lines.join("\n")),
      (e: unknown) => e instanceof BoardError && (e.message.includes(`${maxBoardNodes} values`) || e.message.includes(`${maxBoardItems} items`)),
    )
  }
})

test("an alias that names a map it is inside of is refused, not walked until the stack runs out", () => {
  assert.throws(
    () => parseBoard("a: &x [1, *x]\nitems: []"),
    (e: unknown) => e instanceof BoardError && e.message.includes(`${maxBoardNodes} values`),
  )
})

test("a board has at most the sixteen sources a scene takes", () => {
  const sources = Array.from({ length: 17 }, (_, i) => `  s${i}: { radio: null }`).join("\n")
  assert.throws(() => parseBoard(`sources:\n${sources}`), /at most 16 sources/)
})

test("merge keys are not YAML a board reads: `<<` is a key the board does not take", () => {
  assert.throws(
    () => parseBoard("items:\n  - { <<: { type: label, text: x }, span: [2, 1] }"),
    (e: unknown) => e instanceof BoardError && /unknown type/.test(e.message),
  )
})

test("a board compiles to cells sized by their spans, on a grid of the same unit", () => {
  const { scene } = compileBoard(parseBoard(station), undefined, {}, words, stamp)
  const needle = scene.cells!.find((c) => c.id === "w0")!
  assert.deepEqual([needle.width, needle.height], [3 * 48 + 2 * 4, 2 * 48 + 4], "a needle's default span, 3 by 2")
  assert.equal(scene.values["var.drive"], 40)
  const layout = scene.layout as { grid: { cell?: string; grid?: unknown[] }[]; unit: number[] }
  assert.equal(layout.grid[6].grid!.length, 3, "a group is a grid of its own")
  assert.equal(new Set(scene.layers.map((l) => l.id)).size, scene.layers.length, "every layer id is the scene's only one")
  // An S-meter from -130 in 10-dB segments lights whole segments, counted from its own bottom.
  const lit = scene.layers.find((l) => l.id === "w1-lit")!
  assert.deepEqual({ offset: lit.clipX!.offset, scale: lit.clipX!.scale, input: lit.clipX!.input }, { offset: 130, scale: 0.1, input: [0, 12] })
  // A knob is always heard, so the board keeps its var: unheard, the next event's answer would put it back.
  assert.equal(scene.controls!.find((c) => c.id === "w5-turn")!.event, `c:${stamp}:5`)
})

test("a widget too wide for its grid, or too small to draw, is refused before the app would", () => {
  const refused = (text: string, pattern: RegExp) =>
    assert.throws(
      () =>
        compileBoard(
          parseBoard(text),
          undefined,
          {},
          (t) =>
            t.includes("|")
              ? (() => {
                  throw new Error("bad filter")
                })()
              : t,
          "s",
        ),
      (e: unknown) => e instanceof BoardError && pattern.test(e.message),
    )
  refused("columns: 3\nsources: { rig: { radio: null } }\nitems:\n  - { type: bar, value: rig.swr }", /item 1 spans 4 columns of a grid with 3/)
  refused("unit: [8, 8]\nsources: { rig: { radio: null } }\nitems:\n  - { type: needle, value: rig.swr }", /item 1 is 32 by 20 pixels/)
  refused(
    "columns: 2\nitems:\n  - type: group\n    items: [{ type: label, text: x, span: [3, 1] }]",
    /item 1 needs 3 columns of the grid it is in, which has 2/,
  )
  refused("items:\n  - { type: label, text: '{{ op.station | }}' }", /The Liquid in item 1 cannot be rendered/)
})

function fakeHost() {
  const calls: { call: string; args: unknown }[] = []
  const ok = async (call: string, args: unknown) => {
    calls.push({ call, args })
    return { accepted: true } as never
  }
  const host: BoardHost = {
    readRadio: async (id?: string) => ({ id: id ? `${id}-now` : "logging-now" }) as never,
    setRadio: (args: PanelRadioSet) => ok("setRadio", args),
    setRotator: (args) => ok("setRotator", args),
    stopRotator: (args) => ok("stopRotator", args),
    setAntenna: (args) => ok("setAntenna", args),
    showMessage: async (message) => void calls.push({ call: "showMessage", args: message }),
  }
  return { host, calls }
}

const run = async (host: BoardHost, event: string, value?: number | string, vars: Record<string, number | string> = {}, text = words) => {
  const board = parseBoard(station)
  const { actions, value: v, sets } = actionsFor(board, stamp, event, value)
  const next = { ...vars, ...sets }
  await runActions(host, actions, { board, sources: resolveSources(board, text), vars: next, params: {}, value: v, text })
  return next
}

test("a pick sends the option as $value, upper case as the radio's modes are, to the radio by its id now", async () => {
  const { host, calls } = fakeHost()
  await run(host, `s:${stamp}:3:1`)
  assert.deepEqual(calls, [{ call: "setRadio", args: { mode: "USB", id: "logging-now" } }])
})

test("a nested button turns its source's rotator; a menu entry its own way", async () => {
  const { host, calls } = fakeHost()
  await run(host, `a:${stamp}:6.1`)
  await run(host, `m:${stamp}:6.2:0`)
  assert.deepEqual(
    calls.map((c) => c.args),
    [
      { id: "rot-1", azimuth: 0 },
      { id: "rot-1", azimuth: 90 },
    ],
  )
})

test("an event from a board since edited is refused, not run on whatever item is there now", () => {
  assert.throws(() => actionsFor(parseBoard(station), stamp, `a:stale:6.1`, undefined), /changed since/)
})

test("text that renders empty is refused, never sent as 0: no rotator turns north for a blank bearing", async () => {
  // A bearing from the call being typed renders empty while no call is entered.
  const text =
    "sources: { rot: { rotator: r } }\nitems:\n  - { type: button, label: Aim, onPress: { turnRotator: { source: rot, azimuth: '{{ qso.their.bearing }}' } } }"
  const board = parseBoard(text)
  const { host, calls } = fakeHost()
  const { actions } = actionsFor(board, stampOf(text), `a:${stampOf(text)}:0`, undefined)
  await assert.rejects(
    runActions(host, actions, { board, sources: resolveSources(board, words), vars: {}, params: {}, text: () => "" }),
    /azimuth came out empty/,
  )
  assert.deepEqual(calls, [])
})

test("a knob's own value is taken as the number it is, a step near zero included", async () => {
  // A knob from -1.5 in 0.1 steps sends 2e-16 at its middle: as text that is no plain decimal.
  const { host, calls } = fakeHost()
  await run(host, `c:${stamp}:5`, 2.220446049250313e-16)
  assert.deepEqual(calls[0].args, { id: "rot-1", azimuth: 2.220446049250313e-16 })
})

test("a toggle with a var flips it; a knob sets its var from what it sends", async () => {
  const { host } = fakeHost()
  assert.equal((await run(host, `a:${stamp}:4`)).details, 1)
  assert.equal((await run(host, `c:${stamp}:5`, 72)).drive, 72)
})

const args = (config: string, event?: { action: string; value?: number }) =>
  ({
    panelKey: "board",
    instanceId: "board#1",
    operation: {},
    qsoCount: 0,
    reason: "test",
    config: { board: config },
    ...(event ? { event: { controlId: "c", phase: "activate", sequence: 1, ...event } } : {}),
  }) as unknown as PanelRenderArgs & { event: never }

test("a refusal is a status notice, and the control goes back to where the board has it", async () => {
  const { host, calls } = fakeHost()
  host.setRotator = async () => ({ accepted: false, reason: "disconnected" }) as never
  const panel = createBoardPanel(host)
  const answer = await panel.onEvent!(args(station, { action: `c:${stamp}:5`, value: 72 }), {} as never)
  assert.deepEqual(calls, [{ call: "showMessage", args: { presentation: "status", text: "The rotator did not take it: disconnected" } }])
  assert.deepEqual(answer.values, { "var.drive": 40 }, "the knob is put back; the var was never kept")
})

test("an event from a board since edited puts every control back, saying the board changed", async () => {
  const { host, calls } = fakeHost()
  const panel = createBoardPanel(host)
  const answer = await panel.onEvent!(args(station, { action: `c:stale:5`, value: 72 }), {} as never)
  assert.match((calls[0].args as { text: string }).text, /changed since/)
  assert.deepEqual(answer.values, { "var.drive": 40, "var.details": 0 }, "no item named: every var, as the board has it")
})

test("an event on a board edited into something unreadable says so, rather than failing to report", async () => {
  const { host, calls } = fakeHost()
  const panel = createBoardPanel(host)
  const answer = await panel.onEvent!(args("items: [", { action: `a:${stamp}:4` }), {} as never)
  assert.match((calls[0].args as { text: string }).text, /not valid YAML/)
  assert.deepEqual(answer, { values: {}, strings: {} })
})

test("an answer names only the vars the event changed, so a knob still held keeps its place", async () => {
  const { host } = fakeHost()
  const panel = createBoardPanel(host)
  const answer = await panel.onEvent!(args(station, { action: `a:${stamp}:4` }), {} as never)
  assert.deepEqual(answer.values, { "var.details": 1 })
})

test("a named radio is set by the id just read for it: the set path takes a node's id, not every name a read accepts", async () => {
  const { host, calls } = fakeHost()
  const text = "sources: { front: { radio: Front } }\nitems:\n  - { type: button, label: CW, onPress: { setRadio: { source: front, mode: cw } } }"
  const board = parseBoard(text)
  const { actions } = actionsFor(board, stampOf(text), `a:${stampOf(text)}:0`, undefined)
  await runActions(host, actions, { board, sources: resolveSources(board, words), vars: {}, params: {}, text: words })
  assert.deepEqual(calls, [{ call: "setRadio", args: { mode: "CW", id: "Front-now", selection: "Front-now" } }])
})

test("a path names a widget only through groups, by whole numbers: a menu's entries are not items", () => {
  for (const path of ["6.2.0", "6.x", "6.", "", "1e0"]) {
    assert.throws(
      () => actionsFor(parseBoard(station), stamp, `a:${stamp}:${path}`, undefined),
      (e: unknown) => e instanceof BoardError && /The board has no item/.test(e.message),
      path,
    )
  }
})

test("what every widget needs is refused when missing, by the board, before any widget reads it", () => {
  for (const [type, key] of [
    ["readout", "value"],
    ["frequency", "value"],
    ["bar", "value"],
    ["ledBar", "value"],
    ["needle", "value"],
    ["knob", "var"],
    ["slider", "var"],
  ]) {
    assert.throws(
      () => parseBoard(`items:\n  - { type: ${type}${type === "bar" ? ", adjustable: true" : ""} }`),
      (e: unknown) => e instanceof BoardError && e.message === `item 1 needs a \`${key}\``,
      type,
    )
  }
})

test("a condition on a number takes true and false as 1 and 0, and a quoted version is the version", () => {
  const board = parseBoard(
    `ham2k-board: "1"\nsources: { rig: { radio: null } }\nitems:\n  - { type: label, text: TX, when: { value: rig.transmitting, is: true } }\n  - { type: label, text: RX, when: { value: rig.transmitting, in: [false] } }`,
  )
  assert.equal(board.items[0].when?.is, 1)
  assert.deepEqual(board.items[1].when?.in, [0])
})

test("a choice of words whose pick would set a number to one is refused when read, not at every pick", () => {
  for (const action of ["{ setVar: { name: drive, value: $value } }", "{ setRadio: { frequencyHz: $value } }"]) {
    assert.throws(
      () => parseBoard(`vars: { drive: 40, band: 40m }\nitems:\n  - { type: segmented, value: var.band, options: [40m, 20m], onSelect: ${action} }`),
      (e: unknown) => e instanceof BoardError && /options are words, and its `onSelect` sets the number/.test(e.message),
      action,
    )
  }
})

test("cells past what the app takes, LED segments too thin to draw, and runaway titles are refused by the board", () => {
  const refused = (text: string, pattern: RegExp, render: (t: string) => string = words) =>
    assert.throws(
      () => compileBoard(parseBoard(text), undefined, {}, render, "s"),
      (e: unknown) => e instanceof BoardError && pattern.test(e.message),
    )
  refused("unit: [200, 48]\nitems:\n  - { type: label, text: x, span: [64, 1] }", /a cell is at most 8192 either way/)
  refused(
    "sources: { rig: { radio: null } }\nitems:\n  - { type: ledBar, value: rig.swr, segments: 64, span: [2, 1] }",
    /64 segments in \d+ pixels leaves each under 3/,
  )
  refused("items:\n  - type: group\n    title: '{{ long }}'\n    items: [{ type: label, text: x }]", /comes out 300 characters long, at most 256/, (t) =>
    t.includes("{{") ? "x".repeat(300) : t,
  )
})

test("two board texts get two stamps, and an edit changes the stamp", () => {
  assert.notEqual(stampOf(station), stampOf(`${station} `))
  assert.notEqual(stampOf("a"), stampOf("b"))
})

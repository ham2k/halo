// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
import { test } from "node:test"
import assert from "node:assert/strict"
import type {
  BoardSpot,
  GetSpotsOptions,
  HookContext,
  PanelEnvironment,
  PanelRadioSet,
  PanelRadioState,
  PanelRenderArgs,
  PanelScene,
  PanelSceneEvent,
  SuggestedQso,
} from "@ham2k/extension-sdk"
import { createBandScope, type BandScopeHost } from "./band-scope.ts"
import { scopeBackground, scopeSpots, spotMarks, type ScopeSpot } from "./spots.ts"

const now = 1_800_000_000_000

/** 14.000–14.100 MHz across a 1000 px pane: 100 Hz a pixel. */
const radio: PanelRadioState = {
  id: "k4",
  name: "K4",
  status: "connected",
  stale: false,
  problem: null,
  frequencyHz: 14050000,
  mode: "CW",
  modes: ["CW", "USB", "LSB", "DATA-USB"],
  powerWatts: 10,
  transmitting: false,
  meters: {},
  canTune: true,
  spectrum: {
    problem: null,
    mode: "fixed",
    spanHz: 50000,
    lowHz: 14000000,
    highHz: 14100000,
    refLevelDb: 0,
    speed: "mid",
    spansHz: [50000],
    refMinDb: -30,
    refMaxDb: 30,
    refStepDb: 1,
    modes: ["fixed"],
    speeds: ["mid"],
  },
}

const typography = { fontFamily: "RobotoMono", fontFamilyFallback: [], fontSize: 14, scaledFontSize: 14, fontWeight: 400, lineHeight: 1.2, letterSpacing: 0 }
const environment = {
  version: 1,
  width: 1000,
  height: 400,
  safeInsets: { left: 0, top: 0, right: 0, bottom: 0 },
  brightness: "dark",
  colors: {},
  typography: { body: typography, label: typography, title: typography, display: typography, mono: typography },
  locale: "en",
  textDirection: "ltr",
  devicePixelRatio: 2,
  reducedMotion: false,
  highContrast: false,
} as unknown as PanelEnvironment

function spot(call: string, khz: number, extra: Partial<BoardSpot> & { ageMinutes?: number; source?: string } = {}): BoardSpot {
  const { ageMinutes = 1, source = "pota", ...rest } = extra
  return { their: { call }, freq: khz, band: "20m", spot: { timeInMillis: now - ageMinutes * 60000, source }, ...rest }
}

function harness(board: BoardSpot[]) {
  const asked: GetSpotsOptions[] = [],
    suggested: SuggestedQso[] = [],
    tuned: PanelRadioSet[] = []
  let accepts = true
  let fetched: Promise<void> | undefined
  const host: BandScopeHost = {
    readRadio: async () => radio,
    listRadios: async () => [radio],
    setRadioSpectrum: async () => ({ accepted: true, state: radio }),
    setRadio: async (args) => (tuned.push(args), { accepted: true, state: radio }),
    suggestQso: async ({ qso }) => (suggested.push(qso), { accepted: accepts }),
  }
  const ctx = {
    online: false,
    getSpots: async (options?: GetSpotsOptions) => (asked.push(options ?? {}), await fetched, board),
  } as unknown as HookContext
  const hook = createBandScope(host)
  const args = (config: PanelRenderArgs["config"] = {}): PanelRenderArgs => ({
    instanceId: "one",
    panelKey: "band-scope",
    operation: { uuid: "op-1" },
    qsoCount: 0,
    config,
    reason: "initial",
    environment,
    clock: { nowMillis: now, realNowMillis: now },
  })
  const render = async (config: PanelRenderArgs["config"] = {}) => {
    const content = await hook.render(args(config), ctx)
    assert.equal(content.kind, "scene")
    return (content as { scene: PanelScene }).scene.controls!.find((c) => c.id === "spectrum")!
  }
  const event = (event: Partial<PanelSceneEvent>) =>
    hook.onEvent!({ ...args(), event: { controlId: "spectrum", phase: "commit", sequence: 1, action: "", ...event } }, ctx)
  /** Holds every fetch of the spots until the function returned is called. */
  const hold = () => {
    let release = () => {}
    fetched = new Promise((resolve) => (release = resolve))
    return () => ((fetched = undefined), release())
  }
  return { render, event, asked, suggested, tuned, refuse: () => (accepts = false), hold }
}

const offsets = (scope: { annotations?: { id: string; offset?: unknown }[] }) => Object.fromEntries((scope.annotations ?? []).map((a) => [a.id, a.offset]))

test("spots too close to read apart go to separate lanes, and a zoom that spreads them lays them out again", async () => {
  // 300 Hz apart is 3 px at the whole sweep: one box would hide the other.
  const { render, event } = harness([spot("K1ABC", 14030.0), spot("W2XYZ", 14030.3)])
  // The band plan's labels take the spectrum's top, leaving a pane this short one lane.
  let scope = await render({ plan: "none" })
  const wide = offsets(scope)
  assert.notEqual(wide["spot:K1ABC"], wide["spot:W2XYZ"], "overlapping boxes must not share a lane")
  // Each box has its leader from the spectrum's foot, so a box in a far lane still points at its frequency.
  assert.deepEqual(
    scope.layers?.filter((l) => l.id.startsWith("leader:")).map((l) => l.x),
    ["freq:14030000", "freq:14030300"],
  )

  // Zoomed to 5 kHz across the pane, 300 Hz is 60 px: room for both beside the axis. The app
  // zooms natively, so without laying out again on the zoom's commit they would stay apart.
  await event({ action: "scope:k4", gesture: "zoom", value: 5000 })
  scope = await render({ plan: "none" })
  const narrow = offsets(scope)
  assert.equal(narrow["spot:K1ABC"], narrow["spot:W2XYZ"])
})

test("spots stand where the settings put them over the noise, 30 dB by default, on any radio's scale; on the waterfall only where there is no spectrum", async () => {
  const { render } = harness([spot("K1ABC", 14030)])
  const scope = await render()
  const both = scope.annotations![0]
  // Measured from the noise, not in pixels: a radio's floor and range move the picture under it.
  assert.deepEqual([both.part, both.y, both.offset], ["spectrum", "noise+30db", 4])
  // Its leader rises from the spectrum's foot, through its signal, to the box.
  const leader = scope.layers!.find((l) => l.id === "leader:K1ABC")!
  assert.deepEqual([leader.y, leader.y2], ["spectrum:bottom+0px", "noise+30db-4px"])
  // Under the noise when negative: the coordinate must say so, or the boxes would stand as far over it.
  const low = await render({ spotLevel: -10 })
  assert.equal(low.annotations![0].y, "noise-10db")
  assert.equal(low.layers!.find((l) => l.id === "leader:K1ABC")!.y2, "noise-10db-4px")
  assert.equal((await render({ spotLevel: "lots" })).annotations![0].y, "noise+30db", "an unreadable height keeps the default")
  const alone = (await render({ display: "spectrum" })).annotations![0]
  assert.deepEqual([alone.part, alone.y], ["spectrum", "noise+30db"])
  const falls = (await render({ display: "waterfall" })).annotations![0]
  assert.equal(falls.part, "waterfall", "a part not shown draws nothing on it")
  assert.equal(falls.y, undefined)
  assert.ok((falls.offset as number) > 26, "clear of the axis over the waterfall's head")
})

test("on the axis, a dot marks each spot's frequency and a bar the stretch its mode will be heard over", () => {
  const spots: ScopeSpot[] = [
    { call: "K1SSB", khz: 7200, mode: "SSB", refs: [], ageMinutes: 0, worked: false, isSelf: false, fresh: false },
    { call: "K1USB", khz: 14250, mode: "SSB", refs: [], ageMinutes: 0, worked: false, isSelf: false, fresh: false },
    { call: "K1CW", khz: 14030, mode: "CW", refs: [], ageMinutes: 0, worked: false, isSelf: false, fresh: false },
    { call: "K1ANY", khz: 14060, refs: [], ageMinutes: 0, worked: false, isSelf: false, fresh: false },
  ]
  const { layers } = spotMarks(spots, { hzPerPx: 100, lanes: 3, part: "spectrum", clear: 0, maxAgeMinutes: 30, event: "spot:k4" })
  const byId = (id: string) => layers.find((l) => l.id === id)
  // SSB is lower sideband on 40 m and upper on 20 m: the bar is where to listen, not the dial alone.
  assert.deepEqual([byId("passband:K1SSB")?.x, byId("passband:K1SSB")?.x2], ["freq:7197200", "freq:7200000"])
  assert.deepEqual([byId("passband:K1USB")?.x, byId("passband:K1USB")?.x2], ["freq:14250000", "freq:14252800"])
  assert.deepEqual([byId("passband:K1CW")?.x, byId("passband:K1CW")?.x2], ["freq:14029875", "freq:14030125"])
  assert.equal(byId("passband:K1ANY"), undefined, "a spot naming no mode has no stretch to show")
  // The dot is the same size at any zoom, centred on the axis line where the leader starts.
  assert.deepEqual(
    [byId("dot:K1ANY")?.x, byId("dot:K1ANY")?.x2, byId("dot:K1ANY")?.y, byId("dot:K1ANY")?.y2],
    ["freq:14060000-3px", "freq:14060000+3px", "spectrum:bottom-3px", "spectrum:bottom+3px"],
  )
  assert.equal(byId("leader:K1ANY")?.width, 3)
})

test("a spot's box is the scope's own background, see-through, underlined in its colour rather than boxed in", () => {
  const spots: ScopeSpot[] = [{ call: "K1ABC", khz: 14030, refs: [], ageMinutes: 0, worked: false, isSelf: false, fresh: true }]
  const [box] = spotMarks(spots, { hzPerPx: 100, lanes: 1, part: "spectrum", clear: 0, maxAgeMinutes: 30, event: "spot:k4" }).annotations
  assert.equal((box.background as string).slice(3), scopeBackground.slice(1))
  assert.ok(parseInt((box.background as string).slice(1, 3), 16) < 255, "the signals under it still show")
  assert.deepEqual([box.borderEdges, box.borderWidth, (box.borderColor as string).slice(3)], ["near", 1, (box.color as string).slice(3)])
})

test("when the lanes run out, something new keeps its place over the worked and the old", () => {
  const spots: ScopeSpot[] = [
    { call: "W1OLD", khz: 14030, refs: [], ageMinutes: 2, worked: true, isSelf: false, fresh: false },
    { call: "K9NEW", khz: 14030.1, refs: [], ageMinutes: 25, worked: false, isSelf: false, fresh: true },
    { call: "N0MID", khz: 14030.2, refs: [], ageMinutes: 5, worked: false, isSelf: false, fresh: false },
  ]
  const marks = spotMarks(spots, { hzPerPx: 100, lanes: 2, part: "spectrum", clear: 0, maxAgeMinutes: 30, event: "spot:k4" })
  assert.deepEqual(
    marks.annotations.map((a) => a.id),
    ["spot:K9NEW", "spot:N0MID"],
    "a new one first, then the unworked: the worked one is what the operator can do without",
  )
})

test("older spots fade, and a source's icon comes with its call", () => {
  const spots: ScopeSpot[] = [
    { call: "K1NEW", khz: 14010, refs: [], ageMinutes: 0, worked: false, isSelf: false, fresh: false, icon: "pine-tree", iconColor: "#2E7D32" },
    { call: "K1OLD", khz: 14090, refs: [], ageMinutes: 30, worked: false, isSelf: false, fresh: false },
  ]
  const [fresh, old] = spotMarks(spots, { hzPerPx: 100, lanes: 3, part: "waterfall", clear: 26, maxAgeMinutes: 30, event: "spot:k4" }).annotations
  assert.equal((fresh.color as string).slice(0, 3), "#FF")
  assert.ok(parseInt((old.color as string).slice(1, 3), 16) < 128, "the oldest asked for is drawn faint")
  assert.deepEqual(fresh.icon, { name: "pine-tree", color: "#FF2E7D32" })
  assert.equal(old.icon, undefined)
})

test("one spot a station: where the newest report puts it, with the references of them all, and no stand-in tower", () => {
  const spots = scopeSpots(
    [
      spot("K1ABC", 14062, { source: "cluster" }),
      spot("K1ABC", 14061, { ageMinutes: 8, refs: [{ type: "potaActivation", ref: "US-0001" }], display: { icon: "pine-tree", iconColor: "#2E7D32" } }),
      spot("W2XYZ", 14020, { source: "cluster", display: { icon: "radio-tower" } }),
    ],
    now,
  )
  assert.deepEqual(
    spots.map((s) => [s.call, s.khz, s.refs.map((r) => r.ref), s.icon]),
    [
      ["K1ABC", 14062, ["US-0001"], "pine-tree"],
      ["W2XYZ", 14020, [], undefined],
    ],
  )
})

test("a click on a spot works it as a Spots Panel tap; with no operation to take it, the radio tunes there", async () => {
  const { render, event, suggested, tuned, refuse } = harness([spot("K1ABC", 14250.5, { mode: "SSB", refs: [{ type: "potaActivation", ref: "US-0001" }] })])
  await render()
  await event({ action: "scope:k4", phase: "activate" })
  assert.equal(suggested.length, 0, "a click on the picture is the app's to tune, not a spot")

  await event({ action: "spot:k4", phase: "activate", annotation: "spot:K1ABC" })
  assert.deepEqual(suggested, [{ their: { call: "K1ABC" }, freq: 14250.5, band: "20m", mode: "SSB", refs: [{ type: "potaActivation", ref: "US-0001" }] }])
  assert.deepEqual(tuned, [], "the logging fields move the radio themselves")

  refuse()
  await event({ action: "spot:k4", phase: "activate", annotation: "spot:K1ABC" })
  assert.deepEqual(tuned, [{ id: "k4", frequencyHz: 14250500, mode: "USB" }])
})

test("two band tags of one text, or two calls copied alike, are two places on the band, each worked where it is", async () => {
  // Grouped by call like a station's reports, the second "QRM" would vanish under the first.
  const tag = (khz: number, ageMinutes: number) => {
    const s = spot("QRM", khz, { ageMinutes, source: "local" })
    return { ...s, spot: { ...s.spot, tag: true } }
  }
  const { render, event, suggested } = harness([tag(14020, 1), tag(14250, 2), spot("W1A?", 14030, { mode: "CW" }), spot("W1A?", 14300, { mode: "SSB" })])
  const scope = await render({ plan: "none" })
  const ids = (scope.annotations ?? []).map((a) => a.id).sort()
  assert.deepEqual(ids, ["spot:QRM@14020", "spot:QRM@14250", "spot:W1A?@14030", "spot:W1A?@14300"])
  await event({ action: "spot:k4", phase: "activate", annotation: "spot:QRM@14250" })
  assert.deepEqual(
    suggested.map((q) => [q.their?.call, q.freq]),
    [["QRM", 14250]],
  )
})

test("a click while the spots are being fetched again works the spot on the screen", async () => {
  // A render re-fetches the spots every tick: emptied before the fetch and filled after, the
  // table of spots would drop any click landing in between, with nothing to say so.
  const { render, event, suggested, hold } = harness([spot("K1ABC", 14250.5, { mode: "SSB" })])
  await render()
  const release = hold()
  const again = render()
  await new Promise((resolve) => setTimeout(resolve, 0))
  await event({ action: "spot:k4", phase: "activate", annotation: "spot:K1ABC" })
  assert.equal(suggested.length, 1)
  release()
  await again
})

test("the spots asked for are the radio's band's, as old as the pane says; switched off, none", async () => {
  const { render, asked } = harness([spot("K1ABC", 14030)])
  await render({ age: 10 })
  assert.deepEqual(asked, [{ filter: "sources", band: "20m", maxAgeMinutes: 10 }])
  const off = await render({ spots: false })
  assert.equal(asked.length, 1)
  assert.equal(off.annotations, undefined)
})

test("the band plan is drawn across the whole band, not only about the dial", async () => {
  // The operator pans natively and the panel hears where only when a pan ends: drawn about the
  // dial alone, the band's far edge would be missing once the picture was panned to it.
  const { render } = harness([])
  const scope = await render({ plan: "edges" })
  assert.deepEqual(
    scope.layers?.filter((l) => l.id.startsWith("plan:edge:")).map((l) => l.id),
    ["plan:edge:14000", "plan:edge:14350"],
  )
})

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
import { test } from "node:test"
import assert from "node:assert/strict"
import type { BandAnnotation, HeldBandAnnotation, PanelSceneSpectrumLayer } from "@ham2k/extension-sdk"
import { annotationsFor } from "../../band-plan/src/plan.ts"
import { planLayers, type PlanDetail } from "./band-plan.ts"
import { spotMarks, type ScopeSpot } from "./spots.ts"

/** As the host hands them over: each on its band, its importance set, with its source. */
const held = (band: string, said: BandAnnotation[], source = "band-plan"): HeldBandAnnotation[] =>
  said.map((a) => ({ ...a, band, importance: a.importance ?? "primary", source }))
const plan = (band: string, station = "N0CALL") => held(band, annotationsFor(band, station))
const layout = { hzPerPx: 250, top: "spectrum", rows: 2, window: [13900000, 14450000] as [number, number], most: 64, height: 200 }
/** The US plan with no license levels: they get a test of their own. */
const unlicensed = (band: string) => plan(band, "K1AA").filter((a) => !(a.type === "plan" && a.importance === "secondary"))
const drawn = (detail: PlanDetail, annotations = unlicensed("20m")) => planLayers(annotations, detail, layout)
const texts = (layers: PanelSceneSpectrumLayer[]) => layers.filter((l) => l.kind === "text").map((l) => l.text?.trim())
const ids = (layers: PanelSceneSpectrumLayer[], prefix: string) => layers.filter((l) => l.id.startsWith(prefix)).map((l) => l.x)
const licenseLabels = (layers: PanelSceneSpectrumLayer[]) => layers.filter((l) => l.id.startsWith("plan:license-label:")).map((l) => l.text)
const band20 = (said: BandAnnotation[]) => held("20m", said, "test")

test("each level of the band plan adds to the one before, and No draws nothing", () => {
  assert.deepEqual(drawn("none"), [])
  const edges = drawn("edges")
  // The band's own ends, solid, with what lies past them dimmed: a signal there is out of band.
  assert.deepEqual(ids(edges, "plan:edge:"), ["freq:14000000-1.5px", "freq:14350000-1.5px"])
  assert.equal(edges.filter((l) => l.id.startsWith("plan:out:")).length, 2)
  assert.deepEqual(texts(edges), [], "edges alone write nothing")
  const modes = drawn("modes")
  assert.ok(edges.every((l) => modes.some((m) => m.id === l.id)))
  // FT4's label would land on FT8's, a row down from Data's: at this zoom only its veil shows.
  assert.deepEqual(texts(modes), ["CW", "Data", "CW", "Phone", "FT8"])
  assert.ok(modes.some((l) => l.id === "plan:area:band-plan:window:FT4:14080"))
  const all = drawn("all")
  assert.ok(modes.every((l) => all.some((m) => m.id === l.id)))
  assert.ok(texts(all).includes("🕯️ CW QRP"), "a tertiary annotation shows only at All")
  assert.ok(!texts(modes).includes("🕯️ CW QRP"))
  // A window or a marker is the stretch it covers, veiled, and its label: lines would crowd the picture.
  assert.deepEqual(
    all.filter((l) => l.kind === "line").map((l) => l.id),
    ["plan:mode:14070000", "plan:mode:14095000", "plan:mode:14150000"],
  )
})

test("a known window is veiled with its label boxed over it, without splitting the stretch it sits in", () => {
  const modes = drawn("modes")
  assert.deepEqual(
    modes.filter((l) => l.id.startsWith("plan:mode-label:")).map((l) => [l.x, l.text]),
    [
      ["freq:14000000+8px", "CW"],
      ["freq:14070000+8px", "Data"],
      ["freq:14095000+8px", "CW"],
      ["freq:14150000+8px", "Phone"],
    ],
  )
  const ft8 = modes.find((l) => l.id === "plan:area:band-plan:window:FT8:14074")!
  assert.deepEqual([ft8.kind, ft8.x, ft8.x2], ["rect", "freq:14074000", "freq:14077000"])
  // Over the spectrum alone: down the waterfall it would hide the signals' history.
  assert.deepEqual([ft8.y, ft8.y2], ["spectrum", "spectrum:bottom"])
  // Its label centred over it, on a box as wide as the window where the text fits in it, and as
  // wide as the text, still centred, where it does not.
  const label = modes.find((l) => l.id === "plan:place:band-plan:window:FT8:14074")!
  assert.deepEqual([label.x, label.align], ["freq:14075500", "center"])
  const narrow = modes.find((l) => l.id === "plan:box:band-plan:window:FT8:14074")!
  assert.deepEqual([narrow.x, narrow.x2], ["freq:14075500-13px", "freq:14075500+13px"])
  const zoomed = planLayers(unlicensed("20m"), "modes", { ...layout, hzPerPx: 20 }).find((l) => l.id === "plan:box:band-plan:window:FT8:14074")!
  assert.deepEqual([zoomed.x, zoomed.x2], ["freq:14074000", "freq:14077000"])
  // Each change of kind gets its own line; the band's edge already marks where CW starts.
  assert.deepEqual(ids(modes, "plan:mode:"), ["freq:14070000", "freq:14095000", "freq:14150000"])
  // A mode's label sits on a tag fading into its stretch; a window's has none.
  assert.deepEqual(ids(modes, "plan:mode-tag:"), ["freq:14000000", "freq:14070000", "freq:14095000", "freq:14150000"])
})

test("a label goes at the top where it clears the others, else a row down; with no room, only its area shows", () => {
  const said = band20([
    { type: "edge", fromHz: 14000000, toHz: 14350000 },
    { type: "known", key: "one", fromHz: 14099875, toHz: 14100125, label: "🔔 One" },
    { type: "known", key: "two", fromHz: 14100375, toHz: 14100625, label: "🔔 Two" },
    { type: "known", key: "three", fromHz: 14100875, toHz: 14101125, label: "🔔 Three" },
  ])
  const layers = planLayers(said, "all", layout)
  assert.deepEqual(
    layers.filter((l) => l.id.startsWith("plan:place:")).map((l) => [l.text, l.y]),
    [
      ["🔔 One", "spectrum+3.5px"],
      ["🔔 Two", "spectrum+20.5px"],
    ],
  )
  assert.equal(layers.filter((l) => l.id.startsWith("plan:area:")).length, 3)
  // Its label, wider than what it covers, stands out past it either side.
  const box = layers.find((l) => l.id === "plan:box:test:one")!
  assert.ok(String(box.x).startsWith("freq:14100000-") && String(box.x2).startsWith("freq:14100000+"))
  // A place, not a stretch, is a thin veil about it.
  const place = planLayers(band20([{ type: "known", fromHz: 14100000, label: "Here" }]), "modes", layout).find((l) => l.id.startsWith("plan:area:"))!
  assert.deepEqual([place.x, place.x2], ["freq:14100000-1px", "freq:14100000+1px"])
})

test("a known annotation's suggested color is its box's", () => {
  const layers = planLayers(band20([{ type: "known", key: "net", fromHz: 14300000, toHz: 14303000, label: "Net", color: "#AA3344" }]), "modes", layout)
  assert.equal(layers.find((l) => l.id === "plan:box:test:net")?.fill, "#AA3344")
})

test("only what falls near the radio is drawn, and never more than the plan's share of the layers", () => {
  const near = planLayers(plan("20m", "K1AA"), "all", { ...layout, window: [14250000, 14350000] })
  assert.ok(!near.some((l) => l.text === "FT8"), "a window far off the scope spends no layers")
  assert.equal(planLayers(plan("20m", "K1AA"), "all", { ...layout, most: 3 }).length, 3)
  // The spots take what the plan leaves of the 128 layers a band scope takes.
  const spots: ScopeSpot[] = Array.from({ length: 40 }, (_, i) => ({
    call: `K${i}AA`,
    khz: 14000 + i * 10,
    mode: "CW",
    refs: [],
    ageMinutes: 0,
    worked: false,
    isSelf: false,
    fresh: false,
  }))
  const { layers } = spotMarks(spots, { hzPerPx: 1, lanes: 1, part: "spectrum", clear: 0, maxAgeMinutes: 30, event: "spot", layers: 30 })
  assert.equal(layers.length, 30)
})

test("each license level's privileges are marked where they start and stop, several at one place in one label", () => {
  const layers = planLayers(plan("20m"), "modes", layout)
  // The General's CW ends at 14150, where the US phone starts, and "Phone" says it.
  assert.deepEqual(licenseLabels(layers), ["General", "General"])
  assert.deepEqual(ids(planLayers(plan("20m"), "edges", layout), "plan:license"), [])
  const eighty = planLayers(plan("80m"), "modes", { ...layout, hzPerPx: 20, window: [3400000, 4100000] })
  assert.ok(licenseLabels(eighty).includes("Technician, General"))
  // A station the regulators are not known for sees none.
  assert.deepEqual(licenseLabels(planLayers(plan("20m", "ZZ0ZZ"), "modes", layout)), [])
})

test("a level's end gives way to a mode's start or the band's edge at it, or under its label", () => {
  const said = band20([
    { type: "edge", fromHz: 14000000, toHz: 14350000 },
    { type: "plan", fromHz: 14000000, toHz: 14150000, label: "CW" },
    { type: "plan", fromHz: 14150000, toHz: 14350000, label: "Phone" },
    { type: "plan", fromHz: 14025000, toHz: 14150000, label: "General", importance: "secondary" },
    { type: "plan", fromHz: 14225000, toHz: 14350000, label: "General", importance: "secondary" },
  ])
  // Once phone starts where the General's CW stops, "Phone" says it; both labels would only collide.
  // Where the General's phone meets the band's end, the edge says it.
  assert.deepEqual(licenseLabels(planLayers(said, "modes", { ...layout, hzPerPx: 100 })), ["General", "General"])
  // A start is kept: where privileges begin is news even beside a mode's start.
  const near = band20([
    { type: "edge", fromHz: 14000000, toHz: 14350000 },
    { type: "plan", fromHz: 14150000, toHz: 14350000, label: "Phone" },
    { type: "plan", fromHz: 14152000, toHz: 14350000, label: "General", importance: "secondary" },
  ])
  assert.deepEqual(licenseLabels(planLayers(near, "modes", { ...layout, hzPerPx: 100 })), ["General"])
})

test("mode starts closer than a label's width put the later label a row down, not on the first", () => {
  // Zoomed out on 80 m, CW, Data and Phone start about 30 kHz apart: in one row, the tags would
  // overlap and the dark labels run into each other.
  const said = held("80m", [
    { type: "edge", fromHz: 3500000, toHz: 3600000 },
    { type: "plan", fromHz: 3500000, toHz: 3510000, label: "CW" },
    { type: "plan", fromHz: 3510000, toHz: 3600000, label: "Phone" },
  ])
  const layers = planLayers(said, "modes", { ...layout, hzPerPx: 800, window: [3400000, 3700000] })
  assert.deepEqual(
    layers.filter((l) => l.id.startsWith("plan:mode-label:")).map((l) => [l.text, l.y]),
    [
      ["CW", "spectrum+2px"],
      ["Phone", "spectrum+19px"],
    ],
  )
})

test("the plan's share of the layers is spent on whole marks, never a box without its label", () => {
  const all = planLayers(plan("20m", "K1AA"), "all", layout)
  for (let most = 1; most <= all.length; most++) {
    const kept = planLayers(plan("20m", "K1AA"), "all", { ...layout, most })
    assert.ok(kept.length <= most)
    const has = (id: string) => kept.some((l) => l.id === id)
    for (const l of kept) {
      const [, part, ...rest] = l.id.split(":")
      if (part === "box") assert.ok(has(`plan:place:${rest.join(":")}`), `${l.id} at ${most}`)
      if (part.endsWith("-tag")) assert.ok(has(`plan:${part.replace("-tag", "-label")}:${rest.join(":")}`), `${l.id} at ${most}`)
    }
  }
})

test("two allocated stretches of a band are each edged, with the gap between them out of band", () => {
  const said = held("60m", [
    { type: "edge", fromHz: 5330000, toHz: 5340000 },
    { type: "edge", fromHz: 5350000, toHz: 5360000 },
  ])
  const layers = planLayers(said, "edges", { ...layout, window: [5300000, 5400000] })
  assert.deepEqual(ids(layers, "plan:edge:"), ["freq:5330000-1.5px", "freq:5340000-1.5px", "freq:5350000-1.5px", "freq:5360000-1.5px"])
  assert.deepEqual(
    layers.filter((l) => l.id.startsWith("plan:out:")).map((l) => [l.x, l.x2]),
    [
      ["freq:0", "freq:5330000"],
      ["freq:5340000", "freq:5350000"],
      ["freq:5360000", "freq:10800000"],
    ],
  )
})

test("a general annotation is no part of the plan: the spots draw it", () => {
  assert.deepEqual(planLayers(band20([{ type: "general", fromHz: 14200000, label: "QRM" }]), "all", layout), [])
})

test("two sources marking one place, or one key said twice, draw both, with no id twice", () => {
  // The scene refuses a duplicate id whole: one extension agreeing with the band plan would blank the picture.
  const twice = [
    ...unlicensed("20m"),
    ...band20([
      { type: "plan", fromHz: 14000000, toHz: 14070000, label: "CW" },
      { type: "known", fromHz: 14074000, toHz: 14077000, label: "FT8", key: "window:FT8:14074", importance: "secondary" },
      { type: "known", fromHz: 14074000, toHz: 14077000, label: "FT8", key: "window:FT8:14074", importance: "secondary" },
    ]),
  ]
  const layers = drawn("modes", twice)
  assert.equal(new Set(layers.map((l) => l.id)).size, layers.length)
})

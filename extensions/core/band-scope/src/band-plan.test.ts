// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
import { test } from "node:test"
import assert from "node:assert/strict"
import type { PanelSceneSpectrumLayer } from "@ham2k/extension-sdk"
import { entityPrefixForCall } from "@ham2k/extension-sdk"
import { bandPlan, licenseBreaksFor, markersFor, planLayers, type PlanDetail, type PlanSegment } from "./band-plan.ts"
import { spotMarks, type ScopeSpot } from "./spots.ts"

const us = { ituRegion: 2, countryCode: "us" }
const germany = { ituRegion: 1, countryCode: "de" }
const layout = { hzPerPx: 250, top: "spectrum", rows: 2, window: [13900, 14450] as [number, number], most: 64, height: 200 }
const drawn = (detail: PlanDetail, segments: PlanSegment[] = bandPlan("20m", us), markers = markersFor("20m", { region: 2, entity: "K" })) =>
  planLayers(segments, markers, detail, layout)
const texts = (layers: PanelSceneSpectrumLayer[]) => layers.filter((l) => l.kind === "text").map((l) => l.text?.trim())
const ids = (layers: PanelSceneSpectrumLayer[], prefix: string) => layers.filter((l) => l.id.startsWith(prefix)).map((l) => l.x)

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
  assert.ok(modes.some((l) => l.id === "plan:area:FT4:14080"))
  const all = drawn("all")
  assert.ok(modes.every((l) => all.some((m) => m.id === l.id)))
  assert.ok(texts(all).includes("🕯️ CW QRP"), "a marker's label carries its emoji")
  // A window or a marker is the stretch it covers, veiled, and its label: lines would crowd the picture.
  assert.deepEqual(
    all.filter((l) => l.kind === "line").map((l) => l.id),
    ["plan:mode:14070", "plan:mode:14095", "plan:mode:14150"],
  )
})

test("the FT8 and FT4 windows are veiled, without splitting the stretch they sit in", () => {
  const modes = drawn("modes")
  // The library breaks 20 m's data stretch at each window; read as changes of kind, Data would be
  // labelled three times over between 14070 and 14095.
  assert.deepEqual(
    modes.filter((l) => l.id.startsWith("plan:mode-label:")).map((l) => [l.x, l.text]),
    [
      ["freq:14000000+8px", "CW"],
      ["freq:14070000+8px", "Data"],
      ["freq:14095000+8px", "CW"],
      ["freq:14150000+8px", "Phone"],
    ],
  )
  const ft8 = modes.find((l) => l.id === "plan:area:FT8:14074")!
  assert.deepEqual([ft8.kind, ft8.x, ft8.x2], ["rect", "freq:14074000", "freq:14077000"])
  // Over the spectrum alone: down the waterfall it would hide the signals' history.
  assert.deepEqual([ft8.y, ft8.y2], ["spectrum", "spectrum:bottom"])
  // Its label centred over it, on a box as wide as the window where the text fits in it, and as
  // wide as the text, still centred, where it does not.
  const label = modes.find((l) => l.id === "plan:place:FT8:14074")!
  assert.deepEqual([label.x, label.align], ["freq:14075500", "center"])
  const narrow = modes.find((l) => l.id === "plan:box:FT8:14074")!
  assert.deepEqual([narrow.x, narrow.x2], ["freq:14075500-13px", "freq:14075500+13px"])
  const zoomed = planLayers(bandPlan("20m", us), [], "modes", { ...layout, hzPerPx: 20 }).find((l) => l.id === "plan:box:FT8:14074")!
  assert.deepEqual([zoomed.x, zoomed.x2], ["freq:14074000", "freq:14077000"])
  // Each change of kind gets its own line; the band's edge already marks where CW starts.
  assert.deepEqual(ids(modes, "plan:mode:"), ["freq:14070000", "freq:14095000", "freq:14150000"])
  // A mode's label sits on a tag fading into its stretch; a window's has none.
  assert.deepEqual(ids(modes, "plan:mode-tag:"), ["freq:14000000", "freq:14070000", "freq:14095000", "freq:14150000"])
  assert.ok(!modes.some((l) => l.id.startsWith("plan:mode-tag:") && /FT/.test(l.id)))
})

test("2 m's FT8 window starts where the library has it, past the half-kHz gap below it", () => {
  // Sampled a kHz apart, the gap between FT4 and FT8 falls between two samples, and FT8's window
  // would be drawn from FT4's end, a third wider than it is.
  const windows = bandPlan("2m", us).filter((s) => s.mode === "FT4" || s.mode === "FT8")
  assert.deepEqual(
    windows.map((s) => [s.mode, s.from, s.to]),
    [
      ["FT4", 144170, 144173],
      ["FT8", 144174, 144177],
    ],
  )
})

test("the plan is the station's own: its band's edges, and only the markers for its region and country", () => {
  const layers = planLayers(bandPlan("40m", germany), markersFor("40m", { region: 1, entity: "DL" }), "all", { ...layout, window: [6900, 7400] })
  // Region 1's 40 m ends at 7200; drawn with the US's edges, a German station would see 7200–7300 as its own.
  assert.deepEqual(ids(layers, "plan:edge:"), ["freq:7000000-1.5px", "freq:7200000-1.5px"])
  assert.ok(!texts(layers).some((t) => t?.includes("Here be dragons")), "Region 2's markers are not a German station's")
  assert.ok(texts(layers).includes("🚨 Emergency"), "Region 1's emergency frequency is")
})

test("a label goes at the top where it clears the others, else a row down; with no room, only its area shows", () => {
  const segments: PlanSegment[] = [{ from: 14000, to: 14350, mode: "CW" }]
  const markers = [
    { khz: 14100, emoji: "🔔", label: "One", mode: "CW" },
    { khz: 14100.5, emoji: "🔔", label: "Two", mode: "CW" },
    { khz: 14101, emoji: "🔔", label: "Three", mode: "CW" },
  ]
  const layers = planLayers(segments, markers, "all", layout)
  assert.deepEqual(
    layers.filter((l) => l.id.startsWith("plan:place:")).map((l) => [l.text, l.y]),
    [
      ["🔔 One", "spectrum+3.5px"],
      ["🔔 Two", "spectrum+20.5px"],
    ],
  )
  assert.equal(layers.filter((l) => l.id.startsWith("plan:area:")).length, 3)
  // A CW marker covers CW's passband about it; its label, wider than that, stands out past it either side.
  const one = layers.find((l) => l.id === "plan:area:0")!
  assert.deepEqual([one.x, one.x2], ["freq:14099875", "freq:14100125"])
  const box = layers.find((l) => l.id === "plan:box:0")!
  assert.ok(String(box.x).startsWith("freq:14100000-") && String(box.x2).startsWith("freq:14100000+"))
})

test("only what falls near the radio is drawn, and never more than the plan's share of the layers", () => {
  const near = planLayers(bandPlan("20m", us), markersFor("20m", { region: 2, entity: "K" }), "all", { ...layout, window: [14250, 14350] })
  assert.ok(!near.some((l) => l.text === "FT8"), "a window far off the scope spends no layers")
  assert.equal(planLayers(bandPlan("20m", us), [], "all", { ...layout, most: 3 }).length, 3)
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

test("each license level's privileges are marked where they start and stop, as the library has them", () => {
  // The levels are the station's regulator's, found from its call as the panel finds them.
  const station = { entity: entityPrefixForCall("N0CALL"), region: 2 }
  const breaks = licenseBreaksFor("20m", station)
  // The General's CW and data from 14025 to 14150, its phone from 14225; the Extra has the whole
  // band, and the Technician none of it, so neither breaks it.
  assert.deepEqual(breaks.slice(0, 3), [
    { khz: 14025, label: "General" },
    { khz: 14150, label: "General end", end: true },
    { khz: 14225, label: "General" },
  ])
  // Levels changing at one place share a label, and the legacy Advanced is not marked.
  assert.ok(licenseBreaksFor("80m", station).some((b) => b.khz === 3525 && b.label === "Technician, General"))
  assert.ok(!licenseBreaksFor("80m", station).some((b) => b.label.includes("Advanced")))
  const layers = planLayers(bandPlan("20m", us), [], "modes", layout, breaks)
  assert.deepEqual(
    layers.filter((l) => l.id.startsWith("plan:license-label:")).map((l) => l.text),
    ["General", "General"],
    "where the General's CW ends, the US phone starts, and its label says it",
  )
  assert.deepEqual(ids(planLayers(bandPlan("20m", us), [], "edges", layout, breaks), "plan:license"), [])
  // A regulator the library has no levels for, or a station not known, breaks nothing.
  assert.deepEqual(licenseBreaksFor("20m", { entity: "ZZ" }), [])
  assert.deepEqual(licenseBreaksFor("20m", {}), [])
})

test("a level's end gives way to a mode's start or the band's edge at it, or under its label", () => {
  // Once phone starts where the General's CW stops, "Phone" says it; both labels would only collide.
  const segments: PlanSegment[] = [
    { from: 14000, to: 14150, mode: "CW" },
    { from: 14150, to: 14350, mode: "SSB" },
  ]
  const breaks = [
    { khz: 14025, label: "General" },
    { khz: 14150, label: "General end", end: true },
    { khz: 14225, label: "General" },
  ]
  const layers = planLayers(segments, [], "modes", { ...layout, hzPerPx: 100 }, breaks)
  assert.deepEqual(
    layers.filter((l) => l.id.startsWith("plan:license-label:")).map((l) => l.text),
    ["General", "General"],
  )
  // A start is kept: where privileges begin is news even beside a mode's start.
  const near = planLayers(segments, [], "modes", { ...layout, hzPerPx: 100 }, [{ khz: 14152, label: "General" }])
  assert.deepEqual(
    near.filter((l) => l.id.startsWith("plan:license-label:")).map((l) => l.text),
    ["General"],
  )
})

test("mode starts closer than a label's width put the later label a row down, not on the first", () => {
  // Zoomed out on 80 m, CW, Data and Phone start about 30 kHz apart: in one row, the tags would
  // overlap and the dark labels run into each other.
  const segments: PlanSegment[] = [
    { from: 3500, to: 3510, mode: "CW" },
    { from: 3510, to: 3600, mode: "SSB" },
  ]
  const layers = planLayers(segments, [], "modes", { ...layout, hzPerPx: 800, window: [3400, 3700] })
  assert.deepEqual(
    layers.filter((l) => l.id.startsWith("plan:mode-label:")).map((l) => [l.text, l.y]),
    [
      ["CW", "spectrum+2px"],
      ["Phone", "spectrum+19px"],
    ],
  )
})

test("the plan's share of the layers is spent on whole marks, never a box without its label", () => {
  const all = planLayers(bandPlan("20m", us), markersFor("20m", { region: 2, entity: "K" }), "all", layout)
  for (let most = 1; most <= all.length; most++) {
    const kept = planLayers(bandPlan("20m", us), markersFor("20m", { region: 2, entity: "K" }), "all", { ...layout, most })
    assert.ok(kept.length <= most)
    const has = (id: string) => kept.some((l) => l.id === id)
    for (const l of kept) {
      const [, part, ...rest] = l.id.split(":")
      if (part === "box") assert.ok(has(`plan:place:${rest.join(":")}`), `${l.id} at ${most}`)
      if (part.endsWith("-tag")) assert.ok(has(`plan:${part.replace("-tag", "-label")}:${rest.join(":")}`), `${l.id} at ${most}`)
    }
  }
})

test("a hole in the library's plan inside a band is not the band's end", () => {
  // The library has no segment for 17 m's beacons at 18109–18111: read as out of band, the scope
  // would draw the band's edges and dim it there.
  const layers = planLayers(bandPlan("17m", us), [], "modes", { ...layout, window: [18000, 18200] })
  assert.deepEqual(ids(layers, "plan:edge:"), ["freq:18068000-1.5px", "freq:18168000-1.5px"])
  assert.equal(layers.filter((l) => l.id.startsWith("plan:out:")).length, 2)
})

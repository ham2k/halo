// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The band plan across the scope, as layers from the spectrum's top through the waterfall: the
// band's edges with what lies outside them dimmed; where CW, data and phone begin, each labelled
// on a tag fading into the band; the FT8 and FT4 windows between thin lines; and the places worth
// marking (calling frequencies, QRP, beacons, nets) on dashed ones. The plan is the station's own,
// by its region and country, as the library has it.
import {
  isOutsideLicensePrivileges,
  licenseJurisdictionForEntity,
  licenseLevelKey,
  modeForFrequency,
  SUPER_MODES,
  superModeForMode,
} from "@ham2k/lib-operation-data"
import type { PanelSceneSpectrumLayer } from "@ham2k/extension-sdk"
import { alpha, spotPassband } from "./spots.ts"

/** How much of the plan the scope draws: each level adds to the one before. */
export type PlanDetail = "none" | "edges" | "modes" | "all"

/** Each band's widest edges in kHz, the US's: the plan is looked for between them. */
export const bandEdges: Record<string, [number, number]> = {
  "160m": [1800, 2000],
  "80m": [3500, 4000],
  "60m": [5330, 5410],
  "40m": [7000, 7300],
  "30m": [10100, 10150],
  "20m": [14000, 14350],
  "17m": [18068, 18168],
  "15m": [21000, 21450],
  "12m": [24890, 24990],
  "10m": [28000, 29700],
  "6m": [50000, 54000],
  "4m": [70000, 70500],
  "2m": [144000, 148000],
  "1.25m": [222000, 225000],
  "70cm": [420000, 450000],
}

/**
 * A stretch of a band plan: its mode, null where the plan leaves it open, an empty string where the
 * plan says nothing within the band, false or undefined out of band.
 */
export type PlanSegment = { from: number; to: number; mode: string | null | false | undefined }
export interface Where {
  ituRegion?: number
  countryCode?: string
}
const plans = new Map<string, PlanSegment[]>()

/**
 * A band's plan for a region and country: the stretches where its mode stays the same, end to end.
 * The library answers only frequency by frequency, so the band is sampled finely enough for its
 * narrowest segments, and each change of mode found to within 10 Hz.
 */
export function bandPlan(band: string, where: Where): PlanSegment[] {
  const key = `${band} ${where.ituRegion ?? ""} ${where.countryCode ?? ""}`
  const known = plans.get(key)
  if (known) return known
  const edges = bandEdges[band]
  if (!edges) return []
  const segments: PlanSegment[] = stretchesOf(edges, (khz) => modeForFrequency(khz, where)).map(({ from, to, value }) => ({ from, to, mode: value }))
  // A stretch the library has no segment for between two it has, such as a beacon slot, is a hole
  // in its plan, not the band's end: unplanned, it takes the kind of mode around it.
  const banded = (s?: PlanSegment) => s !== undefined && s.mode !== false && s.mode !== undefined
  for (const [i, s] of segments.entries()) if (s.mode === undefined && banded(segments[i - 1]) && banded(segments[i + 1])) s.mode = ""
  plans.set(key, segments)
  return segments
}

/**
 * The stretches of `[lo, hi]` where `at` answers the same, end to end. The library answers only
 * frequency by frequency, so the band is sampled finely enough for its narrowest segments, and
 * each change found to within 10 Hz.
 */
function stretchesOf<T>([lo, hi]: [number, number], at: (khz: number) => T): { from: number; to: number; value: T }[] {
  // Half a kHz up to 4 MHz wide: 2 m's windows have half-kHz gaps between them, and a coarser step
  // would join FT8's window to the gap below it.
  const step = Math.max(0.5, (hi - lo) / 8000)
  const stretches = [{ from: lo, to: hi, value: at(lo) }]
  for (let k = 1; lo + k * step <= hi; k++) {
    const khz = Math.min(lo + k * step, hi),
      value = at(khz),
      last = stretches[stretches.length - 1]
    if (value === last.value) continue
    let [a, b] = [khz - step, khz]
    while (b - a > 0.01) {
      const m = (a + b) / 2
      if (at(m) === last.value) a = m
      else b = m
    }
    // A plan's edges fall on whole half kHz; within 15 Hz of one, it is that.
    const edge = Math.abs(b - Math.round(b * 2) / 2) <= 0.015 ? Math.round(b * 2) / 2 : Math.round(b * 100) / 100
    last.to = edge
    stretches.push({ from: edge, to: hi, value })
  }
  return stretches
}

/** A place on the band worth marking, from https://ham2k.com/data/band-plans.json. */
export type BandMarker = {
  khz: number
  emoji: string
  label: string
  /** The mode heard there, for the stretch it covers; none for a boundary. */
  mode?: string
  /** Only for stations in these ITU regions. */
  regions?: number[]
  /** Only for stations in these DXCC entities, by prefix. */
  entities?: string[]
}

export const bandMarkers: Record<string, BandMarker[]> = {
  "160m": [
    { khz: 1810, emoji: "🕯️", label: "CW QRP", mode: "CW" },
    { khz: 1836.6, emoji: "💻", label: "WSPR", mode: "WSPR" },
    { khz: 1910, emoji: "🕯️", label: "SSB QRP", mode: "SSB" },
    { khz: 2000, emoji: "🔔", label: "Beacons", mode: "CW" },
  ],
  "80m": [
    { khz: 3555, emoji: "🐢", label: "CW QRS", mode: "CW" },
    { khz: 3560, emoji: "🕯️", label: "CW QRP", mode: "CW" },
    { khz: 3568.6, emoji: "💻", label: "WSPR", mode: "WSPR" },
    { khz: 3735, emoji: "🖼️", label: "SSTV", mode: "SSB" },
    { khz: 3750, emoji: "🚨", label: "Emergency", mode: "SSB", regions: [2] },
    { khz: 3845, emoji: "🖼️", label: "SSTV", mode: "SSB" },
    { khz: 3985, emoji: "🚨", label: "Emergency", mode: "SSB", regions: [2] },
  ],
  "40m": [
    { khz: 7030, emoji: "🕯️", label: "CW QRP", mode: "CW" },
    { khz: 7110, emoji: "🚨", label: "Emergency", mode: "SSB", regions: [1] },
    { khz: 7171, emoji: "🖼️", label: "SSTV", mode: "SSB" },
    { khz: 7200, emoji: "🐉", label: "Here be dragons…", mode: "SSB", regions: [2] },
    { khz: 7240, emoji: "🚨", label: "Emergency", mode: "SSB", regions: [2] },
    { khz: 7285, emoji: "🕯️", label: "SSB QRP", mode: "SSB" },
    { khz: 7285, emoji: "🚨", label: "Emergency", mode: "SSB", regions: [2] },
    { khz: 7290, emoji: "🗣️", label: "AM", mode: "AM" },
  ],
  "30m": [{ khz: 10116, emoji: "🕯️", label: "CW QRP", mode: "CW" }],
  "20m": [
    { khz: 14055, emoji: "🐢", label: "CW QRS", mode: "CW" },
    { khz: 14060, emoji: "🕯️", label: "CW QRP", mode: "CW" },
    { khz: 14100, emoji: "🔔", label: "Beacons", mode: "CW" },
    { khz: 14230, emoji: "🖼️", label: "SSTV", mode: "SSB" },
    { khz: 14285, emoji: "🕯️", label: "SSB QRP", mode: "SSB" },
    { khz: 14300, emoji: "🚨", label: "Emergency", mode: "SSB" },
  ],
  "17m": [
    { khz: 18086, emoji: "🕯️", label: "CW QRP", mode: "CW" },
    { khz: 18110, emoji: "🔔", label: "Beacons", mode: "CW" },
    { khz: 18130, emoji: "🕯️", label: "SSB QRP", mode: "SSB" },
    { khz: 18160, emoji: "🚨", label: "Emergency", mode: "SSB" },
  ],
  "15m": [
    { khz: 21055, emoji: "🐢", label: "CW QRS", mode: "CW" },
    { khz: 21060, emoji: "🕯️", label: "CW QRP", mode: "CW" },
    { khz: 21150, emoji: "🔔", label: "Beacons", mode: "CW" },
    { khz: 21285, emoji: "🕯️", label: "SSB QRP", mode: "SSB" },
    { khz: 21340, emoji: "🖼️", label: "SSTV", mode: "SSB" },
    { khz: 21360, emoji: "🚨", label: "Emergency", mode: "SSB" },
  ],
  "12m": [
    { khz: 24906, emoji: "🕯️", label: "CW QRP", mode: "CW" },
    { khz: 24930, emoji: "🔔", label: "Beacons", mode: "CW" },
    { khz: 24950, emoji: "🕯️", label: "SSB QRP", mode: "SSB" },
  ],
  "10m": [
    { khz: 28055, emoji: "🐢", label: "CW QRS", mode: "CW" },
    { khz: 28060, emoji: "🕯️", label: "CW QRP", mode: "CW" },
    { khz: 28360, emoji: "🕯️", label: "SSB QRP", mode: "SSB" },
    { khz: 28680, emoji: "🖼️", label: "SSTV", mode: "SSB" },
    { khz: 29600, emoji: "🗣️", label: "FM Simplex Calling", mode: "FM" },
  ],
  "6m": [
    { khz: 50125, emoji: "🗣️", label: "SSB Calling", mode: "SSB" },
    { khz: 50350, emoji: "🖼️", label: "SSTV", mode: "SSB" },
    { khz: 50525, emoji: "🗣️", label: "FM Simplex Calling Primary", mode: "FM" },
    { khz: 50540, emoji: "🗣️", label: "FM Simplex Calling Secondary", mode: "FM" },
  ],
  "2m": [{ khz: 146520, emoji: "🗣️", label: "FM Simplex Calling", mode: "FM", entities: ["K"] }],
}

/** Where license levels' privileges start or stop within a band, drawn as a mode's start is. */
export type LicenseBreak = { khz: number; label: string; end?: boolean }
const breaks = new Map<string, LicenseBreak[]>()

/**
 * Where each level the station's regulator still issues may start or stop transmitting on the band,
 * in any mode, as the library has it: "General" where its privileges start, "General end" where
 * they stop, the levels changing at one place in one label. None for a regulator the library has
 * no levels for, or a station not known: the levels are only its own regulator's.
 */
export function licenseBreaksFor(band: string, station: { entity?: string; region?: number }): LicenseBreak[] {
  const jurisdiction = station.entity ? licenseJurisdictionForEntity(station.entity) : undefined
  const edges = bandEdges[band]
  if (!jurisdiction || !edges || !station.entity) return []
  const key = `${band} ${station.entity} ${station.region ?? ""}`
  const known = breaks.get(key)
  if (known) return known
  const changes = new Map<number, { starts: string[]; ends: string[] }>()
  for (const level of jurisdiction.levels.filter((l) => !l.legacy)) {
    const options = { level: licenseLevelKey(jurisdiction, level), entityPrefix: station.entity, ituRegion: station.region }
    // Just above each point: a segment's own edges are outside it, so a sample on one would find
    // every level allowed there and break the band at every edge for an instant.
    const may = (khz: number) => SUPER_MODES.some((mode) => isOutsideLicensePrivileges(khz + 0.004, { ...options, mode }) === false)
    const runs = stretchesOf(edges, may)
    for (const [i, run] of runs.entries()) {
      if (!i) continue
      const change = changes.get(run.from) ?? { starts: [], ends: [] }
      ;(run.value ? change.starts : change.ends).push(level.name)
      changes.set(run.from, change)
    }
  }
  const found = [...changes]
    .sort(([a], [b]) => a - b)
    .flatMap(([khz, { starts, ends }]) => [
      ...(starts.length ? [{ khz, label: starts.join(", ") }] : []),
      ...(ends.length ? [{ khz, label: `${ends.join(", ")} end`, end: true }] : []),
    ])
  breaks.set(key, found)
  return found
}

/** The markers for a station in `region` and the entity `entity` (its prefix); one not known sees them all. */
export function markersFor(band: string, station: { region?: number; entity?: string }): BandMarker[] {
  return (bandMarkers[band] ?? []).filter(
    (m) =>
      (!m.regions || station.region == null || m.regions.includes(station.region)) &&
      (!m.entities || station.entity == null || m.entities.includes(station.entity)),
  )
}

/**
 * The stretch a marker covers, in Hz either side of it: its mode's passband, WSPR's 200 Hz of
 * audio above the dial, and none for a boundary.
 */
function markerPassband(m: BandMarker): [number, number] | undefined {
  if (m.mode === "WSPR") return [1400, 1600]
  return spotPassband(m.mode, m.khz)
}

/** The modes the plan gives a narrow window of their own, inside a stretch of another. */
const windowModes = ["FT8", "FT4"]

type Kind = "CW" | "DATA" | "PHONE" | "ANY"
const kindLabels: Record<Kind, string> = { CW: "CW", DATA: "Data", PHONE: "Phone", ANY: "All modes" }
/** One grey for the license levels' labels and lines. */
const planInk = "#B8C4D0"
/** The band's edges and its modes' boundaries, the lines that matter most: the barrier's yellow. */
const boundaryInk = "#FFD400"
/** A mode's label: dark, on a light gold tag. */
const modeTag = "#F2DC8C",
  modeInk = "#2B2410"
/** A window's or a marker's: a light veil over the stretch of the spectrum it covers, its label on a dark grey box. */
const placeInk = "#FFFFFF"
const labelBox = "#3A4250",
  labelInk = "#E8EEF4"
/** Out of band: a light see-through tint, so what is heard there still shows. */
const outside = "#D0D6DE"

const inBand = (s: PlanSegment) => s.mode !== false && s.mode !== undefined
const kindOf = (mode: string | null): Kind => (mode == null ? "ANY" : (superModeForMode(mode) as Kind))

/**
 * The first of [layers] that make up whole items, up to [most]: a box without its text, or a tag
 * without its label, would be a mark that says nothing. An item is the layers whose ids differ
 * only in the part (`plan:mode-tag:7000`, `plan:mode-label:7000`).
 */
function wholeItems(layers: PanelSceneSpectrumLayer[], most: number): PanelSceneSpectrumLayer[] {
  const items = new Map<string, PanelSceneSpectrumLayer[]>()
  for (const layer of layers) {
    const [, part, ...rest] = layer.id.split(":")
    const item = `${part.replace(/-(tag|label)$/, "").replace(/^(area|box)$/, "place")}:${rest.join(":")}`
    items.set(item, [...(items.get(item) ?? []), layer])
  }
  const kept: PanelSceneSpectrumLayer[] = []
  for (const item of items.values()) {
    if (kept.length + item.length > most) break
    kept.push(...item)
  }
  return kept
}

export interface PlanLayout {
  /** Hz across one pixel of the pane, at the zoom it last reported. */
  hzPerPx: number
  /** Where the labels hang from: the spectrum's top, or the waterfall's under the axis. */
  top: string
  /** Rows of labels from the top, the modes' first, shared by the windows and the markers. */
  rows: number
  /** Only what falls within this stretch, in kHz, is drawn: the rest would only spend layers. */
  window: [number, number]
  /** At most this many layers. */
  most: number
  /** The pane's height in pixels: the edges' stripes are drawn to it, so they keep their slant. */
  height: number
}

/** A label's row height, and its size. */
export const planRow = 17
const labelSize = 10
/** A window's or a marker's label, smaller than a mode's. */
const placeSize = 8.5
/** How far a mode's label stands in from its line, and the padding in a window's or a marker's box. */
const labelInset = 8,
  boxPad = 1.5,
  /** Room at the ends of a window's or a marker's box. */
  sidePad = 5
/** The box's height: the text, its padding above, and a little more below. */
const boxHeight = Math.ceil(placeSize * 1.2 + 2 * boxPad + 2)
/** How far the tag behind a mode's label fades over the band. */
const tagLength = 56

/**
 * A band's edge, as a construction barrier: yellow and black stripes slanting across a strip
 * [barrier] pixels wide and [height] tall.
 */
const barrier = 3
const stripes = (height: number) => {
  const tall = Math.max(1, Math.ceil(height))
  const slants = Array.from(
    { length: Math.ceil(tall / 8) + 1 },
    (_, i) => `<polygon points="0,${i * 8} ${barrier},${i * 8 - barrier} ${barrier},${i * 8 + 4 - barrier} 0,${i * 8 + 4}"/>`,
  )
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${barrier} ${tall}" preserveAspectRatio="none"><rect width="${barrier}" height="${tall}" fill="${boundaryInk}"/><g fill="#111111">${slants.join("")}</g></svg>`
}

const tag = (ink: string, opacity: number, solid = 0) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10" preserveAspectRatio="none"><defs><linearGradient id="t" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="${ink}" stop-opacity="${opacity}"/><stop offset="${solid}" stop-color="${ink}" stop-opacity="${opacity}"/><stop offset="1" stop-color="${ink}" stop-opacity="0"/></linearGradient></defs><rect width="10" height="10" fill="url(#t)"/></svg>`

/**
 * The layers for a band's plan at a level of detail, the most telling first: the edges, the
 * modes' stretches and the license classes' breaks, the windows, then the markers, as many as
 * [layout.most] takes.
 */
export function planLayers(
  segments: PlanSegment[],
  markers: BandMarker[],
  detail: PlanDetail,
  layout: PlanLayout,
  breaks: LicenseBreak[] = [],
): PanelSceneSpectrumLayer[] {
  if (detail === "none" || !segments.length) return []
  const [lo, hi] = layout.window
  const seen = (from: number, to = from) => to >= lo && from <= hi
  const hz = (khz: number) => Math.round(khz * 1000)
  const row = (n: number, dy = 0) => `${layout.top}+${2 + n * planRow + dy}px`
  const layers: PanelSceneSpectrumLayer[] = []

  // The band's edges: a heavy line where it starts and ends, and a veil over what lies outside.
  const runs: [number, number][] = []
  for (const s of segments.filter(inBand)) {
    const last = runs[runs.length - 1]
    if (last && last[1] >= s.from) last[1] = s.to
    else runs.push([s.from, s.to])
  }
  const gaps: [number, number][] = runs.map(([from], i) => [i ? runs[i - 1][1] : -Infinity, from])
  if (runs.length) gaps.push([runs[runs.length - 1][1], Infinity])
  for (const [from, to] of gaps) {
    if (!seen(from, to)) continue
    layers.push({
      id: `plan:out:${from}`,
      kind: "rect",
      x: `freq:${Number.isFinite(from) ? hz(from) : 0}`,
      x2: `freq:${Number.isFinite(to) ? hz(to) : hz(hi * 2)}`,
      fill: alpha(outside, 0.14),
    })
  }
  const edges = [...new Set(runs.flat())]
  for (const khz of edges.filter((k) => seen(k))) {
    layers.push({
      id: `plan:edge:${khz}`,
      kind: "svg",
      x: `freq:${hz(khz)}-${barrier / 2}px`,
      x2: `freq:${hz(khz)}+${barrier / 2}px`,
      svg: stripes(layout.height),
    })
  }
  if (detail === "edges") return wholeItems(layers, layout.most)

  // The modes' stretches. A window of its own, or a hole in the plan, takes the kind before it (at a
  // run's start, the one after), so it splits no stretch.
  const banded = segments.filter(inBand)
  const isWindow = (s: PlanSegment) => typeof s.mode === "string" && windowModes.includes(s.mode)
  const windows = banded.filter(isWindow)
  const kinds = banded.map((s) => (isWindow(s) || s.mode === "" ? undefined : kindOf(s.mode as string | null)))
  for (const [i, s] of banded.entries()) {
    if (kinds[i]) continue
    kinds[i] = (i && banded[i - 1].to === s.from ? kinds[i - 1] : undefined) ?? kinds.slice(i + 1).find((k) => k) ?? "DATA"
  }
  const stretches: { from: number; to: number; kind: Kind }[] = []
  for (const [i, s] of banded.entries()) {
    const last = stretches[stretches.length - 1]
    if (last && last.to === s.from && last.kind === kinds[i]) last.to = s.to
    else stretches.push({ from: s.from, to: s.to, kind: kinds[i]! })
  }
  // The rows of labels from the top, each span in Hz: the modes' take the first, and the windows'
  // and the markers' go where each clears the rest, in the first row that has room.
  const taken: [number, number][][] = Array.from({ length: Math.max(1, layout.rows) }, () => [])
  const px = (n: number) => n * layout.hzPerPx
  // Where a mode or a license class starts: a line (the band's edge already marks its start), and
  // a label on a tag fading into the band, along the top.
  const start = (id: string, khz: number, text: string, kind: "mode" | "license", end = false) => {
    const long = Math.max(tagLength, labelInset + [...text].length * labelSize * 0.62 + 8)
    const span: [number, number] = [hz(khz), hz(khz) + px(long)]
    // Where a level's privileges stop at, or under the label of, a mode's start or the band's edge,
    // that wider boundary says enough.
    if (end && boundaries.some((b) => hz(b) >= span[0] - px(labelInset) && hz(b) <= span[1])) return
    const ink = kind === "mode" ? boundaryInk : alpha(planInk, 0.6)
    if (!edges.includes(khz)) layers.push({ id: `plan:${kind}:${id}`, kind: "line", x: `freq:${hz(khz)}`, width: 2, color: ink })
    // The first row where the label clears the rest: the modes', drawn first, take the top one
    // unless two starts lie closer than a label's width.
    const lane = taken.findIndex((spans) => spans.every(([a, b]) => span[1] <= a || span[0] >= b))
    if (lane < 0) return
    taken[lane].push(span)
    layers.push({
      id: `plan:${kind}-tag:${id}`,
      kind: "svg",
      x: `freq:${hz(khz)}`,
      x2: `freq:${hz(khz)}+${Math.round(long)}px`,
      y: row(lane, -2),
      y2: row(lane + 1, -1),
      // A mode's tag holds solid under its text, so the dark ink stays readable, then fades.
      svg: kind === "mode" ? tag(modeTag, 0.95, (labelInset + [...text].length * labelSize * 0.62) / long) : tag(planInk, 0.45),
    })
    layers.push({
      id: `plan:${kind}-label:${id}`,
      kind: "text",
      x: `freq:${hz(khz)}+${labelInset}px`,
      y: row(lane),
      text,
      size: labelSize,
      weight: 700,
      color: kind === "mode" ? modeInk : planInk,
    })
  }
  const boundaries = [...edges, ...stretches.map((s) => s.from)]
  for (const s of stretches) if (seen(s.from, s.to)) start(`${s.from}`, s.from, kindLabels[s.kind], "mode")
  // Only within the band: where a level's privileges meet the band's own edge, the edge says it.
  const within = (khz: number) => runs.some(([from, to]) => from < khz && khz < to)
  for (const [i, b] of breaks.entries()) if (seen(b.khz) && within(b.khz)) start(`${b.khz}:${i}`, b.khz, b.label, "license", b.end)

  // The windows and the markers: a veil over what each covers, from the top of the picture to its
  // bottom, and its label on a colored box at the top, lower down only where the row is taken.
  const place = (id: string, from: number, to: number, text: string) => {
    layers.push({
      id: `plan:area:${id}`,
      kind: "rect",
      x: from === to ? `freq:${from}-1px` : `freq:${from}`,
      x2: from === to ? `freq:${to}+1px` : `freq:${to}`,
      y: "spectrum",
      y2: "spectrum:bottom",
      fill: alpha(placeInk, 0.1),
    })
    // Centred on what it covers, on a box as wide as that or, where the text does not fit, as the
    // text: in Hz at the zoom the pane last reported, which a zoom's commit lays out again.
    const textPx = sidePad * 2 + [...text].length * placeSize * 0.62 + (/\p{Extended_Pictographic}/u.test(text) ? placeSize * 0.6 : 0)
    const middle = Math.round((from + to) / 2),
      half = Math.ceil(textPx / 2),
      fits = to - from >= px(2 * half)
    const span: [number, number] = fits ? [from - px(1), to + px(1)] : [middle - px(half + 1), middle + px(half + 1)]
    const lane = taken.findIndex((spans) => spans.every(([a, b]) => span[1] <= a || span[0] >= b))
    if (lane < 0) return
    taken[lane].push(span)
    layers.push({
      id: `plan:box:${id}`,
      kind: "rect",
      x: fits ? `freq:${from}` : `freq:${middle}-${half}px`,
      x2: fits ? `freq:${to}` : `freq:${middle}+${half}px`,
      y: row(lane),
      y2: row(lane, boxHeight),
      fill: labelBox,
    })
    layers.push({
      id: `plan:place:${id}`,
      kind: "text",
      x: `freq:${middle}`,
      y: row(lane, boxPad),
      align: "center",
      text,
      size: placeSize,
      weight: 500,
      color: labelInk,
    })
  }
  for (const w of windows) {
    if (seen(w.from, w.to)) place(`${w.mode}:${w.from}`, hz(w.from), hz(w.to), w.mode as string)
  }
  if (detail === "all") {
    for (const [i, m] of markers.entries()) {
      if (!seen(m.khz)) continue
      const [a, b] = markerPassband(m) ?? [0, 0]
      place(`${i}`, hz(m.khz) + a, hz(m.khz) + b, `${m.emoji} ${m.label}`)
    }
  }
  return wholeItems(layers, layout.most)
}

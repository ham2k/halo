// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The band's annotations across the scope, as layers from the spectrum's top through the waterfall:
// the band's edges with what lies outside them dimmed; where CW, data and phone begin, each
// labelled on a tag fading into the band, and where each license level's privileges start and stop;
// and the windows and frequencies known for something, veiled with a boxed label. What the band
// plan says comes from whoever says it (`ctx.getBandAnnotations`), the band-plan extension first.
import type { HeldBandAnnotation, PanelSceneSpectrumLayer } from "@ham2k/extension-sdk"
import { alpha } from "./spots.ts"

/** How much of the plan the scope draws: each level adds to the one before. */
export type PlanDetail = "none" | "edges" | "modes" | "all"

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

/**
 * The first of [layers] that make up whole items, up to [most]: a box without its text, or a tag
 * without its label, would be a mark that says nothing. An item is the layers whose ids differ
 * only in the part (`plan:mode-tag:7000000`, `plan:mode-label:7000000`).
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
  /** Only what falls within this stretch, in Hz, is drawn: the rest would only spend layers. */
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

const importanceRank = { primary: 0, secondary: 1, tertiary: 2 }
const toOf = (a: HeldBandAnnotation) => a.toHz ?? a.fromHz

/**
 * The layers for a band's annotations at a level of detail, the most telling first, as many as
 * [layout.most] takes: the `edge`s, the band's allocated stretches; then the primary `plan`s, the
 * modes' stretches, each marked where it starts; the other `plan`s, the license levels', marked
 * where each starts and stops, several at one place in one label; and the `known`s, windows and
 * frequencies, the tertiary ones only at `all`. The `general` ones are the spots' to draw.
 */
export function planLayers(annotations: HeldBandAnnotation[], detail: PlanDetail, layout: PlanLayout): PanelSceneSpectrumLayer[] {
  if (detail === "none") return []
  const [lo, hi] = layout.window
  const seen = (from: number, to = from) => to >= lo && from <= hi
  const row = (n: number, dy = 0) => `${layout.top}+${2 + n * planRow + dy}px`
  const layers: PanelSceneSpectrumLayer[] = []

  // The band's edges: a heavy line where it starts and ends, and a veil over what lies outside.
  const runs: [number, number][] = []
  for (const a of annotations.filter((a) => a.type === "edge").sort((a, b) => a.fromHz - b.fromHz)) {
    const last = runs[runs.length - 1]
    if (last && last[1] >= a.fromHz) last[1] = Math.max(last[1], toOf(a))
    else runs.push([a.fromHz, toOf(a)])
  }
  const gaps: [number, number][] = runs.map(([from], i) => [i ? runs[i - 1][1] : -Infinity, from])
  if (runs.length) gaps.push([runs[runs.length - 1][1], Infinity])
  for (const [from, to] of gaps) {
    if (!seen(from, to)) continue
    layers.push({
      id: `plan:out:${from}`,
      kind: "rect",
      x: `freq:${Number.isFinite(from) ? from : 0}`,
      x2: `freq:${Number.isFinite(to) ? to : hi * 2}`,
      fill: alpha(outside, 0.14),
    })
  }
  const edges = [...new Set(runs.flat())]
  for (const at of edges.filter((at) => seen(at))) {
    layers.push({
      id: `plan:edge:${at}`,
      kind: "svg",
      x: `freq:${at}-${barrier / 2}px`,
      x2: `freq:${at}+${barrier / 2}px`,
      svg: stripes(layout.height),
    })
  }
  if (detail === "edges") return wholeItems(layers, layout.most)

  const shown = annotations.filter((a) => detail === "all" || a.importance !== "tertiary")
  const modes = shown.filter((a) => a.type === "plan" && a.importance === "primary").sort((a, b) => a.fromHz - b.fromHz)
  // The rows of labels from the top, each span in Hz: the modes' take the first, and the windows'
  // and the markers' go where each clears the rest, in the first row that has room.
  const taken: [number, number][][] = Array.from({ length: Math.max(1, layout.rows) }, () => [])
  const px = (n: number) => n * layout.hzPerPx
  // Where a mode or a license class starts: a line (the band's edge already marks its start), and
  // a label on a tag fading into the band, along the top.
  const start = (id: string, at: number, text: string, kind: "mode" | "license", end = false) => {
    const long = Math.max(tagLength, labelInset + [...text].length * labelSize * 0.62 + 8)
    const span: [number, number] = [at, at + px(long)]
    // Where a level's privileges stop at, or under the label of, a mode's start or the band's edge,
    // that wider boundary says enough.
    if (end && boundaries.some((b) => b >= span[0] - px(labelInset) && b <= span[1])) return
    const ink = kind === "mode" ? boundaryInk : alpha(planInk, 0.6)
    if (!edges.includes(at)) layers.push({ id: `plan:${kind}:${id}`, kind: "line", x: `freq:${at}`, width: 2, color: ink })
    // The first row where the label clears the rest: the modes', drawn first, take the top one
    // unless two starts lie closer than a label's width.
    const lane = taken.findIndex((spans) => spans.every(([a, b]) => span[1] <= a || span[0] >= b))
    if (lane < 0) return
    taken[lane].push(span)
    layers.push({
      id: `plan:${kind}-tag:${id}`,
      kind: "svg",
      x: `freq:${at}`,
      x2: `freq:${at}+${Math.round(long)}px`,
      y: row(lane, -2),
      y2: row(lane + 1, -1),
      // A mode's tag holds solid under its text, so the dark ink stays readable, then fades.
      svg: kind === "mode" ? tag(modeTag, 0.95, (labelInset + [...text].length * labelSize * 0.62) / long) : tag(planInk, 0.45),
    })
    layers.push({
      id: `plan:${kind}-label:${id}`,
      kind: "text",
      x: `freq:${at}+${labelInset}px`,
      y: row(lane),
      text,
      size: labelSize,
      weight: 700,
      color: kind === "mode" ? modeInk : planInk,
    })
  }
  const boundaries = [...edges, ...modes.map((a) => a.fromHz)]
  for (const a of modes) if (seen(a.fromHz, toOf(a))) start(`${a.fromHz}`, a.fromHz, a.label ?? "", "mode")

  // Where each license level's privileges start and stop, only within the band: where they meet
  // the band's own edge, the edge says it. The levels changing at one place share one label.
  const within = (at: number) => runs.some(([from, to]) => from < at && at < to)
  const changes = new Map<number, { starts: string[]; ends: string[] }>()
  const change = (at: number) => changes.get(at) ?? changes.set(at, { starts: [], ends: [] }).get(at)!
  for (const a of shown.filter((a) => a.type === "plan" && a.importance !== "primary")) {
    if (within(a.fromHz)) change(a.fromHz).starts.push(a.label ?? "")
    if (a.toHz != null && within(a.toHz)) change(a.toHz).ends.push(a.label ?? "")
  }
  const breaks = [...changes]
    .sort(([a], [b]) => a - b)
    .flatMap(([at, { starts, ends }]) => [
      ...(starts.length ? [{ at, label: starts.join(", "), end: false }] : []),
      ...(ends.length ? [{ at, label: `${ends.join(", ")} end`, end: true }] : []),
    ])
  for (const [i, b] of breaks.entries()) if (seen(b.at)) start(`${b.at}:${i}`, b.at, b.label, "license", b.end)

  // The windows and the markers: a veil over what each covers, from the top of the picture to its
  // bottom, and its label on a colored box at the top, lower down only where the row is taken.
  const place = (id: string, from: number, to: number, text: string, box: string) => {
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
      fill: box,
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
  const known = shown.filter((a) => a.type === "known").sort((a, b) => importanceRank[a.importance] - importanceRank[b.importance])
  for (const [i, a] of known.entries()) {
    if (seen(a.fromHz, toOf(a))) place(`${a.source}:${a.key ?? i}`, a.fromHz, toOf(a), a.label ?? "", a.color ?? labelBox)
  }
  return wholeItems(distinct(layers), layout.most)
}

/**
 * [layers] with no id twice: a scene with a duplicate is refused whole, and two sources saying a
 * mode starts at one frequency, or one key said twice, would blank the picture. A repeat takes a
 * `#n` on its last part, so its line, tag and label stay one item.
 */
function distinct(layers: PanelSceneSpectrumLayer[]): PanelSceneSpectrumLayer[] {
  const seen = new Map<string, number>()
  return layers.map((layer) => {
    const n = seen.get(layer.id) ?? 0
    seen.set(layer.id, n + 1)
    return n ? { ...layer, id: `${layer.id}#${n}` } : layer
  })
}

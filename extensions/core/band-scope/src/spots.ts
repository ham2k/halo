// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The spots on the scope's band, as annotations at their frequencies over the spectrum, standing
// above the noise where a signal's peak would be, each with a leader up from the spectrum's foot. The app zooms and pans the picture itself, so the annotations are laid out in lanes by
// frequency at the zoom the pane last reported: a pan leaves them right, and a zoom's `commit`
// brings a render that lays them out again.
import type { BoardSpot, HeldBandAnnotation, PanelSceneSpectrumAnnotation, PanelSceneSpectrumLayer, SuggestedQso } from "@ham2k/extension-sdk"

/** One station on the scope: its newest report, with the references of them all. */
export interface ScopeSpot {
  call: string
  /** What tells it from the rest, where [call] alone does not: see [scopeSpots]. */
  key?: string
  khz: number
  band?: string
  mode?: string
  refs: NonNullable<BoardSpot["refs"]>
  ageMinutes: number
  worked: boolean
  isSelf: boolean
  /** Something new to work it for: a band, a mode, a day, a reference or a multiplier, as the Spots panel accents. */
  fresh: boolean
  /** A new multiplier, which the Spots panel draws in its own color over the rest. */
  multiplier?: boolean
  icon?: string
  iconColor?: string
  emoji?: string
  /** A `general` band annotation rather than a station: its label for a call, nothing to log. */
  note?: boolean
  /** Its ink, where it suggests one. */
  color?: string
  /** The stretch it covers in Hz either side of it, where its mode does not say. */
  heard?: [number, number]
}

/**
 * One spot a station from the board's reports, newest first: where and when from the newest,
 * references from them all — a cluster spot after a POTA one still knows the park.
 */
export function scopeSpots(board: BoardSpot[], nowMillis: number): ScopeSpot[] {
  const reports = new Map<string, BoardSpot[]>()
  for (const s of board) {
    if (s.freq == null) continue
    const call = s.their.call.toUpperCase()
    // A call not fully copied ("W1A?") names no one station: two of them are two places on the
    // band, each its own mark.
    const key = call.includes("?") ? `${call}@${s.freq}` : call
    reports.set(key, [...(reports.get(key) ?? []), s])
  }
  return [...reports].map(([key, all]) => {
    const [s] = all
    const call = s.their.call.toUpperCase()
    const refs = new Map<string, NonNullable<BoardSpot["refs"]>[number]>()
    for (const r of all.flatMap((o) => o.refs ?? [])) if (!refs.has(`${r.type}:${r.ref}`)) refs.set(`${r.type}:${r.ref}`, r)
    // Drawn as the newest report that names a reference: a park's tree, not the cluster's tower,
    // which is only the board's stand-in for a source with no icon of its own.
    const shown = all.find((o) => o.refs?.length) ?? s
    const icon = shown.spot.source === "cluster" && !shown.refs?.length ? undefined : (shown.display?.icon ?? shown.icon)
    return {
      call,
      ...(key !== call ? { key } : {}),
      khz: s.freq!,
      band: s.band,
      mode: s.mode ?? undefined,
      refs: [...refs.values()],
      ageMinutes: Math.max(0, Math.round((nowMillis - s.spot.timeInMillis) / 60000)),
      worked: s.annotations?.worked ?? false,
      isSelf: s.annotations?.isSelf ?? false,
      fresh: (s.annotations?.notices ?? []).some((n) => accented.includes(n) || chaseAlert(n)),
      ...(s.annotations?.notices.includes("newMult") ? { multiplier: true } : {}),
      ...(icon ? { icon, iconColor: shown.display?.iconColor } : {}),
      ...(shown.display?.emoji ? { emoji: shown.display.emoji } : {}),
    }
  })
}

/**
 * The band's `general` annotations, as marks among the spots: each labelled, where it is or in the
 * middle of the stretch it covers, in the ink it suggests, never fading.
 */
export function noteSpots(annotations: HeldBandAnnotation[]): ScopeSpot[] {
  // A key said twice — a hook's answer and a put under one key — would be a duplicate mark, which
  // the scene refuses whole.
  const seen = new Map<string, number>()
  return annotations
    .filter((a) => a.type === "general")
    .map((a, i) => {
      const at = Math.round(a.toHz != null ? (a.fromHz + a.toHz) / 2 : a.fromHz)
      const base = `note:${a.source}:${a.key ?? `${a.fromHz}:${i}`}`
      const n = seen.get(base) ?? 0
      seen.set(base, n + 1)
      return {
        call: a.label ?? "",
        key: n ? `${base}#${n}` : base,
        khz: at / 1000,
        refs: [],
        ageMinutes: 0,
        worked: false,
        isSelf: false,
        fresh: false,
        note: true,
        ...(a.icon ? { icon: a.icon, iconColor: a.color } : {}),
        ...(a.color ? { color: a.color } : {}),
        ...(a.toHz != null && a.toHz > a.fromHz ? { heard: [a.fromHz - at, a.toHz - at] as [number, number] } : {}),
      }
    })
}

/** Who keeps a place when the lanes are full: something new first, then the unworked, then the newest. */
const rank = (s: ScopeSpot) => (s.fresh ? 0 : s.worked ? 2 : 1) * 1e6 + s.ageMinutes

/**
 * The scorers' notices the Spots panel accents, and the scope after it. A new DXCC, state or
 * province it leaves out: those are about the call being typed, and on a whole band they would
 * light up most spots.
 */
const accented = ["newBand", "newMode", "newDay", "newRef", "newMult"]

/**
 * A chasing program's verdict the operator asked to be alerted to — `chase:<program>:<verdict>`
 * then flags, `alert` among them — which the Spots panel accents on the call too.
 */
const chaseAlert = (notice: string) => notice.startsWith("chase:") && notice.split(":").slice(3).includes("alert")

/**
 * Over the scope's fixed dark picture: something new in the Spots panel's green and a multiplier in
 * its orange-brown, their dark-theme shades (`HaLoColors.important` and `spotMultiplier`), our own a
 * paler green, the worked grey.
 */
const inks = { fresh: "#1AC81A", multiplier: "#FF8A4C", self: "#8EE3A1", worked: "#7F8EA0", plain: "#E8EEF4" }
/** The scope's own background; a spot's box is it, see-through, so it dims the picture rather than standing out from it. */
export const scopeBackground = "#0B0E17"
const leader = "#8FA3B8"
const ink = (s: ScopeSpot) => s.color ?? (s.multiplier ? inks.multiplier : s.fresh ? inks.fresh : s.isSelf ? inks.self : s.worked ? inks.worked : inks.plain)
/** The oldest asked for is drawn at this strength; a fresh one at full. */
const faintest = 0.4

/** `#RRGGBB` at an opacity, as the scene's `#AARRGGBB`. */
export const alpha = (color: string, opacity: number) =>
  `#${Math.round(Math.min(1, Math.max(0, opacity)) * 255)
    .toString(16)
    .padStart(2, "0")
    .toUpperCase()}${color.slice(1)}`

export interface SpotLayout {
  /** Hz across one pixel of the pane, at the zoom it last reported. */
  hzPerPx: number
  /** Lanes the part has room for, nearest the part's edge first. */
  lanes: number
  /** Up from the spectrum's foot; down from the waterfall's head where the pane shows no spectrum. */
  part: "waterfall" | "spectrum"
  /** Pixels at that edge the frequency axis lies over, which the lanes start past. */
  clear: number
  /**
   * Where the lanes start in place of the part's edge, as a spectrum layer's `y` is written
   * (`noise+30db`); the leaders still rise from the edge.
   */
  from?: string
  maxAgeMinutes: number
  /** The layers left for the spots, of the 512 a band scope takes. */
  layers?: number
  fontFamily?: string
  /** What a click sends, with the annotation's id naming the station. */
  event: string
}

const size = 12,
  padding = 3,
  gap = 6
/** How far apart the lanes are: a box and a little air. */
export const laneHeight = size * 1.2 + padding * 2 + 3
/** RobotoMono advances 0.6 em a glyph; a hair over keeps a guess from letting two boxes touch. */
const advance = size * 0.62

/** A box's width in pixels: the call, the icon before it and the emoji after. */
function widthOf(s: ScopeSpot) {
  return padding * 2 + s.call.length * advance + (s.icon ? size * 1.25 : 0) + (s.emoji ? size * 1.6 : 0)
}

/** The annotation's id for a station; a click names it, and `spotFor` finds the station again. */
export const spotId = (s: ScopeSpot) => `spot:${s.key ?? s.call}`

/** A band scope takes 256 annotations, a spot's label hidden or not: past them, spots are left out. */
const mostAnnotations = 256

/** How far a hidden label's line sits nearer the part's edge than the first lane's border. */
const hiddenInset = 3

/** `±<n>px`, as a coordinate's offset is written. */
const px = (n: number) => `${n < 0 ? "-" : "+"}${Math.abs(n)}px`

/**
 * Each spot in the first lane where its box clears every box already there, in rank order — the
 * best placed nearest the part's edge — each with a leader from that edge to its box, a dot where
 * it meets the edge, and a bar along the edge over the passband its mode takes. One with no room
 * for its box keeps its leader, dot and bar, and its label is collapsed to a short line a few
 * pixels nearer the edge than the first lane's border, where its leader ends: dropped whole, a
 * crowded stretch of band would look empty. The app draws the label whole while the pointer is on
 * the line, over those it covers, and a zoom brings it out for good. Past the annotations and
 * layers a band scope takes, the rest are left out.
 */
export function spotMarks(spots: ScopeSpot[], layout: SpotLayout): { annotations: PanelSceneSpectrumAnnotation[]; layers: PanelSceneSpectrumLayer[] } {
  const taken: [number, number][][] = Array.from({ length: Math.max(0, layout.lanes) }, () => [])
  const annotations: PanelSceneSpectrumAnnotation[] = [],
    layers: PanelSceneSpectrumLayer[] = []
  const down = layout.part === "waterfall"
  // On the part's edge, past the axis lying over it, moved [dy] down the screen.
  const edge = (dy = 0) => (down ? `waterfall${px(layout.clear + dy)}` : `spectrum:bottom${px(dy - layout.clear)}`)
  const budget = layout.layers ?? 512
  for (const s of [...spots].sort((a, b) => rank(a) - rank(b))) {
    const hz = Math.round(s.khz * 1000),
      half = ((widthOf(s) + gap) / 2) * layout.hzPerPx
    const heard = s.heard ?? spotPassband(s.mode, s.khz)
    const lane = taken.findIndex((spans) => spans.every(([from, to]) => hz + half <= from || hz - half >= to))
    if (annotations.length >= mostAnnotations) break
    // One that needs its bar may not fit where one without does: the rest are still tried.
    if (layers.length + (heard ? 3 : 2) > budget) continue
    const opacity = 1 - (1 - faintest) * Math.min(1, s.ageMinutes / Math.max(1, layout.maxAgeMinutes))
    const base = layout.from ? 0 : layout.clear
    const offset = lane < 0 ? base + 4 - hiddenInset : base + 4 + lane * laneHeight
    if (lane >= 0) taken[lane].push([hz - half, hz + half])
    annotations.push({
      id: spotId(s),
      text: s.emoji ? `${s.call} ${s.emoji}` : s.call,
      hz,
      part: layout.part,
      ...(layout.from ? { y: layout.from } : {}),
      offset,
      pointer: false,
      size,
      weight: 700,
      padding,
      radius: 3,
      ...(layout.fontFamily ? { fontFamily: layout.fontFamily } : {}),
      color: alpha(ink(s), opacity),
      background: alpha(scopeBackground, 0.7),
      borderColor: alpha(ink(s), opacity * 0.6),
      borderWidth: 1,
      borderEdges: "near",
      ...(s.icon ? { icon: { name: s.icon, color: alpha(s.iconColor ?? ink(s), opacity) } } : {}),
      ...(lane < 0 ? { collapsed: true } : {}),
      event: layout.event,
    })
    // Where the signal would be heard, a bar along the edge, under the leader and its dot.
    if (heard) {
      layers.push({
        id: `passband:${s.key ?? s.call}`,
        kind: "rect",
        x: `freq:${hz + heard[0]}`,
        x2: `freq:${hz + heard[1]}`,
        y: edge(-2),
        y2: edge(2),
        fill: alpha(ink(s), opacity * 0.35),
      })
    }
    // From the part's edge to the box's edge nearer it.
    layers.push({
      id: `leader:${s.key ?? s.call}`,
      kind: "line",
      x: `freq:${hz}`,
      y: edge(),
      y2: down ? `waterfall+${offset}px` : `${layout.from ?? "spectrum:bottom"}-${offset}px`,
      width: 3,
      color: alpha(leader, opacity * 0.7),
    })
    layers.push({
      id: `dot:${s.key ?? s.call}`,
      kind: "rect",
      x: `freq:${hz}-3px`,
      x2: `freq:${hz}+3px`,
      y: edge(-3),
      y2: edge(3),
      radius: 3,
      fill: alpha(ink(s), opacity),
    })
  }
  return { annotations, layers }
}

/** What a click on a spot puts in the logging fields: the station, where it was heard, and its references. */
export const suggestionFor = (s: ScopeSpot): SuggestedQso => ({
  their: { call: s.call },
  freq: s.khz,
  ...(s.band ? { band: s.band } : {}),
  ...(s.mode ? { mode: s.mode } : {}),
  ...(s.refs.length ? { refs: s.refs } : {}),
})

const digital = ["FT8", "FT4", "JS8", "PSK", "PSK31", "DATA", "DIGI", "OLIVIA", "MFSK", "JT65", "JT9", "Q65", "FST4"]

/** SSB's usual sideband: lower below 10 MHz, upper above and on 60 m. */
const sidebandAt = (khz: number) => (khz < 10000 && !(khz >= 5330 && khz <= 5410) ? "LSB" : "USB")

/** FT8 and FT4: every station on the band's one dial frequency, each somewhere in its 3 kHz. */
const sharedWindow = ["FT8", "FT4"]

/**
 * The stretch a spot's signal takes, in Hz either side of its frequency: phone 2.8 kHz on its
 * sideband, AM 2.8 kHz and FM 7 kHz either side, data 3 kHz above the dial, CW 250 Hz around it.
 * None for a spot that names no mode, nor for FT8 and FT4, whose spots all share the band's window:
 * a bar for each would paint the same 3 kHz over and over, marking no one station.
 */
export function spotPassband(mode: string | undefined, khz: number): [number, number] | undefined {
  if (mode && sharedWindow.includes(mode)) return undefined
  const sideband = mode === "SSB" ? sidebandAt(khz) : mode
  if (sideband === "USB") return [0, 2800]
  if (sideband === "LSB") return [-2800, 0]
  if (mode === "AM") return [-2800, 2800]
  if (mode === "FM") return [-7000, 7000]
  if (mode === "RTTY" || (mode && digital.includes(mode))) return [0, 3000]
  if (mode === "CW") return [-125, 125]
  return undefined
}

/**
 * The radio mode a spot's mode asks for, among those the radio offers: SSB on its usual sideband
 * (lower below 10 MHz, upper on 60 m), digital modes on the radio's data mode, else upper sideband.
 */
export function radioModeFor(mode: string | undefined, khz: number, offered: string[]): string | undefined {
  if (!mode) return undefined
  const wanted =
    mode === "SSB"
      ? [sidebandAt(khz)]
      : ["USB", "LSB", "CW", "AM", "FM"].includes(mode)
        ? [mode]
        : mode === "RTTY"
          ? ["RTTY", "DATA-USB", "USB"]
          : digital.includes(mode)
            ? ["DATA-USB", "USB"]
            : []
  return wanted.find((m) => offered.includes(m))
}

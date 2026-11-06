// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The spots on the scope's band, as annotations at their frequencies over the spectrum, standing
// above the noise where a signal's peak would be, each with a leader up from the spectrum's foot. The app zooms and pans the picture itself, so the annotations are laid out in lanes by
// frequency at the zoom the pane last reported: a pan leaves them right, and a zoom's `commit`
// brings a render that lays them out again.
import type { BoardSpot, PanelSceneSpectrumAnnotation, PanelSceneSpectrumLayer, SuggestedQso } from "@ham2k/extension-sdk"

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
  /** Something new to work it for. */
  fresh: boolean
  icon?: string
  iconColor?: string
  emoji?: string
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
    // A band tag ("QRM") or a call not fully copied ("W1A?") names no one station: two of them
    // are two places on the band, each its own mark.
    const key = s.spot.tag || call.includes("?") ? `${call}@${s.freq}` : call
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
      fresh: (s.annotations?.notices.length ?? 0) > 0,
      ...(icon ? { icon, iconColor: shown.display?.iconColor } : {}),
      ...(shown.display?.emoji ? { emoji: shown.display.emoji } : {}),
    }
  })
}

/** Who keeps a place when the lanes are full: something new first, then the unworked, then the newest. */
const rank = (s: ScopeSpot) => (s.fresh ? 0 : s.worked ? 2 : 1) * 1e6 + s.ageMinutes

/** Over the scope's fixed dark picture: new ones gold, our own green, the worked grey. */
const inks = { fresh: "#FFD166", self: "#8EE3A1", worked: "#7F8EA0", plain: "#E8EEF4" }
/** The scope's own background; a spot's box is it, see-through, so it dims the picture rather than standing out from it. */
export const scopeBackground = "#0B0E17"
const leader = "#8FA3B8"
const ink = (s: ScopeSpot) => (s.fresh ? inks.fresh : s.isSelf ? inks.self : s.worked ? inks.worked : inks.plain)
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
  /** The layers left for the spots, of the 128 a band scope takes. */
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

/** A band scope takes 128 layers, and each spot draws three: its passband, its leader and its dot. */
const layersPerSpot = 3

/** `±<n>px`, as a coordinate's offset is written. */
const px = (n: number) => `${n < 0 ? "-" : "+"}${Math.abs(n)}px`

/**
 * Each spot in the first lane where its box clears every box already there, in rank order — the
 * best placed nearest the part's edge — each with a leader from that edge to its box, a dot where
 * it meets the edge, and a bar along the edge over the passband its mode takes. Those with no room
 * are left out, and past the layers a band scope takes.
 */
export function spotMarks(spots: ScopeSpot[], layout: SpotLayout): { annotations: PanelSceneSpectrumAnnotation[]; layers: PanelSceneSpectrumLayer[] } {
  const taken: [number, number][][] = Array.from({ length: Math.max(0, layout.lanes) }, () => [])
  const annotations: PanelSceneSpectrumAnnotation[] = [],
    layers: PanelSceneSpectrumLayer[] = []
  const down = layout.part === "waterfall"
  // On the part's edge, past the axis lying over it, moved [dy] down the screen.
  const edge = (dy = 0) => (down ? `waterfall${px(layout.clear + dy)}` : `spectrum:bottom${px(dy - layout.clear)}`)
  for (const s of [...spots].sort((a, b) => rank(a) - rank(b))) {
    if (annotations.length >= Math.floor((layout.layers ?? 128) / layersPerSpot)) break
    const hz = Math.round(s.khz * 1000),
      half = ((widthOf(s) + gap) / 2) * layout.hzPerPx
    const lane = taken.findIndex((spans) => spans.every(([from, to]) => hz + half <= from || hz - half >= to))
    if (lane < 0) continue
    taken[lane].push([hz - half, hz + half])
    const opacity = 1 - (1 - faintest) * Math.min(1, s.ageMinutes / Math.max(1, layout.maxAgeMinutes))
    const offset = (layout.from ? 0 : layout.clear) + 4 + lane * laneHeight
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
      event: layout.event,
    })
    // Where the signal would be heard, a bar along the edge, under the leader and its dot.
    const heard = spotPassband(s.mode, s.khz)
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

/**
 * The stretch a spot's signal takes, in Hz either side of its frequency: phone 2.8 kHz on its
 * sideband, AM 2.8 kHz and FM 7 kHz either side, data 3 kHz above the dial, CW 250 Hz around it.
 * None for a spot that names no mode.
 */
export function spotPassband(mode: string | undefined, khz: number): [number, number] | undefined {
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

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The band plan where the station is, as band annotations: each stretch of the band that is
// allocated, between its edges; the stretches of its modes, CW, data and phone; where each license
// level the station's regulator issues may transmit; the FT8 and FT4 windows; and the frequencies
// known for something (calling frequencies, QRP, beacons, nets). The plan is the station's own, by
// its region and country, as the library has it.
import {
  isOutsideLicensePrivileges,
  licenseJurisdictionForEntity,
  licenseLevelKey,
  modeForFrequency,
  SUPER_MODES,
  superModeForMode,
} from "@ham2k/lib-operation-data"
import { entityForCall, entityPrefixForCall, regionAndCountryForDxccCode } from "@ham2k/extension-sdk"
import type { BandAnnotation } from "@ham2k/extension-sdk"

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

/** Where a license level may transmit on a band, in any mode: one stretch of it. */
export type LicenseRun = { level: string; from: number; to: number }
const licenseRuns = new Map<string, LicenseRun[]>()

/**
 * Where each level the station's regulator still issues may transmit on the band, in any mode, as
 * the library has it, a stretch at a time. None for a regulator the library has no levels for, or a
 * station not known: the levels are only its own regulator's.
 */
export function licenseRunsFor(band: string, station: { entity?: string; region?: number }): LicenseRun[] {
  const jurisdiction = station.entity ? licenseJurisdictionForEntity(station.entity) : undefined
  const edges = bandEdges[band]
  if (!jurisdiction || !edges || !station.entity) return []
  const key = `${band} ${station.entity} ${station.region ?? ""}`
  const known = licenseRuns.get(key)
  if (known) return known
  const found: LicenseRun[] = []
  for (const level of jurisdiction.levels.filter((l) => !l.legacy)) {
    const options = { level: licenseLevelKey(jurisdiction, level), entityPrefix: station.entity, ituRegion: station.region }
    // Just above each point: a segment's own edges are outside it, so a sample on one would find
    // every level allowed there and break the band at every edge for an instant.
    const may = (khz: number) => SUPER_MODES.some((mode) => isOutsideLicensePrivileges(khz + 0.004, { ...options, mode }) === false)
    for (const run of stretchesOf(edges, may)) if (run.value) found.push({ level: level.name, from: run.from, to: run.to })
  }
  licenseRuns.set(key, found)
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

/** The modes the plan gives a narrow window of their own, inside a stretch of another. */
const windowModes = ["FT8", "FT4"]

type Kind = "CW" | "DATA" | "PHONE" | "ANY"
const kindLabels: Record<Kind, string> = { CW: "CW", DATA: "Data", PHONE: "Phone", ANY: "All modes" }
const inBand = (s: PlanSegment) => s.mode !== false && s.mode !== undefined
const kindOf = (mode: string | null): Kind => (mode == null ? "ANY" : (superModeForMode(mode) as Kind))

const digital = ["FT8", "FT4", "JS8", "PSK", "PSK31", "DATA", "DIGI", "OLIVIA", "MFSK", "JT65", "JT9", "Q65", "FST4"]

/**
 * The stretch a marker covers, in Hz either side of it: a mode's passband — phone 2.8 kHz on its
 * usual sideband (lower below 10 MHz, upper above and on 60 m), AM 2.8 kHz and FM 7 kHz either
 * side, data 3 kHz above the dial, CW 250 Hz around it — WSPR's 200 Hz of audio above the dial,
 * and none for a boundary.
 */
function markerPassband(m: BandMarker): [number, number] | undefined {
  const lower = m.khz < 10000 && !(m.khz >= 5330 && m.khz <= 5410)
  if (m.mode === "WSPR") return [1400, 1600]
  if (m.mode === "SSB") return lower ? [-2800, 0] : [0, 2800]
  if (m.mode === "AM") return [-2800, 2800]
  if (m.mode === "FM") return [-7000, 7000]
  if (m.mode === "RTTY" || (m.mode && digital.includes(m.mode))) return [0, 3000]
  if (m.mode === "CW") return [-125, 125]
  return undefined
}

const hz = (khz: number) => Math.round(khz * 1000)

/**
 * The band plan on [band] for a station at [station]'s location, or the library's own where it is
 * not known, as annotations: the allocated stretches as `edge`s, the modes' stretches as primary
 * `plan`s and the license levels' as secondary ones, the FT8 and FT4 windows as secondary `known`s,
 * and the markers as tertiary ones.
 */
export function annotationsFor(band: string, station?: string): BandAnnotation[] {
  const where: Where = station ? regionAndCountryForDxccCode(entityForCall(station).dxccCode) : {}
  const segments = bandPlan(band, where)
  if (!segments.length) return []
  const annotations: BandAnnotation[] = []

  const banded = segments.filter(inBand)
  const runs: [number, number][] = []
  for (const s of banded) {
    const last = runs[runs.length - 1]
    if (last && last[1] >= s.from) last[1] = s.to
    else runs.push([s.from, s.to])
  }
  for (const [from, to] of runs) annotations.push({ type: "edge", key: `edge:${from}`, fromHz: hz(from), toHz: hz(to) })

  // The modes' stretches. A window of its own, or a hole in the plan, takes the kind before it (at a
  // run's start, the one after), so it splits no stretch.
  const isWindow = (s: PlanSegment) => typeof s.mode === "string" && windowModes.includes(s.mode)
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
  for (const s of stretches) annotations.push({ type: "plan", key: `mode:${s.from}`, fromHz: hz(s.from), toHz: hz(s.to), label: kindLabels[s.kind] })

  const entity = station ? entityPrefixForCall(station) : undefined
  for (const r of licenseRunsFor(band, { entity, region: where.ituRegion })) {
    annotations.push({ type: "plan", key: `license:${r.level}:${r.from}`, fromHz: hz(r.from), toHz: hz(r.to), label: r.level, importance: "secondary" })
  }

  for (const w of banded.filter(isWindow)) {
    annotations.push({ type: "known", key: `window:${w.mode}:${w.from}`, fromHz: hz(w.from), toHz: hz(w.to), label: w.mode as string, importance: "secondary" })
  }

  for (const [i, m] of markersFor(band, station ? { entity, region: where.ituRegion } : {}).entries()) {
    const covers = markerPassband(m)
    annotations.push({
      type: "known",
      key: `marker:${i}`,
      fromHz: hz(m.khz) + (covers?.[0] ?? 0),
      ...(covers ? { toHz: hz(m.khz) + covers[1] } : {}),
      label: `${m.emoji} ${m.label}`,
      importance: "tertiary",
    })
  }
  return annotations
}

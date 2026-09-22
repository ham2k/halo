// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ARRL VHF+ contest scoring, ported from app-polo's ARRLVHFContestsExtension
// `scoringForQSO`/`accumulateScoreForOperation`/`summarizeScore` into a
// `ContestScorer`.
//
// Three scoring shapes share one scorer, selected by the running event's
// `score` kind (events.ts):
//   * `points` — a fixed value per band (Jan/Jun/Sep VHF).
//   * `distance` — `round(great-circle km) * multipliers[band]` (222 MHz+).
//   * `distanceAndPoints` — the distance formula plus `points.qso` ONCE per
//     unique callsign per band (10 GHz+, rules 5.1–5.4). The QSO points are
//     not multiplied by the band factor, and a station re-worked on the same
//     band from a new location earns distance only. Only a contact carrying
//     the event's full-length grid takes the QSO points, so an earlier
//     short-grid contact with the same station neither earns them nor uses
//     them up.
//
// `operation.grid` is the segment-effective grid for each QSO — the harness
// resolves `break`/`start` overrides before calling `scoreQso`
// (docs/design/contests.md, `ContestScorer.scoreQso` doc comment), so a
// rover's current grid is simply what this reads; no segment-walking here.
//
// A QSO worked while OUR grid differs from a prior QSO with the same station
// is not a dupe — a rover changing squares creates a new, separately-scored
// contact even against a station already worked. Only a repeat of the exact
// (call, band, our grid, their grid) tuple is a dupe. A QSO with no their-grid
// exchange never reaches the dupe check at all — it exits earlier as
// `missingExchange` and is never recorded into `worked`. A grid that is
// present but shorter than the event's exchange (`shortGrid`) still scores
// its distance: the sponsor's log checker may accept it, and refusing the
// points outright would hide a real contact behind a typing slip.

import type { ContestScorer, JSONValue, QsoScoreVerdict, ScoreTally } from "@ham2k/extension-sdk"
import { fmtInteger } from "@ham2k/lib-format-tools"
import { distanceOnEarth, gridToLocation } from "@ham2k/lib-geo-tools"

import { eventFor } from "./events.ts"
import { trimmedGrid } from "./exchange.ts"

export type ARRLVHFScoresheet = {
  /// `call|band|ourGrid` → the set of their-grids already worked under that
  /// key.
  worked: Record<string, string[]>
  /// `call|band` → the QSO points already went to a contact with this
  /// station on this band (`distanceAndPoints` events only).
  qsoPointsTaken: Record<string, true>
  bands: Record<string, number>
  qsos: number
  points: number
  /// The two halves of `points` for `distanceAndPoints` events — the summary
  /// reports them separately, since the rules score them separately.
  distancePoints: number
  qsoPoints: number
  distanceTotal: number
  maxDistance: number
  maxDistancePerBand: Record<string, number>
  dupeCount: number
  dayQsos: number
  dayPoints: number
}

function str(value: JSONValue | undefined): string {
  return typeof value === "string" ? value : ""
}

function distanceKm(ourGrid: string, theirGrid: string): number | null {
  if (!ourGrid || !theirGrid) return null
  // gridToLocation THROWS on anything that isn't a well-formed 4/6/8-char
  // locator — unlike distanceOnEarth, which returns null. A grid that made it
  // this far already passed the exchange field's pattern, but `operation.grid`
  // has no equivalent gate, so a malformed rover grid must not take down
  // scoring for the whole log.
  let our: [number, number]
  let their: [number, number]
  try {
    our = gridToLocation(ourGrid)
    their = gridToLocation(theirGrid)
  } catch {
    return null
  }
  return distanceOnEarth({ lat: our[0], lon: our[1] }, { lat: their[0], lon: their[1] }, { units: "km" })
}

export const ARRLVHFScorer: ContestScorer<ARRLVHFScoresheet> = {
  startScoresheet(): ARRLVHFScoresheet {
    return {
      worked: {},
      qsoPointsTaken: {},
      bands: {},
      qsos: 0,
      points: 0,
      distancePoints: 0,
      qsoPoints: 0,
      distanceTotal: 0,
      maxDistance: 0,
      maxDistancePerBand: {},
      dupeCount: 0,
      dayQsos: 0,
      dayPoints: 0,
    }
  },

  // Mutates and returns the given scoresheet — see ContestScorer.scoreQso.
  scoreQso({ scoresheet, qso, operation, ref, isNewDay }) {
    const base = scoresheet
    // A scoresheet persisted by a build that predates these three fields
    // comes back through `resumeFrom` (the spots panel scores candidates off
    // the cached end-of-log sheet before the whole-log rescore replaces it);
    // without this it reads `undefined[...]` and the pass throws.
    base.qsoPointsTaken ??= {}
    base.distancePoints ??= 0
    base.qsoPoints ??= 0
    if (isNewDay) {
      base.dayQsos = 0
      base.dayPoints = 0
    }

    const event = eventFor(str(ref?.ref))
    if (!event) return { scoresheet: base, score: { value: 0 } }

    const their = (qso.their as Record<string, JSONValue>) ?? {}
    const call = str(their.call)
    if (!call) return { scoresheet: base, score: { value: 0 } }

    const band = str(qso.band)
    if (!event.bands.includes(band)) {
      return { scoresheet: base, score: { value: 0, alerts: ["invalidBand"] } }
    }

    const ourGrid = trimmedGrid(str(operation.grid), event)
    const contestRef = ((qso.refs as Record<string, JSONValue>[] | undefined) ?? []).find((r) => r?.type === "arrl-vhf-tests")
    const theirGrid = trimmedGrid(str(contestRef?.grid), event)

    if (!ourGrid) {
      return { scoresheet: base, score: { value: 0, alerts: ["ourGrid"] } }
    }
    if (!theirGrid) {
      return { scoresheet: base, score: { value: 0, alerts: ["missingExchange"] } }
    }

    const key = `${call}|${band}|${ourGrid}`
    const priorGrids = base.worked[key] ?? []
    const isDupe = priorGrids.includes(theirGrid)
    if (isDupe) {
      base.dupeCount += 1
      return { scoresheet: base, score: { value: 0, dupe: true, alerts: ["duplicate"] } }
    }

    const alerts: string[] = []
    const fullGrid = theirGrid.length >= event.gridChars
    if (event.score !== "points" && !fullGrid) alerts.push("shortGrid")

    let value: number
    let distance: number | null = null
    let distancePoints = 0
    let qsoPoints = 0
    if (event.score === "points") {
      value = event.points?.[band] ?? 0
    } else {
      // Both grids are present here (the earlier `!ourGrid`/`!theirGrid`
      // checks already handled the missing-exchange case) — a null result
      // means one of them is present but malformed, not absent.
      distance = distanceKm(ourGrid, theirGrid)
      if (distance === null) return { scoresheet: base, score: { value: 0, alerts: ["invalidExchange"] } }
      distance = Math.round(distance)
      // A band this event lists but doesn't multiplier is a gap in the event
      // data (polo's own 10 GHz tables omit `submm`) — score it visibly
      // wrong rather than silently zero, so it reads as a data bug to fix
      // instead of a legitimate zero-point contact.
      const multiplier = event.multipliers?.[band]
      if (multiplier === undefined) return { scoresheet: base, score: { value: 0, alerts: ["invalidBand"] } }
      distancePoints = distance * multiplier
      value = distancePoints
      if (event.score === "distanceAndPoints") {
        const pointsKey = `${call}|${band}`
        if (fullGrid && !base.qsoPointsTaken[pointsKey]) {
          qsoPoints = event.points?.qso ?? 0
          base.qsoPointsTaken[pointsKey] = true
        }
        value += qsoPoints
      }
    }

    base.worked[key] = [...priorGrids, theirGrid]
    base.bands[band] = (base.bands[band] ?? 0) + 1
    base.qsos += 1
    base.points += value
    base.distancePoints += distancePoints
    base.qsoPoints += qsoPoints
    base.dayQsos += 1
    base.dayPoints += value
    if (distance !== null) {
      base.distanceTotal += distance
      base.maxDistance = Math.max(base.maxDistance, distance)
      base.maxDistancePerBand[band] = Math.max(base.maxDistancePerBand[band] ?? 0, distance)
    }

    const score: QsoScoreVerdict = { value, band }
    if (distance !== null) score.distance = distance
    if (alerts.length > 0) score.alerts = alerts
    return { scoresheet: base, score }
  },

  summarizeScore({ scoresheet, ref, scope }): Record<string, ScoreTally> {
    const event = eventFor(str(ref?.ref))
    const isDay = scope === "day"
    const points = isDay ? scoresheet.dayPoints : scoresheet.points
    const qsos = isDay ? scoresheet.dayQsos : scoresheet.qsos

    const usesDistance = event?.score !== "points"
    const summary = usesDistance ? `${fmtInteger(points)} pts (${fmtInteger(scoresheet.distanceTotal)} km total)` : `${fmtInteger(points)} pts`
    // The whole-log split; the day scope has no per-day halves to show.
    const split =
      event?.score === "distanceAndPoints" && !isDay
        ? `${fmtInteger(scoresheet.distancePoints)} distance points + ${fmtInteger(scoresheet.qsoPoints)} QSO points`
        : null

    const bandLines = Object.keys(scoresheet.bands)
      .sort()
      .map((band) => {
        const count = scoresheet.bands[band] ?? 0
        if (!count) return null
        return usesDistance
          ? `**${band}**: ${fmtInteger(count)} QSOs • Longest: ${fmtInteger(scoresheet.maxDistancePerBand[band] ?? 0)} km`
          : `**${band}**: ${fmtInteger(count)} QSOs`
      })
      .filter((line): line is string => line !== null)

    return {
      "arrl-vhf-tests": {
        key: "arrl-vhf-tests",
        for: scope,
        icon: "radio-tower",
        total: points,
        qsos,
        summary,
        longSummary: [
          summary + (scoresheet.dupeCount > 0 ? ` (${fmtInteger(scoresheet.dupeCount)} dupe${scoresheet.dupeCount > 1 ? "s" : ""})` : ""),
          ...(split ? [split] : []),
          ...bandLines,
        ].join("\n"),
      },
    }
  },
}

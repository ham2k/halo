// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// IARU Region 1 VHF+ contest scoring, ported from app-polo's
// Region1VHFContestsExtension `scoringForQSO`/`accumulateScoreForOperation`/
// `summarizeScore` into a `ContestScorer`.
//
// Points are `distanceForRegion1VHFContests(ourGrid, theirGrid) *
// multiplier[band]` — R1's own great-circle function (`@ham2k/lib-geo-tools`),
// which rounds UP (`floor(km) + 1`), unlike ARRL's plain `round(km)`. It also
// already try/catches a malformed grid internally and returns null, so
// nothing here needs to guard against `gridToLocation` throwing the way
// arrl-vhf-tests' scorer does.
//
// `operation.grid` is the segment-effective grid for each QSO (the harness
// resolves `break`/`start` overrides before calling `scoreQso`), so a rover's
// current grid is simply what this reads — same as arrl-vhf-tests, no
// segment-walking here.
//
// A QSO worked while OUR grid differs from a prior QSO with the same station
// is not a dupe — a rover changing squares creates a new, separately-scored
// contact. Only a repeat of the exact (call, band, our grid, their grid)
// tuple is a dupe.

import type { ContestScorer, JSONValue, QsoScoreVerdict, ScoreTally } from "@ham2k/extension-sdk"
import { fmtInteger } from "@ham2k/lib-format-tools"
import { distanceForRegion1VHFContests } from "@ham2k/lib-geo-tools"

import { eventFor } from "./events.ts"
import { trimmedGrid } from "./exchange.ts"

/// All 1 except the millimeter bands, matching app-polo's table — R1 doesn't
/// scale the microwave bands as steeply as ARRL's family does. `5m`, `33cm`
/// and `3cm` are absent from app-polo's own table (`distance *
/// BAND_MULTIPLIERS[band]` is `NaN` there for those bands) even though
/// `lib-operation-data`'s VHF_BANDS/UHF_BANDS/SHF_BANDS — spread into
/// `ALL_BANDS` and `R1-VHF-UHF-OCTOBER`'s band list in events.ts — include
/// them; added here at 1, consistent with every other non-millimeter band.
/// Exported for rsgb-vhf-tests, which uses the identical ramp under RSGB's
/// own rules rather than duplicating the table.
export const BAND_MULTIPLIERS: Record<string, number> = {
  "6m": 1,
  "5m": 1,
  "4m": 1,
  "2m": 1,
  "1.25m": 1,
  "70cm": 1,
  "33cm": 1,
  "23cm": 1,
  "13cm": 1,
  "9cm": 1,
  "6cm": 1,
  "3cm": 1,
  "1.25cm": 1,
  "6mm": 2,
  "4mm": 3,
  "2.5mm": 4,
  "2mm": 8,
  "1mm": 10,
  submm: 10,
}

export type R1VHFScoresheet = {
  worked: Record<string, string[]>
  bands: Record<string, number>
  qsos: number
  points: number
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

export const R1VHFScorer: ContestScorer<R1VHFScoresheet> = {
  startScoresheet(): R1VHFScoresheet {
    return {
      worked: {},
      bands: {},
      qsos: 0,
      points: 0,
      distanceTotal: 0,
      maxDistance: 0,
      maxDistancePerBand: {},
      dupeCount: 0,
      dayQsos: 0,
      dayPoints: 0,
    }
  },

  scoreQso({ scoresheet, qso, operation, ref, isNewDay }) {
    const base = scoresheet
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

    const ourGrid = trimmedGrid(str(operation.grid))
    const contestRef = ((qso.refs as Record<string, JSONValue>[] | undefined) ?? []).find((r) => r?.type === "r1-vhf-tests")
    const theirGrid = trimmedGrid(str(contestRef?.grid))

    if (!ourGrid) {
      return { scoresheet: base, score: { value: 0, alerts: ["ourGrid"] } }
    }
    if (!theirGrid) {
      return { scoresheet: base, score: { value: 0, alerts: ["missingExchange"] } }
    }

    const key = `${call}|${band}|${ourGrid}`
    const priorGrids = base.worked[key] ?? []
    if (priorGrids.includes(theirGrid)) {
      base.dupeCount += 1
      return { scoresheet: base, score: { value: 0, dupe: true, alerts: ["duplicate"] } }
    }

    const distance = distanceForRegion1VHFContests(ourGrid, theirGrid)
    if (distance === null) return { scoresheet: base, score: { value: 0, alerts: ["invalidExchange"] } }
    const value = distance * (BAND_MULTIPLIERS[band] ?? 0)

    base.worked[key] = [...priorGrids, theirGrid]
    base.bands[band] = (base.bands[band] ?? 0) + 1
    base.qsos += 1
    base.points += value
    base.dayQsos += 1
    base.dayPoints += value
    base.distanceTotal += distance
    base.maxDistance = Math.max(base.maxDistance, distance)
    base.maxDistancePerBand[band] = Math.max(base.maxDistancePerBand[band] ?? 0, distance)

    const score: QsoScoreVerdict = { value, band, distance }
    return { scoresheet: base, score }
  },

  summarizeScore({ scoresheet, scope }): Record<string, ScoreTally> {
    const isDay = scope === "day"
    const points = isDay ? scoresheet.dayPoints : scoresheet.points
    const qsos = isDay ? scoresheet.dayQsos : scoresheet.qsos

    const summary = `${fmtInteger(points)} pts (${fmtInteger(scoresheet.distanceTotal)} km total)`

    const bandLines = Object.keys(scoresheet.bands)
      .sort()
      .map((band) => {
        const count = scoresheet.bands[band] ?? 0
        if (!count) return null
        return `**${band}**: ${fmtInteger(count)} QSOs • Longest: ${fmtInteger(scoresheet.maxDistancePerBand[band] ?? 0)} km`
      })
      .filter((line): line is string => line !== null)

    return {
      "r1-vhf-tests": {
        key: "r1-vhf-tests",
        for: scope,
        icon: "flag-checkered",
        total: points,
        qsos,
        summary,
        longSummary: [
          summary + (scoresheet.dupeCount > 0 ? ` (${fmtInteger(scoresheet.dupeCount)} dupe${scoresheet.dupeCount > 1 ? "s" : ""})` : ""),
          ...bandLines,
        ].join("\n"),
      },
    }
  },
}

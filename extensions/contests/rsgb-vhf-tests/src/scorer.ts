// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// RSGB VHF+ contest scoring, ported from app-polo's RSGBVHFContestsExtension
// `scoringForQSO`/`accumulateScoreForOperation`/`summarizeScore` into a
// `ContestScorer`. Shares r1-vhf-tests' distance formula and rounding rule
// (`distanceForRegion1VHFContests`, floor(km) + 1) with one addition: working
// the SAME grid as your own scores a fixed 50, since the great-circle formula
// degenerates toward zero at that range and RSGB's rules give a floor instead.
//
// Bonuses (event.bonus, events.ts) are the real divergence from r1: some
// events award flat points once per NEW band×{4-char grid | district |
// DXCC entity} worked. Each seen-set doubles as its own membership check —
// the bonus adds only on the QSO that makes a key first appear — so a
// duplicate (rejected earlier, before bonuses are considered) never
// contributes one.

import type { ContestScorer, JSONValue, QsoScoreVerdict, ScoreTally } from "@ham2k/halo-extension-sdk"
import { entityPrefixForCall } from "../../../sdk/src/dxcc.ts"
import { fmtInteger } from "@ham2k/lib-format-tools"
import { distanceForRegion1VHFContests } from "@ham2k/lib-geo-tools"

import { RSGB_POSTCODE_DISTRICTS } from "./districts.ts"
import { eventFor, hasDistrictExchange } from "./events.ts"
import { trimmedGrid } from "./exchange.ts"
import { BAND_MULTIPLIERS } from "../../r1-vhf-tests/src/scorer.ts"

export type RSGBVHFScoresheet = {
  worked: Record<string, string[]>
  bands: Record<string, number>
  qsos: number
  points: number
  bonus: number
  distanceTotal: number
  maxDistance: number
  maxDistancePerBand: Record<string, number>
  dupeCount: number
  dayQsos: number
  dayPoints: number
  gridsSeen: Record<string, true>
  districtsSeen: Record<string, true>
  entitiesSeen: Record<string, true>
}

function str(value: JSONValue | undefined): string {
  return typeof value === 'string' ? value : ''
}

export const RSGBVHFScorer: ContestScorer<RSGBVHFScoresheet> = {
  startScoresheet(): RSGBVHFScoresheet {
    return {
      worked: {}, bands: {}, qsos: 0, points: 0, bonus: 0, distanceTotal: 0,
      maxDistance: 0, maxDistancePerBand: {}, dupeCount: 0, dayQsos: 0, dayPoints: 0,
      gridsSeen: {}, districtsSeen: {}, entitiesSeen: {},
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
      return { scoresheet: base, score: { value: 0, alerts: ['invalidBand'] } }
    }

    const ourGrid = trimmedGrid(str(operation.grid))
    const contestRef = ((qso.refs as Record<string, JSONValue>[] | undefined) ?? []).find(
      (r) => r?.type === 'rsgb-vhf-tests',
    )
    const theirGrid = trimmedGrid(str(contestRef?.grid))

    if (!ourGrid) {
      return { scoresheet: base, score: { value: 0, alerts: ['ourGrid'] } }
    }
    if (!theirGrid) {
      return { scoresheet: base, score: { value: 0, alerts: ['missingExchange'] } }
    }

    const key = `${call}|${band}|${ourGrid}`
    const priorGrids = base.worked[key] ?? []
    if (priorGrids.includes(theirGrid)) {
      base.dupeCount += 1
      return { scoresheet: base, score: { value: 0, dupe: true, alerts: ['duplicate'] } }
    }

    // The same square as ours is a real, short-range contact the plain
    // great-circle formula would round down toward nothing — RSGB gives it a
    // flat floor instead.
    const distance = theirGrid === ourGrid ? 50 : distanceForRegion1VHFContests(ourGrid, theirGrid)
    if (distance === null) return { scoresheet: base, score: { value: 0, alerts: ['invalidExchange'] } }
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

    // Bonuses: "flat points once per NEW band×{grid4|district|DXCC}" — the
    // bonus adds only when the key wasn't already in the seen-set, so a
    // dupe (rejected above, before reaching here) or a repeat key never
    // contributes twice.
    if (event.bonus?.newGrid) {
      const gridKey = `${band}-${theirGrid.substring(0, 4)}`
      if (!base.gridsSeen[gridKey]) {
        base.gridsSeen[gridKey] = true
        base.bonus += event.bonus.newGrid
      }
    }
    if (event.bonus?.newDistrict && hasDistrictExchange(event)) {
      const location = str(contestRef?.location).toUpperCase()
      if (location && RSGB_POSTCODE_DISTRICTS[location]) {
        const districtKey = `${band}-${location}`
        if (!base.districtsSeen[districtKey]) {
          base.districtsSeen[districtKey] = true
          base.bonus += event.bonus.newDistrict
        }
      }
    }
    if (event.bonus?.newDXCC) {
      const entity = entityPrefixForCall(call)
      if (entity) {
        const entityKey = `${band}-${entity}`
        if (!base.entitiesSeen[entityKey]) {
          base.entitiesSeen[entityKey] = true
          base.bonus += event.bonus.newDXCC
        }
      }
    }

    const score: QsoScoreVerdict = { value, band, distance }
    return { scoresheet: base, score }
  },

  summarizeScore({ scoresheet, scope }): Record<string, ScoreTally> {
    const isDay = scope === 'day'
    const points = isDay ? scoresheet.dayPoints : scoresheet.points
    const qsos = isDay ? scoresheet.dayQsos : scoresheet.qsos
    // Bonuses accumulate for the whole operation only — RSGB's rules award
    // them once per contest, not once per day of a multi-day event.
    const total = points + (isDay ? 0 : scoresheet.bonus)

    const summary = scoresheet.bonus
      ? `${fmtInteger(points)} pts + ${fmtInteger(scoresheet.bonus)} bonus = ${fmtInteger(total)} pts`
      : `${fmtInteger(points)} pts`

    const bandLines = Object.keys(scoresheet.bands).sort().map((band) => {
      const count = scoresheet.bands[band] ?? 0
      if (!count) return null
      return `**${band}**: ${fmtInteger(count)} QSOs • Longest: ${fmtInteger(scoresheet.maxDistancePerBand[band] ?? 0)} km`
    }).filter((line): line is string => line !== null)

    return {
      'rsgb-vhf-tests': {
        key: 'rsgb-vhf-tests',
        for: scope,
        icon: 'flag-checkered',
        total,
        qsos,
        summary,
        longSummary: [
          summary + (scoresheet.dupeCount > 0 ? ` (${fmtInteger(scoresheet.dupeCount)} dupe${scoresheet.dupeCount > 1 ? 's' : ''})` : ''),
          ...bandLines,
        ].join('\n'),
      },
    }
  },
}

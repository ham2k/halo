// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// IARU Region 1 Field Day scoring, per the DARC reference rules
// (https://www.darc.de/der-club/referate/conteste/iaru-region-1-fieldday/rules/).
// Not a polo port — polo never had this contest.
//
// The rules:
//   * Non-WARC HF bands, one QSO per station per band; the QSO's mode must
//     match the running's (CW in June, SSB in September).
//   * Points hinge on BOTH sides being in the field: a fixed station working
//     another fixed station scores zero. Otherwise a fixed station is worth
//     2 points in Europe and 3 outside; a portable one 4 and 6. A station
//     only counts as portable when it SIGNS portable — /P, /M, /MM or /AM
//     (rule 9); /QRP is not a portable designator.
//   * One multiplier per WAE/DXCC entity per band. Total = points × mults.

import { fmtInteger } from "@ham2k/lib-format-tools"
import { parseCallsign } from "@ham2k/lib-callsigns"
import type { ContestScorer, JSONValue, QsoScoreVerdict, ScoreTally } from "@ham2k/extension-sdk"
import { annotateCallAgainstCountryFile } from "../../../sdk/src/dxcc.ts"

export const TYPE = 'r1-fd'

/// A field-day is an HF contest: the WARC bands are excluded by the rules.
export const VALID_BANDS = ['160m', '80m', '40m', '20m', '15m', '10m']

/// The suffixes that make a worked station portable for points (rule 9).
const PORTABLE_INDICATORS = ['P', 'M', 'MM', 'AM']

export type R1FDScoresheet = {
  /// call → bands already worked with it (one QSO per band is allowed).
  workedByCall: Record<string, string[]>
  /// `band|entity` → times worked. PER BAND, unlike WPX's contest-wide
  /// prefixes: `Object.keys().length` IS the multiplier.
  mults: Record<string, number>
  bands: Record<string, number>
  bandPoints: Record<string, number>
  qsos: number
  points: number
  dayQsos: number
  dayPoints: number
  /// Whether WE entered as a fixed station — the setup's `ourStationType`.
  /// Fixed-to-fixed is the one pairing worth nothing.
  ourFixed: boolean
}

function str(value: JSONValue | undefined): string {
  return typeof value === 'string' ? value : ''
}

export function refOfType(container: Record<string, JSONValue>, type: string): Record<string, JSONValue> | undefined {
  return (((container.refs as Record<string, JSONValue>[] | undefined) ?? [])).find((r) => r?.type === type)
}

/// The running's mode, off a ref's `${mode}-${year}` key ("SSB-2026").
export function modeOfRef(refString: string | undefined): string {
  const mode = (refString ?? '').split('-')[0]?.toUpperCase() ?? ''
  return mode === 'CW' || mode === 'SSB' ? mode : ''
}

export function yearOfRef(refString: string | undefined): string {
  const year = (refString ?? '').split('-')[1] ?? ''
  return /^\d{4}$/.test(year) ? year : ''
}

/// Whether a call signs portable for points. `parseCallsign` isolates the
/// designators, so `F/DL1ABC/P` reads its /P and a bare `DL1ABC` reads none.
export function signsPortable(call: string): boolean {
  const indicators = (parseCallsign(call.trim().toUpperCase()).postindicators ?? []) as string[]
  return indicators.some((part) => PORTABLE_INDICATORS.includes(part))
}

/// Each running is single-mode. SSB covers the sideband modes a radio may
/// report; an unconfigured ref filters nothing.
function modeMatches(contestMode: string, qsoMode: string): boolean {
  if (!contestMode) return true
  if (contestMode === 'SSB') return qsoMode === 'SSB' || qsoMode === 'USB' || qsoMode === 'LSB'
  return qsoMode === contestMode
}

export const R1FDScorer: ContestScorer<R1FDScoresheet> = {
  startScoresheet({ ref }): R1FDScoresheet {
    return {
      workedByCall: {}, mults: {}, bands: {}, bandPoints: {},
      qsos: 0, points: 0, dayQsos: 0, dayPoints: 0,
      ourFixed: str(ref?.ourStationType) === 'FIXED',
    }
  },

  // Mutates and returns the given scoresheet — see ContestScorer.scoreQso.
  scoreQso({ scoresheet, qso, ref, isNewDay }) {
    const base = scoresheet
    if (isNewDay) {
      base.dayQsos = 0
      base.dayPoints = 0
    }

    const their = (qso.their as Record<string, JSONValue>) ?? {}
    const call = str(their.call)
    if (!call) return { scoresheet: base, score: { value: 0 } }

    const band = str(qso.band)
    const mode = str(qso.mode)

    if (!modeMatches(modeOfRef(str(ref?.ref)), mode)) {
      return { scoresheet: base, score: { value: 0, alerts: ['invalidMode'] } }
    }
    if (!VALID_BANDS.includes(band)) {
      return { scoresheet: base, score: { value: 0, alerts: ['invalidBand'] } }
    }

    // One QSO per station per band.
    const worked = base.workedByCall[call] ?? []
    if (worked.includes(band)) {
      return { scoresheet: base, score: { value: 0, dupe: true, alerts: ['duplicate'] } }
    }

    // WAE resolution, on both axes at once: the mult list gains the WAE-only
    // entities (*IT9, *TA1, *4U1V…), and `continent` is the WAE continent —
    // European Turkey scores as Europe, which the DXCC table would get wrong.
    const theirInfo = annotateCallAgainstCountryFile(call, { wae: true })

    // POINTS (rule 9). Two-axis table — where they are and whether they are in
    // the field — with the fixed-to-fixed pairing worth zero. There is no
    // low-band doubling and own-country QSOs count like any other.
    const theirPortable = signsPortable(call)
    const inEurope = theirInfo.continent === 'EU'
    let points: number
    if (theirPortable) points = inEurope ? 4 : 6
    else if (base.ourFixed) points = 0
    else points = inEurope ? 2 : 3

    // The multiplier: one per WAE/DXCC entity PER BAND.
    //
    // A zero-point fixed-to-fixed QSO still counts it: the rules zero the
    // POINTS for that pairing and say nothing about the country worked.
    const entity = theirInfo.entityPrefix ?? ''
    let isNewMult = false
    if (entity) {
      const multKey = `${band}|${entity}`
      isNewMult = base.mults[multKey] === undefined
      base.mults[multKey] = (base.mults[multKey] ?? 0) + 1
    }

    if (worked.length > 0) base.workedByCall[call].push(band)
    else base.workedByCall[call] = [band]

    base.bands[band] = (base.bands[band] ?? 0) + 1
    base.bandPoints[band] = (base.bandPoints[band] ?? 0) + points
    base.qsos += 1
    base.points += points
    base.dayQsos += 1
    base.dayPoints += points

    const score: QsoScoreVerdict = { value: points, band }
    const notices: string[] = []
    if (isNewMult) notices.push('newMult')
    if (worked.length > 0) notices.push('newBand')
    if (notices.length > 0) score.notices = notices
    if (entity) score.entity = entity

    return { scoresheet: base, score }
  },

  summarizeScore({ scoresheet, scope }): Record<string, ScoreTally> {
    const isDay = scope === 'day'
    const multCount = Object.keys(scoresheet.mults).length
    const points = isDay ? scoresheet.dayPoints : scoresheet.points
    // Multipliers accumulate across the whole running, so a day's "score" is
    // still its points against the running mult count.
    const total = points * multCount

    return {
      r1fd: {
        key: 'r1fd',
        for: scope,
        icon: 'tent',
        total,
        points,
        mults: multCount,
        qsos: isDay ? scoresheet.dayQsos : scoresheet.qsos,
        label: `${fmtInteger(points)} × ${fmtInteger(multCount)}`,
        summary: `${fmtInteger(total)}`,
        longSummary: breakdown(scoresheet),
      },
    }
  },
}

/// The per-band table — in a field day the per-band countries ARE the score,
/// so seeing where the mults came from is what tells an operator which band
/// needs work.
function breakdown(sheet: R1FDScoresheet): string {
  const lines = VALID_BANDS.map((band) => {
    const qsos = sheet.bands[band] ?? 0
    const points = sheet.bandPoints[band] ?? 0
    const mults = Object.keys(sheet.mults).filter((key) => key.startsWith(`${band}|`)).length
    return qsos === 0
      ? `**${band}**: —`
      : `**${band}**: ${fmtInteger(qsos)} QSOs, ${fmtInteger(points)} pts, ${fmtInteger(mults)} countries`
  })
  return lines.join('\n')
}

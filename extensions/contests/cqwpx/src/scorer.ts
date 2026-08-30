// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// CQ WPX scoring. Ported from app-polo's CQWPXExtension, but implementing the
// published rules rather than polo's reading of them — see POINTS below for the
// two places they differ.
//
// The rules, per the CQ WPX general rules:
//   * The multiplier is the CALLSIGN PREFIX, counted once for the whole
//     contest — NOT per band. That is the one structural difference from CQ WW,
//     and the reason a WPX operator chases new prefixes rather than new bands.
//   * A station may be worked once per band for QSO point credit.
//   * Only 160/80/40/20/15/10m count, and the QSO's mode must match the
//     contest's mode.
//   * Total = QSO points x prefixes.

import { fmtInteger } from "@ham2k/lib-format-tools"
import { parseCallsign } from "@ham2k/lib-callsigns"
import type { ContestScorer, JSONValue, QsoScoreVerdict, ScoreTally } from "@ham2k/extension-sdk"
import { annotateCallAgainstCountryFile } from "../../../sdk/src/dxcc.ts"

/// WPX is an HF contest: the WARC bands are excluded by the rules.
export const VALID_BANDS = ['160m', '80m', '40m', '20m', '15m', '10m']

/// The low bands are worth double, per rule B.1/B.2.
const DOUBLE_POINT_BANDS = ['160m', '80m', '40m']

export type CQWPXScoresheet = {
  /// call → bands already worked with it (one QSO per band is allowed).
  workedByCall: Record<string, string[]>
  /// Prefix → times worked. Contest-wide, NOT per band: `Object.keys().length`
  /// IS the multiplier.
  mults: Record<string, number>
  /// Per-band prefix counts, for the summary table only — they never multiply.
  bandMults: Record<string, Record<string, number>>
  bands: Record<string, number>
  bandPoints: Record<string, number>
  qsos: number
  points: number
  dayQsos: number
  dayPoints: number
  /// Our own continent and DXCC entity, resolved once from the station call —
  /// every point calculation is relative to them.
  ourContinent?: string
  ourEntity?: string
}

function str(value: JSONValue | undefined): string {
  return typeof value === 'string' ? value : ''
}

/// The WPX multiplier for a callsign: the letter/numeral combination that forms
/// the first part of the call.
///
/// `parseCallsign` resolves the hard parts already — a portable designator wins
/// over the home prefix (N8BJQ/W4 → W4, W8/GW4BLE → W8), while /P, /M and /QRP
/// are not prefixes at all (LZ2ITU/P → LZ2). Two rules it does not cover, both
/// named explicitly in the WPX rules:
///
///   * A special-event call that is letters-then-digits IS its own prefix. The
///     rules list HG19, OE25 and LY1000; a general callsign parser reads those
///     as HG1/OE2/LY1 with a numeric suffix, which would merge LY1000 into
///     whatever LY1xxx station was also worked.
///   * Anything with no number gets a zero after its first two letters —
///     PA/N8BJQ → PA0, XEFTJW → XE0. Dropping these instead would silently
///     under-count the multiplier.
export function wpxPrefix(call: string): string {
  const trimmed = call.trim().toUpperCase()
  if (!trimmed) return ''

  // Only for an unmodified call: in `N8BJQ/HG19` the designator is what counts,
  // and `parseCallsign` is what knows which side of the slash that is.
  if (!trimmed.includes('/') && /^[A-Z]+[0-9]+$/.test(trimmed)) return trimmed

  const parsed = parseCallsign(trimmed)
  const candidate = str(parsed.prefix as JSONValue | undefined) || trimmed.replace(/[^A-Z0-9]/g, '')
  if (!candidate) return ''
  return /[0-9]/.test(candidate) ? candidate : `${candidate.slice(0, 2)}0`
}

/// CQ WPX runs separate CW, SSB and RTTY weekends; a QSO in the wrong mode is
/// not a contest QSO. SSB covers the sideband modes a radio may report.
function modeMatches(contestMode: string, qsoMode: string): boolean {
  if (!contestMode) return true
  if (contestMode === 'SSB') return qsoMode === 'SSB' || qsoMode === 'USB' || qsoMode === 'LSB'
  if (contestMode === 'CW') return qsoMode === 'CW'
  return qsoMode === contestMode
}

export const CQWPXScorer: ContestScorer<CQWPXScoresheet> = {
  startScoresheet({ operation }): CQWPXScoresheet {
    const ours = annotateCallAgainstCountryFile(str(operation.stationCall))
    return {
      workedByCall: {}, mults: {}, bandMults: {}, bands: {}, bandPoints: {},
      qsos: 0, points: 0, dayQsos: 0, dayPoints: 0,
      ourContinent: ours.continent,
      ourEntity: ours.entityPrefix,
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

    if (!modeMatches(str(ref?.mode), mode)) {
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

    const theirInfo = annotateCallAgainstCountryFile(call)

    // POINTS (rule B), and the two places app-polo diverges from it:
    //
    //   1. Different continents — 3 points, doubled to 6 on the low bands.
    //   2. Same continent, different country — 1 point, doubled to 2. The
    //      exception is North America, where NA-to-NA is 2, doubled to 4.
    //      (polo gave every same-continent-different-country QSO 2 points,
    //      i.e. the NA rate worldwide — an EU-to-EU QSO scored double.)
    //   3. Same country — 1 point REGARDLESS OF BAND. (polo doubled it on the
    //      low bands along with everything else.)
    //
    // Unlike CQ WW, working your own country is not worth zero here.
    const sameCountry = !!base.ourEntity && !!theirInfo.entityPrefix && base.ourEntity === theirInfo.entityPrefix
    let points: number
    if (sameCountry) {
      points = 1
    } else {
      const sameContinent =
        !!base.ourContinent && !!theirInfo.continent && base.ourContinent === theirInfo.continent
      if (!sameContinent) points = 3
      else points = base.ourContinent === 'NA' ? 2 : 1
      if (DOUBLE_POINT_BANDS.includes(band)) points *= 2
    }

    // The multiplier. Contest-wide: a prefix already worked on any band is not
    // new, however many bands it turns up on.
    const prefix = wpxPrefix(call)
    let isNewMult = false
    if (prefix) {
      isNewMult = base.mults[prefix] === undefined
      base.mults[prefix] = (base.mults[prefix] ?? 0) + 1
      ;(base.bandMults[band] ??= {})[prefix] = (base.bandMults[band]?.[prefix] ?? 0) + 1
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
    if (prefix) score.prefix = prefix

    return { scoresheet: base, score }
  },

  summarizeScore({ scoresheet, scope }): Record<string, ScoreTally> {
    const isDay = scope === 'day'
    const multCount = Object.keys(scoresheet.mults).length
    const points = isDay ? scoresheet.dayPoints : scoresheet.points
    // Multipliers accumulate across the whole contest, so a day's "score" is
    // still its points against the running prefix count.
    const total = points * multCount

    return {
      cqwpx: {
        key: 'cqwpx',
        for: scope,
        icon: 'flag-checkered',
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

/// The per-band table plus the prefix list — in WPX the prefixes ARE the score,
/// so seeing which ones are already in the log is what tells an operator
/// whether a station on the band is worth calling.
function breakdown(sheet: CQWPXScoresheet): string {
  const lines = VALID_BANDS.map((band) => {
    const qsos = sheet.bands[band] ?? 0
    const points = sheet.bandPoints[band] ?? 0
    const mults = Object.keys(sheet.bandMults[band] ?? {}).length
    return qsos === 0
      ? `**${band}**: —`
      : `**${band}**: ${fmtInteger(qsos)} QSOs, ${fmtInteger(points)} pts, ${fmtInteger(mults)} prefixes`
  })

  const prefixes = Object.keys(sheet.mults).sort()
  if (prefixes.length > 0) {
    lines.push('')
    lines.push(`**${fmtInteger(prefixes.length)} prefixes**`)
    lines.push(prefixes.join(' '))
  }
  return lines.join('\n')
}

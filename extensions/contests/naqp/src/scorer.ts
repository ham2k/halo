// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// North American QSO Party scoring, ported from app-polo's NAQPExtension
// `scoringForQSO` / `accumulateScoreForOperation` / `summarizeScore` into a
// `ContestScorer`.
//
// The rules, per the NCJ NAQP rules:
//   * Every valid QSO is worth 1 point. There is no distance or continent
//     ladder — the scoring is entirely in the multipliers.
//   * Multipliers are states, provinces and North American DXCC entities,
//     counted ONCE PER BAND. `DX` is a perfectly good exchange and a perfectly
//     good QSO, but it is not a multiplier.
//   * A station may be worked once per band.
//   * Only 160/80/40/20/15/10m count.
//   * NAQP CW, SSB and RTTY are separate contests on separate weekends, so the
//     operation names one mode and QSOs in another don't count.
//
// Divergences from polo, per the RFC's fix-on-port decision (§8):
//   * polo validates NEITHER band nor mode — it defines VALID_BANDS and never
//     consults it, so a 30m QSO scores and a CW contact counts in the SSB
//     contest. Both are checked here.
//   * polo's duplicate test mixes exact mode (`q.mode === mode`) with
//     super-mode (`superModeForMode(q.mode) === superMode`) in the same
//     function, so USB and LSB on one band read as two different contacts.
//     Since the contest is single-mode anyway, a duplicate here is simply the
//     same station on the same band.

import { fmtInteger } from "@ham2k/lib-format-tools"
import { ADIF_MODE_FOR_SUBMODE, superModeForMode } from "@ham2k/lib-operation-data"
import type { ContestScorer, JSONValue, QsoScoreVerdict, ScoreTally } from "@ham2k/extension-sdk"

import { normalizeLocation } from "./exchange.ts"
import { isMultiplier } from "./locations.ts"

/// NAQP is an HF contest: the WARC bands are excluded by the rules.
export const VALID_BANDS = ['160m', '80m', '40m', '20m', '15m', '10m']

/// The bands a given running actually allows. RTTY is 80-10 — the rules exclude
/// 160m for that one contest only, so a flat list over-claims a band multiplier
/// the log checker will strike.
export function validBandsFor(contestMode: string): string[] {
  return contestMode.toUpperCase() === 'RTTY' ? VALID_BANDS.filter((b) => b !== '160m') : VALID_BANDS
}

export type NAQPScoresheet = {
  /// call → bands already worked with it.
  workedByCall: Record<string, string[]>
  /// `band|LOCATION` → count. Per band, which is the whole multiplier rule.
  mults: Record<string, number>
  bandMults: Record<string, Record<string, number>>
  bands: Record<string, number>
  qsos: number
  points: number
  dayQsos: number
  dayPoints: number
}

function str(value: JSONValue | undefined): string {
  return typeof value === 'string' ? value : ''
}

/// Whether a QSO's mode counts for a contest run in [contestMode].
///
/// CW and phone compare by FAMILY, so a QSO logged as USB or LSB counts in the
/// SSB running — the radio reports the sideband and the sponsor doesn't care
/// which. The digital family cannot: `superModeForMode` lumps RTTY in with FT8,
/// PSK31 and everything else digital, and NAQP RTTY means RTTY. So that one
/// compares exactly.
///
/// A QSO with NO mode is rejected rather than judged. `superModeForMode('')`
/// answers `'DATA'`, which would otherwise make every mode-less QSO — an ADIF
/// import missing MODE, say — a valid RTTY contact.
function modeMatches(contestMode: string, qsoMode: string): boolean {
  if (!contestMode) return true
  if (!qsoMode) return false
  const contestFamily = superModeForMode(contestMode)
  if (contestFamily !== 'DATA') return superModeForMode(qsoMode) === contestFamily

  const mode = qsoMode.toUpperCase()
  const wanted = contestMode.toUpperCase()
  if (mode === wanted) return true
  // `DATA` is halo's own generic picker entry (halo_core ham/radio.dart) — the
  // operator said "digital" without saying which, which in an RTTY running
  // means RTTY. Rejecting it would zero a contact made by anyone whose rig sits
  // in DATA-U.
  if (mode === 'DATA') return true
  // ADIF stores a SUBMODE as the mode when there is one, so a perfectly ordinary
  // RTTY contact can arrive logged as `ASCI`. Resolve it to its parent mode
  // rather than string-matching.
  return (ADIF_MODE_FOR_SUBMODE[mode] ?? '').toUpperCase() === wanted
}

export const NAQPScorer: ContestScorer<NAQPScoresheet> = {
  startScoresheet(): NAQPScoresheet {
    return {
      workedByCall: {}, mults: {}, bandMults: {}, bands: {},
      qsos: 0, points: 0, dayQsos: 0, dayPoints: 0,
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

    if (!modeMatches(str(ref?.mode), str(qso.mode))) {
      return { scoresheet: base, score: { value: 0, alerts: ['invalidMode'] } }
    }
    if (!validBandsFor(str(ref?.mode)).includes(band)) {
      return { scoresheet: base, score: { value: 0, alerts: ['invalidBand'] } }
    }

    const worked = base.workedByCall[call] ?? []
    if (worked.includes(band)) {
      return { scoresheet: base, score: { value: 0, dupe: true, alerts: ['duplicate'] } }
    }

    const contestRef = ((qso.refs as Record<string, JSONValue>[] | undefined) ?? []).find((r) => r?.type === 'naqp')
    const location = normalizeLocation(contestRef?.location)

    // Every valid QSO is a point, whatever they sent — an unrecognized or
    // missing location costs the multiplier, not the contact.
    const points = 1
    let newMult = false
    if (isMultiplier(location)) {
      const mult = `${band}|${location}`
      newMult = base.mults[mult] === undefined
      base.mults[mult] = (base.mults[mult] ?? 0) + 1
      ;(base.bandMults[band] ??= {})[mult] = (base.bandMults[band]?.[mult] ?? 0) + 1
    }

    const heardBefore = worked.length > 0
    if (heardBefore) base.workedByCall[call].push(band)
    else base.workedByCall[call] = [band]

    base.bands[band] = (base.bands[band] ?? 0) + 1
    base.qsos += 1
    base.points += points
    base.dayQsos += 1
    base.dayPoints += points

    const score: QsoScoreVerdict = { value: points, band }
    const notices: string[] = []
    if (newMult) notices.push('newMult')
    // Decided from `worked` as it stood before this band was recorded.
    if (heardBefore) notices.push('newBand')
    if (notices.length > 0) score.notices = notices
    // A location that earns nothing has to SAY so. Every US state, province and
    // NA entity is a multiplier, so an exchange this contest doesn't recognize
    // is a multiplier going unclaimed — and a typo the operator can still fix,
    // if they're told. polo tinted the field red for the same reason.
    if (!location) score.alerts = ['missingExchange']
    else if (!isMultiplier(location) && location !== 'DX') score.alerts = ['invalidExchange']

    return { scoresheet: base, score }
  },

  summarizeScore({ scoresheet, scope }): Record<string, ScoreTally> {
    const isDay = scope === 'day'
    const multCount = Object.keys(scoresheet.mults).length
    const points = isDay ? scoresheet.dayPoints : scoresheet.points
    // Multipliers accumulate across the whole contest, so a day's "score" is
    // still its points against the running multiplier count.
    const total = points * (multCount || 0)

    return {
      naqp: {
        key: 'naqp',
        for: scope,
        icon: 'flag-checkered',
        total,
        points,
        mults: multCount,
        qsos: isDay ? scoresheet.dayQsos : scoresheet.qsos,
        label: `${fmtInteger(points)} × ${fmtInteger(multCount)}`,
        summary: `${fmtInteger(total)}`,
        longSummary: bandBreakdown(scoresheet),
      },
    }
  },
}

/// The per-band table a contester actually reads while operating.
function bandBreakdown(sheet: NAQPScoresheet): string {
  return VALID_BANDS.map((band) => {
    const qsos = sheet.bands[band] ?? 0
    const mults = Object.keys(sheet.bandMults[band] ?? {}).length
    return qsos === 0 && mults === 0
      ? `**${band}**: —`
      : `**${band}**: ${fmtInteger(qsos)} QSOs, ${fmtInteger(mults)} mults`
  }).join('\n')
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Winter Field Day scoring.
//
// DUPLICATED with `fd`, on purpose. The two contests are near-identical —
// same exchange, same points table, same dupe rule, same three-way section
// tally — and a factory would say so in one place. Each extension standing
// alone, readable and movable without reaching into a sibling, is worth more
// here than not repeating it.
//
// What actually differs from ARRL Field Day, and why a shared version would
// have had to be parameterised on all of it anyway:
//   - class is `1H`..`9O` — Home, Indoor, Mobile, Outdoor, no `PC` prefix
//   - the multiplier is the objectives met, each with its OWN weight
//   - there are no bonus points; the objectives ARE the bonus
//   - satellite contacts earn the multiplier but NOT QSO points
//
// The rules: https://www.winterfieldday.org/

import { tally } from "@ham2k/halo-extension-sdk"
import type {
  ContestScorer,
  HookContext,
  JSONValue,
  QsoScoreVerdict,
  ScoreTally,
} from "@ham2k/halo-extension-sdk"
import { fmtInteger } from "@ham2k/lib-format-tools"
import { superModeForMode } from "@ham2k/lib-operation-data"

import { ABBREVIATED_SECTION_NAMES, ARRL_SECTIONS, RAC_SECTIONS } from "./sections.ts"
import { tFor } from "./i18n.ts"

export const TYPE = 'wfd'

/// `1H`, `3O`. The letter is the category — Home, Indoor, Mobile, Outdoor —
/// and unlike ARRL Field Day there is no "please copy" prefix.
export const CLASS_REGEX = /^([1-9][0-9]*)([HIMO])$/

/// Phone is worth one, everything else two.
const POINTS: Record<string, number> = { PHONE: 1, CW: 2, DATA: 2 }

/// Winter Field Day excludes the same four WARC bands as ARRL Field Day.
const INVALID_BANDS = new Set(['60m', '30m', '17m', '12m'])

/// Valid to receive, but not sections — they are tallied on their own.
const NON_SECTION_LOCATIONS = new Set(['MX', 'DX'])

export type WFDScoresheet = {
  /// `call|band|superMode`. The dupe rule is per band AND mode, so the same
  /// station on two bands is two contacts.
  worked: Record<string, true>
  /// Bands and modes already seen per call, so a second contact can be told it
  /// is new on one of them rather than merely refused.
  bandsByCall: Record<string, Record<string, true>>
  modesByCall: Record<string, Record<string, true>>
  qsoPoints: number
  qsoCount: number
  /// Reset on each new UTC day. Winter Field Day ALWAYS spans two of them
  /// (1900Z Saturday to 1859Z Sunday), so without these the per-day header
  /// reports the running total instead of that day's.
  dayPoints: number
  dayQsos: number
  /// The setup as it stood while these QSOs were scored.
  ///
  /// `summarizeScore` is handed the FIRST segment's ref, so reading the
  /// multiplier there loses a mid-contest change — checking off another
  /// objective partway through is normal. Latched here instead, the way
  /// `stateparks` does it.
  multiplier: number
  byMode: Record<string, number>
  /// Three tallies because the rules count them three ways.
  /// Sections already worked, so the notice fires on news rather than on every
  /// contact — matching how newBand/newMode behave.
  sectionsSeen: Record<string, true>
  arrlSections: Record<string, number>
  racSections: Record<string, number>
  otherSections: Record<string, number>
}

function str(value: JSONValue | undefined): string {
  return typeof value === 'string' ? value.trim() : ''
}

function refsOfType(
  container: Record<string, JSONValue> | undefined,
  type: string,
): Record<string, JSONValue>[] {
  const refs = (container?.refs as Record<string, JSONValue>[] | undefined) ?? []
  return Array.isArray(refs) ? refs.filter((r) => r?.type === type) : []
}

export function refOfType(
  container: Record<string, JSONValue> | undefined,
  type: string,
): Record<string, JSONValue> | undefined {
  const refs = (container?.refs as Record<string, JSONValue>[] | undefined) ?? []
  return Array.isArray(refs) ? refs.find((r) => r?.type === type) : undefined
}

/// The multiplier: one for taking part, plus each objective's OWN weight.
///
/// NOT one per objective. The objectives are weighted 1 to 6 and there are
/// twelve of them, so the real maximum is 33 — counting them flat caps it at
/// 8 and reports a well-equipped station's score at a fraction of the truth.
export function objectiveMultiplier(ref: Record<string, JSONValue> | undefined): number {
  let total = 1
  for (const [key, weight] of Object.entries(OBJECTIVES)) {
    if (ref?.[key] === true) total += weight
  }
  return total
}

/// The twelve objectives and what each adds to the multiplier.
export const OBJECTIVES: Record<string, number> = {
  objectiveAltPower: 1,
  objectiveAwayFromHome: 3,
  objectiveMultipleAntennas: 1,
  objectiveFmSatellite: 2,
  objectiveSsbCwSatellite: 3,
  objectiveWinlink: 1,
  objectiveSpecialBulletin: 1,
  objectiveSixBands: 6,
  objectiveTwelveBands: 6,
  objectiveMultipleModes: 2,
  objectiveQrp: 4,
  objectiveSixContinuousHours: 2,
}

/// In form order, so the setup checklist and the scorer cannot drift.
export const OBJECTIVE_KEYS = Object.keys(OBJECTIVES)

export const WFDScorer: ContestScorer<WFDScoresheet> = {
  startScoresheet(): WFDScoresheet {
    return {
      worked: {},
      bandsByCall: {},
      modesByCall: {},
      qsoPoints: 0,
      qsoCount: 0,
      dayPoints: 0,
      dayQsos: 0,
      multiplier: 1,
      byMode: {},
      sectionsSeen: {},
      arrlSections: {},
      racSections: {},
      otherSections: {},
    }
  },

  scoreQso({ scoresheet, qso, operation, ref, isNewDay }, _ctx) {
    const sheet = scoresheet

    // The DUPE rule spans the whole event, so `worked` is never reset — only
    // the day-scoped display counters are.
    if (isNewDay) {
      sheet.dayPoints = 0
      sheet.dayQsos = 0
    }

    // Latched per QSO from the segment-effective operation, so a setup change
    // partway through the contest counts for the QSOs after it.
    const setup = refOfType(operation, TYPE) ?? ref
    sheet.multiplier = objectiveMultiplier(setup)

    const their = (qso.their as Record<string, JSONValue>) ?? {}
    const call = str(their.call).toUpperCase()
    if (!call) return { scoresheet: sheet, score: { value: 0 } }

    const band = str(qso.band)
    // NOT `superModeForMode(mode) ?? 'PHONE'` — that fallback is dead, because
    // the library answers 'DATA' for an empty mode rather than nullish. A
    // mode-less QSO would score 2 instead of 1 and dupe-key as DATA, so a
    // later real SSB contact with the same station on the same band would not
    // be caught. `stateparks` and `naqp` guard it the same way.
    const mode = str(qso.mode)
    const superMode = mode ? superModeForMode(mode) : ''

    if (INVALID_BANDS.has(band)) {
      // An alert rather than silence: an operator who has drifted onto 30m
      // wants to know while they can still move.
      return { scoresheet: sheet, score: { value: 0, alerts: ['invalidBand'] } }
    }

    const qsoRef = refOfType(qso, TYPE)
    const section = str(qsoRef?.location).toUpperCase()
    const theirClass = str(qsoRef?.class).toUpperCase()

    const key = `${call}|${band}|${superMode}`
    if (sheet.worked[key] === true) {
      return { scoresheet: sheet, score: { value: 0, dupe: true, alerts: ['duplicate'] } }
    }

    const notices: string[] = []
    const seenBands = sheet.bandsByCall[call]
    const seenModes = sheet.modesByCall[call]
    // Only news for a station already worked — on a first contact every band is
    // a new band, which is not worth saying.
    if (seenBands && !seenBands[band]) notices.push('newBand')
    if (seenModes && !seenModes[superMode]) notices.push('newMode')

    // A stable KEY, never the section's display name. `notices` is a
    // translation-key vocabulary (app/lib/tools/scoring_labels.dart) that falls
    // back to printing the key itself, so a name pushed through it reaches a
    // Spanish operator in English and is written into the QSO's score cache
    // that way. Every other scorer emits keys only.
    const known = ARRL_SECTIONS[section] ?? RAC_SECTIONS[section]
    const firstOfItsSection = Boolean(section) && !sheet.sectionsSeen[section]
    if (known && firstOfItsSection) notices.push('newSection')

    // Satellite contacts count toward the objectives but NOT toward QSO
    // points — the rules say so twice. The `satellites` extension is what
    // records them, so the ref it writes is the signal.
    const viaSatellite = refsOfType(qso, 'satellite').length > 0
    // An unknown or absent mode is worth the phone rate, not the data rate.
    const value = viaSatellite ? 0 : (POINTS[superMode] ?? 1)

    sheet.worked[key] = true
    ;(sheet.bandsByCall[call] ??= {})[band] = true
    ;(sheet.modesByCall[call] ??= {})[superMode] = true
    sheet.qsoCount += 1
    sheet.qsoPoints += value
    sheet.dayQsos += 1
    sheet.dayPoints += value
    if (section) sheet.sectionsSeen[section] = true
    sheet.byMode[superMode] = (sheet.byMode[superMode] ?? 0) + 1

    if (section) {
      if (ARRL_SECTIONS[section]) {
        sheet.arrlSections[section] = (sheet.arrlSections[section] ?? 0) + 1
      } else if (RAC_SECTIONS[section]) {
        sheet.racSections[section] = (sheet.racSections[section] ?? 0) + 1
      } else if (NON_SECTION_LOCATIONS.has(section)) {
        sheet.otherSections[section] = (sheet.otherSections[section] ?? 0) + 1
      }
    }

    const score: QsoScoreVerdict = { value }
    if (notices.length > 0) score.notices = notices
    return { scoresheet: sheet, score }
  },

  summarizeScore({ scoresheet, scope }, ctx): Record<string, ScoreTally> {
    const t = tFor(ctx)
    const isDay = scope === 'day'
    // Latched during the fold, not read off `ref` — the ref handed here is the
    // FIRST segment's, which loses a mid-contest power change.
    const multiplier = scoresheet.multiplier
    const points = isDay ? scoresheet.dayPoints : scoresheet.qsoPoints
    const qsos = isDay ? scoresheet.dayQsos : scoresheet.qsoCount
    // Bonuses are claimed once for the whole entry, so they belong to the
    // operation total and are left out of a day's figure entirely rather than
    // being counted again on each one — the rule `stateparks` states.
    const total = points * multiplier

    const sections =
      Object.keys(scoresheet.arrlSections).length +
      Object.keys(scoresheet.racSections).length +
      Object.keys(scoresheet.otherSections).length

    return {
      contest: tally(TYPE, scope, total, {
        // Without an icon the day-header renderer drops the whole badge, not
        // just the glyph (qso_list.dart).
        icon: 'snowflake',
        label: t('scoreLabel'),
        summary: t('scoreSummary', { total: fmtInteger(total) }),
        // Spelled out because an operator checking a claimed score wants the
        // arithmetic, not just the answer.
        longSummary: [
          t('scoreQsos', { qsos: fmtInteger(qsos), points: fmtInteger(points), multiplier }),
          t('scoreSections', { sections: fmtInteger(sections) }),
        ]
          .filter((line) => line)
          .join('\n'),
      }),
    }
  },
}

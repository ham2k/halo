// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ARRL Field Day scoring.
//
// DUPLICATED with `wfd`, on purpose. The two contests are near-identical —
// same exchange, same points table, same dupe rule, same three-way section
// tally — and a factory would say so in one place. Each extension standing
// alone, readable and movable without reaching into a sibling, is worth more
// here than not repeating it.
//
// What actually differs from Winter Field Day, and why a shared version would
// have had to be parameterised on all of it anyway:
//   - class is `1A`..`14F`, optionally `PC`-prefixed ("please copy")
//   - the WARC bands score nothing
//   - the multiplier comes from transmitter power and power source
//   - there are bonus points, from a checklist in setup
//
// The rules: https://field-day.arrl.org/

import type { ContestScorer, HookContext, JSONValue, QsoScoreVerdict } from "@ham2k/extension-sdk"
import { contestArithmetic, contestSummary } from "../../../sdk/src/contestSummary.ts"
import { fmtInteger } from "@ham2k/lib-format-tools"
import { superModeForMode } from "@ham2k/lib-operation-data"

import { ABBREVIATED_SECTION_NAMES, ARRL_SECTIONS, RAC_SECTIONS } from "./sections.ts"
import { tFor } from "./i18n.ts"

export const TYPE = "fd"

/// `1A`, `14F`, and `PC2B` for a station asking you to copy a bulletin.
export const CLASS_REGEX = /^(PC)?([1-9][0-9]*)([ABCDEF])$/

/// Phone is worth one, everything else two.
const POINTS: Record<string, number> = { PHONE: 1, CW: 2, DATA: 2 }

/// Field Day does not run on the WARC bands. A contact there is logged and
/// submitted; it simply earns nothing.
const INVALID_BANDS = new Set(["60m", "30m", "17m", "12m"])

/// Valid to receive, but not sections — they are tallied on their own.
const NON_SECTION_LOCATIONS = new Set(["MX", "DX"])

export type FDScoresheet = {
  /// `call|band|superMode`. The dupe rule is per band AND mode, so the same
  /// station on two bands is two contacts.
  worked: Record<string, true>
  /// Bands and modes already seen per call, so a second contact can be told it
  /// is new on one of them rather than merely refused.
  bandsByCall: Record<string, Record<string, true>>
  modesByCall: Record<string, Record<string, true>>
  qsoPoints: number
  qsoCount: number
  /// The setup as it stood while these QSOs were scored.
  ///
  /// `summarizeScore` is handed the FIRST segment's ref, so reading the
  /// multiplier there loses a mid-contest change — switching generator to
  /// battery is the normal way to earn the x5. Latched here instead, the way
  /// `stateparks` does it.
  multiplier: number
  bonus: number
  /// Contacts whose class carried the `PC` prefix. Not scoring — app-polo
  /// reports it, and an operator watching for the bulletin would miss it.
  pleaseCopy: number
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
  return typeof value === "string" ? value.trim() : ""
}

export function refOfType(container: Record<string, JSONValue> | undefined, type: string): Record<string, JSONValue> | undefined {
  const refs = (container?.refs as Record<string, JSONValue>[] | undefined) ?? []
  return Array.isArray(refs) ? refs.find((r) => r?.type === type) : undefined
}

/// The power multiplier, from what the operator declared in setup.
///
/// Five for QRP off batteries or solar, two for QRP on a generator OR 100W off
/// anything, one otherwise. Read off the operation's own ref, which is where
/// the setup form writes.
export function powerMultiplier(ref: Record<string, JSONValue> | undefined): number {
  const power = str(ref?.ourPower).toUpperCase()
  const source = str(ref?.ourPowerSource).toUpperCase()
  if (power === "5W" && source === "BATTERIES") return 5
  if (power === "5W" || power === "100W") return 2
  return 1
}

/// Bonus points, totalled from the checklist in setup.
///
/// Each value and cap is the rule's, not a flat 100 — getting these wrong is
/// how a summary sheet gets rejected. Counted bonuses are capped HERE rather
/// than at input, so a club that really does run 25 transmitters records the
/// truth and still claims the right number.
export function bonusPoints(ref: Record<string, JSONValue> | undefined): number {
  const num = (key: string): number => {
    const value = Number(ref?.[key] ?? 0)
    return Number.isFinite(value) && value > 0 ? value : 0
  }
  const flag = (key: string): boolean => ref?.[key] === true

  let total = 0

  // 100 per transmitter, capped at 20 — and ONLY for running entirely on
  // emergency power. There is no standalone per-transmitter bonus: awarding one
  // gives a mains-powered home station points it is not entitled to, and gives
  // a station that IS on emergency power the same amount twice.
  if (flag("bonusEmergencyPower")) total += Math.min(num("bonusTransmitters"), 20) * 100

  // 10 per formal message, capped at 10 messages.
  total += Math.min(num("bonusNTSMessages"), 10) * 10
  // 5 per GOTA contact, uncapped, plus a flat 100 if a coach ran the station.
  total += num("bonusGotaQsos") * 5
  // 20 per youth participant who made at least one contact, capped at 100.
  total += Math.min(num("bonusYouthParticipants") * 20, 100)

  for (const [key, points] of Object.entries(CLAIMED_BONUSES)) {
    if (flag(key)) total += points
  }
  return total
}

/// The bonuses that are simply claimed or not, and what each is worth.
///
/// Not all 100 — web submission is 50 and Site Responsibilities is 50.
export const CLAIMED_BONUSES: Record<string, number> = {
  bonusMediaPublicity: 100,
  bonusPublicLocation: 100,
  bonusInformationTable: 100,
  bonusMessageToSM: 100,
  bonusSatelliteQSO: 100,
  bonusAlternatePowerQSOs: 100,
  bonusW1AWMessage: 100,
  bonusElectedOfficialVisit: 100,
  bonusAgencyOfficialVisit: 100,
  bonusEducationalActivity: 100,
  bonusSocialMedia: 100,
  bonusSafetyOfficer: 100,
  bonusGotaCoach: 100,
  bonusSiteResponsibilities: 50,
  bonusWebSubmission: 50,
}

/// The claimed bonuses in the order the setup form should list them, so the
/// form and the scorer cannot drift.
export const CLAIMED_BONUS_KEYS = Object.keys(CLAIMED_BONUSES)

export const FDScorer: ContestScorer<FDScoresheet> = {
  startScoresheet(): FDScoresheet {
    return {
      worked: {},
      bandsByCall: {},
      modesByCall: {},
      qsoPoints: 0,
      qsoCount: 0,
      multiplier: 1,
      bonus: 0,
      pleaseCopy: 0,
      byMode: {},
      sectionsSeen: {},
      arrlSections: {},
      racSections: {},
      otherSections: {},
    }
  },

  scoreQso({ scoresheet, qso, operation, ref }, _ctx) {
    const sheet = scoresheet

    // Latched per QSO from the segment-effective operation, so a setup change
    // partway through the contest counts for the QSOs after it.
    const setup = refOfType(operation, TYPE) ?? ref
    sheet.multiplier = powerMultiplier(setup)
    sheet.bonus = bonusPoints(setup)

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
    const superMode = mode ? superModeForMode(mode) : ""

    if (INVALID_BANDS.has(band)) {
      // An alert rather than silence: an operator who has drifted onto 30m
      // wants to know while they can still move.
      return { scoresheet: sheet, score: { value: 0, alerts: ["invalidBand"] } }
    }

    const qsoRef = refOfType(qso, TYPE)
    const section = str(qsoRef?.location).toUpperCase()
    const theirClass = str(qsoRef?.class).toUpperCase()

    const key = `${call}|${band}|${superMode}`
    if (sheet.worked[key] === true) {
      return { scoresheet: sheet, score: { value: 0, dupe: true, alerts: ["duplicate"] } }
    }

    const notices: string[] = []
    const seenBands = sheet.bandsByCall[call]
    const seenModes = sheet.modesByCall[call]
    // Only news for a station already worked — on a first contact every band is
    // a new band, which is not worth saying.
    if (seenBands && !seenBands[band]) notices.push("newBand")
    if (seenModes && !seenModes[superMode]) notices.push("newMode")

    // A stable KEY, never the section's display name. `notices` is a
    // translation-key vocabulary (app/lib/tools/scoring_labels.dart) that falls
    // back to printing the key itself, so a name pushed through it reaches a
    // Spanish operator in English and is written into the QSO's score cache
    // that way. Every other scorer emits keys only.
    const known = ARRL_SECTIONS[section] ?? RAC_SECTIONS[section]
    const firstOfItsSection = Boolean(section) && !sheet.sectionsSeen[section]
    if (known && firstOfItsSection) notices.push("newSection")

    // An unknown or absent mode is worth the phone rate, not the data rate.
    const value = POINTS[superMode] ?? 1

    sheet.worked[key] = true
    ;(sheet.bandsByCall[call] ??= {})[band] = true
    ;(sheet.modesByCall[call] ??= {})[superMode] = true
    sheet.qsoCount += 1
    sheet.qsoPoints += value
    if (section) sheet.sectionsSeen[section] = true
    sheet.byMode[superMode] = (sheet.byMode[superMode] ?? 0) + 1
    if (CLASS_REGEX.test(theirClass) && theirClass.startsWith("PC")) sheet.pleaseCopy += 1

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

  summarizeScore({ scoresheet, scope }, ctx) {
    const t = tFor(ctx)
    // Latched during the fold, not read off `ref` — the ref handed here is the
    // FIRST segment's, which loses a mid-contest power change.
    const multiplier = scoresheet.multiplier
    const points = scoresheet.qsoPoints
    const bonus = scoresheet.bonus
    const sections = Object.keys(scoresheet.arrlSections).length + Object.keys(scoresheet.racSections).length + Object.keys(scoresheet.otherSections).length

    return contestSummary(
      {
        // `contest`, as before: saved postcard sections are keyed by it.
        key: "contest",
        scope,
        icon: "weather-sunny",
        title: "FD",
        total: points * multiplier + bonus,
        arithmetic: contestArithmetic({ qsos: scoresheet.qsoCount, points, mults: multiplier, multsNoun: t("powerMultiplier"), bonus }, ctx),
        detail: [
          t("scoreSections", { sections: fmtInteger(sections) }),
          scoresheet.pleaseCopy > 0 ? t("scorePleaseCopy", { copies: fmtInteger(scoresheet.pleaseCopy) }) : "",
        ]
          .filter((line) => line)
          .join("\n"),
      },
      ctx,
    )
  },
}

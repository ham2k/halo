// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// NRRL Nasjonal Field Day scoring, per the published rules
// (https://nrrl.no/tema/field-day/regler-for-nasjonal-fieldday/).
//
// A SIBLING of `r1-fd`, not a variant of it. The two run the same weekend and
// share an exchange, which invites reading this as the same contest with
// different numbers — it is not, and four of the differences are structural
// rather than parametric:
//   - all three modes run at once (CW / SSB / DIGIMODE), where an R1 running
//     is single-mode and rejects everything else
//   - a station may be worked once per band AND PER MODE, not once per band
//   - the multiplier carries band and mode as well as country (see MULTS)
//   - countries are DXCC, where R1 scores the WAE list
// Plus 60m counts here, the point table is 1/2/3/4 rather than 2/3/4/6, and
// bonuses run to five figures.
//
// There is no fixed-to-fixed rule to mirror because the case cannot arise:
// every entrant is portable by definition (all stations sign /P, and
// "nettspenning fra det offentlige el-nett må ikke brukes").

// TYPE-only from the SDK, and nothing else — a value import (`tally`, or the
// translator behind `i18n.ts`) makes this module unresolvable to plain
// `node --test`, which is why `fd`'s scorer has no unit tests of its own. The
// rules encoded here are worth testing more than the summary is worth
// translating, so the breakdown below stays in language-neutral numbers, as
// `cqwpx` and `r1-fd` do.
import type { ContestScorer, JSONValue, QsoScoreVerdict, ScoreTally } from "@ham2k/extension-sdk"
import { fmtInteger } from "@ham2k/lib-format-tools"
import { superModeForMode } from "@ham2k/lib-operation-data"

import { parseCallsign } from "@ham2k/lib-callsigns"

import { annotateCallAgainstCountryFile } from "../../../sdk/src/dxcc.ts"

export const TYPE = 'nrrl-nfd'

/// The suffixes that make a worked station portable or mobile for points.
///
/// COPIED from `r1-fd` rather than imported, because the two rulebooks do not
/// say the same thing. R1 enumerates the designators outright (its rule 9:
/// "/p", "/m", "/mm", "/am"); NFD asks for "portable/mobile stasjoner" and
/// never defines how you recognise one. Applying R1's list is the reasonable
/// reading and matches what Norwegian entrants send — every NFD station signs
/// /P by its own rules — but it is an INFERENCE here where it is quoted law
/// there, and an import would hide that difference behind a shared symbol.
const PORTABLE_INDICATORS = ['P', 'M', 'MM', 'AM']

export function signsPortable(call: string): boolean {
  const indicators = (parseCallsign(call.trim().toUpperCase()).postindicators ?? []) as string[]
  return indicators.some((part) => PORTABLE_INDICATORS.includes(part))
}

/// "1,8; 3,5; 5; 7; 14; 21; 28" — note 5 MHz, which the IARU R1 field days
/// exclude.
export const VALID_BANDS = ['160m', '80m', '60m', '40m', '20m', '15m', '10m']

/// The contest's three modes. "Det er tre modes: CW, SSB, og DIGIMODE. Til
/// DIGIMODE regnes alt som ikke er enten telefoni eller telegrafi" — which is
/// exactly the CW/PHONE/DATA split `superModeForMode` already makes, so AM and
/// FM group with SSB as telephony rather than falling into digimode.
///
/// Returns '' for a QSO with no mode at all. Worth the guard: `superModeForMode`
/// answers DATA for an empty string, so a mode-less QSO would otherwise be
/// scored, and counted as a digimode multiplier, in silence.
export function nfdMode(mode: string): string {
  if (!mode) return ''
  const superMode = superModeForMode(mode)
  if (superMode === 'CW') return 'CW'
  return superMode === 'PHONE' ? 'SSB' : 'DIGI'
}

export type NFDScoresheet = {
  /// `call|band|mode` already worked — the dupe key. Per MODE as well as band,
  /// so the same station on 20m CW and 20m SSB is two contacts.
  worked: Record<string, true>
  /// `band|mode|entity` → times worked. `Object.keys().length` IS the
  /// multiplier; see MULTS below for why all three parts are in the key.
  mults: Record<string, number>
  bands: Record<string, number>
  bandPoints: Record<string, number>
  byMode: Record<string, number>
  qsos: number
  points: number
  dayQsos: number
  dayPoints: number
  /// The bonuses as they stood while these QSOs were scored.
  ///
  /// Latched during the fold rather than read off `ref` in `summarizeScore`,
  /// which is handed the FIRST segment's ref — the trap `fd` documents.
  bonus: number
}

function str(value: JSONValue | undefined): string {
  return typeof value === 'string' ? value.trim() : ''
}

export function refOfType(
  container: Record<string, JSONValue> | undefined,
  type: string,
): Record<string, JSONValue> | undefined {
  const refs = (container?.refs as Record<string, JSONValue>[] | undefined) ?? []
  return Array.isArray(refs) ? refs.find((r) => r?.type === type) : undefined
}

/// Bonus points, totalled from the checklist in setup.
///
/// Each value and cap is the rule's — getting these wrong is how a summary
/// sheet gets rejected, and here they dwarf the QSO score: a club with six
/// well-supervised recruits claims 50,000 against an HF total that rarely
/// reaches five figures.
///
/// NOT enforced here, deliberately: recruits count for Class A only
/// ("på stasjoner som deltar i Klasse A"), and every bonus has a documentation
/// requirement and a claiming window — both of them about activity off the
/// air, which NRRL adjudicates from the summary sheet and HaLo cannot
/// observe at all. Zeroing a claim because the class field
/// says B would make the score drop for a reason nothing on screen explains;
/// the setup form states the condition instead.
export function bonusPoints(ref: Record<string, JSONValue> | undefined): number {
  const num = (key: string) => {
    const value = Number(ref?.[key] ?? 0)
    return Number.isFinite(value) && value > 0 ? Math.floor(value) : 0
  }
  const flag = (key: string) => ref?.[key] === true

  let total = 0

  // Recruits: 5,000 for one continuous hour, 10,000 for six cumulative — and
  // 50,000 for all of them together however they are made up.
  total += Math.min(num('bonusRecruits1h') * 5000 + num('bonusRecruits6h') * 10000, 50000)

  if (flag('bonusPublicActivity')) total += 10000
  if (flag('bonusOrienteering')) total += 10000

  // Media is PER OUTLET, not per category: "det gis poeng for hver avis,
  // radio, og TV-kanal. Hvert medium gir kun én poengsum uansett antall
  // innlegg" — three newspapers is 30,000, three articles in one is 10,000.
  // So these are counts of outlets, and the form asks for them that way.
  total += (num('bonusNewspapers') + num('bonusRadioChannels') + num('bonusTvChannels')) * 10000

  // One video only, worth 1,000 plus 10 per like in the week after, capped at
  // 10,000. The likes are counted a week later, so this is a figure the
  // operator comes back and fills in rather than one HaLo could know.
  if (flag('bonusYoutubeVideo')) total += Math.min(1000 + num('bonusYoutubeLikes') * 10, 10000)

  if (flag('bonusLocation')) total += 10000
  if (flag('bonusReport')) total += 10000

  return total
}

export const NFDScorer: ContestScorer<NFDScoresheet> = {
  startScoresheet({ ref }): NFDScoresheet {
    return {
      worked: {}, mults: {}, bands: {}, bandPoints: {}, byMode: {},
      qsos: 0, points: 0, dayQsos: 0, dayPoints: 0,
      bonus: bonusPoints(ref),
    }
  },

  // Mutates and returns the given scoresheet — see ContestScorer.scoreQso.
  scoreQso({ scoresheet, qso, isNewDay }) {
    const base = scoresheet
    if (isNewDay) {
      base.dayQsos = 0
      base.dayPoints = 0
    }

    const their = (qso.their as Record<string, JSONValue>) ?? {}
    const call = str(their.call)
    if (!call) return { scoresheet: base, score: { value: 0 } }

    const band = str(qso.band)
    const mode = nfdMode(str(qso.mode))

    if (!mode) return { scoresheet: base, score: { value: 0, alerts: ['invalidMode'] } }
    if (!VALID_BANDS.includes(band)) {
      return { scoresheet: base, score: { value: 0, alerts: ['invalidBand'] } }
    }

    // "En stasjon må bare kontaktes én gang per bånd og per mode." Both parts
    // are in the key, so the same station is fresh credit on each mode of each
    // band — the opposite of `r1-fd`, where a second mode is a duplicate.
    const workedKey = `${call}|${band}|${mode}`
    if (base.worked[workedKey]) {
      return { scoresheet: base, score: { value: 0, dupe: true, alerts: ['duplicate'] } }
    }

    // DXCC, not WAE: "hvert DXCC-land (inkl. Norge)". So Sicily scores as
    // Italy here, where `r1-fd` counts it separately.
    const theirInfo = annotateCallAgainstCountryFile(call)

    // POINTS. A flat two-axis table — where they are, and whether they are in
    // the field. No low-band doubling, and Norway counts like any other
    // European country ("inkl. Norge").
    const theirPortable = signsPortable(call)
    const inEurope = theirInfo.continent === 'EU'
    let points: number
    if (theirPortable) points = inEurope ? 3 : 4
    else points = inEurope ? 1 : 2

    // MULTS. "Hvert DXCC-land (inkl. Norge) og hver av de tre modi (CW, SSB,
    // Digimode) gir multiplikator" reads as country x mode, but the rule's own
    // worked example settles it the other way: "om man kjører DL på 20 m SSB,
    // 20 m CW og 40 m SSB gir dette tre multiplikatorer" is three only if the
    // BAND counts too — country x mode would make the first and third one
    // multiplier. The total agrees: "summen av alle multiplikatorer på alle
    // bånd og alle modi".
    const entity = theirInfo.entityPrefix ?? ''
    let isNewMult = false
    if (entity) {
      const multKey = `${band}|${mode}|${entity}`
      isNewMult = base.mults[multKey] === undefined
      base.mults[multKey] = (base.mults[multKey] ?? 0) + 1
    }

    base.worked[workedKey] = true
    base.bands[band] = (base.bands[band] ?? 0) + 1
    base.bandPoints[band] = (base.bandPoints[band] ?? 0) + points
    base.byMode[mode] = (base.byMode[mode] ?? 0) + 1
    base.qsos += 1
    base.points += points
    base.dayQsos += 1
    base.dayPoints += points

    const score: QsoScoreVerdict = { value: points, band }
    if (isNewMult) score.notices = ['newMult']
    if (entity) score.entity = entity

    return { scoresheet: base, score }
  },

  summarizeScore({ scoresheet, scope }): Record<string, ScoreTally> {
    const isDay = scope === 'day'
    const multCount = Object.keys(scoresheet.mults).length
    const points = isDay ? scoresheet.dayPoints : scoresheet.points
    const qsos = isDay ? scoresheet.dayQsos : scoresheet.qsos
    // Bonuses are claimed once for the whole entry, so they belong to the
    // operation total and are left out of a day's figure rather than being
    // re-added to each one — the rule `fd` and `stateparks` both follow.
    const bonus = isDay ? 0 : scoresheet.bonus

    // ASSUMPTION, and the one number here the rules do not settle: they define
    // the HF score ("summen av alle poeng, multiplisert med summen av alle
    // multiplikatorer ... blir total HF-poengsum") and define the bonuses, but
    // never say how the two combine. Added, which is what every other field
    // day does and what "total HF-poengsum" implies by naming only the HF
    // half. Worth re-checking against a published result before anyone
    // submits on the strength of this figure.
    const total = points * multCount + bonus

    return {
      contest: {
        key: TYPE,
        for: scope,
        // Without an icon the day-header renderer drops the whole badge, not
        // just the glyph (qso_list.dart).
        icon: 'pine-tree',
        total,
        points,
        mults: multCount,
        qsos,
        label: `${fmtInteger(points)} × ${fmtInteger(multCount)}`,
        summary: `${fmtInteger(total)}`,
        // Spelled out because an operator checking a claimed score wants the
        // arithmetic, not just the answer — and here the bonus can be most of
        // it, so folding it into one total would be actively confusing.
        longSummary: breakdown(scoresheet, points, multCount, bonus),
      },
    }
  },
}

/// The arithmetic, then the per-band table and the per-mode split — with
/// multipliers counted per band AND mode, what tells an operator where the
/// score is left is which combinations are thin.
function breakdown(sheet: NFDScoresheet, points: number, mults: number, bonus: number): string {
  const lines: string[] = []
  if (bonus > 0) {
    lines.push(`**${fmtInteger(points)} × ${fmtInteger(mults)} + ${fmtInteger(bonus)} bonus**`)
    lines.push('')
  }

  lines.push(...VALID_BANDS.map((band) => {
    const bandQsos = sheet.bands[band] ?? 0
    const bandPoints = sheet.bandPoints[band] ?? 0
    const bandMults = Object.keys(sheet.mults).filter((key) => key.startsWith(`${band}|`)).length
    return bandQsos === 0
      ? `**${band}**: —`
      : `**${band}**: ${fmtInteger(bandQsos)} QSOs, ${fmtInteger(bandPoints)} pts, ${fmtInteger(bandMults)} mults`
  }))

  const modes = ['CW', 'SSB', 'DIGI']
    .filter((mode) => sheet.byMode[mode])
    .map((mode) => `${mode} ${fmtInteger(sheet.byMode[mode])}`)
  if (modes.length > 0) {
    lines.push('')
    lines.push(modes.join(' · '))
  }
  return lines.join('\n')
}

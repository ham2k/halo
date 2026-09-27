// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// IARU HF World Championship scoring, ported from app-polo's IARUHFExtension
// `scoringForQSO` / `accumulateScoreForOperation` / `summarizeScore` into a
// `ContestScorer`.
//
// The rules, per the IARU HF World Championship rules:
//   * Everyone sends an ITU zone, EXCEPT society headquarters stations (which
//     send their society abbreviation, e.g. ARRL, RSGB) and IARU officials
//     (which send AC, R1, R2 or R3). One exchange field therefore holds three
//     different kinds of value, and which one it is decides both the points and
//     the multiplier.
//   * Points: 1 within our own ITU zone, and 1 for any HQ or official station
//     however far away; 3 to a different zone on our own continent; 5 to
//     another continent.
//   * Multipliers are PER BAND: each zone, each HQ society and each IARU
//     office counts once per band. Total = points x multipliers.
//   * A station may be worked once per band per MODE — CW and phone are
//     separate contacts, unlike CQ WW. Digital modes don't count at all.
//   * Only 160/80/40/20/15/10m count.
//
// The one rule that reads oddly and is correct: an HQ station in our own zone
// is worth 1 like any other HQ station, because the HQ branch never consults
// zones. Polo does the same, and the rules describe HQ contacts as a flat 1.

import { fmtInteger } from "@ham2k/lib-format-tools"
import { superModeForMode } from "@ham2k/lib-operation-data"
import type { ContestScorer, JSONValue, QsoScoreVerdict } from "@ham2k/extension-sdk"
import { contestArithmetic, contestSummary } from "../../../sdk/src/contestSummary.ts"

import { tFor } from "./i18n.ts"
import { annotateCallAgainstCountryFile } from "../../../sdk/src/dxcc.ts"

/// IARU HF is an HF contest: the WARC bands are excluded by the rules.
export const VALID_BANDS = ["160m", "80m", "40m", "20m", "15m", "10m"]

/// The four IARU offices, which are exchanges in their own right rather than
/// societies. Matched before the numeric test, since neither overlaps.
export const OFFICIAL_CODES = ["AC", "R1", "R2", "R3"]

/// An ITU zone (1-90), a society abbreviation, or an IARU office — the field
/// accepts all three because the operator can't know which they'll get until
/// the other station sends it.
export const EXCHANGE_PATTERN = "[A-Za-z0-9]{1,10}"

export type IARUHFScoresheet = {
  /// call → `band|superMode` combinations already worked with it. IARU counts
  /// CW and phone separately, so this is keyed more finely than CQ WW's.
  workedByCall: Record<string, string[]>
  mults: Record<string, number>
  bandMults: Record<string, Record<string, number>>
  bands: Record<string, number>
  bandPoints: Record<string, number>
  qsos: number
  points: number
  /// Resolved once from the station call and the setup ref — every point
  /// calculation is relative to them.
  ourContinent?: string
  ourZone?: string
}

function str(value: JSONValue | undefined): string {
  return typeof value === "string" ? value : ""
}

/// A zone as sent, reduced to canonical form: "08" and "8" are one multiplier
/// and must not count twice. The country file reports zones as NUMBERS, so
/// this deliberately accepts more than a string.
///
/// ITU zones run 1-90, but an out-of-range NUMBER is still treated as a zone
/// rather than rejected. Rejecting it would send it down the HQ branch in
/// [parseExchange], inventing a society called "99" and a multiplier that does
/// not exist — a worse outcome for a typo than recording it as typed.
export function normalizeZone(value: JSONValue | undefined): string {
  const digits = String(value ?? "").trim()
  if (!/^\d+$/.test(digits)) return ""
  const zone = parseInt(digits, 10)
  return zone > 0 ? String(zone) : ""
}

export type ParsedExchange = { kind: "zone"; value: string } | { kind: "hq"; value: string } | { kind: "official"; value: string } | { kind: "none" }

/// Which of the three things an exchange is. Order matters: `R1` is letters
/// and digits both, so the office list is consulted before anything else.
export function parseExchange(raw: JSONValue | undefined): ParsedExchange {
  const text = String(raw ?? "")
    .trim()
    .toUpperCase()
  if (!text) return { kind: "none" }
  if (OFFICIAL_CODES.includes(text)) return { kind: "official", value: text }
  const zone = normalizeZone(text)
  if (zone) return { kind: "zone", value: zone }
  return { kind: "hq", value: text }
}

/// What WE send, which depends on what kind of station we are. Shared with the
/// ADIF and Cabrillo writers so the exported exchange can't drift from the one
/// the operation is set up to send.
export function ourExchange(operation: Record<string, JSONValue>, ref?: Record<string, JSONValue>): string {
  const stationType = str(ref?.stationType)
  if (stationType === "hq") return str(ref?.society).toUpperCase()
  if (stationType === "official") return str(ref?.official).toUpperCase()
  const configured = normalizeZone(ref?.zone)
  if (configured) return configured
  // Not set up yet: the country file's zone for our own call is right for the
  // great majority of operators and beats exporting an empty exchange.
  return normalizeZone(annotateCallAgainstCountryFile(str(operation.stationCall)).ituZone)
}

/// Whether a QSO's mode counts, given the contest's own restriction. IARU runs
/// mixed by default; the CW-only and phone-only entry categories restrict it.
function modeIsValid(restriction: string, mode: string): boolean {
  const superMode = superModeForMode(mode)
  // Digital never counts, whatever the category.
  if (superMode !== "CW" && superMode !== "PHONE") return false
  if (restriction === "CW") return superMode === "CW"
  if (restriction === "Phone") return superMode === "PHONE"
  return true
}

export const IARUHFScorer: ContestScorer<IARUHFScoresheet> = {
  startScoresheet({ operation, ref }): IARUHFScoresheet {
    const ours = annotateCallAgainstCountryFile(str(operation.stationCall))
    return {
      workedByCall: {},
      mults: {},
      bandMults: {},
      bands: {},
      bandPoints: {},
      qsos: 0,
      points: 0,
      ourContinent: ours.continent,
      // Our zone comes from setup when given, since an operator away from home
      // is exactly who needs to override it.
      ourZone: normalizeZone(ref?.zone) || normalizeZone(ours.ituZone),
    }
  },

  // Mutates and returns the given scoresheet — see ContestScorer.scoreQso.
  scoreQso({ scoresheet, qso, ref }) {
    const base = scoresheet

    const their = (qso.their as Record<string, JSONValue>) ?? {}
    const call = str(their.call)
    if (!call) return { scoresheet: base, score: { value: 0 } }

    const band = str(qso.band)
    const mode = str(qso.mode)

    if (!modeIsValid(str(ref?.modeRestriction), mode)) {
      return { scoresheet: base, score: { value: 0, alerts: ["invalidMode"] } }
    }
    if (!VALID_BANDS.includes(band)) {
      return { scoresheet: base, score: { value: 0, alerts: ["invalidBand"] } }
    }

    // One QSO per station per band PER MODE — working someone on 20m CW does
    // not use up 20m phone.
    const slot = `${band}|${superModeForMode(mode)}`
    const worked = base.workedByCall[call] ?? []
    if (worked.includes(slot)) {
      return { scoresheet: base, score: { value: 0, dupe: true, alerts: ["duplicate"] } }
    }

    // The exchange the operator typed wins; the country file's ITU zone for
    // that call is the fallback, so a QSO logged without an exchange still
    // scores. Note this is a ZONE guess only — nothing can guess an HQ society.
    const contestRef = ((qso.refs as Record<string, JSONValue>[] | undefined) ?? []).find((r) => r?.type === "iaru-hf")
    const theirInfo = annotateCallAgainstCountryFile(call)
    // PRESENCE of the field decides, not truthiness — the core writes
    // `theirExchange: ''` for one the operator deliberately emptied and drops
    // the key when none was entered. Guessing over an explicit blank would
    // score a multiplier the Cabrillo line exports as a dash. Spelled out
    // rather than left to `??`, which happens to do the right thing here only
    // because '' is not nullish.
    const exchange = parseExchange(
      contestRef && "theirExchange" in contestRef
        ? contestRef.theirExchange
        : (their.ituZone ?? (their.guess as Record<string, JSONValue>)?.ituZone ?? theirInfo.ituZone),
    )

    let points = 0
    let mult = ""
    if (exchange.kind === "official") {
      points = 1
      mult = `${band}|${exchange.value}`
    } else if (exchange.kind === "hq") {
      // Namespaced so a society that happens to be called "R1" can never
      // collide with the office of the same name.
      points = 1
      mult = `${band}|HQ:${exchange.value}`
    } else if (exchange.kind === "zone") {
      const theirContinent = str(their.continent) || theirInfo.continent
      if (base.ourZone && base.ourZone === exchange.value) {
        points = 1
      } else if (base.ourContinent && theirContinent && base.ourContinent === theirContinent) {
        points = 3
      } else {
        points = 5
      }
      mult = `${band}|Z${exchange.value}`
    }
    // `kind === 'none'` leaves points at 0 and `mult` empty: nothing was sent
    // and nothing could be guessed, so there is no zone to score against. It
    // still falls through and IS RECORDED — an unscored contact is a contact,
    // and skipping the bookkeeping would leave the station unregistered, so
    // working them again on the same band and mode would read as a fresh QSO
    // instead of the duplicate it is.

    let newMult = false
    if (mult) {
      newMult = base.mults[mult] === undefined
      base.mults[mult] = (base.mults[mult] ?? 0) + 1
      ;(base.bandMults[band] ??= {})[mult] = (base.bandMults[band]?.[mult] ?? 0) + 1
    }

    // Decided BEFORE recording this slot: `worked` aliases the stored array, so
    // pushing first would let the new slot answer the question being asked
    // about it — "is this a new mode?" would always be no.
    const heardBefore = worked.length > 0
    const newBand = heardBefore && !worked.some((s) => s.startsWith(`${band}|`))
    const newMode = heardBefore && !worked.some((s) => s.endsWith(`|${superModeForMode(mode)}`))

    if (heardBefore) base.workedByCall[call].push(slot)
    else base.workedByCall[call] = [slot]

    base.bands[band] = (base.bands[band] ?? 0) + 1
    base.bandPoints[band] = (base.bandPoints[band] ?? 0) + points
    base.qsos += 1
    base.points += points

    const score: QsoScoreVerdict = { value: points, band }
    const notices: string[] = []
    if (newMult) notices.push("newMult")
    // Already worked, but on a different band or in a different mode — which is
    // a fresh contact here, so say which.
    if (newBand) notices.push("newBand")
    if (newMode) notices.push("newMode")
    if (notices.length > 0) score.notices = notices
    if (exchange.kind === "zone") score.zone = exchange.value
    // Counted, but earning nothing until an exchange is entered — say so, or
    // the operator has no way to know a multiplier is going unclaimed.
    if (exchange.kind === "none") score.alerts = ["missingExchange"]

    return { scoresheet: base, score }
  },

  summarizeScore({ scoresheet, ref, scope }, ctx) {
    const t = tFor(ctx)
    const keys = Object.keys(scoresheet.mults)
    const zones = keys.filter((key) => key.includes("|Z")).length
    const hq = keys.filter((key) => key.includes("|HQ:")).length
    // An IARU official (AC, R1, R2, R3) is keyed by its bare office.
    const officials = keys.length - zones - hq
    return contestSummary(
      {
        key: "iaru-hf",
        scope,
        icon: "earth",
        title: contestTitle(ref),
        total: scoresheet.points * keys.length,
        arithmetic: contestArithmetic(
          {
            qsos: scoresheet.qsos,
            points: scoresheet.points,
            mults: keys.length,
            multParts: [
              zones === 1 ? t("zoneOne") : zones > 1 ? t("zoneMany", { formatted: fmtInteger(zones) }) : "",
              hq === 1 ? t("hqOne") : hq > 1 ? t("hqMany", { formatted: fmtInteger(hq) }) : "",
              officials === 1 ? t("officialOne") : officials > 1 ? t("officialMany", { formatted: fmtInteger(officials) }) : "",
            ].filter((part) => part),
          },
          ctx,
        ),
        detail: bandBreakdown(scoresheet),
        extra: { points: scoresheet.points, mults: keys.length, qsos: scoresheet.qsos },
      },
      ctx,
    )
  },
}

/// "IARU HF CW" — the name the operation's title gives the contest, which its
/// summary repeats. A Mixed entry is the contest's default and goes unnamed.
export function contestTitle(ref: Record<string, JSONValue> | undefined): string {
  const restriction = str(ref?.modeRestriction)
  return ["IARU HF", restriction && restriction !== "Mixed" ? restriction : undefined].filter(Boolean).join(" ")
}

/// The per-band table a contester actually reads while operating.
function bandBreakdown(sheet: IARUHFScoresheet): string {
  return VALID_BANDS.map((band) => {
    const qsos = sheet.bands[band] ?? 0
    const points = sheet.bandPoints[band] ?? 0
    const mults = Object.keys(sheet.bandMults[band] ?? {}).length
    return qsos === 0 && mults === 0 ? `**${band}**: —` : `**${band}**: ${fmtInteger(qsos)} QSOs, ${fmtInteger(points)} pts, ${fmtInteger(mults)} mults`
  }).join("\n")
}

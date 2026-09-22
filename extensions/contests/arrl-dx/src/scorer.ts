// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ARRL International DX scoring, ported from app-polo's ARRLDXExtension.
//
// The contest is deliberately asymmetric — W/VE stations work DX and DX works
// W/VE, never each other — and that asymmetry drives everything here:
//   * A W/VE station sends its state or province and receives power.
//   * A DX station sends its power and receives a state or province.
//   * 3 points per QSO, flat.
//   * Multipliers are PER BAND, and are whatever the *other* side sent: DXCC
//     entities if we are W/VE, states and provinces if we are DX.
//   * Only 160/80/40/20/15/10m, and the mode must match the contest's.
//
// "W/VE" means the USA and Canada only. Alaska, Hawaii and the Atlantic islands
// are separate DXCC entities and count as DX — a distinction that decides both
// who we may work and what multiplies.

import { fmtInteger } from "@ham2k/lib-format-tools"
import type { ContestScorer, JSONValue, QsoScoreVerdict, ScoreTally } from "@ham2k/extension-sdk"
import { annotateCallAgainstCountryFile } from "../../../sdk/src/dxcc.ts"

export const VALID_BANDS = ["160m", "80m", "40m", "20m", "15m", "10m"]

/// DXCC codes for Canada (1) and the mainland USA (291). Everything else,
/// Alaska and Hawaii included, is DX for this contest's purposes.
const WVE_DXCC_CODES = [1, 291]

/// Power as sent in ARRL DX: a number from 1 to 1500 W, or one of the
/// conventional abbreviations — `K`/`KW` for a kilowatt, and the CW cut-number
/// forms `NN` (99), `1TT` and `ATT` (both 100), where N=9, T=0 and A=1.
/// Anchored and matched case-insensitively by the core.
export const POWER_PATTERN = "[1-9][0-9]{0,2}|1[0-4][0-9]{2}|1500|K|KW|NN|1TT|ATT"

export function isWveCall(call: string): boolean {
  const dxcc = annotateCallAgainstCountryFile(call).dxccCode
  return dxcc != null && WVE_DXCC_CODES.includes(dxcc)
}

export type ARRLDXScoresheet = {
  /// call → bands already worked with it.
  workedByCall: Record<string, string[]>
  mults: Record<string, number>
  bandMults: Record<string, Record<string, number>>
  bands: Record<string, number>
  qsos: number
  points: number
  dayQsos: number
  dayPoints: number
  /// Whether WE are the W/VE side. Decides who we may work and what multiplies.
  weAreWve: boolean
}

function str(value: JSONValue | undefined): string {
  return typeof value === "string" ? value : ""
}

function modeMatches(contestMode: string, qsoMode: string): boolean {
  if (!contestMode) return true
  // ARRL DX runs a CW weekend and a Phone weekend; "Phone" covers the sideband
  // modes a radio may report.
  if (contestMode === "Phone" || contestMode === "SSB") {
    return qsoMode === "SSB" || qsoMode === "USB" || qsoMode === "LSB"
  }
  return qsoMode === contestMode
}

/// Which side we're on: whatever setup said, else inferred from our own
/// callsign — right for almost everyone, and it keeps a half-configured
/// operation scoring sensibly.
export function weAreWve(operation: Record<string, JSONValue>, ref?: Record<string, JSONValue>): boolean {
  const configured = str(ref?.stationType)
  if (configured === "wve") return true
  if (configured === "dx") return false
  return isWveCall(str(operation.stationCall))
}

export const ARRLDXScorer: ContestScorer<ARRLDXScoresheet> = {
  startScoresheet({ operation, ref }): ARRLDXScoresheet {
    return {
      workedByCall: {},
      mults: {},
      bandMults: {},
      bands: {},
      qsos: 0,
      points: 0,
      dayQsos: 0,
      dayPoints: 0,
      weAreWve: weAreWve(operation, ref),
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
      return { scoresheet: base, score: { value: 0, alerts: ["invalidMode"] } }
    }
    if (!VALID_BANDS.includes(band)) {
      return { scoresheet: base, score: { value: 0, alerts: ["invalidBand"] } }
    }

    // The defining rule: W/VE works DX and DX works W/VE. Working our own side
    // is not a contest QSO at all.
    const theyAreWve = isWveCall(call)
    if (theyAreWve === base.weAreWve) {
      return { scoresheet: base, score: { value: 0, alerts: ["invalidCategory"] } }
    }

    const worked = base.workedByCall[call] ?? []
    if (worked.includes(band)) {
      return { scoresheet: base, score: { value: 0, dupe: true, alerts: ["duplicate"] } }
    }

    // The multiplier is whatever the other side sent: their DXCC entity if we
    // are W/VE, the state or province they gave us if we are DX.
    const contestRef = ((qso.refs as Record<string, JSONValue>[] | undefined) ?? []).find((r) => r?.type === "arrl-dx")
    const exchange = str(contestRef?.theirExchange).toUpperCase().trim()
    const multValue = base.weAreWve ? (annotateCallAgainstCountryFile(call).entityPrefix ?? "") : exchange || str(their.state).toUpperCase()

    const notices: string[] = []
    if (multValue) {
      const mult = `${band}|${multValue}`
      if (base.mults[mult] === undefined) notices.push("newMult")
      base.mults[mult] = (base.mults[mult] ?? 0) + 1
      ;(base.bandMults[band] ??= {})[mult] = (base.bandMults[band]?.[mult] ?? 0) + 1
    }
    if (worked.length > 0) notices.push("newBand")

    if (worked.length > 0) base.workedByCall[call].push(band)
    else base.workedByCall[call] = [band]

    // Flat 3 points — unlike CQ WW, distance and continent don't enter into it.
    const points = 3
    base.bands[band] = (base.bands[band] ?? 0) + 1
    base.qsos += 1
    base.points += points
    base.dayQsos += 1
    base.dayPoints += points

    const score: QsoScoreVerdict = { value: points, band }
    if (notices.length > 0) score.notices = notices
    return { scoresheet: base, score }
  },

  summarizeScore({ scoresheet, scope }): Record<string, ScoreTally> {
    const isDay = scope === "day"
    const multCount = Object.keys(scoresheet.mults).length
    const points = isDay ? scoresheet.dayPoints : scoresheet.points

    return {
      arrlDx: {
        key: "arrlDx",
        for: scope,
        icon: "flag-variant",
        total: points * multCount,
        points,
        mults: multCount,
        qsos: isDay ? scoresheet.dayQsos : scoresheet.qsos,
        label: `${fmtInteger(points)} × ${fmtInteger(multCount)}`,
        summary: fmtInteger(points * multCount),
        longSummary: VALID_BANDS.map((band) => {
          const qsos = scoresheet.bands[band] ?? 0
          const mults = Object.keys(scoresheet.bandMults[band] ?? {}).length
          return qsos === 0 && mults === 0 ? `**${band}**: —` : `**${band}**: ${fmtInteger(qsos)} QSOs, ${fmtInteger(mults)} mults`
        }).join("\n"),
      },
    }
  },
}

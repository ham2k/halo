// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The named ARRL VHF+ contest instances, ported from app-polo's
// `arrl-vhf-tests/all-events.js`. Three distinct scoring shapes share this one
// extension (§5.6 of docs/design/contests.md keeps a sponsor's contest family
// as one extension, never one per named event):
//   - `points`: a fixed value per band, no distance involved (the January/
//     June/September VHF contests).
//   - `distance`: `round(km) * multipliers[band]`, no flat QSO points.
//   - `distanceAndPoints`: the same distance formula plus a flat `points.qso`
//     bonus per contact (the 10 GHz+ events).
// `gridChars` is 4 for the HF/VHF-adjacent events and 6 for the microwave
// ones, matching each sponsor's own precision requirement — not a house
// default.

import { EHF_BANDS, SHF_BANDS, UHF_BANDS, VHF_BANDS } from "@ham2k/lib-operation-data"

export type VhfScoreKind = "points" | "distance" | "distanceAndPoints"

export interface VhfEvent {
  key: string
  name: string
  short: string
  /// Cabrillo's CONTEST tag, when it differs from `key` (the 10 GHz events
  /// share one tag across their August/September instances).
  cabrilloName?: string
  bands: string[]
  gridChars: 4 | 6
  score: VhfScoreKind
  /// `points`/`distanceAndPoints`: flat points per band or per QSO.
  points?: Record<string, number> & { qso?: number }
  /// `distance`/`distanceAndPoints`: per-band multiplier on the rounded
  /// great-circle km.
  multipliers?: Record<string, number>
  rules: string
}

const EVENTS: VhfEvent[] = [
  {
    key: "ARRL-VHF-JAN",
    name: "ARRL VHF January",
    short: "VHF Jan",
    bands: [...VHF_BANDS, ...UHF_BANDS, ...SHF_BANDS, ...EHF_BANDS],
    gridChars: 4,
    score: "points",
    points: {
      "6m": 1,
      "5m": 1,
      "4m": 1,
      "2m": 1,
      "1.25m": 2,
      "70cm": 2,
      "33cm": 4,
      "23cm": 4,
      "13cm": 8,
      "9cm": 8,
      "6cm": 8,
      "3cm": 8,
      "1.25cm": 8,
      "6mm": 8,
      "4mm": 8,
      "2mm": 8,
      "2.5mm": 8,
      "1mm": 8,
      submm: 4,
    },
    rules: "https://contests.arrl.org/ContestRules/JanJunSep-VHF-Rules.pdf",
  },
  {
    key: "ARRL-VHF-JUN",
    name: "ARRL VHF June",
    short: "VHF Jun",
    bands: [...VHF_BANDS, ...UHF_BANDS, ...SHF_BANDS, ...EHF_BANDS],
    gridChars: 4,
    score: "points",
    points: {
      "6m": 1,
      "5m": 1,
      "4m": 1,
      "2m": 1,
      "1.25m": 2,
      "70cm": 2,
      "33cm": 3,
      "23cm": 3,
      "13cm": 4,
      "9cm": 4,
      "6cm": 4,
      "3cm": 4,
      "1.25cm": 4,
      "6mm": 4,
      "4mm": 4,
      "2mm": 4,
      "2.5mm": 4,
      "1mm": 4,
      submm: 4,
    },
    rules: "https://contests.arrl.org/ContestRules/JanJunSep-VHF-Rules.pdf",
  },
  {
    key: "ARRL-VHF-SEP",
    name: "ARRL VHF September",
    short: "ARRL VHF Sep",
    bands: [...VHF_BANDS, ...UHF_BANDS, ...SHF_BANDS, ...EHF_BANDS],
    gridChars: 4,
    score: "points",
    points: {
      "6m": 1,
      "5m": 1,
      "4m": 1,
      "2m": 1,
      "1.25m": 2,
      "70cm": 2,
      "33cm": 3,
      "23cm": 3,
      "13cm": 4,
      "9cm": 4,
      "6cm": 4,
      "3cm": 4,
      "1.25cm": 4,
      "6mm": 4,
      "4mm": 4,
      "2mm": 4,
      "2.5mm": 4,
      "1mm": 4,
      submm: 4,
    },
    rules: "https://contests.arrl.org/ContestRules/JanJunSep-VHF-Rules.pdf",
  },
  {
    key: "ARRL-222",
    name: "ARRL 222 MHz and Up",
    short: "ARRL 222",
    bands: ["1.25m", ...UHF_BANDS, ...SHF_BANDS, ...EHF_BANDS],
    gridChars: 6,
    score: "distance",
    multipliers: {
      "1.25m": 2,
      "70cm": 1,
      "33cm": 4,
      "23cm": 2,
      "13cm": 6,
      "9cm": 10,
      "6cm": 10,
      "3cm": 6,
      "1.25cm": 20,
      "6mm": 20,
      "4mm": 20,
      "2mm": 20,
      "2.5mm": 20,
      "1mm": 20,
      submm: 20,
    },
    rules: "https://contests.arrl.org/ContestRules/222-MHz-Rules.pdf",
  },
  {
    key: "ARRL-10G-AUG",
    name: "ARRL 10 GHz and Up - August",
    cabrilloName: "ARRL-10-GHZ",
    short: "ARRL 10G Aug",
    bands: ["3cm", "1.25cm", ...EHF_BANDS],
    gridChars: 6,
    score: "distanceAndPoints",
    points: { qso: 100 },
    multipliers: { "3cm": 1, "1.25cm": 2, "6mm": 3, "4mm": 4, "2mm": 5, "2.5mm": 5, "1mm": 5, submm: 5 },
    rules: "https://contests.arrl.org/ContestRules/10-GHz-Rules.pdf",
  },
  {
    key: "ARRL-10G-SEP",
    name: "ARRL 10 GHz and Up - September",
    cabrilloName: "ARRL-10-GHZ",
    short: "ARRL 10G Sep",
    bands: ["3cm", "1.25cm", ...EHF_BANDS],
    gridChars: 6,
    score: "distanceAndPoints",
    points: { qso: 100 },
    multipliers: { "3cm": 1, "1.25cm": 2, "6mm": 3, "4mm": 4, "2mm": 5, "2.5mm": 5, "1mm": 5, submm: 5 },
    rules: "https://contests.arrl.org/ContestRules/10-GHz-Rules.pdf",
  },
]

const EVENTS_BY_KEY: Record<string, VhfEvent> = Object.fromEntries(EVENTS.map((e) => [e.key, e]))

export function eventFor(key: string | undefined | null): VhfEvent | undefined {
  return key ? EVENTS_BY_KEY[key] : undefined
}

export { EVENTS }

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// NAQP's location exchange: the 50 US states, the 13 Canadian provinces and
// territories, the North American DXCC entities, and `DX` for everyone else.
//
// INLINE, not a shared dataset. docs/design/contests.md §5.3's own table places
// "NAQP locations (111)" here rather than in `operation-data`, and §5.3's M4
// amendment says why that is the right call generally: `ContestScorer` is
// synchronous, so a scorer could never await a cross-extension lookup anyway.
// The whole set is 110 unique codes and well under a kilobyte, read in exactly
// two places, both inside this bundle.

/// The 50 US states. Territories are NOT states here — KP2/KP4/KH6-style
/// entities appear under the DXCC list below, which is how NAQP counts them.
const US_STATES = [
  "AK",
  "AL",
  "AR",
  "AZ",
  "CA",
  "CO",
  "CT",
  "DE",
  "FL",
  "GA",
  "HI",
  "IA",
  "ID",
  "IL",
  "IN",
  "KS",
  "KY",
  "LA",
  "MA",
  "MD",
  "ME",
  "MI",
  "MN",
  "MO",
  "MS",
  "MT",
  "NC",
  "ND",
  "NE",
  "NH",
  "NJ",
  "NM",
  "NV",
  "NY",
  "OH",
  "OK",
  "OR",
  "PA",
  "RI",
  "SC",
  "SD",
  "TN",
  "TX",
  "UT",
  "VA",
  "VT",
  "WA",
  "WI",
  "WV",
  "WY",
]

/// Washington DC is NOT a state, and IS a multiplier — NAQP's rules name it
/// alongside the fifty. Missing it costs a real multiplier AND tells an
/// operator working a DC
/// station that a perfectly good exchange was wrong. §5.3's dataset table says
/// 111 locations; the fifty states alone give 110, and this is the one missing.
const DISTRICT_OF_COLUMBIA = ["DC"]

/// Canadian provinces and territories.
const CANADIAN_PROVINCES = ["AB", "BC", "MB", "NB", "NL", "NS", "NT", "NU", "ON", "PE", "QC", "SK", "YT"]

/// North American DXCC entities, sent as the entity prefix. Note `HI`: it is
/// both Hawaii and the Dominican Republic, which is why this is a SET of codes
/// and not a map to anything — one code, and the operator's own log knows which
/// station it was.
const NORTH_AMERICAN_ENTITIES = [
  "4U1U",
  "6Y",
  "8P",
  "C6",
  "CM",
  "CY0",
  "CY9",
  "FG",
  "FJ",
  "FM",
  "FO",
  "FP",
  "FS",
  "HH",
  "HI",
  "HK0",
  "HP",
  "HR",
  "J3",
  "J6",
  "J7",
  "J8",
  "KG4",
  "KP1",
  "KP2",
  "KP4",
  "KP5",
  "OX",
  "PJ5",
  "PJ7",
  "TG",
  "TI",
  "TI9",
  "V2",
  "V3",
  "V4",
  "VP2E",
  "VP2M",
  "VP2V",
  "VP5",
  "VP9",
  "XE",
  "XF4",
  "YN",
  "YS",
  "YV0",
  "ZF",
]

/// Everything the location field accepts, `DX` included.
export const VALID_LOCATIONS = new Set<string>(["DX", ...US_STATES, ...DISTRICT_OF_COLUMBIA, ...CANADIAN_PROVINCES, ...NORTH_AMERICAN_ENTITIES])

/// Which kind of place a multiplier location names — the summary counts the
/// three apart. `HI` reads as the state: the code alone cannot say which.
export function locationKind(location: string): "state" | "province" | "country" {
  if (US_STATES.includes(location) || DISTRICT_OF_COLUMBIA.includes(location)) return "state"
  if (CANADIAN_PROVINCES.includes(location)) return "province"
  return "country"
}

/// Whether a location counts as a MULTIPLIER. `DX` is a valid exchange and a
/// valid QSO — it just isn't a multiplier, because it names no one place.
export function isMultiplier(location: string): boolean {
  return location !== "DX" && VALID_LOCATIONS.has(location)
}

/// The field accepts letters and digits, 1-4 characters — `4U1U` is the longest
/// and `DX` the shortest. Validity against the real set is checked separately,
/// since a pattern that spelled out 110 alternatives would be unreadable and
/// would still need the set for scoring.
export const LOCATION_PATTERN = "[A-Za-z0-9]{1,4}"

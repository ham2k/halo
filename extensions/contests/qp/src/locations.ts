// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The states and provinces a QSO party's out-of-area contacts come from, with
// their names — an unknown county is only recognizable as a state if we have
// the list, and the operation summary prints both tables in full so an
// operator can see what is still missing.
//
// INLINE, not a shared dataset, following §5.3's M4 amendment and `naqp`'s
// `locations.ts`: `ContestScorer` is synchronous, so a scorer could never
// await a cross-extension lookup, and the two tables together are under a
// kilobyte. Copied from app-polo's `src/data/usStates.json` and
// `canadianProvinces.json`, upper-cased once here rather than on every read.
//
// Washington DC is deliberately NOT in `US_STATES`. Whether it is its own
// multiplier or scores as Maryland is a per-party rule
// (`options.dcCountsAsMaryland`), so the party decides, not this table.

/// The fifty states, by their postal abbreviations.
export const US_STATES: Record<string, string> = {
  AK: "Alaska",
  AL: "Alabama",
  AR: "Arkansas",
  AZ: "Arizona",
  CA: "California",
  CO: "Colorado",
  CT: "Connecticut",
  DE: "Delaware",
  FL: "Florida",
  GA: "Georgia",
  HI: "Hawaii",
  IA: "Iowa",
  ID: "Idaho",
  IL: "Illinois",
  IN: "Indiana",
  KS: "Kansas",
  KY: "Kentucky",
  LA: "Louisiana",
  MA: "Massachusetts",
  MD: "Maryland",
  ME: "Maine",
  MI: "Michigan",
  MN: "Minnesota",
  MO: "Missouri",
  MS: "Mississippi",
  MT: "Montana",
  NC: "North Carolina",
  ND: "North Dakota",
  NE: "Nebraska",
  NH: "New Hampshire",
  NJ: "New Jersey",
  NM: "New Mexico",
  NV: "Nevada",
  NY: "New York",
  OH: "Ohio",
  OK: "Oklahoma",
  OR: "Oregon",
  PA: "Pennsylvania",
  RI: "Rhode Island",
  SC: "South Carolina",
  SD: "South Dakota",
  TN: "Tennessee",
  TX: "Texas",
  UT: "Utah",
  VA: "Virginia",
  VT: "Vermont",
  WA: "Washington",
  WI: "Wisconsin",
  WV: "West Virginia",
  WY: "Wyoming",
}

/// The thirteen provinces and territories.
export const CANADIAN_PROVINCES: Record<string, string> = {
  AB: "Alberta",
  BC: "British Columbia",
  MB: "Manitoba",
  NB: "New Brunswick",
  NL: "Newfoundland and Labrador",
  NS: "Nova Scotia",
  NT: "Northwest Territories",
  NU: "Nunavut",
  ON: "Ontario",
  PE: "Prince Edward Island",
  QC: "Quebec",
  SK: "Saskatchewan",
  YT: "Yukon",
}

/// The name Washington DC is shown under when a party counts it as its own
/// multiplier.
export const DISTRICT_OF_COLUMBIA = 'District of Columbia'

/// The label a party that folds DC into Maryland uses for both codes, so the
/// operator sees the same thing whichever one the other station sent.
export const MARYLAND_AND_DC = 'Maryland & DC'

export function isUsState(code: string): boolean {
  return US_STATES[code.toUpperCase()] !== undefined
}

export function isCanadianProvince(code: string): boolean {
  return CANADIAN_PROVINCES[code.toUpperCase()] !== undefined
}

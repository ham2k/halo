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

/// The ARRL sections, by the abbreviations a sponsor's log checker accepts. For
/// a party whose out-of-party exchange is the SECTION (`sectionsForOutOfState`)
/// this table stands where `US_STATES` does, and nothing maps between the two:
/// `CT` is valid there because it is a section, `CA` is not because it is not.
export const US_SECTIONS: Record<string, string> = {
  AK: "Alaska",
  AL: "Alabama",
  AR: "Arkansas",
  AZ: "Arizona",
  CO: "Colorado",
  CT: "Connecticut",
  DE: "Delaware",
  EB: "East Bay",
  EMA: "Eastern Massachusetts",
  ENY: "Eastern New York",
  EPA: "Eastern Pennsylvania",
  EWA: "Eastern Washington",
  GA: "Georgia",
  IA: "Iowa",
  ID: "Idaho",
  IL: "Illinois",
  IN: "Indiana",
  KS: "Kansas",
  KY: "Kentucky",
  LA: "Louisiana",
  LAX: "Los Angeles",
  MDC: "Maryland-DC",
  ME: "Maine",
  MI: "Michigan",
  MN: "Minnesota",
  MO: "Missouri",
  MS: "Mississippi",
  MT: "Montana",
  NC: "North Carolina",
  ND: "North Dakota",
  NE: "Nebraska",
  NFL: "Northern Florida",
  NH: "New Hampshire",
  NLI: "New York City-Long Island",
  NM: "New Mexico",
  NNJ: "Northern New Jersey",
  NNY: "Northern New York",
  NTX: "North Texas",
  NV: "Nevada",
  OH: "Ohio",
  OK: "Oklahoma",
  OR: "Oregon",
  ORG: "Orange",
  PAC: "Pacific",
  PR: "Puerto Rico",
  RI: "Rhode Island",
  SB: "Santa Barbara",
  SC: "South Carolina",
  SCV: "Santa Clara Valley",
  SD: "South Dakota",
  SDG: "San Diego",
  SF: "San Francisco",
  SFL: "Southern Florida",
  SJV: "San Joaquin Valley",
  SNJ: "Southern New Jersey",
  STX: "South Texas",
  SV: "Sacramento Valley",
  TN: "Tennessee",
  UT: "Utah",
  VA: "Virginia",
  VI: "US Virgin Islands",
  VT: "Vermont",
  WCF: "West Central Florida",
  WI: "Wisconsin",
  WMA: "Western Massachusetts",
  WNY: "Western New York",
  WPA: "Western Pennsylvania",
  WTX: "West Texas",
  WV: "West Virginia",
  WWA: "Western Washington",
  WY: "Wyoming",
}

/// The RAC sections, as the PA QSO Party publishes them.
///
/// Fourteen, and `YT` is deliberately not among them: the sponsor's rules
/// §16.a name "the 14 Canadian Sections" and list Yukon inside `TER`, and
/// their own section sheet agrees. A `VY1` station sending `YT` is therefore
/// an exchange this party does not accept, and reading it as `TER` would put
/// a code in the submitted file that nobody sent. `fd` carries the same
/// omission for Field Day's own rules; both are the sponsor's call, not ours,
/// so a party whose sponsor adopts RAC's current list needs its own table
/// rather than an edit to this one.
export const CANADIAN_SECTIONS: Record<string, string> = {
  AB: "Alberta",
  BC: "British Columbia",
  GH: "Ontario Golden Horseshoe",
  MB: "Manitoba",
  NB: "New Brunswick",
  NL: "Newfoundland and Labrador",
  NS: "Nova Scotia",
  ONE: "Ontario East",
  ONN: "Ontario North",
  ONS: "Ontario South",
  PE: "Prince Edward Island",
  QC: "Quebec",
  SK: "Saskatchewan",
  TER: "Territories",
}

/// The state a section lies in, where the two are not the same code — the
/// question "is this section inside the party?" and nothing else, so a section
/// whose abbreviation IS its state's (`CT`, `ME`, `OH`) is deliberately absent
/// and answered by the code itself.
///
/// `PR` and `VI` are their own sections in no state at all, and `TER` spans
/// three territories; all three are left out, since no party's own ground is
/// any of them and a single answer would be a wrong one.
export const STATE_FOR_SECTION: Record<string, string> = {
  EB: "CA",
  EMA: "MA",
  ENY: "NY",
  EPA: "PA",
  EWA: "WA",
  GH: "ON",
  LAX: "CA",
  MDC: "MD",
  NFL: "FL",
  NLI: "NY",
  NNJ: "NJ",
  NNY: "NY",
  NTX: "TX",
  ONE: "ON",
  ONN: "ON",
  ONS: "ON",
  ORG: "CA",
  PAC: "HI",
  SB: "CA",
  SCV: "CA",
  SDG: "CA",
  SF: "CA",
  SFL: "FL",
  SJV: "CA",
  SNJ: "NJ",
  STX: "TX",
  SV: "CA",
  WCF: "FL",
  WMA: "MA",
  WNY: "NY",
  WPA: "PA",
  WTX: "TX",
  WWA: "WA",
}

/// The name Washington DC is shown under when a party counts it as its own
/// multiplier.
export const DISTRICT_OF_COLUMBIA = "District of Columbia"

/// The label a party that folds DC into Maryland uses for both codes, so the
/// operator sees the same thing whichever one the other station sent.
export const MARYLAND_AND_DC = "Maryland & DC"

export function isUsState(code: string): boolean {
  return US_STATES[code.toUpperCase()] !== undefined
}

export function isCanadianProvince(code: string): boolean {
  return CANADIAN_PROVINCES[code.toUpperCase()] !== undefined
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a QSO party exchange MEANS: turning `ORDES/JEF`, `MD`, `DC` or an empty
// field into the locations a contact is scored and submitted under.
//
// One module, read by the scorer, the entry row, the ADIF and the Cabrillo, for
// the reason `stateparks/parks.ts` gives: the location scored has to be the
// location submitted, and when a scorer and a Cabrillo writer resolve the same
// exchange separately they drift apart exactly where the rules are subtle.
//
// Two fixes to app-polo's resolution, both §8 fix-on-port, both invisible until
// you look for them:
//
//   * polo maps `DC` to `MD` **and** `MD` to `DC` under
//     `dcCountsAsMaryland` (`QSOPartiesExtension.js`, `qpNormalizeLocation`),
//     so the two swap places instead of merging: a Maryland station and a DC
//     station hand a 42-party majority two multipliers for what the rules call
//     one. Both resolve to `MD` here.
//   * polo caps DX-entity multipliers by comparing `scoring.entities?.length`
//     against `dxEntityMultiplierMax` — `scoring.entities` is never an array,
//     so the comparison is `undefined < 10`, false, and the else branch drops
//     the multiplier entirely. The four parties that publish a cap (7QP, IL,
//     NH, WA) therefore award NO DX multipliers at all there. The cap is
//     counted properly in the scoresheet here (`scorer.ts`), so it limits
//     rather than erases.

import type { JSONValue } from "@ham2k/extension-sdk"

import { entityPrefixForCall } from "../../../sdk/src/dxcc.ts"

import { CANADIAN_PROVINCES, CANADIAN_SECTIONS, DISTRICT_OF_COLUMBIA, MARYLAND_AND_DC, STATE_FOR_SECTION, US_SECTIONS, US_STATES } from "./locations.ts"
import { isInParty, partyStates, type QsoParty, stateForCounty } from "./parties.ts"

function str(value: unknown): string {
  return typeof value === "string" ? value : ""
}

/// A single resolved location — one side of a contact may have two of these
/// when it is on a county line.
export interface PartyLocation {
  /// The code as SCORED: a county abbreviation, a state, a province, or `DX`.
  code: string
  /// The key this location adds to the multiplier set, before the per-band or
  /// per-mode prefix. Usually the code itself; a state where a party counts
  /// states rather than counties, and `DX:<prefix>` where each DX entity
  /// multiplies separately.
  multCode: string
  /// What to call it in a notice or a summary — the county's full name, the
  /// state's, or the DX entity's prefix.
  name: string
  /// Whether this is one of the party's OWN counties. "In state" for a party
  /// spanning seven states or three provinces still means "inside the party".
  inParty: boolean
  /// What a submitted file writes for this location, which is not always what
  /// it scores as: thirteen parties set `dxLocationIsPrefix`, meaning a DX
  /// station is logged by its entity prefix while still scoring as the single
  /// `DX` multiplier. Without the distinction the option was inert — every
  /// prefix resolved to `DX` and the Cabrillo wrote that, while the ADIF wrote
  /// the prefix, so the two files disagreed and the option changed nothing.
  sent: string
}

/// Both sides' in/out-of-party standing, which several rules turn on. Passed
/// together because resolving one side needs the other's answer.
export interface Standing {
  weAreInParty: boolean
  theyAreInParty: boolean
}

/// The entities outside the lower 48 whose stations are still a US STATE, by
/// their COUNTRY-FILE prefix — which is not always what a ham would write.
/// Alaska is `KL`, and polo's `KL7` therefore never matched, so an Alaskan
/// station whose exchange we could not read was scored as DX rather than as the
/// state multiplier it is. `naqp/exchange.ts` documents the same correction
/// against the same bundled country file; `KL7` is kept alongside it because a
/// synced or imported record may carry what polo wrote.
const STATE_ENTITIES: Record<string, string> = { KL: "AK", KL7: "AK", KH6: "HI" }

/// The same question where the exchange is a SECTION: more entities answer it,
/// because Puerto Rico, the Virgin Islands and the Pacific possessions are ARRL
/// sections and no state at all. Without them a `KP4` whose exchange went
/// untyped claims the DX multiplier, for a station the sponsor scores as `PR`.
const SECTION_ENTITIES: Record<string, string> = {
  KL: "AK",
  KL7: "AK",
  KH0: "PAC",
  KH1: "PAC",
  KH2: "PAC",
  KH3: "PAC",
  KH4: "PAC",
  KH5: "PAC",
  KH6: "PAC",
  KH7: "PAC",
  KH8: "PAC",
  KH9: "PAC",
  KP4: "PR",
  KP2: "VI",
}

/// The two tables an out-of-party US or Canadian exchange is read against —
/// states and provinces, or sections where the party asks for those. Every
/// reader goes through this, so the field, the scorer, the summary and the
/// file cannot disagree about which vocabulary a party speaks.
export function outOfPartyTables(party: QsoParty): { us: Record<string, string>; canada: Record<string, string> } {
  return party.options.sectionsForOutOfState ? { us: US_SECTIONS, canada: CANADIAN_SECTIONS } : { us: US_STATES, canada: CANADIAN_PROVINCES }
}

const OUR_OWN_CODES = new WeakMap<QsoParty, Set<string>>()

/// Every code in the party's out-of-party vocabulary that lies INSIDE the
/// party. Nobody sends one: in the party the exchange is a county, and outside
/// it nobody is in those states to begin with.
///
/// `partyStates` alone answers this where the vocabulary is states — the set
/// `exchangeOptionsFor` has always filtered by — but a SECTION lies in a state
/// without sharing its code, so PAQP's own `EPA` and `WPA` slip through it.
/// Both are read here, and every reader asks this rather than `partyStates`.
///
/// Memoized: `normalizeLocation` asks on every location of every QSO, live on
/// each keystroke and again on a rescore, and the answer is a property of the
/// party.
export function ourOwnCodes(party: QsoParty): Set<string> {
  const cached = OUR_OWN_CODES.get(party)
  if (cached) return cached
  const ours = partyStates(party)
  const tables = outOfPartyTables(party)
  const codes = new Set<string>()
  for (const code of [...Object.keys(tables.us), ...Object.keys(tables.canada)]) {
    if (ours.has(STATE_FOR_SECTION[code] ?? code)) codes.add(code)
  }
  OUR_OWN_CODES.set(party, codes)
  return codes
}

/// The separators a county line may be typed with. A comma is accepted because
/// the operator may well reach for one; the canonical form written back out is
/// the slash, which is what the sponsors' Cabrillo samples use.
const SEPARATORS = /[/,]/

export const COUNTY_LINE_SEPARATOR = "/"

/// `ORDES/ORJEF` → `['ORDES', 'ORJEF']`, and 7QP's shorthand `ORDES/JEF` with
/// it: where the first code carries a state prefix, a later short code inherits
/// it. polo's rule verbatim, and the reason it is length-based rather than
/// party-based is that only the multi-state parties have codes long enough for
/// the shorthand to be unambiguous.
export function splitLocations(text: string | undefined): string[] {
  const codes = (text ?? "")
    .split(SEPARATORS)
    .map((code) => code.trim().toUpperCase())
    .filter((code) => code)
  if (codes.length > 1 && codes[0].length > 4) {
    const state = codes[0].slice(0, 2)
    return codes.map((code) => (code.length < 4 ? state + code : code))
  }
  return codes
}

/// Everything about the other station that a location depends on: the entity
/// they are in, which decides what a location we don't recognize resolves to.
export function entityPrefixOf(qso: Record<string, unknown> | undefined): string {
  const their = (qso?.their ?? {}) as Record<string, unknown>
  const guess = (their.guess ?? {}) as Record<string, unknown>
  // `||`, not `??`: the core writes an EMPTY STRING for a field that is present
  // and unanswered, and `??` would take that as an answer and never consult the
  // lookup's guess. Every other contest spells it this way.
  const prefix = str(their.entityPrefix) || str(guess.entityPrefix)
  if (prefix) return prefix.toUpperCase()
  // Falls back to the country file, as `naqp` and `arrl-dx` do. A QSO that came
  // in through an ADIF import or a sync carries no `guess` at all, and without
  // this a DX station whose exchange was never typed resolves to NOTHING —
  // scored `missingExchange` at zero, with no DX multiplier in the twenty
  // parties that count them, and an Alaskan station never reaching `AK`.
  const call = typeof their.call === "string" ? their.call : ""
  return call ? (entityPrefixForCall(call) ?? "").toUpperCase() : ""
}

/// The state the other station is in, as looked up rather than sent — the
/// fallback an ADIF or a Cabrillo needs when the exchange was never typed.
export function guessedStateOf(qso: Record<string, unknown> | undefined): string {
  const their = (qso?.their ?? {}) as Record<string, unknown>
  const guess = (their.guess ?? {}) as Record<string, unknown>
  // `||` for the reason `entityPrefixOf` gives: an empty `their.state` is the
  // absence of an answer, and taking it as one left `preferredCodesFor` with
  // nothing to rank by — the caller's likely counties silently stopped floating
  // to the top of the suggestion line, with no other symptom.
  return (str(their.state) || str(guess.state)).trim().toUpperCase()
}

/// One code, resolved to what it is worth — or `''` when it is worth nothing,
/// which is how an unrecognizable exchange from a station in no known entity
/// stays out of the score.
///
/// Takes no `standing`: which side each end is on decides what a location
/// MULTIPLIES (`multCodeFor`), never what it resolves to — a county stays the
/// county that was sent, in the log, the checklist and the Cabrillo alike.
export function normalizeLocation(
  party: QsoParty,
  code: string,
  { entityPrefix = "", received = false }: { entityPrefix?: string; received?: boolean } = {},
): string {
  let location = code.trim().toUpperCase()
  if (!location) return ""

  // A county is a county. Where a party does not count counties as in-party
  // multipliers it is the MULTIPLIER that becomes the state (`multCodeFor`) —
  // the code stays what was sent, so the log, the county checklist and the
  // Cabrillo all still say which county it was. polo converts the code itself
  // for one of the two options that spell this rule and only the multiplier
  // for the other, which is how the same rule ends up with two behaviours.
  if (isInParty(party, location)) return location

  // A code we don't know that is long enough to be a county carries its state
  // in its first two characters — a neighbouring party's county, or a typo.
  if (location.length > 4) location = location.slice(0, 2)

  // A code inside the party is answered with a county and never with itself
  // (`ourOwnCodes`), so one arriving as an EXCHANGE is a mis-copy and resolves
  // to nothing — reported as a bad exchange, with the QSO still in front of the
  // operator to fix. Taking it would claim a multiplier the sponsor's own
  // checker strikes, and write it into the submitted file.
  //
  // Only what was COPIED: our own location is a setup field, and an entrant who
  // typed their state where their county belongs is answered by the scorer's
  // own `ourLocation` alert rather than by having every contact refused.
  if (received && ourOwnCodes(party).has(location)) return ""

  if (party.options.sectionsForOutOfState) {
    // Strict, and deliberately so: a state is accepted only where a section
    // shares its abbreviation. Guessing `CA` into one of nine sections would
    // write a multiplier into the file that nobody sent.
    if (US_SECTIONS[location] || CANADIAN_SECTIONS[location]) return location
  } else {
    if (location === "DC" || location === "MD") {
      return party.options.dcCountsAsMaryland ? "MD" : location
    }
    if (US_STATES[location]) {
      if (party.options.alaskaAndHawaiiAreDX && (location === "AK" || location === "HI")) return "DX"
      return location
    }
    if (CANADIAN_PROVINCES[location]) return location
  }

  // Nothing we recognize. A station in the party's OWN country sends a county,
  // a state or a section, so an unrecognized value from one is a TYPO and
  // resolves to nothing — which the scorer reports as a bad exchange, with the
  // QSO still in front of the operator to fix. polo answers `DX` here, which
  // scores the contact, claims a `DX:K` multiplier in the twenty parties that
  // count entities separately, and lists "K" among the DX entities worked.
  //
  // Alaska, Hawaii and the Pacific possessions are in that country too, though
  // they do not sign `K`. What they send is read like anyone else's, and a code
  // that is not one of those is their typo — no more the state their PREFIX
  // names than `ZZZ` from a Californian is California. Answering with that
  // state would make a multiplier out of a mis-hearing, and silently: the
  // score rises and nothing is flagged. The entry row offers these stations
  // the same list as any other US station and tints what is not on it
  // (`exchangeOptionsFor`), so there is nothing for a guess to rescue. Where a
  // station SENT nothing at all, the prefix is still the best answer there is,
  // and `defaultTheirLocation` gives it.
  //
  // Unless the party counts them as DX, in which case they fall through to it.
  if (entityPrefix === "K" || entityPrefix === "VE") return ""
  if (!party.options.alaskaAndHawaiiAreDX && stateForEntity(party, entityPrefix)) return ""
  return entityPrefix ? "DX" : ""
}

/// The multiplier key a resolved location contributes.
function multCodeFor(party: QsoParty, code: string, entityPrefix: string, standing?: Standing): string {
  // Inside the party, some sponsors multiply by STATE rather than by county:
  // NEQP writes `countiesAreMultForInState: false`, while ACQP, CPQP and DEQP
  // write `countiesCountForInState: false` — polo's own NOTES gives the two
  // options the same description, so they are one rule under two spellings.
  const countiesMultiplyInParty = party.options.countiesAreMultForInState && party.options.countiesCountForInState
  if (!countiesMultiplyInParty && standing?.weAreInParty && standing?.theyAreInParty && isInParty(party, code)) {
    return stateForCounty(party, code)
  }
  if (code === "DX" && party.options.dxEntityIsMultiplier) return `DX:${entityPrefix}`
  return code
}

/// What to call a location out loud.
export function nameForLocation(party: QsoParty, code: string, entityPrefix = ""): string {
  const location = code.toUpperCase()
  const county = party.counties[location] ?? party.otherCounties[location]
  if (county) return county
  if (party.options.sectionsForOutOfState) {
    const section = US_SECTIONS[location] ?? CANADIAN_SECTIONS[location]
    if (section) return section
  }
  if (location === "DC") return party.options.dcCountsAsMaryland ? MARYLAND_AND_DC : DISTRICT_OF_COLUMBIA
  if (location === "MD") return party.options.dcCountsAsMaryland ? MARYLAND_AND_DC : US_STATES.MD
  if (US_STATES[location]) return US_STATES[location]
  if (CANADIAN_PROVINCES[location]) return CANADIAN_PROVINCES[location]
  if (location === "DX") return party.options.dxEntityIsMultiplier && entityPrefix ? `DX: ${entityPrefix}` : "DX"
  return location
}

/// A whole exchange — one location, or a county line's two — resolved.
export function parseLocations(
  party: QsoParty,
  text: string | undefined,
  {
    entityPrefix = "",
    standing,
    received = false,
  }: {
    entityPrefix?: string
    standing?: Standing
    received?: boolean
  } = {},
): PartyLocation[] {
  const seen = new Set<string>()
  const locations: PartyLocation[] = []
  for (const raw of splitLocations(text)) {
    const code = normalizeLocation(party, raw, { entityPrefix, received })
    if (!code || seen.has(code)) continue
    seen.add(code)
    locations.push({
      code,
      multCode: multCodeFor(party, code, entityPrefix, standing),
      name: nameForLocation(party, code, entityPrefix),
      inParty: isInParty(party, code),
      sent: code === "DX" && party.options.dxLocationIsPrefix && entityPrefix ? entityPrefix : code,
    })
  }
  return locations
}

/// OUR location, from setup — `parseLocations`, plus `DX` whatever the party
/// counts. A station outside the US and Canada has no county, state or
/// province to give, and every party accepts entries from them; without this
/// `DX` resolves to nothing (we have no entity prefix of our own to hand
/// `normalizeLocation`), and the whole log scores zero under an `ourLocation`
/// alert.
export function parseOurLocations(party: QsoParty, text: string | undefined): PartyLocation[] {
  const locations = parseLocations(party, text)
  if (splitLocations(text).includes("DX") && !locations.some((location) => location.code === "DX")) {
    locations.push({ code: "DX", multCode: "DX", name: nameForLocation(party, "DX"), inParty: false, sent: "DX" })
  }
  return locations
}

/// What a station who sent us no exchange is recorded as — the ONE answer the
/// scorer and both exports read, so a contact cannot be scored under one
/// location and filed under another.
///
/// In the party's own country, what the lookup says: `their.state` if the
/// operator or an import asserted one, else the callsign lookup's guess. It is
/// consulted only here, where the alternative is `missingExchange` and a
/// contact worth nothing — the entry row still asks the operator for the
/// exchange, and still ranks counties rather than inventing one, because a
/// county is the thing a lookup cannot know.
///
/// The guess is refused unless it RESOLVES against this party, and consulted
/// only for a K or VE station: a DX lookup's `state` is its own country's
/// subdivision, and two-letter codes collide — a German `NS` is not Nova
/// Scotia. Outside those two countries the exchange is the entity, which no
/// party asks a DX station to type.
export function defaultTheirLocation(party: QsoParty, qso: Record<string, JSONValue>): string {
  const entityPrefix = entityPrefixOf(qso as Record<string, unknown>)
  // A station in no known entity — no callsign yet, or one the country file
  // cannot place — is a QSO we cannot place, not a DX contact
  // (`normalizeLocation` draws the same line). Answering `DX` here would slip
  // past the scorer, which normalizes it back to nothing without an entity,
  // and be offered as the suggestion in an empty entry row.
  if (!entityPrefix) return ""
  if (entityPrefix === "K" || entityPrefix === "VE") {
    const guessed = guessedStateOf(qso as Record<string, unknown>)
    // A state CODE, and only that. `normalizeLocation` reads anything longer
    // than four characters as a county carrying its state in its first two, so
    // a lookup that hands back a NAME would resolve `MINNESOTA` to `MI` —
    // Michigan — and both the score and the file would claim the wrong state
    // with nothing looking wrong anywhere. Every US state, DC and every
    // Canadian province is two characters; a longer answer has told us nothing
    // we can file.
    if (guessed.length !== 2 || !normalizeLocation(party, guessed, { entityPrefix })) return ""
    return guessed
  }
  // Alaska and Hawaii are US STATES that do not send `K`, and the scorer
  // credits them as such — so a file that wrote `DX` for one would not support
  // the multiplier the scoreboard already claimed. Unless the party counts them
  // as DX, which none of the shipped ones does.
  const state = stateForEntity(party, entityPrefix)
  if (state && !party.options.alaskaAndHawaiiAreDX) return state
  return party.options.dxLocationIsPrefix && entityPrefix ? entityPrefix : "DX"
}

/// The state an entity's stations are in, for the two that are US states but
/// do not send `K` — read by the export so its fallback cannot disagree with
/// the scorer about an Alaskan or Hawaiian contact.
export function stateForEntity(party: QsoParty, entityPrefix: string): string {
  const table = party.options.sectionsForOutOfState ? SECTION_ENTITIES : STATE_ENTITIES
  return table[entityPrefix] ?? ""
}

/// Whether every location given is inside the party — the test both sides'
/// standing is decided by. An empty list is NOT inside: a station whose
/// exchange we could not resolve is treated as out of the party, which is the
/// safe reading for the in-state-only rules that turn on this.
export function allInParty(locations: PartyLocation[]): boolean {
  return locations.length > 0 && locations.every((location) => location.inParty)
}

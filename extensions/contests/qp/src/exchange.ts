// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The exchange as the operator sees it and as the sponsor receives it: which
// codes the entry row offers, which of them are floated to the top, and the
// Cabrillo rows one contact turns into.
//
// Separate from index.ts so these can be unit-tested: index.ts calls
// `defineExtension` at import time, so nothing in it is reachable from
// `node --test` (naqp's `exchange.ts` is separate for the same reason).

import { operationForQso } from "@ham2k/extension-sdk"
import type { JSONValue, OperationSegmentPayload } from "@ham2k/extension-sdk"

import { ourLocationText, ourModeClass, ourName, ourOperatorClass, ourOverlayClass, ourPowerClass, ourStationClass, refOfType, serial, str } from "./entry.ts"
import {
  allInParty,
  COUNTY_LINE_SEPARATOR,
  defaultTheirLocation,
  entityPrefixOf,
  nameForLocation,
  ourOwnCodes,
  outOfPartyTables,
  parseLocations,
  parseOurLocations,
  splitLocations,
  type Standing,
  stateForEntity,
} from "./location.ts"
import { STATE_FOR_SECTION } from "./locations.ts"
import { type QsoParty, stateForCounty, WARC_BANDS } from "./parties.ts"

export function theirLocationForFile(
  party: QsoParty,
  qso: Record<string, JSONValue>,
  { weAreInParty, lastLocation }: { weAreInParty: boolean; lastLocation?: Record<string, string> },
): string {
  const qsoRef = refOfType(qso as Record<string, unknown>)
  const entityPrefix = entityPrefixOf(qso as Record<string, unknown>)
  const their = (qso.their as Record<string, JSONValue>) ?? {}
  const call = str(their.call).toUpperCase()
  const remembered = call ? lastLocation?.[call] : undefined
  const typed = str(qsoRef?.location).trim()
  // `received` as the scorer means it: only what the operator copied, so the
  // file and the score refuse the same exchanges and fall back on the same ones.
  const received = typed !== ""
  const text = typed || remembered || defaultTheirLocation(party, qso)
  const standing: Standing = { weAreInParty, theyAreInParty: false }
  let locations = parseLocations(party, text, { entityPrefix, standing, received })
  standing.theyAreInParty = allInParty(locations)
  if (standing.theyAreInParty) locations = parseLocations(party, text, { entityPrefix, standing, received })
  if (call && locations.length > 0 && lastLocation) {
    lastLocation[call] = locations.map((location) => location.code).join(COUNTY_LINE_SEPARATOR)
  }
  return locations.map((location) => location.sent).join(COUNTY_LINE_SEPARATOR)
}

/// Whether a contact on [band] counts at all — the WARC bands are closed to
/// contests by IARU convention, and a QSO with no band cannot be checked
/// against any sponsor's rules. The scorer's own test (`scorer.ts`), kept here
/// so the file and the scoreboard cannot disagree about which contacts exist.
export function claimableBand(band: string): boolean {
  return band !== "" && !WARC_BANDS.includes(band)
}

/// The key our own ADIF export sets on the operation's ref: each contact's
/// resolved exchange, by QSO uuid.
///
/// `adifFields` is asked one contact at a time and never sees the log, so it
/// cannot know what a station sent EARLIER — and the scorer and the Cabrillo
/// both score a blank exchange under the county that station gave the first
/// time. Without this the same export run wrote `ERI` in the Cabrillo and
/// nothing at all in the ADIF, for a contact the scoreboard had counted.
///
/// Carried on a copy of the operation — of EVERY segment's operation, since the
/// core generator hands the hook the segment-effective one — in-runtime, so
/// this costs a reference rather than a payload.
export const RESOLVED_MARKER = "resolvedExchange"

/// Every contact's exchange as the file should write it, by uuid — folded in
/// log order, so a station's later blank exchange resolves to what they sent
/// before, exactly as `scorer.ts` folds it.
export function resolvedExchanges(
  party: QsoParty,
  operation: Record<string, JSONValue>,
  qsos: Record<string, JSONValue>[],
  segments?: OperationSegmentPayload[],
): Record<string, string> {
  const lastLocation: Record<string, string> = {}
  const resolved: Record<string, string> = {}
  for (const qso of qsos) {
    if (qso.band === "event" || qso.deleted === true) continue
    const uuid = str(qso.uuid)
    const ours = parseOurLocations(party, ourLocationForQso(qso, operation, segments))
    const text = theirLocationForFile(party, qso, {
      weAreInParty: allInParty(ours),
      // A contact the scorer refuses teaches it nothing, so it may not teach
      // this fold either.
      lastLocation: claimableBand(str(qso.band)) ? lastLocation : undefined,
    })
    if (uuid) resolved[uuid] = text
  }
  return resolved
}

/// The county WE were in for this contact: the operation's own location, read
/// off the operation that was true when the contact was made.
///
/// A rover's county changes mid-log through segments, and the host hands the
/// export the same resolved segments the scorer folds — so the file and the
/// scoreboard read one answer. Nothing is stamped onto the contact and nothing
/// on it is preferred: a county corrected in setup, or in a segment, reaches
/// every contact of that stretch the moment it is corrected, in the score and
/// in the file alike. Without segments the operation's location is true of the
/// whole log by definition.
export function ourLocationForQso(qso: Record<string, JSONValue>, operation: Record<string, JSONValue>, segments?: OperationSegmentPayload[]): string {
  return ourLocationText(operationForQso(operation, qso, segments) as Record<string, unknown>)
}

/// One contact's Cabrillo rows — one per pairing of our counties with theirs,
/// which is how a county line is submitted: each end scores every combination,
/// so each combination is a line the checker can match against the other
/// station's log.
export function cabrilloRowsFor(
  party: QsoParty,
  qso: Record<string, JSONValue>,
  operation: Record<string, JSONValue>,
  ourCall: string,
  { segments, lastLocation }: { segments?: OperationSegmentPayload[]; lastLocation?: Record<string, string> } = {},
): string[][] {
  const qsoRef = refOfType(qso as Record<string, unknown>)
  const their = (qso.their as Record<string, JSONValue>) ?? {}
  const call = str(their.call).toUpperCase()
  const theirCall = cabrilloCall(party, str(their.call))
  const entityPrefix = entityPrefixOf(qso as Record<string, unknown>)

  // Resolved through the SAME path the scorer takes, rather than read raw off
  // the ref. Two ways the two used to disagree, in opposite directions:
  //
  //   * a station whose exchange was typed once and left blank on the next band
  //     scores under the county they gave the first time (the scorer's
  //     `lastLocation`), and the export wrote no row at all — a file claiming
  //     FEWER contacts than the scoreboard;
  //   * an unrecognizable exchange from a US station scores zero
  //     (`invalidExchange`) and the export wrote a row anyway — a file claiming
  //     MORE.
  const typed = str(qsoRef?.location).trim()
  const remembered = call ? lastLocation?.[call] : undefined
  const theirText = typed || remembered || defaultTheirLocation(party, qso)
  const received = typed !== ""

  const ourLocations = parseOurLocations(party, ourLocationForQso(qso, operation, segments))
  const weAreIn = allInParty(ourLocations)

  const standing: Standing = { weAreInParty: weAreIn, theyAreInParty: false }
  let theirLocations = parseLocations(party, theirText, { entityPrefix, standing, received })
  standing.theyAreInParty = allInParty(theirLocations)
  if (standing.theyAreInParty) {
    theirLocations = parseLocations(party, theirText, { entityPrefix, standing, received })
  }

  const ours = ourLocations.map((location) => location.sent)
  const theirs = theirLocations.map((location) => location.sent)

  // Every gate the scorer applies, in the order it applies them — a contact it
  // scored zero may not appear in the file, and one it never learned from may
  // not teach the file either. The band gate is the one this used to miss: a
  // 30m contact scores `invalidBand` and was still written out, and its
  // exchange was still remembered, so the next blank exchange from that station
  // resolved to a county the scoresheet had never recorded.
  if (!claimableBand(str(qso.band))) return []
  if (!weAreIn && !standing.theyAreInParty) return []

  // Only now is this a contact the file claims, so only now is it something the
  // next blank exchange may resolve from.
  if (call && theirLocations.length > 0 && lastLocation) {
    // Remembered as the code, which is what the next contact resolves from —
    // a prefix written into the file is not something to re-parse.
    lastLocation[call] = theirLocations.map((location) => location.code).join(COUNTY_LINE_SEPARATOR)
  }

  // A party that numbers its contacts exchanges the number INSTEAD of a
  // report, and its template has no RST column — a checker reading one
  // column late takes the 599 for the serial.
  const isCw = str(qso.mode) === "CW" || str(qso.mode) === "RTTY"
  const report = party.exchange.number ? [] : [(isCw ? "599" : "59").padEnd(3, " ")]
  const ourSerial = serial(qsoRef?.ourSerial)
  const theirSerial = serial(qsoRef?.theirSerial)
  const ourOwnName = ourName(operation as Record<string, unknown>)
  const theirName = str(qsoRef?.theirName).toUpperCase()

  const rows: string[][] = []
  for (const ourCode of ours) {
    for (const theirCode of theirs) {
      const row = [(ourCall || "-").padEnd(13, " "), ...report]
      if (party.exchange.number) row.push((ourSerial || "0").padEnd(4, " "))
      if (party.exchange.name) row.push((ourOwnName || "-").padEnd(10, " "))
      row.push(ourCode.padEnd(6, " "))
      row.push((theirCall || "-").padEnd(13, " "), ...report)
      if (party.exchange.number) row.push((theirSerial || "-").padEnd(4, " "))
      if (party.exchange.name) row.push((theirName || "-").padEnd(10, " "))
      row.push(theirCode.padEnd(6, " "))
      rows.push(row)
    }
  }
  return rows
}

/// The callsign as the sponsor wants it in the file. Idaho asks for rovers'
/// county suffixes to be stripped — polo's NOTES lists `removeCountySuffixes`
/// as unimplemented; it is honoured here, and the suffix is only ever removed
/// where the party asked for it.
export function cabrilloCall(party: QsoParty, call: string): string {
  const upper = call.toUpperCase()
  if (!party.options.removeCountySuffixes) return upper
  const slash = upper.indexOf("/")
  return slash > 0 ? upper.slice(0, slash) : upper
}

/// The codes the exchange field offers, for the station being worked.
///
/// Narrowed by who they are: a US station in a US party may send a county, a
/// state, or one of a neighbouring party's counties; a Canadian station in that
/// same party can only send a province; and a station in neither country sends
/// their entity, which is not a list at all.
///
/// The narrowing is about what is ANSWERABLE, not about size — for a US station
/// in the three largest parties (7QP, NEQP, IN) the list is still ~470 entries,
/// roughly 15KB, sent once per callsign resolution. That is the measurement
/// §5.6 wants before building a registered `optionSet`, and the one consumer
/// that would justify it.
export function exchangeOptionsFor(party: QsoParty, qso: Record<string, JSONValue> | undefined): { code: string; name?: string }[] {
  const entity = qso ? entityPrefixOf(qso as Record<string, unknown>) : ""
  const asOptions = (table: Record<string, string>) => Object.entries(table).map(([code, name]) => ({ code, name }))

  const ourCounties = [...asOptions(party.counties), ...asOptions(party.otherCounties)]
  // `US_STATES` holds the fifty states and not DC, because whether DC is its
  // own multiplier is a per-party rule (`locations.ts`). It is still a value
  // stations SEND, on every party, so it belongs in the list either way — and
  // without it the field tints a perfectly good exchange as unknown for the
  // whole QSO, while the scorer accepts it.
  // The party's OWN states are not in either list. Nobody sends one: inside
  // the party the exchange is a county, and outside it nobody is in those
  // states to begin with — so `NY` in the New York QSO Party is an exchange no
  // station could have given, and the field says so in red rather than
  // accepting it as the state it resolves to. (`partyStates` is the same set
  // the scorer reads to catch an operator who typed their state where their
  // county belongs; this is the other end of that mistake.)
  // `ourOwnCodes`, not `partyStates`: a SECTION lies inside a state without
  // sharing its code, so PAQP's own `EPA` and `WPA` are exactly as unsendable
  // as `NY` is in the New York QSO Party and slip a plain state comparison.
  const ours = ourOwnCodes(party)
  const notOurs = (options: { code: string; name?: string }[]) => options.filter((option) => !ours.has(option.code))
  // Where the exchange is a section none of the DC question applies: `MDC` is
  // in the table, and `DC` is not something the sponsor accepts.
  const tables = outOfPartyTables(party)
  const states = notOurs(
    party.options.sectionsForOutOfState ? asOptions(tables.us) : [...asOptions(tables.us), { code: "DC", name: nameForLocation(party, "DC") }],
  )
  const provinces = notOurs(asOptions(tables.canada))

  // Alaska and Hawaii are US states whose stations do not sign `K`. They send
  // a county or a state like any other US station — and in the Hawaii QSO
  // Party a Hawaiian is the one station that sends one of its multipliers.
  // Left to the DX path below, exactly they would get no list to pick from
  // and no tint for a typo. Unless the party counts them as DX, which no
  // shipped one does.
  const usState = entity === "K" || (stateForEntity(party, entity) !== "" && !party.options.alaskaAndHawaiiAreDX)
  if (usState) {
    return party.options.entity === "VE" ? states : [...ourCounties, ...states]
  }
  if (entity === "VE") {
    return party.options.entity === "VE" ? [...ourCounties, ...provinces] : provinces
  }
  // A known entity that is neither: they send `DX` or their prefix, and there
  // is no list to search. An empty set turns the field freeform (above).
  if (entity) return []
  // Nobody looked up yet — offer everything, since the operator may be typing
  // the exchange before the callsign resolves.
  return [...ourCounties, ...states, ...provinces]
}

/// The Cabrillo `CATEGORY-` lines the declared entry classes produce.
///
/// This is the reason the classes are captured at all: a submitted log declares
/// its entry in these lines, and a checker reads them rather than guessing.
/// Nothing is emitted for a question the operator did not answer — an omitted
/// line is "no claim", while a guessed one is a claim they never made.
///
/// `operator` splits back into the two lines Cabrillo keeps apart: the
/// multi-operator classes are one `CATEGORY-OPERATOR` with the transmitter
/// count beside it.
export function cabrilloCategories(party: QsoParty, operation: Record<string, JSONValue>): [string, string | undefined][] {
  const op = ourOperatorClass(party, operation as Record<string, unknown>)
  const station = ourStationClass(party, operation as Record<string, unknown>)
  const mode = ourModeClass(party, operation as Record<string, unknown>)
  const overlay = ourOverlayClass(party, operation as Record<string, unknown>)
  const power = ourPowerClass(operation as Record<string, unknown>, undefined, party)

  const transmitter = op === "MULTI-ONE" ? "ONE" : op === "MULTI-TWO" ? "TWO" : op === "MULTI-UNLIMITED" ? "UNLIMITED" : undefined

  return [
    ["CATEGORY-OPERATOR", op ? (op.startsWith("SINGLE") ? "SINGLE-OP" : "MULTI-OP") : undefined],
    ["CATEGORY-TRANSMITTER", transmitter],
    // Only ever ASSISTED: Cabrillo's other value is NON-ASSISTED, and claiming
    // that for an operator who simply answered "Single Op" would be a claim
    // about their spotting that they did not make.
    ["CATEGORY-ASSISTED", op === "SINGLE-OP-ASSISTED" ? "ASSISTED" : undefined],
    ["CATEGORY-POWER", power],
    // `COUNTY-LINE` is a station class sponsors publish and Cabrillo has no
    // value for; it reaches the file as the closest thing it does have.
    ["CATEGORY-STATION", station === "COUNTY-LINE" ? "FIXED" : station],
    ["CATEGORY-MODE", mode === "PHONE" ? "SSB" : mode === "DIGITAL" ? "DIGI" : mode],
    ["CATEGORY-OVERLAY", overlay],
  ]
}

/// The live rewrites the exchange field applies as the operator types: one, and
/// only for a party that has county lines — a comma becomes the separator the
/// operator meant. `location.ts` reads either, and the slash is the form the
/// sponsors' samples use.
export function exchangeTransforms(party: QsoParty): { pattern: string; replacement: string; flags?: string }[] {
  if (!party.options.countyLine) return []
  return [{ pattern: ",", replacement: COUNTY_LINE_SEPARATOR, flags: "g" }]
}

/// How many characters a second county may borrow from the first — the
/// multi-state parties' shorthand, where `ORDES/JEF` means `ORDES/ORJEF`.
///
/// Declared rather than rewritten. A rewrite cannot tell the shorthand from the
/// same letters being typed on the way to the full code: after `IDADA/`, `IDA`
/// is either Idaho county's shorthand or the first three characters of
/// `IDIDA`, and four real 7QP counties (`IDIDA`, `UTUTA`, `WAWAH`, `WAWAL`)
/// have exactly that shape. The field matches and validates both readings and
/// rewrites neither.
export function exchangeInheritPrefix(party: QsoParty): number {
  // Only the multi-state parties have codes long enough for the shorthand to
  // mean anything — the same length test `splitLocations` makes.
  return Object.keys(party.counties).some((code) => code.length > 4) ? 2 : 0
}

/// What this station sent us EARLIER in this operation, if anything.
///
/// The best answer there is: it is not a guess at all but an exchange the
/// operator already copied from this same station, and it is what the scorer
/// and both exports fall back to for a blank second-band contact (the
/// `lastLocation` fold). Offering it in the field means the operator confirms
/// it rather than discovering after the fact that it was assumed.
///
/// [history] is that station's contacts NEWEST first, as `getHistoryForCall`
/// answers — so the first one carrying an exchange wins: a rover who gave a
/// new county on the last band sent that county, not the one they opened
/// with. The callsign, the event markers and the ref are checked here again
/// because a host older than `getHistoryForCall`'s filters ignores them and
/// answers the station's latest contacts of any kind (the SDK's contract).
///
/// [accept] narrows it further, for a history the operator did not just copy
/// (`pastExchangeHolds`).
export function loggedExchangeFor(history: Record<string, JSONValue>[], call: string, accept: (location: string) => boolean = () => true): string {
  const wanted = call.trim().toUpperCase()
  if (!wanted) return ""
  for (const qso of history) {
    if (qso.band === "event") continue
    const their = (qso.their as Record<string, JSONValue>) ?? {}
    if (str(their.call).toUpperCase() !== wanted) continue
    const location = str(refOfType(qso as Record<string, unknown>)?.location).trim()
    if (location && accept(location)) return location
  }
  return ""
}

/// Whether an exchange a station gave in an EARLIER running of this party is
/// still worth offering them now.
///
/// Two things can have changed since, and the history cannot say which:
///
///  * **It was not this party.** Past runnings are found by the operation's
///    party key as a PREFIX (`getHistoryForCall`'s `refPrefix`), and `NE` —
///    Nebraska — is a prefix of `NEQP`, New England. The answer carries the
///    contacts, not their operations, so the party is checked the one way
///    left: every code in the exchange must be one this party offers.
///  * **They moved.** Where the lookup knows their state now, every code must
///    be in it — a county by the state it belongs to, a state or province as
///    itself. A county from two years ago in another state is a wrong prefill
///    the operator has to notice; the lookup's state is what they send.
///
/// An exchange from THIS operation is not checked at all: the operator copied
/// it minutes ago, and a lookup that disagrees is more likely wrong than it.
export function pastExchangeHolds(party: QsoParty, options: { code: string }[], guessedState: string, location: string): boolean {
  const codes = splitLocations(location)
  if (codes.length === 0) return false
  const offered = new Set(options.map((option) => option.code))
  return codes.every((code) => (options.length === 0 || offered.has(code)) && (!guessedState || stateOfCode(party, code) === guessedState))
}

/// The state (or province) an exchange code places a station in: a county by
/// the state it belongs to, a section by the state it lies in, anything else as
/// itself.
///
/// The section step is what lets a past exchange survive the comparison at all
/// where the party speaks sections: what was stored is `EMA` and what the
/// lookup answers is `MA`, so without it they never match and the prefill is
/// simply dead for every out-of-state station.
function stateOfCode(party: QsoParty, code: string): string {
  const isCounty = party.counties[code] !== undefined || party.otherCounties[code] !== undefined
  if (isCounty) return stateForCounty(party, code)
  return STATE_FOR_SECTION[code] ?? code
}

/// The codes floated to the top of the suggestion list: the counties of the
/// state the callsign lookup guessed, and the state itself.
export function preferredCodesFor(party: QsoParty, guessedState: string): string[] {
  if (!guessedState) return []
  const counties = Object.keys(party.counties).filter((code) => stateForCounty(party, code) === guessedState)
  // The state itself only where it is a code a station could send: inside the
  // party it is not offered at all (`exchangeOptionsFor`), and floating a
  // value to the top of a list it is not in would offer the operator an
  // exchange the same field then tints as wrong.
  const ours = ourOwnCodes(party)
  if (!party.options.sectionsForOutOfState) return ours.has(guessedState) ? counties : [...counties, guessedState]
  // A lookup answers with a STATE and the field holds sections, so the state
  // itself is in no list and ranking by it would rank nothing. Every section of
  // that state is floated instead, since no lookup can say which of
  // California's nine they are sitting in.
  const tables = outOfPartyTables(party)
  const sections = [...Object.keys(tables.us), ...Object.keys(tables.canada)].filter(
    (code) => !ours.has(code) && (STATE_FOR_SECTION[code] ?? code) === guessedState,
  )
  return [...counties, ...sections]
}

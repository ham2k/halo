// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The exchange on its way in (what the entry row offers) and on its way out
// (what the sponsor receives). The Cabrillo cases are the ones that matter
// most: a file is submitted once, months after the contest, and nobody reads it
// before it goes.

import { test } from "node:test"
import assert from "node:assert/strict"

import type { JSONValue } from "@ham2k/extension-sdk"

import {
  cabrilloCategories,
  cabrilloCall,
  claimableBand,
  cabrilloRowsFor,
  exchangeInheritPrefix,
  exchangeOptionsFor,
  exchangeTransforms,
  loggedExchangeFor,
  pastExchangeHolds,
  ourLocationForQso,
  preferredCodesFor,
  resolvedExchanges,
  theirLocationForFile,
} from "./exchange.ts"
import { defaultTheirLocation } from "./location.ts"
import { partyFor, type QsoParty } from "./parties.ts"

function party(key: string): QsoParty {
  const found = partyFor(key)
  assert.ok(found, `no party ${key}`)
  return found
}

function operation(location: string): Record<string, JSONValue> {
  return { uuid: "op", stationCall: "N0DEV", refs: [{ type: "qp", ref: "NY", location }] }
}

function qso({
  call = "K1ABC",
  location,
  ourLocation,
  entityPrefix = "K",
  state,
  mode = "CW",
  startAtMillis,
}: {
  call?: string
  location?: string
  /// A stamp an earlier build left on the ref. Present in the fixtures only
  /// to prove it is IGNORED.
  ourLocation?: string
  entityPrefix?: string
  state?: string
  mode?: string
  startAtMillis?: number
} = {}): Record<string, JSONValue> {
  return {
    their: { call, ...(entityPrefix ? { entityPrefix } : {}), ...(state ? { state } : {}) },
    band: "20m",
    mode,
    ...(startAtMillis !== undefined ? { startAtMillis } : {}),
    refs: [{ type: "qp", ...(location !== undefined ? { location } : {}), ...(ourLocation ? { ourLocation } : {}) }],
  }
}

/// A log that changed county at 1000: the base operation's county before, [later]
/// from then on — the payload the host sends as `ExportRequest.segments`.
function segmentsTo(later: string, base = "ALB") {
  return [
    { fromMillis: -1, operation: operation(base) },
    { fromMillis: 1000, operation: operation(later) },
  ]
}

test("a county line submits one row per pairing", () => {
  // Each pairing is what the checker matches against the other station's log,
  // so a line-to-line contact is four lines, not one.
  const rows = cabrilloRowsFor(party("NY"), qso({ location: "ERI/CHA" }), operation("ALB/REN"), "N0DEV")
  assert.equal(rows.length, 4)
  const pairs = rows.map((row) => [row[2].trim(), row[5].trim()])
  assert.deepEqual(pairs, [
    ["ALB", "ERI"],
    ["ALB", "CHA"],
    ["REN", "ERI"],
    ["REN", "CHA"],
  ])
})

test("on a segmented log, the county WE were in is the segment's, not anything on the contact", () => {
  // A rover's county changes mid-log; the host hands the export the same
  // resolved segments the scorer folds, so a contact made after the break is
  // filed under the county the break established — whatever an earlier build
  // stamped onto it when it was saved.
  const before = qso({ location: "ERI", startAtMillis: 500, ourLocation: "REN" })
  const after = qso({ location: "ERI", startAtMillis: 1500, ourLocation: "ALB" })
  assert.equal(ourLocationForQso(before, operation("ALB"), segmentsTo("REN")), "ALB")
  assert.equal(ourLocationForQso(after, operation("ALB"), segmentsTo("REN")), "REN")
  const rows = cabrilloRowsFor(party("NY"), after, operation("ALB"), "N0DEV", { segments: segmentsTo("REN") })
  assert.equal(rows[0][2].trim(), "REN")
})

test("a county corrected in a segment reaches every contact of that stretch", () => {
  // The whole point of reading the segment rather than a stamp: six contacts
  // logged under a mistyped county and then corrected at the break are filed
  // under the correction, in the file as on the scoreboard. A stamp would have
  // kept the typo on all six.
  const stamped = qso({ location: "ERI", startAtMillis: 1500, ourLocation: "MORR" })
  assert.equal(ourLocationForQso(stamped, operation("MORR"), segmentsTo("WRRN", "MORR")), "WRRN")
})

test("without segments, the operation's county is true of the whole log", () => {
  // An operator who logs 30 contacts, notices the county is a typo and fixes it
  // in setup rescores the whole log — and the file has to follow rather than
  // submit the county that was typed by mistake.
  const stamped = qso({ location: "ERI", ourLocation: "ALB" })
  assert.equal(ourLocationForQso(stamped, operation("ALL")), "ALL")
  assert.equal(ourLocationForQso(stamped, operation("ALL"), []), "ALL")
  const rows = cabrilloRowsFor(party("NY"), stamped, operation("ALL"), "N0DEV")
  assert.equal(rows[0][2].trim(), "ALL")
})

test("a serial and a name are columns only for the parties that exchange them", () => {
  // Every column shifts when one is added, so a party that does not trade
  // serials must not get an empty one.
  const plain = cabrilloRowsFor(party("NY"), qso({ location: "ERI" }), operation("ALB"), "N0DEV")
  assert.equal(plain[0].length, 6)
  // California exchanges a serial INSTEAD of a report: our call, serial,
  // county, then theirs — no RST column, or a checker reads 599 as the serial.
  // `ourSerial` is a number because that is how the core allocates it; typed
  // text, `theirSerial` is a string. A reader that only takes strings writes
  // every sent serial as 0.
  const ca = { uuid: "op", stationCall: "N0DEV", refs: [{ type: "qp", ref: "CA", location: "ALAM" }] }
  const caQso = {
    their: { call: "K1ABC", entityPrefix: "K" },
    band: "20m",
    mode: "CW",
    refs: [{ type: "qp", location: "BUTT", ourSerial: 12, theirSerial: "34" }],
  }
  const rows = cabrilloRowsFor(party("CA"), caQso, ca, "N0DEV")
  assert.deepEqual(
    rows[0].map((cell) => cell.trim()),
    ["N0DEV", "12", "ALAM", "K1ABC", "34", "BUTT"],
  )
})

test("a contact with nobody in the party is left out of the file", () => {
  // Two out-of-party stations working each other is not a contest QSO — the
  // scorer awards it nothing, and a submitted file claiming it is an over-claim
  // a checker will strike.
  const outside = { uuid: "op", stationCall: "N0DEV", refs: [{ type: "qp", ref: "NY", location: "NJ" }] }
  assert.deepEqual(cabrilloRowsFor(party("NY"), qso({ location: "CT" }), outside, "N0DEV"), [])
  // One end inside is a contest QSO, whichever end it is.
  assert.equal(cabrilloRowsFor(party("NY"), qso({ location: "ERI" }), outside, "N0DEV").length, 1)
  assert.equal(cabrilloRowsFor(party("NY"), qso({ location: "CT" }), operation("ALB"), "N0DEV").length, 1)
})

test("an exchange nobody typed falls back to what we know of where they are", () => {
  // The exchange is what they SENT, and this is the gap where nothing was
  // copied at all: rather than score the contact zero and file nothing, both
  // sides read the state the QSO carries — asserted on `their.state` by an
  // operator or an import, or the callsign lookup's own guess. The scorer and
  // the file read one function, so they cannot disagree about it.
  assert.equal(defaultTheirLocation(party("NY"), qso({ state: "NJ" })), "NJ")
  const rows = cabrilloRowsFor(party("NY"), qso({ state: "NJ" }), operation("ALB"), "N0DEV")
  assert.equal(rows.length, 1)
  assert.equal(rows[0][5].trim(), "NJ")

  // Nothing known: still nothing claimed. A contact we cannot place is one the
  // scorer refuses (`missingExchange`), and a file may not claim what the
  // scoreboard declined.
  assert.equal(defaultTheirLocation(party("NY"), qso()), "")
  assert.deepEqual(cabrilloRowsFor(party("NY"), qso(), operation("ALB"), "N0DEV"), [])

  // A state that means nothing to this party is not a state. `parseLocations`
  // would drop it anyway; refusing it HERE is what keeps the fallback from
  // reporting a location it cannot resolve.
  assert.equal(defaultTheirLocation(party("NY"), qso({ state: "ZZ" })), "")
  // A state NAME is not a state code. `normalizeLocation` would read
  // `MINNESOTA` as a five-plus-character county and take its first two letters
  // — `MI`, Michigan — so the log and the file would both claim the wrong
  // state with nothing looking wrong anywhere.
  assert.equal(defaultTheirLocation(party("NY"), qso({ state: "MINNESOTA" })), "")

  // Only consulted for a station in the party's own country. A DX lookup's
  // `state` is its own country's subdivision and the two-letter codes collide —
  // a German `NS` is not Nova Scotia.
  assert.equal(defaultTheirLocation(party("NY"), qso({ entityPrefix: "DL", state: "NS" })), "DX")
  // A DX station's exchange IS their entity — nobody asks them to send one, so
  // this is what they gave us, not a guess.
  assert.equal(defaultTheirLocation(party("NY"), qso({ entityPrefix: "DL" })), "DX")
  // Where a party asks for the prefix instead of the word DX (15 of them do).
  assert.equal(defaultTheirLocation(party("WA"), qso({ entityPrefix: "DL" })), "DL")
})

test("the file claims a contact only where the score does", () => {
  // Both sides ask the same question — is one END of this contact wholly
  // inside the party — so a row cannot appear for a contact worth zero. An
  // out-of-party entrant working a county line half outside the party is the
  // case the two readings disagree on.
  const outside = { uuid: "op", stationCall: "N0DEV", refs: [{ type: "qp", ref: "NY", location: "CA" }] }
  assert.deepEqual(cabrilloRowsFor(party("NY"), qso({ location: "ERI/NJ" }), outside, "N0DEV"), [])
  // Wholly inside, and it counts.
  assert.equal(cabrilloRowsFor(party("NY"), qso({ location: "ERI/CHA" }), outside, "N0DEV").length, 2)
})

test("the file says what the scoreboard claimed for an Alaskan contact", () => {
  // The scorer credits an Alaskan station as the state `AK`; a file writing
  // `DX` for the same contact would not support the multiplier already
  // claimed — the divergence `location.ts` exists to prevent.
  assert.equal(defaultTheirLocation(party("NY"), qso({ entityPrefix: "KL" })), "AK")
  assert.equal(defaultTheirLocation(party("NY"), qso({ entityPrefix: "KH6" })), "HI")
})

test("Idaho strips a rover suffix from the callsign, and nobody else does", () => {
  // polo's NOTES lists `removeCountySuffixes` as unimplemented.
  assert.equal(cabrilloCall(party("ID"), "K7ABC/ADA"), "K7ABC")
  assert.equal(cabrilloCall(party("NY"), "K2ABC/M"), "K2ABC/M")
})

test("the entry row offers what the station being worked could possibly send", () => {
  const ny = party("NY")
  // A US station may send a county or a state…
  const us = exchangeOptionsFor(ny, qso({ entityPrefix: "K" })).map((option) => option.code)
  assert.ok(us.includes("ALB"))
  assert.ok(us.includes("NJ"))
  // …a Canadian station in a US party can only send a province…
  const ve = exchangeOptionsFor(ny, qso({ entityPrefix: "VE" })).map((option) => option.code)
  assert.deepEqual(ve.includes("ALB"), false)
  assert.ok(ve.includes("ON"))
  // …and a DX station sends their entity, which is not a list at all, so the
  // field accepts whatever the operator heard.
  assert.deepEqual(exchangeOptionsFor(ny, qso({ entityPrefix: "DL" })), [])
  // A Canadian party is the mirror image.
  const acqp = party("ACQP")
  const acqpVe = exchangeOptionsFor(acqp, qso({ entityPrefix: "VE" })).map((option) => option.code)
  assert.ok(acqpVe.some((code) => acqp.counties[code] !== undefined))
})

test("the county-line shorthand is declared, not rewritten", () => {
  // 7QP's operators may send `ORDES/JEF` for `ORDES/ORJEF`, which the scorer
  // and the Cabrillo already understand — so the field has to accept it too,
  // or it tints a perfectly good exchange invalid.
  //
  // Declared rather than rewritten, because no rewrite can tell the shorthand
  // from the same letters on the way to the full code: after `IDADA/`, `IDA` is
  // either Idaho county's shorthand or the first three characters of `IDIDA`,
  // and four real 7QP counties have exactly that shape.
  assert.equal(exchangeInheritPrefix(party("7QP")), 2)
  const counties = Object.keys(party("7QP").counties)
  for (const code of ["IDIDA", "UTUTA", "WAWAH", "WAWAL"]) {
    assert.ok(counties.includes(code), `${code} is a 7QP county whose shorthand collides`)
  }
  // A party whose codes are three letters has no shorthand at all…
  assert.equal(exchangeInheritPrefix(party("NY")), 0)
  // …and the only live rewrite left is the comma an operator may reach for.
  assert.deepEqual(exchangeTransforms(party("NY")), [{ pattern: ",", replacement: "/", flags: "g" }])
  assert.deepEqual(exchangeTransforms(party("WI")), [])
})

test("DC is offered, because stations send it", () => {
  // `US_STATES` holds the fifty and not DC — whether DC is its own multiplier
  // is a per-party rule. Left out of the list as well, the field tints a
  // perfectly good exchange as unknown for the whole QSO while the scorer
  // accepts it.
  for (const key of ["NY", "MD"]) {
    const codes = exchangeOptionsFor(party(key), qso({ entityPrefix: "K" })).map((option) => option.code)
    assert.ok(codes.includes("DC"), `${key} does not offer DC`)
  }
  // And it reads as whatever that party calls it.
  const ny = exchangeOptionsFor(party("NY"), qso({ entityPrefix: "K" })).find((option) => option.code === "DC")
  assert.equal(ny?.name, "Maryland & DC")
  const md = exchangeOptionsFor(party("MD"), qso({ entityPrefix: "K" })).find((option) => option.code === "DC")
  assert.equal(md?.name, "District of Columbia")
})

test("7QP offers its neighbours' counties, because its entrants work them", () => {
  const codes = exchangeOptionsFor(party("7QP"), qso({ entityPrefix: "K" })).map((option) => option.code)
  assert.ok(codes.includes("ORDES"))
  // A neighbouring party's county — a valid exchange, and not one of 7QP's own.
  assert.ok(codes.some((code) => party("7QP").otherCounties[code] !== undefined))
})

test("the guessed state floats its counties up, and never fills a county in", () => {
  // A COUNTY is only ever ranked: no lookup guesses one, so writing one in
  // would be worse than useless (§5.3). The state itself is the other half of
  // the same guess and IS written in where it is the whole exchange — see the
  // prefill test below.
  const preferred = preferredCodesFor(party("7QP"), "OR")
  assert.ok(preferred.includes("ORDES"))
  assert.deepEqual(
    preferred.some((code) => code.startsWith("WA")),
    false,
  )
  // Oregon's own code is NOT floated up: `OR` is one of 7QP's states, so it is
  // not an exchange any station sends and the field does not offer it. A
  // suggestion the same field then tints red is worse than none.
  assert.deepEqual(preferred.includes("OR"), false)
  // A state from outside the party is both offered and floated.
  assert.ok(preferredCodesFor(party("NY"), "NJ").includes("NJ"))
  assert.deepEqual(preferredCodesFor(party("NY"), ""), [])
})

test("a Hawaiian or an Alaskan picks from the list, like any other US station", () => {
  // KH6 and KL7 are US states whose stations do not sign K. In the Hawaii QSO
  // Party a Hawaiian is the one station that sends one of its multipliers —
  // left to the DX path, exactly they would type it into a field with no
  // list and no tint for a typo.
  const hi = party("HI")
  const hawaiian = exchangeOptionsFor(hi, qso({ entityPrefix: "KH6" })).map((option) => option.code)
  assert.ok(hawaiian.includes("HON"), "the Hawaii multipliers are offered")
  assert.deepEqual(hawaiian.includes("HI"), false, "the party's own state is not")

  // Elsewhere they send their state, from the same list a K station gets.
  const alaskan = exchangeOptionsFor(party("NY"), qso({ entityPrefix: "KL7" })).map((option) => option.code)
  assert.ok(alaskan.includes("AK"))

  // A party that counts them as DX asks them for nothing, as any DX station.
  const dx = { ...hi, options: { ...hi.options, alaskaAndHawaiiAreDX: true } }
  assert.deepEqual(exchangeOptionsFor(dx, qso({ entityPrefix: "KH6" })), [])
})

test("the party's own state is not an exchange anybody sends", () => {
  // In NYQP an in-state station sends a COUNTY, and nobody outside New York is
  // in New York — so `NY` is an exchange no station could have given. It
  // resolves cleanly to the state, which is exactly why the field has to
  // refuse it: accepted, it scores the contact under out-of-party rules and
  // files a state multiplier for a county nobody copied.
  const codes = exchangeOptionsFor(party("NY"), qso({ entityPrefix: "K" })).map((option) => option.code)
  assert.deepEqual(codes.includes("NY"), false)
  assert.ok(codes.includes("NJ"), "every other state is still an exchange")
  assert.ok(codes.includes("ALB"), "and the counties are what an in-state station sends")

  // Every state a multi-state party covers, not just the one its key names.
  const sevenQp = exchangeOptionsFor(party("7QP"), qso({ entityPrefix: "K" })).map((option) => option.code)
  for (const state of ["OR", "WA", "ID", "UT", "WY", "MT"]) {
    assert.deepEqual(sevenQp.includes(state), false, state)
  }
  assert.ok(sevenQp.includes("CA"))

  // A Canadian party refuses its own province for the same reason.
  const bc = exchangeOptionsFor(party("BC"), qso({ entityPrefix: "VE" })).map((option) => option.code)
  assert.deepEqual(bc.includes("BC"), false)
  assert.ok(bc.includes("ON"))
})

test("the hint is what the log will claim if nothing is typed", () => {
  // One function for the field's suggestion and the fallback, so the field
  // cannot offer one thing while the score records another. It goes in as a
  // value where it is an exchange (an out-of-party state, `DX`) and as a hint
  // where it is not (the party's own state).
  const ny = party("NY")
  const hint = (q: Record<string, JSONValue>) => defaultTheirLocation(ny, q)

  // Out of the party the state IS what they will send…
  assert.equal(hint(qso({ entityPrefix: "K", state: "PA" })), "PA")
  // …in the party it is not, and the hint says so anyway: it is how the
  // operator sees WHICH New York station this is while typing the county.
  assert.equal(hint(qso({ entityPrefix: "K", state: "NY" })), "NY")
  // A DX station is never asked to type an exchange at all, so the hint is
  // what the file will write for them.
  assert.equal(hint(qso({ entityPrefix: "DL" })), "DX")
  assert.equal(defaultTheirLocation(party("WA"), qso({ entityPrefix: "DL" })), "DL")
  // Nothing known, nothing hinted.
  assert.equal(hint(qso()), "")
  // No entity at all — no callsign yet, or one the country file cannot place
  // — is a QSO we cannot place, not a DX contact. Answered `DX`, it would be
  // the suggestion shown in every empty entry row.
  assert.equal(defaultTheirLocation(party("NY"), {}), "")
  assert.equal(defaultTheirLocation(party("NY"), { their: { call: "Q0ZZZ" } } as Record<string, JSONValue>), "")
})

test("what this station sent us earlier is offered before any guess", () => {
  // Not a guess at all: an exchange the operator already copied from this same
  // station, and the one the scorer and both exports would silently fall back
  // to for a blank second-band contact. Offering it means the operator
  // confirms it instead of finding out afterwards that it was assumed.
  // Histories are NEWEST first, as `getHistoryForCall` answers.
  const entry = (call: string, location: string, band = "20m") => ({ their: { call }, band, refs: [{ type: "qp", location }] }) as Record<string, JSONValue>
  const history = [entry("K1ABC", "ERI")]
  assert.equal(loggedExchangeFor(history, "K1ABC"), "ERI")
  assert.equal(loggedExchangeFor(history, "k1abc"), "ERI", "the log is not case-sensitive")
  assert.equal(loggedExchangeFor(history, ""), "")

  // The LATEST county they gave, not the first: a rover who drove into the
  // next county sends the new one, and offering the old one would re-log a
  // county they have left.
  assert.equal(loggedExchangeFor([entry("K1ABC", "CHA", "40m"), entry("K1ABC", "ERI")], "K1ABC"), "CHA")

  // A contact whose exchange was never copied teaches this nothing, and an
  // event marker is not a contact.
  const blanks = [entry("K1ABC", "ZZZ", "event"), entry("K1ABC", "", "15m"), entry("K1ABC", "ERI")]
  assert.equal(loggedExchangeFor(blanks, "K1ABC"), "ERI")

  // Another station's contact is not theirs. A host older than the history
  // filters answers the latest contacts it has; the callsign is checked again
  // here so such an answer cannot put somebody else's county in the field.
  assert.equal(loggedExchangeFor([entry("K2XYZ", "ALB"), entry("K1ABC", "ERI")], "K1ABC"), "ERI")
  assert.equal(loggedExchangeFor([entry("K2XYZ", "ALB")], "K1ABC"), "")
})

test("an exchange from an earlier running of the party is offered only while it still holds", () => {
  const ny = party("NY")
  const us = exchangeOptionsFor(ny, qso({ entityPrefix: "K" }))
  const holds = (location: string, guessedState = "") => pastExchangeHolds(ny, us, guessedState, location)

  // Their county from last year, and the lookup still puts them in New York.
  assert.equal(holds("ERI", "NY"), true)
  assert.equal(holds("ERI/CHA", "NY"), true, "a county line holds when every county does")
  // Nothing known about where they are now: the county is all there is.
  assert.equal(holds("ERI"), true)

  // They moved. The lookup says Pennsylvania now, so last year's New York
  // county is not what they will send — their state is.
  assert.equal(holds("ERI", "PA"), false)
  assert.equal(holds("PA", "PA"), true)
  assert.equal(holds("NJ", "PA"), false, "a state they left is no better than a county they left")

  // Not this party at all. Past runnings are found by the party key as a
  // PREFIX, and `NE` — Nebraska — is a prefix of `NEQP`, New England. The
  // answer does not say which operation a contact came from, so a code this
  // party does not offer is the tell.
  const ne = party("NE")
  const neOptions = exchangeOptionsFor(ne, qso({ entityPrefix: "K" }))
  const newEngland = Object.keys(party("NEQP").counties).find((code) => ne.counties[code] === undefined)!
  assert.equal(pastExchangeHolds(ne, neOptions, "", newEngland), false)

  // And the party's own state is not an exchange here, whatever it was there.
  assert.equal(holds("NY", "NY"), false)
})

test("an earlier running is consulted only through the check, and this operation not at all", () => {
  // The check is what `loggedExchangeFor` is handed for past runnings: the
  // first exchange that still holds wins, newest first.
  const entry = (location: string) => ({ their: { call: "K2ABC" }, band: "20m", refs: [{ type: "qp", location }] }) as Record<string, JSONValue>
  const ny = party("NY")
  const us = exchangeOptionsFor(ny, qso({ entityPrefix: "K" }))
  const past = [entry("ERI"), entry("ALB")]
  assert.equal(
    loggedExchangeFor(past, "K2ABC", (l) => pastExchangeHolds(ny, us, "PA", l)),
    "",
  )
  assert.equal(
    loggedExchangeFor(past, "K2ABC", (l) => pastExchangeHolds(ny, us, "NY", l)),
    "ERI",
  )
  // Unchecked, as this operation's history is: the operator just copied it.
  assert.equal(loggedExchangeFor(past, "K2ABC"), "ERI")
})

test("the declared entry classes become the Cabrillo CATEGORY lines", () => {
  // The reason the classes are captured at all: a submitted log declares its
  // entry in these lines, and a checker reads them rather than guessing.
  const op = (ref: Record<string, JSONValue>) => ({ uuid: "op", stationCall: "N0DEV", refs: [{ type: "qp", ref: "NY", ...ref }] })
  const lines = (ref: Record<string, JSONValue>) => Object.fromEntries(cabrilloCategories(party("NY"), op(ref)).filter(([, v]) => v))

  assert.deepEqual(lines({ operator: "SINGLE-OP", power: "LOW", station: "MOBILE", mode: "CW" }), {
    "CATEGORY-OPERATOR": "SINGLE-OP",
    "CATEGORY-POWER": "LOW",
    "CATEGORY-STATION": "MOBILE",
    "CATEGORY-MODE": "CW",
  })

  // Cabrillo keeps the transmitter count apart from the operator class, while
  // sponsors publish them as one ("Multi-Single"), so it splits on the way out.
  assert.deepEqual(lines({ operator: "MULTI-ONE" }), {
    "CATEGORY-OPERATOR": "MULTI-OP",
    "CATEGORY-TRANSMITTER": "ONE",
  })
  assert.equal(lines({ operator: "MULTI-UNLIMITED" })["CATEGORY-TRANSMITTER"], "UNLIMITED")

  // Phone is SSB in a Cabrillo header, and digital is DIGI.
  assert.equal(lines({ mode: "PHONE" })["CATEGORY-MODE"], "SSB")
  assert.equal(lines({ mode: "DIGITAL" })["CATEGORY-MODE"], "DIGI")

  // An unanswered question emits NO line: an omitted category is "no claim",
  // while a guessed one is a claim the operator never made.
  assert.deepEqual(lines({}), {})

  // A class the party does not publish is refused rather than submitted — NY
  // has no EOC class, and a value left behind by another party must not reach
  // a checker under this one.
  assert.deepEqual(lines({ station: "EOC" }), {})
})

test("the file and the scoreboard agree about a blank exchange, both ways", () => {
  // The scorer remembers what a station sent the first time, so a second
  // contact on another band scores under that county. The export was reading
  // the ref raw and wrote NO row for it — a file claiming fewer contacts than
  // the scoreboard.
  const lastLocation: Record<string, string> = {}
  const first = cabrilloRowsFor(party("NY"), qso({ location: "ERI" }), operation("ALB"), "N0DEV", { lastLocation })
  assert.equal(first.length, 1)
  const second = cabrilloRowsFor(party("NY"), qso({}), operation("ALB"), "N0DEV", { lastLocation })
  assert.equal(second.length, 1, "the remembered county carries the second contact")
  assert.equal(second[0][5].trim(), "ERI")

  // And the other direction: an exchange that resolves to nothing scores zero
  // with `invalidExchange`, so no row may be written for it either.
  assert.deepEqual(cabrilloRowsFor(party("NY"), qso({ location: "XYZ" }), operation("ALB"), "N0DEV"), [])
})

test("both files write what the station SENT, which is not always what it scores as", () => {
  // Thirteen parties log a DX station by its entity prefix while it still
  // scores as the single `DX` multiplier. Every prefix used to resolve to `DX`
  // before the file was written, so the Cabrillo wrote `DX`, the ADIF wrote
  // `DL`, and the option those parties set changed nothing at all.
  const wa = { uuid: "op", stationCall: "N0DEV", refs: [{ type: "qp", ref: "WA", location: "KING" }] }
  const dx = qso({ location: "", entityPrefix: "DL", call: "DL1ABC" })
  assert.equal(theirLocationForFile(party("WA"), dx, { weAreInParty: true }), "DL")
  const rows = cabrilloRowsFor(party("WA"), dx, wa, "N0DEV")
  assert.equal(rows[0][5].trim(), "DL", "the Cabrillo says what the ADIF says")

  // A party that logs them as plain `DX` still gets `DX`.
  assert.equal(theirLocationForFile(party("NY"), dx, { weAreInParty: true }), "DX")
})

test("the ADIF and the Cabrillo agree about a remembered exchange", () => {
  // The scorer and the Cabrillo both score a blank exchange under the county
  // that station gave the first time. `adifFields` sees one contact at a time
  // and cannot know that — so our own export resolves the whole log up front
  // and hands the answers over.
  const first = { ...qso({ location: "ERI" }), uuid: "q1" }
  const second = { ...qso({}), uuid: "q2", band: "40m" }
  const resolved = resolvedExchanges(party("NY"), operation("ALB"), [first, second])
  assert.equal(resolved.q1, "ERI")
  assert.equal(resolved.q2, "ERI", "the second contact carries the county from the first")
  // Event rows and deleted contacts are not contacts.
  const withNoise = resolvedExchanges(party("NY"), operation("ALB"), [first, { band: "event", uuid: "e1" }, { ...second, deleted: true }])
  assert.deepEqual(Object.keys(withNoise), ["q1"])
})

test("the file claims no contact the scoreboard refused, and learns nothing from one", () => {
  // A 30m contact scores `invalidBand` at zero. It used to be written into the
  // Cabrillo anyway — and worse, its exchange was remembered, so the next blank
  // exchange from that station resolved in the file to a county the scoresheet
  // had never recorded.
  assert.equal(claimableBand("20m"), true)
  assert.equal(claimableBand("30m"), false)
  assert.equal(claimableBand(""), false)

  const lastLocation: Record<string, string> = {}
  const warc = { ...qso({ location: "ERI" }), band: "30m" }
  assert.deepEqual(cabrilloRowsFor(party("NY"), warc, operation("ALB"), "N0DEV", { lastLocation }), [])
  assert.deepEqual(lastLocation, {}, "a refused contact teaches the file nothing")

  // And the same station on a legal band with a blank exchange is therefore
  // unclaimable too, exactly as the scorer sees it.
  assert.deepEqual(cabrilloRowsFor(party("NY"), qso({}), operation("ALB"), "N0DEV", { lastLocation }), [])
})

test("a party that exchanges sections offers, and files, sections", () => {
  const pa = party("PA")
  const paOperation = (location: string): Record<string, JSONValue> => ({ uuid: "op", stationCall: "N0DEV", refs: [{ type: "qp", ref: "PA", location }] })
  // The field validates against this list, so a state left in it is an
  // exchange the operator is told is fine and the sponsor then rejects.
  const us = exchangeOptionsFor(pa, qso({ entityPrefix: "K" })).map((option) => option.code)
  assert.ok(us.includes("ELK") && us.includes("EMA") && us.includes("MDC") && us.includes("CT"))
  for (const state of ["CA", "NY", "MD", "DC"]) assert.equal(us.includes(state), false, `${state} is offered`)
  // A section INSIDE Pennsylvania is as unsendable as the state is elsewhere:
  // its stations send a county. A plain `partyStates` comparison misses these,
  // because a section lies in a state without sharing its code.
  assert.equal(us.includes("EPA"), false)
  assert.equal(us.includes("WPA"), false)
  const ve = exchangeOptionsFor(pa, qso({ entityPrefix: "VE" })).map((option) => option.code)
  assert.ok(ve.includes("GH") && ve.includes("TER"))
  assert.equal(ve.includes("ON"), false)

  // The file says what the scoreboard scored: the section as sent, and nothing
  // for a state or for a section inside Pennsylvania.
  assert.ok(cabrilloRowsFor(pa, qso({ location: "ema" }), paOperation("ELK"), "N0DEV")[0].some((cell) => cell.trim() === "EMA"))
  assert.deepEqual(cabrilloRowsFor(pa, qso({ location: "CA" }), paOperation("ELK"), "N0DEV"), [])
  assert.deepEqual(cabrilloRowsFor(pa, qso({ location: "EPA" }), paOperation("ELK"), "N0DEV"), [])
  // An untyped Puerto Rican station is `PR`, not the DX multiplier.
  assert.equal(defaultTheirLocation(pa, qso({ call: "KP4AA", entityPrefix: "KP4" })), "PR")
  assert.equal(defaultTheirLocation(pa, qso({ call: "KH6AA", entityPrefix: "KH6" })), "PAC")
  // Our own section reaches the file as typed.
  assert.ok(cabrilloRowsFor(pa, qso({ location: "ELK" }), paOperation("EMA"), "N0DEV")[0].some((cell) => cell.trim() === "EMA"))
})

test("the guess floats SECTIONS where the exchange is a section", () => {
  // A lookup answers with a state and the field holds sections, so ranking by
  // the state ranks a code that is not in the list — the guess silently stops
  // floating anything, which is the failure `guessedStateOf` warns about.
  assert.deepEqual(preferredCodesFor(party("PA"), "MA").sort(), ["EMA", "WMA"])
  // All nine of California's, since no lookup can say which one they are in.
  // Nine and not ten: `PAC` sits in the sponsor's W6 column by call area, but
  // it is Hawaii and the Pacific islands, so it belongs to no state here.
  assert.deepEqual(preferredCodesFor(party("PA"), "CA").sort(), ["EB", "LAX", "ORG", "SB", "SCV", "SDG", "SF", "SJV", "SV"])
  assert.deepEqual(preferredCodesFor(party("PA"), "HI"), ["PAC"])
  // A guess of Pennsylvania itself floats the counties and never `EPA`/`WPA`,
  // which the field does not offer.
  const home = preferredCodesFor(party("PA"), "PA")
  assert.ok(home.includes("ELK"))
  assert.deepEqual(
    home.some((code) => code === "EPA" || code === "WPA"),
    false,
  )
})

test("an exchange from an earlier running still holds when the party speaks sections", () => {
  // What was stored is a SECTION and what the lookup answers is a STATE, so a
  // bare comparison never matches and the prefill is dead for every
  // out-of-state station — the great majority of a PAQP log, and the feature
  // the entry row advertises.
  const pa = party("PA")
  const options = exchangeOptionsFor(pa, qso({ entityPrefix: "K" }))
  assert.equal(pastExchangeHolds(pa, options, "MA", "EMA"), true)
  assert.equal(pastExchangeHolds(pa, options, "", "EMA"), true)
  // A station who has since moved is still refused: `EMA` is not in Ohio.
  assert.equal(pastExchangeHolds(pa, options, "OH", "EMA"), false)
  // And a code this party does not offer at all never holds.
  assert.equal(pastExchangeHolds(pa, options, "MA", "MA"), false)
})

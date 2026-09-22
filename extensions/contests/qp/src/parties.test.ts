// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The party files are hand-maintained and inconsistent, and `parties.ts` is the
// one place that absorbs it. These tests hold it to the shapes that are
// actually in the 49 files — so a re-sync that introduces a fourth spelling of
// the power table fails here rather than silently scoring nothing.

import { test } from "node:test"
import assert from "node:assert/strict"

import manifest from "../manifest.json" with { type: "json" }
import {
  daysUntil,
  hasAlreadyRun,
  PARTIES,
  parsePartyTime,
  partyFor,
  pointsForMode,
  scoringModeFor,
  setupOrderOf,
  stateForCounty,
  SUPPORTED_PARTIES,
} from "./parties.ts"

function party(key: string) {
  const found = partyFor(key)
  assert.ok(found, `no party ${key}`)
  return found
}

test("every party a user can run is findable by name, code and short name", () => {
  // The manifest's keywords are how an operator reaches an extension that is
  // switched OFF — "nyqp", "new york", "salmon run" all have to surface it, or
  // the party is only findable by knowing the extension exists first. Matched
  // the way `ExtensionInfo.matchesSearch` does: a keyword CONTAINS the query.
  const keywords = manifest.keywords.map((keyword) => keyword.toLowerCase())
  const finds = (needle: string) => keywords.some((keyword) => keyword.includes(needle.toLowerCase()))

  for (const party of SUPPORTED_PARTIES) {
    assert.ok(finds(party.name), `no keyword finds ${party.name}`)
    assert.ok(finds(party.short), `no keyword finds ${party.short}`)
    assert.ok(finds(party.key), `no keyword finds ${party.key}`)
  }
  // And the words for the thing itself, which name no party in particular.
  for (const generic of ["qso party", "qso parties", "county", "cabrillo"]) {
    assert.ok(finds(generic), `no keyword finds ${generic}`)
  }
})

test("every party file loads, and each is reachable by key in any case", () => {
  assert.equal(PARTIES.length, 50)
  assert.equal(partyFor("ny")?.name, "New York QSO Party")
  assert.equal(partyFor(" NY ")?.key, "NY")
  assert.equal(partyFor("ZZ"), undefined)
})

test("a placeholder or disabled party is not offered", () => {
  // NSARA is marked disabled in the data, and its own contest page is gone.
  // Offering a party with no county list produces an operation that scores
  // every contact zero without ever saying why.
  assert.equal(party("NS").supported, false)
  assert.equal(party("NY").supported, true)
  assert.ok(SUPPORTED_PARTIES.length < PARTIES.length)
  assert.ok(SUPPORTED_PARTIES.every((p) => Object.keys(p.counties).length > 0))
})

test("the short name is the sponsor's where they have one", () => {
  assert.equal(party("NY").short, "NYQP")
  assert.equal(party("7QP").short, "7QP")
  assert.equal(party("NEQP").short, "NEQP")
  // No `short` in the file: the state key with QP appended.
  assert.equal(party("AL").short, "ALQP")
})

test("dates parse whatever the files spell them as", () => {
  // Unpadded month and day, and a lowercase Z, both of which appear.
  assert.equal(parsePartyTime("2026-5-2 13:00Z"), Date.UTC(2026, 4, 2, 13, 0))
  assert.equal(parsePartyTime("2026-04-30 12:00z"), Date.UTC(2026, 3, 30, 12, 0))
  // Anything unparseable is 0 — "no date", not 1970, which is what the
  // ranking and the info panel read it as.
  assert.equal(parsePartyTime("soon"), 0)
  assert.equal(parsePartyTime(undefined), 0)
})

test("a second operating period is kept, and separate from the first", () => {
  // 14 files run two sessions with a break between. One range spanning both
  // would claim the overnight hours the sponsor does not score.
  const fl = party("FL")
  assert.ok(fl.secondStartMillis && fl.secondEndMillis)
  assert.ok(fl.secondStartMillis > fl.endMillis)
  assert.equal(party("NY").secondStartMillis, undefined)
})

test("a URL with a space in it is repaired, not passed through", () => {
  // qc.json carries `https: //quebecqsoparty.org/`, which would reach the
  // information panel as a link that cannot open.
  assert.equal(party("QC").url, "https://quebecqsoparty.org/")
})

test("all three spellings of the power table, on both class vocabularies", () => {
  // `powerMultiplier` with LP/HP (DE), `powerMultipliers` with LOW/HIGH (KY),
  // and `power` (FL). Reading them apart would leave DE's low-power entrant
  // multiplying by 1 while KY's multiplied by 2, for no reason an operator
  // could see.
  assert.deepEqual(party("DE").powerMultipliers, { QRP: 3, LOW: 2, HIGH: 1 })
  assert.deepEqual(party("KY").powerMultipliers, { QRP: 3, LOW: 2, HIGH: 1 })
  assert.deepEqual(party("FL").powerMultipliers, { QRP: 3, LOW: 2, HIGH: 1 })
  assert.deepEqual(party("NY").powerMultipliers, {})
})

test("DIGI is DATA: the mode a party writes is not the mode a QSO carries", () => {
  // 7QP publishes `DIGI: 4` and a digital QSO's super-mode is `DATA`, so polo
  // never found it and paid the fallback point instead.
  assert.equal(pointsForMode(party("7QP"), "DATA"), 4)
  assert.equal(pointsForMode(party("7QP"), "CW"), 3)
  // An unlisted mode is worth one point, not none: no party lists every mode
  // it allows, and zeroing a contact is a claim this port has no source for.
  assert.equal(pointsForMode(party("AL"), "DATA"), 1)
})

test("a party that counts digital as CW says so once, for every rule", () => {
  assert.equal(scoringModeFor(party("LA"), "DATA"), "CW")
  assert.equal(scoringModeFor(party("NY"), "DATA"), "DATA")
})

test("the two options whose default is TRUE are not read as false when absent", () => {
  // Almost every file omits them, and they mean "counties ARE multipliers" —
  // the ordinary case. Reading an absent key as false would take every county
  // multiplier away from 45 parties.
  assert.equal(party("NY").options.countiesCountForInState, true)
  assert.equal(party("NY").options.countiesAreMultForInState, true)
  assert.equal(party("ACQP").options.countiesCountForInState, false)
  assert.equal(party("NEQP").options.countiesAreMultForInState, false)
})

test("an option written as an explicit null means no", () => {
  // bc.json writes `bonusPerBandMode: null`, which a `?? false` at the call
  // site would leave as null and a truthiness test would get right by luck.
  assert.equal(party("BC").options.bonusPerBandMode, false)
})

test("a county knows its state, three different ways", () => {
  // A multi-state party carries the table…
  assert.equal(stateForCounty(party("CPQP"), "MBBRA"), "MB")
  // …a long abbreviation carries its state in its first two characters…
  assert.equal(stateForCounty(party("7QP"), "ORDES"), "OR")
  // …and a short one belongs to the party whose key IS its state.
  assert.equal(stateForCounty(party("NY"), "ALB"), "NY")
})

test("the setup list is ordered by when a party runs, at any date", () => {
  // Two clocks, because the second is where the ordering has actually been
  // wrong twice: for a few weeks each year every file is out of date, and the
  // stale-vs-stale tiebreak becomes the whole list.
  const order = (nowMillis: number) => [...SUPPORTED_PARTIES].sort((a, b) => setupOrderOf(a, nowMillis) - setupOrderOf(b, nowMillis))

  // A moment when some parties are still to come: they all sit above the ones
  // whose files are out of date, soonest first.
  const midYear = Date.UTC(2026, 5, 1)
  const byRelevance = order(midYear)
  const firstStale = byRelevance.findIndex((party) => hasAlreadyRun(party, midYear))
  assert.ok(firstStale > 0, "some parties are still to come on this date")
  assert.ok(byRelevance.slice(0, firstStale).every((party) => !hasAlreadyRun(party, midYear)))
  assert.ok(byRelevance.slice(firstStale).every((party) => hasAlreadyRun(party, midYear)))
  for (let i = 1; i < firstStale; i++) {
    assert.ok(daysUntil(byRelevance[i - 1], midYear) <= daysUntil(byRelevance[i], midYear))
  }

  // And a moment long after every file has expired — the top of the list is the
  // party that ran most RECENTLY, not the one most out of date. Ordering the
  // stale half by days-until puts the oldest file first, which is the bug this
  // list was fixed for and which comes back here if the tiebreak is dropped.
  const longAfter = Date.UTC(2028, 0, 1)
  const byRecency = order(longAfter)
  assert.ok(
    byRecency.every((party) => hasAlreadyRun(party, longAfter)),
    "every file is stale by then",
  )
  for (let i = 1; i < byRecency.length; i++) {
    assert.ok(
      daysUntil(byRecency[i - 1], longAfter) >= daysUntil(byRecency[i], longAfter),
      `${byRecency[i - 1].key} ran longer ago than ${byRecency[i].key} and sorted above it`,
    )
  }
})

test("a date the calendar does not have is refused, not rolled forward", () => {
  // `sc.json` used to end on `2025-2-29`, which 2025 does not have, and
  // `Date.UTC` turns that into 1 March — an operator would read a period the
  // sponsor never published. The file is fixed; the guard stays, because the
  // next re-sync is where the next such typo arrives.
  assert.equal(parsePartyTime("2025-2-29 01:59Z"), 0)
  assert.equal(parsePartyTime("2028-2-29 01:59Z"), Date.UTC(2028, 1, 29, 1, 59), "but a real 29 February is a date")
  assert.equal(parsePartyTime("2026-13-01 00:00Z"), 0)
  assert.equal(parsePartyTime("2026-4-31 00:00Z"), 0)
})

test("a party with no usable end date is still known to have run", () => {
  // A file whose end date is missing or refused falls back to its START, or a
  // single bad date would float a year-old party to the top of the setup list
  // as though it had never run.
  const stale = { ...party("NY"), endMillis: 0, secondEndMillis: undefined }
  assert.equal(hasAlreadyRun(stale, Date.UTC(2027, 0, 1)), true)
})

test("every shipped party has dates the parser accepts", () => {
  // The whole point of refusing an impossible date is that it shows up HERE,
  // as a party with no dates, rather than as a plausible wrong one in front of
  // an operator.
  for (const party of SUPPORTED_PARTIES) {
    assert.ok(party.startMillis > 0, `${party.key} has no start date`)
    assert.ok(party.endMillis > 0, `${party.key} has no end date`)
    assert.ok(party.endMillis > party.startMillis, `${party.key} ends before it starts`)
    if (party.secondStartMillis) {
      assert.ok(party.secondEndMillis && party.secondEndMillis > party.secondStartMillis, `${party.key}'s second period is malformed`)
      assert.ok(party.secondStartMillis >= party.endMillis, `${party.key}'s second period overlaps its first`)
    }
  }
})

test("a slashed zero is a zero, so Missouri's bonus stations can be worked", () => {
  // `mo.json` writes `WØMA` and `KØGQ` with U+00D8, the slashed zero hams write
  // by hand. A logged callsign carries a digit, so the lookup never matched and
  // neither 100-point bonus could be claimed at all.
  assert.equal(party("MO").bonusStations.W0MA, 100)
  assert.equal(party("MO").bonusStations.K0GQ, 100)
})

test("the exchange is a location unless the file says otherwise", () => {
  assert.deepEqual(party("NY").exchange, { number: false, name: false })
  assert.deepEqual(party("CA").exchange, { number: true, name: false })
  assert.deepEqual(party("PA").exchange, { number: true, name: false })
  assert.deepEqual(party("MN").exchange, { number: false, name: true })
})

test("South Dakota submits as SDQSOP, the registered Cabrillo name", () => {
  // polo's file assumes `SD-QSO-PARTY` because the sponsor names nothing; the
  // Cabrillo registry lists `SDQSOP`. A re-sync that copies polo's file over
  // renames the contest in every submitted log, with no other test noticing.
  assert.equal(party("SD").cabrilloName, "SDQSOP")
})

test("every party offered keys its counties by CODE, which the state rules read", () => {
  // `stateForCounty` reads a county code longer than four characters as its
  // state's two letters plus the county's — right for 7QP's `ORDES`, and
  // nonsense for a file keyed by NAMES: `Cape Breton` reads as `CA`, and
  // `partyStates` then reports California as the party's own ground. Every
  // reader of that set inherits the mistake — the entry row stops offering
  // California, and the scorer refuses it as an exchange.
  //
  // NSARA is keyed that way and ships disabled, which is the only reason
  // nothing is broken today. This is the gate for the day it is enabled, or
  // another file is written the same way.
  for (const party of SUPPORTED_PARTIES) {
    for (const code of Object.keys(party.counties)) {
      assert.match(code, /^[A-Z0-9]{2,6}$/, `${party.key} keys a county as ${JSON.stringify(code)}`)
    }
  }
})

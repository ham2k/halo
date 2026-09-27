// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// QSO-party scoring. Two kinds of test here, and the second kind is the point:
//
//   * the ordinary business — points by mode, multipliers, duplicates;
//   * the rules that only ONE party has, which is where a port silently loses
//     things. Every option a shipped file sets is exercised against the party
//     that sets it, so a re-sync that renames one fails here rather than
//     quietly scoring nothing (ID's bonus stations, NC's rare counties, CO's
//     rover bonus, SC's doubled points, NEQP's state multipliers).
//
// The rover cases are M10's own subject: our county comes from the ref handed
// to `scoreQso`, which the harness resolves per segment, so "we moved" is
// modelled here by scoring later QSOs against a different ref.

import { test } from "node:test"
import assert from "node:assert/strict"

import type { JSONValue } from "@ham2k/extension-sdk"

import { ourPowerClass } from "./entry.ts"
import { multiplierPrefix, QsoPartyScorer, type QpScoresheet } from "./scorer.ts"
import { partyFor } from "./parties.ts"
import { CANADIAN_PROVINCES, US_STATES } from "./locations.ts"

const ctx = { online: false } as never

interface QsoSpec {
  call?: string
  band?: string
  mode?: string
  /// What they sent us.
  location?: string
  entityPrefix?: string
  state?: string
}

function qso({ call = "K1ABC", band = "20m", mode = "CW", location, entityPrefix = "K", state }: QsoSpec = {}): Record<string, JSONValue> {
  return {
    their: { call, ...(entityPrefix ? { entityPrefix } : {}), ...(state ? { state } : {}) },
    band,
    mode,
    ...(location !== undefined ? { refs: [{ type: "qp", location }] } : {}),
  }
}

interface RunOptions {
  party?: string
  /// Where WE are. A list models a rover: the nth QSO is scored against the
  /// nth location, the last one standing for the rest.
  ourLocation?: string | string[]
  mobile?: boolean
  power?: string
  station?: string
}

function run(qsos: Record<string, JSONValue>[], { party = "NY", ourLocation = "ALB", mobile, power, station }: RunOptions = {}) {
  const locations = Array.isArray(ourLocation) ? ourLocation : [ourLocation]
  const refFor = (index: number): Record<string, JSONValue> => ({
    type: "qp",
    ref: party,
    location: locations[Math.min(index, locations.length - 1)],
    ...(mobile ? { mobile } : {}),
    ...(power ? { power } : {}),
    ...(station ? { station } : {}),
  })
  const operation: Record<string, JSONValue> = { uuid: "op", stationCall: "N0DEV", refs: [refFor(0)] }

  let sheet: QpScoresheet = QsoPartyScorer.startScoresheet({ operation, ref: refFor(0) }, ctx)
  const scores = qsos.map((q, index) => {
    const ref = refFor(index)
    const result = QsoPartyScorer.scoreQso({ scoresheet: sheet, qso: q, operation: { ...operation, refs: [ref] }, ref, isNewDay: false }, ctx)
    sheet = result.scoresheet
    return result.score
  })
  const summary = (scope: "operation" | "day" = "operation") => QsoPartyScorer.summarizeScore({ scoresheet: sheet, operation, ref: refFor(0), scope }, ctx).qp
  return { sheet, scores, summary }
}

test("points come from the mode, per party", () => {
  // New York: 1 phone, 2 CW, 3 data.
  assert.equal(run([qso({ mode: "SSB", location: "ERI" })]).scores[0].value, 1)
  assert.equal(run([qso({ mode: "CW", location: "ERI" })]).scores[0].value, 2)
  assert.equal(run([qso({ mode: "FT8", location: "ERI" })]).scores[0].value, 3)
})

test("a county line is worth every pairing of counties — the N×M this milestone is for", () => {
  // Both of us on a line: four contacts in one exchange, and four multipliers.
  const { scores, sheet } = run([qso({ location: "ERI/CHA" })], { ourLocation: "ALB/REN" })
  assert.equal(scores[0].value, 2 * 2 * 2)
  assert.deepEqual(Object.keys(sheet.mults).sort(), ["CHA", "ERI", "NY"])
})

test("the WARC bands do not count, and neither does a QSO with no band", () => {
  assert.deepEqual(run([qso({ band: "30m", location: "ERI" })]).scores[0].alerts, ["invalidBand"])
  assert.deepEqual(run([qso({ band: "", location: "ERI" })]).scores[0].alerts, ["invalidBand"])
})

test("nothing scores until the operator says where WE are", () => {
  // Every contact is worth ours × theirs, so with no county of our own the
  // whole log is zero — and silently, unless it is said out loud.
  const { scores } = run([qso({ location: "ERI" })], { ourLocation: "" })
  assert.equal(scores[0].value, 0)
  assert.deepEqual(scores[0].alerts, ["ourLocation"])
})

test("an exchange that was never sent, and one that means nothing", () => {
  assert.deepEqual(run([qso({ location: "" })]).scores[0].alerts, ["missingExchange"])
  assert.deepEqual(run([qso({ location: "ZZZ", entityPrefix: "" })]).scores[0].alerts, ["invalidExchange"])
})

test("an exchange nobody typed is scored from what we know of where they are", () => {
  // Nothing was copied, so rather than refuse the contact both sides read the
  // state the QSO carries — `their.state` from an operator or an import, or the
  // lookup's own guess. Through `defaultTheirLocation`, the one function the
  // export reads too, so a contact cannot be scored under one location and
  // filed under another.
  const { scores, sheet } = run([qso({ location: "", state: "NJ" })])
  assert.equal(scores[0].value, 2)
  assert.deepEqual(scores[0].alerts, undefined)
  assert.deepEqual(Object.keys(sheet.mults), ["NJ"])

  // Their own state, in their own party. They send a COUNTY, so this is not
  // what they sent — but the alternative is refusing a contact that plainly
  // happened, and the operator can still type the county in. It is credited as
  // the state it resolves to, which is what the file will claim as well.
  const inState = run([qso({ location: "", state: "NY" })])
  assert.ok((inState.scores[0].value as number) > 0)
  assert.deepEqual(Object.keys(inState.sheet.mults), ["NY"])

  // The guess reaches it too, which is what a live QSO carries before the
  // operator touches the State field.
  const guessed = {
    their: { call: "W6ABC", entityPrefix: "K", guess: { state: "CA" } },
    band: "20m",
    mode: "CW",
    refs: [{ type: "qp", location: "" }],
  } as Record<string, JSONValue>
  assert.deepEqual(Object.keys(run([guessed]).sheet.mults), ["CA"])
})

test("a typo from a US station is a bad exchange, not a DX contact", () => {
  // polo ends its resolution with "any entity at all means DX", and `K` is an
  // entity — so a mistyped county for a US station scored, and in the twenty
  // parties that count DX entities separately it claimed a `DX:K` multiplier
  // and listed "K" among the entities worked.
  const { scores, sheet } = run([qso({ location: "ALBA" })])
  assert.equal(scores[0].value, 0)
  assert.deepEqual(scores[0].alerts, ["invalidExchange"])
  assert.deepEqual(sheet.entities, {})
  // A station in a country that is genuinely DX still resolves to DX.
  assert.ok(run([qso({ location: "ZZZ", entityPrefix: "DL" })]).scores[0].value > 0)
})

test("the state a county multiplies as is struck in the states table", () => {
  // NEQP scores an in-party contact by STATE, so the states checklist is where
  // the operator sees that Massachusetts is now had. Recording only the county
  // leaves it reading as still needed while the score already counts it.
  const { sheet } = run([qso({ location: "MAWOR" })], { party: "NEQP", ourLocation: "MABAR" })
  assert.equal(sheet.states.MA, 1)
  // Same for a party whose in-state entrants claim their own state on top of
  // the county (NY).
  assert.equal(run([qso({ location: "ERI" })]).sheet.states.NY, 1)
  // And a Canadian party's provinces land in the provinces table, not the
  // states one.
  const acqp = run([qso({ location: "NSANP", entityPrefix: "VE" })], { party: "ACQP", ourLocation: "NSCOL" })
  assert.equal(acqp.sheet.provinces.NS, 1)
  assert.deepEqual(acqp.sheet.states, {})
})

test("two out-of-party stations working each other is not a contest QSO", () => {
  // The party is between its own people and everyone else.
  const { scores } = run([qso({ location: "CT" })], { ourLocation: "NJ" })
  assert.equal(scores[0].value, 0)
})

test("a station with no exchange is scored under the county they gave last time", () => {
  // polo's `_defaultLocationFor`, folded into the pass: the second contact is
  // a different band, so it counts, and it counts as Erie.
  const { scores, sheet } = run([qso({ location: "ERI" }), qso({ band: "40m" })])
  assert.equal(scores[1].value, 2)
  assert.equal(sheet.counties.ERI, 2)
})

test("a repeat on the same band, mode and county is a duplicate", () => {
  const { scores, sheet } = run([qso({ location: "ERI" }), qso({ location: "ERI" })])
  assert.equal(scores[1].value, 0)
  assert.equal(scores[1].dupe, true)
  assert.deepEqual(scores[1].alerts, ["duplicate"])
  assert.equal(sheet.dupes, 1)
})

test("the same station on a new band or a new mode counts again, and says so", () => {
  const { scores } = run([qso({ location: "ERI" }), qso({ location: "ERI", band: "40m" }), qso({ location: "ERI", mode: "SSB" })])
  assert.ok(scores[1].notices?.includes("newBand"))
  assert.ok(scores[2].notices?.includes("newMode"))
  assert.equal(scores[1].value, 2)
})

test("a rover who moves may work the same station again, from the new county", () => {
  // This is what M10 means by rolling location: the second contact is scored
  // against the segment's ref, so the pair (our county, theirs) is new.
  const { scores } = run([qso({ location: "ERI" }), qso({ location: "ERI" })], {
    ourLocation: ["ALB", "REN"],
  })
  assert.equal(scores[1].value, 2)
  assert.equal(scores[1].dupe, undefined)
})

test("a rover activates each county they operate from", () => {
  const { sheet } = run([qso({ location: "ERI" }), qso({ location: "CHA" })], {
    ourLocation: ["ALB", "REN"],
  })
  assert.deepEqual(sheet.activatedCounties, { ALB: 1, REN: 1 })
})

test("a multiplier is claimed once, and the first claim says so", () => {
  const { scores, sheet } = run([qso({ location: "ERI" }), qso({ call: "K2DEF", location: "ERI" })])
  assert.ok(scores[0].notices?.includes("newMult"))
  assert.ok(!(scores[1].notices ?? []).includes("newMult"))
  assert.equal(Object.keys(sheet.mults).length, 2) // ERI and NY
})

test("an in-party station's own state multiplies alongside the county", () => {
  // NY sets `stateCountsForInState`, so working Erie from Albany is two
  // multipliers: the county, and New York itself.
  const { sheet } = run([qso({ location: "ERI" })])
  assert.deepEqual(Object.keys(sheet.mults).sort(), ["ERI", "NY"])
  // An out-of-party entrant gets the county alone.
  const outside = run([qso({ location: "ERI" })], { ourLocation: "NJ" })
  assert.deepEqual(Object.keys(outside.sheet.mults), ["ERI"])
})

test("multipliers per band, per mode, or once — whichever the party publishes", () => {
  const ny = partyFor("NY")!
  // NY publishes none of the per-band options: a multiplier is a multiplier.
  assert.equal(multiplierPrefix(ny, { band: "20m", mode: "CW", weAreInParty: true }), "")
  // OH counts them per mode, TN per band, SC per band AND mode.
  assert.equal(multiplierPrefix(partyFor("OH")!, { band: "20m", mode: "CW", weAreInParty: true }), "CW:")
  assert.equal(multiplierPrefix(partyFor("TN")!, { band: "20m", mode: "CW", weAreInParty: true }), "20m:")
  assert.equal(multiplierPrefix(partyFor("SC")!, { band: "20m", mode: "CW", weAreInParty: true }), "20m:CW:")
})

test("the side-specific per-band options apply to the side they name", () => {
  // polo tests `inStateMultsPerBand` in all three branches of the same
  // function, so HI could never reach the per-band branch and NH applied the
  // in-state rule to everyone.
  const nh = partyFor("NH")! // outOfStateMultsPerBand
  assert.equal(multiplierPrefix(nh, { band: "20m", mode: "CW", weAreInParty: false }), "20m:")
  assert.equal(multiplierPrefix(nh, { band: "20m", mode: "CW", weAreInParty: true }), "")
})

test("NEQP: an in-party pair multiplies by state, and the county is still logged", () => {
  const { sheet } = run([qso({ location: "MAWOR" })], { party: "NEQP", ourLocation: "MABAR" })
  assert.deepEqual(Object.keys(sheet.mults), ["MA"])
  assert.equal(sheet.counties.MAWOR, 1)
})

test("ACQP: the other spelling of the same rule multiplies by province", () => {
  // `countiesCountForInState: false` (ACQP, CPQP, DEQP) and
  // `countiesAreMultForInState: false` (NEQP) have the same description in
  // polo's own NOTES — one rule, two spellings — and polo converts the CODE for
  // one and only the multiplier for the other. Here the county is always what
  // was sent, and only what it multiplies changes.
  const { sheet } = run([qso({ location: "NSANP", entityPrefix: "VE" })], { party: "ACQP", ourLocation: "NSCOL" })
  assert.equal(sheet.counties.NSANP, 1)
  assert.deepEqual(
    Object.keys(sheet.mults).some((key) => key.includes("NSANP")),
    false,
  )
})

test("SC: an in-state station working out of state scores double", () => {
  const inside = run([qso({ location: "NC" })], { party: "SC", ourLocation: "ABBE" })
  const outside = run([qso({ location: "ABBE" })], { party: "SC", ourLocation: "NC" })
  assert.equal(inside.scores[0].value, 4)
  assert.equal(outside.scores[0].value, 2)
})

test("NC: a rare county multiplies the contact, and the sweep pays once", () => {
  const rare = ["CAB", "GRM", "VAN", "MAC", "DAV"]
  const one = run([qso({ location: "CAB" })], { party: "NC", ourLocation: "WAK" })
  assert.equal(one.scores[0].value, 3 * 10)
  assert.ok(one.scores[0].notices?.includes("rareCounty"))
  // Five rare counties is NC's published minimum for the sweep.
  const swept = run(
    rare.map((location, index) => qso({ call: `K${index}AAA`, location })),
    {
      party: "NC",
      ourLocation: "WAK",
    },
  )
  const points = swept.sheet.points
  // `bonusPostMultiplier`: NC adds its bonus after the multiplier, so the
  // sweep is not multiplied by the county count.
  assert.equal(swept.summary().total, points * Object.keys(swept.sheet.mults).length + 500)
})

test("ID: the bonus stations pay out-of-state entrants only, and sweep", () => {
  // `bonusStationInStateMult: 0` is how the file says "not for us".
  const stations = ["K7S", "K7P", "K7U", "K7D"]
  const outside = run(
    stations.map((call) => qso({ call, location: "ADA" })),
    {
      party: "ID",
      ourLocation: "WA",
    },
  )
  assert.equal(
    Object.values(outside.sheet.bonusStations).reduce((a, b) => a + b, 0),
    400,
  )
  assert.ok(outside.scores[0].notices?.includes("bonusStation"))
  // 400 for the four stations, plus the 100 sweep polo's accumulator never pays.
  const mult = Object.keys(outside.sheet.mults).length
  assert.equal(outside.summary().total, (outside.sheet.points + 500) * mult)

  const inside = run([qso({ call: "K7S", location: "ADA" })], { party: "ID", ourLocation: "BOI" })
  assert.deepEqual(inside.sheet.bonusStations, {})
})

test("a bonus station pays once, and again per band where the party says so", () => {
  // WV pays per band and mode; NY has no bonus stations at all.
  const wv = run([qso({ call: "W8WVA", location: "KAN" }), qso({ call: "W8WVA", location: "KAN", band: "40m" })], { party: "WV", ourLocation: "OH" })
  assert.equal(Object.keys(wv.sheet.bonuses).length, 2)
  assert.equal(wv.sheet.bonusStations.W8WVA, 200)
})

test("CO: the per-county bonus is for rovers, and only above the minimum", () => {
  // 15 QSOs from a county, 500 points — and nothing at all for a fixed station.
  const fifteen = (location: string) => Array.from({ length: 15 }, (_, index) => qso({ call: `K${index}AAA`, location }))

  const rover = run(fifteen("DEN"), { party: "CO", ourLocation: "ADA", mobile: true })
  assert.ok(rover.summary().total > 0)
  const bonusPart = rover.summary().total - rover.sheet.points * Object.keys(rover.sheet.mults).length
  assert.equal(bonusPart, 500)

  const fixed = run(fifteen("DEN"), { party: "CO", ourLocation: "ADA" })
  assert.equal(fixed.summary().total, fixed.sheet.points * Object.keys(fixed.sheet.mults).length)

  // One QSO short of the minimum earns nothing.
  const short = run(fifteen("DEN").slice(0, 14), { party: "CO", ourLocation: "ADA", mobile: true })
  assert.equal(short.summary().total, short.sheet.points * Object.keys(short.sheet.mults).length)
})

test("VA: our own county is a multiplier without working anyone in it", () => {
  const { sheet } = run([qso({ location: "MD" })], { party: "VA", ourLocation: "ALB" })
  assert.ok(Object.keys(sheet.mults).includes("ALB"))
})

test("IL: the DX entity cap limits the multipliers instead of erasing them", () => {
  // polo compares an undefined array length against the cap, so the five
  // parties that publish one award NO DX multipliers at all.
  const entities = ["DL", "F", "G", "I", "EA", "PA"]
  const { sheet } = run(
    entities.map((prefix, index) =>
      qso({
        call: `${prefix}1AA${index}`,
        location: "DX",
        entityPrefix: prefix,
      }),
    ),
    { party: "IL", ourLocation: "COOK" },
  )
  const dxMults = Object.keys(sheet.mults).filter((key) => key.includes("DX:"))
  // IL's cap is 5: the sixth entity is a valid contact worth points, and not
  // a sixth multiplier.
  assert.equal(dxMults.length, 5)
  assert.equal(Object.keys(sheet.entities).length, 6)

  // And a SECOND station in the over-cap entity does not sneak past it. The
  // exemption that keeps an established multiplier claimable has to test what
  // was CREDITED, not what was worked — testing the latter let the sixth
  // entity in on its second contact, one multiplier over a published cap.
  const twice = run(
    [...entities, "PA", "PA"].map((prefix, index) =>
      qso({
        call: `${prefix}1AA${index}`,
        location: "DX",
        entityPrefix: prefix,
      }),
    ),
    { party: "IL", ourLocation: "COOK" },
  )
  assert.equal(Object.keys(twice.sheet.mults).filter((key) => key.includes("DX:")).length, 5)
})

test("DE: a declared power class multiplies the score, and no claim multiplies by one", () => {
  // polo reads none of the four published power tables.
  const qrp = run([qso({ location: "NJ" })], { party: "DE", ourLocation: "NDE", power: "QRP" })
  const undeclared = run([qso({ location: "NJ" })], { party: "DE", ourLocation: "NDE" })
  assert.equal(qrp.summary().total, undeclared.summary().total * 3)
})

// A party is one period, however many UTC days it straddles: the sponsors
// publish one total, and a day's share of it is not a number they define.
test("a party is one period: it offers no per-day summary", () => {
  const { summary } = run([qso({ location: "ERI" }), qso({ call: "K2DEF", location: "CHA" })])
  assert.equal(summary("day"), undefined)
})

test("the summary is titled with the event and its total, and opens on the arithmetic", () => {
  const { summary } = run([qso({ mode: "CW", location: "ERI" }), qso({ call: "K2DEF", mode: "CW", location: "CHA" })])
  const tally = summary()
  // The label is what the information panel shows as the section title — and
  // the only place the total is visible, since a tally with a `longSummary`
  // does not show its short `summary`.
  assert.equal(tally.label, `NYQP: ${tally.total} points`)
  // An in-state NYQP entrant's own state multiplies too, on top of the two
  // counties worked.
  assert.equal((tally.longSummary as string).split("\n")[0], `2 QSOs, ${tally.points} pts × 3 mults (2 counties, 1 state)`)
})

// Counties and states are different things to chase; the split says which
// the log is short of.
test("the arithmetic splits the multipliers by the kind of place", () => {
  const { summary } = run([qso({ location: "ERI" }), qso({ call: "K2DEF", location: "NJ" }), qso({ call: "DL1ABC", location: "DX" })], { ourLocation: "ALB" })
  // NY (our own, in-state) and NJ are states; ERI is a county; NYQP gives DX
  // no multiplier, so it names no kind.
  assert.match((summary().longSummary as string).split("\n")[0], /× 3 mults \(1 county, 2 states\)$/)
})

test("a party this build does not know scores nothing, and says which way it failed", () => {
  const { scores } = run([qso({ location: "ERI" })], { party: "ZZ" })
  assert.deepEqual(scores[0].alerts, ["unknownEvent"])
  // A disabled party is the same answer: it has no rules we can score under.
  assert.deepEqual(run([qso({ location: "ERI" })], { party: "NS" }).scores[0].alerts, ["unknownEvent"])
})

test("the summary lists what is still out there, not just what is done", () => {
  const { summary } = run([qso({ location: "ERI" })])
  const detail = summary().longSummary as string
  // Worked counties are struck through; the rest are there to be chased.
  assert.match(detail, /\*\*~~ERI~~\*\*/)
  assert.match(detail, /\bALB\b/)
  assert.equal(summary().grid, true)
})

test('"Mobile or Rover" is now the station class, and the old flag still counts', () => {
  // The checkbox existed because there was nowhere else to put the question.
  // Declaring Mobile or Rover is the same claim, and it has to earn the same
  // per-county bonus — while an operation logged before the classes existed,
  // or synced from polo, still carries the boolean.
  const fifteen = (location: string) => Array.from({ length: 15 }, (_, index) => qso({ call: `K${index}AAA`, location }))
  const bonusOf = (r: ReturnType<typeof run>) => r.summary().total - r.sheet.points * Object.keys(r.sheet.mults).length

  const byClass = run(fifteen("DEN"), { party: "CO", ourLocation: "ADA", station: "MOBILE" })
  assert.equal(bonusOf(byClass), 500)
  const byFlag = run(fifteen("DEN"), { party: "CO", ourLocation: "ADA", mobile: true })
  assert.equal(bonusOf(byFlag), 500)
  // A fixed station claims none of it.
  const fixed = run(fifteen("DEN"), { party: "CO", ourLocation: "ADA", station: "FIXED" })
  assert.equal(bonusOf(fixed), 0)
})

test("Maine prices a contact by which side the other station is on", () => {
  // "2 points per QSO with ME stations, 1 point per QSO with non-ME stations"
  // — the one published rule no per-mode points table can express.
  const inParty = run([qso({ location: "CBL" })], { party: "ME", ourLocation: "NH" })
  assert.equal(inParty.scores[0].value, 2)
  const outOfParty = run([qso({ location: "NH" })], { party: "ME", ourLocation: "CBL" })
  assert.equal(outOfParty.scores[0].value, 1)
})

test("Arizona and Maine score like the parties they are", () => {
  // Both were added from their sponsors' rules rather than ported, so their
  // basics are worth pinning: Arizona pays 2 for CW and 1 for phone, and its
  // bonus station pays 100.
  assert.equal(run([qso({ location: "PMA" })], { party: "AZ", ourLocation: "APH" }).scores[0].value, 2)
  assert.equal(run([qso({ location: "PMA", mode: "SSB" })], { party: "AZ", ourLocation: "APH" }).scores[0].value, 1)
  const bonus = run([qso({ call: "K7A", location: "PMA" })], { party: "AZ", ourLocation: "CA" })
  assert.equal(bonus.sheet.bonusStations.K7A, 100)
})

test("typing your STATE where your county belongs is said out loud", () => {
  // `NY` resolves cleanly to the state — no party's county codes collide with a
  // state code — so nothing else objects, and the whole log is quietly scored
  // under out-of-state rules: no own-state multiplier, no activated county, a
  // different multiplier key. The contact still counts; the operator is told.
  const typed = run([qso({ location: "ERI" })], { ourLocation: "NY" })
  assert.deepEqual(typed.scores[0].alerts, ["ourLocation"])
  assert.ok((typed.scores[0].value as number) > 0, "the contact still counts for what it is worth")

  // A county is what it should be, and says nothing.
  assert.equal(run([qso({ location: "ERI" })], { ourLocation: "ALB" }).scores[0].alerts, undefined)
  // And a genuine out-of-state entrant is not nagged about their own state.
  assert.equal(run([qso({ location: "ERI" })], { ourLocation: "NJ" }).scores[0].alerts, undefined)
  // Multi-state parties know all of their own states, not just one.
  assert.deepEqual(run([qso({ location: "ORDES" })], { party: "7QP", ourLocation: "UT" }).scores[0].alerts, ["ourLocation"])
})

test("a DX station is resolved from the callsign when nothing else knows", () => {
  // An imported or synced QSO carries no `guess`, so without the country file
  // the entity is unknown: the exchange resolves to nothing, the contact scores
  // `missingExchange`, and the DX multiplier the party publishes is never
  // claimed. `naqp` and `arrl-dx` already reach for the country file this way.
  const imported = {
    their: { call: "DL1ABC" },
    band: "20m",
    mode: "CW",
    refs: [{ type: "qp", location: "" }],
  } as Record<string, JSONValue>
  const { scores, sheet } = run([imported], { party: "IL", ourLocation: "COOK" })
  assert.ok((scores[0].value as number) > 0)
  assert.deepEqual(Object.keys(sheet.entities), ["DL"])
})

test("NH credits each DX entity up to its published cap", () => {
  // "Each NH county, each state, each VE province and up to 10 DXCC countries
  // once" — so each entity IS a multiplier there. Without the flag every DX
  // contact shared one `DX` key and the cap of 10 was inert, costing an NH
  // entrant up to nine multipliers.
  const entities = ["DL", "F", "G", "I", "EA", "PA", "ON4", "SM", "LA", "OZ", "SP", "HA"]
  const { sheet } = run(
    entities.map((prefix, index) =>
      qso({
        call: `${prefix}1AA${index}`,
        location: "DX",
        entityPrefix: prefix,
      }),
    ),
    { party: "NH", ourLocation: "BEL" },
  )
  const dxMults = Object.keys(sheet.mults).filter((key) => key.includes("DX:"))
  assert.equal(dxMults.length, 10, "ten credited, not one and not twelve")
  assert.equal(Object.keys(sheet.entities).length, 12, "all twelve worked")
})

test("a power class the party does not publish is not submitted under it", () => {
  // The setup form writes `ref` in place when the party changes, so a class
  // left behind by the previous one must be refused — as it is on every other
  // axis. Wisconsin publishes power classes; a party without them must not
  // inherit the answer.
  const wi = { type: "qp", ref: "WI", power: "QRP" } as Record<string, JSONValue>
  assert.equal(ourPowerClass(undefined, wi, partyFor("WI")!), "QRP")
  assert.equal(ourPowerClass(undefined, { ...wi, ref: "NV" }, partyFor("NV")!), undefined)
})

test("the band table counts CW, phone and digital apart, per band and in total", () => {
  const { summary } = run([
    qso({ band: "40m", mode: "CW", location: "ERI" }),
    qso({ call: "K2DEF", band: "40m", mode: "SSB", location: "CHA" }),
    qso({ call: "K3GHI", band: "20m", mode: "FT8", location: "ALB" }),
    qso({ call: "K4JKL", band: "160m", mode: "CW", location: "ALB" }),
  ])
  const lines = (summary().longSummary as string).split("\n")
  // Longest wavelength first, not alphabetical — which would file 160m
  // between 15m and 20m — and every mode named on every line, zeros included,
  // so an unworked mode reads as "0", not as an absence.
  assert.deepEqual(
    lines.filter((line) => /^\*\*(\d+m|All bands)\*\*/.test(line)),
    [
      "**160m**: 1 CW, 0 SSB, 0 Digital, **1 total**",
      "**40m**: 1 CW, 1 SSB, 0 Digital, **2 total**",
      "**20m**: 0 CW, 0 SSB, 1 Digital, **1 total**",
      "**All bands**: 2 CW, 1 SSB, 1 Digital, **4 total**",
    ],
  )
})

test("the band table separates digital from CW even where the party scores them as one mode", () => {
  // DE folds data into CW for multipliers and dupes; the table still tells the
  // operator which of the two they worked.
  const { summary } = run([qso({ mode: "FT8", location: "NJ" })], { party: "DE", ourLocation: "NDE" })
  assert.match(summary().longSummary as string, /\*\*20m\*\*: 0 CW, 0 SSB, 1 Digital, \*\*1 total\*\*/)
})

test("AZ: multipliers split by which side of the state line we are on", () => {
  // Out of state: a county counts again on every band and every mode.
  const outside = run([qso({ location: "MCP" }), qso({ location: "MCP", band: "40m" }), qso({ location: "MCP", band: "40m", mode: "SSB" })], {
    party: "AZ",
    ourLocation: "NY",
  })
  assert.deepEqual(Object.keys(outside.sheet.mults).sort(), ["20m:CW:MCP", "40m:CW:MCP", "40m:PHONE:MCP"])

  // In state: two Arizona counties on CW are one multiplier, Arizona itself —
  // and `stateCountsForInState` names the same one, not a second. A DX station
  // with no exchange is its entity, never a state that shares its prefix: `PA`
  // read as a location would be Pennsylvania.
  const inside = run(
    [
      qso({ location: "MCP" }),
      qso({ call: "K1ABD", location: "YMA" }),
      qso({ call: "K1ABE", location: "NY" }),
      qso({ call: "K1ABF", location: "NY", band: "40m" }),
      qso({ call: "PA3XYZ", entityPrefix: "PA" }),
    ],
    { party: "AZ", ourLocation: "PMA" },
  )
  assert.deepEqual(Object.keys(inside.sheet.mults).sort(), ["CW:AZ", "CW:DX:PA", "CW:NY"])
  assert.equal(inside.sheet.entities.PA, 1)
  assert.equal(inside.sheet.states.PA, undefined)

  // The county still identifies the station: the same one from the same county
  // is a repeat, and a mobile that has moved is a fresh contact worth points.
  const repeat = run([qso({ call: "K7XX", location: "MCP" }), qso({ call: "K7XX", location: "MCP" })], { party: "AZ", ourLocation: "PMA" })
  assert.equal(repeat.sheet.dupes, 1)
  const moved = run([qso({ call: "K7XX", location: "MCP" }), qso({ call: "K7XX", location: "YMA" })], { party: "AZ", ourLocation: "PMA" })
  assert.equal(moved.sheet.dupes, 0)
  assert.equal(moved.sheet.points, 4)

  // Total = (QSO points × multipliers) + bonus, with K7A worth 100 once.
  const bonus = run([qso({ call: "K7A", location: "MCP" }), qso({ call: "K7A", location: "MCP", band: "40m" })], { party: "AZ", ourLocation: "NY" })
  assert.equal(bonus.summary().total, 4 * 2 + 100)
})

test("PA: all DX is one multiplier, and K3ZMC pays per band after the multiplier", () => {
  const dx = run(
    ["DL", "F", "G"].map((prefix, index) => qso({ call: `${prefix}1AA${index}`, entityPrefix: prefix })),
    { party: "PA", ourLocation: "ELK" },
  )
  assert.deepEqual(Object.keys(dx.sheet.mults), ["DX"])

  // Each valid QSO with K3ZMC is worth 200, so a second band earns it again.
  const bonus = run([qso({ call: "K3ZMC", location: "MGY" }), qso({ call: "K3ZMC", location: "MGY", band: "40m" })], { party: "PA", ourLocation: "ELK" })
  assert.equal(bonus.sheet.bonusStations.K3ZMC, 400)
  // Two CW QSOs at 2 points, two multipliers (the county and its section),
  // then the bonus.
  assert.equal(bonus.sheet.points, 4)
  assert.equal(Object.keys(bonus.sheet.mults).length, 2)
  assert.equal(bonus.summary().total, 4 * 2 + 400)
})

test("PA: the summary lists the band/mode slots each bonus station has paid in", () => {
  // K3ZMC pays again on every band and mode, so a callsign struck after the
  // first contact reads as "done" while most of its 200s are still open.
  const { summary } = run([qso({ call: "K3ZMC", location: "MGY", band: "40m", mode: "SSB" }), qso({ call: "K3ZMC", location: "MGY", band: "80m" })], {
    party: "PA",
    ourLocation: "ELK",
  })
  assert.match(summary().longSummary as string, /\*\*~~K3ZMC~~\*\* \(80m CW, 40m SSB\)/)

  // Where a bonus pays once, there are no slots to list.
  const az = run([qso({ call: "K7A", location: "MCP" })], { party: "AZ", ourLocation: "NY" }).summary().longSummary as string
  assert.match(az, /\*\*~~K7A~~\*\*(?! \()/)
})

test("PA: an in-state entrant earns each county's section, EPA or WPA, as well as the county", () => {
  // Rule 12.d: the sponsor adds EPA and WPA when rescoring. Missing them
  // under-reports every in-state score by up to two multipliers.
  const inside = run([qso({ call: "K3AAA", location: "MGY" }), qso({ call: "K3BBB", location: "BUX" }), qso({ call: "K3CCC", location: "ALL" })], {
    party: "PA",
    ourLocation: "ELK",
  })
  assert.deepEqual(Object.keys(inside.sheet.mults).sort(), ["ALL", "BUX", "EPA", "MGY", "WPA"])
  assert.match(inside.summary().longSummary as string, /\*\*~~EPA~~\*\*/)

  // Out of state the multipliers are the 67 counties alone (rule 10.b).
  const outside = run([qso({ location: "MGY" })], { party: "PA", ourLocation: "EMA" })
  assert.deepEqual(Object.keys(outside.sheet.mults), ["MGY"])

  // Our own county earns nothing without working anyone: ELK sits in WPA, and
  // a log that only worked EPA must not claim it.
  const eastOnly = run([qso({ location: "MGY" })], { party: "PA", ourLocation: "ELK" })
  assert.deepEqual(Object.keys(eastOnly.sheet.mults).sort(), ["EPA", "MGY"])

  // A county line on the far side is two counties, and one section when both
  // lie in it.
  const line = run([qso({ location: "CAR/LEH" })], { party: "PA", ourLocation: "ELK" })
  assert.deepEqual(Object.keys(line.sheet.mults).sort(), ["CAR", "EPA", "LEH"])
})

test("SD and CA score as their sponsors publish for 2026", () => {
  // South Dakota: QSO Points × Multipliers + Bonus — W0OJY pays 100 once,
  // outside the multiplier.
  const sd = run([qso({ call: "W0OJY", location: "MINN" }), qso({ call: "W0OJY", location: "MINN", band: "40m" })], { party: "SD", ourLocation: "NY" })
  assert.equal(sd.summary().total, 4 * 1 + 100)
  // California: phone is worth 3 points from 2026, the same as CW.
  assert.equal(run([qso({ location: "ALAM", mode: "SSB" })], { party: "CA", ourLocation: "NY" }).scores[0].value, 3)
})

test("CA: an in-state contact multiplies as California, never as its county", () => {
  // CQP's in-state entrants chase states and provinces; a California county
  // is worth the CA multiplier and nothing more. Out of state, the counties
  // ARE the multipliers.
  const inside = run([qso({ location: "LASS" }), qso({ call: "K6XYZ", location: "SCRU" })], { party: "CA", ourLocation: "ALAM" })
  assert.deepEqual(Object.keys(inside.sheet.mults), ["CA"])
  const outside = run([qso({ location: "LASS" })], { party: "CA", ourLocation: "NY" })
  assert.deepEqual(Object.keys(outside.sheet.mults), ["LASS"])
})

test("CA: an in-state entrant's score counts 58 multipliers, and every one worked is still struck", () => {
  // 63 are workable from inside California — the 50 states and 13 provinces
  // and territories — and the sponsor counts 58. Capping what is RECORDED
  // instead would leave the chase list showing worked ones as still needed.
  const codes = [...Object.keys(US_STATES), ...Object.keys(CANADIAN_PROVINCES)].filter((code) => code !== "DC")
  assert.equal(codes.length, 63)
  // California itself is worked by working any county in it.
  const sent = (code: string) => (code === "CA" ? "LASS" : code)
  const qsos = codes.map((code, index) => qso({ call: `K${index}ABC`, location: sent(code), entityPrefix: CANADIAN_PROVINCES[code] ? "VE" : "K" }))
  const { sheet, summary } = run(qsos, { party: "CA", ourLocation: "ALAM" })
  assert.equal(Object.keys(sheet.mults).length, 63)
  assert.equal(summary().mults, 58)
  assert.equal(summary().total, 63 * 3 * 58)
  for (const code of codes) assert.ok(summary().longSummary?.includes(`~~${code}~~`), `${code} is struck`)
  // Out of state the cap does not apply: it is the in-state rule alone.
  assert.equal(run([qso({ location: "LASS" })], { party: "CA", ourLocation: "NY" }).summary().mults, 1)
})

test("a county line may run through more than two counties", () => {
  // Three-way county corners exist and CQP says to send them all. Each of our
  // counties pairs with each of theirs: 3×2 contacts.
  const { scores, sheet } = run([qso({ location: "ERI/CHA" })], { ourLocation: "ALB/REN/SAR" })
  assert.equal(scores[0].value, 3 * 2 * 2)
  assert.deepEqual(Object.keys(sheet.mults).sort(), ["CHA", "ERI", "NY"])
})

test("PA: a station outside Pennsylvania is worth its SECTION, and a state is not one", () => {
  // The sponsor's checker reads the ARRL/RAC list, so the score may only claim
  // what that list holds. The trap is a state table standing in for it: `CA`
  // and `NY` then score as one multiplier each where the rules have nine and
  // four, and `EMA` — a perfectly good exchange — scores zero as a typo.
  const worked = run(
    ["EMA", "WMA", "LAX", "SF", "MDC", "GH", "ONE", "CT"].map((location, index) =>
      qso({
        call: `K1AA${index}`,
        location,
        entityPrefix: location === "GH" || location === "ONE" ? "VE" : "K",
      }),
    ),
    { party: "PA", ourLocation: "ELK" },
  )
  assert.deepEqual(
    worked.scores.map((score) => score.value),
    [2, 2, 2, 2, 2, 2, 2, 2],
  )
  assert.deepEqual(Object.keys(worked.sheet.mults).sort(), ["CT", "EMA", "GH", "LAX", "MDC", "ONE", "SF", "WMA"])
  assert.deepEqual(Object.keys(worked.sheet.provinces).sort(), ["GH", "ONE"])

  // A state that is not also a section is a bad exchange — never a guess at
  // which of its sections was meant, and never the state multiplier.
  const states = run(
    ["CA", "NY", "MA", "MD", "DC", "ON"].map((location, index) =>
      qso({
        call: `K2AA${index}`,
        location,
        entityPrefix: location === "ON" ? "VE" : "K",
      }),
    ),
    { party: "PA", ourLocation: "ELK" },
  )
  for (const score of states.scores) assert.deepEqual(score.alerts, ["invalidExchange"])
  assert.deepEqual(states.sheet.mults, {})

  // Puerto Rico is a section, so an untyped KP4 is `PR` and not the DX
  // multiplier; Hawaii is in the Pacific section, not a state of its own.
  const islands = run([qso({ call: "KP4AA", entityPrefix: "KP4", location: "" }), qso({ call: "KH6AA", entityPrefix: "KH6", location: "" })], {
    party: "PA",
    ourLocation: "ELK",
  })
  assert.deepEqual(Object.keys(islands.sheet.mults).sort(), ["PAC", "PR"])
  assert.deepEqual(islands.sheet.entities, {})
})

test("PA: an entrant outside Pennsylvania enters from a section", () => {
  // `EMA` has to resolve as OUR location too, or a Massachusetts entrant can
  // only operate by typing a state the sponsor then rejects in every QSO line.
  const outside = run([qso({ location: "ELK" }), qso({ call: "K1XYZ", location: "WMA" })], { party: "PA", ourLocation: "EMA" })
  assert.equal(outside.scores[0].value, 2)
  assert.deepEqual(Object.keys(outside.sheet.mults), ["ELK"])
  // Two stations outside the party are still not a contest QSO.
  assert.deepEqual(outside.scores[1].alerts, ["invalidExchange"])
  // And a state is no more our location than it is theirs.
  assert.deepEqual(run([qso({ location: "ELK" })], { party: "PA", ourLocation: "MA" }).scores[0].alerts, ["ourLocation"])

  // And our own SECTION is the mistake this party makes easy: `EPA` resolves
  // cleanly, so nothing else objects, and the whole log would be scored under
  // out-of-state rules — no own-county multiplier, no activated-county bonus,
  // the wrong multiplier keys — with every Cabrillo line claiming an exchange
  // no Pennsylvania station may send. Caught only because the alert reads the
  // party's own GROUND; a plain state comparison has no `EPA` in it.
  const ownSection = run([qso({ location: "MGY" })], { party: "PA", ourLocation: "EPA" })
  assert.deepEqual(ownSection.scores[0].alerts, ["ourLocation"])
  assert.ok((ownSection.scores[0].value as number) > 0, "the contact still counts for what it is worth")
})

test("PA: QRP doubles the QSO points, and the bonus station is added after", () => {
  // Rule 10.d multiplies QSO POINTS, so the 200 K3ZMC pays stays 200. Folding
  // the power factor over the bonus as well would hand a QRP entrant 400.
  const qrp = run([qso({ call: "K3ZMC", location: "MGY" })], { party: "PA", ourLocation: "ELK", power: "QRP" })
  assert.equal(qrp.summary().total, 2 * 2 * 2 + 200)
  const low = run([qso({ call: "K3ZMC", location: "MGY" })], { party: "PA", ourLocation: "ELK", power: "LOW" })
  assert.equal(low.summary().total, 2 * 2 + 200)
})

test("the chase list leaves out multipliers the party itself puts out of reach", () => {
  // A Maryland station sends one of its counties and never `MD`, so `MD` is
  // an entry an operator could hunt forever.
  const md = run([qso({ location: "ALY" })], { party: "MD", ourLocation: "ANA" }).summary().longSummary as string
  assert.doesNotMatch(md, /\bMD\b/)
  // Only the party's OWN ground goes: every other state is there to be
  // chased, and so are the counties.
  assert.match(md, /\bVA\b/)
  assert.match(md, /\bALY\b/)

  // Nobody sends PA's `EPA` or `WPA` either, but working a county earns one
  // (`countySections`), so an in-state entrant chases them like any other.
  const pa = run([qso({ location: "MGY" })], { party: "PA", ourLocation: "ELK" }).summary().longSummary as string
  assert.match(pa, /\*\*~~EPA~~\*\*/)
  assert.match(pa, /\bWPA\b/)
  assert.doesNotMatch(pa, /~~WPA~~/)

  // But where the party's own ground IS a multiplier, it is exactly what the
  // list exists to show as still needed. NEQP scores an in-party contact by
  // STATE, so its six are the in-state multipliers — hiding them until they
  // are worked answers "what is done" when the question is "what is left".
  const neqp = run([qso({ location: "MAWOR" })], { party: "NEQP", ourLocation: "MABAR" }).summary().longSummary as string
  for (const code of ["CT", "ME", "NH", "RI", "VT"]) assert.match(neqp, new RegExp(`\\b${code}\\b`), `NEQP hides ${code}`)
})

test("a code inside the party is refused as a copied exchange, and only as one", () => {
  // `EPA` is not something a Pennsylvania station can send — they send one of
  // 67 counties — so taking it would claim a multiplier the sponsor's checker
  // strikes and write it into the submitted file.
  const sent = run([qso({ call: "K3ABC", location: "EPA" })], { party: "PA", ourLocation: "ELK" })
  assert.equal(sent.scores[0].value, 0)
  assert.deepEqual(sent.scores[0].alerts, ["invalidExchange"])
  assert.deepEqual(sent.sheet.states, {})

  // A contact whose exchange was never copied is a different question, and
  // `defaultTheirLocation` has already answered it: refusing a contact that
  // plainly happened is the worse reading, so the state stands.
  const guessed = run([qso({ call: "K3XYZ", location: "", state: "PA" })], { party: "MD", ourLocation: "ANA" })
  assert.ok((guessed.scores[0].value as number) > 0)

  // Our OWN location is a setup field and not something copied off the air, so
  // an entrant who typed their state there is told so and goes on scoring.
  const ours = run([qso({ location: "ALY" })], { party: "MD", ourLocation: "MD" })
  assert.deepEqual(ours.scores[0].alerts, ["ourLocation"])
  assert.ok((ours.scores[0].value as number) > 0, "the contact still counts for what it is worth")
})

test("the chase list shows every code the scoresheet counted, reachable or not", () => {
  // The heading counts `sheet.states` while the list comes from the party's
  // table, so a code the sheet holds and the table hides prints "1 US States"
  // above a line with nothing struck in it. An in-party station's
  // own state reaches the sheet exactly that way, from a contact whose
  // exchange was never copied.
  const { sheet, summary } = run([qso({ location: "ALY" })], { party: "MD", ourLocation: "ANA" })
  sheet.states.MD = 1
  assert.match(summary().longSummary as string, /\*\*~~MD~~\*\*/)
})

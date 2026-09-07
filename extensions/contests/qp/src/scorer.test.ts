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

function qso({ call = 'K1ABC', band = '20m', mode = 'CW', location, entityPrefix = 'K', state }: QsoSpec = {}): Record<string, JSONValue> {
  return {
    their: { call, ...(entityPrefix ? { entityPrefix } : {}), ...(state ? { state } : {}) },
    band,
    mode,
    ...(location !== undefined ? { refs: [{ type: 'qp', location }] } : {}),
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

function run(qsos: Record<string, JSONValue>[], { party = 'NY', ourLocation = 'ALB', mobile, power, station }: RunOptions = {}) {
  const locations = Array.isArray(ourLocation) ? ourLocation : [ourLocation]
  const refFor = (index: number): Record<string, JSONValue> => ({
    type: 'qp',
    ref: party,
    location: locations[Math.min(index, locations.length - 1)],
    ...(mobile ? { mobile } : {}),
    ...(power ? { power } : {}),
    ...(station ? { station } : {}),
  })
  const operation: Record<string, JSONValue> = { uuid: 'op', stationCall: 'N0DEV', refs: [refFor(0)] }

  let sheet: QpScoresheet = QsoPartyScorer.startScoresheet({ operation, ref: refFor(0) }, ctx)
  const scores = qsos.map((q, index) => {
    const ref = refFor(index)
    const result = QsoPartyScorer.scoreQso(
      { scoresheet: sheet, qso: q, operation: { ...operation, refs: [ref] }, ref, isNewDay: false },
      ctx,
    )
    sheet = result.scoresheet
    return result.score
  })
  const summary = (scope: 'operation' | 'day' = 'operation') =>
    QsoPartyScorer.summarizeScore({ scoresheet: sheet, operation, ref: refFor(0), scope }, ctx).qp
  return { sheet, scores, summary }
}

test('points come from the mode, per party', () => {
  // New York: 1 phone, 2 CW, 3 data.
  assert.equal(run([qso({ mode: 'SSB', location: 'ERI' })]).scores[0].value, 1)
  assert.equal(run([qso({ mode: 'CW', location: 'ERI' })]).scores[0].value, 2)
  assert.equal(run([qso({ mode: 'FT8', location: 'ERI' })]).scores[0].value, 3)
})

test('a county line is worth every pairing of counties — the N×M this milestone is for', () => {
  // Both of us on a line: four contacts in one exchange, and four multipliers.
  const { scores, sheet } = run([qso({ location: 'ERI/CHA' })], { ourLocation: 'ALB/REN' })
  assert.equal(scores[0].value, 2 * 2 * 2)
  assert.deepEqual(Object.keys(sheet.mults).sort(), ['CHA', 'ERI', 'NY'])
})

test('the WARC bands do not count, and neither does a QSO with no band', () => {
  assert.deepEqual(run([qso({ band: '30m', location: 'ERI' })]).scores[0].alerts, ['invalidBand'])
  assert.deepEqual(run([qso({ band: '', location: 'ERI' })]).scores[0].alerts, ['invalidBand'])
})

test('nothing scores until the operator says where WE are', () => {
  // Every contact is worth ours × theirs, so with no county of our own the
  // whole log is zero — and silently, unless it is said out loud.
  const { scores } = run([qso({ location: 'ERI' })], { ourLocation: '' })
  assert.equal(scores[0].value, 0)
  assert.deepEqual(scores[0].alerts, ['ourLocation'])
})

test('an exchange that was never sent, and one that means nothing', () => {
  assert.deepEqual(run([qso({ location: '' })]).scores[0].alerts, ['missingExchange'])
  assert.deepEqual(run([qso({ location: 'ZZZ', entityPrefix: '' })]).scores[0].alerts, ['invalidExchange'])
})

test('a typo from a US station is a bad exchange, not a DX contact', () => {
  // polo ends its resolution with "any entity at all means DX", and `K` is an
  // entity — so a mistyped county for a US station scored, and in the twenty
  // parties that count DX entities separately it claimed a `DX:K` multiplier
  // and listed "K" among the entities worked.
  const { scores, sheet } = run([qso({ location: 'ALBA' })])
  assert.equal(scores[0].value, 0)
  assert.deepEqual(scores[0].alerts, ['invalidExchange'])
  assert.deepEqual(sheet.entities, {})
  // A station in a country that is genuinely DX still resolves to DX.
  assert.ok(run([qso({ location: 'ZZZ', entityPrefix: 'DL' })]).scores[0].value > 0)
})

test('the state a county multiplies as is struck in the states table', () => {
  // NEQP scores an in-party contact by STATE, so the states checklist is where
  // the operator sees that Massachusetts is now had. Recording only the county
  // leaves it reading as still needed while the score already counts it.
  const { sheet } = run([qso({ location: 'MAWOR' })], { party: 'NEQP', ourLocation: 'MABAR' })
  assert.equal(sheet.states.MA, 1)
  // Same for a party whose in-state entrants claim their own state on top of
  // the county (NY).
  assert.equal(run([qso({ location: 'ERI' })]).sheet.states.NY, 1)
  // And a Canadian party's provinces land in the provinces table, not the
  // states one.
  const acqp = run([qso({ location: 'NSANP', entityPrefix: 'VE' })], { party: 'ACQP', ourLocation: 'NSCOL' })
  assert.equal(acqp.sheet.provinces.NS, 1)
  assert.deepEqual(acqp.sheet.states, {})
})

test('two out-of-party stations working each other is not a contest QSO', () => {
  // The party is between its own people and everyone else.
  const { scores } = run([qso({ location: 'CT' })], { ourLocation: 'NJ' })
  assert.equal(scores[0].value, 0)
})

test('a station with no exchange is scored under the county they gave last time', () => {
  // polo's `_defaultLocationFor`, folded into the pass: the second contact is
  // a different band, so it counts, and it counts as Erie.
  const { scores, sheet } = run([
    qso({ location: 'ERI' }),
    qso({ band: '40m' }),
  ])
  assert.equal(scores[1].value, 2)
  assert.equal(sheet.counties.ERI, 2)
})

test('a repeat on the same band, mode and county is a duplicate', () => {
  const { scores, sheet } = run([qso({ location: 'ERI' }), qso({ location: 'ERI' })])
  assert.equal(scores[1].value, 0)
  assert.equal(scores[1].dupe, true)
  assert.deepEqual(scores[1].alerts, ['duplicate'])
  assert.equal(sheet.dupes, 1)
})

test('the same station on a new band or a new mode counts again, and says so', () => {
  const { scores } = run([
    qso({ location: 'ERI' }),
    qso({ location: 'ERI', band: '40m' }),
    qso({ location: 'ERI', mode: 'SSB' }),
  ])
  assert.ok(scores[1].notices?.includes('newBand'))
  assert.ok(scores[2].notices?.includes('newMode'))
  assert.equal(scores[1].value, 2)
})

test('a rover who moves may work the same station again, from the new county', () => {
  // This is what M10 means by rolling location: the second contact is scored
  // against the segment's ref, so the pair (our county, theirs) is new.
  const { scores } = run([qso({ location: 'ERI' }), qso({ location: 'ERI' })], {
    ourLocation: ['ALB', 'REN'],
  })
  assert.equal(scores[1].value, 2)
  assert.equal(scores[1].dupe, undefined)
})

test('a rover activates each county they operate from', () => {
  const { sheet } = run([qso({ location: 'ERI' }), qso({ location: 'CHA' })], {
    ourLocation: ['ALB', 'REN'],
  })
  assert.deepEqual(sheet.activatedCounties, { ALB: 1, REN: 1 })
})

test('a multiplier is claimed once, and the first claim says so', () => {
  const { scores, sheet } = run([
    qso({ location: 'ERI' }),
    qso({ call: 'K2DEF', location: 'ERI' }),
  ])
  assert.ok(scores[0].notices?.includes('newMult'))
  assert.ok(!(scores[1].notices ?? []).includes('newMult'))
  assert.equal(Object.keys(sheet.mults).length, 2) // ERI and NY
})

test('an in-party station\'s own state multiplies alongside the county', () => {
  // NY sets `stateCountsForInState`, so working Erie from Albany is two
  // multipliers: the county, and New York itself.
  const { sheet } = run([qso({ location: 'ERI' })])
  assert.deepEqual(Object.keys(sheet.mults).sort(), ['ERI', 'NY'])
  // An out-of-party entrant gets the county alone.
  const outside = run([qso({ location: 'ERI' })], { ourLocation: 'NJ' })
  assert.deepEqual(Object.keys(outside.sheet.mults), ['ERI'])
})

test('multipliers per band, per mode, or once — whichever the party publishes', () => {
  const ny = partyFor('NY')!
  // NY publishes none of the per-band options: a multiplier is a multiplier.
  assert.equal(multiplierPrefix(ny, { band: '20m', mode: 'CW', weAreInParty: true }), '')
  // OH counts them per mode, TN per band, SC per band AND mode.
  assert.equal(multiplierPrefix(partyFor('OH')!, { band: '20m', mode: 'CW', weAreInParty: true }), 'CW:')
  assert.equal(multiplierPrefix(partyFor('TN')!, { band: '20m', mode: 'CW', weAreInParty: true }), '20m:')
  assert.equal(multiplierPrefix(partyFor('SC')!, { band: '20m', mode: 'CW', weAreInParty: true }), '20m:CW:')
})

test('the side-specific per-band options apply to the side they name', () => {
  // polo tests `inStateMultsPerBand` in all three branches of the same
  // function, so HI could never reach the per-band branch and NH applied the
  // in-state rule to everyone.
  const nh = partyFor('NH')! // outOfStateMultsPerBand
  assert.equal(multiplierPrefix(nh, { band: '20m', mode: 'CW', weAreInParty: false }), '20m:')
  assert.equal(multiplierPrefix(nh, { band: '20m', mode: 'CW', weAreInParty: true }), '')
})

test('NEQP: an in-party pair multiplies by state, and the county is still logged', () => {
  const { sheet } = run([qso({ location: 'MAWOR' })], { party: 'NEQP', ourLocation: 'MABAR' })
  assert.deepEqual(Object.keys(sheet.mults), ['MA'])
  assert.equal(sheet.counties.MAWOR, 1)
})

test('ACQP: the other spelling of the same rule multiplies by province', () => {
  // `countiesCountForInState: false` (ACQP, CPQP, DEQP) and
  // `countiesAreMultForInState: false` (NEQP) have the same description in
  // polo's own NOTES — one rule, two spellings — and polo converts the CODE for
  // one and only the multiplier for the other. Here the county is always what
  // was sent, and only what it multiplies changes.
  const { sheet } = run([qso({ location: 'NSANP', entityPrefix: 'VE' })], { party: 'ACQP', ourLocation: 'NSCOL' })
  assert.equal(sheet.counties.NSANP, 1)
  assert.deepEqual(Object.keys(sheet.mults).some((key) => key.includes('NSANP')), false)
})

test('SC: an in-state station working out of state scores double', () => {
  const inside = run([qso({ location: 'NC' })], { party: 'SC', ourLocation: 'ABBE' })
  const outside = run([qso({ location: 'ABBE' })], { party: 'SC', ourLocation: 'NC' })
  assert.equal(inside.scores[0].value, 4)
  assert.equal(outside.scores[0].value, 2)
})

test('NC: a rare county multiplies the contact, and the sweep pays once', () => {
  const rare = ['CAB', 'GRM', 'VAN', 'MAC', 'DAV']
  const one = run([qso({ location: 'CAB' })], { party: 'NC', ourLocation: 'WAK' })
  assert.equal(one.scores[0].value, 3 * 10)
  assert.ok(one.scores[0].notices?.includes('rareCounty'))
  // Five rare counties is NC's published minimum for the sweep.
  const swept = run(rare.map((location, index) => qso({ call: `K${index}AAA`, location })), {
    party: 'NC',
    ourLocation: 'WAK',
  })
  const points = swept.sheet.points
  // `bonusPostMultiplier`: NC adds its bonus after the multiplier, so the
  // sweep is not multiplied by the county count.
  assert.equal(swept.summary().total, points * Object.keys(swept.sheet.mults).length + 500)
})

test('ID: the bonus stations pay out-of-state entrants only, and sweep', () => {
  // `bonusStationInStateMult: 0` is how the file says "not for us".
  const stations = ['K7S', 'K7P', 'K7U', 'K7D']
  const outside = run(stations.map((call) => qso({ call, location: 'ADA' })), {
    party: 'ID',
    ourLocation: 'WA',
  })
  assert.equal(Object.values(outside.sheet.bonusStations).reduce((a, b) => a + b, 0), 400)
  assert.ok(outside.scores[0].notices?.includes('bonusStation'))
  // 400 for the four stations, plus the 100 sweep polo's accumulator never pays.
  const mult = Object.keys(outside.sheet.mults).length
  assert.equal(outside.summary().total, (outside.sheet.points + 500) * mult)

  const inside = run([qso({ call: 'K7S', location: 'ADA' })], { party: 'ID', ourLocation: 'BOI' })
  assert.deepEqual(inside.sheet.bonusStations, {})
})

test('a bonus station pays once, and again per band where the party says so', () => {
  // WV pays per band and mode; NY has no bonus stations at all.
  const wv = run([
    qso({ call: 'W8WVA', location: 'KAN' }),
    qso({ call: 'W8WVA', location: 'KAN', band: '40m' }),
  ], { party: 'WV', ourLocation: 'OH' })
  assert.equal(Object.keys(wv.sheet.bonuses).length, 2)
  assert.equal(wv.sheet.bonusStations.W8WVA, 200)
})

test('CO: the per-county bonus is for rovers, and only above the minimum', () => {
  // 15 QSOs from a county, 500 points — and nothing at all for a fixed station.
  const fifteen = (location: string) =>
    Array.from({ length: 15 }, (_, index) => qso({ call: `K${index}AAA`, location }))

  const rover = run(fifteen('DEN'), { party: 'CO', ourLocation: 'ADA', mobile: true })
  assert.ok(rover.summary().total > 0)
  const bonusPart = rover.summary().total - rover.sheet.points * Object.keys(rover.sheet.mults).length
  assert.equal(bonusPart, 500)

  const fixed = run(fifteen('DEN'), { party: 'CO', ourLocation: 'ADA' })
  assert.equal(fixed.summary().total, fixed.sheet.points * Object.keys(fixed.sheet.mults).length)

  // One QSO short of the minimum earns nothing.
  const short = run(fifteen('DEN').slice(0, 14), { party: 'CO', ourLocation: 'ADA', mobile: true })
  assert.equal(short.summary().total, short.sheet.points * Object.keys(short.sheet.mults).length)
})

test('VA: our own county is a multiplier without working anyone in it', () => {
  const { sheet } = run([qso({ location: 'MD' })], { party: 'VA', ourLocation: 'ALB' })
  assert.ok(Object.keys(sheet.mults).includes('ALB'))
})

test('IL: the DX entity cap limits the multipliers instead of erasing them', () => {
  // polo compares an undefined array length against the cap, so the five
  // parties that publish one award NO DX multipliers at all.
  const entities = ['DL', 'F', 'G', 'I', 'EA', 'PA']
  const { sheet } = run(entities.map((prefix, index) => qso({
    call: `${prefix}1AA${index}`,
    location: 'DX',
    entityPrefix: prefix,
  })), { party: 'IL', ourLocation: 'COOK' })
  const dxMults = Object.keys(sheet.mults).filter((key) => key.includes('DX:'))
  // IL's cap is 5: the sixth entity is a valid contact worth points, and not
  // a sixth multiplier.
  assert.equal(dxMults.length, 5)
  assert.equal(Object.keys(sheet.entities).length, 6)

  // And a SECOND station in the over-cap entity does not sneak past it. The
  // exemption that keeps an established multiplier claimable has to test what
  // was CREDITED, not what was worked — testing the latter let the sixth
  // entity in on its second contact, one multiplier over a published cap.
  const twice = run([...entities, 'PA', 'PA'].map((prefix, index) => qso({
    call: `${prefix}1AA${index}`,
    location: 'DX',
    entityPrefix: prefix,
  })), { party: 'IL', ourLocation: 'COOK' })
  assert.equal(Object.keys(twice.sheet.mults).filter((key) => key.includes('DX:')).length, 5)
})

test('DE: a declared power class multiplies the score, and no claim multiplies by one', () => {
  // polo reads none of the four published power tables.
  const qrp = run([qso({ location: 'NJ' })], { party: 'DE', ourLocation: 'NDE', power: 'QRP' })
  const undeclared = run([qso({ location: 'NJ' })], { party: 'DE', ourLocation: 'NDE' })
  assert.equal(qrp.summary().total, undeclared.summary().total * 3)
})

test('a day\'s total is that day\'s points against the running multiplier', () => {
  const { summary, sheet } = run([qso({ location: 'ERI' }), qso({ call: 'K2DEF', location: 'CHA' })])
  const mult = Object.keys(sheet.mults).length
  assert.equal(summary('day').total, sheet.dayPoints * mult)
  assert.equal(summary('operation').total, sheet.points * mult)
})

test('a party this build does not know scores nothing, and says which way it failed', () => {
  const { scores } = run([qso({ location: 'ERI' })], { party: 'ZZ' })
  assert.deepEqual(scores[0].alerts, ['unknownEvent'])
  // A disabled party is the same answer: it has no rules we can score under.
  assert.deepEqual(run([qso({ location: 'ERI' })], { party: 'NS' }).scores[0].alerts, ['unknownEvent'])
})

test('the summary lists what is still out there, not just what is done', () => {
  const { summary } = run([qso({ location: 'ERI' })])
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
  const fifteen = (location: string) =>
    Array.from({ length: 15 }, (_, index) => qso({ call: `K${index}AAA`, location }))
  const bonusOf = (r: ReturnType<typeof run>) =>
    r.summary().total - r.sheet.points * Object.keys(r.sheet.mults).length

  const byClass = run(fifteen('DEN'), { party: 'CO', ourLocation: 'ADA', station: 'MOBILE' })
  assert.equal(bonusOf(byClass), 500)
  const byFlag = run(fifteen('DEN'), { party: 'CO', ourLocation: 'ADA', mobile: true })
  assert.equal(bonusOf(byFlag), 500)
  // A fixed station claims none of it.
  const fixed = run(fifteen('DEN'), { party: 'CO', ourLocation: 'ADA', station: 'FIXED' })
  assert.equal(bonusOf(fixed), 0)
})

test('Maine prices a contact by which side the other station is on', () => {
  // "2 points per QSO with ME stations, 1 point per QSO with non-ME stations"
  // — the one published rule no per-mode points table can express.
  const inParty = run([qso({ location: 'CBL' })], { party: 'ME', ourLocation: 'NH' })
  assert.equal(inParty.scores[0].value, 2)
  const outOfParty = run([qso({ location: 'NH' })], { party: 'ME', ourLocation: 'CBL' })
  assert.equal(outOfParty.scores[0].value, 1)
})

test('Arizona and Maine score like the parties they are', () => {
  // Both were added from their sponsors' rules rather than ported, so their
  // basics are worth pinning: Arizona pays 2 for CW and 1 for phone, and its
  // bonus station pays 100.
  assert.equal(run([qso({ location: 'PMA' })], { party: 'AZ', ourLocation: 'APH' }).scores[0].value, 2)
  assert.equal(run([qso({ location: 'PMA', mode: 'SSB' })], { party: 'AZ', ourLocation: 'APH' }).scores[0].value, 1)
  const bonus = run([qso({ call: 'K7A', location: 'PMA' })], { party: 'AZ', ourLocation: 'CA' })
  assert.equal(bonus.sheet.bonusStations.K7A, 100)
})

test('typing your STATE where your county belongs is said out loud', () => {
  // `NY` resolves cleanly to the state — no party's county codes collide with a
  // state code — so nothing else objects, and the whole log is quietly scored
  // under out-of-state rules: no own-state multiplier, no activated county, a
  // different multiplier key. The contact still counts; the operator is told.
  const typed = run([qso({ location: 'ERI' })], { ourLocation: 'NY' })
  assert.deepEqual(typed.scores[0].alerts, ['ourLocation'])
  assert.ok((typed.scores[0].value as number) > 0, 'the contact still counts for what it is worth')

  // A county is what it should be, and says nothing.
  assert.equal(run([qso({ location: 'ERI' })], { ourLocation: 'ALB' }).scores[0].alerts, undefined)
  // And a genuine out-of-state entrant is not nagged about their own state.
  assert.equal(run([qso({ location: 'ERI' })], { ourLocation: 'NJ' }).scores[0].alerts, undefined)
  // Multi-state parties know all of their own states, not just one.
  assert.deepEqual(
    run([qso({ location: 'ORDES' })], { party: '7QP', ourLocation: 'UT' }).scores[0].alerts,
    ['ourLocation'],
  )
})

test('a DX station is resolved from the callsign when nothing else knows', () => {
  // An imported or synced QSO carries no `guess`, so without the country file
  // the entity is unknown: the exchange resolves to nothing, the contact scores
  // `missingExchange`, and the DX multiplier the party publishes is never
  // claimed. `naqp` and `arrl-dx` already reach for the country file this way.
  const imported = {
    their: { call: 'DL1ABC' },
    band: '20m',
    mode: 'CW',
    refs: [{ type: 'qp', location: '' }],
  } as Record<string, JSONValue>
  const { scores, sheet } = run([imported], { party: 'IL', ourLocation: 'COOK' })
  assert.ok((scores[0].value as number) > 0)
  assert.deepEqual(Object.keys(sheet.entities), ['DL'])
})

test('NH credits each DX entity up to its published cap', () => {
  // "Each NH county, each state, each VE province and up to 10 DXCC countries
  // once" — so each entity IS a multiplier there. Without the flag every DX
  // contact shared one `DX` key and the cap of 10 was inert, costing an NH
  // entrant up to nine multipliers.
  const entities = ['DL', 'F', 'G', 'I', 'EA', 'PA', 'ON4', 'SM', 'LA', 'OZ', 'SP', 'HA']
  const { sheet } = run(entities.map((prefix, index) => qso({
    call: `${prefix}1AA${index}`,
    location: 'DX',
    entityPrefix: prefix,
  })), { party: 'NH', ourLocation: 'BEL' })
  const dxMults = Object.keys(sheet.mults).filter((key) => key.includes('DX:'))
  assert.equal(dxMults.length, 10, 'ten credited, not one and not twelve')
  assert.equal(Object.keys(sheet.entities).length, 12, 'all twelve worked')
})

test('a power class the party does not publish is not submitted under it', () => {
  // The setup form writes `ref` in place when the party changes, so a class
  // left behind by the previous one must be refused — as it is on every other
  // axis. Wisconsin publishes power classes; a party without them must not
  // inherit the answer.
  const wi = { type: 'qp', ref: 'WI', power: 'QRP' } as Record<string, JSONValue>
  assert.equal(ourPowerClass(undefined, wi, partyFor('WI')!), 'QRP')
  assert.equal(ourPowerClass(undefined, { ...wi, ref: 'NV' }, partyFor('NV')!), undefined)
})

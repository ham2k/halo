// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// State-park scoring is where this port diverges most from polo, because most of
// what polo computes there never reaches a score: the parks it activates are
// always zero, its bonus points are never added, and working Texas's bonus
// station throws. Every one of those is a test here — they are the cases where
// "same numbers as polo" is the wrong thing to assert.
//
// The rest is the ordinary contest business: points by mode, a park each side
// multiplying, and who counts as a duplicate.

import { test } from "node:test"
import assert from "node:assert/strict"

import type { JSONValue } from "@ham2k/extension-sdk"
import { QSOS_TO_ACTIVATE, StateParksScorer, type StateParksScoresheet } from "./scorer.ts"

const ctx = { online: false } as never

/// An operation activating [ourParks] as POTA references.
function operationFor(...ourParks: string[]): Record<string, JSONValue> {
  return {
    uuid: 'op',
    stationCall: 'N0DEV',
    refs: ourParks.map((ref) => ({ type: 'potaActivation', ref })),
  }
}

interface QsoSpec {
  call?: string
  band?: string
  mode?: string
  /// POTA references the worked station is in.
  hunting?: string[]
  /// A park abbreviation they sent (the Ohio exchange).
  park?: string
  state?: string
  entityPrefix?: string
}

function qso({ call = 'K1ABC', band = '20m', mode = 'CW', hunting, park, state, entityPrefix }: QsoSpec = {}): Record<string, JSONValue> {
  const refs: Record<string, JSONValue>[] = [
    ...(hunting ?? []).map((ref) => ({ type: 'pota', ref })),
    ...(park !== undefined ? [{ type: 'stateparks', park }] : []),
  ]
  return {
    their: { call, ...(state ? { state } : {}), ...(entityPrefix ? { entityPrefix } : {}) },
    band,
    mode,
    ...(refs.length > 0 ? { refs } : {}),
  }
}

function run(
  qsos: Record<string, JSONValue>[],
  { event = 'TXSP', operation = operationFor(), ourPark, ourPower }: {
    event?: string
    operation?: Record<string, JSONValue>
    ourPark?: string
    ourPower?: string
  } = {},
) {
  const ref: Record<string, JSONValue> = {
    type: 'stateparks',
    ref: event,
    ...(ourPark ? { ourPark } : {}),
    ...(ourPower ? { ourPower } : {}),
  }
  let sheet: StateParksScoresheet = StateParksScorer.startScoresheet({ operation, ref }, ctx)
  const scores = qsos.map((q) => {
    const result = StateParksScorer.scoreQso({ scoresheet: sheet, qso: q, operation, ref, isNewDay: false }, ctx)
    sheet = result.scoresheet
    return result.score
  })
  const summary = () => StateParksScorer.summarizeScore({ scoresheet: sheet, operation, ref, scope: 'operation' }, ctx).stateparks
  return { sheet, scores, summary }
}

// Texas parks, from txsp.json.
const TX_A = 'US-2983'
const TX_B = 'US-2984'
const TX_C = 'US-2985'

test('points come from the mode, per event', () => {
  // Texas pays double for CW; Georgia pays one for everything.
  assert.equal(run([qso({ mode: 'CW' })]).scores[0].value, 2)
  assert.equal(run([qso({ mode: 'SSB' })]).scores[0].value, 1)
  assert.equal(run([qso({ mode: 'FT8' })]).scores[0].value, 1)
  assert.equal(run([qso({ mode: 'CW' })], { event: 'GASP' }).scores[0].value, 1)

  // An event that names no points for a mode still pays the base point rather
  // than rejecting the contact — Ohio's data lists PHONE and CW only, and
  // zeroing a digital QSO would be a rules claim this port has no source for.
  assert.equal(run([qso({ mode: 'FT8', band: '20m', park: 'HOC' })], { event: 'OHSP' }).scores[0].value, 1)
  // A QSO with no mode at all is priced at the base point, not judged as digital.
  assert.equal(run([qso({ mode: '' })]).scores[0].value, 1)
})

test('a band the event does not run scores nothing', () => {
  // WARC, excluded everywhere.
  const warc = run([qso({ band: '30m' })]).scores[0]
  assert.equal(warc.value, 0)
  assert.deepEqual(warc.alerts, ['invalidBand'])

  // Ohio runs 80 through 10 — the per-event list polo carries and never reads.
  assert.equal(run([qso({ band: '160m', park: 'HOC' })], { event: 'OHSP' }).scores[0].value, 0)
  assert.equal(run([qso({ band: '40m', park: 'HOC' })], { event: 'OHSP' }).scores[0].value, 1)
  // Texas states no list, so 160m is a contact.
  assert.equal(run([qso({ band: '160m' })]).scores[0].value, 2)
})

test('each park we are activating multiplies the QSO — and only the event’s parks do', () => {
  // One park: the ordinary case, no multiplication.
  assert.equal(run([qso({ mode: 'SSB' })], { operation: operationFor(TX_A) }).scores[0].value, 1)
  // A two-park activation counts the contact for both.
  assert.equal(run([qso({ mode: 'SSB' })], { operation: operationFor(TX_A, TX_B) }).scores[0].value, 2)
  // A park that isn't in the event doesn't. polo multiplied by every POTA
  // activation on the operation, in the event or not.
  assert.equal(run([qso({ mode: 'SSB' })], { operation: operationFor(TX_A, 'US-0001') }).scores[0].value, 1)
  assert.equal(run([qso({ mode: 'SSB' })], { operation: operationFor('US-0001') }).scores[0].value, 1)
})

test('each new park of theirs multiplies too, and is announced', () => {
  const { scores } = run([qso({ mode: 'SSB', hunting: [TX_B] })])
  assert.equal(scores[0].value, 1)
  assert.deepEqual(scores[0].notices, ['newPark'])

  // A park-to-park pair: two parks of theirs, on one contact.
  const twofer = run([qso({ mode: 'SSB', hunting: [TX_B, TX_C] })])
  assert.equal(twofer.scores[0].value, 2)

  // A park outside the event is just an ordinary POTA hunt.
  assert.equal(run([qso({ mode: 'SSB', hunting: ['US-0001'] })]).scores[0].value, 1)
  assert.equal(run([qso({ mode: 'SSB', hunting: ['US-0001'] })]).scores[0].notices, undefined)
})

test('a station is worked once per band and mode, and again from a new park', () => {
  const { scores, sheet } = run([
    qso({ mode: 'SSB', hunting: [TX_B] }),
    qso({ mode: 'SSB', hunting: [TX_B] }),   // same everything: a duplicate
    qso({ mode: 'SSB', band: '40m', hunting: [TX_B] }), // new band
    qso({ mode: 'CW', hunting: [TX_B] }),    // new mode
    qso({ mode: 'SSB', hunting: [TX_C] }),   // same band and mode, new park
  ])

  assert.equal(scores[0].value, 1)
  assert.equal(scores[1].value, 0)
  assert.equal(scores[1].dupe, true)
  assert.deepEqual(scores[1].alerts, ['duplicate'])
  assert.deepEqual(scores[2].notices, ['newBand'])
  assert.deepEqual(scores[3].notices, ['newMode'])
  assert.equal(scores[4].value, 1, 'a different park is a different contact')
  assert.deepEqual(scores[4].notices, ['newPark'])

  // Only the real duplicate counts as one — polo's dupe tally also collected
  // every QSO it rejected for its band.
  assert.equal(sheet.dupes, 1)
  assert.equal(sheet.qsos, 4)
})

test('a plain contact still occupies its slot, so the second one is a duplicate', () => {
  const { scores } = run([qso({ mode: 'SSB' }), qso({ mode: 'SSB' })])
  assert.equal(scores[0].value, 1)
  assert.equal(scores[1].value, 0)
  assert.deepEqual(scores[1].alerts, ['duplicate'])
})

test('once a slot is credited, a contact from NO park is a duplicate too', () => {
  // The ordering that used to leak a point: the `''` standing for "no park" was
  // treated as a park the slot hadn't been credited yet, so a park contact
  // followed by a parkless one — they left the park, or the hunter chip simply
  // wasn't logged that time — scored in full and wasn't even counted as a dupe.
  const { scores, sheet } = run([
    qso({ mode: 'SSB', hunting: [TX_B] }),
    qso({ mode: 'SSB' }),
  ])
  assert.equal(scores[0].value, 1)
  assert.equal(scores[1].value, 0)
  assert.equal(scores[1].dupe, true)
  assert.deepEqual(scores[1].alerts, ['duplicate'])
  assert.equal(sheet.dupes, 1)
  assert.equal(sheet.points, 1)
})

test('a slot remembers every park credited to it, not just the last', () => {
  const { scores } = run([
    qso({ mode: 'SSB', hunting: [TX_B] }),
    qso({ mode: 'SSB', hunting: [TX_C] }), // a new park: counts
    qso({ mode: 'SSB', hunting: [TX_B] }), // back to the first: a duplicate
  ])
  assert.equal(scores[1].value, 1)
  assert.equal(scores[2].value, 0)
  assert.deepEqual(scores[2].alerts, ['duplicate'])
})

test('the park we set up and the park we are activating are ONE park', () => {
  // The default case for Ohio: the setup field is pre-filled from the POTA
  // activation, so both name the same park and it must be counted once.
  const both = run(
    Array.from({ length: QSOS_TO_ACTIVATE }, (_, i) => qso({ call: `K1AB${i}`, band: '40m', park: 'ADA' })),
    { event: 'OHSP', operation: operationFor('US-1958'), ourPark: 'HOC' },
  )
  assert.deepEqual(Object.keys(both.sheet.activated), ['US-1958'])
  assert.equal(both.scores[0].value, 1, 'one activation, so no multiplication')

  // And when they DISAGREE, the POTA activation wins rather than both counting:
  // as a union this scored every QSO twice and claimed two activated parks.
  const disagreeing = run(
    Array.from({ length: QSOS_TO_ACTIVATE }, (_, i) => qso({ call: `K1AB${i}`, band: '40m', park: 'ALU' })),
    { event: 'OHSP', operation: operationFor('US-1958'), ourPark: 'ADA' },
  )
  assert.deepEqual(Object.keys(disagreeing.sheet.activated), ['US-1958'])
  assert.equal(disagreeing.scores[0].value, 1)
})

test('a typed exchange outranks a POTA reference that disagrees with it', () => {
  // Whatever the operator keyed is what was sent on the air, so it is what
  // scores — and what the Cabrillo will claim. When these two resolved the
  // question separately, the app showed a multiplier the submitted log didn't
  // support.
  const { sheet } = run(
    [qso({ band: '40m', hunting: ['US-1933'], park: 'ADA' })],
    { event: 'OHSP' },
  )
  assert.deepEqual(Object.keys(sheet.hunted), ['US-1932'], 'ADA, not the hunted US-1933')
})

test('a bonus station is recognized by its BASE call, however it was worked', () => {
  // /M, /P, a portable prefix: the sponsor's list names the station, not the
  // callsign it happened to sign that afternoon.
  const portable = run([{ ...qso({ call: 'K5LRK/M', mode: 'SSB' }), their: { call: 'K5LRK/M', baseCall: 'K5LRK' } }])
  assert.deepEqual(portable.scores[0].notices, ['bonusStation'])

  // The guessed base call counts too — it is what the lookup pipeline fills in.
  const guessed = run([{ ...qso({ call: 'W5/K5LRK', mode: 'SSB' }), their: { call: 'W5/K5LRK', guess: { baseCall: 'K5LRK' } } }])
  assert.deepEqual(guessed.scores[0].notices, ['bonusStation'])

  // Not a bonus station, and not mistaken for one.
  assert.equal(run([qso({ call: 'K5LRX', mode: 'SSB' })]).scores[0].notices, undefined)
})

test('a bonus station pays once — polo throws here instead', () => {
  // `scoring.bonusStations.push(...)` against an object with no such key: a
  // TypeError out of polo's scorer the first time anyone works K5LRK.
  const { scores, sheet, summary } = run([
    qso({ call: 'K5LRK', mode: 'SSB' }),
    qso({ call: 'K5LRK', mode: 'SSB', band: '40m' }),
  ])

  assert.deepEqual(scores[0].notices, ['bonusStation'])
  assert.deepEqual(scores[1].notices, ['newBand'], 'the bonus is announced once')
  assert.deepEqual(sheet.bonusStations, { K5LRK: 5 })
  // 2 points × 1 multiplier + the 5-point bonus.
  assert.equal(summary().total, 7)
})

test('a park we activate pays its bonus once it is actually activated', () => {
  const operation = operationFor(TX_A)
  const nine = run(Array.from({ length: 9 }, (_, i) => qso({ call: `K1AB${i}`, mode: 'SSB' })), { operation })
  assert.equal(nine.summary().total, 9, 'nine QSOs is not an activation')

  const ten = run(Array.from({ length: QSOS_TO_ACTIVATE }, (_, i) => qso({ call: `K1AB${i}`, mode: 'SSB' })), { operation })
  // 10 points × (1 activated + 0 hunted) + 100 for the activated park. polo
  // never awards this: the guard reads a key its data files put elsewhere, and
  // the total adds a third name that nothing assigns.
  assert.equal(ten.summary().total, 110)
})

test('multipliers are parks: activated, activated + hunted, or none', () => {
  const worked = (event: string) => run(
    [
      ...Array.from({ length: QSOS_TO_ACTIVATE }, (_, i) => qso({ call: `K1AB${i}`, mode: 'SSB', hunting: [TX_B] })),
    ],
    { event, operation: operationFor(TX_A) },
  )

  // Texas: 1 activated + 1 hunted = 2. polo's activated count is always 0.
  const tx = worked('TXSP').summary()
  assert.equal(tx.mults, 2)
  assert.equal(tx.points, 10)
  assert.equal(tx.total, 10 * 2 + 100)

  // Florida multiplies by nothing at all, and pays the same per-park bonus.
  const fl = run(
    Array.from({ length: QSOS_TO_ACTIVATE }, (_, i) => qso({ call: `K1AB${i}`, mode: 'SSB' })),
    { event: 'FLSP', operation: operationFor('US-0634') },
  ).summary()
  assert.equal(fl.mults, 1)
  assert.equal(fl.total, 10 + 100)
})

test('Georgia pays for each distinct park, and multiplies by the parks it activates', () => {
  const operation = operationFor('US-0636')
  const { scores, summary } = run(
    [
      qso({ mode: 'SSB', hunting: ['US-2165'] }),
      qso({ call: 'K2DEF', mode: 'SSB', hunting: ['US-2165'] }),
      qso({ call: 'K3GHI', mode: 'SSB', hunting: ['US-2166'] }),
    ],
    { event: 'GASP', operation },
  )

  // 1 point for the contact, 5 for a park not yet in the log.
  assert.equal(scores[0].value, 6)
  assert.equal(scores[1].value, 1, 'the same park pays its 5 only once')
  assert.equal(scores[2].value, 6)
  // Not yet an activation, so the multiplier floors at 1: 13 points.
  assert.equal(summary().total, 13)
})

test('Ohio’s exchange is a park abbreviation, and it counts as that park', () => {
  const operation = operationFor('US-1958')
  const { scores, sheet, summary } = run(
    [
      qso({ band: '40m', park: 'ADA' }),
      qso({ call: 'K2DEF', band: '40m', park: 'ALU' }),
    ],
    { event: 'OHSP', operation },
  )

  assert.equal(scores[0].value, 1)
  assert.deepEqual(scores[0].notices, ['newPark'])
  // Credited as the park's POTA reference, so a hunter chip and a typed
  // abbreviation are the same fact.
  assert.deepEqual(Object.keys(sheet.hunted), ['US-1932', 'US-1933'])
  // 2 points × (0 activated — 2 QSOs is not an activation — + 2 hunted).
  assert.equal(summary().total, 4)
})

test('Ohio says so when the exchange is missing or isn’t one of its parks', () => {
  const missing = run([qso({ band: '40m' })], { event: 'OHSP' }).scores[0]
  assert.equal(missing.value, 1, 'the contact still counts')
  assert.deepEqual(missing.alerts, ['missingExchange'])

  const wrong = run([qso({ band: '40m', park: 'ZZZ' })], { event: 'OHSP' }).scores[0]
  assert.equal(wrong.value, 1)
  assert.deepEqual(wrong.alerts, ['invalidExchange'])

  // A POTA reference on the QSO is the same statement, so no alert.
  const hunted = run([qso({ band: '40m', hunting: ['US-1932'] })], { event: 'OHSP' }).scores[0]
  assert.deepEqual(hunted.alerts, undefined)

  // The other events have no exchange to miss.
  assert.equal(run([qso({ mode: 'SSB' })]).scores[0].alerts, undefined)
})

test('the park we set up in Ohio counts as ours, POTA activation or not', () => {
  // Someone running the event without logging a POTA activation: the
  // abbreviation they chose at setup is still the park they are in.
  const { sheet, summary } = run(
    Array.from({ length: QSOS_TO_ACTIVATE }, (_, i) => qso({ call: `K1AB${i}`, band: '40m', park: 'ADA' })),
    { event: 'OHSP', ourPark: 'HOC' },
  )
  assert.deepEqual(Object.keys(sheet.activated), ['US-1958'])
  // 10 points × (1 activated + 1 hunted). Ohio pays no per-park bonus.
  assert.equal(summary().total, 20)
})

test('an event this build does not know scores nothing, and says why', () => {
  const { scores, summary } = run([qso({ mode: 'SSB' })], { event: 'WISP' })
  assert.equal(scores[0].value, 0)
  assert.deepEqual(scores[0].alerts, ['unknownEvent'])
  assert.equal(summary().total, 0)
})

test('a day’s figure is its own points against the running multiplier', () => {
  const operation = operationFor(TX_A)
  const ref = { type: 'stateparks', ref: 'TXSP' }
  let sheet = StateParksScorer.startScoresheet({ operation, ref }, ctx)

  for (const [index, q] of [qso({ mode: 'SSB', hunting: [TX_B] }), qso({ call: 'K2DEF', mode: 'SSB' })].entries()) {
    sheet = StateParksScorer.scoreQso({ scoresheet: sheet, qso: q, operation, ref, isNewDay: index === 0 }, ctx).scoresheet
  }
  const firstDay = StateParksScorer.summarizeScore({ scoresheet: sheet, operation, ref, scope: 'day' }, ctx).stateparks
  assert.equal(firstDay.points, 2)

  // A new day resets the day's points but not the parks or the bonuses.
  sheet = StateParksScorer.scoreQso({ scoresheet: sheet, qso: qso({ call: 'K3GHI', mode: 'SSB' }), operation, ref, isNewDay: true }, ctx).scoresheet
  const secondDay = StateParksScorer.summarizeScore({ scoresheet: sheet, operation, ref, scope: 'day' }, ctx).stateparks
  assert.equal(secondDay.points, 1)
  assert.equal(secondDay.mults, 1, 'the park worked yesterday still multiplies today')

  const whole = StateParksScorer.summarizeScore({ scoresheet: sheet, operation, ref, scope: 'operation' }, ctx).stateparks
  assert.equal(whole.points, 3)
})

test('a day’s total leaves the event’s bonuses out, so they are not paid twice', () => {
  const operation = operationFor(TX_A)
  const ref = { type: 'stateparks', ref: 'TXSP' }
  let sheet = StateParksScorer.startScoresheet({ operation, ref }, ctx)

  // Ten QSOs on day one, so the park is activated and its 100-point bonus is due.
  for (let i = 0; i < QSOS_TO_ACTIVATE; i++) {
    sheet = StateParksScorer.scoreQso(
      { scoresheet: sheet, qso: qso({ call: `K1AB${i}`, mode: 'SSB' }), operation, ref, isNewDay: i === 0 },
      ctx,
    ).scoresheet
  }

  const day = StateParksScorer.summarizeScore({ scoresheet: sheet, operation, ref, scope: 'day' }, ctx).stateparks
  const whole = StateParksScorer.summarizeScore({ scoresheet: sheet, operation, ref, scope: 'operation' }, ctx).stateparks
  // 10 points × 1 multiplier, and the bonus counted ONCE, at the operation level.
  assert.equal(day.total, 10)
  assert.equal(whole.total, 110)
  // A second day would otherwise add the same 100 again.
  assert.match(String(whole.label), /\+ 100$/)
  assert.equal(day.label, '10 × 1')
})

test('Texas’s power class ADDS to the multiplier sum, where the event has one', () => {
  // §6.5.1, verbatim: "total QSO points X (power multiplier + Texas State Parks
  // worked multiplier + Texas State Parks activated multiplier) + bonus points".
  // So QRP's 3 is three more multipliers, NOT a trebled score — the name
  // `powerMultipliers` reads the other way, and polo reads the key nowhere at
  // all, scoring a QRP entrant short of a term their rules give them.
  const hunt = [qso({ mode: 'SSB', hunting: [TX_B] })] // 1 point, 1 park worked

  assert.equal(run(hunt).summary().total, 1, 'no class declared claims no term')
  assert.equal(run(hunt, { ourPower: 'QRP' }).summary().total, 4) // 1 × (3 + 1)
  assert.equal(run(hunt, { ourPower: 'LP' }).summary().total, 3) // 1 × (2 + 1)
  assert.equal(run(hunt, { ourPower: 'HP' }).summary().total, 2) // 1 × (1 + 1)
  assert.equal(run(hunt, { ourPower: 'QRP' }).summary().label, '1 × 4')
  // Not one of the classes Texas publishes: no term, rather than a term of its
  // own invention.
  assert.equal(run(hunt, { ourPower: 'MEDIUM' }).summary().total, 1)

  // Nothing else claimed: the power class is the WHOLE multiplier, not a floor of
  // 1 with the class ignored. §6.5.2 is "total QSO points X (power multiplier +
  // Texas State Parks worked multiplier)", and a hunter who has yet to work a
  // park still ran the power they declared. This is the case that moved when the
  // `|| 1` floor moved off the park term.
  const noParks = [qso({ mode: 'SSB' })] // 1 point, no park either side
  assert.equal(run(noParks).summary().total, 1, 'nothing declared and nothing claimed')
  assert.equal(run(noParks, { ourPower: 'QRP' }).summary().total, 3) // 1 × (3 + 0)

  // Ohio asks for a power class too — its Cabrillo carries one — and awards no
  // multiplier for it. The term follows the event's DATA, not the presence of
  // the field, which is also what keeps a class left behind by a switched
  // event from paying out.
  const ohio = [qso({ mode: 'SSB', park: 'ALU' })]
  assert.equal(run(ohio, { event: 'OHSP' }).summary().total, 1)
  assert.equal(run(ohio, { event: 'OHSP', ourPower: 'HP' }).summary().total, 1)
})

test('the power term is read from the SCORESHEET, not from the ref the summary is handed', () => {
  // This is the only reason `sheet.powerMult` exists rather than a read of
  // `ref.ourPower` in summarizeScore: the harness hands scoreQso the
  // SEGMENT-effective operation and summarizeScore the BASE one (sdk/src/scoring.ts),
  // so on a segmented log the ref that carried the class may not be the ref the
  // summary sees. Score with a ref that declares QRP, summarize with one that
  // declares nothing, and the multiplier must still be the one the QSOs were
  // scored under — otherwise a moved-park log silently loses three multipliers.
  const operation = operationFor()
  const scoringRef: Record<string, JSONValue> = { type: 'stateparks', ref: 'TXSP', ourPower: 'QRP' }
  const baseRef: Record<string, JSONValue> = { type: 'stateparks', ref: 'TXSP' }

  let sheet = StateParksScorer.startScoresheet({ operation, ref: baseRef }, ctx)
  sheet = StateParksScorer.scoreQso(
    { scoresheet: sheet, qso: qso({ mode: 'SSB', hunting: [TX_B] }), operation, ref: scoringRef, isNewDay: false },
    ctx,
  ).scoresheet

  assert.equal(sheet.powerMult, 3)
  const summary = StateParksScorer.summarizeScore({ scoresheet: sheet, operation, ref: baseRef, scope: 'operation' }, ctx).stateparks
  assert.equal(summary.total, 4, '1 point × (3 power + 1 park worked)')
})

test('a class declared in a later segment still counts', () => {
  // The scoresheet records the power term as the fold goes, and 0 is what "no
  // class declared" looks like — so recording it with `??=` latched that 0 and
  // the class could never arrive afterwards. Which is the case it is recorded
  // for: on a segmented log, `scoreQso` is handed the SEGMENT's ref, and the
  // segment that carries the class may not be the first one scored.
  const operation = operationFor()
  const bare: Record<string, JSONValue> = { type: 'stateparks', ref: 'TXSP' }
  const declared: Record<string, JSONValue> = { type: 'stateparks', ref: 'TXSP', ourPower: 'QRP' }

  let sheet = StateParksScorer.startScoresheet({ operation, ref: bare }, ctx)
  sheet = StateParksScorer.scoreQso(
    { scoresheet: sheet, qso: qso({ mode: 'SSB', hunting: [TX_B] }), operation, ref: bare, isNewDay: false },
    ctx,
  ).scoresheet
  assert.equal(sheet.powerMult, 0, 'nothing declared yet')

  sheet = StateParksScorer.scoreQso(
    { scoresheet: sheet, qso: qso({ call: 'K2XYZ', mode: 'SSB', hunting: [TX_C] }), operation, ref: declared, isNewDay: false },
    ctx,
  ).scoresheet
  assert.equal(sheet.powerMult, 3, 'the class arrived in the second segment')

  // 2 points × (3 power + 2 parks worked).
  assert.equal(StateParksScorer.summarizeScore({ scoresheet: sheet, operation, ref: bare, scope: 'operation' }, ctx).stateparks.total, 10)
})

test('the summary reads back as a scoreboard, and survives a JSON round trip', () => {
  const { sheet, summary } = run(
    [qso({ call: 'K5LRK', mode: 'SSB', hunting: [TX_B] })],
    { operation: operationFor(TX_A) },
  )

  const tally = summary()
  assert.equal(tally.key, 'stateparks')
  assert.equal(tally.icon, 'flag-checkered')
  assert.ok(tally.label, 'the information panel drops a row with no label')
  assert.ok(tally.summary, 'the day header drops a row with no summary')
  // The park table an operator reads while operating: worked parks struck out.
  assert.match(String(tally.longSummary), /parks worked/)
  assert.match(String(tally.longSummary), new RegExp(`\\*\\*~~${TX_B}~~\\*\\*`))
  assert.match(String(tally.longSummary), /~~K5LRK~~/)

  // The harness checkpoints by JSON round-trip, and the host stores the sheet as
  // JSON — anything that isn't plain data would vanish without an error.
  assert.deepEqual(JSON.parse(JSON.stringify(sheet)), sheet)
  assert.equal(sheet.eventKey, 'TXSP')
  assert.equal(sheet.powerMult, 0, 'recorded on the first QSO, like the event key')
})

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The events dataset is hand-maintained JSON copied from app-polo, so these
// tests are about the DATA and the normalization over it, not about scoring.
// Two things here can break silently on a yearly re-sync: a park abbreviation
// that names a reference the event's own list doesn't have, and a date the
// runtime cannot parse.

import { test } from "node:test"
import assert from "node:assert/strict"

import { bandCounts, daysUntil, EVENTS, eventFor, parseEventTime } from "./events.ts"

test('the four events are all present and identified by their key', () => {
  assert.deepEqual(EVENTS.map((e) => e.key), ['TXSP', 'FLSP', 'GASP', 'OHSP'])
  assert.equal(eventFor('OHSP')?.name, 'Ohio State Parks Event')
  // The ref carries whatever the operator's data carried; a key is a key
  // whatever its case.
  assert.equal(eventFor('ohsp')?.key, 'OHSP')
  assert.equal(eventFor('WISP'), undefined)
  assert.equal(eventFor(undefined), undefined)
})

test('every event has a park list, and Ohio alone exchanges abbreviations', () => {
  assert.equal(EVENTS[0].parks.length, 77, 'TXSP')
  assert.equal(EVENTS[1].parks.length, 176, 'FLSP')
  assert.equal(EVENTS[2].parks.length, 52, 'GASP')
  assert.equal(EVENTS[3].parks.length, 76, 'OHSP')

  assert.deepEqual(EVENTS.map((e) => e.usesParkAbbreviations), [false, false, false, true])
  assert.deepEqual(EVENTS.map((e) => e.exportsCabrillo), [false, false, false, true])
  assert.equal(EVENTS[3].cabrilloName, 'OHSPOTA')
})

test("Ohio's abbreviations and references agree, and both directions resolve", () => {
  const ohsp = eventFor('OHSP')!
  for (const park of ohsp.parks) {
    assert.ok(park.abbreviation, 'every Ohio park has an abbreviation')
    assert.match(park.ref, /^US-\d+$/, `${park.abbreviation} should name a POTA reference`)
    // The lookup both the scorer and the Cabrillo writer run per QSO.
    assert.equal(ohsp.parkByRef[park.ref], park)
    assert.equal(ohsp.parkByAbbreviation[park.abbreviation!], park)
  }
  assert.equal(ohsp.parkByAbbreviation.HOC?.ref, 'US-1958')
  assert.equal(ohsp.parkByRef['US-1958']?.abbreviation, 'HOC')
  assert.equal(ohsp.parkByRef['US-1958']?.name, 'Hocking Hills SP')
})

test('per-event points and rules are lifted out of the two places the data keeps them', () => {
  const txsp = eventFor('TXSP')!
  // CW is worth double in Texas; `options.multipliers` and the top-level
  // `bonusPoints` are siblings in intent and cousins in the file.
  assert.equal(txsp.points.CW, 2)
  assert.equal(txsp.points.PHONE, 1)
  assert.equal(txsp.multipliers, 'stateParksActivatedAndHunted')
  assert.equal(txsp.bonusPointsPerParkActivated, 100)
  assert.deepEqual(txsp.bonusStations, { K5LRK: 5 })

  const gasp = eventFor('GASP')!
  assert.equal(gasp.multipliers, 'stateParksActivated')
  // Georgia's 5 points for a distinct park share the `points` map with the
  // per-mode values in the file, and must not be readable as a mode.
  assert.equal(gasp.pointsPerDistinctPark, 5)
  assert.equal(gasp.points.distinctStatePark, undefined)
  assert.equal(gasp.points.CW, 1)

  assert.equal(eventFor('FLSP')!.multipliers, 'none')
})

test('the file dates parse, in a form Date.parse is not required to accept', () => {
  // Single-digit month, a space separator and a bare Z: V8 takes it, the spec
  // does not, and the runtime these events actually score in is QuickJS.
  assert.equal(parseEventTime('2026-4-18 00:00Z'), Date.UTC(2026, 3, 18, 0, 0))
  assert.equal(parseEventTime('2026-09-12 14:00Z'), Date.UTC(2026, 8, 12, 14, 0))
  assert.equal(parseEventTime('2026-04-18T12:00Z'), Date.UTC(2026, 3, 18, 12, 0))
  // Unparseable reads as "no date" rather than as 1970, which would rank every
  // event as long past.
  assert.equal(parseEventTime('sometime in April'), 0)
  assert.equal(parseEventTime(undefined), 0)

  for (const event of EVENTS) {
    assert.ok(event.startMillis > 0, `${event.key} start`)
    assert.ok(event.endMillis > event.startMillis, `${event.key} end after start`)
  }
})

test('an event more than two weeks past is next year’s, not one long gone', () => {
  const txsp = eventFor('TXSP')!
  const dayBefore = txsp.startMillis - 24 * 60 * 60 * 1000
  assert.equal(daysUntil(txsp, dayBefore), 1)
  assert.equal(daysUntil(txsp, txsp.startMillis), 0)

  // A week after it started it is still the event that just happened...
  const weekAfter = txsp.startMillis + 7 * 24 * 60 * 60 * 1000
  assert.equal(daysUntil(txsp, weekAfter), -7)
  // ...and two months after, it is next April's, so the list an operator sees
  // in June is ordered by what is coming rather than by what is furthest behind.
  const twoMonthsAfter = txsp.startMillis + 60 * 24 * 60 * 60 * 1000
  assert.equal(daysUntil(txsp, twoMonthsAfter), 305)
})

test('each event honours its own band list — the rule polo carries and never reads', () => {
  const ohsp = eventFor('OHSP')!
  // Ohio runs 80 through 10.
  assert.equal(bandCounts(ohsp, '40m'), true)
  assert.equal(bandCounts(ohsp, '160m'), false, 'not in Ohio’s list')
  assert.equal(bandCounts(ohsp, '6m'), false, 'nor is 6m')

  const flsp = eventFor('FLSP')!
  assert.equal(bandCounts(flsp, '6m'), true, 'Florida runs 6m')
  assert.equal(bandCounts(flsp, '2m'), false)

  // WARC is closed to contests everywhere, whether or not an event says so.
  for (const event of EVENTS) {
    for (const band of ['60m', '30m', '17m', '12m']) {
      assert.equal(bandCounts(event, band), false, `${event.key} on ${band}`)
    }
    assert.equal(bandCounts(event, '20m'), true, `${event.key} on 20m`)
    assert.equal(bandCounts(event, ''), false, `${event.key} with no band`)
  }

  // Texas and Georgia state no list, so anything not excluded counts.
  assert.equal(bandCounts(eventFor('TXSP')!, '6m'), true)
  assert.equal(bandCounts(eventFor('GASP')!, '160m'), true)
})

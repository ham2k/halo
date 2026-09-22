// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import { spotsFromSOTAApi, summitGlyphForPoints, type SOTAApiSpot } from "./spotMapping.ts"

/// A real `api-db2.sota.org.uk/api/spots/-1/all/all/` row, trimmed to the
/// fields the mapping reads. Every default here is a shape api2 sent
/// differently, so a test that overrides one is testing the migration.
function apiSpot(overrides: Partial<SOTAApiSpot> = {}): SOTAApiSpot {
  return {
    id: 364150,
    timeStamp: "2026-08-05T21:46:18.348572Z",
    comments: "[SOTA Activator] ",
    callsign: "N0SPOT",
    summitCode: "W7O/WV-096",
    summitName: "Sylvania, Mount",
    activatorCallsign: "KK7ER",
    activatorName: "Michael",
    frequency: 14.062,
    mode: "cw",
    points: 1,
    AltM: 297,
    AltFt: 975,
    type: null,
    epoch: "ed0601ac-a1f9-4666-98ba-2b0e52c07f5e",
    ...overrides,
  }
}

test("frequency arrives as a number in MHz, so a spot lands on the band it was posted for", () => {
  // api2 sent frequency as a string of MHz; reading api-db2's number as kHz
  // (or parseFloat-ing it twice) puts a 20m spot on the wrong band entirely.
  const [spot] = spotsFromSOTAApi([apiSpot({ frequency: 14.062 })])
  assert.equal(spot.freq, 14062)
  assert.equal(spot.band, "20m")
})

test("summitCode is the whole reference — nothing prefixes an association code onto it", () => {
  // api2 split "W7O" and "WV-096" across two fields, so the old mapping
  // joined them. Doing that here yields "W7O/W7O/WV-096".
  const [spot] = spotsFromSOTAApi([apiSpot({ summitCode: "W7O/WV-096" })])
  assert.deepEqual(spot.refs, [{ ref: "W7O/WV-096", type: "sota" }])
})

test("a QRT spot suppresses that activator's earlier spot rather than being skipped over", () => {
  // The trap: filtering non-NORMAL types before deduping drops the QRT and
  // leaves the 20m spot on the board, showing a station that has packed up.
  const spots = spotsFromSOTAApi([
    apiSpot({ id: 2, type: "QRT", timeStamp: "2026-08-05T21:46:18Z" }),
    apiSpot({ id: 1, type: "NORMAL", timeStamp: "2026-08-05T21:10:00Z" }),
  ])
  assert.deepEqual(spots, [])
})

test("a QRT still wins when the feed hands it over out of order", () => {
  // The API sends newest-first today, but nothing in the payload promises
  // it. Trusting that order silently inverts the rule above the moment it
  // changes: the older NORMAL row would win and the QRT would be discarded.
  const spots = spotsFromSOTAApi([
    apiSpot({ id: 1, type: "NORMAL", timeStamp: "2026-08-05T21:10:00Z" }),
    apiSpot({ id: 2, type: "QRT", timeStamp: "2026-08-05T21:46:18Z" }),
  ])
  assert.deepEqual(spots, [])
})

test("a null type is a normal spot — most spotters never set the field", () => {
  const spots = spotsFromSOTAApi([apiSpot({ type: null })])
  assert.equal(spots.length, 1)
})

test("TEST spots stay off the board, the way SOTAWatch hides them", () => {
  const spots = spotsFromSOTAApi([apiSpot({ type: "TEST" })])
  assert.deepEqual(spots, [])
})

test("a TEST spot doesn't take the activator's live spot down with it", () => {
  // The trap: TEST is dropped like QRT, on the far side of the dedupe. It
  // would then win as the newest row and be filtered out, erasing a station
  // that is on the air. An operator posts one just by putting "test" in a
  // spot comment (see index.ts's postSpotToSOTA), so this is reachable.
  const spots = spotsFromSOTAApi([
    apiSpot({ id: 2, type: "TEST", timeStamp: "2026-08-05T21:46:18Z" }),
    apiSpot({ id: 1, type: "NORMAL", frequency: 14.062, timeStamp: "2026-08-05T21:10:00Z" }),
  ])
  assert.deepEqual(
    spots.map((spot) => spot.spot.sourceInfo?.id),
    [1],
  )
})

test("two spots sharing a timestamp break the tie by id, not by the order the feed sent them", () => {
  // Without the tiebreak the sort is stable and falls back to feed order —
  // the very thing the sort exists not to trust.
  const sameTime = "2026-08-05T21:46:18Z"
  const spots = spotsFromSOTAApi([apiSpot({ id: 1, type: "NORMAL", timeStamp: sameTime }), apiSpot({ id: 2, type: "QRT", timeStamp: sameTime })])
  assert.deepEqual(spots, [])
})

test("a type this code has never heard of does not reach the board as a live spot", () => {
  // The trap: filtering `!== 'QRT'` renders anything SOTA adds later — a
  // soft-delete marker, a reservation — as an ordinary spot to tune to.
  const spots = spotsFromSOTAApi([apiSpot({ type: "DELETED" })])
  assert.deepEqual(spots, [])
})

test("only the newest spot per activator survives, whatever else they are spotted on", () => {
  const spots = spotsFromSOTAApi([
    apiSpot({ id: 2, frequency: 7.032, timeStamp: "2026-08-05T21:46:18Z" }),
    apiSpot({ id: 1, frequency: 14.062, timeStamp: "2026-08-05T21:10:00Z" }),
    apiSpot({ id: 3, activatorCallsign: "W1AW", timeStamp: "2026-08-05T21:40:00Z" }),
  ])
  assert.deepEqual(
    spots.map((spot) => spot.spot.sourceInfo?.id),
    [2, 3],
  )
})

test("the label carries points as a glyph and altitude from AltM, not from free text", () => {
  // api2 packed name, altitude and points into one `summitDetails` string;
  // api-db2 sends three fields, so the label is rebuilt rather than parsed.
  const [spot] = spotsFromSOTAApi([apiSpot({ points: 6, summitName: "Stuhleck", AltM: 1782, summitCode: "OE/ST-171" })])
  assert.equal(spot.spot.label, "\u{278F} OE/ST-171: Stuhleck, 1782m")
})

test("timeStamp already carries its Z, so the spot's age is UTC and not the operator's local time", () => {
  // api2 sent a naive timestamp the old mapping appended 'Z' to. Appending a
  // second one makes Date.parse return NaN; dropping it reads the time as local.
  const [spot] = spotsFromSOTAApi([apiSpot({ timeStamp: "2026-08-05T21:46:18.348572Z" })])
  assert.equal(spot.spot.timeInMillis, Date.UTC(2026, 7, 5, 21, 46, 18, 348))
})

test("summitGlyphForPoints covers the whole 1-10 range and nothing outside it", () => {
  assert.equal(summitGlyphForPoints(1), "\u{278A}")
  assert.equal(summitGlyphForPoints(10), "\u{2793}")
  assert.equal(summitGlyphForPoints(0), "")
  assert.equal(summitGlyphForPoints(11), "")
  assert.equal(summitGlyphForPoints(undefined), "")
})

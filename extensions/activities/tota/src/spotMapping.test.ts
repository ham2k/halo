// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import { spotsFromTOTAApi, type TOTAApiSpot } from "./spotMapping.ts"

const NOW = Date.parse("2026-08-31T18:00:00Z")

/// Minutes before [NOW], as the feed writes them.
function ago(minutes: number): string {
  return new Date(NOW - minutes * 60 * 1000).toISOString()
}

/// A real `cluster.php` row's fields, as the award publishes them.
function apiSpot(overrides: Partial<TOTAApiSpot> = {}): TOTAApiSpot {
  return {
    callsign: "ok1abc",
    tower_ref: "OKR-0001",
    frequency: 14285,
    mode: "ssb",
    time_utc: ago(5),
    comment: "",
    spotter: "OK1XYZ",
    ...overrides,
  }
}

test("the feed's own field names are read, and the callsign is normalized", () => {
  // `call`/`freq`/`ref`/`time` are the names every other award in the port
  // uses; reading those here yields a full board of blank spots rather than
  // an error.
  const [spot] = spotsFromTOTAApi([apiSpot()]).spots
  assert.equal(spot.their.call, "OK1ABC")
  assert.equal(spot.freq, 14285)
  assert.equal(spot.band, "20m")
  assert.deepEqual(spot.refs, [{ ref: "OKR-0001", type: "tota" }])
  assert.equal(spot.spot.timeInMillis, Date.parse(ago(5)))
})

test("rozhledny publishes numbers as strings, so a frequency still lands on its band", () => {
  // The tower list ships every numeric field quoted; assuming the cluster
  // does otherwise leaves a spot with no frequency and no band at all.
  const [spot] = spotsFromTOTAApi([apiSpot({ frequency: "14285" })]).spots
  assert.equal(spot.freq, 14285)
  assert.equal(spot.band, "20m")
})

test("nothing is aged out here — the app's own maxSpotAge governs every source together", () => {
  // app-polo cuts the feed at an hour. Doing that here retires a TOTA spot
  // while a POTA one posted at the same moment stays, and leaves TOTA
  // contributing nothing to the panel age filter's longest bucket.
  const spots = spotsFromTOTAApi([apiSpot({ callsign: "ok1old", time_utc: ago(150) }), apiSpot({ callsign: "ok1new", time_utc: ago(30) })]).spots
  assert.deepEqual(
    spots.map((s) => s.their.call),
    ["OK1NEW", "OK1OLD"],
  )
})

test("a QRT suppresses that station's earlier spot rather than being skipped over", () => {
  // The trap: dropping QRT comments before deduping leaves the earlier spot
  // on the board, showing a station that has packed up as still calling.
  const spots = spotsFromTOTAApi([apiSpot({ time_utc: ago(2), comment: "QRT thanks all" }), apiSpot({ time_utc: ago(20), comment: "" })]).spots
  assert.deepEqual(spots, [])
})

test("a QRT still wins when the feed hands it over out of order", () => {
  // Nothing in the payload promises an order, and trusting the feed's would
  // invert the rule above the moment the award reverses it.
  const spots = spotsFromTOTAApi([apiSpot({ time_utc: ago(20), comment: "" }), apiSpot({ time_utc: ago(2), comment: "QRT thanks all" })]).spots
  assert.deepEqual(spots, [])
})

test("only the newest spot per station survives, whatever order the feed used", () => {
  // A station that re-spots on a new band would otherwise appear twice, and
  // an oldest-first feed would leave the stale band as the one shown.
  const spots = spotsFromTOTAApi([apiSpot({ time_utc: ago(40), frequency: 7050 }), apiSpot({ time_utc: ago(3), frequency: 14285 })]).spots
  assert.equal(spots.length, 1)
  assert.equal(spots[0].freq, 14285)
})

test("a QRT posted in the same second as the spot it retracts still wins", () => {
  // The feed stamps to the second, so a self-spot and the QRT that follows it
  // can share a timestamp. Without a tiebreaker that pair falls back to the
  // feed's own order — the dependency the sort exists to remove — and the
  // retracted spot goes to the board.
  const sameSecond = ago(2)
  const spots = spotsFromTOTAApi([apiSpot({ time_utc: sameSecond, comment: "" }), apiSpot({ time_utc: sameSecond, comment: "QRT thanks all" })]).spots
  assert.deepEqual(spots, [])
})

test("a row naming no station is dropped, and does not claim a slot the next one needs", () => {
  // Deduping on an empty callsign publishes one blank board entry and then
  // silently swallows every other call-less row as its duplicate.
  const spots = spotsFromTOTAApi([
    apiSpot({ callsign: "", tower_ref: "OKR-0002" }),
    apiSpot({ callsign: undefined, tower_ref: "OKR-0003" }),
    apiSpot({ callsign: "ok1abc" }),
  ]).spots
  assert.deepEqual(
    spots.map((s) => s.their.call),
    ["OK1ABC"],
  )
})

test("a spot with an unparseable timestamp is dropped, and the drop is counted", () => {
  // An unranked entry would beat the QRT that followed it, and the app reads
  // an absent time as the epoch and drops it from call lookup regardless. The
  // count is the only thing standing between a wire format that moved under us
  // and a board that has simply gone quiet.
  const mapping = spotsFromTOTAApi([apiSpot({ time_utc: "" }), apiSpot({ time_utc: "not a date" })])
  assert.deepEqual(mapping.spots, [])
  assert.equal(mapping.undated, 2)
})

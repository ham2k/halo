// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import { exportFilename, startMillisOf } from "./exportNames.ts"

// 2026-07-27T14:30:00Z
const JULY_27 = Date.UTC(2026, 6, 27, 14, 30)

test("the normal form reads as a sentence, date first", () => {
  assert.equal(
    exportFilename({ stationCall: "N0CALL", ref: "US-1234", startAtMillis: JULY_27, extension: "adi" }),
    "2026-07-27 N0CALL at US-1234.adi",
  )
})

test("the compact form leads with the callsign, so a station's files sort together", () => {
  assert.equal(
    exportFilename({ stationCall: "N0CALL", ref: "US-1234", startAtMillis: JULY_27, extension: "adi", compact: true }),
    "N0CALL@US-1234-20260727.adi",
  )
})

test("an activity with no single reference takes the 'for' form", () => {
  const parts = { stationCall: "N0CALL", activity: "POTA", startAtMillis: JULY_27, extension: "adi" }
  assert.equal(exportFilename(parts), "2026-07-27 N0CALL for POTA.adi")
  assert.equal(exportFilename({ ...parts, compact: true }), "N0CALL-pota-20260727.adi")
})

test("with neither ref nor activity the modifier carries the meaning", () => {
  const parts = { stationCall: "N0CALL", modifier: "Field Day", startAtMillis: JULY_27, extension: "adi" }
  assert.equal(exportFilename(parts), "2026-07-27 N0CALL Field Day.adi")
  assert.equal(exportFilename({ ...parts, compact: true }), "N0CALL-20260727-field-day.adi")
})

test("the modifier survives into the ref forms too", () => {
  const parts = { stationCall: "N0CALL", ref: "US-1234", modifier: "CW", startAtMillis: JULY_27, extension: "adi" }
  assert.equal(exportFilename(parts), "2026-07-27 N0CALL at US-1234 CW.adi")
  assert.equal(exportFilename({ ...parts, compact: true }), "N0CALL@US-1234-20260727-cw.adi")
})

// The date is what the log is ABOUT. A UK operator exporting an evening
// activation would otherwise see tomorrow's date on a file full of today's
// QSOs, because the local day had already rolled over.
test("the date is UTC, not the reader's local day", () => {
  const lateUtc = Date.UTC(2026, 6, 27, 23, 45)
  assert.equal(
    exportFilename({ stationCall: "N0CALL", startAtMillis: lateUtc, extension: "adi" }),
    "2026-07-27 N0CALL.adi",
  )
})

test("path separators can't escape the filename", () => {
  const name = exportFilename({ stationCall: "N0CALL", modifier: "../../etc/passwd", startAtMillis: JULY_27, extension: "adi" })
  assert.ok(!name.includes("/"), `expected no separators in ${name}`)
  assert.ok(!name.includes("\\"), `expected no separators in ${name}`)
})

// Slashed calls are ordinary — a portable operator is `N0CALL/P`, and the
// slug has to keep them distinguishable rather than collapsing to the base.
test("a slashed callsign keeps both halves", () => {
  assert.equal(
    exportFilename({ stationCall: "N0CALL/P", ref: "US-1234", startAtMillis: JULY_27, extension: "adi", compact: true }),
    "N0CALL-P@US-1234-20260727.adi",
  )
})

// A part that is punctuation only slugs away to nothing, and the separator
// beside it has to go too — a `N0CALL--20260727.adi` reads as a bug in the
// app. `activity` is caller-supplied, so this is reachable.
test("a part that slugs away takes its separator with it", () => {
  assert.equal(
    exportFilename({ stationCall: "N0CALL", activity: "!!!", startAtMillis: JULY_27, extension: "adi", compact: true }),
    "N0CALL-20260727.adi",
  )
  assert.equal(
    exportFilename({ stationCall: "!!!", ref: "US-1234", startAtMillis: JULY_27, extension: "adi", compact: true }),
    "US-1234-20260727.adi",
  )
})

// An operation with no callsign, no title and no refs still has to produce
// something openable: ".adi" alone is an extensionless dotfile that hides on
// Unix and shows as nameless everywhere else.
test("an empty operation still gets a usable name", () => {
  const name = exportFilename({ startAtMillis: 0, extension: "adi", stationCall: "" })
  assert.ok(name.endsWith(".adi"))
  assert.ok(!name.startsWith("."), `expected a real stem, got ${name}`)
})

test("startMillisOf prefers the first QSO over the operation's own start", () => {
  const operation = { startAtMillisMin: JULY_27 }
  const qsos = [{ startAtMillis: JULY_27 + 5000 }, { startAtMillis: JULY_27 + 1000 }]
  assert.equal(startMillisOf(operation, qsos), JULY_27 + 1000)
})

test("startMillisOf falls back to the operation when there are no QSOs yet", () => {
  assert.equal(startMillisOf({ startAtMillisMin: JULY_27 }, []), JULY_27)
})

test("startMillisOf returns undefined when nothing has a date, so the caller can use now", () => {
  assert.equal(startMillisOf({}, [{ startAtMillis: 0 }]), undefined)
})

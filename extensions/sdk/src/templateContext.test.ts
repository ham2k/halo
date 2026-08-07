// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

// A log's dates are UTC, and a test process in UTC can't tell a correct
// conversion from a missing one.
process.env.TZ = "America/New_York"

import { test } from "node:test"
import assert from "node:assert/strict"

import { renderTemplate } from "./templates.ts"
import { opValues, qsoValues, templateContext } from "./templateContext.ts"

// 2026-07-27T23:45:00Z — the evening activation whose LOCAL day has already
// rolled over west of Greenwich.
const LATE_JULY_27 = Date.UTC(2026, 6, 27, 23, 45)

test("operation dates are the log's UTC day, not the reader's", () => {
  const op = opValues({ stationCall: "N0CALL", startAtMillisMin: LATE_JULY_27 })
  assert.equal(op.date, "2026-07-27")
  assert.equal(op.dateCompact, "20260727")
  assert.equal(op.startTime, "2345")
})

// The `…At` fields exist so a template can format a timestamp itself. Feeding
// raw millis to liquid's `date` filter is silently absurd — it reads a number
// as SECONDS, so an epoch-millis value renders in the year 58567 — which is
// why the context carries ISO strings instead.
test("the At fields are ISO UTC, ready for the date filter", () => {
  const op = opValues({ startAtMillisMin: LATE_JULY_27 })
  assert.equal(op.startAt, "2026-07-27T23:45:00.000Z")
  assert.equal(renderTemplate("{{ op.startAt | date: '%H:%M' }}", { op }), "23:45")
  assert.notEqual(renderTemplate("{{ ms | date: '%Y' }}", { ms: LATE_JULY_27 }), "2026")
})

// One comma-separated field here, `stationCall` + `stationCallPlusArray` in
// app-polo (halo_core's Operation.stationCalls splits the same way). A
// template that names one station and one that fans out over all of them both
// have to work.
test("several station callsigns are offered as a list as well as the raw field", () => {
  const op = opValues({ stationCall: "N0CALL, n0dev , N0CALL" })
  assert.equal(op.station, "N0CALL, n0dev , N0CALL")
  assert.deepEqual(op.stations, ["N0CALL", "N0DEV"])
})

test("a station-less operation yields no phantom callsign", () => {
  assert.deepEqual(opValues({}).stations, [])
})

// `startAtMillisMin` is a COLUMN on the operation row, not a key in the QSON
// `data` that hooks are handed, so most callers have no operation dates at
// all. Falling back to `Date.now()` would print today's date on a pane
// showing yesterday's log, with nothing to say it was invented — the panel
// host adds the column deliberately, and the ADIF export passes `atMillis`.
test("an operation with no dates in the payload says so, rather than saying today", () => {
  const op = opValues({ stationCall: "N0CALL" })
  assert.equal(op.date, "")
  assert.equal(op.dateCompact, "")
  assert.equal(op.at, "")
  assert.equal(op.startDate, "")
})

test("a caller that knows the log's instant supplies it", () => {
  const context = templateContext({ operation: { stationCall: "N0CALL" }, atMillis: LATE_JULY_27 })
  assert.equal(renderTemplate("{{ op.date }}", context), "2026-07-27")
})

// QSON writes the report each side SENT under its own `sent`, so `their.sent`
// is what we RECEIVED. Naming them after the operator's own words is the
// point; getting the direction backwards would put every report in the wrong
// ADIF field.
test("the reports are named by direction, not by QSON's field name", () => {
  const qso = qsoValues({ our: { sent: "59" }, their: { call: "W1AW", sent: "57" } })
  assert.equal(qso.rstSent, "59")
  assert.equal(qso.rstRcvd, "57")
  assert.equal(qso.call, "W1AW")
})

// The lookup's answer lives under `their.guess` and nowhere else, so the
// nesting is passed through whole rather than flattened into a second
// vocabulary for the same data.
test("the lookup guess is reachable through the QSO's own shape", () => {
  const qso = qsoValues({ their: { call: "W1AW", guess: { name: "Hiram", state: "CT" } } })
  assert.equal(renderTemplate("{{ qso.their.guess.name }} in {{ qso.their.guess.state }}", { qso }), "Hiram in CT")
})

test("a QSO with no timestamp yields empty date fields rather than 1970", () => {
  const qso = qsoValues({ their: { call: "W1AW" } })
  assert.equal(qso.date, "")
  assert.equal(qso.at, "")
})

// `{% if qso %}` is the only way a template can ask "is there a contact
// here?", and a stub object would answer it wrong — a panel with no logging
// field in the view genuinely has no QSO.
test("a namespace the surface has nothing for is absent, not blank", () => {
  const context = templateContext({ operation: { stationCall: "N0CALL" }, appName: "Ham2K Logger" })
  assert.equal("qso" in context, false)
  assert.equal("log" in context, false)
  assert.equal(renderTemplate("{% if qso %}QSO{% else %}none{% endif %}", context), "none")
  assert.equal(renderTemplate("{{ app.name }}", context), "Ham2K Logger")
})

test("a panel's own config is offered under config", () => {
  const context = templateContext({ config: { title: "Skeds" }, nowMillis: LATE_JULY_27 })
  assert.equal(renderTemplate("{{ config.title }} at {{ now | date: '%H:%M' }}", context), "Skeds at 23:45")
})

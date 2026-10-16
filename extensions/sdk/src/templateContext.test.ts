// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
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
test("op.call is op.station under the name qso.call has", () => {
  // The trap: an alias that is only in the docs. It has to be in the object.
  const op = opValues({ stationCall: "N0CALL" })
  assert.equal(op.call, "N0CALL")
  assert.equal(op.call, op.station)
})

test("several station callsigns are offered as a list as well as the raw field", () => {
  const op = opValues({ stationCall: "N0CALL, n0dev , N0CALL" })
  assert.equal(op.station, "N0CALL, n0dev , N0CALL")
  assert.deepEqual(op.stations, ["N0CALL", "N0DEV"])
})

// The host stores the operator under `operatorCall`, per position when the
// device has one, and nothing writes an `operator` key: a template reading
// that renders `DE ` with no error to say why.
test("op.operator is the operator the host resolved for this device", () => {
  assert.equal(opValues({ stationCall: "K2SUL", operatorCall: "B1B" }).operator, "B1B")
  assert.equal(renderTemplate("DE {{ op.operator }}", { op: opValues({ operatorCall: "B1B" }) }), "DE B1B")
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

// A draft's `their.call` is the field as typed — "KN2//KI2D//NK2Y//FR" keyed
// verbatim would send every slash in Morse. The panel's own reading of the
// field has to win, and a logged contact (no `callField`) still reads its call.
test("a draft's call is the one Enter logs, with the rest of the stack named apart", () => {
  const draft = qsoValues({
    their: { call: "KN2//KI2D//NK2Y//FR" },
    callField: { call: "NK2Y", fullCall: "NK2Y", partial: "", nextCall: "KI2D", nextPartial: "FR" },
  })
  assert.equal(draft.call, "NK2Y")
  assert.equal(draft.nextCall, "KI2D")
  assert.equal(draft.nextPartial, "FR")
  assert.equal((draft.their as Record<string, unknown>).call, "KN2//KI2D//NK2Y//FR", "their stays the draft as typed")

  const blank = qsoValues({ their: { call: "W1AW," }, callField: { call: "", nextCall: "", nextPartial: "" } })
  assert.equal(blank.call, "W1AW,", "a blank reading keys the field rather than nothing")

  const partial = qsoValues({ their: { call: "KR" }, callField: { call: "KR", fullCall: "", partial: "KR", nextCall: "", nextPartial: "" } })
  assert.equal(partial.fullCall, "", "a partial is never keyed as a station")
  assert.equal(partial.partial, "KR")

  const logged = qsoValues({ their: { call: "W1AW" } })
  assert.equal(logged.call, "W1AW")
  assert.equal(logged.nextCall, "")
  assert.equal(logged.nextPartial, "")
  assert.equal(logged.fullCall, "W1AW")
  assert.equal(logged.partial, "")
})

// A CW message greeting a station reads what the operator typed first and
// the lookup second; a typed-but-blank field must not hide the lookup, and a
// full name keyed in Morse is not a greeting.
test("state and name prefer what was typed, fall back to the lookup, and name is one word", () => {
  const typed = qsoValues({ their: { call: "W1AW", state: "CT", name: "Hiram Percy", guess: { state: "MA", name: "Someone Else" } } })
  assert.equal(typed.state, "CT")
  assert.equal(typed.name, "Hiram")

  const looked = qsoValues({ their: { call: "W1AW", state: " ", name: "", guess: { state: "MA", name: "Robert J Smith" } } })
  assert.equal(looked.state, "MA")
  assert.equal(looked.name, "Robert")

  const neither = qsoValues({ their: { call: "W1AW" } })
  assert.equal(neither.state, "")
  assert.equal(neither.name, "")
})

// A contest's serials live on its own ref, under a type a CW message has no
// way to know. They are found by FIELD NAME, which is what lets one message
// serve every serial contest — and what breaks silently if a contest names
// its field anything else.
test("serials are found on whichever ref carries them", () => {
  const qso = qsoValues({
    their: { call: "W1AW" },
    refs: [
      { type: "pota", ref: "US-1234" },
      { type: "cqwpx", ourSerial: 12, theirSerial: "345" },
    ],
  })
  assert.equal(qso.serialSent, "12")
  assert.equal(qso.serialRcvd, "345")
})

// Sent, not received: these are typed into a message WE key. Pointing either
// at the other side would send the other station their own exchange back.
test("the short names are the sent side", () => {
  const qso = qsoValues({
    our: { sent: "599" },
    their: { call: "W1AW", sent: "579" },
    refs: [{ type: "cqwpx", ourSerial: 12, theirSerial: 345 }],
  })
  assert.equal(qso.rst, "599")
  assert.equal(qso.serial, "12")
})

// The draft drops a cleared serial from its ref and an ordinary QSO has no
// contest ref at all, but a ref from an import or another extension can carry
// a blank or a null. All of them must render nothing — never "undefined", and
// never a throw that takes the whole message with it.
test("a QSO without a serial yields blanks", () => {
  assert.equal(qsoValues({ their: { call: "W1AW" } }).serial, "")
  assert.equal(qsoValues({ refs: [{ type: "cqwpx", ourSerial: "" }] }).serialSent, "")
  assert.equal(qsoValues({ refs: [{ type: "cqwpx", ourSerial: null }, null, "x"] }).serialSent, "")
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

// One message named inside another is the point of `keyer`: a thanks that
// ends in the CQ. It has to arrive RENDERED — the CQ's own `{{ op.call }}`
// keyed as braces would be nonsense on the air — and a loop has to be an
// error the operator can read, not a hang and not a silently shorter message.
test("keyer.msgN is that message rendered, and a message that reaches itself is an error naming the loop", () => {
  const messages = ["CQ DE {{ op.call }} K", "{{ keyer.msg3 }}", "TU {% if qso.call != blank %}{{ keyer.msg1 }}{% endif %}", "{{ keyer.msg4 }}"]
  const context = (current?: number) => templateContext({ operation: { stationCall: "N0DEV" }, qso: { their: { call: "W1AW" } }, keyer: { messages, current } })

  assert.equal(renderTemplate(messages[2], context(3)), "TU CQ DE N0DEV K")
  assert.equal(renderTemplate(messages[1], context(2)), "TU CQ DE N0DEV K", "an include of an include")
  assert.equal(
    renderTemplate(messages[2], templateContext({ operation: { stationCall: "N0DEV" }, keyer: { messages, current: 3 } })),
    "TU ",
    "never expanded when the branch isn't taken",
  )

  assert.throws(() => renderTemplate(messages[3], context(4)), /F4 → F4/)
  assert.throws(() => renderTemplate("{{ keyer.msg2 }}", context(3)), /F3 → F2 → F3/)
  assert.equal(renderTemplate("{{ keyer.msg3 }}", context()), "TU CQ DE N0DEV K", "a label renders a message without being one")
})

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// Set before anything reads a Date: several of these assertions are about
// NOT rendering in the host's zone, and a test process running in UTC could
// not tell the difference. Node re-reads TZ per call, so this is enough.
process.env.TZ = "America/New_York"

import { test } from "node:test"
import assert from "node:assert/strict"

import { TemplateError, oneLine, renderTemplate, triggersForTemplate } from "./templates.ts"

test("renders values and conditionals from the context", () => {
  assert.equal(
    renderTemplate("{{ op.station }}{% if op.qsoCount > 100 %} busy{% endif %}", {
      op: { station: "N0CALL", qsoCount: 142 },
    }),
    "N0CALL busy",
  )
})

// The whole reason the engine is configured in one place. Liquid's `date`
// filter formats in the HOST's zone by default, so a log kept in UTC would be
// stamped with the reader's evening — and `timezoneOffset` takes minutes
// BEHIND UTC, so the plausible "fix" of -300 for US Eastern renders UTC+5.
test("the date filter is UTC, whatever zone the machine is in", () => {
  assert.equal(renderTemplate("{{ t | date: '%Y-%m-%d %H:%M' }}", { t: "2026-08-06T01:30:00Z" }), "2026-08-06 01:30")
})

// Guards in our own templates are written `!= blank` because of this: a bare
// `{% if x %}` on an empty string is TRUE in liquid, which silently leaves in
// every separator the guard existed to drop (exportNames.ts).
test("an empty string is truthy, so blankness has to be asked for explicitly", () => {
  assert.equal(renderTemplate("{% if s %}yes{% endif %}", { s: "" }), "yes")
  assert.equal(renderTemplate("{% if s != blank %}yes{% endif %}", { s: "" }), "")
})

// Operator-facing leniency: one typo costs one line, not the document. Our
// own templates rely on tests rather than on strict mode.
test("an unknown variable renders empty and an unknown filter passes its value through", () => {
  assert.equal(renderTemplate("[{{ nope.deep }}]", {}), "[]")
  assert.equal(renderTemplate("{{ n | bogus }}", { n: 7 }), "7")
})

test("a template error names the line and column, because someone has to fix it", () => {
  assert.throws(
    () => renderTemplate("line one\n{{ unclosed", {}),
    (e: unknown) => e instanceof TemplateError && /line:2/.test((e as Error).message),
  )
})

// A loop's bound is whatever the template asked for, and a panel render sits
// inside the host's five-second budget: without the limit this hangs the pane
// rather than reporting the template that did it.
test("a runaway loop is abandoned rather than allowed to hold the render", () => {
  assert.throws(
    () => renderTemplate("{% for i in (1..50000000) %}{{ i }}{% endfor %}", {}),
    (e: unknown) => e instanceof TemplateError && /limit/i.test((e as Error).message),
  )
})

test("dash keeps identifiers legible while downcase|dash flattens free text", () => {
  assert.equal(renderTemplate("{{ c | dash }} {{ r | dash }}", { c: "N0CALL/P", r: "US-1234" }), "N0CALL-P US-1234")
  assert.equal(renderTemplate("{{ t | downcase | dash }}", { t: "Field Day 2026!" }), "field-day-2026")
})

test("alnum strips a date to a filename token", () => {
  assert.equal(renderTemplate("{{ d | alnum }}", { d: "2026-07-27" }), "20260727")
})

// Our filters must not shadow liquid's: `registerFilter` overwrites in
// silence, so a template written against liquid's documentation would return
// plausible nonsense with no error. `compact` drops nils from an array, and
// `op.refs`/`qso.refs` are arrays in the standard vocabulary.
test("liquid's own compact still works on a list", () => {
  assert.equal(
    renderTemplate("{{ refs | compact | join: ',' }}", { refs: ["US-1234", null, "US-5678"] }),
    "US-1234,US-5678",
  )
})

test("oneLine closes up the gaps an absent value leaves behind", () => {
  assert.equal(oneLine("2026-07-27 N0CALL  at US-1234 \n"), "2026-07-27 N0CALL at US-1234")
})

// The point of deriving these: a panel that renders operator text can't know
// what the text wants until it reads it, and declaring the whole set would
// put every custom panel on the typing path.
test("triggers are derived from the namespaces a template actually names", () => {
  assert.deepEqual(triggersForTemplate("just words"), [])
  assert.deepEqual(triggersForTemplate("{{ op.station }}"), ["operation"])
  assert.deepEqual(triggersForTemplate("{{ op.qsoCount }} QSOs"), ["qsoLogged", "operation"])
  assert.deepEqual(triggersForTemplate("{{ now | date: '%H:%M' }}"), ["tick:30"])
})

// `qso.their.guess` is filled in by the lookup, which lands after the draft
// changes — a template naming the callsign that didn't also ask for `lookup`
// would show the call with a permanently empty name beside it.
test("naming the QSO asks for the lookup too", () => {
  assert.deepEqual(triggersForTemplate("Working {{ qso.their.call }}"), ["qso", "lookup"])
})

// Tag syntax, not just output syntax: `{% if qso %}` is how a template asks
// whether there is a QSO at all, and it has to count as naming one.
test("a qso mentioned in a tag counts as much as one that is printed", () => {
  assert.deepEqual(triggersForTemplate("{% if qso %}x{% endif %}"), ["qso", "lookup"])
})

// A Custom Text pane is mostly prose, and these words are ordinary English.
// Scanning the whole document would put the operation view on the
// per-keystroke draft path for a static band plan — the exact cost
// per-instance triggers exist to avoid.
test("prose is not a request: only template spans are read", () => {
  assert.deepEqual(triggersForTemplate("Goal: 100 qso today"), [])
  assert.deepEqual(triggersForTemplate("Antennas are now on the 20m dipole"), [])
  assert.deepEqual(triggersForTemplate("Ask the op before keying"), [])
  assert.deepEqual(triggersForTemplate("[QRZ](https://qrz.com/db/op)"), [])
})

test("a span inside prose is still read", () => {
  assert.deepEqual(triggersForTemplate("Band plan\n\n{{ op.station }} is on 20m"), ["operation"])
})

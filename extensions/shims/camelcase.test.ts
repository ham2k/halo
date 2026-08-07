// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import camelCase from "./camelcase.ts"

// This shim stands in for the npm `camelcase` package (see camelcase.ts), so
// the thing worth testing is not "does it camel-case" but "does it still agree
// with the package it replaces, on the inputs its one consumer produces".
//
// That input set is closed and knowable: @ham2k/lib-qson-cabrillo upper-cases
// each line before matching it against /^([A-Z-]+):\s*(.*)\s*$/, so the only
// strings that can ever reach this function are A-Z and hyphen. Nothing here
// needs to handle unicode, digits, or mixed case coming from Cabrillo — which
// is precisely why an ASCII implementation is sufficient.
//
// The expectations below were captured from camelcase@8 itself. A mismatch
// means the shim drifted, and that Cabrillo headers land under the wrong keys.
const CABRILLO_V3_TAGS: Record<string, string> = {
  "START-OF-LOG": "startOfLog",
  "END-OF-LOG": "endOfLog",
  CALLSIGN: "callsign",
  CONTEST: "contest",
  "CATEGORY-ASSISTED": "categoryAssisted",
  "CATEGORY-BAND": "categoryBand",
  "CATEGORY-MODE": "categoryMode",
  "CATEGORY-OPERATOR": "categoryOperator",
  "CATEGORY-POWER": "categoryPower",
  "CATEGORY-STATION": "categoryStation",
  "CATEGORY-TIME": "categoryTime",
  "CATEGORY-TRANSMITTER": "categoryTransmitter",
  "CATEGORY-OVERLAY": "categoryOverlay",
  CERTIFICATE: "certificate",
  "CLAIMED-SCORE": "claimedScore",
  CLUB: "club",
  "CREATED-BY": "createdBy",
  EMAIL: "email",
  "GRID-LOCATOR": "gridLocator",
  LOCATION: "location",
  NAME: "name",
  ADDRESS: "address",
  "ADDRESS-CITY": "addressCity",
  "ADDRESS-STATE-PROVINCE": "addressStateProvince",
  "ADDRESS-POSTALCODE": "addressPostalcode",
  "ADDRESS-COUNTRY": "addressCountry",
  OPERATORS: "operators",
  OFFTIME: "offtime",
  SOAPBOX: "soapbox",
  QSO: "qso",
  "X-QSO": "xQso",
  "X-INSTRUCTION": "xInstruction",
}

test("matches camelcase@8 on every Cabrillo v3 header tag", () => {
  for (const [tag, expected] of Object.entries(CABRILLO_V3_TAGS)) {
    assert.equal(camelCase(tag), expected, `tag ${tag}`)
  }
})

// parseCabrillo dispatches on these six by identity. A drift in any one of
// them does not throw — it silently reroutes a line: a mangled "startOfLog"
// drops the log's version, and a mangled "qso" files contacts as headers.
test("the tags parseCabrillo dispatches on are exact", () => {
  assert.equal(camelCase("START-OF-LOG"), "startOfLog")
  assert.equal(camelCase("END-OF-LOG"), "endOfLog")
  assert.equal(camelCase("QSO"), "qso")
  assert.equal(camelCase("X-QSO"), "xQso")
  assert.equal(camelCase("SOAPBOX"), "soapbox")
  assert.equal(camelCase("ADDRESS"), "address")
})

// Cabrillo cannot produce these, but the shim keeps camelcase@8's signature
// and separator set, so the next caller may. Pinned to upstream's behaviour so
// the shim stays a drop-in rather than quietly becoming its own dialect.
test("keeps camelcase@8 semantics beyond the Cabrillo tag set", () => {
  assert.equal(camelCase("foo_bar"), "fooBar")
  assert.equal(camelCase("foo.bar"), "fooBar")
  assert.equal(camelCase("foo bar"), "fooBar")
  assert.equal(camelCase(["foo", "bar"]), "fooBar")
  // An all-caps word lowercases whole; inner humps survive in a mixed word.
  assert.equal(camelCase("FOO"), "foo")
  assert.equal(camelCase("fooBar"), "fooBar")
})

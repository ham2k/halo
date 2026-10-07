// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import { adifAddress } from "./address.ts"

test("adifAddress writes the mailing address a card goes to, one line per part, CR LF between them", () => {
  const source = { street: "225 Main St", city: "Newington", state: "CT", postal: "06111", country: "United States" }
  assert.equal(adifAddress("ARRL HQ", source), "ARRL HQ\r\n225 Main St\r\nNewington, CT 06111\r\nUnited States")
})

test("adifAddress leaves out the parts a record does not have", () => {
  assert.equal(adifAddress(undefined, { street: "225 Main St", city: "Newington" }), "225 Main St\r\nNewington")
})

// A town alone is what QTH already carries; ADDRESS stating it would claim a
// mailing address the log does not have.
test("adifAddress writes nothing without a street", () => {
  assert.equal(adifAddress("ARRL HQ", { city: "Newington", state: "CT", postal: "06111", country: "United States" }), undefined)
})

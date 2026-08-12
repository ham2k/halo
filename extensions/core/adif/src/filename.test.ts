// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import { filenameFor } from "./filename.ts"

// 2026-07-27T14:30:00Z
const JULY_27 = Date.UTC(2026, 6, 27, 14, 30)

test("an untitled operation's filename is just 'Full'", () => {
  const operation = { stationCall: "N0CALL" }
  assert.equal(filenameFor(operation, [{ startAtMillis: JULY_27 }]), "2026-07-27 N0CALL Full.adi")
})

test("a titled operation trails 'Full' after the title, so two same-day exports don't collide", () => {
  const operation = { stationCall: "N0CALL", title: "Field Day" }
  assert.equal(filenameFor(operation, [{ startAtMillis: JULY_27 }]), "2026-07-27 N0CALL Field Day Full.adi")
})

test("a whitespace-only title is treated as no title", () => {
  const operation = { stationCall: "N0CALL", title: "   " }
  assert.equal(filenameFor(operation, [{ startAtMillis: JULY_27 }]), "2026-07-27 N0CALL Full.adi")
})

test("the compact form slugs the title ahead of 'full'", () => {
  const operation = { stationCall: "N0CALL", title: "Field Day" }
  assert.equal(filenameFor(operation, [{ startAtMillis: JULY_27 }], true), "N0CALL-20260727-field-day-full.adi")
})

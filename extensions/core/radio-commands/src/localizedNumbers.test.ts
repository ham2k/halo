// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Run with `node --experimental-strip-types --test` (see package.json).
//
// The trap here is order. Under comma conventions BOTH marks appear in
// `14.285,5`, and converting the decimal before stripping grouping leaves two
// periods, which parses as nothing at all. Every assertion with both marks in
// one string exists for that.

import { test } from "node:test"
import assert from "node:assert/strict"

import { canonicalNumber, localizeFormattedNumber } from "./localizedNumbers.ts"

const period = { decimalSeparator: ".", groupingSeparator: "," }
const comma = { decimalSeparator: ",", groupingSeparator: "." }

test("canonicalNumber: period conventions pass through untouched", () => {
  assert.equal(canonicalNumber("14285.5", period), "14285.5")
  assert.equal(canonicalNumber("14,285.5", period), "14285.5")
})

test("canonicalNumber: comma conventions swap both marks, grouping first", () => {
  assert.equal(canonicalNumber("14285,5", comma), "14285.5")
  assert.equal(canonicalNumber("14.285,5", comma), "14285.5")
  assert.equal(canonicalNumber("14.285", comma), "14285", "period is grouping here, not a decimal point")
  assert.equal(canonicalNumber("14,285", comma), "14.285", "comma is the decimal — MHz, which parseFreq scales")
})

test("canonicalNumber: an absent ctx falls back to period conventions", () => {
  // A hook invoked by a host too old to send the separators must still work,
  // rather than dropping every decimal point on the floor.
  assert.equal(canonicalNumber("14285.5", {}), "14285.5")
})

test("canonicalNumber: a space-grouping locale (fr, ru, sv, pl)", () => {
  // Those resolve to a narrow no-break space, not to a comma or a period —
  // an invisible, multi-byte mark that a reader must not assume is one
  // character wide or typeable.
  const fr = { decimalSeparator: ",", groupingSeparator: "\u202f" }
  assert.equal(canonicalNumber("14\u202f285,5", fr), "14285.5")
  assert.equal(canonicalNumber("14285,5", fr), "14285.5")
})

test("canonicalNumber: an empty grouping separator is not 'split everywhere'", () => {
  // The degenerate case, where a locale reports the same mark for both.
  // String.split('') splits on every character, which would return "1,4,2..."
  assert.equal(canonicalNumber("14285,5", { decimalSeparator: ",", groupingSeparator: "" }), "14285.5")
})

test("localizeFormattedNumber: rewrites the shared package's fixed output", () => {
  assert.equal(localizeFormattedNumber("14,285.5", period), "14,285.5", "already right, returned as-is")
  assert.equal(localizeFormattedNumber("14,285.5", comma), "14.285,5")
})

test("localizeFormattedNumber: one pass, so the two marks don't undo each other", () => {
  // Two sequential replaces would turn every mark into the same character.
  const both = localizeFormattedNumber("1,234,567.8", comma)
  assert.equal(both, "1.234.567,8")
})

test("a frequency survives the round trip under comma conventions", () => {
  // What the operator is shown must be what they can type back.
  assert.equal(canonicalNumber(localizeFormattedNumber("14,285.5", comma), comma), "14285.5")
})

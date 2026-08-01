// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import { annotateCallAgainstCountryFile, entityPrefixForCall, flagForDxccCode, regionAndCountryForDxccCode } from "./dxcc.ts"

test("entityPrefixForCall resolves a plain callsign's DXCC entity prefix", () => {
  assert.equal(entityPrefixForCall("W1AW"), "K")
})

test("entityPrefixForCall returns undefined for an undefined/empty call", () => {
  assert.equal(entityPrefixForCall(undefined), undefined)
  assert.equal(entityPrefixForCall(""), undefined)
})

test("annotateCallAgainstCountryFile carries the parsed callsign's own fields through, not just country-file additions", () => {
  const info = annotateCallAgainstCountryFile("W1AW/P")
  assert.equal(info.entityPrefix, "K")
  // ParsedCallsign fields (indicators) must survive the annotate step —
  // annotateCallsign relies on this to detect portable/prefixed scope
  // without keeping the pre-annotation parse result around separately.
  assert.ok(info.indicators?.includes("P"))
})

test("flagForDxccCode resolves a known entity's flag", () => {
  const info = annotateCallAgainstCountryFile("W1AW")
  assert.equal(flagForDxccCode(info.dxccCode), "🇺🇸")
})

test("flagForDxccCode returns undefined for an unresolved code", () => {
  assert.equal(flagForDxccCode(undefined), undefined)
})

test("regionAndCountryForDxccCode resolves a known entity's ITU region and country code", () => {
  const info = annotateCallAgainstCountryFile("W1AW")
  assert.deepEqual(regionAndCountryForDxccCode(info.dxccCode), { ituRegion: 2, countryCode: "us" })
})

test("regionAndCountryForDxccCode resolves a Region 3 entity", () => {
  const info = annotateCallAgainstCountryFile("VK2ABC")
  assert.deepEqual(regionAndCountryForDxccCode(info.dxccCode), { ituRegion: 3, countryCode: "au" })
})

test("regionAndCountryForDxccCode returns an empty object for an unresolved code", () => {
  assert.deepEqual(regionAndCountryForDxccCode(undefined), {})
})

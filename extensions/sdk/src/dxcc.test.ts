// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import {
  annotateCallAgainstCountryFile,
  entityForCall,
  entityPrefixForCall,
  flagForDxccCode,
  regionAndCountryForDxccCode,
} from "./dxcc.ts"

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

test("entityForCall resolves our own station's entity from its callsign", () => {
  assert.deepEqual(entityForCall("W1AW"), {
    dxccCode: 291,
    continent: "NA",
    entityName: "United States",
  })
})

// The zones are the country file's per-prefix guess at where inside an entity
// a station is, and a callsign does not settle that: `N0DEV` resolves to zone
// 4 whether the operator is in Missouri or California. Answering with one
// would put a whole ADIF field's worth of wrong claims in every export, so
// the caller is left to find a real answer or write nothing.
//
// Read off a call the country file DOES zone — `W6ABC` annotates as CQ 3, ITU
// 6 — so this fails the moment either one is passed through, rather than
// merely restating the shape of a shorthand return.
test("entityForCall answers nothing about the zones a callsign cannot settle", () => {
  const zoned = entityForCall("W6ABC") as Record<string, unknown>
  assert.equal(zoned.cqZone, undefined)
  assert.equal(zoned.ituZone, undefined)
  assert.equal(annotateCallAgainstCountryFile("W6ABC").cqZone, 3)
})

test("entityForCall answers an empty entity for no call", () => {
  assert.deepEqual(entityForCall(undefined), {})
  assert.deepEqual(entityForCall(""), {})
})

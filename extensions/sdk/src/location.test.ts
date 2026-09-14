// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// `applyLatLonFromApiFields` is the one place POTA's and SOTA's live-API
// fallback bridges a coordinate onto a `Ref` — the trap it exists to catch
// is a schema drift (a string, null, or missing field) silently landing as
// `undefined` rather than a wrong number, so callers' own grid fallback
// still kicks in instead of plotting a bad pin.

import { test } from "node:test"
import assert from "node:assert/strict"

import { applyLatLonFromApiFields } from "./location.ts"

test("copies numeric latitude/longitude onto lat/lon", () => {
  const target: { lat?: number; lon?: number } = {}
  applyLatLonFromApiFields(target, { latitude: 41.5, longitude: -74.25 })
  assert.equal(target.lat, 41.5)
  assert.equal(target.lon, -74.25)
})

test("leaves lat/lon unset when the fields are absent", () => {
  const target: { lat?: number; lon?: number } = {}
  applyLatLonFromApiFields(target, {})
  assert.equal(target.lat, undefined)
  assert.equal(target.lon, undefined)
})

test("leaves lat/lon unset when the fields are the wrong type, rather than coercing", () => {
  const target: { lat?: number; lon?: number } = {}
  applyLatLonFromApiFields(target, { latitude: "41.5", longitude: null })
  assert.equal(target.lat, undefined)
  assert.equal(target.lon, undefined)
})

test("applies each field independently — one good, one bad", () => {
  const target: { lat?: number; lon?: number } = {}
  applyLatLonFromApiFields(target, { latitude: 41.5, longitude: "not-a-number" })
  assert.equal(target.lat, 41.5)
  assert.equal(target.lon, undefined)
})

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import { formatAdifCoordinate } from "./coordinates.ts"

test("a northern latitude is degrees and decimal minutes, three digits and three decimals", () => {
  assert.equal(formatAdifCoordinate(41.375, "lat"), "N041 22.500")
})

test("a western longitude carries the W hemisphere, not a minus sign", () => {
  // The sign lives in the letter: a reader taking `-074` as degrees and then
  // applying the hemisphere would place the station in the wrong ocean.
  assert.equal(formatAdifCoordinate(-74.45, "lon"), "W074 27.000")
})

test("southern and eastern hemispheres use their own letters", () => {
  assert.equal(formatAdifCoordinate(-33.86, "lat"), "S033 51.600")
  assert.equal(formatAdifCoordinate(151.21, "lon"), "E151 12.600")
})

test("degrees and minutes are zero-padded to the widths ADIF states", () => {
  assert.equal(formatAdifCoordinate(1.05, "lat"), "N001 03.000")
  assert.equal(formatAdifCoordinate(0, "lon"), "E000 00.000")
})

test("minutes that round up to a full sixty carry into the degrees", () => {
  // 41.9999999° is 41° 59.9999994', which rounds to 60.000 — a minute value
  // ADIF cannot state. Without the carry this writes `N041 60.000`, which
  // parsers either reject or read as a degree too far south.
  assert.equal(formatAdifCoordinate(41.9999999, "lat"), "N042 00.000")
})

test("a non-numeric or out-of-range value formats to nothing rather than a malformed field", () => {
  assert.equal(formatAdifCoordinate(undefined, "lat"), undefined)
  assert.equal(formatAdifCoordinate(null, "lat"), undefined)
  assert.equal(formatAdifCoordinate("41.375", "lat"), undefined, "a string is not silently coerced")
  assert.equal(formatAdifCoordinate(NaN, "lat"), undefined)
  assert.equal(formatAdifCoordinate(91, "lat"), undefined)
  assert.equal(formatAdifCoordinate(-181, "lon"), undefined)
})

test("a longitude past 90 is still in range — the axes have different limits", () => {
  // Sharing one limit would silently drop every coordinate east of 90°E,
  // which is most of Asia and Australia.
  assert.equal(formatAdifCoordinate(120.5, "lon"), "E120 30.000")
})

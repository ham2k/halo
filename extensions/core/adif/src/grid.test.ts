// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import { gridCell, isGridCenter, isPlaceholderLocation } from "./grid.ts"

test("a cell knows how big it is, which is what its length claims", () => {
  // Four characters is a degree of latitude; every level below divides it.
  assert.equal(gridCell("FN31")?.latSize, 1)
  assert.equal(gridCell("FN31")?.lonSize, 2)
  assert.equal(gridCell("FN31pr")?.latSize, 1 / 24)
  assert.equal(gridCell("FN31pr55")?.latSize, 1 / 240)
})

test("a center is recognised as its own center", () => {
  const cell = gridCell("FN31pr")!
  assert.equal(isGridCenter(cell.lat, cell.lon, "FN31pr"), true)
})

test("a center computed by lib-geo-tools' own arithmetic still reads as one", () => {
  // The trap this tolerance exists for. `mergeLookup.ts` fills a lookup's
  // coordinate from its grid with @ham2k/lib-geo-tools, which accumulates the
  // same sum in a different order — so the pair reaching an export is the
  // same place to within floating-point noise and not the same number.
  const cell = gridCell("FN31pr")!
  assert.equal(isGridCenter(cell.lat + 1e-12, cell.lon - 1e-12, "FN31pr"), true)
})

test("a center that went through an ADIF round trip still reads as one", () => {
  // ADIF stores coordinates to a thousandth of a minute, about 1.8 m.
  const cell = gridCell("FN31pr")!
  const rounded = (v: number) => Math.round(v * 60000) / 60000
  assert.equal(isGridCenter(rounded(cell.lat), rounded(cell.lon), "FN31pr"), true)
})

test("a real fix inside the square is a finer statement and is not its center", () => {
  // The whole point: this must not swallow a GPS fix that merely falls in the
  // same square, or an export would drop a coordinate the operator did take.
  const cell = gridCell("FN31pr")!
  assert.equal(isGridCenter(cell.lat + cell.latSize / 4, cell.lon, "FN31pr"), false)
  assert.equal(isGridCenter(41.7135, -72.7278, "FN31pr"), false)
})

test("the tolerance scales with the cell, so a coarse square does not swallow a town", () => {
  // A hundredth of FN31 is ~1.1 km of latitude; a hundredth of FN31pr55 is
  // ~4.6 m. One tolerance in degrees could not be right for both.
  const coarse = gridCell("FN31")!
  const fine = gridCell("FN31pr55")!
  assert.equal(isGridCenter(coarse.lat + 0.005, coarse.lon, "FN31"), true)
  assert.equal(isGridCenter(fine.lat + 0.005, fine.lon, "FN31pr55"), false)
})

test("a locator that does not decode is nobody's center, and never throws", () => {
  // @ham2k/lib-geo-tools THROWS on a 5-, 7- or 10-character locator, which in
  // an export would discard the whole file over one odd grid in one contact.
  for (const grid of ["", "FN", "NOT_FOUND", "ZZ99", undefined, null, 42]) {
    assert.equal(gridCell(grid), undefined, `${grid}`)
    assert.equal(isGridCenter(41.7135, -72.7278, grid), false, `${grid}`)
  }
})

test("an odd length decodes to the coarser cell it does agree on", () => {
  // Lenient like halo_core's decoder, and unlike lib-geo-tools, which throws
  // for any length that is not 4, 6 or 8. A half-typed locator still places
  // the station in the square it has finished naming.
  assert.deepEqual(gridCell("FN31p"), gridCell("FN31"))
  assert.deepEqual(gridCell("FN31pr5"), gridCell("FN31pr"))
})

test("a ten-character locator decodes rather than throwing", () => {
  const cell = gridCell("FN31pr55xx")
  assert.ok(cell)
  assert.ok(cell.latSize < 1 / 240)
  assert.equal(isGridCenter(cell.lat, cell.lon, "FN31pr55xx"), true)
})

test("a malformed tail yields the coarser cell the locator does agree on", () => {
  // Matches halo_core's decoder: `FN31ZZ` is FN31, because ZZ is no subsquare.
  assert.deepEqual(gridCell("FN31ZZ"), gridCell("FN31"))
})

test("half a coordinate is no coordinate", () => {
  assert.equal(isGridCenter(41.7135, undefined, "FN31pr"), false)
  assert.equal(isGridCenter(undefined, -72.7278, "FN31pr"), false)
})

test("a placeholder pair is recognised, and nothing near it is", () => {
  // A guard wider than the placeholder would drop real stations from the file;
  // one narrower would publish QRZ's South Pole stand-in as a coordinate.
  assert.equal(isPlaceholderLocation(0, 0), true)
  assert.equal(isPlaceholderLocation(-89.979167, -179.958333), true, "what QRZ sends beside AA00aa")
  assert.equal(isPlaceholderLocation(-89.979, -179.958), true, "the same center, rounded")
  assert.equal(isPlaceholderLocation(-89.5, -179), true, "the AA00 center")
  assert.equal(isPlaceholderLocation(0, 0.5), false)
  assert.equal(isPlaceholderLocation(-89.2, -178.5), false, "inside AA00, but not its center")
  assert.equal(isPlaceholderLocation(-90, 0), false, "the South Pole station")
  assert.equal(isPlaceholderLocation(undefined, 0), false)
})

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Whether a coordinate is a Maidenhead cell's own CENTER — the one question
// this exporter has to ask about a location, and the one @ham2k/lib-geo-tools
// cannot answer: `gridToLocation` returns a point without saying how big the
// cell around it is, and it THROWS on anything that is not 4, 6 or 8
// characters (a 10-character locator included), which in an export would
// discard the whole file over one odd grid in one contact.
//
// The port of halo_core's `gridCell`/`isGridCenter` (packages/halo_core/lib/
// src/ham/grid.dart), decoding leniently the way that one does: a malformed
// tail yields the coarser cell it agrees on, and anything unreadable yields
// nothing at all.
//
// The catalog's `ham2k-sota` carries a copy in its src/grid.ts — keep the two
// in step.

export interface GridCell {
  lat: number
  lon: number
  latSize: number
  lonSize: number
}

/// A locator as the cell it names — center and dimensions — or undefined for
/// anything that does not decode. Never throws.
export function gridCell(grid: unknown): GridCell | undefined {
  if (typeof grid !== "string") return undefined
  const g = grid.trim().toUpperCase()
  if (g.length < 4) return undefined

  const lonField = g.charCodeAt(0) - 65
  const latField = g.charCodeAt(1) - 65
  if (lonField < 0 || lonField > 17 || latField < 0 || latField > 17) return undefined

  const lonSquare = digit(g[2])
  const latSquare = digit(g[3])
  if (lonSquare === undefined || latSquare === undefined) return undefined

  let latSize = 1
  let lonSize = 2
  let lat = latField * 10 - 90 + latSquare * latSize
  let lon = lonField * 20 - 180 + lonSquare * lonSize
  const cell = (): GridCell => ({ lat: lat + latSize / 2, lon: lon + lonSize / 2, latSize, lonSize })

  if (g.length >= 6) {
    const lonSub = g.charCodeAt(4) - 65
    const latSub = g.charCodeAt(5) - 65
    if (lonSub < 0 || lonSub >= 24 || latSub < 0 || latSub >= 24) return cell()
    lonSize /= 24
    latSize /= 24
    lon += lonSub * lonSize
    lat += latSub * latSize
  }

  if (g.length >= 8) {
    const lonExt = digit(g[6])
    const latExt = digit(g[7])
    if (lonExt === undefined || latExt === undefined) return cell()
    lonSize /= 10
    latSize /= 10
    lon += lonExt * lonSize
    lat += latExt * latSize
  }

  if (g.length >= 10) {
    const lonSubSub = g.charCodeAt(8) - 65
    const latSubSub = g.charCodeAt(9) - 65
    if (lonSubSub < 0 || lonSubSub >= 24 || latSubSub < 0 || latSubSub >= 24) return cell()
    lonSize /= 24
    latSize /= 24
    lon += lonSubSub * lonSize
    lat += latSubSub * latSize
  }

  return cell()
}

function digit(char: string | undefined): number | undefined {
  if (char === undefined || char < "0" || char > "9") return undefined
  return char.charCodeAt(0) - 48
}

/// A hundredth of the cell's own size — the same fraction halo_core uses, and
/// a fraction rather than a fixed number of degrees because the cells run
/// from 111 km of latitude to 19 m. See `_gridCenterTolerance` there for why
/// a tolerance is needed at all rather than exact equality.
const CENTER_TOLERANCE = 0.01

/// Whether the pair is only [grid]'s own center, and so says nothing the
/// locator did not.
///
/// The app stores that center beside every locator an operator STATES
/// (docs/design/locations.md), so a file must not restate it as a coordinate:
/// ADIF readers take `LAT`/`LON` over `GRIDSQUARE`, and the station would be
/// published standing at a point inside a square it was only placed in.
export function isGridCenter(lat: unknown, lon: unknown, grid: unknown): boolean {
  if (typeof lat !== "number" || typeof lon !== "number") return false
  const cell = gridCell(grid)
  if (!cell) return false
  return Math.abs(lat - cell.lat) <= cell.latSize * CENTER_TOLERANCE && Math.abs(lon - cell.lon) <= cell.lonSize * CENTER_TOLERANCE
}

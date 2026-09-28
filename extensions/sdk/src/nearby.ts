// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT

import type { LookupRow, MapBounds, SuggestArgs } from "./types.ts"

/// The two host lookups a nearby `suggest` reads from — passed in rather than
/// imported, since the SDK barrel re-exports this module and a static import
/// of `host` from it would be circular.
export interface NearbyLookupHost {
  dbLookupSelectByLocation(category: string, lat: number, lon: number, delta: number, activeOnly?: boolean): Promise<LookupRow[]>
  dbLookupSelectInBounds(category: string, bounds: MapBounds, options?: { activeOnly?: boolean; limit?: number }): Promise<LookupRow[]>
}

/// The most references one program answers for a viewport. A map panned over
/// a dense region at the zoom that asks holds a few hundred at most.
export const VIEWPORT_LIMIT = 500

/// The rows a nearby `suggest` (no `searchTerm`) answers from: everything in
/// the map's viewport when the operator panned it (`bounds`), otherwise a box
/// of ±`delta` degrees around `location`. `inViewport` says which, because the
/// two are capped differently — a viewport is answered WHOLE, or its corners
/// stay empty however far the operator pans, while a nearby list is the
/// nearest few.
export async function nearbyLookupRows(
  host: NearbyLookupHost,
  category: string,
  { location, bounds }: Pick<SuggestArgs, "location" | "bounds">,
  { delta, activeOnly }: { delta: number; activeOnly?: boolean },
): Promise<{ rows: LookupRow[]; inViewport: boolean }> {
  if (bounds) return { rows: await host.dbLookupSelectInBounds(category, bounds, { activeOnly, limit: VIEWPORT_LIMIT }), inViewport: true }
  if (location) return { rows: await host.dbLookupSelectByLocation(category, location.lat, location.lon, delta, activeOnly), inViewport: false }
  return { rows: [], inViewport: false }
}

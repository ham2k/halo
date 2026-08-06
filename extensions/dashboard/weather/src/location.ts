// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The weather panel's location parsing, with no SDK import so it unit-tests
// under plain node — the same split spaceWeather.ts uses.

import { gridToLocation } from "@ham2k/lib-geo-tools"

/// A grid square, `lat,lon`, or nothing. Returns null rather than guessing —
/// a panel showing the weather somewhere the operator did not ask about is
/// worse than one saying it could not read the location.
export function parseLocation(raw: string): { latitude: number; longitude: number } | null {
  const text = raw.trim()
  if (!text) return null
  const pair = /^(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)$/.exec(text)
  if (pair) {
    const latitude = Number(pair[1])
    const longitude = Number(pair[2])
    if (Math.abs(latitude) > 90 || Math.abs(longitude) > 180) return null
    return { latitude, longitude }
  }
  try {
    const [latitude, longitude] = gridToLocation(text)
    if (typeof latitude !== "number" || Number.isNaN(latitude)) return null
    return { latitude, longitude }
  } catch {
    // A malformed grid throws out of the library; that is a typo, not a
    // failure worth reporting anywhere but on the panel itself.
    return null
  }
}

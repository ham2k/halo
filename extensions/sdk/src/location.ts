// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// Per-source location accuracy ranks (lower = more precise), ported from
// app-polo's LOCATION_ACCURACY. A 6-char grid is precise enough for our
// purposes, but a source's grid can still be geographically off — a POTA
// park's single-point grid may sit a dozen grids from where a large park's
// operator actually is. So a lookup result tags its location with one of
// these, and `mergeLookupIntoGuess` keeps the most accurate one when more
// than one source (e.g. a POTA park and a SOTA summit on the same QSO)
// offers a location.

export const LOCATION_ACCURACY = {
  EXACT: 0, // Believed to be the right grid6 — confirmed by contact or GPS.
  ACCURATE: 2, // Close enough, maybe a neighbouring grid — e.g. a SOTA summit.
  REASONABLE: 10, // May be off by a dozen grids — most POTA parks.
  VAGUE: 100, // No better than a general state/province.
  NO_LOCATION: 1000,
} as const

/// Bridges a live API's own `latitude`/`longitude` field names onto a
/// target carrying the SDK's `lat`/`lon` (POTA's `POTAParkInfo`, SOTA's
/// `SOTASummitInfo`) — both hand-written activities (with their own network
/// APIs, unlike the shared `referenceActivity` factory) hit this same
/// naming mismatch. `typeof`-checked rather than a blind cast: a field
/// that's absent, or the wrong type because of an API change, degrades to
/// "no exact coordinate" (the caller's existing fallback to a decoded
/// grid) instead of writing a non-number into a field callers assume is a
/// number.
export function applyLatLonFromApiFields(target: { lat?: number; lon?: number }, raw: Record<string, unknown>): void {
  if (typeof raw.latitude === "number") target.lat = raw.latitude
  if (typeof raw.longitude === "number") target.lon = raw.longitude
}

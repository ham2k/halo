// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
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

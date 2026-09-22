// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Reading and guessing the VHF-contest grid exchange.
//
// Separate from index.ts so these can be unit-tested: index.ts calls
// `defineExtension` at import time, so nothing in it is reachable from
// `node --test`.

import type { JSONValue } from "@ham2k/extension-sdk"

import type { VhfEvent } from "./events.ts"

const GRID4_PATTERN = "^[A-R]{2}[0-9]{2}$"
const GRID6_PATTERN = "^[A-R]{2}[0-9]{2}[A-X]{2}$"

/// Trims a grid to the precision this event's exchange actually wants — a
/// station that types or is looked up with 6+ characters, in a 4-character
/// event, sends only the field/square the sponsor's exchange calls for.
export function trimmedGrid(grid: string | undefined | null, event: VhfEvent): string {
  return (grid ?? "").trim().toUpperCase().substring(0, event.gridChars)
}

/// The regex source this event's grid field validates against — anchored and
/// case-insensitive by the core's shared `pattern` compilation.
export function gridPatternFor(event: VhfEvent): string {
  return event.gridChars === 6 ? GRID6_PATTERN : GRID4_PATTERN
}

/// The grid to offer for the station being worked, from whatever the callsign
/// lookup or a prior QSO with this call resolved — mirrors polo's
/// `lookupCall`, which reads the last QSO's `their.grid` for the same call.
export function guessedGrid(their: Record<string, JSONValue> | undefined, event: VhfEvent): string {
  const guess = (their?.guess as Record<string, JSONValue>) ?? {}
  const raw = (their?.grid as string | undefined) ?? (guess.grid as string | undefined)
  return trimmedGrid(raw, event)
}

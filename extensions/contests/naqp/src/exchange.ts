// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Reading and guessing NAQP's two-part exchange.
//
// Separate from index.ts so these can be unit-tested: index.ts calls
// `defineExtension` at import time, so nothing in it is reachable from
// `node --test`.

import type { JSONValue } from "@ham2k/extension-sdk"
import { annotateCallAgainstCountryFile } from "../../../sdk/src/dxcc.ts"

import { VALID_LOCATIONS } from "./locations.ts"

/// The entities whose stations send a STATE or PROVINCE rather than an entity
/// prefix. Everyone else in North America sends their prefix.
///
/// These are COUNTRY-FILE prefixes, which are not always what a ham would
/// write: Alaska is `KL`, not `KL7`. polo's list says `KL7`, so it never
/// matched, and every Alaskan station was logged with the raw prefix instead of
/// their state. Verified against the bundled country file, not assumed.
const SENDS_A_STATE = ["K", "KL", "KH6", "VE"]

function str(value: JSONValue | undefined): string {
  return typeof value === "string" ? value : ""
}

export function normalizeLocation(value: JSONValue | undefined): string {
  return String(value ?? "")
    .trim()
    .toUpperCase()
}

/// A first name, upper-cased — NAQP exchanges are single names, and the lookup
/// may well hand back "Hiram Percy Maxim".
export function firstName(value: JSONValue | undefined): string {
  return str(value).trim().split(/\s+/)[0].toUpperCase()
}

/// The name to offer for this station, from whatever the lookup resolved.
export function guessedName(their: Record<string, JSONValue>): string {
  const guess = (their.guess as Record<string, JSONValue>) ?? {}
  return firstName(their.name) || firstName(guess.name)
}

/// The location to offer for this station: a state or province if they send
/// one, otherwise their entity prefix if it is one NAQP recognizes, otherwise
/// `DX`. Mirrors polo's `_locationFromQSO`, with the prefix corrections.
///
/// Anything not in [VALID_LOCATIONS] comes back EMPTY rather than as itself. A
/// guess here is stamped onto the ref as data of record and exported as though
/// the station had sent it, so a country-file artifact like `HK0/a` must never
/// survive this function.
export function guessedLocation(their: Record<string, JSONValue>): string {
  const guess = (their.guess as Record<string, JSONValue>) ?? {}
  const call = str(their.call)
  const info = (call ? annotateCallAgainstCountryFile(call) : {}) as Record<string, JSONValue>

  const entity = str(their.entityPrefix) || str(guess.entityPrefix) || str(info.entityPrefix)
  const continent = str(their.continent) || str(guess.continent) || str(info.continent)

  if (SENDS_A_STATE.includes(entity)) {
    // A state we don't know is better left blank than guessed wrong — every US
    // and Canadian station is a multiplier, so a wrong one is a wrong claim.
    const state = normalizeLocation(str(their.state) || str(guess.state))
    return VALID_LOCATIONS.has(state) ? state : ""
  }
  if (continent === "NA") {
    const prefix = normalizeLocation(entity)
    if (VALID_LOCATIONS.has(prefix)) return prefix
    // The country file distinguishes sub-entities the DXCC prefix does not:
    // San Andres is `HK0/a` and Clipperton `FO/c`, while NAQP wants the plain
    // `HK0` and `FO` it lists. Reduce to the parent before giving up, or a
    // legitimate multiplier goes unsuggested and probably unlogged.
    const parent = prefix.split("/")[0]
    return VALID_LOCATIONS.has(parent) ? parent : ""
  }
  return entity ? "DX" : ""
}

/// What WE send, as it goes into the exchange fields of an export.
///
/// Read from `ourName`/`ourLocation`, NOT `name`/`location`. `name` on a ref is
/// a CORE-OWNED decoration slot — `decorateRef` writes the activity row's
/// subtitle there, and the decorated ref is what gets persisted — so an
/// extension storing its own data under that key has it overwritten by a
/// display string the moment the operator saves the setup form.
export function ourExchange(ref?: Record<string, JSONValue>): { name: string; location: string } {
  return { name: firstName(ref?.ourName), location: normalizeLocation(ref?.ourLocation) }
}

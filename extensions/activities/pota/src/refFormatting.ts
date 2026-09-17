// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// POTA reference validation/formatting — pulled out of index.ts so it can be
// unit-tested directly (see index.test.ts): this file only imports real npm
// packages and relative file paths, never the `@ham2k/extension-sdk` *bare
// specifier* (a tsc-only path alias — see extensions/tsconfig.json — that
// Node's own module resolver, used by `node --test`, can't resolve at
// runtime). `sdk/src/dxcc.ts` only imports real npm packages itself, so
// importing it by relative path keeps this file resolvable the same way.

import { countryPrefixForCall, entityPrefixForCall } from "../../../sdk/src/dxcc.ts"
import { transformsForPrefix } from "../../../sdk/src/refTransforms.ts"

export { entityPrefixForCall, transformsForPrefix }

// One reference, e.g. "US-1234". The core's ref chip input lets a user type
// several comma/space-separated references into one field (a rover working
// a park-to-park boundary logs every simultaneously-active park on the one
// QSO) — each becomes its OWN `Ref` entry, so this extension only ever sees
// one reference at a time.
export const REFERENCE_REGEX = /^[A-Z0-9]+-(?:[0-9]{4,5}|TEST)$/i

// Same shape as REFERENCE_REGEX but without the dash — a non-greedy prefix
// capture backtracks until what's left at the end is exactly a valid
// suffix (4-5 digits, or TEST), so "US15000" splits as "US" + "15000". Only
// used to recognize free-typed search text (see `normalizeReference`); the
// dash is still required everywhere a reference is stored or displayed.
const DASHLESS_REFERENCE_MATCH = /^([A-Z0-9]+?)(TEST|[0-9]{4,5})$/i

// Accepts a reference typed with or without its dash (e.g. "US-1234" or
// "US1234") and returns the canonical dashed, uppercased form — or null if
// `input` isn't a fully-formed reference either way.
export function normalizeReference(input: string): string | null {
  const trimmed = input.toUpperCase().trim()
  if (REFERENCE_REGEX.test(trimmed)) return trimmed
  const match = DASHLESS_REFERENCE_MATCH.exec(trimmed)
  return match ? `${match[1]}-${match[2]}` : null
}

// POTA's own reference prefix follows a park's real-world country, not the
// ham-radio DXCC entity — see `countryPrefixForCall`.
export const potaCountryPrefixForCall = countryPrefixForCall

// Hunter (secondary control) prefers the entity the OTHER station is in —
// same rule app-polo's POTALoggingControl uses — falling back to our own
// station's entity; the activation control always uses our own.
export function hunterDefaultPrefix(
  operation: { stationCall?: unknown },
  qso: { their?: { call?: unknown } } | undefined,
): string {
  const theirCall = qso?.their?.call as string | undefined
  return (
    potaCountryPrefixForCall(theirCall) ?? potaCountryPrefixForCall(operation.stationCall as string | undefined) ?? 'US'
  )
}

export function activationDefaultPrefix(operation: { stationCall?: unknown }): string {
  return potaCountryPrefixForCall(operation.stationCall as string | undefined) ?? 'US'
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// POTA reference validation/formatting — pulled out of index.ts so it can be
// unit-tested directly (see index.test.ts): this file only imports real npm
// packages, never the `@ham2k/polo-sdk` *value* import (a tsc-only path
// alias — see extensions/tsconfig.json — that Node's own module resolver,
// used by `node --test`, can't resolve at runtime).

import { parseCallsign } from "@ham2k/lib-callsigns"
import { annotateFromCountryFile, useBuiltinCountryFile } from "@ham2k/lib-country-files"
import { DXCC_BY_CODE } from "@ham2k/lib-dxcc-data"

// One reference, e.g. "US-1234". The core's ref chip input lets a user type
// several comma/space-separated references into one field (a rover working
// a park-to-park boundary logs every simultaneously-active park on the one
// QSO) — each becomes its OWN `Ref` entry, so this extension only ever sees
// one reference at a time.
export const REFERENCE_REGEX = /^[A-Z0-9]+-(?:[0-9]{4,5}|TEST)$/i

// Loads the bundled BIGCTY data once per runtime activation, so a park's
// DXCC entity (from its numeric entityId) and a caller's own entity (from
// their callsign) resolve without needing a network round trip.
useBuiltinCountryFile()

export function entityPrefixForCall(call: string | undefined): string | undefined {
  if (!call) return undefined
  return annotateFromCountryFile(parseCallsign(call)).entityPrefix
}

// POTA's own reference prefix follows a park's real-world country, not the
// ham-radio DXCC "entity" a callsign's own prefix maps to — the two diverge
// for exactly the cases POTA itself treats as one country: Hawaii is its
// own DXCC entity ("KH6"), but POTA still prefixes its parks "US-"; a
// Canadian call's DXCC entity prefix is "VE", but POTA uses "CA-"; an EA3
// (Spanish) call's DXCC entity prefix is "EA", but POTA uses "ES-".
// `@ham2k/lib-dxcc-data`'s `countryCode` field on each DXCC entity already
// carries this real-world mapping (a lowercase ISO-3166-ish code, e.g.
// "us"/"ca"/"es") — falls back to the DXCC entity prefix itself for the
// handful of entities with no `countryCode` (mostly long-deleted DXCC
// entities unlikely to have any real POTA parks).
export function potaCountryPrefixForCall(call: string | undefined): string | undefined {
  if (!call) return undefined
  const annotated = annotateFromCountryFile(parseCallsign(call))
  const countryCode = annotated.dxccCode != null ? DXCC_BY_CODE[annotated.dxccCode]?.countryCode : undefined
  return countryCode ? countryCode.toUpperCase() : annotated.entityPrefix
}

// Live-typing reformatting for the (possibly comma/space-separated list of)
// POTA reference(s) in one chip's field, e.g. "us1234 us5678" ->
// "US-1234,US-5678" — mirrors app-polo's POTAInput.jsx textTransformer
// chain, but declared once per loggingControls/operationControls call (with
// `prefix` baked in from the QSO's guessed DXCC entity) instead of run in
// the runtime on every keystroke; the core's native input widget applies
// this list, in order, on every keystroke.
export function transformsForPrefix(prefix: string): { pattern: string; replacement: string; flags?: string }[] {
  return [
    // a run of spaces between two refs -> ", " (normalize to one separator style)
    { pattern: '([A-Z0-9]-\\d+|TEST) +(?=[A-Z0-9])', replacement: '${1}, ', flags: 'gi' },
    // bare number (or "TEST"), at the start or right after a separator -> prefix-number
    // (the separator itself is captured and replayed, not consumed, so a
    // pasted "US-1234,5678" keeps its comma instead of merging into one ref).
    // Braced `${1}`/`${2}`, not bare `$1`/`$2` — `prefix` can itself start
    // with a digit (e.g. DXCC "3D2" for Fiji), and a bare "$1" immediately
    // followed by that would misparse as capture group 13.
    { pattern: '(^|,\\s*)(\\d\\d+|TEST)', replacement: `\${1}${prefix}-\${2}`, flags: 'gi' },
    // "US1234" -> "US-1234". Anchored with a negative lookbehind so it only
    // fires at the START of a not-yet-dashed reference — without it, a
    // multi-character DXCC prefix that mixes letters and digits (e.g.
    // Fiji's "3D2") gets its OWN internal "D2" mismatched as an undashed
    // reference once transform 2 above has already inserted "3D2-1234",
    // corrupting it into "3D-2-1234".
    { pattern: '(?<![A-Z0-9])([A-Z]+)(\\d+|TEST)', replacement: '${1}-${2}', flags: 'gi' },
    // NOTE: deliberately no "eagerly insert the next prefix right after a
    // trailing comma" rule here (an earlier version had one) — transform 2
    // above already prefixes a second reference once 2+ digits appear after
    // the comma, the same way it does at the start of the field. An eager
    // version that inserted "US-" the instant a trailing comma appeared
    // made deleting back through a second reference impossible: backspacing
    // "US-1234,US-5678" down to "US-1234,US-" and then to "US-1234," would
    // immediately re-grow the trailing "US-1234,US-" the transform had just
    // reinserted, so the comma itself could never be reached.

    // strip anything that can't appear in a reference list
    { pattern: '[^A-Z0-9\\-, ]', replacement: '', flags: 'gi' },
  ]
}

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

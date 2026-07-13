// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Hardcoded callsign-annotation pre-step (not a registered `lookup` hook —
// always runs first, regardless of any other hook's declared priority, per
// ham2k/app-halo-dist#8). Parses the callsign's structure and annotates it
// against the bundled DXCC country file, the same way `core/scoring` does.

import { parseCallsign } from "@ham2k/lib-callsigns"
import { annotateFromCountryFile, useBuiltinCountryFile } from "@ham2k/lib-country-files"
import type { CallInfo, CallInfoLookup } from "@ham2k/polo-sdk"

useBuiltinCountryFile()

// Well-known postindicators that denote a temporary/traveling location —
// exact vocabulary confirmed from lib-callsigns' `KNOWN_INDICATORS` list
// (parseCallsign.ts): 'P' (portable), 'M' (mobile), 'AM' (maritime mobile
// alternate), 'MM' (maritime mobile).
const PORTABLE_INDICATORS = new Set(['P', 'M', 'AM', 'MM'])

export function annotateCallsign(call: string): CallInfoLookup {
  const parsed = parseCallsign(call)
  const annotated = annotateFromCountryFile(parsed) as CallInfo

  let locationScope: CallInfo['locationScope'] = 'qth'
  if (parsed.indicators?.some((i) => PORTABLE_INDICATORS.has(i))) {
    locationScope = 'portable'
  } else if (parsed.preindicator || parsed.prefixOverride) {
    locationScope = 'prefixed'
  }

  return {
    ...annotated,
    source: 'callsign-annotation',
    scope: 'general',
    call,
    locationScope,
    // The country-file entity's centroid isn't real QTH data — suppressing
    // it here keeps a later "already have a grid" skip-check from being
    // satisfied by a coarse DXCC-entity-level location. `locSource` (which
    // `annotateFromCountryFile` sets to e.g. 'prefix' for this same
    // centroid match) must be suppressed too — it's a LOCATION_FIELD, so
    // the merge's priority-order rule would otherwise let this always-first
    // step permanently claim it, blocking any later real source (QRZ/HamDB)
    // from ever recording where its own location data actually came from.
    lat: undefined,
    lon: undefined,
    grid: undefined,
    locSource: undefined,
  }
}

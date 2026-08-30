// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Hardcoded callsign-annotation pre-step (not a registered `lookup` hook —
// always runs first, regardless of any other hook's declared
// priority). Parses the callsign's structure and annotates it
// against the bundled DXCC country file, the same way `core/scoring` does.
//
// `annotateCallAgainstCountryFile`/`flagForDxccCode` come in by relative
// path, not the `@ham2k/extension-sdk` alias — this file has its own
// `annotate.test.ts` run via plain `node --test`, which can't resolve that
// tsc-only bare specifier (see activities/pota/src/refFormatting.ts's
// header comment for the same constraint). `dxcc.ts` only imports real npm
// packages itself, so the relative import stays resolvable.

import { annotateCallAgainstCountryFile, flagForDxccCode, regionAndCountryForDxccCode } from "../../../sdk/src/dxcc.ts"
import type { CallInfo, CallInfoLookup } from "@ham2k/extension-sdk"

// Well-known postindicators that denote a temporary/traveling location —
// exact vocabulary confirmed from lib-callsigns' `KNOWN_INDICATORS` list
// (parseCallsign.ts): 'P' (portable), 'M' (mobile), 'AM' (maritime mobile
// alternate), 'MM' (maritime mobile).
const PORTABLE_INDICATORS = new Set(['P', 'M', 'AM', 'MM'])

// `flag`/`ituRegion`/`countryCode` ride along as extra fields CallInfo/
// CallInfoLookup's fixed shape (from lib-qson-tools, matching app-polo's
// QSON schema) doesn't declare — the same way every hook result already
// crosses the Dart/JS bridge as a plain untyped map, and
// `mergeLookupIntoGuess` merges any field generically, not just the ones
// CallInfo declares. `flag` is used by the QSO row's DX/domestic column;
// `ituRegion`/`countryCode` let
// `modeForFrequency` prefer/exclude region- or country-scoped band-plan
// segments for the operator's own entity, without porting
// lib-dxcc-data's entity table into Dart. Widening only these fields,
// rather than casting the whole return value to `CallInfoLookup`, keeps
// every other field still checked against its real declared type.
type CallInfoLookupWithFlag = CallInfoLookup & { flag?: string; ituRegion?: number; countryCode?: string }

export function annotateCallsign(call: string): CallInfoLookupWithFlag {
  const annotated = annotateCallAgainstCountryFile(call) as CallInfo

  let locationScope: CallInfo['locationScope'] = 'qth'
  if (annotated.indicators?.some((i) => PORTABLE_INDICATORS.has(i))) {
    locationScope = 'portable'
  } else if (annotated.preindicator || annotated.prefixOverride) {
    locationScope = 'prefixed'
  }

  return {
    ...annotated,
    source: 'callsign-annotation',
    scope: 'general',
    call,
    locationScope,
    flag: flagForDxccCode(annotated.dxccCode),
    ...regionAndCountryForDxccCode(annotated.dxccCode),
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

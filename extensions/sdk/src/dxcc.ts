// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Shared DXCC entity resolution — parses a callsign against the bundled
// country file (no network) and, separately, looks up that entity's flag
// emoji. core/lookups' callsign-annotation pre-step, core/scoring's
// DXCC-worked-entities rule, and activities/pota's country-prefix
// formatting all share this one parseCallsign+annotateFromCountryFile
// call instead of carrying their own copies.
//
// A plain module, not part of the `@ham2k/halo-extension-sdk` *value* import users
// must avoid (see activities/pota/src/refFormatting.ts's header comment) —
// import it by relative path from a file that needs to stay resolvable by
// plain `node --test`, or via the `@ham2k/halo-extension-sdk` re-export otherwise.

import { parseCallsign } from "@ham2k/lib-callsigns"
import { annotateFromCountryFile, useBuiltinCountryFile } from "@ham2k/lib-country-files"
import type { AnnotatedCallInfo } from "@ham2k/lib-country-files"
import { DXCC_BY_CODE } from "@ham2k/lib-dxcc-data"

// Loads the bundled BIGCTY data once per runtime activation — self-contained,
// no network — so DXCC entity resolution works without relying on a
// callsign already having been enriched by a lookup hook.
useBuiltinCountryFile()

/// Parses and resolves a callsign's DXCC entity against the bundled country
/// file. No network access.
export function annotateCallAgainstCountryFile(call: string): AnnotatedCallInfo {
  return annotateFromCountryFile(parseCallsign(call))
}

export function entityPrefixForCall(call: string | undefined): string | undefined {
  if (!call) return undefined
  return annotateCallAgainstCountryFile(call).entityPrefix
}

/// That entity's flag emoji, via `@ham2k/lib-dxcc-data` — a separate table
/// keyed by numeric DXCC code, not part of the country-file data itself.
export function flagForDxccCode(dxccCode: number | undefined): string | undefined {
  return dxccCode == null ? undefined : DXCC_BY_CODE[dxccCode]?.flag
}

/// That entity's ITU region (1/2/3) and lowercase ISO country code, via
/// `@ham2k/lib-dxcc-data` — the same table `flagForDxccCode` reads.
/// `countryCode` matches band_plan_segments.dart's `countries` values
/// exactly (both come from this same upstream data), so the two can be
/// compared directly with no further normalization.
export function regionAndCountryForDxccCode(
  dxccCode: number | undefined,
): { ituRegion?: number; countryCode?: string } {
  if (dxccCode == null) return {}
  const entity = DXCC_BY_CODE[dxccCode]
  return { ituRegion: entity?.ituRegion, countryCode: entity?.countryCode }
}

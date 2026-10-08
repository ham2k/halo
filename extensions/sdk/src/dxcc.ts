// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// Shared DXCC entity resolution — parses a callsign against the bundled
// country file (no network) and, separately, looks up that entity's flag
// emoji. core/lookups' callsign-annotation pre-step, core/scoring's
// DXCC-worked-entities rule, and the catalog's `ham2k-pota` country-prefix
// formatting all share this one parseCallsign+annotateFromCountryFile
// call instead of carrying their own copies.
//
// A plain module, not part of the `@ham2k/extension-sdk` *value* import users
// must avoid (see `ham2k-pota`'s refFormatting.ts header comment) —
// import it by relative path from a file that needs to stay resolvable by
// plain `node --test`, or via the `@ham2k/extension-sdk` re-export otherwise.

import { parseCallsign } from "@ham2k/lib-callsigns"
import { annotateFromCountryFile, BIGCTY, useBuiltinCountryFile } from "@ham2k/lib-country-files"
import type { AnnotatedCallInfo } from "@ham2k/lib-country-files"
import { DXCC_BY_CODE } from "@ham2k/lib-dxcc-data"

// Loads the bundled BIGCTY data once per runtime activation — self-contained,
// no network — so DXCC entity resolution works without relying on a
// callsign already having been enriched by a lookup hook.
useBuiltinCountryFile()

/// Parses and resolves a callsign's DXCC entity against the bundled country
/// file. No network access.
///
/// `wae: true` resolves against the WAE country list instead: the extra
/// entities carry starred prefixes (`*IT9`, `*TA1`, `*4U1V`) and their WAE
/// continent — European Turkey is EU there, not AS — which is what a
/// WAE-multiplier contest scores by.
///
/// `lon` is east-positive and `tz` reads as a UTC offset with its ordinary
/// sign — "GMT-5" is five hours behind UTC — as every lookup source writes them.
export function annotateCallAgainstCountryFile(call: string, options?: { wae?: boolean }): AnnotatedCallInfo {
  const annotated = annotateFromCountryFile(parseCallsign(call), options)
  if (!WEST_POSITIVE) return annotated
  return {
    ...annotated,
    ...(typeof annotated.lon === "number" ? { lon: 0 - annotated.lon } : {}),
    ...(annotated.tz ? { tz: flippedTz(annotated.tz) } : {}),
  }
}

/// `@ham2k/lib-country-files` before 1.1 passes the country file's
/// west-positive longitude and UTC offset through as they are; 1.1 states
/// both with the ordinary sign. The app supplies that library to every
/// extension, while each extension bundles its own copy of this file, so which
/// convention this code meets depends on the app it runs in — and is read off
/// the data: the United States' centroid is west of Greenwich, so a positive
/// longitude there is the old convention.
const WEST_POSITIVE = (BIGCTY.entities.K?.lon ?? 0) > 0

function flippedTz(tz: string): string {
  const match = /^GMT([+-]?\d+(?:\.\d+)?)$/.exec(tz)
  if (!match) return tz
  const offset = 0 - Number(match[1])
  return offset > 0 ? `GMT+${offset}` : `GMT${offset}`
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
export function regionAndCountryForDxccCode(dxccCode: number | undefined): { ituRegion?: number; countryCode?: string } {
  if (dxccCode == null) return {}
  const entity = DXCC_BY_CODE[dxccCode]
  return { ituRegion: entity?.ituRegion, countryCode: entity?.countryCode }
}

/// The real-world country a callsign's entity sits in, as an uppercase ISO
/// 3166 code — the prefix POTA ("US-1234") and LLOTA ("LLUS-0001") build
/// their references from, which is NOT the ham-radio DXCC entity: Hawaii is
/// its own entity ("KH6") but its parks are "US-"; a Canadian call's entity
/// prefix is "VE" but its parks are "CA-"; an EA3 call's is "EA" but Spain's
/// are "ES-". `@ham2k/lib-dxcc-data`'s `countryCode` carries that mapping;
/// the handful of entities without one (mostly long-deleted) fall back to
/// the entity prefix itself.
export function countryPrefixForCall(call: string | undefined): string | undefined {
  if (!call) return undefined
  const annotated = annotateCallAgainstCountryFile(call)
  const { countryCode } = regionAndCountryForDxccCode(annotated.dxccCode)
  return countryCode ? countryCode.toUpperCase() : annotated.entityPrefix
}

/// The DXCC entity a callsign belongs to — for our OWN station, whose entity
/// an operation records nowhere, having only the callsign it resolves from.
///
/// The three fields it answers with are the ones a callsign settles: an entity
/// has one name, one DXCC number and one continent, so this restates the call
/// rather than guessing beyond it. Deliberately NOT the zones — a
/// continent-sized entity spans several of those, and which one a station is
/// in does not follow from its callsign. Whatever fills those has to know
/// where the station actually is.
export function entityForCall(call: string | undefined): Pick<AnnotatedCallInfo, "dxccCode" | "continent" | "entityName"> {
  if (!call) return {}
  const { dxccCode, continent, entityName } = annotateCallAgainstCountryFile(call)
  return { dxccCode, continent, entityName }
}

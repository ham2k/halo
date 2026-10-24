// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The band a typed word names — "20", "20M", "70CM", "2MM", "SUBMM".
//
// Built from `EXTENDED_BANDS`, the whole vocabulary of bands the app knows and
// the pool the `$core.bands` Bands setting picks from (halo_core's
// `extendedBands` snapshots it), so the command cannot drift from it as that
// list grows. Deliberately wider than the Band dropdown, which offers only the
// bands enabled in Settings: naming a band is how an operator reaches one they
// work rarely enough not to have enabled.
//
// The unit-fallback rule mirrors halo_core's `parseBandInput`
// (packages/halo_core/lib/src/ham/radio.dart): a unit the operator typed pins
// which candidate to try, and a bare number means the metre band, falling
// back to centimetres because there is no 70m band to prefer. Millimetre
// bands are NOT in that fallback — "1" is 1mm to nobody, and the microwave
// operators who work them say "1MM" or use the GHz designations
// (parseGigBandCommand.ts).
//
// Pulled out of index.ts (which imports the SDK's `defineExtension` and so
// can't load under the plain node test runner) so this can be tested directly.

import { EXTENDED_BANDS } from "@ham2k/lib-operation-data"

/// Band names in wide use that are not what the band is called here. '75m' is
/// the phone end of 80m, and '2200m' is the common name for the band the band
/// table calls '2190m' — typed either way, the operator means the same band.
const BAND_ALIASES: Record<string, string> = {
  "75m": "80m",
  "2200m": "2190m",
}

/// 'other' is a fallback the band table produces, not a band anyone works.
const BAND_NAMES = new Set<string>((EXTENDED_BANDS as readonly string[]).filter((band) => band !== "other"))

const UNIT_SUFFIX = /(mm|cm|m)$/

/// The band `input` names, in the app's own spelling, or null for anything
/// else.
export function parseBandCommand(input: string): string | null {
  const spaced = input.trim().toLowerCase().replace(/\s/g, "")
  if (!spaced) return null
  // A comma is either a period, as in parseBandInput — "1,25" from a
  // comma-decimal keypad is the 1.25m band — or grouping, "2,190m".
  return bandNamed(spaced.replace(/,/g, ".")) ?? bandNamed(spaced.replace(/,/g, ""))
}

function bandNamed(cleaned: string): string | null {
  const suffix = UNIT_SUFFIX.exec(cleaned)?.[1]
  const units = suffix ? [suffix] : ["m", "cm"]
  const stem = suffix ? cleaned.slice(0, -suffix.length) : cleaned

  for (const unit of units) {
    // An exact name match, never a parsed number: matching numerically would
    // accept "20.0" and "1.250", spellings the Band dropdown never shows.
    const name = `${stem}${unit}`
    if (BAND_NAMES.has(name)) return name
    const alias = BAND_ALIASES[name]
    if (alias) return alias
  }
  return null
}

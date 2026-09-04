// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Microwave operators name their bands in GHz — '10G', not '3cm' — and that is
// also what contest exchanges and Cabrillo logs use. Typing the frequency
// instead is a trap: '10368.1' is read as kHz, so the band only comes out right
// by way of a fallback.
//
// Pulled out of index.ts (which imports the SDK's `defineExtension` and so
// can't load under the plain node test runner) so this can be tested directly.

/// Several bands go by more than one designation, so both are accepted.
/// 119G and 142G are not: they name allocations that no longer exist, and fall
/// outside every band we have.
const BANDS_FOR_GIG_DESIGNATIONS: Record<string, string> = {
  '1.2G': '23cm',
  '1.3G': '23cm',
  '2.3G': '13cm',
  '2.4G': '13cm',
  '3.3G': '9cm',
  '3.4G': '9cm',
  '5.7G': '6cm',
  '5.8G': '6cm',
  '10G': '3cm',
  '24G': '1.25cm',
  '47G': '6mm',
  '75G': '4mm', // The Cabrillo label; 76G and 78G are where the band is actually worked
  '76G': '4mm',
  '78G': '4mm',
  '122G': '2.5mm', // The Cabrillo label, though the band itself starts at 122.25 GHz
  '123G': '2.5mm',
  '134G': '2mm',
  '241G': '1mm',
}

/// Built from the designations we know, so a callsign like '9G5XX' is still read
/// as a call. Unlike app-polo, only the dotted spelling is matched: HaLo's
/// `MobileDotToSlashFormatter` gates on a callsign prefix that '1.' fails, so
/// '1.2G' reaches a command with its period intact.
const GIG_DESIGNATIONS_REGEX = new RegExp(
  `^(${Object.keys(BANDS_FOR_GIG_DESIGNATIONS).map((d) => d.replace(/\./g, '\\.')).join('|')})(HZ)?$`,
  'i',
)

export interface GigBandCommand {
  /// The designation as the table spells it, e.g. '10G' for an input of '10ghz'.
  designation: string
  band: string
}

/// The band `input` names ("10G", "10GHz", "1.2g"), or null for anything else.
export function parseGigBandCommand(input: string): GigBandCommand | null {
  const match = GIG_DESIGNATIONS_REGEX.exec(input.trim())
  if (!match) return null
  const designation = match[1].toUpperCase()
  const band = BANDS_FOR_GIG_DESIGNATIONS[designation]
  // The regex is built from the table, and a test holds them to each other.
  // Bail out rather than pass an undefined on: that would clear the QSO's band
  // and frequency while still telling the operator the band was set.
  if (!band) return null
  return { designation, band }
}

export { BANDS_FOR_GIG_DESIGNATIONS }

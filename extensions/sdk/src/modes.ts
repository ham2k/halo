// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// When two mode strings name the same emission for the purpose of duplicate
// detection. Scorers compare a candidate's `band|mode` against the ones a
// station has already been worked on, and a raw string comparison there makes
// the same contact look fresh whenever the two sides spell the mode at
// different resolutions — which they routinely do. A radio reports the
// sideband (`USB`), while POTA, SOTA and most spotters say `SSB`; SOTAwatch
// only ever says `DATA` or `DV`. Working a spot that says `SSB` after logging
// the station on `USB` is a duplicate, and the board has to strike it.
//
// A plain module, like dxcc.ts — import it by relative path from anything that
// must stay resolvable by plain `node --test`.

import { ADIF_MODES_AND_SUBMODES, ADIF_MODE_FOR_SUBMODE, superModeForMode } from "@ham2k/lib-operation-data"

/// The three spellings of one emission. ADIF calls `USB`/`LSB` submodes of
/// `SSB`, which [modesMatchForDupe]'s parent rule below would already catch —
/// but that rule leaves the two SIBLINGS distinct, and one contact logged on
/// `USB` and spotted on `LSB` is still one contact. The same fold qso_merge's
/// `_matchableMode` applies for the same reason.
const SIDEBAND_SPELLINGS = new Set(['SSB', 'USB', 'LSB'])

/// Spellings that are not ADIF modes at all but arrive from feeds that use
/// their own vocabulary — SOTAwatch posts `DV` where ADIF says `DIGITALVOICE`.
/// Resolved before the parent rule, so `DV` matches `DMR` through it.
const MODE_ALIASES: Record<string, string> = { DV: 'DIGITALVOICE' }

/// Spellings that name a whole super mode rather than an emission. A spot
/// that says `DATA` is not claiming the station is on some mode called DATA —
/// it is saying "one of the digital modes", so it matches whichever one the
/// contact was actually logged on.
const COARSE_SUPER_MODES: Record<string, string> = {
  DATA: 'DATA',
  DIGI: 'DATA',
  DIGITAL: 'DATA',
  PHONE: 'PHONE',
}

/// Every mode and submode ADIF names. The coarse rule below tests the WORKED
/// side against this before widening: `superModeForMode` answers `'DATA'` for
/// anything it does not recognize — an imported `OTHER`, a typo, and the
/// coarse spellings themselves — so without it `DATA` would match every one of
/// them, and `PHONE` would match `DATA`.
const KNOWN_MODES = new Set(ADIF_MODES_AND_SUBMODES.map((mode) => mode.toUpperCase()))

/// One spelling per emission, for a key that has to be stable: the sidebands
/// fold to `SSB` and the alias spellings resolve, everything else passes
/// through untouched. Two contacts on `FT4` and `MFSK` keep two keys — the
/// parent rule below belongs to duplicate matching, not to counting.
///
/// Exported because core scoring's bands-and-modes tally keys on this too: a
/// log holding both `USB` and `SSB` is one mode worked, and reporting it as
/// two contradicts the duplicate rule that already treats them as one.
export function canonicalMode(mode: string): string {
  const upper = (mode ?? '').trim().toUpperCase()
  if (SIDEBAND_SPELLINGS.has(upper)) return 'SSB'
  return MODE_ALIASES[upper] ?? upper
}

/// Whether a contact already in the log on [worked] makes one on [candidate]
/// a duplicate rather than fresh credit.
///
/// Matches a mode against its ADIF PARENT (`FT4` against `MFSK`,
/// `DMR` against `DIGITALVOICE`) but never two siblings — `FT4` and `FT2` are
/// separate contacts for award and contest credit, and so are `DMR` and
/// `C4FM`. The sideband spellings are the one exception, folded above.
///
/// DIRECTIONAL in its coarse rule, and only there: a coarse [candidate]
/// matches whichever mode the log names, but a coarse mode already IN the log
/// does not swallow the super mode around it. The asymmetry is the difference
/// between what a feed claims and what the operator recorded — a spot posted
/// as `DATA` is a station on some digital mode, while a QSO logged as `DATA`
/// (which a tapped SOTAwatch spot fills the field with) is one contact, and
/// must not make every later FT8, RTTY and PSK31 contact with that station on
/// that band a duplicate forever.
///
/// An absent mode matches only another absent mode: `superModeForMode('')`
/// answers `'DATA'`, so without the [KNOWN_MODES] guard every mode-less
/// contact would duplicate against the coarse `DATA` spelling.
export function modesMatchForDupe(worked: string, candidate: string): boolean {
  const w = canonicalMode(worked)
  const c = canonicalMode(candidate)
  if (w === c) return true
  if (!w || !c) return false
  if (ADIF_MODE_FOR_SUBMODE[w] === c || ADIF_MODE_FOR_SUBMODE[c] === w) return true
  const superMode = COARSE_SUPER_MODES[c]
  return Boolean(superMode) && KNOWN_MODES.has(w) && superModeForMode(w) === superMode
}

/// Bands whose voice sits on the lower sideband, for when a contact records a
/// band and no frequency. Every other band name is upper.
///
/// Both spellings of the two bands that have two — `2190m`/`2200m` and
/// `80m`/`75m` — because a contact carrying either arrives from an import or a
/// spot feed.
///
/// The same set `halo_core`'s `_lsbBands` holds, and the rule below is the
/// same rule: the app decides which sideband to log and this side decides
/// whether that sideband is worth writing into an exported file, so where the
/// two disagree the file contradicts the panel the operator worked from.
const LSB_BANDS = new Set(['2190m', '2200m', '630m', '560m', '160m', '80m', '75m', '40m'])

/// Below this, voice is lower sideband; at or above it, upper. A plain split
/// through HF, not a band edge — so this needs no band table to agree with,
/// which is what keeps it identical to the Dart side by construction.
const UPPER_SIDEBAND_FLOOR_KHZ = 9000

/// The one stretch below the floor that runs upper: 60 m is channelized USB by
/// international agreement.
const SIXTY_METRE_LO_KHZ = 5000
const SIXTY_METRE_HI_KHZ = 6000

/// The sideband voice conventionally runs on, from [freqKHz] if there is one
/// and from [band] otherwise, or **undefined** only when there is neither.
///
/// Mirrors `halo_core`'s `expectedSideband`, undefined for its null.
export function expectedSideband({ freqKHz, band }: { freqKHz?: number; band?: string }): string | undefined {
  if (freqKHz != null) {
    if (freqKHz >= UPPER_SIDEBAND_FLOOR_KHZ) return 'USB'
    return freqKHz >= SIXTY_METRE_LO_KHZ && freqKHz < SIXTY_METRE_HI_KHZ ? 'USB' : 'LSB'
  }
  if (!band) return undefined
  return LSB_BANDS.has(band) ? 'LSB' : 'USB'
}

/// Whether [mode] names the sideband the band does NOT run — the one thing
/// about a sideband worth writing down or showing.
///
/// False wherever there is nothing to contradict: a generic `SSB`, a non-voice
/// mode, and a contact stating neither a frequency nor a band.
///
/// Mirrors `halo_core`'s `isUnexpectedSideband`.
export function isUnexpectedSideband(
  mode: string | undefined | null,
  { freqKHz, band }: { freqKHz?: number; band?: string },
): boolean {
  // No trim, because the Dart twin does none: the two are documented to answer
  // identically, and ` LSB` answering differently across them is exactly the
  // app-versus-file contradiction that pairing them is meant to prevent.
  const upper = (mode ?? '').toUpperCase()
  if (upper !== 'USB' && upper !== 'LSB') return false
  const expected = expectedSideband({ freqKHz, band })
  return expected !== undefined && upper !== expected
}

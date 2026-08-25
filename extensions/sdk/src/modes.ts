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

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Pure parsing/combining logic for Callsign Notes files ("Hams of Note",
// ham2k/app-halo-dist#17), kept free of hook/host dependencies so it can be
// unit tested with plain `node --test` (see annotate.ts's header comment for
// the same constraint).
//
// File format (same as app-polo's call-notes extension): one entry per line,
// `CALLSIGN <note text...>` — the first whitespace-delimited token is the
// key, everything after it is the note. Blank lines and `#`-prefixed lines
// are comments. The same key may appear on multiple lines; entries
// accumulate in file order. Note text may carry a leading emoji marker and
// basic Markdown (e.g. links).

export interface CallNoteEntry {
  call: string
  note: string
}

export type CallNotesIndex = Record<string, CallNoteEntry[]>

/// A leading run of emoji at the start of a note is that note's "marker".
/// Explicit emoji/symbol ranges (plus ZWJ/variation-selector/skin-tone
/// combiners, so multi-codepoint sequences like 🧑‍💻 or 🏕️ match whole) —
/// deliberately NOT "any non-ASCII", which would eat a leading accented
/// letter in a note like "Ángel - friend".
const LEADING_EMOJI =
  /^[\u{1F000}-\u{1FFFF}\u{2300}-\u{23FF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}]+/u

/// Expansion eligibility (issue #17): the note must read as a plain list of
/// callsign-like tokens — ASCII letters/digits//- only, commas between
/// tokens, spaces allowed ONLY right after a comma. Anything with emoji or
/// free-text spacing is descriptive, not an expansion.
const EXPANDABLE = /^[A-Za-z0-9/-]+(?:, ?[A-Za-z0-9/-]+)*$/

export function parseCallNotes(body: string): CallNotesIndex {
  const entries: CallNotesIndex = {}
  for (let line of body.split(/[\r\n]+/)) {
    line = line.trim()
    if (!line || line.startsWith('#')) continue
    const [key, ...noteWords] = line.split(/\s+/)
    if (key.length > 2 && noteWords.length > 0) {
      const call = key.toUpperCase()
      entries[call] = entries[call] || []
      entries[call].push({ call, note: noteWords.join(' ') })
    }
  }
  return entries
}

const MAX_MARKER_EMOJIS = 4

/// Folds a call's note entries into one display string plus a single marker
/// emoji, following app-polo's combineCallNotes: the FIRST entry's text is
/// the most important (and supplies the marker emoji), every entry's leading
/// emoji joins the marker run (deduped, capped at 4 with a "+n" overflow).
export function combineNotes(entries: CallNoteEntry[] | undefined): { note: string; emoji?: string } | null {
  if (!entries || entries.length === 0) return null

  const emojis: string[] = []
  for (const entry of entries) {
    const match = LEADING_EMOJI.exec(entry.note)
    if (match && !emojis.includes(match[0])) emojis.push(match[0])
  }

  const text = entries[0].note.replace(LEADING_EMOJI, '').trim()
  const shown = emojis.slice(0, MAX_MARKER_EMOJIS).join('')
  const overflow = emojis.length > MAX_MARKER_EMOJIS ? `+${emojis.length - MAX_MARKER_EMOJIS}` : ''
  const note = [shown + overflow, text].filter(Boolean).join(' ')
  return { note, emoji: emojis[0] }
}

/// The value `//KEY` expands to: the first of the key's entries whose note
/// is expansion-eligible (see EXPANDABLE above), uppercased — e.g. an entry
/// `DAN WD4DAN,WD4JMM` expands to "WD4DAN,WD4JMM", which the call field
/// then treats as an ordinary comma-separated call list (issue #7). Returns
/// null when no entry qualifies, in which case no expansion is offered.
export function expansionValueFor(entries: CallNoteEntry[] | undefined): string | null {
  for (const entry of entries ?? []) {
    const note = entry.note.trim()
    if (EXPANDABLE.test(note)) return note.toUpperCase()
  }
  return null
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Pure parsing/combining logic for Callsign Notes files ("Hams of Note"),
// kept free of hook/host dependencies so it can be
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

/// Expansion eligibility: once any leading decoration is stripped (see
/// expansionValueFor), the note must read as a plain list of callsign-like
/// tokens — ASCII letters/digits//- only, commas between tokens, spaces
/// allowed ONLY right after a comma. Anything else in the remainder is
/// descriptive, not an expansion.
const EXPANDABLE = /^[A-Za-z0-9/-]+(?:, ?[A-Za-z0-9/-]+)*$/

/// A leading ATX heading marker (`#` through `######`, which InlineMarkdownText
/// renders) is decoration, same as a leading emoji — stripped before testing
/// EXPANDABLE, same as LEADING_EMOJI. Requires the trailing whitespace ATX
/// syntax itself requires (`\s+`, not `\s*`): without it, `#K1ABC,K2DEF`
/// would strip to an expansion InlineMarkdownText renders literally with the
/// `#` still showing, not as the heading this stripping assumes it became.
const LEADING_HEADING = /^#{1,6}\s+/

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

/// The value `//KEY` expands to: the first of the key's entries whose note,
/// once its leading marker (a heading OR an emoji — never both; see below) is
/// stripped, is expansion-eligible (see EXPANDABLE above) — e.g. an entry
/// `1GM ## VK1GM,VK2ETI` expands to "VK1GM,VK2ETI", uppercased, which the
/// call field then treats as an ordinary comma-separated call list. Returns
/// null when no entry qualifies (after stripping), in which case no
/// expansion is offered.
///
/// Strips AT MOST ONE marker, not both chained: combineNotes and
/// logging_controls.dart's _noteParts only ever look for a leading emoji at
/// position 0, so a note starting `## 🎉 …` would expand here (heading
/// stripped, emoji still leading) while its emoji goes unrecognized as a
/// marker on the display side. Not chaining leaves that combination
/// ineligible instead — the same "no expansion offered" outcome the display
/// side already gives it, rather than two paths disagreeing about a note
/// this format was never meant to describe.
export function expansionValueFor(entries: CallNoteEntry[] | undefined): string | null {
  for (const entry of entries ?? []) {
    const trimmed = entry.note.trim()
    const stripped = LEADING_HEADING.test(trimmed)
      ? trimmed.replace(LEADING_HEADING, '')
      : trimmed.replace(LEADING_EMOJI, '')
    const note = stripped.trim()
    if (EXPANDABLE.test(note)) return note.toUpperCase()
  }
  return null
}

/// A custom note file (HALO-53) has no separate enable toggle — removing it
/// from settings IS how it's disabled, unlike a builtin — so its `dataFile`
/// registration key has to be *derived* from something the user's settings
/// already carry, not a separately-stored id. `location` is what's actually
/// unique per file, and deriving from it means editing anything BUT the URL
/// (the file's display name, say) keeps the same identifier — so the same
/// download cache and last-updated bookkeeping carry over, rather than
/// orphaning it under an id that no longer matches anything. This key also
/// becomes a literal filename (`data_file_manager.dart` caches each file's
/// parsed index as `<key>.json`), which is why every non-alphanumeric
/// character is stripped rather than just lowercased.
/// Cheap, deterministic 32-bit hash (djb2 variant) of the FULL location —
/// the `.slice(0, 60)` below only keeps the slug readable; two different
/// long URLs (e.g. pre-signed links whose distinguishing token sits past
/// character 60) can share the same first 60 slug characters, and without
/// this suffix would collide onto the same `registerHook` key, silently
/// dropping one file's data.
function shortHash(input: string): string {
  let hash = 5381
  for (let i = 0; i < input.length; i++) {
    hash = (Math.imul(hash, 33) + input.charCodeAt(i)) | 0
  }
  return (hash >>> 0).toString(36)
}

export function customIdentifier(location: string): string {
  const slug = location
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 60)
  return `custom-${slug}-${shortHash(location)}`
}

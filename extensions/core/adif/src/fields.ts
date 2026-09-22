// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Rendering one ADIF record's fields.

/// Characters HaLo itself puts into a field, folded back to the ASCII a
/// forty-year-old logging program can read. The typographic quotes come from
/// the lookup layer's `First “Nick” Last` (see normalizeGuess.ts); this table
/// is meant to grow as other Unicode punctuation finds its way in.
///
/// Not a general sanitizer: a correspondent's name in its own script stays as
/// they spell it. lib-format-tools' `sanitizeToISO8859` is the blunter tool —
/// it replaces everything outside Latin-1 with `·`, which would mangle those.
const SUBSTITUTIONS: [RegExp, string][] = [
  [/[“”]/g, '"'],
  [/[‘’]/g, "'"],
]

function sanitizeAdifText(text: string): string {
  return SUBSTITUTIONS.reduce((result, [pattern, replacement]) => result.replace(pattern, replacement), text)
}

/// One field on its way out. `value` is whatever the source had — a number, a
/// date, nothing at all — and an empty one writes nothing, which is how the
/// record's optional fields are left out.
export interface AdifField {
  name: string
  value: unknown
}

export function field(name: string, value: unknown): string {
  if (value === undefined || value === null || value === "") return ""
  // A MAP is never an ADIF value. QSON is a forward-compatible blob and
  // `qson_values.dart` normalizes only the keys a Dart getter reads, so a peer
  // or a lookup writing `{ cqZone: { value: 5 } }` reaches here intact — and
  // `String()` would put the literal text `[object Object]` in a file an
  // operator submits. Writing nothing loses the same field either way and says
  // nothing false about the contact.
  //
  // A LIST is not that case: `String(['US-0001', 'US-0002'])` is ADIF's own
  // comma-separated multi-value syntax, which is what a field like
  // MY_POTA_REF wants from a hook that answers with several.
  if (typeof value === "object" && !Array.isArray(value)) return ""
  const text = sanitizeAdifText(String(value))
  return `<${name}:${text.length}>${text} `
}

/// A record's fields, in order, with each NAME written at most once: ADIF has
/// no meaning for a field repeated inside one record, and a log processor
/// reading the second copy would contradict the first. The first one to carry
/// a value wins — so the contact's own fields outrank an activity's, and among
/// the `adifFields` hooks the order they were asked in decides, the main
/// handler first (see [fieldSetsPerHook]). app-polo resolves a collision the
/// same way (`qsonToADIF.js`, "keep the first one defined").
///
/// A field that renders EMPTY doesn't claim the name — polo's list holds the
/// undefined ones too, so there a `{ STATE: undefined }` the base row never
/// wrote still shuts out a hook's STATE. Nothing should have to know which
/// optional fields the row above happened to skip.
export function renderRow(fields: AdifField[]): string {
  // Case-folded: ADIF field names are case-insensitive, and a third-party
  // extension answering `my_sig` beside a core hook's `MY_SIG` would otherwise
  // write the field twice — the very record this exists to prevent.
  const written = new Set<string>()
  let row = ""
  for (const { name, value } of fields) {
    if (written.has(name.toUpperCase())) continue
    const text = field(name, value)
    if (!text) continue
    written.add(name.toUpperCase())
    row += text
  }
  return row
}

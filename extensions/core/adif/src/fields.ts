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
  if (value === undefined || value === null || value === '') return ''
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
  let row = ''
  for (const { name, value } of fields) {
    if (written.has(name.toUpperCase())) continue
    const text = field(name, value)
    if (!text) continue
    written.add(name.toUpperCase())
    row += text
  }
  return row
}

/// ADIF's `CNTY` is `STATE,County` and nothing else. What a contact stores is
/// one of several shapes, from writers that never agreed on one (HALO-562):
///
/// - `US/NY/Kings` — the country-qualified code an ADIF import produces
///   (`adif_to_qson.dart`), whose last two segments are already the answer;
/// - `??/NY/Kings` — the same, from a country whose scheme the import didn't
///   recognise, and equally answerable;
/// - `PR/Ponce` — Puerto Rico, which that importer leaves UNqualified, so the
///   two segments are the state and county themselves;
/// - `Hartford` — a plain name from a lookup (`normalizeGuess.ts`) or typed
///   into the More pane, which needs the contact's own state to become one.
///
/// A name with no state and no state in the code writes NOTHING. `CNTY`
/// without its state is not a county to any program that reads this file, and
/// a half-answer in an award submission is worse than an absent one — which
/// is also why the qualifier is stripped rather than passed through: `PR,
/// PR/Ponce` would be read by nothing.
export function adifCounty(county: unknown, state: unknown): string | undefined {
  const text = typeof county === 'string' ? county.trim() : ''
  if (!text) return undefined
  const stateCode = typeof state === 'string' ? state.trim() : ''
  const segments = text.split('/').filter((segment) => segment !== '')
  const name = segments[segments.length - 1]
  if (!name) return undefined
  const qualifier = segments.length >= 2 ? segments[segments.length - 2] : ''
  // Three deep, the middle segment is the state whatever the country said.
  const resolved = segments.length >= 3 && qualifier !== '??' ? qualifier : ''
  // Two deep is ambiguous, because the importer produces both shapes: a
  // Puerto Rican `PR/Ponce`, where the first segment IS the state, and a
  // `US/Hartford` or `??/Hartford` from a `CNTY` that arrived without its
  // comma, where it is the country qualifier and no state was ever stated.
  // Only the two country qualifiers the importer emits can be told apart, so
  // they are excluded by name and everything else two-deep reads as
  // state/county — `US,Hartford` is a state code to nothing.
  const pair = segments.length === 2 && qualifier !== '??' && qualifier !== 'US' ? qualifier : ''
  const finalState = resolved || pair || stateCode
  return finalState ? `${finalState},${name}` : undefined
}

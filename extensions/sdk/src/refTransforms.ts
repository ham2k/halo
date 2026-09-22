// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// Live-typing reformatting rules shared by the reference-list programs whose
// codes are `<prefix>-<number>` (POTA's "US-1234", LLOTA's "LLUS-0001"). A
// plain module like dxcc.ts — no `@ham2k/extension-sdk` value import — so a
// test can reach it by relative path under plain `node --test`.

/// One pass of `RefListInputDescriptor.transforms` (types.ts): a regex source,
/// a replacement with braced `${n}` group placeholders, and JS-style flags.
export type RefTransform = { pattern: string; replacement: string; flags?: string }

/// Live-typing reformatting for the (possibly comma/space-separated list of)
/// reference(s) in one chip's field, e.g. "us1234 us5678" ->
/// "US-1234,US-5678" — mirrors app-polo's POTAInput.jsx textTransformer
/// chain, but declared once per loggingControls/operationControls call (with
/// `prefix` baked in from the QSO's guessed DXCC entity) instead of run in
/// the runtime on every keystroke; the core's native input widget applies
/// this list, in order, on every keystroke.
export function transformsForPrefix(prefix: string): RefTransform[] {
  return [
    // a run of spaces between two refs -> ", " (normalize to one separator style)
    { pattern: "([A-Z0-9]-\\d+|TEST) +(?=[A-Z0-9])", replacement: "${1}, ", flags: "gi" },
    // bare number (or "TEST"), at the start or right after a separator -> prefix-number
    // (the separator itself is captured and replayed, not consumed, so a
    // pasted "US-1234,5678" keeps its comma instead of merging into one ref).
    // Braced `${1}`/`${2}`, not bare `$1`/`$2` — `prefix` can itself start
    // with a digit (e.g. DXCC "3D2" for Fiji), and a bare "$1" immediately
    // followed by that would misparse as capture group 13.
    { pattern: "(^|,\\s*)(\\d\\d+|TEST)", replacement: `\${1}${prefix}-\${2}`, flags: "gi" },
    // "US1234" -> "US-1234". Anchored with a negative lookbehind so it only
    // fires at the START of a not-yet-dashed reference — without it, a
    // multi-character DXCC prefix that mixes letters and digits (e.g.
    // Fiji's "3D2") gets its OWN internal "D2" mismatched as an undashed
    // reference once transform 2 above has already inserted "3D2-1234",
    // corrupting it into "3D-2-1234".
    { pattern: "(?<![A-Z0-9])([A-Z]+)(\\d+|TEST)", replacement: "${1}-${2}", flags: "gi" },
    // NOTE: deliberately no "eagerly insert the next prefix right after a
    // trailing comma" rule here (app-polo's inputs have one) — transform 2
    // above already prefixes a second reference once 2+ digits appear after
    // the comma, the same way it does at the start of the field. An eager
    // version that inserted "US-" the instant a trailing comma appeared
    // makes deleting back through a second reference impossible: backspacing
    // "US-1234,US-5678" down to "US-1234,US-" and then to "US-1234," would
    // immediately re-grow the trailing "US-1234,US-" the transform had just
    // reinserted, so the comma itself could never be reached.

    // strip anything that can't appear in a reference list
    { pattern: "[^A-Z0-9\\-, ]", replacement: "", flags: "gi" },
  ]
}

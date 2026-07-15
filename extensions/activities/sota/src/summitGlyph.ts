// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Spot label points glyph — pulled out of index.ts so it can be unit-tested
// directly (see index.test.ts): this file has no dependency on
// `@ham2k/halo-extension-sdk` (a tsc-only path alias — see extensions/tsconfig.json —
// that Node's own module resolver, used by `node --test`, can't resolve at
// runtime), unlike index.ts which imports real hook types/values from it.

// `summitDetails` is a free-text string like "Iwaguroyama, 1746m, 10
// points" — api2 has no separate `points` field, unlike app-polo's
// api-db2 source.
export function summitGlyphFromDetails(summitDetails: string): string {
  const match = summitDetails.match(/,\s*(\d+)\s*points?\s*$/i)
  const points = match ? parseInt(match[1], 10) : 0
  // U+278A-U+2793: Dingbat Negative Circled Sans-Serif Digits One-Ten — same
  // glyph scheme app-polo uses for SOTA spot points. Points only ever range
  // 1-10, matching that block, so anything outside it isn't a real value.
  return points >= 1 && points <= 10 ? String.fromCodePoint(10121 + points) : ''
}

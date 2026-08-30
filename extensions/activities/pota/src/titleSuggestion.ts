// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Pulled out of index.ts's RefHandler so it can be unit-tested directly (see
// index.test.ts) without pulling in the `@ham2k/extension-sdk` bare
// specifier — a tsc-only path alias Node's own module resolver can't resolve
// at runtime (same reason refFormatting.ts stays free of it).

/// Minimal shape this needs from a decorated Ref — matches the SDK's Ref.
interface RefLike {
  type: string
  ref?: string
  name?: string
}

/// Minimal shape this returns — matches the SDK's TitleSuggestion.
interface TitleSuggestionLike {
  at: string
  subtitle?: string
}

// Only the activation ref means "this operation is happening at this park"
// — a hunting ref just names a station worked, not
// where this operation is. `ref`/`name` are proper nouns, not prose, so no
// translation needed here (unlike decorateRef's placeholders).
export function suggestOperationTitleForPota(ref: RefLike, activationType: string): TitleSuggestionLike | null {
  if (ref.type !== activationType || !ref.ref) return null
  return { at: ref.ref, subtitle: ref.name }
}

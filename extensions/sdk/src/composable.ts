// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The kernel's rule for in-runtime composition, shared with the SDK's test
// harness so an extension's unit test is refused where the app would refuse
// it. Not re-exported from the SDK's entry point.

import { COMPOSABLE_CATEGORIES } from "./hookCategories.ts"

/// Throws unless [category] is one extensions may compose
/// (COMPOSABLE_CATEGORIES). A bundle reaches `invokeLocal` on the kernel
/// whatever SDK it was built with, so the narrowed `hooks.*` types are a
/// convenience and this is the rule for that entry. The host's own way in,
/// which reaches every category, is its `bridge`, which no bundle can call.
///
/// Compared by hand, never through `Array.prototype.includes` or an iterator:
/// a bundle shares this realm's intrinsics and can rewrite either to answer
/// yes.
export function requireComposable(category: string): void {
  for (let i = 0; i < COMPOSABLE_CATEGORIES.length; i++) {
    if (COMPOSABLE_CATEGORIES[i] === category) return
  }
  throw new Error(`Hooks in the "${category}" category cannot be invoked from inside the runtime; only ${COMPOSABLE_CATEGORIES.join(", ")} can`)
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The kernel's rule for in-runtime composition, shared with the SDK's test
// harness so an extension's unit test is refused where the app would refuse
// it. Not re-exported from the SDK's entry point.

import { COMPOSABLE_CATEGORIES } from "./hookCategories.ts"

/// Throws unless [category] is one extensions may compose
/// (COMPOSABLE_CATEGORIES). A bundle reaches `invokeLocal` through `__polo`
/// whatever SDK it was built with, so the narrowed `hooks.*` types are a
/// convenience and this is the rule for that entry. The kernel's bridge
/// entries on `__polo` (`invokeHook`, `invokeHookAll`, `invokeHookBatch`) are
/// not held to it: they are the host's, but a bundle can reach them too.
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

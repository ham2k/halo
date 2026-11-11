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

// Every name an object inherits from Object.prototype, taken as the kernel
// loads, before any bundle can add to it.
const INHERITED_NAMES: Record<string, true> = Object.create(null)
{
  const names = Object.getOwnPropertyNames(Object.prototype)
  for (let i = 0; i < names.length; i++) INHERITED_NAMES[names[i]] = true
}

/// Throws unless [method] can be a hook's own method: a string, and not a
/// name every object has. `valueOf` answers with the hook object itself — the
/// other extension's live hook, through which its account reaches the caller
/// on that hook's next call — and the rest of Object.prototype is no hook's
/// method either.
export function requireHookMethodName(method: unknown): void {
  if (typeof method !== "string" || INHERITED_NAMES[method] === true) {
    throw new Error(`"${String(method)}" is not a hook method that can be invoked from inside the runtime`)
  }
}

/// Whether [s] starts with [prefix], compared by index, never with
/// `String.prototype.startsWith`: a bundle evaluated earlier can rewrite that
/// to answer yes to any key.
export function hasPrefix(s: string, prefix: string): boolean {
  if (s.length < prefix.length) return false
  for (let i = 0; i < prefix.length; i++) {
    if (s[i] !== prefix[i]) return false
  }
  return true
}

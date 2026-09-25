// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// Every hook category, spelled once on the extension side. `registerHook` and
// the in-runtime invocations accept only these and `ref:<type>`, so a
// misspelled category fails the typecheck instead of registering a hook
// nothing ever calls — the runtime itself accepts any string, and would say
// nothing. A manifest's `hooks` is held to the same list without a check of
// its own: the build requires it to match what the bundle registers
// (hook-check.mjs), and the typecheck keeps what it registers in here.
//
// The host's half of every name lives in halo_core's hook catalog
// (packages/halo_core/lib/src/hook_names.dart); a category the host names
// belongs in both, and app/test/guards/hook_names_test.dart fails when the
// host spells one this list does not have.

/// The categories the host, or another extension, invokes. The in-runtime ones
/// (`adifFields`, `lookup`, `recentContextLookup`, `callNotes`, `bench`) are
/// called only from inside the runtime, but a misspelling costs the same.
export const HOOK_CATEGORIES = [
  "account",
  "activity",
  "adifFields",
  "adifImport",
  "bench",
  "callNotes",
  "command",
  "dataFile",
  "export",
  "form",
  "lookup",
  "lookupService",
  "panel",
  "recentContextLookup",
  "runtime",
  "scoring",
  "settingsPanel",
  "spots",
  "syncTransport",
  "template",
] as const

export type HookCategory = (typeof HOOK_CATEGORIES)[number]

/// What a hook may be registered or invoked under: a category above, or a
/// reference handler — `ref:<type>`, and the `ref:<type>/<code>` form that
/// claims a legacy reference under someone else's type.
export type HookCategoryName = HookCategory | `ref:${string}`

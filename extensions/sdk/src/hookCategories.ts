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
  "bandAnnotations",
  "bench",
  "callNotes",
  "chasing",
  "cluster",
  "command",
  "dataFile",
  "export",
  "form",
  "keyerSets",
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

/// The categories one extension may invoke inside the runtime (`hooks.*`, the
/// kernel's `invokeLocal`): hooks meant to be asked by other extensions for
/// data. The kernel refuses
/// every other one, `ref:<type>` and the caller's own hooks included — a
/// target hook runs with its own context, so composing an `account`,
/// `command` or `syncTransport` hook would act with another extension's
/// credentials. The allowed ones answer questions and may still spend the
/// target's account doing it: any extension can make a QRZ or HamQTH
/// `lookup` look a call up with the operator's login. That is the service
/// those hooks exist to give, and nothing here limits it. Keep this the list
/// of what extensions actually compose; the host invokes every category over
/// the bridge regardless.
///
/// Not named `*HOOK_CATEGORIES`: the hook-names guard matches that array by
/// its name.
export const COMPOSABLE_CATEGORIES = [
  "adifFields",
  "callNotes",
  "export",
  "lookup",
  "lookupService",
  "recentContextLookup",
] as const satisfies readonly HookCategory[]

export type ComposableHookCategory = (typeof COMPOSABLE_CATEGORIES)[number]

/// What a hook may be registered or invoked under: a category above, or a
/// reference handler — `ref:<type>`, and the `ref:<type>/<code>` form that
/// claims a legacy reference under someone else's type.
export type HookCategoryName = HookCategory | `ref:${string}`

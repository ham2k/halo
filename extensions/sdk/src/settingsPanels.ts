// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Pure, host-independent helpers for the `settingsPanel`/`account` hook
// dispatch in kernel.ts — pulled out (same pattern as
// extensions/core/lookups/src/mergeLookup.ts) so this logic has its own
// unit test suite instead of only being exercised through the JS
// engine/bridge plumbing, which isn't easily unit-testable in isolation.

import type { SettingsPanelDescriptor } from "./types.ts"

export interface SettingsPanelEntry {
  panelKey: string
  hookKey: string
  extensionKey: string
  title: string | null
  icon: string | null
  order: number | null
  kind: "simple" | "dynamic"
  /// See SettingsPanelDescriptor.sidebar's doc comment (types.ts) — defaults
  /// true.
  sidebar: boolean
  /// See SettingsPanelDescriptor.dataFilesSection's doc comment (types.ts)
  /// — defaults false.
  dataFilesSection: boolean
}

/// Key namespacing rule (docs/extensions/settings.md): for categories where
/// an extension can register more than one of something (settingsPanel
/// panels, account credentials), the registration key must equal the
/// extension's own key or be prefixed `<extensionKey>_` — e.g. extension
/// `pota` may use `pota` or `pota_spots`, never bare `spots` or camelCase
/// `potaSpots`. Categories outside that rule always pass.
export function isValidHookKey(category: string, extensionKey: string, resolvedKey: string): boolean {
  if (category !== "settingsPanel" && category !== "account") return true
  return resolvedKey === extensionKey || resolvedKey.startsWith(`${extensionKey}_`)
}

/// Tier 1 (`kind: 'simple'`) settings panels are static data, not a
/// getDefinition() function — this builds the FormDefinition shape directly
/// from the registered object, with no field values overlaid (the host
/// owns Tier 1 persistence and overlays current values itself).
export function tier1FormDefinition(hook: Record<string, unknown>): { title: unknown; elements: unknown } {
  return { title: hook.title, elements: hook.fields ?? [] }
}

/// One `settingsPanel` registration can surface more than one panel. Builds
/// the flat list of panel entries for one registration: Tier 1 is always
/// exactly one (the registration itself); Tier 2 is one unless
/// `descriptors` (the result of calling its `getPanels()`, when present) is
/// given, in which case it's one per descriptor. `hookKey` (routes
/// `invokeHook` calls back to this registration) is always the
/// registration's own key, independent of `panelKey` — the two only differ
/// for a Tier 2 registration whose `getPanels()` returns more than one
/// panel under a single hook object.
export function settingsPanelEntriesFor(
  record: { key: string; extensionKey: string; hook: Record<string, unknown> },
  descriptors?: SettingsPanelDescriptor[] | null,
): SettingsPanelEntry[] {
  const hook = record.hook
  if (hook.kind === "simple") {
    return [
      {
        panelKey: record.key,
        hookKey: record.key,
        extensionKey: record.extensionKey,
        title: (hook.title as string) ?? null,
        icon: (hook.icon as string) ?? null,
        order: (hook.order as number) ?? null,
        kind: "simple",
        sidebar: (hook.sidebar as boolean | undefined) ?? true,
        dataFilesSection: (hook.dataFilesSection as boolean | undefined) ?? false,
      },
    ]
  }
  if (hook.kind === "dynamic") {
    if (descriptors) {
      // A Tier 2 registration's getPanels() can return arbitrary keys at
      // call time (unlike the registration key itself, which
      // registerHook already checked) — apply the same namespacing rule
      // here so a misbehaving extension can't claim another extension's
      // panel key. Dropped silently from the caller's perspective; the
      // one caller (kernel.ts) logs a warning per dropped descriptor,
      // which is why the log doesn't belong in this pure function.
      return descriptors
        .filter((d) => isValidHookKey("settingsPanel", record.extensionKey, d.key))
        .map((d) => ({
          panelKey: d.key,
          hookKey: record.key,
          extensionKey: record.extensionKey,
          title: d.title ?? null,
          icon: d.icon ?? null,
          order: d.order ?? null,
          kind: "dynamic",
          sidebar: d.sidebar ?? true,
          dataFilesSection: d.dataFilesSection ?? false,
        }))
    }
    // No getPanels: the registration itself is the one panel. Title is
    // unknown until getDefinition is fetched — the host falls back to
    // displaying the key until then.
    return [
      {
        panelKey: record.key,
        hookKey: record.key,
        extensionKey: record.extensionKey,
        title: null,
        icon: null,
        order: null,
        kind: "dynamic",
        sidebar: true,
        dataFilesSection: false,
      },
    ]
  }
  return []
}

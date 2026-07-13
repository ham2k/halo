// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// @ham2k/polo-sdk — the surface extensions import. Each extension bundle carries
// its own copy of this module (esbuild bundles it in), while all shared
// state lives on the kernel singleton at globalThis.__polo. That split is
// deliberate: the module-scoped `currentExtensionKey` below is per-bundle, which
// is how host KV calls get namespaced to the extension without extensions having
// to pass their own key around.

import type {
  FetchOptions,
  FetchResponse,
  JSONValue,
  ExtensionDefinition,
  LookupRow,
  FormDefinition,
  FormField,
  StatusBarMessageParams,
  StatusBarProgressParams,
  StatusBarNoticeParams,
} from "./types"

export * from "./types"
export * from "./i18n"

interface KernelApi {
  defineExtension(def: ExtensionDefinition): void
  hostCall(method: string, params: Record<string, unknown>): Promise<unknown>
  invokeLocal(
    category: string,
    method: string,
    args: unknown,
    online?: boolean,
  ): Promise<{ key: string; ok: boolean; value?: unknown; error?: string }[]>
  invokeLocalSequential(
    category: string,
    method: string,
    initialArgs: unknown,
    fold: (args: unknown, hookResult: unknown, hookKey: string) => unknown,
    online?: boolean,
  ): Promise<{ key: string; ok: boolean; value?: unknown; error?: string }[]>
  log(message: string): void
  getAccountKvKey(extensionKey: string): string
  registerDynamicForm(formId: string, extensionKey: string, hookObj: Record<string, unknown>): void
  unregisterDynamicForm(formId: string): void
  host: {
    showForm(form: FormDefinition, state?: Record<string, any>, extensionKey?: string): Promise<Record<string, any> | null>
  }
}

let currentExtensionKey = 'unknown'

function kernel(): KernelApi {
  const k = (globalThis as Record<string, unknown>).__polo as KernelApi | undefined
  if (!k) throw new Error('polo kernel not loaded; kernel.js must be evaluated before extension bundles')
  return k
}

export function defineExtension(def: ExtensionDefinition): void {
  currentExtensionKey = def.key
  kernel().defineExtension(def)
}

/// Cross-extension composition inside the runtime (no bridge round-trip).
export const hooks = {
  invokeAll(category: string, method: string, args: unknown, online?: boolean) {
    return kernel().invokeLocal(category, method, args, online)
  },

  /// Like `invokeAll`, but calls hooks one at a time in priority order,
  /// threading each result into the next call's args via `fold` — needed
  /// when later hooks must see earlier hooks' contributions.
  invokeAllSequential(
    category: string,
    method: string,
    initialArgs: unknown,
    fold: (args: unknown, hookResult: unknown, hookKey: string) => unknown,
    online?: boolean,
  ) {
    return kernel().invokeLocalSequential(category, method, initialArgs, fold, online)
  },
}

export const host = {
  async fetch(url: string, options?: FetchOptions): Promise<FetchResponse> {
    return (await kernel().hostCall('fetch', { url, ...options })) as FetchResponse
  },

  async kvGet(key: string): Promise<JSONValue | null> {
    return (await kernel().hostCall('kvGet', { ns: currentExtensionKey, key })) as JSONValue | null
  },

  async kvSet(key: string, value: JSONValue): Promise<void> {
    await kernel().hostCall('kvSet', { ns: currentExtensionKey, key, value })
  },

  async setAccountSession(session: Record<string, string>): Promise<void> {
    const kvKey = kernel().getAccountKvKey(currentExtensionKey)
    await kernel().hostCall('setAccountSession', { ns: currentExtensionKey, kvKey, session })
  },

  /// The app's own core settings (theme/locale/font scale) — not a generic
  /// KV store, these read/write SettingsService directly so a change here
  /// takes effect everywhere else in the app (MaterialApp's themeMode,
  /// LocaleSettings, text scaling), not just in some extension's own
  /// storage. For the core/settings extension's General panel; not
  /// intended for arbitrary extension use.
  async getCoreSettings(): Promise<{ themeMode: string; locale: string; fontScale: string }> {
    return (await kernel().hostCall('getCoreSettings', {})) as { themeMode: string; locale: string; fontScale: string }
  },

  async setCoreSetting(key: string, value: JSONValue): Promise<void> {
    await kernel().hostCall('setCoreSetting', { key, value })
  },

  /// Looks up a string from the app's own translations (app/lib/i18n/
  /// {en,es}.i18n.json) by its dot-path key (e.g. "settings.theme.title"),
  /// in whatever locale is currently active — there's no separate
  /// extension-i18n system, this is the same source of truth the rest of
  /// the app reads via its generated `t[key]` lookup. Returns null if the
  /// key doesn't exist or isn't a plain string (e.g. it needs interpolation
  /// params, which this doesn't support).
  async translate(key: string): Promise<string | null> {
    return (await kernel().hostCall('translate', { key })) as string | null
  },

  /// Same lookup as `translate`, but for many keys in one bridge round
  /// trip — for a panel with a dozen-plus labels, that's a dozen-plus
  /// fewer JS↔Dart hops than calling `translate` in a loop. Missing/non-
  /// string keys come back as null, same as `translate`.
  async translateAll(keys: string[]): Promise<Record<string, string | null>> {
    return (await kernel().hostCall('translateAll', { keys })) as Record<string, string | null>
  },

  async dbLookupSelectOne(category: string, key: string): Promise<LookupRow | null> {
    return (await kernel().hostCall('dbLookupSelectOne', { category, key })) as LookupRow | null
  },

  async dbLookupSelectAll(category: string, query: string): Promise<LookupRow[]> {
    return (await kernel().hostCall('dbLookupSelectAll', { category, query })) as LookupRow[]
  },

  async dbLookupSelectByLocation(category: string, lat: number, lon: number, delta: number): Promise<LookupRow[]> {
    return (await kernel().hostCall('dbLookupSelectByLocation', { category, lat, lon, delta })) as LookupRow[]
  },

  async showForm(form: FormDefinition, state: Record<string, any> = {}): Promise<Record<string, any> | null> {
    return kernel().host.showForm(form, state, currentExtensionKey)
  },

  statusBar: {
    /// A transient single-line message, replacing any prior message under
    /// the same `key`. `key` is automatically namespaced to this extension —
    /// other extensions can't see or clear it.
    async setMessage(params: StatusBarMessageParams): Promise<void> {
      await kernel().hostCall('statusBarSetMessage', { ...params, ns: currentExtensionKey })
    },

    /// A transient progress bar under `key`; omit `value` for indeterminate.
    async setProgress(params: StatusBarProgressParams): Promise<void> {
      await kernel().hostCall('statusBarSetProgress', { ...params, ns: currentExtensionKey })
    },

    /// Removes the message/progress item under `key`, if any.
    async clear(key: string): Promise<void> {
      await kernel().hostCall('statusBarClear', { key, ns: currentExtensionKey })
    },

    /// A richer, dismissible notice, replacing any prior undismissed notice
    /// under the same `key`. Stays in the user's notice history after
    /// dismissal.
    async showNotice(params: StatusBarNoticeParams): Promise<void> {
      await kernel().hostCall('statusBarShowNotice', { ...params, ns: currentExtensionKey })
    },

    /// Dismisses the active notice under `key`, if any.
    async dismissNotice(key: string): Promise<void> {
      await kernel().hostCall('statusBarDismissNotice', { key, ns: currentExtensionKey })
    },
  },

  log(message: string): void {
    kernel().log(`[${currentExtensionKey}] ${message}`)
  },
}

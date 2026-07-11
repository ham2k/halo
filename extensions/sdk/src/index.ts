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
  invokeAll(category: string, method: string, args: unknown) {
    return kernel().invokeLocal(category, method, args)
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
      await kernel().hostCall('statusBarSetMessage', { ...params, extensionKey: currentExtensionKey })
    },

    /// A transient progress bar under `key`; omit `value` for indeterminate.
    async setProgress(params: StatusBarProgressParams): Promise<void> {
      await kernel().hostCall('statusBarSetProgress', { ...params, extensionKey: currentExtensionKey })
    },

    /// Removes the message/progress item under `key`, if any.
    async clear(key: string): Promise<void> {
      await kernel().hostCall('statusBarClear', { key, extensionKey: currentExtensionKey })
    },

    /// A richer, dismissible notice, replacing any prior undismissed notice
    /// under the same `key`. Stays in the user's notice history after
    /// dismissal.
    async showNotice(params: StatusBarNoticeParams): Promise<void> {
      await kernel().hostCall('statusBarShowNotice', { ...params, extensionKey: currentExtensionKey })
    },

    /// Dismisses the active notice under `key`, if any.
    async dismissNotice(key: string): Promise<void> {
      await kernel().hostCall('statusBarDismissNotice', { key, extensionKey: currentExtensionKey })
    },
  },

  log(message: string): void {
    kernel().log(`[${currentExtensionKey}] ${message}`)
  },
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// @ham2k/polo-sdk — the surface extensions import. Each extension bundle carries
// its own copy of this module (esbuild bundles it in), while all shared
// state lives on the kernel singleton at globalThis.__polo. That split is
// deliberate: the module-scoped `currentExtensionKey` below is per-bundle, which
// is how host KV calls get namespaced to the extension without extensions having
// to pass their own key around.

import type { FetchOptions, FetchResponse, JSONValue, ExtensionDefinition } from "./types"

export * from "./types"

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

  log(message: string): void {
    kernel().log(`[${currentExtensionKey}] ${message}`)
  },
}

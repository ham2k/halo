// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// @ham2k/polo-sdk — the surface plugins import. Each plugin bundle carries
// its own copy of this module (esbuild bundles it in), while all shared
// state lives on the kernel singleton at globalThis.__polo. That split is
// deliberate: the module-scoped `currentPluginKey` below is per-bundle, which
// is how host KV calls get namespaced to the plugin without plugins having
// to pass their own key around.

import type { FetchOptions, FetchResponse, JSONValue, PluginDefinition } from "./types"

export * from "./types"

interface KernelApi {
  definePlugin(def: PluginDefinition): void
  hostCall(method: string, params: Record<string, unknown>): Promise<unknown>
  log(message: string): void
}

let currentPluginKey = 'unknown'

function kernel(): KernelApi {
  const k = (globalThis as Record<string, unknown>).__polo as KernelApi | undefined
  if (!k) throw new Error('polo kernel not loaded; kernel.js must be evaluated before plugin bundles')
  return k
}

export function definePlugin(def: PluginDefinition): void {
  currentPluginKey = def.key
  kernel().definePlugin(def)
}

export const host = {
  async fetch(url: string, options?: FetchOptions): Promise<FetchResponse> {
    return (await kernel().hostCall('fetch', { url, ...options })) as FetchResponse
  },

  async kvGet(key: string): Promise<JSONValue | null> {
    return (await kernel().hostCall('kvGet', { ns: currentPluginKey, key })) as JSONValue | null
  },

  async kvSet(key: string, value: JSONValue): Promise<void> {
    await kernel().hostCall('kvSet', { ns: currentPluginKey, key, value })
  },

  log(message: string): void {
    kernel().log(`[${currentPluginKey}] ${message}`)
  },
}

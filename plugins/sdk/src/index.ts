// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// @ham2k/polo-sdk — the surface plugins import. Everything here is a thin,
// stateless wrapper over the kernel singleton at globalThis.__polo, so that
// each separately-bundled plugin shares one registry and one host bridge.

import type { FetchOptions, FetchResponse, JSONValue, PluginDefinition } from "./types"

export * from "./types"

interface KernelApi {
  definePlugin(def: PluginDefinition): void
  hostCall(method: string, params: unknown): Promise<unknown>
  log(message: string): void
}

function kernel(): KernelApi {
  const k = (globalThis as Record<string, unknown>).__polo as KernelApi | undefined
  if (!k) throw new Error('polo kernel not loaded; kernel.js must be evaluated before plugin bundles')
  return k
}

export function definePlugin(def: PluginDefinition): void {
  kernel().definePlugin(def)
}

export const host = {
  async fetch(url: string, options?: FetchOptions): Promise<FetchResponse> {
    return (await kernel().hostCall('fetch', { url, ...options })) as FetchResponse
  },

  async kvGet(key: string): Promise<JSONValue | null> {
    return (await kernel().hostCall('kvGet', { key })) as JSONValue | null
  },

  async kvSet(key: string, value: JSONValue): Promise<void> {
    await kernel().hostCall('kvSet', { key, value })
  },

  log(message: string): void {
    kernel().log(message)
  },
}

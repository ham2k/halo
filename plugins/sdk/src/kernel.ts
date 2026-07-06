// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The plugin runtime kernel. This bundle is evaluated FIRST, before any
// plugin bundle. It owns all shared state (registry, pending host calls) as a
// singleton on globalThis.__polo. Plugin bundles talk to it through the thin
// wrappers in `index.ts`.
//
// Activation is lazy: definePlugin only registers the definition; the host
// calls activateAll() after every bundle has been evaluated. This removes
// the declaration-order footgun spike 01 found (esbuild IIFE output hoists
// late declarations as undefined vars).
//
// Bridge protocol (all payloads are JSON strings over the 'polo' channel):
//   JS → Dart:  {type:'result', id, ok, value|error, jsMillis}
//               {type:'hostCall', callId, method, params}
//               {type:'log', message}
//   Dart → JS:  __polo.invokeHook(id, category, key|null, method, argsJson)
//               __polo.invokeHookAll(id, category, method, argsJson)
//               __polo.activateAll()
//               __polo.hostResponse(callId, ok, resultJson)

import type { PluginDefinition, RegisterHookParams } from "./types"

declare function sendMessage(channel: string, message: string): void

interface HookRecord {
  category: string
  key: string
  priority: number
  pluginKey: string
  hook: Record<string, unknown>
}

interface PendingHostCall {
  resolve: (value: unknown) => void
  reject: (error: Error) => void
}

const plugins: Record<string, PluginDefinition> = {}
const activated = new Set<string>()
const hooks: HookRecord[] = []
const pendingHostCalls = new Map<number, PendingHostCall>()
let nextHostCallId = 1

function post(message: Record<string, unknown>) {
  sendMessage('polo', JSON.stringify(message))
}

function log(message: string) {
  post({ type: 'log', message })
}

function describeError(e: unknown): string {
  // JavaScriptCore stacks don't include the message; report both.
  const err = e as Error
  return err?.message ? `${err.message}\n${err.stack ?? ''}`.trim() : String(e)
}

function hooksFor(category: string, key: string | null): HookRecord[] {
  return hooks
    .filter((h) => h.category === category && (key == null || h.key === key))
    .sort((a, b) => b.priority - a.priority)
}

function hostCall(method: string, params: Record<string, unknown>): Promise<unknown> {
  const callId = nextHostCallId++
  return new Promise((resolve, reject) => {
    pendingHostCalls.set(callId, { resolve, reject })
    post({ type: 'hostCall', callId, method, params })
  })
}

async function callHookMethod(record: HookRecord, method: string, args: unknown): Promise<unknown> {
  const fn = record.hook[method]
  if (typeof fn !== 'function') {
    throw new Error(`hook ${record.category}/${record.key} has no method ${method}`)
  }
  return await fn.call(record.hook, args, { online: true })
}

function activatePlugin(def: PluginDefinition) {
  if (activated.has(def.key)) return
  activated.add(def.key)
  try {
    def.onActivation({
      registerHook(category: string, params: RegisterHookParams) {
        if (!params?.hook) {
          throw new Error(`registerHook(${category}) called with no hook in plugin ${def.key}`)
        }
        hooks.push({
          category,
          key: params.key ?? def.key,
          priority: params.priority ?? 0,
          pluginKey: def.key,
          hook: params.hook as Record<string, unknown>,
        })
      },
    })
    log(`activated plugin ${def.key}@${def.version}`)
  } catch (e) {
    log(`ERROR activating plugin ${def.key}: ${describeError(e)}`)
  }
}

const kernel = {
  definePlugin(def: PluginDefinition) {
    plugins[def.key] = def
  },

  /// Called by the host once all bundles are evaluated.
  activateAll() {
    for (const def of Object.values(plugins)) activatePlugin(def)
  },

  invokeHook(id: number, category: string, key: string | null, method: string, argsJson: string) {
    const startedAt = Date.now()
    void (async () => {
      try {
        const record = hooksFor(category, key)[0]
        if (!record) throw new Error(`no hook registered for ${category}/${key ?? '*'}`)
        const result = await callHookMethod(record, method, JSON.parse(argsJson))
        post({ type: 'result', id, ok: true, value: result ?? null, jsMillis: Date.now() - startedAt })
      } catch (e) {
        post({ type: 'result', id, ok: false, error: describeError(e), jsMillis: Date.now() - startedAt })
      }
    })()
  },

  /// Invokes `method` on every hook in a category (priority order) and
  /// responds with one entry per hook: {key, ok, value|error}. Failures are
  /// per-entry so one bad source never poisons the rest.
  invokeHookAll(id: number, category: string, method: string, argsJson: string) {
    const startedAt = Date.now()
    void (async () => {
      const args = JSON.parse(argsJson)
      const records = hooksFor(category, null).filter((r) => typeof r.hook[method] === 'function')
      const entries = await Promise.all(
        records.map(async (record) => {
          try {
            return { key: record.key, ok: true, value: (await callHookMethod(record, method, args)) ?? null }
          } catch (e) {
            return { key: record.key, ok: false, error: describeError(e) }
          }
        }),
      )
      post({ type: 'result', id, ok: true, value: entries, jsMillis: Date.now() - startedAt })
    })()
  },

  /// In-runtime composition: lets one plugin invoke other plugins' hooks
  /// without crossing the bridge (e.g. the ADIF exporter collecting
  /// per-QSO fields from activity plugins). Returns settled entries in
  /// priority order; failing hooks are isolated.
  async invokeLocal(
    category: string,
    method: string,
    args: unknown,
  ): Promise<{ key: string; ok: boolean; value?: unknown; error?: string }[]> {
    const records = hooksFor(category, null).filter((r) => typeof r.hook[method] === 'function')
    return await Promise.all(
      records.map(async (record) => {
        try {
          return { key: record.key, ok: true, value: (await callHookMethod(record, method, args)) ?? null }
        } catch (e) {
          return { key: record.key, ok: false, error: describeError(e) }
        }
      }),
    )
  },

  hostResponse(callId: number, ok: boolean, resultJson: string) {
    const pending = pendingHostCalls.get(callId)
    if (!pending) return
    pendingHostCalls.delete(callId)
    try {
      const result = JSON.parse(resultJson)
      if (ok) pending.resolve(result)
      else pending.reject(new Error(String(result)))
    } catch (e) {
      pending.reject(e as Error)
    }
  },

  hostCall,
  log,

  registeredHooks(): string[] {
    return hooks.map((h) => `${h.category}/${h.key} (${h.pluginKey})`)
  },
}

;(globalThis as Record<string, unknown>).__polo = kernel

// Route console.log to the host so plugin debugging output is visible.
;(globalThis as Record<string, unknown>).console = {
  log: (...args: unknown[]) => log(args.map(String).join(' ')),
  warn: (...args: unknown[]) => log('WARN ' + args.map(String).join(' ')),
  error: (...args: unknown[]) => log('ERROR ' + args.map(String).join(' ')),
}

// Built-in bench hooks, used to measure pure bridge round-trip latency
// (echo) and JS compute throughput (spin) with no plugin code involved.
kernel.definePlugin({
  key: 'kernel-bench',
  name: 'Kernel benchmarks',
  version: '0.0.1',
  onActivation({ registerHook }) {
    registerHook('bench', {
      key: 'kernel',
      hook: {
        echo: async (args: unknown) => args,
        spin: async (args: { iterations?: number }) => {
          const n = args?.iterations ?? 1_000_000
          let acc = 0
          for (let i = 0; i < n; i++) acc = (acc + i * 31) % 1_000_003
          return { iterations: n, acc }
        },
      },
    })
  },
})

log('kernel ready')

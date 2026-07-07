// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The extension runtime kernel. This bundle is evaluated FIRST, before any
// extension bundle. It owns all shared state (registry, pending host calls) as a
// singleton on globalThis.__polo. Extension bundles talk to it through the thin
// wrappers in `index.ts`.
//
// Activation is lazy: defineExtension only registers the definition; the host
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

import type { ExtensionDefinition, RegisterHookParams } from "./types"

declare function sendMessage(channel: string, message: string): void

interface HookRecord {
  category: string
  key: string
  priority: number
  extensionKey: string
  hook: Record<string, unknown>
}

interface PendingHostCall {
  resolve: (value: unknown) => void
  reject: (error: Error) => void
}

const extensions: Record<string, ExtensionDefinition> = {}
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

async function getAccountContext(extensionKey: string): Promise<unknown> {
  const accountHookRecord = hooks.find((h) => h.category === 'account' && h.extensionKey === extensionKey)
  if (!accountHookRecord) return undefined
  const kvKey = accountHookRecord.hook.kvKey || accountHookRecord.key || extensionKey
  try {
    return (await hostCall('getAccount', { ns: extensionKey, kvKey })) as unknown
  } catch (e) {
    return undefined
  }
}

async function callHookMethod(record: HookRecord, method: string, args: unknown): Promise<unknown> {
  const member = record.hook[method]
  const account = (await getAccountContext(record.extensionKey)) as { credentials?: Record<string, string>; session?: Record<string, string> } | undefined
  const ctx = { online: true, account }
  if (typeof member === 'function') {
    return await member.call(record.hook, args, ctx)
  }
  return member
}

function activateExtension(def: ExtensionDefinition) {
  if (activated.has(def.key)) return
  activated.add(def.key)
  try {
    def.onActivation({
      registerHook(category: string, params: RegisterHookParams) {
        if (!params?.hook) {
          throw new Error(`registerHook(${category}) called with no hook in extension ${def.key}`)
        }
        hooks.push({
          category,
          key: params.key ?? def.key,
          priority: params.priority ?? 0,
          extensionKey: def.key,
          hook: params.hook as Record<string, unknown>,
        })
      },
    })
    log(`activated extension ${def.key}@${def.version}`)
  } catch (e) {
    log(`ERROR activating extension ${def.key}: ${describeError(e)}`)
  }
}

const kernel = {
  defineExtension(def: ExtensionDefinition) {
    extensions[def.key] = def
  },

  /// Called by the host once all bundles are evaluated.
  activateAll() {
    for (const def of Object.values(extensions)) activateExtension(def)
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

  invokeHookAll(id: number, category: string, method: string, argsJson: string) {
    const startedAt = Date.now()
    void (async () => {
      const args = JSON.parse(argsJson)
      if (category === 'account' && method === 'getDefinition') {
        const records = hooksFor('account', null)
        const entries = records.map((record) => {
          return {
            key: record.key,
            ok: true,
            value: {
              key: record.key,
              extensionKey: record.extensionKey,
              label: record.hook.label ?? record.key,
              kvKey: record.hook.kvKey ?? record.key ?? record.extensionKey,
              fields: record.hook.fields ?? [],
              oauth2: record.hook.oauth2 ?? null,
            }
          }
        })
        post({ type: 'result', id, ok: true, value: entries, jsMillis: Date.now() - startedAt })
        return
      }
      const records = hooksFor(category, null).filter((r) => typeof r.hook[method] === 'function' || r.hook[method] !== undefined)
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

  /// In-runtime composition: lets one extension invoke other extensions' hooks
  /// without crossing the bridge (e.g. the ADIF exporter collecting
  /// per-QSO fields from activity extensions). Returns settled entries in
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
    return hooks.map((h) => `${h.category}/${h.key} (${h.extensionKey})`)
  },

  getAccountKvKey(extensionKey: string): string {
    const accountHookRecord = hooks.find((h) => h.category === 'account' && h.extensionKey === extensionKey)
    return (accountHookRecord?.hook?.kvKey as string | undefined) || accountHookRecord?.key || extensionKey
  },
}

;(globalThis as Record<string, unknown>).__polo = kernel

// Route console.log to the host so extension debugging output is visible.
;(globalThis as Record<string, unknown>).console = {
  log: (...args: unknown[]) => log(args.map(String).join(' ')),
  warn: (...args: unknown[]) => log('WARN ' + args.map(String).join(' ')),
  error: (...args: unknown[]) => log('ERROR ' + args.map(String).join(' ')),
}

// Built-in bench hooks, used to measure pure bridge round-trip latency
// (echo) and JS compute throughput (spin) with no extension code involved.
kernel.defineExtension({
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

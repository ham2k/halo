// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The plugin runtime kernel. This bundle is evaluated FIRST, before any
// plugin bundle. It owns all shared state (registry, pending host calls) as a
// singleton on globalThis.__polo. Plugin bundles talk to it through the thin
// wrappers in `index.ts`.
//
// Bridge protocol (all payloads are JSON strings over the 'polo' channel):
//   JS → Dart:  {type:'result', id, ok, value|error, jsMillis}
//               {type:'hostCall', callId, method, params}
//               {type:'log', message}
//   Dart → JS:  __polo.invokeHook(id, category, key|null, method, argsJson)
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
const hooks: HookRecord[] = []
const pendingHostCalls = new Map<number, PendingHostCall>()
let nextHostCallId = 1

function post(message: Record<string, unknown>) {
  sendMessage('polo', JSON.stringify(message))
}

function log(message: string) {
  post({ type: 'log', message })
}

function findHook(category: string, key: string | null): HookRecord | undefined {
  const matches = hooks
    .filter((h) => h.category === category && (key == null || h.key === key))
    .sort((a, b) => b.priority - a.priority)
  return matches[0]
}

function hostCall(method: string, params: unknown): Promise<unknown> {
  const callId = nextHostCallId++
  return new Promise((resolve, reject) => {
    pendingHostCalls.set(callId, { resolve, reject })
    post({ type: 'hostCall', callId, method, params })
  })
}

const kernel = {
  definePlugin(def: PluginDefinition) {
    plugins[def.key] = def
    try {
      def.onActivation({
        registerHook(category: string, params: RegisterHookParams) {
          if (!params?.hook) {
            throw new Error(`registerHook(${category}) called with no hook — check declaration order in plugin ${def.key}`)
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
      log(`ERROR activating plugin ${def.key}: ${e}`)
    }
  },

  invokeHook(id: number, category: string, key: string | null, method: string, argsJson: string) {
    const startedAt = Date.now()
    const respond = (ok: boolean, payload: unknown) => {
      post({
        type: 'result',
        id,
        ok,
        ...(ok ? { value: payload ?? null } : { error: String(payload) }),
        jsMillis: Date.now() - startedAt,
      })
    }

    void (async () => {
      try {
        const record = findHook(category, key)
        if (!record) throw new Error(`no hook registered for ${category}/${key ?? '*'}`)
        const fn = record.hook[method]
        if (typeof fn !== 'function') {
          throw new Error(`hook ${category}/${record.key} has no method ${method}`)
        }
        const args = JSON.parse(argsJson)
        const result = await fn.call(record.hook, args, { online: true })
        respond(true, result)
      } catch (e) {
        // JavaScriptCore stacks don't include the message; report both.
        const err = e as Error
        respond(false, err?.message ? `${err.message}\n${err.stack ?? ''}`.trim() : String(e))
      }
    })()
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

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

import type { ExtensionDefinition, RegisterHookParams, FormDefinition, FormField } from "./types"

import * as libCallsigns from "@ham2k/lib-callsigns"
import * as libCountryFiles from "@ham2k/lib-country-files"
import * as libCqmagData from "@ham2k/lib-cqmag-data"
import * as libDxccData from "@ham2k/lib-dxcc-data"
import * as libFormatTools from "@ham2k/lib-format-tools"
import * as libGeoTools from "@ham2k/lib-geo-tools"
import * as libOperationData from "@ham2k/lib-operation-data"
import * as libQsonAdif from "@ham2k/lib-qson-adif"
import * as libQsonCabrillo from "@ham2k/lib-qson-cabrillo"
import * as libQsonTools from "@ham2k/lib-qson-tools"
import i18next from "i18next"

declare const __SHARED_VERSIONS__: Record<string, string>

const sharedModules: Record<string, any> = {
  "@ham2k/lib-callsigns": libCallsigns,
  "@ham2k/lib-country-files": libCountryFiles,
  "@ham2k/lib-cqmag-data": libCqmagData,
  "@ham2k/lib-dxcc-data": libDxccData,
  "@ham2k/lib-format-tools": libFormatTools,
  "@ham2k/lib-geo-tools": libGeoTools,
  "@ham2k/lib-operation-data": libOperationData,
  "@ham2k/lib-qson-adif": libQsonAdif,
  "@ham2k/lib-qson-cabrillo": libQsonCabrillo,
  "@ham2k/lib-qson-tools": libQsonTools,
  "i18next": i18next,
}

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

async function callHookMethod(record: HookRecord, method: string, args: unknown, online = true): Promise<unknown> {
  const member = record.hook[method]
  const account = (await getAccountContext(record.extensionKey)) as { credentials?: Record<string, string>; session?: Record<string, string> } | undefined
  let developerMode = false
  let locale = 'en'
  try {
    const settings = (await hostCall('getSettings', {})) as { developerMode?: boolean; locale?: string } | undefined
    if (settings?.developerMode) {
      developerMode = true
    }
    if (settings?.locale) {
      locale = settings.locale
    }
  } catch (e) {
    // ignore
  }
  const ctx = { online, account, developerMode, locale }
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
        const hookObj = params.hook as Record<string, unknown>
        if (category === 'dataFile') {
          if (typeof hookObj.csvToLookupEntry === 'function' && typeof hookObj.mapCsvBatch !== 'function') {
            hookObj.mapCsvBatch = async (args: { rows: unknown[][] }) => {
              const mapper = hookObj.csvToLookupEntry as (row: unknown) => unknown
              return args.rows.map(row => mapper(row)).filter(x => x !== null && x !== undefined)
            }
          }
          if (typeof hookObj.jsonToLookupEntry === 'function' && typeof hookObj.mapJsonBatch !== 'function') {
            hookObj.mapJsonBatch = async (args: { entries: unknown[] }) => {
              const mapper = hookObj.jsonToLookupEntry as (entry: unknown) => unknown
              return args.entries.map(entry => mapper(entry)).filter(x => x !== null && x !== undefined)
            }
          }
        }
        hooks.push({
          category,
          key: params.key ?? def.key,
          priority: params.priority ?? 0,
          extensionKey: def.key,
          hook: hookObj,
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
        const args = JSON.parse(argsJson)
        const online = typeof args?.online === 'boolean' ? args.online : true
        const result = await callHookMethod(record, method, args, online)
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
      if (category === 'dataFile' && method === 'getDefinition') {
        const records = hooksFor('dataFile', null)
        const entries = records.map((record) => {
          return {
            key: record.key,
            ok: true,
            value: {
              key: record.key,
              extensionKey: record.extensionKey,
              extensionName: extensions[record.extensionKey]?.name,
              name: record.hook.name,
              description: record.hook.description,
              url: record.hook.url,
              maxAgeInDays: record.hook.maxAgeInDays,
              fetchType: record.hook.fetchType,
              category: record.hook.category,
              csvOptions: record.hook.csvOptions ?? null,
              jsonOptions: record.hook.jsonOptions ?? null,
            }
          }
        })
        post({ type: 'result', id, ok: true, value: entries, jsMillis: Date.now() - startedAt })
        return
      }
      const online = typeof args?.online === 'boolean' ? args.online : true
      const records = hooksFor(category, null).filter((r) => typeof r.hook[method] === 'function' || r.hook[method] !== undefined)
      const entries = await Promise.all(
        records.map(async (record) => {
          try {
            return { key: record.key, ok: true, value: (await callHookMethod(record, method, args, online)) ?? null }
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
    online = true,
  ): Promise<{ key: string; ok: boolean; value?: unknown; error?: string }[]> {
    const records = hooksFor(category, null).filter((r) => typeof r.hook[method] === 'function')
    return await Promise.all(
      records.map(async (record) => {
        try {
          return { key: record.key, ok: true, value: (await callHookMethod(record, method, args, online)) ?? null }
        } catch (e) {
          return { key: record.key, ok: false, error: describeError(e) }
        }
      }),
    )
  },

  /// Like `invokeLocal`, but calls each matching hook one at a time, in
  /// priority order, threading its result through `fold` to produce the
  /// args for the next hook — needed when later hooks must see earlier
  /// hooks' contributions (e.g. the lookup service's priority-ordered
  /// merge), unlike `invokeLocal`'s parallel fan-out.
  async invokeLocalSequential(
    category: string,
    method: string,
    initialArgs: unknown,
    fold: (args: unknown, hookResult: unknown, hookKey: string) => unknown,
    online = true,
  ): Promise<{ key: string; ok: boolean; value?: unknown; error?: string }[]> {
    const records = hooksFor(category, null).filter((r) => typeof r.hook[method] === 'function')
    let args = initialArgs
    const out: { key: string; ok: boolean; value?: unknown; error?: string }[] = []
    for (const record of records) {
      try {
        const value = (await callHookMethod(record, method, args, online)) ?? null
        args = fold(args, value, record.key)
        out.push({ key: record.key, ok: true, value })
      } catch (e) {
        out.push({ key: record.key, ok: false, error: describeError(e) })
      }
    }
    return out
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

  registerDynamicForm(formId: string, extensionKey: string, hookObj: Record<string, unknown>) {
    hooks.push({
      category: 'form',
      key: formId,
      priority: 0,
      extensionKey,
      hook: hookObj,
    })
  },

  unregisterDynamicForm(formId: string) {
    const idx = hooks.findIndex((h) => h.category === 'form' && h.key === formId)
    if (idx !== -1) {
      hooks.splice(idx, 1)
    }
  },

  host: {
    async showForm(form: FormDefinition, state: Record<string, any> = {}, extensionKey: string = 'kernel'): Promise<Record<string, any> | null> {
      const formId = `dynamic:${Math.random().toString(36).substring(2, 10)}`
      
      const cleanElements = form.elements.map(el => {
        if (el.type === 'field') {
          const { validate, transform, ...rest } = el
          return rest
        }
        return el
      })
      const cleanForm = { ...form, elements: cleanElements }

      kernel.registerDynamicForm(formId, extensionKey, {
        getDefinition: async () => cleanForm,
        validateField: async (args: { fieldKey: string; value: any; state: Record<string, any> }) => {
          const field = form.elements.find(el => el.type === 'field' && (el as FormField).key === args.fieldKey) as FormField | undefined
          if (field?.validate) {
            return (await field.validate(args.value, args.state)) ?? null
          }
          return null
        },
        transformField: async (args: { fieldKey: string; value: any; state: Record<string, any> }) => {
          const field = form.elements.find(el => el.type === 'field' && (el as FormField).key === args.fieldKey) as FormField | undefined
          if (field?.transform) {
            return await field.transform(args.value, args.state)
          }
          return args.value
        },
        onChangeField: async (args: { fieldKey: string; value: any; state: Record<string, any> }) => {
          if (form.onChange) {
            return (await form.onChange(args.fieldKey, args.value, args.state)) ?? null
          }
          return null
        }
      })

      try {
        const result = await hostCall('showForm', { formId, form: cleanForm, state })
        return result as Record<string, any> | null
      } finally {
        kernel.unregisterDynamicForm(formId)
      }
    }
  },

  sharedModules,
  sharedVersions: typeof __SHARED_VERSIONS__ !== 'undefined' ? __SHARED_VERSIONS__ : {},
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

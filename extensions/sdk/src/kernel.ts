// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The extension runtime kernel. This bundle is evaluated FIRST, before any
// extension bundle. It owns all shared state (registry, pending host calls) as a
// singleton on globalThis.__polo. Extension bundles talk to it through the thin
// wrappers in `index.ts`.
//
// Activation is lazy: defineExtension only registers the definition; the host
// calls activateAll() after every bundle has been evaluated. This removes
// a declaration-order footgun (esbuild IIFE output hoists late declarations
// as undefined vars).
//
// Bridge protocol (all payloads are JSON strings over the 'polo' channel):
//   JS → Dart:  {type:'result', id, ok, value|error, jsMillis}
//               {type:'partial', id, keys|entry}  — only when wantsPartials
//               {type:'hostCall', callId, method, params}
//               {type:'log', message}
//               {type:'updateInterpretation', input, interpretation}
//   Dart → JS:  __polo.invokeHook(id, category, key|null, method, argsJson)
//               __polo.invokeHookAll(id, category, method, argsJson, wantsPartials)
//               __polo.activateAll()
//               __polo.hostResponse(callId, ok, resultJson)

// FIRST: patches Number.prototype.toLocaleString on engines without Intl
// (QuickJS-NG). Imported ahead of everything else so the patch is in place
// before any module that formats a number is evaluated.
import { installNumberFormatPolyfill } from "./number-format.ts"
installNumberFormatPolyfill()

import type { ExtensionDefinition, RegisterHookParams, FormDefinition, FormField, SettingsPanelDescriptor, Spot, HistoryForCallOptions } from "./types.ts"
import { isValidHookKey, tier1FormDefinition, settingsPanelEntriesFor } from "./settingsPanels.ts"
import { installAppClock } from "./appClock.ts"

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
import * as liquidjs from "liquidjs"

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
  // The template engine every extension reaches through sdk/src/templates.ts
  // — one copy here rather than 80 KB in each bundle that renders text.
  "liquidjs": liquidjs,
}

declare function sendMessage(channel: string, message: string): void

// ---- Raw channel capture -------------------------------------------------
// The engine exposes a global `sendMessage(channel, message)` — the raw wire
// to Dart. Left public, any extension bundle could forge protocol messages
// (fake results hijacking other hooks' responses, host calls with arbitrary
// identity). The kernel evaluates before every bundle, so it captures the
// function into module scope and removes the global: from here on, the only
// way onto the wire is through kernel APIs, which enforce identity.
// (This is soft, single-realm containment — a hostile bundle can still
// tamper with shared globals like __polo itself. Hard isolation needs
// per-extension realms; see DESIGN.md §3's manifest/review story.)
const rawSendMessage: typeof sendMessage =
  typeof sendMessage === 'function' ? sendMessage : (globalThis as Record<string, any>).sendMessage
try {
  delete (globalThis as Record<string, unknown>).sendMessage
} catch (e) {
  // non-configurable — fall through to shadowing below
}
if (typeof (globalThis as Record<string, unknown>).sendMessage === 'function') {
  try {
    ;(globalThis as Record<string, unknown>).sendMessage = () => {
      throw new Error('the raw message channel is kernel-private')
    }
  } catch (e) {
    // both delete and assignment blocked: nothing more we can do here
  }
}

// ---------------------------------------------------------------------------
// The app clock inside the sandbox (docs/design/time.md §6)
//
// appClock.ts replaces `globalThis.Date` so every extension's Date.now() and
// new Date() follow the app's clock without knowing this happened. Installed
// here, before any bundle evaluates, same as the raw message channel above.
//
// `realNow` is the clock captured BEFORE that swap, and the kernel's own
// timings and cache TTLs use it deliberately: they measure real elapsed work,
// and a speed factor would silently scale them.
const { realNow, setClockTravel } = installAppClock()

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
// Which BUNDLE defined each extension key — the provenance `unloadBundle`
// needs, since one bundle may define several extensions (`bundleMayDefine`
// lets 'pota' define 'pota-all-parks') and unloading has to take all of them.
// Null for the kernel's own definitions, made outside any bundle window:
// nothing can unload those, which is the intent.
const definingBundle: Record<string, string | null> = {}
const pendingHostCalls = new Map<number, PendingHostCall>()
let nextHostCallId = 1

// ---- Bundle evaluation windows --------------------------------------------
// The host brackets every bundle's evaluation with beginBundle(key)/
// endBundle(), where `key` comes from the host's own manifest (index.json) —
// so an extension's identity is host-declared, not self-declared. Inside a
// window, defineExtension only accepts the bundle's key or a key it prefixes
// ('pota' also defines 'pota-all-parks'); outside any window (once bundles
// have started), definitions are refused so a hook can't mint a new identity
// at invocation time.
let currentBundleKey: string | null = null
let bundlesStarted = false

function bundleMayDefine(bundleKey: string, extensionKey: string): boolean {
  return (
    extensionKey === bundleKey ||
    extensionKey.startsWith(`${bundleKey}-`) ||
    extensionKey.startsWith(`${bundleKey}_`)
  )
}

function post(message: Record<string, unknown>) {
  rawSendMessage('polo', JSON.stringify(message))
}

function log(message: string) {
  post({ type: 'log', message })
}

// A `command` hook's interpret() can call this any time after it starts —
// including after its own returned Promise already resolved — to push a
// later CommandInterpretation for the same `input` (e.g. once a background
// fetch SOLAR/WEATHER kicked off resolves). One-way, like `log`: no
// response ever comes back over the wire. `input` lets the app discard a
// stale push if the user has since typed something else, the same way it
// already discards a stale describe-preview result.
function updateInterpretation(input: string, interpretation: Record<string, unknown>) {
  post({ type: 'updateInterpretation', input, interpretation })
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

/// The records that answer a call for [category], most precise first.
///
/// Identical to `hooksFor` for every category but `ref:<type>`. A call for one
/// of those also reaches the records registered as `ref:<type>/<prefix>` whose
/// prefix begins the REFERENCE's own code, which is how the New York QSO Party
/// answers `{type: 'qp', ref: 'NY'}` — an operation logged when fifty parties
/// were one extension, which nothing rewrites.
///
/// The longest prefix wins: a record registered under the bare type claims the
/// whole family at zero, so the party that named the reference beats the
/// bundled extension that merely contained it, and neither has to know the
/// other exists. Priority breaks a tie, as it always did.
///
/// The code comes off `args.ref`, which every `ref:` method is called with. A
/// call carrying no readable code matches the bare type alone — a prefix has
/// nothing to begin.
function hooksForRef(category: string, key: string | null, args: unknown): HookRecord[] {
  if (!category.startsWith('ref:') || category.includes('/')) return hooksFor(category, key)
  const raw = (args as { ref?: { ref?: unknown } } | null)?.ref?.ref
  const code = typeof raw === 'string' ? raw.toLowerCase() : null
  const qualified = `${category}/`
  const ranked: { record: HookRecord; strength: number }[] = []
  for (const h of hooks) {
    if (key != null && h.key !== key) continue
    if (h.category === category) {
      ranked.push({ record: h, strength: 0 })
      continue
    }
    if (!h.category.startsWith(qualified)) continue
    const claimed = h.category.slice(qualified.length).toLowerCase()
    if (!claimed || code === null || !code.startsWith(claimed)) continue
    ranked.push({ record: h, strength: claimed.length })
  }
  ranked.sort((a, b) => b.strength - a.strength || b.record.priority - a.record.priority)
  return ranked.map((entry) => entry.record)
}

// Host calls that carry (or act on) a caller identity: their `ns`/`kvKey`/
// `extensionKey` params must be derived by the kernel from which extension
// is calling — never supplied by extension code, or any bundle could read
// any other's keychain credentials, KV state, or clear its status items.
const IDENTITY_HOST_METHODS = new Set([
  'fetch',
  'getLocation',
  'listRadios',
  'readRadio',
  'setRadioConnection',
  'tuneRadio',
  'secret',
  'kvGet',
  'kvSet',
  'getAccount',
  'setAccountSession',
  'showMessage',
  'statusBarSetMessage',
  'statusBarSetProgress',
  'statusBarClear',
  'statusBarShowNotice',
  'statusBarDismissNotice',
])

/// Internal, trusted dispatch — everything on the wire goes through here.
function dispatchHostCall(method: string, params: Record<string, unknown>): Promise<unknown> {
  // An extension writing its own session must see it on its very next hook
  // call, not after the context cache's TTL (see getAccountContext).
  if (method === 'setAccountSession' && typeof params.ns === 'string') {
    cachedAccounts.delete(params.ns)
  }
  const callId = nextHostCallId++
  return new Promise((resolve, reject) => {
    pendingHostCalls.set(callId, { resolve, reject })
    post({ type: 'hostCall', callId, method, params })
  })
}

/// The public (`__polo.hostCall`) surface: identity-bearing methods are
/// refused — extensions reach those through the activation-scoped
/// `api.hostCall` their SDK copy captures (see activateExtension), whose
/// identity params the kernel injects itself.
function hostCall(method: string, params: Record<string, unknown>): Promise<unknown> {
  if (IDENTITY_HOST_METHODS.has(method)) {
    return Promise.reject(
      new Error(`host call '${method}' carries extension identity and is only available through the SDK host API`),
    )
  }
  return dispatchHostCall(method, params)
}

/// The privileged host-call function handed to one extension at activation:
/// identity params are forced to the kernel's own record of who this is.
function boundHostCallFor(extensionKey: string) {
  return (method: string, params: Record<string, unknown>): Promise<unknown> => {
    if (!IDENTITY_HOST_METHODS.has(method)) return dispatchHostCall(method, params)
    const bound: Record<string, unknown> = { ...params, ns: extensionKey, extensionKey }
    if (method === 'getAccount' || method === 'setAccountSession') {
      bound.kvKey = kernel.getAccountKvKey(extensionKey)
    }
    return dispatchHostCall(method, bound)
  }
}

// Hook-context caching: without it, settings and account credentials get
// re-fetched over the bridge before EVERY hook method call — 1-2 extra
// round trips (the account one hitting the platform keychain) multiplied
// by N hooks in every invokeHookAll fan-out, on paths as hot as the
// debounced per-keystroke lookup. Both change rarely; a short TTL bounds
// staleness and the host can force-invalidate (__polo.invalidateContext)
// when it writes settings or credentials.
const CONTEXT_CACHE_TTL_MILLIS = 3000
// The cache holds the in-flight PROMISE, not the resolved value: an
// invokeHookAll fan-out calls N hooks concurrently, and value-caching would
// let every one of them miss before the first fetch resolves.
let cachedSettings: { value: Promise<unknown>; at: number } | null = null
const cachedAccounts = new Map<string, { value: Promise<unknown>; at: number }>()

function invalidateContext() {
  cachedSettings = null
  cachedAccounts.clear()
}

function getSettingsContext(): Promise<unknown> {
  if (cachedSettings && realNow() - cachedSettings.at < CONTEXT_CACHE_TTL_MILLIS) return cachedSettings.value
  const value = (async () => {
    try {
      return await dispatchHostCall('getSettings', {})
    } catch (e) {
      return undefined
    }
  })()
  cachedSettings = { value, at: realNow() }
  return value
}

function getAccountContext(extensionKey: string): Promise<unknown> {
  const accountHookRecord = hooks.find((h) => h.category === 'account' && h.extensionKey === extensionKey)
  if (!accountHookRecord) return Promise.resolve(undefined)
  const cached = cachedAccounts.get(extensionKey)
  if (cached && realNow() - cached.at < CONTEXT_CACHE_TTL_MILLIS) return cached.value
  const kvKey = accountHookRecord.hook.kvKey || accountHookRecord.key || extensionKey
  const value = (async () => {
    try {
      // Trusted kernel path (this is the kernel deriving identity itself,
      // not extension code claiming one) — bypasses the public gate.
      return (await dispatchHostCall('getAccount', { ns: extensionKey, kvKey })) as unknown
    } catch (e) {
      return undefined
    }
  })()
  cachedAccounts.set(extensionKey, { value, at: realNow() })
  return value
}

async function callHookMethod(record: HookRecord, method: string, args: unknown, online = true): Promise<unknown> {
  const member = record.hook[method]
  // Plain data members don't get a ctx — skip the context fetches entirely.
  if (typeof member !== 'function') return member
  const account = (await getAccountContext(record.extensionKey)) as { credentials?: Record<string, string>; session?: Record<string, string> } | undefined
  let developerMode = false
  let locale = 'en'
  const settings = (await getSettingsContext()) as
    | {
        developerMode?: boolean
        locale?: string
        appName?: string
        distanceUnits?: string
        gridPrecision?: number
        edition?: string
        enabledExperiments?: string[]
        experiments?: { key: string; name: string; aliases: string[] }[]
      }
    | undefined
  if (settings?.developerMode) {
    developerMode = true
  }
  if (settings?.locale) {
    locale = settings.locale
  }
  const ctx = {
    online,
    account,
    developerMode,
    locale,
    appName: settings?.appName,
    distanceUnits: settings?.distanceUnits ?? 'kilometers',
    gridPrecision: settings?.gridPrecision ?? 6,
    edition: settings?.edition,
    enabledExperiments: settings?.enabledExperiments ?? [],
    experiments: settings?.experiments ?? [],
    // Log-data reads (HookContext.getOperation/getQsos in types.ts). Built
    // per call like the rest of ctx but deliberately NOT cached like
    // settings/account above — log data changes with every QSO, and a
    // 3s-stale QSO list is exactly what a caller like SEED can't tolerate.
    // Not identity-bearing (no ns/kvKey), so plain dispatchHostCall is fine.
    getOperation: async (uuid: string) =>
      ((await dispatchHostCall('getOperation', { uuid })) as Record<string, unknown> | null) ?? null,
    // Null (unknown operation / no log access) passes through untouched —
    // it means something different from [] (see HookContext.getQsos).
    getQsos: async (operationUuid: string) =>
      (await dispatchHostCall('getQsos', { operationUuid })) as Record<string, unknown>[] | null,
    // Reads the host's already-fetched spot cache; never triggers a fetch,
    // so it is cheap enough for the per-keystroke lookup pipeline (see
    // HookContext.getSpotsForCall).
    getSpotsForCall: async (call: string, maxAgeMinutes?: number) =>
      ((await dispatchHostCall('getSpotsForCall', { call, maxAgeMinutes })) as Spot[] | null) ?? [],
    // Cross-operation log read, backing `call-history` — see
    // HookContext.getHistoryForCall.
    getHistoryForCall: async (call: string, options?: HistoryForCallOptions) =>
      ((await dispatchHostCall('getHistoryForCall', { ...options, call })) as Record<string, unknown>[] | null) ?? [],
  }
  return await member.call(record.hook, args, ctx)
}

/// Activates one extension, returning once its onActivation call (and
/// whatever it awaits, e.g. `host.getSettings()` before registering some of
/// its hooks) has actually settled — not just been kicked off. `activateAll`
/// awaits every extension's promise before telling the host activation is
/// complete: without that, an extension whose hook registration depends on
/// an internal await isn't guaranteed to have finished by the time the host
/// considers the runtime started.
async function activateExtension(def: ExtensionDefinition): Promise<string | null> {
  if (activated.has(def.key)) return null
  activated.add(def.key)
  try {
    await def.onActivation({
      // Activation is the identity hand-off: this function closes over the
      // extension's kernel-recorded key, and the SDK copy inside the bundle
      // captures it in module scope — unreachable from other bundles.
      hostCall: boundHostCallFor(def.key),
      registerHook(category: string, params: RegisterHookParams) {
        if (!params?.hook) {
          throw new Error(`registerHook(${category}) called with no hook in extension ${def.key}`)
        }
        const hookObj = params.hook as Record<string, unknown>
        if (category === 'dataFile') {
          if (typeof hookObj.csvToLookupEntry === 'function' && typeof hookObj.mapCsvBatch !== 'function') {
            // `headers` arrives once per chunk rather than once per row: the
            // host sends positional rows and the zip happens here, because
            // repeating every column name in the JSON for every row was 61% of
            // the bytes crossing the boundary on SOTA's 181k-row file.
            // Without headers (a `hasHeaders: false` file) the row is passed
            // through positionally, which is the other half of the declared
            // `string[] | Record<string, string>` mapper signature.
            hookObj.mapCsvBatch = async (args: { rows: unknown[][]; headers?: string[] }) => {
              const mapper = hookObj.csvToLookupEntry as (row: unknown) => unknown
              const headers = args.headers
              if (!headers) {
                return args.rows.map(row => mapper(row)).filter(x => x !== null && x !== undefined)
              }
              const out: unknown[] = []
              for (const row of args.rows) {
                const cells = row as string[]
                // Short rows leave the trailing keys ABSENT rather than
                // undefined-valued — mappers test `!r.SummitCode`, and a ragged
                // CSV line must behave the same as it did when the host built
                // this object.
                const limit = headers.length < cells.length ? headers.length : cells.length
                // Null-prototype so a column NAME out of a third-party file is
                // only ever data. On a plain `{}`, `obj['__proto__'] = str`
                // hits Object.prototype's setter and is silently discarded —
                // where the host's Dart map round-tripped through JSON.parse
                // would have made it a readable own property.
                const obj: Record<string, string> = Object.create(null)
                for (let j = 0; j < limit; j++) obj[headers[j]] = cells[j]
                const mapped = mapper(obj)
                if (mapped !== null && mapped !== undefined) out.push(mapped)
              }
              return out
            }
          }
          if (typeof hookObj.jsonToLookupEntry === 'function' && typeof hookObj.mapJsonBatch !== 'function') {
            hookObj.mapJsonBatch = async (args: { entries: unknown[] }) => {
              const mapper = hookObj.jsonToLookupEntry as (entry: unknown) => unknown
              return args.entries.map(entry => mapper(entry)).filter(x => x !== null && x !== undefined)
            }
          }
        }
        const resolvedKey = params.key ?? def.key
        // Key namespacing (docs/extensions/settings.md; rule itself lives
        // in settingsPanels.ts so it has its own unit tests). Logged and
        // skipped rather than thrown: one bad key shouldn't take down the
        // rest of the extension's hook registrations.
        if (!isValidHookKey(category, def.key, resolvedKey)) {
          log(
            `ERROR registerHook(${category}) in extension ${def.key}: key '${resolvedKey}' must equal '${def.key}' or be prefixed '${def.key}_' — hook not registered`,
          )
          return
        }
        hooks.push({
          category,
          key: resolvedKey,
          priority: params.priority ?? 0,
          extensionKey: def.key,
          hook: hookObj,
        })
      },
    })
    log(`activated extension ${def.key}@${def.version}`)
    return null
  } catch (e) {
    const message = describeError(e)
    log(`ERROR activating extension ${def.key}: ${message}`)
    // Returned as well as logged: boot tolerates a failed activation (one
    // extension must not take the runtime down), but a dev-loop reload has to
    // be able to SAY the save failed rather than reporting a reload that
    // registered nothing as a success.
    return `${def.key}: ${message}`
  }
}

/// Activates every extension not yet activated, settling only once each
/// onActivation has. `activateExtension` no-ops on anything already marked, so
/// this is equally the boot's "activate all" and a reload's "activate what the
/// new bundle just defined".
function activatePending(): Promise<Array<string | null>> {
  return Promise.all(Object.values(extensions).map(activateExtension))
}

const kernel = {
  defineExtension(def: ExtensionDefinition) {
    if (bundlesStarted && currentBundleKey == null) {
      log(`ERROR defineExtension('${def.key}') outside a bundle evaluation window — ignored`)
      return
    }
    if (currentBundleKey != null && !bundleMayDefine(currentBundleKey, def.key)) {
      log(`ERROR bundle '${currentBundleKey}' tried to define extension '${def.key}' — keys must match the host manifest; ignored`)
      return
    }
    if (extensions[def.key]) {
      log(`ERROR duplicate extension key '${def.key}' — ignored`)
      return
    }
    extensions[def.key] = def
    definingBundle[def.key] = currentBundleKey
  },

  /// Host-only bracketing of bundle evaluation — see the block comment on
  /// currentBundleKey above.
  beginBundle(key: string) {
    bundlesStarted = true
    currentBundleKey = key
  },

  endBundle() {
    currentBundleKey = null
  },

  /// Called by the host once all bundles are evaluated. Deliberately NOT
  /// awaited by the caller (`load()`/`init()` on the Dart side) — the host's
  /// own message-receive loop isn't running until `load()` returns, so
  /// blocking here on an onActivation call that awaits a host round trip
  /// (e.g. call-notes' `getSettings()`) would deadlock. Instead this runs the
  /// activations, awaits them all, and posts a one-shot `activationComplete`
  /// message once they've genuinely settled — picked up later by the
  /// already-running receive loop, same as any other message (HALO-53
  /// review).
  activateAll() {
    void (async () => {
      try {
        await activatePending()
      } finally {
        post({ type: 'activationComplete' })
      }
    })()
  },

  /// Removes everything one bundle contributed: every extension it defined,
  /// each one's hooks (dynamic forms included — `registerDynamicForm` pushes
  /// an ordinary `hooks` entry under the extension's key), and their
  /// activation marks, so a re-evaluation of the bundle activates afresh.
  ///
  /// Only the DEV loop reloads a bundle (docs/extensions/development.md); the
  /// app never unloads one at runtime. Two properties of this runtime are what
  /// make it safe to drop an extension mid-session: every bundle is its own
  /// IIFE closure, so re-evaluating gives genuinely fresh module state, and
  /// there are no timers, so an unloaded extension has no pending work left to
  /// fire. A hook call already in flight is the one loose end — its promise
  /// may still resolve, and the host settles it by call id as usual.
  ///
  /// A bundle that defined nothing (never loaded, or failed to evaluate) is
  /// not an error: reload calls this before every evaluation, including the
  /// first one after a failure.
  unloadBundle(bundleKey: string) {
    const keys = Object.keys(extensions).filter((k) => definingBundle[k] === bundleKey)
    for (const key of keys) {
      for (let i = hooks.length - 1; i >= 0; i--) {
        if (hooks[i].extensionKey === key) hooks.splice(i, 1)
      }
      delete extensions[key]
      delete definingBundle[key]
      activated.delete(key)
    }
    if (keys.length) log(`unloaded bundle ${bundleKey} (${keys.join(', ')})`)
  },

  /// Activates whatever a reloaded bundle just defined, and reports back under
  /// [token] once it has genuinely settled. Distinct from `activateAll`'s
  /// `activationComplete`, which means "the runtime finished booting" and is
  /// awaited once, by everyone — a reload must not be able to answer that.
  activateReloaded(bundleKey: string, token: number) {
    void (async () => {
      try {
        const errors = (await activatePending()).filter((e): e is string => e !== null)
        // Only THIS bundle's failures fail the reload. Another extension that
        // was already broken is not this save's fault, and reporting it here
        // would send the author looking in the wrong file.
        const mine = errors.filter((e) => {
          const key = e.slice(0, e.indexOf(':'))
          return definingBundle[key] === bundleKey || key === bundleKey
        })
        if (mine.length) post({ type: 'reloadComplete', token, ok: false, error: mine.join('\n') })
        else post({ type: 'reloadComplete', token, ok: true })
      } catch (e) {
        post({ type: 'reloadComplete', token, ok: false, error: describeError(e) })
      }
    })()
  },

  invokeHook(id: number, category: string, key: string | null, method: string, argsJson: string) {
    const startedAt = realNow()
    void (async () => {
      try {
        const args = JSON.parse(argsJson)
        // Parsed BEFORE the hook is chosen: for a `ref:` category the choice
        // depends on the reference in the args, not on the category alone.
        const record = hooksForRef(category, key, args)[0]
        if (!record) throw new Error(`no hook registered for ${category}/${key ?? '*'}`)
        // Tier 1 settings panels (kind: 'simple') are static data, not a
        // getDefinition() function — build the FormDefinition from the
        // registered object directly. Everything else (Tier 2's real
        // getDefinition/validateField/transformField/onChangeField, and any
        // action method on either tier) goes through the generic path below.
        if (category === 'settingsPanel' && method === 'getDefinition' && record.hook.kind === 'simple') {
          post({ type: 'result', id, ok: true, value: tier1FormDefinition(record.hook), jsMillis: realNow() - startedAt })
          return
        }
        const online = typeof args?.online === 'boolean' ? args.online : true
        const result = await callHookMethod(record, method, args, online)
        post({ type: 'result', id, ok: true, value: result ?? null, jsMillis: realNow() - startedAt })
      } catch (e) {
        post({ type: 'result', id, ok: false, error: describeError(e), jsMillis: realNow() - startedAt })
      }
    })()
  },

  invokeHookAll(id: number, category: string, method: string, argsJson: string, wantsPartials = false) {
    const startedAt = realNow()
    void (async () => {
      // Same whole-body containment as invokeHook: anything thrown outside
      // the per-record try/catches below (malformed argsJson, a special-case
      // branch, an unserializable aggregate failing inside post()) must
      // still produce a result message — otherwise it becomes an unhandled
      // rejection and the Dart caller burns its full timeout reporting a
      // misleading "timed out" instead of the real error.
      try {
      const args = JSON.parse(argsJson)
      if (category === 'account' && method === 'getDefinition') {
        const records = hooksFor('account', null)
        const entries = await Promise.all(records.map(async (record) => {
          try {
            // A per-edition client (e.g. SOTA's OAuth) is a function;
            // callHookMethod builds it a ctx the same way any
            // other hook method call would. A plain object needs neither.
            // Own try/catch, not just the outer one: one account's oauth2
            // throwing must not blank out every other account's entry too
            // (same per-source isolation invokeHookAll gives every caller).
            const oauth2 =
              typeof record.hook.oauth2 === 'function'
                ? await callHookMethod(record, 'oauth2', {})
                : (record.hook.oauth2 ?? null)
            return {
              key: record.key,
              ok: true,
              value: {
                key: record.key,
                extensionKey: record.extensionKey,
                // label/description/fields may each be a function of ctx
                // (same convention as oauth2 above) so extensions can
                // localize them via ctx.locale — callHookMethod returns a
                // plain member as-is, so static values cost nothing extra.
                label: (await callHookMethod(record, 'label', {})) ?? record.key,
                description: (await callHookMethod(record, 'description', {})) ?? null,
                kvKey: record.hook.kvKey ?? record.key ?? record.extensionKey,
                fields: (await callHookMethod(record, 'fields', {})) ?? [],
                oauth2,
                synchronizable: record.hook.synchronizable ?? false,
              }
            }
          } catch (e) {
            return { key: record.key, ok: false, error: describeError(e) }
          }
        }))
        post({ type: 'result', id, ok: true, value: entries, jsMillis: realNow() - startedAt })
        return
      }
      // One `settingsPanel` registration can surface more than one panel —
      // flattening/entry-shape logic lives in settingsPanelEntriesFor
      // (settingsPanels.ts) so it has its own unit tests; this handles the
      // two things that logic can't own itself: calling a Tier 2
      // registration's `getPanels()` (each an independent, potentially
      // bridge-crossing call, dispatched concurrently like every other
      // category below — not sequentially, there's no fold/ordering need
      // here), and rejecting any returned panel key that fails the same
      // namespacing rule `registerHook` already enforces on the
      // registration key itself (settingsPanelEntriesFor filters these
      // out; logging them here is what makes a dropped panel visible to
      // the extension author instead of just silently missing).
      if (category === 'settingsPanel' && method === 'getPanels') {
        const records = hooksFor('settingsPanel', null)
        const online = typeof args?.online === 'boolean' ? args.online : true
        const perRecord = await Promise.all(
          records.map(async (record) => {
            try {
              const descriptors =
                record.hook.kind === 'dynamic' && typeof record.hook.getPanels === 'function'
                  ? ((await callHookMethod(record, 'getPanels', {}, online)) as SettingsPanelDescriptor[] | null)
                  : undefined
              for (const d of descriptors ?? []) {
                if (!isValidHookKey('settingsPanel', record.extensionKey, d.key)) {
                  log(
                    `ERROR settingsPanel getPanels() in extension ${record.extensionKey}: key '${d.key}' must equal '${record.extensionKey}' or be prefixed '${record.extensionKey}_' — panel dropped`,
                  )
                }
              }
              return { ok: true as const, panels: settingsPanelEntriesFor(record, descriptors) }
            } catch (e) {
              return { ok: false as const, key: record.key, error: describeError(e) }
            }
          }),
        )
        const entries: { key: string; ok: boolean; value?: unknown; error?: string }[] = []
        for (const result of perRecord) {
          if (result.ok) {
            for (const panel of result.panels) entries.push({ key: panel.panelKey, ok: true, value: panel })
          } else {
            entries.push({ key: result.key, ok: false, error: result.error })
          }
        }
        post({ type: 'result', id, ok: true, value: entries, jsMillis: realNow() - startedAt })
        return
      }
      if (category === 'dataFile' && method === 'getDefinition') {
        const records = hooksFor('dataFile', null)
        const entries = await Promise.all(records.map(async (record) => {
          // Own try/catch per record — name/description may be functions of
          // ctx (localized, same convention as the account members above),
          // and one throwing must not blank out every other data file.
          try {
            return {
              key: record.key,
              ok: true,
              value: {
                key: record.key,
                extensionKey: record.extensionKey,
                extensionName: extensions[record.extensionKey]?.name,
                name: await callHookMethod(record, 'name', {}),
                description: await callHookMethod(record, 'description', {}),
                // Through callHookMethod like `name` and `description`, not
                // read raw: a definition whose URL depends on something the
                // extension has to ASK for — TOTA's list carries its API key as
                // a query parameter — supplies a function, and a plain string
                // still comes back unchanged.
                url: await callHookMethod(record, 'url', {}),
                maxAgeInDays: record.hook.maxAgeInDays,
                fetchType: record.hook.fetchType,
                encoding: record.hook.encoding ?? null,
                category: record.hook.category,
                csvOptions: record.hook.csvOptions ?? null,
                jsonOptions: record.hook.jsonOptions ?? null,
              }
            }
          } catch (e) {
            return { key: record.key, ok: false, error: describeError(e) }
          }
        }))
        post({ type: 'result', id, ok: true, value: entries, jsMillis: realNow() - startedAt })
        return
      }
      const online = typeof args?.online === 'boolean' ? args.online : true
      const records = hooksFor(category, null).filter((r) => typeof r.hook[method] === 'function' || r.hook[method] !== undefined)

      // Narration, for a host that means to salvage it: the roster of hooks
      // about to run, then each entry as it settles, then the final result
      // unchanged. Without it a host that gives up waiting has nothing to
      // keep — every entry is trapped in the `Promise.all` below, however
      // long ago it resolved. The roster comes first because a host seeing
      // only what arrived cannot tell a hook that went quiet from one that
      // was never going to answer.
      //
      // Off unless asked for, because it is not free: each value crosses the
      // bridge a second time, and this same path serves `command.interpret`
      // (per keystroke) and `spots.fetchSpots` (thousands of objects).
      //
      // No timer and no cancellation pair with any of this. A host that
      // stops waiting stops waiting; the hooks below run to completion
      // regardless. See `partialOnTimeout` in ExtensionHost.
      if (wantsPartials) post({ type: 'partial', id, keys: records.map((r) => r.key) })

      const entries = await Promise.all(
        records.map(async (record) => {
          let entry: { key: string; ok: boolean; value?: unknown; error?: string }
          try {
            entry = { key: record.key, ok: true, value: (await callHookMethod(record, method, args, online)) ?? null }
          } catch (e) {
            entry = { key: record.key, ok: false, error: describeError(e) }
          }
          if (wantsPartials) post({ type: 'partial', id, entry })
          return entry
        }),
      )
      post({ type: 'result', id, ok: true, value: entries, jsMillis: realNow() - startedAt })
      } catch (e) {
        post({ type: 'result', id, ok: false, error: describeError(e), jsMillis: realNow() - startedAt })
      }
    })()
  },

  /// In-runtime composition: lets one extension invoke other extensions' hooks
  /// without crossing the bridge (e.g. the ADIF exporter collecting
  /// per-QSO fields from activity extensions). Returns settled entries in
  /// priority order; failing hooks are isolated.
  /// [key] narrows the fan-out to one extension's hook. Passing null means
  /// every hook in the category — INCLUDING the caller's own, which is a
  /// recursion trap for any hook that delegates within its own category (a
  /// contest's `generateExport` asking for ADIF re-enters itself). Target the
  /// hook you actually want whenever you know its key.
  async invokeLocal(
    category: string,
    method: string,
    args: unknown,
    online = true,
    key: string | null = null,
  ): Promise<{ key: string; ok: boolean; value?: unknown; error?: string }[]> {
    const records = hooksFor(category, key).filter((r) => typeof r.hook[method] === 'function')
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

  /// Called by the host after it writes settings or account credentials, so
  /// the next hook call sees them immediately instead of after the TTL.
  invalidateContext,

  /// Points the sandbox's `Date` at the host's app clock (docs/design/time.md).
  /// The host sends its ANCHOR PAIR rather than an offset, so both sides
  /// compute the same virtual time from the same formula — an offset would be
  /// stale by however long the message took, and under a speed factor that
  /// error would keep growing. Re-sent whenever travel changes and whenever an
  /// engine boots; `anchorRealMillis: 0` means real time.
  setClockTravel,

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
  updateInterpretation,

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

// Built-in runtime introspection: the Developer panel's "Active Extensions"
// listing calls this — versions live only in each bundle's defineExtension
// manifest, so the runtime is the one place they can be read from.
kernel.defineExtension({
  key: 'kernel-info',
  name: 'Kernel info',
  version: '0.0.1',
  onActivation({ registerHook }) {
    registerHook('runtime', {
      key: 'kernel',
      hook: {
        listExtensions: async () =>
          Object.values(extensions)
            .filter((def) => activated.has(def.key))
            .map((def) => ({ key: def.key, name: def.name, version: def.version, description: def.description ?? null })),
        // What actually registered, as opposed to what a manifest's `hooks`
        // array claims. The two disagree exactly when something is wrong —
        // an activation that threw halfway, a hook whose key the namespacing
        // rule refused — which is what a caller asking this wants to see.
        // Methods are the hook object's own function-valued keys, in
        // registration order; anything else on it is configuration
        // (`sourceName`, `kvKey`, `scope`) and is not callable.
        listHooks: async () =>
          hooks.map((record) => ({
            category: record.category,
            key: record.key,
            extensionKey: record.extensionKey,
            priority: record.priority,
            methods: Object.keys(record.hook).filter((name) => typeof record.hook[name] === 'function'),
          })),
      },
    })
  },
})

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

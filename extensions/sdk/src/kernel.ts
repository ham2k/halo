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
//               {type:'socketsDropped', socketIds}
//               {type:'timerWake', delayMillis|null}
//               {type:'timersSuspended', extensionKey, reason}
//   Dart → JS:  __polo.invokeHook(id, category, key|null, method, argsJson)
//               __polo.invokeHookAll(id, category, method, argsJson, wantsPartials)
//               __polo.invokeHookBatch(id, callsJson, wantsPartials)
//               __polo.activateAll()
//               __polo.hostResponse(callId, ok, resultJson)
//               __polo.socketEvent(socketId, eventJson)
//               __polo.runTimers()
//               __polo.setAppVisible(visible)

// FIRST: patches Number.prototype.toLocaleString on engines without Intl
// (QuickJS-NG). Imported ahead of everything else so the patch is in place
// before any module that formats a number is evaluated.
import { installNumberFormatPolyfill } from "./number-format.ts"
installNumberFormatPolyfill()

import type {
  ExtensionDefinition,
  RegisterHookParams,
  FormDefinition,
  FormField,
  SettingsPanelDescriptor,
  Spot,
  HistoryForCallOptions,
  GetSpotsOptions,
  BoardSpot,
} from "./types.ts"
import { isValidHookKey, tier1FormDefinition, settingsPanelEntriesFor } from "./settingsPanels.ts"
import { installAppClock } from "./appClock.ts"
import type { HookCategoryName } from "./hookCategories.ts"
import { createTimerQueue, removeAmbientTimers } from "./timerQueue.ts"
import { createLogCopies, deepFreeze, FROZEN_QSOS_API, type LogChanges } from "./logCopy.ts"

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
  i18next: i18next,
  // The template engine every extension reaches through sdk/src/templates.ts
  // — one copy here rather than 80 KB in each bundle that renders text.
  liquidjs: liquidjs,
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
const rawSendMessage: typeof sendMessage = typeof sendMessage === "function" ? sendMessage : (globalThis as Record<string, any>).sendMessage
try {
  delete (globalThis as Record<string, unknown>).sendMessage
} catch (e) {
  // non-configurable — fall through to shadowing below
}
if (typeof (globalThis as Record<string, unknown>).sendMessage === "function") {
  try {
    ;(globalThis as Record<string, unknown>).sendMessage = () => {
      throw new Error("the raw message channel is kernel-private")
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

// ---- Timers ---------------------------------------------------------------
// The only timers in the sandbox are the ones in `timerQueue.ts`, handed to
// each extension at activation under its own identity. Removed before any
// bundle evaluates, the same way the raw message channel is.
if (!removeAmbientTimers()) log("ERROR the engine's own timers could not be removed; extensions can reach them outside any budget")

// The timer queue's clock: the engine's own monotonic one, unless the host
// stamps a time in before each evaluation. Only a test does that, to run
// extension timers on the same fake clock as the host's wake timer — with the
// two on different clocks, a wake fires on fake time and finds nothing due.
let stampedNow: number | null = null

const timerQueue = createTimerQueue({
  realNow: () => stampedNow ?? performance.now(),
  wake: (delayMillis) => post({ type: "timerWake", delayMillis }),
  log,
  describeError,
  suspended: (extensionKey, reason) => post({ type: "timersSuspended", extensionKey, reason }),
})

// What the host last said about the app's visibility. Starts visible, so an
// engine that boots while the app is hidden hears `onHide` from the host's
// first push rather than never.
let appVisible = true

// Extensions whose onActivation completed — the only ones told about
// visibility. One still activating has nothing ready to hide, and hears the
// state it was left in once it finishes; one whose activation failed hears
// nothing at all.
const live = new Set<string>()

function tellVisibility(key: string, visible: boolean) {
  const def = extensions[key]
  const method = visible ? "onShow" : "onHide"
  const handler = def?.[method]
  if (typeof handler !== "function") return
  // One extension's handler failing must not keep the others from hearing.
  const report = (e: unknown) => log(`ERROR ${key} ${method}: ${describeError(e)}`)
  try {
    const result = handler.call(def)
    if (result instanceof Promise) result.catch(report)
  } catch (e) {
    report(e)
  }
}

interface HookRecord {
  category: HookCategoryName
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
// The extension API level each bundle's manifest declares, as the host
// states it at `beginBundle` — null for one built with the app, which is
// always at the app's own level. Read through `apiOf`.
const bundleApi: Record<string, number | null> = {}

/// The API level [extensionKey] was built for: its defining bundle's, and
/// the app's own for a bundle that declares none or for the kernel's own.
function apiOf(extensionKey: string): number {
  const bundle = definingBundle[extensionKey]
  return (bundle ? bundleApi[bundle] : null) ?? Infinity
}

const logCopies = createLogCopies({
  changes: async (operationUuid, cursor) => (await dispatchHostCall("getQsoChanges", { operationUuid, cursor })) as LogChanges | null,
  whole: async (operationUuid) => (await dispatchHostCall("getQsos", { operationUuid })) as Record<string, unknown>[] | null,
})
const pendingHostCalls = new Map<number, PendingHostCall>()
let nextHostCallId = 1

// Listeners for the sockets `host.webSocket` opened, by the id the host's
// events arrive under. `owner` is set by the bound host call that opens the
// socket — kernel-recorded, like every identity here — and is what lets
// `unloadBundle` drop a reloaded extension's listeners with its hooks.
interface SocketListener {
  owner: string | null
  listener: (event: Record<string, unknown>) => unknown
}
const socketListeners = new Map<number, SocketListener>()
let nextSocketId = 1

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
  return extensionKey === bundleKey || extensionKey.startsWith(`${bundleKey}-`) || extensionKey.startsWith(`${bundleKey}_`)
}

function post(message: Record<string, unknown>) {
  rawSendMessage("polo", JSON.stringify(message))
}

function log(message: string) {
  post({ type: "log", message })
}

// A `command` hook's interpret() can call this any time after it starts —
// including after its own returned Promise already resolved — to push a
// later CommandInterpretation for the same `input` (e.g. once a background
// fetch SOLAR/WEATHER kicked off resolves). One-way, like `log`: no
// response ever comes back over the wire. `input` lets the app discard a
// stale push if the user has since typed something else, the same way it
// already discards a stale describe-preview result.
function updateInterpretation(input: string, interpretation: Record<string, unknown>) {
  post({ type: "updateInterpretation", input, interpretation })
}

function describeError(e: unknown): string {
  // JavaScriptCore stacks don't include the message; report both.
  //
  // Never throws: extensions throw whatever they like — `Object.create(null)`,
  // a revoked Proxy — and this runs inside the kernel's own error handling,
  // where a throw abandons whatever it was handling.
  try {
    const err = e as Error
    return err?.message ? `${err.message}\n${err.stack ?? ""}`.trim() : String(e)
  } catch {
    return "(an error that cannot be printed)"
  }
}

type SettledEntry = { key: string; ok: boolean; value?: unknown; error?: string; noHandler?: boolean }

/// [entry], or — when JSON cannot carry what its hook answered (a circular
/// object, a BigInt) — that hook's own failure in its place.
function serializable(entry: SettledEntry): SettledEntry {
  try {
    JSON.stringify(entry)
    return entry
  } catch (e) {
    return { key: entry.key, ok: false, error: `returned something JSON cannot represent: ${describeError(e)}` }
  }
}

/// Posts a fan-out's or a batch's settled entries. They cross as ONE message,
/// so a single entry JSON cannot carry would fail every other entry with it:
/// only when the whole will not serialize is each entry checked, and those
/// that will not become their own hook's failure. The common case pays for one
/// serialization.
function postEntries(id: number, entries: SettledEntry[], startedAt: number) {
  try {
    post({ type: "result", id, ok: true, value: entries, jsMillis: realNow() - startedAt })
  } catch {
    post({ type: "result", id, ok: true, value: entries.map(serializable), jsMillis: realNow() - startedAt })
  }
}

/// One settled entry of a narrated fan-out or batch — see [postEntries].
function postPartial(id: number, entry: SettledEntry) {
  try {
    post({ type: "partial", id, entry })
  } catch {
    post({ type: "partial", id, entry: serializable(entry) })
  }
}

function hooksFor(category: HookCategoryName, key: string | null): HookRecord[] {
  return hooks.filter((h) => h.category === category && (key == null || h.key === key)).sort((a, b) => b.priority - a.priority)
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
function hooksForRef(category: HookCategoryName, key: string | null, args: unknown): HookRecord[] {
  if (!category.startsWith("ref:") || category.includes("/")) return hooksFor(category, key)
  return claimsOn(category as `ref:${string}`, key, args).map((entry) => entry.record)
}

/// Every record claiming the reference in [args] for a `ref:<type>` [category],
/// with how precisely it claims it — the length of the prefix it named, zero
/// for the bare type — strongest first, then by priority. [hooksForRef]'s
/// ranking, with the strength kept.
function claimsOn(category: `ref:${string}`, key: string | null, args: unknown): { record: HookRecord; strength: number }[] {
  const raw = (args as { ref?: { ref?: unknown } } | null)?.ref?.ref
  const code = typeof raw === "string" ? raw.toLowerCase() : null
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
  return ranked
}

/// The extensions that answer for [refs]: for each, every extension holding the
/// strongest claim on it ([claimsOn]).
///
/// A longer claim excludes a shorter one: on `{type: 'qp', ref: 'CA'}` a
/// party's `ref:qp/ca` leaves out the bundled QSO-party extension's `ref:qp`,
/// or both would write a CONTEST_ID into the same record. Equal claims all
/// count, whatever their priority or the order they registered in, because
/// neither says which of them writes the fields: WCA registers
/// `ref:ecaActivation` too, to resolve a castle while ECA is off, and writes
/// nothing for one — taking only the first would drop ECA's own.
function extensionsRouting(refs: unknown[]): Set<string> {
  const keys = new Set<string>()
  for (const ref of refs) {
    const type = (ref as { type?: unknown } | null)?.type
    if (typeof type !== "string" || type === "" || type.includes("/")) continue
    const claims = claimsOn(`ref:${type}`, null, { ref })
    for (const claim of claims) {
      if (claim.strength < claims[0].strength) break
      keys.add(claim.record.extensionKey)
    }
  }
  return keys
}

/// Whether [record] is asked whatever references a contact carries: an
/// `adifFields` hook whose manifest says `adifFieldsScope: "always"`, the one
/// category with such an opt-in.
function askedForEveryRef(category: HookCategoryName, record: HookRecord): boolean {
  return category === "adifFields" && extensions[record.extensionKey]?.adifFieldsScope === "always"
}

// Host calls that carry (or act on) a caller identity: their `ns`/`kvKey`/
// `extensionKey` params must be derived by the kernel from which extension
// is calling — never supplied by extension code, or any bundle could read
// any other's keychain credentials, KV state, or clear its status items.
const IDENTITY_HOST_METHODS = new Set([
  "fetch",
  "getLocation",
  "listRadios",
  "readRadio",
  "setRadioConnection",
  "setRadio",
  "tuneRadio",
  "setRadioSpectrum",
  "sendRadioCw",
  "playRadioVoice",
  "setRadioPtt",
  "stopRadioTransmit",
  "secret",
  "kvGet",
  "kvSet",
  "getAccount",
  "setAccountSession",
  "showMessage",
  "statusBarSetMessage",
  "statusBarSetProgress",
  "statusBarClear",
  "statusBarShowNotice",
  "statusBarDismissNotice",
  "webSocketOpen",
  "webSocketSend",
  "webSocketClose",
])

/// Internal, trusted dispatch — everything on the wire goes through here.
function dispatchHostCall(method: string, params: Record<string, unknown>): Promise<unknown> {
  // An extension writing its own session must see it on its very next hook
  // call, not after the context cache's TTL (see getAccountContext).
  if (method === "setAccountSession" && typeof params.ns === "string") {
    cachedAccounts.delete(params.ns)
  }
  const callId = nextHostCallId++
  return new Promise((resolve, reject) => {
    pendingHostCalls.set(callId, { resolve, reject })
    post({ type: "hostCall", callId, method, params })
  })
}

/// The public (`__polo.hostCall`) surface: identity-bearing methods are
/// refused — extensions reach those through the activation-scoped
/// `api.hostCall` their SDK copy captures (see activateExtension), whose
/// identity params the kernel injects itself.
function hostCall(method: string, params: Record<string, unknown>): Promise<unknown> {
  if (IDENTITY_HOST_METHODS.has(method)) {
    return Promise.reject(new Error(`host call '${method}' needs the calling extension's identity and is only available through the SDK host API`))
  }
  return dispatchHostCall(method, params)
}

/// The privileged host-call function handed to one extension at activation:
/// identity params are forced to the kernel's own record of who this is.
function boundHostCallFor(extensionKey: string) {
  return (method: string, params: Record<string, unknown>): Promise<unknown> => {
    if (!IDENTITY_HOST_METHODS.has(method)) return dispatchHostCall(method, params)
    const bound: Record<string, unknown> = { ...params, ns: extensionKey, extensionKey }
    if (method === "getAccount" || method === "setAccountSession") {
      bound.kvKey = kernel.getAccountKvKey(extensionKey)
    }
    if (method === "webSocketOpen") {
      // Only an id registerSocket handed out and nobody has opened yet. Ids
      // are guessable: a second open naming one in use would take over its
      // listener, and one naming an id not yet handed out would take it from
      // whoever gets it next — leaving a socket no unload knows to close.
      const socket = socketListeners.get(params.socketId as number)
      if (!socket || socket.owner !== null) {
        return Promise.reject(new Error(`webSocket: socket ${String(params.socketId)} is not reserved, or already in use`))
      }
      socket.owner = extensionKey
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
      return await dispatchHostCall("getSettings", {})
    } catch (e) {
      return undefined
    }
  })()
  cachedSettings = { value, at: realNow() }
  return value
}

function getAccountContext(extensionKey: string): Promise<unknown> {
  const accountHookRecord = hooks.find((h) => h.category === "account" && h.extensionKey === extensionKey)
  if (!accountHookRecord) return Promise.resolve(undefined)
  const cached = cachedAccounts.get(extensionKey)
  if (cached && realNow() - cached.at < CONTEXT_CACHE_TTL_MILLIS) return cached.value
  const kvKey = accountHookRecord.hook.kvKey || accountHookRecord.key || extensionKey
  const value = (async () => {
    try {
      // Trusted kernel path (this is the kernel deriving identity itself,
      // not extension code claiming one) — bypasses the public gate.
      return (await dispatchHostCall("getAccount", { ns: extensionKey, kvKey })) as unknown
    } catch (e) {
      return undefined
    }
  })()
  cachedAccounts.set(extensionKey, { value, at: realNow() })
  return value
}

/// The uuid of the `operation` a hook was handed, if it was handed one — the
/// operation a `getSpots` call judges its spots against unless told another.
function operationUuidOf(args: unknown): string | undefined {
  const uuid = (args as { operation?: { uuid?: unknown } } | null | undefined)?.operation?.uuid
  return typeof uuid === "string" && uuid !== "" ? uuid : undefined
}

async function callHookMethod(record: HookRecord, method: string, args: unknown, online = true): Promise<unknown> {
  const member = record.hook[method]
  // Plain data members don't get a ctx — skip the context fetches entirely.
  if (typeof member !== "function") return member
  const account = (await getAccountContext(record.extensionKey)) as { credentials?: Record<string, string>; session?: Record<string, string> } | undefined
  let developerMode = false
  let locale = "en"
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
    distanceUnits: settings?.distanceUnits ?? "kilometers",
    gridPrecision: settings?.gridPrecision ?? 6,
    edition: settings?.edition,
    enabledExperiments: settings?.enabledExperiments ?? [],
    experiments: settings?.experiments ?? [],
    // Log-data reads (HookContext.getOperation/getQsos in types.ts). Built
    // per call like the rest of ctx but deliberately NOT cached like
    // settings/account above — log data changes with every QSO, and a
    // 3s-stale QSO list is exactly what a caller like SEED can't tolerate.
    // `getQsos` answers from the shared copy, which asks the host what
    // changed on every call (logCopy.ts), so it is never staler than that.
    // Not identity-bearing (no ns/kvKey), so plain dispatchHostCall is fine.
    getOperation: async (uuid: string) => ((await dispatchHostCall("getOperation", { uuid })) as Record<string, unknown> | null) ?? null,
    // Null (unknown operation / no log access) passes through untouched —
    // it means something different from [] (see HookContext.getQsos).
    getQsos: (operationUuid: string) => logCopies.read(operationUuid, { frozen: apiOf(record.extensionKey) >= FROZEN_QSOS_API }),
    // Reads the host's already-fetched spot cache; never triggers a fetch,
    // so it is cheap enough for the per-keystroke lookup pipeline (see
    // HookContext.getSpotsForCall).
    getSpotsForCall: async (call: string, maxAgeMinutes?: number) =>
      ((await dispatchHostCall("getSpotsForCall", { call, maxAgeMinutes })) as Spot[] | null) ?? [],
    // The whole board, defaulting its operation to the one this hook was
    // handed so a panel's spots come back judged without asking — see
    // HookContext.getSpots. `annotate: false` asks for none, so none is sent.
    getSpots: async (options?: GetSpotsOptions) =>
      ((await dispatchHostCall("getSpots", {
        ...options,
        operationUuid: options?.operationUuid ?? (options?.annotate === false ? undefined : operationUuidOf(args)),
      })) as BoardSpot[] | null) ?? [],
    // Cross-operation log read, backing `call-history` — see
    // HookContext.getHistoryForCall.
    getHistoryForCall: async (call: string, options?: HistoryForCallOptions) =>
      ((await dispatchHostCall("getHistoryForCall", { ...options, call })) as Record<string, unknown>[] | null) ?? [],
  }
  return await member.call(record.hook, args, ctx)
}

/// What `runHook` throws when nothing registers the category: an answer about
/// the reference ("no program handles this"), not a failure of one — a batch
/// entry says so with `noHandler`, so a host can tell the two apart without
/// reading the message.
class NoHandlerError extends Error {}

/// One host-requested call on the highest-priority hook for `category` (and
/// `key`, when given) — what `invokeHook` runs, and what `invokeHookBatch`
/// runs once per call, so a call routes the same way whichever way it came.
async function runHook(category: HookCategoryName, key: string | null, method: string, args: unknown): Promise<unknown> {
  // Chosen from the args, not the category alone: for a `ref:` category the
  // hook depends on the reference being asked about.
  const record = hooksForRef(category, key, args)[0]
  if (!record) throw new NoHandlerError(`no hook registered for ${category}/${key ?? "*"}`)
  // Tier 1 settings panels (kind: 'simple') are static data, not a
  // getDefinition() function — build the FormDefinition from the registered
  // object directly. Everything else (Tier 2's real getDefinition/
  // validateField/transformField/onChangeField, and any action method on
  // either tier) goes through the generic path below.
  if (category === "settingsPanel" && method === "getDefinition" && record.hook.kind === "simple") {
    return tier1FormDefinition(record.hook)
  }
  const requested = (args as { online?: unknown } | null)?.online
  const online = typeof requested === "boolean" ? requested : true
  if (category === "scoring") args = await withLoggedQsos(record, args)
  return await callHookMethod(record, method, args, online)
}

/// A full rescore names the contacts it read (`qsoUuids`) instead of sending
/// them: they come from the shared log copy here, in the host's order, so the
/// log crosses the bridge once per change rather than once per scorer per
/// pass. Every scorer still finds `qsos` in its args, so a bundle on any SDK
/// folds them unchanged — frozen at the frozen level, copies below it.
///
/// `qsos` the host sent as themselves — a tail, the live paths' replay — are
/// frozen at that level too. A scorer handed writable contacts on most passes
/// and frozen ones on a full pass would fail only on the pass that rescores
/// everything, inside the app and nowhere else.
///
/// Uuids, not "the log", because the host's checkpoint digest counts exactly
/// the contacts it read: one logged since, folded here, would be replayed as
/// the next pass's tail and counted twice. One deleted or edited since is
/// absent or newer here, which the digest no longer matches, so the next
/// pass folds cold (`resolveScoringResume`).
async function withLoggedQsos(record: HookRecord, args: unknown): Promise<unknown> {
  const { qsoUuids, ...rest } = (args ?? {}) as { qsoUuids?: unknown; qsos?: unknown }
  const frozen = apiOf(record.extensionKey) >= FROZEN_QSOS_API
  if (Array.isArray(rest.qsos)) {
    if (frozen) deepFreeze(rest.qsos)
    return args
  }
  if (!Array.isArray(qsoUuids)) return args
  const operationUuid = operationUuidOf(args)
  const qsos = operationUuid ? await logCopies.pick(operationUuid, qsoUuids.map(String), { frozen }) : null
  // A log the runtime cannot read is a failed pass, not an empty one: folded
  // as empty, its zero totals would replace the operation's cached score.
  if (qsos === null) throw new Error(`scoreQsos named contacts of an operation whose log cannot be read (${operationUuid ?? "no operation"})`)
  return { ...rest, qsos }
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
  const timerOwner = timerQueue.owner(def.key)
  try {
    await def.onActivation({
      // Activation is the identity hand-off: this function closes over the
      // extension's kernel-recorded key, and the SDK copy inside the bundle
      // captures it in module scope — unreachable from other bundles.
      hostCall: boundHostCallFor(def.key),
      timers: {
        set: (callback: unknown, delay: unknown, repeat: boolean, args: unknown[]) => timerQueue.set(timerOwner, callback, delay, repeat, args),
        clear: (id: unknown) => timerQueue.clear(timerOwner, id),
      },
      registerHook(category: HookCategoryName, params: RegisterHookParams) {
        if (!params?.hook) {
          throw new Error(`registerHook(${category}) called with no hook in extension ${def.key}`)
        }
        const hookObj = params.hook as Record<string, unknown>
        if (category === "dataFile") {
          if (typeof hookObj.csvToLookupEntry === "function" && typeof hookObj.mapCsvBatch !== "function") {
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
                return args.rows.map((row) => mapper(row)).filter((x) => x !== null && x !== undefined)
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
          if (typeof hookObj.jsonToLookupEntry === "function" && typeof hookObj.mapJsonBatch !== "function") {
            hookObj.mapJsonBatch = async (args: { entries: unknown[] }) => {
              const mapper = hookObj.jsonToLookupEntry as (entry: unknown) => unknown
              return args.entries.map((entry) => mapper(entry)).filter((x) => x !== null && x !== undefined)
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
    // An `adifFields` hook the full ADIF export will never ask writes nothing,
    // and the export says nothing about it. The packer refuses a manifest like
    // that; this is for a bundle it never saw, and for a definition that did
    // not spread the manifest and so lost its opt-in.
    const own = hooks.filter((h) => h.extensionKey === def.key)
    if (own.some((h) => h.category === "adifFields") && def.adifFieldsScope !== "always" && !own.some((h) => h.category.startsWith("ref:"))) {
      log(
        `ERROR extension ${def.key} registers adifFields but handles no reference and does not set adifFieldsScope: "always" — the full ADIF export will never ask it`,
      )
    }
    log(`activated extension ${def.key}@${def.version}`)
    // Not if a dev reload unloaded it while it was still activating.
    if (extensions[def.key] === def) {
      live.add(def.key)
      if (!appVisible) tellVisibility(def.key, false)
    }
    return null
  } catch (e) {
    const message = describeError(e)
    log(`ERROR activating extension ${def.key}: ${message}`)
    // Whatever timers it set before throwing belong to an extension that
    // never came up.
    timerQueue.cancel(timerOwner)
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
  beginBundle(key: string, api?: number | null) {
    bundlesStarted = true
    currentBundleKey = key
    bundleApi[key] = typeof api === "number" ? api : null
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
        post({ type: "activationComplete" })
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
  /// its timers are dropped here with everything else, so an unloaded
  /// extension has no pending work left to fire. A hook call already in flight
  /// is the one loose end — its promise may still resolve, and the host
  /// settles it by call id as usual.
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
      live.delete(key)
    }
    // The new code never opened these sockets and must not hear their
    // events; the host closes exactly the ids named here.
    const dropped: number[] = []
    for (const [id, socket] of socketListeners) {
      if (socket.owner !== null && keys.includes(socket.owner)) {
        socketListeners.delete(id)
        dropped.push(id)
      }
    }
    if (dropped.length) post({ type: "socketsDropped", socketIds: dropped })
    timerQueue.drop(keys)
    if (keys.length) log(`unloaded bundle ${bundleKey} (${keys.join(", ")})`)
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
          const key = e.slice(0, e.indexOf(":"))
          return definingBundle[key] === bundleKey || key === bundleKey
        })
        if (mine.length) post({ type: "reloadComplete", token, ok: false, error: mine.join("\n") })
        else post({ type: "reloadComplete", token, ok: true })
      } catch (e) {
        post({ type: "reloadComplete", token, ok: false, error: describeError(e) })
      }
    })()
  },

  invokeHook(id: number, category: HookCategoryName, key: string | null, method: string, argsJson: string) {
    const startedAt = realNow()
    void (async () => {
      try {
        const result = await runHook(category, key, method, JSON.parse(argsJson))
        post({ type: "result", id, ok: true, value: result ?? null, jsMillis: realNow() - startedAt })
      } catch (e) {
        post({ type: "result", id, ok: false, error: describeError(e), jsMillis: realNow() - startedAt })
      }
    })()
  },

  /// Several single-hook calls in one crossing: each `{category, key, method,
  /// args}` is routed and run exactly as `invokeHook` would run it, all of
  /// them concurrently, and the result is one `{key, ok, value|error}` entry
  /// per call, in call order, `key` being the call's index. One call failing
  /// is that entry's `ok: false`, never the batch's; one that nothing registers
  /// also carries `noHandler: true`.
  ///
  /// Narrated like `invokeHookAll` when `wantsPartials` is set — the roster
  /// is the list of indices — so a host that stops waiting keeps every call
  /// that already answered.
  invokeHookBatch(id: number, callsJson: string, wantsPartials = false) {
    const startedAt = realNow()
    void (async () => {
      try {
        const calls = JSON.parse(callsJson) as { category: HookCategoryName; key?: string | null; method: string; args?: unknown; error?: string }[]
        if (wantsPartials) post({ type: "partial", id, keys: calls.map((_, i) => String(i)) })
        const entries = await Promise.all(
          calls.map(async (call, i) => {
            let entry: SettledEntry
            try {
              // A call the host could not encode arrives carrying why, and fails alone.
              if (call.error) throw new Error(call.error)
              entry = { key: String(i), ok: true, value: (await runHook(call.category, call.key ?? null, call.method, call.args ?? {})) ?? null }
            } catch (e) {
              entry = { key: String(i), ok: false, error: describeError(e), ...(e instanceof NoHandlerError ? { noHandler: true } : {}) }
            }
            if (wantsPartials) postPartial(id, entry)
            return entry
          }),
        )
        postEntries(id, entries, startedAt)
      } catch (e) {
        post({ type: "result", id, ok: false, error: describeError(e), jsMillis: realNow() - startedAt })
      }
    })()
  },

  invokeHookAll(id: number, category: HookCategoryName, method: string, argsJson: string, wantsPartials = false) {
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
        if (category === "account" && method === "getDefinition") {
          const records = hooksFor("account", null)
          const entries = await Promise.all(
            records.map(async (record) => {
              try {
                // A per-edition client (e.g. SOTA's OAuth) is a function;
                // callHookMethod builds it a ctx the same way any
                // other hook method call would. A plain object needs neither.
                // Own try/catch, not just the outer one: one account's oauth2
                // throwing must not blank out every other account's entry too
                // (same per-source isolation invokeHookAll gives every caller).
                const oauth2 = typeof record.hook.oauth2 === "function" ? await callHookMethod(record, "oauth2", {}) : (record.hook.oauth2 ?? null)
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
                    label: (await callHookMethod(record, "label", {})) ?? record.key,
                    description: (await callHookMethod(record, "description", {})) ?? null,
                    kvKey: record.hook.kvKey ?? record.key ?? record.extensionKey,
                    fields: (await callHookMethod(record, "fields", {})) ?? [],
                    oauth2,
                    synchronizable: record.hook.synchronizable ?? false,
                  },
                }
              } catch (e) {
                return { key: record.key, ok: false, error: describeError(e) }
              }
            }),
          )
          postEntries(id, entries, startedAt)
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
        if (category === "settingsPanel" && method === "getPanels") {
          const records = hooksFor("settingsPanel", null)
          const online = typeof args?.online === "boolean" ? args.online : true
          const perRecord = await Promise.all(
            records.map(async (record) => {
              try {
                const descriptors =
                  record.hook.kind === "dynamic" && typeof record.hook.getPanels === "function"
                    ? ((await callHookMethod(record, "getPanels", {}, online)) as SettingsPanelDescriptor[] | null)
                    : undefined
                for (const d of descriptors ?? []) {
                  if (!isValidHookKey("settingsPanel", record.extensionKey, d.key)) {
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
          postEntries(id, entries, startedAt)
          return
        }
        if (category === "dataFile" && method === "getDefinition") {
          const records = hooksFor("dataFile", null)
          const entries = await Promise.all(
            records.map(async (record) => {
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
                    name: await callHookMethod(record, "name", {}),
                    description: await callHookMethod(record, "description", {}),
                    // Through callHookMethod like `name` and `description`, not
                    // read raw: a definition whose URL depends on something the
                    // extension has to ASK for — TOTA's list carries its API key as
                    // a query parameter — supplies a function, and a plain string
                    // still comes back unchanged.
                    url: await callHookMethod(record, "url", {}),
                    maxAgeInDays: record.hook.maxAgeInDays,
                    fetchType: record.hook.fetchType,
                    encoding: record.hook.encoding ?? null,
                    category: record.hook.category,
                    csvOptions: record.hook.csvOptions ?? null,
                    jsonOptions: record.hook.jsonOptions ?? null,
                  },
                }
              } catch (e) {
                return { key: record.key, ok: false, error: describeError(e) }
              }
            }),
          )
          postEntries(id, entries, startedAt)
          return
        }
        const online = typeof args?.online === "boolean" ? args.online : true
        const records = hooksFor(category, null).filter((r) => typeof r.hook[method] === "function" || r.hook[method] !== undefined)

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
        if (wantsPartials) post({ type: "partial", id, keys: records.map((r) => r.key) })

        const entries = await Promise.all(
          records.map(async (record) => {
            let entry: SettledEntry
            try {
              entry = { key: record.key, ok: true, value: (await callHookMethod(record, method, args, online)) ?? null }
            } catch (e) {
              entry = { key: record.key, ok: false, error: describeError(e) }
            }
            if (wantsPartials) postPartial(id, entry)
            return entry
          }),
        )
        postEntries(id, entries, startedAt)
      } catch (e) {
        post({ type: "result", id, ok: false, error: describeError(e), jsMillis: realNow() - startedAt })
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
  /// [forRefs] narrows it to the extensions that answer for one of those
  /// references ([extensionsRouting]), plus any [askedForEveryRef] — for a
  /// fan-out that must not reach an extension the contact has nothing to do
  /// with. The full ADIF export is one: a program answering every contact
  /// stamps its fields on every log the operator keeps.
  async invokeLocal(
    category: HookCategoryName,
    method: string,
    args: unknown,
    online = true,
    key: string | null = null,
    forRefs: unknown[] | null = null,
  ): Promise<{ key: string; ok: boolean; value?: unknown; error?: string }[]> {
    const routing = forRefs ? extensionsRouting(forRefs) : null
    const records = hooksFor(category, key).filter(
      (r) => typeof r.hook[method] === "function" && (routing === null || routing.has(r.extensionKey) || askedForEveryRef(category, r)),
    )
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
    category: HookCategoryName,
    method: string,
    initialArgs: unknown,
    fold: (args: unknown, hookResult: unknown, hookKey: string) => unknown,
    online = true,
  ): Promise<{ key: string; ok: boolean; value?: unknown; error?: string }[]> {
    const records = hooksFor(category, null).filter((r) => typeof r.hook[method] === "function")
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

  /// The timer queue's time until the host stamps another, in milliseconds on
  /// the host's monotonic clock. Sent only by a host given a test clock.
  setMonotonicNow(millis: number) {
    stampedNow = millis
  },

  /// The host's answer to a `timerWake`: fires every timer now due.
  runTimers() {
    timerQueue.run()
  },

  /// Called by the host whenever the app is shown or hidden, and once after
  /// every boot. Tells each live extension through its definition's
  /// `onShow`/`onHide` — on a change only, so the boot push is silent for an
  /// app that is visible.
  setAppVisible(visible: boolean) {
    if (visible === appVisible) return
    appVisible = visible
    for (const key of live) tellVisibility(key, visible)
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

  /// Reserves a socket id for [listener]. The SDK's `host.webSocket` does
  /// this BEFORE asking the host to connect, so no event can arrive for an id
  /// nothing is listening on.
  registerSocket(listener: (event: Record<string, unknown>) => unknown): number {
    const id = nextSocketId++
    socketListeners.set(id, { owner: null, listener })
    return id
  },

  /// Hands one host-delivered socket event to its listener. `close` is always
  /// the last event a socket gets, so it retires the id.
  socketEvent(socketId: number, eventJson: string) {
    const socket = socketListeners.get(socketId)
    if (!socket) return
    let event: Record<string, unknown>
    try {
      event = JSON.parse(eventJson)
    } catch (e) {
      log(`ERROR malformed socket event: ${describeError(e)}`)
      return
    }
    if (event.type === "close") socketListeners.delete(socketId)
    // A browser logs a failed socket whatever the page does with it; an
    // extension without an onerror would otherwise see only a bare 1006.
    if (event.type === "error") log(`${socket.owner ?? "unknown"} socket ${socketId}: ${String(event.message)}`)
    // An extension's callback failing is its own bug, and must not stop the
    // next event from being delivered — or take the kernel with it.
    const report = (e: unknown) => log(`ERROR ${socket.owner ?? "unknown"} socket ${event.type} handler: ${describeError(e)}`)
    try {
      const result = socket.listener(event)
      if (result instanceof Promise) result.catch(report)
    } catch (e) {
      report(e)
    }
  },

  hostCall,
  // Inside a bundle's evaluation, a line is attributed to that bundle: a
  // library logging as its module loads has no extension key of its own yet.
  log: (message: string) => log(currentBundleKey !== null ? `[${currentBundleKey}] ${message}` : message),
  updateInterpretation,

  registeredHooks(): string[] {
    return hooks.map((h) => `${h.category}/${h.key} (${h.extensionKey})`)
  },

  getAccountKvKey(extensionKey: string): string {
    const accountHookRecord = hooks.find((h) => h.category === "account" && h.extensionKey === extensionKey)
    return (accountHookRecord?.hook?.kvKey as string | undefined) || accountHookRecord?.key || extensionKey
  },

  registerDynamicForm(formId: string, extensionKey: string, hookObj: Record<string, unknown>) {
    hooks.push({
      category: "form",
      key: formId,
      priority: 0,
      extensionKey,
      hook: hookObj,
    })
  },

  unregisterDynamicForm(formId: string) {
    const idx = hooks.findIndex((h) => h.category === "form" && h.key === formId)
    if (idx !== -1) {
      hooks.splice(idx, 1)
    }
  },

  host: {
    async showForm(form: FormDefinition, state: Record<string, any> = {}, extensionKey: string = "kernel"): Promise<Record<string, any> | null> {
      const formId = `dynamic:${Math.random().toString(36).substring(2, 10)}`

      const cleanElements = form.elements.map((el) => {
        if (el.type === "field") {
          const { validate, transform, ...rest } = el
          return rest
        }
        return el
      })
      const cleanForm = { ...form, elements: cleanElements }

      kernel.registerDynamicForm(formId, extensionKey, {
        getDefinition: async () => cleanForm,
        validateField: async (args: { fieldKey: string; value: any; state: Record<string, any> }) => {
          const field = form.elements.find((el) => el.type === "field" && (el as FormField).key === args.fieldKey) as FormField | undefined
          if (field?.validate) {
            return (await field.validate(args.value, args.state)) ?? null
          }
          return null
        },
        transformField: async (args: { fieldKey: string; value: any; state: Record<string, any> }) => {
          const field = form.elements.find((el) => el.type === "field" && (el as FormField).key === args.fieldKey) as FormField | undefined
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
        },
      })

      try {
        const result = await hostCall("showForm", { formId, form: cleanForm, state })
        return result as Record<string, any> | null
      } finally {
        kernel.unregisterDynamicForm(formId)
      }
    },
  },

  sharedModules,
  sharedVersions: typeof __SHARED_VERSIONS__ !== "undefined" ? __SHARED_VERSIONS__ : {},
}

;(globalThis as Record<string, unknown>).__polo = kernel

// Route console.log to the host so extension debugging output is visible.
;(globalThis as Record<string, unknown>).console = {
  log: (...args: unknown[]) => log(args.map(String).join(" ")),
  warn: (...args: unknown[]) => log("WARN " + args.map(String).join(" ")),
  error: (...args: unknown[]) => log("ERROR " + args.map(String).join(" ")),
}

// Built-in runtime introspection: the Developer panel's "Active Extensions"
// listing calls this — versions live only in each bundle's defineExtension
// manifest, so the runtime is the one place they can be read from.
kernel.defineExtension({
  key: "kernel-info",
  name: "Kernel info",
  version: "0.0.1",
  onActivation({ registerHook }) {
    registerHook("runtime", {
      key: "kernel",
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
            methods: Object.keys(record.hook).filter((name) => typeof record.hook[name] === "function"),
          })),
      },
    })
  },
})

// Built-in bench hooks, used to measure pure bridge round-trip latency
// (echo) and JS compute throughput (spin) with no extension code involved.
kernel.defineExtension({
  key: "kernel-bench",
  name: "Kernel benchmarks",
  version: "0.0.1",
  onActivation({ registerHook }) {
    registerHook("bench", {
      key: "kernel",
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

log("kernel ready")

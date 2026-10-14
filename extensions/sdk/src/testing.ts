// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// Running a hook without the app. An extension's hooks are the part the app
// actually calls, and until now the only way to exercise one was to build the
// bundles, boot QuickJS and drive Flutter — so extension tests reached past
// the hooks and called the plain functions behind them instead. What the hook
// hands back, the shape the host receives, went untested.
//
//   const wwff = await loadExtension(() => import("./index.ts"))
//   const controls = await wwff.runHook("activity", "operationControls", {
//     operation: fixtureOperation({ refs: [{ type: "wwffActivation", ref: "GFF-0001" }] }),
//   })
//
// NOT exported from index.ts, and deliberately: everything index.ts exports is
// bundled into all 53 extensions. Import it by path, the way tests already
// import `sdk/src/dxcc.ts`.
//
// The stand-in kernel here answers what activation and a hook call touch, and
// nothing more; a test that needs a particular answer passes `hostCalls`. The
// build's own manifest check (`extensions/hook-check.mjs`) keeps a second,
// smaller stand-in for the same runtime — it evaluates BUILT bundles in a vm
// rather than importing source — so a host call taught to one is worth
// teaching to the other.

import type { ExtensionDefinition, HookContext, JSONValue } from "./types.ts"
import { installAppClock } from "./appClock.ts"
import type { AppClockHandle } from "./appClock.ts"
import { createTimerQueue } from "./timerQueue.ts"
import { deepFreeze, FROZEN_QSOS_API } from "./logCopy.ts"

/// A host call's stand-in answer, by method name (`getSettings`,
/// `dbLookupSelectAll`, `fetch`…). Anything unlisted answers null, which
/// every extension already has to tolerate: `host.secret()` is null in the
/// dev loop, and a lookup table is empty until its data file syncs.
export type HostCallStubs = Record<string, (params: Record<string, unknown>) => unknown>

export interface LoadExtensionOptions {
  hostCalls?: HostCallStubs
  /// Merged over the default context handed to every hook call.
  ctx?: Partial<HookContext>
  /// The extension API level to run under. Defaults to the `api` the
  /// definition carries from its manifest. One that declares none is held to
  /// the levels the app holds it to: a built-in (no `category`) at the app's
  /// own, any other at 0.
  api?: number
}

export interface RunHookOptions {
  /// Which registration to call, when one extension registers several in a
  /// category under different keys (`pota` and `pota-all-parks` both register
  /// `dataFile`). Defaults to the only one, and throws if there are several.
  key?: string
  ctx?: Partial<HookContext>
}

export interface LoadedExtension {
  /// Every hook the extension registered, in registration order.
  readonly hooks: { category: string; key: string; hook: Record<string, unknown> }[]
  /// The definitions the module declared — one for most extensions, more for
  /// a bundle that defines a sub-extension (`pota` also defines
  /// `pota-all-parks`).
  readonly definitions: ExtensionDefinition[]
  /// The categories it registered, for asserting the shape of the extension
  /// itself rather than one hook's answer.
  categories(): string[]
  /// Calls one hook method the way the runtime does, with a HookContext.
  /// Throws when the category, the key or the method is absent — a test that
  /// silently exercised nothing would be worse than one that failed.
  runHook(category: string, method: string, args?: unknown, options?: RunHookOptions): Promise<unknown>
  /// The extension's timers, on a clock only the test moves.
  readonly timers: TestTimers
}

/// The runtime's own timer queue — the same budget, cap and suspension rules
/// (timerQueue.ts) — on a clock that stands still until [advance] moves it.
///
/// Only what goes through the SDK is here: `host.setTimeout` and friends. A
/// bare `setTimeout` reaches the SDK's only in a BUILT bundle, where the build
/// rewrites it; a test imports the source, so there it is Node's own timer.
export interface TestTimers {
  /// Moves the clock forward by [ms], firing whatever comes due on the way, in
  /// order — a 1000ms interval advanced by 3500ms fires three times — and
  /// letting each callback's awaited work settle before the next fires.
  ///
  /// From the first call on, `Date` follows the same clock, so a callback that
  /// reads the time sees the moment it fired rather than the test's wall
  /// clock: a fake timer read against a real clock tests nothing
  /// (docs/design/time.md §7). It stays pinned for every test that shares
  /// this loaded extension, and the next [loadExtension] goes back to real
  /// time.
  ///
  /// Rejects if a callback threw or rejected, or if the extension broke its
  /// budget and lost its timers — in the app either one is a bug the operator
  /// would only ever see as a feature quietly stopping.
  advance(ms: number): Promise<void>
  /// Whether any timer is still set — for asserting a close or a stop left
  /// nothing behind.
  readonly pending: boolean
}

const defaultContext: HookContext = {
  online: false,
  locale: "en",
  appName: "Ham2K Logger",
  developerMode: false,
}

/// An operation the way a hook receives one: a plain JSON map. Override
/// anything; `refs` is the field most hooks look at.
export function fixtureOperation(overrides: Record<string, JSONValue> = {}): Record<string, JSONValue> {
  return {
    uuid: "test-operation",
    stationCall: "KI2D",
    title: "Test Operation",
    refs: [],
    ...overrides,
  }
}

/// One logged QSO, in the shape a hook receives. `startAtMillis` is fixed
/// rather than "now" so a scorer's answer cannot depend on the day the test
/// runs (docs/design/time.md).
export function fixtureQso(overrides: Record<string, JSONValue> = {}): Record<string, JSONValue> {
  return {
    uuid: "test-qso",
    startAtMillis: Date.UTC(2026, 0, 1, 12, 0, 0),
    band: "20m",
    mode: "SSB",
    freq: 14250,
    our: { call: "KI2D", sent: "59" },
    their: { call: "W1AW", sent: "59" },
    ...overrides,
  }
}

/// A short log: three contacts, an hour apart, different calls and bands.
/// For a scorer or an export, where one QSO proves nothing about totals.
export function fixtureQsos(count = 3): Record<string, JSONValue>[] {
  const calls = ["W1AW", "K2ABC", "N3XYZ", "W4DEF", "K5GHI"]
  const bands = ["20m", "40m", "15m", "80m", "10m"]
  return Array.from({ length: count }, (_, i) =>
    fixtureQso({
      uuid: `test-qso-${i + 1}`,
      startAtMillis: Date.UTC(2026, 0, 1, 12 + i, 0, 0),
      band: bands[i % bands.length],
      their: { call: calls[i % calls.length], sent: "59" },
    }),
  )
}

/// Definitions captured from every module imported so far. Node caches an
/// ESM module, so re-importing an extension does NOT re-run its
/// `defineExtension` — [loadExtension] keys what it captured by the module
/// namespace so a second load of the same extension still works.
const captured: ExtensionDefinition[] = []
const definitionsByModule = new WeakMap<object, ExtensionDefinition[]>()

/// The one extension key this process has loaded. In the runtime each bundle
/// carries its OWN copy of the SDK, so `host.*` resolves to the extension it
/// was compiled into; here every extension shares one module instance, and
/// that instance binds host calls to whichever extension was defined LAST.
/// Two in one process therefore answer each other's stubs — quietly, and in
/// whichever direction the imports happened to run. One per process instead,
/// which costs nothing: `node:test` already gives each file its own.
let loadedKey: string | undefined

/// Installed on the first [TestTimers.advance] in the process, and kept: the
/// replaced `Date` is what extension code already holds by then.
let appClock: AppClockHandle | undefined

/// Timers for one loaded extension, on a clock starting at the real time.
function testTimers() {
  let now = Date.now()
  let nextDeadline: number | null = null
  const failures: unknown[] = []
  const suspensions: string[] = []
  const queue = createTimerQueue({
    realNow: () => now,
    wake: (delay) => (nextDeadline = delay === null ? null : now + delay),
    // A timer the queue would not keep is a feature that quietly stops in the
    // app: here it fails the test.
    log: (message) => {
      if (message.includes(" set a timer ")) failures.push(new Error(message))
    },
    describeError: (e) => {
      failures.push(e)
      return e instanceof Error ? e.message : String(e)
    },
    suspended: (_, reason) => suspensions.push(reason),
  })
  const pinDate = () => {
    appClock ??= installAppClock()
    appClock.setClockTravel(appClock.realNow(), now, 0)
  }
  const settle = () => new Promise((resolve) => setImmediate(resolve))
  // Each reported once: a test that expects one failure and then a recovery
  // must be able to advance past it.
  const failIfBroken = () => {
    if (suspensions.length) {
      const reasons = suspensions.splice(0).join(", ")
      const behind = failures.splice(0).map((e) => (e instanceof Error ? e.message : String(e)))
      throw new Error(
        `the extension's timers were suspended (${reasons})${behind.length ? `, after: ${behind.join("; ")}` : ""} — see timerQueue.ts for its budget`,
      )
    }
    if (failures.length) throw failures.splice(0)[0]
  }

  const timers: TestTimers = {
    async advance(ms) {
      const target = now + ms
      while (nextDeadline !== null && nextDeadline <= target) {
        now = Math.max(now, nextDeadline)
        nextDeadline = null
        pinDate()
        queue.run()
        await settle()
        failIfBroken()
      }
      now = target
      pinDate()
    },
    get pending() {
      return nextDeadline !== null
    },
  }
  return { queue, timers }
}

function installKernel(hostCalls: HostCallStubs, timerRefusals: string[]) {
  const answer = async (method: string, params: Record<string, unknown>) => {
    const stub = hostCalls[method]
    if (stub) return stub(params ?? {})
    if (method === "getSettings") return {}
    if (method.startsWith("dbLookup")) return []
    return null
  }
  ;(globalThis as Record<string, unknown>).__polo = {
    defineExtension: (definition: ExtensionDefinition) => captured.push(definition),
    hostCall: answer,
    log: (message: string) => {
      if (message.includes("a timer was ignored")) timerRefusals.push(message)
    },
    invokeLocal: async () => [],
    invokeLocalSequential: async () => [],
    updateInterpretation: () => {},
    getAccountKvKey: (extensionKey: string) => extensionKey,
    registerDynamicForm: () => {},
    unregisterDynamicForm: () => {},
    host: { showForm: async () => null },
    sharedModules: {},
    sharedVersions: {},
  }
  return answer
}

/// Imports an extension and activates it, returning a handle its hooks can be
/// called through. [importer] is the extension's own entry point:
/// `() => import("./index.ts")`.
///
/// The kernel stand-in is installed BEFORE the import, because
/// `defineExtension` runs while the module body evaluates.
export async function loadExtension(importer: () => Promise<unknown>, options: LoadExtensionOptions = {}): Promise<LoadedExtension> {
  const timerRefusals: string[] = []
  const answer = installKernel(options.hostCalls ?? {}, timerRefusals)
  // Back to real time: a clock pinned by an earlier load's `advance` belongs
  // to that load's tests, not this one's.
  appClock?.setClockTravel(0, 0, 1)

  const before = captured.length
  const namespace = (await importer()) as object
  const fresh = captured.slice(before)
  if (fresh.length) definitionsByModule.set(namespace, fresh)
  const definitions = fresh.length ? fresh : (definitionsByModule.get(namespace) ?? [])
  if (!definitions.length) {
    throw new Error("loadExtension: the module defined no extension — it must call defineExtension() when imported")
  }

  const key = definitions[0].key
  if (loadedKey && loadedKey !== key) {
    throw new Error(
      `loadExtension: this process already loaded '${loadedKey}', and one process can only hold one — ` +
        `every extension shares a single SDK instance here, which binds host.* to whichever was defined last, ` +
        `so '${loadedKey}' and '${key}' would answer each other's hostCalls. Put each extension in its own test file.`,
    )
  }
  loadedKey = key

  const hooks: { category: string; key: string; hook: Record<string, unknown> }[] = []
  const { queue, timers } = testTimers()
  for (const definition of definitions) {
    const owner = queue.owner(definition.key)
    await definition.onActivation({
      hostCall: answer,
      timers: {
        set: (callback, delay, repeat, args) => queue.set(owner, callback, delay, repeat, args),
        clear: (id) => queue.clear(owner, id),
      },
      registerHook: (category: string, params: { hook: unknown; key?: string; priority?: number }) => {
        hooks.push({
          category,
          key: params.key ?? definition.key,
          hook: params.hook as Record<string, unknown>,
        })
      },
    })
  }
  // A library that sets a timer as its module loads gets an id that never
  // fires, in the app as here — the work it scheduled silently never happens.
  if (timerRefusals.length) throw new Error(`loadExtension: ${timerRefusals.join("; ")}`)

  // From API 9 the app hands an extension the log's QSOs frozen (logCopy.ts),
  // and a write to one throws. A harness that handed them over writable would
  // let an extension pass its own tests and throw inside the app.
  const declared = (definitions[0] as { api?: unknown }).api
  const api = options.api ?? (typeof declared === "number" ? declared : definitions[0].category ? 0 : Infinity)
  const frozenQsos = api >= FROZEN_QSOS_API
  const frozenCopy = <T>(value: T): T => deepFreeze(structuredClone(value))

  return {
    definitions,
    hooks,
    timers,
    categories: () => [...new Set(hooks.map((h) => h.category))].sort(),
    async runHook(category, method, args = {}, runOptions = {}) {
      const matches = hooks.filter((h) => h.category === category && (!runOptions.key || h.key === runOptions.key))
      if (!matches.length) {
        const known = hooks.map((h) => `${h.category}:${h.key}`).join(", ")
        throw new Error(`runHook: no '${category}' hook${runOptions.key ? ` with key '${runOptions.key}'` : ""} — registered: ${known || "none"}`)
      }
      if (matches.length > 1) {
        throw new Error(`runHook: ${matches.length} '${category}' hooks registered (${matches.map((h) => h.key).join(", ")}) — pass { key } to choose`)
      }
      const hook = matches[0].hook
      const member = hook[method]
      if (typeof member !== "function") {
        const methods = Object.keys(hook)
          .filter((k) => typeof hook[k] === "function")
          .join(", ")
        throw new Error(`runHook: '${category}' hook has no '${method}' method — it has: ${methods || "none"}`)
      }
      const ctx = { ...defaultContext, ...options.ctx, ...runOptions.ctx } as HookContext
      if (frozenQsos) {
        const getQsos = ctx.getQsos
        if (getQsos) {
          ctx.getQsos = async (uuid) => {
            const log = await getQsos(uuid)
            return log && frozenCopy(log)
          }
        }
        const sent = (args as { qsos?: unknown } | null)?.qsos
        if (category === "scoring" && Array.isArray(sent)) args = { ...(args as object), qsos: frozenCopy(sent) }
      }
      return await (member as (a: unknown, c: HookContext) => unknown).call(hook, args, ctx)
    },
  }
}

/// Runs a control's `input.transforms` over [text] the way the core's input
/// does (`packages/halo_widgets/lib/src/ref_text_input.dart`'s
/// `RefTransformFormatter`): braced `${n}` placeholders, `g` and `i` flags,
/// two passes so a multi-character paste converges.
export function applyRefTransforms(text: string, transforms: { pattern: string; replacement: string; flags?: string }[]): string {
  const applyOnce = (t: string) => {
    for (const transform of transforms) {
      const regex = new RegExp(transform.pattern, transform.flags ?? "")
      t = t.replace(regex, (...args) => {
        const groups = args.slice(1, -2) as string[]
        return transform.replacement.replace(/\$\{(\d+)\}/g, (_, i) => groups[Number(i) - 1] ?? "")
      })
    }
    return t
  }
  return applyOnce(applyOnce(text))
}

/// What the field holds after [text] is typed one character at a time, the
/// transforms running after each keystroke — the case the end-anchored rules
/// are written for, and one a single paste does not exercise.
export function typeRefText(text: string, transforms: { pattern: string; replacement: string; flags?: string }[]): string {
  let field = ""
  for (const char of text) field = applyRefTransforms(field + char, transforms)
  return field
}

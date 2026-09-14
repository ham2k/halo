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

/// A host call's stand-in answer, by method name (`getSettings`,
/// `dbLookupSelectAll`, `fetch`…). Anything unlisted answers null, which
/// every extension already has to tolerate: `host.secret()` is null in the
/// dev loop, and a lookup table is empty until its data file syncs.
export type HostCallStubs = Record<string, (params: Record<string, unknown>) => unknown>

export interface LoadExtensionOptions {
  hostCalls?: HostCallStubs
  /// Merged over the default context handed to every hook call.
  ctx?: Partial<HookContext>
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

function installKernel(hostCalls: HostCallStubs) {
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
    log: () => {},
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
export async function loadExtension(
  importer: () => Promise<unknown>,
  options: LoadExtensionOptions = {},
): Promise<LoadedExtension> {
  const answer = installKernel(options.hostCalls ?? {})

  const before = captured.length
  const namespace = (await importer()) as object
  const fresh = captured.slice(before)
  if (fresh.length) definitionsByModule.set(namespace, fresh)
  const definitions = fresh.length ? fresh : (definitionsByModule.get(namespace) ?? [])
  if (!definitions.length) {
    throw new Error(
      "loadExtension: the module defined no extension — it must call defineExtension() when imported",
    )
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
  for (const definition of definitions) {
    await definition.onActivation({
      hostCall: answer,
      registerHook: (category: string, params: { hook: unknown; key?: string; priority?: number }) => {
        hooks.push({
          category,
          key: params.key ?? definition.key,
          hook: params.hook as Record<string, unknown>,
        })
      },
    })
  }

  return {
    definitions,
    hooks,
    categories: () => [...new Set(hooks.map((h) => h.category))].sort(),
    async runHook(category, method, args = {}, runOptions = {}) {
      const matches = hooks.filter((h) => h.category === category && (!runOptions.key || h.key === runOptions.key))
      if (!matches.length) {
        const known = hooks.map((h) => `${h.category}:${h.key}`).join(", ")
        throw new Error(`runHook: no '${category}' hook${runOptions.key ? ` with key '${runOptions.key}'` : ""} — registered: ${known || "none"}`)
      }
      if (matches.length > 1) {
        throw new Error(
          `runHook: ${matches.length} '${category}' hooks registered (${matches.map((h) => h.key).join(", ")}) — pass { key } to choose`,
        )
      }
      const hook = matches[0].hook
      const member = hook[method]
      if (typeof member !== "function") {
        const methods = Object.keys(hook).filter((k) => typeof hook[k] === "function").join(", ")
        throw new Error(`runHook: '${category}' hook has no '${method}' method — it has: ${methods || "none"}`)
      }
      const ctx = { ...defaultContext, ...options.ctx, ...runOptions.ctx } as HookContext
      return await (member as (a: unknown, c: HookContext) => unknown).call(hook, args, ctx)
    },
  }
}

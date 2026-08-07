// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// @ham2k/halo-extension-sdk — the surface extensions import. Each extension bundle carries
// its own copy of this module (esbuild bundles it in), while all shared
// state lives on the kernel singleton at globalThis.__polo. That split is
// deliberate: the module-scoped `currentExtensionKey` below is per-bundle, which
// is how host KV calls get namespaced to the extension without extensions having
// to pass their own key around.

import type {
  DeviceLocation,
  FetchOptions,
  FetchResponse,
  JSONValue,
  ExtensionDefinition,
  LookupRow,
  FormDefinition,
  FormField,
  ResultMessage,
  SearchSettingsParams,
  SettingsSearchResult,
  StatusBarMessageParams,
  StatusBarProgressParams,
  StatusBarNoticeParams,
  VersionInfo,
} from "./types"

export * from "./types"
export * from "./i18n"
export * from "./dxcc"
export * from "./location"
export * from "./scoring"
export * from "./activityScoring"
export * from "./activityExports"
export * from "./activityAdifImport"
export * from "./exportNames"
export * from "./referenceActivity"
export * from "./templates"
export * from "./templateContext"

interface KernelApi {
  defineExtension(def: ExtensionDefinition): void
  hostCall(method: string, params: Record<string, unknown>): Promise<unknown>
  invokeLocal(
    category: string,
    method: string,
    args: unknown,
    online?: boolean,
    key?: string | null,
  ): Promise<{ key: string; ok: boolean; value?: unknown; error?: string }[]>
  invokeLocalSequential(
    category: string,
    method: string,
    initialArgs: unknown,
    fold: (args: unknown, hookResult: unknown, hookKey: string) => unknown,
    online?: boolean,
  ): Promise<{ key: string; ok: boolean; value?: unknown; error?: string }[]>
  log(message: string): void
  updateInterpretation(input: string, interpretation: Record<string, unknown>): void
  getAccountKvKey(extensionKey: string): string
  registerDynamicForm(formId: string, extensionKey: string, hookObj: Record<string, unknown>): void
  unregisterDynamicForm(formId: string): void
  host: {
    showForm(form: FormDefinition, state?: Record<string, any>, extensionKey?: string): Promise<Record<string, any> | null>
  }
}

let currentExtensionKey = 'unknown'

/// Privileged host-call functions handed over by the kernel at activation,
/// one per extension this bundle defines ('pota' also defines
/// 'pota-all-parks'). Module-scoped — each bundle carries its own SDK copy,
/// so other bundles can't reach these closures. Identity params are
/// injected by the kernel; the `ns` values this module passes alongside are
/// ignored fallbacks.
const privilegedHostCalls: Record<string, (method: string, params: Record<string, unknown>) => Promise<unknown>> = {}

function kernel(): KernelApi {
  const k = (globalThis as Record<string, unknown>).__polo as KernelApi | undefined
  if (!k) throw new Error('polo kernel not loaded; kernel.js must be evaluated before extension bundles')
  return k
}

/// The bound call for the currently-active extension key, falling back to
/// any this bundle holds (a bundle's sub-extensions share its identity
/// prefix), then to the public kernel surface (which refuses
/// identity-bearing methods — only reachable before activation).
function hostCallFn(): (method: string, params: Record<string, unknown>) => Promise<unknown> {
  const bound = privilegedHostCalls[currentExtensionKey] ?? Object.values(privilegedHostCalls)[0]
  if (bound) return bound
  return (method, params) => kernel().hostCall(method, params)
}

export function defineExtension(def: ExtensionDefinition): void {
  currentExtensionKey = def.key
  kernel().defineExtension({
    ...def,
    onActivation(api) {
      if (typeof api.hostCall === 'function') privilegedHostCalls[def.key] = api.hostCall
      return def.onActivation(api)
    },
  })
}

/// Cross-extension composition inside the runtime (no bridge round-trip).
export const hooks = {
  /// EVERY hook in the category — including the CALLER's own. A hook that
  /// delegates within its own category therefore re-enters itself; use
  /// `invokeOne` when you know which extension you want.
  invokeAll(category: string, method: string, args: unknown, online?: boolean) {
    return kernel().invokeLocal(category, method, args, online)
  },

  /// One named extension's hook.
  ///
  /// Prefer this over filtering `invokeAll`'s results for the key you wanted.
  /// A contest's `generateExport` delegating the ADIF build is exactly the
  /// recursive shape described above, and loops forever through `invokeAll`.
  invokeOne(category: string, key: string, method: string, args: unknown, online?: boolean) {
    return kernel().invokeLocal(category, method, args, online, key)
  },

  /// Like `invokeAll`, but calls hooks one at a time in priority order,
  /// threading each result into the next call's args via `fold` — needed
  /// when later hooks must see earlier hooks' contributions.
  invokeAllSequential(
    category: string,
    method: string,
    initialArgs: unknown,
    fold: (args: unknown, hookResult: unknown, hookKey: string) => unknown,
    online?: boolean,
  ) {
    return kernel().invokeLocalSequential(category, method, initialArgs, fold, online)
  },
}

export const host = {
  async fetch(url: string, options?: FetchOptions): Promise<FetchResponse> {
    return (await hostCallFn()('fetch', { url, ...options })) as FetchResponse
  },

  async kvGet(key: string): Promise<JSONValue | null> {
    return (await hostCallFn()('kvGet', { ns: currentExtensionKey, key })) as JSONValue | null
  },

  /// The device's current GPS position, or null when location is
  /// unavailable, denied, or off — for a command (e.g. WEATHER) that needs a
  /// location fix and has no operation grid to fall back to. May prompt the
  /// user for location permission the first time it's called.
  async getLocation(): Promise<DeviceLocation | null> {
    return (await hostCallFn()('getLocation', {})) as DeviceLocation | null
  },

  /// Read-only build identity — platform, edition, version, build number,
  /// git sha — for a command (REPORT) that needs to say exactly what build it
  /// ran on. `buildNumber` is null on Dev; see VersionInfo.
  async getVersionInfo(): Promise<VersionInfo> {
    return (await hostCallFn()('getVersionInfo', {})) as VersionInfo
  },

  /// The app's settings, read-only: resolved core values (theme, locale,
  /// units, logging toggles, bands/modes, privacy consents, the active
  /// profile's operatorCall, ...) plus every extension's settings group
  /// under `extensions`. Never includes credentials or accounts — those
  /// live in the platform keychain via the account hook system, not in
  /// settings.
  async getSettings(): Promise<Record<string, JSONValue>> {
    return (await hostCallFn()('getSettings', {})) as Record<string, JSONValue>
  },

  /// Writes settings into THIS extension's own group (surfaced to other
  /// readers as `extensions.extension_<key>` in getSettings). The namespace
  /// is injected here — core settings and other extensions' groups are not
  /// writable.
  async setSettings(values: Record<string, JSONValue>): Promise<void> {
    await hostCallFn()('setSettings', { ns: currentExtensionKey, values })
  },

  /// Resolves what a SET/SHOW/HIDE command names against the app's settings.
  ///
  /// The catalog it searches is built from the app's declarative settings
  /// registry, so it reaches every setting the settings screen would show and
  /// respects the same `devMode`, `environment` and `visibleWhen` visibility
  /// rules. None of that data — option lists, current values, commit routing
  /// — exists on this side of the bridge, which is why the settings commands
  /// ask rather than carrying their own list.
  ///
  /// `kind` narrows the search: `'show'`/`'hide'` reach only visibility
  /// toggles and derive their own value from the verb, so `value` is for
  /// `'set'` only. Never rejects: an unmatched query answers `{found: false}`,
  /// which is the normal state of a half-typed command.
  async searchSettings(params: SearchSettingsParams): Promise<SettingsSearchResult> {
    return (await hostCallFn()('searchSettings', { ...params })) as SettingsSearchResult
  },

  async kvSet(key: string, value: JSONValue): Promise<void> {
    await hostCallFn()('kvSet', { ns: currentExtensionKey, key, value })
  },

  async setAccountSession(session: Record<string, string>): Promise<void> {
    const kvKey = kernel().getAccountKvKey(currentExtensionKey)
    await hostCallFn()('setAccountSession', { ns: currentExtensionKey, kvKey, session })
  },

  /// Presents a ResultMessage imperatively — for hooks whose results can't
  /// carry a `userMessage` (e.g. a lookup hitting an auth error). Hooks
  /// that CAN return one (spots posting) should prefer that instead.
  async showMessage(message: ResultMessage): Promise<void> {
    await hostCallFn()('showMessage', { ...message, ns: currentExtensionKey })
  },

  /// Looks up a string from the app's own translations (app/lib/i18n/
  /// {en,es}.i18n.json) by its dot-path key (e.g. "settings.theme.title"),
  /// in whatever locale is currently active — there's no separate
  /// extension-i18n system, this is the same source of truth the rest of
  /// the app reads via its generated `t[key]` lookup. Returns null if the
  /// key doesn't exist or isn't a plain string (e.g. it needs interpolation
  /// params, which this doesn't support).
  async translate(key: string): Promise<string | null> {
    return (await hostCallFn()('translate', { key })) as string | null
  },

  /// Same lookup as `translate`, but for many keys in one bridge round
  /// trip — for a panel with a dozen-plus labels, that's a dozen-plus
  /// fewer JS↔Dart hops than calling `translate` in a loop. Missing/non-
  /// string keys come back as null, same as `translate`.
  async translateAll(keys: string[]): Promise<Record<string, string | null>> {
    return (await hostCallFn()('translateAll', { keys })) as Record<string, string | null>
  },

  /// A build-time secret by name, or null when this build has no such value.
  ///
  /// "Secret" in the sense every cloud platform uses it — real credentials and
  /// plain per-build configuration alike: an award's API key, an OAuth client
  /// id that differs per edition, a token tied to whoever's account pays.
  ///
  /// An extension reads the names that start with its own key — `sota` reads
  /// `SOTA_*`. The kernel binds the caller's identity onto the call, so asking
  /// for anything outside that prefix returns null. See
  /// `app/lib/config/secret_policy.dart` for the two escape hatches.
  ///
  /// Expect null and degrade: a fresh checkout, a fork, and every CI build
  /// without the value configured all have none, and a hook that throws
  /// instead of returning empty takes its whole feature down for them.
  ///
  /// This is a stopgap around a flat map. A real secrets service, and flags to
  /// gate the calls that use these, are follow-up work.
  async secret(name: string): Promise<string | null> {
    return (await hostCallFn()('secret', { name })) as string | null
  },

  async dbLookupSelectOne(category: string, key: string): Promise<LookupRow | null> {
    return (await hostCallFn()('dbLookupSelectOne', { category, key })) as LookupRow | null
  },

  async dbLookupSelectAll(category: string, query: string): Promise<LookupRow[]> {
    return (await hostCallFn()('dbLookupSelectAll', { category, query })) as LookupRow[]
  },

  async dbLookupSelectByLocation(category: string, lat: number, lon: number, delta: number): Promise<LookupRow[]> {
    return (await hostCallFn()('dbLookupSelectByLocation', { category, lat, lon, delta })) as LookupRow[]
  },

  async showForm(form: FormDefinition, state: Record<string, any> = {}): Promise<Record<string, any> | null> {
    return kernel().host.showForm(form, state, currentExtensionKey)
  },

  statusBar: {
    /// A transient single-line message, replacing any prior message under
    /// the same `key`. `key` is automatically namespaced to this extension —
    /// other extensions can't see or clear it.
    async setMessage(params: StatusBarMessageParams): Promise<void> {
      await hostCallFn()('statusBarSetMessage', { ...params, ns: currentExtensionKey })
    },

    /// A transient progress bar under `key`; omit `value` for indeterminate.
    async setProgress(params: StatusBarProgressParams): Promise<void> {
      await hostCallFn()('statusBarSetProgress', { ...params, ns: currentExtensionKey })
    },

    /// Removes the message/progress item under `key`, if any.
    async clear(key: string): Promise<void> {
      await hostCallFn()('statusBarClear', { key, ns: currentExtensionKey })
    },

    /// A richer, dismissible notice, replacing any prior undismissed notice
    /// under the same `key`. Stays in the user's notice history after
    /// dismissal.
    async showNotice(params: StatusBarNoticeParams): Promise<void> {
      await hostCallFn()('statusBarShowNotice', { ...params, ns: currentExtensionKey })
    },

    /// Dismisses the active notice under `key`, if any.
    async dismissNotice(key: string): Promise<void> {
      await hostCallFn()('statusBarDismissNotice', { key, ns: currentExtensionKey })
    },
  },

  log(message: string): void {
    kernel().log(`[${currentExtensionKey}] ${message}`)
  },

  /// Pushes a later CommandInterpretation for the same `input` a `command`
  /// hook's `interpret()` was called with — see CommandHook's doc. One-way,
  /// like `log`: call it, don't await anything back.
  updateInterpretation(input: string, interpretation: Record<string, unknown>): void {
    kernel().updateInterpretation(input, interpretation)
  },
}

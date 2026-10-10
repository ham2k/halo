// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// @ham2k/extension-sdk — the surface extensions import. Each extension bundle carries
// its own copy of this module (esbuild bundles it in), while all shared
// state lives on the kernel singleton at globalThis.__polo. That split is
// deliberate: the module-scoped `currentExtensionKey` below is per-bundle, which
// is how host KV calls get namespaced to the extension without extensions having
// to pass their own key around.

import type {
  DeviceLocation,
  MapBounds,
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
  PanelRadioState,
  PanelRadioSpectrumSet,
  PanelRadioSet,
  PanelRadioTarget,
  PanelRadioResult,
  ExtensionWebSocket,
  WebSocketOptions,
} from "./types.ts"

import { base64ToBytes, bytesToBase64 } from "./base64.ts"
import type { HookCategoryName } from "./hookCategories.ts"
import { adoptExtensionTimers, clearInterval, clearTimeout, setInterval, setTimeout } from "./timers.ts"

export * from "./types.ts"
export * from "./hookCategories.ts"
export * from "./panelScene.ts"
export * from "./i18n.ts"
export * from "./dxcc.ts"
export * from "./location.ts"
export * from "./modes.ts"
export * from "./scoring.ts"
export * from "./contestSummary.ts"
export * from "./segments.ts"
export * from "./activityScoring.ts"
export * from "./activityExports.ts"
export * from "./activityAdifImport.ts"
export * from "./exportNames.ts"
export * from "./exportSettings.ts"
export * from "./referenceActivity.ts"
export * from "./nearby.ts"
export * from "./refTransforms.ts"
export * from "./templates.ts"
export * from "./templateContext.ts"
export * from "./testOperation.ts"

interface KernelApi {
  defineExtension(def: ExtensionDefinition): void
  hostCall(method: string, params: Record<string, unknown>): Promise<unknown>
  invokeLocal(
    category: string,
    method: string,
    args: unknown,
    online?: boolean,
    key?: string | null,
    forRefs?: unknown[] | null,
  ): Promise<{ key: string; ok: boolean; value?: unknown; error?: string }[]>
  invokeLocalSequential(
    category: string,
    method: string,
    initialArgs: unknown,
    fold: (args: unknown, hookResult: unknown, hookKey: string) => unknown,
    online?: boolean,
  ): Promise<{ key: string; ok: boolean; value?: unknown; error?: string }[]>
  log(message: string): void
  registerSocket(listener: (event: Record<string, unknown>) => unknown): number
  socketEvent(socketId: number, eventJson: string): void
  updateInterpretation(input: string, interpretation: Record<string, unknown>): void
  getAccountKvKey(extensionKey: string): string
  registerDynamicForm(formId: string, extensionKey: string, hookObj: Record<string, unknown>): void
  unregisterDynamicForm(formId: string): void
  host: {
    showForm(form: FormDefinition, state?: Record<string, any>, extensionKey?: string): Promise<Record<string, any> | null>
  }
}

let currentExtensionKey = "unknown"

/// Privileged host-call functions handed over by the kernel at activation,
/// one per extension this bundle defines ('pota' also defines
/// 'pota-all-parks'). Module-scoped — each bundle carries its own SDK copy,
/// so other bundles can't reach these closures. Identity params are
/// injected by the kernel; the `ns` values this module passes alongside are
/// ignored fallbacks.
const privilegedHostCalls: Record<string, (method: string, params: Record<string, unknown>) => Promise<unknown>> = {}

function kernel(): KernelApi {
  const k = (globalThis as Record<string, unknown>).__polo as KernelApi | undefined
  if (!k) throw new Error("polo kernel not loaded; kernel.js must be evaluated before extension bundles")
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
    // Called on the author's own object, as onActivation is below, so `this`
    // is the same object in all three: state kept on it at activation is there
    // to stop on hide.
    onShow: def.onShow && (() => def.onShow!()),
    onHide: def.onHide && (() => def.onHide!()),
    onActivation(api) {
      if (typeof api.hostCall === "function") privilegedHostCalls[def.key] = api.hostCall
      adoptExtensionTimers(def.key, currentExtensionKey, api.timers)
      return def.onActivation(api)
    },
  })
}

/// The host's frame limit (`maxWebSocketFrameSize` in
/// packages/halo_extension_host/lib/src/extension_sockets.dart), checked here
/// too so an oversized send throws at the caller instead of failing into a log.
const MAX_FRAME_SIZE = 1024 * 1024

function utf8Length(text: string): number {
  let length = 0
  for (const ch of text) {
    const cp = ch.codePointAt(0)!
    length += cp < 0x80 ? 1 : cp < 0x800 ? 2 : cp < 0x10000 ? 3 : 4
  }
  return length
}

/// `host.webSocket`. [call] is captured once, so a socket's sends go out
/// under the identity that opened it whichever extension is current later.
function openWebSocket(
  call: (method: string, params: Record<string, unknown>) => Promise<unknown>,
  url: string,
  options?: WebSocketOptions,
): ExtensionWebSocket {
  let readyState: 0 | 1 | 2 | 3 = 0
  let protocol = ""
  const failed = (what: string) => (e: unknown) => kernel().log(`webSocket ${what} on ${url} failed: ${e instanceof Error ? e.message : String(e)}`)
  const socket: ExtensionWebSocket = {
    url,
    get readyState() {
      return readyState
    },
    get protocol() {
      return protocol
    },
    onopen: null,
    onmessage: null,
    onerror: null,
    onclose: null,
    send(data: string | ArrayBuffer | ArrayBufferView) {
      if (readyState !== 1) throw new Error("WebSocket is not open")
      let frame: Record<string, unknown>
      if (typeof data === "string") {
        if (data.length > MAX_FRAME_SIZE) throw new Error("WebSocket message too big")
        frame = { data }
      } else {
        const bytes = data instanceof ArrayBuffer ? new Uint8Array(data) : new Uint8Array(data.buffer, data.byteOffset, data.byteLength)
        if (bytes.length > MAX_FRAME_SIZE) throw new Error("WebSocket message too big")
        frame = { binary: bytesToBase64(bytes) }
      }
      call("webSocketSend", { socketId, ...frame }).catch(failed("send"))
    },
    close(code?: number, reason?: string) {
      // Checked here as well as by the host so a bad close throws at the
      // caller, as a browser's does, instead of leaving the socket "closing".
      if (code !== undefined && (!Number.isInteger(code) || (code !== 1000 && (code < 3000 || code > 4999)))) {
        throw new Error("close code must be 1000 or 3000-4999")
      }
      if (reason !== undefined && (typeof reason !== "string" || utf8Length(reason) > 123)) {
        throw new Error("close reason must be a string of at most 123 UTF-8 bytes")
      }
      if (readyState >= 2) return
      const before = readyState
      readyState = 2
      call("webSocketClose", { socketId, ...(code !== undefined ? { code } : {}), ...(reason !== undefined ? { reason } : {}) }).catch((e) => {
        // The host kept the socket, so "closing" would be a state no event
        // ever ends — and would refuse every send on a connection still up.
        if (readyState === 2) readyState = before
        failed("close")(e)
      })
    },
  }
  // A bundle built with this SDK can land in an app older than sockets, whose
  // kernel has no registry: say so, rather than a bare TypeError.
  if (typeof kernel().registerSocket !== "function") throw new Error("host.webSocket needs a newer version of HaLo")
  // Registered before the host is asked to connect, so no event can arrive
  // for an id nothing is listening on.
  const socketId = kernel().registerSocket((event) => {
    switch (event.type) {
      case "open":
        // A close asked for while connecting keeps the socket closing.
        if (readyState !== 0) return
        readyState = 1
        protocol = String(event.protocol ?? "")
        return socket.onopen?.()
      case "message": {
        const data = typeof event.binary === "string" ? base64ToBytes(event.binary).buffer : String(event.data)
        return socket.onmessage?.({ data: data as string | ArrayBuffer })
      }
      case "error":
        return socket.onerror?.({ message: String(event.message ?? "") })
      case "close":
        readyState = 3
        return socket.onclose?.({ code: Number(event.code), reason: String(event.reason ?? ""), wasClean: event.wasClean === true })
    }
  })
  call("webSocketOpen", { socketId, url, ...(options?.protocols ? { protocols: options.protocols } : {}) }).catch((e) => {
    // Refused before any connection existed, so the host will send nothing:
    // the events a browser gives a socket that failed to connect come from here.
    kernel().socketEvent(socketId, JSON.stringify({ type: "error", message: e instanceof Error ? e.message : String(e) }))
    kernel().socketEvent(socketId, JSON.stringify({ type: "close", code: 1006, reason: "", wasClean: false }))
  })
  return socket
}

/// Cross-extension composition inside the runtime (no bridge round-trip).
export const hooks = {
  /// EVERY hook in the category — including the CALLER's own. A hook that
  /// delegates within its own category therefore re-enters itself; use
  /// `invokeOne` when you know which extension you want.
  invokeAll(category: HookCategoryName, method: string, args: unknown, online?: boolean) {
    return kernel().invokeLocal(category, method, args, online)
  },

  /// One named extension's hook.
  ///
  /// Prefer this over filtering `invokeAll`'s results for the key you wanted.
  /// A contest's `generateExport` delegating the ADIF build is exactly the
  /// recursive shape described above, and loops forever through `invokeAll`.
  invokeOne(category: HookCategoryName, key: string, method: string, args: unknown, online?: boolean) {
    return kernel().invokeLocal(category, method, args, online, key)
  },

  /// Like `invokeAll`, but only the hooks of the extensions that answer for one
  /// of [refs] — for each, those holding the strongest `ref:<type>` claim on it
  /// (a `ref:<type>/<code>` prefix beats the bare type) — plus, for
  /// `adifFields`, any whose manifest sets `adifFieldsScope: "always"`.
  /// For a fan-out over programs that must leave out the ones a contact has
  /// nothing to do with, as the full ADIF export does.
  invokeForRefs(category: HookCategoryName, method: string, args: unknown, refs: unknown[], online?: boolean) {
    return kernel().invokeLocal(category, method, args, online, null, refs)
  },

  /// Like `invokeAll`, but calls hooks one at a time in priority order,
  /// threading each result into the next call's args via `fold` — needed
  /// when later hooks must see earlier hooks' contributions.
  invokeAllSequential(
    category: HookCategoryName,
    method: string,
    initialArgs: unknown,
    fold: (args: unknown, hookResult: unknown, hookKey: string) => unknown,
    online?: boolean,
  ) {
    return kernel().invokeLocalSequential(category, method, initialArgs, fold, online)
  },
}

export const host = {
  async listRadios(): Promise<PanelRadioState[]> {
    return (await hostCallFn()("listRadios", {})) as PanelRadioState[]
  },
  async readRadio(id?: string): Promise<PanelRadioState | null> {
    return (await hostCallFn()("readRadio", { ...(id ? { id } : {}) })) as PanelRadioState | null
  },
  async setRadioConnection(args: PanelRadioTarget & { connected: boolean }): Promise<PanelRadioResult> {
    return (await hostCallFn()("setRadioConnection", { ...args })) as PanelRadioResult
  },
  /** Sets frequency, mode, power, keyer speed, tuner, passband and antennas. Needs `requiresRadioWrite` and extension API 7. */
  async setRadio(args: PanelRadioSet): Promise<PanelRadioResult> {
    return (await hostCallFn()("setRadio", { ...args })) as PanelRadioResult
  },
  /** @deprecated `setRadio`'s name through extension API 6, still answered by newer hosts. */
  async tuneRadio(args: PanelRadioSet): Promise<PanelRadioResult> {
    return (await hostCallFn()("tuneRadio", { ...args })) as PanelRadioResult
  },
  /** Changes the radio's scope. Needs `requiresRadioWrite` and extension API 6; the result's state reports what the radio took. */
  async setRadioSpectrum(args: PanelRadioSpectrumSet): Promise<PanelRadioResult> {
    return (await hostCallFn()("setRadioSpectrum", { ...args })) as PanelRadioResult
  },
  /** Keys `text` on the logging radio's key, as the keyer area does. Needs `requiresRadioWrite` and extension API 7. */
  async sendRadioCw(args: PanelRadioTarget & { text: string }): Promise<PanelRadioResult> {
    return (await hostCallFn()("sendRadioCw", { ...args })) as PanelRadioResult
  },
  /** Plays one of `keying.voiceMemories` once — never repeating. Needs `requiresRadioWrite` and extension API 7. */
  async playRadioVoice(args: PanelRadioTarget & { memory: number }): Promise<PanelRadioResult> {
    return (await hostCallFn()("playRadioVoice", { ...args })) as PanelRadioResult
  },
  /** Keys or unkeys the logging radio's PTT through the app's own latch. Needs `requiresRadioWrite` and extension API 7. */
  async setRadioPtt(args: PanelRadioTarget & { on: boolean }): Promise<PanelRadioResult> {
    return (await hostCallFn()("setRadioPtt", { ...args })) as PanelRadioResult
  },
  /** Stops all CW, voice and PTT the app is keying, as Escape does. Needs `requiresRadioWrite` and extension API 7. */
  async stopRadioTransmit(args: PanelRadioTarget): Promise<PanelRadioResult> {
    return (await hostCallFn()("stopRadioTransmit", { ...args })) as PanelRadioResult
  },
  async fetch(url: string, options?: FetchOptions): Promise<FetchResponse> {
    return (await hostCallFn()("fetch", { url, ...options })) as FetchResponse
  },

  /// A WebSocket to a host the manifest's `webSockets` lists — see
  /// `ExtensionWebSocket`. Returns at once, connecting, as a browser's does.
  webSocket(url: string, options?: WebSocketOptions): ExtensionWebSocket {
    return openWebSocket(hostCallFn(), url, options)
  },

  async kvGet(key: string): Promise<JSONValue | null> {
    return (await hostCallFn()("kvGet", { ns: currentExtensionKey, key })) as JSONValue | null
  },

  /// The device's current GPS position, or null when location is
  /// unavailable, denied, or off — for a command (e.g. WEATHER) that needs a
  /// location fix and has no operation grid to fall back to. May prompt the
  /// user for location permission the first time it's called.
  async getLocation(): Promise<DeviceLocation | null> {
    return (await hostCallFn()("getLocation", {})) as DeviceLocation | null
  },

  /// Read-only build identity — platform, edition, version, build number,
  /// git sha — for a command (REPORT) that needs to say exactly what build it
  /// ran on. `buildNumber` is null on Dev; see VersionInfo.
  async getVersionInfo(): Promise<VersionInfo> {
    return (await hostCallFn()("getVersionInfo", {})) as VersionInfo
  },

  /// The app's settings, read-only: resolved core values (theme, locale,
  /// units, logging toggles, bands/modes, privacy consents, the active
  /// profile's operatorCall, ...) plus every extension's settings group
  /// under `extensions`. Never includes credentials or accounts — those
  /// live in the platform keychain via the account hook system, not in
  /// settings.
  async getSettings(): Promise<Record<string, JSONValue>> {
    return (await hostCallFn()("getSettings", {})) as Record<string, JSONValue>
  },

  /// Writes settings into THIS extension's own group (surfaced to other
  /// readers as `extensions.extension_<key>` in getSettings). The namespace
  /// is injected here — core settings and other extensions' groups are not
  /// writable.
  async setSettings(values: Record<string, JSONValue>): Promise<void> {
    await hostCallFn()("setSettings", { ns: currentExtensionKey, values })
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
    return (await hostCallFn()("searchSettings", { ...params })) as SettingsSearchResult
  },

  async kvSet(key: string, value: JSONValue): Promise<void> {
    await hostCallFn()("kvSet", { ns: currentExtensionKey, key, value })
  },

  async setAccountSession(session: Record<string, string>): Promise<void> {
    const kvKey = kernel().getAccountKvKey(currentExtensionKey)
    await hostCallFn()("setAccountSession", { ns: currentExtensionKey, kvKey, session })
  },

  /// Presents a ResultMessage imperatively — for hooks whose results can't
  /// carry a `userMessage` (e.g. a lookup hitting an auth error). Hooks
  /// that CAN return one (spots posting) should prefer that instead.
  async showMessage(message: ResultMessage): Promise<void> {
    await hostCallFn()("showMessage", { ...message, ns: currentExtensionKey })
  },

  /// Looks up a string from the app's own translations (app/lib/i18n/
  /// {en,es}.i18n.json) by its dot-path key (e.g. "settings.theme.title"),
  /// in whatever locale is currently active — there's no separate
  /// extension-i18n system, this is the same source of truth the rest of
  /// the app reads via its generated `t[key]` lookup. Returns null if the
  /// key doesn't exist or isn't a plain string (e.g. it needs interpolation
  /// params, which this doesn't support).
  async translate(key: string): Promise<string | null> {
    return (await hostCallFn()("translate", { key })) as string | null
  },

  /// Same lookup as `translate`, but for many keys in one bridge round
  /// trip — for a panel with a dozen-plus labels, that's a dozen-plus
  /// fewer JS↔Dart hops than calling `translate` in a loop. Missing/non-
  /// string keys come back as null, same as `translate`.
  async translateAll(keys: string[]): Promise<Record<string, string | null>> {
    return (await hostCallFn()("translateAll", { keys })) as Record<string, string | null>
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
    return (await hostCallFn()("secret", { name })) as string | null
  },

  async dbLookupSelectOne(category: string, key: string): Promise<LookupRow | null> {
    return (await hostCallFn()("dbLookupSelectOne", { category, key })) as LookupRow | null
  },

  /// [subCategory], when given, filters IN THE QUERY rather than after —
  /// which matters because of `limit`: a common word ("trail") can match
  /// thousands of rows worldwide, and the query only returns the first 100
  /// it happens to find. Filtering by subCategory afterward, in the caller,
  /// can end up filtering an already-truncated set down to nothing even
  /// though a real match exists — POTA, which scopes by the caller's own
  /// DXCC entity, passes it here instead, so the limit applies to the
  /// already-narrowed set. SOTA scopes by entity too but needs a PREFIX
  /// match ([subCategory] here is exact-equals only), so it still filters
  /// after the fact and is exposed to the same truncation bug this exists
  /// to avoid.
  ///
  /// [activeOnly] drops rows whose `flags` is explicitly 0 — the convention a
  /// data-file mapper follows for a reference its program has RETIRED — and is
  /// in the query for the same `limit` reason: retirements cluster (a program
  /// delists a whole class at once), so a search for a word that class shares
  /// can fill the cap with retired rows and leave the live matches just past
  /// it. A row that never said (`flags` null) is NOT retired and survives.
  async dbLookupSelectAll(category: string, query: string, subCategory?: string, activeOnly?: boolean): Promise<LookupRow[]> {
    return (await hostCallFn()("dbLookupSelectAll", { category, query, subCategory, activeOnly })) as LookupRow[]
  },

  async dbLookupSelectByLocation(category: string, lat: number, lon: number, delta: number, activeOnly?: boolean): Promise<LookupRow[]> {
    return (await hostCallFn()("dbLookupSelectByLocation", { category, lat, lon, delta, activeOnly })) as LookupRow[]
  },

  /// Every row inside `bounds`, nearest its centre first, at most `limit`
  /// (default 500, never past 1000). `west` past `east` is a box across the
  /// antimeridian. Only an app that sends `SuggestArgs.bounds` answers this
  /// call — so call it only when `bounds` arrived, as `nearbyLookupRows` does.
  async dbLookupSelectInBounds(category: string, bounds: MapBounds, options: { activeOnly?: boolean; limit?: number } = {}): Promise<LookupRow[]> {
    return (await hostCallFn()("dbLookupSelectInBounds", { category, ...bounds, ...options })) as LookupRow[]
  },

  async showForm(form: FormDefinition, state: Record<string, any> = {}): Promise<Record<string, any> | null> {
    return kernel().host.showForm(form, state, currentExtensionKey)
  },

  statusBar: {
    /// A transient single-line message, replacing any prior message under
    /// the same `key`. `key` is automatically namespaced to this extension —
    /// other extensions can't see or clear it.
    async setMessage(params: StatusBarMessageParams): Promise<void> {
      await hostCallFn()("statusBarSetMessage", { ...params, ns: currentExtensionKey })
    },

    /// A transient progress bar under `key`; omit `value` for indeterminate.
    async setProgress(params: StatusBarProgressParams): Promise<void> {
      await hostCallFn()("statusBarSetProgress", { ...params, ns: currentExtensionKey })
    },

    /// Removes the message/progress item under `key`, if any.
    async clear(key: string): Promise<void> {
      await hostCallFn()("statusBarClear", { key, ns: currentExtensionKey })
    },

    /// A richer, dismissible notice, replacing any prior undismissed notice
    /// under the same `key`. Stays in the user's notice history after
    /// dismissal.
    async showNotice(params: StatusBarNoticeParams): Promise<void> {
      await hostCallFn()("statusBarShowNotice", { ...params, ns: currentExtensionKey })
    },

    /// Dismisses the active notice under `key`, if any.
    async dismissNotice(key: string): Promise<void> {
      await hostCallFn()("statusBarDismissNotice", { key, ns: currentExtensionKey })
    },
  },

  log(message: string): void {
    kernel().log(`[${currentExtensionKey}] ${message}`)
  },

  /// Browser-shaped timers, on real time, bound to this extension and held to
  /// its budget (docs/extensions/README.md, "Timers"). A bundle built for
  /// extension API 3 reaches these from a plain `setTimeout` too, npm
  /// dependencies included (sdk/src/timers.ts).
  setTimeout,
  setInterval,
  clearTimeout,
  clearInterval,

  /// Pushes a later CommandInterpretation for the same `input` a `command`
  /// hook's `interpret()` was called with — see CommandHook's doc. One-way,
  /// like `log`: call it, don't await anything back.
  updateInterpretation(input: string, interpretation: Record<string, unknown>): void {
    kernel().updateInterpretation(input, interpretation)
  },
}

# HaLo Next Extensions

Extensions are TypeScript modules that give HaLo its domain knowledge:
activity programs (POTA, SOTA…), contests, callsign lookup services, spot
sources, exporters, and eventually sync transports and commands. The Flutter
core knows nothing about any of them — it invokes **hooks** and renders
**declarative UI contributions** (see [DESIGN.md](../../DESIGN.md) §2–§5).

- **[hooks.md](hooks.md)** — reference for every hook category.

## Anatomy of an extension

An extension is one directory under `extensions/` with a `src/index.ts` that
calls `defineExtension`:

```ts
import { defineExtension, host } from "@ham2k/polo-sdk"

defineExtension({
  key: 'pota',                 // unique, stable; namespaces KV storage
  name: 'Parks on the Air',
  version: '0.0.1',
  onActivation({ registerHook }) {
    registerHook('lookup', { hook: LookupHandler, priority: 50 })
    registerHook('ref:pota', { hook: RefHandler, key: 'pota' })
  },
})
```

Rules of the road:

- `defineExtension` only **registers** the definition. Activation happens
  after every bundle is evaluated (the host calls `__polo.activateAll()`),
  so declaration order inside your bundle never matters.
- Hooks are **pure functions of their arguments plus the host API** — no
  global app state, no UI. Everything in and out is JSON.
- A hook that throws is isolated: the error is reported per-source and other
  extensions are unaffected. A hook that hangs is timed out by the host.
- Each bundle carries its own copy of the SDK; shared state lives only in
  the kernel singleton (`globalThis.__polo`).

## The host API

Available via `import { host } from "@ham2k/polo-sdk"`:

| Function | Purpose |
|---|---|
| `host.fetch(url, options?)` | HTTPS requests, executed by the Dart host. Returns `{status, body}`. Per-extension domain allowlists are planned. |
| `host.kvGet(key)` / `host.kvSet(key, value)` | Key-value storage, automatically namespaced to your extension (currently in-memory; keychain-backed persistence planned for credentials). |
| `host.log(message)` | Log line, prefixed with your extension key, visible in the app console. |

Cross-extension composition (calling other extensions' hooks *inside* the
runtime, without a bridge round-trip):

```ts
import { hooks } from "@ham2k/polo-sdk"
const entries = await hooks.invokeAll('adifFields', 'fieldsForOneQSO', { qso, operation })
// entries: [{key, ok, value|error}, ...] in priority order
```

Planned host APIs from the design (not yet implemented): `host.lookups`
(offline reference datasets), `host.qsos`/`host.operations` (indexed log
queries), `host.events` (subscriptions), `host.secrets` (keychain).

## Build and dev loop

```sh
cd extensions
npm install
npm run typecheck        # tsc over the whole workspace
npm run build            # esbuild bundles → app/assets/extensions/ + index.json
```

Bundles are single-file IIFEs targeting ES2020 (QuickJS / JavaScriptCore).
npm dependencies — including the published `@ham2k/lib-*` packages — bundle
in as-is; `@ham2k/lib-operation-data` and `lib-format-tools` are already used
this way.

Adding an extension: create `extensions/<category>/<name>/src/index.ts`, add
an entry to `bundles` in `extensions/build.mjs`, rebuild, and restart the app
(bundles are baked into assets; runtime download/update channels come later).

Integration testing without Flutter: see
`packages/halo_extension_host/test/extension_host_test.dart`, which boots the
real JS engine against the built kernel plus inline extension source. For
pure hook logic, plain vitest against fixture QSOs works — hooks have no
dependencies beyond the SDK.

## Lifecycle and the bridge, briefly

The Dart `ExtensionHost` (packages/halo_extension_host) runs the JS engine on
a background isolate. It evaluates `kernel.js` first, then every extension
bundle listed in `index.json`, then activates all extensions. Hook calls
cross the bridge as JSON messages with per-call timeouts; host calls
(`fetch`, KV) travel the other way. The app-facing surface is
`ExtensionService` (app/lib/services/extension_service.dart), which shapes
raw hook invocations into domain calls (merged lookups, control descriptors,
ref decoration).

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
import { defineExtension, host } from "@ham2k/halo-extension-sdk"

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

Available via `import { host } from "@ham2k/halo-extension-sdk"`:

| Function | Purpose |
|---|---|
| `host.fetch(url, options?)` | HTTPS requests, executed by the Dart host. Returns `{status, body}`. Per-extension domain allowlists are planned. The host stamps HaLo's canonical `User-Agent` on every call — don't set your own unless your extension declares `allowUserAgentOverride` ([docs/design/network.md](../design/network.md)). |
| `host.kvGet(key)` / `host.kvSet(key, value)` | Key-value storage, automatically namespaced to your extension (currently in-memory; keychain-backed persistence planned for credentials). |
| `host.statusBar.setMessage(params)` / `.setProgress(params)` | Transient single-line message or progress bar in the app's footer, keyed and namespaced to your extension the same way as `kvGet`/`kvSet`. |
| `host.statusBar.clear(key)` | Removes a message/progress item you posted. |
| `host.statusBar.showNotice(params)` / `.dismissNotice(key)` | A richer, dismissible notice (markdown body, optional `link`/`dialog` action buttons) shown as a "post-it" over the footer and kept in the user's Settings → About → Recent Notices history. |
| `host.log(message)` | Log line, prefixed with your extension key, visible in the app console. |

Cross-extension composition (calling other extensions' hooks *inside* the
runtime, without a bridge round-trip):

```ts
import { hooks } from "@ham2k/halo-extension-sdk"
const entries = await hooks.invokeAll('adifFields', 'fieldsForOneQSO', { qso, operation })
// entries: [{key, ok, value|error}, ...] in priority order
```

Planned host APIs from the design (not yet implemented): `host.lookups`
(offline reference datasets), `host.qsos`/`host.operations` (indexed log
queries), `host.events` (subscriptions), `host.secrets` (keychain).

## Internationalization (i18n)

Extensions running in the QuickJS isolate have access to the shared `i18next` library (pre-loaded inside the kernel to avoid duplicate bundle bloat). 

### Exposing Translations
You can define localized strings in your extension as a JSON/JS map and load them using the SDK's `createTranslator` helper alongside the `locale` passed in the `HookContext`:

```ts
import { createTranslator, HookContext } from "@ham2k/halo-extension-sdk"

const resources = {
  en: {
    translation: {
      name: "Parks on the Air"
    }
  },
  es: {
    translation: {
      name: "Parques en el Aire"
    }
  }
}

export const RefHandler = {
  decorateRef: async ({ ref }, ctx: HookContext) => {
    // Initialize the translator for the current invocation's locale
    const t = createTranslator(resources, ctx.locale || 'en')
    return {
      ...ref,
      name: t('name')
    }
  }
}
```

By resolving locale-aware keys inside extension logic, you ensure that dynamically rendered labels, exporters, or lookup details match the user's active application language seamlessly.

## Build and dev loop

```sh
cd extensions
npm install
npm run typecheck        # tsc over the whole workspace
npm run build            # esbuild bundles → app/assets/extensions/ + index.json
```

Bundles are single-file IIFEs targeting ES2020 (QuickJS / JavaScriptCore).
npm dependencies — including the published `@ham2k/lib-*` packages — bundle
in as-is; `@ham2k/lib-operation-data` and `@ham2k/lib-format-tools` are already used
this way.

### Number Formatting in Extensions

Any user-facing counts, scores, or statistics returned by extensions (such as hook values, labels, summaries, or descriptions) **must use thousands separators** for readability. Extensions must import and use the formatting tools from `@ham2k/lib-format-tools`:

```typescript
import { fmtInteger } from "@ham2k/lib-format-tools"

// Example: formatting a tally count
const label = `${fmtInteger(tally.total)} QSOs`
const summary = fmtInteger(tally.total)
```

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

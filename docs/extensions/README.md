# HaLo Next Extensions

Extensions are TypeScript modules that give HaLo its domain knowledge:
activity programs (POTA, SOTA…), contests, callsign lookup services, spot
sources, exporters, and eventually sync transports and commands. The Flutter
core knows nothing about any of them — it invokes **hooks** and renders
**declarative UI contributions** (see [DESIGN.md](../../DESIGN.md) §2–§5).

- **[hooks.md](hooks.md)** — reference for every hook category.
- **[templates.md](templates.md)** — the templating engine and the values a
  template can name, for panels, filenames and ADIF fields.
- **[cli.md](cli.md)** — `halo-ext`, which runs these hooks outside the app.

## Anatomy of an extension

An extension is one directory under `extensions/` with two required pieces:
a static `manifest.json` declaring its public identity, and a `src/index.ts`
that imports it and calls `defineExtension`:

```json
// manifest.json — everything knowable without running the code
{
  "key": "pota",               // unique, stable; namespaces KV storage
  "name": "Parks on the Air",
  "shortName": "POTA",
  "version": "0.0.1",
  "description": "Park references, spots, and activation logging",
  "category": "activity",      // panel grouping: activity | contest | lookup |
                               // spots; omit for core (always-on). A value the
                               // panel doesn't know falls under "Other"
                               // (app/lib/views/extensions_panel.dart).
  "enabledByDefault": true,
  "experiments": ["gato"],     // rare. Any experiments.yaml KEY; availability
                               // gate: hidden from the panel and
                               // never loaded unless EVERY listed experiment
                               // (app/experiments.yaml) is enabled; the user's
                               // enable/disable choice is kept while hidden.
  "icon": "pine-tree",         // MDI icon name
  "accentColor": "#068541",    // brand accent, #RRGGBB
  "keywords": ["parks", "activation", "hunting"],
  "hooks": ["activity", "dataFile", "lookup", "ref:pota", "spots"],
  "domains": ["api.pota.app", "pota.app"],  // host.fetch allowlist
  "translations": { "es": { "description": "Referencias de parques…" } }
}
```

### Secrets

`host.secret(name)` reads a build-time value: "secrets" in the sense every cloud
platform uses it — real credentials and plain per-build configuration alike. An
award's API key is one; so is an OAuth client id that differs per build edition.

**An extension sees a secret when its NAME starts with the extension's key.**
`sota` reads `SOTA_OAUTH_CLIENT_ID_PROD`, `tota` reads `TOTA_API_KEY`. That
convention covers every secret in the app today, so nothing needs declaring
anywhere; name a new one after the extension that uses it and it just works.

Two escape hatches exist in `app/lib/config/secret_policy.dart` for values that
belong to no single extension — `sharedSecrets` (any extension may read) and
`grants` (a named list of extension keys). Both are empty. The policy is
committed code rather than a manifest field on purpose: an extension asking for
access is not the same as being granted it, and one reviewable list beats a
claim spread across thirty manifests.

The host resolves each extension's readable subset once, at load, and holds only
that. The kernel stamps the caller's identity onto the call, so an extension can
reach neither another's values nor a name outside its own prefix.

Values come from the environment (`mise.local.toml` locally, the CI env in
`app_dist/ci/*.sh`) into a gitignored `app/lib/config/secrets.dart`. App code
reads that map directly. See `secrets.dart.example`.

**Expect null and degrade.** A fresh checkout, a fork, and every build without
the value configured all have none. A hook that throws instead of returning
empty takes its whole feature down for them. Where a sensible default exists,
prefer it: SOTA keeps its per-edition OAuth redirect URLs in code as a
fallback, so a fresh checkout can still log in to SOTAWatch.

**Don't log a URL that carries one.** Some programs take their key as a query
parameter, and `debugPrint` is not stripped from release builds — the data-file
downloader redacts query strings for exactly this reason
(`redactUrlForLog`, in halo_core's `data_file_parsing.dart`). An extension that
logs its own fetch URLs
has to do the same.

### Testing anything that fetches

`ExtensionHost.start` takes an `httpClient`. Supply one (a `MockClient` from
`package:http/testing.dart`) and `host.fetch` goes out over it instead of the
network — while the manifest allowlist, the https requirement, the canonical
User-Agent and both timeouts still run, because the seam sits below them.
Supplying a client forces in-process mode, since a client cannot cross an
isolate boundary.

`spot_network_test.dart` is the worked example: feeds, spot posting, and a check
that an undeclared domain is still blocked through the stub.

This flat map is a stopgap — see below.

### 🔜 Planned: a secrets service, and flags to gate external calls

Two related pieces of infrastructure, agreed 2026-07-26 while porting the
activities that need keys.

**A secrets service.** `host.secret()` is deliberately minimal: one accessor
over a flat const map, with scoping by declared name and nothing else. It wants
replacing with somewhere secrets are registered, described, scoped and audited —
including knowing which are real credentials and which are plain configuration,
a distinction the flat map does not carry.

The open question worth settling first is whether user-supplied credentials
(`fieldType: 'secret'`, the `account` hook) and build-time values should share
one service or stay separate — they have different lifetimes, different storage
(keychain vs. compiled-in) and different failure modes, but an extension author
currently has to learn both.

**Flags gating external API calls.** app-polo already does this — every
network-touching activity hook starts with a check like

```js
if (GLOBAL?.flags?.services?.wwbota === false) return []
```

(see `src/extensions/activities/wwbota/WWBOTAExtension.js` and its siblings).
HaLo has a flags service in `app/lib/services/flags_service.dart` but nothing
reaching extensions. The point is being able to turn off one program's spot feed
or spot posting remotely — when an award's API breaks, starts rate-limiting, or
has to be pulled — without shipping a build. That argues for the check living in
the host rather than in each extension's own code, so an extension cannot forget
it and a flag cannot be ignored.

Worth reading first: this file, `hooks.md`, `docs/design/activities.md` §3.4,
and `app/lib/services/flags_service.dart`.

```ts
import { defineExtension, host } from "@ham2k/halo-extension-sdk"
import manifest from "../manifest.json" with { type: "json" }

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook('lookup', { hook: LookupHandler, priority: 50 })
    registerHook('ref:pota', { hook: RefHandler, key: 'pota' })
  },
})
```

The manifest is the **single source** for this metadata: the bundle spreads
it into `defineExtension`, and `build.mjs` reads it to produce
`index.json` for the Dart host — which must list even *disabled*
extensions, whose bundles are never evaluated, so the metadata has to be
readable without running any JS. The build fails if a manifest's `key`
doesn't match its bundle entry. `hooks` is declarative (documentation and
tooling); the kernel still learns the actual hooks from `registerHook`.

Rules of the road:

- `defineExtension` only **registers** the definition. Activation happens
  after every bundle is evaluated (the host calls `__polo.activateAll()`),
  so declaration order inside your bundle never matters.
- Hooks are **pure functions of their arguments plus the host API** — no
  global app state, no UI. Everything in and out is JSON.
- A hook that throws is isolated: the error is reported per-source and other
  extensions are unaffected. A hook that **hangs** is weaker — the host times
  out the whole fan-out, not your hook, because the runtime answers a fan-out
  with a single call and nothing in it can be cancelled. A caller that opts
  into partial results keeps whatever the other hooks returned and is told
  which ones went quiet and which answered with an error, as separate lists
  (the Spots Panel names both to the operator); every other caller gets an
  error and no results at all. So a hook with an optional request to make
  should bound it — see `host.fetch`'s `timeout` — rather than leave the
  category's whole budget resting on somebody else's server.
- Each bundle carries its own copy of the SDK; shared state lives only in
  the kernel singleton (`globalThis.__polo`).

## The host API

Available via `import { host } from "@ham2k/halo-extension-sdk"`:

| Function | Purpose |
|---|---|
| `host.fetch(url, options?)` | HTTPS requests, executed by the Dart host. Returns `{status, body}`. Per-extension domain allowlists are planned. The host stamps HaLo's canonical `User-Agent` on every call — don't set your own unless your extension declares `allowUserAgentOverride` ([docs/design/network.md](../design/network.md)). `options.timeout` (ms) bounds the whole request, and is clamped downward only — you may declare a request not worth the host's default wait, not award yourself a longer one. Worth setting on anything optional, per the hanging-hook note above. |
| `host.kvGet(key)` / `host.kvSet(key, value)` | Key-value storage, automatically namespaced to your extension (currently in-memory; keychain-backed persistence planned for credentials). |
| `host.statusBar.setMessage(params)` / `.setProgress(params)` | Transient single-line message or progress bar in the app's footer, keyed and namespaced to your extension the same way as `kvGet`/`kvSet`. |
| `host.statusBar.clear(key)` | Removes a message/progress item you posted. |
| `host.statusBar.showNotice(params)` / `.dismissNotice(key)` | A richer, dismissible notice (markdown body, optional `link`/`dialog` action buttons) shown as a "post-it" over the footer and kept in the user's Settings → About → Recent Notices history. |
| `host.getVersionInfo()` | Read-only build identity: platform, edition, version, versionName, buildNumber, gitSha. `buildNumber` is null on Dev, where the compiled-in number is the last release's rather than the running build's. |
| `host.log(message)` | Log line, prefixed with your extension key, visible in the app console. |

### What the JS runtime does NOT have

Native builds run **QuickJS-NG**, which is ECMA-262 only. There is no
ECMA-402: **`Intl` is undefined**. Verified against the engine, not inferred.

The trap is that the fallbacks do not throw. `toLocaleString`,
`toLocaleTimeString` and friends all exist and all **silently ignore a
`timeZone` option**, returning host-local time instead. On a machine that
happens to sit in the requested zone the result looks perfectly right, so the
bug is invisible to whoever wrote it and shows up only for a user somewhere
else. Number and date formatting are host-locale-shaped for the same reason —
`ctx.locale` tells you the app's locale, but nothing in the runtime will
format *for* it.

Web builds run on the browser's engine, which **does** have full `Intl`. So
code that reaches for it works in a web build and is quietly wrong in every
native one — the worst possible split, and the reason to treat `Intl` as
absent everywhere.

There are also **no timers**: `setTimeout` and `setInterval` are simply not
defined. Promises work — the host pumps the job queue — but nothing that
needs the clock to fire does. A timeout raced in JS therefore doesn't merely
fail to fire, it throws `ReferenceError` out of your hook. Bound a request
with `host.fetch`'s own `timeout` option, which the host enforces, and let
the host's periodic triggers (a panel's `tick`) be your clock.

Work in UTC and do the arithmetic yourself (`extensions/sdk/src/
templateContext.ts` slices `toISOString()` for its date and time values — a
worked example), or hand the raw value to the host and let Dart format it.
Anything that has to be shown in a real zone belongs on the Dart side, which
has a zone database — the Clock pane is native for exactly this reason. (The
Weather pane is native for a different one, and needs no zone database: it
labels its hours from the offset the forecast reports.)

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

## Turning data into text

Panel documents, export filenames and ADIF free-text fields are TEMPLATES
over one shared vocabulary — see **[templates.md](templates.md)**. The engine
(`liquidjs`) lives in the kernel like `i18next`, so a bundle that renders
text carries only the wrapper. Reach it through the SDK's `renderTemplate` /
`templateContext`, never by constructing a `Liquid` yourself: the wrapper
owns the options, and UTC is one of them.

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

To exercise a hook by hand — against the real API, with the real bundles, and
without launching the app — use `halo-ext` ([cli.md](cli.md)):

```sh
mise run ext -- --only pota ref pota US-1234
```

## Lifecycle and the bridge, briefly

The Dart `ExtensionHost` (packages/halo_extension_host) runs the JS engine on
a background isolate. It evaluates `kernel.js` first, then every extension
bundle listed in `index.json`, then activates all extensions. Hook calls
cross the bridge as JSON messages with per-call timeouts; host calls
(`fetch`, KV) travel the other way. The app-facing surface is
`ExtensionService` (app/lib/services/extension_service.dart), which shapes
raw hook invocations into domain calls (merged lookups, control descriptors,
ref decoration).

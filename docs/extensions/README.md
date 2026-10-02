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
- **[development.md](development.md)** — the dev loop: rebuild on save, and
  reload one extension in a running app without restarting it.
- **[distribution.md](distribution.md)** — the `.h2kext` bundle format,
  packaging an extension, and installing one someone else made.

Those are the docs for working **in this repo**. An extension built outside it
gets the same references inside `@ham2k/extension-sdk` — `AGENTS.md`, `docs/`
and the worked `samples/` (`extensions/samples/k2hrc-*` here), all pinned to
that version — and starts with
`npx -p @ham2k/extension-tools h2kext-init <callsign>-<name>` ([distribution.md](distribution.md)).

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
  "description": "Activate and chase parks worldwide; spots on pota.app",
  "category": "activity",      // panel grouping: activity | contest | lookup |
                               // spots; omit for core (always-on). A value the
                               // panel doesn't know falls under "Other"
                               // (app/lib/views/extensions_panel.dart).
  "enabledByDefault": true,      // built-ins only: whether the app ships it
                               // switched on. The packer refuses it in a
                               // distributed bundle, where the operator's
                               // having installed it IS the answer.
  "experiments": ["keyer"],    // rare. Any experiments.yaml KEY; availability
                               // gate: hidden from the panel and
                               // never loaded unless EVERY listed experiment
                               // (app/experiments.yaml) is enabled; the user's
                               // enable/disable choice is kept while hidden.
  "icon": "pine-tree",         // MDI icon name
  "accentColor": "#068541",    // brand accent, #RRGGBB
  "keywords": ["parks", "activation", "hunting"],
  "hooks": ["activity", "dataFile", "lookup", "ref:pota", "spots"],
  "adifFieldsScope": "always", // rare. The full ADIF export asks this
                               // extension's adifFields about EVERY contact,
                               // not only those carrying a reference it
                               // handles (hooks.md, `adifFields`).
  "domains": ["api.pota.app", "pota.app"],  // host.fetch allowlist
  "webSockets": ["stream.example.com"],     // host.webSocket allowlist, rare;
                               // see "WebSockets" below
  "relevance": { "entities": ["K", "VE"] }, // where, when and for whom it is
                               // relevant; omit for worldwide (see below)
  "translations": { "es": { "description": "Referencias de parques…" } }
}
```

The app builds in only its core extensions; every other extension is a
catalog bundle, some of them pre-loaded — see
[distribution.md](distribution.md#pre-loaded-extensions).

`relevance` says where, when and for whom the extension matters. The catalog
ranks its listing by it for the operator's own callsign — and the Extensions
panel's Catalog section shows the catalog's rows in that order — while
nothing hides an extension over it. The build index carries it for the
catalog's use; the panel does not rank the app's own extensions by it.

Its four geographic lists (`entities`, `countries`, `continents`,
`ituRegions`) are allowlists: a missing or empty list does not gate, values
within a list are ORed, and the lists are ANDed; case is the matcher's job,
not the author's. They are the geo keys of HaLo's notices, rule for rule.
`dates` lists the UTC days the extension's events start (`YYYY-MM-DD`), and
`interests` what an operator has to be into for it to matter; neither takes
part in the geographic match. The packer's rules for all six are in
[distribution.md](distribution.md).

### Secrets

`host.secret(name)` reads a build-time value: "secrets" in the sense every cloud
platform uses it — real credentials and plain per-build configuration alike.

**No extension reads one today**, and that is the useful thing to know before
reaching for it. An award's API key and an OAuth client id both used to come
through here, and both moved into the extension that uses them as ordinary
constants: a catalog bundle is a zip anyone may download, so a value inside one
is published whatever the store around it claims, and a native app is a public
client (RFC 8252) with no client secret to protect in the first place. Reach
for `host.secret()` only for a value that is genuinely confidential AND
genuinely reaches the client — and if both are true, consider whether the call
belongs on a Ham2K endpoint that holds the key instead.

**An extension sees a secret when its NAME starts with the extension's key.**
`sota` reads `SOTA_OAUTH_CLIENT_ID_PROD`, `tota` reads `TOTA_API_KEY`. That
convention covers every secret in the app today, so nothing needs declaring
anywhere; name a new one after the extension that uses it and it just works.

Two escape hatches exist in `packages/halo_build_tools/lib/src/secret_policy.dart`
for values that belong to no single extension — `sharedSecrets` (any extension may read) and `grants` (a
named list of extension keys). Both are empty. The policy is committed code
rather than a manifest field on purpose: an extension asking for access is not
the same as being granted it, and one reviewable list beats a claim spread
across thirty manifests.

A third list refuses rather than grants. `appOnlySecrets` names values no
extension may read whatever key it claims, because the prefix rule grants by
NAME and an extension key is not entirely ours to choose — the catalog serves
Ham2K's own extensions under a reserved prefix, which the app strips before
asking the policy, so a bundle published as `ham2k-pusher` would be asked
about as `pusher`. Being listed there says nothing about being confidential:
`PUSHER_KEY` and `PUSHER_CLUSTER` are Pusher's public client-side identifiers.
It says only that Dart is the sole consumer, so nothing needs to cross the
boundary.

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
import { defineExtension, host } from "@ham2k/extension-sdk"
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
doesn't match its bundle entry. `hooks` is declarative — the kernel still
learns the actual hooks from `registerHook` — but its `ref:<type>` entries are
read by the host: an operation carrying a reference of a type no loaded
extension handles offers to enable the switched-off extension that declares
it, or to install one from the catalog, so an activity that leaves them out is
never offered that way. List only the types the extension publishes a control
for — a `ref:` entry for a legacy type it merely decorates or scores would
offer a switch that cannot clear the row.

A **qualified** entry, `ref:<type>/<code-prefix>`, claims the references of a
type this extension does not publish. It exists for a type that used to hold
many events in one extension and became one extension per event: the New York
QSO Party publishes `ref:ny-qso-party`, and every operation logged before the
split carries `{type: 'qp', ref: 'NY'}`, which nothing else answers any more.
Declaring `ref:qp/ny` beside its own type says those references are this
extension's.

Nothing is rewritten. The operation stays exactly as the operator logged it —
a log is not an extension's to edit years after the fact — and the extension
reaches back for it instead. That has to hold at every layer that asks "whose
reference is this", so the same claim is stated three times, once where each
layer can read it:

| Layer | Where | Decides |
| --- | --- | --- |
| Manifest | `hooks: ["ref:qp/ny"]` | which extension is OFFERED for an unhandled reference |
| Control | `input.alsoHandles: ["qp/ny"]` | which control ANSWERS for it once the extension is on |
| Runtime | `registerHook("ref:qp/ny")` | which handler a `ref:qp` call is ROUTED to |

The code is matched as a lower-cased **prefix**, and the **longest match
wins**. A plain `ref:qp` claims the whole family at length zero, so the party
that named the reference beats the bundled extension that merely contained it,
and neither has to know the other exists. Nebraska claims `ref:qp/ne` and New
England `ref:qp/neqp`, so a `NEQP` reference matches both and the longer one
decides — the case that makes prefix-and-longest the rule rather than exact
equality.

A control's form reads from, and writes back onto, whichever reference it
matched, keeping that reference's own `type` and `ref`. Taking the control's
own type on save would retype the operation the first time its setup form was
opened, which is the same edit by a slower route.

Rules, all enforced by the build: the entry must be shaped `<type>/<prefix>`
with one slash and both halves present, since anything else matches no
reference at all; a claim must be backed by a control declaring it in
`alsoHandles`, or the host offers this extension for a red row and the row
stays red; and a control that answers for a claim the manifest does not
declare is never offered for it, so nothing ever reaches that control.

The build checks all of this rather than trusting it (`extensions/hook-check.mjs`):
it activates each built bundle against a stand-in kernel and compares what
`registerHook` was actually called with. A plain category must match both ways;
a declared `ref:<type>` must publish a control, while registering one you do
NOT declare is how a decorate-only handler is written (WWBOTA answers for the
legacy `ukbota` types without offering itself for them); and a qualified
`ref:<type>/<prefix>` must be well-formed and must agree with the controls
both ways — a claim no control declares in `alsoHandles`, or a control
declaring one the manifest does not claim, is caught.

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

Available via `import { host } from "@ham2k/extension-sdk"`:

| Function | Purpose |
|---|---|
| `host.fetch(url, options?)` | HTTPS requests, executed by the Dart host. Returns `{status, body}`. A plain `http://` URL is refused unless its host serves http only and `services.ham2k.net` fronts it (`servicesHttpOnlyHosts` in `halo_extension_host`'s `fetch_policy.dart` — the QSO Party Hub), in which case it goes out over https through that proxy on every build; `domains` still names the original host, and the bundle declares `"api": 4`, the first API that does this. Per-extension domain allowlists are planned. The host stamps HaLo's canonical `User-Agent` on every call — don't set your own unless your extension declares `allowUserAgentOverride` ([docs/design/network.md](../design/network.md)). `options.timeout` (ms) bounds the whole request, and is clamped downward only — you may declare a request not worth the host's default wait, not award yourself a longer one. Worth setting on anything optional, per the hanging-hook note above. |
| `host.webSocket(url, options?)` | A live connection to a host the manifest's `webSockets` lists, shaped like the browser's `WebSocket`. See [WebSockets](#websockets). |
| `host.setTimeout(fn, ms, ...args)` / `host.setInterval(…)` / `host.clearTimeout(id)` / `host.clearInterval(id)` | Timers, shaped like the browser's, on real time and held to a budget. A bundle built for extension API 3 gets them as plain `setTimeout` and friends too. See [Timers](#timers). |
| `host.kvGet(key)` / `host.kvSet(key, value)` | Key-value storage, automatically namespaced to your extension (currently in-memory; keychain-backed persistence planned for credentials). |
| `host.statusBar.setMessage(params)` / `.setProgress(params)` | Transient single-line message or progress bar in the app's footer, keyed and namespaced to your extension the same way as `kvGet`/`kvSet`. |
| `host.statusBar.clear(key)` | Removes a message/progress item you posted. |
| `host.statusBar.showNotice(params)` / `.dismissNotice(key)` | A richer, dismissible notice (markdown body, optional `link`/`dialog` action buttons) shown as a "post-it" over the footer and kept in the user's Settings → About → Recent Notices history. |
| `host.getVersionInfo()` | Read-only build identity: platform, edition, version, versionName, buildNumber, gitSha. `buildNumber` is null on Dev, where the compiled-in number is the last release's rather than the running build's. |
| `host.log(message)` | Log line, prefixed with your extension key, visible in the app console. |

### WebSockets

`host.webSocket(url, { protocols })` returns at once, connecting, and behaves
like a browser's `WebSocket` with `binaryType = "arraybuffer"`: `readyState`,
`protocol`, `send(data)`, `close(code?, reason?)`, and `onopen` / `onmessage` /
`onerror` / `onclose`. The host holds the connection; frames reach your
callbacks whenever the peer sends them, outside any hook call, so there is no
`ctx` there.

```ts
const ws = host.webSocket("wss://stream.example.com/spots")
ws.onopen = () => ws.send(JSON.stringify({ subscribe: "spots" }))
ws.onmessage = (e) => { /* e.data: string, or ArrayBuffer for a binary frame */ }
ws.onclose = (e) => { /* e.code, e.reason, e.wasClean */ }
```

A distributed bundle that declares `webSockets` must declare `"api": 2`
([distribution.md](distribution.md)), so an app too old for sockets refuses it
at install rather than failing at the first connect.

The rules, all enforced by the host:

- **The manifest's `webSockets` is its own grant.** Same entry shape as
  `domains` (exact hosts, `*.example.com`, a lone `*`), and a host listed only
  under `domains` gets no socket: consenting to requests is not consenting to a
  standing connection. The install screen names each entry.
- **`wss://` to a listed host; plain `ws://` only to a local-network one** —
  loopback, the private ranges, link-local, IPv6 unique-local, and `localhost`
  or `.local` names. Gear in the shack rarely has a certificate; anything past
  the router has no such excuse. A name counts by its spelling, not by what it
  resolves to.
- **`"local"` admits every local-network address**, over either scheme, for
  gear whose address only the operator knows — so you need not declare `*`,
  which would grant the whole internet too.
- **At most four sockets per extension, and 1 MiB per frame** either way (UTF-16
  code units of text, bytes of binary). An oversized `send` throws; an oversized
  inbound frame closes the socket with 1009 rather than arriving cut short.
- **A refused socket fails the way a browser's does** — `onerror`, then
  `onclose` with 1006 — never as a throw from `host.webSocket`. The `onerror`
  message says why.
- **Reloading your extension, or the app replacing its runtime (enabling or
  disabling any extension), closes your sockets without an `onclose`**: the
  code that would hear it is gone. Open them again from `onActivation` or when
  a hook next needs one.

Reconnect after a delay, and a growing one: `onclose` → `setTimeout(connect,
backoff)`. Reconnecting straight from `onclose`, against a server that is
down, is a loop, and the [timer budget](#timers) will not save you from it —
there is no timer in it to charge.

On the web build the browser sets the handshake's `User-Agent` (every native
build sends HaLo's), and plain `ws://` to a LAN address is blocked outright as
mixed content, since the page itself is served over https.

### Timers

`host.setTimeout(fn, ms, ...args)`, `host.setInterval(fn, ms, ...args)`,
`host.clearTimeout(id)` and `host.clearInterval(id)` behave like a browser's:
extra arguments reach the callback, an id is a number, and either clear
reaches either kind. They run outside any hook call, like a socket's
callbacks, so there is no `ctx` there.

A bundle built for **extension API 3** gets them as plain `setTimeout` and
friends as well: the build (`buildOptionsFor` in `tools/h2kext-build.mjs`)
points every bare use in the bundle at the SDK's, npm dependencies included,
so a library that schedules work runs on your extension's timers. Only what
the bundle carries, though: the host's shared libraries (`sharedDependencies`)
run inside the kernel and have no timers at all. A
distributed bundle that uses timers declares `"api": 3`
([distribution.md](distribution.md)); an older app has none to give it. In a
test the source is not built, so a bare `setTimeout` there is Node's — code
you want the test harness to drive calls `host.setTimeout`
([development.md](development.md)).

The rules, all enforced by the kernel (`extensions/sdk/src/timerQueue.ts`):

- **Real, monotonic time.** Timers do not follow developer time travel,
  though `Date` does, nor a system clock someone sets back: a timer is a
  duration the host sleeps for (docs/design/time.md §6).
- **`setTimeout` never throws** for a function callback. A timer it will not
  keep — past the cap below, set while your timers are suspended, or set
  before your extension has activated (a library doing so as its module loads)
  — gets an id that never fires, and the console says so once. A hook that
  sets a timer, or a library that does, keeps working.
- **At most 16 live timers per extension.**
- **No minimum delay, and a budget instead.** Every timer that fires is charged
  to your extension: what its callback took, plus 1 ms for each wake that
  fires anything of yours, which is what a zero-delay chain costs even when
  its callbacks cost nothing. Your callbacks may average **10% of real time**,
  with **five seconds** of burst on top, so one heavy callback every few
  minutes is fine and a loop is not. That wake charge alone puts a floor
  under intervals: at 10 ms or less, none stays within budget whatever its
  callback does. Anything that has to move faster than a few times a second
  belongs in a native pane.
- **Five callbacks in a row that throw** count as breaking the budget too.
  A promise a callback returns that rejects later is logged but not counted:
  that is usually a network failure, and a poller that is offline must not
  lose its timers for the session over it.
- **So does a callback the engine has to interrupt** for running past its time
  limit — on native builds. The web build's Worker has no such limit: a
  callback that never returns hangs it, as a hook that never returns does.
- **Breaking the budget suspends your timers**: every one is cancelled, and a
  new one is ignored, until the runtime is replaced or the extension reloaded.
  Your hooks keep working. The console says which rule you broke, and in
  developer mode a notice names your extension.
- **Only a callback's synchronous part is measured.** What it does after an
  `await` runs later, where nothing can tell whose work it is — the same as a
  hook's. Keep heavy work in the part that is measured, or in small pieces.
- **The app does not pause timers while it is hidden**, though the platform
  may: iOS suspends a backgrounded app, and a browser slows a hidden tab's
  timers to about once a minute. For work worth doing only while someone can
  see it, stop and restart it from `onHide` and `onShow`.
- **Reloading your extension, or the app replacing its runtime, cancels its
  timers**, as it closes its sockets. Set them again from `onActivation`.

### Visibility: `onShow` and `onHide`

An extension definition may carry `onShow()` and `onHide()` beside
`onActivation`. They are called when the app comes into view and goes out of
it — a desktop window restored, a browser tab selected again, a phone app back
in the foreground — and only on a change. `onHide` is also called as
activation completes if the app is hidden by then, so an extension always
learns the state it starts in; one whose activation failed hears neither,
and whatever timers it set while activating are cancelled. Both are called on
your own definition object, the same `this` `onActivation` sees.

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

The engine's own timers are gone too, on both platforms: the only timers are
the kernel's (see [Timers](#timers)). Bound a request with `host.fetch`'s own
`timeout` option rather than racing it against one: a timeout raced in JS
settles your promise and leaves the request running, while the host's
actually stops it.

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
import { hooks } from "@ham2k/extension-sdk"
const refs = [...(operation.refs ?? []), ...(qso.refs ?? [])]
const entries = await hooks.invokeForRefs('adifFields', 'fieldsForOneQSO', { qso, operation }, refs)
// entries: [{key, ok, value|error}, ...] in priority order
```

`invokeForRefs` asks only the extensions claiming one of those references (and,
for `adifFields`, any that opt into every contact) — what a file combining
several programs wants, since a program the contact has nothing to do with
then writes nothing into it ([hooks.md](hooks.md), `adifFields`).
`invokeAll(category, method, args)` asks every hook in the category, the
caller's own included; `invokeOne(category, key, method, args)` asks one
extension by key.

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
import { createTranslator, HookContext } from "@ham2k/extension-sdk"

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

Only the app's core extensions live in this repository and are baked into
its assets. Any other extension — Ham2K's own included — is a catalog bundle:
it lives in its own repository ([ham2k/extensions](https://github.com/ham2k/extensions)
holds Ham2K's), is packed and published as a `.h2kext`
([distribution.md](distribution.md)), and reaches the app from the catalog or,
for the few a new install needs, as a pre-load. A new core extension gets an
entry in `bundles` in `extensions/build-config.mjs`.

For iterating rather than adding, `npm run dev` rebuilds on save and reloads
the one extension in a running app — see **[development.md](development.md)**.

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
`ExtensionService` (app/lib/services/extensions/extension_service.dart), which shapes
raw hook invocations into domain calls (merged lookups, control descriptors,
ref decoration).

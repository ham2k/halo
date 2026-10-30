# Working in the Ham2K Logger repository

Everything else under `docs/extensions/` is written for an author with the
SDK and the tools from npm. This page is for a contributor working inside
the app's own repository, where the extensions workspace, the dev server,
the `halo-ext` command line, the test harness and the build secrets live.
None of it is needed, or available, outside a checkout.

## The workspace

```
extensions/
  sdk/              @ham2k/extension-sdk: src/, build.mjs, AGENTS.md (generated), README.md
  tools/            @ham2k/extension-tools: h2kext-init, h2kext-build, h2kext-pack, h2kext-publish
  core/             the extensions built into the app, under bare keys
  samples/          the k2hrc-* worked examples the SDK ships
  build-config.mjs  the bundle list and the esbuild options, shared by every build
  build.mjs         builds the core into app/assets/extensions/ + index.json
  dev-server.mjs    rebuilds on save and reloads one extension in a running app
  hook-check.mjs    activates each built bundle and compares registrations with the manifest
```

```sh
cd extensions
npm install
npm run typecheck        # tsc over the whole workspace
npm run build            # → app/assets/extensions/ and index.json
npm test                 # the SDK's, the tools' and the core extensions' unit tests
```

Every extension in the workspace reaches the SDK through a tsconfig path
alias straight at `sdk/src/index.ts`; esbuild compiles the TypeScript on the
way past. `sdk/build.mjs` exists only to produce the npm package for
authors with none of this.

**Only the core is built in.** The app's own extensions, the ones that are
the app itself (`adif`, `scoring`, `lookups`, `templates`, the command sets,
`ham2k-lofi` sync), live under `extensions/core/` and are listed in
`bundles` in `build-config.mjs`. Every other extension, Ham2K's own
included, is a catalog bundle in [ham2k/extensions](https://github.com/ham2k/extensions),
reaching the app from the catalog or as a pre-load. A new core extension is
an entry in `bundles`; a new program is a catalog extension. The build fails if a
manifest's `key` does not match its bundle entry.

**The SDK package** (`sdk/build.mjs`) ships one file per module, never one
bundle, so an author's tree-shaking can tell which parts their extension
reaches, and keeps the shared libraries as bare specifiers so the build
preset can rewrite them; the build asserts both, since breaking either
produces a package that works and is silently five times larger.
`kernel.ts` (the host: it defines the runtime and holds the one instance of
every shared library) and `testing.ts` are never published.

**Manifest fields the core uses** and the packer refuses in a bundle: no
`category` makes an extension core, always on and never listed;
`enabledByDefault` says whether a built-in starts out on; `experiments`
lists experiment keys from `app/experiments.yaml` that must all be on for
the extension to load or be listed. `build.mjs` produces `index.json` for
the host from the manifests, which must describe even disabled extensions,
whose bundles are never evaluated.

**`hook-check.mjs`** activates each built bundle against a stand-in kernel
and compares what `registerHook` was called with against the manifest's
`hooks`. A plain category must match both ways; a declared `ref:<type>` must
publish a control, while registering one you do not declare is how a
decorate-only handler is written; a qualified `ref:<type>/<prefix>` must be
well-formed and agree with the controls' `alsoHandles` both ways. The build
fails on a mismatch.

**The hook categories** are spelled once on the extension side, in
`sdk/src/hookCategories.ts`, and once on the host's, in halo_core's hook
catalog (`packages/halo_core/lib/src/hook_names.dart`); a guard test fails
when the two disagree. A new category goes in both.

## The dev server

Editing an extension normally means `npm run build`, restarting the app,
and finding your way back to what you were looking at. The dev server
rebuilds as you save and hands the new bundle to a **running** app, which
swaps that one extension in place; everything else keeps running.

```sh
cd extensions
npm run dev                            # every extension
npm run dev -- --only adif,scoring     # just the ones you are working on
npm run dev -- --port 9000             # default 8787
npm run dev -- --host 127.0.0.1        # default 0.0.0.0, so a phone on the LAN can reach it
```

It prints the URLs. In the app: **Settings → Developer → Extension Dev
Server**, enter the URL, connect. It is a server rather than a watched
folder because the app is usually on a phone.

- On connect, the app fetches the server's index and uses the dev bundle
  **instead of** the one baked in for every extension the server offers,
  which is what lets you iterate on `pota` itself. Anything the server does
  not offer keeps running from the app's assets.
- Each save pushes a reload: the old version's hooks are unregistered, the
  new source is evaluated, its `onActivation` runs. The extension's
  key-value store survives a reload. A save that does not compile pushes
  the build error instead, and the app keeps the last version that built.
- **Not covered:** the kernel (`sdk/src/kernel.ts`), whose change still needs
  `npm run build` and an app restart; the server says so when it changes.
  The rest of the SDK is covered, since every bundle inlines it, and only the
  bundles that actually came out different reload: an edit to a comment, or
  to a module a given extension does not use, rebuilds it and changes
  nothing. Dart code needs its own hot reload.
- **Build secrets** are null for anything dev-served, whatever key it claims.
- `host.log()` output from a dev-served extension is forwarded to the
  terminal running `npm run dev`, prefixed `│`.
- Bundles are built in memory; the server never writes to
  `app/assets/extensions`. The server and `build.mjs` import the same
  `build-config.mjs`, so the two builds cannot drift.

The protocol, for anyone changing either end (all JSON; `protocol` is bumped
when the shape changes):

| Endpoint | |
| --- | --- |
| `GET /ping` | `{ server, protocol, extensions: [key…] }` |
| `GET /index.json` | `{ extensions: [manifest entry…] }`, the app's own `index.json` shape minus the kernel |
| `GET /<key>.js` | one bundle's source |
| `GET /events` | Server-Sent Events: `hello` (with `buildErrors`), `reload` (with the manifest), `buildError` |
| `POST /logs` | `{ lines: [String…] }`, what the app's extensions logged |

## `halo-ext`: the extensions on the command line

`halo-ext` boots the **real** extension runtime (the same QuickJS host, the
same built bundles, the same hooks) outside the app, and lets you call any
hook with JSON and read back what it returned. It answers the questions a
debugger cannot: what does `decorateRef` return for this park, today, over
the real API; which command hook claims this text; what does the ADIF
exporter produce for this operation.

```sh
mise run ext -- lookup KI2D            # or: cd packages/halo_cli && dart run bin/halo_ext.dart …
```

**Setup.** `mise run setup` makes the three things it needs once per
checkout: the built bundles (it reads `app/assets/extensions` and the
pre-loaded catalog bundles beside it, so POTA is `ham2k-pota` here as in the
app), the host build of the JS engine (`packages/halo_quickjs/tool/build_host.sh`),
and `packages/halo_cli`'s dependencies. After that only the bundles go
stale: `cd extensions && npm run build` after every extension change. Run it
from anywhere in the repo, or point `HALO_EXT_BUNDLES` or `--bundles` at a
bundle directory. `--dev-server 127.0.0.1:8787` overlays a running dev
server's extensions on the built bundles; `--verbose` names what came from
where.

It runs on the plain Dart VM, where `dart:ui` does not exist, so neither
`halo_cli` nor anything it imports (`halo_extension_host`, `halo_core`,
`halo_build_tools`, `halo_quickjs`) may import `package:flutter`; the gate
runs their tests with `dart test` for that reason.

**Commands.** `invoke` is the primitive and reaches every hook; the rest
assemble one `invoke`:

```sh
halo-ext invoke <category> <method> [--key K] [--all] [--args JSON]
halo-ext invoke ref:pota decorateRef --args '{"ref":{"type":"pota","ref":"US-1234"}}'
```

| Command | Hook |
| --- | --- |
| `list [--hooks]` | the bundle index; `--hooks` boots and reports what actually registered |
| `lookup <CALL> [--recent-context]` | `lookupService/core.lookupCallInfo` |
| `command <TEXT> [--execute]`, `command --catalog` | every `command` hook's `interpret` / `catalog` |
| `spots [--source K]` | `spots.fetchSpots` |
| `export [--list] [--type T] [--out F]` | `export.suggestExportOptions` / `generateExport` |
| `score [summaries \| sections \| qsos] [--key K] [--ref JSON] [--md]` | `scoring.scoreQsos`, merged across the operation's scorers unless `--key` |
| `suggest [TERM] [--callsign C]` | every `activity` hook's `suggest` |
| `ref <TYPE> <REF> [--validate \| --title]` | `ref:<type>.decorateRef` / `validateRef` / `suggestOperationTitle` |
| `adif-fields [--combinations]` | every `adifFields` hook |
| `data-files list \| sync [KEY…]` | downloads and imports the reference datasets |
| `account list \| set \| test \| forget` | the `account` hook: stored credentials and `testCredentials` |

- **Global options:** `--only`/`--exclude` load a subset of extensions
  (`--only ham2k-pota` runs POTA and nothing else, so nobody else's hook can
  answer); `--qson`/`--op`/`--qsos`/`--qso` supply log data;
  `--location lat,lon`; `--offline` tells hooks the device has no network;
  `--md` renders a report where one exists; `--compact` prints results on one
  line; `-v`/`--verbose` narrates host calls; `--all-extensions` includes
  extensions that are off by default; `--cache` and `--config` move the two
  directories.
- **A log:** `--qson mylog.qson` takes one QSON file (`{ "operation": {…},
  "qsos": […] }`, what an export of one writes, so an exported log works
  unedited). A QSON is a whole log, so one that lists no contacts is an
  **empty** log and hooks see `[]`; `--op` on its own still means the `null`
  that says the host has no log access. `--op` and `--qsos` supply the halves
  and override the file's when both are given. Every JSON option takes a
  path, `-` for stdin, or inline JSON (anything starting with `{` or `[`; a
  leading `@` on a path is accepted too). Results go to stdout; logs,
  warnings and anything an extension tried to show a user go to stderr. Exit
  codes: 0 ok, 1 the hook or the runtime failed, 2 a usage error.
- **Scoring** selects the scorers the operation needs and merges their
  verdicts as the app does, keyed by scorer, each under its own heading in
  priority order with `--md`; a scorer that fails is reported as
  `{"error": …}` in its own place rather than taking the run down. `--key`
  asks one scorer for its raw, unmerged result and `--ref` gives it the
  reference it scopes to; `--ref` belongs to `--key` and is refused without
  it, and both work on either side of the subcommand. `score qsos --md`
  joins the verdicts back to the log you passed, by callsign and time.
  Everything in these reports is the scorer's own text, notice keys raw
  (`newState`), since the CLI has no translations. `--md` is refused, not
  ignored, by commands with no report to render.
- **Accounts** live in `~/.config/ham2k/halo-cli.json` (`$XDG_CONFIG_HOME`,
  or `--config`), written `0600`; treat it like a keychain. `account set`
  prompts for what you did not pass, so a password need never appear in
  shell history; with no terminal it names the missing fields instead, to be
  fed as arguments or as `key=value` lines on `--stdin`. A field the
  extension never declared is refused rather than stored. `account list`
  reports which fields are stored, never their values; accounts of
  extensions off by default need `--all-extensions` to be visible. OAuth
  accounts show `"oauth2": true` and have no fields: the app runs a browser
  flow this tool does not.
- **Reference data** (`data-files sync`) lands in `~/.cache/ham2k/halo-cli`
  (`$XDG_CACHE_HOME`, or `--cache`) and stays there; without it `suggest`
  and the grid-resolving lookups answer empty. A raw file is replayed into
  the runtime at every boot, so its sync reports `entries` and a `cachedAt`
  path rather than a row count.
- **Configuration:** the config file holds what the app keeps in preferences
  and the keychain:

  ```json
  {
    "settings": { "operatorCall": "KI2D", "developerMode": true },
    "accounts": { "ham2k-qrz": { "credentials": { "username": "KI2D", "password": "…" } } },
    "extensions": { "ham2k-wwff": true },
    "secrets": { "SOTA_API_KEY": "…" }
  }
  ```

  `settings` merge over defaults that mirror the app's `getSettings`;
  `extensions` switches an extension on or off; `secrets` are the build-time
  values behind `host.secret`, each extension seeing only the names its key
  prefixes, under the app's policy. `HALO_SETTING_<key>` and
  `HALO_SECRET_<NAME>` override from the environment and are never written
  back. A `--config` path that does not exist is an error for everything
  except `account set`, which creates it.
- **It has no log, no UI, no app translations and no sync**: `getOperation`
  and `getQsos` answer from what you passed and nothing else; `showForm`
  answers cancelled and status-bar calls are printed to stderr;
  `host.translate` answers null; `syncTransport` is a stateful loop the app
  owns, not a one-shot call. Its `getSpots` board is every spot handed to it,
  never annotated, since there is no operator.
- `--only <key>` is the fastest way to tell your hook's answer from a
  higher-priority one elsewhere. `list --hooks` reports what `registerHook`
  did, where the manifest only claims; they disagree when an activation
  threw halfway or a hook key was refused by the namespacing rule. Traffic
  from here carries `Ham2K halo-ext/<version> (<platform> cli)` as its
  User-Agent, so a debugging session is distinguishable from the product in
  an API operator's logs; the per-extension domain allowlist and every other
  `host.fetch` rule still apply.

## Testing a hook

`sdk/src/testing.ts` loads an extension and calls its hooks in a plain
`node:test` run: no bundles, no QuickJS, no Flutter. It is deliberately not
exported from the SDK's index and not shipped in the package; import it by
path.

```ts
import { fixtureOperation, fixtureQsos, loadExtension } from "../../../sdk/src/testing.ts"

const pota = await loadExtension(() => import("./index.ts"))

test("an activating operation is offered the park control", async () => {
  const controls = await pota.runHook("activity", "operationControls", {
    operation: fixtureOperation({ refs: [{ type: "potaActivation", ref: "US-0001" }] }),
  })
  assert.equal(controls[0].input.refType, "potaActivation")
})
```

- `loadExtension` installs a stand-in kernel, imports your entry point and
  activates it, so `runHook` reaches the hook the app would call. It throws
  when the category, the key or the method is absent, so a test cannot
  exercise nothing and still be green.
- `fixtureOperation`, `fixtureQso` and `fixtureQsos` are plain JSON in the
  shapes a hook receives. Host calls answer benignly (`getSettings` gives
  `{}`, a lookup `[]`, everything else null); pass `hostCalls` to answer a
  particular one, and `ctx` to set the locale or anything else the hook
  reads.
- From extension API 9 `runHook` hands a hook the log frozen, taking the
  level from your manifest or `loadExtension(..., { api })`.
- **Timers run on a clock only the test moves**: `ext.timers.advance(ms)`
  fires what comes due in order and lets each callback's awaited work settle,
  and `ext.timers.pending` says whether any remain; from the first `advance`,
  `Date` follows the same clock, pinned for every test sharing that loaded
  extension until the next `loadExtension` goes back to real time. `advance`
  rejects if a callback threw, a timer was ignored (one past the cap, say),
  or the extension broke its budget; `loadExtension` rejects if a timer was
  set while the extension was still loading, which in the app never fires.
  A bare `setTimeout` in the source is Node's here, so code a test should
  drive calls `host.setTimeout`.
- **One extension per test file**; `loadExtension` refuses a second, since in
  a test process the SDK's `host` is shared and would bind to whichever
  extension was defined last.

Worked examples: `sdk/src/testing.test.ts` and `testing-frozen.test.ts`
for the harness itself, `sync/ham2k-lofi/src/registration.test.ts` for an
extension's hooks, and the catalog extensions' tests in ham2k/extensions.

Integration testing without Flutter boots the real engine against the built
kernel plus inline extension source in `packages/halo_extension_host/test/`.
`ExtensionHost.start` takes an `httpClient`; supply a `MockClient` and
`host.fetch` goes out over it while the manifest allowlist, the https
requirement, the canonical User-Agent and both timeouts still run, since the
seam sits below them. Supplying a client forces in-process mode, since a
client cannot cross an isolate boundary.

## Build secrets

`host.secret(name)` reads a build-time value: "secrets" in the sense every
cloud platform uses it, real credentials and plain per-build configuration
alike. **No extension reads one today**, and that is the useful thing to
know before reaching for it: a catalog bundle is a zip anyone may download,
and a native app is a public client, so the values that once came
through here moved into the extensions that use them as ordinary constants.
Reach for it only for a value that is genuinely confidential and genuinely
reaches the client, and then consider whether the call belongs on a Ham2K
endpoint that holds the key instead.

- An extension sees a secret when its **name starts with the extension's
  key**: `sota` reads `SOTA_OAUTH_CLIENT_ID_PROD`. Nothing needs declaring.
  The host resolves each extension's readable subset once, at load, and
  holds only that; the kernel stamps the caller's identity onto the call, so
  an extension can reach neither another's values nor a name outside its
  own prefix.
- `packages/halo_build_tools/lib/src/secret_policy.dart` holds the escape
  hatches: `sharedSecrets` (any extension may read), `grants` (a named list
  of keys), and `appOnlySecrets`, which refuses values no extension may read
  whatever key it claims, since the catalog serves Ham2K's own extensions
  under a reserved prefix the app strips before asking. All committed code,
  on purpose: one reviewable list beats a claim spread across thirty
  manifests.
- Values come from the environment (`mise.local.toml` locally, the CI
  environment in release builds) into a gitignored
  `app/lib/config/secrets.dart`; see `secrets.dart.example`.
- Installed, pre-loaded and dev-served extensions see **none**, whatever key
  they claim. Expect null and degrade.
- Never log a URL that carries one; `debugPrint` is not stripped from
  release builds.

## Pre-loaded extensions

The app ships some catalog bundles already packaged under
`app/assets/preloaded-extensions/`, installing the ones the operator has
switched on into the ordinary store at first boot, so a new install works
offline and the catalog moves it forward from there. A pre-load is frozen
into the binary, so every release must carry the catalog's current stable
release of each one:

```sh
node scripts/preloaded-extensions.mjs check     # compares with what the catalog serves, byte for byte
node scripts/preloaded-extensions.mjs update    # replaces any that are behind; `update <key>` adds one
```

Publishing a new release of a pre-loaded extension is therefore also a
change to this repository, and the release cut refuses to ship pre-loads
that fail the check. How the app manages installed extensions, pre-loads,
the retired built-ins, revocations and a lost store is in
[docs/design/extension-install.md](../design/extension-install.md).

## The host and the app

- `packages/halo_extension_host` runs the JS engine on a background isolate:
  it evaluates `kernel.js`, then every bundle listed in `index.json`, then
  activates all extensions. Hook calls cross the bridge as JSON messages
  with per-call timeouts; host calls travel the other way.
- `app/lib/services/extensions/` is the app-facing surface, which shapes
  raw hook invocations into domain calls: merged lookups, control
  descriptors, reference decoration, the install lifecycle, the keychain.
- `app/test/extension/` and `packages/halo_extension_host/test/` hold the
  host's tests; `app/test/guards/hook_names_test.dart` keeps the two
  category lists in step.

## These pages

`docs/extensions/*.md` are shipped inside `@ham2k/extension-sdk` by
`extensions/sdk/build.mjs` (which lists the pages it ships, rewrites links
that leave the directory into GitHub URLs, and copies `agents.md` to the
package root as `AGENTS.md`) and synced to catalog.ham2k.net, whose
navigation lists each page by file name. `docs/design/extension-docs.md` is
the contract for writing them: the audience, the voice, where each fact
lives, and the skeleton of a reference section. `extensions/docs.test.ts`
holds the pages to the SDK's surface (every host call, category, manifest
field, context field, scene kind and API level named where it belongs),
checks every link and anchor, and refuses the notes voice. This page is on
the site and not in the package.

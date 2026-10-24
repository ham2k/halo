# Development

Practical guide to setting up, running, building, and testing Ham2K Logger
("HaLo"). For architecture and the extension model, start with
[DESIGN.md](DESIGN.md); the full doc index is [docs/README.md](docs/README.md).

The repo is a Flutter app (`app/`) plus local Dart packages (`packages/`) and a
TypeScript extension bundle (`extensions/`). The extensions are compiled to
single-file JS bundles that ship as app assets and run in an embedded QuickJS
runtime — so **the extensions must be built before the app will run**.

---

## Prerequisites

- **Flutter** — pinned to the version in [`mise.toml`](mise.toml). The
  easiest way to get it is [mise](https://mise.jdx.dev):
  ```sh
  mise install          # installs the pinned Flutter (Dart ships inside it)
  ```
  The first time mise sees this repo it will ask you to trust the config:
  ```sh
  mise trust
  ```
  Dart is not pinned separately — it comes with Flutter.
- **Node.js** — for building the extensions. Not pinned by mise; CI uses
  **Node 22**, so match that locally.
- **OpenSSL 3** — the independent loopback peer for the TLS tests, never a
  production runtime dependency. On macOS, use `brew install openssl@3`;
  `/usr/bin/openssl` is LibreSSL and cannot run these tests. On current
  Debian/Ubuntu, use `sudo apt-get install openssl` and check `openssl version`
  reports `OpenSSL 3.x`. On Windows or with a custom installation, put OpenSSL
  3 on `PATH` or set `HALO_TLS_TEST_OPENSSL` to its executable. The test helper
  also finds the standard Apple Silicon and Intel Homebrew locations.
- **Platform toolchains** for whatever targets you build:
  - macOS/iOS → Xcode, plus `brew install automake libtool` — CocoaPods
    builds libserialport (the serial CAT transport) from source, and
    without autotools `pod install` fails with "Please run `brew install
    automake libtool`" and the app won't build at all
  - Android → Android SDK/NDK (see the Windows/README notes for a full list)
  - Windows → Visual Studio 2026 with "C++ Desktop development" (see
    [README.md](README.md#windows)), **and a JDK on `JAVA_HOME`** even though
    nothing here is Java: `sentry_flutter` depends on `jni`, which declares
    `windows: ffiPlugin: true`, so every Windows build configures it and its
    CMake stops at `Could NOT find JNI (missing: JAVA_INCLUDE_PATH
    JAVA_INCLUDE_PATH2 JVM)`. Android Studio's bundled JBR is a full JDK and
    works. CI images carry one already, so this bites local builds only.
  - Linux → the usual Flutter Linux desktop deps (plus a
    [quirks](docs/quirks.md))

---

## First-time setup

```sh
mise install && mise trust     # the pinned Flutter, and trust this repo's mise config once
mise run setup                 # scripts/setup.sh — everything below, idempotent
cd app && flutter run -d macos
```

`setup` first checks its tools, including OpenSSL 3 (installing `openssl@3`
through Homebrew on macOS if needed and Homebrew is available). Missing tools
on other hosts fail with installation instructions. It then points git at the tracked hooks (`.githooks/`, the
guard on pushes to `main`); copies the blank `secrets.dart` template if none
exists (optional — every consumer degrades without its key, and the Map tab
needs none: MapLibre and OpenFreeMap take no token); runs `npm ci` and
`npm run build` in `extensions/` (the bundles are gitignored, and the app is
nothing without them); builds the host copy of the JS engine that
`flutter test` and `halo-ext` load; and runs `flutter pub get` for the app
and every first-party package. Re-run it after pulling — each step is a
no-op once done.

Notes:
- **Extension bundles are gitignored** (`app/assets/extensions/`) and only
  regenerate on an explicit `npm run build`. Re-run it after changing anything
  under `extensions/`.
- **K4 TLS native builds** use Dart build hooks to fetch pinned, hash-verified
  Mbed TLS source and compile it with the target toolchain. Native runs, tests
  and builds prepare it automatically; web builds skip it. A cold cache needs
  network access, including when starting a native replay tool. For prefetch,
  custom caches and offline builds, see
  [halo_tls_psk](packages/halo_tls_psk/README.md#native-builds-and-source-cache).
- **macOS/iOS local signing:** ad-hoc signing re-prompts for keychain access on
  every rebuild. To sign consistently, copy
  `app/macos/Runner/Configs/Local.xcconfig.sample` → `Local.xcconfig` and set
  `DEVELOPMENT_TEAM` to your Apple team ID (same for
  `app/ios/Flutter/Local.xcconfig.sample`). See
  [README.md](README.md#building-locally-on-macos-or-ios).

---

## Running the app

Run from `app/`, or use the `mise` tasks below. `mac`, `web`, `windows` and
`linux` rebuild the extension bundles first — they are gitignored, so a stale
or missing bundle otherwise loads silently; `android` and `run-ios` do not.

| Target | Command |
|---|---|
| macOS | `mise run mac` (rebuilds extensions first) — or `cd app && flutter run -d macos` |
| Web | `mise run web` (`-d web-server` on :8765) — or `cd app && flutter run -d chrome` |
| iOS | `mise run run-ios` (opens Simulator, then `flutter run -d iphone`) |
| Android | `mise run android` — or `cd app && flutter run -d android` |
| Windows | `mise run windows` — or `cd app && flutter run -d windows` |
| Linux | `mise run linux` — or `cd app && flutter run -d linux` |

The `mise` task is the one to prefer for each: they pass `HALO_GIT_SHA`, so the
build says which commit it is (below).

Tips:
- Launch **debug** desktop builds through `flutter run` (or your IDE) rather than
  double-clicking the built binary — debug mode needs the Dart VM service that
  the tool attaches.
- **A Dev build identifies itself by its commit SHA, not a build number** — its
  `kBuildNumber` is the last release's (see *Builds & editions*), so the home
  pane and About show `HALO_GIT_SHA` instead — the home pane's second line goes
  away entirely when none was baked in, while About keeps `Version 26.9.0` and
  just drops the parenthetical. Every `mise` run task and the web launch config
  pass
  `--dart-define=HALO_GIT_SHA=$(git rev-parse --short HEAD)`, the way CI does.
  A raw `flutter run` bakes none, so that build cannot say which commit it is
  unless you add the same flag.
- The web dev server also backs the one config in
  [`.claude/launch.json`](.claude/launch.json) (`halo-web`, port 8765).

---

## Builds & editions

Every build has an **edition** — `dev`, `next`, or `prod` — selected by the
`HALO_EDITION` dart-define (see
[`edition.dart`](packages/halo_build_tools/lib/src/edition.dart)). It defaults to
**`dev`**; unrecognized values fall back to `dev`. The edition drives the app
name/badge, the User-Agent channel (`kAppFlavor`), and per-platform bundle IDs so
editions install side-by-side.

```sh
# Web (per-edition identity is stamped by scripts/apply-web-edition.sh)
flutter build web --dart-define=HALO_EDITION=next

# Android — the `--flavor` is REQUIRED (a flavor dimension is declared)
flutter build apk --flavor next --dart-define=HALO_EDITION=next --no-tree-shake-icons

# Windows / Linux read HALO_EDITION from the environment too
export HALO_EDITION=next
flutter build linux --release --dart-define=HALO_EDITION=next --no-tree-shake-icons
```

macOS/iOS official builds set the edition via xcconfig; CI (`codemagic.yaml`)
wires all of this up. The public version number lives in
[`version.dart`](app/lib/config/version.dart), not in native metadata.

---

## Tests & checks

The single source of truth is **`./scripts/test.sh`** (or `mise run test`): it
typechecks + tests the extensions, **rebuilds the bundles** (Dart integration
tests load them), copies the blank secrets template if missing, then runs
`flutter analyze` and the tests for every package and the app — `dart test`
for a package whose pubspec never names the Flutter SDK (`halo_core`,
`halo_build_tools`, `halo_cli`), `flutter test` for the rest. The pure-Dart
ones run on the plain Dart VM, where `dart:ui` does not exist, and
`flutter test` would supply it and hide a Flutter import that breaks them
(docs/extensions/cli.md).

CI runs `./scripts/test.sh --quick` on every push to `main` and nothing else
(`.github/workflows/checks.yml`): the source-scanning guards, the extensions'
typecheck, and `dart analyze` for every package — never the suite. The
guards are the clock-discipline grep plus the convention tests under
`app/test` that read source rather than pump widgets (`--list guards`), and
quick mode runs them so a broken convention on `main` reddens something.
`--guards` runs exactly those on their own (about forty seconds), and
`--browser` the browser-platform tests, which fail rather than skip when
`BROWSER_REQUIRED=1`. A new rule of that shape belongs in one of them, not
in a hand-written workflow step.

Dart code is formatted at **160 columns**. Every first-party package's
`analysis_options.yaml` sets `formatter: page_width: 160`, so a plain
`dart format <file>` and an editor's format-on-save use it — never pass
`--line-length`. The full gate and `--quick` both fail on an unformatted file
(generated `.g.dart` files are exempt). The width is read through the
`include:` chain, so a package without `pub get` formats at the default 80.
The extensions' TypeScript, `.mjs` and JSON are formatted by the Prettier
pinned in `extensions/package.json`, at the same width and without
semicolons (`extensions/.prettierrc.json`): `npm run format` there, or an
editor's Prettier integration, which picks the config up. The gate runs
`npm run format:check`; Markdown is wrapped by hand and exempt.
A commit that only reformats goes in `.git-blame-ignore-revs`; run
`git config blame.ignoreRevsFile .git-blame-ignore-revs` once per clone so
`git blame` looks past it (GitHub's blame view already does). Git refuses to
blame at all in a checkout that lacks the file, so a worktree cut before it
existed needs a rebase first.

For the inner loop, the same script runs **subsets** — it handles the
stale-bundle problem itself (rebuilding only when `extensions/` is newer than
the built bundles) and skips `npm ci` / `pub get` / `analyze`:

```sh
./scripts/test.sh --list            # see the groups (packages + one directory each under app/test/)
./scripts/test.sh spots logging     # named groups; app groups combine into one run
./scripts/test.sh widgets           # a whole package
./scripts/test.sh --changed         # derive the subset from the diff vs origin/main
```

`--changed` maps changed package paths to their package, and `app/lib` files to
test files sharing their name prefix in any group directory; what it can't scope (helpers, pubspecs,
assets) widens to the whole app suite, and build/CI infrastructure changes get
a loud "run the full gate". Subset runs are a convenience, **not** the gate:
they skip analyze, dependent packages, and the browser-platform step. The full
`./scripts/test.sh` is still what counts before a merge.

The `guards` subset, including guards selected by `--changed`, keeps the
localized-label check's strings fresh without building extension bundles or
the native JS engine. Other selected groups still prepare their dependencies.

Run `./scripts/test.sh --benchmark-scoring` for the real-engine scoring timing
table (full passes and resumed appends at several log sizes). It prepares the
bundles and host library, then runs `scoring_bench.dart` explicitly. Benchmark
files use a `_bench.dart` suffix so normal test discovery excludes them;
scoring correctness and checkpoint behavior remain in the regular suite.

### Writing an app test

An app test lives in the `app/test/<group>/` directory of the feature it
covers — a group is a directory, `--list` reads the tree, and a file left
directly under `app/test/` fails every run. Convention guards that read
source rather than pump widgets go in `guards/`.
`app/test/support/halo_test_support.dart` is the harness: import it and start
at the assertion. `makeHaLoServices({prefs, stubs, extensions})` builds prefs,
settings, an in-memory database and a `HaLoServices` over them (the database
closes at tearDown); `pumpHaLo(tester, (services) => MyPanel(services:
services), size: …)` mounts a widget inside the `TranslationProvider` +
`MaterialApp` pair the app's widgets expect. `stubs` is a
`{'category:key:method': result}` map answered by one `FakeExtensionHost` —
a `Function` value is called with the hook's args, an `Exception` value is
thrown — stub an `ExtensionHostException` to stand in for a failing hook,
since that is what the service catches. A hook called with no key is stubbed as
`'category:null:method'` (`'ref:pota:null:decorateRef'`), and
`extensions.ready` stays false under the fake, so a path that checks it
behaves as if the runtime were down. Prefer `settleFrames` to `pumpAndSettle`
wherever a `WallClock` ticks in the tree: the settle loop never finds a quiet frame and runs into
its ten-minute timeout. The same directory holds the larger fakes (secure
storage, panel extensions, the peer transports, a connected CAT radio) and
`app/test/flutter_test_config.dart` gives every file an empty prefs store —
on purpose without the widget binding, which would replace `HttpClient`
with one answering 400 to the peer transport tests' real sockets.

A full run takes about six minutes on an Apple-silicon Mac (measured
2026-09-07: 333–386 s, of which the app suite is about four minutes and the
extension bundle build plus the package suites the rest). A subset run of one
small app group is about 20 s.

Run pieces directly while iterating:

```sh
cd app && flutter test                       # app widget/unit tests
cd packages/halo_widgets && flutter test     # a Flutter package
cd packages/halo_core && dart test           # a pure-Dart one (also halo_cli, halo_build_tools)
cd extensions && npm run typecheck && npm test
```

If you run Dart tests directly, `npm run build` the extensions first — the
gitignored bundles are loaded by the extension-host tests, so stale bundles give
misleading results. Prefer `scripts/test.sh` (full or subset) when in doubt.

---

## Build-time & runtime flags

Set at compile time with `--dart-define=NAME=value`; the two marked "also env"
can additionally be set as an environment variable at runtime on non-web
platforms (e.g. `NAME=value flutter run …`).

| Flag | Where | Default | Effect |
|---|---|---|---|
| `HALO_EDITION` | dart-define | `dev` | Build edition: `dev` / `next` / `prod`. See above. |
| `ONBOARD_AS` | dart-define **or** env | *(unset)* | **Debug builds only** (inert in release). Skips first-run onboarding and applies it directly: `ONBOARD_AS=CALL,activity,…` — the first token is the operator callsign, the rest are extension keys to enable. e.g. `ONBOARD_AS=KI2D,pota,sota`. |
| `DEV_LABEL` | dart-define **or** env | *(unset)* | **Debug builds only** (inert in release). Shows the given string in the home-screen header, right after the edition badge — to mark which dev build / session is running. e.g. `DEV_LABEL="header work"`. Also suppresses the tester-notes overlay, which otherwise covers the app on every cold start of a working copy; run without the label (or use `DEVTESTER`) to see it. On deployed **web preview** builds (which are release builds, so the compile-time value is stripped) the label is auto-derived from the preview URL instead — previews go to testers, so they keep showing the overlay. |
| `POLO_OPEN_FIRST_OP` | dart-define **or** env (`=1`) | off | On launch, jump straight into the most recent operation. Handy for iterating on the operation view. |
| `HALO_DEV_DATA` | env (dart-define reaches only Dart — see below) | *(unset)* | **Debug builds only** (inert in release). Puts this launch's whole app data — log database, data-file cache and settings — under the given absolute path instead of the one directory every build of this edition shares. Nothing is migrated in or out; an empty directory starts with an empty log. **The keychain is not sandboxed** — it is keyed by bundle id — so the launch still holds your real sync device key; a sandbox therefore starts with sync OFF, and turning it on points an empty log at your actual account. It also lets several instances run at once: the macOS single-instance guard steps aside for a sandboxed launch, which is why this has to be an environment variable — native code cannot read a dart-define, and a dart-defined sandbox would be killed at launch by whichever build started first. |
| `DEV_LOCATION` | dart-define **or** env | *(unset)* | **Debug builds only** (inert in release). Mocks the device GPS with the given Maidenhead grid locator, so `LocationService` never touches OS permissions or a real fix — e.g. `DEV_LOCATION=FN21rq`. An invalid locator is logged and ignored (falls back to the real GPS). |
| `DEV_LOCATION_STATUS` | dart-define **or** env | *(unset)* | **Debug builds only** (inert in release). Pins `LocationService` at one `LocationStatus` — `unknown`, `determining`, `available`, `unavailable` or `permissionDenied` — so the states behind it can be reviewed on demand instead of by revoking an OS permission. Outranks `DEV_LOCATION`, which still supplies the position for a pinned `available`. An unrecognized name is logged and ignored. |
| `HALO_STUB_LOOKUPS` | dart-define (`=1`) | off | **Debug builds only** (read via `debugEnvFlag`, empty in release). Makes callsign lookups return a deterministic canned result instead of calling the network/credentialed lookup extensions (QRZ/Ham2K Lookup Service/…) — for fast, offline, reproducible verification. See *Driving the app from a browser / agent* below. |
| `HAM2K_LOFI_SECRET` | dart-define | *(empty)* | LoFi sync app-attestation secret injected at build time. Empty on dev builds (the extension uses a `no-secret` default). Identifies the build, not the device. |
| `HALO_SLOW_HOOK_MS` | dart-define | *(unset)* | How long a hook call may wait for the extension engine before the host logs a `SLOW-QUEUE` line naming it and whatever was evaluating ahead of it. Setting it also turns those lines on in a **release** build, which is the only place the numbers mean anything — a debug build's Dart is slow enough to overstate them. Unset, the threshold is 100 ms and the lines are debug-only. The wait itself is measured on every build regardless; this only decides what gets reported. Sweep it down (`=1`) to see every call. Web is structurally exempt: there the engine runs in-process, so nothing ever queues. |

Examples:

```sh
# Debug macOS run, skipping onboarding as KI2D with POTA + SOTA enabled
cd app && flutter run -d macos --dart-define=ONBOARD_AS=KI2D,pota,sota

# Or via the environment (non-web)
ONBOARD_AS=KI2D,pota flutter run -d macos

# Label the running build in the home header (e.g. with your session name)
cd app && flutter run -d macos --dart-define=DEV_LABEL="header work"

# A data sandbox of this worktree's own, and a second instance alongside
# whatever else is already running (HALO-315)
cd app && HALO_DEV_DATA="$PWD/../.halo-dev-data" flutter run -d macos \
  --dart-define=DEV_LABEL="my task"
```

Sandbox the data whenever a branch changes `schemaVersion`. Drift migrations
are one-way and every Dev build otherwise shares one database, so the first
build to run with a higher version migrates the log for **every** checkout on
the machine, and the ones on older branches then refuse to open it — with
deleting the database the only way back.

Build-time values (`app/lib/config/secrets.dart` — award API keys,
per-edition OAuth clients) and, for release CI, signing secrets are **not**
dart-defines — they're a gitignored source file and CI shell env vars,
respectively.

---

## Developer commands (typed into the call field)

Most dev affordances are **commands typed into the "their call" field** and
handled by extensions. They're case-insensitive. The `dev-commands` extension
([`extensions/core/dev-commands/src/index.ts`](extensions/core/dev-commands/src/index.ts))
registers:

| Command | Effect |
|---|---|
| `DEVMODE` (or `KONAMI`) | Toggle **developer mode** on/off. |
| `DEVNOTICE` | Post a sample notice to the status bar. |
| `DEVSTATUS` | Post a sample status message (stacks, to demo the "+N" footer). |
| `DEVPROGRESS` | Show a progress bar. `DEVPROGRESS 10` = 10%; bare = indeterminate. |
| `DEVSPLASH` | Re-show the startup release-notes overlay (bypasses the once-per-version gate). |
| `DEVONBOARD` | Re-show the first-run onboarding overlay (bypasses its gate; completing it really writes settings). |
| `RELOAD` | Force data-file re-sync, ignoring the 30-day staleness check. `RELOAD POTA` / `RELOAD SOTA` by category; `RELOAD ALL` / `RELOADALL` / `RELOAD!` for everything. |
| `SEED` | Fill the current operation with generated QSOs. `SEED` = 10, `SEED 20` = 20, `SEED 15 3H` = 15 spread over 3 hours. Needs an open operation. |

Other core extensions add their own call-field commands:

- **Radio** ([`radio-commands`](extensions/core/radio-commands/src/index.ts)):
  a band (`20`, `40M`, …), a mode (`CW`, `SSB`, `FT8`, …), or a bare frequency
  in MHz sets that value on the current QSO.
- **Spotting** ([`spot-commands`](extensions/core/spot-commands/src/index.ts)):
  `SPOT` / `SPOTME` / `SELFSPOT` self-spot (optional comment); `QRV` / `QRT` /
  `QSY` / `QRX` self-spot with that Q-code as the comment; `SPOTLAST` /
  `SPOTTHEM` spot the last logged QSO.
- **Annotations**
  ([`annotation-commands`](extensions/core/annotation-commands/src/index.ts)):
  `NOTE <text>`, `TODO <text>`, `SOLAR` (current solar conditions), `WEATHER`
  (current weather).
- **Settings**
  ([`settings-commands`](extensions/core/settings-commands/src/index.ts)):
  `SET <setting>` reports a setting and its current value, `SET <setting>
  <value>` changes it (`SET ZEROBEAT N`, `SET THEME DARK`, `SET AVOID ZERO BEAT
  N` — a multi-word name works, since the app splits name from value against
  the catalog); `SHOW <setting>` / `HIDE <setting>` flip a `show…`/`hide…`
  toggle. Settings are matched by SUBSEQUENCE (VS Code
  Ctrl+P style) against key, label and any declared `aliases`, so `SET ZRBT`
  finds Avoid Zero Beat and `SET DFRCW` finds `defaultReportCW`; descriptions
  are matched as plain substrings, since a subsequence of a whole sentence
  matches almost anything. Ranking rewards consecutive characters, word
  boundaries (camelCase humps included) and short names. The All Settings
  search box uses the same matcher, so both answer a given word with the same
  set. A bare name, a value that can't be
  typed on one line (multiselect, account, secret), or a query naming several
  settings opens a dialog listing **every** match, best first, rather than
  guessing at the top one. The searchable set is derived from the
  declarative settings registry and honours `devMode`, `environment` and
  `visibleWhen`, so a command only ever reaches a setting the settings screen
  would currently show.

### Developer mode

Turn it on with the `DEVMODE`/`KONAMI` command, by typing `DEVMODE` (or
`KONAMI`) as your callsign during onboarding, or via the toggle in **Settings →
Developer Settings**. It unlocks:

- the **Developer Settings** panel in Settings,
- `devMode`-flagged form fields (hidden otherwise, shown with the orange dev
  accent),
- dev-only export behavior, and
- `ctx.developerMode` inside the extension runtime (so extensions like
  `dev-commands` can gate on it).

---

## Driving the app from a browser / agent

Dev **web** builds (`flutter run -d web-server` — i.e. any non-release build)
expose a small control + inspection surface so agents and scripts can drive and
read the app deterministically instead of pixel-hunting the Flutter canvas.
**None of it ships to production**: the bridge only installs on non-release web,
the accessibility DOM + structured logging are gated the same way, and the
stub/fixture hooks are read through `debugEnvFlag` (empty in release).

### `window.__halo`

Installed on `window` at startup (non-release web only). Getters return plain JS
objects/arrays you can read via `javascript_tool`.
Source: [`app/lib/config/dev_bridge.dart`](app/lib/config/dev_bridge.dart).

| Call | Returns / effect |
|---|---|
| `getState()` | Snapshot of the current screen: `{view, operation:{uuid, stationCall, title, qsoCount}, call, editing, guess, vfo}`. `view` is `operation` on the logging screen, else `none`. |
| `getGuess()` | Just the current callsign guess (`{name, grid, state, entityName, …}`), or null. |
| `setField('call', 'W1AW')` | Sets the call field as if typed — fires the debounced lookup/scoring. |
| `tap('log')` / `tap('wipe')` | Logs the current QSO / wipes the compose fields. |
| `ready` | A Promise that resolves once bootstrap **and** the home screen's first data load are done. `await window.__halo.ready` instead of sleeping after a page load. |
| `recentLog()` | The buffered structured events (see below), oldest-first. |
| `resetFixture()` | Backs up then clears all operations + QSOs, restores font scale / distance units to defaults, seeds a fresh "HALO Fixture" operation, and navigates into it. Returns `{uuid, stationCall, qsoCount, backupId}`; the pre-reset data is recoverable from the `OperationsBackup`/`QsosBackup` tables under `backupId`. `await ready` first. |

Example — an agent driving the core logging loop from a clean, deterministic state:

```js
// Launch: flutter run -d web-server --dart-define=HALO_STUB_LOOKUPS=1
await window.__halo.ready
await window.__halo.resetFixture()
window.__halo.setField('call', 'W1AW')
while (!window.__halo.getState().guess) await new Promise(r => setTimeout(r, 50))
window.__halo.tap('log')
```

### Accessibility DOM + stable identifiers

On dev web the app forces Flutter's semantics DOM on (normally opt-in behind the
"Enable accessibility" affordance), so the generic browser tools (`read_page` /
`find` / `computer`) see labeled nodes instead of a blank canvas. Key logging
widgets carry stable, translation-independent identifiers, surfaced as
`flt-semantics-identifier="…"`:

| Identifier | Widget |
|---|---|
| `field.call` | The "their call" input |
| `action.log` | The Log button |
| `action.wipe` | The Wipe / secondary-action button |
| `qso.row.<CALL>` | Each logged QSO's row (e.g. `qso.row.W1AW`) |

Convention: `field.<name>` inputs, `action.<name>` buttons, `qso.row.<call>` rows.
Add more with the `semanticId(id, child)` helper in
[`packages/halo_widgets/lib/src/semantic_id.dart`](packages/halo_widgets/lib/src/semantic_id.dart).

### Structured console logging

Dev builds emit stable tagged events to the console (picked up by
`read_console_messages`) and buffer them for `window.__halo.recentLog()`:

- `[qso] {uuid, op, call, band, mode}` — each logged contact.
- `[lookup] {call, phase, name, grid, entity, source}` — each callsign lookup.

Add your own with `DevLog.instance.log('tag', {…})`
([`packages/halo_core/lib/src/dev_log.dart`](packages/halo_core/lib/src/dev_log.dart));
it's a no-op in release.

---

## Handy `mise` tasks

Defined in [`mise.toml`](mise.toml):

| Task | What it does |
|---|---|
| `mise run bundle` | Build the extension JS/TS bundles. |
| `mise run mac` | Build extensions, then run the macOS app. |
| `mise run android` / `mise run run-ios` | Run on Android / iOS simulator. |
| `mise run test` | Full verification (extensions + every Dart package + app). |
| `mise run deploy-web` | Build extensions + web app and deploy to Cloudflare Pages. |
| `mise run mac-files` | Open the macOS app's sandboxed Documents folder (sqlite db, exports). |
| `mise run ops -- <cmd>` | `halo-ops` CLI. `status` (released version per edition, from tags); `release [--edition next] [--dry-run] [--yes]` (bump `version.dart`, rename `tester-notes.yaml`'s `upcoming` key to the new build, commit both, tag, push to trigger CI — refuses while `tester-notes.yaml` has uncommitted changes); `code-push [--edition next] [--force] [--dry-run]` (publish a Shorebird code push of HEAD via a per-commit `code-push-<edition>-<sha>` tag; hard-blocks when native/dependency files changed since the release, or when the public version has already been published); `prune-code-pushes [--older-than <days>] [--all] [--dry-run]` (delete old `code-push-<edition>-<sha>` trigger tags, default older than 2 months); `preview <name> [--dry-run]` (deploy a web preview of HEAD via a `web-preview-<name>` tag → `https://<name>-halo-dev.ham2k.net`); `prune-previews [--older-than <days>] [--name <n>] [--all]` (list/delete web previews — Pages + DNS + tag; needs `CLOUDFLARE_API_TOKEN`/`CLOUDFLARE_ACCOUNT_ID`). `--json` for automation. |

---

## Where things live

| Path | What |
|---|---|
| `app/` | The Flutter app. |
| `packages/` | Local Dart packages. First-party: `halo_core` (pure Dart — models, database, sync engine, peer protocol), `halo_widgets` (the widget catalog and the modules built from it), `halo_i18n` (the slang sources and generated strings — every first-party package may depend on it), `halo_extension_host` (the QuickJS bridge and extension manifests), `halo_quickjs` (the QuickJS-NG FFI plugin), `halo_cli` (`halo-ext`, hooks outside the app), `halo_build_tools` (editions and version stamping). Vendored, each with a `PATCH.md` saying what it changes and why ([quirks](docs/quirks.md)): `flutter_inappwebview_macos_patched`, `flutter_inappwebview_windows_patched`, `flutter_inappwebview_linux_stub`, `usb_serial_patched`, `universal_ble_patched`. |
| `app_dist/` | The private distribution layer — the store, update and telemetry services the open-source app stubs out. Absent from the public mirror by design. |
| `workers/` | Cloudflare Workers: the dev-preview proxy. |
| `extensions/` | The SDK, the tools, and the core TypeScript extensions (every other extension is a catalog bundle, some pre-loaded from `app/assets/preloaded-extensions/` — `scripts/preloaded-extensions.mjs` keeps them current). `build.mjs` bundles the core into `app/assets/extensions/`; `dev-server.mjs` (`npm run dev`) rebuilds on save and reloads one in a running app ([docs/extensions/development.md](docs/extensions/development.md)); both build from `build-config.mjs`. |
| `scripts/` | `test.sh`, `deploy-web.sh`, `apply-web-edition.sh`, `preloaded-extensions.mjs`, and the Linux arm64 cross-build (`build-linux-arm64.sh`, `aarch64-linux-gnu.cmake` — see below). |
| `docs/` | [Index](docs/README.md), [design/](docs/design/), [extensions/](docs/extensions/README.md), [quirks](docs/quirks.md), [releases](docs/releases.md). |
| `.github/workflows/`, `codemagic.yaml` | CI (GitHub Actions) and release builds (Codemagic). |

### Platform splits

A feature that exists on only some platforms is one file that exports the
implementation for the build: `foo.dart` holds
`export 'foo_web.dart' if (dart.library.io) 'foo_io.dart';` (or the
condition the other way round), and the two files are named for the platform
each is compiled into — never for what they do there. The platform a feature
does not exist on still gets its file, and that file's header says what it
does instead — nothing, an empty stream, or a throw — and why that answer is
the honest one for its callers. `serial_transport_unsupported.dart` is the one
third arm, for a platform with neither `dart:io` nor `dart:js_interop`; nothing
ships to one, and the conditional export needs a default all the same.

### Linux arm64

`flutter build linux --target-platform linux-arm64` **refuses to run on an x64
host** (`build_linux.dart:88-94`, unconditional). The refusal is in the command,
not the machinery, so `scripts/build-linux-arm64.sh` drives CMake directly and
lets Flutter's own rules do the Dart half. Run it from the
`🐧 Linux ARM64 — 🔨 full app build (manual)` Codemagic workflow; it is a CI
script and is not expected to work on a developer machine.

Three things it has to supply by hand, because Flutter will not fetch them for a
foreign target: the linux-arm64 engine artifacts (two zips), a `gen_snapshot`
that runs under `qemu-user-static`, and a Debian multiarch arm64 sysroot.

The compiler is **clang**, not `aarch64-linux-gnu-g++`, and that is not a
preference — `flutter assemble`'s `dart_build` step requires a compiler named
literally `clang` next to the `CMAKE_CXX_COMPILER` it reads from
`CMakeCache.txt`. See the header of `scripts/aarch64-linux-gnu.cmake`; it also
explains why the toolchain file uses `find_program` rather than `set`, and why
ASM needs its target spelled out separately.

It stops at a verified bundle. Packaging and publishing are the `app_dist` half
and are not wired up yet.


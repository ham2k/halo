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

- **Flutter** — pinned to the version in [`mise.toml`](mise.toml) (currently
  `3.44.4`). The easiest way to get it is [mise](https://mise.jdx.dev):
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
- **Platform toolchains** for whatever targets you build:
  - macOS/iOS → Xcode, plus `brew install automake libtool` — CocoaPods
    builds libserialport (GATO's serial CAT transport) from source, and
    without autotools `pod install` fails with "Please run `brew install
    automake libtool`" and the app won't build at all
  - Android → Android SDK/NDK (see the Windows/README notes for a full list)
  - Windows → Visual Studio 2026 with "C++ Desktop development" (see
    [README.md](README.md#windows))
  - Linux → the usual Flutter Linux desktop deps (plus a
    [quirks](docs/quirks.md))

---

## First-time setup

```sh
# 1. Tools
mise install && mise trust

# 2. Build the extension bundles (required before the app runs)
cd extensions
npm install
npm run build            # → app/assets/extensions/*.js + index.json  (gitignored)
cd ..

# 3. Map token (optional — the Map tab falls back to OpenStreetMap without it)
cp app/lib/config/secrets.dart.example app/lib/config/secrets.dart
#   then paste a public Mapbox token (starts with `pk.`) into that file.
#   Get one at https://account.mapbox.com/access-tokens/ . The file is gitignored.

# 4. Run it
cd app && flutter run -d macos
```

Notes:
- **Extension bundles are gitignored** (`app/assets/extensions/`) and only
  regenerate on an explicit `npm run build`. Re-run it after changing anything
  under `extensions/`.
- **No Mapbox token?** The app still runs — the Map tab uses OpenStreetMap.
  Mapbox is only used when a `pk.` token is present (and never on Linux).
- **macOS/iOS local signing:** ad-hoc signing re-prompts for keychain access on
  every rebuild. To sign consistently, copy
  `app/macos/Runner/Configs/Local.xcconfig.sample` → `Local.xcconfig` and set
  `DEVELOPMENT_TEAM` to your Apple team ID (same for
  `app/ios/Flutter/Local.xcconfig.sample`). See
  [README.md](README.md#building-locally-on-macos-or-ios).

---

## Running the app

Run from `app/` (or use the `mise` tasks below, which rebuild extensions first).

| Target | Command |
|---|---|
| macOS | `cd app && flutter run -d macos` — or `mise run mac` (rebuilds extensions) |
| Web | `cd app && flutter run -d web-server --web-port 8765` (or `-d chrome`) |
| iOS | `mise run run-ios` (opens Simulator, then `flutter run -d iphone`) |
| Android | `cd app && flutter run -d android` — or `mise run android` |
| Windows | `cd app && flutter run -d windows` |
| Linux | `cd app && flutter run -d linux` |

Tips:
- Launch **debug** desktop builds through `flutter run` (or your IDE) rather than
  double-clicking the built binary — debug mode needs the Dart VM service that
  the tool attaches.
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

The single source of truth is **`./scripts/test.sh`** (or `mise run test`),
which mirrors CI: it typechecks + tests the extensions, **rebuilds the bundles**
(Dart integration tests load them), copies the mapbox token template if missing,
then runs `flutter analyze` + `flutter test` for every package and the app.

Run pieces directly while iterating:

```sh
cd app && flutter test                       # app widget/unit tests
cd packages/halo_widgets && flutter test     # a package (also halo_core, etc.)
cd extensions && npm run typecheck && npm test
```

If you run Dart tests directly, `npm run build` the extensions first — the
gitignored bundles are loaded by the extension-host tests, so stale bundles give
misleading results. Prefer `scripts/test.sh` when in doubt.

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
| `DEV_LOCATION` | dart-define **or** env | *(unset)* | **Debug builds only** (inert in release). Mocks the device GPS with the given Maidenhead grid locator, so `LocationService` never touches OS permissions or a real fix — e.g. `DEV_LOCATION=FN21rq`. An invalid locator is logged and ignored (falls back to the real GPS). |
| `DEV_LOCATION_STATUS` | dart-define **or** env | *(unset)* | **Debug builds only** (inert in release). Pins `LocationService` at one `LocationStatus` — `unknown`, `determining`, `available`, `unavailable` or `permissionDenied` — so the states behind it can be reviewed on demand instead of by revoking an OS permission. Outranks `DEV_LOCATION`, which still supplies the position for a pinned `available`. An unrecognized name is logged and ignored. |
| `HALO_STUB_LOOKUPS` | dart-define (`=1`) | off | **Debug builds only** (read via `debugEnvFlag`, empty in release). Makes callsign lookups return a deterministic canned result instead of calling the network/credentialed lookup extensions (QRZ/HamDB/…) — for fast, offline, reproducible verification. See *Driving the app from a browser / agent* below. |
| `HAM2K_LOFI_SECRET` | dart-define | *(empty)* | LoFi sync app-attestation secret injected at build time. Empty on dev builds (the extension uses a `no-secret` default). Identifies the build, not the device. |

Examples:

```sh
# Debug macOS run, skipping onboarding as KI2D with POTA + SOTA enabled
cd app && flutter run -d macos --dart-define=ONBOARD_AS=KI2D,pota,sota

# Or via the environment (non-web)
ONBOARD_AS=KI2D,pota flutter run -d macos

# Label the running build in the home header (e.g. with your session name)
cd app && flutter run -d macos --dart-define=DEV_LABEL="header work"
```

Build-time values (`app/lib/config/secrets.dart` — the Mapbox token, award API
keys, per-edition OAuth clients) and, for release CI, secrets
like `MAPBOX_ACCESS_TOKEN` / `SDK_REGISTRY_TOKEN` are **not** dart-defines —
they're a gitignored source file and CI shell env vars, respectively.

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
| `mise run ops -- <cmd>` | `halo-ops` CLI. `status` (released version per edition, from tags); `release [--edition next] [--dry-run] [--yes]` (bump `version.dart`, rename `tester-notes.yaml`'s `upcoming` key to the new build, commit both, tag, push to trigger CI — refuses while `tester-notes.yaml` has uncommitted changes); `patch [--edition next] [--force] [--dry-run]` (publish a Shorebird Dart patch of HEAD via a per-commit `patch-<edition>-<sha>` tag; hard-blocks when native/dependency files changed since the release); `prune-patches [--older-than <days>] [--all] [--dry-run]` (delete old `patch-<edition>-<sha>` trigger tags, default older than 2 months); `preview <name> [--dry-run]` (deploy a web preview of HEAD via a `web-preview-<name>` tag → `https://<name>-halo-dev.ham2k.net`); `prune-previews [--older-than <days>] [--name <n>] [--all]` (list/delete web previews — Pages + DNS + tag; needs `CLOUDFLARE_API_TOKEN`/`CLOUDFLARE_ACCOUNT_ID`). `--json` for automation. |

---

## Where things live

| Path | What |
|---|---|
| `app/` | The Flutter app. |
| `packages/` | Local Dart packages: `halo_core`, `halo_widgets`, `halo_extension_host`, `halo_build_tools`. |
| `extensions/` | TypeScript extensions + `build.mjs` (bundles → `app/assets/extensions/`). |
| `scripts/` | `test.sh`, `deploy-web.sh`, `apply-web-edition.sh`, and the Linux arm64 cross-build (`build-linux-arm64.sh`, `aarch64-linux-gnu.cmake` — see below). |
| `docs/` | [Index](docs/README.md), [design/](docs/design/), [extensions/](docs/extensions/README.md), [quirks](docs/quirks.md), [releases](docs/releases.md). |
| `.github/workflows/`, `codemagic.yaml` | CI (GitHub Actions) and release builds (Codemagic). |

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


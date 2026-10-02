# Ham2K Logger — Release Architecture

> Status: draft · Last updated: 2026-08-06

This document describes how Ham2K Logger is versioned, built, distributed, and
updated across every platform it targets, and how its three **editions** — a
build-it-yourself **Dev** edition plus the two official **Next** (pre-release)
and **Regular** (stable) editions — run side by side. It captures the lessons
carried over from the React Native Ham2K PoLo release process and adapts them to
Flutter + Shorebird.

Targets: **Android, iOS, Windows, macOS, Linux, Web.**

---

## 1. Core model

Releases follow a **monthly cadence**. Each month a new *line* is cut, named
after its target month (e.g. `26.9`). Within a line, fixes and small
improvements ship continuously as **code pushes**, without a new store binary.
§2.0 fixes the vocabulary this document uses for all of that.

There are **three independent update planes**, each with a different delivery
mechanism, cadence, and set of constraints. Keeping them separate is the central
design principle of this architecture.

| Plane | Delivers | Mechanism | Cadence | Store review? |
|-------|----------|-----------|---------|---------------|
| **Binary** | Full app: engine, native code, plugins, assets | App stores + self-updating downloads (appcast) | Monthly | Yes (store channels) |
| **Dart patch** | Compiled Dart code changes | Shorebird code push | Continuous | No |
| **JS extension** | Extension logic (contest defs, data sources, adapters, export formats) | First-party OTA from Ham2K origin | Continuous | No |

**Why three planes.** Each mechanism can only carry certain kinds of change.
Native/engine/plugin/permission changes *must* ride the binary plane. Pure-Dart
fixes ride Shorebird. Extension logic rides our own OTA channel. A change is
assigned to the lowest-friction plane that can legally and technically carry it.

---

## 2. Versioning, naming, and identity

### 2.0 The five coordinates

A release is pinned by five independent numbers, named here before anything
else because the naming collision is what makes this section necessary. **The
word "patch" alone names three different things**: semver's third component,
Shorebird's over-the-air unit, and — casually — any small fix. Conflate them
and an ordinary occurrence ("September '26 patch 2 has to be a full binary")
reads as a contradiction.

**The rule: *patch* is the version component; Shorebird's mechanism is a *code
push*.** This is the vocabulary Ham2K PoLo already uses, and this document
follows it everywhere.

| Coordinate | Counts | Advances on | Lives in |
|---|---|---|---|
| **line** | the month — `26.9`, "September '26" | the monthly cut | `MainVersion` |
| **patch** | every user-visible update to the line | a binary **or** a code push | `PublicVersion.patch` |
| **stage** | a Next milestone — `pre3`, `rc1` | a deliberate hand bump | `PublicVersion.preRelease` / `preReleaseLabel` |
| **build** | the native binary | a full binary only | `kBuildNumber` |
| **code push** | a Shorebird increment on one build | every Shorebird publish | Shorebird's own counter; shown as `.N` after the build |

The first three compose the public version string (§2.1); the build is the
native identity (§2.2) and the code push rides on top of it (§4). So *patch 2*
says **what** changed and *build 131* says **how it arrived**, and the two no
longer compete for the same word.

**Two identities, two owners.** The five coordinates split cleanly across them:

- **Public-facing version** (§2.1) — the human-readable string shown in the UI,
  logs, and sync metadata. It lives in **Dart**, so a code push can rewrite it,
  and no store validates it (which is what makes `-preN` labels safe).
- **Build/release identity** (§2.2) — the number baked into the native binary at
  build time, encoded to satisfy each platform's format rules. It is **frozen for
  the life of a binary** (Shorebird cannot change it) and is also the key
  Shorebird uses to bind a code push to a release.

Section 2.3 explains how the patchable public version is stored.

### 2.1 Public-facing version — `line.patch[-stage]`

`26.9.0`, `26.9.3`, `26.9.0-pre3`, `26.9.0-rc1`. Assembled by `PublicVersion`
(`halo_build_tools`) from the first three coordinates:

- **line** — `YY.M`, the two-digit year and the **target month** (`26.9` = the
  September 2026 line). Because Next runs ahead (§2.5), the line usually carries
  the *following* month's name and branding while it is still being built.
- **patch** — the third component, counting every user-visible update to the
  line: `26.9.0` → `26.9.1` → `26.9.2` …. It counts **updates, not
  mechanisms**. Most arrive as code pushes; when a change can't ride one (§4.2)
  the next number arrives as a full binary instead, taking its place in the same
  sequence. The number never says which of the two it was — that is the build's
  job (§2.2), and wanting the version string to answer it is the mistake this
  vocabulary exists to prevent.
- **stage** (Next only) — `-<label><N>`, marking a milestone within a cycle:
  `pre` by default (`26.9.0-pre1`, `-pre2`, …), or `alpha`/`beta`/`rc`. It is
  **coarse and hand-bumped** — a milestone you announce, typically spanning
  several builds — so the build number, not the stage, is Next's fine-grained
  identity. A code push applied on top of a stage appends its own counter:
  `26.9.0-pre3.1`.
- **product stage label** — `kStageLabel` in `config/version.dart`, currently
  `ALPHA`. Not a coordinate and deliberately not part of the version. The stage
  suffix marks one build's place within a cycle; this marks how mature the
  *product as a whole* is, and applies to every version and every edition until
  deliberately changed (`''` removes it). It exists only in the human name —
  `September '26 ALPHA patch 1`, ahead of the patch and stage parts — and never
  in the numeric string, so it reaches no tag, plist, or store field.

Every code push is bound to the exact release build it was compiled against
(§4.1).

#### Worked examples, and the two traps

**Regular** — the model PoLo already runs, legal on every platform:

```
September '26            26.9.0  (build 130)      full binary
September '26 patch 1    26.9.1  (build 130.1)    code push
September '26 patch 2    26.9.2  (build 131)      full binary — a native fix
September '26 patch 3    26.9.3  (build 131.1)    code push, on the new base
```

**Next** — patch pinned at `.0` for the whole cycle, with the stage counter
carrying the milestone and the build number carrying the churn:

```
September '26 pre 3      26.9.0-pre3    (build 138)
September '26 pre 3      26.9.0-pre3    (build 139)    same milestone, new binary
September '26 pre 3.1    26.9.0-pre3.1  (build 139.1)  code push
September '26 rc 1       26.9.0-rc1     (build 142)
```

Two consequences follow, both of which fail silently if forgotten:

- **A mid-month rebuild splits the install base.** Code pushes bind to one
  build (§4.1), so `26.9.3` published against build 131 never reaches a device
  still on build 130 — that device catches up only when its store or appcast
  delivers the new binary. Publishing a fix as a code push after a rebuild
  therefore covers *part* of the population, and the part it misses is
  invisible from the Shorebird console, which only reports on the release the
  push targeted.
- **Promotion is a rebuild, not a relabel.** `kPublicVersionInfo` is compiled
  in, and Next and Regular are separate Shorebird apps with separate identities
  (§2.6, §4.5) — so `rc1` → `26.9.0` means a fresh Regular binary carrying its
  own build number. There is no operation that renames an existing build.

**The name has one canonical spelling and one translated one.**
`PublicVersion.displayName` — `September '26 ALPHA patch 1` — is the canonical
form and stays English wherever it goes: notice rules match on it, the
extension host is handed it, release tags and commit messages spell it. The UI
renders the operator's language instead (`Parche 1`), and splits the name
across two lines on the version splash. Both build from
`PublicVersion.displayParts()`, which is what keeps them describing the same
version: add a component to the version and there is one grammar to update, not
two — a test pins the two spellings together
(`app/test/ui/version_label_test.dart`).

### 2.2 Build/release identity — one build number, per-platform encodings

The build number is a single **monotonic integer** — `kBuildNumber` in
`lib/config/version.dart`. It is deliberately small (it started at `73`), which
keeps it under every platform's field limit — including the 16-bit Windows/Linux
`FILEVERSION` cap — so **all platforms share the one value** with no per-platform
narrowing. `halo-ops release` advances it automatically: it takes the highest
`+<build>` across the `v<version>+<build>` release tags, adds one, writes it into
`version.dart`, and tags the release — so nobody bumps it by hand.

The code-push counter is **not** part of it and reaches no native field: the
platform tables below project the line, patch, stage and build only. A code
push cannot alter a signed binary's metadata, so `build 131.1` exists in the
Dart layer and on screen (§2.3), never in a plist, manifest or `FILEVERSION`.

The same cut also names the build's **tester notes**, renaming their `upcoming`
key to the build number it just computed and committing that inside the tagged
commit — see §2.7.

> Earlier lines used a date-encoded `YYMM·MMDD·S` id. That overflowed the 16-bit
> Windows/Linux field (forcing a separate desktop part) and, being large, pinned
> every platform of a release to whatever build number iOS had already floored at.
> The plain counter avoids both. History is not rewritten — the counter simply
> continues upward from where the old scheme left off.

CI projects the version + build number into each platform's native fields via
`PlatformVersions.project` (`tool/print_build_versions.dart`). Each platform has
hard format limits the projection respects:

| Platform | Native field(s) | Constraint | Example (`26.8.1-alpha1`, build 73) |
|----------|-----------------|------------|------------|
| **Android** | `versionCode` / `versionName` | code ≤ **2,100,000,000**, strictly increasing, single-use | `73` / `26.8.1-alpha1` |
| **iOS** | `CFBundleVersion` / `CFBundleShortVersionString` | build ≤ **18 chars**; marketing = **≤ 3 integers, no suffixes** | `73` / `26.8.1` |
| **macOS** | `CFBundleVersion` / `CFBundleShortVersionString` | direct distribution (no App Store review) → marketing **keeps the suffix** | `73` / `26.8.1-alpha1` |
| **Windows** | MSIX / `FILEVERSION` `a.b.c.d` | each part **0–65535**, major ≠ 0; revision **must be 0 only for MSIX/Store** (see note) | `26.8.1.73` |
| **Linux** | package version | string; build number distinguishes builds | `26.8.1-alpha1` (build 73) |
| **Web** | — | none (server-deployed) | n/a |

Two projection rules follow from the table:

- **Desktop uses the full public version as its build-name — same string as every
  other platform.** Windows and Linux both build with
  `--build-name=<public version>` (`26.8.1-alpha1`) and `--build-number=<build>`,
  exactly like Android/macOS, so the version reads the same everywhere (the About
  view, Windows file properties, and the WinSparkle update dialog all show
  `26.8.1-alpha1`, never a desktop-only `26.8.96`).
  - **Windows `FILEVERSION` is derived, not hand-encoded.** Flutter parses
    `build-name+build-number` and emits the numeric `FILEVERSION` as
    `major.minor.patch.build` — `26.8.1-alpha1+73` → `26.8.1.73` (each part well
    under the 16-bit cap). The revision slot is the build number, not `0`, which
    matters **only for an MSIX/Store submission** (Microsoft reserves the 4th part
    and requires `0`). We ship a signed portable ZIP + Inno installer (WinSparkle),
    *not* MSIX/Store, so nothing requires revision `0`; a future Store/MSIX
    artifact can force its own revision to `0` for that build alone.
    (`PlatformVersions.windowsFileVersion` / `linuxPackageVersion` still model the
    old numeric `major.minor.build` encoding but are no longer what CI builds from.)
  - **`package_info_plus` reads the real build** from the `+N` suffix of the exe's
    `ProductVersion` (Windows) / `version.json`'s `build_number` (Linux), both from
    `--build-number` — so the About view shows the build instead of the old
    **"Build 0"** (which came from passing `--build-number=0`).
  - **WinSparkle** compares **build numbers**, like Sparkle on macOS: the app
    calls `win_sparkle_set_app_build_version` with the bare build at startup, so
    the appcast advertises `<sparkle:version>131</sparkle:version>` plus a
    `<sparkle:shortVersionString>` carrying the public version for display. That
    call is not in the `auto_updater` plugin — it is bound directly to the
    bundled `WinSparkle.dll` in `app/lib/services/winsparkle_config_io.dart`,
    which also explains the ordering constraint (everything there must run before
    the plugin's `setFeedURL`, since that is where `win_sparkle_init()` happens).

    **Never go back to advertising the `FileVersion` string.** WinSparkle
    compares version *strings* by splitting on character class and treats `-`
    and `+` as string parts compared lexicographically, so `26.8.1-alpha1+125`
    sorts **above** `26.8.1+130` (`-` is `0x2D`, `+` is `0x2B`): every install
    predating a cosmetic suffix change judges *itself* newer than the release and
    never updates again. That stranded the whole pre-127 Windows fleet. A build
    number is an integer comparison and cannot repeat it.
  - **Caveat for a future `.deb`:** two builds that share a public version differ
    only in the build number, so its packaging must fold that number into the
    Debian version for `dpkg` upgrade ordering (AppImage needs no version
    comparison; the current scheme is fine for it).
- **iOS marketing string cannot carry `-preN`.** `CFBundleShortVersionString` must
  be pure `X.Y.Z`, so the plist marketing version stays `26.8.1` for all of
  `alpha1`/`pre1`, `pre2`, and the final release; the pre-release label lives in the
  app UI, TestFlight notes, and the build number. This is fine because App Store
  Connect only requires the *build number* to increase per marketing-version
  string — and a fresh marketing version (e.g. `26.8.0` → `26.8.1`) lets the build
  number restart low.
- **macOS keeps the suffix** (`macMarketingVersion` = `26.8.1-alpha1`): the DMG
  is distributed directly with Developer ID + Sparkle, outside App Store review,
  and Sparkle's update dialog displays `CFBundleShortVersionString`. With the
  suffix present, "26.8.1-alpha1 is available — you have 26.8.1" can't drop the
  pre-release distinction, and when two builds share the same public version
  Sparkle automatically appends their build numbers in parentheses
  ("26.8.1-alpha1 (84) — you have 26.8.1-alpha1 (83)").

### 2.3 Where the public version lives (patchable)

Because a code push only swaps Dart, the public version must live in
**compiled Dart** — e.g. a constant in `lib/version.dart`:

```dart
const kPublicVersion = '26.8.1';
```

A code push that bumps the public version edits this file; the new string ships
inside the push and updates on-device when it lands.

- **Do not source it from `package_info_plus`** — that reads the native
  Info.plist/manifest (the frozen build identity), which a code push can't
  change.
- **Version displays take the build number from compiled Dart too**
  (`kBuildNumber`), for the same reason plus a second one: a local `flutter run`
  reports a native build number of `1`, which names no release at all.
  The notice environment (`services/flags_service.dart`) reads the same
  constants, so a `builds` rule targets the build a reporter reads off their
  screen — and, like the display, a Dev build reports no build number at all
  and is targeted by its `shas` (git SHA) instead. A `shas`/`exceptShas` entry names a
  build when one of the two is a prefix of the other, in either direction,
  because the ends are cut to different lengths: `git rev-parse --short` sizes
  its answer to the repository, the displays cut that to seven, and what a
  shipped binary baked is frozen. So a rule may be written at whatever length
  was to hand — the seven a Dev reporter reads off their screen, the nine in an
  older screenshot, or a whole forty pasted out of git.

  On an official build the SHA is reported but never DISPLAYED (a build names
  itself one way, below), so a `shas` rule aimed at one is authored from the
  release tag and can never be confirmed against what its operator sees. That
  cuts hardest for `exceptShas`: it can withhold a notice from official builds
  by a field nobody on those builds can read back. An entry shorter than six
  characters is dropped rather than honoured: it would name a slice of the
  fleet instead of a build, and an `exceptShas` that withholds a notice too
  widely leaves nothing on anyone's screen to report it by. An empty entry
  matches nothing, rather than everything.

  Note that local development builds now bake a SHA too (the `mise` run tasks
  pass `HALO_GIT_SHA`), so a rule targeting a commit reaches every developer
  sitting on it as well as the deploy cut from it. They were immune to
  `shas` targeting when they carried no identity at all. `package_info_plus` still
  supplies the build number to the User-Agent (`config/user_agent.dart`) alone;
  it reports the *native* identity and will disagree with the UI on a local
  build or once a code push is running.
- **The patch number is bumped deliberately, not derived** from Shorebird's
  counter. The two count different things (§2.0): Shorebird restarts at 1 for
  every release, so deriving would reset the public version at each rebuild and
  could never express a full-binary patch, which has no code push at all.
  `halo-ops` guards the bump instead — it refuses to publish a version that has
  already been triggered, reading HEAD's version.dart against the release tag and
  the surviving code-push trigger tags. Best-effort by construction: pruned or
  unreadable tags are reported and skipped, never fatal.
- **Every official build captures its commit**, whether or not it shows one.
  Each release script and each code-push script bakes `HALO_GIT_SHA` from
  `git_sha_or_die` (`app_dist/ci/git-sha-common.sh`; `build-windows.ps1` carries
  the same rule in PowerShell, and the web workflows and `scripts/deploy-web.sh`
  inline it, since a public checkout has no `app_dist/` to source), and a lookup
  that cannot answer FAILS the build. `git rev-parse … || echo ""` would hand
  `flutter build` an empty define, which it accepts without complaint — and what
  ships is a release no Sentry event, no `shas` rule and no bug report can
  identify, with nothing in the log to say so. A build machine always has a
  checkout, so a failure there means something is wrong enough to stop for.
  Capturing is separate from displaying: an official build reports its SHA and
  never renders it (below). A web deploy to a STANDING url writes the same SHA to
  `build_sha.txt` beside the bundle — both halves or neither, because a bundle
  that bakes one while the stamp beside it says something else tells every open
  tab it is stale, and the reload it offers cannot clear that. A preview deploy
  writes no stamp: each tag gets its own url, so nothing there is ever
  superseded in place, and a missing stamp reads as "unknown" rather than as a
  mismatch.
- **Version displays** carry the version plus a build-identity parenthetical,
  rendered by one shared helper (`buildDetails()` in `views/version_label.dart`)
  so the home pane and the About row can never disagree: `Version 26.9.3
  (build 131.1)` — the public version for humans, then ONE build identity, never
  two. A build that has a truthful build number names itself by it and says
  nothing about its commit; the code push extends that number rather than taking
  a field of its own, because Shorebird's counter is only meaningful against one
  release: a bare `.1` names nothing. With no code push applied the build stands
  alone (`build 131`).

  The Dev edition is the other case: its `kBuildNumber` is the last *release's*,
  not the running build's, so the git SHA identifies the binary instead
  (`Version 26.9.3 (04e3d1)`), cut to seven characters — and a Dev build with no
  SHA baked in shows nothing at all rather than borrow a number that is not its
  own. A code push moves it back to the first case, since only a
  `shorebird release` binary can carry one. The splash screens carry none of it.
- **Sync/log metadata** should record both the public version *and* the
  build + code-push fingerprint, since only the latter reproduces a device's
  exact code.

### 2.4 Extension version

Independent semver per extension, gated by a minimum app/API version (see §6).

### 2.5 Release lifecycle (the `26.9` line, end to end)

1. **Stage on Next.** Binary builds ship to **Logger Next** first, branded for
   the coming month: `26.9.0-pre1`, `-pre2`, …. The patch component stays `.0`
   for the whole cycle; the stage is the milestone and the build number is the
   fine-grained identity, so several builds under one stage is normal, not a
   mistake. Fixes between builds can go out as Next code pushes —
   `26.9.0-pre3.1`.
2. **Promote.** When a stage is judged stable enough it becomes the official
   **`26.9.0`** on Regular. This is a **rebuild**, not a relabel: the version is
   compiled in and the two editions are separate Shorebird apps, so the promoted
   release carries its own new build number. Both Logger and Logger Next receive
   it.
3. **Patch through the month.** Subsequent fixes ship as code pushes —
   `26.9.1`, `26.9.2`, … — all bound to the release build promoted in step 2.
4. **Rebuild when a change can't ride a code push.** Native, engine, plugin or
   permission changes (§4.2) take the next patch number as a **full binary** —
   `26.9.2` as build 131 — with its own build number. Code pushes then resume on
   *that* release. Note what step 4 costs: devices still on the previous build
   receive none of the code pushes published afterwards, so a fix that matters to
   everyone belongs in the binary, not in a push layered on top of it.

The cycle then restarts as `26.10` opens on Next.

### 2.6 Editions and identity

Three **editions** share one codebase. Each is a fully separate installable app
with its own identity, so all three can be installed side by side with isolated
data and settings:

| Edition | Identity (all platforms) | Signed & distributed? | Update planes |
|---------|--------------------------|-----------------------|---------------|
| **Dev** | `com.ham2k.logger.dev` | Locally: no (ad-hoc). In CD: **yes** — signed like the others | Shorebird (own app); no appcast / extension OTA |
| **Ham2K Logger Next** (pre-release) | `com.ham2k.logger.next` | Yes — official | Binary + Shorebird + extension OTA (own feeds) |
| **Ham2K Logger** (stable) | `com.ham2k.logger.prod` | Yes — official | Binary + Shorebird + extension OTA (own feeds) |

- **Dev** is the build-it-yourself edition — for quick tests by agents or the
  maintainers, and for anyone who wants to run HaLo in their own environment.
  **Building it locally needs no signing certificates, no store accounts, and
  none of the distribution machinery**: a clean public checkout builds it with
  ad-hoc/no signing, and that path is unchanged.

  **CD is different.** The `macos-dev-release` / `ios-dev-release` workflows
  produce a *real signed* Dev build — Developer ID + notarized on macOS,
  TestFlight on iOS — so a Dev build can be installed and run like any normal
  download instead of fighting Gatekeeper or sideloading. That means CD Dev needs
  the same signing secrets as the other editions, so those workflows are no
  longer runnable from a public checkout (previously `macos-dev` was; nothing
  here is now).

  CD Dev is also a **Shorebird release**, against its own Shorebird app, so Dart
  code pushes can target it like any other edition (`ios-dev-code-push`,
  `macos-dev-code-push`). It still gets **no appcast and no extension OTA** — a new
  Dev *binary* means a rebuild or a fresh download. Everything needed to *build*
  Dev locally remains in the public history (§8), and that path never touches
  Shorebird.
- **Next** and **Regular** are the two **official** editions that Ham2K signs and
  distributes publicly. Next runs ahead of Regular (§2.5) and is where binary
  pre-releases land first. Each is a distinct distributed product with its own
  store presence, appcast feed, Shorebird app, and extension-OTA feeds.

The `.dev` / `.next` / `.prod` leaf under a shared `com.ham2k.logger` base is the
identity on every platform — Android `applicationId`, iOS/macOS bundle ID, Windows
package identity / AUMID, and Linux app ID (desktop file / package name). Different
identities mean the OS treats the three as distinct apps and isolates their data
automatically.

**Why suffixed dot-segments, not a hyphen.** A hyphen leaf like
`com.ham2k.logger-next` is invalid: Android `applicationId` allows only
`[a-zA-Z0-9_]` per segment (hyphens rejected), and Flatpak/D-Bus discourage
hyphens. Dot-separated leaves are valid on every platform, so a single consistent
identifier scheme works everywhere and avoids per-platform divergence.

Any linkage between a user's Regular and Next data is an **app-layer concern of the
sync service** (e.g. same account, per-install profiles), deliberately kept out of
the release/packaging machinery so a sync change can never entangle distribution.

**Selecting the edition at build time.** The edition is chosen by a build input,
**not** by separate Xcode schemes or hand-edited native files — so the two official
editions never need to appear in the public project (§8). It is mirrored into Dart
as `HALO_EDITION` (`--dart-define`, default `dev`) so runtime branding and which
update feeds to contact follow the same switch. A public checkout can only resolve
`dev`; Next and Regular resolve only where `app_dist/` is present.

Each platform reads the same `HALO_EDITION` through its own native idiom, and each
carries a per-edition app icon plus a display name (the name sits beside the icon,
so it drops the "Ham2K" prefix — "Power Logger" on macOS, Linux and the web,
"Portable Logger" on iOS and Android — with the edition suffix `" (Dev)"` /
`" Next"` / none). **Windows still says "Windows Logger"**, alone among them:
`flutter_secure_storage_windows` derives its folder from the exe's own
`ProductName` version resource (`%APPDATA%\<CompanyName>\<ProductName>`), so
renaming it orphans an installed operator's stored credentials and needs a
one-time migration rather than an edit:

| Platform | Edition switch | Icon selection |
|---|---|---|
| **macOS / iOS** | `HALO_EDITION` in `Runner/Configs/AppInfo.xcconfig` → bundle id + `ASSETCATALOG_COMPILER_APPICON_NAME` | `AppIcon-<edition>` asset-catalog sets |
| **Android** | Gradle `edition` product flavors (`--flavor <edition>`) → `applicationId` suffix + `${appLabel}` | per-flavor `src/<edition>/res/mipmap-*` |
| **Windows** | `HALO_EDITION` env → `runner/CMakeLists.txt` `configure_file`s `halo_edition.h` | `resources/app_icon-<edition>.ico` via `Runner.rc` |
| **Linux** | `HALO_EDITION` env → `CMakeLists.txt` app id + product-name compile defs | `app_icon-<edition>.png` + `.desktop`, named after the app id |
| **Web** | `--dart-define=HALO_EDITION`; `scripts/apply-web-edition.sh` stamps the built bundle | `favicon-<edition>.png` + per-edition PWA manifest icons |

Machine-facing strings (ADIF `PROGRAMID`, HTTP `User-Agent`, spot source) stay the
fixed, edition- and platform-agnostic **"Ham2K Logger"** regardless of the above.

### 2.7 What we tell users — release notes and tester notes

Two hand-edited YAML files under `app/assets/`, both rendering each entry under
`changes` as markdown — so a multi-line note can use a YAML block scalar. They
carry no comments beyond a pointer here: **this section is their
documentation.**

| | `release-notes.yaml` | `tester-notes.yaml` |
|---|---|---|
| Audience | everyone | Dev and Next editions only |
| Shown in | startup "what's new" overlay, Settings → About → Recent Changes | tester overlay (`config/tester_notes.dart`) |
| Keyed by | full public version (`kPublicVersion`, §2.3), e.g. `"26.8.0"` | build number (`kBuildNumber`, §2.2), e.g. `"130"` |
| Extra keys | `name` (`August '26`), `photoCaption` | — |
| Written | at release time | as work merges |

A release's cover photo lives at
`assets/images/releases/<MAJOR.MINOR>-photo.jpg`, shared across the patches of a
main version.

A tester sees **every entry newer than the last build they dismissed**, not just
the current one — which is why a note written today still lands for someone who
skipped two builds, and why notes may safely accumulate under `upcoming`.

**How an entry is written** — both files, except where a bullet says otherwise:

- **About ten words on one line, naming what changed** — a longer one is fine
  when it earns it, like a list of radios. Where to find it goes in only when
  the name doesn't already say so, in a trailing parenthetical:
  "Customizable export data and templates (Settings → Exports)". How it works,
  setup steps, caveats and rationale do not fit — the feature explains itself,
  and the rest belongs in the docs or on the card.
- **Lead with a label, not a sentence.** The voice is PoLo's `RELEASE-NOTES.json`:
  - *New …* for a setting, command, pane or control: "New Keep Device Awake
    setting", "New REPORT command files a bug from the app".
  - *Added … to the radio list* for radios: "Added Icom IC-7100 to the radio
    list".
  - *Improved* / *Fixed* / *Updated* … for something that already existed:
    "Improved spot swiping".
  - A bare name for a whole new activity or contest: "IARU Region 1 Field Day".
  - Otherwise a short present-tense statement: "Spots you post say SSB on
    the band's usual sideband".
- **Plain text.** No bold, no trailing period; backticks only for something
  typed (`` `OPER KI2D` ``). Platform-only changes name the platform in the
  sentence ("…on Windows"), not as a `Windows:` prefix. Credit outside
  contributors in parentheses: "(thanks to KC6X)".
- **Word choice** follows [user-interface.md § Wording](design/user-interface.md#wording).
- **Tester notes only**: a short ask fits as a parenthetical — "(tell us how it
  behaves)", "(feedback welcome)". A release note never solicits — it announces.
- **One entry per change, never one per detail.** A rule the feature happens to
  have, or a special case it handles, is not its own entry.
- **Neither file is a changelog.** Only a new feature or a new control someone
  can go and exercise earns an entry. Bug fixes, refinements to behaviour that
  already existed, polish and platform-specific fixes usually do not, and work
  with no user-visible surface (refactors, docs, CI, tooling) never does — so
  most merged changes get no tester note at all, and a release lists its
  headlines rather than its month.
- **Never mention an experiment**, in either file — not the feature behind one,
  not the `EXP` word that toggles it, not the fact that one gates something
  else. Experiments are announced deliberately, to the people invited to try
  them; a note broadcasts them to everyone on the edition instead. Work behind
  an experiment earns its note in the build that ships it without the gate.
  Nothing enforces this — it is checked when the note is written.

**How tester notes reach a build.** They are written as work merges, under an
`upcoming` key at the left margin (created when the last cut took it):

```yaml
upcoming:
  changes:
    - "Something a tester should try"
```

`halo-ops release` renames that key to the build it ships in, so nobody types a
build number and no note lands under a build that never ships. Until the rename,
`upcoming` is a non-numeric key the app's parser skips — that is what keeps
accumulated notes off a tester's screen before the build carrying them exists.

For Next, the same entry is also the build's store testing notes — TestFlight's
"What to Test" and the Play release notes — printed as plain text by
`app/tool/print_tester_notes.dart` and fitted to each store's length limit. A
build with no entry says only its version there. Regular keeps the bare version:
Play carries a release's notes forward when it is promoted to production.

Because the file is hand-edited and the cut commits, tags and pushes it unseen,
the cut vets it rather than trusting it. It parses the document on both sides of
the rename and **refuses** — before writing, tagging or pushing anything — on a
file that no longer parses, a top-level key that is neither a build number nor
`upcoming` (a typo there would otherwise be dropped silently by the cut *and*
the app), a build that already has an entry, or **any uncommitted change to the
file**: notes ride in their own task's commit, so at cut time it must match
`HEAD`, and `git commit --only` would otherwise sweep an in-progress note into
the release. A key created ahead of its notes is simply left for the next cut.
Every planning surface (`--json`, `--dry-run`, a dev-branch preview) reports the
problem instead of failing, since none of them writes anything.

---

## 3. Binary plane — full app updates

The binary plane delivers everything Shorebird and the extension channel cannot:
engine upgrades, native code, plugins, new permissions, and bundled assets. Every
monthly main version is a binary release.

### 3.1 Store-distributed installs

- **iOS / macOS**: App Store (stable), TestFlight (Next). No sideload path exists
  on iOS, so "out-of-store auto-update" simply does not apply there. The iOS CI
  (`ios-next-release` / `ios-prod-release`, delegating to `app_dist/ci/build-ios.sh`) currently
  uploads **both** editions to TestFlight — each keyed on its own app record
  (`com.ham2k.logger.next` / `.prod`); promoting Regular to the public App Store
  is a later manual step. `ios-dev-release` is a public, unsigned compile check.
  The iOS build also publishes a metadata-only entry to the edition's download
  manifest, so the download page lists which version/build iOS is at and says it
  is TestFlight-only — there is nothing to download there.
- **Android**: Google Play (stable), Play testing track — internal/closed/open —
  (Next). `android-next-release` / `android-prod-release` both go through
  `app_dist/ci/build-android.sh`, uploading the AAB to the `internal` track and
  promoting that same release into `GOOGLE_PLAY_TRACK` when one is set. Each
  edition is its own Play listing (`com.ham2k.logger.next` / `.prod`), so a
  closed-track name configured for one has to exist on the other too.
- **Public testers (Next only)**: every Next build also goes to Play **open
  testing** and to the TestFlight **external group** (submitted for Beta App
  Review), so it reaches public testers once each store's review passes. A build
  that should see private testers first is cut with `halo-ops release
  --private-first`, which marks its release tag; the build then stops at the
  internal/closed tracks and internal TestFlight. `halo-ops promote-testers
  <build>` hands such a build on later — the same two store steps, run by their
  own CI workflow — but only while it is still the newest build: each upload
  replaces the Play internal track's release it promotes from. Dev and Regular
  builds never reach public testers.

Store installs update through the store's own mechanism; no custom updater
needed.

### 3.2 Direct-download installs (self-updating)

For installs made outside the stores (website downloads), the app updates itself
via a **Sparkle-style appcast**: the app periodically checks a channel-specific
appcast feed, and downloads/installs a newer signed binary when one is published.

- **macOS / Windows**: `auto_updater` (Sparkle / WinSparkle) — or
  `desktop_updater` / `flutter_desktop_updater` if a single package covering Linux
  is preferred.
- **Android sideload**: in-app "update available" check that downloads and
  launches the new APK (requires `REQUEST_INSTALL_PACKAGES`).
- **Linux**: see §5.

The appcast feeds are **channel-aware** so regular and Next read different feeds,
and so a stable/beta split can exist on the binary plane if desired.

### 3.3 Signing is a hard prerequisite

Silent/unattended binary updates require the artifacts to be trusted by the OS:

- **macOS**: Developer ID signed → hardened runtime → notarized → stapled →
  Gatekeeper-accepted.
- **Windows**: Authenticode signed (publisher trust / SmartScreen).
- **Linux**: descriptor/zsync signing or an equivalent publisher-authenticity
  policy on the download.

Without this, updaters are blocked and the auto-update story fails. Budget setup
time for certificates, notarization, and stapling before wiring the updater.

Every direct-download installer is published with a **SHA-256 sidecar** beside
it — `<file>.sha256` under the same key, one line in `sha256sum` format, so
`sha256sum -c <file>.sha256` (or `shasum -a 256 -c`) verifies a download as-is.
The same hash is the `sha256` field of the platform's manifest entry, and the
download page prints it under the filename, linked to the sidecar. Both are
computed from the exact local file that was uploaded, by the same publish step.
The checksum is an integrity check, not a trust root: the page and the sidecar
sit on the same host as the installer, so it catches a truncated or corrupted
download, while the signature above is what proves who built it. Store-only
entries carry none, and neither do the self-update enclosures — Sparkle and
WinSparkle already verify those against their signing keys.

### 3.4 The approval manifest — what a store will actually serve

The download manifests (`halo-<edition>/<platform>.json`, written by
`app_dist/ci/publish-download.sh`) record what CI
**built and submitted**. For the first minutes-to-hours of a mobile release that
is ahead of what anyone can install: Play needs roughly half an hour to serve an
uploaded release to its track, and an iOS build waits on processing and Beta App
Review. Prompting off those files means telling someone an update exists and then
sending them to a store page with no Update button.

So a second, separate object records the last build a store will actually serve:

```
halo-<edition>/approved.json
  { "edition": "next",
    "platforms": { "ios":     { "version": "26.9.0", "build": 144, "approvedAt": "…Z" },
                   "android": { "version": "26.9.0", "build": 144, "approvedAt": "…Z" } } }
```

Separate rather than a field inside `<platform>.json`, because each of those is
rewritten whole by every build of its platform (that is what keeps parallel
tag-triggered builds from clobbering each other) — a value written alongside one
would not survive the next build. This file is the one exception to that rule and
is therefore read-modify-written, over the S3 API rather than the CDN.

Per edition, so `approved` needs no qualifier: for Next it means "on the testing
track, installable by testers", for Regular it means READY_FOR_SALE. Written by
`app_dist/ci/publish-approved.sh`.

**`approvedAt` may be in the future**, and that is the mechanism, not a wart. The
app treats an entry as installable only once the stamp has passed, which lets
Android record its own approval up front — `build-android.sh` calls the script
with a 30-minute offset the moment the Play submit succeeds, needing no polling
and no manual step. iOS has no such predictable interval, so its entry is written
by hand for now (a later job can derive it from the App Store Connect API's
`betaAppReviewSubmission` / `appStoreState`, which CI is already credentialed
for).

The app compares on **`build`**, not on `version`: the build number is a single
monotonic integer across every platform and edition (§2.2), while a version holds
still for a whole release cycle as the build climbs beneath it. `version` in this
file is for display.

### 3.5 Building an edition without announcing it — `HALO_PUBLISH_MANIFEST`

Being *built* and being *announced* are two different decisions, and an edition
can sit between them for weeks. A signed store build reaches only the testers
invited to TestFlight or a Play track; the manifests under
`https://updates.ham2k.net/halo-<edition>/` reach everyone — they put a row on
the public download page and make every install's "Check for Updates" start
offering the build.

`HALO_PUBLISH_MANIFEST` separates the two. It defaults to `true`, so a workflow
that does not mention it behaves exactly as it always has; set to `false` it
suppresses every write under that prefix:

- the per-platform download entry, the re-derived `latest.json`, and the
  download page itself (`publish-download.sh`),
- the approval manifest (`publish-approved.sh`, §3.4),
- and, on macOS, the **Sparkle appcast and its update zip** — the update feed
  itself, and so the loudest of the three.

Store delivery is deliberately outside the flag: the TestFlight upload and the
Play submit + track promotion still run. What stops is only the public
announcement.

The check lives at the entry of the two publish scripts
(`app_dist/ci/manifest-guard.sh`), not at each caller, so a build script cannot
reach a manifest write without passing it. An unrecognised or empty value is a
build failure rather than a default — a `HALO_PUBLISH_MANIFEST: "False"` quietly
read as "publish" would announce an edition that was being held back, and once
the download page and every install has seen it there is no taking it back.
**Windows is not covered**: `build-windows.ps1` publishes through a PowerShell
sibling and writes its own WinSparkle appcast, neither of which can source the
guard, and there is no Regular Windows workflow yet. Wiring one means porting the
guard first. What Windows has instead is a gate on the *trigger*: the script
publishes only when Codemagic set `CM_TAG`, i.e. a release tag started the run.
A `windows-next-release` started by hand from a branch builds, signs and uploads
its symbols, then stops after the artifacts zip — which is how the pipeline is
exercised without touching the download that every Next install points at. A
manual-start Regular Windows workflow, like its macOS sibling, would need this
gate revisited alongside the port.

The three Regular workflows (`ios-prod-release`, `macos-prod-release`,
`android-prod-release`) set it from the `hold_regular` anchor in
`codemagic.yaml`. Making Regular public is that one anchor going to `"true"`,
after which the next Regular build of each platform writes its entry.

---

## 4. Code-push plane — Shorebird

Shorebird delivers **Dart-only** changes over the air, with no store submission,
across **Android, iOS, Windows, macOS, and Linux** (desktop code push went to
production in Feb 2025). **Web needs no code push** — a Flutter web build fetches
the latest version from our server on load.

### 4.1 Release binding (the key difference from CodePush)

A Shorebird code push is bound to the **exact release build it was compiled against**.
Coming from App Center CodePush — where a deployment key loosely tracks a channel —
this is the important mental-model change:

- Each monthly binary is a distinct Shorebird **release**.
- Code pushes target that release version specifically.
- Tooling must build/promote code pushes **per active release line**, not globally.

This actually fits the monthly-binary + continuous-code-push model exactly; it just
has to be respected in CI.

### 4.2 What may ride a code push

Code pushes must be **pure Dart**. Anything touching plugins, the engine, native
assets, or new permissions requires a full binary release (§3). Discipline here is
essential — keep new native surface for the monthly cut.

### 4.3 Tracks

Shorebird supports unlimited arbitrarily-named tracks plus percentage-based
rollouts. Ham2K uses three cohort tracks, promoted upward:

```
bleeding-edge  →  unstable  →  stable
   (earliest testers)   (wider testing)   (all users)
```

- Publish to `bleeding-edge`, verify, `shorebird patches promote` upward.
- Within `stable`, use **percentage rollout** for a graduated release even after
  a code push reaches the stable track.
- **Next** has its **own Shorebird app** (Shorebird keys per app identity), so it
  carries its own `bleeding-edge`/`unstable`/`stable` tracks independently.

**Mechanics.** CI publishes every code push to **`bleeding-edge`**; moving it upward
is a deliberate, separate act:

```
shorebird patches set-track --release <ver> --patch <n> --track unstable [--flavor <edition>]
shorebird patches set-track --release <ver> --patch <n> --track stable   [--flavor <edition>]
```

Use `set-track` for **every** hop, including the last: `shorebird patches promote`
still works but is **deprecated** ("Use `shorebird patches set-track
--track=stable` instead"), and it only ever targets `stable`. `set-track` accepts
any custom track name, so it covers the whole ladder.

**Which devices see a track.** An installed app only checks `stable` by default;
following an earlier ring is **opt-in per device**, via **Settings → Developer →
Code Push Track** (Developer Mode only). That selector is wired to
`package:shorebird_code_push`: `ShorebirdUpdateService` (lib/services/) checks the
chosen track on launch and downloads any code push, applied on the next restart. So a
`bleeding-edge` code push reaches only the handful of devices that have opted into that
ring — exactly the staging behaviour we want — until it's promoted to `stable`,
which everyone follows.

Because we drive updates ourselves, **`shorebird.yaml` is generated with
`auto_update: false`** (app_dist/ci/shorebird-common.sh): the built-in updater only
ever checks `stable`, so leaving it on would fight a device that has opted into a
different ring. The selector only appears in real `shorebird release` builds
(`UpdateService.isAvailable`), so it's invisible in local/debug/web builds where
the engine isn't present.

### 4.4 App Store policy note

Apple 3.3.1 permits hot-patching only where it does not change the app's intended,
advertised purpose. Keep code pushes to fixes and tweaks, not features that alter what
review was told the app does.

### 4.5 How editions map to Shorebird apps, and CI wiring

Shorebird selects which app a build belongs to by an `app_id` in `shorebird.yaml`,
and its per-flavor support keys off a **Gradle flavor** (Android) or an **Xcode
scheme** (iOS/macOS). Our editions are Android Gradle flavors, but on iOS/macOS
they are driven by the `HALO_EDITION` xcconfig switch with **no per-edition Xcode
schemes** (§2.6, §8) — deliberately. So Shorebird's `--flavor` can't select the
app on those platforms.

`shorebird init` handles the Android side for us: it detects the Gradle flavors,
creates one Shorebird app per flavor, and writes them into `shorebird.yaml` as a
`flavors:` map (plus a top-level default app it also creates). **Those ids are not
secrets** — the generated file says so itself — so `shorebird.yaml` is **committed
as generated**, and Android simply passes `--flavor <edition>`.

iOS and macOS can't use that: with no Xcode schemes, `--flavor` has nothing to
select, and a flavor-less `shorebird release` would fall back to the top-level
default app — the wrong one. So for those two platforms the official build/code-push
scripts call `shorebird_select_edition` (`app_dist/ci/shorebird-common.sh`), which
reads the edition's id out of the committed `flavors:` map and rewrites
`shorebird.yaml` **without** the map, leaving exactly the intended app as the
top-level `app_id`. It sits beside where those scripts already write
`HALO_EDITION` into `Local.xcconfig` — the same edition seam.

The only Shorebird **secret** is `SHOREBIRD_TOKEN`, an API key created in the
console (Account → API Keys; `shorebird login:ci` is gone). Prefer the
"Release & Patch only" scope, and note that key expiry will silently start failing
CI.

**All three editions have a Shorebird app** — `shorebird init` created one per
flavor, and CD registers a release for each, so Dev takes code pushes too. **Web gets
none**: it reloads the latest bundle on load.

**Native requirements** `shorebird init` adds, both needed for code push to work:

- **Android** — `android.permission.INTERNET` in the *main* manifest (it was only
  in the debug/profile manifests, so release builds had no network at all).
- **macOS** — `com.apple.security.cs.allow-unsigned-executable-memory` in
  `Release.entitlements`, since the updater executes patched code under the
  hardened runtime.

**Flutter version — floor is 3.44.5.** Shorebird's dashboard can only report
**rollout adoption** (which code push each device is actually running) for releases
built with **Flutter ≥ 3.44.5**; older releases still take code pushes fine, they just can't
report. We therefore pin **3.44.9** in `mise.toml`,
`codemagic.yaml`, and the build scripts — keep those three in step, and don't drop
below 3.44.5 or adoption tracking goes dark. Xcode 27 sets a second, higher floor
of **3.44.9**: below it no universal macOS or iOS binary builds
([quirks.md](quirks.md#xcode-27-rejects-deployment-targets-and-a-lipo-call-that-older-toolchains-accept)). Because **code pushes inherit the
release's Flutter version**, a release built on an older Flutter can never gain
adoption reporting: it needs a *new release* to do so.

Shorebird supports our pinned Flutter on
every target platform (its floors — iOS/Android 3.24, macOS 3.27.3, Windows 3.29,
Linux 3.32.6 — are all below it). `--flutter-version` is a *release*-only flag;
**code pushes inherit the release's Flutter version**, so a Flutter-pin bump is
inherently a new binary release, never a code push (which reinforces §4.2).

**CLI version — pinned, not `stable`.** The Shorebird CLI is a git checkout, and
its upstream installer clones the `stable` branch — so CI would otherwise run
whatever shipped most recently, and a release cut is the worst place to meet a
breaking CLI. `shorebird_install` clones **one tag** instead
(`SHOREBIRD_CLI_VERSION`), chosen so the Flutter it bundles shares a minor with
the pin above: bump the two together, or the CLI reaches for engine artifacts a
whole minor away from what the release is built with. A detached tag is not the
`stable` branch, so the CLI's own auto-update check stays off.

**Release step.** For Next/Regular the official builds swap `flutter build
<ipa|apk|…>` for `shorebird release <platform> --flutter-version=<pin> -- <the
existing flutter args>`. The `--build-name` / `--build-number` projection (§2.2)
passes straight through as the **release version**, so each monthly binary is the
distinct Shorebird release its code pushes bind to (§4.1). Dev and Web keep plain
`flutter build`.

**Code push step.** A separate workflow runs `shorebird patch <platform>` (with the
same edition selection) and publishes to `bleeding-edge`, to be promoted upward
explicitly (§4.3); `SHOREBIRD_TRACK` overrides the track. Code pushes must be pure
Dart (§4.2). A code push is never distributed, so the macOS code-push build needs no
Developer ID certificate and no notarization.

Trigger it with **`halo-ops code-push`** (or manually from the Codemagic UI): it
pushes a per-commit `code-push-<edition>-<sha>` tag, which fans out to that edition's
iOS/macOS/Android code-push workflows (each `triggering:` on the `code-push-<edition>-*`
pattern). A fresh tag per commit means every code push is a tag creation, so
Codemagic triggers reliably. Before pushing, it diffs the current release tag →
HEAD and **hard-blocks** when any change falls outside the pure-Dart/asset
surface (native dirs, `pubspec.*`) — `--force` overrides that local pre-flight.
It's only a heuristic; Shorebird's build-time diff of the compiled artifact is
the authoritative gate. Old trigger tags are swept by **`halo-ops
prune-code-pushes`** (anything older than two months by default) — they only trigger
builds, so deleting them never touches a published code push.

It passes **`--release-version` explicitly**, resolved by
`shorebird_release_version` (newest release, or `SHOREBIRD_RELEASE_VERSION`).
This is not optional: a code-push build carries pubspec's placeholder `0.1.0+1`, not
the release's §2.2-projected version, so Shorebird's default lookup fails with
`Release not found: "0.1.0+1"`. Re-running the projection wouldn't reliably fix it
either — `kBuildNumber` advances per release, so once it has been bumped past the
target release the projection no longer names that release.

**Wired so far:** iOS, macOS, and Android for **Next** (release + code push), and
the same three for **Regular** (release only — `ios-prod-release`,
`macos-prod-release`, `android-prod-release`, all manual-start, all holding their
manifests per §3.5). Regular code-push workflows follow the same pattern via
`HALO_EDITION=prod` when wanted; Windows/Linux are not wired for Regular at all.

**Prerequisites (one-time):** run `shorebird init` (creates the apps and the
committed `shorebird.yaml`), then add `SHOREBIRD_TOKEN` to the `ios_signing`,
`macos_signing`, and `android_signing` groups. Nothing else is secret.

### 4.6 Telling the user their install is stale

Shorebird has **no mandatory-push flag** — its API offers `readCurrentPatch()`,
`checkForUpdate()` and `update()`, and nothing about required-ness. So a user
can download `26.9.0` from a store and run it while three code pushes on top fix
serious bugs. We build the nagging ourselves.

Three signals answer the same question — *is this install out of date, and what
should the user do?* — and are evaluated as one (`services/staleness.dart`):

| Signal | Means | Remedy | Tier |
|---|---|---|---|
| **code-push floor** | below a server-declared minimum for this build | restart — the fix is already here | nag |
| **expired build** | past its horizon (§2.2: Next 14d, Regular 6mo) | download a new binary | nag |
| **newer release** | the `latestRelease` flag names a newer binary | download a new binary | notice |

**At most one verdict per launch**, ranked in that order. The floor outranks the
binary signals because its remedy is the cheapest and most certain; sending
someone to fetch a binary when a restart would do is worse advice, not more
urgent advice. A *notice* is a status-bar entry; a *nag* is a dialog. Nothing
escalates on its own.

**The floor is server-side**, in the flags channel that already fetches at launch
(§ the `latestRelease` flag), beside it in `defaults.json`:

```json
"minCodePush": { "131": 3 },
"minCodePushMessage": "Fixes a bug that can lose QSOs logged while offline."
```

**Keyed by build**, because Shorebird's counter restarts at 1 for every release —
after a mid-month rebuild two live binaries carry independent counters, so a bare
push number names nothing (§2.1's first trap). Build numbers are globally
monotonic across editions, so Next and Regular keys cannot collide.

**Server-side rather than baked into the push**, because criticality is usually
discovered *after* publishing — often it is push 1 that turned out broken — so the
floor must be raisable at any moment. `halo-ops code-push` prints the JSON to
paste once a push is promoted: nothing else connects "promoted to stable" to
"made required", and that edit falls due exactly when you are firefighting.

**No hard gate, on any platform.** Every presentation offers *Ignore for now*, and
a dismissed verdict returns on the next launch or six hours later — a wall-clock
timestamp, since a field laptop can sit running for days and no timer survives a
sleeping machine. Expiration gets that too; it was launch-only, so it never
re-appeared for the operator most likely to be on a stale build.

**What the user is asked to do differs by platform, and only that:**

| Platform | Action |
|---|---|
| macOS / Windows / Linux | **Restart now** (`RestartService`) |
| Android | "restart to apply" — the intent-based relaunch is too fragile to offer as a button |
| iOS | "quit and reopen" — **no button** |

iOS has no relaunch primitive, and quitting programmatically is both prohibited
by Apple's HIG (it reads as a crash) and useless here: nothing would bring the
app back. A button would either lie or vanish the app mid-activation. In practice
iOS terminates backgrounded apps often enough that a push lands on its own within
a day; the nag matters for the operator who keeps the app resident.

**An unreadable code-push number is silent, not zero.** "We could not read it" and
"no push is applied" are different facts, and treating the first as the second
nags an operator who is already up to date with no action that would make it
stop. The boot cache records whether the read *answered*, not only what it
answered.

**Everything fails open.** A failed flags fetch, an unreadable push number, a
malformed floor, a missing Navigator — each ends in silence. This is a field
logging app: a user mid-activation with no signal must always reach the log.

---

## 5. Linux distribution

Shorebird code pushes work on Linux; the effort is in **binary distribution and
auto-update**, which has no single standard.

| Format | Role | Notes / trade-offs |
|--------|------|--------------------|
| **AppImage** | **Primary direct download** | Single self-contained file; pairs with AppImageUpdate/zsync for delta updates; no sandbox, so rig/serial/USB access is straightforward. |
| **Flatpak (Flathub)** | **Discoverability** | De-facto cross-distro store; sandboxed auto-update. Sandbox + portals can complicate self-update *and* serial/USB access — validate rig control before committing. |
| **Snap** | Optional (Ubuntu reach) | Good auto-update, but confinement issues similar to Flatpak and less popular outside Ubuntu. |
| **.deb / .rpm** | On demand | Native feel, but we own repo hosting + signing; auto-update means running an apt/dnf repo. Add only if users ask. |

**Recommendation**: AppImage (with its own updater) as the primary website
download, **plus** Flatpak on Flathub for discoverability. Validate that rig/serial
hardware access works under the Flatpak sandbox before relying on it. Add `.deb`
later if demand appears.

---

## 6. JS extension plane — first-party OTA

Extensions are JavaScript authored by Ham2K and executed in the app's embedded JS
engine (QuickJS or a WebView). Because they are **content we serve**,
they update over the air with no Shorebird and no store submission, identically on
all platforms including web.

### 6.1 Delivery and integrity

- Serve **only over HTTPS** from the controlled Ham2K origin.
- **Sign each bundle and verify the signature/hash before execution**, so a
  compromised CDN cannot push malicious code to every user. (Also strengthens the
  store-policy position.)
- Optionally give the extension channel its own `stable`/`unstable`/`bleeding-edge`
  tracks, mirroring Shorebird.

### 6.2 Version gating

Extensions call into the app's Dart/native bridge. An OTA extension update cannot
assume a bridge method that only exists in a newer monthly binary. Tag each
extension with a **minimum app/API version** and refuse to load incompatible ones —
the same release-binding discipline Shorebird enforces for code pushes.

### 6.3 Store policy

- **Apple (2.5.2)**: downloading and executing interpreted JS is permitted
  provided it does not change the app's primary, advertised purpose. Frame Ham2K
  Logger as an *extensible logging platform* in the listing so extensions read as
  fulfilling the stated purpose. Avoid becoming a marketplace for third-party
  (especially paid) code. First-party extensions are lowest-risk.
- **Google Play**: interpreted code loaded at runtime is allowed if it can't be
  used to violate other policies; the specific prohibition is loading untrusted
  content / unverified URLs into a WebView JS interface. HTTPS from our own origin,
  no arbitrary user-supplied URLs into a JS bridge → compliant.

### 6.4 Pre-loaded extensions ride the release

The app builds in only its core extensions; everything else is a catalog
bundle, and the ones a new install needs ship inside the binary as pre-loads
(`app/assets/preloaded-extensions/`, see
[distribution.md](extensions/distribution.md#pre-loaded-extensions)). A binary
freezes them, so each release must carry the catalog's **current stable
release** of every one: an older one starts every new install behind the
catalog, and an install moving off the retired built-ins onto it offline, until
its first update check.

`node scripts/preloaded-extensions.mjs check` compares them, byte for byte,
with what the catalog serves at the app's extension API level;
`… update [key…]` refreshes them (and adds `key`). `halo-ops release` runs the
check and refuses to cut a Next or Prod build that fails it — including a check
that could not reach the catalog — unless given `--force`. Every planning
surface (`--json`, `--dry-run`) reports the result without refusing.

---

## 7. Product/variant/track/platform matrix

Dev is built from source and never distributed, so it does not appear below — see
§2.6 and §8. The distributed surface is **Next + Regular × platforms × tracks**, a
large matrix that must be driven by CI, not by hand.

```
                  Binary plane          Code pushes (Shorebird)       JS extensions
                  ------------          -----------------------       -------------
Ham2K Logger
  iOS             App Store             stable/unstable/bleeding      OTA (3 tracks)
  Android         Google Play           stable/unstable/bleeding      OTA (3 tracks)
  macOS           Store + appcast       stable/unstable/bleeding      OTA (3 tracks)
  Windows         Appcast               stable/unstable/bleeding      OTA (3 tracks)
  Linux           AppImage + Flathub    stable/unstable/bleeding      OTA (3 tracks)
  Web             Server deploy         n/a (server fetch)            OTA (3 tracks)

Ham2K Logger Next   (own app identity + own Shorebird app + own appcast/OTA feeds)
  iOS             TestFlight            own 3 tracks                  own OTA feeds
  Android         Play testing track    own 3 tracks                  own OTA feeds
  macOS/Win/Linux Appcast (Next feed)   own 3 tracks                  own OTA feeds
  Web             Next server deploy    n/a                           own OTA feeds
```

### CI responsibilities (single source of config)

- Build all flavors/platforms; sign, notarize, staple (mac), Authenticode (win),
  sign Linux artifacts.
- Publish channel-aware appcast feeds.
- Cut Shorebird releases and build/promote code pushes **per active release line**.
- Publish and sign JS extension bundles.

Codemagic has first-class Shorebird support; GitHub Actions is the alternative.
Either way, one config should drive the whole matrix — otherwise the monthly
release becomes a manual slog.

---

## 8. Repo segregation — public core vs `app_dist`

The three editions live in **one codebase**, but everything needed *only* to
**sign and distribute** the two official editions must stay out of the public
repository. The rule: **a plain build is `dev`; it carries none of the
signing/distribution machinery, and `app_dist/` + CI are what turn a build into a
real `next` or `prod`.** The edition *identity* (name, bundle id) is derived from a
single `HALO_EDITION` switch, so a public checkout can produce a `dev` build with
no configuration — but it cannot sign, notarize, or reach the official feeds.

Ham2K develops on `halo-dist` (branches off `main`). Publishing is two-stage:
on every push to `main`, the **Publish Public** workflow
(`.github/workflows/publish-public.yml`) regenerates the `public` branch by
filtering `app_dist/` out of the full history with git-filter-repo, so
`app_dist/` never reaches the public history and commits may freely mix the
two sides; the open-source mirror (`ham2k/halo`) is then updated manually
with `halo-ops publish-code`, so work can sit on `main` before going public.
Commit messages are published verbatim (see `.agents/AGENTS.md`). A public
checkout simply has no `app_dist/` directory.

**The seam is an optional include per platform** — the shape already used today by
`app/macos/Runner/Configs/AppInfo.xcconfig`'s
`#include? "…/app_dist/macos/Signing.xcconfig"`, which silently no-ops in public
checkouts. The identity itself is computed from `HALO_EDITION` (default `dev`),
**not** by per-edition schemes or hand-edited native files; `app_dist/` supplies the
signing/feeds and, where a platform can't derive identity from a build variable, the
per-edition values.

Only the **macOS** seam is implemented today; the Android/Windows/Linux/Web rows
below describe the target shape for later PRs (iOS mirrors macOS).

| Platform | Public default (`dev`) | Official `next`/`prod` |
|----------|--------------------------|------------------------|
| macOS *(done)* / iOS *(planned)* | `AppInfo.xcconfig` derives name + bundle id from `HALO_EDITION` (default `dev`, ad-hoc signing) | CI writes `HALO_EDITION = next\|prod` into `Local.xcconfig`; team/cert come from `app_dist/macos/Signing.xcconfig`, and CI Developer ID-signs |
| Android *(planned)* | `build.gradle.kts` defines only the `dev` product flavor | `apply(from = …/app_dist/android/editions.gradle.kts)` if present — adds `next`/`prod` flavors + signing |
| Windows *(planned)* | CMake / `Runner.rc` dev identity | `include(…/app_dist/windows/edition.cmake OPTIONAL)` — AUMID, MSIX identity, cert |
| Linux *(planned)* | `CMakeLists.txt` dev `APPLICATION_ID` | `include(…/app_dist/linux/edition.cmake OPTIONAL)` — app id, desktop file, AppImage/Flatpak packaging |
| Web *(planned)* | builds with `HALO_EDITION=dev` | deploy targets + Cloudflare Pages project names in `app_dist/` |

On macOS, `HALO_EDITION` is a plain xcconfig variable: `PRODUCT_BUNDLE_IDENTIFIER =
com.ham2k.logger.$(HALO_EDITION)` and `PRODUCT_NAME =
$(HALO_PRODUCT_NAME_$(HALO_EDITION))`. xcconfig substitutes variables in setting
*values* (including nested lookups) but **not** in `#include` paths — which is why
the edition is a value switch and the dist include (`Signing.xcconfig`) keeps a
fixed name.

**What lives in `app_dist/` (dist-only):**

- The per-platform edition/signing fragments above (`next`/`prod` bundle ids,
  names, certs, provisioning).
- The **official CI build logic**, `app_dist/ci/build-macos.sh`, and the
  `codemagic.yaml` that calls it. Codemagic only reads a `codemagic.yaml` at the
  repo **root** (no custom path, no includes), so that file has to live there
  even though it is dist-only; the publish filter drops it by name rather than
  by prefix. Its workflows are thin declarations that just run
  `bash app_dist/ci/build-macos.sh` — the signing and notarization steps live in
  that dist-only script — but the file still enumerates every credential group
  and release channel, which is what keeps it out of public. It is fine for a
  public file to *reference* `app_dist/`; what stays out is the contents. No
  secrets sit in either — certs live in Codemagic's encrypted env groups, the
  team in `app_dist/macos/Signing.xcconfig`.
- **Shorebird** config — the two Shorebird app ids (Next, Regular) and their track
  setup (§4.3).
- **Appcast** feed configuration/URLs for desktop auto-update (§3.2), per edition.
- **Extension OTA** endpoint + signing keys (§6).
- Store/notary credential references (already env-group based).

**What stays public:** every `dev` flavor definition, the optional-include seam
itself (harmless no-ops), `halo_build_tools`, `version.dart`, edition-aware
branding, and a "build Dev yourself" guide. **Success criterion for any change
here: a clean public checkout with no `app_dist/` still builds and runs `dev` on
every platform.**

---

## 9. Open items / decisions to confirm

- Choice of desktop updater package (`auto_updater` vs. `desktop_updater` /
  `flutter_desktop_updater`) — decide based on whether one package covering Linux
  is worth its trade-offs.
- Validate rig/serial hardware access under Flatpak (and Snap) sandboxing.
- Decide whether Next is a separate iOS/macOS app record or a distinct bundle ID
  on the same record.
- Define the extension min-API/version contract and its enforcement point.
- Define how the sync service links regular ↔ Next profiles at the app layer.

---

## Appendix — sources

- Shorebird — Overview: https://docs.shorebird.dev/code-push/
- Shorebird — Production Desktop Support (Feb 2025): https://shorebird.dev/blog/desktop-in-production/
- Shorebird — Custom Update Tracks: https://shorebird.dev/blog/custom-tracks/
- Shorebird — Tracks, Percentage Rollouts and A/B testing: https://shorebird.dev/blog/tracks-percentage-rollouts-a-b-testing/
- Shorebird — Staging Patches: https://docs.shorebird.dev/code-push/guides/staging-patches/
- Shorebird — FAQ: https://docs.shorebird.dev/code-push/faq/
- auto_updater (Sparkle/WinSparkle): https://pub.dev/packages/auto_updater
- flutter_desktop_updater: https://github.com/MarlonJD/flutter_desktop_updater
- Flutter — Desktop support: https://docs.flutter.dev/platform-integration/desktop
- Apple — App Review Guidelines (2.5.2 / 3.3.1): https://developer.apple.com/app-store/review/guidelines/
- Bitrise — What App Stores allow with OTA updates: https://bitrise.io/blog/post/what-app-stores-allow-with-ota-updates-apple-and-google-policy-explained
- Google Play — Device and Network Abuse policy: https://support.google.com/googleplay/android-developer/answer/16559646?hl=en
- Android Developers — Dynamic Code Loading: https://developer.android.com/privacy-and-security/risks/dynamic-code-loading

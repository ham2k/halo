# Ham2K Logger — Release Architecture

> Status: draft · Last updated: 2026-07-14

This document describes how Ham2K Logger is versioned, built, distributed, and
updated across every platform it targets, and how the "Next" pre-release variant
runs alongside the stable product. It captures the lessons carried over from the
React Native Ham2K PoLo release process and adapts them to Flutter + Shorebird.

Targets: **Android, iOS, Windows, macOS, Linux, Web.**

---

## 1. Core model

Releases follow a **monthly cadence**. Each month a new *main version* is cut,
named after its target month (e.g. `26.8`). Between main versions, fixes and
small improvements ship continuously as **patches**, without a new store binary.

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

The app carries **two distinct version identities**, each with a different owner
and mutability:

- **Public-facing version** (§2.1) — the human-readable `MAJOR.MINOR.PATCH` shown
  in the UI, logs, and sync metadata. It lives in **Dart**, so a Shorebird patch
  can rewrite it, and no store validates it (so `-preN` labels are safe).
- **Build/release identity** (§2.2) — the number baked into the native binary at
  build time, encoded to satisfy each platform's format rules. It is **frozen for
  the life of a binary** (Shorebird cannot change it) and is also the key
  Shorebird uses to match patches to a release.

Section 2.3 explains how the patchable public version is stored.

### 2.1 Public-facing version — `MAJOR.MINOR.PATCH`

- **`MAJOR.MINOR`** is the *main version*, `YY.M` — the two-digit year and the
  **target month** (e.g. `26.8` = the August 2026 line). Because Next runs ahead
  (§2.5), the main version usually carries the *following* month's name and
  branding while it is still being built.
- **`PATCH`** (third component) increments continuously after a main version ships:
  `26.8.0` → `26.8.1` → `26.8.2` … Most increments are **Shorebird patches**
  (Dart-only, no new binary). Occasionally a full binary rebuild is needed
  mid-cycle; it simply takes the next number in the same sequence (e.g. `26.8.3`
  as a full build). The `PATCH` number is a continuous counter — its value does
  not by itself say whether an increment was a patch or a full build.
- **Pre-release suffix** (Next only): binary pre-releases append `-preN`
  (`26.8.0-pre1`, `26.8.0-pre2`, …). A Shorebird patch applied to a pre-release
  appends a further counter: `26.8.0-pre1.1`.

Every patch/pre-release is bound to the exact release build it was compiled
against (see §4.1).

### 2.2 Build/release identity — one build, per-platform encodings

The canonical build id is the strictly-increasing integer **`YYMM·MMDD·S`**:

| Segment | Meaning | Example |
|---------|---------|---------|
| `YYMM` | the **version's** year + target month | `2608` (for `26.8`) |
| `MMDD` | the **build date** (may be an earlier month than the version) | `0729` (July 29) |
| `S` | one sequential digit for multiple builds the same day | `1` |

Example: **`260807291`** = version `26.8`, built **July 29**, sequence `1` — the
official `26.8.0` release. Version month (`08`) and build month (`07`) legitimately
differ because the line is branded for the coming month.

CI projects this single build id into each platform's required native fields. Each
platform has hard format limits, and the projection must respect them:

| Platform | Native field(s) | Constraint | This build |
|----------|-----------------|------------|------------|
| **Android** | `versionCode` / `versionName` | code ≤ **2,100,000,000**, strictly increasing, single-use | `260807291` / `26.8.0` |
| **iOS / macOS** | `CFBundleVersion` / `CFBundleShortVersionString` | build ≤ **18 chars**; marketing = **≤ 3 integers, no suffixes** | `260807291` / `26.8.0` |
| **Windows** | MSIX / `FILEVERSION` `a.b.c.d` | each part **0–65535**, major ≠ 0, **revision = 0** for Store | `26.8.7291.0` |
| **Linux** | package version | numeric, monotonic ordering | `26.8.7291` |
| **Web** | — | none (server-deployed) | n/a |

Three projection rules follow from the table:

- **Windows/Linux build part = `MMDD·10 + S`** → `7291` here, max `12319` (Dec 31,
  seq 9), safely under 65,535 and increasing through the month. Windows appends the
  mandatory `.0` revision (`26.8.7291.0`); **Linux uses `26.8.7291` directly**.
  Linux needs no `~preN` suffix — the numeric build id already orders correctly and
  is unique, so a Next pre-release simply carries a lower build number.
- **iOS marketing string cannot carry `-preN`.** `CFBundleShortVersionString` must
  be pure `X.Y.Z`, so the plist marketing version stays `26.8.0` for all of
  `pre1`, `pre2`, and the final release; the pre-release label lives in the app UI,
  TestFlight notes, and the build number. This is fine because App Store Connect
  only requires the *build number* to increase per marketing-version string.
- The **9-digit build id fits Android and iOS/macOS as-is** for every year up to
  `99` (`991212319` ≈ 991 M, under the 2.1 B cap).

### 2.3 Where the public version lives (patchable)

Because Shorebird patches only swap Dart, the public version must live in
**compiled Dart** — e.g. a constant in `lib/version.dart`:

```dart
const kPublicVersion = '26.8.1';
```

A patch that bumps the public version edits this file; the new string ships inside
the patch and updates on-device when the patch lands.

- **Do not source it from `package_info_plus`** — that reads the native
  Info.plist/manifest (the frozen build identity), which a patch can't change. Use
  `package_info_plus` only to display the *build* number.
- **Optionally derive it** from the Shorebird runtime's current patch number
  (`"$base.${patchNumber ?? 0}"`) so you can't forget to bump it; keep an explicit
  override for `-preN` labels and full-rebuild jumps.
- **About screen** should show all three layers: `26.8.1 (build 260807291, patch
  3)` — public version for humans, build number pins the native binary, patch
  number pins the Dart layer.
- **Sync/log metadata** should record both the public version *and* the
  build+patch fingerprint, since only the latter reproduces a device's exact code.

### 2.4 Extension version

Independent semver per extension, gated by a minimum app/API version (see §6).

### 2.5 Release lifecycle (worked example, the `26.8` line)

1. **Pre-releases on Next.** Binary builds ship to **Logger Next** first, branded
   for the coming month: `26.8.0-pre1`, `26.8.0-pre2`, … each with its own build
   number (`2608` + its build date + seq). Fixes between pre-releases can go out as
   Next Shorebird patches, e.g. `26.8.0-pre1.1`.
2. **Stabilize.** When a pre-release is judged stable enough (say **July 29**), it
   is promoted to the official **`26.8.0`**, build `260807291`. **Both** Logger and
   Logger Next receive this release.
3. **Patch through the month.** Subsequent fixes ship as Shorebird patches
   `26.8.1`, `26.8.2`, … all based on the official build `260807291`.
4. **Rare full rebuild.** If a change can't ride a patch (native/engine/plugin),
   cut a new full binary that takes the next number in sequence, e.g. `26.8.3`,
   with its own build number. Then resume patching until the next monthly line
   (`26.9`) begins on Next.

### 2.6 Products and identity

Two products share the codebase via **Flutter build flavors**, each with its own
application identity so both can be installed side by side with fully separate data
and settings:

| Product | Identity (all platforms) |
|---------|--------------------------|
| **Ham2K Logger** (stable) | `com.ham2k.halo.prod` |
| **Ham2K Logger Next** (pre-release) | `com.ham2k.halo.next` |

The same identity is used for every platform's identifier — Android
`applicationId`, iOS/macOS bundle ID, Windows package identity / AUMID, and Linux
app ID (desktop file / package name). The `.prod` / `.next` leaf distinguishes the
two flavors under a shared `com.ham2k.halo` base.

**Why dot-segments, not a hyphen.** `com.ham2k.halo-next` is invalid: Android
`applicationId` allows only `[a-zA-Z0-9_]` per segment (hyphens rejected), and
Flatpak/D-Bus discourage hyphens. Dot-separated leaves are valid on every platform,
so a single consistent identifier works everywhere and avoids per-platform
divergence.

Different identities mean the OS treats the two as distinct apps and isolates their
data automatically. Any linkage between a user's regular and Next data is an
**app-layer concern of the sync service** (e.g. same account, per-install profiles)
and is deliberately kept out of the release/packaging machinery so a sync change
can never entangle distribution.

---

## 3. Binary plane — full app updates

The binary plane delivers everything Shorebird and the extension channel cannot:
engine upgrades, native code, plugins, new permissions, and bundled assets. Every
monthly main version is a binary release.

### 3.1 Store-distributed installs

- **iOS / macOS**: App Store (stable), TestFlight (Next). No sideload path exists
  on iOS, so "out-of-store auto-update" simply does not apply there.
- **Android**: Google Play (stable), Play testing track — internal/closed/open —
  (Next).

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

---

## 4. Dart patch plane — Shorebird code push

Shorebird delivers **Dart-only** changes over the air, with no store submission,
across **Android, iOS, Windows, macOS, and Linux** (desktop code push went to
production in Feb 2025). **Web needs no code push** — a Flutter web build fetches
the latest version from our server on load.

### 4.1 Release binding (the key difference from CodePush)

A Shorebird patch is bound to the **exact release build it was compiled against**.
Coming from App Center CodePush — where a deployment key loosely tracks a channel —
this is the important mental-model change:

- Each monthly binary is a distinct Shorebird **release**.
- Patches target that release version specifically.
- Tooling must build/promote patches **per active release line**, not globally.

This actually fits the monthly-binary + continuous-patch model exactly; it just
has to be respected in CI.

### 4.2 What may ride a patch

Patches must be **pure Dart**. Anything touching plugins, the engine, native
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
  a patch reaches the stable track.
- **Next** has its **own Shorebird app** (Shorebird keys per app identity), so it
  carries its own `bleeding-edge`/`unstable`/`stable` tracks independently.

### 4.4 App Store policy note

Apple 3.3.1 permits hot-patching only where it does not change the app's intended,
advertised purpose. Keep patches to fixes and tweaks, not features that alter what
review was told the app does.

---

## 5. Linux distribution

Shorebird patches work on Linux; the effort is in **binary distribution and
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
engine (flutter_js/QuickJS or a WebView). Because they are **content we serve**,
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
the same release-binding discipline Shorebird enforces for patches.

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

---

## 7. Product/variant/track/platform matrix

Regular + Next × platforms × tracks is a large surface. It must be driven by CI,
not by hand.

```
                  Binary plane          Dart patches (Shorebird)      JS extensions
                  ------------          ------------------------      -------------
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
- Cut Shorebird releases and build/promote patches **per active release line**.
- Publish and sign JS extension bundles.

Codemagic has first-class Shorebird support; GitHub Actions is the alternative.
Either way, one config should drive the whole matrix — otherwise the monthly
release becomes a manual slog.

---

## 8. Open items / decisions to confirm

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

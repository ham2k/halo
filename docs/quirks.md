# Build & Platform Quirks

Workarounds we carry for upstream or platform bugs. Each entry records what
breaks, why, and where the fix lives — so nobody later "cleans up" a
load-bearing workaround without knowing what it protects.

## `flutter_inappwebview_macos` does not compile under Swift Package Manager

**Breaks:** `flutter build macos` fails outright — not a test failure, so the
Dart suite passes clean while the app cannot be built.

> error: protocol 'ASWebAuthenticationPresentationContextProviding' requires
> 'presentationAnchor(for:)' to be available in macOS 10.14 and newer

The plugin's `Package.swift` declares `.macOS("10.14")`, but its own
`presentationAnchor(for:)` — the witness for that protocol — is annotated
`@available(macOS 10.15, *)`, and Swift requires a witness to be available at
the conformance's minimum. Under CocoaPods this never bit, because Flutter's
podhelper raises every pod's `MACOSX_DEPLOYMENT_TARGET` to the app's (10.15);
SPM honours the package's own declaration and an app cannot raise it. 6.2 is
the first version to ship an SPM manifest, so the bug arrives with it. iOS is
unaffected — there the same witness is annotated `@available(iOS 12.0, *)`,
matching its declared `.iOS("12.0")`.

**Carried for it:** `packages/flutter_inappwebview_macos_patched`, a copy of
the published package that is byte-identical apart from that one line, wired
in through `dependency_overrides`. Its `PATCH.md` holds the verification and
re-vendoring commands.

**Rejected alternatives**, both tested rather than assumed:

- Holding `flutter_inappwebview_macos` at 1.1.2 while the rest takes the beta.
  Resolves, and `flutter analyze` passes — then the kernel snapshot fails,
  because the old implementation reads
  `PlatformPrintJobControllerCreationParams.onComplete`, which the beta's
  platform interface no longer has. **Analyze does not validate a dependency
  override; only a build does.**
- `flutter: config: enable-swift-package-manager: false` in `app/pubspec.yaml`
  — a genuine project-scoped switch that beats global config, but it moves
  *every* Apple plugin back to CocoaPods (sentry, sqlite3 included),
  needs a `pod repo update` locally and in CI, and runs against Flutter's own
  push to deintegrate CocoaPods.

**When to revisit:** when an upstream release declares `.macOS("10.15")` or
later. Upstream has not committed since 2026-02-10.

## Linux has no web view, and the override in `app/pubspec.yaml` keeps it that way

**Breaks:** anything that builds an `InAppWebView` dies on Linux at widget
build time — an assertion in debug, a `TypeError` in release.

`flutter_inappwebview` 6.2 endorses a Linux implementation, so the absence is
now deliberate rather than incidental. That implementation is backed by WPE
WebKit, and `flutter_inappwebview_linux`'s CMake is a `FATAL_ERROR` when WPE
is missing. No Ubuntu after 22.04 ships WPE in any form — Launchpad #1981592
removed it as an "unmaintained web engine" **and** blacklisted Debian syncs —
and that includes the noble image `linux-x64-next-release` and
`linux-arm64-next-release` build on. Taking the real package fails the
AppImage builds at CMake configure time.

So `app/pubspec.yaml` carries a `dependency_overrides` entry pointing
`flutter_inappwebview_linux` at `packages/flutter_inappwebview_linux_stub`,
a package of the same name whose Linux plugin declaration is Dart-only
(`dartPluginClass`, no `pluginClass`) and whose `registerWith` deliberately
registers nothing. Result: `native_build: false`, no CMake on the Linux
builders, and `InAppWebViewPlatform.instance` unset exactly as before.

**Do not "fix" this by deleting the override.** It is what keeps both Linux
release workflows building — and `app_dist/pubspec.yaml` carries the same
block, because `dependency_overrides` apply only in the package being
resolved as root and do not reach a package that path-depends on `app`.
Keep the two lists identical.

`app/test/webview_plugin_overrides_test.dart` enforces all of this, so the
warning above is not the only thing standing between a tidy-up and a broken
release. It asserts against the generated `.flutter-plugins-dependencies`
that Linux still resolves to the stub with `native_build: false`, that macOS
still resolves to the patched copy, and — by calling it — that the stub's
`registerWith` leaves `InAppWebViewPlatform.instance` untouched. Removing
the override fails all three tests in its `the Linux web view stays absent`
group; the published package's own `registerWith` registers a real instance,
which is what the last of the three catches.

It cannot catch the native half. Nothing in the Dart suite compiles Swift or
configures CMake, so a re-vendored macOS package missing its one patched
line passes everything and breaks `flutter build macos`.

**Carried for it:**

- **OAuth login** (`app/lib/views/oauth_browser_login.dart`). The sign-in page
  opens in the operator's own browser everywhere; what Linux and Web lack is a
  way for the authorization code to come back, so they route through LoFi's
  webhook relay, picked by `oauthUsesWebhookRelay` (Windows joins them for the
  same reason — it registers none of the schemes either, HALO-178). On Linux a
  custom-scheme redirect has no way home at all: the `.desktop` file registers
  no scheme handler and has no `%u`, `app_links` is fed only by gtk
  `command-line`/`open` signals our runner never emits (it overrides
  `local_command_line` and calls `g_application_activate`), and the runner is
  `G_APPLICATION_NON_UNIQUE`.
- **Maps** (`app/lib/views/operation/map_panel.dart`). Linux falls through to the
  OSM backend rather than the MapLibre webview one — see the Linux entry in
  [backlog.md](backlog.md).
- **HTML extension panels** (`app/lib/views/operation/panel_content_view.dart`).
  The pane's own probe returns early for Linux, so it stays on the
  `htmlPanelUnsupported` message and never constructs a web view.
- **The Web Site panel** (`app/lib/views/operation/website/website_panel.dart`).
  Its probe returns early for Linux, so the pane shows `websiteUnsupported`
  and offers the site to the OS browser instead of showing a page. This is the
  only entry here an operator can add deliberately and then find inert, so it
  is the one most likely to be reported as a bug.

**When to revisit:** HALO-220 holds the engine evaluation and the triggers.
"When 6.2 goes stable" is retired as a trigger — we took the beta, and it did
not help.

## `flutter_secure_storage` on Linux needs libsecret AND a Secret Service

**Breaks:** two different ways, and they are worth keeping apart.

- **The libsecret SHARED LIBRARY is absent.** `flutter_secure_storage_linux`
  links it with `pkg_check_modules(... REQUIRED ...)` and bundles nothing, and
  our AppImage/tarball take every library from the host — so `ld.so` fails before
  `main()`. No window, no dialog, no Sentry event, nothing for the operator to
  search for. **Nothing in the app can report this**; it is why the requirement
  is documented rather than detected.
- **libsecret is present but no Secret Service is running** (no gnome-keyring,
  KWallet or KeePassXC), or the keyring will not unlock. Reads and writes throw.
  libsecret reports all three of "no service", "no default collection" and
  "locked" as the SAME `KeyringLocked` code, so no message may claim which.

**Carried for it (#438):** `SettingsService.ensureSyncDeviceKey` returns null
rather than throwing, so boot completes and sync stays off;
`ExtensionService.getAccountCredentials` answers **null** — distinct from `{}`,
which means "not connected" — and the Accounts panel and account dialog say so
instead of spinning; one notice, once, on Linux, names what to install.

**Decided, deliberately NOT done:** bundling libsecret into the artifacts, and
any file-backed credential store. Bundling fixes only the first failure, leaves
most of that population in the second, and addresses one of at least two
identically-shaped host dependencies (`libsentry.so` needs the host's libcurl the
same way) — with no Linux machine in the loop to verify it. A local file store
would put the key beside the data, which is the downgrade
`settings_service.dart` already refuses for the device key.

**When to revisit:** if a user reports the launch failure — which they now can,
because the requirement is written down where they can find it.

Add the next one here rather than leaving it to be rediscovered.

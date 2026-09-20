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
the conformance's minimum. Under CocoaPods this never bit, because the pod
inherits the app's `MACOSX_DEPLOYMENT_TARGET` (12.0) — see the Xcode 27 entry
below for which pods Flutter's podhelper does that for, and which our Podfile does;
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

## Xcode 27 rejects deployment targets, and a `lipo` call, that older toolchains accept

**Breaks:** under Xcode 27 every macOS and iOS build fails — not a test
failure, so the Dart suite passes clean while neither app can be built. Two
separate errors, and the second only appears once the first is fixed:

> error: The macOS deployment target 'MACOSX_DEPLOYMENT_TARGET' is set to
> 10.13, but the range of supported deployment target versions is 12.0 to
> 27.0.x. (in target 'Sparkle' from project 'Pods')

> Target release_unpack_macos failed: Exception: Binary …/FlutterMacOS does
> not contain architectures "arm64 x86_64".

**Deployment targets.** Xcode 27 supports macOS 12.0+ and iOS 15.0+, and a
target below that is an error rather than a warning. The app's own floors
already sit there; the pods' do not. Flutter's podhelper
(`flutter_additional_macos_build_settings` / `…_ios_…`) lets a pod inherit the
app's floor only when the pod's target is below 10.15 (macOS) or 13 (iOS)
**and** the pod depends on Flutter — so `Sparkle` (10.13) and `libserialport`
(10.11), which do not depend on Flutter, and Flutter's own `FlutterMacOS`
(exactly 10.15) and `Flutter` (exactly 13.0), all keep a value Xcode refuses.

**Carried for it:** the `post_install` hook in `app/macos/Podfile` and
`app/ios/Podfile` raises any pod configuration below the Pods project's floor
up to it. CocoaPods derives that floor from the Podfile's `platform` line, so
it is declared once per platform — and the same hook refuses to run while the
Runner project's deployment target says anything else. The hook is raise-only by design: a
pod that needs *more* than the floor keeps its value, so that incompatibility
still fails the build. Forcing every pod to the floor, or deleting the key so
every pod inherits, would hide it.

**`lipo`.** The second error is misleading: `lipo -info` on that binary lists
both architectures. Flutter below 3.44.9 verifies a framework with one call,
`lipo <binary> -verify_arch arm64 x86_64`, and Xcode 27's `lipo` accepts a
single architecture there ("-verify_arch requires exactly one input file"),
so every multi-architecture build fails: macOS release and profile, and the
iOS generic simulator. A single-architecture build — macOS debug — never
reaches it, which is why a debug build passing says nothing about a release.

**Carried for it:** the Flutter pin is at least **3.44.9**, which verifies one
architecture per call ([releases.md §4.5](releases.md) holds the pin and its
other floor). On an older pin, `FLUTTER_XCODE_ARCHS=arm64 flutter build …`
builds a single-architecture binary for local checks only.

**Nothing re-checks this.** The release pipeline pins an older Xcode, so only
a local build under Xcode 27 exercises either half.

**When to revisit:** the `lipo` half has no workaround left to remove — it is
a floor on the pin, and goes away when 3.44.9 is no longer a version anyone
would pin. The Podfile hooks can go when a build with them deleted passes
under the newest Xcode: that needs every pod to ship a supported target and
podhelper to stop gating its own rule on a Flutter dependency.

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

`app/test/platform/webview_plugin_overrides_test.dart` enforces all of this, so the
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
  webhook relay, picked by `oauthUsesWebhookRelay`. On Linux a custom-scheme
  redirect has no way home at all, and for two separate reasons: the
  `.desktop` file registers no scheme handler and has no `%u` (HALO-121), so
  nothing hands the app a URL in the first place; and the runner is
  `G_APPLICATION_NON_UNIQUE`, so even a URL that arrived would start a second
  process rather than reaching the running one (HALO-500).

  Windows has the first half — it registers the schemes and forwards them to
  the running instance (HALO-178) — so its redirect no longer wants for a
  scheme. `oauthUsesWebhookRelay` still routes it through the relay, and
  should keep doing so until someone verifies the native path on a real
  machine.
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

## On the web a web view is an iframe, and its sandbox grants top-level navigation

**Breaks:** nothing visibly — which is the problem. `flutter_inappwebview_web`
renders an `<iframe>`, and what an extension's `html` panel is actually held to
there is not what the policy in `panel_content_view.dart` says.

Which platform enforces what (checked against the pinned 6.2.0-beta.3 family):

| | JS off | network blocked | navigation cancelled |
| --- | --- | --- | --- |
| iOS / macOS | yes | yes — `contentBlockers` | yes |
| Android | yes | yes — `blockNetworkLoads` | yes |
| Windows | yes | **no** | yes |
| Web | yes | **no** | **no** |

Two things follow, and it is worth keeping them apart.

**The network gap is not web-specific.** Windows has no implementation of
`blockNetworkLoads`, `blockNetworkImage` or `contentBlockers` either, and still
renders panels. That is the case `docs/extensions/hooks.md` already describes:
no-network is a rule a panel author must follow, not one they are held to
everywhere. Do not cite it as the reason the web is refused — it would argue
just as well for refusing Windows.

**The navigation gap is.** The web package honours `javaScriptEnabled: false`
by removing `allow-scripts`, but the sandbox attribute it then writes is every
OTHER token — `allow-top-navigation`, `allow-popups`, `allow-same-origin`
included. An extension's document can therefore navigate the whole app away or
open windows, and `shouldOverrideUrlLoading` is not a reliable veto over an
iframe's own top-level navigation the way it is over a native web view's. That
is a hijack rather than a leak, it is strictly worse than any platform we do
render on, and `_SandboxedHtmlView`'s comments lean on the navigation block
harder than on anything else.

**What we do:** `panel_content_view.dart` refuses `kIsWeb` at the `case 'html'`
branch, before `_HtmlPanelView`, with its own message
(`htmlPanelUnsupportedOnWeb`) — the platform HAS a web view, so the
`htmlPanelUnsupported` wording would be untrue.

Deliberately NOT folded into `probeWebviewSupport`: the Web Site pane shares
that probe and legitimately runs on the web, because it loads the operator's
own URL under no sandbox at all. The trust source is what differs, not the
platform.

**Testing it.** `kIsWeb` is a compile-time constant, so the branch is compiled
away on the host VM: no override reaches it, and a case added to
`panel_html_platform_gate_test.dart` would assert the native branch while
reading as coverage of both. A browser is the only place the condition is true
at RUNTIME — but the risk here is a future edit silently dropping the guard,
and that is caught by reading the source instead.
`panel_html_web_gate_test.dart` scans `panel_content_view.dart` for the check,
the way `no_hover_tooltips_test` and `links_leave_the_app_test` enforce their
own invisible conventions. It runs on the host VM like any other test.

A true runtime test in a browser is still not possible:

But a `--platform chrome` test that imports `panel_content_view.dart` HANGS —
reproducibly, at `loading`, at 0% CPU, indefinitely. Bisected:

- `settings_fuzzy_test.dart` (the existing browser test) passes in seconds
- `flutter_inappwebview` alone in a browser test passes
- each of `panel_content_view.dart`'s other imports passes alone
  (flutter_markdown, flutter_svg, halo_widgets, strings.g, error_reporting_service,
  link_opener, windows_webview)
- **all eight of those imports together pass**
- importing `panel_content_view.dart` itself hangs

So it is that library's own DDC module, not its dependency closure, and the
cause is not yet known. Do not wire such a test into `scripts/test.sh
--browser` before this is understood: the step is part of the full gate, and a
hanging test there blocks every merge rather than failing one.

The gate itself is one `kIsWeb` check and is verified by reading; the risk it
carries is that a future edit removes it silently. That is what this entry is
for.

## Windows: a map click blurs the page mid-press, and MapLibre drops the drag

**Breaks:** dragging the map on Windows — on and off, sometimes every other
drag, sometimes never — while marker clicks and wheel zoom keep working.

`flutter_inappwebview_windows` hosts WebView2 in composition mode and forwards
Flutter's pointer events with `SendMouseInput`. Chromium takes keyboard focus
on every mousedown it receives; its window sits under a hidden *owned*
top-level the plugin creates, so that focus change deactivates the main
window, and the runner's `WM_ACTIVATE` handler (`win32_window.cpp`) refocuses
the Flutter view at once — unconditionally, on `WA_INACTIVE` too. The page
therefore sees a window `blur` in the middle of every press. MapLibre's
handler manager treats a blur as "stop every gesture", which disarms the drag
the mousedown just started; whether the blur or the mousedown reaches the
page first is a race, hence the erratic pattern.

**Where the fix lives:** `mapbox_webview_map_view.dart` builds the map page
with `suppressWindowBlur` on Windows, a capture-phase `blur` listener in the
page's head that stops the event before MapLibre's own listener (registered
later) runs. Keyboard focus stays in Flutter, which is what a logger wants.
Nothing is changed on other platforms: the blur-cancels-drag behaviour is what
ends a drag cleanly when the window really does lose focus mid-gesture.

The focus round-trip itself (main window deactivated and reactivated within
one press) still happens on every map click. Nothing visible depends on it
today; if it ever does, the runner's unconditional `SetFocus` on
`WA_INACTIVE` is where to look.

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

## Web: a list rebuilt in place keeps its old accessibility geometry, and clicks land on the wrong row

**Breaks:** a click acts on a row the operator did not click. On the web, with
the accessibility DOM active, the row under the pointer does nothing and a row
near it acts instead — a toggle flips the wrong item, a picker chooses the
wrong entry. Not a logic bug in the list, and it reads exactly like one.

On the web a click never reaches the canvas. Flutter mirrors the widget tree
into `<flt-semantics>` elements layered over it, and for a scrolling list it
places every row inside a real scrollable element. Those elements are what the
browser hit-tests and what dispatches the tap. When a list's contents change
while the same scrollable stays mounted — a search filter narrowing it, a row
removed, a re-sort — those elements can keep the previous list's geometry:
they end up roughly a row's height from what is painted, and the click goes to
whichever node sits at that pixel.

Measured on Flutter 3.44.6, Manage Extensions filtered to "qso" (3 results):

| clicked (painted) | DOM node actually hit | result |
| --- | --- | --- |
| North American QSO Party | "Contests" section header | nothing |
| Spot History | "Callsign Lookups" header | nothing |
| Call History | **Spot History** | the wrong extension toggled |

**It is not a rare configuration.** Orca's embedded browser has the
accessibility DOM on, so it is the standing condition for our own web testing,
and it is always on for anyone using a screen reader. If `HALO-122` ever
forces semantics on, it reaches every web user.

**What we do:** give such a list a `key` derived from WHICH rows it holds —
`listContentsKey` in `halo_widgets` — so a changed row set builds a fresh
scrollable whose nodes are positioned from scratch. Keyed by the row set
rather than by the query behind it: a filter is not the only thing that
changes the rows, and a change that leaves the set alone (toggling a row's
own switch) must NOT remount, or every list churns its elements on every
interaction.

**What does not need it:** a list whose rebuild leaves every existing row where
it was — an append at the END moves nothing below it, so nothing goes stale.
The trigger is rows MOVING, which is what a filter, a removal, a re-sort and a
PREPEND all do, and an append does not. A newest-first log prepends on every
entry, so "it only gains rows" is not the exemption it sounds like.

Identity is a proxy for movement and not a complete one: anything that changes
a row's HEIGHT moves every row below it while the set is untouched — a locale
change rewriting every label, a subtitle that wraps at one font scale and not
another. A list whose rows change height under it needs its own thinking.

**A row set the list cannot see** still has to reach the key. Where the rows
come from children that decide their own contents — the Settings panel's
categories each load and filter their own — the child reports a changed set
upwards and the list keys on that; a group growing sub-options when a toggle
goes on moves every row below it with the query and everything else
untouched.

**A list that cannot afford to be remounted** takes the key anyway and keeps
its children through it: give each child a `GlobalKey` and the framework MOVES
it into the fresh scrollable rather than disposing it with the old one. The
Settings panel does this — its forms own the focus nodes the operator is
typing against, and disposing them empties the search field (the live-filter
rule in user-interface.md) — so "the rows hold state" is not on its own a
reason to leave a searched list unkeyed.

**Not testable here.** The Flutter test harness has no web semantics DOM, so a
widget test cannot fail when this breaks; one would read as coverage and
assert nothing. Verification is by measurement against a running web build:
read each row's painted position, ask `document.elementFromPoint` what the DOM
has at that pixel, and compare. The method and the before/after numbers are on
`HALO-530`.

**Revisit** on a Flutter upgrade — this is an upstream defect in the engine's
semantics geometry, not a design decision. When it is fixed, these keys become
churn on every filter keystroke and should come out together.

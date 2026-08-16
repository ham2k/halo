# Backlog

Known gaps and planned work not yet turned into GitHub issues. Architectural
*risks* (things that could invalidate the design) stay in
[DESIGN.md](../DESIGN.md) §11; this file tracks incomplete features and
unverified platforms.

Most of the original feature backlog (secondary controls, QSO row layout,
radio/VFO service, exports panel, activities view, status bar, call stacking)
has shipped and was removed from this file on 2026-07-15.

## Windows map backend unverified; Linux has no webview path

The Map tab routes Windows to the `flutter_inappwebview` MapLibre backend
(`app/lib/views/map/mapbox_webview_map_view.dart`) — code-audited against
`flutter_inappwebview_windows` 0.6.0 (the bridge, `evaluateJavascript`,
`onConsoleMessage`, `transparentBackground` and `initialData` all have
Windows implementations, and the routing falls back to OSM when no WebView2
environment can be created) but still never run on a Windows machine.
Windows now runs `flutter_inappwebview_windows` 0.7.0-beta.3, on WebView2 SDK
1.0.3650.58, and the webview map backend **has** been run there since: a
Codemagic Windows build renders the MapLibre pane, which exercises the
app's own WebView2 environment, `initialData` and `evaluateJavascript` on the
new SDK. What remains unexercised is the rest of the bridge — `onConsoleMessage`,
`transparentBackground`, and the fallback path when no WebView2 environment
can be created (which by definition does not arise on a machine where one
can).
Two Windows-only caveats, also noted in the backend's header: every
`InAppWebView` must be given the app's own WebView2 environment
(`app/lib/services/windows_webview.dart`), because the plugin's own is
rooted next to the exe and fails outright where that directory is not
writable; and `NavigateToString` caps the document at 2MB (the page is ~10KB,
nowhere close).

Linux is routed to the OSM/`flutter_map` backend (markers/lines/callouts,
no globe) because it has no web view at all.

We are on `flutter_inappwebview` 6.2.0-beta.3, which *does* endorse a Linux
implementation — and `app/pubspec.yaml` overrides it away, because that
implementation needs WPE WebKit and its CMake is a `FATAL_ERROR` without it.
No Ubuntu after 22.04 ships WPE in any form (Launchpad #1981592 removed it
and blacklisted Debian syncs), including the noble image both AppImage
workflows build on, so taking the real package breaks the Linux release.
**Letting Linux into `map_panel.dart`'s webview branch would therefore not
give Linux a map — it would give it a blank pane**, since no implementation is
registered there. Two guards hold it out and both would have to go: the branch
names macOS and Windows, and `_webviewSupported` is only ever set for those
two, so widening the branch alone changes nothing.
`panel_html_platform_gate_test.dart` asserts the outcome rather than either
guard, and stays green until both move.

The engine evaluation, the routes that could actually work, and the revisit
triggers live on HALO-220 — the short version is that Ubuntu's only
security-supported engine is WebKitGTK, which exports the same DMA-BUF
buffers WPE does but publishes no API to reach them, so any Linux web view
is a build rather than a dependency.

## Web map backend needs a real-deployment shakeout

The web Map backend (`app/lib/views/map/mapbox_web_map_view.dart`) mounts
MapLibre GL JS on an `HtmlElementView` div via `<script>`-tag loading and
`js_interop`, sharing the marker/line/popup JS (`map_gl_script.dart`) with
the desktop webview backend. Verified against a dev
`flutter run -d web-server` build; still to check on a real deployment: CSP
headers allowing MapLibre's CDN (`unpkg.com`) and its tile providers
(`tiles.openfreemap.org`, `basemaps.cartocdn.com`).

## Sync onboarding UX is a bare-minimum banner, not a guided flow

`SyncEngine` (`packages/halo_core/lib/src/sync/sync_engine.dart`) does
pause-and-ask account reconciliation (combine/replace, backed by a full
backfill — `syncedUntilMillis`/`anyClient: true`, paging backward until
caught up, mirroring app-polo's `sync.js`) and a `SYNCALL` debug command
reusing the same backup-and-clear mechanism.

What's missing is app-polo's four onboarding *scenarios* as a guided UX
(`app-polo/src/store/sync/README.md`): new-install-vs-existing-account
framing, waiting-for-email-confirmation states, etc. Settings just shows a
plain Combine/Replace banner with no narrative around it.

## Scoring handlers ported from web-lofi are incomplete

The `scoring` hook ([extensions/hooks.md](extensions/hooks.md)) is
implemented as a single coarse-batched extension (`extensions/core/scoring`)
rather than web-lofi's per-ref-type bridge hooks. It covers duplicate-contact
detection, DXCC entities worked (resolved locally via
`@ham2k/lib-country-files`' `useBuiltinCountryFile`), bands and modes worked,
and US states / Canadian provinces — the last carrying web-lofi's
`USStatesScoringHandler` / `CanadianProvincesScoringHandler` lists inline,
since no state/province reference data lib is wired in. What remains from
web-lofi is its per-handler summary presentation (the struck-through
worked/unworked grid), not the rules.

## Contest support: exchange controls and an archetype extension

DESIGN.md §10's step 3 called for a contest archetype extension (NAQP or a
QSO party) alongside POTA and QRZ; it was never built. The UI catalog also
still only ships `refList` — a contest exchange needs a `textField` control
kind (deferred in work phases 4 and 5), and scoring needs contest rules
beyond the three core ones above.

## One logging-field focus rule still needs a decision

[design/logging-fields.md](design/logging-fields.md) specifies the focus and
keyboard-navigation contract for the main logging fields. All of it is
implemented except this, which is blocked on a decision rather than on the
work:

- **"Nothing focused → focus the callsign field" is not a standing rule.** It
  is enforced at first build and after specific actions (log, wipe, collapsing
  a secondary control, Space in the frequency field) rather than as an
  invariant. Making it standing means deciding what should happen when focus
  is dropped deliberately — including by the empty-field tap-to-blur
  (`TapToDismissEmptyField`), which would otherwise fight it on mobile.

## The QSO list has no "goto" search

APP-19 asked for Cmd/Ctrl-G — a field to jump to a QSO by number, or search by
callsign with jump-to-next/previous. Agreed shape: an overlay bar pinned at the
top of the QSO list.

The scrolling half is already built: `_QsoListState._revealSelected` works out
where any row is arithmetically and scrolls to it, however far outside the
viewport it started, so a goto only has to move the selection and let the list
follow. What's missing is the bar itself and the search over callsigns.

## Callsign lookup results are not cached

app-polo caches lookup results in the `lookups` table; HaLo re-queries QRZ/
Ham2K Lookup Service on every enrichment pass (deferred in phase 3, still
true — no lookup cache exists in `extensions/core/lookups` or
`ExtensionService`). Offline *datasets* are covered by the `dataFile` hook;
this is about per-callsign lookup results.

## Deferred from the 2026-07-14 architecture review

All P0/P1 findings from the 2026-07-14 architecture review were fixed in its
same-day remediation (Milestones A–D, annotated inline in the review — in
git history at `docs/reviews/2026-07-14-architecture-review.md`, removed
from the tree 2026-07-15). Three items were deferred by design and are
tracked only here:

- **Hard extension isolation.** The shipped containment is soft and
  single-realm — a hostile bundle can tamper with shared globals (`__polo`
  itself) — and there is no true execution-time interrupt on any platform
  (a `while(true)` hook is caught by the Dart-side timeout + host restart,
  not pre-empted). Both need DESIGN.md §3's direct-FFI QuickJS binding.
  Prerequisite for the third-party/OTA extension channel.
- **SDK contract versioning and a discriminated `Hook` union.** No
  `minCatalog`-style negotiation exists for the OTA channel, and the `Hook`
  type's `| Record<string, unknown>` arm erases misspelled-method errors.
  Also a third-party-channel prerequisite.
- **`LoggingControls` decomposition.** The ~2,600-line widget mixes keyboard
  shortcuts, command dispatch, VFO mirroring, undo, and form building; a
  structural refactor with no behavior change, deserving its own pass.

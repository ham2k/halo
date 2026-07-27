# Build & Platform Quirks

Workarounds we carry for upstream or platform bugs. Each entry records what
breaks, why, and where the fix lives — so nobody later "cleans up" a
load-bearing workaround without knowing what it protects.

The one long-standing entry — `flutter_js` failing to bundle its prebuilt
quickjs bridge on Linux — went away with `flutter_js` itself in Phase 3 of the
JS engine work ([design/js-engine.md](design/js-engine.md)).

## `flutter_inappwebview` has no Linux implementation

**Breaks:** anything that builds an `InAppWebView` crashes on Linux — an
assertion in debug, a `TypeError` in release, at widget build time. The plugin
declares `android/ios/macos/web/windows` (6.1.5) and is absent from
`app/linux/flutter/generated_plugin_registrant.cc`; `codemagic.yaml` excludes it
from the Linux build deliberately. It compiles; it dies when the route builds.

**Carried for it:**

- **OAuth login** (`app/lib/views/oauth_browser_login.dart`, #430/#431). On
  platforms with no webview the login runs in the system browser and the
  provider's redirect comes back as a link the operator PASTES. Paste is the
  only working return path on Linux, not a fallback: the `.desktop` file
  registers no scheme handler and has no `%u` (#260), `app_links` there is fed
  only by gtk `command-line`/`open` signals our runner never emits (it overrides
  `local_command_line` and calls `g_application_activate`), and the runner is
  `G_APPLICATION_NON_UNIQUE`. Fixing that needs #260 **plus** the runner.
- **Maps** (`app/lib/views/operation/map_panel.dart`). Linux falls through to the
  OSM backend rather than the Mapbox webview one — see the Linux entry in
  [backlog.md](backlog.md).

**When to revisit:** the same trigger the map entry already carries — when
`flutter_inappwebview` 6.2 goes stable, since 6.2.0-beta.3 endorses a WPE WebKit
Linux implementation ([backlog.md](backlog.md)). BOTH of the above want
revisiting together: they are one gap, and whoever bumps the plugin for the map
has no reason to discover the login page.

Add the next one here rather than leaving it to be rediscovered.

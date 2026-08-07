# Build & Platform Quirks

Workarounds we carry for upstream or platform bugs. Each entry records what
breaks, why, and where the fix lives — so nobody later "cleans up" a
load-bearing workaround without knowing what it protects.

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

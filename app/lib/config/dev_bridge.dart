// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A dev/preview-only bridge for inspecting (and later driving) the running app
// from outside it — so agents and scripts can query app state deterministically
// instead of pixel-hunting the Flutter canvas (ham2k/app-halo-dist#235). This
// read-only first cut exposes a state snapshot; the web installer
// (dev_bridge_installer.dart) surfaces it as `window.__halo`.
//
// Pure Dart with no web import, so it's inert off web and in production: nothing
// installs the JS entry point there, so [stateProvider] is simply never invoked.

/// The single bridge instance. The active screen registers a [stateProvider];
/// the web installer reads it.
class DevBridge {
  DevBridge._();
  static final DevBridge instance = DevBridge._();

  /// Whether the web entry point was actually installed (dev/preview build on
  /// web) — set by the installer. Screens gate their [stateProvider]
  /// registration on this, so nothing dev-only runs when the bridge is absent
  /// (native, or a production release), and the gate lives in ONE place: extend
  /// the installer's condition and registration follows automatically.
  bool installed = false;

  /// Supplies the current-state snapshot — set by the active screen
  /// (OperationView) on mount and cleared on dispose. Null when no screen has
  /// registered one (e.g. the home screen).
  Map<String, dynamic> Function()? stateProvider;

  /// A JSON-able snapshot of what the app is currently showing/composing, or a
  /// `{'view': 'none'}` placeholder when nothing is registered.
  Map<String, dynamic> state() => stateProvider?.call() ?? <String, dynamic>{'view': 'none'};

  /// Just the current callsign guess (grid/state/name/entityPrefix/…) from the
  /// snapshot, or null.
  Object? guess() => state()['guess'];
}

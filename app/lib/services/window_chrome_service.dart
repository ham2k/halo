// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The macOS traffic-light buttons float over the app's own AppBar (see
// platform_chrome.dart and macos/Runner/MainFlutterWindow.swift). To center
// them vertically, the native side needs the AppBar's height — but Flutter is
// the only side that actually knows it (it scales with the font-scale setting
// and could change with any header redesign). Rather than have the native
// code re-derive that height by mirroring Flutter's font-scale math — which
// drifts out of sync the moment the header changes — Flutter is the single
// source of truth and pushes the real height across this channel whenever it
// changes.
//
// The same channel also carries header gesture reports (double-click,
// Windows drag) and window-control actions, sent from halo_widgets'
// platform_chrome.dart (windowHeaderGestureArea, WindowsCaptionButtons)
// since that's where the AppBar helpers live, plus window-state pushes from
// the native side (received in [WindowChromeService.init]). The Windows
// runner (windows/runner/flutter_window.cpp) serves the same channel for
// its chromeless window.

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:halo_widgets/halo_widgets.dart' show macOSWindowIsFullScreen, windowsWindowIsMaximized;

class WindowChromeService {
  static const _channel = MethodChannel('ham2k/window_chrome');

  /// Chosen from the macOS app menu: "About" shows the release overlay,
  /// "Preferences…" (⌘,) opens the Settings view. The app wires these once its
  /// services and navigator are ready (see main.dart); the native side invokes
  /// them through this channel (macos/Runner MainMenu.xib + AppDelegate).
  static void Function()? onShowReleaseOverlay;
  static void Function()? onOpenSettings;

  static bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  /// Platforms where the runner strips the native window chrome and this
  /// channel stands in for it (macOS traffic lights over the header; Windows
  /// custom frame with Flutter-drawn caption buttons).
  static bool get _chromeless =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows);

  static double? _lastReported;
  static Size? _lastMinimumSize;

  /// Registers the receiving end of the channel. Call once at startup.
  /// Native pushes: macOS full-screen transitions (feed halo_widgets'
  /// [macOSWindowIsFullScreen] so the header drops the traffic-light
  /// clearance while the buttons live in the system's auto-hiding titlebar
  /// overlay) and Windows maximize state (feeds [windowsWindowIsMaximized]
  /// for the caption buttons' maximize/restore glyph).
  static void init() {
    if (!_chromeless) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'fullScreenChanged') {
        macOSWindowIsFullScreen.value = call.arguments as bool? ?? false;
      } else if (call.method == 'maximizedChanged') {
        windowsWindowIsMaximized.value = call.arguments as bool? ?? false;
      } else if (call.method == 'menuAbout') {
        onShowReleaseOverlay?.call();
      } else if (call.method == 'menuPreferences') {
        onOpenSettings?.call();
      }
      return null;
    });
    if (defaultTargetPlatform == TargetPlatform.windows) {
      _syncWindowsMaximizedState();
    }
  }

  /// The native side only pushes maximize TRANSITIONS, so a fresh Dart side
  /// (launch, hot restart) must pull the current state or a maximized
  /// window would show the wrong caption glyph until the next transition.
  static Future<void> _syncWindowsMaximizedState() async {
    try {
      final maximized = await _channel.invokeMethod<bool>('getIsMaximized');
      if (maximized != null) windowsWindowIsMaximized.value = maximized;
    } on PlatformException {
      // Window gone or channel not ready; the next transition push corrects.
    } on MissingPluginException {
      // Tests/embeddings without the native handler.
    }
  }

  /// Tells the native window the current AppBar height so it can center the
  /// traffic-light buttons in it. Deduped: a no-op unless the height actually
  /// changed, so it's safe to call from a build method on every rebuild.
  static void reportTitleBarHeight(double height) {
    if (!_supported) return;
    if (_lastReported != null && (_lastReported! - height).abs() < 0.5) return;
    _lastReported = height;
    _channel.invokeMethod('setTitleBarHeight', {'height': height});
  }

  /// Tells the native window the smallest size the user may resize it to —
  /// `minWindowSize` (docs/design/layouts.md) times the current UI scale, so
  /// the floor holds in the UiScale-divided space the layouts measure in.
  /// Deduped like [reportTitleBarHeight]; called from the same builder so it
  /// re-reports when the font scale changes. Both chromeless platforms
  /// enforce it (macOS contentMinSize; Windows WM_GETMINMAXINFO).
  static void reportMinimumSize(Size size) {
    if (!_chromeless) return;
    if (_lastMinimumSize == size) return;
    _lastMinimumSize = size;
    _channel.invokeMethod('setMinimumSize', {'width': size.width, 'height': size.height});
  }
}

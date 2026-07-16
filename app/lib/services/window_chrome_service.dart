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
// The same channel also carries header double-click reports, sent from
// halo_widgets' platform_chrome.dart (macOSHeaderDoubleClickArea) since
// that's where the AppBar helpers live, and full-screen transitions pushed
// from the native side (received in [WindowChromeService.init]).

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:halo_widgets/halo_widgets.dart' show macOSWindowIsFullScreen;

class WindowChromeService {
  static const _channel = MethodChannel('ham2k/window_chrome');

  static bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  static double? _lastReported;
  static Size? _lastMinimumSize;

  /// Registers the receiving end of the channel. Call once at startup.
  /// Currently one native push: full-screen transitions, which feed
  /// halo_widgets' [macOSWindowIsFullScreen] so the header can drop the
  /// traffic-light clearance while the buttons live in the system's
  /// auto-hiding titlebar overlay.
  static void init() {
    if (!_supported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'fullScreenChanged') {
        macOSWindowIsFullScreen.value = call.arguments as bool? ?? false;
      }
      return null;
    });
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
  /// re-reports when the font scale changes.
  static void reportMinimumSize(Size size) {
    if (!_supported) return;
    if (_lastMinimumSize == size) return;
    _lastMinimumSize = size;
    _channel.invokeMethod('setMinimumSize', {'width': size.width, 'height': size.height});
  }
}

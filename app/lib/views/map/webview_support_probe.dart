// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Shared by every pane that picks between a webview-backed map/HTML backend
// and an OSM/no-webview fallback per platform (map_panel.dart's Map tab,
// activities_results_map.dart's results map) — one probe, so a fix to its
// race/caching behavior can't land in one pane and silently miss the other.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../services/windows_webview.dart';

/// Whether the desktop webview backend can run here — false on a Windows
/// machine where no WebView2 environment can be created, and where routing
/// to the webview would leave the map permanently blank instead of falling
/// back to OSM. macOS starts true (WKWebView is part of the OS); Windows
/// starts from the cached answer, pessimistically false the first time.
/// That first answer costs a cold browser-process spawn, not a registry
/// lookup, so the first map open of a session visibly shows OSM and then
/// swaps to the webview map — every later one goes straight to the cached
/// answer.
///
/// Call [initWebviewSupportProbe] from `initState` and
/// [maybeProbeWebviewSupport] from `didChangeDependencies`.
mixin WebviewSupportProbe<T extends StatefulWidget> on State<T> {
  bool _webviewSupported = false;

  /// Set once [maybeProbeWebviewSupport] has actually asked — NOT on a
  /// platform skip, so a pane mounted off macOS/Windows keeps re-checking on
  /// every dependency change, which costs nothing (the branch returns
  /// immediately). Guards against stacking a second `.then` on
  /// [WindowsWebView.isAvailable]'s memoized future when a pane flips
  /// visible more than once; it does not guard against a second
  /// browser-process spawn, which that future already rules out.
  bool _probed = false;

  bool get webviewSupported => _webviewSupported;

  void initWebviewSupportProbe() {
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.macOS && defaultTargetPlatform != TargetPlatform.windows)) {
      return;
    }
    _webviewSupported = WindowsWebView.resolved ?? defaultTargetPlatform != TargetPlatform.windows;
  }

  /// Kicks off the WebView2 availability probe the first time this pane is
  /// actually on screen, not merely mounted — a dock group's `IndexedStack`
  /// builds every pane in it up front, and probing from `initState` would
  /// spawn the WebView2 browser process for a pane nobody has looked at yet.
  /// Outside a dock, `DockPaneVisibility.of` answers true immediately, so
  /// this fires on the same frame `initState` used to.
  void maybeProbeWebviewSupport() {
    if (_probed) return;
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.macOS && defaultTargetPlatform != TargetPlatform.windows)) {
      return;
    }
    if (!DockPaneVisibility.of(context)) return;
    _probed = true;
    WindowsWebView.isAvailable().then((ok) {
      if (mounted && ok != _webviewSupported) setState(() => _webviewSupported = ok);
    });
  }
}

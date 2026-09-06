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
/// answer, but only once this pane is actually visible (see
/// [maybeProbeWebviewSupport]).
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

  /// Whether this pane has been on screen at least once — the gate a backend
  /// with a real webview in it waits for on EVERY platform, where
  /// [webviewSupported] only ever answers for macOS/Windows.
  ///
  /// A dock group's `IndexedStack` mounts and lays out every pane in it, so a
  /// map built from a bare `initState` is a whole webview — the GL script off
  /// a CDN, a style, and a screen's worth of tiles — fetched for a pane
  /// nobody has opened.
  ///
  /// Latched, not live: once the operator has looked at the map it stays
  /// built, so switching between panes in a group doesn't tear the map down
  /// and re-fetch all of that on the way back.
  bool get paneEverVisible => _paneEverVisible;
  bool _paneEverVisible = false;

  /// Kept only as a call site for symmetry with [maybeProbeWebviewSupport];
  /// deliberately does nothing. Reading the cached availability here used to
  /// set [webviewSupported] unconditionally — which meant a pane mounted
  /// HIDDEN inside a dock group's `IndexedStack` (every pane in a group
  /// builds up front, see `dock_layout.dart`) built its real `InAppWebView`
  /// the moment `WindowsWebView.resolved` was already cached `true`, racing
  /// every other webview-backed pane in the same group doing the same on the
  /// same frame — the concurrent-GPU-surface-initialization crash class
  /// Intel's Windows driver is known to hit (flutter/flutter#187747; see
  /// HALO-290/HALO-NEXT-3). The read now happens in
  /// [maybeProbeWebviewSupport], gated on [DockPaneVisibility], which has
  /// `context` and can actually ask.
  void initWebviewSupportProbe() {}

  /// Kicks off the WebView2 availability check the first time this pane is
  /// actually on screen, not merely mounted — a dock group's `IndexedStack`
  /// builds every pane in it up front, and answering (or probing) support
  /// from `initState` would build a real webview, or spawn the WebView2
  /// browser process, for a pane nobody has looked at yet. Outside a dock,
  /// `DockPaneVisibility.of` answers true immediately, so this still fires
  /// on the same frame `initState` used to.
  void maybeProbeWebviewSupport() {
    // Before the platform gate, and unconditionally: this is what registers
    // the dependency on `DockPaneVisibility`, which is what calls
    // didChangeDependencies again when the pane is finally opened. Read only
    // inside the gate below, it would never be read at all on iOS/Android —
    // and [paneEverVisible] would stay false for the life of the pane.
    if (!_paneEverVisible && DockPaneVisibility.of(context)) _paneEverVisible = true;
    if (_probed) return;
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.macOS && defaultTargetPlatform != TargetPlatform.windows)) {
      return;
    }
    if (!DockPaneVisibility.of(context)) return;
    _probed = true;
    final resolved = WindowsWebView.resolved;
    if (resolved != null || defaultTargetPlatform != TargetPlatform.windows) {
      final supported = resolved ?? true;
      if (supported != _webviewSupported) setState(() => _webviewSupported = supported);
      return;
    }
    WindowsWebView.isAvailable().then((ok) {
      if (mounted && ok != _webviewSupported) setState(() => _webviewSupported = ok);
    });
  }
}

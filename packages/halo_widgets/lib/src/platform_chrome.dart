// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// On macOS, MainFlutterWindow.swift makes the native title bar transparent
// and folds it into the content view (`titlebarAppearsTransparent` +
// `fullSizeContentView`), so there's no separate gray bar above the app's
// own AppBar — the AppBar's color reaches the very top of the window. The
// traffic-light buttons keep floating over that top-left corner though, so
// any AppBar leading content needs left clearance to avoid sitting under
// them.

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui_scale.dart';

bool get isMacOSChromelessWindow =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

/// Horizontal space to reserve for the traffic-light buttons when
/// [isMacOSChromelessWindow]. A PHYSICAL measurement: the native buttons are
/// fixed-size system controls that don't scale with the UI, so this clearance
/// is divided by [UiScale.of] wherever it's applied (the AppBar leading lives
/// inside the scaled subtree) to keep it a constant on-screen size.
const double macOSTrafficLightInset = 70;

/// Extra breathing room between the traffic lights and whatever AppBar
/// leading content follows them (logo, back button), so it doesn't start
/// immediately at their edge. Physical, like [macOSTrafficLightInset].
const double macOSTrafficLightGap = 16;

/// True while the macOS window is in native full screen — pushed from
/// MainFlutterWindow.swift over the window-chrome channel (the app's
/// WindowChromeService registers the receiving handler). The app root feeds
/// it into a [MacOSFullScreenScope]; header code reads the scope, not this
/// notifier, so the views that reserved traffic-light clearance rebuild on
/// the transition.
final ValueNotifier<bool> macOSWindowIsFullScreen = ValueNotifier<bool>(false);

/// Scope distributing the full-screen state to header builders. An
/// InheritedWidget (rather than reading [macOSWindowIsFullScreen] directly)
/// because the notifier alone can't reach them: MaterialApp.builder wraps a
/// prebuilt Navigator `child`, so a root rebuild short-circuits at the
/// identical child widget — only an inherited dependency makes the AppBars
/// below re-run their build when the value flips.
class MacOSFullScreenScope extends InheritedWidget {
  final bool isFullScreen;

  const MacOSFullScreenScope({super.key, required this.isFullScreen, required super.child});

  /// False when no scope is above (tests, non-app embeddings).
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MacOSFullScreenScope>()?.isFullScreen ?? false;

  @override
  bool updateShouldNotify(MacOSFullScreenScope oldWidget) => oldWidget.isFullScreen != isFullScreen;
}

/// The traffic-light clearance in the AppBar's (scaled) coordinate space, so
/// it renders at a constant physical size that always clears the native
/// buttons regardless of UI scale. Use this instead of the raw constants for
/// any custom leading layout (see [macOSAwareLeadingWidth]). Zero in native
/// full screen, where the buttons leave the header for the system's
/// auto-hiding titlebar overlay and leading content aligns with the edge.
double macOSTrafficLightClearance(BuildContext context) => MacOSFullScreenScope.of(context)
    ? 0
    : (macOSTrafficLightInset + macOSTrafficLightGap) / UiScale.of(context);

/// True on desktop/windowed platforms (macOS, Windows, Linux) and web, where
/// an AppBar title reads like a windowed app's title bar and should sit
/// left-aligned next to any leading content; false on mobile (iOS, Android),
/// where a fullscreen app's title centers per each platform's own
/// convention.
bool get isWindowedPlatform =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;

/// True on iOS/Android — where on-screen keyboards make "/" awkward to type
/// (issue #7's "." → "/" autocorrect for logging inputs) and other
/// mobile-only input quirks apply.
bool get isMobilePlatform =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

/// The app's full self-identification name (.agents/AGENTS.md: "On desktop
/// versions it identifies itself as 'Ham2K Logger' while on mobile versions
/// it uses 'Ham2K Portable Logger'") — for places the app names itself to an
/// external service or file (e.g. a spot's `source` field, an ADIF
/// `PROGRAMID` header). Distinct from the OS-level window/task-switcher
/// title (`main.dart`'s "HaLo") or the in-app home-screen heading
/// (`home.title`/`home.titleDesktop`), which follow their own conventions.
String get ham2kAppName =>
    isWindowedPlatform ? 'Ham2K Logger' : 'Ham2K Portable Logger';

/// `AppBar.leadingWidth` for a plain back button that reserves clearance for
/// the traffic-light buttons — pair with [macOSAwareBackButton]. Every
/// pushed view's AppBar needs this (or the equivalent custom-leading math
/// home_view.dart does for its logo), otherwise the title/back arrow render
/// underneath the floating traffic lights. The back button's own width scales
/// with the UI; the traffic-light clearance stays fixed physical.
double? macOSAwareLeadingWidth(BuildContext context) =>
    isMacOSChromelessWindow ? 48 + macOSTrafficLightClearance(context) : null;

/// A `BackButton` with left padding reserved for the traffic-light buttons
/// when [isMacOSChromelessWindow]. Pair with [macOSAwareLeadingWidth] as the
/// AppBar's `leadingWidth`.
Widget macOSAwareBackButton(BuildContext context, {VoidCallback? onPressed}) => MouseRegion(
      cursor: SystemMouseCursors.click,
      child: isMacOSChromelessWindow
          ? Padding(
              padding: EdgeInsets.only(left: macOSTrafficLightClearance(context)),
              child: BackButton(onPressed: onPressed),
            )
          : BackButton(onPressed: onPressed),
    );

// The same channel MainFlutterWindow.swift listens on for the app's
// WindowChromeService height reports; this end only ever sends.
const _windowChromeChannel = MethodChannel('ham2k/window_chrome');

/// `AppBar.flexibleSpace` for headers that sit at the top of the window:
/// double-clicking the header's empty background performs the native
/// title-bar double-click action (zoom, or minimize/nothing per the user's
/// System Settings choice — resolved in MainFlutterWindow.swift), since the
/// chromeless window has no real title bar to provide it. flexibleSpace
/// renders BEHIND the toolbar row in the AppBar's stack, so buttons and
/// title keep winning hit-testing and only clicks on empty background land
/// here. Null when not [isMacOSChromelessWindow].
Widget? macOSHeaderDoubleClickArea() => isMacOSChromelessWindow
    ? GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () => _windowChromeChannel.invokeMethod('performHeaderDoubleClickAction'),
        child: const SizedBox.expand(),
      )
    : null;

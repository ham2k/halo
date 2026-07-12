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

bool get isMacOSChromelessWindow =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

/// Horizontal space to reserve for the traffic-light buttons when
/// [isMacOSChromelessWindow].
const double macOSTrafficLightInset = 70;

/// Extra breathing room between the traffic lights and whatever AppBar
/// leading content follows them (logo, back button), so it doesn't start
/// immediately at their edge.
const double macOSTrafficLightGap = 16;

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

/// `AppBar.leadingWidth` for a plain back button that reserves clearance for
/// the traffic-light buttons — pair with [macOSAwareBackButton]. Every
/// pushed view's AppBar needs this (or the equivalent custom-leading math
/// home_view.dart does for its logo), otherwise the title/back arrow render
/// underneath the floating traffic lights.
double? get macOSAwareLeadingWidth =>
    isMacOSChromelessWindow ? 48 + macOSTrafficLightInset + macOSTrafficLightGap : null;

/// A `BackButton` with left padding reserved for the traffic-light buttons
/// when [isMacOSChromelessWindow]. Pair with [macOSAwareLeadingWidth] as the
/// AppBar's `leadingWidth`.
Widget macOSAwareBackButton({VoidCallback? onPressed}) => MouseRegion(
      cursor: SystemMouseCursors.click,
      child: isMacOSChromelessWindow
          ? Padding(
              padding: const EdgeInsets.only(left: macOSTrafficLightInset + macOSTrafficLightGap),
              child: BackButton(onPressed: onPressed),
            )
          : BackButton(onPressed: onPressed),
    );

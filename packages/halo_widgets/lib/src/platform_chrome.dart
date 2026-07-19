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

import 'layout.dart';
import 'mdi_icons.dart';
import 'ui_scale.dart';

bool get isMacOSChromelessWindow =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

/// On Windows the runner strips the native title bar and frame the same way
/// (custom-frame WM_NCCALCSIZE in win32_window.cpp), but unlike macOS there
/// are no native buttons left at all — the caption controls are Flutter-drawn
/// ([WindowsCaptionButtons], overlaid at the app root) and sit at the top
/// RIGHT, so headers reserve trailing clearance ([windowsCaptionClearance])
/// instead of leading.
bool get isWindowsChromelessWindow =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

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

/// The **product name**, tailored per platform so each build reads naturally.
/// Shown wherever the app names itself in the UI (splash, home header + right
/// pane, About, onboarding). It stands beneath a HAM2K graphic — which already
/// carries the brand — so it omits "Ham2K":
///   macOS → `Mac Logger`, Windows → `Windows Logger`, Linux → `Linux Logger`,
///   iOS/Android → `Portable Logger`, Web → `Browser Logger`.
/// See `Ham2kBrandMark` in the app's `views/ham2k_logo.dart`.
String get ham2kProductName {
  if (kIsWeb) return 'Browser Logger';
  return switch (defaultTargetPlatform) {
    TargetPlatform.macOS => 'Mac Logger',
    TargetPlatform.windows => 'Windows Logger',
    TargetPlatform.linux => 'Linux Logger',
    TargetPlatform.iOS || TargetPlatform.android => 'Portable Logger',
    _ => 'Logger',
  };
}

/// The **full self-identification name** — [ham2kProductName] with the "Ham2K"
/// brand prefixed, e.g. `Ham2K Mac Logger`. For **human-facing** places the name
/// stands on its own without a HAM2K graphic — e.g. the About screen's copyable
/// version text. Distinct from the OS-level window/task-switcher title
/// (`main.dart`'s "HaLo"). For machine-facing strings use [ham2kMachineName].
String get ham2kAppName => 'Ham2K $ham2kProductName';

/// The **machine-facing** name — a fixed, platform- and edition-agnostic
/// `Ham2K Logger`, for strings other software reads: an ADIF `PROGRAMID`, HTTP
/// headers (the `User-Agent`), a spot's `source`. Deliberately NOT
/// [ham2kProductName]-tailored, so interop tools always see one stable program
/// name.
const String ham2kMachineName = 'Ham2K Logger';

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

/// A rectangle in the AppBar's own background color, floating over the header's
/// top-left corner beneath the native traffic lights. Overlaid at the app root
/// (main.dart) — the macOS counterpart to [WindowsCaptionButtons] on the
/// opposite edge. The reserved clearance keeps header content out of this
/// corner at rest, but content that *animates* through it (a title cross-fading
/// on a route change, an action button sliding in) would otherwise flash out
/// from the gaps around the buttons; this mask hides it. Its right edge is a
/// transparent gradient so masked content dissolves across it instead of
/// hard-clipping at a vertical line — the mirror of the secondary-control caret
/// mask. `IgnorePointer` so the header's drag/double-click gesture area
/// underneath still gets pointer events in the gaps between the native buttons.
/// Collapses to nothing off macOS and in native full screen, where the buttons
/// (and the clearance) are gone.
class MacOSTrafficLightMask extends StatelessWidget {
  const MacOSTrafficLightMask({super.key});

  @override
  Widget build(BuildContext context) {
    final clearance = isMacOSChromelessWindow ? macOSTrafficLightClearance(context) : 0.0;
    if (clearance == 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final color = theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    // Solid across the buttons' fixed-physical zone, fading to transparent over
    // the trailing gap so nothing hard-clips at the mask's edge.
    final opaqueStop = macOSTrafficLightInset / (macOSTrafficLightInset + macOSTrafficLightGap);

    return IgnorePointer(
      child: SizedBox(
        width: clearance,
        height: theme.appBarTheme.toolbarHeight ?? kToolbarHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [opaqueStop, 1.0],
              colors: [color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}

// The same channel MainFlutterWindow.swift listens on for the app's
// WindowChromeService height reports; this end only ever sends.
const _windowChromeChannel = MethodChannel('ham2k/window_chrome');

/// `AppBar.flexibleSpace` for headers that sit at the top of the window:
/// the chromeless window has no real title bar, so the header's empty
/// background stands in for it. Double-clicking performs the native
/// title-bar double-click action (macOS: zoom, or minimize/nothing per the
/// user's System Settings choice, resolved in MainFlutterWindow.swift;
/// Windows: maximize/restore). On Windows a drag also moves the window —
/// without a caption there is no other way to move it (macOS keeps the
/// system's invisible drag strip at the very top, so it needs no Flutter
/// drag). flexibleSpace renders BEHIND the toolbar row in the AppBar's
/// stack, so buttons and title keep winning hit-testing and only gestures
/// on empty background land here. Null on all other platforms.
Widget? windowHeaderGestureArea() {
  if (!isMacOSChromelessWindow && !isWindowsChromelessWindow) return null;
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onDoubleTap: () => _windowChromeChannel.invokeMethod('performHeaderDoubleClickAction'),
    // The native side takes over the pointer (WM_NCLBUTTONDOWN enters the
    // system move loop), so onPanStart is the whole gesture.
    onPanStart: isWindowsChromelessWindow
        ? (_) => _windowChromeChannel.invokeMethod('startWindowDrag')
        : null,
    // Right-clicking a real Windows title bar opens the window system menu
    // (Restore/Move/Size/…); the native side shows it at the cursor.
    onSecondaryTap: isWindowsChromelessWindow
        ? () => _windowChromeChannel.invokeMethod('showSystemMenu')
        : null,
    child: const SizedBox.expand(),
  );
}

/// True while the Windows window is maximized — pushed from the native
/// runner (flutter_window.cpp) over the window-chrome channel and received
/// by the app's WindowChromeService. Drives [WindowsCaptionButtons]'
/// maximize/restore glyph; the buttons listen directly, so no scope is
/// needed (nothing else lays out differently when maximized).
final ValueNotifier<bool> windowsWindowIsMaximized = ValueNotifier<bool>(false);

/// Width of one Flutter-drawn caption button ([WindowsCaptionButtons]) —
/// the native Windows caption metric, in logical pixels (scales with the
/// UI like the rest of the header, unlike the fixed-physical macOS traffic
/// lights, which are native controls we can't scale).
const double windowsCaptionButtonWidth = 46;

/// Trailing space a window-top AppBar's `actions` must reserve so they
/// don't sit under the caption-button overlay when
/// [isWindowsChromelessWindow]; zero elsewhere, so it can be applied
/// unconditionally as a trailing SizedBox.
double windowsCaptionClearance(BuildContext context) =>
    isWindowsChromelessWindow ? 3 * windowsCaptionButtonWidth + 8 : 0;

/// The trailing spacer every window-top AppBar puts at the END of its
/// `actions` (adding one if it has none): it keeps action buttons — and,
/// by constraining the title's width, long titles — from rendering under
/// the caption-button overlay. Collapses to zero width off Windows. The
/// counterpart of the macOS side's leading clearance
/// ([macOSAwareLeadingWidth]), just on the opposite edge.
Widget windowsCaptionSpacer(BuildContext context) => SizedBox(width: windowsCaptionClearance(context));

/// The minimum size a resizable desktop window may be shrunk to, in PHYSICAL
/// pixels (already multiplied by [uiScale]) — pass to `WindowChromeService.
/// reportMinimumSize`. The width is the S-size layout floor ([minWindowSize],
/// the smallest width that still lays out as S rather than XS) plus room for
/// the native window controls that float over the header, so the S content and
/// the controls never overlap:
///  - chromeless macOS: the traffic lights, a fixed PHYSICAL size
///    ([macOSTrafficLightInset] + [macOSTrafficLightGap]), so unscaled;
///  - chromeless Windows: the Flutter-drawn caption buttons
///    ([windowsCaptionClearance]'s width), logical, so scaled by [uiScale];
///  - platforms with a native title bar (Linux): none — the controls live in
///    their own bar, not over the content.
/// Height is [minWindowSize] scaled.
Size desktopMinimumWindowSize(double uiScale) {
  final double controls = isMacOSChromelessWindow
      ? macOSTrafficLightInset + macOSTrafficLightGap
      : isWindowsChromelessWindow
          ? (3 * windowsCaptionButtonWidth + 8) * uiScale
          : 0;
  return Size(minWindowSize.width * uiScale + controls, minWindowSize.height * uiScale);
}

/// The minimize / maximize-restore / close buttons for the chromeless
/// Windows window, overlaid at the app root's top-right corner (main.dart)
/// so they float over every route's header — the same "window chrome above
/// app content" role the native traffic lights play on macOS. Actions go
/// over the window-chrome channel to the native runner.
class WindowsCaptionButtons extends StatelessWidget {
  const WindowsCaptionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = theme.appBarTheme.toolbarHeight ?? kToolbarHeight;
    // Header foreground color, so the glyphs read on the AppBar background
    // they float over.
    final glyphColor = theme.appBarTheme.foregroundColor ??
        (theme.brightness == Brightness.dark ? Colors.white : Colors.black);

    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CaptionButton(
            semanticLabel: 'Minimize',
            icon: MdiIcons.windowMinimize,
            glyphColor: glyphColor,
            onPressed: () => _windowChromeChannel.invokeMethod('minimizeWindow'),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: windowsWindowIsMaximized,
            builder: (context, isMaximized, _) => _CaptionButton(
              semanticLabel: isMaximized ? 'Restore' : 'Maximize',
              icon: isMaximized ? MdiIcons.windowRestore : MdiIcons.windowMaximize,
              glyphColor: glyphColor,
              onPressed: () => _windowChromeChannel.invokeMethod('toggleMaximizeWindow'),
            ),
          ),
          _CaptionButton(
            semanticLabel: 'Close',
            icon: MdiIcons.windowClose,
            glyphColor: glyphColor,
            // Windows convention: close lights up red on hover.
            hoverColor: const Color(0xFFC42B1C),
            hoverGlyphColor: Colors.white,
            onPressed: () => _windowChromeChannel.invokeMethod('closeWindow'),
          ),
        ],
      ),
    );
  }
}

class _CaptionButton extends StatefulWidget {
  final String semanticLabel;
  final IconData icon;
  final Color glyphColor;
  final Color? hoverColor;
  final Color? hoverGlyphColor;
  final VoidCallback onPressed;

  const _CaptionButton({
    required this.semanticLabel,
    required this.icon,
    required this.glyphColor,
    required this.onPressed,
    this.hoverColor,
    this.hoverGlyphColor,
  });

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hoverColor = widget.hoverColor ?? widget.glyphColor.withValues(alpha: 0.12);
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Container(
            width: windowsCaptionButtonWidth,
            height: double.infinity,
            color: _hovered ? hoverColor : Colors.transparent,
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: 16,
              color: _hovered ? (widget.hoverGlyphColor ?? widget.glyphColor) : widget.glyphColor,
            ),
          ),
        ),
      ),
    );
  }
}

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
import 'mdi_icons.g.dart';
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

/// On Linux the runner (linux/runner/my_application.cc) installs an
/// effectively invisible custom titlebar via `gtk_window_set_titlebar`
/// instead of the native header bar — that keeps GTK on its normal
/// client-side-decoration path (so the window manager still supplies
/// drag/resize/shadow handling) while leaving nothing visible for it to
/// draw. Like Windows, there are no native buttons left, so the caption
/// controls are the same Flutter-drawn [WindowsCaptionButtons] at the top
/// right — every place gated on [isWindowsChromelessWindow] below for that
/// shared behavior also checks this.
bool get isLinuxChromelessWindow =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

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

/// True on desktop/windowed platforms (macOS, Windows, Linux) and web,
/// false on mobile (iOS, Android). Drives the app's own OS-level naming and
/// a few mobile-only layout adjustments — NOT AppBar title alignment, which
/// is left-aligned everywhere (theme.dart's `centerTitle: false`).
bool get isWindowedPlatform =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;

/// True on iOS/Android — where on-screen keyboards make "/" awkward to type
/// (the "." → "/" autocorrect for logging inputs) and other mobile-only
/// input quirks apply.
bool get isMobilePlatform =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

/// Whether a physical keyboard is attached, on the platforms where that is a
/// question — fed by the app's HardwareKeyboardService over the
/// `ham2k/hardware_keyboard` channel (iOS 14+ via GCKeyboard, Android via
/// InputDevice), the same app-feeds-the-notifier arrangement as
/// [macOSWindowIsFullScreen]. Defaults to false, which on mobile means the
/// no-uninvited-virtual-keyboard behavior (docs/design/logging-fields.md's
/// carve-out) — the safe reading while the channel's first answer is still
/// in flight. Only meaningful where [isMobilePlatform] is true; every
/// consumer must gate on that first, since nothing feeds this on desktop or
/// web.
final ValueNotifier<bool> hardwareKeyboardAttached = ValueNotifier<bool>(false);

/// True on iOS specifically — used where iOS's soft keyboards behave
/// differently enough from Android's to warrant a per-platform choice, e.g.
/// the NumbersAndPunctuation keyboard (numbers-first, but with symbols and a
/// space bar) that suits the numeric logging fields, where Android's
/// signed-number type would drop to a letterless numeric pad instead. See
/// `LoggingControls`'s `_numbersAndPunctuationOnIOS`.
bool get isIOSPlatform => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// True on Windows specifically — used by `flags.dart`'s image-based flag
/// fallback (Flutter's Windows-desktop Skia text layout can't compose a
/// multi-codepoint flag emoji into a single glyph).
bool get isWindowsPlatform => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

/// Lowercase platform token for data-driven platform filtering — settings'
/// `environment` attribute (docs/extensions/settings.md) and server notices
/// (app/lib/services/notices.dart's `_knownPlatforms`) both filter on this
/// same vocabulary: `ios`, `android`, `macos`, `windows`, `linux`, or `web`.
/// `kIsWeb` wins over `defaultTargetPlatform`, which reports the HOST OS on
/// web (see oauth_browser_login.dart's platform-detection note) — a phone's
/// mobile browser must read as `web`, not `ios`/`android`.
String get platformToken {
  if (kIsWeb) return 'web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.macOS:
      return 'macos';
    case TargetPlatform.windows:
      return 'windows';
    case TargetPlatform.linux:
      return 'linux';
    default:
      return defaultTargetPlatform.name.toLowerCase();
  }
}

/// True in a browser. A named getter rather than bare `kIsWeb` at each call
/// site, because [isWindowedPlatform] deliberately lumps web in with desktop
/// — web is desktop-*shaped* but has no filesystem, so anything about files
/// has to ask this instead.
bool get isWebPlatform => kIsWeb;

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
///
/// [close] swaps the arrow for a cross, for a view that COVERS what it came
/// from rather than sitting deeper than it. An arrow promises a step back
/// along a trail; a view that arrived over the top of everything has no trail
/// to step back along, and closing it is the only thing the control does.
Widget macOSAwareBackButton(BuildContext context, {VoidCallback? onPressed, bool close = false}) {
  final button = close
      ? IconButton(
          icon: const Icon(MdiIcons.close),
          onPressed: onPressed ?? () => Navigator.maybePop(context),
        )
      : BackButton(onPressed: onPressed);
  return MouseRegion(
    cursor: SystemMouseCursors.click,
    child: isMacOSChromelessWindow
        ? Padding(padding: EdgeInsets.only(left: macOSTrafficLightClearance(context)), child: button)
        : button,
  );
}

/// True while a dimming modal — a `showDialog` dialog or a `showModalPane`
/// pane — sits on top of the root navigator. The window-chrome mask
/// ([MacOSTrafficLightMask]) hides itself while this is set: a modal barrier
/// dims the whole window, and the mask's bright same-as-header rectangle
/// floating in the top-left corner over that dimmed backdrop reads as a stray
/// box. The release/onboarding overlays already sit ABOVE the mask, so they
/// hide it by z-order; dialogs are pushed onto the navigator BELOW it, so they
/// need this signal instead. Driven by [ModalBarrierRouteObserver], installed
/// in `MaterialApp.navigatorObservers` at the app root.
final ValueNotifier<bool> modalBarrierIsVisible = ValueNotifier<bool>(false);

/// Keeps [modalBarrierIsVisible] in sync with the navigator's route stack.
/// Counts live routes that actually dim the window (a non-transparent
/// [ModalRoute.barrierColor]) so it stays correct across stacked dialogs;
/// opaque page routes (no barrier) and transparent-barrier popups (dropdown /
/// menu overlays) are deliberately ignored — the mask only hides for the
/// dimming dialogs and panes the design cares about.
class ModalBarrierRouteObserver extends NavigatorObserver {
  int _count = 0;

  bool _dims(Route<dynamic>? route) {
    final color = route is ModalRoute ? route.barrierColor : null;
    return color != null && color.a > 0;
  }

  void _bump(int delta) {
    _count = (_count + delta).clamp(0, 1 << 30);
    modalBarrierIsVisible.value = _count > 0;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_dims(route)) _bump(1);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_dims(route)) _bump(-1);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_dims(route)) _bump(-1);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (_dims(oldRoute)) _bump(-1);
    if (_dims(newRoute)) _bump(1);
  }
}

/// Depth of currently-visible blurred-background modals (the app's
/// `wideModalChrome`, used by the release overlay and the About photo modal).
/// While it is > 0, [MacOSTrafficLightMask] hides its AppBar-colored gradient
/// rectangle — otherwise that opaque corner reads as a stray header strip
/// floating over the modal's blur. Callers bracket a modal with
/// [enterBlurredModal] / [exitBlurredModal].
///
/// The depth is a plain int mutated synchronously, so it never lingers past a
/// caller's disposal (no cross-test leak); a separate revision notifier drives
/// the mask rebuild and is bumped a frame later, since touching a notifier
/// during another subtree's mount/unmount would markNeedsBuild the app-root
/// mask mid-build.
int _blurredModalDepth = 0;
final ValueNotifier<int> _blurredModalRevision = ValueNotifier<int>(0);

/// Marks a blurred-background modal as visible; pair with [exitBlurredModal].
void enterBlurredModal() => _adjustBlurredModal(1);

/// Marks a blurred-background modal as gone; pair with [enterBlurredModal].
void exitBlurredModal() => _adjustBlurredModal(-1);

void _adjustBlurredModal(int delta) {
  _blurredModalDepth += delta;
  WidgetsBinding.instance.addPostFrameCallback((_) => _blurredModalRevision.value++);
}

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

    final mask = IgnorePointer(
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

    // Hide the mask while a dimming dialog/pane covers the window
    // (modalBarrierIsVisible, from ModalBarrierRouteObserver) OR a
    // blurred-background modal is up (_blurredModalDepth — e.g. the About photo
    // modal, whose transparent barrier that observer ignores). Either way the
    // bright same-as-header box would read as a stray rectangle over the
    // dim/blur. Matches how the release/onboarding overlays (which sit above
    // the mask) already hide it; nothing animates through this corner behind a
    // static modal, so dropping the mask there loses nothing.
    return ListenableBuilder(
      listenable: Listenable.merge([modalBarrierIsVisible, _blurredModalRevision]),
      builder: (context, child) =>
          (modalBarrierIsVisible.value || _blurredModalDepth > 0) ? const SizedBox.shrink() : child!,
      child: mask,
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
/// Windows/Linux: maximize/restore). On Windows and Linux a drag also moves
/// the window — without a caption there is no other way to move it (macOS
/// keeps the system's invisible drag strip at the very top, so it needs no
/// Flutter drag). flexibleSpace renders BEHIND the toolbar row in the
/// AppBar's stack, so buttons and title keep winning hit-testing and only
/// gestures on empty background land here. Null on all other platforms.
Widget? windowHeaderGestureArea() {
  if (!isMacOSChromelessWindow && !isWindowsChromelessWindow && !isLinuxChromelessWindow) return null;
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onDoubleTap: () => _windowChromeChannel.invokeMethod('performHeaderDoubleClickAction'),
    // The native side takes over the pointer (WM_NCLBUTTONDOWN / gtk_window_
    // begin_move_drag enters the system move loop), so onPanStart is the
    // whole gesture.
    onPanStart: (isWindowsChromelessWindow || isLinuxChromelessWindow)
        ? (_) => _windowChromeChannel.invokeMethod('startWindowDrag')
        : null,
    // Right-clicking a real Windows title bar opens the window system menu
    // (Restore/Move/Size/…); the native side shows it at the cursor. No
    // Linux equivalent wired up yet.
    onSecondaryTap: isWindowsChromelessWindow
        ? () => _windowChromeChannel.invokeMethod('showSystemMenu')
        : null,
    child: const SizedBox.expand(),
  );
}

/// True while the Windows or Linux window is maximized — pushed from the
/// native runner (flutter_window.cpp / my_application.cc) over the
/// window-chrome channel and received by the app's WindowChromeService.
/// Drives [WindowsCaptionButtons]' maximize/restore glyph; the buttons
/// listen directly, so no scope is needed (nothing else lays out
/// differently when maximized). Name kept from when this was Windows-only;
/// both chromeless platforms share the one notifier and channel method.
final ValueNotifier<bool> windowsWindowIsMaximized = ValueNotifier<bool>(false);

/// Width of one Flutter-drawn caption button ([WindowsCaptionButtons]) —
/// the native Windows caption metric, in logical pixels (scales with the
/// UI like the rest of the header, unlike the fixed-physical macOS traffic
/// lights, which are native controls we can't scale).
const double windowsCaptionButtonWidth = 46;

/// Trailing space a window-top AppBar's `actions` must reserve so they
/// don't sit under the caption-button overlay when
/// [isWindowsChromelessWindow] or [isLinuxChromelessWindow]; zero
/// elsewhere, so it can be applied unconditionally as a trailing SizedBox.
double windowsCaptionClearance(BuildContext context) =>
    (isWindowsChromelessWindow || isLinuxChromelessWindow) ? 3 * windowsCaptionButtonWidth + 8 : 0;

/// The trailing spacer every window-top AppBar puts at the END of its
/// `actions` (adding one if it has none): it keeps action buttons — and,
/// by constraining the title's width, long titles — from rendering under
/// the caption-button overlay. Collapses to zero width off Windows. The
/// counterpart of the macOS side's leading clearance
/// ([macOSAwareLeadingWidth]), just on the opposite edge.
Widget windowsCaptionSpacer(BuildContext context) => SizedBox(width: windowsCaptionClearance(context));

/// Shrinks an arbitrary (non-Text) header widget — e.g. a Row mixing an
/// icon/badge with text — to fit whatever width it's given, with no floor.
/// Every plain single-line title uses [shrinkToFitText] instead, which adds
/// a minimum-legible-size floor; reach for this only when the content isn't
/// a single [Text].
///
/// `FittedBox(fit: BoxFit.scaleDown)`: its child gets loose/unbounded
/// constraints, so it lays out at its natural size, then the whole thing
/// scales down uniformly — but never up — only if that natural size is
/// wider than the space this is given.
Widget shrinkToFit(Widget child, {AlignmentGeometry alignment = Alignment.centerLeft}) =>
    FittedBox(fit: BoxFit.scaleDown, alignment: alignment, child: child);

/// Wraps an AppBar title/subtitle line so it reads the full text at a
/// smaller size instead of truncating outright — use in place of
/// `overflow: TextOverflow.ellipsis`. Font size shrinks to fit, but never
/// below [minScale] (default 75%) of its natural size — past that point the
/// line falls back to an ellipsis instead of shrinking into illegibility.
///
/// [condensed], for a secondary line (a subtitle under its own title — not
/// the title itself, which should stay at normal width), tries Roboto's
/// variable-font 'wdth' axis at its Condensed value (75, vs. 100 Normal) —
/// same font size, narrower glyphs — BEFORE shrinking the font size at all:
/// a condensed render stays fully legible, unlike a smaller one, so it's the
/// cheaper trade to make first. No-ops if condensing wouldn't
/// actually narrow the text (e.g. a font with no 'wdth' axis).
Widget shrinkToFitText(Text text, {double minScale = 0.75, bool condensed = false}) => LayoutBuilder(
  builder: (context, constraints) {
    final style = DefaultTextStyle.of(context).style.merge(text.style);
    final data = text.data ?? text.textSpan?.toPlainText() ?? '';
    final direction = text.textDirection ?? Directionality.of(context);

    // Measured through the ambient text scaler, because that is what the
    // Text below paints through: measuring unscaled would call a title that
    // only overflows under OS/accessibility scaling a fit, and it would then
    // neither shrink nor ellipsize. [minScale] stays relative to the SCALED
    // size — at a 2x system font a line gives back at most a quarter of it,
    // rather than undoing the reader's setting to buy room.
    // theme.dart's textWidth does the same job and is the house measurer, but
    // it fixes textDirection at LTR; this one honours the Text's own.
    // The Text's own scaler when it has one, so measurement and paint can
    // never disagree about which scaler applies.
    final textScaler = text.textScaler ?? MediaQuery.textScalerOf(context);
    double widthOf(TextStyle s) {
      final painter = TextPainter(
        text: TextSpan(text: data, style: s),
        textDirection: direction,
        textScaler: textScaler,
      );
      try {
        painter.layout();
        return painter.width;
      } finally {
        // Frees the native paragraph rather than leaving it to a GC finalizer:
        // an animating header rebuilds its titles every frame.
        painter.dispose();
      }
    }

    var effectiveStyle = style;
    var scale = 1.0;
    final baseFontSize = style.fontSize ?? 14;
    TextStyle styleAt(double s) => effectiveStyle.copyWith(fontSize: baseFontSize * s);
    if (constraints.maxWidth.isFinite) {
      var width = widthOf(effectiveStyle);
      if (condensed && width > constraints.maxWidth) {
        final condensedStyle = effectiveStyle.copyWith(fontVariations: const [FontVariation('wdth', 75)]);
        final condensedWidth = widthOf(condensedStyle);
        if (condensedWidth < width) {
          effectiveStyle = condensedStyle;
          width = condensedWidth;
        }
      }
      if (width > constraints.maxWidth) {
        scale = (constraints.maxWidth / width).clamp(minScale, 1.0);
        // That ratio is exact only for a LINEAR scaler, where
        // scale(F·s) == s·scale(F). Android 14+ curves system font scaling —
        // the amplification tapers as the size grows — and there the ratio
        // lands short: iterating it converges on the answer from ABOVE and
        // never reaches it, so the line would ellipsize while claiming to have
        // been fitted. Verify the chosen size, and only when it doesn't fit,
        // bisect down to one that does. The check costs one measurement in the
        // linear case, where the ratio is already exact.
        if (scale > minScale && widthOf(styleAt(scale)) > constraints.maxWidth) {
          var tooWide = scale;
          scale = minScale;
          for (var i = 0; i < 4; i++) {
            final mid = (scale + tooWide) / 2;
            if (widthOf(styleAt(mid)) <= constraints.maxWidth) {
              scale = mid;
            } else {
              tooWide = mid;
            }
          }
        }
      }
    }
    return Text(
      data,
      style: styleAt(scale),
      // Carried through, not dropped: measuring in one direction (or scaler)
      // and painting in another is the drift this whole function exists to
      // avoid.
      textDirection: text.textDirection,
      textScaler: text.textScaler,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  },
);

/// The minimum size a resizable desktop window may be shrunk to, in PHYSICAL
/// pixels (already multiplied by [uiScale]) — pass to `WindowChromeService.
/// reportMinimumSize`. The width is the S-size layout floor ([minWindowSize],
/// the smallest width that still lays out as S rather than XS) plus room for
/// the native window controls that float over the header, so the S content and
/// the controls never overlap:
///  - chromeless macOS: the traffic lights, a fixed PHYSICAL size
///    ([macOSTrafficLightInset] + [macOSTrafficLightGap]), so unscaled;
///  - chromeless Windows/Linux: the Flutter-drawn caption buttons
///    ([windowsCaptionClearance]'s width), logical, so scaled by [uiScale].
/// Height is [minWindowSize] scaled.
Size desktopMinimumWindowSize(double uiScale) {
  final double controls = isMacOSChromelessWindow
      ? macOSTrafficLightInset + macOSTrafficLightGap
      : (isWindowsChromelessWindow || isLinuxChromelessWindow)
          ? (3 * windowsCaptionButtonWidth + 8) * uiScale
          : 0;
  return Size(minWindowSize.width * uiScale + controls, minWindowSize.height * uiScale);
}

/// The minimize / maximize-restore / close buttons for the chromeless
/// Windows and Linux windows, overlaid at the app root's top-right corner
/// (main.dart) so they float over every route's header — the same "window
/// chrome above app content" role the native traffic lights play on macOS.
/// Actions go over the window-chrome channel to the native runner
/// (flutter_window.cpp / my_application.cc).
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

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A foldable's display, as iOS describes it and Flutter does not. The
// MediaQuery carries one inset per edge and no fold, so on the iPhone Duo's
// inner display a status bar that only fills the top-right corner still
// costs the whole width its height, the rounded corners reach into a header
// iOS reports no inset for, and a half-folded keyboard is reported as
// everything below the fold. iOS 27.1 reports each of those to native code
// (the `DisplayRegions` reporter in app/ios/Runner/SceneDelegate.swift); this
// carries them over and corrects the MediaQuery once, at the app root, so
// every reader below gets the corrected insets.
//
// Applied only on a display that reports a fold. What the same calls answer
// on a phone or tablet that has none is unverified, and those are laid out
// as Flutter reports them (docs/quirks.md).

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'platform_chrome.dart' show isIOSPlatform;
import 'ui_scale.dart';

/// A window-top header raised into the status bar's band: its [height], and
/// what it must hold clear at its [trailing] edge (the status bar), beyond
/// the safe area. Its leading edge needs nothing of its own: the corner's
/// clearance there is the window's left inset.
typedef StatusBandHeader = ({double height, double trailing});

/// The header raised into the status bar's band where the display has one,
/// in [context]'s units — which the Font Scale divides, since the band is a
/// fixed physical size (docs/design/ui-scaling.md). Null everywhere else,
/// where a header sits below the top inset at its usual height.
StatusBandHeader? statusBandHeaderOf(BuildContext context) {
  final header = context.dependOnInheritedWidgetOfExactType<_StatusBandScope>()?.header;
  if (header == null) return null;
  final scale = UiScale.of(context);
  return (height: header.height / scale, trailing: header.trailing / scale);
}

/// On a half-folded display, how far the fold sits above the keyboard
/// actually drawn, in [context]'s units; zero everywhere else. The app root
/// ([DisplayRegionInsets]) already reports the drawn keyboard as the inset,
/// so this strip is the room between the content and the fold — for
/// whatever should end at the fold instead, like the numbers row.
double stripBelowFoldOf(BuildContext context) => (context.dependOnInheritedWidgetOfExactType<_FoldStripScope>()?.strip ?? 0) / UiScale.of(context);

/// The safe area a bar along the window's bottom edge holds — the status
/// footer, which covers the home indicator for the whole window — in
/// [context]'s units. On a foldable's display it sits lower than the safe
/// area, and clears the rounded corners at its sides instead; everywhere
/// else it is the safe area.
EdgeInsets bottomBarPaddingOf(BuildContext context) {
  final padding = MediaQuery.paddingOf(context);
  final corners = context.dependOnInheritedWidgetOfExactType<_BottomBarScope>()?.corners;
  if (corners == null) return padding;
  final scale = UiScale.of(context);
  return padding.copyWith(
    left: math.max(padding.left, corners.left / scale),
    right: math.max(padding.right, corners.right / scale),
    // Never more than the safe area: with the keyboard up it is zero.
    bottom: math.min(padding.bottom, _bottomBarBottomInset / scale),
  );
}

/// What iOS reports about the display, in the root MediaQuery's logical
/// points, for the view [size] it was measured at.
@immutable
class DisplayRegions {
  final Size size;

  /// The insets a header of [_headerExtent] at the top edge should keep:
  /// where it starts, and what it holds clear either side of it.
  final EdgeInsets? headerBar;

  /// The safe area widened at each edge by the display's rounded corners.
  final EdgeInsets? cornerSafeArea;

  /// The fold, with the margins iOS keeps either side of it, and whether the
  /// display is half-folded across it ([foldActive]).
  final Rect? fold;
  final bool foldActive;

  const DisplayRegions({required this.size, this.headerBar, this.cornerSafeArea, this.fold, this.foldActive = false});

  /// Null for anything not shaped like the reporter's snapshot: a native
  /// side that answers wrongly corrects nothing rather than everything.
  static DisplayRegions? fromMap(Object? raw) {
    if (raw is! Map) return null;
    double? number(Map<Object?, Object?> map, String key) => switch (map[key]) {
      final num n => n.toDouble(),
      _ => null,
    };
    EdgeInsets? insets(Object? value) {
      if (value is! Map) return null;
      final (top, left, bottom, right) = (number(value, 'top'), number(value, 'left'), number(value, 'bottom'), number(value, 'right'));
      if (top == null || left == null || bottom == null || right == null) return null;
      return EdgeInsets.fromLTRB(left, top, right, bottom);
    }

    final width = number(raw, 'width');
    final height = number(raw, 'height');
    if (width == null || height == null) return null;
    final fold = raw['fold'];
    Rect? foldRect;
    if (fold is Map) {
      final (left, top, w, h) = (number(fold, 'left'), number(fold, 'top'), number(fold, 'width'), number(fold, 'height'));
      if (left != null && top != null && w != null && h != null) foldRect = Rect.fromLTWH(left, top, w, h);
    }
    return DisplayRegions(
      size: Size(width, height),
      headerBar: insets(raw['headerBar']),
      cornerSafeArea: insets(raw['cornerSafeArea']),
      fold: foldRect,
      foldActive: fold is Map && fold['active'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DisplayRegions &&
      other.size == size &&
      other.headerBar == headerBar &&
      other.cornerSafeArea == cornerSafeArea &&
      other.fold == fold &&
      other.foldActive == foldActive;

  @override
  int get hashCode => Object.hash(size, headerBar, cornerSafeArea, fold, foldActive);
}

/// The bar height the reporter asks iOS to place, in physical points: on the
/// iPhone Duo's inner display it starts a bar this tall at 24pt. iOS places
/// the bar for the height it is asked about, so the start and the clearances
/// either side are the answers for this one. The reporter's own default
/// (`headerExtent` in SceneDelegate.swift) is the same figure, for the pushes
/// it sends before this pull reaches it.
const double _headerExtent = 58;

/// The height the raised header actually takes, in physical points: from
/// iOS's 24pt start, this sets the header's text on the status bar clock's
/// baseline, which sits higher in the band than the middle of iOS's own bar.
/// Measured off the iOS 27.1 simulator's iPhone Duo; a hardcoded stand-in
/// (docs/quirks.md).
const double _statusBandHeaderHeight = 46;

/// Above the tallest keyboard the iPhone Duo's inner display draws unfolded
/// (311pt, with the suggestion bar), and below what it reports half-folded:
/// a report past it, half-folded, is the keyboard settled or on its way.
const double _openKeyboardMax = 320;

/// How tall the keyboard is actually drawn half-folded, with and without the
/// suggestion bar, measured off the iOS 27.1 simulator's iPhone Duo. iOS
/// reports no drawn keyboard height there (docs/quirks.md).
const double _halfFoldKeyboardWithSuggestions = 445;
const double _halfFoldKeyboardWithoutSuggestions = 396;

/// A [SafeArea] for a bar along the window's bottom edge, holding
/// [bottomBarPaddingOf] at its sides and bottom rather than the window's
/// safe area.
class BottomBarSafeArea extends StatelessWidget {
  final Widget child;

  const BottomBarSafeArea({super.key, required this.child});

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(padding: bottomBarPaddingOf(context)),
    child: SafeArea(top: false, child: child),
  );
}

/// How far a bar along the bottom edge sits off it on a foldable's display,
/// in physical points, in place of the 34pt safe area. iOS places a bar of
/// the footer's height exactly at the safe area — it centres every bottom bar
/// 48pt up — so this is a hardcoded stand-in (docs/quirks.md): low enough to
/// spend less of the display on the band, high enough to keep the bar's
/// contents clear of the home indicator below them and, with the corner
/// clearance at its sides, of the rounded corners.
const double _bottomBarBottomInset = 12;

/// The app's MediaQuery, corrected by what iOS reports about a foldable's
/// display ([DisplayRegions]):
///
/// - Where the status bar fills only part of the top band, the top inset
///   drops to where iOS would start a header bar, the left inset takes the
///   bar's leading clearance, and [statusBandHeaderOf] says how tall that
///   header is and what it holds clear beside the status bar.
/// - Elsewhere, the leading and trailing insets clear the rounded corners,
///   which iOS leaves out of the safe area.
/// - Half-folded, the keyboard inset drops to the keyboard actually drawn,
///   and [stripBelowFoldOf] says how far above it the fold is.
/// - The status footer sits lower than the bottom safe area, clear of the
///   corners at its sides ([bottomBarPaddingOf]).
///
/// Belongs OUTSIDE [UiScale], which divides the insets it is handed.
class DisplayRegionInsets extends StatefulWidget {
  final Widget child;

  const DisplayRegionInsets({super.key, required this.child});

  @override
  State<DisplayRegionInsets> createState() => _DisplayRegionInsetsState();
}

class _DisplayRegionInsetsState extends State<DisplayRegionInsets> {
  static const _channel = MethodChannel('ham2k/display_regions');

  DisplayRegions? _regions;

  /// Whether the focused field brings up iOS's suggestion bar, and so the
  /// taller keyboard. Guessing the bar where there is none only leaves a
  /// strip empty; missing one lays the fields under the keys. So it is
  /// assumed with no field to ask, and for any field iOS offers suggestions
  /// or autofill for: autocorrect, an obscured password, or autofill hints,
  /// which bring up its Passwords bar.
  ///
  /// Read when focus moves, not while building: mid-build, the focused field
  /// can be one being torn down in the same frame, and looking up its
  /// ancestors then asserts.
  bool _suggestionBar = true;

  /// Read once: the platform never changes under a running app, so the child
  /// bare off iOS never swaps the widgets above the app. On iOS it is ALWAYS
  /// under them, corrected or not — a fold or a rotation that switched
  /// between the two shapes would unmount the whole app beneath them.
  late final bool _ios = isIOSPlatform;

  @override
  void initState() {
    super.initState();
    if (!_ios) return;
    FocusManager.instance.addListener(_focusChanged);
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'changed') return null;
      // Reported here, not thrown: the channel would turn the error into a
      // reply the reporter never reads, and the push would vanish.
      try {
        _receive(call.arguments);
      } catch (exception, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(exception: exception, stack: stack, library: 'halo_widgets', context: ErrorDescription('applying a display regions report')),
        );
      }
      return null;
    });
    _fetch();
  }

  @override
  void dispose() {
    if (_ios) {
      FocusManager.instance.removeListener(_focusChanged);
      _channel.setMethodCallHandler(null);
    }
    super.dispose();
  }

  /// The pull covers everything before the first push: launch, hot restart.
  Future<void> _fetch() async {
    try {
      _receive(await _channel.invokeMethod<Object?>('get', {'headerExtent': _headerExtent}));
    } on MissingPluginException {
      // Tests and embeddings without the reporter: nothing is corrected. Said
      // on the console, since on a device it is a channel or method name the
      // two sides disagree on, and the layout alone does not show it.
      debugPrint('[display-regions] no native reporter; display insets uncorrected');
    }
  }

  void _receive(Object? raw) {
    final regions = DisplayRegions.fromMap(raw);
    if (mounted && regions != _regions) setState(() => _regions = regions);
  }

  void _focusChanged() {
    final field = FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<EditableText>();
    final bar = field == null || field.autocorrect || field.obscureText || (field.autofillHints?.isNotEmpty ?? false);
    if (bar != _suggestionBar) setState(() => _suggestionBar = bar);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ios) return widget.child;
    final mq = MediaQuery.of(context);
    final regions = _regions;
    // A report for another size is one the rotation or fold has not caught
    // up with: its insets belong to the display as it was.
    final current =
        regions != null && regions.fold != null && (regions.size.width - mq.size.width).abs() <= 1 && (regions.size.height - mq.size.height).abs() <= 1;

    StatusBandHeader? header;
    var padding = mq.padding;
    var viewPadding = mq.viewPadding;
    var viewInsets = mq.viewInsets;
    var strip = 0.0;
    EdgeInsets? bottomBarCorners;
    if (current) {
      final bar = regions.headerBar;
      final corners = regions.cornerSafeArea;
      bottomBarCorners = corners;
      if (bar != null && bar.top < mq.padding.top) {
        // The bar's leading clearance becomes the window's left inset, not
        // the header's alone: the rail runs down that edge under the app's
        // mark, and a clearance the mark took by itself would set it off the
        // rail's column. The trailing one is the status bar's, and only the
        // header's row has it beside it.
        padding = padding.copyWith(top: bar.top, left: math.max(padding.left, bar.left));
        viewPadding = viewPadding.copyWith(top: math.min(viewPadding.top, bar.top), left: math.max(viewPadding.left, bar.left));
        header = (height: _statusBandHeaderHeight, trailing: math.max(0.0, bar.right - padding.right));
      } else if (corners != null) {
        padding = padding.copyWith(left: math.max(padding.left, corners.left), right: math.max(padding.right, corners.right));
        viewPadding = viewPadding.copyWith(left: math.max(viewPadding.left, corners.left), right: math.max(viewPadding.right, corners.right));
      }
      final halfFold = _halfFold(regions, mq.viewInsets.bottom);
      if (halfFold != null) {
        viewInsets = viewInsets.copyWith(bottom: halfFold.keyboard);
        strip = halfFold.strip;
      }
    }

    return _StatusBandScope(
      header: header,
      child: _BottomBarScope(
        corners: bottomBarCorners,
        child: _FoldStripScope(
          strip: strip,
          child: MediaQuery(
            data: mq.copyWith(padding: padding, viewPadding: viewPadding, viewInsets: viewInsets),
            child: widget.child,
          ),
        ),
      ),
    );
  }

  /// Half-folded across a fold that spans the display, the keyboard actually
  /// drawn ([keyboard]) and the strip between its top and the fold ([strip]);
  /// null otherwise. iOS reports the keyboard as reaching the fold's upper
  /// margin, whatever keyboard it draws below.
  ///
  /// Reports between [_openKeyboardMax] and that one are the keyboard
  /// animating in or out, and the correction scales with them. Applied only
  /// once the report settles, the layout jumps by the whole correction at the
  /// end of the keyboard's arrival and the start of its departure. Scaled
  /// from the open maximum rather than from zero, the layout never sits lower
  /// than the keyboard iOS is drawing on its way.
  ({double keyboard, double strip})? _halfFold(DisplayRegions regions, double reported) {
    final fold = regions.fold;
    if (fold == null || !regions.foldActive || fold.width < regions.size.width - 1) return null;
    final settled = regions.size.height - fold.top;
    if (reported <= _openKeyboardMax || settled <= _openKeyboardMax) return null;
    final t = math.min(1.0, (reported - _openKeyboardMax) / (settled - _openKeyboardMax));
    final drawn = _suggestionBar ? _halfFoldKeyboardWithSuggestions : _halfFoldKeyboardWithoutSuggestions;
    final foldLine = regions.size.height - fold.center.dy;
    return (keyboard: _openKeyboardMax + (drawn - _openKeyboardMax) * t, strip: math.max(0.0, foldLine - drawn) * t);
  }
}

/// Two scopes, not one: the strip moves on every frame of a half-folded
/// keyboard's animation, and every window-top header depends on the band.
class _StatusBandScope extends InheritedWidget {
  final StatusBandHeader? header;

  const _StatusBandScope({required this.header, required super.child});

  @override
  bool updateShouldNotify(_StatusBandScope oldWidget) => header != oldWidget.header;
}

class _BottomBarScope extends InheritedWidget {
  /// iOS's corner-adapted safe area, in physical points; null where the
  /// bottom bar holds the plain safe area.
  final EdgeInsets? corners;

  const _BottomBarScope({required this.corners, required super.child});

  @override
  bool updateShouldNotify(_BottomBarScope oldWidget) => corners != oldWidget.corners;
}

class _FoldStripScope extends InheritedWidget {
  final double strip;

  const _FoldStripScope({required this.strip, required super.child});

  @override
  bool updateShouldNotify(_FoldStripScope oldWidget) => strip != oldWidget.strip;
}

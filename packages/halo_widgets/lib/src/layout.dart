// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The app-wide width vocabulary (docs/design/layouts.md): four shirt sizes
// and one ideal pane width. Root views branch their pane arrangement on
// `ShirtSize.of(context)` instead of inventing per-view breakpoints, so
// every view reflows at the same window widths.
//
// Widths here are plain logical pixels in the UiScale-divided space
// (docs/design/ui-scaling.md rule 4): `ShirtSize.of` reads the scaled
// MediaQuery width on purpose, so a larger font scale genuinely fits less
// and collapses layouts sooner — and a font-scale change can flip a view's
// shirt size while it's on screen.

import 'package:flutter/widgets.dart';

import 'density.dart';
import 'spacing.dart';

/// The width most panes are designed for.
///
/// Width only. The height counterpart is `LayoutDensity` (density.dart), which
/// classifies how much vertical room the app's furniture spends — see
/// docs/design/layouts.md § Layout density. It sits between the S and L
/// boundaries, and that gap is deliberate: a window around this width just
/// shows one pane at its best size — there is no "M" shirt size. Two-pane
/// layouts default their primary pane to this width.
const double idealPaneWidth = 500.0;

/// Below this a pane stops being useful (forms wrap badly, lists truncate).
/// The default minimum for either side of a resizable split.
const double minPaneWidth = 280.0;

/// The floor a DOCK pane may be laid out at, on either axis — a different and
/// much harder limit than [minPaneWidth], which is about a pane being *useful*.
/// This one is about a pane being *possible*: below it a pane cannot draw the
/// chrome that makes it a pane at all, and its own Column overflows.
///
/// **Height** is [dockMinPaneHeight] — one standard value for every pane,
/// whatever chrome it happens to carry. A group of tabs cannot be shorter than
/// a tab; a group with a header cannot be shorter than that header; and a
/// headerless pane cannot be shorter than the chrome edit mode needs to put
/// over it. Those are the same measurement, so they are one number, and a pane
/// never changes height just because the operator entered edit mode.
///
/// **Width** is [dockMinPaneWidth]: enough for a grab handle and an options
/// button with no title between them. A pane narrower than that has no way to
/// be moved or configured, which makes it unrecoverable rather than merely
/// cramped.
///
/// Read the height through [dockMinPaneHeight], never as a constant: on touch
/// the chrome it is derived from is held to the tap-target minimum, and the
/// density rungs move it besides.
double dockMinPaneHeight(BuildContext context) => LayoutDensity.chromeHeightOf(context);

/// Grab handle + options button, no title. Both are square tap targets at the
/// chrome height, plus the gap between them.
double dockMinPaneWidth(BuildContext context) => LayoutDensity.chromeHeightOf(context) * 2 + Space.md;

/// The base resize floor for a desktop window, in logical (UiScale-divided)
/// pixels: the width is the S-size layout minimum ([ShirtSize.xsMax]) — a
/// resizable window may not shrink into the XS single-column layout — and the
/// height is a comfortable minimum. Fixed device screens may be smaller
/// (layouts must still tolerate them); resizable windows may not. The native
/// window controls that float over the header (traffic lights / caption
/// buttons) need width on top of this; that platform- and scale-dependent
/// sum is `desktopMinimumWindowSize` (platform_chrome.dart), which is what
/// WindowChromeService actually enforces.
const Size minWindowSize = Size(ShirtSize.xsMax, 480.0);

/// The standard duration/curve for layout changes (pane widths, panes
/// appearing on a shirt-size flip) — matches the app's existing implicit
/// animations.
const Duration layoutAnimationDuration = Duration(milliseconds: 300);
const Curve layoutAnimationCurve = Curves.easeInOut;

/// How a root view participates in layout customization (DESIGN.md §7).
///
/// The classification drives the divider language: [customizable] views use
/// the solid header-colored dividers everywhere (their panes are movable,
/// and the solid bar reads as furniture between movable modules), while
/// [fixed] views may opt their splits into the "surfaces" style
/// (ResizableSplitView's overlay divider with the drop shadow), which
/// reads as one surface floating over another.
enum ViewLayoutPolicy {
  /// The view's arrangement is fixed: panes never move, and its splits may
  /// use either divider style (Home and Settings currently opt into
  /// "surfaces").
  fixed,

  /// The view's panes are user-arrangeable via the dock layout (currently
  /// only the Operation view). Solid dividers only.
  customizable,
}

enum ShirtSize {
  xs,
  s,
  l,
  xl;

  /// Below this → XS: genuinely small phones (the classic 360 Android
  /// baseline is already S).
  static const double xsMax = 360.0;

  /// Below this → S. At 720 the settings and operation views go two-pane;
  /// iPad-mini portrait (768) and up qualify.
  static const double sMax = 720.0;

  /// Below this → L. XL is reserved: it behaves identically to L today and
  /// exists so views can diverge later (third columns, wider gutters)
  /// without another migration.
  static const double lMax = 1200.0;

  static ShirtSize fromWidth(double width) {
    if (width < xsMax) return xs;
    if (width < sMax) return s;
    if (width < lMax) return l;
    return xl;
  }

  /// The shirt size for [context]'s window. Depends on `MediaQuery.size`, so
  /// callers rebuild live as the window is resized or the font scale changes.
  static ShirtSize of(BuildContext context) => fromWidth(MediaQuery.sizeOf(context).width);

  /// Whether root views show side-by-side panes at this size (L and XL).
  bool get isTwoPane => index >= l.index;
}

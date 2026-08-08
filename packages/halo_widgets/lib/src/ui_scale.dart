// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// App-wide UI scaling. The font-scale setting scales the ENTIRE interface —
// header, list rows, buttons, padding, borders, gaps, text — not just text
// and icons, and it does so from ONE place so ordinary widget code never has
// to know about scaling. Write plain Flutter with logical pixels; it scales
// for free, and proportions can't drift because everything scales by exactly
// the same factor.
//
// Mechanism: the child subtree is told (via MediaQuery) that the screen is
// `size / scale` logical pixels, so it lays out in that larger-or-smaller
// coordinate space; a Transform then paints the result back up by `scale` to
// fill the real window. Because Flutter records the scene as vector drawing
// commands and rasterizes AFTER the transform, text and shapes stay crisp at
// any scale — only embedded raster images and native platform views (e.g. a
// map webview) scale as textures.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class UiScale extends StatelessWidget {
  final double scale;
  final Widget child;

  const UiScale({super.key, required this.scale, required this.child});

  /// The UI scale in effect for [context] (1.0 if none is above). For the
  /// rare element that must stay a fixed PHYSICAL size while everything around
  /// it scales — e.g. clearance for the macOS traffic lights, which are native
  /// fixed-size controls (see platform_chrome.dart) — divide the fixed
  /// physical dimension by this to get the logical value that renders at that
  /// fixed size after the transform.
  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_UiScaleScope>()?.scale ?? 1.0;

  @override
  Widget build(BuildContext context) {
    if (scale == 1.0) return _UiScaleScope(scale: 1.0, child: child);

    final mq = MediaQuery.of(context);
    final inverse = 1.0 / scale;
    // Size AND insets divide by the scale, so safe areas and the on-screen
    // keyboard land correctly in the scaled coordinate space.
    final scaledMq = mq.copyWith(
      size: mq.size * inverse,
      padding: mq.padding * inverse,
      viewInsets: mq.viewInsets * inverse,
      viewPadding: mq.viewPadding * inverse,
      systemGestureInsets: mq.systemGestureInsets * inverse,
    );

    // FittedBox (not a bare Transform): a bare Transform would pass the
    // window's tight constraints straight through, forcing the inner SizedBox
    // back to full size so nothing actually scaled. FittedBox lays the child
    // out at its natural (divided) size under loose constraints, then scales
    // it to fill — the fill factor works out to exactly `scale` because the
    // SizedBox is the window size divided by `scale`.
    //
    // SizedBox.expand around it because FittedBox only scales up to the
    // constraints it is GIVEN. Handed loose ones it shrink-wraps instead, and
    // the whole mechanism silently degrades: the subtree still lays out in the
    // divided coordinate space (so the UI reflows) but never gets magnified.
    // That asymmetry only shows above 1.0 — below it the child is larger than
    // the window and gets clamped, which looks correct — so a loose-constraint
    // ancestor can hide the failure entirely. Expanding here makes the
    // primitive independent of the parent's constraint discipline.
    return _UiScaleScope(
      scale: scale,
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.fill,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: scaledMq.size.width,
            height: scaledMq.size.height,
            child: MediaQuery(data: scaledMq, child: child),
          ),
        ),
      ),
    );
  }
}

/// One pane drawn at a different scale from the rest of the app.
///
/// [UiScale] is a ROOT primitive and cannot be nested: it sizes its inner box
/// to the ambient MediaQuery — the WINDOW — and lets `BoxFit.fill` stretch
/// that box to whatever constraints it is given. At the root those two agree
/// and the fill factor works out to exactly `scale`. Inside a pane they do
/// not: the box is still window-shaped while the constraints are pane-shaped,
/// so the two axes stretch by DIFFERENT factors and text comes out narrower
/// or wider rather than bigger. Nothing throws; it just looks wrong.
///
/// This measures instead — the box is the incoming CONSTRAINTS divided by the
/// factor, so filling them back is uniform by construction.
///
/// [scale] is ABSOLUTE, on the same 1.0-is-normal ladder as the app's own
/// Font Scale, and the relative factor is worked out here. A caller passing a
/// pre-divided value would have to know what is already in force, and would
/// be wrong the moment the app's own scale changed underneath it.
class SubtreeUiScale extends StatelessWidget {
  final double scale;
  final Widget child;

  const SubtreeUiScale({super.key, required this.scale, required this.child});

  @override
  Widget build(BuildContext context) {
    final relative = scale / UiScale.of(context);
    // No early return at identity, tempting as it is. Returning the child
    // unwrapped changes the widget chain above it, so a pane whose override
    // is dialled to whatever the app is already at would UNMOUNT its subtree
    // — a map reloading its tiles, an extension panel re-rendering, a
    // half-typed field cleared — on the way past. At 1.0 everything below is
    // the identity anyway.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Nothing to divide. Panes are laid out under tight constraints, so
        // this is a caller putting one somewhere it was never meant to go —
        // better unscaled than laid out against infinity, but loud about it:
        // the override silently doing nothing while its setting stays
        // checked is indistinguishable from the setting being off.
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          assert(false, 'SubtreeUiScale needs bounded constraints on both axes; got $constraints');
          return child;
        }
        final mq = MediaQuery.of(context);
        final inverse = 1.0 / relative;
        // The SUBTREE's idea of the screen still divides the same way the
        // root's does, so breakpoints inside a rescaled pane answer about the
        // window like they do everywhere else. Only the box below is measured
        // from the pane.
        final scaledMq = mq.copyWith(
          size: mq.size * inverse,
          padding: mq.padding * inverse,
          viewInsets: mq.viewInsets * inverse,
          viewPadding: mq.viewPadding * inverse,
          systemGestureInsets: mq.systemGestureInsets * inverse,
        );
        return _UiScaleScope(
          // The ABSOLUTE scale, not the relative factor: this is what
          // [PixelGrid] multiplies by the device ratio, and what it has to
          // snap against is the real device grid.
          scale: scale,
          // Sized to the measured box, so the FittedBox below is given TIGHT
          // constraints. It only scales up to the constraints it is given; a
          // loose ancestor and it shrink-wraps the child instead, and the
          // whole mechanism degrades silently — the subtree still lays out in
          // the divided space, so more or less fits on screen, but is never
          // magnified. Same trap, and same fix, as [UiScale]'s own
          // SizedBox.expand; a LayoutBuilder passes its incoming constraints
          // straight through, so measuring them is not the same as tightening
          // them.
          child: SizedBox.fromSize(
            size: constraints.biggest,
            child: FittedBox(
              fit: BoxFit.fill,
              alignment: Alignment.topLeft,
              child: SizedBox.fromSize(
                size: constraints.biggest * inverse,
                child: MediaQuery(data: scaledMq, child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The DEVICE pixel grid, as seen from inside the scaled coordinate space:
/// one logical (UiScale-divided) pixel paints as `UiScale × devicePixelRatio`
/// device pixels.
///
/// A boundary between two differently-colored surfaces that lands BETWEEN
/// device pixels is antialiased into both, and the blended pair reads as a
/// hairline seam — the gaps you see between panes. So every such boundary
/// (pane edges, divider edges, the top of a pane's header bar) snaps to this
/// grid. Snapping whole LOGICAL pixels is not enough: at a non-1.0 font scale
/// those still land off the device grid (0.85 × 2.0 = a 1.7 device-px step).
///
/// Snap BOUNDARY POSITIONS, not extents: an extent snapped in isolation still
/// lands off-grid if the element before it started off-grid. The pattern is to
/// walk a run cumulatively, snap each edge, and take each child's extent as the
/// difference between its two snapped edges — see `DockLayoutView._buildSplit`.
class PixelGrid {
  /// Device pixels per logical pixel in this coordinate space.
  final double devicePixelsPerLogical;

  const PixelGrid(this.devicePixelsPerLogical);

  static PixelGrid of(BuildContext context) =>
      PixelGrid(UiScale.of(context) * MediaQuery.devicePixelRatioOf(context));

  double snap(double value) => (value * devicePixelsPerLogical).roundToDouble() / devicePixelsPerLogical;

  /// Snaps DOWN — for a value that must not exceed a cap (an in-flight
  /// animation value against the space actually available).
  double snapDown(double value) => (value * devicePixelsPerLogical).floorToDouble() / devicePixelsPerLogical;

  /// Snaps UP, never below one whole device pixel — for a thin line that must
  /// stay visible as well as crisp (rounding 0.4 device px to 0 erases it).
  double snapUp(double value) =>
      math.max(1.0, (value * devicePixelsPerLogical).ceilToDouble()) / devicePixelsPerLogical;
}

class _UiScaleScope extends InheritedWidget {
  final double scale;

  const _UiScaleScope({required this.scale, required super.child});

  @override
  bool updateShouldNotify(_UiScaleScope oldWidget) => oldWidget.scale != scale;
}

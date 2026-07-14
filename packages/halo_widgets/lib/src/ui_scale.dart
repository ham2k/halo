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

    // FittedBox (not a bare Transform): the window hands down TIGHT
    // constraints, which would otherwise force a plain SizedBox straight back
    // to full size. FittedBox lays the child out at its natural (divided)
    // size under loose constraints, then scales it to fill the window — the
    // fill factor works out to exactly `scale` because the SizedBox is the
    // window size divided by `scale`.
    return _UiScaleScope(
      scale: scale,
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: scaledMq.size.width,
          height: scaledMq.size.height,
          child: MediaQuery(data: scaledMq, child: child),
        ),
      ),
    );
  }
}

class _UiScaleScope extends InheritedWidget {
  final double scale;

  const _UiScaleScope({required this.scale, required super.child});

  @override
  bool updateShouldNotify(_UiScaleScope oldWidget) => oldWidget.scale != scale;
}

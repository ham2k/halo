// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The three dots beside a view's title that say "this opens a sheet", and
// the hand-off they make to the sheet's accept button as it slides in. Shared
// by every header that opens a top sheet from its title, so they all move the
// same way.

import 'package:flutter/material.dart';

/// How far into the sheet's open/close slide (0 closed, 1 open) the header's
/// falling-dots handoff to the accept button completes — shared by the
/// title's leading-gap animation, the accept button's own grow-in, and the
/// dots' fade-out ([SheetHeaderDots]), which all have to reach their end state
/// at the same instant for the handoff to read as one motion rather than three
/// drifting apart.
const sheetHandoffThreshold = 0.6;

/// The dots' own footprint in the title row — the width the leading gap rests
/// at while the sheet is closed.
const double sheetHeaderDotsWidth = 10.0;

/// The title's leading gap at [progress] through the sheet's slide: from the
/// dots' own width to [okButtonWidth] — the accept button draws OVER this
/// corner, not inside it, so the title has to make room — on the same curve
/// [SheetAcceptHandoff] grows the button by. Null before the button has laid
/// out, when the dots' width is right anyway.
double sheetLeadingGapWidth(double progress, double? okButtonWidth) {
  if (progress == 0.0) return sheetHeaderDotsWidth;
  final growth = (progress / sheetHandoffThreshold).clamp(0.0, 1.0);
  final target = okButtonWidth ?? sheetHeaderDotsWidth;
  return sheetHeaderDotsWidth + (target - sheetHeaderDotsWidth) * growth;
}

/// The sheet's accept button growing out of the dots' top circle instead of
/// popping in at full size — on the curve the dots fade by, so the two read
/// as one handoff.
class SheetAcceptHandoff extends StatelessWidget {
  /// The sheet's slide; null reads as fully open.
  final Animation<double>? animation;
  final Widget child;

  const SheetAcceptHandoff({super.key, required this.animation, required this.child});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation ?? const AlwaysStoppedAnimation(1.0),
    builder: (context, child) {
      final growth = ((animation?.value ?? 1.0) / sheetHandoffThreshold).clamp(0.0, 1.0);
      return Opacity(
        opacity: growth,
        child: Transform.scale(scale: 0.2 + 0.8 * growth, alignment: Alignment.centerLeft, child: child),
      );
    },
    child: child,
  );
}

class SheetHeaderDots extends StatelessWidget {
  /// The sheet's slide, 0 closed to 1 open.
  final double progress;

  const SheetHeaderDots({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    // Fixed width: the space stays reserved while the sheet is open, so the
    // header title never shifts — the accept button draws over this corner
    // via the sheet's headerLeading instead.
    return SizedBox(
      width: sheetHeaderDotsWidth,
      height: 32,
      child: CustomPaint(
        size: const Size(sheetHeaderDotsWidth, 32),
        painter: _FallingDotsPainter(progress: progress, dotColor: onPrimary),
      ),
    );
  }
}

class _FallingDotsPainter extends CustomPainter {
  final double progress;
  final Color dotColor;

  _FallingDotsPainter({required this.progress, required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    // The dots fall toward the sheet sliding in below and fade out on the
    // way; the top dot grows slightly as it goes, reading as a hand-off to
    // the accept button growing in over it.
    final opacity = (1.0 - progress / sheetHandoffThreshold).clamp(0.0, 1.0);
    if (opacity <= 0) return;

    final paint = Paint()
      ..color = dotColor.withValues(alpha: dotColor.a * opacity)
      ..style = PaintingStyle.fill;

    const x = 4.0;
    const dotRadius = 1.8;
    final dy = 26.0 * progress;

    canvas.drawCircle(Offset(x, 10.0 + dy), dotRadius + 4.0 * progress, paint);
    canvas.drawCircle(Offset(x, 16.0 + dy), dotRadius, paint);
    canvas.drawCircle(Offset(x, 22.0 + dy), dotRadius, paint);
  }

  @override
  bool shouldRepaint(_FallingDotsPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.dotColor != dotColor;
}

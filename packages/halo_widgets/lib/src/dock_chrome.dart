// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The paint of edit mode: the frame around a pane or tab that can be
// dragged, and the wash over the ones that cannot. Sizes and colours here
// are the ones the layout's hit-testing assumes, so they live together.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'density.dart';
import 'theme.dart' show fabAccentColor;

/// Thick enough to read as the pane's own outline from across the window
/// rather than as a hairline somebody left on, which is the whole job: while
/// editing, the operator is looking at BLOCKS, and the contents are only
/// there to say which block is which.
const double editingFrameWidth = 5.0;

/// Rounds the TABS' top corners only. The pane's bottom corners stay square:
/// they sit against the dock's own dividers and edges, which are square, and
/// a rounded corner there reads as a gap somebody forgot to close.
const double editingFrameRadius = 8.0;

/// Fills the tab that is showing, so the pane's own tab is picked out of the
/// strip at a glance while the operator is deciding what to move. A fixed
/// dark blue rather than a ColorScheme role, for the same reason
/// [fabAccentColor] is one: the strip is the app's teal chrome in both
/// brightnesses, so what sits on it has to be chosen against THAT rather than
/// against a surface.
const Color editingSelectedTabColor = Color(0xFF003049);

/// [fabAccentColor], not `colorScheme.primary` like the drop bands: this
/// frame sits ON pane content in both brightnesses, and that is exactly the
/// role fabAccentColor exists for — a color that pops against primary chrome
/// and surfaces alike. Keeping the two apart also keeps them legible
/// together, since the frames are up while a drag paints its band.
const Color _editingFrameColor = fabAccentColor;

/// Over the contents of every pane while editing. Heavy, and deliberately
/// neutral: the panes are blocks to be arranged then, not things to read, and
/// a half-opaque grey says that about a map's tiles and a log's table alike.
/// It doubles as the drop regions' wash does — a painted surface is what
/// routes pointer events over a native platform view back to Flutter.
const Color _editingScrimColor = Color(0x80808080);

/// The showing tab's fill, bled down into the top of the pane so the two read
/// as one surface rather than as a coloured tab above a grey pane.
///
/// A fade, with no solid band under the header: nothing sits in that space
/// any more (the pane's editing control moved up into the header itself), so
/// holding a slab of flat colour there would be reserving room for something
/// that is not coming.
class EditingPaneWash extends StatelessWidget {
  const EditingPaneWash({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        if (!height.isFinite || height <= 0) return const ColoredBox(color: _editingScrimColor);
        // A pane can be shorter than the fade — a three-way vertical split in
        // a small window, or a large font scale — so it takes at most half of
        // what there is.
        final fade = math.min(LayoutDensity.chromeHeightOf(context), height / 2);
        // One gradient rather than stacked boxes: stacked boxes have to be
        // told how to give way when the pane is short, and every answer to
        // that is a way to overflow.
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [editingSelectedTabColor, _editingScrimColor, _editingScrimColor],
              stops: [0, fade / height, 1],
            ),
          ),
        );
      },
    );
  }
}

Paint get _editingFramePaint => Paint()
  ..color = _editingFrameColor
  ..style = PaintingStyle.stroke
  ..strokeWidth = editingFrameWidth
  ..strokeCap = StrokeCap.butt
  // Mitred, so the pane's two square corners close to a point rather than
  // leaving the stroke's own width unpainted at each.
  ..strokeJoin = StrokeJoin.miter;

/// One tab's segment of its pane's outline.
///
/// EVERY tab is outlined — each one is a thing that can be picked up, so each
/// is drawn as a block with a rounded top. The tab that is SHOWING leaves its
/// bottom open, so the pane's outline runs into it; the rest close theirs,
/// and those closing lines tile into the pane's top edge exactly, at any tab
/// width and at any scroll offset.
class TabFramePainter extends CustomPainter {
  final bool selected;

  /// Whether this tab is at an end of the strip. An INTERIOR tab centres its
  /// side strokes on its own boundaries, so it and its neighbour draw the one
  /// line between them instead of two 5pt lines 5pt apart. The strip's two
  /// outer edges have no neighbour to share with and would lose their outer
  /// half to the scroll viewport's clip, so those are inset instead.
  final bool isFirst;
  final bool isLast;

  const TabFramePainter({required this.selected, required this.isFirst, required this.isLast});

  @override
  void paint(Canvas canvas, Size size) {
    const half = editingFrameWidth / 2;
    final left = isFirst ? half : 0.0;
    final right = isLast ? size.width - half : size.width;
    // Never more than half the tab, so a narrow tab bows rather than drawing
    // a corner that has run past the opposite one.
    final r = math.min(editingFrameRadius, math.max(0.0, (right - left) / 2));
    // Quadratic curves through the corner point rather than arcTo: the sweep
    // direction of an arc between two points has two answers and only one of
    // them is the corner.
    final path = Path()
      ..moveTo(left, size.height)
      ..lineTo(left, half + r)
      ..quadraticBezierTo(left, half, left + r, half)
      ..lineTo(right - r, half)
      ..quadraticBezierTo(right, half, right, half + r)
      ..lineTo(right, size.height);
    if (!selected) {
      // Edge to edge, not corner to corner: this line IS the pane's top edge
      // where this tab sits over it, and it has to meet what the tabs either
      // side of it drew.
      path
        ..moveTo(0, size.height - half)
        ..lineTo(size.width, size.height - half);
    }
    canvas.drawPath(path, _editingFramePaint);
  }

  @override
  bool shouldRepaint(TabFramePainter oldDelegate) =>
      oldDelegate.selected != selected || oldDelegate.isFirst != isFirst || oldDelegate.isLast != isLast;
}

/// The rest of the outline: the pane body's leading, trailing and bottom
/// edges, with the bottom corners rounded. No top — the tab strip drew that,
/// notched around the tab that is showing.
class PaneFramePainter extends CustomPainter {
  /// Whether the tab strip above is drawing this pane's top edge for us.
  /// False for a headerless pane, which has no strip and so needs the fourth
  /// side painted here — the outline is what marks a pane as a block to be
  /// moved, and three sides of one reads as an unfinished box.
  final bool topFromStrip;

  const PaneFramePainter({this.topFromStrip = true});

  @override
  void paint(Canvas canvas, Size size) {
    const half = editingFrameWidth / 2;
    if (!topFromStrip) {
      canvas.drawRect(
        Rect.fromLTRB(half, half, size.width - half, size.height - half),
        _editingFramePaint,
      );
      return;
    }
    // Starts at y = 0, which is the strip's own bottom edge — the horizontal
    // segments the tabs drew are centred half a stroke ABOVE that, so the two
    // overlap rather than meeting at a seam. The pane's content is inset by a
    // whole stroke on these three sides (see `_buildGroup` in dock_layout.dart), so the line sits
    // in room the pane gave up rather than over anything it is showing.
    //
    // Square corners: these two sit against the dock's own dividers and its
    // outer edge, both square, and a radius there opens a gap rather than
    // softening anything.
    final path = Path()
      ..moveTo(half, 0)
      ..lineTo(half, size.height - half)
      ..lineTo(size.width - half, size.height - half)
      ..lineTo(size.width - half, 0);
    canvas.drawPath(path, _editingFramePaint);
  }

  @override
  bool shouldRepaint(PaneFramePainter oldDelegate) => oldDelegate.topFromStrip != topFromStrip;
}

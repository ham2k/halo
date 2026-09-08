// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// `AnimatedCrossFade` for a SLIVER: opens and shuts a whole sliver subtree,
/// wiping it in and out from the top and fading it as it goes.
///
/// The accordion body has to be slivers rather than a box, because the
/// section bands INSIDE it pin — and a pinned band is a sliver, which a box
/// subtree cannot hold. That rules out `AnimatedCrossFade`, which sizes a
/// box; this is the sliver equivalent, and the two are meant to read the
/// same on screen.
///
/// The child is laid out at its full size throughout, and what shrinks is
/// how much of it this sliver claims and paints — so the rows inside do not
/// reflow on their way out, exactly as a cross-fade's clip does not reflow
/// what it hides.
///
/// The child stays MOUNTED while shut. A settings category holds forms whose
/// `FocusNode`s and `TextEditingController`s belong to their State: dropping
/// them mid-search takes the focus out of the field being typed in (on web,
/// the browser's text-input element goes with it), which is why the panel
/// keeps every category built.
class CollapsingSliver extends StatefulWidget {
  final bool expanded;

  /// The sliver to open and shut. One sliver, so a group of them arrives as
  /// a [SliverMainAxisGroup].
  final Widget child;

  final Duration duration;
  final Curve curve;

  const CollapsingSliver({
    super.key,
    required this.expanded,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
    this.curve = Curves.easeInOut,
  });

  @override
  State<CollapsingSliver> createState() => _CollapsingSliverState();
}

class _CollapsingSliverState extends State<CollapsingSliver> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    // Where it starts, not where it animates from: a category built open
    // (the one the panel remembers) must not play its own opening.
    value: widget.expanded ? 1 : 0,
  );

  @override
  void didUpdateWidget(CollapsingSliver old) {
    super.didUpdateWidget(old);
    _controller.duration = widget.duration;
    if (widget.expanded != old.expanded) {
      widget.expanded ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Clamped, and read from the widget rather than captured: a curve that
  /// overshoots (an elastic one) hands out values outside 0..1, which both a
  /// `SliverOpacity` and a `SliverGeometry` assert against.
  double get _factor => widget.curve.transform(_controller.value).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        // Built once and reused across every frame of the animation: the
        // subtree holds the forms, and rebuilding it per frame would be both
        // wasteful and a way to lose their State.
        child: widget.child,
        builder: (context, child) => _CollapsedSliver(
          factor: _factor,
          // Semantics go with the paint: a shut category is not a place the
          // screen reader (or the Tab order) should land.
          child: SliverOpacity(opacity: _factor, sliver: child!),
        ),
      );
}

class _CollapsedSliver extends SingleChildRenderObjectWidget {
  final double factor;

  const _CollapsedSliver({required this.factor, required Widget child}) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCollapsedSliver(factor: factor);

  @override
  void updateRenderObject(BuildContext context, _RenderCollapsedSliver renderObject) =>
      renderObject.factor = factor;
}

/// Reports [factor] of its child's extent and paints the top of it, clipped.
class _RenderCollapsedSliver extends RenderSliver with RenderObjectWithChildMixin<RenderSliver> {
  _RenderCollapsedSliver({required this._factor});

  double _factor;

  set factor(double value) {
    if (value == _factor) return;
    _factor = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! SliverPhysicalParentData) child.parentData = SliverPhysicalParentData();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      geometry = SliverGeometry.zero;
      return;
    }
    // Laid out against the FULL viewport, not against what is left of this
    // sliver: the child must produce the same layout at every stage of the
    // animation, or its rows reflow as it opens.
    child.layout(constraints, parentUsesSize: true);
    final childGeometry = child.geometry!;
    if (childGeometry.scrollOffsetCorrection != null) {
      geometry = SliverGeometry(scrollOffsetCorrection: childGeometry.scrollOffsetCorrection);
      return;
    }

    final scrollExtent = childGeometry.scrollExtent * _factor;
    // What a sliver of OUR extent would paint, and never more of the child
    // than the child itself has.
    final paintExtent = math.min(
      childGeometry.paintExtent,
      calculatePaintOffset(constraints, from: 0, to: scrollExtent),
    );
    geometry = SliverGeometry(
      scrollExtent: scrollExtent,
      paintExtent: paintExtent,
      layoutExtent: math.min(childGeometry.layoutExtent, paintExtent),
      maxPaintExtent: childGeometry.maxPaintExtent * _factor,
      // Relayed, not dropped: the child holds the pinned bands, and a
      // viewport told they obstruct nothing lays the next sliver out as if
      // there were nothing to paint under.
      maxScrollObstructionExtent: math.min(childGeometry.maxScrollObstructionExtent, paintExtent),
      cacheExtent: calculateCacheOffset(constraints, from: 0, to: scrollExtent),
      // The part of the child past the wipe is painted over, not laid out
      // away, so there is always something outside the box to clip.
      hasVisualOverflow: true,
    );
    (child.parentData! as SliverPhysicalParentData).paintOffset = Offset.zero;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null || !geometry!.visible) return;
    context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & _clipSize,
      (context, offset) => context.paintChild(child, offset),
    );
  }

  Size get _clipSize => switch (constraints.axis) {
        Axis.vertical => Size(constraints.crossAxisExtent, geometry!.paintExtent),
        Axis.horizontal => Size(geometry!.paintExtent, constraints.crossAxisExtent),
      };

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) {
    final child = this.child;
    // Only what is actually on screen answers a tap: half-wiped rows still
    // exist below the clip, and a row nobody can see must not be tappable.
    if (child == null || mainAxisPosition >= geometry!.paintExtent) return false;
    return child.geometry!.hitTestExtent > 0 &&
        child.hitTest(result, mainAxisPosition: mainAxisPosition, crossAxisPosition: crossAxisPosition);
  }

  @override
  double childMainAxisPosition(RenderSliver child) => 0;

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) =>
      (child.parentData! as SliverPhysicalParentData).applyPaintTransform(transform);
}

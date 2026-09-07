// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The drop targets edit mode shows while a tab is being dragged: a group's
// body bands, the slots between tabs, the dock's own edge, and the delete
// well. All of them report into DockLayoutViewState; none holds layout.

import 'package:flutter/material.dart';

import 'density.dart';
import 'layout.dart';
import 'mdi_icons.g.dart';

import 'dock_regions.dart';

/// The split targets over a group's BODY while a drag is live: a top and a
/// bottom band, each a third of the height and running the full width, and a
/// left and a right band, each a third of the width and running the full
/// height. Joining a group as a tab is not here — that is the tab strip's own
/// job (see [DockTabDropSlot]), where the tabs the module would join actually
/// are.
///
/// The bands OVERLAP at the corners, deliberately: full-length bands are what
/// make each one big enough to hit without aiming, and the ambiguity that
/// buys is resolved by two rules rather than by shrinking them —
///
/// 1. entering a corner from outside picks the HORIZONTAL band, because a
///    pointer arriving at a corner is usually on its way somewhere and the
///    top/bottom split is the one a corner reads as;
/// 2. a band already highlighted KEEPS the pointer as it slides into an
///    overlap, so the highlight doesn't flicker between two answers while
///    the operator is still moving.
///
/// The middle square belongs to no band: a drop there is a no-op rather than
/// a guess.
class DockGroupDropRegions extends StatefulWidget {
  final double washAlpha;
  final void Function(String id, DockBodyDrop drop) onDrop;

  const DockGroupDropRegions({super.key, required this.washAlpha, required this.onDrop});

  @override
  State<DockGroupDropRegions> createState() => _DockGroupDropRegionsState();
}

class _DockGroupDropRegionsState extends State<DockGroupDropRegions> {
  DockBodyDrop? _active;

  /// The band last highlighted, kept after [_active] clears so the highlight
  /// can fade out where it was rather than blinking off.
  DockBodyDrop? _fading;

  void _updateFrom(Offset globalOffset) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(globalOffset);
    // The outer bands first: they are disjoint from the centre square by
    // construction, and only the outer ones carry the sticky-corner rule —
    // which must not be handed a centre answer to stick to.
    final split = dockSplitRegionAt(local, box.size, active: _active?.nest == false ? _active!.region : null);
    final drop = split != null
        ? DockBodyDrop(split, nest: false)
        : switch (dockNestRegionAt(local, box.size)) {
            final region? => DockBodyDrop(region, nest: true),
            null => null,
          };
    if (drop != _active) {
      setState(() {
        _active = drop;
        _fading = drop ?? _fading;
      });
    }
  }

  /// Where [drop]'s highlight is painted — the band itself, so what the
  /// operator sees is exactly what they are aiming at. A nesting half is drawn
  /// inside the centre square, at the size the pane it creates will have.
  Rect _bandOf(DockBodyDrop drop, Size size) {
    if (drop.nest) {
      final left = size.width / 3;
      final top = size.height / 3;
      final inert = size.height / 3 * dockNestInertFraction / 2;
      final half = size.height / 2;
      return drop.region == DockRegion.top
          ? Rect.fromLTRB(left, top, size.width - left, half - inert)
          : Rect.fromLTRB(left, half + inert, size.width - left, size.height - top);
    }
    return switch (drop.region) {
      DockRegion.top => Rect.fromLTWH(0, 0, size.width, size.height / 3),
      DockRegion.bottom => Rect.fromLTWH(0, size.height * 2 / 3, size.width, size.height / 3),
      DockRegion.left => Rect.fromLTWH(0, 0, size.width / 3, size.height),
      DockRegion.right => Rect.fromLTWH(size.width * 2 / 3, 0, size.width / 3, size.height),
    };
  }

  @override
  Widget build(BuildContext context) {
    // Stays on colorScheme.primary, unlike the rest of the app's on-surface
    // accents, and deliberately: this paints over PANE CONTENT rather than
    // over a theme surface, so no single flat color works. The map pane's
    // tiles are light in BOTH brightnesses, and against white the 2px border
    // reads at 6.4:1 in primary but only 2.8:1 in the lighter accent — under
    // the 3:1 a UI stroke needs, on the pane the drop target most needs to
    // cover. Against a dark pane the trade runs the other way (2.7:1 vs
    // 6.2:1). Fixing both needs a two-tone stroke, not a different color.
    final accent = Theme.of(context).colorScheme.primary;
    return DragTarget<String>(
      // One target over the whole body, not one per band: the overlap rules
      // above need a single place that knows both where the pointer is and
      // which band it last chose, and separate DragTargets would each only
      // know their own half of that.
      onWillAcceptWithDetails: (details) {
        _updateFrom(details.offset);
        return true;
      },
      onMove: (details) => _updateFrom(details.offset),
      onLeave: (_) => setState(() => _active = null),
      onAcceptWithDetails: (details) {
        final drop = _active;
        setState(() => _active = null);
        // The inert strip on the centre line, and nothing else: no band, no
        // guess, and somewhere for an abandoned drag to land.
        if (drop != null) widget.onDrop(details.data, drop);
      },
      builder: (context, candidates, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final shown = _active ?? _fading;
            final band = shown == null ? null : _bandOf(shown, size);
            return Stack(
              fit: StackFit.expand,
              children: [
                // Painted even when nothing is highlighted: a surface is what
                // routes pointer events over a native platform view (the map)
                // back to Flutter, so a body that painted nothing would take
                // no drops at all there.
                ColoredBox(color: accent.withValues(alpha: widget.washAlpha)),
                if (band != null)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 120),
                    curve: layoutAnimationCurve,
                    left: band.left,
                    top: band.top,
                    width: band.width,
                    height: band.height,
                    child: AnimatedOpacity(
                      opacity: _active == null ? 0 : 1,
                      duration: const Duration(milliseconds: 120),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.30),
                          border: Border.all(color: accent, width: 2),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// The drop target on ONE tab: dropping here puts the dragged module in this
/// group, at this tab's position — which is how a module joins a group of
/// tabs AND how the tabs within a group are reordered, since they are the
/// same act seen from two sides.
///
/// Which side of the tab the pointer is on decides whether the module lands
/// before or after it, and an insertion bar is drawn on that edge — the
/// answer to "where will it go" has to be visible before the drop, not
/// after.
class DockTabDropSlot extends StatefulWidget {
  final int index;

  /// Called with the module and the index it should occupy in the group.
  final void Function(String id, int index) onDrop;
  final Widget child;

  const DockTabDropSlot({super.key, required this.index, required this.onDrop, required this.child});

  @override
  State<DockTabDropSlot> createState() => _DockTabDropSlotState();
}

class _DockTabDropSlotState extends State<DockTabDropSlot> {
  /// Null when no drag is over this tab; otherwise the edge the module would
  /// land on.
  bool? _after;

  void _updateFrom(Offset globalOffset) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.isEmpty) return;
    final after = box.globalToLocal(globalOffset).dx > box.size.width / 2;
    if (after != _after) setState(() => _after = after);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.onPrimary;
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        _updateFrom(details.offset);
        return true;
      },
      onMove: (details) => _updateFrom(details.offset),
      onLeave: (_) => setState(() => _after = null),
      onAcceptWithDetails: (details) {
        final after = _after ?? false;
        setState(() => _after = null);
        widget.onDrop(details.data, after ? widget.index + 1 : widget.index);
      },
      builder: (context, candidates, _) => Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          PositionedDirectional(
            start: (_after ?? false) ? null : 0,
            end: (_after ?? false) ? 0 : null,
            top: 0,
            bottom: 0,
            // Always positioned, only its width animates: a bar that is
            // mounted and unmounted can't slide from one edge of the tab to
            // the other as the pointer crosses the middle.
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: layoutAnimationCurve,
              width: _after == null ? 0 : 3,
              color: primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Where a pane goes to be thrown away: a circle over the HOST app's own
/// window header, live only while something is being dragged.
///
/// Deleting is a DRAG destination rather than a button on the pane, and that
/// is the whole point of it — a control sitting on every pane is one an
/// operator can hit by accident while doing something else, and the thing it
/// destroys is a pane they had arranged and configured. Reaching this one
/// takes a deliberate journey with the pane already in hand — and a second
/// route, for a pointer that cannot make that journey, lives in the pane's
/// own layout options.
///
/// Bigger than a tap target and flush against the top edge, so a pane thrown
/// upwards lands on it: mid-drag the pointer is already busy, and a target
/// with a gap above it has to be aimed at.
class DockDeleteDropTarget extends StatelessWidget {
  final ValueChanged<String> onDrop;

  const DockDeleteDropTarget({super.key, required this.onDrop});

  /// Against the header's own height rather than a fixed number: this sits at
  /// the very top of the dock, right under that header, and the two read as
  /// one band.
  static const double _sizeFactor = 1.4;

  /// The circle's diameter in the dock's own coordinates. Shared with the
  /// arming rule, which is about this exact geometry — a constant beside it
  /// would be wrong at every density but one.
  static double diameterIn(BuildContext context) => LayoutDensity.chromeHeightOf(context) * _sizeFactor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = diameterIn(context);
    return DragTarget<String>(
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidates, _) {
        final armed = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: layoutAnimationCurve,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Solid once the pane is over it. Short of that it is a
            // suggestion, not the loudest thing on a screen the operator is
            // in the middle of rearranging.
            color: theme.colorScheme.error.withValues(alpha: armed ? 1.0 : 0.75),
            border: Border.all(color: theme.colorScheme.onError, width: armed ? 3 : 0),
          ),
          child: Icon(
            MdiIcons.trashCanOutline,
            color: theme.colorScheme.onError,
            size: size * 0.5,
            semanticLabel: MaterialLocalizations.of(context).deleteButtonTooltip,
          ),
        );
      },
    );
  }
}

/// A thin strip along the dock's own edge: dropping there makes the module a
/// new full-length pane on that side.
class DockEdgeDropTarget extends StatelessWidget {
  final DockRegion region;
  final ValueChanged<String> onDrop;

  const DockEdgeDropTarget({super.key, required this.region, required this.onDrop});

  @override
  Widget build(BuildContext context) {
    final tertiary = Theme.of(context).colorScheme.tertiary;
    return DragTarget<String>(
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidates, _) {
        final active = candidates.isNotEmpty;
        return Container(color: tertiary.withValues(alpha: active ? 0.45 : 0.10));
      },
    );
  }
}

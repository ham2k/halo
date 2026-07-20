// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// PROTOTYPE of the module-docking layout of DESIGN.md §7: a tree of splits
// whose leaves are tab groups of "modules" (the pane subtrees a view already
// builds — logging panel, map, spots…). Every tab doubles as a grab handle:
// dragging it over another group shows five drop regions (left / right / top
// / bottom / center-as-tab) plus thin strips along the dock's own edges, and
// dropping rearranges the tree. Dividers between siblings drag to resize.
//
// The layout is a plain JSON-serializable tree (see [DockNode.toJson]) so a
// view can persist it through SettingsService the way divider widths are
// persisted today. The view owns the module WIDGETS and passes them in each
// build; this widget only owns the arrangement. Modules stay mounted while
// hidden behind an unselected tab (IndexedStack), so in-progress input
// survives tab switches — but note this prototype does NOT yet carry the
// GlobalKey reparenting guarantees of docs/design/layouts.md rule 2 across
// arbitrary tree mutations (a module stays mounted through a drop because
// the caller keys it; the keep-alive bucket subtleties of TabBarView don't
// apply here).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'icon_resolver.dart';
import 'layout.dart';

/// A node in the dock tree: either a [DockSplit] (row/column of children
/// with weights) or a [DockGroup] (a tabbed stack of module ids).
sealed class DockNode {
  Map<String, dynamic> toJson();

  static DockNode? fromJson(Object? json) {
    if (json is! Map) return null;
    switch (json['type']) {
      case 'group':
        final modules = (json['modules'] as List?)?.whereType<String>().toList() ?? [];
        if (modules.isEmpty) return null;
        final selected = (json['selected'] as num?)?.toInt() ?? 0;
        return DockGroup(modules, selected: selected.clamp(0, modules.length - 1));
      case 'split':
        final children = (json['children'] as List?)?.map(DockNode.fromJson).whereType<DockNode>().toList() ?? [];
        if (children.isEmpty) return null;
        if (children.length == 1) return children.first;
        final weights = (json['weights'] as List?)?.whereType<num>().map((w) => w.toDouble()).toList();
        // Non-positive or non-finite weights (a corrupted or hand-edited
        // persisted spec) would produce NaN/negative pane extents — fall
        // back to equal shares rather than crash unrecoverably on launch.
        final valid = weights != null && weights.length == children.length && weights.every((w) => w.isFinite && w > 0);
        return DockSplit(
          json['axis'] == 'v' ? Axis.vertical : Axis.horizontal,
          children,
          valid ? weights : List.filled(children.length, 1),
        );
    }
    return null;
  }

  /// Every module id in this subtree, in visual order.
  List<String> collectModules() => switch (this) {
    DockGroup(:final modules) => List.of(modules),
    DockSplit(:final children) => [for (final c in children) ...c.collectModules()],
  };
}

/// A tabbed stack of modules. With a single module the header still shows
/// its one tab — that IS the grab handle for a standalone pane.
class DockGroup extends DockNode {
  final List<String> modules;
  int selected;

  DockGroup(this.modules, {this.selected = 0});

  @override
  Map<String, dynamic> toJson() => {'type': 'group', 'modules': modules, 'selected': selected};
}

/// A row (horizontal) or column (vertical) of children sized by [weights]
/// (arbitrary positive numbers, normalized at layout time).
class DockSplit extends DockNode {
  final Axis axis;
  final List<DockNode> children;
  final List<double> weights;

  DockSplit(this.axis, this.children, this.weights);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'split',
    'axis': axis == Axis.vertical ? 'v' : 'h',
    'children': [for (final c in children) c.toJson()],
    'weights': weights,
  };
}

/// Where a drag lands relative to a target group (or the dock's own edges).
enum DockRegion { left, right, top, bottom, center }

class DockLayoutView extends StatefulWidget {
  /// The starting arrangement. The view owns mutations from then on,
  /// reporting each through [onSpecChanged]; later changes to this field are
  /// ignored (rebuild with a new [Key] to force a reset).
  final DockNode initialSpec;

  /// Module id → tab label.
  final Map<String, String> titles;

  /// Module id → the (caller-keyed) pane widget. Read fresh every build so
  /// the panes get their latest props; must cover every id in the spec.
  final Map<String, Widget> children;

  final ValueChanged<DockNode>? onSpecChanged;

  const DockLayoutView({
    super.key,
    required this.initialSpec,
    required this.titles,
    required this.children,
    this.onSpecChanged,
  });

  /// True when [spec]'s modules are exactly [moduleIds] — the guard a view
  /// uses before trusting a persisted spec (a module renamed or added since
  /// it was saved falls back to the view's default arrangement).
  static bool specMatches(DockNode? spec, Iterable<String> moduleIds) {
    if (spec == null) return false;
    final inSpec = spec.collectModules();
    return inSpec.length == inSpec.toSet().length &&
        inSpec.toSet().containsAll(moduleIds) &&
        moduleIds.toSet().containsAll(inSpec);
  }

  @override
  State<DockLayoutView> createState() => DockLayoutViewState();
}

/// Public so a view can hold a `GlobalKey<DockLayoutViewState>` and call
/// [revealModule] — the dock-mode equivalent of the fixed layout's
/// programmatic `TabController.animateTo` (surfacing command output, a
/// tapped spot's logging pane, the call-info detail).
class DockLayoutViewState extends State<DockLayoutView> {
  late DockNode _spec = widget.initialSpec;

  /// The module id being dragged, or null — gates the drop-region overlays.
  String? _dragging;

  static const double _dividerExtent = 7.0;
  static const double _headerHeight = 40.0;
  static const double _minPaneExtent = 120.0;

  /// Same trick as ResizableSplitView._platformViewHitWashAlpha: a painted
  /// (near-invisible) surface is what routes pointer events over a native
  /// platform view (the map) back to Flutter, so drop targets sitting on the
  /// map must paint SOMETHING to receive the drop.
  static const double _hitWashAlpha = 0.004;

  void _emit() => widget.onSpecChanged?.call(_spec);

  /// Selects the tab of the group containing [id], surfacing that module.
  /// No-op when the module isn't in the layout. Not persisted — a reveal is
  /// programmatic, not a user arrangement choice.
  void revealModule(String id) {
    bool select(DockNode node) => switch (node) {
      DockGroup() => node.modules.contains(id) && (node.selected = node.modules.indexOf(id)) >= 0,
      DockSplit() => node.children.any(select),
    };
    setState(() => select(_spec));
  }

  // --- tree mutations -----------------------------------------------------

  /// Removes [id] wherever it lives, pruning empty groups and collapsing
  /// single-child splits. Returns the replacement subtree (null when the
  /// whole subtree vanished).
  DockNode? _removed(DockNode node, String id) {
    switch (node) {
      case DockGroup():
        final index = node.modules.indexOf(id);
        if (index >= 0) {
          node.modules.removeAt(index);
          if (node.modules.isEmpty) return null;
          node.selected = node.selected.clamp(0, node.modules.length - 1);
        }
        return node;
      case DockSplit():
        for (var i = node.children.length - 1; i >= 0; i--) {
          final replacement = _removed(node.children[i], id);
          if (replacement == null) {
            node.children.removeAt(i);
            node.weights.removeAt(i);
          } else {
            node.children[i] = replacement;
          }
        }
        if (node.children.isEmpty) return null;
        if (node.children.length == 1) return node.children.first;
        return node;
    }
  }

  DockSplit? _parentOf(DockNode node, DockNode child) {
    if (node is! DockSplit) return null;
    for (final c in node.children) {
      if (identical(c, child)) return node;
      final found = _parentOf(c, child);
      if (found != null) return found;
    }
    return null;
  }

  void _handleDrop(String id, DockGroup target, DockRegion region) {
    setState(() {
      if (region == DockRegion.center) {
        final existing = target.modules.indexOf(id);
        if (existing >= 0) {
          target.selected = existing; // already here — just show it
          return;
        }
        _spec = _removed(_spec, id) ?? DockGroup([id]);
        target.modules.add(id);
        target.selected = target.modules.length - 1;
        return;
      }
      // A side drop of a group's sole module beside itself is a no-op.
      if (target.modules.length == 1 && target.modules.single == id) return;
      _spec = _removed(_spec, id) ?? DockGroup([id]);
      final fresh = DockGroup([id]);
      final axis = (region == DockRegion.left || region == DockRegion.right) ? Axis.horizontal : Axis.vertical;
      final before = region == DockRegion.left || region == DockRegion.top;
      final parent = _parentOf(_spec, target);
      if (parent != null && parent.axis == axis) {
        // Split the target's share with the newcomer instead of re-weighting
        // the whole row.
        final i = parent.children.indexWhere((c) => identical(c, target));
        parent.weights[i] = parent.weights[i] / 2;
        parent.children.insert(before ? i : i + 1, fresh);
        parent.weights.insert(before ? i : i + 1, parent.weights[i]);
      } else {
        final split = DockSplit(axis, before ? [fresh, target] : [target, fresh], [1, 1]);
        if (parent == null) {
          _spec = identical(_spec, target) ? split : _spec;
        } else {
          final i = parent.children.indexWhere((c) => identical(c, target));
          parent.children[i] = split;
        }
      }
    });
    _emit();
  }

  /// A drop on the dock's own edge strip: the module becomes a new
  /// quarter-ish pane along that whole edge.
  void _handleEdgeDrop(String id, DockRegion region) {
    setState(() {
      final spec = _spec;
      if (spec is DockGroup && spec.modules.length == 1 && spec.modules.single == id) return;
      final root = _removed(_spec, id) ?? DockGroup([id]);
      final fresh = DockGroup([id]);
      final axis = (region == DockRegion.left || region == DockRegion.right) ? Axis.horizontal : Axis.vertical;
      final before = region == DockRegion.left || region == DockRegion.top;
      if (root is DockSplit && root.axis == axis) {
        final share = root.weights.reduce((a, b) => a + b) / root.weights.length / 2;
        root.children.insert(before ? 0 : root.children.length, fresh);
        root.weights.insert(before ? 0 : root.weights.length, share);
        _spec = root;
      } else {
        _spec = DockSplit(axis, before ? [fresh, root] : [root, fresh], before ? [1, 3] : [3, 1]);
      }
    });
    _emit();
  }

  // --- rendering ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildNode(_spec),
        // The dock's own edge strips, live only mid-drag.
        if (_dragging != null)
          for (final region in const [DockRegion.left, DockRegion.right, DockRegion.top, DockRegion.bottom])
            _positionedEdge(region, _EdgeDropTarget(region: region, onDrop: (id) => _handleEdgeDrop(id, region))),
      ],
    );
  }

  Widget _positionedEdge(DockRegion region, Widget child) {
    const extent = 20.0;
    return switch (region) {
      DockRegion.left => Positioned(left: 0, top: 0, bottom: 0, width: extent, child: child),
      DockRegion.right => Positioned(right: 0, top: 0, bottom: 0, width: extent, child: child),
      DockRegion.top => Positioned(left: 0, right: 0, top: 0, height: extent, child: child),
      DockRegion.bottom => Positioned(left: 0, right: 0, bottom: 0, height: extent, child: child),
      DockRegion.center => throw ArgumentError('center is not an edge'),
    };
  }

  Widget _buildNode(DockNode node) => switch (node) {
    DockGroup() => _buildGroup(node),
    DockSplit() => _buildSplit(node),
  };

  Widget _buildSplit(DockSplit split) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = split.axis == Axis.horizontal;
        final total = horizontal ? constraints.maxWidth : constraints.maxHeight;
        // Floored at zero: a window smaller than the dividers alone must
        // degrade to zero-extent panes, not negative SizedBox widths.
        final available = math.max(0.0, total - _dividerExtent * (split.children.length - 1));
        final weightSum = split.weights.reduce((a, b) => a + b);
        final extents = [for (final w in split.weights) available * w / weightSum];
        final children = <Widget>[];
        for (var i = 0; i < split.children.length; i++) {
          if (i > 0) {
            children.add(
              _DockDivider(
                axis: split.axis,
                onDrag: (delta) => setState(() {
                  if (available <= 0) return;
                  // Move the boundary between i-1 and i, keeping both panes
                  // usable; weights shift by the dragged fraction of the run.
                  // Bounds via max/min, not clamp(): a pane ALREADY below the
                  // minimum (persisted weights in a smaller window) inverts
                  // clamp's limits, which throws — max/min just refuse to
                  // shrink it further.
                  final deltaWeight = delta / available * weightSum;
                  final lower = _minPaneExtent / available * weightSum;
                  final maxGive = math.max(0.0, split.weights[i - 1] - lower);
                  final maxTake = math.max(0.0, split.weights[i] - lower);
                  final shift = math.min(maxTake, math.max(-maxGive, deltaWeight));
                  split.weights[i - 1] += shift;
                  split.weights[i] -= shift;
                }),
                onDragEnd: _emit,
              ),
            );
          }
          children.add(
            SizedBox(
              width: horizontal ? extents[i] : null,
              height: horizontal ? null : extents[i],
              child: _buildNode(split.children[i]),
            ),
          );
        }
        return horizontal
            ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
      },
    );
  }

  Widget _buildGroup(DockGroup group) {
    final theme = Theme.of(context);
    final headerColor = theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: headerColor,
          child: SizedBox(
            height: _headerHeight,
            // Scrollable so many tabs in a narrow pane clip gracefully
            // instead of overflowing (scroll-wheel reachable; tab drags win
            // the gesture arena over the scroll view, which is fine — the
            // strip is primarily tapped, and it usually fits).
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < group.modules.length; i++)
                    _DockTab(
                      title: widget.titles[group.modules[i]] ?? group.modules[i],
                      selected: i == group.selected,
                      showHandle: group.modules.length == 1 || i == group.selected,
                      // Selection is part of the persisted spec (toJson carries
                      // it), so a tap must emit like a drop does — otherwise
                      // the saved arrangement reopens on a stale tab.
                      onTap: () {
                        setState(() => group.selected = i);
                        _emit();
                      },
                      moduleId: group.modules[i],
                      onDragStarted: (id) => setState(() => _dragging = id),
                      onDragEnded: () => setState(() => _dragging = null),
                    ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              IndexedStack(
                // Tight constraints, like a TabBarView page — panes are
                // designed to fill their pane, not shrink-wrap.
                sizing: StackFit.expand,
                index: group.selected,
                children: [for (final id in group.modules) widget.children[id] ?? const SizedBox.shrink()],
              ),
              if (_dragging != null)
                _GroupDropRegions(washAlpha: _hitWashAlpha, onDrop: (id, region) => _handleDrop(id, group, region)),
            ],
          ),
        ),
      ],
    );
  }
}

/// One tab in a group header: tap to select, drag to move the module. The
/// drag-indicator dots mark it as a handle.
class _DockTab extends StatelessWidget {
  final String title;
  final bool selected;
  final bool showHandle;
  final VoidCallback onTap;
  final String moduleId;
  final ValueChanged<String> onDragStarted;
  final VoidCallback onDragEnded;

  const _DockTab({
    required this.title,
    required this.selected,
    required this.showHandle,
    required this.onTap,
    required this.moduleId,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tabTheme = theme.tabBarTheme;
    final labelColor = (selected ? tabTheme.labelColor : tabTheme.unselectedLabelColor) ?? theme.colorScheme.onPrimary;
    final label = Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: selected ? (tabTheme.indicatorColor ?? labelColor) : Colors.transparent, width: 3),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(resolveIconName('drag-vertical'), size: 16, color: labelColor.withValues(alpha: 0.6)),
            ),
          Text(title, style: theme.textTheme.titleSmall?.copyWith(color: labelColor)),
        ],
      ),
    );
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: Draggable<String>(
        data: moduleId,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        onDragStarted: () => onDragStarted(moduleId),
        onDragEnd: (_) => onDragEnded(),
        onDraggableCanceled: (_, _) => onDragEnded(),
        feedback: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(6),
          color: theme.colorScheme.primary,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onPrimary)),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: label),
        child: InkWell(onTap: onTap, child: label),
      ),
    );
  }
}

/// The five drop regions overlaid on a group's body while a drag is live.
class _GroupDropRegions extends StatelessWidget {
  final double washAlpha;
  final void Function(String id, DockRegion region) onDrop;

  const _GroupDropRegions({required this.washAlpha, required this.onDrop});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideW = (constraints.maxWidth * 0.25).clamp(32.0, 140.0);
        final sideH = (constraints.maxHeight * 0.25).clamp(32.0, 140.0);
        Widget target(DockRegion region) =>
            _RegionDropTarget(region: region, washAlpha: washAlpha, onDrop: (id) => onDrop(id, region));
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(left: sideW, right: sideW, top: sideH, bottom: sideH, child: target(DockRegion.center)),
            Positioned(left: 0, top: 0, bottom: 0, width: sideW, child: target(DockRegion.left)),
            Positioned(right: 0, top: 0, bottom: 0, width: sideW, child: target(DockRegion.right)),
            Positioned(left: sideW, right: sideW, top: 0, height: sideH, child: target(DockRegion.top)),
            Positioned(left: sideW, right: sideW, bottom: 0, height: sideH, child: target(DockRegion.bottom)),
          ],
        );
      },
    );
  }
}

class _RegionDropTarget extends StatelessWidget {
  final DockRegion region;
  final double washAlpha;
  final ValueChanged<String> onDrop;

  const _RegionDropTarget({required this.region, required this.washAlpha, required this.onDrop});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return DragTarget<String>(
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidates, _) {
        final active = candidates.isNotEmpty;
        // Painted even when inactive (the wash) so the drop registers over
        // native platform views like the map.
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: layoutAnimationCurve,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: active ? 0.30 : washAlpha),
            border: active ? Border.all(color: primary, width: 2) : null,
            borderRadius: region == DockRegion.center ? BorderRadius.circular(8) : null,
          ),
          child: active && region == DockRegion.center
              ? Center(child: Icon(resolveIconName('tab-plus'), color: primary, size: 32))
              : null,
        );
      },
    );
  }
}

/// A thin strip along the dock's own edge: dropping there makes the module a
/// new full-length pane on that side.
class _EdgeDropTarget extends StatelessWidget {
  final DockRegion region;
  final ValueChanged<String> onDrop;

  const _EdgeDropTarget({required this.region, required this.onDrop});

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

/// The draggable boundary between two split siblings — a visible hairline
/// centered in a slim grab strip (unlike ResizableSplitView's overlay
/// divider, these own layout space: an N-way split has no single "secondary"
/// pane to overlay).
class _DockDivider extends StatelessWidget {
  final Axis axis;

  /// Delta along the split's main axis, in logical pixels.
  final ValueChanged<double> onDrag;
  final VoidCallback onDragEnd;

  const _DockDivider({required this.axis, required this.onDrag, required this.onDragEnd});

  @override
  Widget build(BuildContext context) {
    final horizontal = axis == Axis.horizontal;
    final line = Center(
      child: Container(
        width: horizontal ? 1 : null,
        height: horizontal ? null : 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
    return MouseRegion(
      cursor: horizontal ? SystemMouseCursors.resizeLeftRight : SystemMouseCursors.resizeUpDown,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: horizontal ? (d) => onDrag(d.delta.dx) : null,
        onHorizontalDragEnd: horizontal ? (_) => onDragEnd() : null,
        onVerticalDragUpdate: horizontal ? null : (d) => onDrag(d.delta.dy),
        onVerticalDragEnd: horizontal ? null : (_) => onDragEnd(),
        child: SizedBox(
          width: horizontal ? DockLayoutViewState._dividerExtent : null,
          height: horizontal ? null : DockLayoutViewState._dividerExtent,
          child: line,
        ),
      ),
    );
  }
}

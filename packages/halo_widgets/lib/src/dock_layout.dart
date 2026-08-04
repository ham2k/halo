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

import 'layout.dart';
import 'mdi_icons.g.dart';
import 'pane_divider.dart';
import 'resizable_split_view.dart' show PaneSafeArea;
import 'tab_chrome.dart';
import 'ui_scale.dart';

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

  /// Module id → a trailing widget for that module's group header — shown
  /// at the header's right edge, and only when the module is the group's
  /// selected tab (so a solo module's trailing widget is always visible,
  /// and one sharing a group with others only shows when it's the active
  /// tab). Absent ids show nothing.
  final Map<String, WidgetBuilder>? tabActions;

  final ValueChanged<DockNode>? onSpecChanged;

  const DockLayoutView({
    super.key,
    required this.initialSpec,
    required this.titles,
    required this.children,
    this.tabActions,
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

  // Dock splits use the shared solid divider (pane_divider.dart) — same
  // header-colored bar as ResizableSplitView's default style.
  static const double _dividerExtent = paneDividerWidth;
  // kMinInteractiveDimension (48), not an arbitrary compact height: a
  // shorter header squeezes any IconButton placed in it (e.g. a module's
  // tabActions trailing widget) below Material's own minimum tap target,
  // silently shrinking it — matches kTextTabBarHeight, which the narrow
  // tab bar and the fixed split's title bar both already use for the same
  // reason.
  static const double _headerHeight = kMinInteractiveDimension;
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
        // Weights give fractional extents; laying panes out at those puts
        // every boundary after the first one between device pixels, where it
        // antialiases against its neighbor and reads as a hairline gap. Walk
        // the run cumulatively instead and snap each BOUNDARY (a pane extent
        // snapped on its own still starts off-grid if the pane before it did),
        // taking each element's extent as the difference between its two
        // snapped edges. `flat` interleaves pane and divider extents:
        // pane i is at 2i, the divider before it at 2i-1.
        final grid = PixelGrid.of(context);
        final flat = <double>[];
        for (var i = 0; i < split.children.length; i++) {
          if (i > 0) flat.add(_dividerExtent);
          flat.add(available * split.weights[i] / weightSum);
        }
        var edge = 0.0;
        var snappedEdge = 0.0;
        for (var j = 0; j < flat.length; j++) {
          edge += flat[j];
          // The run's own trailing edge stays exactly `total`: if this dock
          // sits inside something that is itself off-grid, snapping the last
          // edge can't fix that and would only open a real gap at the end.
          // Intermediate edges are capped at `total` for the same reason in
          // reverse — with an off-grid `total` (a vertical split's body height
          // is the window minus a 56pt AppBar, fractional at several scales) a
          // sub-device-pixel last pane lets snap() round the edge BEFORE it
          // past the end, and the children would then overflow the run.
          final next = j == flat.length - 1 ? total : math.min(total, grid.snap(edge));
          flat[j] = math.max(0.0, next - snappedEdge);
          snappedEdge = next;
        }
        // The ambient value this split sits inside. Only the child at the
        // split's own leading/trailing edge, on the split's OWN axis, is at
        // a physical screen edge — an interior child (between two others)
        // touches no device edge on that axis and reads 0 there. The
        // cross-axis isn't divided by this split, so it passes through to
        // every child unchanged.
        final ambient = PaneSafeArea.maybeOf(context);
        final ambientLeft = ambient?.left ?? 0;
        final ambientTop = ambient?.top ?? 0;
        final ambientRight = ambient?.right ?? 0;
        final ambientBottom = ambient?.bottom ?? 0;
        final children = <Widget>[];
        for (var i = 0; i < split.children.length; i++) {
          if (i > 0) {
            children.add(
              SolidPaneDivider(
                axis: split.axis,
                extent: flat[2 * i - 1],
                onDragUpdate: (delta) => setState(() {
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
                // Weights were mutated live during the drag — a cancelled
                // gesture (pointer lost to another recognizer) must persist
                // what's on screen too, or the layout silently reverts on
                // relaunch.
                onDragCancel: _emit,
              ),
            );
          }
          final isFirst = i == 0;
          final isLast = i == split.children.length - 1;
          children.add(
            SizedBox(
              width: horizontal ? flat[2 * i] : null,
              height: horizontal ? null : flat[2 * i],
              child: PaneSafeArea(
                left: horizontal ? (isFirst ? ambientLeft : 0) : ambientLeft,
                top: horizontal ? ambientTop : (isFirst ? ambientTop : 0),
                right: horizontal ? (isLast ? ambientRight : 0) : ambientRight,
                bottom: horizontal ? ambientBottom : (isLast ? ambientBottom : 0),
                child: _buildNode(split.children[i]),
              ),
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
            // Snapped: the header's color meets the pane body at this edge,
            // and _headerHeight × the grid is fractional at some scale/DPR
            // combinations (40 × 0.85 × 2.75), which seams the two.
            height: PixelGrid.of(context).snap(_headerHeight),
            // A Builder, not this method's own `context`: `_buildGroup` is a
            // plain Dart call from `_buildSplit`/`_buildNode`, not a fresh
            // Element — reusing `State.context` here would always resolve
            // PaneSafeArea against DockLayoutView's OWN outer ambient,
            // ignoring the position-correct value `_buildSplit` wrapped THIS
            // child in. Builder gets a context at this group's real tree
            // position.
            child: Builder(
              builder: (context) {
                final selectedModule = group.modules[group.selected];
                final trailing = widget.tabActions?[selectedModule]?.call(context);
                return Padding(
                  padding: EdgeInsets.only(left: PaneSafeArea.leftOf(context), right: PaneSafeArea.rightOf(context)),
                  child: Row(
                    children: [
                      Expanded(
                        // Scrollable so many tabs in a narrow pane clip
                        // gracefully instead of overflowing (scroll-wheel
                        // reachable; tab drags win the gesture arena over the
                        // scroll view, which is fine — the strip is primarily
                        // tapped, and it usually fits).
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (var i = 0; i < group.modules.length; i++)
                                _DockTab(
                                  title: widget.titles[group.modules[i]] ?? group.modules[i],
                                  selected: i == group.selected,
                                  showHandle: group.modules.length == 1 || i == group.selected,
                                  // Selection is part of the persisted spec
                                  // (toJson carries it), so a tap must emit
                                  // like a drop does — otherwise the saved
                                  // arrangement reopens on a stale tab.
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
                      if (trailing != null) trailing,
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // No local PaneSafeArea wrap here: this group's content
              // inherits whatever ambient value _buildSplit (or this dock's
              // own outer ancestor, for a lone root group) already
              // established — re-wrapping with a hardcoded value would
              // shadow it (InheritedWidget lookup finds only the nearest
              // ancestor).
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

  Widget _labelRow(Color labelColor, {required TextStyle? style}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (showHandle)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(MdiIcons.dragVertical, size: 16, color: labelColor.withValues(alpha: 0.6)),
        ),
      Text(title, style: style?.copyWith(color: labelColor)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tabTheme = theme.tabBarTheme;
    // Only used for the drag ghost below — the live tab's own label color
    // comes from TabChrome, which resolves the same way.
    final ghostLabelColor = (selected ? tabTheme.labelColor : tabTheme.unselectedLabelColor) ?? theme.colorScheme.onPrimary;
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
        // Not TabChrome here: while its counterpart is being dragged
        // elsewhere, this dimmed placeholder shouldn't itself be tappable
        // or announced as a tab.
        childWhenDragging: Opacity(
          opacity: 0.35,
          child: Container(
            decoration: TabChrome.indicatorDecoration(selected: selected, labelColor: ghostLabelColor, tabTheme: tabTheme),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            child: _labelRow(ghostLabelColor, style: theme.textTheme.titleSmall),
          ),
        ),
        child: TabChrome(
          selected: selected,
          semanticLabel: title,
          onTap: onTap,
          builder: (context, labelColor) => _labelRow(labelColor, style: Theme.of(context).textTheme.titleSmall),
        ),
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
              ? Center(child: Icon(MdiIcons.tabPlus, color: primary, size: 32))
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


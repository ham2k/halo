// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// PROTOTYPE of the module-docking layout of DESIGN.md §7: a tree of splits
// whose leaves are tab groups of "modules" (the pane subtrees a view already
// builds — logging panel, map, spots…). Every tab doubles as a grab handle.
// Dragging one shows where it can land: on another group's TAB STRIP, at the
// position under the pointer (which both joins a group and reorders within
// one), on that group's body in a top/bottom/left/right band that splits it,
// or on a thin strip along the dock's own edge for a new full-length pane.
// Dividers between siblings drag to resize.
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

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import 'density.dart';
import 'layout.dart';
import 'mdi_icons.g.dart';
import 'pane_divider.dart';
import 'spacing.dart';
import 'resizable_split_view.dart' show PaneSafeArea;
import 'tab_chrome.dart';
import 'ui_scale.dart';

/// A node in the dock tree: either a [DockSplit] (row/column of children
/// with weights) or a [DockGroup] (a tabbed stack of module ids).
///
/// This is the dock's **definition** — what panes exist and how they are
/// arranged — and nothing else. Which tab is on top is [DockState], stored
/// apart from it. The split is load-bearing rather than tidy: while
/// selection lived in here, tapping a tab was an edit to the arrangement,
/// so merely looking at another pane rewrote the operator's saved layout.
sealed class DockNode {
  Map<String, dynamic> toJson();

  static DockNode? fromJson(Object? json) {
    if (json is! Map) return null;
    switch (json['type']) {
      case 'group':
        final modules = (json['modules'] as List?)?.whereType<String>().toList() ?? [];
        if (modules.isEmpty) return null;
        // `selected` is deliberately NOT read, though older saved
        // definitions still carry one: it is state, and state has its own
        // store now. A definition written before the split simply opens on
        // its first tab once, and stops carrying the field when next saved.
        return DockGroup(modules);
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
  Map<String, dynamic> toJson() => {'type': 'group', 'modules': modules};
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

/// What the operator has done to a dock arrangement without changing it:
/// which pane is on top of each group, and (later) which collapsible panes
/// are hidden. Kept apart from [DockNode] so that touching state is never a
/// write to the definition.
///
/// Keyed by **module id**, not by a group's position or a generated node id:
/// `selected` is simply the set of modules that are on top of whatever group
/// holds them. A group holding none of them shows its first, which is also
/// the default for a group nobody has touched. That survives rearranging the
/// dock — moving a pane to another group carries its selectedness with it —
/// and needs no migration when the tree's shape changes underneath.
class DockState {
  final Set<String> selected;

  const DockState({this.selected = const {}});

  static const empty = DockState();

  bool get isEmpty => selected.isEmpty;

  Map<String, dynamic> toJson() => {'selected': selected.toList()};

  static DockState fromJson(Object? json) {
    if (json is! Map) return empty;
    return DockState(selected: {...?(json['selected'] as List?)?.whereType<String>()});
  }

  /// The state a live tree is currently in.
  factory DockState.of(DockNode node) => DockState(selected: _selectedIn(node).toSet());

  static Iterable<String> _selectedIn(DockNode node) sync* {
    switch (node) {
      case DockGroup(:final modules, :final selected):
        if (modules.isNotEmpty) yield modules[selected.clamp(0, modules.length - 1)];
      case DockSplit(:final children):
        for (final child in children) {
          yield* _selectedIn(child);
        }
    }
  }

  /// Puts each group's remembered module on top, in place. A group this
  /// state says nothing about is LEFT ALONE rather than reset — a definition
  /// parsed from JSON already opens on its first tab, and forcing that here
  /// would also overrule a caller that built a tree with a selection of its
  /// own.
  void applyTo(DockNode node) {
    switch (node) {
      case DockGroup(:final modules):
        final index = modules.indexWhere(selected.contains);
        if (index >= 0) node.selected = index;
      case DockSplit(:final children):
        for (final child in children) {
          applyTo(child);
        }
    }
  }

  @override
  bool operator ==(Object other) => other is DockState && setEquals(other.selected, selected);

  @override
  int get hashCode => Object.hashAllUnordered(selected);
}

/// Whether the pane reading this is the one on top of its tab group. Every
/// pane in a group stays MOUNTED (the group is an IndexedStack, so a
/// half-typed field survives a tab switch), which means a pane that costs
/// something to keep current — an extension panel crossing the JS bridge —
/// has no other way to know nobody is looking at it.
///
/// Absent means visible: a pane outside a dock (the fixed layouts, a test)
/// is on screen whenever it is built.
class DockPaneVisibility extends InheritedWidget {
  final bool visible;

  const DockPaneVisibility({super.key, required this.visible, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DockPaneVisibility>()?.visible ?? true;

  /// The value WITHOUT registering a dependency, for a caller that already
  /// depends on it through [of] and needs it mid-frame — `didUpdateWidget`
  /// runs BEFORE `didChangeDependencies` when a widget and its inherited
  /// ancestors both change in one pump, so a State reading its own cached
  /// copy there is reading the previous frame's answer.
  static bool readOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<DockPaneVisibility>()?.visible ?? true;

  @override
  bool updateShouldNotify(DockPaneVisibility oldWidget) => oldWidget.visible != visible;
}

/// Which side of a target group (or of the dock itself) a drag lands on.
/// Joining a group as a TAB is not a region: it happens on the tab strip and
/// carries the position within the group, which a region can't say.
enum DockRegion { left, right, top, bottom }

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

  /// Module id → a trailing widget for that module's own TAB — shown at the
  /// tab's trailing edge, and only while the module is the group's selected
  /// tab (so a solo module's action is always visible, and one sharing a
  /// group with others only shows when it's the active tab). Absent ids show
  /// nothing, and cost nothing: only a module that HAS an action reserves
  /// the room for one.
  ///
  /// It belongs to the tab rather than the header because a group's header
  /// is entirely tabs — an action parked at the header's own right edge
  /// reads as belonging to the group, not to the one module it acts on.
  final Map<String, WidgetBuilder>? tabActions;

  /// Fires when the ARRANGEMENT changes — a pane added, removed, moved or
  /// resized. Never for a tab tap: see [onStateChanged].
  final ValueChanged<DockNode>? onSpecChanged;

  /// The state to open in. Like [initialSpec], read once.
  final DockState initialState;

  /// Fires when which pane is on top changes, which is emphatically not an
  /// edit to the arrangement — the operator looking at another tab must not
  /// rewrite their saved layout.
  final ValueChanged<DockState>? onStateChanged;

  const DockLayoutView({
    super.key,
    required this.initialSpec,
    required this.titles,
    required this.children,
    this.tabActions,
    this.onSpecChanged,
    this.initialState = DockState.empty,
    this.onStateChanged,
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
class DockLayoutViewState extends State<DockLayoutView> with SingleTickerProviderStateMixin {
  late DockNode _spec = widget.initialSpec;

  /// Drives a just-dropped pane from nothing to its share, so the layout is
  /// seen to rearrange rather than jumping to a new arrangement the operator
  /// then has to re-read. An explicit controller, not an implicit animation:
  /// a drop restructures the children list, and an implicit animation would
  /// be interpolating from whatever pane happened to hold that slot before.
  /// Built in [initState], not lazily: a `late final` initializer would be
  /// run BY `dispose()` on a dock that never saw a drop, and creating a
  /// ticker while the element is being unmounted throws.
  late final AnimationController _growth;

  /// The split holding the pane being grown, and its index in it.
  DockSplit? _growingSplit;
  int _growingIndex = 0;

  @override
  void initState() {
    super.initState();
    // The tree arrives as a pure definition — every group on its first tab —
    // and the remembered state is laid over it here.
    widget.initialState.applyTo(_spec);
    _growth = AnimationController(vsync: this, duration: layoutAnimationDuration)
      ..addListener(() {
        if (mounted) setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) setState(() => _growingSplit = null);
      });
  }

  void _growPane(DockSplit split, int index) {
    _growingSplit = split;
    _growingIndex = index;
    _growth.forward(from: 0);
  }

  @override
  void dispose() {
    _growth.dispose();
    super.dispose();
  }

  /// The module id being dragged, or null — gates the drop-region overlays.
  String? _dragging;

  // Dock splits use the shared solid divider (pane_divider.dart) — same
  // header-colored bar as ResizableSplitView's default style.
  static const double _dividerExtent = paneDividerWidth;
  static const double _minPaneExtent = 120.0;

  /// Publishes a pane's own density when it is genuinely shorter than what it
  /// inherited — a vertical split halves the height without the window
  /// changing at all, and a pane spending the window's room it does not have
  /// is the case `LayoutDensityScope.forHeight` exists for. It only ever
  /// tightens: a tall pane cannot buy back room the window lacks.
  static Widget _densityForPane({required double? height, required Widget child}) =>
      height == null ? child : LayoutDensityScope.forHeight(height: height, child: child);

  /// Same trick as ResizableSplitView._platformViewHitWashAlpha: a painted
  /// (near-invisible) surface is what routes pointer events over a native
  /// platform view (the map) back to Flutter, so drop targets sitting on the
  /// map must paint SOMETHING to receive the drop.
  static const double _hitWashAlpha = 0.004;

  void _emit() {
    widget.onSpecChanged?.call(_spec);
    // An arrangement change moves panes between groups, so what is on top
    // can change without anyone tapping a tab.
    _emitState();
  }

  void _emitState() => widget.onStateChanged?.call(DockState.of(_spec));

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

  /// Every module in the layout, in visual order — what a layout editor
  /// lists. Read from the LIVE tree, not the caller's `initialSpec`, which
  /// stopped being the arrangement the moment the user moved anything.
  List<String> get modules => _spec.collectModules();

  /// What the dock is showing on top of each group right now — the same
  /// value [DockLayoutView.onStateChanged] reports. Exposed so a test can
  /// assert on the SELECTION: a tab's label is in the tree whether or not it
  /// is the selected one, so asserting on the label proves nothing.
  @visibleForTesting
  DockState get currentState => DockState.of(_spec);

  /// Drops [id] out of the layout entirely, pruning whatever it leaves empty.
  /// Refuses to remove the last module — a dock with nothing in it has no
  /// tab left to drag anything back with, so the layout would be
  /// unrecoverable from inside the view.
  ///
  /// Reported through `onSpecChanged` like any other arrangement change:
  /// removing a pane is a user choice that must survive a relaunch.
  bool removeModule(String id) {
    if (!_spec.collectModules().contains(id) || _spec.collectModules().length <= 1) return false;
    setState(() => _spec = _removed(_spec, id)!);
    _emit();
    return true;
  }

  /// Brings [id] into the layout as a tab of the LAST group in visual order,
  /// selected — the far side of the dock from the primary pane, which is
  /// where a tabbed group normally lives and where a returning pane is least
  /// likely to displace what the operator is working in. Already-present
  /// modules are revealed instead of duplicated.
  void addModule(String id) {
    if (_spec.collectModules().contains(id)) {
      revealModule(id);
      return;
    }
    DockGroup lastGroup(DockNode node) => switch (node) {
      DockGroup() => node,
      DockSplit() => lastGroup(node.children.last),
    };
    setState(() {
      final group = lastGroup(_spec);
      group.modules.add(id);
      group.selected = group.modules.length - 1;
    });
    _emit();
  }

  /// Replaces the whole arrangement — how a view restores its default
  /// layout, or installs one it could only resolve after this mounted, since
  /// [DockLayoutView.initialSpec] is read only once.
  ///
  /// [emit] false for the latter: reporting a restored arrangement back out
  /// would persist it as though the operator had just chosen it.
  void replaceSpec(DockNode spec, {bool emit = true}) {
    setState(() => _spec = spec);
    if (emit) _emit();
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

  /// A dropped pane takes the share of the band it was dropped on — the
  /// bands are thirds, so the newcomer arrives at the size the operator was
  /// looking at when they let go, rather than at half the target and then
  /// needing a divider drag to become what the target promised.
  static const _newPaneShare = 1 / 3;

  void _handleDrop(String id, DockGroup target, DockRegion region) {
    setState(() {
      // A side drop of a group's sole module beside itself is a no-op.
      if (target.modules.length == 1 && target.modules.single == id) return;
      _spec = _removed(_spec, id) ?? DockGroup([id]);
      final fresh = DockGroup([id]);
      final axis = (region == DockRegion.left || region == DockRegion.right) ? Axis.horizontal : Axis.vertical;
      final before = region == DockRegion.left || region == DockRegion.top;
      final parent = _parentOf(_spec, target);
      if (parent != null && parent.axis == axis) {
        // The newcomer takes its share OUT OF THE TARGET rather than out of
        // the whole row: the panes either side of the target are not part of
        // what was dropped on and must not move.
        final i = parent.children.indexWhere((c) => identical(c, target));
        final share = parent.weights[i];
        parent.weights[i] = share * (1 - _newPaneShare);
        final at = before ? i : i + 1;
        parent.children.insert(at, fresh);
        parent.weights.insert(at, share * _newPaneShare);
        _growPane(parent, at);
      } else {
        final weights = before
            ? [_newPaneShare, 1 - _newPaneShare]
            : [1 - _newPaneShare, _newPaneShare];
        final split = DockSplit(axis, before ? [fresh, target] : [target, fresh], weights);
        if (parent == null) {
          _spec = identical(_spec, target) ? split : _spec;
        } else {
          final i = parent.children.indexWhere((c) => identical(c, target));
          parent.children[i] = split;
        }
        _growPane(split, before ? 0 : 1);
      }
    });
    _emit();
  }

  /// A drop on [target]'s tab strip: the module takes position [insertIndex]
  /// among that group's tabs, and is selected — a module that lands behind
  /// an unselected tab looks like a drop that did nothing.
  ///
  /// The same call covers reordering (the module is already in this group)
  /// and joining from elsewhere, because they differ only in where the
  /// module comes from.
  void _handleTabDrop(String id, DockGroup target, int insertIndex) {
    setState(() {
      final existing = target.modules.indexOf(id);
      if (existing >= 0) {
        // [insertIndex] is a position in the list as the operator sees it,
        // which still holds the module being moved — so once it is out, every
        // position after it has shifted down by one.
        target.modules.removeAt(existing);
        final adjusted = (insertIndex > existing ? insertIndex - 1 : insertIndex).clamp(0, target.modules.length);
        target.modules.insert(adjusted, id);
      } else {
        _spec = _removed(_spec, id) ?? DockGroup([id]);
        target.modules.insert(insertIndex.clamp(0, target.modules.length), id);
      }
      target.selected = target.modules.indexOf(id);
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
        // A pane arriving from a drop opens up over the animation rather than
        // appearing at full size — but never below the height of its own tab
        // strip, which is the least a group can paint in: a pane shorter than
        // its chrome overflows its own Column, and a pretty transition is not
        // worth a layout error. A drop into a pane already near that floor
        // simply doesn't animate.
        final growing = identical(split, _growingSplit);
        final rawSum = split.weights.reduce((a, b) => a + b);
        final floorWeight = available <= 0 ? 0.0 : LayoutDensity.chromeHeightOf(context) / available * rawSum;
        final weights = growing
            ? [
                for (var i = 0; i < split.weights.length; i++)
                  i == _growingIndex
                      ? math.max(
                          math.min(split.weights[i], floorWeight),
                          split.weights[i] * layoutAnimationCurve.transform(_growth.value),
                        )
                      : split.weights[i],
              ]
            : split.weights;
        final weightSum = weights.reduce((a, b) => a + b);
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
          flat.add(available * weights[i] / weightSum);
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
              child: _densityForPane(
                // Only a VERTICAL split shortens its children — a horizontal
                // one divides width, and the panes keep the full height they
                // inherited. Re-deriving there would resolve the same rung
                // and only cost a rebuild.
                height: horizontal ? null : flat[2 * i],
                child: PaneSafeArea(
                  left: horizontal ? (isFirst ? ambientLeft : 0) : ambientLeft,
                  top: horizontal ? ambientTop : (isFirst ? ambientTop : 0),
                  right: horizontal ? (isLast ? ambientRight : 0) : ambientRight,
                  bottom: horizontal ? ambientBottom : (isLast ? ambientBottom : 0),
                  child: _buildNode(split.children[i]),
                ),
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

  /// One tab of [group], as a flex child of the strip's row. [context] must
  /// be one from inside the header (a module's action builder resolves its
  /// theme and PaneSafeArea there, not at the dock's root).
  Widget _buildTab(BuildContext context, DockGroup group, int index) {
    final id = group.modules[index];
    // A module's action belongs to that module's own tab and shows only
    // while the tab is the active one — a solo module's tab always is. The
    // builder runs only when its result will be seen; `hasAction` is what
    // holds the room open on the other tabs, so nothing resizes as the
    // selection moves.
    final active = group.modules.length == 1 || index == group.selected;
    final action = widget.tabActions?[id];
    return Expanded(
      child: _TabDropSlot(
        index: index,
        onDrop: (dragged, at) => _handleTabDrop(dragged, group, at),
        child: _DockTab(
        title: widget.titles[id] ?? id,
        selected: index == group.selected,
        showHandle: active,
        hasAction: action != null,
        action: active ? action?.call(context) : null,
        // State, not arrangement: this emits through onStateChanged, and
        // must never reach onSpecChanged. A tab tap that rewrote the saved
        // definition is how merely looking at another pane could replace an
        // operator's layout with whatever stand-in was on screen.
        onTap: () {
          setState(() => group.selected = index);
          _emitState();
        },
        moduleId: id,
          onDragStarted: (id) => setState(() => _dragging = id),
          onDragEnded: () => setState(() => _dragging = null),
        ),
      ),
    );
  }

  /// A module in the arrangement that the caller supplied no widget for.
  /// Renders as nothing, but says so: an empty pane where a pane was asked
  /// for otherwise reads as a broken panel rather than a missing one.
  Widget _missingPane(String id) {
    assert(() {
      debugPrint('[dock] no child widget supplied for module "$id" — rendering an empty pane');
      return true;
    }());
    return const SizedBox.shrink();
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
            // The same chrome height as every other tab strip — this IS the
            // dock's tab strip, and it sits beside and below the ones in the
            // fixed layouts. `chromeHeightOf` holds it to Material's minimum
            // tap target on touch, which a shorter header would otherwise
            // squeeze a module's `tabActions` IconButton below, silently.
            //
            // Snapped because the header's color meets the pane body at this
            // edge, and the height × the grid is fractional at some scale/DPR
            // combinations (48 × 0.85 × 2.75), which seams the two.
            height: PixelGrid.of(context).snap(LayoutDensity.chromeHeightOf(context)),
            // A Builder, not this method's own `context`: `_buildGroup` is a
            // plain Dart call from `_buildSplit`/`_buildNode`, not a fresh
            // Element — reusing `State.context` here would always resolve
            // PaneSafeArea against DockLayoutView's OWN outer ambient,
            // ignoring the position-correct value `_buildSplit` wrapped THIS
            // child in. Builder gets a context at this group's real tree
            // position.
            child: Builder(
              builder: (context) {
                return Padding(
                  padding: EdgeInsets.only(left: PaneSafeArea.leftOf(context), right: PaneSafeArea.rightOf(context)),
                  // Tabs share the strip evenly and only scroll once they
                  // genuinely don't fit, so a dock group reads as the same
                  // kind of tab bar as the stock one beside it. The layering
                  // that gets both: IntrinsicWidth sizes the Row of
                  // equal-flex tabs to (widest tab × count), ConstrainedBox
                  // stretches that to the viewport when it is narrower, and
                  // the scroll view takes over beyond it (scroll-wheel
                  // reachable; tab drags win the gesture arena over the
                  // scroll view, which is fine — the strip is primarily
                  // tapped, and it usually fits).
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: IntrinsicWidth(
                          child: Row(
                            // Stretch, not the default center: centered, a tab
                            // shrink-wraps its label and paints its
                            // bottom-border selection indicator at the LABEL's
                            // bottom edge, well above the strip's — the same
                            // trap operation_view's _narrowTabBar solves with
                            // an explicit height. Stretch is what reaches the
                            // strip's height from here: RenderFlex stretches
                            // to its incoming maxHeight, and the horizontal
                            // viewport passes the strip's height through as
                            // that max.
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < group.modules.length; i++) _buildTab(context, group, i),
                            ],
                          ),
                        ),
                      ),
                    ),
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
                children: [
                  for (var i = 0; i < group.modules.length; i++)
                    DockPaneVisibility(
                      visible: i == group.selected,
                      child: widget.children[group.modules[i]] ?? _missingPane(group.modules[i]),
                    ),
                ],
              ),
              // Cross-faded rather than mounted outright: bands that appear
              // the instant a drag starts read as a flicker under the
              // pointer, and on drop they would vanish before the layout
              // they described has finished moving.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: _dragging == null
                    ? const SizedBox.shrink()
                    : _GroupDropRegions(washAlpha: _hitWashAlpha, onDrop: (id, region) => _handleDrop(id, group, region)),
              ),
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

  /// Whether this module has an action at all — reserves its room whether or
  /// not [action] is being shown right now.
  final bool hasAction;

  /// The module's own action (a settings button), shown at the tab's trailing
  /// edge while this tab is the active one.
  final Widget? action;

  final VoidCallback onTap;
  final String moduleId;
  final ValueChanged<String> onDragStarted;
  final VoidCallback onDragEnded;

  const _DockTab({
    required this.title,
    required this.selected,
    required this.showHandle,
    required this.hasAction,
    required this.action,
    required this.onTap,
    required this.moduleId,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  static const double _handleSize = 16;

  /// A tab's contents: the grab handle pinned to its leading edge, the
  /// module's action to its trailing edge, and the label centered between
  /// them.
  ///
  /// Both edge slots are the SAME width and are held open whether or not
  /// they currently hold anything — that is what keeps the label both
  /// centered in the tab and fixed in place. A slot that collapsed when
  /// empty would swing the label sideways every time the selection moved
  /// (the handle and the action only show on the active tab), and unequal
  /// slots would leave a tab with a settings button reading off-center
  /// against its neighbours. Same reservation, for the same reason, as
  /// operation_view.dart's `_narrowTab`.
  ///
  /// An action is assumed no wider than one chrome row is tall (the tap
  /// target an icon button in this strip gets) — again as `_narrowTabBar`
  /// assumes for its own trailing button.
  Widget _tabContent(BuildContext context, Color labelColor, {required TextStyle? style}) {
    final slot = hasAction ? math.max(_handleSize, LayoutDensity.chromeHeightOf(context)) : _handleSize;
    return Row(
      children: [
        SizedBox(
          width: slot,
          child: showHandle
              ? Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Icon(MdiIcons.dragVertical, size: _handleSize, color: labelColor.withValues(alpha: 0.6)),
                )
              : null,
        ),
        Expanded(child: Center(child: Text(title, style: style?.copyWith(color: labelColor)))),
        SizedBox(
          width: slot,
          child: action == null ? null : Align(alignment: AlignmentDirectional.centerEnd, child: action),
        ),
      ],
    );
  }

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
            padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
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
            padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
            child: _tabContent(context, ghostLabelColor, style: theme.textTheme.titleSmall),
          ),
        ),
        child: TabChrome(
          selected: selected,
          semanticLabel: title,
          // Far tighter than a stock tab's label padding: the handle and the
          // action live in this inset, and a grab handle set in from its own
          // tab's edge reads as decoration next to the label rather than as
          // the tab's own corner. The label stays centred regardless — the
          // slots either side of it are equal.
          padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
          onTap: onTap,
          builder: (context, labelColor) => _tabContent(context, labelColor, style: Theme.of(context).textTheme.titleSmall),
        ),
      ),
    );
  }
}

/// Which split band [local] falls in, given the band [active] right now.
/// The bands are thirds and they overlap at the corners — see
/// [_GroupDropRegions] for why, and for the two rules this implements.
/// Returns null for the middle square, which belongs to no band.
@visibleForTesting
DockRegion? dockSplitRegionAt(Offset local, Size size, {DockRegion? active}) {
  if (size.isEmpty) return null;
  final horizontal = local.dy < size.height / 3
      ? DockRegion.top
      : local.dy > size.height * 2 / 3
      ? DockRegion.bottom
      : null;
  final vertical = local.dx < size.width / 3
      ? DockRegion.left
      : local.dx > size.width * 2 / 3
      ? DockRegion.right
      : null;
  if (horizontal != null && vertical != null) {
    if (active == horizontal || active == vertical) return active;
    return horizontal;
  }
  return horizontal ?? vertical;
}

/// The split targets over a group's BODY while a drag is live: a top and a
/// bottom band, each a third of the height and running the full width, and a
/// left and a right band, each a third of the width and running the full
/// height. Joining a group as a tab is not here — that is the tab strip's own
/// job (see [_TabDropSlot]), where the tabs the module would join actually
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
class _GroupDropRegions extends StatefulWidget {
  final double washAlpha;
  final void Function(String id, DockRegion region) onDrop;

  const _GroupDropRegions({required this.washAlpha, required this.onDrop});

  @override
  State<_GroupDropRegions> createState() => _GroupDropRegionsState();
}

class _GroupDropRegionsState extends State<_GroupDropRegions> {
  DockRegion? _active;

  /// The band last highlighted, kept after [_active] clears so the highlight
  /// can fade out where it was rather than blinking off.
  DockRegion? _fading;

  void _updateFrom(Offset globalOffset) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final region = dockSplitRegionAt(box.globalToLocal(globalOffset), box.size, active: _active);
    if (region != _active) {
      setState(() {
        _active = region;
        _fading = region ?? _fading;
      });
    }
  }

  /// Where [region]'s highlight is painted — the band itself, so what the
  /// operator sees is exactly what they are aiming at.
  Rect _bandOf(DockRegion region, Size size) => switch (region) {
    DockRegion.top => Rect.fromLTWH(0, 0, size.width, size.height / 3),
    DockRegion.bottom => Rect.fromLTWH(0, size.height * 2 / 3, size.width, size.height / 3),
    DockRegion.left => Rect.fromLTWH(0, 0, size.width / 3, size.height),
    DockRegion.right => Rect.fromLTWH(size.width * 2 / 3, 0, size.width / 3, size.height),
  };

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
        final region = _active;
        setState(() => _active = null);
        // The middle square: no band, no guess.
        if (region != null) widget.onDrop(details.data, region);
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
class _TabDropSlot extends StatefulWidget {
  final int index;

  /// Called with the module and the index it should occupy in the group.
  final void Function(String id, int index) onDrop;
  final Widget child;

  const _TabDropSlot({required this.index, required this.onDrop, required this.child});

  @override
  State<_TabDropSlot> createState() => _TabDropSlotState();
}

class _TabDropSlotState extends State<_TabDropSlot> {
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


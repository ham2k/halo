// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// PROTOTYPE of the module-docking layout of DESIGN.md §7: a tree of splits
// whose leaves are tab groups of "modules" (the pane subtrees a view already
// builds — logging panel, map, spots…).
//
// The dock has two modes, and the split between them is the point (see
// [DockLayoutView.editing]). Ordinarily it is a viewer: tabs select, dividers
// between siblings drag to resize, and nothing rearranges. While EDITING,
// every tab doubles as a grab handle, and dragging one shows where it can
// land: on another group's TAB STRIP, at the position under the pointer
// (which both joins a group and reorders within one), on that group's body in
// a top/bottom/left/right band that splits it, or on a thin strip along the
// dock's own edge for a new full-length pane.
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

import 'package:flutter/foundation.dart' show setEquals, visibleForTesting;
import 'package:flutter/material.dart';

import 'density.dart';
import 'layout.dart';
import 'mdi_icons.g.dart';
import 'pane_divider.dart';
import 'spacing.dart';
import 'resizable_split_view.dart' show PaneSafeArea;
import 'tab_chrome.dart';
import 'theme.dart' show fabAccentColor, textWidth;
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

  /// This arrangement without [id], for a module a view has RETIRED — one that
  /// is no longer a pane at all, so a saved arrangement naming it describes
  /// something that cannot be built.
  ///
  /// Null when nothing is left. A group emptied of its last module goes with
  /// it, and a split left holding one child collapses into that child, so the
  /// remaining panes take the space rather than sharing it with a gap.
  ///
  /// NOT for a module that is merely unavailable — an extension disabled or
  /// slow to answer still gets a placeholder pane, because its arrangement is
  /// meant to come back.
  DockNode? without(String id) {
    switch (this) {
      case DockGroup(:final modules):
        final kept = modules.where((m) => m != id).toList();
        return kept.isEmpty ? null : DockGroup(kept);
      case DockSplit(:final axis, :final children, :final weights):
        final kept = <DockNode>[];
        final keptWeights = <double>[];
        for (var i = 0; i < children.length; i++) {
          final child = children[i].without(id);
          if (child == null) continue;
          kept.add(child);
          keptWeights.add(weights[i]);
        }
        if (kept.isEmpty) return null;
        if (kept.length == 1) return kept.first;
        return DockSplit(axis, kept, keptWeights);
    }
  }
}

/// A tabbed stack of modules. With a single module the header still shows
/// its one tab — that IS the grab handle for a standalone pane.
class DockGroup extends DockNode {
  final List<String> modules;
  int selected;

  DockGroup(this.modules, {this.selected = 0});

  /// Copies rather than aliasing the live list: a caller holding a snapshot
  /// of the arrangement (the layout editor's revert target) would otherwise
  /// watch it change under them as panes move.
  @override
  Map<String, dynamic> toJson() => {'type': 'group', 'modules': List<String>.of(modules)};
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
    // Copied, like [DockGroup.toJson]'s modules — and this one is the live
    // list a divider drag mutates in place.
    'weights': List<double>.of(weights),
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

// --- the editing frame ------------------------------------------------------
//
// While editing, every pane is outlined as a FOLDER: the outline runs up
// around the tab that is showing, back down, and on around the pane's body,
// so the pane and the tab that names it read as one object to pick up. The
// tabs that are not showing sit above the line, behind it.
//
// It is drawn in pieces — each tab paints its own segment, the body paints
// its other three sides — rather than by one painter over the group, because
// only a tab knows where it is: tabs share the strip evenly until they stop
// fitting, and then the strip scrolls. A painter above them would have to
// measure, and a measurement taken mid-scroll or off-screen is exactly the
// kind that is a frame stale.

/// Thick enough to read as the pane's own outline from across the window
/// rather than as a hairline somebody left on, which is the whole job: while
/// editing, the operator is looking at BLOCKS, and the contents are only
/// there to say which block is which.
const double _editingFrameWidth = 5.0;

/// Rounds the TABS' top corners only. The pane's bottom corners stay square:
/// they sit against the dock's own dividers and edges, which are square, and
/// a rounded corner there reads as a gap somebody forgot to close.
const double _editingFrameRadius = 8.0;

/// Fills the tab that is showing, so the pane's own tab is picked out of the
/// strip at a glance while the operator is deciding what to move. A fixed
/// dark blue rather than a ColorScheme role, for the same reason
/// [fabAccentColor] is one: the strip is the app's teal chrome in both
/// brightnesses, so what sits on it has to be chosen against THAT rather than
/// against a surface.
const Color _editingSelectedTabColor = Color(0xFF003049);

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
class _EditingPaneWash extends StatelessWidget {
  const _EditingPaneWash();

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
              colors: const [_editingSelectedTabColor, _editingScrimColor, _editingScrimColor],
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
  ..strokeWidth = _editingFrameWidth
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
class _TabFramePainter extends CustomPainter {
  final bool selected;

  /// Whether this tab is at an end of the strip. An INTERIOR tab centres its
  /// side strokes on its own boundaries, so it and its neighbour draw the one
  /// line between them instead of two 5pt lines 5pt apart. The strip's two
  /// outer edges have no neighbour to share with and would lose their outer
  /// half to the scroll viewport's clip, so those are inset instead.
  final bool isFirst;
  final bool isLast;

  const _TabFramePainter({required this.selected, required this.isFirst, required this.isLast});

  @override
  void paint(Canvas canvas, Size size) {
    const half = _editingFrameWidth / 2;
    final left = isFirst ? half : 0.0;
    final right = isLast ? size.width - half : size.width;
    // Never more than half the tab, so a narrow tab bows rather than drawing
    // a corner that has run past the opposite one.
    final r = math.min(_editingFrameRadius, math.max(0.0, (right - left) / 2));
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
  bool shouldRepaint(_TabFramePainter oldDelegate) =>
      oldDelegate.selected != selected || oldDelegate.isFirst != isFirst || oldDelegate.isLast != isLast;
}

/// The rest of the outline: the pane body's leading, trailing and bottom
/// edges, with the bottom corners rounded. No top — the tab strip drew that,
/// notched around the tab that is showing.
class _PaneFramePainter extends CustomPainter {
  /// Whether the tab strip above is drawing this pane's top edge for us.
  /// False for a headerless pane, which has no strip and so needs the fourth
  /// side painted here — the outline is what marks a pane as a block to be
  /// moved, and three sides of one reads as an unfinished box.
  final bool topFromStrip;

  const _PaneFramePainter({this.topFromStrip = true});

  @override
  void paint(Canvas canvas, Size size) {
    const half = _editingFrameWidth / 2;
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
    // whole stroke on these three sides (see [_buildGroup]), so the line sits
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
  bool shouldRepaint(_PaneFramePainter oldDelegate) => oldDelegate.topFromStrip != topFromStrip;
}

/// Which side of a target group (or of the dock itself) a drag lands on.
/// Joining a group as a TAB is not a region: it happens on the tab strip and
/// carries the position within the group, which a region can't say.
enum DockRegion { left, right, top, bottom }

/// Expects a root `Overlay` above it (any `MaterialApp`/`WidgetsApp` provides
/// one) — the layout-edit delete target is painted there rather than in this
/// widget's own subtree, so it can reach over the host app's own window
/// header. Its absence degrades gracefully: no delete target, everything else
/// unaffected.
///
/// The delete target shows the instant a drag starts, with no check on
/// whether the PRESS that started the drag landed on top of it — safe only
/// because the target paints well above the dock's own top edge, where no
/// tab's own press can land. A host that puts nothing of its own above the
/// dock — no separate app bar or window header — puts a tab's press and the
/// target back in the same place: a barely-moved press near the dock's
/// top-center could then show and immediately accept a drop on it. Keep
/// something above the dock's own top edge.
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

  /// Builds a pane's editing control, at the trailing end of its group's
  /// header. Given the module id of the pane that group is showing; return an
  /// empty widget for a pane that wants none.
  ///
  /// At the header's end rather than inside the tab, unlike [tabActions] —
  /// while editing, a tab is a grab handle, and a control riding on one
  /// competes with the drag for the same pointer. [tabActions] is hidden for
  /// exactly that reason, and this takes its place.
  final Widget Function(BuildContext context, String moduleId)? editingPaneControls;

  /// Modules whose group header is hidden — for a pane that is alone in its
  /// group and whose operator has turned its header off.
  ///
  /// One thing always overrides it: a group holding more than one module keeps
  /// its header whatever this says, because the header IS the tab strip there
  /// and hiding it would strand every pane but the showing one.
  ///
  /// [editing] does NOT override it. A headerless pane still needs a grab
  /// handle and its own control while the layout is being rearranged, but it
  /// gets them floated over its corner (`_FloatingPaneChrome`) rather than in
  /// a strip — a strip conjured for the edit costs a chrome height the pane
  /// may not have, and a pane that changes size on entering edit mode makes
  /// [dockMinPaneExtent] two numbers instead of one.
  final Set<String> headerlessModules;

  /// Module id → a minimum size the module's own content needs, beyond the
  /// default floor ([dockMinPaneExtent]) every pane already gets. A width or
  /// height left null falls back to the default on that axis. Missing ids get
  /// the default on both.
  ///
  /// A tabbed group takes the max across its modules on each axis — whichever
  /// tab is showing, the group must fit it. Read through [DockNode] traversal
  /// ([DockLayoutViewState._nodeMinExtent]), never assumed uniform: a nested
  /// [DockSplit] needs its own subtree's minimum, not one chrome height per
  /// direct child.
  final Map<String, Size> moduleMinimumSizes;

  /// A module the operator dragged onto the delete target, reported AFTER it
  /// has left the arrangement — the caller's cue to forget whatever else it
  /// keeps under that id. Not a veto: the dock has already removed it, and
  /// the arrangement change reaches [onSpecChanged] like any other.
  final ValueChanged<String>? onModuleDeleted;

  /// Fires when the ARRANGEMENT changes — a pane added, removed, moved or
  /// resized. Never for a tab tap: see [onStateChanged].
  final ValueChanged<DockNode>? onSpecChanged;

  /// Whether the ARRANGEMENT is being edited.
  ///
  /// Off — the ordinary state — the dock is something you use rather than
  /// something you arrange: tabs select, dividers resize, and there is no
  /// grab handle to catch a pointer that was aiming at a tab. Nothing about
  /// the panes can be moved by accident, which matters because the pane a
  /// stray drag lands in is the one with a half-typed QSO in it.
  ///
  /// On, every tab becomes a handle, each group is framed over its own
  /// contents, and the panes stop taking pointer input — a drag starting
  /// inside a pane would otherwise be swallowed by whatever that pane does
  /// with drags, and the frame would be promising something it can't do.
  ///
  /// The dock does not itself decide what "save" means: it reports every
  /// change through [onSpecChanged] as always, and the view holding the
  /// editing flag decides whether that reaches storage.
  final bool editing;

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
    this.editingPaneControls,
    this.headerlessModules = const {},
    this.moduleMinimumSizes = const {},
    this.onModuleDeleted,
    this.onSpecChanged,
    this.editing = false,
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
    // Deferred a frame: `Overlay.of` needs the ancestor tree this State is
    // being mounted INTO, which isn't resolvable until that mount completes.
    WidgetsBinding.instance.addPostFrameCallback((_) => _insertDeleteTargetOverlay());
  }

  void _growPane(DockSplit split, int index) {
    _growingSplit = split;
    _growingIndex = index;
    _growth.forward(from: 0);
  }

  /// Lives outside this State's own subtree so it can paint over the HOST
  /// app's own window header, not just the dock's content area — see
  /// [_buildDeleteTargetOverlay].
  OverlayEntry? _deleteTargetOverlayEntry;

  void _insertDeleteTargetOverlay() {
    if (!mounted || _deleteTargetOverlayEntry != null) return;
    // `maybeOf`, not `of`: every real host has a root Overlay (MaterialApp's
    // Navigator provides one), but a test harness or an unusual embedding
    // might not, and losing the delete target is a survivable degradation —
    // not something worth an assertion failure inside a post-frame callback,
    // several stack frames from whoever actually embedded this dock.
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    // The ROOT overlay, not the nearest one: a route-local Overlay (a Modal
    // Pane, a dialog) would still leave the target under whatever chrome sits
    // above the route, which is exactly the app's own window header here.
    final entry = OverlayEntry(builder: (context) => _buildDeleteTargetOverlay());
    overlay.insert(entry);
    _deleteTargetOverlayEntry = entry;
  }

  @override
  void dispose() {
    _deleteTargetOverlayEntry?.remove();
    _growth.dispose();
    super.dispose();
  }

  /// The module id being dragged, or null — gates the drop-region overlays.
  String? _dragging;

  // Dock splits use the shared solid divider (pane_divider.dart) — same
  // header-colored bar as ResizableSplitView's default style, at the width
  // the dock's mode calls for.
  //
  // The editing width is granted unconditionally, NOT rationed against what
  // the panes can spare. A dock short enough that those few extra points
  // overflow a pane is already overflowing for a larger reason: entering edit
  // mode also gives every headerless group a tab strip, a whole chrome height
  // the divider cannot give back. Rationing the bar buys a guarantee that
  // still does not hold, so the honest version is the plain one — see
  // docs/design/layouts.md.
  double get _dividerExtent => paneDividerWidth(editing: widget.editing);

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

  /// The delete target, laid over the HOST app's own window header rather
  /// than the dock's content area — a pane is thrown UP and OUT, not at a
  /// button living among the panes it might be mistaken for one of. Reached
  /// through the root [Overlay] because that header belongs to the view
  /// hosting this dock, not to anything in this widget's own subtree.
  ///
  /// Absent for the last module in the arrangement, which cannot be
  /// removed — an empty dock has no tab left to drag anything back with, so
  /// the layout would be unrecoverable from inside the view. A target that
  /// refuses on drop would read as a bug.
  Widget _buildDeleteTargetOverlay() {
    if (!(_dragging != null && _spec.collectModules().length > 1)) {
      return const SizedBox.shrink();
    }
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Align(child: _DeleteDropTarget(onDrop: _handleDeleteDrop)),
    );
  }

  /// Call after any change [_buildDeleteTargetOverlay] depends on
  /// (`_dragging`, the spec). The entry's Element is a sibling subtree, not a
  /// descendant reached by this State's own `setState` — safe to call
  /// directly from here because these all run as ordinary event-handler
  /// callbacks, never mid-build, which is the one context `markNeedsBuild`
  /// refuses.
  void _syncDeleteTargetOverlay() => _deleteTargetOverlayEntry?.markNeedsBuild();

  void _handleDeleteDrop(String id) {
    if (removeModule(id)) widget.onModuleDeleted?.call(id);
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

  /// A module's declared minimum along [axis] ([DockLayoutView.moduleMinimumSizes]),
  /// or 0 when it has none — 0 rather than the default unit, so a caller can
  /// `max()` this against [dockMinPaneExtent] without double-counting.
  double _moduleMinFor(String id, Axis axis) {
    final size = widget.moduleMinimumSizes[id];
    return (axis == Axis.horizontal ? size?.width : size?.height) ?? 0;
  }

  /// [node]'s own minimum extent along [axis], walking its subtree.
  ///
  /// [crossExtent] is the ACTUAL extent [node] will receive on the other
  /// axis, when known. Known for the top-level call (a split's own direct
  /// children share its incoming cross-axis constraint via
  /// `CrossAxisAlignment.stretch`) and stays known through any further
  /// nesting ALONG [axis] — a split that doesn't subdivide the cross axis
  /// can't hide it. It is lost only crossing into a NESTED split whose own
  /// axis is the one being asked about as a cross axis: that split divides
  /// it among its children by weight, which isn't decided until the layout
  /// this computation runs ahead of. There, a grandchild [DockGroup] that
  /// DOES reflow (see below) is estimated at the single-unit floor rather
  /// than the true 3-unit one — an UNDER-estimate in the narrow-cross-axis
  /// case, never an over-estimate, so it cannot itself manufacture a new
  /// overflow.
  double _nodeMinExtent(DockNode node, Axis axis, {double? crossExtent}) {
    switch (node) {
      case DockGroup(:final modules):
        final unit = dockPaneUnit(context);
        // Only a headerless SOLO module reflows: it gets `_FloatingPaneChrome`,
        // which stacks vertically below three units. Every other group shows a
        // real header row — a tab strip for more than one module, or a plain
        // title bar for one — that never stacks, editing or not, so its floor
        // stays three units wide by one tall regardless of what the cross axis
        // can spare. This must track `_buildGroup`'s own `showHeader`, or the
        // floor promises an orientation the header can't actually paint.
        final reflows = modules.length == 1 && widget.headerlessModules.contains(modules.first);
        final base = reflows
            ? (crossExtent != null ? dockMinPaneExtent(context, crossExtent: crossExtent) : unit)
            : (axis == Axis.horizontal ? unit * 3 : unit);
        final declared = modules.fold(0.0, (max_, id) => math.max(max_, _moduleMinFor(id, axis)));
        return math.max(base, declared);
      case DockSplit(axis: final childAxis, :final children):
        if (childAxis == axis) {
          // This split's OWN axis matches the one being measured, so it
          // doesn't subdivide the CROSS axis at all — every child gets the
          // exact crossExtent this call received (`CrossAxisAlignment.stretch`
          // gives each of THIS split's children the same cross-axis share the
          // split itself was handed). Known, not lost, so it propagates.
          final dividerTotal = _dividerExtent * (children.length - 1);
          return children.fold(
            dividerTotal,
            (sum, c) => sum + _nodeMinExtent(c, axis, crossExtent: crossExtent),
          );
        }
        // Here this split's OWN axis IS the cross axis being asked about —
        // it divides that axis among its children by weight, which isn't
        // known ahead of the layout this computation runs ahead of. See the
        // class comment above for what that costs.
        return children.fold(0.0, (max_, c) => math.max(max_, _nodeMinExtent(c, axis)));
    }
  }

  Widget _buildSplit(DockSplit split) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = split.axis == Axis.horizontal;
        final total = horizontal ? constraints.maxWidth : constraints.maxHeight;
        final dividerExtent = _dividerExtent;
        // Floored at zero: a window smaller than the dividers alone must
        // degrade to zero-extent panes, not negative SizedBox widths.
        final available = math.max(0.0, total - dividerExtent * (split.children.length - 1));
        // A pane arriving from a drop opens up over the animation rather than
        // appearing at full size — but never below the height of its own tab
        // strip, which is the least a group can paint in: a pane shorter than
        // its chrome overflows its own Column, and a pretty transition is not
        // worth a layout error. A drop into a pane already near that floor
        // simply doesn't animate.
        final growing = identical(split, _growingSplit);
        final rawSum = split.weights.reduce((a, b) => a + b);
        final floorWeight = available <= 0 ? 0.0 : LayoutDensity.chromeHeightOf(context) / available * rawSum;
        var weights = growing
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
        var weightSum = weights.reduce((a, b) => a + b);
        // Hold every child to the floor for this axis, BEFORE the extents are
        // derived. The divider drag below bounds a DRAG and nothing else, so
        // on its own it lets a saved arrangement — or a shipped default like
        // 9:1 — lay a pane out below the height of its own chrome, which
        // overflows the group's Column. That is a layout error
        // the operator cannot see the cause of and cannot drag their way out
        // of, since the drag bound refuses to shrink a pane that is already
        // under the limit but never grows it back.
        //
        // Proportional give: the panes above the floor fund the ones below it,
        // in proportion to what they have, so a run that is merely tight
        // degrades evenly instead of collapsing its last child. A run with no
        // room for its own floors (available < the floors' sum) is left
        // alone — every child is under, there is nothing to take from, and
        // scaling further would only trade one overflow for another.
        //
        // Per-child, not a single scalar: a module can declare a larger
        // minimum than the default (`DockLayoutView.moduleMinimumSizes`), and
        // a child that is itself a nested split needs its own subtree's
        // minimum, not one unit per direct child — see [_nodeMinExtent].
        final crossExtent = horizontal ? constraints.maxHeight : constraints.maxWidth;
        final floors = [for (final c in split.children) _nodeMinExtent(c, split.axis, crossExtent: crossExtent)];
        final totalFloor = floors.fold(0.0, (a, b) => a + b);
        if (available > 0 && weightSum > 0 && totalFloor <= available) {
          final floorWeights = [for (final f in floors) f / available * weightSum];
          final lifted = [for (var i = 0; i < weights.length; i++) math.max(weights[i], floorWeights[i])];
          final excess = lifted.reduce((a, b) => a + b) - weightSum;
          if (excess > 0) {
            // What the panes ABOVE their own floor can give, and what each gives.
            final spare = [for (var i = 0; i < lifted.length; i++) math.max(0.0, lifted[i] - floorWeights[i])];
            final spareSum = spare.reduce((a, b) => a + b);
            if (spareSum > 0) {
              for (var i = 0; i < lifted.length; i++) {
                lifted[i] -= excess * spare[i] / spareSum;
              }
            }
          }
          weights = lifted;
          weightSum = weights.reduce((a, b) => a + b);
        }
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
          if (i > 0) flat.add(dividerExtent);
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
                  // Against the weights this frame was LAID OUT from, which
                  // are not the stored ones whenever the floor above lifted a
                  // pane: measured from the stored pair instead, a boundary
                  // beside an under-floor pane moves by the difference
                  // between them rather than by the drag, so it lags the
                  // pointer and then snaps. The lifted pair is also what is on
                  // screen, so adopting it here is the same rule `onDragCancel`
                  // follows — persist what the operator can see. Not while a
                  // pane is animating in: those weights are a frame of an
                  // animation, not an arrangement.
                  final base = List<double>.of(growing ? split.weights : weights);
                  // Move the boundary between i-1 and i, keeping both panes
                  // usable; weights shift by the dragged fraction of the run.
                  // Bounds via max/min, not clamp(): a pane ALREADY below the
                  // minimum (persisted weights in a smaller window) inverts
                  // clamp's limits, which throws — max/min just refuse to
                  // shrink it further.
                  final deltaWeight = delta / available * weightSum;
                  final maxGive = math.max(0.0, base[i - 1] - floors[i - 1] / available * weightSum);
                  final maxTake = math.max(0.0, base[i] - floors[i] / available * weightSum);
                  final shift = math.min(maxTake, math.max(-maxGive, deltaWeight));
                  base[i - 1] += shift;
                  base[i] -= shift;
                  for (var k = 0; k < split.weights.length; k++) {
                    split.weights[k] = base[k];
                  }
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
    // builder runs only when its result will be seen.
    final solo = group.modules.length == 1;
    final active = solo || index == group.selected;
    // The slot holds one thing or the other, never both: what a pane offers
    // while it is being USED, or — while the layout is being edited — its
    // layout options. They are different questions, and edit mode is when
    // only the second one can be answered.
    final action = widget.editing
        ? (widget.editingPaneControls == null ? null : (ctx) => widget.editingPaneControls!(ctx, id))
        : widget.tabActions?[id];
    // Unwrapped: the two strips wrap it differently — see [_buildGroup].
    return _TabDropSlot(
        index: index,
        onDrop: (dragged, at) => _handleTabDrop(dragged, group, at),
        child: _DockTab(
        title: widget.titles[id] ?? id,
        selected: index == group.selected,
        editing: widget.editing,
        // A group of one is a PANE, not a tab bar of one: it renders as a
        // plain title bar, like the fixed split's. There is nothing to
        // select, so nothing should look selectable.
        solo: solo,
        isFirst: index == 0,
        isLast: index == group.modules.length - 1,
        // Every tab while editing, not just the active one: the handle is
        // what says a tab can be moved, and a group whose three tabs show one
        // handle between them reads as one movable pane and two fixed ones.
        showHandle: widget.editing,
        // Reserved only where it will be USED while editing. The reservation
        // exists to keep labels from shifting as the selection moves, and a
        // tab that can be squeezed to its handle has given that up already —
        // holding a chrome-height slot open on it would put a floor under the
        // squeeze at five times the handle's width.
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
        onDragStarted: (id) {
          setState(() => _dragging = id);
          _syncDeleteTargetOverlay();
        },
        onDragEnded: () {
          setState(() => _dragging = null);
          _syncDeleteTargetOverlay();
        },
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
    // See [headerlessModules] for the two overrides. Edit mode is NOT one of
    // them any more: a strip conjured for the duration of an edit is a whole
    // chrome height the pane has to find from somewhere, and a pane already at
    // its floor ([dockMinPaneExtent]) has nowhere to find it — so the layout
    // overflowed for exactly as long as the operator was rearranging it, which
    // is the worst possible moment. A headerless pane gets [_FloatingPaneChrome]
    // laid OVER its top-left corner instead: same handle, same title, same
    // options button, no height taken from anything.
    final showHeader = group.modules.length > 1 ||
        !widget.headerlessModules.contains(group.modules.first);
    final floatingChrome = widget.editing && !showHeader;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
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
                    builder: (context, constraints) {
                      // Stretch, not the default center, in both strips:
                      // centered, a tab shrink-wraps its label and paints its
                      // bottom-border selection indicator at the LABEL's
                      // bottom edge, well above the strip's — the same trap
                      // operation_view's _narrowTabBar solves with an explicit
                      // height. Stretch is what reaches the strip's height
                      // from here: RenderFlex stretches to its incoming
                      // maxHeight, and the horizontal viewport passes the
                      // strip's height through as that max.
                      if (widget.editing) {
                        // The editing strip does NOT scroll. Scrolling is the
                        // right answer while the dock is being used — the
                        // operator is reading tabs, and a squeezed one reads
                        // as nothing. Mid-rearrange it is the wrong one: the
                        // tab scrolled out of sight is as likely as not the
                        // one being worked on, and the handles are what the
                        // strip is for. So it squeezes instead, and the tab
                        // that is SHOWING is the one that keeps its name.
                        final count = group.modules.length;
                        final floor = _DockTab.activeMinWidth(context);
                        // Even shares while they are wide enough to read, and
                        // only then the showing tab's floor — the squeeze is
                        // what a narrow strip costs, not a permanent shape.
                        final squeezing = count > 1 && constraints.maxWidth / count < floor;
                        if (!squeezing) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < count; i++) Expanded(child: _buildTab(context, group, i)),
                            ],
                          );
                        }
                        // What is left over, shared out. CONTINUOUS rather
                        // than a step down to the handle: the others give up
                        // exactly what the showing tab needs and no more, so a
                        // strip a few points too narrow costs a few points of
                        // label rather than every label at once — but never
                        // past the grab handle, which is a fixed box and
                        // overflows the Row rather than shrinking with it.
                        final others = math.max(
                          _DockTab.squeezedMinWidth,
                          (constraints.maxWidth - floor) / (count - 1),
                        );
                        final rest = others * (count - 1);
                        if (floor + rest <= constraints.maxWidth) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < count; i++)
                                if (i == group.selected)
                                  // Expanded, not the floor: it takes what the
                                  // others left, which is the floor plus
                                  // whatever rounding they gave back.
                                  Expanded(child: _buildTab(context, group, i))
                                else
                                  SizedBox(width: others, child: _buildTab(context, group, i)),
                            ],
                          );
                        }
                        // Not even handles fit. Scrolling is the wrong answer
                        // while rearranging — see above — but it is the only
                        // one left that does not paint a tab over its
                        // neighbour, and a strip this narrow has already lost
                        // the argument.
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < count; i++)
                                SizedBox(
                                  width: i == group.selected ? floor : others,
                                  child: _buildTab(context, group, i),
                                ),
                            ],
                          ),
                        );
                      }
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: constraints.maxWidth),
                          child: IntrinsicWidth(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < group.modules.length; i++)
                                  Expanded(child: _buildTab(context, group, i)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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
              // While editing, the pane's own contents take no pointer input.
              // A pane is a block to be moved then, and its insides are a
              // picture of what the block holds: a drag begun inside the log
              // would otherwise be taken by the log's own scroll or selection
              // gestures, and a tap would put the caret in a field the
              // operator can't see the point of typing into.
              // ExcludeFocus alongside it, which IgnorePointer does not
              // imply: whatever held focus when editing began keeps it
              // otherwise, and in this app that is a logging field — now
              // under an opaque wash, still taking keystrokes, still
              // submitting the QSO on Enter. ExcludeSemantics for the same
              // reason one level up: a screen reader must not land on a
              // control that is only a picture of itself right now.
              ExcludeSemantics(
                excluding: widget.editing,
                child: ExcludeFocus(
                  excluding: widget.editing,
                  child: IgnorePointer(
                    ignoring: widget.editing,
                // The pane gives up the room the outline needs rather than
                // being painted over: while editing it is a little smaller on
                // its three free sides, and the line sits in what it gave up.
                // Nothing on the top — the tab strip's own segments are the
                // outline there, and the strip has not moved.
                    child: Padding(
                      padding: widget.editing
                          ? EdgeInsets.only(
                              left: _editingFrameWidth,
                              // A headerless pane has no strip drawing its top
                              // edge, so it gives up room for that side too.
                              top: showHeader ? 0 : _editingFrameWidth,
                              right: _editingFrameWidth,
                              bottom: _editingFrameWidth,
                            )
                          : EdgeInsets.zero,
                      child: IndexedStack(
                        // Tight constraints, like a TabBarView page — panes
                        // are designed to fill their pane, not shrink-wrap.
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
                    ),
                  ),
                ),
              ),
              if (widget.editing) const IgnorePointer(child: _EditingPaneWash()),
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
              // Last, so the outline is over the drop bands too — otherwise
              // the pane being aimed at loses its own edges at the moment it
              // matters most.
              if (widget.editing)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _PaneFramePainter(topFromStrip: showHeader)),
                  ),
                ),
              // Above the frame and the wash both: it is the only thing in a
              // headerless pane that is still a control while editing, so
              // nothing may paint over it.
              if (floatingChrome)
                // `.fill`, not left/top alone: a Positioned with only two
                // edges hands its child UNBOUNDED constraints (nothing pins
                // the other two), so the reflow LayoutBuilder inside
                // _FloatingPaneChrome could never see the pane's real width
                // and always chose the wide layout. Align keeps the content
                // shrink-wrapped within the now-bounded box — it gets LOOSE
                // constraints from Align, not the tight ones Positioned.fill
                // itself receives.
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(left: _editingFrameWidth, top: _editingFrameWidth),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: _FloatingPaneChrome(
                        title: widget.titles[group.modules.first] ?? group.modules.first,
                        moduleId: group.modules.first,
                        action: widget.editingPaneControls?.call(context, group.modules.first),
                        onDragStarted: (id) {
                          setState(() => _dragging = id);
                          _syncDeleteTargetOverlay();
                        },
                        onDragEnded: () {
                          setState(() => _dragging = null);
                          _syncDeleteTargetOverlay();
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A tab's action while the dock is being USED, painted quiet and coming up
/// to full strength under the pointer.
///
/// Quiet because it is not what the tab is FOR: the tab is a name to read and
/// a place to tap, and a control at full contrast beside every name competes
/// with the one thing the strip exists to say. It has to stay findable
/// though, so it darkens against the header rather than fading out — visible
/// at a glance, unmistakable once aimed at.
///
/// The recolour is a [ColorFilter], not a colour passed down: the action is
/// the CALLER's widget and has already chosen its own colour (it is the same
/// button the fixed split's title bar shows, where it must read against that
/// header instead). srcIn repaints whatever it is handed.
class _QuietTabAction extends StatefulWidget {
  final Widget child;

  const _QuietTabAction({required this.child});

  @override
  State<_QuietTabAction> createState() => _QuietTabActionState();
}

class _QuietTabActionState extends State<_QuietTabAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    final active = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;
    final quiet = quietTabActionTone(header, active);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: TweenAnimationBuilder<Color?>(
        duration: const Duration(milliseconds: 150),
        tween: ColorTween(end: _hovered ? active : quiet),
        builder: (context, color, child) => ColorFiltered(
          colorFilter: ColorFilter.mode(color ?? quiet, BlendMode.srcIn),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Where a quiet tab action's resting tone starts, as a fraction of the way
/// from the header toward black.
const double _quietening = 0.35;

/// The least contrast an interactive control may have against what it sits on
/// (WCAG 1.4.11). A control the operator cannot find is not quiet, it is
/// missing — and for an extension panel this button is the only way to its
/// settings form, with no hover to bring it up on a touch screen.
const double _minQuietContrast = 3.0;

/// The resting tone for a [_QuietTabAction] on [header]: [_quietening] of the
/// way to black, and further if that does not clear [_minQuietContrast].
/// Derived rather than fixed because the header colour is the edition's, and a
/// constant that reads on one is invisible on another.
///
/// Darkening is the whole look — the control recedes INTO its header rather
/// than fading off it. A header already so dark that nothing below it clears
/// the floor has no quiet tone to offer, so [active] is used unchanged: a
/// control at full strength is a worse-looking header than intended, and an
/// invisible one is a feature the operator cannot reach.
@visibleForTesting
Color quietTabActionTone(Color header, Color active) {
  for (var t = _quietening; t < 1.0; t += 0.05) {
    final tone = Color.lerp(header, Colors.black, t)!;
    if (_contrastBetween(tone, header) >= _minQuietContrast) return tone;
  }
  return active;
}

double _contrastBetween(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// One tab in a group header: tap to select, drag to move the module. The
/// drag-indicator dots mark it as a handle.
class _DockTab extends StatelessWidget {
  final String title;
  final bool selected;

  /// See [DockLayoutView.editing]. Off, this tab is only a tab — no
  /// [Draggable] wraps it at all, so there is no drag gesture competing with
  /// the tap, and no grab cursor promising a move that isn't offered.
  final bool editing;

  /// Whether this is its group's ONLY module, in which case it is not a tab
  /// at all: no selection indicator, no tap, not announced as a tab, and its
  /// title reads from the leading edge like the fixed split's pane title bar.
  /// A tab bar of one offers a choice that does not exist.
  final bool solo;

  /// Position in the strip, for the editing outline — see
  /// [_TabFramePainter.isFirst].
  final bool isFirst;
  final bool isLast;

  final bool showHandle;

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
    required this.editing,
    required this.solo,
    required this.isFirst,
    required this.isLast,
    required this.showHandle,
    required this.action,
    required this.onTap,
    required this.moduleId,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  /// The grab handle exists only while editing ([showHandle] IS `editing`),
  /// so there is one size and one strength: it is the control the operator
  /// is there to use, not a hint that a tab could be moved.
  static const double editingHandleSize = 20;

  /// The least the SHOWING tab is squeezed to while editing: both slots — its
  /// grab handle and its options button — and enough between them for three
  /// letters and an ellipsis. Less than that and the one tab whose name the
  /// operator still needs is showing nothing but punctuation.
  ///
  /// Measured rather than guessed at, so it holds at every font scale: a
  /// fixed number is a number for one scale, and the strip would collapse
  /// early at Larger and late at Smallest.
  static double activeMinWidth(BuildContext context) {
    // [textWidth], not a bare TextPainter: it folds in the ambient text style
    // and the current textScaler, so this holds under OS/accessibility text
    // sizing too. A hand-rolled painter measures the unscaled string and
    // under-reserves by however much the operator has turned their text up.
    final width = textWidth(
      context,
      'Abc…',
      Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold) ?? const TextStyle(),
    );
    // Every box between the tab's two edges: the handle, the action, the
    // label's own inset either side of it (see [_tabContent]) and the tab's
    // padding. Leave one out and the floor is that much short — the tab
    // ellipsizes below the three letters this exists to keep.
    return editingHandleSize + _editingActionSize + width + Space.sm * 2 + Space.xxs * 2;
  }

  /// The least a tab being squeezed can be given: its grab handle and the
  /// tab's own padding, both fixed boxes. Below this the Row overflows
  /// instead of shrinking, and the handle paints over the neighbouring tab.
  static const double squeezedMinWidth = editingHandleSize + Space.xxs * 2;

  /// What a tab's action is given while editing — its own icon and a little
  /// around it, rather than the chrome-height tap target it gets while the
  /// dock is being USED.
  ///
  /// The slots are deliberately UNEQUAL here, unlike everywhere else in this
  /// tab: equal slots keep the label centred and fixed as the selection
  /// moves, and that is worth two full chrome heights when an operator is
  /// reading tab names. Mid-rearrange it is not — a squeezed tab spending
  /// 96pt on a 20pt handle and a 24pt glyph shows "SP…" where it could show
  /// the word.
  static const double _editingActionSize = 32;

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
  /// A tab's contents: the grab handle (while editing) at the leading edge,
  /// then the module's name, then its action — packed together, with the
  /// slack after them.
  ///
  /// They read as ONE thing that way: the name says what the pane is and the
  /// action acts on it, and a control at the far edge of a wide tab reads as
  /// the strip's rather than as that pane's. The name is left-aligned for the
  /// same reason a pane title is — it is a heading, and a heading starts
  /// where the eye already is.
  Widget _tabContent(BuildContext context, Color labelColor, {required TextStyle? style}) {
    return Row(
      children: [
        if (showHandle)
          SizedBox(
            width: editingHandleSize,
            child: Icon(MdiIcons.dragVertical, size: editingHandleSize, color: labelColor),
          ),
        Expanded(
          child: Row(
            children: [
              // Flexible, so a squeezed tab's name gives up its width down to
              // nothing rather than forcing the tab to stay as wide as one
              // line of text.
              Flexible(
                child: Padding(
                  // A pane heading takes the fixed split's own title-bar
                  // inset, so a solo dock pane and the split's logging pane
                  // read as the same kind of thing. A tab with no handle
                  // starts its name at that same inset — nothing else stands
                  // between the name and the tab's edge — while a tab being
                  // rearranged gives it back to the handle already sitting
                  // there. The trailing side stays tight either way: it is
                  // the gap to the options button, not an edge.
                  padding: EdgeInsetsDirectional.only(
                    start: showHandle ? Space.sm : Space.lg,
                    end: solo ? Space.lg : Space.sm,
                  ),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // A pane's name is what the operator is arranging BY while
                    // editing — the tab is otherwise a handle and a border
                    // with some text between them.
                    style: (editing ? style?.copyWith(fontWeight: FontWeight.bold) : style)
                        ?.copyWith(color: labelColor),
                  ),
                ),
              ),
              if (action != null) _actionSlot(context),
            ],
          ),
        ),
      ],
    );
  }

  /// The module's action, sized to what is in it: its glyph while editing
  /// (see [_editingActionSize]), a full tap target otherwise.
  Widget _actionSlot(BuildContext context) => SizedBox(
    width: editing ? _editingActionSize : LayoutDensity.chromeHeightOf(context),
    child: editing
        ? IconButtonTheme(
            // Tightened to its glyph. The tap target shrinks with it, which
            // is the trade: a control pressed once per rearrange, against
            // letters in the name of the pane being rearranged.
            data: IconButtonThemeData(
              style: IconButton.styleFrom(
                minimumSize: const Size.square(_editingActionSize),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            child: action!,
          )
        : _QuietTabAction(child: action!),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tabTheme = theme.tabBarTheme;
    // Only used for the drag ghost below — the live tab's own label color
    // comes from TabChrome, which resolves the same way.
    final ghostLabelColor = (selected ? tabTheme.labelColor : tabTheme.unselectedLabelColor) ?? theme.colorScheme.onPrimary;
    // A group of one is a pane with a title bar, not a tab bar of one: no
    // TabChrome at all, so there is no selection indicator, no tap, and
    // nothing announced to a screen reader as a tab. Its colour comes from
    // the app bar's, like the fixed split's title bar, rather than from the
    // tab theme's label roles — which are about selected-vs-not, a
    // distinction this has no second thing to make.
    final tab = solo
        ? Semantics(
            header: true,
            label: title,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
              child: _tabContent(
                context,
                theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary,
                style: theme.textTheme.titleSmall,
              ),
            ),
          )
        : TabChrome(
            selected: selected,
            semanticLabel: title,
            // Far tighter than a stock tab's label padding: the handle and the
            // action live in this inset, and a grab handle set in from its own
            // tab's edge reads as decoration next to the label rather than as
            // the tab's own corner.
            padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
            onTap: onTap,
            // While editing, the outline marks the showing tab and its bottom
            // is deliberately open — the pane runs into it. The stock
            // indicator sits across exactly that opening.
            showIndicator: !editing,
            builder: (context, labelColor) =>
                _tabContent(context, labelColor, style: Theme.of(context).textTheme.titleSmall),
          );
    // Outside edit mode the tab is only a tab. Not a disabled Draggable but
    // no Draggable at all: one that merely refuses still enters the gesture
    // arena against the tap, so tabs would answer a click late — or not at
    // all, once the pointer moved a few pixels first.
    if (!editing) return tab;
    // A Material rather than a DecoratedBox: it becomes the nearest one above
    // the tab's InkWell, so hover and press still land ON the fill instead of
    // splashing on the strip underneath, out of sight.
    final filledTab = selected
        ? Material(
            color: _editingSelectedTabColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(_editingFrameRadius)),
            child: tab,
          )
        : tab;
    // A foreground painter, so the outline lands over the tab's own selection
    // indicator and over the fill, rather than under either.
    final framedTab = CustomPaint(
      foregroundPainter: _TabFramePainter(selected: selected, isFirst: isFirst, isLast: isLast),
      child: filledTab,
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
        child: framedTab,
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
class _DeleteDropTarget extends StatelessWidget {
  final ValueChanged<String> onDrop;

  const _DeleteDropTarget({required this.onDrop});

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


/// The edit-mode chrome for a pane that has no header of its own: a grab
/// handle, the pane's name, and its layout-options button, in a small block
/// laid OVER the pane's top-left corner.
///
/// Over, not above. A strip conjured for the duration of an edit costs a whole
/// chrome height, and a pane at [dockMinPaneExtent] has none to give — so the
/// arrangement overflowed for precisely as long as it was being rearranged.
/// Floating it means a pane is the same height edit mode or not, which is also
/// what lets [dockMinPaneExtent] be ONE number rather than one per state.
///
/// Sized to its content, so it covers as little of the pane as it can, and
/// faded out toward its right and bottom edges rather than stopping at a hard
/// border: the block sits on top of somebody's content, and a rectangle with a
/// crisp edge reads as a piece of that content rather than as chrome over it.
class _FloatingPaneChrome extends StatelessWidget {
  final String title;
  final String moduleId;
  final Widget? action;
  final ValueChanged<String> onDragStarted;
  final VoidCallback onDragEnded;

  const _FloatingPaneChrome({
    required this.title,
    required this.moduleId,
    required this.action,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  /// How far past the content the fade runs before it is fully transparent.
  /// The gradient needs somewhere to happen: ending it at the last glyph puts
  /// a hard edge exactly where the block is trying not to have one.
  static const double _fadeExtent = 28.0;

  /// Clear space between the controls and where the fade begins, so the block
  /// reads as chrome sitting on the pane rather than as a label crowded
  /// against its own edge.
  static const double _runUp = Space.xl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    final onHeader = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;
    final unit = LayoutDensity.chromeHeightOf(context);
    final handle = Icon(MdiIcons.dragVertical, size: _DockTab.editingHandleSize, color: onHeader);
    final label = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleSmall?.copyWith(color: onHeader, fontWeight: FontWeight.bold),
    );
    // Deliberately NOT a _DockTab: a tab is a choice among tabs, and this is
    // the only thing in its pane. Borrowing the tab's frame and fill made it
    // read as a one-tab strip that had come loose — the pane's own outline
    // ([_PaneFramePainter]) is what marks the block now, and this carries just
    // the three controls on the fade.
    //
    // The pane offering this block is, by construction, at LEAST
    // [dockMinPaneExtent]'s floor — three units in a row, or one wide by
    // three tall when the pane can't spare the width. Reading its own real
    // constraint (via the enclosing LayoutBuilder below) rather than
    // assuming the roomier shape keeps the two in agreement: a floor that
    // promised vertical stacking must get a block that actually stacks.
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= unit * 3;
        final content = wide
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  handle,
                  const SizedBox(width: Space.xxs),
                  Flexible(child: label),
                  if (action != null) ...[const SizedBox(width: Space.xs), action!],
                ],
              )
            : SizedBox(
                width: unit,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    handle,
                    const SizedBox(height: Space.xxs),
                    label,
                    if (action != null) ...[const SizedBox(height: Space.xs), action!],
                  ],
                ),
              );
        final blockWidth = wide ? null : unit + _fadeExtent;
        final blockHeight = wide ? unit + _fadeExtent : unit * 3 + _fadeExtent;
        return IgnorePointer(
          // Paint-only outside the block itself: the fade extends past the
          // controls, and a transparent tail that swallowed taps would take
          // them from the pane underneath.
          ignoring: false,
          child: SizedBox(
            width: blockWidth,
            height: blockHeight,
            child: DecoratedBox(
              // Diagonal, which fades BOTH free edges with one gradient — the
              // block is anchored top-left, so right and bottom are the two
              // sides that meet the pane's content.
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [header, header, header.withValues(alpha: 0)],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: Padding(
                padding: wide
                    ? const EdgeInsets.only(left: Space.md, right: _runUp + _fadeExtent, bottom: _fadeExtent)
                    : const EdgeInsets.only(left: Space.md, top: Space.md, right: _fadeExtent, bottom: _runUp + _fadeExtent),
                child: SizedBox(
                  width: wide ? null : unit,
                  height: wide ? unit : null,
                  child: MouseRegion(
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
                          child: Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onPrimary),
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(opacity: 0.4, child: content),
                      child: content,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

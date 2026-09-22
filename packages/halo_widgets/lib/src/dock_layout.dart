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

import 'package:flutter/material.dart';

import 'density.dart';
import 'layout.dart';
import 'pane_divider.dart';
import 'resizable_split_view.dart' show PaneSafeArea;
import 'ui_scale.dart';

import 'dock_chrome.dart';
import 'dock_drop_targets.dart';
import 'dock_model.dart';
import 'dock_regions.dart';
import 'dock_tab.dart';

/// Whether the pane reading this is the one on top of its tab group. Every
/// pane in a group stays MOUNTED (the group is an IndexedStack, so a
/// half-typed field survives a tab switch), which means a pane that costs
/// something to keep current — an extension panel crossing the JS bridge —
/// has no other way to know nobody is looking at it.
///
/// Absent means visible: a pane outside a dock (a fixed view, a test) is on
/// screen whenever it is built.
class DockPaneVisibility extends InheritedWidget {
  final bool visible;

  const DockPaneVisibility({super.key, required this.visible, required super.child});

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<DockPaneVisibility>()?.visible ?? true;

  /// The value WITHOUT registering a dependency, for a caller that already
  /// depends on it through [of] and needs it mid-frame — `didUpdateWidget`
  /// runs BEFORE `didChangeDependencies` when a widget and its inherited
  /// ancestors both change in one pump, so a State reading its own cached
  /// copy there is reading the previous frame's answer.
  static bool readOf(BuildContext context) => context.getInheritedWidgetOfExactType<DockPaneVisibility>()?.visible ?? true;

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
  /// gets them floated over its corner (`FloatingPaneChrome`) rather than in
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

  /// Modules this arrangement will not let go of: no grab handle, no
  /// `Draggable`, and [removeModule] refuses them — so they reach neither the
  /// delete target nor the Remove in a pane's layout options.
  ///
  /// For a pane the view cannot function without. A phone whose logging pane
  /// has been dragged away is a dead app, and unlike the last-pane rule there
  /// is nothing about the arrangement on screen that says so — which is why
  /// the tab simply never becomes draggable, rather than a drop being refused
  /// after the operator has already carried it somewhere.
  final Set<String> pinnedModuleIds;

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
    this.pinnedModuleIds = const {},
  });

  /// True when [spec]'s modules are exactly [moduleIds] — the guard a view
  /// uses before trusting a persisted spec (a module renamed or added since
  /// it was saved falls back to the view's default arrangement).
  static bool specMatches(DockNode? spec, Iterable<String> moduleIds) {
    if (spec == null) return false;
    final inSpec = spec.collectModules();
    return inSpec.length == inSpec.toSet().length && inSpec.toSet().containsAll(moduleIds) && moduleIds.toSet().containsAll(inSpec);
  }

  @override
  State<DockLayoutView> createState() => DockLayoutViewState();
}

/// Public so a view can hold a `GlobalKey<DockLayoutViewState>` and call
/// [revealModule] — a programmatic tab selection (surfacing command output,
/// a tapped spot's logging pane, the call-info detail).
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

  /// The boundary whose touch strip the pointer is over, keyed as
  /// `(split, index)` like [_dragOvershoot] — null the rest of the time, and
  /// always null off a touch platform, where no strip is built. The strip
  /// covers the bar, so the bar's own hover never fires while it exists;
  /// this is how the grab line still lights under a trackpad cursor on an
  /// iPad.
  (DockSplit, int)? _hoveredDivider;

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

  void _handleDividerDragEnd(DockSplit split, int index) {
    _dragOvershoot.remove((split, index));
    _emit();
  }

  /// Travel a pointer has made past a boundary's limit, in logical pixels,
  /// keyed by the boundary it belongs to — the split and the index of the
  /// child after it. The boundary moves by the CLAMPED shift, so without
  /// banking the remainder a reversal would move it the instant the pointer
  /// turned around, leaving the cursor off the divider by however far it had
  /// pushed into the floor.
  ///
  /// Per boundary rather than one for the dock: [SolidPaneDivider] tracks a
  /// single pointer PER DIVIDER, and drives its drag from a raw [Listener]
  /// that never enters the gesture arena, so nothing arbitrates between two
  /// dividers. Two fingers on two of them would otherwise share one
  /// accumulator — each drag zeroing the other's bank and spending its
  /// travel — which is the very fault this banking exists to prevent.
  ///
  /// [ResizableSplitView] holds the same invariant via its unclamped
  /// `_dragPosition`; the two must not disagree about it.
  final Map<(DockSplit, int), double> _dragOvershoot = {};

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
    // Selects at EVERY level on the way down, not just where the module sits:
    // a pane inside a container is only on screen once the container's own tab
    // is showing too, so a reveal that stopped at the innermost group would
    // leave it behind a tab nobody selected.
    bool select(DockNode node) {
      switch (node) {
        case DockGroup():
          final at = node.modules.indexOf(id);
          if (at >= 0) {
            node.selected = at;
            return true;
          }
          for (var i = 0; i < node.modules.length; i++) {
            final subtree = node.nested[node.modules[i]];
            if (subtree != null && select(subtree)) {
              node.selected = i;
              return true;
            }
          }
          return false;
        case DockSplit():
          return node.children.any(select);
      }
    }

    setState(() => select(_spec));
  }

  /// Every module in the layout, in visual order — what a layout editor
  /// lists. Read from the LIVE tree, not the caller's `initialSpec`, which
  /// stopped being the arrangement the moment the user moved anything.
  List<String> get modules => _spec.collectModules();

  /// The live arrangement, for a test that needs to see the tree rather than
  /// the flattened module list [modules] gives. Not for production code: the
  /// host owns its own copy and hears about changes through `onSpecChanged`.
  @visibleForTesting
  DockNode get spec => _spec;

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
  /// [id] may name a CONTAINER, in which case everything inside it goes —
  /// what the tab says it holds is what it holds. Each module dropped is
  /// reported through [DockLayoutView.onModuleDeleted] separately, so a host
  /// forgetting their contents does not have to know the shape of what it
  /// removed.
  bool removeModule(String id) {
    final losing = _modulesLostRemoving(id);
    if (losing == null) return false;
    final pruned = _removed(_spec, id);
    if (pruned == null) return false;
    setState(() => _spec = pruned);
    _emit();
    for (final module in losing) {
      widget.onModuleDeleted?.call(module);
    }
    return true;
  }

  /// The modules removing [id] would take, or null when the dock refuses —
  /// [id] is not in the arrangement, something pinned is inside it, or the
  /// last pane would go with it.
  ///
  /// One place, because three callers have to agree: [removeModule] itself,
  /// the delete target — which must not be OFFERED for a drop it will refuse,
  /// since "a target that refuses on drop would read as a bug" — and the
  /// host's own Remove in a pane's layout options.
  List<String>? _modulesLostRemoving(String id) {
    final container = _spec.collectContainerIds().contains(id);
    if (!container && !_spec.collectModules().contains(id)) return null;
    // The SUBTREE for a container, not just its id: nesting a pinned pane puts
    // it behind a container tab that is not itself pinned, and a guard reading
    // only the dragged id would let that tab carry it to the delete target —
    // the one outcome pinning exists to make unreachable.
    //
    // Null from `_subtreeOf` is a lookup that FAILED, not a container holding
    // nothing: read as the latter the count below passes, and the removal then
    // throws — a bug surfacing as a crash rather than as a refusal.
    //
    // Counted in MODULES: a container's tab standing alone is still a dock
    // with panes in it, and the rule is only that the last PANE cannot go.
    final losing = container ? _subtreeOf(id)?.collectModules() : [id];
    if (losing == null) return null;
    if (losing.any(widget.pinnedModuleIds.contains)) return null;
    if (_spec.collectModules().length - losing.length < 1) return null;
    return losing;
  }

  /// Whether the dock would drop [id] — for a host deciding whether to OFFER
  /// the removal at all. See [_modulesLostRemoving].
  bool canRemoveModule(String id) => _modulesLostRemoving(id) != null;

  /// What container [id] holds, or null when nothing by that id is one.
  DockNode? _subtreeOf(String id) {
    DockNode? find(DockNode node) => switch (node) {
      DockGroup(:final nested) => nested[id] ?? nested.values.map(find).nonNulls.firstOrNull,
      DockSplit(:final children) => children.map(find).nonNulls.firstOrNull,
    };
    return find(_spec);
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
  /// [onDetach] receives a nested container's subtree when [id] names one, so
  /// a drop that picks a container up can put it back down still holding what
  /// was in it. Without it the drag would arrive as an empty tab and the panes
  /// inside would be gone — a move that silently deletes.
  /// [collapse] false leaves the tree in its intermediate shape — a split with
  /// one child, a container down to one module — for a caller that is about to
  /// put something back and will [_normalized] once at the end.
  ///
  /// It exists because normalising here is what made a two-pane container
  /// impossible to rearrange from the inside: taking one of its two panes out
  /// empties that pane's group, which collapses the split, which retires the
  /// container — detaching the very group the drop was aimed at, so the
  /// placement found nothing to place into and gave up. The tree is only ever
  /// odd between those two points, inside one `setState`, so nothing renders
  /// it.
  DockNode? _removed(DockNode node, String id, {void Function(DockNode)? onDetach, bool collapse = true}) {
    switch (node) {
      case DockGroup():
        final index = node.modules.indexOf(id);
        if (index >= 0) {
          if (node.nested.remove(id) case final subtree?) onDetach?.call(subtree);
          node.modules.removeAt(index);
        } else {
          for (final slot in node.modules.toList()) {
            final subtree = node.nested[slot];
            if (subtree == null) continue;
            final replacement = _removed(subtree, id, onDetach: onDetach, collapse: collapse);
            if (replacement == null) {
              node.nested.remove(slot);
              node.modules.remove(slot);
            } else {
              node.nested[slot] = replacement;
            }
          }
        }
        if (node.modules.isEmpty) return null;
        // Holds the nested invariant and applies the collapse rule — a
        // container down to one module hands its slot back to it.
        if (collapse) node.collapseNested();
        return node;
      case DockSplit():
        for (var i = node.children.length - 1; i >= 0; i--) {
          final replacement = _removed(node.children[i], id, onDetach: onDetach, collapse: collapse);
          if (replacement == null) {
            node.children.removeAt(i);
            node.weights.removeAt(i);
          } else {
            node.children[i] = replacement;
          }
        }
        if (node.children.isEmpty) return null;
        if (collapse && node.children.length == 1) return node.children.first;
        return node;
    }
  }

  /// Puts the live tree into its canonical shape and reports whether anything
  /// is left. False is a caller's failure path: it has just placed something,
  /// so an empty result means the placement did not take.
  bool _normalize() {
    final next = _normalized(_spec);
    if (next == null) return false;
    _spec = next;
    return true;
  }

  /// The canonical shape of [node]: every group's nested invariant and collapse
  /// rule applied, and every split left holding one child folded into it.
  ///
  /// Run ONCE, after a placement — see [_removed]'s `collapse`. Null when
  /// nothing is left, which a caller that has just placed something should
  /// treat as a failure rather than as an empty dock.
  DockNode? _normalized(DockNode node) {
    switch (node) {
      case DockGroup():
        for (final slot in node.modules.toList()) {
          final subtree = node.nested[slot];
          if (subtree == null) continue;
          var next = _normalized(subtree);
          // A container holding a group whose ONE tab is another container is
          // two tabs deep for one thing — the operator would see "More"
          // containing a single "More". The outer is the tab they already had,
          // with the name and options they set on it, so the inner folds away.
          while (next is DockGroup && next.modules.length == 1 && next.nested[next.modules.first] != null) {
            next = next.nested[next.modules.first]!;
          }
          if (next == null) {
            node.nested.remove(slot);
            node.modules.remove(slot);
          } else {
            node.nested[slot] = next;
          }
        }
        if (node.modules.isEmpty) return null;
        node.collapseNested();
        return node;
      case DockSplit():
        for (var i = node.children.length - 1; i >= 0; i--) {
          final next = _normalized(node.children[i]);
          if (next == null) {
            node.children.removeAt(i);
            node.weights.removeAt(i);
          } else {
            node.children[i] = next;
          }
        }
        if (node.children.isEmpty) return null;
        if (node.children.length == 1) return node.children.first;
        return node;
    }
  }

  /// A fresh id for a container, unique within THIS dock.
  ///
  /// Local, unlike a panel instance id: a container indexes nothing outside
  /// its own arrangement — its title and layout options live in the view's own
  /// per-class `paneOptions` — so two docks each holding a `nested#1` collide
  /// over nothing.
  ///
  /// [alsoTaken] is not optional politeness: the caller has already DETACHED
  /// what it is placing, so the id of a container in flight — and of every
  /// container inside it — reads as free from the tree, and the lowest-free
  /// rule hands it straight back. The arrangement then holds one id twice,
  /// which shares one `paneOptions` entry between two tabs and, on the next
  /// launch, fails the host's duplicate check and costs the operator the whole
  /// layout.
  String _newContainerId({Iterable<String> alsoTaken = const []}) {
    final taken = {..._spec.collectContainerIds(), ...alsoTaken};
    var n = 1;
    while (taken.contains('$dockContainerIdBase#$n')) {
      n++;
    }
    return '$dockContainerIdBase#$n';
  }

  /// The node a dragged [id] should arrive as: a plain group for a module, and
  /// for a container the same tab it left as, still holding [carried].
  DockGroup _arriving(String id, DockNode? carried) => carried == null ? DockGroup([id]) : DockGroup([id], nested: {id: carried});

  /// The split [child] is a child OF, or null when it is the root or the whole
  /// subtree behind a container slot — neither of which has one.
  ///
  /// Descends through `nested` as well as through splits. A group inside a
  /// container is a group like any other, and a walk that stopped at the group
  /// holding the container would report every one of them as parentless — which
  /// callers read as "this is the root".
  DockSplit? _parentOf(DockNode node, DockNode child) {
    switch (node) {
      case DockGroup(:final nested):
        for (final subtree in nested.values) {
          if (identical(subtree, child)) return null;
          final found = _parentOf(subtree, child);
          if (found != null) return found;
        }
        return null;
      case DockSplit(:final children):
        for (final c in children) {
          if (identical(c, child)) return node;
          final found = _parentOf(c, child);
          if (found != null) return found;
        }
        return null;
    }
  }

  /// Puts [replacement] where [target] sits — a split's child, a container's
  /// subtree, or the root itself. False when [target] is not in the tree at
  /// all, which is the one answer a caller must not ignore: it has already
  /// taken the dragged module out by then, and dropping the replacement on the
  /// floor loses it.
  bool _replaceNode(DockNode target, DockNode replacement) {
    if (identical(_spec, target)) {
      _spec = replacement;
      return true;
    }
    bool inside(DockNode node) {
      switch (node) {
        case DockGroup(:final nested):
          for (final slot in nested.keys.toList()) {
            if (identical(nested[slot], target)) {
              nested[slot] = replacement;
              return true;
            }
            if (inside(nested[slot]!)) return true;
          }
          return false;
        case DockSplit(:final children):
          for (var i = 0; i < children.length; i++) {
            if (identical(children[i], target)) {
              children[i] = replacement;
              return true;
            }
            if (inside(children[i])) return true;
          }
          return false;
      }
    }

    return inside(_spec);
  }

  /// A dropped pane takes the share of the band it was dropped on — the
  /// bands are thirds, so the newcomer arrives at the size the operator was
  /// looking at when they let go, rather than at half the target and then
  /// needing a divider drag to become what the target promised.
  static const _newPaneShare = 1 / 3;

  void _handleDrop(String id, DockGroup target, DockRegion region) {
    // Every path below takes the module OUT of the tree before it knows where
    // it is going. A restore point is what keeps an abandoned placement from
    // being a deletion — the alternative is unpicking a mutation whose shape
    // depends on which branch it failed in. Cheap: taken once per drop, used
    // only on a path that should never run.
    final restore = _spec.toJson();
    final selection = DockState.of(_spec);
    var failed = false;
    setState(() {
      // A side drop of a group's sole module beside itself is a no-op.
      if (target.modules.length == 1 && target.modules.single == id) return;
      DockNode? carried;
      // Deferred: normalising here would collapse a two-pane container out
      // from under the group being dropped ON. `_normalize` below is what puts
      // the tree back into shape, once, after the placement.
      _spec = _removed(_spec, id, onDetach: (node) => carried = node, collapse: false) ?? _arriving(id, carried);
      final fresh = _arriving(id, carried);
      final axis = (region == DockRegion.left || region == DockRegion.right) ? Axis.horizontal : Axis.vertical;
      final before = region == DockRegion.left || region == DockRegion.top;
      // Checked the same way the other two handlers check it, and for the
      // same reason: dragging a CONTAINER's tab onto a band of a pane inside
      // that container detaches the group being dropped on. Not an
      // impossibility to assert away — an assert here throws before the
      // restore below can run, which turns a no-op into the deletion it was
      // added to prevent.
      if (!_isInTree(target)) {
        failed = true;
        return;
      }
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
        final weights = before ? [_newPaneShare, 1 - _newPaneShare] : [1 - _newPaneShare, _newPaneShare];
        final split = DockSplit(axis, before ? [fresh, target] : [target, fresh], weights);
        // Through `_replaceNode` rather than "null parent means root": a group
        // that is the whole subtree behind a container slot also has no split
        // parent, and treating it as the root would discard `split` — the only
        // thing holding `fresh` — with the module already taken out of the
        // tree, so the drop would delete the pane it was moving.
        if (!_replaceNode(target, split)) {
          failed = true;
          return;
        }
        // Reached only if `target` is in the tree but sits nowhere a node can
        // be replaced, which the checks above already rule out.
        _growPane(split, before ? 0 : 1);
      }
      if (!_normalize()) failed = true;
    });
    if (failed) {
      _restoreTree(restore, selection, 'drop-lost-target: the dropped-on group left the tree mid-drop');
      return;
    }
    _emit();
  }

  /// A drop on the CENTRE of [target]'s body: the tab that is showing becomes
  /// a **container** — a vertical split holding what was in that tab and the
  /// newcomer, [above] or below it — and the container takes the tab's slot.
  ///
  /// The tab set itself does not change shape: {Info, Spots, Map} with Info
  /// dropped below Map's centre is {Spots, More[Map over Info]}, not four
  /// panes and not a split of the whole group. That is the distinction from
  /// the four edge bands ([_handleDrop]), which split the group in its PARENT.
  void _handleNestDrop(String id, DockGroup target, {required bool above}) {
    // See [_handleDrop]'s own restore point, and for the same reason: the
    // removal below runs before this knows the slot is still there to nest
    // into. Removing `id` can take `target` out of the tree entirely —
    // emptying its sibling collapses the split around it, and a container down
    // to one module hands its slot back and drops the subtree holding `target`
    // with it — and `target.modules` reads perfectly well on an orphan.
    final restore = _spec.toJson();
    final selection = DockState.of(_spec);
    var failed = false;
    setState(() {
      if (target.modules.isEmpty) return;
      final slot = target.modules[target.selected.clamp(0, target.modules.length - 1)];
      // The showing tab IS the thing being dragged: there is nothing to put it
      // beside except itself.
      if (slot == id) return;
      DockNode? carried;
      _spec = _removed(_spec, id, onDetach: (node) => carried = node, collapse: false) ?? _arriving(id, carried);
      // Re-found, never the index captured above: removing `id` from this very
      // group shifts every slot after it. And reachability separately, which
      // an index cannot answer for.
      final at = target.modules.indexOf(slot);
      if (at < 0 || !_isInTree(target)) {
        failed = true;
        return;
      }
      // A container already in this slot would only be reachable if the outer
      // body took drops while a container tab was showing, which it does not
      // (see [_buildGroup]) — handled anyway rather than assumed away.
      final held = target.nested.remove(slot) ?? DockGroup([slot]);
      final fresh = _arriving(id, carried);
      final containerId = _newContainerId(alsoTaken: fresh.collectContainerIds());
      target.nested[containerId] = DockSplit(Axis.vertical, above ? [fresh, held] : [held, fresh], [1, 1]);
      target.modules[at] = containerId;
      target.selected = at;
      if (!_normalize()) failed = true;
    });
    if (failed) {
      // A nest that cannot be completed is a no-op, not a deletion. Reachable
      // for real: nest B under A, then drag one of the container's two panes
      // onto the other's centre — the removal collapses the container out from
      // under the group being dropped on.
      _restoreTree(restore, selection, 'nest-lost-target: the dropped-on group left the tree mid-drop');
      return;
    }
    _emit();
  }

  /// Puts the tree back as it was and TELLS THE HOST so.
  ///
  /// Both halves are load-bearing. `_spec` begins life as the host's own
  /// object (`widget.initialSpec`) and every mutation above runs in place, so
  /// by now the host is holding the damaged tree — a restore that only
  /// repaired this widget's field would look right on screen and save a
  /// missing pane. And the selection has to be laid back over it: which tab is
  /// on top is STATE, and the restore point is a definition, which by design
  /// carries none — so a restore without this snaps every strip in the dock
  /// back to its first tab.
  void _restoreTree(Map<String, dynamic> snapshot, DockState selection, String why) {
    debugPrint('[layout] $why');
    final spec = DockNode.fromJson(snapshot)!;
    selection.applyTo(spec);
    setState(() => _spec = spec);
    _emit();
  }

  /// Whether [node] is still reachable from the live tree. Identity, not
  /// equality: what a caller holding a node from before a mutation needs to
  /// know is whether THAT object is still in it.
  bool _isInTree(DockNode node) {
    bool find(DockNode current) {
      if (identical(current, node)) return true;
      return switch (current) {
        DockGroup(:final nested) => nested.values.any(find),
        DockSplit(:final children) => children.any(find),
      };
    }

    return find(_spec);
  }

  /// A drop on [target]'s tab strip: the module takes position [insertIndex]
  /// among that group's tabs, and is selected — a module that lands behind
  /// an unselected tab looks like a drop that did nothing.
  ///
  /// The same call covers reordering (the module is already in this group)
  /// and joining from elsewhere, because they differ only in where the
  /// module comes from.
  void _handleTabDrop(String id, DockGroup target, int insertIndex) {
    // See [_handleDrop]'s restore point, for the same reason.
    final restore = _spec.toJson();
    final selection = DockState.of(_spec);
    var failed = false;
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
        DockNode? carried;
        _spec = _removed(_spec, id, onDetach: (node) => carried = node, collapse: false) ?? _arriving(id, carried);
        // A container's contents are on screen while its tab shows, and that
        // tab is draggable — so the strip being dropped on can be one INSIDE
        // the container being dragged, which `_removed` has just detached.
        // Inserting into an orphan loses the container and every pane in it.
        if (!_isInTree(target)) {
          failed = true;
          return;
        }
        target.modules.insert(insertIndex.clamp(0, target.modules.length), id);
        // A container joins a strip as the same tab it left as, still holding
        // what was in it.
        if (carried case final subtree?) target.nested[id] = subtree;
      }
      target.selected = target.modules.indexOf(id);
      if (!_normalize()) failed = true;
    });
    if (failed) {
      _restoreTree(restore, selection, 'tab-drop-lost-target: the dropped-on group left the tree mid-drop');
      return;
    }
    _emit();
  }

  /// A drop on the dock's own edge strip: the module becomes a new
  /// quarter-ish pane along that whole edge.
  void _handleEdgeDrop(String id, DockRegion region) {
    setState(() {
      final spec = _spec;
      if (spec is DockGroup && spec.modules.length == 1 && spec.modules.single == id) return;
      DockNode? carried;
      final root = _removed(_spec, id, onDetach: (node) => carried = node) ?? _arriving(id, carried);
      final fresh = _arriving(id, carried);
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
            _positionedEdge(region, DockEdgeDropTarget(region: region, onDrop: (id) => _handleEdgeDrop(id, region))),
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
    // Asked about the id actually IN FLIGHT, not just "more than one pane
    // exists": a container tab stands for everything inside it, and a pinned
    // pane nested behind one would otherwise reach a target that silently
    // refuses it.
    final dragging = _dragging;
    if (dragging == null || !canRemoveModule(dragging)) {
      return const SizedBox.shrink();
    }
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Align(child: DockDeleteDropTarget(onDrop: _handleDeleteDrop)),
    );
  }

  /// Call after any change [_buildDeleteTargetOverlay] depends on
  /// (`_dragging`, the spec). The entry's Element is a sibling subtree, not a
  /// descendant reached by this State's own `setState` — safe to call
  /// directly from here because these all run as ordinary event-handler
  /// callbacks, never mid-build, which is the one context `markNeedsBuild`
  /// refuses.
  void _syncDeleteTargetOverlay() => _deleteTargetOverlayEntry?.markNeedsBuild();

  void _handleDeleteDrop(String id) => removeModule(id);

  Widget _positionedEdge(DockRegion region, Widget child) {
    const extent = 20.0;
    return switch (region) {
      DockRegion.left => Positioned(left: 0, top: 0, bottom: 0, width: extent, child: child),
      DockRegion.right => Positioned(right: 0, top: 0, bottom: 0, width: extent, child: child),
      DockRegion.top => Positioned(left: 0, right: 0, top: 0, height: extent, child: child),
      DockRegion.bottom => Positioned(left: 0, right: 0, bottom: 0, height: extent, child: child),
    };
  }

  /// What tab slot [index] of [group] shows: a container's whole subtree, or
  /// a pane wrapped in the chrome editing gives a pane.
  Widget _slotBody(DockGroup group, int index, {required bool showHeader}) {
    final slot = group.modules[index];
    if (group.nested[slot] case final subtree?) return _buildNode(subtree);
    final pane = widget.children[slot] ?? _missingPane(slot);
    // While editing, the pane's own contents take no pointer input. A pane is
    // a block to be moved then, and its insides are a picture of what the
    // block holds: a drag begun inside the log would otherwise be taken by the
    // log's own scroll or selection gestures, and a tap would put the caret in
    // a field the operator can't see the point of typing into.
    //
    // ExcludeFocus alongside it, which IgnorePointer does not imply: whatever
    // held focus when editing began keeps it otherwise, and in this app that
    // is a logging field — now under an opaque wash, still taking keystrokes,
    // still submitting the QSO on Enter. ExcludeSemantics for the same reason:
    // a screen reader must not land on a control that is only a picture of
    // itself right now.
    //
    // Per SLOT rather than around the whole IndexedStack, because a container
    // slot must not get any of it — see [_slotBody]'s caller.
    return ExcludeSemantics(
      excluding: widget.editing,
      child: ExcludeFocus(
        excluding: widget.editing,
        child: IgnorePointer(
          ignoring: widget.editing,
          // The pane gives up the room the outline needs rather than being
          // painted over: while editing it is a little smaller on its three
          // free sides, and the line sits in what it gave up. Nothing on the
          // top — the tab strip's own segments are the outline there, and the
          // strip has not moved.
          child: Padding(
            padding: widget.editing
                ? EdgeInsets.only(
                    left: editingFrameWidth,
                    // A headerless pane has no strip drawing its top edge, so
                    // it gives up room for that side too.
                    top: showHeader ? 0 : editingFrameWidth,
                    right: editingFrameWidth,
                    bottom: editingFrameWidth,
                  )
                : EdgeInsets.zero,
            child: pane,
          ),
        ),
      ),
    );
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
      case DockGroup(:final modules, :final nested):
        final unit = dockPaneUnit(context);
        // Only a headerless SOLO module reflows: it gets `FloatingPaneChrome`,
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
        // A container slot asks for whatever its whole subtree asks for — an
        // inner vertical split needs both its panes' heights, and a panel
        // inside it can declare a minimum of its own. Counted, or a divider
        // drag squeezes a group holding a two-pane container down to the
        // single-pane floor and the inner split overflows.
        final declared = modules.fold(0.0, (max_, id) {
          final subtree = nested[id];
          return math.max(max_, subtree == null ? _moduleMinFor(id, axis) : _nodeMinExtent(subtree, axis, crossExtent: crossExtent));
        });
        return math.max(base, declared);
      case DockSplit(axis: final childAxis, :final children):
        if (childAxis == axis) {
          // This split's OWN axis matches the one being measured, so it
          // doesn't subdivide the CROSS axis at all — every child gets the
          // exact crossExtent this call received (`CrossAxisAlignment.stretch`
          // gives each of THIS split's children the same cross-axis share the
          // split itself was handed). Known, not lost, so it propagates.
          final dividerTotal = _dividerExtent * (children.length - 1);
          return children.fold(dividerTotal, (sum, c) => sum + _nodeMinExtent(c, axis, crossExtent: crossExtent));
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
                      ? math.max(math.min(split.weights[i], floorWeight), split.weights[i] * layoutAnimationCurve.transform(_growth.value))
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
        // Transparent, touch-sized grab strips overlaid on the boundaries —
        // empty off a touch platform. See [paneDividerTouchSlop] for why the
        // widening can't happen on the bar itself.
        final touchStrips = <Widget>[];
        final touchSlop = paneDividerTouchSlop();
        // The leading edge of the element about to be added, along the
        // split's own axis: the SNAPPED extents in `flat`, summed as they are
        // consumed, which is where the strips have to sit.
        var runOffset = 0.0;
        for (var i = 0; i < split.children.length; i++) {
          if (i > 0) {
            void handleDividerDrag(double delta) => setState(() {
              // A run with no room, or weights that sum to nothing, cannot
              // convert pixels to weight at all — so the travel IS
              // overshoot and is banked rather than dropped. Guarding
              // weightSum here too keeps this path's arithmetic as safe as
              // the build path's above: `shift / weightSum` would otherwise
              // make the bank NaN, and NaN weights persist silently, coming
              // back as a layout the loader discards.
              if (available <= 0 || weightSum <= 0) {
                _dragOvershoot[(split, i)] = (_dragOvershoot[(split, i)] ?? 0) + delta;
                return;
              }
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
              // Banked overshoot first, so travel spent pushing against a
              // floor has to be paid back before the boundary moves again.
              // Kept in PIXELS, not weight: a window resized mid-drag
              // changes what a weight is worth, and a debt recorded in the
              // old currency would repay the wrong distance.
              final desired = delta + (_dragOvershoot[(split, i)] ?? 0);
              final deltaWeight = desired / available * weightSum;
              final maxGive = math.max(0.0, base[i - 1] - floors[i - 1] / available * weightSum);
              final maxTake = math.max(0.0, base[i] - floors[i] / available * weightSum);
              final shift = math.min(maxTake, math.max(-maxGive, deltaWeight));
              _dragOvershoot[(split, i)] = desired - shift / weightSum * available;
              base[i - 1] += shift;
              base[i] -= shift;
              for (var k = 0; k < split.weights.length; k++) {
                split.weights[k] = base[k];
                // Written back into the frame's own snapshot too, which
                // `base` is re-derived from on every event: the pointer
                // moves this frame collected are all dispatched before the
                // rebuild, so without this the 2nd..Nth each start from the
                // same stale values and only the last survives. A
                // high-rate mouse delivers several moves per frame and a
                // slow frame collects more still, so the boundary would
                // advance at a fraction of the pointer's speed exactly
                // when the machine is busiest. Harmless when `weights`
                // already IS `split.weights` (no floor was lifted).
                weights[k] = base[k];
              }
            });
            children.add(
              SolidPaneDivider(
                axis: split.axis,
                extent: flat[2 * i - 1],
                onDragStart: () => _dragOvershoot[(split, i)] = 0,
                onDragUpdate: handleDividerDrag,
                hovered: _hoveredDivider == (split, i),
                onDragEnd: () => _handleDividerDragEnd(split, i),
                // Weights were mutated live during the drag — a cancelled
                // gesture (pointer lost to another recognizer) must persist
                // what's on screen too, or the layout silently reverts on
                // relaunch.
                onDragCancel: () => _handleDividerDragEnd(split, i),
              ),
            );
            if (touchSlop > 0) {
              final stripStart = runOffset - touchSlop;
              final stripExtent = flat[2 * i - 1] + touchSlop * 2;
              touchStrips.add(
                Positioned(
                  left: horizontal ? stripStart : 0,
                  right: horizontal ? null : 0,
                  top: horizontal ? 0 : stripStart,
                  bottom: horizontal ? 0 : null,
                  width: horizontal ? stripExtent : null,
                  height: horizontal ? null : stripExtent,
                  // Same callbacks as the bar it covers, which is the whole
                  // point: the strip hit-tests first, so on a touch platform
                  // this is the object that actually drags. It carries the
                  // resize cursor for the same reason: covering the bar takes
                  // the bar's own MouseRegion out of the hit path, and a
                  // mobile build with a trackpad (an iPad's) would otherwise
                  // show a plain arrow over every boundary.
                  child: MouseRegion(
                    cursor: horizontal ? SystemMouseCursors.resizeLeftRight : SystemMouseCursors.resizeUpDown,
                    onEnter: (_) => setState(() => _hoveredDivider = (split, i)),
                    // Unconditionally, without checking that the exit is the
                    // strip that entered: `DockSplit` has no `==`, so a spec
                    // rebuilt into fresh instances under a resting pointer
                    // would leave this pinned to a split nothing can match
                    // again, and no divider would ever light after that. Only
                    // one strip can be hovered at a time regardless.
                    onExit: (_) => setState(() => _hoveredDivider = null),
                    child: PaneDividerDragTarget(
                      axis: split.axis,
                      onDragStart: () => _dragOvershoot[(split, i)] = 0,
                      onDragUpdate: handleDividerDrag,
                      onDragEnd: () => _handleDividerDragEnd(split, i),
                      onDragCancel: () => _handleDividerDragEnd(split, i),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              );
            }
            runOffset += flat[2 * i - 1];
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
          runOffset += flat[2 * i];
        }
        final run = horizontal
            ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
        if (touchStrips.isEmpty) return run;
        // Passthrough, so the run is laid out under exactly the constraints
        // it gets without the Stack — every extent above was derived from
        // them, and a loosened one would re-derive nothing but still let the
        // run size itself to its children.
        return Stack(fit: StackFit.passthrough, children: [run, ...touchStrips]);
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
        ? (widget.editingPaneControls == null ? null : (BuildContext ctx) => widget.editingPaneControls!(ctx, id))
        : widget.tabActions?[id];
    // Unwrapped: the two strips wrap it differently — see [_buildGroup].
    return DockTabDropSlot(
      index: index,
      onDrop: (dragged, at) => _handleTabDrop(dragged, group, at),
      child: DockTab(
        title: widget.titles[id] ?? id,
        selected: index == group.selected,
        editing: widget.editing,
        // A group of one is a PANE, not a tab bar of one: it renders as a
        // plain title bar. There is nothing to select, so nothing should
        // look selectable.
        solo: solo,
        isFirst: index == 0,
        isLast: index == group.modules.length - 1,
        // Every tab while editing, not just the active one: the handle is
        // what says a tab can be moved, and a group whose three tabs show one
        // handle between them reads as one movable pane and two fixed ones.
        showHandle: widget.editing && !widget.pinnedModuleIds.contains(id),
        pinned: widget.pinnedModuleIds.contains(id),
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
    // is the worst possible moment. A headerless pane gets [FloatingPaneChrome]
    // laid OVER its top-left corner instead: same handle, same title, same
    // options button, no height taken from anything.
    final showHeader = group.modules.length > 1 || !widget.headerlessModules.contains(group.modules.first);
    // The showing slot holds a whole subtree rather than a pane. Everything
    // this group draws AS a pane — the editing wash, its own drop bands, its
    // own outline — belongs to the panes inside instead, each of which draws
    // its own. So the outer group's body bands are unreachable while a
    // container is showing: splitting THIS group means selecting a plain tab
    // first, and the dock's own edge strips are always there.
    final showingNested = group.nested.containsKey(group.modules[group.selected.clamp(0, group.modules.length - 1)]);
    final floatingChrome = widget.editing && !showHeader;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          Material(
            color: headerColor,
            child: SizedBox(
              // The same chrome height as every other strip of chrome — this
              // IS the dock's tab strip. `chromeHeightOf` holds it to
              // Material's minimum tap target on touch, which a shorter header
              // would otherwise squeeze a module's `tabActions` IconButton
              // below, silently.
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
                    // Tabs share the strip evenly and ellipsize their names,
                    // and only scroll once even a few letters each no longer
                    // fit — so a dock group reads as the same kind of tab bar
                    // as the stock one beside it. Sizing the strip to its
                    // WIDEST tab instead (IntrinsicWidth over equal-flex tabs)
                    // pushes it past the pane the moment one module has a long
                    // name, and a tab scrolled out of sight is a pane the
                    // operator cannot reach without first discovering that the
                    // strip scrolls at all. Beyond the floor it does scroll
                    // (scroll-wheel reachable; tab drags win the gesture arena
                    // over the scroll view, which is fine — the strip is
                    // primarily tapped, and it usually fits).
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Stretch, not the default center, in both strips:
                        // centered, a tab shrink-wraps its label and paints its
                        // bottom-border selection indicator at the LABEL's
                        // bottom edge, well above the strip's. Stretch is what
                        // reaches the strip's height
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
                          final floor = DockTab.activeMinWidth(context);
                          // Even shares while they are wide enough to read, and
                          // only then the showing tab's floor — the squeeze is
                          // what a narrow strip costs, not a permanent shape.
                          final squeezing = count > 1 && constraints.maxWidth / count < floor;
                          if (!squeezing) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [for (var i = 0; i < count; i++) Expanded(child: _buildTab(context, group, i))],
                            );
                          }
                          // What is left over, shared out. CONTINUOUS rather
                          // than a step down to the handle: the others give up
                          // exactly what the showing tab needs and no more, so a
                          // strip a few points too narrow costs a few points of
                          // label rather than every label at once — but never
                          // past the grab handle, which is a fixed box and
                          // overflows the Row rather than shrinking with it.
                          final others = math.max(DockTab.squeezedMinWidth, (constraints.maxWidth - floor) / (count - 1));
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
                                for (var i = 0; i < count; i++) SizedBox(width: i == group.selected ? floor : others, child: _buildTab(context, group, i)),
                              ],
                            ),
                          );
                        }
                        final count = group.modules.length;
                        // ONE floor for the whole group, action included where
                        // any tab in it has one — not the selected tab's own.
                        // The action moves with the selection, and a floor that
                        // moved with it would resize every tab in the strip on
                        // each tap. Under it the tabs share; at it they stop and
                        // the strip scrolls, so the floor is also the width the
                        // scrolling strip gives them.
                        final floor = DockTab.readableMinWidth(context, solo: count == 1, hasAction: group.modules.any((id) => widget.tabActions?[id] != null));
                        if (count * floor <= constraints.maxWidth) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [for (var i = 0; i < count; i++) Expanded(child: _buildTab(context, group, i))],
                          );
                        }
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [for (var i = 0; i < count; i++) SizedBox(width: floor, child: _buildTab(context, group, i))],
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
              IndexedStack(
                // Tight constraints, like a TabBarView page — panes are
                // designed to fill their pane, not shrink-wrap.
                sizing: StackFit.expand,
                index: group.selected,
                children: [
                  for (var i = 0; i < group.modules.length; i++)
                    // A Builder so the value below can be ANDed with the one
                    // this group is itself inside. `DockPaneVisibility.of`
                    // reads the NEAREST ancestor only, so an inner group that
                    // published its own selection unqualified would tell the
                    // selected pane of a hidden container that it is on screen
                    // — and everything that acts on this (the mobile numbers
                    // row, every polling panel, the webview panes) would go on
                    // as if nobody had switched tabs.
                    Builder(
                      builder: (context) => DockPaneVisibility(
                        visible: i == group.selected && DockPaneVisibility.of(context),
                        // A CONTAINER slot renders its whole subtree, bare: the
                        // groups inside it apply their own editing chrome and
                        // own their own drop regions, so wrapping them in this
                        // group's would leave a nested arrangement with no way
                        // to be rearranged.
                        child: _slotBody(group, i, showHeader: showHeader),
                      ),
                    ),
                ],
              ),
              // All three belong to a PANE. A container showing in this slot
              // is not one — it is a piece of layout, and the panes inside it
              // draw their own wash, bands and outline.
              if (widget.editing && !showingNested) const IgnorePointer(child: EditingPaneWash()),
              // Cross-faded rather than mounted outright: bands that appear
              // the instant a drag starts read as a flicker under the
              // pointer, and on drop they would vanish before the layout
              // they described has finished moving.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: _dragging == null || showingNested
                    ? const SizedBox.shrink()
                    : DockGroupDropRegions(
                        washAlpha: _hitWashAlpha,
                        onDrop: (id, drop) =>
                            drop.nest ? _handleNestDrop(id, group, above: drop.region == DockRegion.top) : _handleDrop(id, group, drop.region),
                      ),
              ),
              // Last, so the outline is over the drop bands too — otherwise
              // the pane being aimed at loses its own edges at the moment it
              // matters most.
              if (widget.editing && !showingNested)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: PaneFramePainter(topFromStrip: showHeader)),
                  ),
                ),
              // Above the frame and the wash both: it is the only thing in a
              // headerless pane that is still a control while editing, so
              // nothing may paint over it.
              if (floatingChrome)
                // `.fill`, not left/top alone: a Positioned with only two
                // edges hands its child UNBOUNDED constraints (nothing pins
                // the other two), so the reflow LayoutBuilder inside
                // FloatingPaneChrome could never see the pane's real width
                // and always chose the wide layout. Align keeps the content
                // shrink-wrapped within the now-bounded box — it gets LOOSE
                // constraints from Align, not the tight ones Positioned.fill
                // itself receives.
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(left: editingFrameWidth, top: editingFrameWidth),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: FloatingPaneChrome(
                        title: widget.titles[group.modules.first] ?? group.modules.first,
                        moduleId: group.modules.first,
                        pinned: widget.pinnedModuleIds.contains(group.modules.first),
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

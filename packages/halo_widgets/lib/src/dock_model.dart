// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The dock's definition and its selection: a JSON-serializable tree of
// splits and tab groups, and — kept apart from it on purpose — which tab
// each group shows. [DockNode] says why the two never share a class.

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

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
        // Nested containers, keyed by the SLOT they occupy in `modules`. Read
        // before the slots are filtered, since a slot naming a container that
        // does not parse is a slot with nothing behind it — dropped, rather
        // than left to render as a missing panel nobody can explain.
        final nested = <String, DockNode>{};
        if (json['nested'] case final Map<dynamic, dynamic> raw) {
          for (final entry in raw.entries) {
            final key = entry.key;
            final node = DockNode.fromJson(entry.value);
            if (key is String && node != null) {
              nested[key] = node;
            } else {
              // Every drop below is LOGGED, unlike an unknown plain module id,
              // which keeps its pane and says so on screen. A container has no
              // such pane to say it with, so a tab holding three panes can go
              // between launches — and without a line here a report of "my
              // panes disappeared" has nothing behind it.
              debugPrint('[layout] dropped container "$key" — its subtree does not parse');
            }
          }
        }
        nested.removeWhere((key, _) {
          if (modules.contains(key)) return false;
          debugPrint('[layout] dropped container "$key" — no tab holds it');
          return true;
        });
        // A slot is a container's id only if the container is actually there.
        // Anything left that looks like one and is not in [nested] names
        // nothing, so it goes.
        final slots = modules.where((m) {
          if (nested.containsKey(m) || !isDockContainerId(m)) return true;
          debugPrint('[layout] dropped slot "$m" — it names a container that is not there');
          return false;
        }).toList();
        if (slots.isEmpty) return null;
        // `selected` is deliberately NOT read, though older saved
        // definitions still carry one: it is state, and state has its own
        // store now. A definition written before the split simply opens on
        // its first tab once, and stops carrying the field when next saved.
        return DockGroup(slots, nested: nested)..collapseNested();
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

  /// Every MODULE id in this subtree, in visual order — the panes a view has
  /// to build. A nested container's own id is not one of them (it names no
  /// panel); its contents are, in its place. See [collectContainerIds].
  List<String> collectModules() => switch (this) {
    DockGroup(:final modules, :final nested) => [
      for (final m in modules)
        if (nested[m] case final node?) ...node.collectModules() else m,
    ],
    DockSplit(:final children) => [for (final c in children) ...c.collectModules()],
  };

  /// Every nested container's id in this subtree, in visual order. Apart from
  /// [collectModules] because the two answer different questions: a container
  /// has a tab, a title and layout options, but nothing builds a pane for it.
  List<String> collectContainerIds() => switch (this) {
    DockGroup(:final modules, :final nested) => [
      for (final m in modules)
        if (nested[m] case final node?) ...[m, ...node.collectContainerIds()],
    ],
    DockSplit(:final children) => [for (final c in children) ...c.collectContainerIds()],
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
      case DockGroup(:final modules, :final nested):
        final keptNested = <String, DockNode>{};
        final kept = <String>[];
        for (final slot in modules) {
          if (slot == id) continue;
          if (nested[slot] case final node?) {
            // A container whose whole contents were the retired module goes
            // with them; one left holding a single module hands that slot
            // back to it, which is the same collapse [collapseNested] makes.
            final inner = node.without(id);
            if (inner == null) continue;
            final single = inner.collectModules();
            if (single.length == 1 && inner.collectContainerIds().isEmpty) {
              kept.add(single.single);
            } else {
              kept.add(slot);
              keptNested[slot] = inner;
            }
          } else {
            kept.add(slot);
          }
        }
        return kept.isEmpty ? null : DockGroup(kept, nested: keptNested);
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

/// The prefix every nested container's id carries — see [DockGroup.nested].
/// Its own word rather than a panel key, because it names no panel: nothing
/// in the catalog answers for it, and a view must not try to build a pane for
/// one.
const dockContainerIdBase = 'nested';

/// Whether [id] names a nested container rather than a module.
bool isDockContainerId(String id) => id == dockContainerIdBase || id.startsWith('$dockContainerIdBase#');

/// A tabbed stack of TAB SLOTS. With a single slot the header still shows
/// its one tab — that IS the grab handle for a standalone pane.
///
/// A slot is ordinarily a module id. A slot listed in [nested] is instead a
/// **container**: the tab is still a tab, with its own title and layout
/// options, but what it holds is a whole subtree — the arrangement a drop on
/// this group's centre band builds (docs/design/layouts.md).
///
/// Two fields rather than one recursive list of nodes, because every consumer
/// in the app keys off a module id — titles, pane options, dock state,
/// headerless modules, minimum sizes — and all of them reach a container
/// unchanged this way, as does every arrangement saved before containers
/// existed. The price is one invariant, and it is this class's to keep:
/// **`nested`'s keys are always a subset of `modules`**. `fromJson` enforces
/// it on the way in; [collapseNested] is what holds it after a mutation.
class DockGroup extends DockNode {
  final List<String> modules;

  /// The subtree behind each container slot, keyed by that slot's id.
  final Map<String, DockNode> nested;

  int selected;

  DockGroup(this.modules, {Map<String, DockNode>? nested, this.selected = 0})
      : nested = nested ?? <String, DockNode>{};

  /// The subtree behind [slot], or null when it holds a plain module.
  DockNode? nestedIn(String slot) => nested[slot];

  /// Restores the invariant after a mutation, and applies the collapse rule:
  /// a container left holding ONE module hands its slot back to that module.
  ///
  /// A container holding one GROUP of several tabs is left alone — that is a
  /// tab set the operator built, and folding its tabs up into this strip
  /// would rearrange more than they did.
  void collapseNested() {
    nested.removeWhere((key, _) => !modules.contains(key));
    for (var i = 0; i < modules.length; i++) {
      final node = nested[modules[i]];
      if (node == null) continue;
      final inside = node.collectModules();
      if (inside.length == 1 && node.collectContainerIds().isEmpty) {
        nested.remove(modules[i]);
        // Handing the slot back only when it is free. A saved arrangement can
        // hold the same module both as a slot and inside a container here, and
        // a group listing one module twice hands one widget to two tabs:
        // `indexOf` always finds the first, so selection and every drop path
        // then act on the wrong one.
        if (modules.contains(inside.single)) {
          modules.removeAt(i);
          i--;
        } else {
          modules[i] = inside.single;
        }
      }
    }
    // A slot that named a container which is no longer there names nothing.
    for (var i = modules.length - 1; i >= 0; i--) {
      if (isDockContainerId(modules[i]) && !nested.containsKey(modules[i])) modules.removeAt(i);
    }
    if (modules.isNotEmpty) selected = selected.clamp(0, modules.length - 1);
  }

  /// Copies rather than aliasing the live list: a caller holding a snapshot
  /// of the arrangement (the layout editor's revert target) would otherwise
  /// watch it change under them as panes move.
  @override
  Map<String, dynamic> toJson() => {
    'type': 'group',
    'modules': List<String>.of(modules),
    // Omitted entirely when empty, so an arrangement with no containers
    // serializes to exactly what it always did.
    if (nested.isNotEmpty) 'nested': {for (final e in nested.entries) e.key: e.value.toJson()},
  };
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
      case DockGroup(:final modules, :final nested, :final selected):
        if (modules.isNotEmpty) yield modules[selected.clamp(0, modules.length - 1)];
        // Every container, not only the showing one: a container behind
        // another tab still remembers which of ITS panes was on top, and a
        // state that only reached the visible branch would forget that the
        // moment the operator looked elsewhere.
        for (final subtree in nested.values) {
          yield* _selectedIn(subtree);
        }
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
      case DockGroup(:final modules, :final nested):
        final index = modules.indexWhere(selected.contains);
        if (index >= 0) node.selected = index;
        for (final subtree in nested.values) {
          applyTo(subtree);
        }
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

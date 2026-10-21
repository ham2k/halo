// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A layout drawn small, with a tick on every panel — what the export and
// import dialogs show so the operator can take part of one rather than all
// of it (docs/design/layouts.md § Layout files).

import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

/// The shape the diagram draws, built from a dock tree (export) or a layout
/// file (import) — the two name their panes differently, so each tab carries
/// its own [LayoutDiagramTab.key] for the selection to hold.
sealed class LayoutDiagramNode {
  const LayoutDiagramNode();
}

class LayoutDiagramSplit extends LayoutDiagramNode {
  final Axis axis;
  final List<LayoutDiagramNode> children;
  final List<double> weights;
  const LayoutDiagramSplit(this.axis, this.children, this.weights);
}

class LayoutDiagramGroup extends LayoutDiagramNode {
  final List<LayoutDiagramTab> tabs;
  const LayoutDiagramGroup(this.tabs);
}

class LayoutDiagramTab {
  /// What the selection holds for a panel tab. Unused for a container, whose
  /// tick stands for everything inside it.
  final Object key;
  final String label;
  final LayoutDiagramNode? container;

  /// Said under the label — why a tab cannot be picked, or what it needs.
  final String? note;

  /// False for a tab that cannot be picked at all; it is drawn unticked.
  final bool enabled;

  const LayoutDiagramTab({required this.key, required this.label, this.container, this.note, this.enabled = true});
}

/// Every pickable panel under [node].
Set<Object> layoutDiagramLeaves(LayoutDiagramNode node) => switch (node) {
  LayoutDiagramSplit(:final children) => {for (final child in children) ...layoutDiagramLeaves(child)},
  LayoutDiagramGroup(:final tabs) => {
    for (final tab in tabs)
      if (tab.container case final inner?) ...layoutDiagramLeaves(inner) else if (tab.enabled) tab.key,
  },
};

/// [root] drawn as boxes in the proportions of its splits, a tick beside
/// each panel and one over each tab set and container for all of it.
class LayoutDiagram extends StatelessWidget {
  final LayoutDiagramNode root;
  final Set<Object> selected;
  final ValueChanged<Set<Object>> onChanged;
  final double height;

  const LayoutDiagram({super.key, required this.root, required this.selected, required this.onChanged, this.height = 240});

  @override
  Widget build(BuildContext context) => SizedBox(height: height, child: _node(context, root));

  Widget _node(BuildContext context, LayoutDiagramNode node) => switch (node) {
    LayoutDiagramSplit(:final axis, :final children, :final weights) => Flex(
      direction: axis,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: axis == Axis.horizontal ? Space.xs : 0, height: axis == Axis.vertical ? Space.xs : 0),
          Expanded(flex: _flex(weights, i), child: _node(context, children[i])),
        ],
      ],
    ),
    LayoutDiagramGroup(:final tabs) => _group(context, tabs),
  };

  /// Weights as integer flex factors, kept proportional and never zero.
  static int _flex(List<double> weights, int index) {
    final total = weights.fold(0.0, (a, b) => a + b);
    return total <= 0 ? 1 : (weights[index] / total * 1000).round().clamp(1, 1000);
  }

  Widget _group(BuildContext context, List<LayoutDiagramTab> tabs) {
    final theme = Theme.of(context);
    final leaves = layoutDiagramLeaves(LayoutDiagramGroup(tabs));
    // One tick for the whole tab set, only where there is more than one thing
    // in it to tick; its tabs are indented under it.
    final asSet = tabs.length > 1 && leaves.isNotEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(Space.xs),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (asSet)
            ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest,
              child: _tick(context, label: context.t.operation.layout.layouts.tabSet, keys: leaves),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(left: asSet ? Space.xxl : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final tab in tabs)
                    if (tab.container case final inner?)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _tick(context, label: tab.label, keys: layoutDiagramLeaves(inner)),
                          // Indented under the container's tick, the way a tab
                          // set's tabs are under its own.
                          Padding(
                            padding: const EdgeInsets.only(left: Space.xxl, right: Space.xxs, bottom: Space.xxs),
                            child: SizedBox(height: height / 2, child: _node(context, inner)),
                          ),
                        ],
                      )
                    else
                      _tick(context, label: tab.label, keys: {if (tab.enabled) tab.key}, note: tab.note, enabled: tab.enabled),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A tick for [keys] — on when all are picked, mixed when some are.
  Widget _tick(BuildContext context, {required String? label, required Set<Object> keys, String? note, bool enabled = true}) {
    final theme = Theme.of(context);
    final picked = keys.where(selected.contains).length;
    final value = keys.isEmpty || picked == 0 ? false : (picked == keys.length ? true : null);
    final canToggle = enabled && keys.isNotEmpty;
    void toggle() => onChanged(value == true ? ({...selected}..removeAll(keys)) : {...selected, ...keys});
    return InkWell(
      onTap: canToggle ? toggle : null,
      child: Row(
        children: [
          Checkbox(
            value: value,
            tristate: true,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: canToggle ? (_) => toggle() : null,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label != null)
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: enabled ? null : theme.disabledColor),
                  ),
                if (note != null)
                  Text(
                    note,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

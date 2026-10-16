// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One Operation Summaries pane's settings: which of the operation's sections
// it shows, and in what order. The one widget behind both routes in — the
// tab's settings button and the pane layout options' embed — so the panel
// offers one settings surface whichever way the operator came
// (docs/design/layouts.md). Saves as it goes, like the rest of that embed.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../../services/panel_service.dart';
import '../postcard_summary.dart' show postcardSectionsOrder;
import 'operation_summaries_panel.dart';

class OperationSummariesSettings extends StatefulWidget {
  final String panelId;
  final PanelService panels;

  /// This operation's sections, as the pane builds them. Only their keys,
  /// titles and icons are read.
  final List<SummarySection> sections;
  final SummariesConfigWrite write;

  const OperationSummariesSettings({super.key, required this.panelId, required this.panels, required this.sections, required this.write});

  @override
  State<OperationSummariesSettings> createState() => _OperationSummariesSettingsState();
}

class _OperationSummariesSettingsState extends State<OperationSummariesSettings> {
  List<String> _order = const [];
  Set<String> _hidden = const {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final panel = widget.panels[widget.panelId];
    if (panel == null) return;
    final config = await widget.panels.configFor(panel);
    if (!mounted) return;
    setState(() {
      _order = summariesKeyList(config[summariesOrderKey]);
      _hidden = summariesKeyList(config[summariesHiddenKey]).toSet();
    });
  }

  /// This operation's section keys, as they came — what an untouched pane
  /// shows.
  List<String> get _plainKeys => [for (final section in widget.sections) section.key];

  /// Whether THIS operation's sections differ from how they come — another
  /// operation's picks are not this one's to offer resetting.
  bool get _custom {
    final plain = _plainKeys;
    return _hidden.any(plain.contains) || !listEquals([for (final section in summarySectionsInOrder(widget.sections, order: _order)) section.key], plain);
  }

  Future<void> _save({required List<String> order, required Set<String> hidden}) async {
    // An order that only restates how the sections come is no order at all;
    // stored, it would pin a scorer first seen tomorrow after all of today's.
    final storedOrder = listEquals(order, _plainKeys) ? const <String>[] : order;
    setState(() {
      _order = storedOrder;
      _hidden = hidden;
    });
    try {
      await widget.write(summariesOrderKey, storedOrder.isEmpty ? null : storedOrder);
      await widget.write(summariesHiddenKey, hidden.isEmpty ? null : hidden.toList());
    } finally {
      // Even after a failed write: the pane re-reads whatever did land
      // rather than going on showing the picks from before.
      widget.panels.markConfigChanged(widget.panelId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.operation.layout.panels;
    final listed = summarySectionsInOrder(widget.sections, order: _order);
    final keys = [for (final section in listed) section.key];
    return ReorderableListView(
      // Scrolls itself in both places it is shown — the settings dialog and
      // the pane layout options' bounded region — so a dragged row can carry
      // the list past its visible end.
      shrinkWrap: true,
      buildDefaultDragHandles: false,
      header: SectionHeader(t.summariesSections),
      onReorderItem: (oldIndex, newIndex) {
        final picked = [...keys];
        picked.insert(newIndex, picked.removeAt(oldIndex));
        // Other operations' sections keep the places they were given.
        unawaited(
          _save(
            order: postcardSectionsOrder(_order, picked, here: {...keys}),
            hidden: _hidden,
          ),
        );
      },
      footer: _custom
          ? ListTile(
              leading: Icon(MdiIcons.restore),
              title: Text(t.summariesReset),
              // This operation's sections only: another operation's picks
              // stay where they were.
              onTap: () {
                final plain = {..._plainKeys};
                unawaited(_save(order: [..._order.where((key) => !plain.contains(key))], hidden: {..._hidden.where((key) => !plain.contains(key))}));
              },
            )
          : null,
      children: [
        for (final (index, section) in listed.indexed)
          ListTile(
            key: ValueKey(section.key),
            leading: ReorderableDragStartListener(index: index, child: Icon(MdiIcons.dragHorizontalVariant)),
            title: Row(
              children: [
                if (section.icon case final icon?) ...[Icon(resolveIconName(icon), size: 18, color: section.iconColor), const SizedBox(width: Space.lg)],
                Flexible(child: Text(section.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            trailing: Checkbox(
              value: !_hidden.contains(section.key),
              onChanged: (checked) =>
                  unawaited(_save(order: _order, hidden: checked == true ? ({..._hidden}..remove(section.key)) : {..._hidden, section.key})),
            ),
          ),
      ],
    );
  }
}

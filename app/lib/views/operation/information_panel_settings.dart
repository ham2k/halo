// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One Info pane's settings: the face it is drawn on, then which of the
// operation's sections it shows, and in what order — the Operation Postcard
// options' picker over the pane's own sections. The Summaries pane's too,
// being that pane. The one widget behind both routes in, the tab's settings
// button and the pane layout options' embed, and saves as it goes in both.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../services/panel_service.dart';
import 'information_panel.dart';
import 'summaries/operation_summaries_panel.dart' show summariesKeyList;

class InformationPanelSettings extends StatefulWidget {
  final String panelId;
  final PanelService panels;

  /// This operation's sections, as the pane builds them. Only their keys,
  /// titles and icons are read.
  final List<InfoSection> sections;

  const InformationPanelSettings({super.key, required this.panelId, required this.panels, required this.sections});

  @override
  State<InformationPanelSettings> createState() => _InformationPanelSettingsState();
}

class _InformationPanelSettingsState extends State<InformationPanelSettings> {
  List<String> _order = const [];
  Set<String> _hidden = const {};
  String? _theme;
  String? _checklistStyle;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final panel = widget.panels[widget.panelId];
    if (panel == null) {
      setState(() => _loaded = true);
      return;
    }
    final config = await widget.panels.configFor(panel);
    if (!mounted) return;
    setState(() {
      _order = summariesKeyList(config[infoOrderKey]);
      _hidden = summariesKeyList(config[infoHiddenKey]).toSet();
      _theme = config[infoThemeKey] as String?;
      _checklistStyle = config[infoChecklistStyleKey] as String?;
      _loaded = true;
    });
  }

  /// This operation's section keys, as they came — what an untouched pane
  /// shows.
  List<String> get _plainKeys => [for (final section in widget.sections) section.key];

  /// Whether THIS operation's sections differ from how they come — another
  /// operation's picks are not this one's to offer resetting.
  bool get _custom {
    final plain = _plainKeys;
    return _hidden.any(plain.contains) || !listEquals([for (final section in infoSectionsInOrder(widget.sections, order: _order)) section.key], plain);
  }

  Future<void> _write(Map<String, dynamic> values) async {
    final panel = widget.panels[widget.panelId];
    if (panel == null) return;
    // Bumps the pane's revision, even after a failed write: the pane
    // re-reads whatever did land rather than going on showing the picks from
    // before. These settings re-read it too.
    try {
      await widget.panels.writeConfig(panel, values, notify: false);
    } catch (_) {
      if (mounted) unawaited(_load());
      rethrow;
    } finally {
      widget.panels.markConfigChanged(widget.panelId);
    }
  }

  Future<void> _saveSections({required List<String> order, required Set<String> hidden}) {
    setState(() {
      _order = order;
      _hidden = hidden;
    });
    return _write({infoOrderKey: order.isEmpty ? null : order, infoHiddenKey: hidden.isEmpty ? null : hidden.toList()});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.operation.layout.panels;
    final listed = infoSectionsInOrder(widget.sections, order: _order);
    final keys = [for (final section in listed) section.key];
    // Slivers, so the theme's form, the sections and the reset scroll as one
    // list in both places this is shown — the settings dialog and the pane
    // layout options' bounded region — and a dragged row can carry the list
    // past its visible end.
    return CustomScrollView(
      shrinkWrap: true,
      slivers: [
        // Drawn by the form renderer, as every panel's own fields are, once
        // the stored picks have loaded: it reads its initial state only once,
        // so a re-read that finds other values draws a new one.
        if (_loaded)
          FormRenderer(
            key: ValueKey((_theme, _checklistStyle)),
            formDefinition: {
              'elements': [
                {
                  'type': 'field',
                  'key': infoThemeKey,
                  'fieldType': 'select',
                  'label': t.infoTheme,
                  'options': [
                    {'value': infoAppTheme, 'label': t.infoThemeApp},
                    {'value': 'gray', 'label': t.infoThemeGray},
                    {'value': 'muted', 'label': t.infoThemeMuted},
                    {'value': 'contrast', 'label': t.infoThemeContrast},
                    {'value': 'teal', 'label': t.infoThemeTeal},
                  ],
                },
                {
                  'type': 'field',
                  'key': infoChecklistStyleKey,
                  'fieldType': 'select',
                  'label': t.infoChecklistStyle,
                  'options': [
                    {'value': infoHighlightPending, 'label': t.infoHighlightPending},
                    {'value': infoHighlightWorked, 'label': t.infoHighlightWorked},
                  ],
                },
              ],
            },
            initialState: {infoThemeKey: _theme ?? infoAppTheme, infoChecklistStyleKey: _checklistStyle ?? infoHighlightPending},
            showActions: false,
            showTitle: false,
            sliver: true,
            settingsList: true,
            onChange: (key, value, state) async {
              // Each one's default is stored as none.
              final stored = value == infoAppTheme || value == infoHighlightPending ? null : value as String?;
              setState(() => key == infoThemeKey ? _theme = stored : _checklistStyle = stored);
              // Not awaited: the form renderer would swallow a failed write
              // whole, where unawaited it reaches ErrorPolicy.
              unawaited(_write({key: stored}));
              return null;
            },
            onSubmit: (_) {},
            onCancel: () {},
          ),
        // Not until the stored picks have loaded either: a tick or a drag
        // made from none would overwrite them all.
        if (_loaded) SliverToBoxAdapter(child: SectionHeader(t.summariesSections)),
        if (_loaded)
          SliverReorderableList(
            itemCount: listed.length,
            onReorderItem: (oldIndex, newIndex) {
              final picked = [...keys];
              picked.insert(newIndex, picked.removeAt(oldIndex));
              // Other operations' sections keep the places they were given.
              unawaited(
                _saveSections(
                  order: infoOrderAfterDrag(_order, picked, here: {...keys}, plain: _plainKeys),
                  hidden: _hidden,
                ),
              );
            },
            itemBuilder: (context, index) {
              final section = listed[index];
              return Material(
                key: ValueKey(section.key),
                type: MaterialType.transparency,
                child: ListTile(
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
                        unawaited(_saveSections(order: _order, hidden: checked == true ? ({..._hidden}..remove(section.key)) : {..._hidden, section.key})),
                  ),
                ),
              );
            },
          ),
        // Always there, so it is found where it is looked for; live only
        // once there is something to put back.
        if (_loaded)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.xl, Space.md, Space.xl, Space.xl),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  icon: Icon(MdiIcons.restore),
                  label: Text(t.summariesReset),
                  // This operation's sections only: another operation's
                  // picks stay where they were.
                  onPressed: _custom
                      ? () {
                          final plain = {..._plainKeys};
                          unawaited(
                            _saveSections(order: [..._order.where((key) => !plain.contains(key))], hidden: {..._hidden.where((key) => !plain.contains(key))}),
                          );
                        }
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

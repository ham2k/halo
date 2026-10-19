// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Operation Postcard's options: whether the map page carries its band
// legend and its grayline, then which of the summary sections go on the pages after it, and
// in what order — the logging panel's own show/hide-and-reorder dialog
// (showControlSettingsDialog) over the summary's sections instead.

import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'postcard_summary.dart';

/// A summary section as the picker lists it.
typedef PostcardSectionChoice = ({String key, String label, String? icon, Color? iconColor});

/// One entry per section key in [sections], in their order, named and marked
/// as the first section of each is — but every day's section goes under
/// [daysLabel], one entry for all of them.
List<PostcardSectionChoice> postcardSectionChoices(List<PostcardSummarySection> sections, {required String daysLabel}) {
  final choices = <String, PostcardSectionChoice>{};
  for (final section in sections) {
    final heading = section.heading;
    choices[section.key] ??= (
      key: section.key,
      label: section.key == PostcardSummarySection.daysKey ? daysLabel : heading.title,
      icon: heading.icon,
      iconColor: heading.iconColor,
    );
  }
  return [...choices.values];
}

/// What the dialog resolved to: whether to draw the legend and the grayline,
/// and the order and the hidden keys to keep — or, with [reset], the legend
/// back on, the grayline off, none of either, and every pick ever made
/// forgotten.
typedef PostcardOptionsPick = ({bool legend, bool grayline, List<String> order, Set<String> hidden, bool reset});

/// The legend's and the grayline's switches, then the picker over [choices], listed in their order
/// with those in [hidden] unticked — the picker left out where there are no
/// sections. Offers a reset where there are [custom] picks. Resolves to what
/// to keep, or null when cancelled.
Future<PostcardOptionsPick?> showPostcardOptionsDialog(
  BuildContext context, {
  required bool legend,
  required bool grayline,
  required List<PostcardSectionChoice> choices,
  required Set<String> hidden,
  bool custom = false,
}) {
  final byKey = {for (final choice in choices) choice.key: choice};
  var order = [for (final choice in choices) choice.key];
  var unticked = {...hidden.where(byKey.containsKey)};
  var showLegend = legend;
  var showGrayline = grayline;

  return showHaloDialog<PostcardOptionsPick>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        final t = context.t.map.postcard;
        return HaloDialog(
          title: Text(t.options),
          // The ReorderableListView scrolls itself, so the shell must not —
          // see showControlSettingsDialog.
          scrollable: false,
          wide: true,
          list: true,
          content: SizedBox(
            width: 360,
            child: ReorderableListView(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              header: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    leading: Icon(MdiIcons.mapLegend),
                    title: Text(t.bandLegend),
                    trailing: Checkbox(value: showLegend, onChanged: (checked) => setDialogState(() => showLegend = checked == true)),
                    onTap: () => setDialogState(() => showLegend = !showLegend),
                  ),
                  ListTile(
                    leading: Icon(MdiIcons.weatherNight),
                    title: Text(t.grayline),
                    trailing: Checkbox(value: showGrayline, onChanged: (checked) => setDialogState(() => showGrayline = checked == true)),
                    onTap: () => setDialogState(() => showGrayline = !showGrayline),
                  ),
                  if (choices.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.lg),
                      child: SectionHeader(t.sectionsAndOrder),
                    ),
                ],
              ),
              onReorderItem: (oldIndex, newIndex) => setDialogState(() {
                final reordered = List<String>.from(order);
                final key = reordered.removeAt(oldIndex);
                reordered.insert(newIndex, key);
                order = reordered;
              }),
              children: [
                for (final (index, key) in order.indexed)
                  if (byKey[key] case final choice?)
                    ListTile(
                      key: ValueKey(key),
                      leading: ReorderableDragStartListener(index: index, child: Icon(MdiIcons.dragHorizontalVariant)),
                      title: Row(
                        children: [
                          if (choice.icon case final icon?) ...[
                            Icon(resolveIconName(icon), size: 18, color: choice.iconColor),
                            const SizedBox(width: Space.lg),
                          ],
                          Flexible(child: Text(choice.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      trailing: Checkbox(
                        value: !unticked.contains(key),
                        onChanged: (checked) => setDialogState(() {
                          unticked = checked == true ? ({...unticked}..remove(key)) : {...unticked, key};
                        }),
                      ),
                    ),
              ],
            ),
          ),
          tools: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: custom
                  ? () => Navigator.of(dialogContext).pop((legend: true, grayline: false, order: const <String>[], hidden: const <String>{}, reset: true))
                  : null,
              child: Text(t.reset),
            ),
          ),
          cancel: TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(context.t.common.cancel)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop((legend: showLegend, grayline: showGrayline, order: order, hidden: unticked, reset: false)),
              child: Text(context.t.common.save),
            ),
          ],
        );
      },
    ),
  );
}

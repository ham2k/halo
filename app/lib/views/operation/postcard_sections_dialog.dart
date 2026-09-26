// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which of the Operation Postcard's summary sections go on its pages, and in
// what order: the logging panel's own show/hide-and-reorder dialog
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

/// What the picker resolved to: the order and the hidden keys to keep — or,
/// with [reset], none of either, and every pick ever made forgotten.
typedef PostcardSectionsPick = ({List<String> order, Set<String> hidden, bool reset});

/// The picker over [choices], listed in their order with those in [hidden]
/// unticked, offering to reset the picks where there are [custom] ones.
/// Resolves to what to keep, or null when cancelled.
Future<PostcardSectionsPick?> showPostcardSectionsDialog(
  BuildContext context, {
  required List<PostcardSectionChoice> choices,
  required Set<String> hidden,
  bool custom = false,
}) {
  final byKey = {for (final choice in choices) choice.key: choice};
  var order = [for (final choice in choices) choice.key];
  var unticked = {...hidden.where(byKey.containsKey)};

  return showHaloDialog<PostcardSectionsPick>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        final t = context.t.map.postcard;
        return HaloDialog(
          title: Text(t.sections),
          // The ReorderableListView scrolls itself, so the shell must not —
          // see showControlSettingsDialog.
          scrollable: false,
          wide: true,
          content: SizedBox(
            width: 360,
            child: ReorderableListView(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
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
              onPressed: custom ? () => Navigator.of(dialogContext).pop((order: const <String>[], hidden: const <String>{}, reset: true)) : null,
              child: Text(t.reset),
            ),
          ),
          cancel: TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(context.t.common.cancel)),
          actions: [
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop((order: order, hidden: unticked, reset: false)), child: Text(context.t.common.save)),
          ],
        );
      },
    ),
  );
}

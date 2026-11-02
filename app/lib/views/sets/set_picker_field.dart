// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The picker for a kind of named set (SetCategory): one dropdown, folders as
// headers with their sets indented under them, and — pinned under the list,
// however long it grows — the way into the set manager.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../services/halo_services.dart';
import '../../services/sets/set_category.dart';
import '../../services/sets/set_tree.dart';
import 'set_manager_pane.dart';

/// How far in each folder level indents its rows.
const setTreeIndent = Space.xl;

class SetPickerField extends StatefulWidget {
  final HaLoServices services;
  final SetCategory category;
  final String label;

  /// The set shown as picked.
  final String value;
  final ValueChanged<String> onChanged;

  const SetPickerField({super.key, required this.services, required this.category, required this.label, required this.value, required this.onChanged});

  @override
  State<SetPickerField> createState() => _SetPickerFieldState();
}

class _SetPickerFieldState extends State<SetPickerField> {
  final _controller = MenuController();

  /// The menu's own padding either side of a row's content, as
  /// [MenuItemButton] lays it out.
  static const _itemPadding = Space.md * 2;

  /// What the pinned footer and its divider take from the menu's height.
  static const _footerHeight = 64.0;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.category.listenable,
    builder: (context, _) => LayoutBuilder(builder: (context, constraints) => _build(context, constraints.maxWidth.isFinite ? constraints.maxWidth : 320)),
  );

  Widget _build(BuildContext context, double width) {
    final theme = Theme.of(context);
    final category = widget.category;
    final names = {for (final set in category.sets) set.id: set.name};
    final tree = category.tree;
    final open = category.openFolders;
    final muted = theme.colorScheme.onSurfaceVariant;
    final itemWidth = width > _itemPadding ? width - _itemPadding : null;
    return MenuAnchor(
      controller: _controller,
      style: MenuStyle(
        minimumSize: WidgetStatePropertyAll(Size(width, 0)),
        maximumSize: WidgetStatePropertyAll(Size(width, dropdownMenuMaxHeight(context))),
        alignment: Alignment.bottomLeft,
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      menuChildren: [
        PlatformViewShield(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The sets scroll; the footer below them does not, so the way
              // into the manager is there at the end of a list of fifty as
              // much as of two.
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: math.max(0, dropdownMenuMaxHeight(context) - _footerHeight)),
                // Not the primary controller: the menu panel's own scroll view
                // already holds it, and a scrollbar on two positions asserts.
                child: SingleChildScrollView(
                  primary: false,
                  padding: const EdgeInsets.symmetric(vertical: Space.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final row in tree.rows([for (final set in category.sets) set.id], open: open))
                        switch (row) {
                          // A folder is a heading, not a choice: it holds sets,
                          // and is never one. Pressing it opens or closes it,
                          // with the menu left open to pick from what it shows.
                          SetTreeFolderRow(:final folder, :final depth) => MenuItemButton(
                            closeOnActivate: false,
                            onPressed: () => category.toggleFolder(folder.id),
                            child: SizedBox(
                              width: itemWidth,
                              child: Padding(
                                padding: EdgeInsets.only(left: depth * setTreeIndent),
                                child: Row(
                                  children: [
                                    Icon(open.contains(folder.id) ? MdiIcons.chevronDown : MdiIcons.chevronRight, size: 18, color: muted),
                                    const SizedBox(width: Space.xs),
                                    Icon(open.contains(folder.id) ? MdiIcons.folderOpenOutline : MdiIcons.folderOutline, size: 18, color: muted),
                                    const SizedBox(width: Space.sm),
                                    Expanded(
                                      child: Text(
                                        folder.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelLarge?.copyWith(color: muted),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SetTreeSetRow(:final id, :final depth) => MenuItemButton(
                            onPressed: () => widget.onChanged(id),
                            child: SizedBox(
                              width: itemWidth,
                              child: Padding(
                                padding: EdgeInsets.only(left: depth * setTreeIndent),
                                child: Text(
                                  names[id] ?? '?',
                                  overflow: TextOverflow.ellipsis,
                                  style: id == widget.value ? TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.primary) : null,
                                ),
                              ),
                            ),
                          ),
                        },
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                child: MenuItemButton(
                  leadingIcon: const Icon(MdiIcons.folderCogOutline, size: 18),
                  onPressed: () => showSetManagerPane(context, widget.services, category),
                  child: Text(category.manageLabel),
                ),
              ),
            ],
          ),
        ),
      ],
      builder: (context, controller, _) => InkWell(
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        child: InputDecorator(
          decoration: poloFieldDecoration(context, widget.label).copyWith(suffixIcon: dropdownTrailingIcon, filled: true, fillColor: theme.colorScheme.surface),
          child: Text(names[widget.value] ?? '?', overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The picker for a kind of named set (SetCategory): one dropdown, folders as
// headers with their sets indented under them, and — pinned under the list,
// however long it grows — the way into the set manager.
//
// Drawn as the app's other dropdowns are, DropdownButtonFormField's: the
// same field, arrow and hover, and a modal list that a tap outside closes
// without reaching what is under it. Not that widget itself: a folder opens
// in place with the list left up, and the footer stays put while the sets
// scroll, neither of which its menu can do.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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

/// What the list closed on: a set, or the way into the manager.
sealed class _Choice {}

class _PickedSet extends _Choice {
  final String id;
  _PickedSet(this.id);
}

class _ManageSets extends _Choice {}

class _SetPickerFieldState extends State<SetPickerField> with WidgetsBindingObserver {
  final _focusNode = FocusNode(debugLabel: 'SetPickerField');
  bool _hovering = false;

  /// DropdownButton's own: its icon size, and the margin it puts after the
  /// icon in a filled field.
  static const _iconSize = 24.0;
  static const _iconEndMargin = 12.0;

  /// The open list, while it is.
  _SetPickerRoute? _route;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_focusChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  /// The list is placed against the field once, when it opens: a window
  /// resized or turned under it leaves it adrift, so it closes, as the
  /// framework's dropdown does.
  @override
  void didChangeMetrics() {
    if (_route case final route? when route.isActive) route.navigator?.removeRoute(route);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode
      ..removeListener(_focusChanged)
      ..dispose();
    super.dispose();
  }

  void _focusChanged() => setState(() {});

  Future<void> _open() async {
    final navigator = Navigator.of(context);
    final field = context.findRenderObject()! as RenderBox;
    final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
    final choice = await navigator.push(
      _route = _SetPickerRoute(
        anchor: field.localToGlobal(Offset.zero, ancestor: overlay) & field.size,
        category: widget.category,
        value: widget.value,
        capturedThemes: InheritedTheme.capture(from: context, to: navigator.context),
        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      ),
    );
    _route = null;
    if (!mounted) return;
    switch (choice) {
      case _PickedSet(:final id):
        widget.onChanged(id);
      case _ManageSets():
        await showSetManagerPane(context, widget.services, widget.category);
      case null:
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: widget.category.listenable, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    final category = widget.category;
    final tree = category.tree;
    final name = category.sets.where((set) => set.id == widget.value).firstOrNull?.name ?? '?';
    final iconColor = theme.brightness == Brightness.dark ? Colors.white70 : Colors.grey.shade700;
    return Actions(
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _open())},
      child: Semantics(
        button: true,
        child: Focus(
          focusNode: _focusNode,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovering = true),
            onExit: (_) => setState(() => _hovering = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _open,
              child: InputDecorator(
                decoration: poloFieldDecoration(context, widget.label).copyWith(
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  suffixIconConstraints: const BoxConstraints(minWidth: _iconSize + _iconEndMargin, minHeight: _iconSize),
                  suffixIcon: Padding(
                    padding: const EdgeInsetsDirectional.only(end: _iconEndMargin),
                    child: IconTheme(
                      data: IconThemeData(color: iconColor, size: _iconSize),
                      child: dropdownTrailingIcon,
                    ),
                  ),
                ),
                isFocused: _focusNode.hasPrimaryFocus,
                isHovering: _hovering,
                // The folders the set is filed in come first, so two sets with
                // the same name in different folders read apart once picked.
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (tree.folderOf(widget.value) case final folder?)
                        TextSpan(
                          text: '${tree.pathOf(folder).join(' / ')} / ',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      TextSpan(text: name),
                    ],
                  ),
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The open list, as a route of its own over everything: modal, as the
/// framework's dropdown menu is.
class _SetPickerRoute extends PopupRoute<_Choice> {
  /// The field, in the navigator's overlay's coordinates.
  final Rect anchor;
  final SetCategory category;
  final String value;
  final CapturedThemes capturedThemes;

  @override
  final String barrierLabel;

  _SetPickerRoute({required this.anchor, required this.category, required this.value, required this.capturedThemes, required this.barrierLabel});

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: HoldSizeWhileCovered(
      child: CustomSingleChildLayout(
        delegate: _BelowOrAbove(anchor: anchor, maxHeight: dropdownMenuMaxHeight(context)),
        child: capturedThemes.wrap(_SetPickerMenu(category: category, value: value)),
      ),
    ),
  );
}

/// The list under the field where it fits, over it where there is more room
/// above, at the field's width either way.
class _BelowOrAbove extends SingleChildLayoutDelegate {
  final Rect anchor;
  final double maxHeight;

  const _BelowOrAbove({required this.anchor, required this.maxHeight});

  /// What the list keeps from the screen's edges.
  static const _margin = Space.md;

  double _below(Size size) => size.height - anchor.bottom - _margin;
  double _above() => anchor.top - _margin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => BoxConstraints(
    minWidth: anchor.width,
    maxWidth: anchor.width,
    maxHeight: math.max(0.0, math.min(maxHeight, math.max(_below(constraints.biggest), _above()))),
  );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final below = childSize.height <= _below(size) || _below(size) >= _above();
    final left = clampDouble(anchor.left, 0, math.max(0, size.width - childSize.width));
    return Offset(left, below ? anchor.bottom : anchor.top - childSize.height);
  }

  @override
  bool shouldRelayout(_BelowOrAbove old) => anchor != old.anchor || maxHeight != old.maxHeight;
}

class _SetPickerMenu extends StatelessWidget {
  final SetCategory category;
  final String value;

  const _SetPickerMenu({required this.category, required this.value});

  /// The framework dropdown's row height and padding.
  static const _rowHeight = kMinInteractiveDimension;
  static const _rowPadding = EdgeInsets.symmetric(horizontal: Space.xl);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      // The framework dropdown's menu: the canvas, raised 8, corners of 2.
      color: theme.canvasColor,
      elevation: 8,
      borderRadius: const BorderRadius.all(Radius.circular(2)),
      clipBehavior: Clip.antiAlias,
      child: PlatformViewShield(
        child: DefaultTextStyle(
          style: theme.textTheme.titleMedium ?? const TextStyle(),
          child: ListenableBuilder(listenable: category.listenable, builder: (context, _) => _build(context, theme)),
        ),
      ),
    );
  }

  Widget _build(BuildContext context, ThemeData theme) {
    final names = {for (final set in category.sets) set.id: set.name};
    final open = category.openFolders;
    final muted = theme.colorScheme.onSurfaceVariant;
    final touch = FocusManager.instance.highlightMode == FocusHighlightMode.touch;
    Widget row({required VoidCallback onTap, required Widget child, bool selected = false, int depth = 0}) {
      final content = SizedBox(
        height: _rowHeight,
        child: Padding(
          padding: _rowPadding.add(EdgeInsetsDirectional.only(start: depth * setTreeIndent)),
          child: Align(alignment: AlignmentDirectional.centerStart, child: child),
        ),
      );
      // As the framework dropdown marks the picked row: focused, which the
      // focus highlight shows, and where that is not drawn, painted so.
      return InkWell(
        autofocus: selected,
        onTap: onTap,
        child: selected && touch ? Ink(color: theme.focusColor, child: content) : content,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The sets scroll; the footer below them does not, so the way into
        // the manager is there at the end of a list of fifty as much as of two.
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: Space.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in category.tree.rows([for (final set in category.sets) set.id], open: open))
                  switch (entry) {
                    // A folder is a heading, not a choice: it holds sets, and
                    // is never one. Pressing it opens or closes it, with the
                    // list left up to pick from what it shows.
                    SetTreeFolderRow(:final folder, :final depth) => row(
                      depth: depth,
                      onTap: () => category.toggleFolder(folder.id),
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
                    SetTreeSetRow(:final id, :final depth) => row(
                      depth: depth,
                      selected: id == value,
                      onTap: () => Navigator.of(context).pop(_PickedSet(id)),
                      child: Text(names[id] ?? '?', overflow: TextOverflow.ellipsis),
                    ),
                  },
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          child: row(
            onTap: () => Navigator.of(context).pop(_ManageSets()),
            child: Row(
              children: [
                const Icon(MdiIcons.folderCogOutline, size: 18),
                const SizedBox(width: Space.md),
                Expanded(child: Text(category.manageLabel, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The `fieldType: 'list'` field: its summary row or inline rows, the dialog
// that edits the list, and the item editor each row opens.

part of 'form_renderer.dart';

/// The callbacks a `fieldType: 'list'` editor needs — built by
/// [_ListFields._listFieldActions], shared by both presentations
/// (`_buildInlineListField`'s inline rows and `_openListEditor`'s dialog).
/// Deleting is the item editor's own footer button, not a row's.
class _ListFieldActions {
  final Future<void> Function(int? index) editItem;
  final void Function(int oldIndex, int newIndex) reorder;

  /// Sets the list's `itemSwitch` key on one item, from its row's switch.
  final void Function(int index, bool on) setSwitch;

  const _ListFieldActions({required this.editItem, required this.reorder, required this.setSwitch});
}

/// [FormRendererState]'s list fields. The members declared abstract below are
/// the state's own, which every field type shares.
mixin _ListFields on State<FormRenderer> {
  Map<String, dynamic> get _values;
  Map<String, String> get _errors;
  bool get _isSubmitting;
  EdgeInsetsGeometry get _rowContentPadding;
  Color? _devModeColor(Map<String, dynamic> el);
  Future<void> _handleFieldBlurOrInteraction(String key, dynamic value);

  String _listItemTitle(Map<String, dynamic> el, Map<String, dynamic> item) {
    final template = el['itemTitle'] as String?;
    return template != null
        ? _templateString(template, item)
        : item.values.firstWhere((v) => v != null && v.toString().isNotEmpty, orElse: () => '').toString();
  }

  /// The switch at the end of a list row, for a list declaring `itemSwitch`
  /// (the key of an on/off value in each item, which its editor then leaves
  /// out). An item without that key reads as on: a new item is on until
  /// switched off.
  Widget? _listItemSwitch(Map<String, dynamic> el, Map<String, dynamic> item, int index, _ListFieldActions actions) {
    final switchKey = el['itemSwitch'];
    if (switchKey is! String) return null;
    return Switch(value: item[switchKey] != false, onChanged: _isSubmitting ? null : (on) => actions.setSwitch(index, on));
  }

  /// A `fieldType: 'list'` field. `inline: true` renders the item rows (with
  /// a reorder handle per row, and an Add row) directly here
  /// — see [_buildInlineListField]. Otherwise: a single row summarizing the
  /// current items as a comma-separated list; tapping it opens
  /// [_openListEditor]'s dialog where the actual add/edit/delete/reorder
  /// happens.
  Widget _buildListField(Map<String, dynamic> el, ThemeData theme) {
    if (el['inline'] == true) return _buildInlineListField(el, theme);

    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    final description = el['description'] as String?;
    final icon = el['icon'] as String?;
    final errorText = _errors[key];
    final items = ((_values[key] as List?) ?? const []).cast<Map<String, dynamic>>();
    final devModeColor = _devModeColor(el);
    final summary = [
      for (final item in items)
        if (_listItemTitle(el, item).isNotEmpty) _listItemTitle(el, item),
    ].join(', ');

    Widget? subtitle;
    if (errorText != null) {
      subtitle = Text(errorText, style: TextStyle(color: theme.colorScheme.error, fontSize: 12));
    } else if (summary.isNotEmpty) {
      subtitle = Text(summary, style: TextStyle(color: devModeColor));
    } else if (description != null && description.isNotEmpty) {
      subtitle = Text(description, style: TextStyle(color: devModeColor));
    }

    return ListTile(
      contentPadding: _rowContentPadding,
      leading: icon != null ? Icon(resolveIconName(icon), color: devModeColor) : null,
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: devModeColor),
      ),
      subtitle: subtitle,
      trailing: Icon(MdiIcons.chevronRight, color: devModeColor ?? theme.colorScheme.onSurfaceVariant),
      onTap: _isSubmitting ? null : () => _openListEditor(el),
      mouseCursor: SystemMouseCursors.click,
    );
  }

  /// `inline: true`'s rendering: the same add/edit/delete/reorder behavior
  /// as [_openListEditor] (both built from [_listFieldActions]), just laid
  /// out directly in the form instead of behind a summary row that opens a
  /// dialog — for a list that IS the section's content (e.g. call-notes'
  /// custom files), not one field among several. Tapping a row (or Add)
  /// still opens the `itemFields` editor dialog; only the outer
  /// reorder/delete/add wrapper is inline instead of a second, nested
  /// dialog.
  Widget _buildInlineListField(Map<String, dynamic> el, ThemeData theme) {
    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    final itemLabel = el['itemLabel'] as String? ?? label;
    final orderable = el['orderable'] == true;
    final errorText = _errors[key];
    final items = ((_values[key] as List?) ?? const []).cast<Map<String, dynamic>>();
    final actions = _listFieldActions(context: context, key: key, el: el, items: items, itemLabel: itemLabel);

    Widget rowFor(int index) {
      final title = _listItemTitle(el, items[index]);
      return ListTile(
        key: ValueKey('$key-item-$index'),
        contentPadding: _rowContentPadding,
        // Leading, not trailing (unlike the dialog editor's drag handle) —
        // the drag gesture is scoped to just this icon via the listener
        // below, so it can't be confused with the row's own onTap.
        leading: orderable ? ReorderableDragStartListener(index: index, child: const Icon(MdiIcons.dragHorizontalVariant)) : null,
        title: Text(title.isEmpty ? t.formChrome.untitled : title),
        onTap: _isSubmitting ? null : () => actions.editItem(index),
        trailing: _listItemSwitch(el, items[index], index, actions),
        mouseCursor: SystemMouseCursors.click,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (errorText != null)
          Padding(
            padding: _rowContentPadding,
            child: Text(errorText, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
          ),
        if (orderable)
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // onReorderItem hands over already-adjusted indices, so the
            // move-down compensation in `actions.reorder` has to change with
            // the callback — a behaviour change that belongs to HALO-534.
            // ignore: deprecated_member_use
            onReorder: actions.reorder,
            // Otherwise, on a desktop/web (mouse) platform, the framework
            // auto-adds its OWN trailing drag handle to every row — landing
            // right on top of the row's switch, where it has one. rowFor already
            // wires up its own leading handle via ReorderableDragStartListener.
            buildDefaultDragHandles: false,
            children: [for (var i = 0; i < items.length; i++) rowFor(i)],
          )
        else
          for (var i = 0; i < items.length; i++) rowFor(i),
        Padding(
          padding: _rowContentPadding,
          child: TextButton.icon(
            onPressed: _isSubmitting ? null : () => actions.editItem(null),
            icon: const Icon(MdiIcons.plus, size: 18),
            label: Text(t.formChrome.addItem(label: itemLabel)),
          ),
        ),
      ],
    );
  }

  /// The add/edit/delete/reorder behavior shared by [_buildInlineListField]
  /// and [_openListEditor] — the only thing that differs between the two
  /// presentations is the surrounding chrome (an inline `Column` vs a
  /// `HaloDialog`) and each row's own layout, both of which stay with their
  /// respective callers. [items] is the current value list at the moment
  /// of the call — both callers already re-derive it from `_values[key]`
  /// on every rebuild they care about (the inline field's own `build`, or
  /// the dialog's `StatefulBuilder`), so a plain list is enough; nothing
  /// here needs to re-read it later. [afterCommit], when given, runs right
  /// after a commit's `setState` — only the dialog needs it, to also
  /// refresh its own `StatefulBuilder` (the inline field's `build` already
  /// covers that).
  _ListFieldActions _listFieldActions({
    required BuildContext context,
    required String key,
    required Map<String, dynamic> el,
    required List<Map<String, dynamic>> items,
    required String itemLabel,
    VoidCallback? afterCommit,
  }) {
    final itemFields = (el['itemFields'] as List? ?? const []).cast<Map<String, dynamic>>();

    Future<void> commit(List<Map<String, dynamic>> newItems) async {
      setState(() {
        _values[key] = newItems;
        _errors.remove(key);
      });
      afterCommit?.call();
      await _handleFieldBlurOrInteraction(key, newItems);
    }

    Future<void> editItem(int? index) async {
      final itemPath = '$key[${index ?? items.length}]';
      final initial = index != null ? Map<String, dynamic>.from(items[index]) : <String, dynamic>{};
      var deleted = false;
      final result = await showFormDialog(
        context,
        formDefinition: {
          'title': index != null ? t.formChrome.editItem(label: itemLabel) : t.formChrome.addItem(label: itemLabel),
          'elements': itemFields,
        },
        initialState: initial,
        validator: widget.validator == null ? null : (fieldKey, value, state) => widget.validator!('$itemPath.$fieldKey', value, state),
        transformer: widget.transformer == null ? null : (fieldKey, value, state) => widget.transformer!('$itemPath.$fieldKey', value, state),
        developerMode: widget.developerMode,
        // Only for an item that exists: there is nothing to delete while
        // adding one.
        destructiveAction: index == null
            ? null
            : (label: t.formChrome.removeItem, color: Theme.of(context).colorScheme.error, icon: MdiIcons.trashCanOutline, onPressed: () => deleted = true),
      );
      if (deleted && index != null) {
        // Asked once the editor has closed, as the station panel's Remove
        // does: the question is about the item, not about the form's unsaved
        // edits — and a Delete beside Save is an easy slip.
        final title = _listItemTitle(el, items[index]);
        if (!context.mounted) return;
        final confirmed = await showHaloDialog<bool>(
          context: context,
          builder: (context) => HaloDialog(
            title: Text(t.formChrome.deleteItemTitle(name: title.isEmpty ? itemLabel : title)),
            cancel: TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(t.common.cancel)),
            actions: [FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(t.formChrome.removeItem))],
          ),
        );
        if (confirmed == true) await commit(List<Map<String, dynamic>>.from(items)..removeAt(index));
        return;
      }
      if (result == null) return;
      final newItems = List<Map<String, dynamic>>.from(items);
      if (index != null) {
        // Merged over the item, not in place of it: keys the editor has no
        // field for — the row's `itemSwitch` among them — stay as they were.
        newItems[index] = {...items[index], ...result};
      } else {
        newItems.add(result);
      }
      await commit(newItems);
    }

    void setSwitch(int index, bool on) {
      final switchKey = el['itemSwitch'] as String?;
      if (switchKey == null) return;
      final newItems = List<Map<String, dynamic>>.from(items);
      newItems[index] = {...items[index], switchKey: on};
      commit(newItems);
    }

    void reorder(int oldIndex, int newIndex) {
      final newItems = List<Map<String, dynamic>>.from(items);
      if (newIndex > oldIndex) newIndex -= 1;
      newItems.insert(newIndex, newItems.removeAt(oldIndex));
      commit(newItems);
    }

    return _ListFieldActions(editItem: editItem, reorder: reorder, setSwitch: setSwitch);
  }

  /// The list field's editor dialog: a summary row per item plus an "Add"
  /// row. Every mutation commits immediately (autosave, like every other
  /// field) — Done just closes. Editing or adding an item reopens the same
  /// form renderer recursively (via [showFormDialog]) scoped to
  /// `itemFields`, so there's no separate "list item editor" widget — just
  /// a smaller [FormDefinition].
  Future<void> _openListEditor(Map<String, dynamic> el) async {
    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    // Matches _buildInlineListField's own fallback — without it, a non-inline
    // list field that declares itemLabel had it silently ignored here,
    // showing the plural container label in the Add/Edit dialog and button
    // instead.
    final itemLabel = el['itemLabel'] as String? ?? label;
    final orderable = el['orderable'] == true;

    await showHaloDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          // Read through _values each build so both this dialog and the
          // summary row behind it stay live.
          final items = ((_values[key] as List?) ?? const []).cast<Map<String, dynamic>>();
          final actions = _listFieldActions(
            context: dialogContext,
            key: key,
            el: el,
            items: items,
            itemLabel: itemLabel,
            // The inline field's own `build` already picks up a commit via
            // the outer setState; this dialog is a separate overlay that
            // needs telling explicitly to redraw with the new items.
            afterCommit: () => setDialogState(() {}),
          );

          Widget rowFor(int index) {
            final title = _listItemTitle(el, items[index]);
            return ListTile(
              key: ValueKey('$key-item-$index'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(title.isEmpty ? t.formChrome.untitled : title),
              onTap: _isSubmitting ? null : () => actions.editItem(index),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // A real drag listener, not decoration — with the
                  // framework's auto handle off below, this icon IS the
                  // drag affordance (same wiring as the inline editor's
                  // leading handle).
                  if (orderable) ReorderableDragStartListener(index: index, child: const Icon(MdiIcons.dragHorizontalVariant, size: 20)),
                  ?_listItemSwitch(el, items[index], index, actions),
                ],
              ),
            );
          }

          return HaloDialog(
            wide: true,
            title: Text(label),
            // Rows run edge to edge; the shell's own scroll view is off because
            // this content scrolls itself, and its width comes from the shared
            // sizing.
            contentPadding: EdgeInsets.zero,
            scrollable: false,
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (orderable)
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      // Same as the inline editor: on mouse platforms the
                      // framework auto-adds its own trailing handle to
                      // every row, doubling the row's own — the trailing
                      // icon above carries the ReorderableDragStartListener
                      // instead.
                      buildDefaultDragHandles: false,
                      // See the ReorderableListView above — HALO-534.
                      // ignore: deprecated_member_use
                      onReorder: actions.reorder,
                      children: [for (var i = 0; i < items.length; i++) rowFor(i)],
                    )
                  else
                    for (var i = 0; i < items.length; i++) rowFor(i),
                  TextButton.icon(
                    onPressed: _isSubmitting ? null : () => actions.editItem(null),
                    icon: const Icon(MdiIcons.plus, size: 18),
                    label: Text(t.formChrome.addItem(label: itemLabel)),
                  ),
                ],
              ),
            ),
            cancel: TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(t.common.done)),
          );
        },
      ),
    );
  }
}

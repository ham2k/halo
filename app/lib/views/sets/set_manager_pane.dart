// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The set manager: every set of a kind (SetCategory) in its folders, and
// what one does to them — rename, duplicate, move, export, delete — plus
// new folders and imports. Reached from the picker's "Manage … Sets" footer.
//
// Not a draft: each action is written as it is taken, and the one that
// cannot be taken back — a delete — asks first. A manager whose Cancel
// undid a delete would also have to undo the recordings that went with a
// voice set, which no other pane in the app pretends it can.

import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../services/error_reporting_service.dart';
import '../../services/file_pick.dart';
import '../../services/halo_services.dart';
import '../../services/sets/set_category.dart';
import '../../services/sets/set_tree.dart';
import 'set_picker_field.dart' show setTreeIndent;

Future<void> showSetManagerPane(BuildContext context, HaLoServices services, SetCategory category) => showModalPane<void>(
  context,
  title: category.title,
  closeLabel: context.t.common.close,
  scrollable: false,
  closeButton: false,
  // Brings a set in from outside — the pane's, not any one row's.
  headerActions: [
    if (category.fileType != null)
      Builder(
        builder: (context) =>
            TextButton.icon(icon: const Icon(MdiIcons.fileImportOutline), label: Text(context.t.sets.import), onPressed: () => _import(context, category)),
      ),
  ],
  builder: (_) => _SetManagerPane(services: services, category: category),
);

Future<void> _import(BuildContext context, SetCategory category) async {
  final m = context.t.sets;
  final type = category.fileType;
  if (type == null) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final XFile? chosen;
  try {
    chosen = await pickFile(
      acceptedTypeGroups: [
        // iOS filters by UTI and throws for a group carrying none.
        XTypeGroup(label: type.label, extensions: type.extensions, uniformTypeIdentifiers: const ['public.data'], mimeTypes: type.mimeTypes),
      ],
    );
  } catch (e, stack) {
    ErrorReportingService.report(e, stack, context: 'sets:import-picker', told: messenger != null);
    messenger?.showSnackBar(haloSnackBar(m.importPickerFailed(error: ErrorReportingService.messageOf(e))));
    return;
  }
  if (chosen == null) return;
  try {
    final id = await category.import(await chosen.readAsBytes(), chosen.name);
    if (id != null) messenger?.showSnackBar(haloSnackBar(m.imported(name: category.nameOf(id))));
  } on SetFileException catch (e, stack) {
    ErrorReportingService.report(e, stack, context: 'sets:import', told: messenger != null);
    final problem = switch (e.problem) {
      SetFileProblem.unreadable => m.problemUnreadable,
      SetFileProblem.wrongKind => m.problemWrongKind,
      SetFileProblem.newerVersion => m.problemNewerVersion,
      SetFileProblem.malformed => m.problemMalformed,
    };
    messenger?.showSnackBar(haloSnackBar(m.importUnreadable(filename: chosen.name, problem: problem)));
  } catch (e, stack) {
    // The file could not be read off the disk, or the set not stored: the
    // app's failure, not the file's.
    ErrorReportingService.report(e, stack, context: 'sets:import', told: messenger != null);
    messenger?.showSnackBar(haloSnackBar(m.importFailed(filename: chosen.name, error: ErrorReportingService.messageOf(e))));
  }
}

class _SetManagerPane extends StatefulWidget {
  final HaLoServices services;
  final SetCategory category;

  const _SetManagerPane({required this.services, required this.category});

  @override
  State<_SetManagerPane> createState() => _SetManagerPaneState();
}

class _SetManagerPaneState extends State<_SetManagerPane> {
  /// The set or folder whose name is being edited in its row, if any.
  String? _renaming;

  /// Scrolls the list while a drag is held near its top or bottom edge, so a
  /// folder scrolled out of sight can still be dropped on.
  EdgeDraggingAutoScroller? _autoScroller;

  /// [rowContext] is inside the list's scroll view, which the State's own
  /// context is not. The rect is about a row tall, centred on the pointer:
  /// scrolling starts once it crosses the list's edge.
  void _dragMoved(BuildContext rowContext, Offset pointer) {
    final scrollable = Scrollable.maybeOf(rowContext);
    if (scrollable == null) return;
    if (_autoScroller?.scrollable != scrollable) _autoScroller = EdgeDraggingAutoScroller(scrollable, velocityScalar: 50);
    _autoScroller!.startAutoScrollIfNecessary(Rect.fromCenter(center: pointer, width: 1, height: 56));
  }

  void _dragEnded() => _autoScroller?.stopAutoScroll();

  SetCategory get category => widget.category;

  Future<bool> _confirm({required String title, required String text}) async =>
      await showHaloDialog<bool>(
        context: context,
        builder: (context) => HaloDialog(
          title: Text(title),
          content: Text(text),
          cancel: TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.t.common.cancel)),
          actions: [FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(context.t.common.delete))],
        ),
      ) ==
      true;

  /// Where to move [name] to: the top level, or a folder — never a folder
  /// into itself or one inside it ([folderId]). Null for no choice; the
  /// empty string for the top level.
  Future<String?> _askFolder({required String name, String? folderId, String? current}) {
    final tree = category.tree;
    final excluded = folderId == null ? const <String>{} : tree.folderAndDescendants(folderId);
    final m = context.t.sets;
    final choices = [
      (id: '', label: m.topLevel),
      for (final row in tree.rows(const []))
        if (row is SetTreeFolderRow && !excluded.contains(row.folder.id)) (id: row.folder.id, label: tree.pathOf(row.folder.id).join(' / ')),
    ];
    return showHaloDialog<String>(
      context: context,
      builder: (context) => HaloDialog(
        // A list's rows, reaching the card's edges like every other list.
        list: true,
        title: Text(m.moveTitle(name: name)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final choice in choices)
              ListTile(
                leading: Icon(choice.id.isEmpty ? MdiIcons.fileTreeOutline : MdiIcons.folderOutline),
                title: Text(choice.label),
                selected: choice.id == (current ?? ''),
                onTap: () => Navigator.of(context).pop(choice.id),
                mouseCursor: SystemMouseCursors.click,
              ),
          ],
        ),
        cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
      ),
    );
  }

  /// Made with a name already, and straight into editing it: a folder is
  /// named in its row like any rename, not in a dialog of its own.
  Future<void> _newFolder({String? parent}) async {
    final m = context.t.sets;
    final tree = category.tree;
    final (next, folder) = tree.addFolder(SetCategory.unique(m.newFolder, [for (final folder in tree.folders) folder.name]), parent: parent);
    await category.setTree(next);
    if (mounted) setState(() => _renaming = folder.id);
  }

  /// Also called once the pane is gone, for a name left mid-edit as it
  /// closed.
  Future<void> _finishRename(String id, String? name, {required bool folder}) async {
    // Only where it is still this one being renamed: a rename ended by
    // another starting (New Folder, mid-edit) would otherwise end that one.
    if (mounted && _renaming == id) setState(() => _renaming = null);
    final wanted = name?.trim() ?? '';
    if (wanted.isEmpty) return;
    if (folder) {
      final current = category.tree.folder(id);
      if (current != null && current.name != wanted) await category.setTree(category.tree.renameFolder(id, wanted));
    } else if (wanted != category.nameOf(id)) {
      await category.rename(id, wanted);
    }
  }

  Future<void> _export(String id) async {
    final m = context.t.sets;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final box = context.findRenderObject() as RenderBox?;
    final exports = widget.services.exports;
    try {
      final file = await category.export(id);
      final files = [
        {'filename': file.filename, 'content': file.content, 'mimeType': file.mimeType},
      ];
      if (isWebPlatform) {
        await exports.downloadFiles(files);
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        await exports.shareFiles(files, sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size);
      } else {
        final saved = await exports.saveToDisk(files);
        // Android names the files it saved, not where: "to" a list of
        // names would read as a destination.
        if (saved != null) {
          messenger?.showSnackBar(haloSnackBar(saved.namesFiles ? m.exportedNamed(names: saved.location) : m.exported(location: saved.location)));
        }
      }
    } catch (e, stack) {
      ErrorReportingService.report(e, stack, context: 'sets:export', told: messenger != null);
      messenger?.showSnackBar(haloSnackBar(m.exportFailed(error: ErrorReportingService.messageOf(e))));
    }
  }

  /// Runs [action], and where it fails says so in [failed]'s words: for a
  /// voice set it moves recordings, which can fail where a settings write
  /// does not, and the generic notice would say less, once a session.
  Future<void> _attempt(String doing, String Function(String error) failed, Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await action();
    } catch (e, stack) {
      ErrorReportingService.report(e, stack, context: 'sets:$doing', told: messenger != null);
      messenger?.showSnackBar(haloSnackBar(failed(ErrorReportingService.messageOf(e))));
    }
  }

  List<_Action> _setActions(String id) {
    final m = context.t.sets;
    final name = category.nameOf(id);
    return [
      (icon: MdiIcons.pencilOutline, label: m.rename, destructive: false, onPressed: category.canRename(id) ? () => setState(() => _renaming = id) : null),
      (
        icon: MdiIcons.contentCopy,
        label: m.duplicate,
        destructive: false,
        onPressed: () =>
            _attempt('duplicate', (error) => m.duplicateFailed(name: name, error: error), () => category.duplicate(id, m.duplicateName(name: name))),
      ),
      (
        icon: MdiIcons.folderMoveOutline,
        label: m.moveTo,
        destructive: false,
        onPressed: () async {
          final to = await _askFolder(name: name, current: category.tree.folderOf(id));
          if (to != null) await category.setTree(category.tree.moveSet(id, to.isEmpty ? null : to));
        },
      ),
      if (category.fileType != null) (icon: MdiIcons.fileExportOutline, label: m.export, destructive: false, onPressed: () => _export(id)),
      (
        icon: MdiIcons.trashCanOutline,
        label: m.delete,
        destructive: true,
        onPressed: category.canDelete(id)
            ? () async {
                if (!await _confirm(title: m.deleteSet, text: category.deleteConfirmation(name))) return;
                await _attempt('delete', (error) => m.deleteFailed(name: name, error: error), () => category.delete(id));
              }
            : null,
      ),
    ];
  }

  List<_Action> _folderActions(SetFolder folder) {
    final m = context.t.sets;
    return [
      (icon: MdiIcons.pencilOutline, label: m.rename, destructive: false, onPressed: () => setState(() => _renaming = folder.id)),
      (icon: MdiIcons.folderPlusOutline, label: m.newFolder, destructive: false, onPressed: () => _newFolder(parent: folder.id)),
      (
        icon: MdiIcons.folderMoveOutline,
        label: m.moveTo,
        destructive: false,
        onPressed: () async {
          final to = await _askFolder(name: folder.name, folderId: folder.id, current: folder.parent);
          if (to != null) await category.setTree(category.tree.moveFolder(folder.id, to.isEmpty ? null : to));
        },
      ),
      (
        icon: MdiIcons.trashCanOutline,
        label: m.delete,
        destructive: true,
        onPressed: () async {
          if (await _confirm(
            title: m.deleteFolder,
            text: m.deleteFolderConfirm(name: folder.name),
          )) {
            await category.setTree(category.tree.deleteFolder(folder.id));
          }
        },
      ),
    ];
  }

  Widget _row({
    required String id,
    required bool folder,
    required String name,
    required int depth,
    required Widget leading,
    TextStyle? titleStyle,
    Widget? subtitle,
    required List<_Action> actions,
  }) {
    final padding = EdgeInsetsDirectional.only(start: Space.xxl + depth * setTreeIndent, end: Space.md);
    if (_renaming == id) {
      return ListTile(
        contentPadding: padding.copyWith(end: Space.xxl),
        leading: leading,
        title: _InlineName(
          initial: name,
          style: titleStyle,
          onDone: (value) => _finishRename(id, value, folder: folder),
        ),
      );
    }
    return _dragAndDrop(
      dragged: (id: id, folder: folder),
      name: name,
      leading: leading,
      dropFolder: folder ? id : category.tree.folderOf(id),
      child: _RowMenu(
        actions: actions,
        label: context.t.sets.actions(name: name),
        builder: (open, menu) => ListTile(
          contentPadding: padding,
          leading: leading,
          title: Text(name, style: titleStyle),
          subtitle: subtitle,
          trailing: menu,
          onTap: open,
          mouseCursor: SystemMouseCursors.click,
        ),
      ),
    );
  }

  /// Whether [dragged] dropped into [folder] (null: the top level) moves it
  /// anywhere: not where it already is, and never a folder into itself or
  /// one inside it.
  bool _canDrop(_Dragged dragged, String? folder) {
    final tree = category.tree;
    if (!dragged.folder) return tree.folderOf(dragged.id) != folder;
    if (folder != null && tree.folderAndDescendants(dragged.id).contains(folder)) return false;
    return tree.folder(dragged.id)?.parent != folder;
  }

  Future<void> _drop(_Dragged dragged, String? folder) {
    final tree = category.tree;
    return category.setTree(dragged.folder ? tree.moveFolder(dragged.id, folder) : tree.moveSet(dragged.id, folder));
  }

  /// A row that can be dragged, and dropped on. Dropped on a folder, what
  /// was dragged goes into it; dropped on a set, beside that set — which is
  /// how something comes back out to the top level. On a touch screen the
  /// drag starts with a long press, so a swipe still scrolls the list.
  Widget _dragAndDrop({required _Dragged dragged, required String name, required Widget leading, required String? dropFolder, required Widget child}) {
    final theme = Theme.of(context);
    final feedback = Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(Space.md),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.md),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: Space.lg),
            Text(name, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
    final dimmed = Opacity(opacity: 0.4, child: child);
    final draggable = Builder(
      builder: (rowContext) => isMobilePlatform
          ? LongPressDraggable<_Dragged>(
              data: dragged,
              feedback: feedback,
              childWhenDragging: dimmed,
              onDragUpdate: (details) => _dragMoved(rowContext, details.globalPosition),
              onDragEnd: (_) => _dragEnded(),
              child: child,
            )
          : Draggable<_Dragged>(
              data: dragged,
              feedback: feedback,
              childWhenDragging: dimmed,
              onDragUpdate: (details) => _dragMoved(rowContext, details.globalPosition),
              onDragEnd: (_) => _dragEnded(),
              child: child,
            ),
    );
    return DragTarget<_Dragged>(
      onWillAcceptWithDetails: (details) => _canDrop(details.data, dropFolder),
      onAcceptWithDetails: (details) => _drop(details.data, dropFolder),
      builder: (context, candidates, _) =>
          ColoredBox(color: candidates.isEmpty ? Colors.transparent : theme.colorScheme.primary.withValues(alpha: 0.12), child: draggable),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = context.t.sets;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: category.listenable,
      builder: (context, _) {
        final names = {for (final set in category.sets) set.id: set.name};
        final active = category.activeId;
        final rows = category.rows;
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SettingsList(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, row) in rows.indexed)
                        switch (row) {
                          SetTreeFolderRow(:final folder, :final depth) => _row(
                            id: folder.id,
                            folder: true,
                            name: folder.name,
                            depth: depth,
                            leading: const Icon(MdiIcons.folderOutline),
                            titleStyle: theme.textTheme.titleSmall,
                            // Said, because an empty folder is otherwise a
                            // heading over nothing.
                            subtitle: index + 1 >= rows.length || rows[index + 1].depth <= depth
                                ? Text(m.empty, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))
                                : null,
                            actions: _folderActions(folder),
                          ),
                          SetTreeSetRow(:final id, :final depth) => _row(
                            id: id,
                            folder: false,
                            name: names[id] ?? '?',
                            depth: depth,
                            leading: Icon(
                              id == active ? MdiIcons.checkCircle : MdiIcons.fileDocumentOutline,
                              color: id == active ? theme.colorScheme.primary : null,
                            ),
                            subtitle: id == active ? Text(m.inUse, style: theme.textTheme.bodySmall) : null,
                            actions: _setActions(id),
                          ),
                        },
                    ],
                  ),
                ),
              ),
            ),
            haloDialogFooterBand(
              context,
              // The tools slot is Expanded: unaligned, a lone button sits in
              // the middle of it.
              tools: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(icon: const Icon(MdiIcons.folderPlusOutline), label: Text(m.newFolder), onPressed: _newFolder),
              ),
              cancel: TextButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(context.t.common.done)),
            ),
          ],
        );
      },
    );
  }
}

/// What is being dragged: a set's id, or a folder's.
typedef _Dragged = ({String id, bool folder});

typedef _Action = ({IconData icon, String label, bool destructive, VoidCallback? onPressed});

/// A row's ⋮, handed to [builder] to place at the row's end, whose menu
/// opens immediately to the ⋮'s left — where the pointer already is, and
/// never past the pane's edge. Tapping the row ([builder]'s `open`) opens
/// the same menu in the same place.
class _RowMenu extends StatefulWidget {
  final List<_Action> actions;
  final String label;
  final Widget Function(VoidCallback open, Widget menu) builder;

  const _RowMenu({required this.actions, required this.label, required this.builder});

  @override
  State<_RowMenu> createState() => _RowMenuState();
}

class _RowMenuState extends State<_RowMenu> {
  final _controller = MenuController();

  static const _itemPadding = EdgeInsets.symmetric(horizontal: Space.xl);

  void _toggle() => _controller.isOpen ? _controller.close() : _controller.open();

  /// As wide as the widest item asks for: the menu's width has to be known
  /// to put its trailing edge against the ⋮.
  double _menuWidth(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge ?? const TextStyle();
    var text = 0.0;
    for (final action in widget.actions) {
      final width = textWidth(context, action.label, style);
      if (width > text) text = width;
    }
    // The icon, the gap MenuItemButton leaves after it, and slack for
    // glyph rounding.
    return _itemPadding.horizontal + 24 + Space.lg + text + Space.md;
  }

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    final width = _menuWidth(context);
    return widget.builder(
      _toggle,
      MenuAnchor(
        controller: _controller,
        alignmentOffset: Offset(-width, 0),
        style: MenuStyle(
          alignment: AlignmentDirectional.topStart,
          minimumSize: WidgetStatePropertyAll(Size(width, 0)),
          maximumSize: WidgetStatePropertyAll(Size(width, double.infinity)),
        ),
        menuChildren: [
          for (final action in widget.actions)
            MenuItemButton(
              style: MenuItemButton.styleFrom(padding: _itemPadding),
              leadingIcon: Icon(action.icon, color: action.destructive && action.onPressed != null ? error : null),
              onPressed: action.onPressed,
              child: Text(action.label),
            ),
        ],
        builder: (context, controller, _) => IconButton(
          icon: Icon(MdiIcons.dotsVertical, semanticLabel: widget.label),
          onPressed: _toggle,
        ),
      ),
    );
  }
}

/// A name edited where it is shown. Enter, leaving the field, or the field
/// going away — the pane closed under it — keeps it; Escape keeps the old
/// one, and [onDone] gets null for that.
class _InlineName extends StatefulWidget {
  final String initial;
  final TextStyle? style;
  final ValueChanged<String?> onDone;

  const _InlineName({required this.initial, required this.onDone, this.style});

  @override
  State<_InlineName> createState() => _InlineNameState();
}

class _InlineNameState extends State<_InlineName> {
  late final _controller = TextEditingController(text: widget.initial)..selection = TextSelection(baseOffset: 0, extentOffset: widget.initial.length);
  final _focus = FocusNode();
  var _done = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _finish(_controller.text);
    });
  }

  void _finish(String? value) {
    if (_done) return;
    _done = true;
    widget.onDone(value);
  }

  @override
  void dispose() {
    // In a microtask: the owner's setState is refused while the tree that
    // is disposing this is locked.
    if (!_done) {
      _done = true;
      final (onDone, value) = (widget.onDone, _controller.text);
      scheduleMicrotask(() => onDone(value));
    }
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => _finish(null)},
    child: TextField(
      controller: _controller,
      focusNode: _focus,
      autofocus: true,
      style: widget.style,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(isDense: true),
      onSubmitted: _finish,
    ),
  );
}

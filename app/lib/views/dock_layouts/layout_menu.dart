// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The named-layout switcher beside the layout button, and everything its
// menu opens: new, duplicate, rename, delete, export and import
// (docs/design/layouts.md § Named layouts).

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../services/error_reporting_service.dart';
import '../../services/export_service.dart' show ExportException;
import '../../services/extensions/extension_info.dart';
import '../../services/file_pick.dart';
import '../../services/halo_services.dart';
import '../../services/panel_service.dart' show PanelViews;
import '../dock_host.dart';
import '../operation/missing_panel_pane.dart' show MissingExtensionAction, extensionKeyOfPanelId, panelKeyOfPanelId;
import 'layout_diagram.dart';
import 'layout_file.dart';
import 'view_layouts.dart';

/// The name of the layout on screen with a drop-down arrow, for opening the
/// layouts sheet under it.
class LayoutSwitcherButton extends StatelessWidget {
  final DockHost host;
  final Color color;

  /// Opens the sheet, given how far its right edge sits from the screen's.
  final void Function(double? rightInset) onOpen;

  const LayoutSwitcherButton({super.key, required this.host, required this.color, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final name = host.layoutName(host.viewLayouts.activeLayout);
    return TextButton(
      style: TextButton.styleFrom(foregroundColor: color),
      onPressed: () {
        // The sheet hangs from this button's right edge, the way the Add a
        // Panel sheet hangs from the plus.
        final box = context.findRenderObject() as RenderBox?;
        final rightInset = box == null || !box.attached
            ? null
            : math.max(0.0, MediaQuery.sizeOf(context).width - box.localToGlobal(Offset(box.size.width, 0)).dx);
        onOpen(rightInset);
      },
      child: Semantics(
        label: context.t.operation.layout.layouts.switcherLabel(name: name),
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(name, overflow: TextOverflow.ellipsis),
            ),
            const Icon(MdiIcons.menuDown, size: 20),
          ],
        ),
      ),
    );
  }
}

/// This view's layouts, one row each: a tap on another one switches to it,
/// and the one on screen carries Edit. New, Import and Export are at the
/// foot, since they are about layouts in general rather than about a row.
///
/// [rightInset] aligns the sheet under the control that opened it; null
/// centres it, for the narrow Tools menu, which has no such control.
Future<void> showLayoutsSheet(BuildContext context, DockHost host, {double? rightInset}) => showTopModalPane<void>(
  context,
  rightInset: rightInset,
  maxWidth: idealPaneWidth,
  contentPadding: EdgeInsets.zero,
  closeLabel: context.t.common.close,
  title: Padding(
    padding: const EdgeInsets.only(right: Space.lg),
    child: Text(context.t.operation.layout.layouts.menuTitle, textAlign: rightInset == null ? null : TextAlign.right),
  ),
  builder: (_) => _LayoutsSheet(host: host),
);

class _LayoutsSheet extends StatefulWidget {
  final DockHost host;

  const _LayoutsSheet({required this.host});

  @override
  State<_LayoutsSheet> createState() => _LayoutsSheetState();
}

class _LayoutsSheetState extends State<_LayoutsSheet> {
  DockHost get _host => widget.host;

  @override
  void initState() {
    super.initState();
    _host.refreshLayouts();
  }

  /// Closes the sheet and runs [action] against the VIEW, whose context
  /// outlives the sheet's: everything at the foot opens a dialog or a file
  /// picker of its own, and a sheet left open under it would be one more
  /// thing to dismiss after.
  void _closeThen(Future<void> Function(BuildContext viewContext) action) {
    Navigator.of(context).pop();
    unawaited(action(_host.context));
  }

  /// Closes the sheet and runs [leave], which draws another layout. From the
  /// editor, an edit that changed something is saved or discarded first, as
  /// the operator chooses; staying put closes nothing.
  Future<void> _leave(Future<void> Function() leave) async {
    final save = await _keepDraftBeforeLeaving(context, _host);
    if (save == null || !mounted) return;
    Navigator.of(context).pop();
    await _host.leaveEditFor(leave, save: save);
  }

  Future<void> _edit(ViewLayout layout) async {
    final result = await showHaloDialog<_EditResult>(
      context: context,
      builder: (_) => _EditLayoutDialog(
        name: _host.layoutName(layout),
        description: layout.description,
        panels: _host.layoutPaneTitles(layout.id).join(' · '),
        canDelete: _host.viewLayouts.layouts.length > 1,
      ),
    );
    if (result == null || !mounted) return;
    if (result.delete) {
      // From the editor the draft goes with the layout it was a draft of.
      if (await _confirmDelete(context, _host.layoutName(layout))) await _host.leaveEditFor(() => _host.deleteLayout(layout.id), save: false);
    } else if (result.name case final name?) {
      await _host.editLayout(layout.id, name: name, description: result.description);
    }
    if (mounted) setState(() {});
  }

  Future<void> _new() async {
    final result = await showHaloDialog<({String name, bool duplicate})>(
      context: context,
      builder: (_) => _NewLayoutDialog(currentName: _host.layoutName(_host.viewLayouts.activeLayout)),
    );
    if (result == null || !mounted) return;
    if (result.duplicate) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      final t = context.t.operation.layout.layouts;
      Navigator.of(context).pop();
      try {
        await _host.duplicateLayout(_host.viewLayouts.active, result.name);
      } catch (e, stack) {
        ErrorReportingService.report(e, stack, context: 'layout:duplicate', told: messenger != null);
        messenger?.showSnackBar(haloSnackBar(t.duplicateFailed(error: ErrorReportingService.messageOf(e))));
      }
    } else {
      await _leave(() => _host.createLayout(result.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.operation.layout.layouts;
    final layouts = _host.viewLayouts;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, layout) in layouts.layouts.indexed) ...[
          if (index > 0) const Divider(height: 1),
          _row(context, layout, active: layout.id == layouts.active),
        ],
        // All three as the footer's own buttons, which stack when they do not
        // fit on one line — a Row of them would overflow on a phone.
        haloDialogFooterBand(
          context,
          actions: [
            TextButton.icon(
              icon: const Icon(MdiIcons.import),
              label: Text(t.menuImport),
              onPressed: () => _closeThen((viewContext) => runLayoutImport(viewContext, _host)),
            ),
            TextButton.icon(
              icon: const Icon(MdiIcons.export),
              label: Text(t.menuExport),
              onPressed: () => _closeThen((viewContext) => runLayoutExport(viewContext, _host)),
            ),
            FilledButton.icon(icon: const Icon(MdiIcons.plus), label: Text(t.menuNew), onPressed: () => unawaited(_new())),
          ],
        ),
      ],
    );
  }

  Widget _row(BuildContext context, ViewLayout layout, {required bool active}) {
    final t = context.t.operation.layout.layouts;
    final theme = Theme.of(context);
    final name = _host.layoutName(layout);
    return ListTile(
      tileColor: active ? theme.colorScheme.secondaryContainer : haloSheetRowColor(context),
      leading: Icon(
        active ? MdiIcons.checkCircle : MdiIcons.viewDashboardOutline,
        color: active ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      // So two layouts are told apart by more than a name.
      subtitle: Text(_host.layoutDescription(layout), maxLines: 2, overflow: TextOverflow.ellipsis),
      // The layout on screen is the one there is to edit — and the one row a
      // tap has nothing to switch to.
      trailing: active ? TextButton.icon(icon: const Icon(MdiIcons.pencil), label: Text(t.edit), onPressed: () => unawaited(_edit(layout))) : null,
      onTap: active ? null : () => unawaited(_leave(() async => _host.switchLayout(layout.id))),
    );
  }
}

/// Whether to save the edit in progress before leaving its layout: null to
/// stay, and false — discard — without asking when there is no edit, or one
/// that changed nothing.
Future<bool?> _keepDraftBeforeLeaving(BuildContext context, DockHost host) async {
  if (!host.layoutDraftChanged) return false;
  final t = context.t.operation.layout.layouts;
  return showHaloDialog<bool>(
    context: context,
    builder: (dialogContext) => HaloDialog(
      title: Text(t.leaveEditTitle(name: host.layoutName(host.viewLayouts.activeLayout))),
      content: Text(t.leaveEditBody),
      destructive: TextButton(
        style: TextButton.styleFrom(foregroundColor: Theme.of(dialogContext).colorScheme.error),
        onPressed: () => Navigator.of(dialogContext).pop(false),
        child: Text(t.discard),
      ),
      cancel: TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(context.t.common.cancel)),
      actions: [FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(context.t.common.save))],
    ),
  );
}

Future<bool> _confirmDelete(BuildContext context, String name) async {
  final t = context.t.operation.layout.layouts;
  final confirmed = await showHaloDialog<bool>(
    context: context,
    builder: (dialogContext) => HaloDialog(
      title: Text(t.deleteTitle),
      content: Text(t.deleteBody(name: name)),
      cancel: TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(context.t.common.cancel)),
      actions: [FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(context.t.common.delete))],
    ),
  );
  return confirmed == true;
}

typedef _EditResult = ({String? name, String? description, bool delete});

/// The layout's name and description, with Delete at the far edge of the
/// footer — the one place to take a layout away, behind a confirmation of
/// its own.
class _EditLayoutDialog extends StatefulWidget {
  final String name;
  final String? description;

  /// What a blank description shows instead, offered as the field's hint.
  final String panels;
  final bool canDelete;

  const _EditLayoutDialog({required this.name, required this.description, required this.panels, required this.canDelete});

  @override
  State<_EditLayoutDialog> createState() => _EditLayoutDialogState();
}

class _EditLayoutDialogState extends State<_EditLayoutDialog> {
  late final _name = TextEditingController(text: widget.name);
  late final _description = TextEditingController(text: widget.description);

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final description = _description.text.trim();
    if (name.isNotEmpty) Navigator.of(context).pop((name: name, description: description.isEmpty ? null : description, delete: false));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.operation.layout.layouts;
    return HaloDialog(
      title: Text(t.editTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: poloFieldDecoration(context, t.nameLabel),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: Space.lg),
          TextField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            minLines: 1,
            maxLines: 3,
            decoration: poloFieldDecoration(context, t.descriptionLabel, hintText: widget.panels),
          ),
        ],
      ),
      // Absent for the last layout rather than refused after the press: a
      // view has to draw something.
      destructive: widget.canDelete
          ? TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.of(context).pop((name: null, description: null, delete: true)),
              child: Text(context.t.common.delete),
            )
          : null,
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
      actions: [FilledButton(onPressed: _name.text.trim().isEmpty ? null : _save, child: Text(context.t.common.save))],
    );
  }
}

/// A name for the new layout, and what it starts as: a copy of the one on
/// screen, or the view's default arrangement.
class _NewLayoutDialog extends StatefulWidget {
  final String currentName;

  const _NewLayoutDialog({required this.currentName});

  @override
  State<_NewLayoutDialog> createState() => _NewLayoutDialogState();
}

class _NewLayoutDialogState extends State<_NewLayoutDialog> {
  final _name = TextEditingController();
  bool _duplicate = true;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create() {
    final name = _name.text.trim();
    if (name.isNotEmpty) Navigator.of(context).pop((name: name, duplicate: _duplicate));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.operation.layout.layouts;
    Widget choice(bool duplicate, String label, String? hint) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_duplicate == duplicate ? MdiIcons.radioboxMarked : MdiIcons.radioboxBlank),
      title: Text(label),
      subtitle: hint == null ? null : Text(hint),
      onTap: () => setState(() => _duplicate = duplicate),
    );
    return HaloDialog(
      title: Text(t.newTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: poloFieldDecoration(context, t.nameLabel),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _create(),
          ),
          const SizedBox(height: Space.md),
          choice(true, t.duplicateCurrent, widget.currentName),
          choice(false, t.startFromDefault, null),
        ],
      ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
      actions: [FilledButton(onPressed: _name.text.trim().isEmpty ? null : _create, child: Text(t.create))],
    );
  }
}

// ------------------------------------------------------------------ export

LayoutDiagramNode _diagramOfDock(DockNode node, String Function(String id) titleOf) => switch (node) {
  DockSplit(:final axis, :final children, :final weights) => LayoutDiagramSplit(axis, [for (final c in children) _diagramOfDock(c, titleOf)], weights),
  DockGroup(:final modules, :final nested) => LayoutDiagramGroup([
    for (final slot in modules)
      LayoutDiagramTab(key: slot, label: titleOf(slot), container: nested[slot] == null ? null : _diagramOfDock(nested[slot]!, titleOf)),
  ]),
};

/// Exports the layout on screen, or the part of it the operator ticks.
Future<void> runLayoutExport(BuildContext context, DockHost host) async {
  final t = context.t.operation.layout.layouts;
  final services = host.dockServices;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final layoutClass = host.dockLayoutClass;
  final layout = host.viewLayouts.activeLayout;
  final titles = host.dockTitles();
  final spec = host.arrangementSpec(layout.id, layoutClass);
  // The operator's own name for a pane, then the panel's — not the live tab
  // label, which can carry a count ("10 QSOs") that is no part of a layout.
  final diagram = _diagramOfDock(spec, (id) => host.paneOptions[id]?.title ?? services.panels[id]?.title ?? titles[id] ?? panelKeyOfPanelId(id));
  final choice = await showHaloDialog<({Set<Object> selected, bool everything})>(
    context: context,
    builder: (_) => _ExportDialog(diagram: diagram),
  );
  if (choice == null) return;
  try {
    final file = await host.buildLayoutFile(layout.id, {
      layoutClass: choice.everything ? null : choice.selected.contains,
      // The other arrangement has no diagram here — it is not on screen to
      // pick from — so it travels whole, and only with a whole layout.
      if (choice.everything) layoutClass.other: null,
    });
    if (file == null) return;
    final files = [
      {'filename': '${_fileStem(host.layoutName(layout))}.$layoutFileExtension', 'content': file.toYaml(), 'mimeType': 'application/yaml'},
    ];
    if (isWebPlatform) {
      await services.exports.downloadFiles(files);
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final box = context.mounted ? context.findRenderObject() as RenderBox? : null;
      await services.exports.shareFiles(files, sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size);
    } else {
      final saved = await services.exports.saveToDisk(files);
      if (saved != null) messenger?.showSnackBar(haloSnackBar(t.exported(location: saved.location)));
    }
  } catch (e, stack) {
    // An ExportException is the platform's answer to the save — a refusal the
    // operator is shown, not a fault to file.
    if (e is! ExportException) ErrorReportingService.report(e, stack, context: 'layout:export', told: messenger != null);
    messenger?.showSnackBar(haloSnackBar(t.exportFailed(error: ErrorReportingService.messageOf(e))));
  }
}

/// A layout's name as a file name: what a file system refuses goes.
String _fileStem(String name) {
  final stem = name.replaceAll(RegExp(r'[\\/:*?"<>|]+'), ' ').trim();
  return stem.isEmpty ? 'layout' : stem;
}

class _ExportDialog extends StatefulWidget {
  final LayoutDiagramNode diagram;

  const _ExportDialog({required this.diagram});

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  late final _all = layoutDiagramLeaves(widget.diagram);
  late Set<Object> _selected = {..._all};

  @override
  Widget build(BuildContext context) {
    final t = context.t.operation.layout.layouts;
    final everything = _selected.containsAll(_all);
    return HaloDialog(
      wide: true,
      title: Text(t.exportTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.exportPick, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: Space.md),
          LayoutDiagram(root: widget.diagram, selected: _selected, onChanged: (next) => setState(() => _selected = next)),
        ],
      ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
      actions: [
        FilledButton(
          onPressed: _selected.isEmpty ? null : () => Navigator.of(context).pop((selected: _selected, everything: everything)),
          child: Text(t.exportAction),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ import

/// What an exported layout file is named with. The content is YAML, but a
/// name of its own says which app the file is for.
const layoutFileExtension = 'h2klyt';

List<XTypeGroup> layoutFileTypeGroups() => [
  // Plain `.yaml` too: the format is meant to be written by hand.
  //
  // iOS filters by UTI and throws for a group carrying none; neither has a
  // UTI of its own there, so the group asks for `public.data` and the parse
  // decides.
  const XTypeGroup(
    label: 'Ham2K layout',
    extensions: [layoutFileExtension, 'yaml', 'yml'],
    uniformTypeIdentifiers: ['public.data'],
    mimeTypes: ['application/yaml', 'text/yaml'],
  ),
];

/// Picks a layout file and brings it in the way the operator chooses.
Future<void> runLayoutImport(BuildContext context, DockHost host) async {
  final t = context.t.operation.layout.layouts;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final XFile? chosen;
  try {
    chosen = await pickFile(acceptedTypeGroups: layoutFileTypeGroups());
  } catch (e, stack) {
    ErrorReportingService.report(e, stack, context: 'layout:import-picker', told: messenger != null);
    messenger?.showSnackBar(haloSnackBar(t.importPickerFailed(error: ErrorReportingService.messageOf(e))));
    return;
  }
  if (chosen == null) return;
  final LayoutFile file;
  try {
    file = LayoutFile.parse(utf8.decode(await chosen.readAsBytes(), allowMalformed: true));
  } on LayoutFileException catch (e) {
    // The file, not the app: nothing to report.
    debugPrint('[layout] ${chosen.name} is not a layout: $e');
    final problem = switch (e.problem) {
      LayoutFileProblem.notYaml => t.problemNotYaml(line: e.line ?? '?'),
      LayoutFileProblem.notLayoutFile => t.problemNotLayoutFile,
      LayoutFileProblem.newerVersion => t.problemNewerVersion,
      LayoutFileProblem.noArrangement => t.problemNoArrangement,
      LayoutFileProblem.malformed => t.problemMalformed,
      LayoutFileProblem.tooLarge => t.problemTooLarge,
    };
    messenger?.showSnackBar(haloSnackBar(t.importUnreadable(filename: chosen.name, problem: problem)));
    return;
  }
  if (!context.mounted) return;
  final stem = chosen.name.replaceFirst(RegExp(r'\.(h2klyt|ya?ml)$', caseSensitive: false), '');
  // The picks are tabs of the arrangement drawn for this class, and stay
  // theirs through a rotation behind the dialog.
  final shown = host.dockLayoutClass;
  final choice = await showHaloDialog<_ImportChoice>(
    context: context,
    builder: (_) => _ImportDialog(host: host, file: file, shown: shown, suggestedName: file.name ?? stem),
  );
  if (choice == null) return;
  // The other arrangement has no diagram to pick from, so it comes whole —
  // and only as a new layout or in place of one, since [importTargets] never
  // offers it for an add.
  final targets = host.importTargets(file, choice.mode, shown: shown);
  final arrangements = <DockLayoutClass, LayoutFileArrangement>{};
  for (final entry in targets.entries) {
    if (entry.key == shown) {
      if (entry.value.pruned(choice.selected.contains) case final pruned?) arrangements[entry.key] = pruned;
    } else {
      arrangements[entry.key] = entry.value;
    }
  }
  if (arrangements.isEmpty) {
    messenger?.showSnackBar(haloSnackBar(t.importNothing));
    return;
  }
  var save = false;
  if (choice.mode == LayoutImportMode.newLayout) {
    // Drawn in place of the layout on screen, so an edit of that one ends.
    // The other modes land in the edit itself.
    if (!context.mounted) return;
    final answer = await _keepDraftBeforeLeaving(context, host);
    if (answer == null) return;
    save = answer;
  }
  final ({List<String> skipped, List<String> restored}) imported;
  try {
    imported = await host.importLayout(
      arrangements,
      mode: choice.mode,
      name: choice.name,
      description: file.description,
      replaceSharedSettings: choice.replaceSettings,
      saveDraft: save,
    );
  } catch (e, stack) {
    ErrorReportingService.report(e, stack, context: 'layout:import', told: messenger != null);
    messenger?.showSnackBar(haloSnackBar(t.importFailed(error: ErrorReportingService.messageOf(e))));
    return;
  }
  final (:skipped, :restored) = imported;
  final services = host.dockServices;
  String titles(Iterable<String> ids) => {for (final id in ids) services.panels[id]?.title ?? host.nativeTitles[id] ?? panelKeyOfPanelId(id)}.join(', ');
  if (skipped.isNotEmpty) messenger?.showSnackBar(haloSnackBar(t.importSkipped(panels: titles(skipped))));
  if (restored.isNotEmpty) messenger?.showSnackBar(haloSnackBar(t.importKeptPinned(panels: titles(restored))));
}

typedef _ImportChoice = ({LayoutImportMode mode, String name, Set<Object> selected, bool replaceSettings});

class _ImportDialog extends StatefulWidget {
  final DockHost host;
  final LayoutFile file;
  final DockLayoutClass shown;
  final String suggestedName;

  const _ImportDialog({required this.host, required this.file, required this.shown, required this.suggestedName});

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  late final _name = TextEditingController(text: widget.suggestedName);
  var _mode = LayoutImportMode.newLayout;
  bool _replaceSettings = false;
  late Set<Object> _selected = layoutDiagramLeaves(_diagram);

  DockHost get _host => widget.host;
  HaLoServices get _services => _host.dockServices;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Map<DockLayoutClass, LayoutFileArrangement> get _targets => _host.importTargets(widget.file, _mode, shown: widget.shown);

  LayoutFileArrangement get _shown => _targets[widget.shown]!;

  LayoutDiagramNode get _diagram {
    final t = context.t.operation.layout.layouts;
    final refused = _host.importRefusals(_shown, _mode);
    String label(LayoutFileTab tab) {
      final title = tab.options['title'];
      if (title is String && title.isNotEmpty) return title;
      final panel = tab.panel!;
      return _services.panels[panel]?.title ?? _host.nativeTitles[panel] ?? panelKeyOfPanelId(panel);
    }

    String? note(LayoutFileTab tab) {
      final panel = tab.panel!;
      if (refused.contains(panel)) return _host.offersPanel(panel) ? t.alreadyPlaced : t.notOffered;
      final key = extensionKeyOfPanelId(panel);
      if (key != null && _services.panels[panel] == null) return t.needsExtension(name: _extensionName(key));
      return null;
    }

    LayoutDiagramNode convert(LayoutFileNode node) => switch (node) {
      LayoutFileSplit(:final axis, :final children, :final weights) => LayoutDiagramSplit(axis, [for (final c in children) convert(c)], weights),
      LayoutFileGroup(:final tabs) => LayoutDiagramGroup([
        for (final tab in tabs)
          if (tab.container case final inner?)
            LayoutDiagramTab(
              key: tab,
              label: tab.options['title'] is String ? tab.options['title'] as String : context.t.operation.layout.nestedPaneTitle,
              container: convert(inner),
            )
          else
            LayoutDiagramTab(key: tab, label: label(tab), note: note(tab), enabled: !refused.contains(tab.panel)),
      ]),
    };
    return convert(_shown.root);
  }

  /// Every extension the file's panels come from, in the order it lists them.
  List<String> get _missingExtensions {
    final keys = <String>{
      for (final extension in widget.file.extensions) extension.key,
      for (final arrangement in widget.file.arrangements.values)
        for (final panel in arrangement.panels) ?extensionKeyOfPanelId(panel),
    };
    return [
      for (final key in keys)
        if (!_running(key)) key,
    ];
  }

  bool _running(String key) {
    final info = _installed(key);
    return info != null && _services.extensions.isExtensionActive(info);
  }

  ExtensionInfo? _installed(String key) => _services.extensions.extensionInfo(key);

  String _extensionName(String key) {
    final locale = LocaleSettings.currentLocale.languageCode;
    return widget.file.extensions.where((e) => e.key == key).firstOrNull?.name ?? _installed(key)?.nameFor(locale) ?? key;
  }

  /// The view [view] names on screen — a [PanelViews] value.
  String _viewName(String view) {
    final t = context.t.operation.layout.layouts;
    return switch (view) {
      PanelViews.home => t.viewHome,
      PanelViews.operation => t.viewOperation,
      PanelViews.logs => t.viewLogs,
      PanelViews.chase => t.viewChase,
      _ => view,
    };
  }

  /// Whether the file carries settings for a panel placed once, which would
  /// replace the ones this device already keeps for it.
  bool get _hasSharedSettings {
    bool shared(LayoutFileNode node) => switch (node) {
      LayoutFileSplit(:final children) => children.any(shared),
      LayoutFileGroup(:final tabs) => tabs.any(
        (tab) => tab.container != null ? shared(tab.container!) : tab.settings.isNotEmpty && !_host.isMultiplePanel(tab.panel!, fileSaysInstance: tab.instance),
      ),
    };
    return _targets.values.any((arrangement) => shared(arrangement.root));
  }

  /// Brings an extension in, then ticks the panels that became pickable with
  /// it. Only those: the picks the operator already made, unticks included,
  /// stay as they were.
  Future<bool> _gain(Future<bool> Function() gain) async {
    final pickable = layoutDiagramLeaves(_diagram);
    try {
      if (!await gain()) return false;
      await _services.panels.refreshExtensionPanels();
    } catch (e, stack) {
      ErrorReportingService.report(e, stack, context: 'layout:import-gain-extension');
      return false;
    }
    if (mounted) {
      final now = layoutDiagramLeaves(_diagram);
      setState(() => _selected = {..._selected.intersection(now), ...now.difference(pickable)});
    }
    return true;
  }

  void _setMode(LayoutImportMode mode) => setState(() {
    _mode = mode;
    // What can be picked depends on the mode — adding refuses what is
    // already on screen — so the picks start over.
    _selected = layoutDiagramLeaves(_diagram);
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t.operation.layout.layouts;
    final theme = Theme.of(context);
    final missing = _missingExtensions;
    final diagram = _diagram;
    final name = _name.text.trim();
    final fromView = widget.file.view;
    final canImport = _selected.isNotEmpty && (_mode != LayoutImportMode.newLayout || name.isNotEmpty);
    Widget modeRow(LayoutImportMode mode, String label, {bool enabled = true}) => ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      enabled: enabled,
      leading: Icon(_mode == mode ? MdiIcons.radioboxMarked : MdiIcons.radioboxBlank),
      title: Text(label),
      onTap: () => _setMode(mode),
    );
    return HaloDialog(
      wide: true,
      title: Text(t.importTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A file from another view still imports: the panels the two
          // share come across, and the rest are marked in the diagram below.
          if (fromView != null && fromView != _host.dockView)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: Text(t.importFromOtherView(view: _viewName(fromView)), style: theme.textTheme.bodySmall),
            ),
          modeRow(LayoutImportMode.newLayout, t.importAsNew),
          if (_mode == LayoutImportMode.newLayout)
            Padding(
              padding: const EdgeInsets.only(left: Space.xxl, bottom: Space.md),
              child: TextField(controller: _name, decoration: poloFieldDecoration(context, t.nameLabel), onChanged: (_) => setState(() {})),
            ),
          // Both replace and add go into an edit of the layout on screen, and
          // an edit belongs to the layout it began in.
          modeRow(LayoutImportMode.replace, t.importReplace),
          modeRow(LayoutImportMode.add, t.importAdd),
          if (_mode == LayoutImportMode.add)
            Padding(
              padding: const EdgeInsets.only(left: Space.xxl, bottom: Space.md),
              child: Text(t.importAddHint, style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: Space.md),
          Text(t.importPick, style: theme.textTheme.titleSmall),
          const SizedBox(height: Space.md),
          LayoutDiagram(root: diagram, selected: _selected, onChanged: (next) => setState(() => _selected = next)),
          if (_hasSharedSettings)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _replaceSettings,
              onChanged: (value) => setState(() => _replaceSettings = value ?? false),
              title: Text(t.importReplaceSettings),
            ),
          for (final key in missing) _extensionRow(context, key),
        ],
      ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
      actions: [
        FilledButton(
          onPressed: canImport ? () => Navigator.of(context).pop((mode: _mode, name: name, selected: _selected, replaceSettings: _replaceSettings)) : null,
          child: Text(t.importAction),
        ),
      ],
    );
  }

  /// One extension the file's panels need, with what there is to do about
  /// it (see [MissingExtensionAction]).
  Widget _extensionRow(BuildContext context, String key) => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    leading: const Icon(MdiIcons.toyBrickPlusOutline),
    title: Text(context.t.operation.layout.layouts.needsExtension(name: _extensionName(key))),
    trailing: MissingExtensionAction(services: _services, extensionKey: key, gainWith: _gain),
  );
}

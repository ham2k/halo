// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The CW message editor: one row per function key — the key, an optional
// label beside it, the template underneath — each opening its own dialog
// with the message and, under a Details band, the label. Reached from the
// Station dialog's Messages button and from the keyer area's dialog.
//
// An operator keeps SETS of these — a Default, a POTA, whatever else they
// make — and the header's picker says which one is being edited AND, on
// Save, which one F1-F8 key (`CwMessageSet`, settings_service.dart). The
// whole dialog is a draft: the rows hand their edits up rather than storing
// them, so Cancel abandons every set the operator touched and not merely the
// one on screen.
//
// The active set's messages are still settings (`cwMessage1..8`,
// `cwMessageLabel1..8` in the Radio group), so SET and All Settings reach
// them too; this is the editor an operator meets, not the storage.

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../i18n/strings.g.dart';
import '../services/halo_services.dart';
import '../services/settings_service.dart';

/// The glyph for message `n` (1-based): its key's number in a circle, the
/// same one the settings fields declare by name. Consts, not names resolved
/// from a literal string — a literal icon name in core Dart is invisible to
/// the guard that checks every name resolves.
const cwMessageNumberIcons = [
  MdiIcons.numeric1Circle,
  MdiIcons.numeric2Circle,
  MdiIcons.numeric3Circle,
  MdiIcons.numeric4Circle,
  MdiIcons.numeric5Circle,
  MdiIcons.numeric6Circle,
  MdiIcons.numeric7Circle,
  MdiIcons.numeric8Circle,
];

Future<void> showCwMessagesDialog(BuildContext context, HaLoServices services) => showHaloDialog<void>(
      context: context,
      builder: (context) => _CwMessagesDialog(services: services),
    );

class _CwMessagesDialog extends StatefulWidget {
  final HaLoServices services;

  const _CwMessagesDialog({required this.services});

  @override
  State<_CwMessagesDialog> createState() => _CwMessagesDialogState();
}

/// The whole dialog edits a DRAFT of the sets and writes it on Save — which
/// is why the rows below hand their edits back rather than storing them.
/// Anything else and Cancel would only undo the set the operator was looking
/// at when they pressed it, having already stored the ones they left.
class _CwMessagesDialogState extends State<_CwMessagesDialog> {
  late final List<CwMessageSet> _sets = [...widget.services.settings.cwMessageSets];
  late String _selected = widget.services.settings.cwMessageSetName;

  CwMessageSet get _set => _sets.firstWhere((set) => set.name == _selected, orElse: () => _sets.first);

  void _replace(CwMessageSet set) {
    final index = _sets.indexWhere((entry) => entry.name == _selected);
    if (index < 0) return;
    setState(() => _sets[index] = set);
  }

  /// A name nothing else in the draft answers to — the name IS a set's
  /// identity (it is what `cwMessageSet` stores), so two alike would leave
  /// the function keys reading whichever came first.
  String _uniqueName(String wanted) {
    var name = wanted;
    var suffix = 2;
    while (_sets.any((set) => set.name == name)) {
      name = '$wanted $suffix';
      suffix++;
    }
    return name;
  }

  /// The seeded Default is not deletable, and neither is the last set left:
  /// the function keys have to have somewhere to read from, and a set the
  /// operator can rebuild from the seeds is the one that can always be
  /// fallen back to. Renaming it away makes it an ordinary set — the name IS
  /// the identity here, and pretending otherwise would need a flag stored
  /// per set for a rule one dialog enforces.
  bool get _canDelete => _sets.length > 1 && _selected != t.settings.radio.cwMessages.setDefault;

  Future<void> _newSet() async {
    final m = context.t.settings.radio.cwMessages;
    final name = await showHaloDialog<String>(
      context: context,
      builder: (context) => _NewSetDialog(title: m.newSet, field: m.newSetName),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    // A duplicate of what is on screen, not of what is stored: the operator
    // asked for another set LIKE this one, edits included.
    final copy = _set.renamed(_uniqueName(name.trim()));
    setState(() {
      _sets.add(copy);
      _selected = copy.name;
    });
  }

  Future<void> _rename() async {
    final m = context.t.settings.radio.cwMessages;
    final name = await showHaloDialog<String>(
      context: context,
      builder: (context) => _NewSetDialog(title: m.renameSet, field: m.newSetName, initial: _selected),
    );
    if (name == null || name.trim().isEmpty || !mounted || name.trim() == _selected) return;
    final index = _sets.indexWhere((set) => set.name == _selected);
    if (index < 0) return;
    setState(() {
      _sets[index] = _sets[index].renamed(_uniqueName(name.trim()));
      _selected = _sets[index].name;
    });
  }

  /// Only from the draft — Save is what makes it real, so an accidental
  /// delete is undone by Cancel and needs no confirmation of its own.
  void _delete() {
    if (!_canDelete) return;
    final index = _sets.indexWhere((set) => set.name == _selected);
    if (index < 0) return;
    setState(() {
      _sets.removeAt(index);
      _selected = _sets[index.clamp(0, _sets.length - 1)].name;
    });
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    await widget.services.settings.setCwMessageSets(_sets, active: _selected);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.t.settings.radio.cwMessages;
    final theme = Theme.of(context);
    final set = _set;
    return HaloDialog(
      title: Text(m.title),
      // The picker rides in the header slot, which does not scroll with the
      // rows: which set is being edited has to stay readable at the eighth
      // message as much as at the first. On the section band's ground and
      // reaching the card's edges, so the title above it and the picker read
      // as two things — the dialog's name, and the row that says what is in
      // it — and the band lines up with the section bands the rows below
      // sit under.
      header: Container(
        color: haloDialogBandColorAt(context),
        padding: const EdgeInsets.fromLTRB(Space.xxl, Space.md, Space.xxl, Space.xl),
        child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: set.name,
                    icon: dropdownTrailingIcon,
                    decoration: poloFieldDecoration(context, m.sets).copyWith(
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                    menuMaxHeight: dropdownMenuMaxHeight(context),
                    items: [
                      for (final entry in _sets)
                        DropdownMenuItem<String>(value: entry.name, child: Text(entry.name)),
                    ],
                    onChanged: (name) => name == null ? null : setState(() => _selected = name),
                  ),
                ),
                const SizedBox(width: Space.sm),
                // The three things one does to a set, beside the picker that
                // says which one. No hover tooltips (docs/design/user-interface.md),
                // so the accessible name is the only place each is named.
                IconButton(
                  icon: Icon(MdiIcons.fileOutline, semanticLabel: m.newSet),
                  onPressed: _newSet,
                ),
                IconButton(
                  icon: Icon(MdiIcons.pencilOutline, semanticLabel: m.renameSet),
                  onPressed: _rename,
                ),
                IconButton(
                  icon: Icon(
                    MdiIcons.trashCanOutline,
                    semanticLabel: m.deleteSet,
                    color: _canDelete ? theme.colorScheme.error : null,
                  ),
                  onPressed: _canDelete ? _delete : null,
                ),
              ],
            ),
      ),
      // The rows ARE the dialog's content — to the card's edges, inset
      // off the same SettingsList every other list in the app reads.
      list: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var n = 1; n <= SettingsService.cwMessageCount; n++)
            ListTile(
              leading: Icon(cwMessageNumberIcons[n - 1]),
              title: Text.rich(TextSpan(children: [
                TextSpan(text: m.key(n: n), style: const TextStyle(fontWeight: FontWeight.w600)),
                if (set.label(n).trim().isNotEmpty) TextSpan(text: '  ${set.label(n).trim()}'),
              ])),
              subtitle: Text(
                set.message(n).trim().isEmpty ? m.empty : set.message(n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: set.message(n).trim().isEmpty ? theme.colorScheme.onSurface.withValues(alpha: 0.5) : null,
                ),
              ),
              onTap: () async {
                final edited = await showHaloDialog<({String message, String label})>(
                  context: context,
                  builder: (context) => _CwMessageDialog(n: n, message: set.message(n), label: set.label(n)),
                );
                if (edited == null || !mounted) return;
                _replace(_set.withMessage(n, edited.message).withLabel(n, edited.label));
              },
              mouseCursor: SystemMouseCursors.click,
            ),
        ],
      ),
      // Cancel, not Done: there are pending changes to abandon now that the
      // rows edit a draft (dialog_footer_convention_test.dart).
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
      actions: [
        FilledButton(onPressed: _save, child: Text(context.t.common.save)),
      ],
    );
  }
}

/// Names a new set. Nothing but a field and the two verbs: the set it will
/// copy is already chosen, in the dialog behind this one.
class _NewSetDialog extends StatefulWidget {
  final String title;
  final String field;

  /// The name to start from — empty for a new set, the current one when
  /// renaming, so a rename is an edit rather than a retype.
  final String initial;

  const _NewSetDialog({required this.title, required this.field, this.initial = ''});

  @override
  State<_NewSetDialog> createState() => _NewSetDialogState();
}

class _NewSetDialogState extends State<_NewSetDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_name.text.trim());

  @override
  Widget build(BuildContext context) => HaloDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: poloFieldDecoration(context, widget.field),
          onSubmitted: (_) => _save(),
        ),
        cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
        actions: [
          FilledButton(onPressed: _save, child: Text(context.t.common.save)),
        ],
      );
}

/// One message: the template first, then its label under a Details band.
/// Hands its two values back through `pop` rather than storing them — the
/// dialog above holds the draft every set is edited in.
class _CwMessageDialog extends StatefulWidget {
  final int n;
  final String message;
  final String label;

  const _CwMessageDialog({required this.n, required this.message, required this.label});

  @override
  State<_CwMessageDialog> createState() => _CwMessageDialogState();
}

class _CwMessageDialogState extends State<_CwMessageDialog> {
  late final _message = TextEditingController(text: widget.message);
  late final _label = TextEditingController(text: widget.label);

  @override
  void dispose() {
    _message.dispose();
    _label.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop((message: _message.text.trim(), label: _label.text.trim()));

  @override
  Widget build(BuildContext context) {
    final m = context.t.settings.radio.cwMessages;
    // Zero content inset so the Details band runs edge to edge; the fields
    // take the dialog's usual inset themselves (halo_dialog.dart's default).
    const rowInset = EdgeInsets.symmetric(horizontal: Space.xxl);
    return HaloDialog(
      title: Text(m.messageTitle(n: widget.n)),
      contentPadding: EdgeInsets.zero,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: rowInset.copyWith(top: Space.xl, bottom: Space.xl),
            child: TextField(
              controller: _message,
              autofocus: true,
              // Not uppercased: Liquid's `{{ qso.call }}` is case-sensitive,
              // and the queue uppercases what is keyed anyway.
              decoration: poloFieldDecoration(context, m.key(n: widget.n)),
              onSubmitted: (_) => _save(),
            ),
          ),
          SectionHeader(m.details),
          Padding(
            padding: rowInset.copyWith(top: Space.lg, bottom: Space.xl),
            child: TextField(
              controller: _label,
              textCapitalization: TextCapitalization.sentences,
              decoration: poloFieldDecoration(context, m.labelField),
              onSubmitted: (_) => _save(),
            ),
          ),
        ],
      ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
      actions: [
        FilledButton(onPressed: _save, child: Text(context.t.common.save)),
      ],
    );
  }
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The CW message editor: one row per function key — the key, an optional
// label beside it, the template underneath — each opening its own dialog
// with the message and, under a Details band, the label. Reached from the
// Station dialog's CW Keyer button, the keyer area's dialog, and Settings →
// Radio's CW Keyer row.
//
// An operator keeps SETS of these — a Default, a POTA, whatever else they
// make — and the header's picker says which one is being edited AND, on
// Save, which one F1-F8 key (`CwMessageSet`, settings_service.dart). The
// whole dialog is a draft: the rows hand their edits up rather than storing
// them, so Cancel abandons every set the operator touched and not merely the
// one on screen. The keyer's behaviour — message 1's repeat and Enter Sends
// Messages — sits under the picker and is NOT part of the draft: it applies
// as it changes, as in the Phone Keyer dialog, so a dialog closed by a tap
// outside cannot silently drop a pick that looked made.
//
// The active set's messages are still settings (`cwMessage1..8`,
// `cwMessageLabel1..8` in the Radio group), so SET and SHOW reach them too;
// this is the editor an operator meets, not the storage.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../services/cat/cat_service.dart';
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nothing to key CW with at all, connected or not: said first,
            // because every control below does nothing until it changes.
            ListenableBuilder(
              listenable: widget.services.cat,
              builder: (context, _) => widget.services.cat.designatedKeyIsKeyer ? const SizedBox.shrink() : KeyerUnsupportedNotice(text: m.notSupported),
            ),
            // How the messages go out first — speed, repeat, ESM — then which
            // set of them is being edited. Message 1 only repeats
            // (SettingsService.cwRepeatDelay).
            Row(
              children: [
                // The speed messages go out at, first: it is what an
                // operator adjusts most between contacts.
                _KeyerSpeedField(cat: widget.services.cat),
                const SizedBox(width: Space.md),
                Expanded(
                  child: RepeatDelayField(
                    value: '${widget.services.settings.cwRepeatDelay.inSeconds}',
                    label: m.repeat,
                    offLabel: m.repeatOff,
                    afterLabel: (n) => m.repeatAfter(n: n),
                    onChanged: (value) {
                      // Off ends a chain already counting down.
                      if (value == '0') widget.services.cat.cancelKeyerRepeat();
                      unawaited(widget.services.settings.setCwRepeatDelay(int.parse(value)));
                    },
                  ),
                ),
                if (widget.services.settings.experimentEnabled('esm') /* stored key, see experiments.yaml */ ) ...[
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: EnterSendsField(
                      value: widget.services.cat.operatorEnterSends,
                      onChanged: (value) => widget.services.cat.setEnterSends(on: value.on, running: value.running),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: set.name,
                    icon: dropdownTrailingIcon,
                    decoration: poloFieldDecoration(context, m.sets).copyWith(filled: true, fillColor: theme.colorScheme.surface),
                    menuMaxHeight: dropdownMenuMaxHeight(context),
                    items: [for (final entry in _sets) DropdownMenuItem<String>(value: entry.name, child: Text(entry.name))],
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
                  icon: Icon(MdiIcons.trashCanOutline, semanticLabel: m.deleteSet, color: _canDelete ? theme.colorScheme.error : null),
                  onPressed: _canDelete ? _delete : null,
                ),
              ],
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
              title: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: m.key(n: n),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (set.label(n).trim().isNotEmpty) TextSpan(text: '  ${set.label(n).trim()}'),
                  ],
                ),
              ),
              subtitle: Text(
                set.message(n).trim().isEmpty ? m.empty : set.message(n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: set.message(n).trim().isEmpty ? theme.colorScheme.onSurface.withValues(alpha: 0.5) : null),
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
      help: TextButton(
        onPressed: () => showHaloDialog<void>(
          context: context,
          builder: (context) => _CwMessagesHelpDialog(esm: widget.services.settings.experimentEnabled('esm') /* stored key, see experiments.yaml */),
        ),
        child: Text(m.help),
      ),
      // Cancel, not Done: there are pending changes to abandon now that the
      // rows edit a draft (dialog_footer_convention_test.dart).
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
      actions: [FilledButton(onPressed: _save, child: Text(context.t.common.save))],
    );
  }
}

/// Message 1's repeat as a field, in either keyer dialog: Off, or after two
/// to ten seconds (SettingsService.cwRepeatDelayOptions, shared by both).
class RepeatDelayField extends StatelessWidget {
  final String value;
  final String label;
  final String offLabel;
  final String Function(String seconds) afterLabel;
  final ValueChanged<String> onChanged;

  const RepeatDelayField({super.key, required this.value, required this.label, required this.offLabel, required this.afterLabel, required this.onChanged});

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    isExpanded: true,
    initialValue: value,
    icon: dropdownTrailingIcon,
    decoration: poloFieldDecoration(context, label).copyWith(filled: true, fillColor: Theme.of(context).colorScheme.surface),
    menuMaxHeight: dropdownMenuMaxHeight(context),
    items: [
      for (final option in SettingsService.cwRepeatDelayOptions)
        DropdownMenuItem<String>(value: option, child: Text(option == '0' ? offLabel : afterLabel(option))),
    ],
    onChanged: (choice) => choice == null ? null : onChanged(choice),
  );
}

/// Enter Sends Messages as a field — Off, Run or S&P, the three states the
/// keyer area's pill steps through. In both keyer dialogs, because the one
/// setting plays CW messages and voice memories alike
/// (docs/design/logging-fields.md § Enter Sends Messages).
class EnterSendsField extends StatelessWidget {
  final ({bool on, bool running}) value;
  final ValueChanged<({bool on, bool running})> onChanged;

  const EnterSendsField({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final m = context.t.settings.radio.enterSends;
    final current = !value.on
        ? 'off'
        : value.running
        ? 'run'
        : 'sp';
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: current,
      icon: dropdownTrailingIcon,
      decoration: poloFieldDecoration(context, m.field).copyWith(filled: true, fillColor: Theme.of(context).colorScheme.surface),
      menuMaxHeight: dropdownMenuMaxHeight(context),
      items: [
        DropdownMenuItem<String>(value: 'off', child: Text(m.off)),
        DropdownMenuItem<String>(value: 'run', child: Text(m.run)),
        DropdownMenuItem<String>(value: 'sp', child: Text(m.sp)),
      ],
      onChanged: (choice) => switch (choice) {
        'run' => onChanged((on: true, running: true)),
        'sp' => onChanged((on: true, running: false)),
        'off' => onChanged((on: false, running: true)),
        _ => null,
      },
    );
  }
}

/// What an operator needs to write a message, and no more: the
/// placeholders an exchange is made of and the two filters that shape a
/// number for CW. The whole vocabulary is docs/extensions/templates.md; a
/// list of all of it here would bury the handful that get used.
class _CwMessagesHelpDialog extends StatelessWidget {
  const _CwMessagesHelpDialog({required this.esm});

  /// Whether Enter Sends Messages can be on, which adds what it keys from
  /// each function key — read off the ESM set and
  /// [CwMessageSet.esmKeys], so this can't name a key ESM doesn't use.
  final bool esm;

  @override
  Widget build(BuildContext context) {
    final m = context.t.settings.radio.cwMessages;
    final theme = Theme.of(context);
    // Templates are code, identical in every language; only what they mean
    // is translated.
    final rows = [
      ('{{ op.call }}', m.helpOpCall),
      ('{{ qso.call }}', m.helpQsoCall),
      ('{{ qso.fullCall }}', m.helpQsoFullCall),
      ('{{ qso.partial }}', m.helpQsoPartial),
      ('{{ qso.nextCall }}', m.helpQsoNextCall),
      ('{{ qso.nextPartial }}', m.helpQsoNextPartial),
      ('{{ qso.name }}', m.helpQsoName),
      ('{{ qso.state }}', m.helpQsoState),
      ('{{ keyer.msg1 }}', m.helpKeyerMsg),
      ('{{ qso.rst }}', m.helpQsoRst),
      ('{{ qso.serial }}', m.helpQsoSerial),
      ('{{ qso.serial | pad: 3 }}', m.helpPad),
      ('{{ qso.rst | cut }}', m.helpCut),
      ('{{ qso.serial | cut: "0159" }}', m.helpCutDigits),
    ];
    final esmSet = CwMessageSet.esm();
    final esmRows = [
      for (final MapEntry(key: role, value: n) in CwMessageSet.esmKeys.entries)
        (
          'F$n  ${esmSet.message(n)}',
          switch (role) {
            EsmMessage.cq => m.helpEsmCq,
            EsmMessage.exchange => m.helpEsmExchange,
            EsmMessage.thanks => m.helpEsmThanks,
            EsmMessage.myCall => m.helpEsmMyCall,
            EsmMessage.hisCall => m.helpEsmHisCall,
            EsmMessage.again => m.helpEsmAgain,
          },
        ),
    ];
    Widget row(String template, String meaning) => ListTile(
      visualDensity: VisualDensity.compact,
      title: Text(template, style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'RobotoMono')),
      subtitle: Text(meaning),
    );
    return HaloDialog(
      title: Text(m.helpTitle),
      list: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.md), child: Text(m.helpIntro)),
          for (final (template, meaning) in rows) row(template, meaning),
          // The placeholders put together, headed apart from the list: it
          // is one message, not one more value.
          Padding(padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, 0), child: Text(m.helpFullExample)),
          row('{{ qso.call }} {{ qso.rst | cut }} {{ qso.serial | pad: 3 | cut }}', m.helpExample),
          if (esm) ...[
            Padding(padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.md), child: Text(m.helpEsmIntro)),
            for (final (template, meaning) in esmRows) row(template, meaning),
            row(
              'TU {% if qso.fullCall != blank %}{{ keyer.msg5 }} {{ keyer.msg2 }}{% elsif qso.partial != blank %}{{ qso.partial }}?{% endif %}',
              m.helpEsmStackThanks,
            ),
          ],
        ],
      ),
      // Done, not Cancel: nothing here can be changed.
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.done)),
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
    actions: [FilledButton(onPressed: _save, child: Text(context.t.common.save))],
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
  void initState() {
    super.initState();
    // The label's placeholder is the message, as it is being typed.
    _message.addListener(_onMessageChanged);
  }

  void _onMessageChanged() => setState(() {});

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
    // Zero content padding, with the settings row inset published instead
    // (`list`): the Details band reads it, and the fields take the same one
    // themselves.
    const rowInset = EdgeInsets.symmetric(horizontal: settingsRowInset);
    return HaloDialog(
      title: Text(m.messageTitle(n: widget.n)),
      list: true,
      contentPadding: EdgeInsets.zero,
      // The body scrolls itself, because its band pins — which needs a
      // sliver viewport, and the shell's plain scroll view is not one.
      scrollable: false,
      content: SectionedListView(
        shrinkWrap: true,
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
              // Left blank, the key is labelled with its message.
              decoration: poloFieldDecoration(context, m.labelField, hintText: _message.text.trim()),
              onSubmitted: (_) => _save(),
            ),
          ),
        ],
      ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
      actions: [FilledButton(onPressed: _save, child: Text(context.t.common.save))],
    );
  }
}

/// The keyer's speed, sized to its value ("30 WPM") rather than stretched —
/// what the radio reports, and what it is told on a pick. Follows the radio
/// while the dialog is open, and is disabled while nothing can key.
class _KeyerSpeedField extends StatelessWidget {
  final CatService cat;

  const _KeyerSpeedField({required this.cat});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: cat,
    builder: (context, _) {
      final ks = context.t.settings.radio.keyerSpeed;
      final range = cat.keyerSpeedRange;
      final speed = cat.keyerSpeed;
      final canKey = cat.canKeyCw;
      final inRange = speed != null && range != null && speed >= range.min && speed <= range.max;
      final theme = Theme.of(context);
      final valueStyle = theme.textTheme.titleMedium ?? const TextStyle();
      final labelStyle = theme.textTheme.bodySmall ?? const TextStyle();
      // The wider of the value and the floating label, plus the field's
      // content padding and the dropdown's trailing icon.
      final width = math.max(textWidth(context, '30 ${ks.unit}', valueStyle), textWidth(context, ks.title, labelStyle)) + 16 + 32;
      return SizedBox(
        width: width,
        child: DropdownButtonFormField<int>(
          // Keyed on the value: FormFieldState reads initialValue once, and
          // the radio's answer arrives after the first build.
          key: ValueKey('keyerSpeed:${inRange ? speed : null}:$canKey'),
          isExpanded: true,
          initialValue: inRange ? speed : null,
          icon: dropdownTrailingIcon,
          decoration: poloFieldDecoration(context, ks.title).copyWith(filled: true, fillColor: theme.colorScheme.surface),
          menuMaxHeight: dropdownMenuMaxHeight(context),
          items: [
            if (range != null)
              for (var wpm = range.min; wpm <= range.max; wpm++) DropdownMenuItem<int>(value: wpm, child: Text('$wpm ${ks.unit}')),
          ],
          onChanged: canKey ? (wpm) => wpm == null ? null : cat.setKeyerSpeed(wpm) : null,
        ),
      );
    },
  );
}

/// The first row of a keyer dialog whose equipment cannot send what it
/// edits — the CW key, or the radio's voice memories.
class KeyerUnsupportedNotice extends StatelessWidget {
  final String text;

  const KeyerUnsupportedNotice({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Row(
        children: [
          Icon(MdiIcons.alertCircleOutline, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

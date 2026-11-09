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
// make — and the header's picker says which one F1-F8 key, and so which one
// is being edited (`CwMessageSet`). Everything applies as it changes — a
// pick, a message, the keyer's behaviour under the picker — so a dialog
// closed by a tap outside cannot silently drop an edit that looked made.
// What the dialog changed is undone by Revert, from a copy of each set taken
// before its first edit; the sets themselves — their names, folders, copies
// — are the set manager's, reached from the picker, and Revert leaves them
// as the manager left them.
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
import '../services/sets/cw_message_set_category.dart';
import '../services/sets/offered_keyer_sets.dart';
import '../services/settings_service.dart';
import 'sets/set_picker_field.dart';
import 'keying_pickers.dart';
import 'settings/keyboard_shortcuts_panel.dart' show KeyerMessageKeys;

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

/// [radio] is the radio whose speed and Run / S&P the dialog shows, `A` or
/// `B` — a keyer area's own; null for the operator's. The messages are the
/// same for both radios.
Future<void> showCwMessagesDialog(BuildContext context, HaLoServices services, {String? radio}) {
  final keyingRadio = radio ?? services.cat.operatorRadio;
  // The speed field shows a value the radio never volunteers — see
  // CatService.refreshKeyerSpeed. Asked as the dialog opens, so the answer
  // is on screen by the time the operator reads the field.
  services.cat.keyer(keyingRadio).refreshKeyerSpeed();
  return showModalPane<void>(
    context,
    title: context.t.settings.radio.cwMessages.title,
    closeLabel: context.t.common.close,
    // The rows scroll under a pinned picker and a pinned footer, whose Done is
    // the way out — so no X in the header (haloDialogFooterBand).
    scrollable: false,
    closeButton: false,
    builder: (_) => _CwMessagesDialog(services: services, radio: keyingRadio),
  );
}

/// Message [n] of the set in use, on its own — what a long press or a
/// right click on its keyer button opens. Saved into that set on the
/// dialog's Save; only shown, where the set is an extension's.
Future<void> showCwMessageDialog(BuildContext context, HaLoServices services, int n) async {
  final settings = services.settings;
  final set = settings.activeCwMessageSet;
  final edited = await showHaloDialog<({String message, String label})>(
    context: context,
    builder: (context) => _CwMessageDialog(n: n, message: set.message(n), label: set.label(n), readOnly: isOfferedSetId(set.id)),
  );
  if (edited == null) return;
  // The sets as they are now, not as the dialog opened on.
  await settings.setCwMessageSets([
    for (final entry in settings.cwMessageSets) entry.id == set.id ? entry.withMessage(n, edited.message).withLabel(n, edited.label) : entry,
  ], active: settings.cwMessageSetId);
}

class _CwMessagesDialog extends StatefulWidget {
  final HaLoServices services;
  final String radio;

  const _CwMessagesDialog({required this.services, required this.radio});

  @override
  State<_CwMessagesDialog> createState() => _CwMessagesDialogState();
}

/// The dialog stores each edit as it is made, and keeps what it would take to
/// undo them: every set touched as it was before its first edit, and the set
/// in use when the dialog opened. Revert puts all of them back — not merely
/// the set on screen, which would leave the ones the operator moved away
/// from edited.
class _CwMessagesDialogState extends State<_CwMessagesDialog> {
  /// The width the speed field, the gap and message 1's repeat need side
  /// by side with the cooldown still readable; narrower, the repeat goes
  /// under the speed.
  static const _repeatBesideSpeedWidth = 440.0;

  late final _settings = widget.services.settings;
  late final _category = CwMessageSetCategory(_settings);

  /// Each set the dialog has changed, as it was before the first change —
  /// its messages and labels; its name is the manager's, never reverted.
  final _before = <String, CwMessageSet>{};
  late final _activeBefore = _settings.cwMessageSetId;

  bool get _changed => _before.isNotEmpty || _settings.cwMessageSetId != _activeBefore;

  Future<void> _pick(String id) => _settings.setCwMessageSets(_settings.cwMessageSets, active: id);

  /// The name of the extension set [id] comes with; null for the operator's.
  String? _offeredBy(String id) => _settings.offeredKeyerSets.cw.where((offered) => offered.set.id == id).firstOrNull?.ownerName;

  Future<void> _edit(int n, ({String message, String label}) edited) {
    final set = _settings.activeCwMessageSet;
    _before.putIfAbsent(set.id, () => set);
    return _settings.editActiveCwMessageSet((set) => set.withMessage(n, edited.message).withLabel(n, edited.label));
  }

  /// A set the manager deleted since is left deleted, and an active set it
  /// deleted leaves the one in use now. The copies are let go only once the
  /// write has landed: a write that fails leaves them there to try again.
  Future<void> _revert() async {
    await _settings.setCwMessageSets(
      [for (final set in _settings.cwMessageSets) _before[set.id]?.renamed(set.name) ?? set],
      active: _settings.cwMessageSets.any((set) => set.id == _activeBefore) || _settings.offeredCwMessageSet(_activeBefore) != null
          ? _activeBefore
          : _settings.cwMessageSetId,
    );
    if (mounted) setState(_before.clear);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: widget.services.settings, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final m = context.t.settings.radio.cwMessages;
    final theme = Theme.of(context);
    final set = _settings.activeCwMessageSet;
    // As showFormPane's: min so the dialog card fits the rows, spaceBetween
    // so full screen, where the pane IS the screen, the slack falls above the
    // footer rather than under it.
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The picker is pinned above the rows: which set is being edited has
              // to stay readable at the eighth message as much as at the first. On
              // the section band's ground and reaching the pane's edges, so the
              // title above it and the picker read as two things — the pane's name,
              // and the row that says what is in it.
              Container(
                color: haloDialogBandColorAt(context),
                padding: const EdgeInsets.fromLTRB(Space.xxl, Space.md, Space.xxl, Space.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // What keys the messages, as the Station panel picks it —
                    // radio1's; Radio B's has its own row there.
                    if (widget.radio == 'A')
                      ListenableBuilder(
                        listenable: Listenable.merge([widget.services.cat, widget.services.settings]),
                        builder: (context, _) => Padding(
                          padding: const EdgeInsets.only(bottom: Space.md),
                          child: Row(
                            children: [
                              Expanded(
                                child: cwKeyPicker(
                                  context,
                                  widget.services,
                                  keys: keyNodes(widget.services),
                                  label: context.t.settings.station.keyInUse,
                                  filled: true,
                                ),
                              ),
                              const SizedBox(width: Space.sm),
                              cwKeyingOptionsButton(context),
                            ],
                          ),
                        ),
                      ),
                    // Nothing to key CW with at all, connected or not: said
                    // before the rest, because every control below does nothing
                    // until it changes.
                    ListenableBuilder(
                      listenable: widget.services.cat,
                      builder: (context, _) =>
                          widget.services.cat.keyer(widget.radio).designatedKeyIsKeyer ? const SizedBox.shrink() : KeyerUnsupportedNotice(text: m.notSupported),
                    ),
                    // How the messages go out first — speed with message 1's
                    // repeat beside it where the cooldown still reads, under
                    // it where it would not, then ESM — then which set of
                    // them is being edited.
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // The speed messages go out at, first: it is what an
                        // operator adjusts most between contacts.
                        final speed = _KeyerSpeedField(cat: widget.services.cat, keyer: widget.services.cat.keyer(widget.radio));
                        final repeat = ListenableBuilder(
                          listenable: widget.services.settings,
                          builder: (context, _) => RepeatFields(
                            on: widget.services.settings.cwRepeat,
                            cooldown: widget.services.settings.cwRepeatCooldown,
                            onToggled: (on) {
                              // Off ends a chain already counting down — on
                              // either radio, since the repeat is theirs both.
                              if (!on) {
                                for (final radio in ['A', 'B']) {
                                  widget.services.cat.keyer(radio).cancelKeyerRepeat();
                                }
                              }
                              unawaited(widget.services.settings.setCwRepeat(on));
                            },
                            onCooldown: (seconds) => unawaited(widget.services.settings.setCwRepeatCooldown(seconds)),
                          ),
                        );
                        if (constraints.maxWidth >= _repeatBesideSpeedWidth) {
                          return Row(
                            children: [
                              speed,
                              const SizedBox(width: Space.xxl),
                              Expanded(child: repeat),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            speed,
                            const SizedBox(height: Space.md),
                            repeat,
                          ],
                        );
                      },
                    ),
                    if (widget.services.settings.experimentEnabled('esm') /* stored key, see experiments.yaml */ ) ...[
                      const SizedBox(height: Space.md),
                      EnterSendsField(cat: widget.services.cat),
                    ],
                    const SizedBox(height: Space.md),
                    SetPickerField(services: widget.services, category: _category, label: m.sets, value: set.id, onChanged: (id) => unawaited(_pick(id))),
                    if (_offeredBy(set.id) case final extension?)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.sm),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            context.t.sets.offeredLocked(name: set.name, extension: extension, manage: _category.manageLabel),
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // The rows ARE the pane's content — to its edges, inset off the same
              // SettingsList every other list in the app reads.
              Flexible(
                child: SettingsList(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var n = 1; n <= SettingsService.cwMessageCount; n++)
                          ListTile(
                            leading: Icon(cwMessageNumberIcons[n - 1]),
                            // The label, or the message's own title dimmed where it has
                            // none; the keys that send it on the right.
                            title: set.label(n).trim().isNotEmpty
                                ? Text(set.label(n).trim())
                                : Text(
                                    m.messageTitle(n: n),
                                    style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                                  ),
                            trailing: KeyerMessageKeys(services: widget.services, n: n),
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
                                builder: (context) => _CwMessageDialog(n: n, message: set.message(n), label: set.label(n), readOnly: isOfferedSetId(set.id)),
                              );
                              if (edited == null || !mounted) return;
                              await _edit(n, edited);
                            },
                            mouseCursor: SystemMouseCursors.click,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        haloDialogFooterBand(
          context,
          help: TextButton(
            onPressed: () => showHaloDialog<void>(
              context: context,
              builder: (context) => _CwMessagesHelpDialog(esm: widget.services.settings.experimentEnabled('esm') /* stored key, see experiments.yaml */),
            ),
            child: Text(m.help),
          ),
          // Done, not Save: every edit is already stored, so the way out
          // commits nothing (dialog_footer_convention_test.dart). Revert
          // beside it once there is something to put back.
          secondary: _changed ? TextButton(onPressed: () => unawaited(_revert()), child: Text(context.t.common.revert)) : null,
          cancel: FilledButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(context.t.common.done)),
        ),
      ],
    );
  }
}

/// Message 1's repeat, in either keyer dialog: whether it repeats, and the
/// cooldown before it goes again ([keyerRepeatCooldowns]). Both apply as
/// they change, like the rest of the band they sit on.
class RepeatFields extends StatelessWidget {
  final bool on;
  final Duration cooldown;
  final ValueChanged<bool> onToggled;
  final ValueChanged<int> onCooldown;

  const RepeatFields({super.key, required this.on, required this.cooldown, required this.onToggled, required this.onCooldown});

  @override
  Widget build(BuildContext context) {
    final m = context.t.settings.radio.cwMessages;
    final seconds = '${cooldown.inSeconds}';
    return Row(
      children: [
        // The name lives in Semantics, per docs/design/user-interface.md.
        Semantics(
          label: m.repeat,
          child: Switch(value: on, onChanged: onToggled),
        ),
        const SizedBox(width: Space.xs),
        Text(m.repeatShort, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: Space.md),
        Expanded(
          child: DropdownButtonFormField<String>(
            key: ValueKey('cooldown:$seconds'),
            isExpanded: true,
            initialValue: seconds,
            icon: dropdownTrailingIcon,
            decoration: poloFieldDecoration(context, m.cooldown).copyWith(filled: true, fillColor: Theme.of(context).colorScheme.surface),
            menuMaxHeight: dropdownMenuMaxHeight(context),
            items: [
              for (final option in keyerRepeatCooldowns)
                DropdownMenuItem<String>(
                  value: option,
                  child: Text(m.cooldownSeconds(n: option)),
                ),
            ],
            onChanged: (choice) => choice == null ? null : onCooldown(int.parse(choice)),
          ),
        ),
      ],
    );
  }
}

/// Enter Sends Messages as a switch, in both keyer dialogs, because the one
/// setting plays CW messages and voice memories alike
/// (docs/design/logging-fields.md § Enter Sends Messages). On or off only:
/// Run or S&P is the set's operating style, which outlives ESM and is set
/// elsewhere (docs/design/logging-fields.md § Operating style).
class EnterSendsField extends StatelessWidget {
  final CatService cat;

  const EnterSendsField({super.key, required this.cat});

  @override
  Widget build(BuildContext context) {
    final m = context.t.settings.radio.enterSends;
    return ValueListenableBuilder(
      valueListenable: cat.enterSends,
      builder: (context, esm, _) => Row(
        children: [
          // The name lives in Semantics, per docs/design/user-interface.md.
          Semantics(
            label: m.field,
            child: Switch(
              value: esm.on,
              onChanged: (on) => cat.setEnterSends(on: on),
            ),
          ),
          const SizedBox(width: Space.xs),
          Flexible(child: Text(m.field, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
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
          Padding(padding: EdgeInsets.fromLTRB(haloDialogSideInset(context), Space.xl, haloDialogSideInset(context), Space.md), child: Text(m.helpIntro)),
          for (final (template, meaning) in rows) row(template, meaning),
          // The placeholders put together, headed apart from the list: it
          // is one message, not one more value.
          Padding(padding: EdgeInsets.fromLTRB(haloDialogSideInset(context), Space.xl, haloDialogSideInset(context), 0), child: Text(m.helpFullExample)),
          row('{{ qso.call }} {{ qso.rst | cut }} {{ qso.serial | pad: 3 | cut }}', m.helpExample),
          if (esm) ...[
            Padding(padding: EdgeInsets.fromLTRB(haloDialogSideInset(context), Space.xl, haloDialogSideInset(context), Space.md), child: Text(m.helpEsmIntro)),
            for (final (template, meaning) in esmRows) row(template, meaning),
            row(
              'TU {% if next.fullCall != blank %}{{ next.call }} {{ keyer.msg2 }}{% elsif next.partial != blank %}{{ next.partial }}?{% endif %}',
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

/// Names a new set, or renames one — CW's or the voice messages'. Nothing
/// but a field and the two verbs: the set it will copy is already chosen, in
/// the pane behind this one.
class SetNameDialog extends StatefulWidget {
  final String title;
  final String field;

  /// The name to start from — empty for a new set, the current one when
  /// renaming, so a rename is an edit rather than a retype.
  final String initial;

  const SetNameDialog({super.key, required this.title, required this.field, this.initial = ''});

  @override
  State<SetNameDialog> createState() => SetNameDialogState();
}

class SetNameDialogState extends State<SetNameDialog> {
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
/// caller knows which set they belong to. [readOnly] shows a message of a
/// set nobody here changes (an extension's), and hands nothing back.
class _CwMessageDialog extends StatefulWidget {
  final int n;
  final String message;
  final String label;
  final bool readOnly;

  const _CwMessageDialog({required this.n, required this.message, required this.label, this.readOnly = false});

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

  void _save() => Navigator.of(context).pop(widget.readOnly ? null : (message: _message.text.trim(), label: _label.text.trim()));

  @override
  Widget build(BuildContext context) {
    final m = context.t.settings.radio.cwMessages;
    // Zero content padding, with the settings row inset published instead
    // (`list`): the Details band reads it, and the fields take the same one
    // themselves.
    final rowInset = EdgeInsets.symmetric(horizontal: haloDialogSideInset(context));
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
              readOnly: widget.readOnly,
              autofocus: !widget.readOnly,
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
              readOnly: widget.readOnly,
              textCapitalization: TextCapitalization.sentences,
              // Left blank, the key is labelled with its message.
              decoration: poloFieldDecoration(context, m.labelField, hintText: _message.text.trim()),
              onSubmitted: (_) => _save(),
            ),
          ),
        ],
      ),
      // Done, not Cancel, where there is nothing to save
      // (dialog_footer_convention_test.dart).
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(widget.readOnly ? context.t.common.done : context.t.common.cancel)),
      actions: [if (!widget.readOnly) FilledButton(onPressed: _save, child: Text(context.t.common.save))],
    );
  }
}

/// The keyer's speed, sized to its value ("30 WPM") rather than stretched —
/// what the radio reports, and what it is told on a pick. Follows the radio
/// while the dialog is open, and is disabled while nothing can key.
class _KeyerSpeedField extends StatelessWidget {
  final CatService cat;

  /// The radio whose keyer's speed this is.
  final RadioKeyer keyer;

  const _KeyerSpeedField({required this.cat, required this.keyer});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: cat,
    builder: (context, _) {
      final ks = context.t.settings.radio.keyerSpeed;
      final range = keyer.keyerSpeedRange;
      final speed = keyer.keyerSpeed;
      final canKey = keyer.canKeyCw;
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
          onChanged: canKey ? (wpm) => wpm == null ? null : keyer.setKeyerSpeed(wpm) : null,
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

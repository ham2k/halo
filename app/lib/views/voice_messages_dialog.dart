// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The voice message editor: one row per message — the key, the label beside
// it, and how long it plays for underneath — each row opening its own
// dialog, where the label, the message's length, PLAYING it and RECORDING it
// live. The list names the messages; the dialog is where anything happens to
// one. Reached from the Station dialog's keyer row, the keyer area's voice
// pill and Settings → Radio's Phone Keyer row. Shaped like the CW editor
// deliberately, minus what has no meaning here: there is no speed and no
// message text.
//
// The messages are the radio's own memories, or a SET recorded on this
// computer as CW's are; which of the two is the Station panel's Phone Keying
// pick (VoiceKeyingSource). The radio's audio lives in the radio, and the app
// stores only a label (`voiceMessageLabel1..8`) and a measured length
// (`voiceMessageDuration1..8`, both in the Radio group). The length is
// MEASURED, never typed and never asked for: every play times itself
// (CatService.playVoiceMemory, docs/design/cat.md § Voice keying). A radio
// that names and times its own memories (a FlexRadio's DVK) is the
// exception: its names and lengths are the ones shown, and a label saved
// here is saved on the radio. A set is recordings on this computer
// (`VoiceMessageSet`, docs/design/cat.md § The computer's voice keyer), and
// the sound devices and delays it plays with are in their own dialog
// (showComputerVoiceSettingsDialog), reached from the same pick.
//
// Unlike the CW editor, nothing here is a draft: a recording is written the
// moment it ends, so a Cancel that undid the set it went into could not undo
// the recording. Every pick and edit applies as it is made, and deleting a
// set — its recordings with it — asks first.
//
// With no radio that can play, the rows stay editable and the buttons are
// gone: a label is worth setting before the rig is on the desk.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../services/halo_services.dart';
import 'package:halo_audio/halo_audio.dart';

import '../services/cat/cat_service.dart';
import '../services/error_reporting_service.dart';
import '../services/cat/computer_voice_keyer.dart';
import '../services/cat/voice_words.dart';
import '../services/peer/peer_station_radios.dart';
import '../services/settings_service.dart';
import 'settings/keyboard_shortcuts_panel.dart' show KeyerMessageKeys;
import 'keying_pickers.dart' show phoneKeyingParts;
import 'cw_messages_dialog.dart' show EnterSendsField, KeyerUnsupportedNotice, RepeatFields, SetNameDialog, cwMessageNumberIcons;
import 'keyer_area.dart' show keyerOrSay;
import 'voice_words_pane.dart';

/// [radio] is the radio whose memories the dialog shows and plays, `A` or
/// `B` — a keyer area's own; null for the operator's. The memories are audio
/// in each rig, so each radio's are its own.
Future<void> showVoiceMessagesDialog(BuildContext context, HaLoServices services, {String? radio}) => showModalPane<void>(
  context,
  title: context.t.settings.radio.voiceMessages.title,
  closeLabel: context.t.common.close,
  // The rows scroll under a pinned picker and a pinned footer, whose Done is
  // the way out — so no X in the header (haloDialogFooterBand).
  scrollable: false,
  closeButton: false,
  builder: (_) => _VoiceMessagesPane(services: services, radio: radio ?? services.cat.operatorRadio),
);

class _VoiceMessagesPane extends StatelessWidget {
  final HaLoServices services;
  final String radio;

  const _VoiceMessagesPane({required this.services, required this.radio});

  /// A name no other set answers to: two rows of the same name could not be
  /// told apart.
  String _uniqueName(BuildContext context, String wanted) {
    final taken = {for (final set in services.settings.voiceMessageSets) set.name};
    var name = wanted;
    var suffix = 2;
    while (taken.contains(name)) {
      name = '$wanted $suffix';
      suffix++;
    }
    return name;
  }

  Future<void> _newSet(BuildContext context) async {
    final m = context.t.settings.radio.voiceMessages;
    final name = await showHaloDialog<String>(
      context: context,
      builder: (context) => SetNameDialog(title: m.newSet, field: m.newSetName),
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    await services.cat.addVoiceMessageSet(_uniqueName(context, name.trim()));
  }

  Future<void> _rename(BuildContext context, VoiceMessageSet set) async {
    final m = context.t.settings.radio.voiceMessages;
    final name = await showHaloDialog<String>(
      context: context,
      builder: (context) => SetNameDialog(title: m.renameSet, field: m.newSetName, initial: set.name),
    );
    if (name == null || name.trim().isEmpty || name.trim() == set.name || !context.mounted) return;
    await services.cat.renameVoiceMessageSet(set.id, _uniqueName(context, name.trim()));
  }

  /// Asks first: the recordings go with the set, and nothing brings them
  /// back.
  Future<void> _delete(BuildContext context, VoiceMessageSet set) async {
    final m = context.t.settings.radio.voiceMessages;
    final confirmed = await showHaloDialog<bool>(
      context: context,
      builder: (context) => HaloDialog(
        title: Text(m.deleteSet),
        content: Text(m.deleteSetConfirm(name: set.name)),
        cancel: TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.t.common.cancel)),
        actions: [FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(context.t.common.delete))],
      ),
    );
    if (confirmed == true) await services.cat.deleteVoiceMessageSet(set.id);
  }

  @override
  Widget build(BuildContext context) {
    final m = context.t.settings.radio.voiceMessages;
    final theme = Theme.of(context);
    final settings = services.settings;
    final cat = services.cat;
    final keyer = cat.keyer(radio);
    return ListenableBuilder(
      listenable: Listenable.merge([settings, cat, keyer.voiceActivity]),
      builder: (context, _) {
        final canPlay = keyer.canPlayVoice;
        // The radio's own count while one can play; every label otherwise,
        // so a memory the next radio has is not unnameable until it is on.
        final count = canPlay ? keyer.voiceMemoryCount : SettingsService.voiceMessageCount;
        final activity = keyer.voiceActivity.value;
        final fromComputer = keyer.voiceMessagesFromComputer;
        final active = settings.activeVoiceMessageSet;
        // As showFormPane's: min so the dialog card fits the rows,
        // spaceBetween so full screen, where the pane IS the screen, the
        // slack falls above the footer rather than under it.
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
                  // Pinned above the rows, on the band the CW editor's picker sits
                  // on, and stating the same rule: only message 1 repeats.
                  Container(
                    color: haloDialogBandColorAt(context),
                    padding: const EdgeInsets.fromLTRB(Space.xxl, Space.md, Space.xxl, Space.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Where this radio's messages come from, as the
                        // Station panel picks it.
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.md),
                          child: Builder(
                            builder: (context) {
                              final parts = phoneKeyingParts(context, services, radio: radio, filled: true);
                              return Row(
                                children: [
                                  Expanded(child: parts.picker),
                                  for (final control in parts.controls) ...[const SizedBox(width: Space.sm), control],
                                ],
                              );
                            },
                          ),
                        ),
                        // A radio with no voice memories at all, connected or not.
                        if (!keyer.radio1HasVoiceMemories)
                          KeyerUnsupportedNotice(text: keyer.phoneKeyingOff ? context.t.settings.station.phoneKeyingOff : m.notSupported),
                        // ESM, then message 1's repeat on a row of its own: the
                        // switch and its cooldown need the width.
                        if (settings.experimentEnabled('esm') /* stored key, see experiments.yaml */ ) ...[
                          EnterSendsField(
                            value: (on: cat.enterSends.value.on, running: cat.isRunning(radio)),
                            onChanged: (value) {
                              cat.setEnterSends(on: value.on);
                              cat.setRunning(radio, value.running);
                            },
                          ),
                          const SizedBox(height: Space.md),
                        ],
                        RepeatFields(
                          on: settings.voiceRepeat,
                          cooldown: settings.voiceRepeatCooldown,
                          onToggled: (on) {
                            // Off ends a chain already counting down — on
                            // either radio, since the repeat is theirs both.
                            if (!on) {
                              for (final radio in ['A', 'B']) {
                                cat.keyer(radio).cancelKeyerRepeat();
                              }
                            }
                            unawaited(settings.setVoiceRepeat(on));
                          },
                          onCooldown: (seconds) => unawaited(settings.setVoiceRepeatCooldown(seconds)),
                        ),
                        if (fromComputer && keyer.computerVoiceProblem != null) ...[
                          const SizedBox(height: Space.md),
                          KeyerUnsupportedNotice(
                            text: computerVoiceProblemText(context, keyer.computerVoiceProblem!, detail: keyer.computerVoiceProblemDetail),
                          ),
                        ],
                        // Last, right above the messages it picks.
                        if (fromComputer) ...[
                          const SizedBox(height: Space.md),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey('voiceSet:${active.id}'),
                                  isExpanded: true,
                                  initialValue: active.id,
                                  icon: dropdownTrailingIcon,
                                  decoration: poloFieldDecoration(context, m.sets).copyWith(filled: true, fillColor: theme.colorScheme.surface),
                                  menuMaxHeight: dropdownMenuMaxHeight(context),
                                  items: [
                                    for (final set in settings.voiceMessageSets)
                                      DropdownMenuItem(
                                        value: set.id,
                                        child: Text(set.name, overflow: TextOverflow.ellipsis),
                                      ),
                                  ],
                                  onChanged: (id) => id == null ? null : unawaited(cat.selectVoiceMessageSet(id)),
                                ),
                              ),
                              const SizedBox(width: Space.sm),
                              // As in the CW editor. The default set is always
                              // there: it is neither renamed nor deleted.
                              IconButton(
                                icon: Icon(MdiIcons.fileOutline, semanticLabel: m.newSet),
                                onPressed: () => _newSet(context),
                              ),
                              IconButton(
                                icon: Icon(MdiIcons.pencilOutline, semanticLabel: m.renameSet),
                                onPressed: active.isDefault ? null : () => _rename(context, active),
                              ),
                              IconButton(
                                icon: Icon(MdiIcons.trashCanOutline, semanticLabel: m.deleteSet, color: active.isDefault ? null : theme.colorScheme.error),
                                onPressed: active.isDefault ? null : () => _delete(context, active),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Flexible(
                    child: SettingsList(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var n = 1; n <= count; n++)
                              ListTile(
                                leading: Icon(cwMessageNumberIcons[n - 1]),
                                // The label, or the message's own title dimmed where it has
                                // none; the keys that send it on the right.
                                title: keyer.voiceMessageShownLabel(n).trim().isNotEmpty
                                    ? Text(keyer.voiceMessageShownLabel(n).trim())
                                    : Text(
                                        m.messageTitle(n: n),
                                        style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                                      ),
                                trailing: KeyerMessageKeys(services: services, n: n),
                                // What the memory IS — its length — unless something
                                // is being done with it right now, which is the more
                                // urgent thing to say.
                                subtitle: Text(
                                  activity?.memory == n
                                      ? (activity!.doubtful ? m.doubtful : (activity.recording ? m.recording : m.playing))
                                      : (keyer.voiceMessageDuration(n) > 0
                                            ? voiceDurationText(context, keyer.voiceMessageDuration(n))
                                            : voiceUnknownLengthText(context, keyer, n)),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: activity?.memory == n || keyer.voiceMessageDuration(n) > 0
                                        ? null
                                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                                onTap: () => showHaloDialog<void>(
                                  context: context,
                                  builder: (context) => _VoiceMessageDialog(services: services, radio: radio, n: n),
                                ),
                                mouseCursor: SystemMouseCursors.click,
                              ),
                            // The recordings messages are said with — radio1's,
                            // as the computer's recordings are.
                            if (fromComputer && radio == 'A' && settings.experimentEnabled('words') /* stored key, see experiments.yaml */ )
                              ListTile(
                                leading: const Icon(MdiIcons.alphabetical),
                                title: Text(context.t.settings.radio.voiceWords.title),
                                subtitle: Text(m.wordsDescription, style: theme.textTheme.bodySmall),
                                onTap: () => showVoiceWordsPane(context, services),
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
            // Done, not Close: the footer convention for a surface with
            // nothing to commit (dialog_footer_convention_test.dart).
            haloDialogFooterBand(
              context,
              cancel: TextButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(context.t.common.done)),
            ),
          ],
        );
      },
    );
  }
}

/// One memory: its label, how long it plays for, and the way to record it.
/// The label is an edit, saved on Save; measuring and recording are things
/// the RADIO does, so they happen as they are pressed and a Cancel does not
/// undo them — there is nothing here to undo them to. "Say with my words"
/// is saved on Save too, or as Play on Radio or Record acts on it: what
/// goes on the air is what the field says, and a recording made in place of
/// the words is the one that plays.
class _VoiceMessageDialog extends StatefulWidget {
  final HaLoServices services;
  final String radio;
  final int n;

  const _VoiceMessageDialog({required this.services, required this.radio, required this.n});

  @override
  State<_VoiceMessageDialog> createState() => _VoiceMessageDialogState();
}

class _VoiceMessageDialogState extends State<_VoiceMessageDialog> {
  late final _opened = widget.services.cat.keyer(widget.radio).voiceMessageLabel(widget.n);
  late final _label = TextEditingController(text: _opened);
  late final _template = TextEditingController(text: widget.services.cat.keyer(widget.radio).voiceMessageTemplate(widget.n));

  /// Whether this message can be said from the operator's words: this
  /// radio's recordings on this computer, with voiced words on.
  bool get _voiceable =>
      widget.services.cat.keyer(widget.radio).voiceMessagesFromComputer &&
      widget.services.settings.experimentEnabled('words') /* stored key, see experiments.yaml */;

  /// What the template says for the draft as it is, and what it needs that
  /// is not recorded — or why it says nothing. Null before the first preview.
  String? _says;
  String? _missing;
  Timer? _previewing;

  @override
  void initState() {
    super.initState();
    if (_voiceable) unawaited(_preview());
  }

  void _templateChanged(String _) {
    _previewing?.cancel();
    _previewing = Timer(const Duration(milliseconds: 300), () => unawaited(_preview()));
  }

  /// Touches neither [context] nor [setState] before its first await: the
  /// first preview starts in [initState].
  Future<void> _preview() async {
    final words = widget.services.cat.keyer('A').voicedWords;
    final template = _template.text;
    if (words == null || template.trim().isEmpty) {
      if (_says != null || _missing != null) setState(() => _says = _missing = null);
      return;
    }
    String? says, missing;
    try {
      final preview = await words.preview(template);
      if (!mounted) return;
      final m = context.t.settings.radio.voiceMessages;
      if (preview == null) {
        says = m.previewNoOperation;
      } else {
        says = m.willSay(words: spokenText(preview.plan));
        final absent = [for (final word in preview.plan.unrecorded) word.spoken, ...preview.plan.unspeakable];
        if (absent.isNotEmpty) missing = m.willSayMissing(words: absent.join(', '));
      }
    } on VoicedMessageRefused catch (e) {
      reportRefusalCause(e, told: mounted);
      if (!mounted) return;
      says = computerVoiceProblemText(context, e.problem, detail: e.detail);
    }
    if (!mounted || template != _template.text) return;
    setState(() {
      _says = says;
      _missing = missing;
    });
  }

  /// A recording played on the computer's own speakers, for the operator to
  /// hear what they recorded without putting it on the air.
  AudioPlayback? _listening;

  void _listen() {
    final playback = widget.services.cat.keyer(widget.radio).listenToVoiceMessage(widget.n);
    if (playback == null) return;
    setState(() => _listening = playback);
    unawaited(
      playback.done.then((_) {
        if (mounted && identical(_listening, playback)) setState(() => _listening = null);
      }),
    );
  }

  void _stopListening() {
    _listening?.stop();
    setState(() => _listening = null);
  }

  /// The template said for the draft as it is, on the computer's own
  /// speakers.
  AudioPlayback? _listeningToWords;

  Future<void> _listenToWords() async {
    final words = widget.services.cat.keyer('A').voicedWords;
    if (words == null) return;
    _stopListeningToWords();
    final AudioPlayback playback;
    try {
      playback = await words.listenToTemplate(widget.n, _template.text);
    } on VoicedMessageRefused catch (e) {
      reportRefusalCause(e, told: mounted);
      if (mounted) setState(() => _missing = computerVoiceProblemText(context, e.problem, detail: e.detail));
      return;
    }
    if (!mounted) {
      playback.stop();
      return;
    }
    setState(() => _listeningToWords = playback);
    unawaited(
      playback.done.then((_) {
        if (mounted && identical(_listeningToWords, playback)) setState(() => _listeningToWords = null);
      }),
    );
  }

  void _stopListeningToWords() {
    _listeningToWords?.stop();
    if (_listeningToWords != null) setState(() => _listeningToWords = null);
  }

  /// Whether the operator changed the label. A Save without a change writes
  /// nothing: on a radio that names its own memories the field may hold what
  /// was shown before the radio said otherwise, and saving that would rename
  /// the slot for every client of the radio.
  bool get _edited => _label.text != _opened;

  @override
  void dispose() {
    _listening?.stop();
    _listeningToWords?.stop();
    _previewing?.cancel();
    _label.dispose();
    _template.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    // Nothing to save for a peer's memory: the name is that device's, and
    // writing this station's own label would rename audio nobody is looking
    // at.
    if (_edited && widget.services.cat.keyer(widget.radio).voiceMessagesAreLocal) {
      await widget.services.cat.keyer(widget.radio).setVoiceMessageLabel(widget.n, _label.text.trim());
    }
    await _keepTemplate();
    navigator.pop();
  }

  /// Writes the field's words as the message's, where they differ from what
  /// is stored.
  Future<void> _keepTemplate() async {
    final keyer = widget.services.cat.keyer(widget.radio);
    if (_voiceable && _template.text.trim() != keyer.voiceMessageTemplate(widget.n).trim()) {
      await keyer.setVoiceMessageTemplate(widget.n, _template.text.trim());
    }
  }

  /// The template a message is said with, and what it says now. What to
  /// write in it is under Help.
  Widget _templateFields(BuildContext context) {
    final m = context.t.settings.radio.voiceMessages;
    final theme = Theme.of(context);
    final note = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.8));
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xxl, 0, Space.xxl, Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _template,
            minLines: 1,
            maxLines: 3,
            style: const TextStyle(fontFamily: 'RobotoMono'),
            decoration: poloFieldDecoration(context, m.templateField).copyWith(
              suffixIcon: _listeningToWords != null
                  ? IconButton(
                      icon: Icon(MdiIcons.stop, semanticLabel: m.stopButton),
                      onPressed: _stopListeningToWords,
                    )
                  : IconButton(
                      icon: Icon(MdiIcons.headphones, semanticLabel: m.listenButton),
                      onPressed: _template.text.trim().isEmpty ? null : () => unawaited(_listenToWords()),
                    ),
            ),
            onChanged: _templateChanged,
          ),
          if (_says != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: Text(_says!, style: note),
            ),
          if (_missing != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(_missing!, style: note?.copyWith(color: theme.colorScheme.error)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = context.t.settings.radio.voiceMessages;
    final settings = widget.services.settings;
    final cat = widget.services.cat;
    final keyer = cat.keyer(widget.radio);
    // Zero content inset so the bands run edge to edge; the fields take the
    // dialog's usual inset themselves (halo_dialog.dart's default).
    const rowInset = EdgeInsets.symmetric(horizontal: Space.xxl);
    return ListenableBuilder(
      listenable: Listenable.merge([settings, cat, keyer.voiceActivity, _template]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final activity = keyer.voiceActivity.value;
        final recording = activity?.memory == widget.n && activity!.recording;
        final playing = activity?.memory == widget.n && !activity!.recording;
        final busy = activity != null;
        final duration = keyer.voiceMessageDuration(widget.n);
        // Said with the operator's words, the message plays no recording of
        // its own: one recorded now would never be heard.
        final saidWithWords = _voiceable && _template.text.trim().isNotEmpty;
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
                  controller: _label,
                  // Not the operator's to name while the audio is a peer's:
                  // the label describes THAT radio's recording, and one
                  // typed here would be saved against this station's own
                  // memories, which are not what the row above is showing.
                  readOnly: !keyer.voiceMessagesAreLocal,
                  autofocus: keyer.voiceMessagesAreLocal,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: poloFieldDecoration(context, m.labelField),
                  onSubmitted: (_) => _save(),
                ),
              ),
              if (_voiceable) _templateFields(context),
              // Whose memories these are, when they are not this device's —
              // said once, above the buttons, because it explains both the
              // read-only label and the lengths beside it.
              if (!keyer.voiceMessagesAreLocal)
                Padding(
                  padding: rowInset.copyWith(bottom: Space.md),
                  child: Text(
                    m.namedOnDevice(device: peerDeviceLabel(cat.followedPeerRadio)),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.8)),
                  ),
                )
              // A name typed here reaches every other client of that radio,
              // which is worth knowing before typing one.
              else if (keyer.voiceMessagesNamedOnRadio)
                Padding(
                  padding: rowInset.copyWith(bottom: Space.md),
                  child: Text(m.namedOnRadio, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.8))),
                ),
              // Shown, never asked for: every play times itself, so a memory
              // is measured the first time it is used and there is nothing
              // here to press.
              // One row for everything the radio can do with this memory,
              // its measured length between the two verbs: playing is what
              // measures it, so an unmeasured memory is one Play away from
              // filling the gap.
              Padding(
                padding: rowInset.copyWith(top: Space.md, bottom: Space.lg),
                child: Row(
                  children: [
                    // Drawn even where the CAT cannot record, and disabled
                    // there: absent, recording looks like something this app
                    // does not do rather than something this RADIO does not.
                    if (recording)
                      FilledButton.tonalIcon(
                        onPressed: keyer.stopVoice,
                        icon: Icon(MdiIcons.stop, color: theme.colorScheme.error),
                        label: Text(m.stopButton),
                      )
                    else
                      FilledButton.tonalIcon(
                        onPressed: busy || !keyer.canRecordVoice || saidWithWords
                            ? null
                            : () async {
                                if (!keyerOrSay(context, widget.services, keyer, () => keyer.canRecordVoice)) return;
                                // A file being listened to is held open, and on
                                // Windows the recording cannot then take its place.
                                if (_listening != null) _stopListening();
                                // The field is empty here: words still stored
                                // would play instead of what is recorded.
                                await _keepTemplate();
                                keyer.recordVoiceMemory(widget.n);
                              },
                        icon: const Icon(MdiIcons.recordCircleOutline),
                        label: Text(m.recordButton),
                      ),
                    Expanded(
                      child: Text(
                        duration > 0 ? voiceDurationText(context, duration) : voiceUnknownLengthText(context, keyer, widget.n),
                        textAlign: TextAlign.center,
                        style: duration > 0
                            ? theme.textTheme.bodyLarge
                            : theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    ),
                    if (keyer.voiceMessagesFromComputer && duration > 0) ...[
                      if (_listening != null)
                        FilledButton.tonalIcon(onPressed: _stopListening, icon: const Icon(MdiIcons.stop), label: Text(m.stopButton))
                      else
                        FilledButton.tonalIcon(onPressed: busy ? null : _listen, icon: const Icon(MdiIcons.headphones), label: Text(m.listenButton)),
                    ],
                  ],
                ),
              ),
              // On a line of its own: this one goes out over the air, where
              // Listen above stays on the computer.
              if (keyer.canPlayVoice)
                Padding(
                  padding: rowInset.copyWith(bottom: Space.lg),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: playing
                        ? FilledButton.tonalIcon(onPressed: keyer.stopVoice, icon: const Icon(MdiIcons.stop), label: Text(m.stopButton))
                        : FilledButton.tonalIcon(
                            // Once: this is the operator listening to the
                            // memory, not calling CQ with it.
                            onPressed: busy
                                ? null
                                : () async {
                                    if (!keyerOrSay(context, widget.services, keyer, () => keyer.canPlayVoice)) return;
                                    await _keepTemplate();
                                    keyer.playVoiceMemory(widget.n, repeat: false);
                                  },
                            icon: const Icon(MdiIcons.play),
                            label: Text(m.playOnRadio),
                          ),
                  ),
                ),
              // Why the button above is disabled, before anything about how
              // to use it: an operator who cannot record from here needs to
              // know that first.
              if (!keyer.canRecordVoice)
                Padding(
                  padding: rowInset.copyWith(bottom: Space.xl),
                  child: Text(m.recordOnRadio, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.8))),
                ),
              // Under the buttons: it explains what to do AFTER pressing
              // Record, not what Record is (EquipmentModel.recordingHelp).
              if (keyer.canRecordVoice && keyer.voiceRecordingHelp != null)
                Padding(
                  padding: rowInset.copyWith(bottom: Space.xl),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        // Named, because the note describes ONE rig's front
                        // panel and a station can have more than one radio.
                        TextSpan(
                          text: '${m.recordHelpTitle(model: keyer.voiceRecordingHelp!.model)} ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: keyer.voiceRecordingHelp!.text),
                      ],
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.8)),
                  ),
                ),
            ],
          ),
          // The folder rather than the file: opening the file would play it
          // on whatever the system plays sound files with, and the folder is
          // where a sound file is put in or taken out.
          secondary: keyer.voiceMessagesFromComputer ? TextButton(onPressed: () => keyer.revealVoiceMessage(widget.n), child: Text(m.openFileButton)) : null,
          help: _voiceable
              ? TextButton(
                  onPressed: () => showHaloDialog<void>(context: context, builder: (context) => const _VoiceTemplateHelpDialog()),
                  child: Text(m.help),
                )
              : null,
          cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
          actions: [FilledButton(onPressed: _save, child: Text(context.t.common.save))],
        );
      },
    );
  }
}

/// What to write in "Say with my words": the values a voiced message is
/// made of, and one whole message. Only what the operator's words can say —
/// a name or a state would be spelled letter by letter.
class _VoiceTemplateHelpDialog extends StatelessWidget {
  const _VoiceTemplateHelpDialog();

  @override
  Widget build(BuildContext context) {
    final m = context.t.settings.radio.voiceMessages;
    final theme = Theme.of(context);
    // Templates are code, identical in every language; only what they mean
    // is translated.
    final rows = [('{{ qso.call }}', m.templateHelpCall), ('{{ qso.rst }}', m.templateHelpReport), ('{{ phone.msg2 }}', m.templateHelpMessage)];
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
          Padding(padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.md), child: Text(m.templateHelp)),
          for (final (template, meaning) in rows) row(template, meaning),
          Padding(padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, 0), child: Text(m.helpFullExample)),
          row('{{ qso.call }} {{ qso.rst }} QSL?', m.helpExample),
        ],
      ),
      // Done, not Cancel: nothing here can be changed.
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.done)),
    );
  }
}

/// [plan]'s words as the operator reads them: a part's words with spaces,
/// the parts apart, a message's recording by its key.
String spokenText(VoicedPlan plan) => [
  for (final (i, piece) in plan.pieces.indexed)
    '${i > 0 && piece.startsPart
        ? ' · '
        : i > 0
        ? ' '
        : ''}${switch (piece) {
      WordPiece(:final word) => word.spoken,
      RecordingPiece(:final message) => 'M$message',
    }}',
].join();

/// A measured length as seconds with one decimal — "4.2 s". The measurement
/// has milliseconds in it (settings_service.dart), and a memory rounded to
/// the second reads as if the app guessed.
String voiceDurationText(BuildContext context, int millis) => context.t.settings.radio.voiceMessages.durationSeconds(n: (millis / 1000).toStringAsFixed(1));

/// What memory [n] with no length says: on a radio that times its own
/// memories, no length is an empty memory, and playing it measures nothing;
/// a recording on the computer may be a file it cannot play.
String voiceUnknownLengthText(BuildContext context, RadioKeyer keyer, int n) {
  final m = context.t.settings.radio.voiceMessages;
  if (keyer.voiceMessageVoiced(n)) return m.voiced;
  if (keyer.voiceMessagesFromComputer) return keyer.voiceMessageUnplayable(n) ? m.unplayable : m.notRecorded;
  return keyer.voiceMessagesNamedOnRadio ? m.emptyOnRadio : m.notMeasured;
}

/// Reports the failure behind [refusal], where there is one — [told] when
/// the refusal is on the operator's screen, so no generic notice says it
/// again.
void reportRefusalCause(VoicedMessageRefused refusal, {required bool told}) {
  final cause = refusal.cause;
  if (cause != null) ErrorReportingService.report(cause, refusal.causeStack, context: 'voice:render-message', told: told);
}

String computerVoiceProblemText(BuildContext context, ComputerVoiceProblem problem, {String? detail}) {
  final m = context.t.settings.radio.voiceMessages;
  return switch (problem) {
    ComputerVoiceProblem.noOutput => m.problemNoOutput,
    ComputerVoiceProblem.outputMissing => m.problemOutputMissing,
    ComputerVoiceProblem.inputMissing => m.problemInputMissing,
    ComputerVoiceProblem.deviceFailed => m.problemDeviceFailed,
    ComputerVoiceProblem.notRecorded => m.problemNotRecorded,
    ComputerVoiceProblem.recordingSilent => m.problemRecordingSilent,
    ComputerVoiceProblem.cannotKey => m.problemCannotKey,
    ComputerVoiceProblem.radioAudioUnavailable => m.problemRadioAudioUnavailable,
    ComputerVoiceProblem.sourceRefused => m.problemSourceRefused,
    ComputerVoiceProblem.unplayable => m.problemUnplayable,
    ComputerVoiceProblem.recordingFailed => m.problemRecordingFailed,
    ComputerVoiceProblem.fileFailed => m.problemFileFailed,
    ComputerVoiceProblem.wordsMissing => m.problemWordsMissing(words: detail ?? ''),
    ComputerVoiceProblem.templateFailed => m.problemTemplateFailed(error: detail ?? ''),
    ComputerVoiceProblem.noOperation => m.problemNoOperation,
    ComputerVoiceProblem.nothingSaid => m.problemNothingSaid,
  };
}

/// The computer's voice keyer settings for [radio]'s (`A` or `B`) rig, from
/// its Phone Keying pick. Done, not Save: like the fields in it, nothing
/// here is a draft. Under SO2R each radio has a dialog of its own, named for
/// it, and the same device may be picked in both.
Future<void> showComputerVoiceSettingsDialog(BuildContext context, HaLoServices services, {String radio = 'A'}) => showHaloDialog<void>(
  context: context,
  builder: (context) {
    final st = context.t.settings.station;
    final so2r = services.settings.experimentEnabled('so2r') /* stored key, see experiments.yaml */;
    return HaloDialog(
      title: Text(so2r ? st.so2rRadioName(radio: radio, name: st.computerVoiceSettings) : st.computerVoiceSettings),
      content: ListenableBuilder(
        listenable: services.cat,
        builder: (context, _) => _ComputerVoiceFields(keyer: services.cat.keyer(radio), audio: services.cat.computerVoiceAudio!, so2r: so2r),
      ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.done)),
    );
  },
);

/// The computer's voice keyer settings, on [keyer]'s radio's node: the
/// sound devices, and the delays around the audio. Per radio, unlike the set
/// in use: the sound card is the rig's, and so is how long it takes to
/// switch. They apply as they change.
class _ComputerVoiceFields extends StatefulWidget {
  final RadioKeyer keyer;
  final VoiceAudio audio;

  /// Whether to say which radio's output this is: with two radios, two
  /// dialogs each saying "Send audio to" would not say to which.
  final bool so2r;

  const _ComputerVoiceFields({required this.keyer, required this.audio, required this.so2r});

  @override
  State<_ComputerVoiceFields> createState() => _ComputerVoiceFieldsState();
}

class _ComputerVoiceFieldsState extends State<_ComputerVoiceFields> {
  static const _leadOptions = [0, 100, 150, 200, 250, 300, 400, 500, 750];
  static const _tailOptions = [0, 50, 100, 150, 200, 300, 500];

  /// Read once as the dialog opens: listing the devices is a call into the
  /// system's audio layer, not something to repeat on every rebuild.
  late List<AudioDevice> _outputs;
  late List<AudioDevice> _inputs;

  @override
  void initState() {
    super.initState();
    try {
      _outputs = widget.audio.outputs();
      _inputs = widget.audio.inputs();
    } on HaloAudioException catch (e, st) {
      reportVoiceFailure('devices', e, st);
      _outputs = _inputs = const [];
    }
  }

  void _set(Map<String, dynamic> changes) => unawaited(widget.keyer.updateVoiceKeyingConfig(changes));

  @override
  Widget build(BuildContext context) {
    final m = context.t.settings.radio.voiceMessages;
    final config = widget.keyer.voiceKeyingNode?.config ?? const {};
    final decoration = poloFieldDecoration(context, '');
    Widget dropdown<T>({required String label, required T value, required List<DropdownMenuItem<T>> items, required ValueChanged<T> onChanged}) =>
        DropdownButtonFormField<T>(
          key: ValueKey('$label:$value'),
          isExpanded: true,
          initialValue: value,
          icon: dropdownTrailingIcon,
          decoration: decoration.copyWith(labelText: label),
          menuMaxHeight: dropdownMenuMaxHeight(context),
          items: items,
          onChanged: (choice) => choice == null ? null : onChanged(choice),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _deviceField(
          label: widget.so2r ? m.outputFor(radio: widget.keyer.radio) : m.output,
          devices: _outputs,
          stored: voiceDeviceFromConfig(config[voiceOutputConfigKey]),
          // No default for the output: the system's default device is
          // the computer's speakers far more often than the radio.
          defaultLabel: null,
          // First, and what nothing picked means, on a radio that takes its
          // audio over the network: no sound device between them.
          radioLabel: widget.keyer.voiceKeyingRadioTakesAudio ? m.outputRadio : null,
          radioPicked: config[voiceOutputConfigKey] == null || voiceOutputIsRadio(config[voiceOutputConfigKey]),
          build: dropdown,
          onChanged: (device) => _set({voiceOutputConfigKey: device == null ? null : voiceDeviceToConfig(device)}),
          onRadio: () => _set({voiceOutputConfigKey: voiceOutputRadio}),
        ),
        const SizedBox(height: Space.md),
        _deviceField(
          label: m.input,
          devices: _inputs,
          stored: voiceDeviceFromConfig(config[voiceInputConfigKey]),
          defaultLabel: m.inputDefault,
          build: dropdown,
          onChanged: (device) => _set({voiceInputConfigKey: device == null ? null : voiceDeviceToConfig(device)}),
        ),
        const SizedBox(height: Space.md),
        Row(
          children: [
            Expanded(
              child: dropdown<int>(
                label: m.lead,
                value: _option(config[voiceLeadConfigKey], defaultVoiceLead, _leadOptions),
                items: [
                  for (final ms in _leadOptions)
                    DropdownMenuItem(
                      value: ms,
                      child: Text(m.millis(n: ms)),
                    ),
                ],
                onChanged: (ms) => _set({voiceLeadConfigKey: ms}),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: dropdown<int>(
                label: m.tail,
                value: _option(config[voiceTailConfigKey], defaultVoiceTail, _tailOptions),
                items: [
                  for (final ms in _tailOptions)
                    DropdownMenuItem(
                      value: ms,
                      child: Text(m.millis(n: ms)),
                    ),
                ],
                onChanged: (ms) => _set({voiceTailConfigKey: ms}),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The stored delay as one of [options] — the nearest, for a value written
  /// some other way.
  int _option(Object? raw, Duration fallback, List<int> options) {
    final ms = raw is num ? raw.round() : fallback.inMilliseconds;
    return options.reduce((a, b) => (a - ms).abs() <= (b - ms).abs() ? a : b);
  }

  /// A device picker. The stored device stays pickable while it is not
  /// connected — marked so — rather than vanishing and reading as unset.
  Widget _deviceField({
    required String label,
    required List<AudioDevice> devices,
    required ({String? id, String? name})? stored,
    required String? defaultLabel,
    required Widget Function<T>({required String label, required T value, required List<DropdownMenuItem<T>> items, required ValueChanged<T> onChanged}) build,
    required ValueChanged<AudioDevice?> onChanged,
    String? radioLabel,
    bool radioPicked = false,
    VoidCallback? onRadio,
  }) {
    final m = context.t.settings.radio.voiceMessages;
    final current = stored == null ? null : matchAudioDevice(devices, id: stored.id, name: stored.name);
    final missing = stored != null && current == null ? AudioDevice(id: stored.id ?? '', name: stored.name ?? '') : null;
    final choices = [?missing, ...devices];
    // By position, not by id: an id can be empty (the null backend, a
    // stored device known only by name), and would collide with "none".
    const none = -1, radio = -2;
    final selected = radioLabel != null && radioPicked
        ? radio
        : current != null
        ? choices.indexOf(current)
        : (missing != null ? 0 : none);
    return build<int>(
      label: label,
      value: selected,
      items: [
        if (radioLabel != null) DropdownMenuItem(value: radio, child: Text(radioLabel)),
        if (defaultLabel != null || selected == none) DropdownMenuItem(value: none, child: Text(defaultLabel ?? m.pickDevice)),
        for (final (i, device) in choices.indexed)
          DropdownMenuItem(
            value: i,
            child: Text(identical(device, missing) ? m.deviceMissing(name: device.name) : device.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (i) {
        if (i == radio) return onRadio?.call();
        // The unplugged device is shown, not chosen again: storing it back
        // would replace its id with the placeholder this list made for it.
        if (i != none && identical(choices[i], missing)) return;
        onChanged(i == none ? null : choices[i]);
      },
    );
  }
}

/// What to CALL the device holding the memories — its name, or its id when a
/// pick made as the peer dropped stored no name (`PeerRadioSelection`).
String peerDeviceLabel(PeerRadioSelection? selection) {
  if (selection == null) return '';
  return selection.deviceName.isEmpty ? selection.deviceId : selection.deviceName;
}

/// The label for memory [n] — as set, its template when it is said from
/// the operator's words, or the key ("M3") when neither is.
///
/// Through the radio's keyer rather than the settings, because the memories
/// can be a PEER radio's: the label then belongs to the device the audio is
/// in (docs/design/cat.md § Keying a peer's radio).
String voiceMessageLabelFor(RadioKeyer keyer, int n, String key) {
  final label = keyer.voiceMessageShownLabel(n).trim();
  return label.isEmpty ? key : label;
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The voice memory editor: one row per memory the radio holds — the key, the
// label beside it, and how long it plays for underneath — each row opening
// its own dialog, where the label, the memory's length, PLAYING it and
// RECORDING it live. The list names the memories; the dialog is where
// anything happens to one. Reached from the Station dialog's keyer row, the
// keyer area's voice pill and Settings → Radio's Phone Keyer row. Shaped like
// the CW editor deliberately, minus what has no meaning here: there is no
// speed, no message text, and no SETS — the audio is in the radio's five
// memories, so a second set could only rename the same five.
//
// The audio lives in the radio, which is what the app stores nothing of: a
// label (`voiceMessageLabel1..8`) and a measured length
// (`voiceMessageDuration1..8`, both in the Radio group) are the whole of it.
// The length is MEASURED, never typed and never asked for: every play times
// itself (CatService.playVoiceMemory, docs/design/cat.md § Voice keying), so
// a memory is measured the first time it is used and cannot drift from the
// audio the way a number someone typed would. A radio that names and times
// its own memories (a FlexRadio's DVK) is the exception: its names and
// lengths are the ones shown, and a label saved here is saved on the radio.
// With no radio that can play, the rows
// stay editable and the buttons are gone: a label is worth setting before the
// rig is on the desk.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../services/halo_services.dart';
import '../services/cat/cat_service.dart';
import '../services/peer/peer_station_radios.dart';
import '../services/settings_service.dart';
import 'cw_messages_dialog.dart' show EnterSendsField, KeyerUnsupportedNotice, RepeatDelayField, cwMessageNumberIcons;

Future<void> showVoiceMessagesDialog(BuildContext context, HaLoServices services) => showHaloDialog<void>(
  context: context,
  builder: (context) => _VoiceMessagesDialog(services: services),
);

class _VoiceMessagesDialog extends StatelessWidget {
  final HaLoServices services;

  const _VoiceMessagesDialog({required this.services});

  @override
  Widget build(BuildContext context) {
    final m = context.t.settings.radio.voiceMessages;
    final theme = Theme.of(context);
    final settings = services.settings;
    final cat = services.cat;
    return ListenableBuilder(
      listenable: Listenable.merge([settings, cat, cat.voiceActivity]),
      builder: (context, _) {
        final canPlay = cat.canPlayVoice;
        // The radio's own count while one can play; every label otherwise,
        // so a memory the next radio has is not unnameable until it is on.
        final count = canPlay ? cat.voiceMemoryCount : SettingsService.voiceMessageCount;
        final activity = cat.voiceActivity.value;
        return HaloDialog(
          title: Text(m.title),
          // The same band the CW editor's picker sits on, and the same rule
          // it states: only memory 1 repeats. No Save here, so both fields
          // apply as they change.
          header: Container(
            color: haloDialogBandColorAt(context),
            padding: const EdgeInsets.fromLTRB(Space.xxl, Space.md, Space.xxl, Space.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // A radio with no voice memories at all, connected or not.
                if (!cat.radio1HasVoiceMemories) KeyerUnsupportedNotice(text: m.notSupported),
                Row(
                  children: [
                    Expanded(
                      child: RepeatDelayField(
                        value: '${settings.voiceRepeatDelay.inSeconds}',
                        label: m.repeat,
                        offLabel: m.repeatOff,
                        afterLabel: (n) => m.repeatAfter(n: n),
                        onChanged: (value) {
                          // Off ends a chain already counting down.
                          if (value == '0') cat.cancelKeyerRepeat();
                          unawaited(settings.setVoiceRepeatDelay(int.parse(value)));
                        },
                      ),
                    ),
                    if (settings.experimentEnabled('esm') /* stored key, see experiments.yaml */ ) ...[
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: EnterSendsField(
                          value: cat.enterSends.value,
                          onChanged: (value) => cat.setEnterSends(on: value.on, running: value.running),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          list: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var n = 1; n <= count; n++)
                ListTile(
                  leading: Icon(cwMessageNumberIcons[n - 1]),
                  title: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: m.key(n: n),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (cat.voiceMessageLabel(n).trim().isNotEmpty) TextSpan(text: '  ${cat.voiceMessageLabel(n).trim()}'),
                      ],
                    ),
                  ),
                  // What the memory IS — its measured length — unless the
                  // radio is doing something with it right now, which is
                  // the more urgent thing to say.
                  subtitle: Text(
                    activity?.memory == n
                        ? (activity!.doubtful ? m.doubtful : (activity.recording ? m.recording : m.playing))
                        : (cat.voiceMessageDuration(n) > 0 ? voiceDurationText(context, cat.voiceMessageDuration(n)) : voiceUnknownLengthText(context, cat)),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: activity?.memory == n || cat.voiceMessageDuration(n) > 0 ? null : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  onTap: () => showHaloDialog<void>(
                    context: context,
                    builder: (context) => _VoiceMessageDialog(services: services, n: n),
                  ),
                  mouseCursor: SystemMouseCursors.click,
                ),
              // Whose the audio is, since nothing else here says it is not
              // the app's to edit.
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.xxl, Space.md, Space.xxl, Space.md),
                child: Text(m.description, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
              ),
            ],
          ),
          // Done, not Close: the footer convention for a dialog with nothing
          // to commit (dialog_footer_convention_test.dart).
          cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.done)),
        );
      },
    );
  }
}

/// One memory: its label, how long it plays for, and the way to record it.
/// The label is an edit, saved on Save; measuring and recording are things
/// the RADIO does, so they happen as they are pressed and a Cancel does not
/// undo them — there is nothing here to undo them to.
class _VoiceMessageDialog extends StatefulWidget {
  final HaLoServices services;
  final int n;

  const _VoiceMessageDialog({required this.services, required this.n});

  @override
  State<_VoiceMessageDialog> createState() => _VoiceMessageDialogState();
}

class _VoiceMessageDialogState extends State<_VoiceMessageDialog> {
  late final _opened = widget.services.cat.voiceMessageLabel(widget.n);
  late final _label = TextEditingController(text: _opened);

  /// Whether the operator changed the label. A Save without a change writes
  /// nothing: on a radio that names its own memories the field may hold what
  /// was shown before the radio said otherwise, and saving that would rename
  /// the slot for every client of the radio.
  bool get _edited => _label.text != _opened;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    // Nothing to save for a peer's memory: the name is that device's, and
    // writing this station's own label would rename audio nobody is looking
    // at.
    if (_edited && widget.services.cat.voiceMessagesAreLocal) {
      await widget.services.cat.setVoiceMessageLabel(widget.n, _label.text.trim());
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.t.settings.radio.voiceMessages;
    final settings = widget.services.settings;
    final cat = widget.services.cat;
    // Zero content inset so the bands run edge to edge; the fields take the
    // dialog's usual inset themselves (halo_dialog.dart's default).
    const rowInset = EdgeInsets.symmetric(horizontal: Space.xxl);
    return ListenableBuilder(
      listenable: Listenable.merge([settings, cat, cat.voiceActivity]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final activity = cat.voiceActivity.value;
        final recording = activity?.memory == widget.n && activity!.recording;
        final playing = activity?.memory == widget.n && !activity!.recording;
        final busy = activity != null;
        final duration = cat.voiceMessageDuration(widget.n);
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
                  readOnly: !cat.voiceMessagesAreLocal,
                  autofocus: cat.voiceMessagesAreLocal,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: poloFieldDecoration(context, m.labelField),
                  onSubmitted: (_) => _save(),
                ),
              ),
              // Whose memories these are, when they are not this device's —
              // said once, above the buttons, because it explains both the
              // read-only label and the lengths beside it.
              if (!cat.voiceMessagesAreLocal)
                Padding(
                  padding: rowInset.copyWith(bottom: Space.md),
                  child: Text(
                    m.namedOnDevice(device: peerDeviceLabel(cat.followedPeerRadio)),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.8)),
                  ),
                )
              // A name typed here reaches every other client of that radio,
              // which is worth knowing before typing one.
              else if (cat.voiceMessagesNamedOnRadio)
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
                        onPressed: cat.stopVoice,
                        icon: Icon(MdiIcons.stop, color: theme.colorScheme.error),
                        label: Text(m.stopButton),
                      )
                    else
                      FilledButton.tonalIcon(
                        onPressed: busy || !cat.canRecordVoice ? null : () => cat.recordVoiceMemory(widget.n),
                        icon: const Icon(MdiIcons.recordCircleOutline),
                        label: Text(m.recordButton),
                      ),
                    Expanded(
                      child: Text(
                        duration > 0 ? voiceDurationText(context, duration) : voiceUnknownLengthText(context, cat),
                        textAlign: TextAlign.center,
                        style: duration > 0
                            ? theme.textTheme.bodyLarge
                            : theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    ),
                    if (cat.canPlayVoice)
                      if (playing)
                        FilledButton.tonalIcon(onPressed: cat.stopVoice, icon: const Icon(MdiIcons.stop), label: Text(m.stopButton))
                      else
                        FilledButton.tonalIcon(
                          // Once: this is the operator listening to the
                          // memory, not calling CQ with it.
                          onPressed: busy ? null : () => cat.playVoiceMemory(widget.n, repeat: false),
                          icon: const Icon(MdiIcons.play),
                          label: Text(m.playButton),
                        ),
                  ],
                ),
              ),
              // Why the button above is disabled, before anything about how
              // to use it: an operator who cannot record from here needs to
              // know that first.
              if (!cat.canRecordVoice)
                Padding(
                  padding: rowInset.copyWith(bottom: Space.xl),
                  child: Text(m.recordOnRadio, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.8))),
                ),
              // Under the buttons: it explains what to do AFTER pressing
              // Record, not what Record is (EquipmentModel.recordingHelp).
              if (cat.canRecordVoice && cat.voiceRecordingHelp != null)
                Padding(
                  padding: rowInset.copyWith(bottom: Space.xl),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        // Named, because the note describes ONE rig's front
                        // panel and a station can have more than one radio.
                        TextSpan(
                          text: '${m.recordHelpTitle(model: cat.voiceRecordingHelp!.model)} ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: cat.voiceRecordingHelp!.text),
                      ],
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.8)),
                  ),
                ),
            ],
          ),
          cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
          actions: [FilledButton(onPressed: _save, child: Text(context.t.common.save))],
        );
      },
    );
  }
}

/// A measured length as seconds with one decimal — "4.2 s". The measurement
/// has milliseconds in it (settings_service.dart), and a memory rounded to
/// the second reads as if the app guessed.
String voiceDurationText(BuildContext context, int millis) => context.t.settings.radio.voiceMessages.durationSeconds(n: (millis / 1000).toStringAsFixed(1));

/// What a memory with no length says: on a radio that times its own
/// memories, no length is an empty memory, and playing it measures nothing.
String voiceUnknownLengthText(BuildContext context, CatService cat) {
  final m = context.t.settings.radio.voiceMessages;
  return cat.voiceMessagesNamedOnRadio ? m.emptyOnRadio : m.notMeasured;
}

/// What to CALL the device holding the memories — its name, or its id when a
/// pick made as the peer dropped stored no name (`PeerRadioSelection`).
String peerDeviceLabel(PeerRadioSelection? selection) {
  if (selection == null) return '';
  return selection.deviceName.isEmpty ? selection.deviceId : selection.deviceName;
}

/// The label for memory [n] — as set, or the key ("M3") when none is.
///
/// Through `CatService` rather than the settings, because the memories can be
/// a PEER radio's: the label then belongs to the device the audio is in
/// (docs/design/cat.md § Keying a peer's radio).
String voiceMessageLabelFor(CatService cat, int n, String key) {
  final label = cat.voiceMessageLabel(n).trim();
  return label.isEmpty ? key : label;
}

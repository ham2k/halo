// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The voice memory editor: one row per memory the radio holds — the key, the
// label beside it, and how long it plays for underneath — each row opening
// its own dialog, where the label, the memory's length, PLAYING it and
// RECORDING it live. The list names the memories; the dialog is where
// anything happens to one. Reached from the Station dialog's keyer row and
// from the keyer area's voice pill. Shaped like the CW editor deliberately,
// minus what has no meaning here: there is no speed, no message text, and no
// SETS — the audio is in the radio's five memories, so a second set could
// only rename the same five.
//
// The audio lives in the radio, which is what the app stores nothing of: a
// label (`voiceMessageLabel1..8`) and a measured length
// (`voiceMessageDuration1..8`, both in the Radio group) are the whole of it.
// The length is MEASURED, never typed and never asked for: every play times
// itself (CatService.playVoiceMemory, docs/design/cat.md § Voice keying), so
// a memory is measured the first time it is used and cannot drift from the
// audio the way a number someone typed would. With no radio that can play, the rows
// stay editable and the buttons are gone: a label is worth setting before the
// rig is on the desk.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../i18n/strings.g.dart';
import '../services/halo_services.dart';
import '../services/settings_service.dart';
import 'cw_messages_dialog.dart' show cwMessageNumberIcons;

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
        final canRecord = cat.canRecordVoice;
        // The radio's own count while one can play; every label otherwise,
        // so a memory the next radio has is not unnameable until it is on.
        final count = canPlay ? cat.voiceMemoryCount : SettingsService.voiceMessageCount;
        final activity = cat.voiceActivity.value;
        return HaloDialog(
          title: Text(m.title),
          // The same band the CW editor's picker sits on, and the same rule
          // it states: only memory 1 repeats.
          header: Container(
            color: haloDialogBandColorAt(context),
            padding: const EdgeInsets.fromLTRB(Space.xxl, Space.md, Space.xxl, Space.xl),
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: '${settings.voiceRepeatDelay.inSeconds}',
              icon: dropdownTrailingIcon,
              decoration: poloFieldDecoration(context, m.repeat).copyWith(
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
              menuMaxHeight: dropdownMenuMaxHeight(context),
              items: [
                for (final option in SettingsService.cwRepeatDelayOptions)
                  DropdownMenuItem<String>(
                    value: option,
                    child: Text(option == '0' ? m.repeatOff : m.repeatAfter(n: option)),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                // Off ends a chain already counting down.
                if (value == '0') cat.cancelKeyerRepeat();
                unawaited(settings.setVoiceRepeatDelay(int.parse(value)));
              },
            ),
          ),
          list: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var n = 1; n <= count; n++)
                ListTile(
                  leading: Icon(cwMessageNumberIcons[n - 1]),
                  title: Text.rich(TextSpan(children: [
                    TextSpan(text: m.key(n: n), style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (settings.voiceMessageLabel(n).trim().isNotEmpty)
                      TextSpan(text: '  ${settings.voiceMessageLabel(n).trim()}'),
                  ])),
                  // What the memory IS — its measured length — unless the
                  // radio is doing something with it right now, which is
                  // the more urgent thing to say.
                  subtitle: Text(
                    activity?.memory == n
                        ? (activity!.doubtful ? m.doubtful : (activity.recording ? m.recording : m.playing))
                        : (settings.voiceMessageDuration(n) > 0
                            ? voiceDurationText(context, settings.voiceMessageDuration(n))
                            : m.notMeasured),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: activity?.memory == n || settings.voiceMessageDuration(n) > 0
                          ? null
                          : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  onTap: () => showHaloDialog<void>(
                    context: context,
                    builder: (context) => _VoiceMessageDialog(services: services, n: n),
                  ),
                  mouseCursor: SystemMouseCursors.click,
                ),
              // Why the buttons are missing, or why Record is: said once
              // under the list rather than on every row.
              if (!canPlay || !canRecord)
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.xxl, Space.md, Space.xxl, Space.md),
                  child: Text(
                    !canPlay ? m.notAvailable : m.recordOnRadio,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                  ),
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
  late final _label = TextEditingController(text: widget.services.settings.voiceMessageLabel(widget.n));

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    await widget.services.settings.setVoiceMessageLabel(widget.n, _label.text.trim());
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
        final duration = settings.voiceMessageDuration(widget.n);
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
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: poloFieldDecoration(context, m.labelField),
                  onSubmitted: (_) => _save(),
                ),
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
                    if (cat.canRecordVoice)
                      if (recording)
                        FilledButton.tonalIcon(
                          onPressed: cat.stopVoice,
                          icon: Icon(MdiIcons.stop, color: theme.colorScheme.error),
                          label: Text(m.stopButton),
                        )
                      else
                        FilledButton.tonalIcon(
                          onPressed: busy ? null : () => cat.recordVoiceMemory(widget.n),
                          icon: const Icon(MdiIcons.recordCircleOutline),
                          label: Text(m.recordButton),
                        ),
                    Expanded(
                      child: Text(
                        duration > 0 ? voiceDurationText(context, duration) : m.notMeasured,
                        textAlign: TextAlign.center,
                        style: duration > 0
                            ? theme.textTheme.bodyLarge
                            : theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                      ),
                    ),
                    if (cat.canPlayVoice)
                      if (playing)
                        FilledButton.tonalIcon(
                          onPressed: cat.stopVoice,
                          icon: const Icon(MdiIcons.stop),
                          label: Text(m.stopButton),
                        )
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
              // Under the buttons: it explains what to do AFTER pressing
              // Record, not what Record is (EquipmentModel.recordingHelp).
              if (cat.canRecordVoice && cat.voiceRecordingHelp != null)
                Padding(
                  padding: rowInset.copyWith(bottom: Space.xl),
                  child: Text.rich(
                    TextSpan(children: [
                      // Named, because the note describes ONE rig's front
                      // panel and a station can have more than one radio.
                      TextSpan(
                        text: '${m.recordHelpTitle(model: cat.voiceRecordingHelp!.model)} ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: cat.voiceRecordingHelp!.text),
                    ]),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
            ],
          ),
          cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
          actions: [
            FilledButton(onPressed: _save, child: Text(context.t.common.save)),
          ],
        );
      },
    );
  }
}

/// A measured length as seconds with one decimal — "4.2 s". The measurement
/// has milliseconds in it (settings_service.dart), and a memory rounded to
/// the second reads as if the app guessed.
String voiceDurationText(BuildContext context, int millis) =>
    context.t.settings.radio.voiceMessages.durationSeconds(n: (millis / 1000).toStringAsFixed(1));

/// The label for memory [n] — as set, or the key ("M3") when none is.
String voiceMessageLabelFor(SettingsService settings, int n, String key) {
  final label = settings.voiceMessageLabel(n).trim();
  return label.isEmpty ? key : label;
}

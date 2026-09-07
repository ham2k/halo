// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The voice memory editor: one row per memory the radio holds — the key,
// the label beside it, and at the end a Play (or Stop) and, on a radio
// whose CAT can record, a Record (or Stop) — each row opening a dialog for
// its label. Reached from the Station dialog's keyer row and from the
// keyer area's voice pill.
//
// The audio lives in the radio, which is what makes this editor so much
// smaller than the CW one: the only thing the app stores is a label
// (`voiceMessageLabel1..8` in the Radio group), and the only thing it can
// DO to a memory is ask the radio to play or record it. With no radio that
// can play, the rows stay editable and the buttons are gone — a label is
// worth setting before the rig is on the desk.

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
                  subtitle: activity?.memory == n
                      ? Text(
                          activity!.doubtful ? m.doubtful : (activity.recording ? m.recording : m.playing),
                          style: theme.textTheme.bodySmall,
                        )
                      : null,
                  trailing: canPlay
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Play, or Stop while THIS memory plays; a
                            // memory that is recording has nothing to play.
                            // No hover tooltips (docs/design/user-interface.md):
                            // the accessible name is the only name.
                            if (activity?.memory == n && !activity!.recording)
                              IconButton(
                                icon: Icon(MdiIcons.stop, semanticLabel: m.stop),
                                onPressed: cat.stopVoice,
                              )
                            else
                              IconButton(
                                icon: Icon(MdiIcons.play, semanticLabel: m.play(n: n)),
                                onPressed: activity == null ? () => cat.playVoiceMemory(n) : null,
                              ),
                            if (canRecord)
                              if (activity?.memory == n && activity!.recording)
                                IconButton(
                                  icon: Icon(MdiIcons.stop, color: theme.colorScheme.error, semanticLabel: m.stopRecording),
                                  onPressed: cat.stopVoice,
                                )
                              else
                                IconButton(
                                  icon: Icon(MdiIcons.recordCircleOutline, semanticLabel: m.record(n: n)),
                                  onPressed: activity == null ? () => cat.recordVoiceMemory(n) : null,
                                ),
                          ],
                        )
                      : null,
                  onTap: () => showHaloDialog<void>(
                    context: context,
                    builder: (context) => _VoiceMessageDialog(settings: settings, n: n),
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

/// One memory: its label, which is all there is to edit.
class _VoiceMessageDialog extends StatefulWidget {
  final SettingsService settings;
  final int n;

  const _VoiceMessageDialog({required this.settings, required this.n});

  @override
  State<_VoiceMessageDialog> createState() => _VoiceMessageDialogState();
}

class _VoiceMessageDialogState extends State<_VoiceMessageDialog> {
  late final _label = TextEditingController(text: widget.settings.voiceMessageLabel(widget.n));

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    await widget.settings.setVoiceMessageLabel(widget.n, _label.text.trim());
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.t.settings.radio.voiceMessages;
    return HaloDialog(
      title: Text(m.messageTitle(n: widget.n)),
      content: TextField(
        controller: _label,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: poloFieldDecoration(context, m.labelField),
        onSubmitted: (_) => _save(),
      ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
      actions: [
        FilledButton(onPressed: _save, child: Text(context.t.common.save)),
      ],
    );
  }
}

/// The label for memory [n] — as set, or the key ("M3") when none is.
String voiceMessageLabelFor(SettingsService settings, int n, String key) {
  final label = settings.voiceMessageLabel(n).trim();
  return label.isEmpty ? key : label;
}

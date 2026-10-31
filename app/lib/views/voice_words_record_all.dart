// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Record All (docs/design/cat.md § Voiced words): the operator reads calls
// and phrases as on the air, one after another, until every letter, digit
// and phrase has its takes in every place — then a second set, and on to
// five. Each reading is cut into its words' takes the moment it ends and
// played back word by word, each lit as it plays; Space takes it and asks
// for the next, Backspace deletes it and records the same call again.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';
import 'package:halo_audio/halo_audio.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../services/cat/computer_voice_keyer.dart' show VoicedMessageRefused;
import '../services/cat/voice_word_prompts.dart';
import '../services/cat/voice_words.dart';
import '../services/cat/voiced_words.dart';
import 'cw_messages_dialog.dart' show KeyerUnsupportedNotice;
import 'voice_messages_dialog.dart' show computerVoiceProblemText;
import 'voice_words_pane.dart' show VoiceTakePill, voiceTakeLabel;

Future<void> showVoiceWordsRecordAll(BuildContext context, VoicedWords words, String call) => showHaloDialog<void>(
  context: context,
  builder: (_) => _RecordAllDialog(words: words, call: call),
);

class _RecordAllDialog extends StatefulWidget {
  final VoicedWords words;
  final String call;

  const _RecordAllDialog({required this.words, required this.call});

  @override
  State<_RecordAllDialog> createState() => _RecordAllDialogState();
}

class _RecordAllDialogState extends State<_RecordAllDialog> with SingleTickerProviderStateMixin {
  late String? _prompt = widget.words.nextPrompt(widget.call);

  /// The prompt being read, while its recording runs.
  String? _reading;

  /// Whether the last reading is being played back for the operator to take
  /// or record again: the prompt waits on them.
  bool _reviewing = false;

  AudioPlayback? _listening;
  ReadingTake? _listeningTo;
  String? _listenProblem;

  /// The playback of the reading, piece by piece, followed by [_follow].
  List<({int atMs, ReadingTake? take})> _said = const [];
  late final Ticker _follow;

  VoicedWords get words => widget.words;

  @override
  void initState() {
    super.initState();
    _follow = createTicker(_followSaid);
    words.addListener(_recordingEnded);
  }

  @override
  void dispose() {
    words.removeListener(_recordingEnded);
    _listening?.stop();
    _follow.dispose();
    // Closed mid-reading: what was read is kept, as Stop would.
    if (words.recording != null) words.stopRecording();
    super.dispose();
  }

  void _recordingEnded() {
    if (_reading == null || words.recording != null) return;
    final read = _reading;
    _reading = null;
    final last = words.lastSaid;
    if (words.splitProblem != null || words.recordProblem != null || last?.text != read) return;
    setState(() => _reviewing = true);
    _playBack(last!.takes);
  }

  void _record() {
    final prompt = _prompt;
    if (prompt == null || words.recording != null) return;
    _stopListening();
    setState(() => _reviewing = false);
    if (words.recordSaid(widget.call, prompt)) _reading = prompt;
  }

  /// Takes the reading under review and asks for the next.
  void _accept() {
    _stopListening();
    setState(() {
      _reviewing = false;
      _prompt = words.nextPrompt(widget.call);
    });
  }

  /// Deletes the reading under review and records the same prompt again.
  void _reRecord() {
    final last = words.lastSaid;
    if (last == null) return;
    _stopListening();
    words.forgetLastSaid(widget.call);
    setState(() => _prompt = last.text);
    _record();
  }

  /// What Space does where the dialog is: record, stop, or take the reading.
  void _space() {
    if (words.recording != null) {
      words.stopRecording();
    } else if (_reviewing) {
      _accept();
    } else {
      _record();
    }
  }

  void _playBack(List<ReadingTake> takes) {
    if (takes.isEmpty) return;
    _play(takes.first, () {
      final heard = words.listenToTakes(widget.call, takes);
      _said = heard.said;
      return heard.playback;
    });
    if (_listening != null) _follow.start();
  }

  void _followSaid(Duration elapsed) {
    ReadingTake? take;
    for (final piece in _said) {
      if (piece.atMs > elapsed.inMilliseconds) break;
      take = piece.take;
    }
    if (take != _listeningTo) setState(() => _listeningTo = take);
  }

  void _play(ReadingTake take, AudioPlayback? Function() start) {
    _stopListening();
    AudioPlayback? playback;
    String? problem;
    try {
      playback = start();
    } on VoicedMessageRefused catch (e) {
      problem = computerVoiceProblemText(context, e.problem, detail: e.detail);
    }
    setState(() {
      _listening = playback;
      _listeningTo = playback == null ? null : take;
      _listenProblem = problem;
    });
    if (playback == null) return;
    unawaited(
      playback.done.then((_) {
        if (mounted && identical(_listening, playback)) setState(_quiet);
      }),
    );
  }

  void _stopListening() {
    _listening?.stop();
    if (_listening != null || _follow.isActive) setState(_quiet);
  }

  void _quiet() {
    _listening = _listeningTo = null;
    _said = const [];
    _follow.stop();
  }

  String? _problem(BuildContext context) {
    final m = context.t.settings.radio.voiceWords;
    final split = words.splitProblem;
    // A prompt is cut by splitSaid, which finds no voice or not every word.
    if (split != null) return split == VoiceWordSplitProblem.silent ? m.splitSilent : m.splitWordCount;
    final problem = words.recordProblem;
    return problem == null ? _listenProblem : computerVoiceProblemText(context, problem);
  }

  @override
  Widget build(BuildContext context) {
    final m = context.t.settings.radio.voiceWords;
    final theme = Theme.of(context);
    final note = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.8));
    return ListenableBuilder(
      listenable: words,
      builder: (context, _) {
        final call = widget.call;
        final slots = words.promptSlots(call);
        final set = words.promptSet(call);
        final missing = set == null ? 0 : slots.where((slot) => words.keptOf(call, slot) < set).length;
        final recording = words.recording != null;
        final prompt = _prompt;
        final problem = _problem(context);
        final last = words.lastSaid;
        // The keys work wherever focus is in the dialog, a button included:
        // these sit nearer the focus than the app's own Space-activates.
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.space): _space,
            const SingleActivator(LogicalKeyboardKey.backspace): () {
              if (_reviewing && !recording) _reRecord();
            },
          },
          child: Focus(
            autofocus: true,
            child: HaloDialog(
              title: Text(m.recordAll),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(m.recordAllIntro, style: note),
                  const SizedBox(height: Space.lg),
                  if (set == null)
                    Text(m.recordAllDone, style: theme.textTheme.titleMedium)
                  else ...[
                    Text(m.recordAllSet(n: set, missing: missing, total: slots.length)),
                    const SizedBox(height: Space.xs),
                    LinearProgressIndicator(value: slots.isEmpty ? 1 : 1 - missing / slots.length),
                  ],
                  const SizedBox(height: Space.xl),
                  if (prompt != null) ...[
                    Text(
                      prompt,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall?.copyWith(fontFamily: 'RobotoMono', fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: Space.sm),
                    Text(
                      [for (final piece in words.promptPieces(call, prompt)) voicePromptSpoken(piece.word)].join(' '),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: Space.lg),
                    if (_reviewing && last != null) ...[
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: Space.xs,
                        runSpacing: Space.xs,
                        children: [
                          for (final take in last.takes)
                            VoiceTakePill(
                              take: take,
                              semanticLabel: '${voicePromptSpoken(take.word)}, ${voiceTakeLabel(context, take, 1)}',
                              label: voicePromptSpoken(take.word),
                              playing: _listeningTo == take,
                              enabled: !recording,
                              onTap: () => _listeningTo == take ? _stopListening() : _play(take, () => words.listen(call, take)),
                            ),
                        ],
                      ),
                      const SizedBox(height: Space.lg),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: Space.md,
                        runSpacing: Space.xs,
                        children: [
                          FilledButton.icon(onPressed: _accept, icon: const Icon(MdiIcons.check), label: Text(m.acceptNext)),
                          TextButton.icon(onPressed: _reRecord, icon: const Icon(MdiIcons.undo), label: Text(m.reRecord)),
                        ],
                      ),
                    ] else
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: Space.md,
                        runSpacing: Space.xs,
                        children: [
                          FilledButton.icon(
                            style: recording ? FilledButton.styleFrom(backgroundColor: theme.colorScheme.error) : null,
                            onPressed: recording ? words.stopRecording : _record,
                            icon: Icon(recording ? MdiIcons.stop : MdiIcons.recordCircleOutline),
                            label: Text(recording ? m.stopSpace : m.recordSpace),
                          ),
                          TextButton(onPressed: recording ? null : () => setState(() => _prompt = words.nextPrompt(call)), child: Text(m.skip)),
                        ],
                      ),
                  ],
                  if (problem != null) ...[const SizedBox(height: Space.md), KeyerUnsupportedNotice(text: problem)],
                ],
              ),
              cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.done)),
            ),
          ),
        );
      },
    );
  }
}

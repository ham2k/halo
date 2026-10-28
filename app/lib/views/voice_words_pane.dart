// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Words pane (docs/design/cat.md § Voiced words): an operator's word set
// — every letter, digit and phrase a voiced message is said from — with a
// row per word to record it, listen to it, or (a phrase) delete it, and Record
// All for reading the whole list in one go. Reached from the Phone Keyer
// pane, under the `words` experiment.
//
// As in the Phone Keyer pane, nothing here is a draft: a word's takes are
// written the moment its recording ends.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_audio/halo_audio.dart';
import 'package:halo_core/halo_core.dart' show uuidGenerator;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../services/cat/computer_voice_keyer.dart' show VoicedMessageRefused;
import '../services/cat/voice_words.dart';
import '../services/cat/voiced_words.dart';
import '../services/halo_services.dart';
import '../services/voice_message_set.dart';
import 'cw_messages_dialog.dart' show KeyerUnsupportedNotice, SetNameDialog;
import 'voice_messages_dialog.dart' show computerVoiceProblemText;

Future<void> showVoiceWordsPane(BuildContext context, HaLoServices services) {
  final words = services.cat.keyer('A').voicedWords;
  if (words == null) return Future.value();
  return showModalPane<void>(
    context,
    title: context.t.settings.radio.voiceWords.title,
    closeLabel: context.t.common.close,
    scrollable: false,
    closeButton: false,
    builder: (_) => _VoiceWordsPane(services: services, words: words),
  );
}

class _VoiceWordsPane extends StatefulWidget {
  final HaLoServices services;
  final VoicedWords words;

  const _VoiceWordsPane({required this.services, required this.words});

  @override
  State<_VoiceWordsPane> createState() => _VoiceWordsPaneState();
}

class _VoiceWordsPaneState extends State<_VoiceWordsPane> {
  late final _call = TextEditingController(text: widget.words.operatorCall);
  final _try = TextEditingController();

  AudioPlayback? _listening;

  /// The word being listened to, or [_try] for the text tried out.
  Object? _listeningTo;

  /// Why the text tried out cannot be said.
  String? _tryProblem;

  /// Why a word's takes would not play.
  String? _listenProblem;

  /// The pacing while a slider is dragged; written when it is let go.
  VoicedPacing? _pacing;

  bool _advanced = false;

  String get call => _call.text.trim().toUpperCase();

  @override
  void dispose() {
    _listening?.stop();
    // A pane closed mid-recording keeps what was read, as Stop would.
    if (widget.words.recording != null) widget.words.stopRecording();
    _call.dispose();
    _try.dispose();
    super.dispose();
  }

  void _listen(VoiceWord word) {
    setState(() => _listenProblem = null);
    _play(word, () => widget.words.listen(call, word), (problem) => _listenProblem = problem);
  }

  void _listenToTry() {
    setState(() => _tryProblem = null);
    _play(_try, () => widget.words.listenToText(call, _try.text), (problem) => _tryProblem = problem);
  }

  void _stopListening() {
    _listening?.stop();
    setState(() => _listening = _listeningTo = null);
  }

  /// Plays what [start] starts, or says through [refused] why it will not.
  void _play(Object what, AudioPlayback? Function() start, void Function(String problem) refused) {
    _listening?.stop();
    AudioPlayback? playback;
    try {
      playback = start();
    } on VoicedMessageRefused catch (e) {
      setState(() => refused(computerVoiceProblemText(context, e.problem, detail: e.detail)));
    }
    setState(() {
      _listening = playback;
      _listeningTo = playback == null ? null : what;
    });
    if (playback == null) return;
    unawaited(
      playback.done.then((_) {
        if (mounted && identical(_listening, playback)) setState(() => _listening = _listeningTo = null);
      }),
    );
  }

  void _record(List<VoiceWord> words) {
    _listening?.stop();
    setState(() => _listening = _listeningTo = null);
    widget.words.record(call, words);
  }

  Future<void> _addPhrase() async {
    final m = context.t.settings.radio.voiceWords;
    final text = await showHaloDialog<String>(
      context: context,
      builder: (context) => SetNameDialog(title: m.addPhrase, field: m.phraseField),
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    await widget.words.addPhrase(call, VoicePhrase(id: uuidGenerator.v4(), text: text.trim()));
  }

  String? _problem(BuildContext context) {
    final m = context.t.settings.radio.voiceWords;
    final split = widget.words.splitProblem;
    if (split != null) {
      return switch (split) {
        VoiceWordSplitProblem.silent => m.splitSilent,
        VoiceWordSplitProblem.notThreeTakes => m.splitNotThreeTakes,
        VoiceWordSplitProblem.lineCount => m.splitLineCount,
        VoiceWordSplitProblem.linesTooClose => m.splitLinesTooClose,
      };
    }
    final problem = widget.words.recordProblem;
    return problem == null ? _listenProblem : computerVoiceProblemText(context, problem);
  }

  @override
  Widget build(BuildContext context) {
    final m = context.t.settings.radio.voiceWords;
    final theme = Theme.of(context);
    final note = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.8));
    return ListenableBuilder(
      listenable: Listenable.merge([widget.words, widget.services.settings, _call, _try]),
      builder: (context, _) {
        final words = widget.words.words(call);
        final recording = widget.words.recording;
        final recordingAll = recording != null && recording.words.length > 1;
        final problem = _problem(context);
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
                  Container(
                    color: haloDialogBandColorAt(context),
                    padding: const EdgeInsets.fromLTRB(Space.xxl, Space.md, Space.xxl, Space.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _call,
                                readOnly: recording != null,
                                textCapitalization: TextCapitalization.characters,
                                decoration: poloFieldDecoration(context, m.callField).copyWith(filled: true, fillColor: theme.colorScheme.surface),
                              ),
                            ),
                            const SizedBox(width: Space.md),
                            if (recordingAll)
                              FilledButton.tonalIcon(
                                onPressed: widget.words.stopRecording,
                                icon: Icon(MdiIcons.stop, color: theme.colorScheme.error),
                                label: Text(context.t.settings.radio.voiceMessages.stopButton),
                              )
                            else
                              FilledButton.tonalIcon(
                                onPressed: recording != null || call.isEmpty ? null : () => _record(words),
                                icon: const Icon(MdiIcons.recordCircleOutline),
                                label: Text(m.recordAll),
                              ),
                          ],
                        ),
                        const SizedBox(height: Space.md),
                        Text(recordingAll ? m.recordAllGuide : m.intro, style: note),
                        if (problem != null) ...[const SizedBox(height: Space.md), KeyerUnsupportedNotice(text: problem)],
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
                            for (final word in words) _row(context, word, recording),
                            ListTile(
                              leading: const Icon(MdiIcons.plus),
                              title: Text(m.addPhrase),
                              enabled: recording == null && call.isNotEmpty,
                              onTap: _addPhrase,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Trying the words out, and the pauses they are said with,
                  // below the list: adjusted and listened to together. A
                  // Material rather than a coloured box, so the Advanced
                  // Settings row's ink shows on it.
                  Material(
                    color: haloDialogBandColorAt(context),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(Space.xxl, Space.lg, Space.xxl, Space.md),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _try,
                                  textCapitalization: TextCapitalization.characters,
                                  style: const TextStyle(fontFamily: 'RobotoMono'),
                                  decoration: poloFieldDecoration(context, m.tryField).copyWith(filled: true, fillColor: theme.colorScheme.surface),
                                  onChanged: (_) {
                                    if (_tryProblem != null) setState(() => _tryProblem = null);
                                  },
                                  onSubmitted: (_) {
                                    // As the Listen button: never into a recording, never for no one.
                                    if (widget.words.recording == null && call.isNotEmpty && _try.text.trim().isNotEmpty) _listenToTry();
                                  },
                                ),
                              ),
                              const SizedBox(width: Space.md),
                              if (_listeningTo == _try)
                                FilledButton.tonalIcon(
                                  onPressed: _stopListening,
                                  icon: const Icon(MdiIcons.stop),
                                  label: Text(context.t.settings.radio.voiceMessages.stopButton),
                                )
                              else
                                FilledButton.tonalIcon(
                                  onPressed: recording != null || call.isEmpty || _try.text.trim().isEmpty ? null : _listenToTry,
                                  icon: const Icon(MdiIcons.headphones),
                                  label: Text(context.t.settings.radio.voiceMessages.listenButton),
                                ),
                            ],
                          ),
                          if (_tryProblem != null) ...[
                            const SizedBox(height: Space.sm),
                            Text(_tryProblem!, style: note?.copyWith(color: theme.colorScheme.error)),
                          ],
                          const SizedBox(height: Space.sm),
                          _pacingSection(context, enabled: call.isNotEmpty),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            haloDialogFooterBand(
              context,
              cancel: TextButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(context.t.common.done)),
            ),
          ],
        );
      },
    );
  }

  /// How a message is said with [call]'s set — its pauses (a letter's may
  /// overlap the one before, so it goes below zero) and its speed — folded
  /// away under Advanced Settings: the defaults sound like a call.
  Widget _pacingSection(BuildContext context, {required bool enabled}) {
    final m = context.t.settings.radio.voiceWords;
    final pacing = _pacing ?? widget.services.settings.voicePacing(call);
    final set = call;
    Widget slider(String label, double value, ({num min, num max}) range, double step, String Function(double v) shown, VoicedPacing Function(double v) apply) {
      final min = range.min.toDouble(), max = range.max.toDouble();
      final v = value.clamp(min, max);
      return Row(
        children: [
          SizedBox(width: 170, child: Text(label)),
          Expanded(
            child: Slider(
              value: v,
              min: min,
              max: max,
              divisions: ((max - min) / step).round(),
              onChanged: enabled ? (v) => setState(() => _pacing = apply(v)) : null,
              onChangeEnd: enabled
                  ? (v) async {
                      await widget.services.settings.setVoicePacing(set, apply(v));
                      if (mounted) setState(() => _pacing = null);
                    }
                  : null,
            ),
          ),
          SizedBox(width: 64, child: Text(shown(v), textAlign: TextAlign.end)),
        ],
      );
    }

    String millis(double v) => m.pauseValue(ms: v.round());
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTileTheme(
          contentPadding: EdgeInsets.zero,
          child: CollapsibleRow(title: m.advancedSettings, expanded: _advanced, onToggle: () => setState(() => _advanced = !_advanced)),
        ),
        CollapsibleBody(
          expanded: _advanced,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              slider(
                m.pauseLetters,
                pacing.letters.inMilliseconds.toDouble(),
                VoicedPacing.lettersRange,
                10,
                millis,
                (v) => pacing.copyWith(letters: Duration(milliseconds: v.round())),
              ),
              slider(
                m.pauseWords,
                pacing.words.inMilliseconds.toDouble(),
                VoicedPacing.wordsRange,
                10,
                millis,
                (v) => pacing.copyWith(words: Duration(milliseconds: v.round())),
              ),
              slider(m.speed, pacing.speed, VoicedPacing.speedRange, 0.05, (v) => m.speedValue(speed: v.toStringAsFixed(2)), (v) => pacing.copyWith(speed: v)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, VoiceWord word, ({String call, List<VoiceWord> words})? recording) {
    final m = context.t.settings.radio.voiceWords;
    final theme = Theme.of(context);
    final recorded = widget.words.recorded(call, word);
    final recordingThis = recording != null && recording.words.length == 1 && recording.words.single == word;
    return ListTile(
      title: Text(word.spoken),
      subtitle: Text(
        recordingThis ? (word.once ? m.recordingOnce(words: word.spoken) : m.recordingOne(word: word.spoken)) : (recorded ? m.recorded : m.notRecorded),
        style: theme.textTheme.bodySmall?.copyWith(color: recorded || recordingThis ? null : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (recorded && _listeningTo == word)
            IconButton(
              icon: Icon(MdiIcons.stop, semanticLabel: context.t.settings.radio.voiceMessages.stopButton),
              onPressed: _stopListening,
            )
          else if (recorded)
            IconButton(
              icon: Icon(MdiIcons.headphones, semanticLabel: context.t.settings.radio.voiceMessages.listenButton),
              onPressed: recording != null ? null : () => _listen(word),
            ),
          if (recordingThis)
            IconButton(
              icon: Icon(MdiIcons.stop, color: theme.colorScheme.error, semanticLabel: context.t.settings.radio.voiceMessages.stopButton),
              onPressed: widget.words.stopRecording,
            )
          else
            IconButton(
              icon: Icon(MdiIcons.recordCircleOutline, semanticLabel: context.t.settings.radio.voiceMessages.recordButton),
              onPressed: recording != null || call.isEmpty ? null : () => _record([word]),
            ),
          // The operator's own phrases; the fixed words are every set's.
          if (!fixedVoiceWords.contains(word))
            IconButton(
              icon: Icon(MdiIcons.trashCanOutline, color: theme.colorScheme.error, semanticLabel: m.deletePhrase),
              onPressed: recording != null ? null : () => unawaited(widget.words.forget(call, word)),
            ),
        ],
      ),
    );
  }
}

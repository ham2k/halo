// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Words pane (docs/design/cat.md § Voiced words): an operator's word set
// — every letter, digit and phrase a voiced message is said from — with a
// row per word to record another reading of it or (a phrase) delete it, its
// readings in the row, each take of each to listen to. Reached from the
// Phone Keyer pane, under the `words` experiment.
//
// As in the Phone Keyer pane, nothing here is a draft: a word's takes are
// written the moment its recording ends.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
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
import 'voice_words_record_all.dart';

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

class _VoiceWordsPaneState extends State<_VoiceWordsPane> with SingleTickerProviderStateMixin {
  late final _call = TextEditingController(text: widget.words.operatorCall);
  late final _try = TextEditingController(text: widget.services.settings.voiceTryText);

  AudioPlayback? _listening;

  /// The take being listened to, a [ReadingTake], or [_try] for the text
  /// tried out.
  Object? _listeningTo;

  /// What the text tried out says, piece by piece, and the take it is
  /// saying now — followed by [_follow] from when it starts to play.
  List<({int atMs, ReadingTake? take})> _said = const [];
  ReadingTake? _saying;
  late final Ticker _follow;

  /// Each word's row, to bring the take being said into view.
  final _rows = <VoiceWord, GlobalKey>{};

  /// Why the text tried out cannot be said.
  String? _tryProblem;

  /// Why a word's takes would not play.
  String? _listenProblem;

  /// The pacing while a slider is dragged; written when it is let go.
  VoicedPacing? _pacing;

  bool _advanced = false;

  String get call => _call.text.trim().toUpperCase();

  @override
  void initState() {
    super.initState();
    _follow = createTicker(_followSaid);
  }

  @override
  void dispose() {
    _listening?.stop();
    _follow.dispose();
    // A pane closed mid-recording keeps what was read, as Stop would.
    if (widget.words.recording != null) widget.words.stopRecording();
    _keepTryText();
    _call.dispose();
    _try.dispose();
    super.dispose();
  }

  void _keepTryText() {
    if (_try.text != widget.services.settings.voiceTryText) unawaited(widget.services.settings.setVoiceTryText(_try.text));
  }

  void _listen(ReadingTake take) {
    setState(() => _listenProblem = null);
    _play(take, () => widget.words.listen(call, take), (problem) => _listenProblem = problem);
  }

  void _listenToTry() {
    _keepTryText();
    setState(() => _tryProblem = null);
    var said = const <({int atMs, ReadingTake? take})>[];
    _play(_try, () {
      final heard = widget.words.listenToText(call, _try.text);
      said = heard.said;
      return heard.playback;
    }, (problem) => _tryProblem = problem);
    if (_listeningTo != _try) return;
    _said = said;
    _follow.start();
  }

  /// The take of the text tried out being said [elapsed] into it, shown
  /// and brought into view as it changes.
  void _followSaid(Duration elapsed) {
    ReadingTake? take;
    for (final piece in _said) {
      if (piece.atMs > elapsed.inMilliseconds) break;
      take = piece.take;
    }
    if (take == _saying) return;
    setState(() => _saying = take);
    final row = take == null ? null : _rows[take.word]?.currentContext;
    if (row != null) unawaited(Scrollable.ensureVisible(row, alignment: 0.5, duration: const Duration(milliseconds: 150)));
  }

  void _stopListening() {
    _listening?.stop();
    setState(_quiet);
  }

  void _quiet() {
    _listening = _listeningTo = _saying = null;
    _said = const [];
    _follow.stop();
  }

  /// Plays what [start] starts, or says through [refused] why it will not.
  void _play(Object what, AudioPlayback? Function() start, void Function(String problem) refused) {
    _listening?.stop();
    setState(_quiet);
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
        if (mounted && identical(_listening, playback)) setState(_quiet);
      }),
    );
  }

  void _record(VoiceWord word) {
    _listening?.stop();
    setState(_quiet);
    widget.words.record(call, word);
  }

  Future<void> _deleteTake(ReadingTake take) async {
    final m = context.t.settings.radio.voiceWords;
    final confirmed = await showHaloDialog<bool>(
      context: context,
      builder: (dialogContext) => HaloDialog(
        title: Text(m.deleteReadingTitle(word: take.word.spoken)),
        cancel: TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(context.t.common.cancel)),
        actions: [FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(context.t.common.delete))],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (_listeningTo == take) _stopListening();
    widget.words.forgetTake(call, take);
  }

  Future<void> _recordAll() async {
    _listening?.stop();
    setState(_quiet);
    await showVoiceWordsRecordAll(context, widget.words, call);
  }

  Future<void> _deleteAll() async {
    final m = context.t.settings.radio.voiceWords;
    final set = call;
    final confirmed = await showHaloDialog<bool>(
      context: context,
      builder: (dialogContext) => HaloDialog(
        title: Text(m.deleteAllTitle(call: set)),
        cancel: TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(context.t.common.cancel)),
        actions: [FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(context.t.common.delete))],
      ),
    );
    if (confirmed != true || !mounted) return;
    _stopListening();
    widget.words.forgetAll(set);
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
        VoiceWordSplitProblem.wordCount => m.splitWordCount,
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
                            TextButton.icon(
                              onPressed: recording != null || call.isEmpty ? null : _deleteAll,
                              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                              icon: const Icon(MdiIcons.trashCanOutline),
                              label: Text(m.deleteAll),
                            ),
                          ],
                        ),
                        const SizedBox(height: Space.md),
                        Row(
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: recording != null || call.isEmpty ? null : _recordAll,
                              icon: const Icon(MdiIcons.microphone),
                              label: Text(m.recordAll),
                            ),
                            const SizedBox(width: Space.lg),
                            Expanded(child: Text(m.intro, style: note)),
                          ],
                        ),
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

  /// A word's row: its name, each take it keeps as a pill — played by a
  /// tap, deleted by its X — in the order recorded, scrolling between the
  /// name and the record button.
  Widget _row(BuildContext context, VoiceWord word, ({String call, VoiceWord? word, String? text})? recording) {
    final m = context.t.settings.radio.voiceWords;
    final vm = context.t.settings.radio.voiceMessages;
    final theme = Theme.of(context);
    final takes = widget.words.takes(call, word);
    final recordingThis = recording != null && recording.word == word;
    final full = widget.words.nextReading(call, word) == null;
    final faint = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5));
    return ListTile(
      key: _rows.putIfAbsent(word, GlobalKey.new),
      title: Row(
        children: [
          SizedBox(
            width: _wordWidth,
            child: Text(word.spoken, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: takes.isEmpty
                ? Text(recordingThis ? '' : m.notRecorded, style: faint)
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final (i, take) in takes.indexed)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: Space.xs),
                            child: VoiceTakePill(
                              take: take,
                              semanticLabel: voiceTakeLabel(context, take, takes.take(i + 1).where((t) => t.take == take.take).length),
                              playing: _listeningTo == take || _saying == take,
                              enabled: recording == null,
                              onTap: () => _listeningTo == take ? _stopListening() : _listen(take),
                              onDelete: () => unawaited(_deleteTake(take)),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      subtitle: recordingThis ? Text(word.once ? m.recordingOnce(words: word.spoken) : m.recordingOne(word: word.spoken)) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (recordingThis)
            IconButton(
              icon: Icon(MdiIcons.stop, color: theme.colorScheme.error, semanticLabel: vm.stopButton),
              onPressed: widget.words.stopRecording,
            )
          else
            IconButton(
              icon: Icon(MdiIcons.recordCircleOutline, semanticLabel: takes.isEmpty ? vm.recordButton : m.recordAnother),
              onPressed: recording != null || call.isEmpty || full ? null : () => _record(word),
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

  /// The words' names take one width, so every row's pills start at the
  /// same place.
  static const _wordWidth = 96.0;
}

/// [take] as a screen reader names it, [n] counted among its own kind: the
/// first opening take, the second.
String voiceTakeLabel(BuildContext context, ReadingTake take, int n) {
  final m = context.t.settings.radio.voiceWords;
  if (take.word.once) return m.reading(n: n);
  return switch (take.take) {
    WordTake.opening => m.takeOpening(n: n),
    WordTake.middle => m.takeMiddle(n: n),
    WordTake.closing => m.takeClosing(n: n),
  };
}

/// One take of a word, drawn as where it falls in a part — a ray ending
/// for the opening take, a segment for one inside, a ray starting for the
/// closing one — played on a tap, stopped on another, and an X that
/// deletes it where there is an [onDelete].
class VoiceTakePill extends StatelessWidget {
  final ReadingTake take;

  /// What a screen reader says for it.
  final String semanticLabel;

  /// The word, shown before its icon where takes of different words sit
  /// side by side.
  final String? label;

  final bool playing;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const VoiceTakePill({
    super.key,
    required this.take,
    required this.semanticLabel,
    this.label,
    required this.playing,
    required this.enabled,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final m = context.t.settings.radio.voiceWords;
    final scheme = Theme.of(context).colorScheme;
    final foreground = (playing ? scheme.onPrimary : scheme.onSecondaryContainer).withValues(alpha: enabled ? 1 : 0.5);
    const shape = StadiumBorder();
    return Material(
      color: playing ? scheme.primary : scheme.secondaryContainer,
      shape: shape,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: semanticLabel,
            excludeSemantics: true,
            child: InkWell(
              customBorder: shape,
              onTap: enabled ? onTap : null,
              child: Padding(
                padding: EdgeInsetsDirectional.only(start: Space.sm, end: onDelete == null ? Space.sm : Space.xxs, top: Space.xs, bottom: Space.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (label != null) ...[
                      Text(label!, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: foreground)),
                      const SizedBox(width: Space.xxs),
                    ],
                    Icon(
                      switch (take.take) {
                        WordTake.opening => MdiIcons.rayEnd,
                        WordTake.middle => MdiIcons.rayStartEnd,
                        WordTake.closing => MdiIcons.rayStart,
                      },
                      size: 20,
                      color: foreground,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onDelete != null)
            InkWell(
              customBorder: const CircleBorder(),
              onTap: enabled ? onDelete : null,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: Space.xxs, end: Space.sm, top: Space.xs, bottom: Space.xs),
                child: Icon(MdiIcons.close, size: 12, color: foreground, semanticLabel: m.deleteReading),
              ),
            ),
        ],
      ),
    );
  }
}

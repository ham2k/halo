// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Voiced words on this computer (docs/design/cat.md § Voiced words): each
// operator's word set — the recordings of their letters, digits and phrases —
// and a phone message's template made into one recording just before it
// plays. Radio1's alone, as the computer's voice keyer is.

import 'package:flutter/foundation.dart';
import 'package:halo_audio/halo_audio.dart' show AudioPlayback;

import '../error_reporting_service.dart';
import '../settings_service.dart';
import 'cat_keying.dart';
import 'computer_voice_keyer.dart';
import 'voice_words.dart';

final _voicedWords = Expando<VoicedWords>();

extension VoicedWordsKeying on CatKeying {
  /// Radio1's word sets and the templates said from them; null where the
  /// computer's voice keyer cannot run.
  VoicedWords? get voicedWords {
    final audio = voiceAudio;
    if (audio == null || !ownsVoiceSource) return null;
    final existing = _voicedWords[this];
    if (existing != null) return existing;
    final words = VoicedWords(
      settings: settings,
      audio: audio,
      root: () => voiceMessagesRoot,
      messageFile: voiceMessageFile,
      messageTemplate: (n) => settings.activeVoiceMessageSet.template(n),
      recorder: () => voiceRecorder,
    );
    voiceMaker = words.voice;
    return _voicedWords[this] = words;
  }
}

/// Renders a phone message's template against the contact being logged — the
/// operation view's, which holds the draft — as its text and the operator
/// whose words say it. Fails with [VoicedMessageRefused] for a template that
/// does not render.
typedef VoiceTemplateRender = Future<({String text, String operatorCall})> Function(String template, int message);

/// The longest a reading of every word may run, per word, before it is
/// stopped: three takes and a breath.
const voiceWordReadingPerWord = Duration(seconds: 5);

class VoicedWords extends ChangeNotifier {
  VoicedWords({
    required this.settings,
    required this.audio,
    required this.root,
    required this.messageFile,
    required this.messageTemplate,
    required this.recorder,
  });

  final SettingsService settings;
  final VoiceAudio audio;

  /// The voice messages' directory, null until it is known.
  final String? Function() root;

  /// Where message [n] of the set in use is recorded.
  final String Function(int n) messageFile;

  /// What message [n] of the set in use is said with — empty for its
  /// recording.
  final String Function(int n) messageTemplate;

  /// [template] ready to render: a `{{ phone.msgN }}` whose message is said
  /// with words becomes that message's template — what it says, not a
  /// recording it may not have — and any other becomes its mark. One level
  /// only, so a message naming itself, or two naming each other, end at a
  /// mark rather than going round.
  String _expand(String template) => markVoicedMessages(
    template.replaceAllMapped(voicedMessageTag, (tag) {
      final inner = messageTemplate(int.parse(tag[1]!));
      return inner.trim().isEmpty ? tag[0]! : inner;
    }),
  );

  /// The keyer that records on radio1's input — its own, or the desk's with no radio.
  final ComputerVoiceKeyer? Function() recorder;

  VoiceTemplateRender? _render;
  String Function()? _operatorCall;
  void Function(int n, VoicedMessageRefused refusal)? _refused;

  /// Lets the operation view render templates against its draft, say whose
  /// words are in use, and hear a message refused — a key that keys nothing
  /// must not look like one that worked — until [detach] with the same
  /// [render].
  void attach(VoiceTemplateRender render, {required String Function() operatorCall, void Function(int n, VoicedMessageRefused refusal)? refused}) {
    _render = render;
    _operatorCall = operatorCall;
    _refused = refused;
    notifyListeners();
  }

  void detach(VoiceTemplateRender render) {
    if (!identical(_render, render)) return;
    _render = null;
    _operatorCall = null;
    _refused = null;
    notifyListeners();
  }

  /// Whose words a message says: the open operation's operator, else the
  /// profile's.
  String get operatorCall {
    final call = _operatorCall?.call().trim() ?? '';
    return call.isNotEmpty ? call : settings.operatorCall.trim();
  }

  String? _dir(String call) {
    final root = this.root();
    final set = voiceWordSetCall(call);
    return root == null || set.isEmpty ? null : '$root/words/$set';
  }

  /// Where [take] of [word] is kept — the one recording, for a word
  /// recorded [VoiceWord.once].
  String? wordFile(String call, VoiceWord word, WordTake take) {
    final dir = _dir(call);
    if (dir == null) return null;
    return word.once ? '$dir/${word.key}.wav' : '$dir/${word.key}-${take.suffix}.wav';
  }

  /// [call]'s words, the fixed ones first, then their phrases.
  List<VoiceWord> words(String call) => [...fixedVoiceWords, for (final phrase in settings.voicePhrases(call)) phrase.word];

  /// Whether [word] has all its takes in [call]'s set.
  bool recorded(String call, VoiceWord word) => WordTake.values.every((take) {
    final path = wordFile(call, word, take);
    return path != null && audio.lengthOf(path) != null;
  });

  // --- Saying a message ---

  /// Turns the files written for each play over, so one still open — a play
  /// stopping, on Windows — is never the one being written.
  int _voiced = 0;

  /// Message [n]'s [template] as one recording, ready to play — see
  /// [ComputerVoiceKeyer.prepare]. Refused before anything is keyed when
  /// there is no contact to render against, the template fails, or it says
  /// what the operator's words cannot.
  Future<String> voice(int n, String template) async {
    try {
      return await _voice(n, template);
    } on VoicedMessageRefused catch (refusal) {
      final refused = _refused;
      if (refused != null) {
        refused(n, refusal);
      } else if (refusal.cause != null) {
        // No one to show it: reported plainly, so the generic notice says it.
        ErrorReportingService.report(refusal.cause!, refusal.causeStack, context: 'voice:render-message');
      }
      rethrow;
    }
  }

  Future<String> _voice(int n, String template) async {
    final render = _render;
    if (render == null) throw const VoicedMessageRefused(ComputerVoiceProblem.noOperation);
    final rendered = await render(_expand(template), n);
    return _say(rendered.operatorCall, rendered.text);
  }

  /// [text] said in [call]'s words, as one recording — refused, naming what
  /// is missing, when those words cannot say all of it.
  String _say(String call, String text) {
    final plan = _plan(call, text);
    final missing = [
      for (final word in plan.unrecorded) word.spoken,
      ...plan.unspeakable,
      for (final piece in plan.pieces)
        if (piece is RecordingPiece && audio.lengthOf(messageFile(piece.message)) == null) 'M${piece.message}',
    ];
    if (missing.isNotEmpty) throw VoicedMessageRefused(ComputerVoiceProblem.wordsMissing, missing.toSet().join(', '));
    if (plan.pieces.isEmpty) throw const VoicedMessageRefused(ComputerVoiceProblem.nothingSaid);
    return _write(
      call,
      plan,
      (piece) => switch (piece) {
        WordPiece(:final word, :final take) => wordFile(call, word, take)!,
        RecordingPiece(:final message) => messageFile(message),
      },
    );
  }

  String _write(String call, VoicedPlan plan, String Function(VoicedPiece piece) fileOf) {
    final samples = joinVoicedPlan(plan, (piece) => audio.decode(fileOf(piece), rate: voiceWordRate, channels: 1), speed: settings.voicePacing(call).speed);
    final path = '${root()}/words/.voiced-${_voiced++ % 4}.wav';
    audio.write(path, encodeVoiceWav(samples));
    return path;
  }

  /// [text] in [call]'s words, on the computer's own output — the operator
  /// trying their words out. Throws [VoicedMessageRefused] as a message
  /// would be refused.
  AudioPlayback listenToText(String call, String text) => _listenTo(() => _say(call, text));

  /// Message [n]'s [template] as it would be said for the draft now, on the
  /// computer's own output. Throws [VoicedMessageRefused] as the message
  /// would be refused, without the refusal reaching the operation view.
  Future<AudioPlayback> listenToTemplate(int n, String template) async {
    final render = _render;
    if (render == null) throw const VoicedMessageRefused(ComputerVoiceProblem.noOperation);
    final rendered = await render(_expand(template), n);
    return _listenTo(() => _say(rendered.operatorCall, rendered.text));
  }

  /// Plays what [make] writes. A file or device that fails is reported and
  /// refused as unplayable, for the caller to say; anything else is a bug,
  /// and goes on up.
  AudioPlayback _listenTo(String Function() make) {
    try {
      return audio.listen(make());
    } on Exception catch (e, st) {
      if (!isVoiceAudioFailure(e)) rethrow;
      reportVoiceFailure('listen', e, st);
      throw const VoicedMessageRefused(ComputerVoiceProblem.unplayable);
    }
  }

  /// What [template] would say for the draft as it is now, for the message
  /// editor — null with no operation open to render against.
  Future<({VoicedPlan plan, String call})?> preview(String template) async {
    final render = _render;
    if (render == null) return null;
    final rendered = await render(_expand(template), 0);
    final call = rendered.operatorCall;
    return (plan: _plan(call, rendered.text), call: call);
  }

  VoicedPlan _plan(String call, String text) =>
      planVoicedText(text, phrases: settings.voicePhrases(call), pacing: settings.voicePacing(call), recorded: (word) => recorded(call, word));

  // --- Recording words ---

  /// What is being recorded — one word, or every word in one reading —
  /// and for whom; null while nothing is.
  ({String call, List<VoiceWord> words})? get recording => _recording;
  ({String call, List<VoiceWord> words})? _recording;
  ComputerVoiceKeyer? _recordingOn;

  /// Why the last recording kept nothing: the recorder's own problem, or
  /// [splitProblem].
  ComputerVoiceProblem? get recordProblem => _recordProblem;
  ComputerVoiceProblem? _recordProblem;
  VoiceWordSplitProblem? get splitProblem => _splitProblem;
  VoiceWordSplitProblem? _splitProblem;

  /// Records [words] of [call]'s set: one word read three times run
  /// together — once, for a [VoiceWord.once] phrase — or every word one line
  /// each. False when it could not start
  /// ([recordProblem] says why) or there is nowhere to keep it.
  bool record(String call, List<VoiceWord> words) {
    final keyer = recorder(), dir = _dir(call);
    _recordProblem = null;
    _splitProblem = null;
    if (keyer == null || dir == null || words.isEmpty) {
      // Nowhere to record from or to — the directory not yet known.
      _recordProblem = ComputerVoiceProblem.recordingFailed;
      notifyListeners();
      return false;
    }
    final started = keyer.recordFile(
      '$dir/.reading.wav',
      ceiling: voiceWordReadingPerWord * words.length + const Duration(seconds: 5),
      done: (kept) => _recorded(keyer, call, words, kept),
    );
    if (started) {
      _recording = (call: call, words: words);
      _recordingOn = keyer;
    } else {
      _recordProblem = keyer.problem;
    }
    notifyListeners();
    return started;
  }

  /// Ends a recording, keeping what was read.
  void stopRecording() => _recordingOn?.stopVoice();

  void _recorded(ComputerVoiceKeyer keyer, String call, List<VoiceWord> words, String? kept) {
    _recording = null;
    _recordingOn = null;
    if (kept == null) {
      _recordProblem = keyer.problem;
    } else {
      try {
        final samples = audio.decode(kept, rate: voiceWordRate, channels: 1);
        final lines = splitReading(samples, [for (final word in words) word.once ? 1 : 3]);
        for (final (i, word) in words.indexed) {
          for (final MapEntry(key: take, value: audio) in wordTakes(samples, lines[i]).entries) {
            this.audio.write(wordFile(call, word, take)!, encodeVoiceWav(audio));
          }
        }
      } on VoiceWordSplitException catch (e) {
        _splitProblem = e.problem;
      } on Exception catch (e, st) {
        reportVoiceFailure('words', e, st);
        _recordProblem = ComputerVoiceProblem.recordingFailed;
      } finally {
        audio.delete(kept);
      }
    }
    notifyListeners();
  }

  /// Plays [word]'s takes as they are said, on the computer's own output —
  /// the operator hearing what they recorded. Null while it is not
  /// recorded; refused ([VoicedMessageRefused]) when a take will not play.
  AudioPlayback? listen(String call, VoiceWord word) {
    if (!recorded(call, word)) return null;
    final plan = VoicedPlan([
      if (word.once)
        WordPiece(word, WordTake.middle, Duration.zero)
      else ...[
        WordPiece(word, WordTake.opening, Duration.zero),
        WordPiece(word, WordTake.middle, settings.voicePacing(call).words),
        WordPiece(word, WordTake.closing, settings.voicePacing(call).words),
      ],
    ]);
    return _listenTo(() => _write(call, plan, (piece) => wordFile(call, (piece as WordPiece).word, piece.take)!));
  }

  /// Deletes [word]'s takes from [call]'s set — and, for a phrase, the phrase.
  Future<void> forget(String call, VoiceWord word) async {
    final dir = _dir(call);
    if (dir != null) {
      // Both layouts: whatever the word was recorded as goes with it.
      audio.delete('$dir/${word.key}.wav');
      for (final take in WordTake.values) {
        audio.delete('$dir/${word.key}-${take.suffix}.wav');
      }
    }
    if (word.phrase != null) {
      await settings.setVoicePhrases(call, [
        for (final phrase in settings.voicePhrases(call))
          if (phrase.word != word) phrase,
      ]);
    }
    notifyListeners();
  }

  Future<void> addPhrase(String call, VoicePhrase phrase) async {
    await settings.setVoicePhrases(call, [...settings.voicePhrases(call), phrase]);
    notifyListeners();
  }
}

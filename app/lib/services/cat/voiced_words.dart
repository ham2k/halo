// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Voiced words on this computer (docs/design/cat.md § Voiced words): each
// operator's word set — the recordings of their letters, digits and phrases —
// and a phone message's template made into one recording just before it
// plays. Kept on radio1's keying; Radio B's keyer says its messages through
// the same maker (CatService wires it), so both radios say the one set of
// words.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:halo_audio/halo_audio.dart' show AudioPlayback;
import 'package:halo_i18n/halo_i18n.dart';

import '../error_reporting_service.dart';
import '../settings_service.dart';
import 'cat_keying.dart';
import 'computer_voice_keyer.dart';
import 'driver.dart' show VoiceScript;
import 'voice_word_prompts.dart';
import 'voice_words.dart';

final _voicedWords = Expando<VoicedWords>();

extension VoicedWordsKeying on CatKeying {
  /// The operator's word sets and the templates said from them, on radio1's
  /// keying; null where the computer's voice keyer cannot run, and on Radio
  /// B's keying, whose maker is this one's.
  VoicedWords? get voicedWords {
    final audio = voiceAudio;
    if (audio == null || radio != 'A') return null;
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

/// The longest a reading of a word may run before it is stopped: three
/// takes and a breath.
const voiceWordReadingCeiling = Duration(seconds: 10);

/// The most of each take a word keeps. A reading is three takes, each kept
/// and deleted on its own, and a message draws each take from any reading
/// that has it ([VoicedWords.voice]).
const voiceWordReadings = 5;

/// One take of one reading of a word: what a message says, and what the
/// Word Recordings pane plays, shows and deletes.
typedef ReadingTake = ({VoiceWord word, int reading, WordTake take});

class VoicedWords extends ChangeNotifier {
  VoicedWords({
    required this.settings,
    required this.audio,
    required this.root,
    required this.messageFile,
    required this.messageTemplate,
    required this.recorder,
    math.Random? random,
  }) : _random = random ?? math.Random();

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

  /// Which reading each take of a message comes from.
  final math.Random _random;

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

  /// Where [take] of [word]'s [reading] is kept — the one recording, for a
  /// word recorded [VoiceWord.once]. The first reading's files are named for
  /// the word alone, with no reading number: a set recorded with one reading
  /// a word is read as its first.
  String? wordFile(String call, VoiceWord word, WordTake take, {int reading = 0}) {
    final dir = _dir(call);
    if (dir == null) return null;
    final name = _readingName(word, reading);
    return word.once ? '$dir/$name.wav' : '$dir/$name-${take.suffix}.wav';
  }

  String _readingName(VoiceWord word, int reading) => reading == 0 ? word.key : '${word.key}~$reading';

  /// [call]'s words, the fixed ones first, then their phrases.
  List<VoiceWord> words(String call) => [...fixedVoiceWords, for (final phrase in settings.voicePhrases(call)) phrase.word];

  /// The takes a reading of [word] has: the one recording, for a word
  /// recorded [VoiceWord.once].
  static List<WordTake> takesOf(VoiceWord word) => word.once ? const [WordTake.middle] : WordTake.values;

  /// The readings of [word] in [call]'s set that have [take], in the order
  /// they are kept — a deleted one leaves its place free.
  List<int> readings(String call, VoiceWord word, WordTake take) => [
    for (var reading = 0; reading < voiceWordReadings; reading++)
      if (wordFile(call, word, take, reading: reading) case final path? when audio.lengthOf(path) != null) reading,
  ];

  /// Every take of [word] kept in [call]'s set, in the order recorded: by
  /// when its file was written, a reading's takes in the order said.
  List<ReadingTake> takes(String call, VoiceWord word) {
    final kept = [
      for (final take in takesOf(word))
        for (final reading in readings(call, word, take)) (word: word, reading: reading, take: take),
    ];
    final written = {for (final take in kept) take: audio.modifiedAt(_takeFile(call, take))};
    int order(ReadingTake a, ReadingTake b) {
      final (x, y) = (written[a], written[b]);
      final byTime = x == null || y == null ? 0 : x.compareTo(y);
      if (byTime != 0) return byTime;
      return a.reading != b.reading ? a.reading.compareTo(b.reading) : a.take.index.compareTo(b.take.index);
    }

    return kept..sort(order);
  }

  /// Whether [word] has every take a message says it in, in [call]'s set.
  bool recorded(String call, VoiceWord word) => word.saidIn.every((take) => readings(call, word, take).isNotEmpty);

  /// What says [word] where the planner put it as [take]: that take where
  /// [word] has it, else one it has — a phrase's one recording, named as its
  /// pill is, or a "/P" read alone, placed as an opening with only its
  /// closing take kept.
  ReadingTake _sayTake(String call, VoiceWord word, WordTake take) {
    final from = takesOf(word).contains(take) && readings(call, word, take).isNotEmpty
        ? take
        : takesOf(word).firstWhere((t) => readings(call, word, t).isNotEmpty, orElse: () => take);
    return (word: word, reading: _anyReading(call, word, from), take: from);
  }

  /// Which of [word]'s readings [take] comes from, drawn for each take on
  /// its own: a word said twice in a message, or a message said twice, need
  /// not sound the same twice.
  int _anyReading(String call, VoiceWord word, WordTake take) {
    final readings = this.readings(call, word, take);
    return readings[_random.nextInt(readings.length)];
  }

  // --- Saying a message ---

  /// Turns the files written for each play over, so one still open — a play
  /// stopping, on Windows — is never the one being written.
  int _voiced = 0;

  /// Message [n]'s [template] as one recording, ready to play — see
  /// [ComputerVoiceKeyer.prepare]. Refused before anything is keyed when
  /// there is no contact to render against, the template fails, or it says
  /// what the operator's words cannot.
  Future<MadeVoiceMessage> voice(int n, String template) async {
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

  Future<MadeVoiceMessage> _voice(int n, String template) async {
    final render = _render;
    if (render == null) throw const VoicedMessageRefused(ComputerVoiceProblem.noOperation);
    final rendered = await render(_expand(template), n);
    return _say(rendered.operatorCall, rendered.text);
  }

  /// [text] said in [call]'s words, as one recording — refused, naming what
  /// is missing, when those words cannot say all of it. [said], given, gets
  /// each piece as it is played: when it starts, and the take it is — null
  /// for a recorded message inside it.
  MadeVoiceMessage _say(String call, String text, {List<({int atMs, ReadingTake? take})>? said}) {
    final plan = _plan(call, text);
    final missing = [
      for (final word in plan.unrecorded) word.spoken,
      ...plan.unspeakable,
      for (final piece in plan.pieces)
        if (piece is RecordingPiece && audio.lengthOf(messageFile(piece.message)) == null) 'M${piece.message}',
    ];
    if (missing.isNotEmpty) throw VoicedMessageRefused(ComputerVoiceProblem.wordsMissing, missing.toSet().join(', '));
    if (plan.pieces.isEmpty) throw const VoicedMessageRefused(ComputerVoiceProblem.nothingSaid);
    final takes = [
      for (final piece in plan.pieces)
        if (piece case WordPiece(:final word, :final take)) _sayTake(call, word, take) else null,
    ];
    final starts = <int>[];
    final path = _write(
      call,
      plan,
      (i, piece) => switch (piece) {
        WordPiece() => _takeFile(call, takes[i]!),
        RecordingPiece(:final message) => messageFile(message),
      },
      starts: starts,
    );
    said?.addAll([for (final (i, take) in takes.indexed) (atMs: starts[i] * 1000 ~/ voiceWordRate, take: take)]);
    final script = voicedScript(text, plan, starts, _messageName);
    return MadeVoiceMessage(path, script: script == null ? null : VoiceScript(script.text, script.marks));
  }

  /// A recorded message inside another, as the keyer line names it.
  String _messageName(int n) {
    final label = settings.activeVoiceMessageSet.label(n).trim();
    return label.isNotEmpty ? label : t.settings.radio.voiceMessages.key(n: n);
  }

  String _takeFile(String call, ReadingTake take) => wordFile(call, take.word, take.take, reading: take.reading)!;

  /// [plan] joined into one file, [fileOf] naming the file of its piece [i].
  String _write(String call, VoicedPlan plan, String Function(int i, VoicedPiece piece) fileOf, {List<int>? starts}) {
    var i = 0;
    final samples = joinVoicedPlan(
      plan,
      (piece) => audio.decode(fileOf(i++, piece), rate: voiceWordRate, channels: 1),
      speed: settings.voicePacing(call).speed,
      starts: starts,
    );
    final path = '${root()}/words/.voiced-${_voiced++ % 4}.wav';
    audio.write(path, encodeVoiceWav(samples));
    return path;
  }

  /// [text] in [call]'s words, on the computer's own output — the operator
  /// trying their words out — with each piece it says, as [_say] gives
  /// them. Throws [VoicedMessageRefused] as a message would be refused.
  ({AudioPlayback playback, List<({int atMs, ReadingTake? take})> said}) listenToText(String call, String text) {
    final said = <({int atMs, ReadingTake? take})>[];
    return (playback: _listenTo(() => _say(call, text, said: said).path), said: said);
  }

  /// Message [n]'s [template] as it would be said for the draft now, on the
  /// computer's own output. Throws [VoicedMessageRefused] as the message
  /// would be refused, without the refusal reaching the operation view.
  Future<AudioPlayback> listenToTemplate(int n, String template) async {
    final render = _render;
    if (render == null) throw const VoicedMessageRefused(ComputerVoiceProblem.noOperation);
    final rendered = await render(_expand(template), n);
    return _listenTo(() => _say(rendered.operatorCall, rendered.text).path);
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

  /// The word being recorded, or the text a Record All prompt reads, and
  /// for whom; null while nothing is.
  ({String call, VoiceWord? word, String? text})? get recording => _recording;
  ({String call, VoiceWord? word, String? text})? _recording;
  ComputerVoiceKeyer? _recordingOn;

  /// Why the last recording kept nothing: the recorder's own problem, or
  /// [splitProblem].
  ComputerVoiceProblem? get recordProblem => _recordProblem;
  ComputerVoiceProblem? _recordProblem;
  VoiceWordSplitProblem? get splitProblem => _splitProblem;
  VoiceWordSplitProblem? _splitProblem;

  /// The first place free of [take] of [word], null with all
  /// [voiceWordReadings] of it kept.
  int? _freePlace(String call, VoiceWord word, WordTake take) {
    final kept = readings(call, word, take);
    for (var reading = 0; reading < voiceWordReadings; reading++) {
      if (!kept.contains(reading)) return reading;
    }
    return null;
  }

  /// Where each take of another reading of [word] goes: the first place
  /// free of that take — null while any take has all [voiceWordReadings]
  /// kept, which another reading would have nowhere to put.
  Map<WordTake, int>? nextReading(String call, VoiceWord word) {
    final places = <WordTake, int>{};
    for (final take in takesOf(word)) {
      final free = _freePlace(call, word, take);
      if (free == null) return null;
      places[take] = free;
    }
    return places;
  }

  /// Records another reading of [word] in [call]'s set: the word read three
  /// times run together — once, for a [VoiceWord.once] phrase. False when it
  /// could not start ([recordProblem] says why), there is nowhere to keep
  /// it, or the word has all of a take.
  bool record(String call, VoiceWord word) {
    _recordProblem = null;
    _splitProblem = null;
    final places = nextReading(call, word);
    if (places == null) return false;
    return _record(call, word: word, (samples) {
      final takes = splitReading(samples, [word.once ? 1 : 3]).single;
      for (final MapEntry(key: take, value: audio) in wordTakes(samples, takes).entries) {
        this.audio.write(wordFile(call, word, take, reading: places[take]!)!, encodeVoiceWav(audio));
      }
    });
  }

  // --- Record All ---

  /// Every place Record All fills in [call]'s set.
  List<VoiceWordSlot> promptSlots(String call) => voicePromptSlots(words(call));

  /// How many takes [call]'s set keeps of [slot].
  int keptOf(String call, VoiceWordSlot slot) => readings(call, slot.word, slot.take).length;

  /// The set Record All is collecting for [call] — see [voicePromptSet].
  int? promptSet(String call) => voicePromptSet(promptSlots(call), (slot) => keptOf(call, slot), most: voiceWordReadings);

  /// What Record All asks [call]'s operator to read next; null once every
  /// place has all it keeps.
  String? nextPrompt(String call) {
    final set = promptSet(call);
    if (set == null) return null;
    return nextVoicePrompt(words: words(call), phrases: settings.voicePhrases(call), kept: (slot) => keptOf(call, slot), set: set, random: _random);
  }

  /// [text] as Record All cuts it: as a message would say it, every phrase
  /// counted recorded so the one it names is the one read.
  List<WordPiece> promptPieces(String call, String text) =>
      planVoicedText(text, phrases: settings.voicePhrases(call), recorded: (_) => true).pieces.whereType<WordPiece>().toList();

  /// The prompt last read, and the takes it left — for the operator to
  /// listen to, or take back ([forgetLastSaid]).
  ({String text, List<ReadingTake> takes})? get lastSaid => _lastSaid;
  ({String text, List<ReadingTake> takes})? _lastSaid;

  /// Records [text] read as on the air, each word kept as the take it is
  /// where it falls — a call's first word its opening take, and so on — in
  /// the first place free of it; a take with all it keeps gets none. False
  /// when it could not start ([recordProblem] says why).
  bool recordSaid(String call, String text) {
    _recordProblem = null;
    _splitProblem = null;
    final pieces = promptPieces(call, text);
    if (pieces.isEmpty) return false;
    return _record(call, text: text, (samples) {
      final ranges = splitSaid(samples, [for (final piece in pieces) _expectedLength(call, piece.word)]);
      final cut = saidTakes(samples, ranges, inside: [for (final piece in pieces) piece.take == WordTake.middle]);
      final kept = <ReadingTake>[];
      for (final (i, piece) in pieces.indexed) {
        final slot = voicePieceSlot(piece);
        final place = _freePlace(call, slot.word, slot.take);
        if (place == null) continue;
        audio.write(wordFile(call, slot.word, slot.take, reading: place)!, encodeVoiceWav(cut[i]));
        kept.add((word: slot.word, reading: place, take: slot.take));
      }
      _lastSaid = (text: text, takes: kept);
    });
  }

  /// [takes] one after another with [gap] between, on the computer's own
  /// output — Record All playing back what was just read, each word apart
  /// so each cut is heard — with each take as it starts, as [listenToText]
  /// gives them.
  ({AudioPlayback playback, List<({int atMs, ReadingTake? take})> said}) listenToTakes(
    String call,
    List<ReadingTake> takes, {
    Duration gap = const Duration(milliseconds: 300),
  }) {
    final plan = VoicedPlan([for (final (i, take) in takes.indexed) WordPiece(take.word, take.take, i == 0 ? Duration.zero : gap)]);
    final starts = <int>[];
    final playback = _listenTo(() => _write(call, plan, (i, _) => _takeFile(call, takes[i]), starts: starts));
    return (playback: playback, said: [for (final (i, take) in takes.indexed) (atMs: starts[i] * 1000 ~/ voiceWordRate, take: take)]);
  }

  /// Deletes the takes the last prompt read left.
  void forgetLastSaid(String call) {
    for (final take in _lastSaid?.takes ?? const <ReadingTake>[]) {
      if (_dir(call) != null) audio.delete(_takeFile(call, take));
    }
    _lastSaid = null;
    notifyListeners();
  }

  /// How long [word] is said, in milliseconds: its middle takes' own length
  /// where it has them — the operator's pace, not a guess — else
  /// [voiceWordLengthGuess].
  double _expectedLength(String call, VoiceWord word) {
    final lengths = [
      for (final reading in readings(call, word, WordTake.middle))
        if (audio.lengthOf(wordFile(call, word, WordTake.middle, reading: reading)!) case final length?) length.inMilliseconds,
    ];
    return lengths.isEmpty ? voiceWordLengthGuess(word) : lengths.reduce((a, b) => a + b) / lengths.length;
  }

  /// Records into the set's scratch file, then [keep]s what was read.
  bool _record(String call, void Function(Float32List samples) keep, {VoiceWord? word, String? text}) {
    final keyer = recorder(), dir = _dir(call);
    if (keyer == null || dir == null) {
      // Nowhere to record from or to — the directory not yet known.
      _recordProblem = ComputerVoiceProblem.recordingFailed;
      notifyListeners();
      return false;
    }
    final started = keyer.recordFile('$dir/.reading.wav', ceiling: voiceWordReadingCeiling, done: (kept) => _recorded(keyer, kept, keep));
    if (started) {
      _recording = (call: call, word: word, text: text);
      _recordingOn = keyer;
    } else {
      _recordProblem = keyer.problem;
    }
    notifyListeners();
    return started;
  }

  /// Ends a recording, keeping what was read.
  void stopRecording() => _recordingOn?.stopVoice();

  void _recorded(ComputerVoiceKeyer keyer, String? kept, void Function(Float32List samples) keep) {
    _recording = null;
    _recordingOn = null;
    if (kept == null) {
      _recordProblem = keyer.problem;
    } else {
      try {
        keep(audio.decode(kept, rate: voiceWordRate, channels: 1));
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

  /// Plays [take] alone, as a message says it, on the computer's own output
  /// — the operator hearing what they recorded. Null while it is not kept;
  /// refused ([VoicedMessageRefused]) when it will not play.
  AudioPlayback? listen(String call, ReadingTake take) {
    if (!readings(call, take.word, take.take).contains(take.reading)) return null;
    final plan = VoicedPlan([WordPiece(take.word, take.take, Duration.zero)]);
    return _listenTo(() => _write(call, plan, (_, _) => _takeFile(call, take)));
  }

  /// Deletes [take] from [call]'s set, every other take kept.
  void forgetTake(String call, ReadingTake take) {
    if (_dir(call) == null) return;
    audio.delete(_takeFile(call, take));
    notifyListeners();
  }

  void _deleteReading(String call, VoiceWord word, int reading) {
    final dir = _dir(call);
    if (dir == null) return;
    final name = _readingName(word, reading);
    // Both layouts: whatever the word was recorded as goes with it.
    audio.delete('$dir/$name.wav');
    for (final take in WordTake.values) {
      audio.delete('$dir/$name-${take.suffix}.wav');
    }
  }

  /// Deletes every take of every word in [call]'s set. The phrases stay,
  /// to be recorded again.
  void forgetAll(String call) {
    final dir = _dir(call);
    if (dir == null) return;
    audio.deleteDirectory(dir);
    _lastSaid = null;
    notifyListeners();
  }

  /// Deletes every reading of [word] from [call]'s set — and, for a phrase,
  /// the phrase.
  Future<void> forget(String call, VoiceWord word) async {
    for (var reading = 0; reading < voiceWordReadings; reading++) {
      _deleteReading(call, word, reading);
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

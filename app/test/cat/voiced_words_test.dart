// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Voiced words on this computer (voiced_words.dart): a template made into
// one recording from the operator's words, and the words recorded.
//
// The traps are a message said in another operator's voice — the words
// looked up under the wrong call — one that lacks a word played with a hole
// in it rather than refused by name, a refusal nobody hears about, a
// `{{ phone.msgN }}` with no recording behind it, and a reading of the words
// split and kept without the operator's takes landing where a message looks
// for them.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/computer_voice_keyer.dart';
import 'package:ham2k_logger/services/cat/voice_words.dart';
import 'package:ham2k_logger/services/cat/voiced_words.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_secure_storage.dart';
import '../support/fake_voice_audio.dart';

const _root = '/v';

void main() {
  late FakeVoiceAudio audio;
  late SettingsService settings;
  late VoicedWords words;
  late ComputerVoiceKeyer recorder;
  final templates = <int, String>{};

  setUp(() async {
    templates.clear();
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService(await SharedPreferences.getInstance(), secureStorage: FakeSecureStorage());
    audio = FakeVoiceAudio()..inputDevices = [];
    recorder = ComputerVoiceKeyer(ptt: null, audio: audio, config: () => const {}, fileFor: (n) => '$_root/set/$n.wav', report: (_) {});
    words = VoicedWords(
      settings: settings,
      audio: audio,
      root: () => _root,
      messageFile: (n) => '$_root/set/$n.wav',
      messageTemplate: (n) => templates[n] ?? '',
      recorder: () => recorder,
    );
  });

  /// Every take of [spoken] recorded for [call].
  void recordWords(String call, Iterable<String> spoken) {
    for (final word in fixedVoiceWords.where((w) => spoken.contains(w.spoken))) {
      for (final take in WordTake.values) {
        audio.lengths[words.wordFile(call, word, take)!] = const Duration(milliseconds: 400);
      }
    }
  }

  group('saying a message', () {
    late String rendered;
    final refused = <(int, ComputerVoiceProblem)>[];
    late String asked;

    setUp(() {
      rendered = 'K8AB 59';
      refused.clear();
      words.attach(
        (template, n) async {
          asked = template;
          return (text: rendered, operatorCall: 'N0DEV');
        },
        operatorCall: () => 'N0DEV',
        refused: (n, refusal) => refused.add((n, refusal.problem)),
      );
    });

    test("is the draft rendered and said in this operator's words, as one file", () async {
      recordWords('N0DEV', ['Kilo', 'Eight', 'Alpha', 'Bravo', 'Five', 'Nine']);
      final path = (await words.voice(3, '{{ qso.call }} 59')).path;
      expect(audio.written.keys, [path]);
      expect(path, startsWith('$_root/words/'));
      expect(refused, isEmpty);
    });

    test('names what it lacks rather than playing with a hole in it, and the view hears of it', () async {
      recordWords('N0DEV', ['Kilo', 'Eight', 'Alpha', 'Five', 'Nine']);
      // Recorded by another operator, whose voice is not this one's.
      recordWords('W1AW', ['Bravo']);
      await expectLater(
        words.voice(3, '{{ qso.call }} 59'),
        throwsA(isA<VoicedMessageRefused>().having((e) => e.problem, 'problem', ComputerVoiceProblem.wordsMissing).having((e) => e.detail, 'detail', 'Bravo')),
      );
      expect(audio.written, isEmpty);
      expect(refused, [(3, ComputerVoiceProblem.wordsMissing)]);
    });

    test('{{ phone.msgN }} reaches the renderer as a mark, and needs that message recorded', () async {
      recordWords('N0DEV', ['Kilo', 'Eight', 'Alpha', 'Bravo']);
      rendered = '${voicedMessageMark(2)} K8AB';
      await expectLater(words.voice(1, '{{ phone.msg2 }} {{ qso.call }}'), throwsA(isA<VoicedMessageRefused>().having((e) => e.detail, 'detail', 'M2')));
      expect(asked, '${voicedMessageMark(2)} {{ qso.call }}');
      audio.lengths['$_root/set/2.wav'] = const Duration(seconds: 2);
      await words.voice(1, '{{ phone.msg2 }} {{ qso.call }}');
      expect(audio.written, hasLength(1));
    });

    test("a template listened to in the editor is refused there, and the operation view hears nothing of it", () async {
      // A refusal reaching the view would show a status-bar notice for a
      // message nobody tried to key.
      recordWords('N0DEV', ['Kilo', 'Eight', 'Alpha', 'Five', 'Nine']);
      await expectLater(words.listenToTemplate(3, '{{ qso.call }}'), throwsA(isA<VoicedMessageRefused>().having((e) => e.detail, 'detail', 'Bravo')));
      expect(refused, isEmpty);
      recordWords('N0DEV', ['Bravo']);
      expect(await words.listenToTemplate(3, '{{ qso.call }}'), isNotNull);
      expect(audio.written, hasLength(1));
    });

    test("{{ phone.msgN }} of a message said with words says that message's words, one level deep", () async {
      // Taken for a recording, M2 would be refused for having none, or play
      // an old one; followed without end, a message naming itself would
      // never finish rendering.
      templates[2] = 'QSL? {{ phone.msg2 }}';
      await expectLater(words.voice(1, '{{ phone.msg2 }}'), throwsA(isA<VoicedMessageRefused>()));
      expect(asked, 'QSL? ${voicedMessageMark(2)}');
    });

    test('with no operation open there is nothing to say it for', () async {
      words = VoicedWords(
        settings: settings,
        audio: audio,
        root: () => _root,
        messageFile: (n) => '$_root/set/$n.wav',
        messageTemplate: (n) => templates[n] ?? '',
        recorder: () => recorder,
      );
      await expectLater(
        words.voice(1, '{{ qso.call }}'),
        throwsA(isA<VoicedMessageRefused>().having((e) => e.problem, 'problem', ComputerVoiceProblem.noOperation)),
      );
    });
  });

  test("text tried out is said in the named call's words, with no operation open", () {
    recordWords('W1AW', ['Five', 'Nine']);
    expect(
      () => words.listenToText('N0DEV', '59'),
      throwsA(isA<VoicedMessageRefused>().having((e) => e.problem, 'problem', ComputerVoiceProblem.wordsMissing)),
    );
    expect(words.listenToText('W1AW', '59'), isNotNull);
  });

  test('a phrase of several words is recorded once, and said from that one recording', () async {
    await words.addPhrase('N0DEV', const VoicePhrase(id: 'ty', text: 'thank you'));
    final phrase = words.words('N0DEV').last;
    expect(phrase.once, isTrue);
    // Each take's file is the one recording: looked for as three, a phrase
    // recorded once would never count as recorded.
    expect({for (final take in WordTake.values) words.wordFile('N0DEV', phrase, take)}, {'$_root/words/N0DEV/p-ty.wav'});
    audio.lengths['$_root/words/N0DEV/p-ty.wav'] = const Duration(seconds: 1);
    expect(words.recorded('N0DEV', phrase), isTrue);
    // Placed as an opening, it plays as its pill names it, or the pill
    // never lights.
    expect(words.listenToText('N0DEV', 'thank you').said.single.take?.take, WordTake.middle);
  });

  // The trap: a suffix asked for in all three takes, so a set Record All
  // filled — "stroke" only inside a call, "/P" only closing one — refuses
  // every call with a suffix.
  test('a suffix needs only the take a message says it in, and is said from it wherever the planner puts it', () {
    recordWords('N0DEV', ['November', 'Zero', 'Delta', 'Echo', 'Victor', 'Four']);
    final portable = fixedPhraseWords.firstWhere((w) => w.phrase == '/P');
    audio.lengths[words.wordFile('N0DEV', strokeWord, WordTake.middle)!] = const Duration(milliseconds: 400);
    audio.lengths[words.wordFile('N0DEV', portable, WordTake.closing)!] = const Duration(milliseconds: 400);
    expect(words.recorded('N0DEV', strokeWord), isTrue);
    expect(words.recorded('N0DEV', portable), isTrue);
    expect(words.listenToText('N0DEV', 'N0DEV/4'), isNotNull);
    expect(words.listenToText('N0DEV', 'N0DEV/P'), isNotNull);
    final alone = words.listenToText('N0DEV', '/P DE N0DEV').said.first.take!;
    expect((alone.word, alone.take), (portable, WordTake.closing), reason: 'placed opening, said from the take it has');
  });

  test("a take that will not play is refused as unplayable, for the pane to say", () {
    // Returned as nothing, the Listen press did nothing at all: the failure
    // is uploaded quietly, on the promise that the pane says it.
    recordWords('N0DEV', ['Five', 'Nine']);
    audio.failingDecodes.add(words.wordFile('N0DEV', fixedVoiceWords.firstWhere((w) => w.spoken == 'Nine'), WordTake.closing)!);
    expect(() => words.listenToText('N0DEV', '59'), throwsA(isA<VoicedMessageRefused>().having((e) => e.problem, 'problem', ComputerVoiceProblem.unplayable)));
  });

  /// [word] read for [call] as the operator reads it — three takes run
  /// together, once for a phrase — and the recording stopped.
  void readWord(String call, VoiceWord word) {
    final reading = <double>[];
    void part(int ms, double? db) {
      final noise = math.Random(reading.length);
      for (var i = 0; i < ms * voiceWordRate ~/ 1000; i++) {
        final a = db == null ? 0.0 : math.pow(10, db / 20).toDouble();
        reading.add(a * math.sin(2 * math.pi * 180 * reading.length / voiceWordRate) + (noise.nextDouble() - 0.5) * 2e-4);
      }
    }

    part(300, null);
    for (var take = 0; take < (word.once ? 1 : 3); take++) {
      part(300, -10);
      part(40, null);
    }
    part(700, null);
    expect(words.record(call, word), isTrue);
    final recordingPath = '$_root/words/${voiceWordSetCall(call)}/.reading.wav.recording';
    audio
      ..lengths[recordingPath] = const Duration(seconds: 3)
      ..samples[recordingPath] = Float32List.fromList(reading);
    audio.recordings.last.peak = 0.3;
    words.stopRecording();
  }

  // The trap: another reading written over the first, or kept where no
  // message looks — recorded, and never heard; a bad take that cannot go
  // without its good ones; and takes shown in an order the operator never
  // recorded them in.
  test('each take of a reading is kept, and deleted, on its own, up to five of each', () {
    final kilo = fixedVoiceWords.firstWhere((w) => w.spoken == 'Kilo');
    List<String> shown() => [for (final t in words.takes('N0DEV', kilo)) '${t.reading}${t.take.suffix}'];
    readWord('N0DEV', kilo);
    expect(words.splitProblem, isNull);
    expect(shown(), ['0i', '0m', '0f']);
    expect(audio.written.keys, containsAll(['$_root/words/N0DEV/k-i.wav', '$_root/words/N0DEV/k-m.wav', '$_root/words/N0DEV/k-f.wav']));
    expect(audio.deleted, contains('$_root/words/N0DEV/.reading.wav'), reason: 'the reading is split, then gone');
    expect(words.recording, isNull);

    readWord('N0DEV', kilo);
    expect(shown(), ['0i', '0m', '0f', '1i', '1m', '1f']);

    words.forgetTake('N0DEV', (word: kilo, reading: 0, take: WordTake.opening));
    expect(audio.deleted, contains('$_root/words/N0DEV/k-i.wav'));
    expect(shown(), ['0m', '0f', '1i', '1m', '1f'], reason: "the reading's other takes kept");
    expect(words.recorded('N0DEV', kilo), isTrue);

    // The next reading's opening take fills the place the deleted one left;
    // its others go after the second reading's. Shown as recorded, last.
    readWord('N0DEV', kilo);
    expect(audio.written.keys, containsAll(['$_root/words/N0DEV/k~2-m.wav', '$_root/words/N0DEV/k~2-f.wav']));
    expect(shown(), ['0m', '0f', '1i', '1m', '1f', '0i', '2m', '2f'], reason: 'in the order recorded, not by place');

    words.forgetTake('N0DEV', (word: kilo, reading: 1, take: WordTake.closing));
    words.forgetTake('N0DEV', (word: kilo, reading: 2, take: WordTake.closing));
    words.forgetTake('N0DEV', (word: kilo, reading: 0, take: WordTake.closing));
    expect(words.recorded('N0DEV', kilo), isFalse, reason: 'no closing take: a call cannot end on Kilo');

    for (var i = 0; i < 2; i++) {
      readWord('N0DEV', kilo);
    }
    expect(words.readings('N0DEV', kilo, WordTake.middle), [0, 1, 2, 3, 4]);
    expect(words.record('N0DEV', kilo), isFalse, reason: 'five of a take is all a word keeps');
    expect(words.recording, isNull);
  });

  /// [text] read for Record All as [lengths] of speech run together, a
  /// shallow dip between each word, and the recording stopped.
  void readSaid(String call, String text, List<int> lengths) {
    final reading = <double>[];
    void part(int ms, double? db) {
      final noise = math.Random(reading.length);
      for (var i = 0; i < ms * voiceWordRate ~/ 1000; i++) {
        final a = db == null ? 0.0 : math.pow(10, db / 20).toDouble();
        reading.add(a * math.sin(2 * math.pi * 180 * reading.length / voiceWordRate) + (noise.nextDouble() - 0.5) * 2e-4);
      }
    }

    part(300, null);
    for (final (i, ms) in lengths.indexed) {
      if (i > 0) part(30, -28);
      part(ms, -10);
    }
    part(500, null);
    expect(words.recordSaid(call, text), isTrue);
    final recordingPath = '$_root/words/${voiceWordSetCall(call)}/.reading.wav.recording';
    audio
      ..lengths[recordingPath] = const Duration(seconds: 3)
      ..samples[recordingPath] = Float32List.fromList(reading);
    audio.recordings.last.peak = 0.3;
    words.stopRecording();
  }

  // The trap: a call's words kept as the wrong takes — its first word as a
  // middle one — so a message opens on a word said from inside a call; and
  // a reading that cannot be taken back.
  test('a call read for Record All keeps each word as the take it is where it falls, and Redo takes them back', () {
    VoiceWord w(String key) => fixedVoiceWords.firstWhere((word) => word.key == key);
    final a = w('a');
    expect(words.keptOf('N0DEV', (word: a, take: WordTake.opening)), 0);
    readSaid('N0DEV', 'AB1C', const [400, 400, 300, 450]);
    expect(words.splitProblem, isNull);
    expect(
      audio.written.keys,
      containsAll(['$_root/words/N0DEV/a-i.wav', '$_root/words/N0DEV/b-m.wav', '$_root/words/N0DEV/1-m.wav', '$_root/words/N0DEV/c-f.wav']),
    );
    expect(audio.written.keys, isNot(contains('$_root/words/N0DEV/a-m.wav')), reason: 'only the take it is');
    expect(words.keptOf('N0DEV', (word: a, take: WordTake.opening)), 1);
    expect([for (final t in words.lastSaid!.takes) '${t.word.key}-${t.take.suffix}'], ['a-i', 'b-m', '1-m', 'c-f']);

    // Another with the same opening word goes in the next place free of it.
    readSaid('N0DEV', 'A2DE', const [400, 300, 400, 400]);
    expect(audio.written.keys, contains('$_root/words/N0DEV/a~1-i.wav'));

    words.forgetLastSaid('N0DEV');
    expect(audio.deleted, containsAll(['$_root/words/N0DEV/a~1-i.wav', '$_root/words/N0DEV/2-m.wav', '$_root/words/N0DEV/e-f.wav']));
    expect(audio.deleted, isNot(contains('$_root/words/N0DEV/a-i.wav')), reason: 'only the last reading goes');
    expect(words.lastSaid, isNull);
  });

  test("a take with all it keeps gets none from a call read, and the call's other words are kept", () {
    final a = fixedVoiceWords.firstWhere((word) => word.key == 'a');
    for (var reading = 0; reading < voiceWordReadings; reading++) {
      audio.lengths[words.wordFile('N0DEV', a, WordTake.opening, reading: reading)!] = const Duration(milliseconds: 400);
    }
    readSaid('N0DEV', 'AB1C', const [400, 400, 300, 450]);
    expect([for (final t in words.lastSaid!.takes) t.word.key], ['b', '1', 'c']);
    expect(words.keptOf('N0DEV', (word: a, take: WordTake.opening)), voiceWordReadings);
  });

  // Drawn once per word, a message mixes nothing: every Kilo in it, and in
  // every message, sounds alike, which is what several readings are for.
  test("a message draws each take from any of the word's readings, on its own", () {
    final scripted = _ScriptedRandom([1, 0, 0, 2]);
    words = VoicedWords(
      settings: settings,
      audio: audio,
      root: () => _root,
      messageFile: (n) => '$_root/set/$n.wav',
      messageTemplate: (n) => templates[n] ?? '',
      recorder: () => recorder,
      random: scripted,
    );
    final kilo = fixedVoiceWords.firstWhere((w) => w.spoken == 'Kilo'), eight = fixedVoiceWords.firstWhere((w) => w.spoken == 'Eight');
    for (final word in [kilo, eight]) {
      for (final reading in [0, 1, 2]) {
        for (final take in WordTake.values) {
          audio.lengths[words.wordFile('N0DEV', word, take, reading: reading)!] = const Duration(milliseconds: 300);
        }
      }
    }
    words.listenToText('N0DEV', 'K8');
    words.listenToText('N0DEV', 'K8');
    expect(audio.decodes, ['$_root/words/N0DEV/k~1-i.wav', '$_root/words/N0DEV/8-f.wav', '$_root/words/N0DEV/k-i.wav', '$_root/words/N0DEV/8~2-f.wav']);
  });
}

/// A [math.Random] whose ints are [ints], in turn.
class _ScriptedRandom implements math.Random {
  _ScriptedRandom(this.ints);

  final List<int> ints;
  var _next = 0;

  @override
  int nextInt(int max) {
    final n = ints[_next++ % ints.length];
    expect(n, lessThan(max));
    return n;
  }

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}

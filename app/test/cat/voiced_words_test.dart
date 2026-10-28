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
      final path = await words.voice(3, '{{ qso.call }} 59');
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
    expect(words.listenToText('N0DEV', 'thank you'), isNotNull);
  });

  test("a take that will not play is refused as unplayable, for the pane to say", () {
    // Returned as nothing, the Listen press did nothing at all: the failure
    // is uploaded quietly, on the promise that the pane says it.
    recordWords('N0DEV', ['Five', 'Nine']);
    audio.failingDecodes.add(words.wordFile('N0DEV', fixedVoiceWords.firstWhere((w) => w.spoken == 'Nine'), WordTake.closing)!);
    expect(() => words.listenToText('N0DEV', '59'), throwsA(isA<VoicedMessageRefused>().having((e) => e.problem, 'problem', ComputerVoiceProblem.unplayable)));
  });

  test('a reading of two words keeps three takes of each, where a message looks for them', () {
    // Two lines, words run together inside each.
    final reading = <double>[];
    void part(int ms, double? db) {
      final noise = math.Random(reading.length);
      for (var i = 0; i < ms * voiceWordRate ~/ 1000; i++) {
        final a = db == null ? 0.0 : math.pow(10, db / 20).toDouble();
        reading.add(a * math.sin(2 * math.pi * 180 * reading.length / voiceWordRate) + (noise.nextDouble() - 0.5) * 2e-4);
      }
    }

    part(300, null);
    for (var line = 0; line < 2; line++) {
      for (var take = 0; take < 3; take++) {
        part(300, -10);
        part(40, null);
      }
      part(700, null);
    }
    final kilo = fixedVoiceWords.firstWhere((w) => w.spoken == 'Kilo'), eight = fixedVoiceWords.firstWhere((w) => w.spoken == 'Eight');
    expect(words.record('N0DEV', [kilo, eight]), isTrue);
    const recordingPath = '$_root/words/N0DEV/.reading.wav.recording';
    audio
      ..lengths[recordingPath] = const Duration(seconds: 6)
      ..samples[recordingPath] = Float32List.fromList(reading);
    audio.recordings.single.peak = 0.3;
    words.stopRecording();

    expect(words.splitProblem, isNull);
    expect(words.recorded('N0DEV', kilo), isTrue);
    expect(words.recorded('N0DEV', eight), isTrue);
    expect(audio.written.keys, containsAll(['$_root/words/N0DEV/k-i.wav', '$_root/words/N0DEV/8-f.wav']));
    expect(audio.deleted, contains('$_root/words/N0DEV/.reading.wav'), reason: 'the reading is split, then gone');
    expect(words.recording, isNull);
  });
}

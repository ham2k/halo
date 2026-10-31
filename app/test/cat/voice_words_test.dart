// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Voiced words (voice_words.dart): a message's text said from the operator's
// recordings of each letter, digit and phrase.
//
// The traps are a call said like a list — every word on its closing take, or
// evenly spaced — a phrase spelled letter by letter because a shorter one
// matched first, a word's decay dragging after it or its last consonant cut
// off with it, and a recording split in the wrong place: at the stop inside
// "Whiskey" rather than between two of them, or one reading's lines taken
// apart at the pause inside "eight, eight, eight".

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/voice_words.dart';

const _rate = voiceWordRate;

/// Synthetic speech: (milliseconds, level in dBFS — null for the room).
Float32List _signal(List<(int, double?)> parts) {
  final out = <double>[];
  final noise = math.Random(1);
  for (final (ms, db) in parts) {
    final n = ms * _rate ~/ 1000;
    final amplitude = db == null ? 0.0 : math.pow(10, db / 20).toDouble();
    for (var i = 0; i < n; i++) {
      out.add(amplitude * math.sin(2 * math.pi * 180 * out.length / _rate) + (noise.nextDouble() - 0.5) * 2e-4);
    }
  }
  return Float32List.fromList(out);
}

int _ms(int samples) => samples * 1000 ~/ _rate;

void main() {
  bool all(VoiceWord _) => true;
  // Every word but the phrases every set has: they are spelled unrecorded.
  bool own(VoiceWord word) => !fixedPhraseWords.contains(word);

  group('planVoicedText', () {
    test('a call is its prefix and suffix, and each part of a message starts and ends on its own takes', () {
      final plan = planVoicedText('K8AB 59 7', recorded: all);
      // The trap: every word on its closing take is a list being read, not a
      // call being given.
      expect(plan.describe(), 'Kilo(i) Eight Alpha Bravo(f) Five(i) Nine(f) Seven(f)');
      const pacing = VoicedPacing();
      final letters = pacing.letters, groups = pacing.groups, words = pacing.words;
      expect([for (final p in plan.pieces) p.gap], [Duration.zero, letters, groups, letters, words, letters, words]);
    });

    test("the operator's spacing lays the words down, and where a part starts does not depend on it", () {
      // Letters set further apart than words: a part told by its gap would
      // run "K8AB 59" together as one and split the call inside itself.
      const pacing = VoicedPacing(letters: Duration(milliseconds: 300), words: Duration(milliseconds: 100));
      final plan = planVoicedText('K8AB 59', pacing: pacing, recorded: all);
      expect([for (final p in plan.pieces) p.gap.inMilliseconds], [0, 300, 380, 300, 100, 300]);
      expect([for (final p in plan.pieces) p.startsPart], [true, false, false, false, true, false]);
    });

    test('a slash is said as "stroke", a breath ahead of it, and what follows it spelled', () {
      final plan = planVoicedText('N9CW/P', recorded: own);
      expect(plan.describe(), 'November(i) Nine Charlie Whiskey Stroke Papa(f)');
      expect(plan.pieces[4].gap, const VoicedPacing().stroke);
      expect(plan.unrecorded, isEmpty, reason: 'a fixed phrase not recorded is spelled, not missing');
    });

    test("a call's last slash part is its slashed phrase, and no phrase is said from inside a call", () {
      // "/P" said as the operator recorded it ("portable") ends the call;
      // "TU" matched inside KI2TU would say a call as "KI2, thank you".
      expect(planVoicedText('N9CW/P', recorded: all).describe(), 'November(i) Nine Charlie Whiskey /P(f)');
      expect(planVoicedText('N9CW/P', recorded: all).pieces.last.gap, const VoicedPacing().stroke);
      expect(planVoicedText('VE3/K8AB', recorded: all).describe(), 'Victor(i) Echo Three Stroke Kilo Eight Alpha Bravo(f)');
      expect(planVoicedText('KI2TU TU', recorded: all).describe(), 'Kilo(i) India Two Tango Uniform(f) TU(f)');
      expect(planVoicedText('TU', recorded: own).describe(), 'Tango(i) Uniform(f)');
    });

    test('the longest phrase wins, on whole words, and what no phrase covers is spelled', () {
      final phrases = [const VoicePhrase(id: 'cq', text: 'CQ'), const VoicePhrase(id: 'cqpota', text: 'CQ POTA')];
      final plan = planVoicedText('cq pota, de K8AB', phrases: phrases, recorded: all);
      // "CQ" alone matching first would say "CQ" then spell P-O-T-A.
      expect(plan.describe(), 'CQ POTA(i) Delta(i) Echo(f) Kilo(i) Eight Alpha Bravo(f)');
    });

    test('a phrase written with its punctuation is its own recording, and one without takes any punctuation', () {
      // "QRZ?" asks; "QRZ" stripped of its "?" would say the question flat,
      // and a "?" phrase matching a plain "QRZ" would ask what was not asked.
      final phrases = [const VoicePhrase(id: 'plain', text: 'QRZ'), const VoicePhrase(id: 'asked', text: 'qrz?')];
      String said(String text) => (planVoicedText(text, phrases: phrases, recorded: own).pieces.single as WordPiece).word.key;
      expect(said('QRZ?'), 'p-asked');
      expect(said('QRZ'), 'p-plain');
      expect(said('QRZ,'), 'p-plain');
      expect((planVoicedText('QRZ', phrases: [phrases.last], recorded: own).describe()), 'Quebec(i) Romeo Zulu(f)');
    });

    test("a phrase is matched as a message's words are read, and the operator's own wins over a fixed one", () {
      // A lone dash kept in the phrase would never match the message, which
      // drops it; and which of two "/P" recordings plays must not depend on
      // how a sort happened to order them.
      final dashed = planVoicedText(
        'CQ - POTA',
        phrases: [const VoicePhrase(id: 'd', text: 'CQ - POTA')],
        recorded: all,
      );
      expect((dashed.pieces.single as WordPiece).word.key, 'p-d');
      final mine = [const VoicePhrase(id: 'mine', text: '/P')];
      expect((planVoicedText('/P', phrases: mine, recorded: all).pieces.single as WordPiece).word.key, 'p-mine');
      expect((planVoicedText('N9CW/P', phrases: mine, recorded: all).pieces.last as WordPiece).word.key, 'p-mine');
    });

    test('a word of one part takes the middle take inside a message, so it neither starts nor ends it', () {
      final plan = planVoicedText(
        'K8AB QRZ 5',
        phrases: [const VoicePhrase(id: 'q', text: 'QRZ')],
        recorded: all,
      );
      expect(
        [for (final p in plan.pieces.whereType<WordPiece>()) p.take],
        [
          WordTake.opening, WordTake.middle, WordTake.middle, WordTake.closing, //
          WordTake.middle, // QRZ
          WordTake.closing, // 5, the message's last word
        ],
      );
    });

    test("{{ phone.msgN }} is that message's recording, a part of its own", () {
      final text = markVoicedMessages('{{ phone.msg3 }} K8AB {{phone.msg2}}');
      final plan = planVoicedText(text, recorded: all);
      expect(plan.pieces.first, isA<RecordingPiece>().having((p) => p.message, 'message', 3));
      expect(plan.pieces.last, isA<RecordingPiece>().having((p) => p.message, 'message', 2).having((p) => p.gap, 'gap', VoicedPacing.defaultWords));
      expect(plan.describe(), '[message 3] Kilo(i) Eight Alpha Bravo(f) [message 2]');
    });

    test('what cannot be said is named, once each, and the plan is not speakable', () {
      final plan = planVoicedText('K8AB #1 KÖ', recorded: (w) => w.key != 'k');
      expect(plan.unrecorded.map((w) => w.spoken), ['Kilo']);
      expect(plan.unspeakable, ['#', 'Ö']);
      expect(plan.speakable, isFalse);
      expect(planVoicedText('K8AB', recorded: all).speakable, isTrue);
    });
  });

  test('a faster word is shorter at the same pitch', () {
    // Resampled to speed it up, a word would rise in pitch with the speed:
    // the operator's voice turned into someone else's.
    final word = _signal([(600, -10)]);
    int crossings(Float32List s) {
      var n = 0;
      for (var i = 1; i < s.length; i++) {
        if ((s[i - 1] < 0) != (s[i] < 0)) n++;
      }
      return n;
    }

    for (final speed in [0.5, 1.5]) {
      final changed = changeTempo(word, speed);
      expect(_ms(changed.length), closeTo(600 / speed, 5));
      final pitch = crossings(changed) / changed.length, original = crossings(word) / word.length;
      expect(pitch, closeTo(original, original * 0.05), reason: 'at ${speed}x');
    }
  });

  // The keyer line sets apart what has been said as a message plays. A span
  // off by one bolds a letter before it is heard; one for a phrase that
  // covers only its first word shows "CQ" said while "POTA" is.
  group('where each piece is written', () {
    (int, int) span(String text, String written) => (text.indexOf(written), text.indexOf(written) + written.length);

    test('a letter is its character, punctuation and spacing left out', () {
      const text = ' k8ab,  59 ';
      final plan = planVoicedText(text, recorded: all);
      expect(plan.spans, [(1, 2), (2, 3), (3, 4), (4, 5), (8, 9), (9, 10)]);
    });

    test('a phrase is all its words; a stroke its slash; a slashed phrase its slash and suffix', () {
      final phrases = [const VoicePhrase(id: 'cqpota', text: 'CQ POTA')];
      const text = 'cq pota N9CW/P VE3/K8AB';
      final plan = planVoicedText(text, phrases: phrases, recorded: all);
      expect(plan.describe(), startsWith('CQ POTA(i) November(i) Nine Charlie Whiskey /P(f)'));
      expect(plan.spans.first, span(text, 'cq pota'));
      expect(plan.spans[5], span(text, '/P'), reason: 'said as "portable", it is the whole suffix');
      expect(plan.spans[9], (text.indexOf('/K'), text.indexOf('/K') + 1), reason: 'said as "stroke", it is the slash alone');
    });

    test("the script shows a recorded message by its name, and says through each piece's end as it starts", () {
      final text = ' ${voicedMessageMark(2)}   K8 ';
      final plan = planVoicedText(text, recorded: all);
      final script = voicedScript(text, plan, [0, 48000, 60000], (n) => 'CQ M$n')!;
      expect(script.text, 'CQ M2 K8');
      expect(script.marks, [(atMs: 0, said: 5), (atMs: 1000, said: 7), (atMs: 1250, said: 8)]);
    });

    test('a plan that does not say where its pieces are has no script', () {
      final plan = VoicedPlan([const WordPiece(VoiceWord('kilo', 'Kilo'), WordTake.middle, Duration.zero)]);
      expect(voicedScript('K', plan, [0], (n) => ''), isNull);
    });
  });

  group('cutWordTail', () {
    test('cuts the decay 20 dB under the peak, and keeps a final consonant above that line', () {
      // A vowel, the "t" of Eight 15 dB under it, then the long decay of a
      // word said on its own.
      final word = _signal([(200, -6), (60, -21), (300, -36)]);
      final cut = cutWordTail(word);
      // The "t" is kept (200 + 60 ms), the decay goes, but for the 30 ms fade.
      expect(_ms(cut.length), inInclusiveRange(260, 300));
    });
  });

  group('splitWordTakes', () {
    test('cuts between the words, not at the stop inside one that is as long as the gap between them', () {
      // "Whis-key whis-key whis-key": a 60 ms stop inside each word, 50 ms
      // between words — pause length alone takes the stops for boundaries.
      final whiskey = [(150, -10.0), (60, null), (180, -14.0)];
      final s = _signal([(200, null), ...whiskey, (50, null), ...whiskey, (50, null), ...whiskey, (300, null)]);
      final takes = splitWordTakes(s);
      expect(takes, hasLength(3));
      for (final (a, b) in takes) {
        expect(_ms(b - a), inInclusiveRange(380, 520), reason: 'a take is a whole word, not half of one');
      }
    });

    test('a click before the words is not where the first take starts', () {
      // The click of the button that starts the recording, then "Bravo" run
      // together three times: counted as speech, the click pulls every split
      // forward and the opening take is the click and a silence.
      final bravo = [(160, -10.0), (40, -30.0), (200, -12.0)];
      final s = _signal([(200, null), (50, -12), (400, null), ...bravo, (30, null), ...bravo, (30, null), ...bravo, (300, null)]);
      final takes = splitWordTakes(s);
      expect(_ms(takes.first.$1), greaterThan(600), reason: 'the opening take starts at the first word');
      for (final (a, b) in takes) {
        expect(_ms(b - a), inInclusiveRange(380, 520), reason: 'a take is a whole word');
      }
    });

    test('a word said only twice is not three takes', () {
      final s = _signal([(200, null), (300, -10), (300, null), (300, -10), (300, null)]);
      expect(() => splitWordTakes(s), throwsA(isA<VoiceWordSplitException>()));
    });
  });

  group('splitReading', () {
    List<(int, double?)> line(int insideGap) => [(250, -10), (insideGap, null), (250, -10), (insideGap, null), (250, -12)];

    test('the lines are the longest gaps, though a pause inside a line comes close', () {
      // A breath between lines of 450 ms, a stop of 230 ms inside one: any
      // fixed pause length between the two misreads the other reading.
      final s = _signal([(300, null), ...line(230), (450, null), ...line(40), (450, null), ...line(40), (300, null)]);
      final words = splitReading(s, const [3, 3, 3]);
      expect(words, hasLength(3));
      expect([for (final w in words) w.length], [3, 3, 3]);
      // Each line's takes lie inside that line.
      expect(_ms(words[1][0].$1), greaterThan(300 + 1210 + 400));
    });

    test('lines no further apart than the pauses inside them are refused rather than guessed', () {
      // Words run together in two lines and apart in the one between: the
      // pauses inside that one are nearly the breaths around it.
      final s = _signal([(300, null), ...line(100), (350, null), ...line(300), (350, null), ...line(100), (300, null)]);
      expect(
        () => splitReading(s, const [3, 3, 3]),
        throwsA(isA<VoiceWordSplitException>().having((e) => e.problem, 'problem', VoiceWordSplitProblem.linesTooClose)),
      );
    });

    test('read with a pause after every word, the words go three to a line', () {
      final word = [(300, -10.0), (700, null)];
      final s = _signal([(300, null), for (var i = 0; i < 6; i++) ...word]);
      final words = splitReading(s, const [3, 3]);
      expect([for (final w in words) w.length], [3, 3]);
      expect(_ms(words[1][0].$1), inInclusiveRange(3200, 3300));
    });

    test("a line's last take ends before the next line begins", () {
      // A short breath between lines, the words inside each run together:
      // a closing take running on past the breath ends on the next word.
      final s = _signal([(300, null), ...line(40), (200, null), ...line(40), (300, null)]);
      final words = splitReading(s, const [3, 3]);
      expect(words[0].last.$2, lessThanOrEqualTo(words[1].first.$1));
    });

    test('a phrase of several words is one take, its own pauses kept inside it', () {
      // "Kilo kilo kilo", then "thank you" read once: split as three takes,
      // the phrase would be cut at its pause into words never said alone.
      final thankYou = [(250, -10.0), (120, null), (250, -12.0)];
      final s = _signal([(300, null), ...line(40), (500, null), ...thankYou, (300, null)]);
      final words = splitReading(s, const [3, 1]);
      expect([for (final w in words) w.length], [3, 1]);
      final (a, b) = words[1].single;
      expect(_ms(b - a), greaterThan(600), reason: 'both words, and the pause between them');
    });
  });

  test("a word's takes share one gain, so its closing take keeps the drop it was said with", () {
    final s = _signal([(100, null), (300, -10), (100, null), (300, -10), (100, null), (300, -16), (100, null)]);
    final takes = wordTakes(s, splitWordTakes(s));
    double peak(Float32List t) => t.fold(0.0, (m, v) => math.max(m, v.abs()));
    final drop = 20 * math.log(peak(takes[WordTake.closing]!) / peak(takes[WordTake.middle]!)) / math.ln10;
    expect(drop, closeTo(-6, 0.5));
  });

  test('a negative gap overlaps the word before instead of adding silence', () {
    final plan = VoicedPlan([const RecordingPiece(1, Duration.zero), const RecordingPiece(2, Duration(milliseconds: -100))]);
    final joined = joinVoicedPlan(plan, (_) => _signal([(500, -10)]));
    expect(_ms(joined.length), 900);
  });

  test("a WAV is 16-bit mono at the recorder's rate", () {
    final wav = encodeVoiceWav(Float32List(480));
    final data = ByteData.sublistView(wav);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(data.getUint16(22, Endian.little), 1);
    expect(data.getUint32(24, Endian.little), _rate);
    expect(data.getUint16(34, Endian.little), 16);
    expect(wav.length, 44 + 960);
  });
}

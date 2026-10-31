// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Word Recordings pane (voice_words_pane.dart): a word records another
// reading from its own row, and each reading it keeps is a pill in that row,
// each take a pill of its own to play it and an X to delete it. The traps
// are a take the operator cannot reach to delete — a bad one stays in every
// message it is drawn into — a Delete that takes the word's other takes
// with it, or one that takes a take on a stray tap; and a message tried out
// that does not show which recording said which word.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/voice_word_prompts.dart';
import 'package:ham2k_logger/services/cat/voice_words.dart';
import 'package:ham2k_logger/services/cat/voiced_words.dart';
import 'package:ham2k_logger/services/halo_services.dart';
import 'package:ham2k_logger/services/voice_message_set.dart';
import 'package:ham2k_logger/views/voice_words_pane.dart';

import '../support/fake_voice_audio.dart';
import '../support/halo_test_support.dart';

void main() {
  late FakeVoiceAudio audio;
  late HaLoServices services;

  setUp(() async {
    audio = FakeVoiceAudio();
    services = (await makeHaLoServices(
      cat: (settings) => CatService(settings, voiceAudio: audio, voiceMessagesDirectory: () async => '/v'),
    )).services;
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(onPressed: () => showVoiceWordsPane(context, services), child: const Text('open')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Words for operator'), 'N0DEV');
    await tester.pumpAndSettle();
  }

  /// Kilo's [readings], each take 300 ms long.
  VoicedWords recordKilo(List<int> readings) {
    final words = services.cat.keyer('A').voicedWords!;
    final kilo = fixedVoiceWords.firstWhere((w) => w.spoken == 'Kilo');
    for (final reading in readings) {
      for (final take in WordTake.values) {
        audio.lengths[words.wordFile('N0DEV', kilo, take, reading: reading)!] = const Duration(milliseconds: 300);
      }
    }
    return words;
  }

  Finder kiloRow() => find.ancestor(of: find.text('Kilo'), matching: find.byType(ListTile));

  /// Whether the take pill [label] is lit, as the take playing.
  bool lit(WidgetTester tester, String label) {
    final segment = find.ancestor(of: find.bySemanticsLabel(label), matching: find.byType(Material)).first;
    return tester.widget<Material>(segment).color == Theme.of(tester.element(segment)).colorScheme.primary;
  }

  testWidgets("each take is a pill in its word's row: a tap plays it, and its X deletes that take alone, once confirmed", (tester) async {
    // The directory is found the first time something asks.
    services.cat.keyer('A').voicedWords!.root();
    await tester.runAsync(pumpEventQueue);
    final words = recordKilo([0, 1]);
    final kilo = fixedVoiceWords.firstWhere((w) => w.spoken == 'Kilo');
    await open(tester);

    expect(find.descendant(of: kiloRow(), matching: find.bySemanticsLabel('Record Another')), findsOneWidget);
    expect(
      find.descendant(of: kiloRow(), matching: find.text('Record Another')),
      findsNothing,
      reason: 'the button is its icon alone',
    );
    final alphaRow = find.ancestor(of: find.text('Alpha'), matching: find.byType(ListTile));
    expect(
      find.descendant(of: alphaRow, matching: find.bySemanticsLabel('Record')),
      findsOneWidget,
      reason: 'a word with nothing records its first',
    );
    // Each take of each reading in the word's own row, between its name and Record.
    for (final label in ['First take 1', 'Middle take 1', 'Last take 1', 'First take 2', 'Last take 2']) {
      expect(
        find.descendant(of: kiloRow(), matching: find.bySemanticsLabel(label)),
        findsOneWidget,
        reason: label,
      );
    }

    await tester.ensureVisible(kiloRow());
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: kiloRow(), matching: find.bySemanticsLabel('Middle take 2')));
    await tester.pump();
    expect(audio.decodes, ['/v/words/N0DEV/k~1-m.wav'], reason: 'a tap on a take plays that take of that reading alone');
    expect(lit(tester, 'Middle take 2'), isTrue);
    expect(lit(tester, 'First take 2'), isFalse);

    await tester.tap(find.descendant(of: kiloRow(), matching: find.bySemanticsLabel('Delete recording')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(words.readings('N0DEV', kilo, WordTake.opening), [0, 1], reason: 'a stray tap on the X deletes nothing');

    await tester.tap(find.descendant(of: kiloRow(), matching: find.bySemanticsLabel('Delete recording')).first);
    await tester.pumpAndSettle();
    expect(find.text('Delete this recording of “Kilo”?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(audio.deleted, contains('/v/words/N0DEV/k-i.wav'));
    expect(audio.deleted, isNot(contains('/v/words/N0DEV/k~1-i.wav')));
    expect(audio.deleted, isNot(contains('/v/words/N0DEV/k-m.wav')), reason: "the reading's other takes kept");
    expect(words.readings('N0DEV', kilo, WordTake.opening), [1]);
    expect(words.readings('N0DEV', kilo, WordTake.middle), [0, 1]);
    expect(
      find.descendant(of: kiloRow(), matching: find.bySemanticsLabel('First take 2')),
      findsNothing,
      reason: 'counted by kind, one left',
    );
    expect(find.descendant(of: kiloRow(), matching: find.bySemanticsLabel('First take 1')), findsOneWidget);
  });

  testWidgets('a message tried out lights each take as it is said, and is there again when the pane opens', (tester) async {
    services.cat.keyer('A').voicedWords!.root();
    await tester.runAsync(pumpEventQueue);
    // One reading, so the take each piece is drawn from is known.
    recordKilo([0]);
    await open(tester);
    final tryField = find.widgetWithText(TextField, 'Try saying');
    await tester.enterText(tryField, 'KK');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Listen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // "KK" is Kilo's opening take, then its closing one, 300 ms later and
    // the letters' pause.
    expect(lit(tester, 'First take 1'), isTrue, reason: 'the take being said is lit');
    expect(lit(tester, 'Last take 1'), isFalse);
    await tester.pump(const Duration(milliseconds: 600));
    expect(lit(tester, 'First take 1'), isFalse);
    expect(lit(tester, 'Last take 1'), isTrue, reason: 'the light follows the message');
    audio.listens.last.end();
    await tester.pump();
    expect(lit(tester, 'Last take 1'), isFalse, reason: 'nothing lit once it has been said');

    expect(services.settings.voiceTryText, 'KK', reason: 'what was listened to is kept');
    // Edited and not listened to: closing the pane keeps it too.
    await tester.enterText(tryField, 'K8');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'K8'), findsOneWidget, reason: 'the message tried out is there again');
  });

  // The traps: a reading taken without being heard back — a bad cut kept
  // with no chance to catch it — Space reaching a focused button instead of
  // the dialog, and Backspace leaving the bad takes behind.
  testWidgets('Record All plays each word just read apart, Space takes it and asks for the next, Backspace records it again', (tester) async {
    // Messages from this computer: what records on the desk's microphone.
    await services.settings.setVoiceKeyingSource(VoiceKeyingSource.words);
    services.cat.keyer('A').voicedWords!.root();
    await tester.runAsync(pumpEventQueue);
    final words = services.cat.keyer('A').voicedWords!;
    await open(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Record All'));
    await tester.pumpAndSettle();
    final total = words.promptSlots('N0DEV').length;
    expect(find.text('Set 1: $total of $total still to record'), findsOneWidget);
    // The pane behind the dialog has pills of its own.
    final dialogPills = find.descendant(of: find.byType(HaloDialog), matching: find.byType(VoiceTakePill));

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(words.recordProblem, isNull);
    final prompt = words.recording!.text!;
    expect(find.text(prompt), findsOneWidget, reason: 'the prompt is what is recorded');
    final pieces = words.promptPieces('N0DEV', prompt);
    expect(find.text([for (final p in pieces) voicePromptSpoken(p.word)].join(' ')), findsOneWidget, reason: 'its phonetics below it');

    // The words read run together, a shallow dip between each.
    void read() {
      final reading = <double>[];
      void part(int ms, double? db) {
        for (var i = 0; i < ms * voiceWordRate ~/ 1000; i++) {
          final a = db == null ? 0.0 : math.pow(10, db / 20).toDouble();
          reading.add(a * math.sin(2 * math.pi * 180 * reading.length / voiceWordRate) + ((i * 7919) % 100 - 50) * 4e-6);
        }
      }

      part(300, null);
      for (var i = 0; i < pieces.length; i++) {
        if (i > 0) part(30, -28);
        part(400, -10);
      }
      part(500, null);
      const recordingPath = '/v/words/N0DEV/.reading.wav.recording';
      audio
        ..lengths[recordingPath] = const Duration(seconds: 6)
        ..samples[recordingPath] = Float32List.fromList(reading);
      audio.recordings.last.peak = 0.3;
    }

    read();
    final plays = audio.listens.length;
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(words.splitProblem, isNull);
    final takes = words.lastSaid!.takes;
    expect(takes, hasLength(pieces.length));
    expect(audio.listens.length, plays + 1, reason: 'what was just read plays back at once');
    expect(find.text(prompt), findsOneWidget, reason: 'the prompt waits to be taken or recorded again');
    expect(find.text('Next (Space)'), findsOneWidget);
    final pills = tester.widgetList<VoiceTakePill>(dialogPills).toList();
    expect(pills.map((p) => p.take), takes);
    expect(pills.first.playing, isTrue, reason: 'the first word lit as it plays');
    // Each word about 400 ms, 300 ms apart: a second in, the second plays.
    await tester.pump(const Duration(seconds: 1));
    final lit = [for (final p in tester.widgetList<VoiceTakePill>(dialogPills)) p.playing];
    expect(lit.indexOf(true), 1, reason: 'the light follows the playback, $lit');
    final missing = words.promptSlots('N0DEV').where((slot) => words.keptOf('N0DEV', slot) < 1).length;
    expect(missing, lessThan(total));
    expect(find.text('Set 1: $missing of $total still to record'), findsOneWidget);

    // Backspace: the takes deleted and the same call recording again.
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(words.recording?.text, prompt, reason: 'the same call, recording again');
    expect(find.text('Set 1: $total of $total still to record'), findsOneWidget, reason: 'its takes taken back');

    read();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(words.lastSaid!.takes, hasLength(pieces.length));

    // Space with the Next button focused still goes through the dialog.
    Focus.of(tester.element(find.text('Next (Space)'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(words.recording, isNull, reason: 'taking a reading records nothing');
    expect(find.text('Record (Space)'), findsOneWidget);
    expect(dialogPills, findsNothing);
    expect(find.text('Set 1: $missing of $total still to record'), findsOneWidget, reason: 'the takes kept');
  });

  // The trap: a Delete All that takes the operator's phrases with it, or
  // that goes on one stray tap.
  testWidgets("Delete All takes every recording of the set once confirmed, and keeps the set's phrases", (tester) async {
    services.cat.keyer('A').voicedWords!.root();
    await tester.runAsync(pumpEventQueue);
    final words = recordKilo([0, 1]);
    await services.settings.setVoicePhrases('N0DEV', const [VoicePhrase(id: 'cq', text: 'CQ POTA')]);
    await open(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Delete All'));
    await tester.pumpAndSettle();
    expect(find.text('Delete every recording for N0DEV?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(words.takes('N0DEV', fixedVoiceWords.firstWhere((w) => w.spoken == 'Kilo')), hasLength(6), reason: 'a stray tap deletes nothing');

    await tester.tap(find.widgetWithText(TextButton, 'Delete All'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(words.takes('N0DEV', fixedVoiceWords.firstWhere((w) => w.spoken == 'Kilo')), isEmpty);
    expect(audio.deleted, contains('/v/words/N0DEV'), reason: "the set's directory, and only that set's");
    expect(services.settings.voicePhrases('N0DEV').map((p) => p.text), ['CQ POTA'], reason: 'the phrases stay, to record again');
  });
}

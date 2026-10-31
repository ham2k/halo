// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Record All's prompts (voice_word_prompts.dart). The traps are a place no
// prompt ever reaches — a letter never asked for at the end of a call, so
// the set never completes — a prompt that asks for nothing the set lacks,
// one with a phrase after the call ("AB1C TU", said like neither), one that
// says a character twice ("JJ5L"), and phonetics that read differently from
// what a message will say ("/P" read "stroke papa").

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/voice_word_prompts.dart';
import 'package:ham2k_logger/services/cat/voice_words.dart';

void main() {
  final slots = voicePromptSlots(fixedVoiceWords);

  String spoken(String text) =>
      [for (final piece in planVoicedText(text, recorded: (_) => true).pieces.whereType<WordPiece>()) voicePromptSpoken(piece.word)].join(' ');

  test('the phonetics are what a message says, a suffix as it is said', () {
    expect(spoken('KI2D/P'), 'kilo india two delta portable');
    expect(spoken('KN2X/4'), 'kilo november two x-ray stroke four');
    expect(spoken('AB4D QSL?'), 'alpha bravo four delta QSL?', reason: 'a phrase as written, its question kept');
  });

  test('every letter and digit is asked for in all three places, stroke and a suffix only where they fall', () {
    for (final char in 'ABCXYZ0189'.split('')) {
      final word = fixedVoiceWords.firstWhere((w) => w.key == char.toLowerCase());
      expect([for (final s in slots.where((s) => s.word == word)) s.take], WordTake.values, reason: char);
    }
    expect([for (final s in slots.where((s) => s.word == strokeWord)) s.take], [WordTake.middle]);
    final portable = fixedPhraseWords.firstWhere((w) => w.phrase == '/P');
    expect([for (final s in slots.where((s) => s.word == portable)) s.take], [WordTake.closing]);
    final tu = fixedPhraseWords.firstWhere((w) => w.phrase == 'TU');
    expect(slots.where((s) => s.word == tu), isEmpty, reason: 'a phrase is recorded on its own');
  });

  test('a set is the least any place has, and each prompt fills only places that set lacks', () {
    // The first set done but for Kilo opening a call and Two closing one.
    final kilo = fixedVoiceWords.firstWhere((w) => w.key == 'k');
    final two = fixedVoiceWords.firstWhere((w) => w.key == '2');
    int kept(VoiceWordSlot slot) => (slot.word == kilo && slot.take == WordTake.opening) || (slot.word == two && slot.take == WordTake.closing) ? 0 : 1;
    expect(voicePromptSet(slots, kept, most: 5), 1);
    final random = math.Random(3);
    var reached = 0;
    for (var i = 0; i < 20; i++) {
      final prompt = nextVoicePrompt(words: fixedVoiceWords, phrases: const [], kept: kept, set: 1, random: random)!;
      final pieces = planVoicedText(prompt, recorded: (_) => true).pieces.whereType<WordPiece>().map(voicePieceSlot);
      if (pieces.contains((word: kilo, take: WordTake.opening)) || pieces.contains((word: two, take: WordTake.closing))) reached++;
    }
    expect(reached, 20, reason: 'every prompt reaches a missing place while there is one');
    expect(voicePromptSet(slots, (_) => 5, most: 5), isNull, reason: 'five of everything is all there is');
  });

  test('every place is reached, set after set', () {
    // Prompts read and kept until the first set completes: a place no
    // prompt can reach keeps it from ever completing.
    final counts = <VoiceWordSlot, int>{};
    final random = math.Random(1);
    int kept(VoiceWordSlot slot) => counts[slot] ?? 0;
    var prompts = 0;
    while (voicePromptSet(slots, kept, most: 5) == 1 && prompts < 400) {
      final prompt = nextVoicePrompt(words: fixedVoiceWords, phrases: const [], kept: kept, set: 1, random: random)!;
      expect(prompt, matches(RegExp(r'^[A-Z0-9]{4}(/[A-Z0-9])?$')), reason: 'one call, at times a suffix');
      final call = prompt.substring(0, 4);
      expect(call.split('').toSet(), hasLength(4), reason: '$prompt says a character twice');
      for (final piece in planVoicedText(prompt, recorded: (_) => true).pieces.whereType<WordPiece>()) {
        final slot = voicePieceSlot(piece);
        counts[slot] = kept(slot) + 1;
      }
      prompts++;
    }
    expect(voicePromptSet(slots, kept, most: 5), 2, reason: 'the first set completed in $prompts prompts');
    expect(prompts, lessThan(slots.length ~/ 2), reason: 'each prompt fills several places, $prompts prompts for ${slots.length}');
  });

  test('a word with no take to measure is guessed at about its length', () {
    final golf = fixedVoiceWords.firstWhere((w) => w.key == 'g');
    final november = fixedVoiceWords.firstWhere((w) => w.key == 'n');
    final qrz = fixedPhraseWords.firstWhere((w) => w.phrase == 'QRZ');
    expect(voiceWordLengthGuess(golf), lessThan(voiceWordLengthGuess(november)));
    expect(voiceWordLengthGuess(november) / voiceWordLengthGuess(golf), lessThan(2), reason: 'a syllable adds less than a word');
    expect(voiceWordLengthGuess(qrz), greaterThan(voiceWordLengthGuess(golf)), reason: 'QRZ is said letter by letter');
  });
}

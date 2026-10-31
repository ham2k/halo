// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Record All (docs/design/cat.md § Voiced words): calls for the operator to
// read as on the air, chosen so each reading fills places in their word set
// still missing — every letter and digit opening a call, inside one and
// closing it — set after set. Pure functions, so what is
// asked for is tested without a recorder.

import 'dart:math' as math;

import 'voice_words.dart';

/// A place a word is said in: a word recorded once has the one.
typedef VoiceWordSlot = ({VoiceWord word, WordTake take});

/// Every place Record All asks for in a set with [words]: each letter and
/// digit opening a call, inside one and closing it; "stroke" inside a call,
/// where it is always said; and a slashed suffix ("/P") closing one, where
/// it always is. Phrases are recorded on their own: a "TU" or a "QRP" read
/// after a call is said nothing like either.
List<VoiceWordSlot> voicePromptSlots(List<VoiceWord> words) => [
  for (final word in words)
    if (word.phrase == null || word.phrase!.startsWith('/'))
      for (final take in word.saidIn) (word: word, take: take),
];

/// The place [piece] fills.
VoiceWordSlot voicePieceSlot(WordPiece piece) => (word: piece.word, take: piece.word.once ? WordTake.middle : piece.take);

/// What the operator says for [word] as a prompt shows it: the phonetic in
/// lower case, a slashed suffix as said ("portable"), a phrase as written.
String voicePromptSpoken(VoiceWord word) => switch (word.phrase) {
  null => word.spoken.toLowerCase(),
  '/P' => 'portable',
  '/M' => 'mobile',
  final phrase => phrase,
};

/// About how long [word] is said, in milliseconds, for a word with no take
/// to measure: most are 350-550 ms whatever their syllables, so a syllable
/// adds less than a word does. Letters written with no vowel ("QRZ") are
/// said letter by letter.
double voiceWordLengthGuess(VoiceWord word) {
  var syllables = 0;
  for (final token in voicePromptSpoken(word).split(RegExp(r'[\s-]+'))) {
    final letters = token.replaceAll(RegExp('[^A-Za-z]'), '');
    if (letters.isEmpty) continue;
    final vowels = RegExp('[aeiouy]+', caseSensitive: false).allMatches(letters.replaceAll(RegExp(r'e$'), '')).length;
    syllables += vowels == 0 ? letters.length : vowels;
  }
  return 300 + 80 * math.max(1, syllables).toDouble();
}

/// The set Record All is collecting: 1 while any place has nothing, 2 while
/// any has only one, and so on — null once every place has [most].
int? voicePromptSet(List<VoiceWordSlot> slots, int Function(VoiceWordSlot slot) kept, {required int most}) {
  if (slots.isEmpty) return null;
  final least = slots.map(kept).reduce(math.min);
  return least >= most ? null : least + 1;
}

const _letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const _digits = '0123456789';

/// The next call for the operator to read ("AB1C"), at times with a
/// suffix ("AB1C/P", "AB1C/4"), filling places [set] still lacks. Never a
/// character twice in one call — "JJ5L" is no fun to say — and drawn from
/// the better few of a handful rather than the one best, so calls vary at
/// the price of a few readings more. Null with none lacking.
String? nextVoicePrompt({
  required List<VoiceWord> words,
  required List<VoicePhrase> phrases,
  required int Function(VoiceWordSlot slot) kept,
  required int set,
  required math.Random random,
}) {
  final slots = voicePromptSlots(words);
  final missing = [
    for (final slot in slots)
      if (kept(slot) < set) slot,
  ];
  if (missing.isEmpty) return null;
  // What is said is what the planner makes of the text — the takes are cut
  // as a message would say it — so a candidate is scored by its plan.
  int score(String text) {
    final plan = planVoicedText(text, phrases: phrases, recorded: (_) => true);
    var filled = 0;
    for (final piece in plan.pieces.whereType<WordPiece>()) {
      if (kept(voicePieceSlot(piece)) < set) filled++;
    }
    return filled;
  }

  final candidates = [
    for (var i = 0; i < 12; i++)
      if (_candidate(missing, random) case final text) (text: text, score: score(text)),
  ];
  final best = candidates.map((c) => c.score).reduce(math.max);
  final good = [
    for (final c in candidates)
      if (c.score >= best - 1 && c.score > 0) c.text,
  ];
  return good.isEmpty ? candidates.first.text : good[random.nextInt(good.length)];
}

/// A call built around places [missing] lacks — a missing opening letter or
/// digit first, a closing one last, inside ones between — no character in
/// it twice, one or two digits as a call has; with a suffix, at times,
/// where one is missing.
String _candidate(List<VoiceWordSlot> missing, math.Random random) {
  final call = <String>[];
  bool fits(String c) => !call.contains(c) && (!_digits.contains(c) || call.where(_digits.contains).length < 2);
  String? pick(WordTake take) {
    final chars = [
      for (final slot in missing)
        if (slot.word.phrase == null && slot.word != strokeWord && slot.take == take) slot.word.key.toUpperCase(),
    ].where(fits).toList();
    return chars.isEmpty ? null : chars[random.nextInt(chars.length)];
  }

  String any() {
    while (true) {
      final c = random.nextInt(3) == 0 ? _digits[random.nextInt(_digits.length)] : _letters[random.nextInt(_letters.length)];
      if (fits(c)) return c;
    }
  }

  for (final take in const [WordTake.opening, WordTake.middle, WordTake.middle, WordTake.closing]) {
    call.add(pick(take) ?? any());
  }
  T draw<T>(List<T> from) => from[random.nextInt(from.length)];
  // A call has a digit: without one it is spelled, a part the planner reads
  // the same, but not what a call sounds like. [fits] keeps a letter in it.
  if (!call.any(_digits.contains)) call[1 + random.nextInt(2)] = draw(_digits.split('').where((d) => !call.contains(d)).toList());
  var text = call.join();

  final suffixes = [
    for (final slot in missing)
      if (slot.word == strokeWord)
        '/${draw(_digits.split('').where((d) => !call.contains(d)).toList())}'
      else if (slot.word.phrase case final phrase? when phrase.startsWith('/'))
        phrase,
  ];
  if (suffixes.isNotEmpty && random.nextInt(3) == 0) text += suffixes[random.nextInt(suffixes.length)];
  return text;
}

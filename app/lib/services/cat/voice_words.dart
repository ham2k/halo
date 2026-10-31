// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Voiced words (docs/design/cat.md § Voiced words): a phone message's text
// spoken from the operator's own recordings of each letter, digit and phrase.
// Each word is recorded read three times run together ("Kilo kilo kilo"), and
// kept as three takes — opening, middle and closing — because a word sounds
// different where it falls: the closing one drops, and is what makes a call
// end like a call rather than a list. A phrase of several words is
// recorded once, as said: it carries its own rise and fall. Pure functions on samples, so the
// splitting and joining are tested without a sound device.

import 'dart:math' as math;
import 'dart:typed_data';

/// Every recording and take is mono at this rate: the recorder's own
/// (halo_audio records 48 kHz mono), and what a message is joined at.
const voiceWordRate = 48000;

/// Where a take of a word is used: the first word of a part, a word inside
/// it, or the last — and its file's suffix.
enum WordTake {
  opening('i'),
  middle('m'),
  closing('f');

  const WordTake(this.suffix);
  final String suffix;
}

/// One thing the operator records: a letter, a digit, "stroke", or a
/// phrase of their own. [key] names its files; [spoken] is what the
/// operator is asked to say.
class VoiceWord {
  final String key;
  final String spoken;

  /// The text a phrase stands for in a message, upper case, its punctuation
  /// as written — null for the fixed vocabulary, which is spelled character
  /// by character.
  final String? phrase;

  const VoiceWord(this.key, this.spoken, {this.phrase});

  /// Whether it is recorded once rather than as three takes: a phrase of
  /// several words, whose own rise and fall is the take for every place.
  bool get once => phrase?.contains(' ') ?? false;

  @override
  bool operator ==(Object other) => other is VoiceWord && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'VoiceWord($key)';
}

/// The ITU phonetics. What the operator says for each is theirs — the label
/// is only the prompt.
const _phonetics = {
  'A': 'Alpha', 'B': 'Bravo', 'C': 'Charlie', 'D': 'Delta', 'E': 'Echo', 'F': 'Foxtrot', 'G': 'Golf', //
  'H': 'Hotel', 'I': 'India', 'J': 'Juliett', 'K': 'Kilo', 'L': 'Lima', 'M': 'Mike', 'N': 'November', //
  'O': 'Oscar', 'P': 'Papa', 'Q': 'Quebec', 'R': 'Romeo', 'S': 'Sierra', 'T': 'Tango', 'U': 'Uniform', //
  'V': 'Victor', 'W': 'Whiskey', 'X': 'X-ray', 'Y': 'Yankee', 'Z': 'Zulu', //
  '0': 'Zero', '1': 'One', '2': 'Two', '3': 'Three', '4': 'Four', //
  '5': 'Five', '6': 'Six', '7': 'Seven', '8': 'Eight', '9': 'Nine', //
};

/// The words every word set has, in the order they are read.
final fixedVoiceWords = [for (final MapEntry(:key, :value) in _phonetics.entries) VoiceWord(key.toLowerCase(), value), strokeWord, ...fixedPhraseWords];

/// Phrases every word set has: the portable and mobile suffixes, and the
/// Q-codes and abbreviations a phone contact uses most. Unlike the
/// operator's own, one not recorded is spelled rather than refused — they
/// are there whether or not the operator says them.
final fixedPhraseWords = [
  for (final text in const ['/P', '/M', 'QSL', 'QSL?', 'QRZ', 'TU', 'QRP'])
    VoiceWord(text.toLowerCase().replaceAll('/', 'slash-').replaceAll('?', '-q'), text, phrase: text),
];

const strokeWord = VoiceWord('stroke', 'Stroke');

VoiceWord? _spelled(String char) => switch (_phonetics[char]) {
  final spoken? => VoiceWord(char.toLowerCase(), spoken),
  null => char == '/' ? strokeWord : null,
};

/// A phrase the operator added to their word set: [id] names its files, so
/// editing the text keeps the recording.
class VoicePhrase {
  final String id;
  final String text;

  const VoicePhrase({required this.id, required this.text});

  /// Its words as a message's are read: a lone dash or comma is no word.
  VoiceWord get word => VoiceWord('p-$id', text, phrase: _tokens(text).where((token) => _stripped(token).isNotEmpty).join(' '));

  static VoicePhrase? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], text = json['text'];
    if (id is! String || id.isEmpty || text is! String || !_tokens(text).any((token) => _stripped(token).isNotEmpty)) return null;
    return VoicePhrase(id: id, text: text);
  }

  Map<String, dynamic> toJson() => {'id': id, 'text': text};
}

/// [text]'s words, upper case, as written.
List<String> _tokens(String text) => [
  for (final token in text.toUpperCase().split(RegExp(r'\s+')))
    if (token.isNotEmpty) token,
];

/// [token] with the punctuation around it gone — a comma or a question mark
/// is how a message is written, not something said. Only punctuation: a
/// character nothing spells (`#`, `Ö`) stays, to be named rather than left
/// out of the message without a word.
String _stripped(String token) => token.replaceAll(RegExp(r'''^[.,;:!?'"()\[\]-]+|[.,;:!?'"()\[\]-]+$'''), '');

/// What `{{ phone.msgN }}` is replaced with before a template is rendered:
/// message N's own recording, which the renderer passes through as text. A
/// character no message is written with, so nothing typed is taken for one.
String voicedMessageMark(int n) => '$n';
final _messageMark = RegExp('([1-9])');

/// `{{ phone.msgN }}` as a template writes it, with the spacing Liquid allows.
final voicedMessageTag = RegExp(r'\{\{\s*phone\.msg([1-9])\s*\}\}');

/// [template] with every `{{ phone.msgN }}` turned into its mark, ready to
/// render: the renderer knows nothing of phone messages, and need not.
String markVoicedMessages(String template) => template.replaceAllMapped(voicedMessageTag, (m) => voicedMessageMark(int.parse(m[1]!)));

/// One step of a voiced message: a take of a word, or a message's whole
/// recording, with how far after the previous step it starts — negative to
/// overlap its tail.
sealed class VoicedPiece {
  final Duration gap;

  /// Whether it begins a part of the message — a call, a report, a phrase —
  /// rather than continuing one.
  final bool startsPart;

  const VoicedPiece(this.gap, {this.startsPart = false});
}

class WordPiece extends VoicedPiece {
  final VoiceWord word;
  final WordTake take;
  const WordPiece(this.word, this.take, super.gap, {super.startsPart});

  @override
  String toString() => '${word.spoken}${take == WordTake.middle ? '' : '(${take.suffix})'}';
}

class RecordingPiece extends VoicedPiece {
  final int message;
  const RecordingPiece(this.message, super.gap, {super.startsPart});

  @override
  String toString() => '[message $message]';
}

/// How a message's words are laid down, the operator's to set per word set:
/// how far apart, and how fast each is said. The defaults sound like a call:
/// letters in a group run into each other, the parts of a message ("K8AB /
/// 59 / 7") are a short breath apart. Longer, and a call sounds read from a
/// list.
class VoicedPacing {
  /// Between the letters and digits of a group ("K8", "AB", "59") — negative
  /// to overlap the tail of the one before.
  final Duration letters;

  /// Between the parts of a message: a call, a report, a phrase.
  final Duration words;

  /// How much faster than recorded each word is said, at its own pitch —
  /// 1 as recorded.
  final double speed;

  const VoicedPacing({this.letters = defaultLetters, this.words = defaultWords, this.speed = 1});

  VoicedPacing copyWith({Duration? letters, Duration? words, double? speed}) =>
      VoicedPacing(letters: letters ?? this.letters, words: words ?? this.words, speed: speed ?? this.speed);

  static const defaultLetters = Duration(milliseconds: -40);
  static const defaultWords = Duration(milliseconds: 150);

  /// What each may be set to, in milliseconds.
  static const lettersRange = (min: -100, max: 100);
  static const wordsRange = (min: 0, max: 200);
  static const speedRange = (min: 0.5, max: 1.5);

  /// Between a call's prefix and suffix: a beat longer than between letters,
  /// so "K8 AB" is heard as two halves of one call.
  Duration get groups => letters + const Duration(milliseconds: 80);

  /// Before "stroke" or a slashed suffix ("/P"), a little longer again.
  Duration get stroke => letters + const Duration(milliseconds: 120);

  static VoicedPacing fromJson(Object? json) {
    Duration? ms(Object? v, ({int min, int max}) range) => v is int ? Duration(milliseconds: v.clamp(range.min, range.max)) : null;
    if (json is! Map) return const VoicedPacing();
    final speed = json['speed'];
    return VoicedPacing(
      letters: ms(json['letters'], lettersRange) ?? defaultLetters,
      words: ms(json['words'], wordsRange) ?? defaultWords,
      speed: speed is num ? speed.toDouble().clamp(speedRange.min, speedRange.max) : 1,
    );
  }

  Map<String, dynamic> toJson() => {'letters': letters.inMilliseconds, 'words': words.inMilliseconds, 'speed': speed};
}

/// A message's text as the words that say it, and what it needs that is not
/// there: characters nothing spells, and words with no recording.
class VoicedPlan {
  final List<VoicedPiece> pieces;

  /// Characters no word spells (a `#`, an accented letter), in order, once each.
  final List<String> unspeakable;

  /// Words the message needs and the word set has not recorded, in order, once each.
  final List<VoiceWord> unrecorded;

  /// Where each piece is written in the planned text, start to end, beside
  /// [pieces] — empty for a plan made from no text.
  final List<(int, int)> spans;

  const VoicedPlan(this.pieces, {this.unspeakable = const [], this.unrecorded = const [], this.spans = const []});

  bool get speakable => unspeakable.isEmpty && unrecorded.isEmpty && pieces.isNotEmpty;

  /// Each piece with its take marked where it is not the middle one —
  /// "Kilo(i) Eight Alpha Bravo(f) Five(i) Nine(f)" — for tests and logs.
  /// What the operator reads is the dialog's spokenText.
  String describe() => pieces.map((p) => p.toString()).join(' ');
}

/// Plans [text] — a rendered message — from [phrases] and the fixed words,
/// [recorded] saying whether a word's takes are there.
///
/// Phrases are matched first, longest first, on whole words, so "CQ POTA"
/// is said as recorded rather than spelled — and never inside a word: KI2TU
/// is a call, not "KI2" and "TU". A phrase written with its
/// punctuation is a recording of its own ("QRZ?" is asked, "QRZ" is not) and
/// matches only as written; one without matches whatever punctuation the
/// message puts around it, where no phrase matches as written. Each word
/// left is a part of its own: one with a digit and a letter is a call, said
/// as its prefix and suffix with "stroke" before what follows a slash, and
/// anything else is spelled. A call's last slash part is a slashed phrase
/// where there is one ("/P" is "portable", as the operator says it), and
/// "stroke" and its letters where there is not. A part starts on an opening
/// take and ends on a closing one; a part of one word takes the opening take
/// first in the message, the closing take last, and the middle one between,
/// so a phrase or a digit inside a message neither starts nor ends it.
/// [pacing] lays them down.
VoicedPlan planVoicedText(
  String text, {
  List<VoicePhrase> phrases = const [],
  VoicedPacing pacing = const VoicedPacing(),
  required bool Function(VoiceWord word) recorded,
}) {
  // The operator's own first, so one of theirs wins over a fixed phrase of
  // the same text. The index breaks ties: List.sort is not stable.
  final candidates = [
    for (final phrase in phrases) phrase.word,
    for (final word in fixedPhraseWords)
      if (recorded(word)) word,
  ];
  final phraseWords = [for (final (i, word) in candidates.indexed) (word: word, words: word.phrase!.split(' '), order: i)]
    ..sort((a, b) => b.words.length != a.words.length ? b.words.length.compareTo(a.words.length) : a.order.compareTo(b.order));
  final slashed = <String, VoiceWord>{};
  for (final p in phraseWords) {
    if (p.words.length == 1 && p.words.single.startsWith('/')) slashed.putIfAbsent(p.words.single, () => p.word);
  }
  final parts = <List<List<Object>>>[]; // part -> groups -> VoiceWord | int (a message) | String (unspeakable)
  final partSpans = <List<(int, int)>>[]; // part -> where each of its items is written
  // split() leaves the marks out: each segment after the first follows one.
  final marks = _messageMark.allMatches(text).toList();
  for (final (i, segment) in text.split(_messageMark).indexed) {
    final offset = i == 0 ? 0 : marks[i - 1].end;
    if (i > 0) {
      parts.add([
        [int.parse(marks[i - 1][1]!)],
      ]);
      partSpans.add([(marks[i - 1].start, marks[i - 1].end)]);
    }
    // Each token's word as written, punctuation off, where it is in [text].
    final written = [
      for (final match in RegExp(r'\S+').allMatches(segment))
        if (_stripped(match[0]!.toUpperCase()) case final word when word.isNotEmpty)
          (token: match[0]!.toUpperCase(), start: offset + match.start + match[0]!.toUpperCase().indexOf(word), word: word),
    ];
    final tokens = [for (final w in written) w.token];
    for (var w = 0; w < tokens.length;) {
      ({VoiceWord word, List<String> words, int order})? match;
      var matchExact = -1;
      for (final p in phraseWords) {
        if (match != null && p.words.length < match.words.length) break;
        final exact = _phraseAt(tokens, w, p.words);
        if (exact > matchExact) (match, matchExact) = (p, exact);
      }
      if (match != null) {
        parts.add([
          [match.word],
        ]);
        final last = written[w + match.words.length - 1];
        partSpans.add([(written[w].start, last.start + last.word.length)]);
        w += match.words.length;
        continue;
      }
      final part = _partOf(_stripped(tokens[w]), slashed);
      parts.add(part);
      partSpans.add(_itemSpans(written[w].word, written[w].start, [for (final group in part) ...group], slashed));
      w++;
    }
  }

  final pieces = <VoicedPiece>[];
  final spans = <(int, int)>[];
  final unspeakable = <String>[];
  final unrecorded = <VoiceWord>[];
  for (final (p, groups) in parts.indexed) {
    final flat = [for (final group in groups) ...group];
    var index = 0;
    for (final (g, group) in groups.indexed) {
      for (final (w, item) in group.indexed) {
        final gap = pieces.isEmpty
            ? Duration.zero
            : g == 0 && w == 0
            ? pacing.words
            : w == 0
            ? (item == strokeWord || (item is VoiceWord && slashed.containsValue(item)) ? pacing.stroke : pacing.groups)
            : pacing.letters;
        final startsPart = g == 0 && w == 0;
        final take = flat.length == 1
            ? (p == parts.length - 1
                  ? WordTake.closing
                  : p == 0
                  ? WordTake.opening
                  : WordTake.middle)
            : index == 0
            ? WordTake.opening
            : index == flat.length - 1
            ? WordTake.closing
            : WordTake.middle;
        switch (item) {
          case final VoiceWord word:
            if (!recorded(word) && !unrecorded.contains(word)) unrecorded.add(word);
            pieces.add(WordPiece(word, take, gap, startsPart: startsPart));
            spans.add(partSpans[p][index]);
          case final int message:
            pieces.add(RecordingPiece(message, gap, startsPart: startsPart));
            spans.add(partSpans[p][index]);
          case final String char:
            if (!unspeakable.contains(char)) unspeakable.add(char);
        }
        index++;
      }
    }
  }
  return VoicedPlan(pieces, unspeakable: unspeakable, unrecorded: unrecorded, spans: spans);
}

/// Where each of [items] — [_partOf]'s for [word], written at [start] — is
/// in the text: a letter its character, "stroke" its slash, a slashed
/// phrase its slash and what follows.
List<(int, int)> _itemSpans(String word, int start, List<Object> items, Map<String, VoiceWord> slashed) {
  final out = <(int, int)>[];
  var at = 0;
  for (final item in items) {
    if (item == strokeWord || (item is VoiceWord && slashed.containsValue(item))) {
      final slash = word.indexOf('/', at);
      final from = slash < 0 ? at : slash;
      final next = item == strokeWord ? from + 1 : word.indexOf('/', from + 1);
      final to = next < 0 ? word.length : next;
      out.add((start + from, start + to));
      at = to;
    } else {
      while (at < word.length && word[at] == '/') {
        at++;
      }
      out.add((start + at, start + math.min(at + 1, word.length)));
      at++;
    }
  }
  return out;
}

/// What [plan], made from [text], shows as it plays: [text] with its
/// spacing evened and each recorded message's mark as [messageName] calls
/// it, and for each piece the moment it starts — from [starts], in samples
/// ([joinVoicedPlan]) — with how much of that text has been said once it
/// has. Null when the plan does not say where its pieces are written.
({String text, List<({int atMs, int said})> marks})? voicedScript(String text, VoicedPlan plan, List<int> starts, String Function(int n) messageName) {
  if (plan.spans.length != plan.pieces.length || starts.length != plan.pieces.length) return null;
  // The spans are where pieces are in the text upper-cased. On the web that
  // is JavaScript's upper case, where "ß" is "SS": a character whose upper
  // case is longer puts every span after it past where it is written.
  if (text.toUpperCase().length != text.length) return null;
  final shown = StringBuffer();
  final endAt = List<int>.filled(text.length, 0);
  var space = false;
  for (var i = 0; i < text.length;) {
    final mark = _messageMark.matchAsPrefix(text, i);
    final unit = mark?[0] ?? text[i];
    if (mark == null && unit.trim().isEmpty) {
      space = true;
      endAt[i++] = shown.length;
      continue;
    }
    if (space && shown.isNotEmpty) shown.write(' ');
    space = false;
    shown.write(mark == null ? unit : messageName(int.parse(mark[1]!)));
    for (var k = 0; k < unit.length; k++) {
      endAt[i++] = shown.length;
    }
  }
  return (
    text: shown.toString(),
    marks: [for (final (k, span) in plan.spans.indexed) (atMs: starts[k] * 1000 ~/ voiceWordRate, said: span.$2 > 0 ? endAt[span.$2 - 1] : 0)],
  );
}

/// Whether [phrase] is said by [tokens] from [from]: -1 when it is not,
/// else how many of its words are written there exactly as in the phrase.
int _phraseAt(List<String> tokens, int from, List<String> phrase) {
  if (from + phrase.length > tokens.length) return -1;
  var exact = 0;
  for (final (i, word) in phrase.indexed) {
    final token = tokens[from + i];
    if (token == word) {
      exact++;
    } else if (word != _stripped(word) || _stripped(token) != word) {
      return -1;
    }
  }
  return exact;
}

/// One word of a message as its groups. A call ("K8AB", "N9CW/P",
/// "VE3/K8AB") is its prefix through the last digit before the suffix, the
/// suffix, then "stroke" and whatever follows each slash; anything else is
/// one group, spelled. A last slash part [slashed] has a phrase for is that
/// phrase, in place of "stroke" and its letters.
List<List<Object>> _partOf(String word, Map<String, VoiceWord> slashed) {
  Object spell(String char) => _spelled(char) ?? char;
  final pieces = word.split('/');
  final isCall = RegExp('[A-Z]').hasMatch(word) && RegExp('[0-9]').hasMatch(word);
  if (!isCall) return [word.split('').map(spell).toList()];
  // The base is the part with the call's digit in it; any other slash part
  // is said after a stroke, prefixes included ("VE3 stroke K8AB" reads the
  // way it is written).
  final groups = <List<Object>>[];
  for (final (i, piece) in pieces.indexed) {
    if (piece.isEmpty) continue;
    final group = <Object>[if (i > 0) strokeWord];
    final lastDigit = piece.lastIndexOf(RegExp('[0-9]'));
    final suffix = i > 0 && i == pieces.length - 1 ? slashed['/$piece'] : null;
    if (suffix != null) {
      groups.add([suffix]);
    } else if (lastDigit >= 0 && lastDigit < piece.length - 1) {
      groups.add([...group, ...piece.substring(0, lastDigit + 1).split('').map(spell)]);
      groups.add(piece.substring(lastDigit + 1).split('').map(spell).toList());
    } else {
      groups.add([...group, ...piece.split('').map(spell)]);
    }
  }
  return groups;
}

// --- Audio ---

const _frame = voiceWordRate ~/ 100; // 10 ms

/// Each 10 ms frame's level in dB.
List<double> _envelope(Float32List s) {
  final out = <double>[];
  for (var start = 0; start + _frame <= s.length; start += _frame) {
    var sum = 0.0;
    for (var i = start; i < start + _frame; i++) {
      sum += s[i] * s[i];
    }
    out.add(10 * math.log(math.max(sum / _frame, 1e-18)) / math.ln10);
  }
  return out;
}

/// Where a word ends: where it has fallen [belowPeakDb] under its own peak,
/// then faded out over [fade]. A word read on its own decays long after it
/// is said; inside a call the next word cuts it off, and kept it drags. Much
/// shallower than 20 dB and the cut takes real endings — the "t" of Eight
/// and the "x" of Six sit 12-20 dB under the vowel.
Float32List cutWordTail(Float32List s, {double belowPeakDb = 20, Duration fade = const Duration(milliseconds: 30)}) {
  final env = _envelope(s);
  if (env.isEmpty) return s;
  final peak = env.reduce(math.max);
  var last = env.length - 1;
  while (last > 0 && env[last] <= peak - belowPeakDb) {
    last--;
  }
  final end = (last + 1) * _frame;
  final fadeSamples = fade.inMicroseconds * voiceWordRate ~/ 1000000;
  final kept = Float32List.fromList(s.sublist(0, math.min(s.length, end + fadeSamples)));
  for (var i = end; i < kept.length; i++) {
    kept[i] *= 1 - (i - end) / fadeSamples;
  }
  return kept;
}

/// [s] faded in and out over [length], so a cut never clicks.
Float32List _fadeEdges(Float32List s, {Duration length = const Duration(milliseconds: 5)}) {
  final n = math.min(s.length ~/ 2, length.inMicroseconds * voiceWordRate ~/ 1000000);
  for (var i = 0; i < n; i++) {
    final g = i / n;
    s[i] *= g;
    s[s.length - 1 - i] *= g;
  }
  return s;
}

/// [s] said [speed] times as fast, at its own pitch: WSOLA — 20 ms Hann
/// frames at half overlap, each taken from within 5 ms of where it falls
/// where it best continues the one before. Resampling instead would raise
/// the voice with the speed.
Float32List changeTempo(Float32List s, double speed) {
  if (speed == 1 || s.isEmpty) return s;
  const n = 960, hop = n ~/ 2, tolerance = 240, stride = 8;
  final window = [for (var i = 0; i < n; i++) 0.5 - 0.5 * math.cos(2 * math.pi * i / n)];
  final source = Float32List(s.length + 2 * n + tolerance)..setAll(0, s);
  final length = (s.length / speed).floor();
  final out = Float32List(length + 2 * n);
  var previous = 0;
  for (var k = 0; (k * hop * speed).floor() + n + tolerance < source.length - n && k * hop + n <= out.length; k++) {
    final nominal = (k * hop * speed).floor();
    var at = 0;
    if (k > 0) {
      final target = previous + hop;
      var best = double.negativeInfinity;
      for (var p = math.max(0, nominal - tolerance); p <= nominal + tolerance; p += stride) {
        var sum = 0.0;
        for (var i = 0; i < n; i += stride) {
          sum += source[p + i] * source[target + i];
        }
        if (sum > best) (best, at) = (sum, p);
      }
    }
    for (var i = 0; i < n; i++) {
      out[k * hop + i] += source[at + i] * window[i];
    }
    previous = at;
  }
  return Float32List.sublistView(out, 0, length);
}

/// [plan] as one recording, each piece's samples from [load] — a word's take
/// with its tail cut and at [speed], a message's recording as it is — laid
/// down at its gap, a negative one overlapping the piece before.
///
/// [starts], given, gets the sample each piece starts at.
Float32List joinVoicedPlan(VoicedPlan plan, Float32List Function(VoicedPiece piece) load, {double speed = 1, List<int>? starts}) {
  final pieces = [
    for (final piece in plan.pieces)
      (
        gap: piece.gap.inMicroseconds * voiceWordRate ~/ 1000000,
        samples: piece is WordPiece ? _fadeEdges(changeTempo(cutWordTail(load(piece)), speed)) : load(piece),
      ),
  ];
  var length = 0;
  for (final piece in pieces) {
    length = math.max(0, length + piece.gap) + piece.samples.length;
  }
  final out = Float32List(length);
  var at = 0;
  for (final piece in pieces) {
    at = math.max(0, at + piece.gap);
    starts?.add(at);
    for (var i = 0; i < piece.samples.length; i++) {
      out[at + i] += piece.samples[i];
    }
    at += piece.samples.length;
  }
  for (var i = 0; i < out.length; i++) {
    out[i] = out[i].clamp(-1.0, 1.0);
  }
  return out;
}

// --- Splitting a recording into takes ---

/// Why a recording could not be split into its words' takes.
enum VoiceWordSplitProblem {
  /// Nothing loud enough to be a voice.
  silent,

  /// Not three words to be found in it — said once, or twice.
  notThreeTakes,

  /// A reading of every word does not come apart into as many lines as
  /// there are words.
  lineCount,

  /// A reading's lines are not clearly apart: a pause inside a line is as
  /// long as the pauses between them.
  linesTooClose,
}

class VoiceWordSplitException implements Exception {
  final VoiceWordSplitProblem problem;
  const VoiceWordSplitException(this.problem);

  @override
  String toString() => 'VoiceWordSplitException(${problem.name})';
}

/// The levels a recording is read against: speech is [voiced] and above,
/// [quiet] is where a take's edges are trimmed to.
({double voiced, double quiet}) _levels(List<double> env) {
  final sorted = [...env]..sort();
  final floor = sorted[sorted.length ~/ 10];
  final peak = sorted.last;
  // Clear of the room: a recorder settling sits a few dB under a line set
  // 12 dB over the floor. Never within 20 dB of the peak, though — a
  // recording trimmed close to the voice has no room left to measure.
  final voiced = math.min(math.max(floor + 20, peak - 35), peak - 20);
  return (voiced: voiced, quiet: voiced - 6);
}

typedef _Run = (int start, int end);

List<_Run> _runs(List<double> env, bool Function(double level) on) {
  final out = <_Run>[];
  int? start;
  for (var i = 0; i <= env.length; i++) {
    final isOn = i < env.length && on(env[i]);
    if (isOn && start == null) start = i;
    if (!isOn && start != null) {
      out.add((start, i));
      start = null;
    }
  }
  return out;
}

/// Runs of speech joined across a pause shorter than [join] frames — a stop
/// inside a word ("Whis-key") — and with runs under [shortest] frames
/// dropped as clicks.
List<_Run> _spoken(List<double> env, double voiced, {int join = 20, int shortest = 15}) {
  final out = <_Run>[];
  for (final (a, b) in _runs(env, (v) => v > voiced)) {
    if (out.isNotEmpty && a - out.last.$2 < join) {
      out.last = (out.last.$1, b);
    } else {
      out.add((a, b));
    }
  }
  return [
    for (final run in out)
      if (run.$2 - run.$1 >= shortest) run,
  ];
}

/// The three takes of one line read run together, frames [a]..[b]: the pair
/// of dips that splits it most evenly, deeper dips breaking near-ties. The
/// three takes are one word, so about one length — where a pause's length
/// alone takes the stop inside a word ("sk" in Whiskey) for the gap
/// between two.
List<_Run>? _splitLine(List<double> env, int a, int b, {required int limit}) {
  final n = b - a;
  if (n < 9) return null;
  final smooth = [
    for (var i = a; i < b; i++)
      [for (var j = math.max(a, i - 1); j < math.min(b, i + 2); j++) env[j]].reduce((x, y) => x + y) / (math.min(b, i + 2) - math.max(a, i - 1)),
  ];
  final top = smooth.reduce(math.max);
  final dips = [
    for (var i = (n * 0.15).floor(); i < (n * 0.85).floor(); i++)
      if (i > 0 && i < n - 1 && smooth[i] < top - 6 && smooth[i] <= smooth[i - 1] && smooth[i] <= smooth[i + 1]) i,
  ];
  (double, int, int)? best;
  for (var x = 0; x < dips.length; x++) {
    for (var y = x + 1; y < dips.length; y++) {
      final c1 = dips[x], c2 = dips[y];
      final lengths = [c1, c2 - c1, n - c2];
      final spread = (lengths.reduce(math.max) - lengths.reduce(math.min)) / (n / 3);
      final score = spread + (smooth[c1] + smooth[c2] - 2 * top) / 100;
      if (best == null || score < best.$1) best = (score, c1, c2);
    }
  }
  if (best == null) return null;
  return [(a, a + best.$2), (a + best.$2, a + best.$3), (a + best.$3, math.min(limit, b + 30))];
}

/// The three takes of one word read run together ("Kilo kilo kilo"), as
/// sample ranges in [s]. Read with a pause after each, the three are found
/// by the pauses instead.
List<(int, int)> splitWordTakes(Float32List s) => splitReading(s, const [3]).single;

/// Words read one line each — three times run together, or once for a word
/// of [takes] 1, a breath between lines — as each word's takes, sample
/// ranges in [s].
///
/// The count is known, so the longest gaps are the line breaks: a breath
/// between lines can be shorter than the stop in "eight, eight", and a fixed
/// pause length takes one for the other. Read with a pause after EVERY word,
/// there are as many runs as takes, and they go to the words in order.
List<List<(int, int)>> splitReading(Float32List s, List<int> takes) {
  final count = takes.length;
  final env = _envelope(s);
  if (env.isEmpty) throw const VoiceWordSplitException(VoiceWordSplitProblem.silent);
  final levels = _levels(env);
  final single = _spoken(env, levels.voiced);
  if (single.isEmpty) throw const VoiceWordSplitException(VoiceWordSplitProblem.silent);

  List<List<_Run>> lines;
  if (single.length == takes.fold(0, (sum, n) => sum + n)) {
    // Ten frames either side, for the soft starts and ends under the line.
    final padded = [for (final (a, b) in single) (math.max(0, a - 10), math.min(env.length, b + 10))];
    lines = [];
    var at = 0;
    for (final n in takes) {
      lines.add(padded.sublist(at, at + n));
      at += n;
    }
  } else {
    // Only the runs inside speech: a click or a breath on its own — the
    // button that started the recording — otherwise starts a line early, and
    // every take's split moves with it.
    final runs = [
      for (final run in _runs(env, (v) => v > levels.voiced))
        if (single.any((speech) => run.$1 >= speech.$1 && run.$2 <= speech.$2)) run,
    ];
    if (runs.length < count) throw const VoiceWordSplitException(VoiceWordSplitProblem.lineCount);
    final byGap = [for (var i = 1; i < runs.length; i++) i]..sort((x, y) => (runs[y].$1 - runs[y - 1].$2).compareTo(runs[x].$1 - runs[x - 1].$2));
    final breaks = byGap.take(count - 1).toList()..sort();
    if (count > 1 && byGap.length >= count) {
      int gapAt(int i) => runs[i].$1 - runs[i - 1].$2;
      final narrowestBreak = breaks.map(gapAt).reduce(math.min);
      final widestInside = gapAt(byGap[count - 1]);
      if (narrowestBreak < 1.5 * widestInside) throw const VoiceWordSplitException(VoiceWordSplitProblem.linesTooClose);
    }
    final starts = [0, ...breaks];
    final ends = [...breaks, runs.length];
    lines = [];
    for (var i = 0; i < count; i++) {
      final a = runs[starts[i]].$1, b = runs[ends[i] - 1].$2;
      // A line's last take keeps its soft end, but stops halfway to the
      // next line: past it, a short breath between them would end the word
      // on the next one's first syllable.
      final limit = i < count - 1 ? (b + runs[ends[i]].$1) ~/ 2 : env.length;
      final line = takes[i] == 1 ? [(a, math.min(limit, b + 30))] : _splitLine(env, a, b, limit: limit);
      if (line == null) throw VoiceWordSplitException(count == 1 ? VoiceWordSplitProblem.notThreeTakes : VoiceWordSplitProblem.lineCount);
      lines.add(line);
    }
  }
  return [
    for (final line in lines)
      [for (final (a, b) in line) _trimmed(env, a, b, levels.quiet) ?? (throw const VoiceWordSplitException(VoiceWordSplitProblem.notThreeTakes))],
  ];
}

/// Frames [a]..[b] trimmed to the voice in them, as samples: 20 ms before
/// the first frame over [quiet] and 50 ms after the last, for the soft ends
/// a level line misses.
(int, int)? _trimmed(List<double> env, int a, int b, double quiet) {
  int? first, last;
  for (var i = a; i < b && i < env.length; i++) {
    if (env[i] > quiet) {
      first ??= i;
      last = i;
    }
  }
  if (first == null || last == null) return null;
  return (math.max(0, first - 2) * _frame, math.min(env.length, last + 5) * _frame);
}

/// One word's three takes cut from [s], all at one gain — so the closing
/// take keeps the drop it was said with — that brings the middle take to a
/// common loudness, every word alike, short of clipping. A word recorded
/// [VoiceWord.once] is one range, kept as its middle take.
Map<WordTake, Float32List> wordTakes(Float32List s, List<(int, int)> ranges) {
  final takes = [for (final (a, b) in ranges) Float32List.fromList(s.sublist(a, b))];
  double rms(Float32List t) => math.sqrt(t.fold(0.0, (sum, v) => sum + v * v) / math.max(1, t.length));
  final loudest = takes.expand((t) => t).fold(0.0, (m, v) => math.max(m, v.abs()));
  final middle = rms(takes[takes.length ~/ 2]);
  final gain = middle == 0 ? 1.0 : math.min(_wordLoudness / middle, 0.9 / math.max(loudest, 1e-9));
  return {
    for (final (i, take) in (takes.length == 1 ? const [WordTake.middle] : WordTake.values).indexed)
      take: _fadeEdges(Float32List.fromList([for (final v in takes[i]) v * gain])),
  };
}

/// The level every word's middle take is brought to (-20 dBFS RMS): words
/// recorded at different moments, or loud and soft by nature ("Eight",
/// "Sierra"), sound alike side by side.
const _wordLoudness = 0.1;

/// [s] as a 16-bit mono WAV file at [voiceWordRate].
Uint8List encodeVoiceWav(Float32List s) {
  final data = s.length * 2;
  final out = ByteData(44 + data);
  void ascii(int at, String text) {
    for (var i = 0; i < text.length; i++) {
      out.setUint8(at + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  out.setUint32(4, 36 + data, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  out.setUint32(16, 16, Endian.little);
  out.setUint16(20, 1, Endian.little); // PCM
  out.setUint16(22, 1, Endian.little); // mono
  out.setUint32(24, voiceWordRate, Endian.little);
  out.setUint32(28, voiceWordRate * 2, Endian.little);
  out.setUint16(32, 2, Endian.little);
  out.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  out.setUint32(40, data, Endian.little);
  for (var i = 0; i < s.length; i++) {
    out.setInt16(44 + 2 * i, (s[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }
  return out.buffer.asUint8List();
}

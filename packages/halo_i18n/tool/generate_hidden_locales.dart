// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Writes the hidden locales — lib/i18n/hidden/{qro,qrp,cw}.i18n.json — from
// the English source: QRO is every string uppercased, QRP lowercased, CW in
// Morse code. The same three PoLo builds (its generate-translations.js).
// They are reached only by typing `LANG QRO` / `LANG QRP` / `LANG CW`, never
// listed in the Language setting.
//
// Run before `dart run slang`, from packages/halo_i18n:
//
//   dart run tool/generate_hidden_locales.dart && dart run slang
//
// `scripts/test.sh` runs both on every pass that loads the strings, and the
// gate fails when the committed output was behind en.i18n.json.
//
// Only the words change. Placeholders (`$name`, `${name}`), code spans, URLs,
// markdown link targets, `**` and line breaks pass through untouched: a
// placeholder whose name changed case, or a `**` spelled out in Morse, breaks
// the generated code or the rendering rather than merely looking odd.

import 'dart:convert';
import 'dart:io';

const _dot = '·';
const _dash = '—';

const _morse = {
  'A': '.-',
  'B': '-...',
  'C': '-.-.',
  'D': '-..',
  'E': '.',
  'F': '..-.',
  'G': '--.',
  'H': '....',
  'I': '..',
  'J': '.---',
  'K': '-.-',
  'L': '.-..',
  'M': '--',
  'N': '-.',
  'O': '---',
  'P': '.--.',
  'Q': '--.-',
  'R': '.-.',
  'S': '...',
  'T': '-',
  'U': '..-',
  'V': '...-',
  'W': '.--',
  'X': '-..-',
  'Y': '-.--',
  'Z': '--..',
  '0': '-----',
  '1': '.----',
  '2': '..---',
  '3': '...--',
  '4': '....-',
  '5': '.....',
  '6': '-....',
  '7': '--...',
  '8': '---..',
  '9': '----.',
  '.': '.-.-.-',
  ',': '--..--',
  '?': '..--..',
  '!': '-.-.--',
  '/': '-..-.',
  '+': '.-.-.',
  '=': '-...-',
  '-': '-....-',
  '(': '-.--.',
  ')': '-.--.-',
  '&': '.-...',
  ':': '---...',
  ';': '-.-.-.',
  '"': '.-..-.',
  "'": '.----.',
  '_': '..--.-',
  r'$': '...-..-',
  '@': '.--.-.',
};

/// Everything a transform must leave exactly as written.
final _protected = RegExp(
  r'\$\{[^}]+\}|\$[A-Za-z_][A-Za-z0-9_]*' // placeholders
  r'|`[^`]*`' // code spans
  r'|\]\([^)]*\)|\[' // markdown link targets and openers
  r'|https?://[^\s)\]"*]+' // bare URLs
  r'|\*\*|\n',
);

String _transformText(String value, String Function(String text) words) {
  final out = StringBuffer();
  var last = 0;
  for (final match in _protected.allMatches(value)) {
    out
      ..write(words(value.substring(last, match.start)))
      ..write(match[0]);
    last = match.end;
  }
  out.write(words(value.substring(last)));
  return out.toString();
}

/// Letters as Morse with a space between them and ` / ` between words;
/// protected tokens and characters with no Morse code (accented letters,
/// emoji, `…`) stand as themselves among them.
String toMorse(String value) {
  final pieces = <String>[];
  var start = 0;
  void addText(String text) {
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      if (char.trim().isEmpty) {
        if (pieces.isNotEmpty && pieces.last != '/' && pieces.last != '\n') pieces.add('/');
        continue;
      }
      final code = _morse[char.toUpperCase()];
      pieces.add(code == null ? char : code.replaceAll('.', _dot).replaceAll('-', _dash));
    }
  }

  for (final match in _protected.allMatches(value)) {
    addText(value.substring(start, match.start));
    if (match[0] == '\n' && pieces.isNotEmpty && pieces.last == '/') pieces.removeLast();
    pieces.add(match[0]!);
    start = match.end;
  }
  addText(value.substring(start));
  while (pieces.isNotEmpty && pieces.last == '/') {
    pieces.removeLast();
  }
  return pieces.join(' ').replaceAll(RegExp(r' ?\n ?'), '\n');
}

String toQro(String value) => _transformText(value, (text) => text.toUpperCase());

String toQrp(String value) => _transformText(value, (text) => text.toLowerCase());

Object? _transformTree(Object? node, String Function(String) transform) => switch (node) {
  final String value => transform(value),
  final Map<String, dynamic> map => {for (final MapEntry(:key, :value) in map.entries) key: _transformTree(value, transform)},
  _ => node,
};

void main() {
  final i18n = Directory('lib/i18n');
  if (!File('${i18n.path}/en.i18n.json').existsSync()) {
    stderr.writeln('Run from packages/halo_i18n.');
    exit(64);
  }
  final english = jsonDecode(File('${i18n.path}/en.i18n.json').readAsStringSync());
  final encoder = const JsonEncoder.withIndent('  ');
  for (final (locale, transform) in [('qro', toQro), ('qrp', toQrp), ('cw', toMorse)]) {
    File('${i18n.path}/hidden/$locale.i18n.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('${encoder.convert(_transformTree(english, transform))}\n');
  }
}

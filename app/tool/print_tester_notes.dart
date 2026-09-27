// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Prints one build's tester notes (assets/tester-notes.yaml) as plain text,
// one "• " line per change — for CI to use as a store's per-build testing
// notes. Prints nothing when the build has no notes, so the caller supplies
// its own fallback; exits non-zero when the file is not shaped like tester
// notes, which is not the same thing.
//
//   dart run tool/print_tester_notes.dart <build> [max-chars]
//
// With max-chars, whole lines are dropped from the end until the text fits,
// and a closing "• …" line says some were. Stores reject over-long notes
// outright rather than cutting them.
//
// Pure Dart on purpose — config/tester_notes.dart imports Flutter, which
// `dart run` cannot load — so the lookup below repeats that parser's rules
// for keys: quoted ("125") and bare (125) spellings are the same build.
// ignore_for_file: avoid_print — a build script; stdout is the interface.
import 'dart:io';

import 'package:yaml/yaml.dart';

void main(List<String> args) {
  final build = args.isEmpty ? null : int.tryParse(args[0]);
  final maxChars = args.length > 1 ? int.tryParse(args[1]) : null;
  if (build == null || (args.length > 1 && maxChars == null) || args.length > 2) {
    stderr.writeln('usage: print_tester_notes.dart <build> [max-chars]');
    exit(2);
  }

  final doc = loadYaml(File('assets/tester-notes.yaml').readAsStringSync());
  if (doc is! YamlMap) _fail('assets/tester-notes.yaml is not a map of builds');
  final entry = doc.entries.where((e) => e.key == build || (e.key is String && int.tryParse(e.key as String) == build)).firstOrNull;
  if (entry == null) return;
  final body = entry.value;
  if (body is! YamlMap) _fail('build $build\'s entry is not a map');
  final changes = body['changes'];
  if (changes == null) return;
  if (changes is! YamlList) _fail('build $build\'s changes are not a list');

  // The overlay renders these as markdown; a store shows the markers literally.
  // Code spans become quotes rather than vanishing: they mark keys like `.`
  // and `,` that are unreadable bare.
  final lines = [for (final change in changes) '• ${change.toString().replaceAllMapped(RegExp(r'`([^`]*)`'), (m) => '"${m[1]}"').replaceAll('**', '')}'];
  print(_fit(lines, maxChars));
}

String _fit(List<String> lines, int? maxChars) {
  final all = lines.join('\n');
  if (maxChars == null || all.length <= maxChars) return all;
  const more = '• …';
  final kept = [...lines];
  while (kept.isNotEmpty && [...kept, more].join('\n').length > maxChars) {
    kept.removeLast();
  }
  return [...kept, more].join('\n');
}

Never _fail(String message) {
  stderr.writeln('print_tester_notes: $message');
  exit(1);
}

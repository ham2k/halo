// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Reading JSON in and writing JSON out.
//
// Every JSON-valued option accepts the same three forms — inline, `@file`,
// and `-` for stdin — so nothing has to be quoted into a shell when it gets
// big, and a pipeline can feed one command's output straight into the next.

import 'dart:convert';
import 'dart:io';

import 'runtime.dart' show CliUsageError;

/// Parses a JSON option value: `-` reads stdin, a value starting with `{` or
/// `[` is the JSON itself, and anything else is a path — with or without a
/// leading `@`. Returns null for a null/absent value.
///
/// The bare path matters more than it looks. These options are usually handed
/// a file (`--qson ~/Downloads/2026-07-15.KI2D.qson`), and requiring `@` made
/// the everyday case fail as "not valid JSON — Unexpected character (at
/// character 1)", pointing at the filename it had just been told to read.
Object? readJsonArg(String? value, {required String label}) {
  if (value == null) return null;
  final String text;
  if (value == '-') {
    text = _readStdin();
  } else if (value.startsWith('{') || value.startsWith('[')) {
    text = value;
  } else {
    // `@` stays supported: it is the way to name a file whose path really
    // does start with a brace, and other tools have taught people to use it.
    final path = value.startsWith('@') ? value.substring(1) : value;
    final file = File(path);
    if (!file.existsSync()) {
      throw CliUsageError(
        '$label: no such file: $path\n'
        '(a value is a path, `-` for stdin, or inline JSON starting with { or [)',
      );
    }
    text = file.readAsStringSync();
  }
  if (text.trim().isEmpty) return null;
  try {
    return jsonDecode(text);
  } on FormatException catch (e) {
    throw CliUsageError('$label: not valid JSON — $e');
  }
}

/// [readJsonArg] where the result must be an object.
Map<String, Object?>? readJsonMapArg(String? value, {required String label}) {
  final parsed = readJsonArg(value, label: label);
  if (parsed == null) return null;
  if (parsed is! Map) throw CliUsageError('$label: expected a JSON object, got ${parsed.runtimeType}');
  return parsed.cast<String, Object?>();
}

/// [readJsonArg] where the result must be an array of objects — a QSO list,
/// a spot list.
List<Map<String, Object?>>? readJsonListArg(String? value, {required String label}) {
  final parsed = readJsonArg(value, label: label);
  if (parsed == null) return null;
  if (parsed is! List) throw CliUsageError('$label: expected a JSON array, got ${parsed.runtimeType}');
  return [
    for (final entry in parsed)
      if (entry is Map) entry.cast<String, Object?>() else throw CliUsageError('$label: array must hold objects'),
  ];
}

/// Drains stdin. By LINES, not bytes: a piped QSON is easily a megabyte, and
/// `readByteSync` pays a syscall per byte for it.
String _readStdin() {
  final buffer = StringBuffer();
  while (true) {
    final line = stdin.readLineSync(encoding: utf8);
    if (line == null) break;
    buffer.writeln(line);
  }
  return buffer.toString();
}

const _pretty = JsonEncoder.withIndent('  ');

/// Writes one result to stdout. Pretty by default because the first reader is
/// usually a person; `--compact` gives one line per invocation for pipelines.
void writeJson(Object? value, {required bool compact}) {
  stdout.writeln(compact ? jsonEncode(value) : _pretty.convert(value));
}

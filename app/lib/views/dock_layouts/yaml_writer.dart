// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A minimal YAML emitter for JSON-shaped values. The `yaml` package only
// reads; layout files are written for people to read and edit, which is why
// they are YAML rather than JSON in the first place.

import 'dart:convert';

/// [value] — maps, lists, strings, numbers, bools and nulls — as block-style
/// YAML that `package:yaml` reads back to an equal value.
///
/// A list of short scalars goes on one line (`weights: [2, 1]`), and a
/// multi-line string is a literal block, since those are what a person
/// editing the file looks for. Anything a plain scalar could misread — a
/// `yes`, a leading `-`, a `: ` inside — is double-quoted, and JSON's escapes
/// are YAML's.
String toYaml(Object? value) {
  final out = StringBuffer();
  if (value is Map && value.isNotEmpty) {
    _writeMap(out, value, 0);
  } else if (value is List && value.isNotEmpty) {
    _writeList(out, value, 0);
  } else {
    out.writeln(_scalar(value));
  }
  return out.toString();
}

void _writeMap(StringBuffer out, Map<dynamic, dynamic> map, int indent, {bool firstInline = false}) {
  var first = true;
  for (final entry in map.entries) {
    if (!(first && firstInline)) out.write(' ' * indent);
    first = false;
    out.write('${_scalar('${entry.key}')}:');
    _writeValue(out, entry.value, indent);
  }
}

void _writeList(StringBuffer out, List<dynamic> list, int indent) {
  for (final item in list) {
    out.write('${' ' * indent}-');
    if (item is Map && item.isNotEmpty) {
      out.write(' ');
      _writeMap(out, item, indent + 2, firstInline: true);
    } else if (item is List && item.isNotEmpty && !_isFlowList(item)) {
      out.writeln();
      _writeList(out, item, indent + 2);
    } else {
      out.write(' ');
      _writeInline(out, item, indent + 2);
    }
  }
}

/// The value after a `key:`, which already sits at [indent].
void _writeValue(StringBuffer out, Object? value, int indent) {
  if (value is Map && value.isNotEmpty) {
    out.writeln();
    _writeMap(out, value, indent + 2);
  } else if (value is List && value.isNotEmpty && !_isFlowList(value)) {
    out.writeln();
    _writeList(out, value, indent);
  } else {
    out.write(' ');
    _writeInline(out, value, indent + 2);
  }
}

/// A scalar, a flow list or an empty collection, ending its own line; a
/// multi-line string continues as a literal block indented to [indent].
void _writeInline(StringBuffer out, Object? value, int indent) {
  if (value is String && _literalBlockable(value)) {
    out.writeln(value.endsWith('\n') ? '|' : '|-');
    final body = value.endsWith('\n') ? value.substring(0, value.length - 1) : value;
    for (final line in body.split('\n')) {
      out.writeln(line.isEmpty ? '' : '${' ' * indent}$line');
    }
    return;
  }
  if (value is List) {
    out.writeln('[${value.map(_scalar).join(', ')}]');
    return;
  }
  out.writeln(value is Map ? '{}' : _scalar(value));
}

bool _isFlowList(List<dynamic> list) =>
    list.every((item) => item == null || item is num || item is bool || (item is String && !item.contains('\n'))) && list.map(_scalar).join(', ').length <= 60;

/// Whether [value] reads back unchanged from a `|` or `|-` block: more than
/// one line, no leading whitespace on the first (a block takes its
/// indentation from it), no trailing whitespace on any (an editor eats it),
/// and at most one final newline (`|` keeps exactly one).
bool _literalBlockable(String value) {
  if (!value.contains('\n') || value.contains('\r') || value.endsWith('\n\n')) return false;
  if (value.startsWith(' ') || value.startsWith('\t') || value.startsWith('\n')) return false;
  return value.split('\n').every((line) => line == line.trimRight());
}

final _plain = RegExp(r'^[A-Za-z_][A-Za-z0-9_ .:/#@+()-]*$');
const _reserved = {'true', 'false', 'yes', 'no', 'on', 'off', 'null', 'y', 'n', '~'};

String _scalar(Object? value) {
  if (value == null) return 'null';
  if (value is bool || value is int) return '$value';
  if (value is double) {
    if (!value.isFinite) return 'null';
    return value == value.roundToDouble() && value.abs() < 1e15 ? '${value.toInt()}' : '$value';
  }
  final text = '$value';
  final plain =
      _plain.hasMatch(text) &&
      !_reserved.contains(text.toLowerCase()) &&
      !text.endsWith(' ') &&
      !text.endsWith(':') &&
      !text.contains(': ') &&
      !text.contains(' #');
  return plain ? text : jsonEncode(text);
}

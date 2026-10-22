// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Reads a YAML file someone handed the app — a layout, a set of keyboard
// shortcuts — without letting a hostile one stall it: the reading half of
// yaml_writer.dart.

import 'package:yaml/yaml.dart';

/// A document refused for its size or its nesting, before or while it was
/// read.
class YamlTooLargeException implements Exception {
  /// What was too large, in English: for the console, never the screen.
  final String detail;

  const YamlTooLargeException(this.detail);

  @override
  String toString() => 'too large: $detail';
}

/// How many values a document may hold once its aliases are expanded — far
/// past any file the app writes, far short of what stalls the app.
const _maxNodes = 100000;

/// How deep a document's brackets may nest — far past any file the app
/// writes.
const _maxDepth = 200;

/// [text] as plain maps, lists and scalars. Throws [YamlException] for text
/// that is not YAML, and [YamlTooLargeException] for a document over the
/// caps above.
///
/// Block nesting is not counted: one line of `- - - …` a hundred thousand deep
/// runs the parser out of stack, and the [StackOverflowError] is the caller's
/// to catch around everything it does with the document, which recurses as
/// deep.
Object? loadPlainYaml(String text) {
  if (_nestsTooDeep(text)) throw const YamlTooLargeException('nested more than $_maxDepth deep');
  return _plainJson(loadYaml(text), _NodeBudget());
}

class _NodeBudget {
  var _left = _maxNodes;

  void spend() {
    if (--_left < 0) throw const YamlTooLargeException('more than $_maxNodes values');
  }
}

/// Whether [text]'s `[` and `{` nest deeper than [_maxDepth], checked before
/// the parser sees it: its time grows with the square of the depth, and a
/// line of a hundred thousand brackets holds the app for seconds. Counted
/// with no regard for quoting, so an upper bound — the writer nests by
/// indentation, and a name's brackets are never two hundred left open.
bool _nestsTooDeep(String text) {
  var depth = 0;
  for (final unit in text.codeUnits) {
    if (unit == 0x5B || unit == 0x7B) {
      if (++depth > _maxDepth) return true;
    } else if ((unit == 0x5D || unit == 0x7D) && depth > 0) {
      depth--;
    }
  }
  return false;
}

/// `package:yaml`'s nodes as plain maps and lists, so nothing downstream
/// meets a `YamlMap` that refuses to be written to.
///
/// Counted against [budget]: an alias is one node the parser hands back
/// wherever it is named, and copying it out copies it every time. Ten
/// levels of ten aliases each is a line of text per level and ten billion
/// values to copy.
Object? _plainJson(Object? node, _NodeBudget budget) {
  budget.spend();
  return switch (node) {
    final Map<dynamic, dynamic> map => {for (final e in map.entries) '${e.key}': _plainJson(e.value, budget)},
    final List<dynamic> list => [for (final item in list) _plainJson(item, budget)],
    _ => node,
  };
}

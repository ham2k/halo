// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0
import 'dart:convert';

/// Apply the deliberately small unified-diff subset used by our pinned patches.
/// No fuzzy matching, path changes, new/deleted files, or newline conversions.
Map<String, List<int>> applySourcePatch(String patch, Map<String, List<int>> originals) {
  final lines = patch.split('\n');
  if (lines.removeLast().isNotEmpty) throw const FormatException('Patch must end with a newline');
  final results = <String, List<int>>{};
  var cursor = 0;
  while (cursor < lines.length) {
    final oldHeader = lines[cursor++];
    if (!oldHeader.startsWith('--- a/') || cursor == lines.length) {
      throw const FormatException('Unsupported patch header');
    }
    final path = oldHeader.substring(6);
    if (lines[cursor++] != '+++ b/$path' || results.containsKey(path) || !originals.containsKey(path)) {
      throw const FormatException('Patch must modify an allowlisted file exactly once');
    }
    final original = utf8.decode(originals[path]!);
    if (!original.endsWith('\n')) throw const FormatException('Patched source must end with a newline');
    final before = original.split('\n')..removeLast();
    final after = <String>[];
    var consumed = 0;
    var hunks = 0;
    while (cursor < lines.length && !lines[cursor].startsWith('--- a/')) {
      final header = RegExp(r'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(?: .*)?$').firstMatch(lines[cursor++]);
      if (header == null) throw const FormatException('Unsupported patch hunk');
      final oldStart = int.parse(header[1]!);
      final oldCount = int.parse(header[2] ?? '1');
      final newStart = int.parse(header[3]!);
      final newCount = int.parse(header[4] ?? '1');
      final start = oldCount == 0 ? oldStart : oldStart - 1;
      if (start < consumed || start > before.length) throw const FormatException('Patch hunk is out of order');
      after.addAll(before.sublist(consumed, start));
      consumed = start;
      if ((newCount == 0 ? newStart : newStart - 1) != after.length) {
        throw const FormatException('Patch new-line position does not match');
      }
      var removed = 0;
      var added = 0;
      while (removed < oldCount || added < newCount) {
        if (cursor == lines.length || lines[cursor].isEmpty) throw const FormatException('Truncated patch hunk');
        final line = lines[cursor++];
        final operation = line[0];
        final content = line.substring(1);
        if (operation == ' ' || operation == '-') {
          if (removed == oldCount || consumed == before.length || before[consumed] != content) {
            throw const FormatException('Patch source context does not match');
          }
          consumed++;
          removed++;
        }
        if (operation == ' ' || operation == '+') {
          if (added == newCount) throw const FormatException('Patch hunk line count does not match');
          after.add(content);
          added++;
        }
        if (operation != ' ' && operation != '+' && operation != '-') {
          throw const FormatException('Unsupported patch operation');
        }
      }
      hunks++;
    }
    if (hunks == 0) throw const FormatException('Patch contains no hunks');
    after.addAll(before.sublist(consumed));
    results[path] = utf8.encode('${after.join('\n')}\n');
  }
  if (results.length != originals.length) throw const FormatException('Patch file inventory does not match');
  return results;
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Rendering a scoring result as markdown.
//
// Presentation only: every string here comes from the scorer itself — its
// tally keys, its `label`/`longSummary` (already markdown, already localized
// by the hook), its notice keys. Nothing is renamed or recomputed. The CLI
// has no i18n, so a notice reaches the page as the raw `newState` the scorer
// emitted rather than a translation invented here; that is also what an
// extension author is looking for.
//
// The tally SHAPE is deliberately read generically — anything map-valued is a
// breakdown — because a contest scorer's tallies are its own (zones,
// sections, multipliers) and a hardcoded list of known keys would render the
// core scorer's four and silently drop everyone else's.

import 'dart:convert';

/// Scalar fields every tally carries, which are rendered as their own columns
/// rather than as a breakdown.
const _tallyScalars = {'key', 'for', 'icon', 'total', 'count', 'label', 'summary', 'longSummary'};

/// The whole result: summaries, then sections, then per-QSO scores.
String scoreMarkdown(Map<String, Object?> result, {List<Map<String, Object?>>? qsos, String? scorerKey}) {
  final parts = [
    if (scorerKey != null) '# Score — `$scorerKey`',
    scoreSummariesMarkdown(_mapOf(result['operationSummary'])),
    scoreSectionsMarkdown(_listOf(result['daySections'])),
    scoreQsosMarkdown(_mapOf(result['qsoScores']), qsos: qsos),
  ];
  return parts.join('\n\n');
}

/// The operation's tallies — one row per tally the scorer reports.
String scoreSummariesMarkdown(Map<String, Object?> summary) {
  if (summary.isEmpty) return '## Summary\n\n_No tallies._';
  return '## Summary\n\n${_table(headers: const ['Tally', 'Total', 'Detail'], align: const [_Align.left, _Align.right, _Align.left], rows: [
    for (final entry in summary.entries) ['`${entry.key}`', _totalOf(_mapOf(entry.value)), _detailOf(_mapOf(entry.value))],
  ])}';
}

/// One row per day section (24h UTC buckets, the convention every scorer
/// follows), with each tally's detail as its own column.
String scoreSectionsMarkdown(List<Map<String, Object?>> sections) {
  if (sections.isEmpty) return '## Sections\n\n_No day sections._';

  // Columns are the union of the tally keys across days, in first-seen order:
  // a scorer can start reporting a tally on the day it first applies, and
  // taking only the first day's keys would drop it.
  final tallyKeys = <String>[];
  for (final section in sections) {
    for (final key in _mapOf(section['scores']).keys) {
      if (!tallyKeys.contains(key)) tallyKeys.add(key);
    }
  }

  return '## Sections\n\n${_table(headers: ['Day (UTC)', 'QSOs', for (final key in tallyKeys) '`$key`'], align: [_Align.left, _Align.right, for (final _ in tallyKeys) _Align.left], rows: [
    for (final section in sections) [_utcDate(section['day']), '${section['count'] ?? ''}', for (final key in tallyKeys) _detailOf(_mapOf(_mapOf(section['scores'])[key]))],
  ])}';
}

/// Per-QSO verdicts, joined to the log when it was supplied.
///
/// The join is what makes this readable: a verdict is keyed by uuid, and a
/// table of uuids tells you nothing about which contact scored what. Without
/// a log the uuid is all there is, and is shown as such rather than omitted.
String scoreQsosMarkdown(Map<String, Object?> qsoScores, {List<Map<String, Object?>>? qsos}) {
  if (qsoScores.isEmpty) return '## QSOs\n\n_No scored QSOs._';

  final byUuid = {
    for (final qso in qsos ?? const <Map<String, Object?>>[])
      if (qso['uuid'] is String) qso['uuid'] as String: qso,
  };
  final joined = byUuid.isNotEmpty;

  return '## QSOs\n\n${_table(headers: [
    if (joined) ...['Time (UTC)', 'Call', 'Band', 'Mode'] else 'QSO',
    'Points',
    'Notices',
  ], align: [
    if (joined) ...[_Align.left, _Align.left, _Align.left, _Align.left] else _Align.left,
    _Align.right,
    _Align.left,
  ], rows: [
    for (final entry in qsoScores.entries) () {
        final verdict = _mapOf(entry.value);
        final qso = byUuid[entry.key];
        return [
          if (joined) ...[_utcTime(qso?['startAtMillis']), '${_mapOf(qso?['their'])['call'] ?? ''}', '${qso?['band'] ?? ''}', '${qso?['mode'] ?? ''}'] else '`${entry.key}`',
          '${verdict['value'] ?? ''}',
          // Notices and alerts share a column, alerts marked: they differ in
          // severity, not in kind, and a scorer emits few enough of either
          // that two columns would be mostly empty.
          [..._stringsOf(verdict['notices']), ..._stringsOf(verdict['alerts']).map((alert) => '**$alert**')].join(', '),
        ];
      }(),
  ])}';
}

/// A tally's headline number. `total` is what every scorer sets; `count` is
/// the QSO-count tally's own field and stands in when there is no total.
String _totalOf(Map<String, Object?> tally) => '${tally['total'] ?? tally['count'] ?? ''}';

/// What the scorer says about this tally, plus whatever it broke down and
/// did not already say.
///
/// A `longSummary` is the scorer's own fuller statement, composed for display
/// — core's bandsAndModes sets `**20m**: 44 SSB` and leaves `label`
/// empty. Appending its `bands`/`modes` maps under it would print the same
/// counts twice. So: when a tally composed a long summary, that IS the
/// detail; when it only has a short label, the breakdowns are the part it
/// left unsaid.
String _detailOf(Map<String, Object?> tally) {
  if (tally.isEmpty) return '';
  final longSummary = _text(tally['longSummary']);
  if (longSummary.isNotEmpty) return longSummary;

  final said = _text(tally['label']).isNotEmpty ? _text(tally['label']) : _text(tally['summary']);
  final breakdowns = <String>[
    for (final entry in tally.entries)
      if (!_tallyScalars.contains(entry.key) && entry.value is Map && (entry.value as Map).isNotEmpty)
        _breakdown(entry.key, (entry.value as Map).cast<String, Object?>()),
    // Only when there are any: every operation carries a duplicates field,
    // and "0 duplicates" on every row is noise.
    if (tally['duplicates'] case final num duplicates when duplicates > 0) '$duplicates duplicate${duplicates == 1 ? '' : 's'}',
  ];

  return [if (said.isNotEmpty) said, ...breakdowns].join(' · ');
}

String _text(Object? value) => value is String ? value.trim() : '';

/// `entities: K 35 · HI 7 · …`, biggest first, ties broken by name so the
/// output does not reshuffle between runs on equal counts.
String _breakdown(String name, Map<String, Object?> counts) {
  final entries = counts.entries.toList()
    ..sort((a, b) {
      final byCount = _num(b.value).compareTo(_num(a.value));
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  return '$name: ${entries.map((entry) => '${entry.key} ${entry.value}').join(', ')}';
}

enum _Align { left, right }

/// A GitHub-flavored table. Cells are escaped for `|` only — everything else
/// in them is the scorer's own markdown and must survive intact.
String _table({required List<String> headers, required List<List<String>> rows, required List<_Align> align}) {
  final buffer = StringBuffer()
    ..writeln('| ${headers.map(_escape).join(' | ')} |')
    ..writeln('|${align.map((a) => a == _Align.right ? '---:' : '---').map((rule) => '$rule|').join()}');
  for (final row in rows) {
    buffer.writeln('| ${row.map(_escape).join(' | ')} |');
  }
  return buffer.toString().trimRight();
}

String _escape(String cell) => cell.replaceAll('|', r'\|').replaceAll('\n', ' ');

String _utcDate(Object? millis) => millis is num ? DateTime.fromMillisecondsSinceEpoch(millis.toInt(), isUtc: true).toIso8601String().substring(0, 10) : '';

String _utcTime(Object? millis) => millis is num ? DateTime.fromMillisecondsSinceEpoch(millis.toInt(), isUtc: true).toIso8601String().substring(11, 16) : '';

num _num(Object? value) => value is num ? value : 0;

Map<String, Object?> _mapOf(Object? value) => value is Map ? value.cast<String, Object?>() : const <String, Object?>{};

List<Map<String, Object?>> _listOf(Object? value) => value is List
    ? [
        for (final entry in value)
          if (entry is Map) entry.cast<String, Object?>(),
      ]
    : const [];

List<String> _stringsOf(Object? value) => value is List ? [for (final entry in value) entry is String ? entry : jsonEncode(entry)] : const [];

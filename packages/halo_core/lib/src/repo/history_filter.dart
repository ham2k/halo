// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The options an extension passes to `ctx.getHistoryForCall` — one parse and
// one set of rules for both hosts. The app runs [HistoryFilter.toSql] inside
// `QsosRepository.historyForCall`; the CLI, which holds its log as a list of
// QSON maps, runs [HistoryFilter.matches]. The two must agree, so both live
// here and `history_filter_test.dart` runs the same cases through both.

import 'package:drift/drift.dart';

import '../db/database.dart';
import '../ham/radio.dart';

/// Which modes one `mode`/`excludeMode` value stands for.
///
/// A literal mode names an emission, but the family spellings name a group:
/// `SSB` is also every contact a radio logged as `USB` or `LSB`, and
/// `PHONE`/`CW`/`DATA` are [superModeForMode]'s three families. Without the
/// fold, `mode: 'SSB'` misses the sideband a CAT-connected radio reported.
class HistoryModeMatch {
  /// Uppercase modes matched exactly.
  final Set<String> literals;

  /// Also every non-null mode outside CW and [superPhoneModes] — the `DATA`
  /// family, which is open-ended: [superModeForMode] calls anything it does
  /// not recognize digital, and so does this.
  final bool data;

  const HistoryModeMatch({this.literals = const {}, this.data = false});

  /// What [data] leaves out — every mode outside these is `DATA`.
  static const nonDataModes = {'CW', ...superPhoneModes};

  static const _sidebands = {'SSB', 'USB', 'LSB'};
  static const _dataSpellings = {'DATA', 'DIGI', 'DIGITAL'};

  static HistoryModeMatch parse(Iterable<String> values) {
    final literals = <String>{};
    var data = false;
    for (final value in values) {
      final mode = value.trim().toUpperCase();
      if (_sidebands.contains(mode)) {
        literals.addAll(_sidebands);
      } else if (mode == 'PHONE') {
        literals.addAll(superPhoneModes);
      } else if (_dataSpellings.contains(mode)) {
        data = true;
      } else {
        literals.add(mode);
      }
    }
    return HistoryModeMatch(literals: literals, data: data);
  }

  bool matches(String? mode) {
    if (mode == null) return false;
    final upper = mode.toUpperCase();
    return literals.contains(upper) || (data && !nonDataModes.contains(upper));
  }
}

class HistoryFilter {
  /// What an unfiltered call returns — the call-history lookup source reads
  /// the most recent match or two, with room to skip past the QSO it is
  /// re-enriching.
  static const defaultLimit = 5;

  /// A call worked hundreds of times must not ship its whole history across
  /// the extension bridge, whatever the caller asks for.
  static const maxLimit = 50;

  static const none = HistoryFilter();

  /// A QSO matches when ONE ref — its own, or its operation's — is of any
  /// of [refTypes] and its `ref` starts with any of [refPrefixes], each
  /// checked only when given. The same ref must pass both: a POTA ref in the
  /// US and a SOTA ref in France do not make a French POTA contact. Both
  /// places count because an activity lives in either: a hunted park is on
  /// the QSO, the park being activated (`potaActivation`) on the operation.
  final Set<String> refTypes;

  /// Whether an operation's refs are read as they stood when each QSO was
  /// made — a `break`/`start` row can move a log to a second park or end a
  /// contest — rather than as the operation row's base `refs`. Opt-in: it
  /// costs a lookup per QSO, and most logs have no segments.
  final bool refsSegmentAware;

  /// Folded by [_asciiUpper]; `ref` is compared ignoring ASCII case only,
  /// because SQLite's `upper()` folds nothing else and the app and the CLI
  /// must give one answer.
  final Set<String> refPrefixes;
  final Set<String> operations;
  final Set<String> excludeOperations;

  /// Lowercase, as bands are spelled (`20m`).
  final Set<String> bands;
  final Set<String> excludeBands;
  final HistoryModeMatch? modes;
  final HistoryModeMatch? excludeModes;

  /// Inclusive bounds on `startAtMillis`. A QSO with no start time never
  /// matches a bound: it cannot be shown to fall inside one.
  final int? fromMillis;
  final int? toMillis;

  final int limit;

  const HistoryFilter({
    this.refTypes = const {},
    this.refPrefixes = const {},
    this.refsSegmentAware = false,
    this.operations = const {},
    this.excludeOperations = const {},
    this.bands = const {},
    this.excludeBands = const {},
    this.modes,
    this.excludeModes,
    this.fromMillis,
    this.toMillis,
    this.limit = defaultLimit,
  });

  /// Parses the host-call params. Every option is optional; a value that is
  /// present but malformed throws [FormatException], which the host turns
  /// into a rejected promise. Dropping it instead would answer a narrower
  /// question with the unfiltered history, and the caller would trust it.
  ///
  /// The `*Date` options are whole UTC days and the `*Time` options exact
  /// instants, all inclusive. Where several bounds are given for one side,
  /// the tightest wins.
  ///
  /// An unknown key throws too — a misspelled `refTypes` would otherwise
  /// answer unfiltered — and so does an include option (`refType`,
  /// `refPrefix`, `operation`, `band`, `mode`) given with no values: `operation: []`
  /// built from an empty list asks for "none of these", which no answer
  /// here expresses. An empty `exclude…` option excludes nothing.
  factory HistoryFilter.fromParams(Map<String, dynamic> params) {
    final unknown = params.keys.where((key) => !_knownParams.contains(key));
    if (unknown.isNotEmpty) {
      throw FormatException('getHistoryForCall: unknown option `${unknown.first}`');
    }
    final froms = <int>[
      if (params['fromDate'] != null) _startOfUtcDay(_parseInstant('fromDate', params['fromDate'])),
      if (params['fromDateMillis'] != null) _startOfUtcDay(_parseMillis('fromDateMillis', params['fromDateMillis'])),
      if (params['fromTime'] != null) _parseInstant('fromTime', params['fromTime']),
      if (params['fromTimeMillis'] != null) _parseMillis('fromTimeMillis', params['fromTimeMillis']),
    ];
    final tos = <int>[
      if (params['toDate'] != null) _endOfUtcDay(_parseInstant('toDate', params['toDate'])),
      if (params['toDateMillis'] != null) _endOfUtcDay(_parseMillis('toDateMillis', params['toDateMillis'])),
      if (params['toTime'] != null) _parseInstant('toTime', params['toTime']),
      if (params['toTimeMillis'] != null) _parseMillis('toTimeMillis', params['toTimeMillis']),
    ];
    final mode = _strings(params, 'mode', include: true);
    final excludeMode = _strings(params, 'excludeMode');
    return HistoryFilter(
      refTypes: _strings(params, 'refType', include: true),
      refPrefixes: {for (final prefix in _strings(params, 'refPrefix', include: true)) _asciiUpper(prefix)},
      refsSegmentAware: _bool(params, 'refsSegmentAware'),
      operations: _strings(params, 'operation', include: true),
      excludeOperations: _strings(params, 'excludeOperation'),
      bands: {for (final band in _strings(params, 'band', include: true)) band.toLowerCase()},
      excludeBands: {for (final band in _strings(params, 'excludeBand')) band.toLowerCase()},
      modes: mode.isEmpty ? null : HistoryModeMatch.parse(mode),
      excludeModes: excludeMode.isEmpty ? null : HistoryModeMatch.parse(excludeMode),
      fromMillis: froms.isEmpty ? null : froms.reduce((a, b) => a > b ? a : b),
      toMillis: tos.isEmpty ? null : tos.reduce((a, b) => a < b ? a : b),
      limit: _limit(params['limit']),
    );
  }

  /// [qso] as QSON, and [operation] as the QSON of the operation it belongs
  /// to, when known — as it stood at the QSO's start when
  /// [refsSegmentAware], which the caller resolves. [operationUuid] stands in for a QSO that does not name
  /// its own operation — the CLI's `--qsos` belong to the one `--op`.
  ///
  /// Does not cover the call, deletion or event-marker rules: those are the
  /// caller's, as they are for an unfiltered history.
  bool matches(Map<String, Object?> qso, {String? operationUuid, Map<String, Object?>? operation}) {
    if (refTypes.isNotEmpty || refPrefixes.isNotEmpty) {
      bool anyMatches(Object? refs) => refs is List && refs.any((ref) => ref is Map && _refMatches(ref));
      if (!anyMatches(qso['refs']) && !anyMatches(operation?['refs'])) return false;
    }
    final uuid = (qso['operation'] as String?) ?? operationUuid;
    if (operations.isNotEmpty && !operations.contains(uuid)) return false;
    if (excludeOperations.contains(uuid)) return false;
    final band = (qso['band'] as String?)?.toLowerCase();
    if (bands.isNotEmpty && !bands.contains(band)) return false;
    if (excludeBands.contains(band)) return false;
    final mode = qso['mode'] as String?;
    if (modes != null && !modes!.matches(mode)) return false;
    if (excludeModes != null && excludeModes!.matches(mode)) return false;
    if (fromMillis != null || toMillis != null) {
      final start = qso['startAtMillis'];
      if (start is! num) return false;
      if (fromMillis != null && start < fromMillis!) return false;
      if (toMillis != null && start > toMillis!) return false;
    }
    return true;
  }

  bool _refMatches(Map<Object?, Object?> ref) {
    if (refTypes.isNotEmpty && !refTypes.contains(ref['type'])) return false;
    if (refPrefixes.isEmpty) return true;
    final value = ref['ref'];
    return value is String && refPrefixes.any(_asciiUpper(value).startsWith);
  }

  static String _asciiUpper(String value) =>
      String.fromCharCodes(value.codeUnits.map((c) => c >= 0x61 && c <= 0x7a ? c - 0x20 : c));

  /// [matches], in SQL over [q] and [o], the operation it belongs to — left
  /// joined, so a QSO whose operation row has not arrived is matched on its
  /// own refs alone. Each clause is written never to be NULL — a NULL band
  /// or mode would otherwise turn an `exclude…` clause's NOT into NULL and
  /// drop the QSO it should keep.
  Expression<bool> toSql($QsosTable q, $OperationsTable o) {
    Expression<bool> bandIn(Set<String> bands) => q.band.isNotNull() & q.band.lower().isIn(bands);
    Expression<bool> modeIn(HistoryModeMatch match) {
      final mode = q.mode.upper();
      Expression<bool> any = const Constant(false);
      if (match.literals.isNotEmpty) any = any | mode.isIn(match.literals);
      if (match.data) any = any | mode.isNotIn(HistoryModeMatch.nonDataModes);
      return q.mode.isNotNull() & any;
    }

    Expression<bool> all = const Constant(true);
    if (refTypes.isNotEmpty || refPrefixes.isNotEmpty) {
      final qsoData = '"${q.aliasedName}"."${q.data.name}"';
      final operationData = '"${o.aliasedName}"."${o.data.name}"';
      all = all &
          (_hasMatchingRef(qsoData, r'$.refs') |
              (refsSegmentAware
                  ? _hasMatchingRef(_segmentRefsSql(q, operationData), r'$')
                  : _hasMatchingRef(operationData, r'$.refs')));
    }
    if (operations.isNotEmpty) all = all & q.operation.isIn(operations);
    if (excludeOperations.isNotEmpty) all = all & q.operation.isNotIn(excludeOperations);
    if (bands.isNotEmpty) all = all & bandIn(bands);
    if (excludeBands.isNotEmpty) all = all & bandIn(excludeBands).not();
    if (modes != null) all = all & modeIn(modes!);
    if (excludeModes != null) all = all & modeIn(excludeModes!).not();
    if (fromMillis != null) all = all & q.startAtMillis.isBiggerOrEqualValue(fromMillis!);
    if (toMillis != null) all = all & q.startAtMillis.isSmallerOrEqualValue(toMillis!);
    return all;
  }

  /// The operation's refs as they stood at the QSO's start, as JSON text —
  /// `SegmentedOperation.effectiveAt`'s rule: the latest `break`/`start` row
  /// at or before the QSO that restates the operation decides; its `refs`
  /// replaces the base's, an explicit null means none, and an absent key
  /// falls back to the base. A QSO with no start time gets the base, as it
  /// does there.
  String _segmentRefsSql($QsosTable q, String operationData) {
    final qso = '"${q.aliasedName}"';
    return "(COALESCE(("
        "SELECT CASE json_type(e.data, '\$.event.operation.refs') WHEN 'null' THEN '[]' "
        "ELSE json_extract(e.data, '\$.event.operation.refs') END "
        "FROM ${q.actualTableName} AS e "
        "WHERE e.operation = $qso.operation AND e.band = 'event' AND e.deleted = 0 "
        "AND COALESCE(e.start_at_millis, 0) <= $qso.start_at_millis "
        "AND CASE WHEN json_valid(e.data) THEN json_extract(e.data, '\$.event.event') IN ('break', 'start') "
        "AND json_type(e.data, '\$.event.operation') = 'object' ELSE 0 END "
        "ORDER BY COALESCE(e.start_at_millis, 0) DESC LIMIT 1"
        "), CASE WHEN json_valid($operationData) THEN json_extract($operationData, '\$.refs') END))";
  }

  /// [_refMatches] over the array at [path] in the JSON [json] (a column or
  /// an expression), in SQL: both tests sit on one `json_each` row, so one
  /// ref has to pass them together. `json_each` throws on malformed JSON and
  /// `json_extract` on a non-object element, and SQLite does not promise to
  /// short-circuit AND — so the guards are CASEs, which it does evaluate
  /// lazily. Without them one bad row fails every filtered history lookup,
  /// not just its own. NULL (no operation row) is not valid JSON, and `refs`
  /// that is not an array matches nothing, as in [matches]. A non-text `ref`
  /// never matches a prefix, as it does not there either.
  Expression<bool> _hasMatchingRef(String json, String path) {
    String quoted(String value) => "'${value.replaceAll("'", "''")}'";
    final tests = [
      if (refTypes.isNotEmpty) "json_extract(r.value, '\$.type') IN (${refTypes.map(quoted).join(', ')})",
      if (refPrefixes.isNotEmpty)
        "json_type(r.value, '\$.ref') = 'text' AND (${[
          for (final prefix in refPrefixes)
            // substr counts characters, not UTF-16 code units.
            "upper(substr(json_extract(r.value, '\$.ref'), 1, ${prefix.runes.length})) = ${quoted(prefix)}",
        ].join(' OR ')})",
    ];
    return CustomExpression<bool>(
      'CASE WHEN json_valid($json) THEN CASE WHEN json_type($json, \'$path\') = \'array\' THEN EXISTS ('
      'SELECT 1 FROM json_each($json, \'$path\') AS r '
      'WHERE CASE WHEN r.type = \'object\' THEN (${tests.join(' AND ')}) ELSE 0 END'
      ') ELSE 0 END ELSE 0 END',
    );
  }

  static const _knownParams = {
    'call',
    'refType', 'refPrefix', 'refsSegmentAware', 'operation', 'excludeOperation', 'band', 'excludeBand', 'mode', 'excludeMode',
    'fromDate', 'toDate', 'fromDateMillis', 'toDateMillis',
    'fromTime', 'toTime', 'fromTimeMillis', 'toTimeMillis',
    'limit',
  };

  static Set<String> _strings(Map<String, dynamic> params, String key, {bool include = false}) {
    final value = params[key];
    if (value == null) return const {};
    final Set<String> values;
    if (value is String) {
      values = {if (value.trim().isNotEmpty) value.trim()};
    } else if (value is List && value.every((v) => v is String)) {
      values = {for (final v in value.cast<String>()) if (v.trim().isNotEmpty) v.trim()};
    } else {
      throw FormatException('getHistoryForCall: `$key` must be a string or an array of strings, got $value');
    }
    if (include && values.isEmpty) {
      throw FormatException('getHistoryForCall: `$key` has no values, so it would match nothing');
    }
    return values;
  }

  static bool _bool(Map<String, dynamic> params, String key) {
    final value = params[key];
    if (value == null || value is bool) return value == true;
    throw FormatException('getHistoryForCall: `$key` must be true or false, got $value');
  }

  static int _limit(Object? value) {
    if (value == null) return defaultLimit;
    if (value is! num || value < 1) {
      throw FormatException('getHistoryForCall: `limit` must be a positive number, got $value');
    }
    return value.toInt().clamp(1, maxLimit);
  }

  static int _parseMillis(String key, Object? value) {
    if (value is num) return value.toInt();
    throw FormatException('getHistoryForCall: `$key` must be a number of milliseconds, got $value');
  }

  /// An ISO 8601 date or timestamp. One with no offset is UTC, not local:
  /// a log's times are UTC, and the same call must not answer differently
  /// by the machine's time zone.
  static int _parseInstant(String key, Object? value) {
    final parsed = value is String ? DateTime.tryParse(value.trim()) : null;
    if (parsed != null) {
      if (parsed.isUtc) return parsed.millisecondsSinceEpoch;
      return DateTime.utc(parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute, parsed.second,
              parsed.millisecond, parsed.microsecond)
          .millisecondsSinceEpoch;
    }
    throw FormatException('getHistoryForCall: `$key` must be an ISO 8601 date or timestamp, got $value');
  }

  static const _dayMillis = Duration.millisecondsPerDay;
  static int _startOfUtcDay(int millis) => millis - millis % _dayMillis;
  static int _endOfUtcDay(int millis) => _startOfUtcDay(millis) + _dayMillis - 1;
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What actually crosses the bridge when the Spots Panel asks which spots are
// worked. The scoring harness reads the operation's log through
// `operation.uuid` and treats a missing one as an EMPTY log — no error, no
// warning, just every spot reported as unworked forever. An operation's `data`
// map does not carry its uuid, so the service folds it in; nothing else in the
// stack notices if it stops.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/extension_service.dart';

/// Records every hook invocation so a test can assert on the arguments, not
/// just the result.
class _RecordingHost implements ExtensionHost {
  final List<({String category, String? key, String method, Object? args})> calls = [];
  final Map<String, dynamic> results;

  _RecordingHost(this.results);

  @override
  Future<dynamic> invokeHook(
    String category, {
    String? key,
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    calls.add((category: category, key: key, method: method, args: args));
    return results['$category:$key:$method'];
  }

  @override
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final res = results['$category:*:$method'];
    return res == null ? const [] : (res as List).cast<Map<String, dynamic>>();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ServiceWithHost extends ExtensionService {
  final _RecordingHost mockHost;
  final Map<String, dynamic> scopes;
  _ServiceWithHost(this.mockHost, {this.scopes = const {'core': 'always'}});

  @override
  ExtensionHost? get host => mockHost;

  /// Which scorers exist is not what these tests are about — they cover what
  /// reaches the hook once one has been selected.
  @override
  Future<Map<String, dynamic>> getScoringScopes() async => scopes;

  @override
  Future<void> start() async {}
}

/// A host answering `scoreCandidates` with [verdicts], for the core scorer
/// (scope `always`, so it applies to every operation).
_RecordingHost _host(Map<String, dynamic> verdicts) =>
    _RecordingHost({'scoring:core:scoreCandidates': verdicts});

Map<String, dynamic> _candidate(String call) => {
      'their': {'call': call},
      'band': '20m',
      'mode': 'SSB',
      'refs': const <Map<String, dynamic>>[],
      'startAtMillis': 1735689600000,
    };

void main() {
  test('the operation reaching the scorer carries the uuid', () async {
    final host = _host({
      'k1abc': {'notices': const [], 'alerts': const ['duplicate']},
    });
    final service = _ServiceWithHost(host);

    // The shape the Spots Panel has: an operation's `data`, which holds the
    // station call and refs but NOT the uuid.
    await service.scoreCandidates(
      operation: const {'stationCall': 'N0DEV'},
      operationUuid: 'op-1',
      candidates: {'k1abc': _candidate('K1ABC')},
    );

    final call = host.calls.firstWhere((c) => c.method == 'scoreCandidates');
    final operation = (call.args as Map)['operation'] as Map;
    expect(operation['uuid'], 'op-1',
        reason: 'without the uuid the harness reads an empty log and no spot is ever a duplicate');
    // Folded in, not substituted for — the scorers still need the rest.
    expect(operation['stationCall'], 'N0DEV');
  });

  test('every candidate goes over in ONE call per scorer', () async {
    final host = _host(const <String, dynamic>{});
    final service = _ServiceWithHost(host);

    await service.scoreCandidates(
      operation: const {'stationCall': 'N0DEV'},
      operationUuid: 'op-1',
      candidates: {
        for (var i = 0; i < 25; i++) 'c$i': _candidate('W${i}ABC'),
      },
    );

    final scoring = host.calls.where((c) => c.method == 'scoreCandidates').toList();
    expect(scoring.length, 1, reason: 'a bridge crossing per spot is what this call exists to avoid');
    expect(((scoring.first.args as Map)['candidates'] as List).length, 25);
  });

  test('verdicts come back keyed by the caller\'s own candidate keys', () async {
    final host = _host({
      'worked': {'notices': const [], 'alerts': const ['duplicate']},
      'fresh': {'notices': const ['newBand'], 'alerts': const []},
    });
    final service = _ServiceWithHost(host);

    final result = await service.scoreCandidates(
      operation: const {'stationCall': 'N0DEV'},
      operationUuid: 'op-1',
      candidates: {'worked': _candidate('K1ABC'), 'fresh': _candidate('W2XYZ')},
    );

    expect(result?['worked']?['alerts'], ['duplicate']);
    expect(result?['fresh']?['notices'], ['newBand']);
  });

  // A candidate a scorer had nothing to say about is dropped rather than
  // carried as empty lists — the panel reads "absent" and "nothing to report"
  // identically, and an empty entry per spot is pure payload.
  test('a candidate with nothing to report is absent from the result', () async {
    final host = _host({
      'quiet': {'notices': const [], 'alerts': const []},
      'loud': {'notices': const [], 'alerts': const ['duplicate']},
    });
    final service = _ServiceWithHost(host);

    final result = await service.scoreCandidates(
      operation: const {'stationCall': 'N0DEV'},
      operationUuid: 'op-1',
      candidates: {'quiet': _candidate('K1ABC'), 'loud': _candidate('W2XYZ')},
    );

    expect(result?.containsKey('quiet'), isFalse);
    expect(result?.containsKey('loud'), isTrue);
  });

  // The cached scoresheet lets a scorer skip folding the whole log, which is
  // the dominant cost of a pass on a long log.
  test('a supplied scoresheet reaches its own scorer as resumeFrom', () async {
    final host = _host(const <String, dynamic>{});
    final service = _ServiceWithHost(host);

    await service.scoreCandidates(
      operation: const {'stationCall': 'N0DEV'},
      operationUuid: 'op-1',
      candidates: {'a': _candidate('K1ABC')},
      scoresheets: const {'core': {'workedByCall': {}}},
    );

    final args = host.calls.firstWhere((c) => c.method == 'scoreCandidates').args as Map;
    expect(args['resumeFrom'], const {'workedByCall': {}});
  });

  // Omitting it must send NO `resumeFrom` at all rather than a null one: the
  // harness branches on the key's presence, and a null would still be "resume",
  // from nothing — every candidate judged against an empty log.
  test('no scoresheet means the key is absent, not null', () async {
    final host = _host(const <String, dynamic>{});
    final service = _ServiceWithHost(host);

    await service.scoreCandidates(
      operation: const {'stationCall': 'N0DEV'},
      operationUuid: 'op-1',
      candidates: {'a': _candidate('K1ABC')},
    );

    final args = host.calls.firstWhere((c) => c.method == 'scoreCandidates').args as Map;
    expect(args.containsKey('resumeFrom'), isFalse);
  });

  // Null means "no scorer ran at all", which the panel treats as "keep the
  // previous verdicts" rather than un-striking every worked spot. It must not
  // be confused with a scorer that ran and reported nothing.
  test('a runtime with no scorers returns null, not an empty map', () async {
    final service = _ServiceWithHost(_RecordingHost(const {}), scopes: const {});

    final result = await service.scoreCandidates(
      operation: const {'stationCall': 'N0DEV'},
      operationUuid: 'op-1',
      candidates: {'a': _candidate('K1ABC')},
    );

    expect(result, isNull);
  });
}

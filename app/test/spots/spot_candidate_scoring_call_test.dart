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
import 'package:ham2k_logger/services/error_reporting_service.dart';
import 'package:ham2k_logger/services/extension_scoring.dart';
import 'package:ham2k_logger/services/extension_service.dart';

import '../support/error_reporting_fakes.dart';

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
    final result = results['$category:$key:$method'];
    // A hook that throws is stored as the exception itself — the failure this
    // file needs is a scorer that raises, not one that answers oddly.
    if (result is Exception) throw result;
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
    bool partialOnTimeout = false,
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
  setUp(ErrorReportingService.resetFailureStreaks);
  tearDown(ErrorReportingService.resetFailureStreaks);

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

  // The cached checkpoint lets a scorer skip folding the whole log, which is
  // the dominant cost of a pass on a long log; the tail beside it is what the
  // checkpoint has not folded.
  test('a supplied checkpoint reaches its own scorer as resumeFrom, with its day and the tail', () async {
    final host = _host(const <String, dynamic>{});
    final service = _ServiceWithHost(host);

    await service.scoreCandidates(
      operation: const {'stationCall': 'N0DEV'},
      operationUuid: 'op-1',
      candidates: {'a': _candidate('K1ABC')},
      resume: (
        checkpoints: {'core': (sheet: const {'workedByCall': {}}, day: 86400000)},
        tail: [const {'uuid': 'c', 'their': {'call': 'K1ABC'}}],
      ),
    );

    final args = host.calls.firstWhere((c) => c.method == 'scoreCandidates').args as Map;
    expect(args['resumeFrom'], const {'workedByCall': {}});
    expect(args['resumeDay'], 86400000);
    expect(args['qsos'], [const {'uuid': 'c', 'their': {'call': 'K1ABC'}}]);
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

  group('a scorer that fails', () {
    // The distinction this whole group is about: "nobody ran" and "the one
    // who knows failed" are opposite instructions to the panel, and before
    // they were told apart a broken core scorer produced the SAME null as a
    // runtime still starting — so the board kept every strike the dead
    // scorer had last put there.
    test('returns an empty map, not the null that means "keep the old verdicts"', () async {
      final service = _ServiceWithHost(
        _RecordingHost({'scoring:core:scoreCandidates': Exception('scorer blew up')}),
      );

      final result = await withScoringBackend(() => service.scoreCandidates(
            operation: const {'stationCall': 'N0DEV'},
            operationUuid: 'op-1',
            candidates: {'worked': _candidate('K1ABC')},
          ));

      expect(result, isNotNull, reason: 'null would leave the board struck through by a scorer that is gone');
      expect(result, isEmpty, reason: 'no duplicate alert survives, so every spot reads available');
    });

    // The half that must NOT change: one contest scorer breaking cannot cost
    // the operator core's dupe marking, which is the reason the catch is
    // per-scorer in the first place.
    test('the scorers that did answer still report', () async {
      final service = _ServiceWithHost(
        _RecordingHost({
          'scoring:core:scoreCandidates': {
            'worked': {'notices': const [], 'alerts': const ['duplicate']},
          },
          'scoring:contest:scoreCandidates': Exception('contest scorer blew up'),
        }),
        scopes: const {'core': 'always', 'contest': 'always'},
      );

      final result = await withScoringBackend(() => service.scoreCandidates(
            operation: const {'stationCall': 'N0DEV'},
            operationUuid: 'op-1',
            candidates: {'worked': _candidate('K1ABC')},
          ));

      expect(result?['worked']?['alerts'], ['duplicate']);
    });

    // A pass runs every couple of minutes for as long as an operation is
    // open. Reporting each one would send a four-hour activation's worth of
    // identical events for one broken extension.
    test('reports once, however many passes fail', () async {
      final service = _ServiceWithHost(
        _RecordingHost({'scoring:core:scoreCandidates': Exception('scorer blew up')}),
      );
      final backend = FakeErrorReportingBackend();

      await withErrorHooks(() async {
        for (var pass = 0; pass < 3; pass++) {
          await service.scoreCandidates(
            operation: const {'stationCall': 'N0DEV'},
            operationUuid: 'op-1',
            candidates: {'worked': _candidate('K1ABC')},
          );
        }
      }, backend: backend);

      expect(backend.exceptions.length, 1);
      expect(backend.exceptions.single.error, isA<ScoringHookFailure>());
      expect((backend.exceptions.single.error as ScoringHookFailure).scorerKey, 'core');
    });

    // Without the recordSuccess on the answering path the streak never
    // clears, so a scorer that broke, recovered and broke again would be
    // reported only the first time — and the second outage would be
    // invisible for the rest of the session.
    test('a scorer that recovers and breaks again is reported again', () async {
      final backend = FakeErrorReportingBackend();
      final broken = _ServiceWithHost(
        _RecordingHost({'scoring:core:scoreCandidates': Exception('scorer blew up')}),
      );
      final working = _ServiceWithHost(
        _RecordingHost({
          'scoring:core:scoreCandidates': {
            'worked': {'notices': const [], 'alerts': const ['duplicate']},
          },
        }),
      );

      await withErrorHooks(() async {
        for (final service in [broken, working, broken]) {
          await service.scoreCandidates(
            operation: const {'stationCall': 'N0DEV'},
            operationUuid: 'op-1',
            candidates: {'worked': _candidate('K1ABC')},
          );
        }
      }, backend: backend);

      expect(backend.exceptions.length, 2);
    });
  });
}

/// Runs [body] with the error hooks installed and a throwaway backend, for
/// the cases that are about the RESULT rather than the report — a scorer
/// failure reports through ErrorReportingService either way, and without a
/// backend in place it would reach the real one.
Future<T> withScoringBackend<T>(Future<T> Function() body) async {
  late T result;
  await withErrorHooks(() async {
    result = await body();
  }, backend: FakeErrorReportingBackend());
  return result;
}

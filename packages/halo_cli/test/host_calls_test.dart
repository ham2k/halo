// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:io';

import 'package:halo_cli/src/bundles.dart';
import 'package:halo_cli/src/config.dart';
import 'package:halo_cli/src/host_calls.dart';
import 'package:test/test.dart';

void main() {
  final index = BundleIndex(
    directory: Directory('/nowhere'),
    kernelFile: 'kernel.js',
    extensions: const [
      BundleEntry(key: 'pota', file: 'pota.js', name: 'POTA'),
      BundleEntry(key: 'annotation-commands', file: 'ac.js', name: 'Annotations', requiresLocation: true),
    ],
  );

  CliHostCalls host({
    LogContext log = LogContext.empty,
    ({double lat, double lon})? location,
    Set<String> locationAllowlist = const {},
  }) =>
      CliHostCalls(
        config: CliConfig(),
        index: index,
        log: log,
        location: location,
        locationAllowlist: locationAllowlist,
      );

  group('--qson', () {
    test('supplies both halves of the log from one file', () {
      // The shape PoLo exports and every coarse hook already takes, so a real
      // exported log is usable unedited.
      final log = LogContext.resolve(qson: const {
        'operation': {'uuid': 'op-1', 'stationCall': 'N0DEV'},
        'qsos': [
          {'their': {'call': 'W1AW'}}
        ],
      });
      expect(log.operation?['stationCall'], 'N0DEV');
      expect(log.qsos, hasLength(1));
    });

    test('--op overrides the file\'s operation without touching its QSOs', () {
      // Replaying a real log against a different operation is the reason to
      // pass both; merging instead would leave you guessing which operation
      // produced the answer.
      final log = LogContext.resolve(
        qson: const {
          'operation': {'uuid': 'op-1', 'stationCall': 'N0DEV'},
          'qsos': [
            {'their': {'call': 'W1AW'}}
          ],
        },
        operation: const {'uuid': 'op-2', 'stationCall': 'KI2D'},
      );
      expect(log.operation?['stationCall'], 'KI2D');
      // No merge: the overriding operation is used whole, so nothing of the
      // file's operation leaks into it.
      expect(log.operation, isNot(contains('refs')));
      expect(log.qsos, hasLength(1));
    });

    test('a QSON with no qsos is an EMPTY log, while --op alone is no log at all', () {
      // The distinction hooks branch on (HookContext.getQsos): [] is "the
      // operation is real and has no QSOs yet", null is "this host has no log
      // access". Handing over a QSON file is granting access, so a file
      // listing no contacts describes an empty log — but an operation on its
      // own is not a claim to have supplied the log's contents.
      final fromQson = LogContext.resolve(qson: const {
        'operation': {'uuid': 'op-1'}
      });
      expect(fromQson.operation, isNotNull);
      expect(fromQson.qsos, isEmpty);

      final fromOpAlone = LogContext.resolve(operation: const {'uuid': 'op-1'});
      expect(fromOpAlone.qsos, isNull);
    });

    test('an explicitly empty qsos array is still an empty log', () {
      expect(LogContext.resolve(qson: const {'qsos': []}).qsos, isEmpty);
    });

    test('something that is not a log is refused, naming what one looks like', () {
      // The likely mistakes are a bare operation or a bare QSO array, and
      // neither announces itself.
      expect(() => LogContext.resolve(qson: const {'uuid': 'op-1', 'stationCall': 'N0DEV'}),
          throwsA(isA<QsonShapeError>().having((e) => e.message, 'message', contains('operation'))));
      expect(() => LogContext.resolve(qson: const {'qsos': 'not an array'}), throwsA(isA<QsonShapeError>()));
      expect(() => LogContext.resolve(qson: const {'operation': 'not an object'}), throwsA(isA<QsonShapeError>()));
    });
  });

  group('log reads', () {
    test('getQsos answers null with no log, [] for an empty one', () async {
      // HookContext.getQsos draws this distinction and hooks branch on it:
      // null means "this host has no log access", [] means "the operation is
      // real and has no QSOs yet". Collapsing them makes SEED's placement
      // rule read an empty log as a missing one.
      expect(await host().call('getQsos', {'operationUuid': 'op-1'}), isNull);

      final withLog = host(log: const LogContext(operation: {'uuid': 'op-1'}, qsos: []));
      expect(await withLog.call('getQsos', {'operationUuid': 'op-1'}), isEmpty);
    });

    test('a request for a DIFFERENT operation is a miss, not a substitution', () async {
      // The CLI holds one operation. Answering with it regardless of the uuid
      // asked for would let a hook believe it read the log it named.
      final calls = host(log: const LogContext(operation: {'uuid': 'op-1'}, qsos: [
        {'their': {'call': 'KI2D'}}
      ]));
      expect(await calls.call('getQsos', {'operationUuid': 'op-2'}), isNull);
      expect(await calls.call('getOperation', {'uuid': 'op-2'}), isNull);
      expect(await calls.call('getOperation', {'uuid': 'op-1'}), containsPair('uuid', 'op-1'));
    });

    test('getQsos leaves out soft-deleted QSOs, in any client\'s spelling of deleted', () async {
      // The app never hands a hook a deleted QSO; a CLI replay of an
      // exported log that did would score or export contacts the operator
      // removed.
      final calls = host(log: const LogContext(operation: {'uuid': 'op-1'}, qsos: [
        {'their': {'call': 'KI2D'}},
        {'their': {'call': 'W1AW'}, 'deleted': true},
        {'their': {'call': 'N0CALL'}, 'deleted': 1},
        {'band': 'event', 'eventKind': 'break'},
      ]));
      final result = await calls.call('getQsos', {'operationUuid': 'op-1'}) as List;
      expect(result.map((qso) => ((qso as Map)['their'] as Map?)?['call']), ['KI2D', null]);
    });
  });

  group('getSpotsForCall', () {
    Map<String, Object?> spot(String call, {required int ageMinutes}) => {
          'their': {'call': call},
          'spot': {
            'timeInMillis':
                DateTime.now().millisecondsSinceEpoch - ageMinutes * Duration.millisecondsPerMinute,
          },
        };

    test('filters by callsign and by the spot\'s OWN age', () async {
      // The age is measured on `spot.timeInMillis`, not on when the host
      // fetched it — a stale spot replayed into a fresh cache is still stale,
      // and spot-history pulling a two-hour-old park into the QSO being
      // logged is exactly the wrong answer.
      final calls = host(
        log: LogContext(spots: [
          spot('KI2D', ageMinutes: 5),
          spot('KI2D', ageMinutes: 120),
          spot('N0CALL', ageMinutes: 5),
        ]),
      );
      final result = await calls.call('getSpotsForCall', {'call': 'ki2d', 'maxAgeMinutes': 30});
      expect(result, hasLength(1));
    });
  });

  group('getHistoryForCall', () {
    test('answers [] with no log, same as no match', () async {
      expect(await host().call('getHistoryForCall', {'call': 'KI2D'}), isEmpty);
    });

    test('filters by callsign, case-insensitively, most recent first', () async {
      final calls = host(
        log: const LogContext(operation: {'uuid': 'op-1'}, qsos: [
          {
            'their': {'call': 'KI2D'},
            'startAtMillis': 1000,
          },
          {
            'their': {'call': 'W1AW'},
            'startAtMillis': 2000,
          },
          {
            'their': {'call': 'KI2D'},
            'startAtMillis': 3000,
          },
        ]),
      );
      final result = await calls.call('getHistoryForCall', {'call': 'ki2d'}) as List;
      expect(result, hasLength(2));
      expect((result.first as Map)['startAtMillis'], 3000);
    });

    test('an event marker never stands in as a "most recent QSO"', () async {
      final calls = host(
        log: const LogContext(operation: {'uuid': 'op-1'}, qsos: [
          {
            'their': {'call': 'KI2D'},
            'startAtMillis': 1000,
          },
          {
            'their': {'call': 'KI2D'},
            'band': 'event',
            'startAtMillis': 2000,
          },
        ]),
      );
      final result = await calls.call('getHistoryForCall', {'call': 'KI2D'}) as List;
      expect(result, hasLength(1));
      expect((result.single as Map)['startAtMillis'], 1000);
    });

    test('a deleted QSO is not history, in any client\'s spelling of deleted', () async {
      final calls = host(
        log: const LogContext(operation: {'uuid': 'op-1'}, qsos: [
          {
            'their': {'call': 'KI2D'},
            'startAtMillis': 1000,
          },
          {
            'their': {'call': 'KI2D'},
            'deleted': true,
            'startAtMillis': 2000,
          },
          {
            'their': {'call': 'KI2D'},
            'deleted': 1,
            'startAtMillis': 3000,
          },
        ]),
      );
      final result = await calls.call('getHistoryForCall', {'call': 'KI2D'}) as List;
      expect(result.map((qso) => (qso as Map)['startAtMillis']), [1000]);
    });

    test('caps at 5, same headroom as the app answers with', () async {
      final calls = host(
        log: LogContext(
          operation: const {'uuid': 'op-1'},
          qsos: [
            for (var i = 0; i < 8; i++)
              {
                'their': {'call': 'KI2D'},
                'startAtMillis': i,
              },
          ],
        ),
      );
      final result = await calls.call('getHistoryForCall', {'call': 'KI2D'}) as List;
      expect(result, hasLength(5));
    });

    // The rules are halo_core's history_filter_test.dart, which runs the
    // same cases through the app's SQL; these prove the CLI applies them.
    test('options narrow the log before the cap, and --op names the operation', () async {
      final calls = host(
        log: LogContext(
          operation: const {'uuid': 'op-1'},
          qsos: [
            {
              'their': {'call': 'KI2D'},
              'startAtMillis': 0,
              'refs': [
                {'type': 'cwt'}
              ],
            },
            for (var i = 1; i <= 6; i++)
              {
                'their': {'call': 'KI2D'},
                'startAtMillis': i,
              },
          ],
        ),
      );
      final cwt = await calls.call('getHistoryForCall', {'call': 'KI2D', 'refType': 'cwt'}) as List;
      expect(cwt.map((qso) => (qso as Map)['startAtMillis']), [0]);
      expect(await calls.call('getHistoryForCall', {'call': 'KI2D', 'excludeOperation': 'op-1'}), isEmpty);
      expect(await calls.call('getHistoryForCall', {'call': 'KI2D', 'limit': 50}), hasLength(7));
    });

    test('a malformed option throws rather than answering unfiltered', () async {
      final calls = host(log: const LogContext(operation: {'uuid': 'op-1'}, qsos: []));
      await expectLater(calls.call('getHistoryForCall', {'call': 'KI2D', 'band': 20}), throwsFormatException);
    });

    test('a malformed option throws even when the invocation was given no log', () async {
      // An extension author testing without --qsos would otherwise never
      // learn the option is bad.
      await expectLater(host().call('getHistoryForCall', {'call': 'KI2D', 'band': 20}), throwsFormatException);
    });
  });

  group('getLocation', () {
    test('is refused for an extension that never declared requiresLocation', () async {
      // The manifest capability is the app's gate too. An extension that
      // quietly gains the device's position here would be running with
      // permissions it does not have in the product.
      expect(
        () => host(location: (lat: 1, lon: 2), locationAllowlist: const {'annotation-commands'})
            .call('getLocation', {'extensionKey': 'pota'}),
        throwsA(isA<HostCallRefused>()),
      );
    });

    test('answers a declared extension, and answers null with no fix', () async {
      const allowed = {'annotation-commands'};
      final withFix = host(location: (lat: 41.7, lon: -74.5), locationAllowlist: allowed);
      expect(await withFix.call('getLocation', {'extensionKey': 'annotation-commands'}),
          {'latitude': 41.7, 'longitude': -74.5});

      final withoutFix = host(locationAllowlist: allowed);
      expect(await withoutFix.call('getLocation', {'extensionKey': 'annotation-commands'}), isNull);
    });
  });

  test('an unimplemented host call is REFUSED, not answered with null', () async {
    // The kernel turns a rejection into a rejected promise, so the extension
    // takes its error path. A null would read as a real answer and could be
    // cached as one.
    expect(() => host().call('summonTheAncients', const {}), throwsA(isA<HostCallRefused>()));
  });

  test('getSettings carries the extension groups under `extensions`', () async {
    final settings = await host().call('getSettings', const {}) as Map;
    expect(settings['extensions'], isA<Map>());
    expect(settings['appName'], 'Ham2K Logger');
  });
}

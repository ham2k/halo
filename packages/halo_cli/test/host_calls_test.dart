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

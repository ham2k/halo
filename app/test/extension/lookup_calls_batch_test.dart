// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `lookupCalls` looks up many callsigns in one crossing for the spot board.
// Its traps: the answers must come back in the order asked whatever the
// runtime settles first, one call failing must cost only that call, and a
// batch must stay one crossing — a crossing per call is the flood it exists
// to prevent. And its failure streak: a busy engine leaves stragglers in
// most batches, and counting those holds the streak past its one report, so
// a real outage afterwards uploads nothing.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/error_reporting_service.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import '../support/error_reporting_fakes.dart';
import '../support/fake_extension_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(ErrorReportingService.resetFailureStreaks);
  tearDown(ErrorReportingService.resetFailureStreaks);

  test('answers each call in order, in one crossing, and a failed call answers null alone', () async {
    final host = FakeExtensionHost({
      'lookupService:core:lookupCallInfo': (Object? args) {
        final call = ((args as Map)['callInfo'] as Map)['call'] as String;
        if (call == 'N0BAD') throw Exception('call notes broke');
        return {
          'guess': {'name': 'Name of $call'},
        };
      },
    });
    final extensions = ExtensionServiceWithFakeHost(host);

    late List<Map<String, dynamic>?> answers;
    await withErrorHooks(() async {
      answers = await extensions.lookupCalls(
        [(call: 'W1AW', qso: const {}), (call: 'N0BAD', qso: const {}), (call: 'K1ABC', qso: const {})],
        operation: const {},
        online: false,
        streakKey: 'test:lookups',
      );
    }, backend: FakeErrorReportingBackend());

    expect(host.batches, hasLength(1));
    expect([for (final answer in answers) (answer?['guess'] as Map?)?['name']], ['Name of W1AW', null, 'Name of K1ABC']);
  });

  // The runtime refuses a call shorter than a callsign can be, as
  // `lookupCall` does — asked anyway, it would spend a slot in the batch.
  test('a call too short to be a callsign answers null without being asked', () async {
    final host = FakeExtensionHost({
      'lookupService:core:lookupCallInfo': (Object? args) => {'guess': <String, dynamic>{}},
    });
    final answers = await ExtensionServiceWithFakeHost(
      host,
    ).lookupCalls([(call: 'K1', qso: const {}), (call: 'W1AW', qso: const {})], operation: const {}, streakKey: 'test:lookups');

    expect(answers.first, isNull);
    expect(answers.last, isNotNull);
    expect(host.batches.single, hasLength(1));
  });

  group('the failure streak', () {
    Future<FakeErrorReportingBackend> lookUp(ExtensionHost host, {required int times}) async {
      final backend = FakeErrorReportingBackend();
      await withErrorHooks(() async {
        for (var i = 0; i < times; i++) {
          await ExtensionServiceWithFakeHost(
            host,
          ).lookupCalls([(call: 'W1AW', qso: const {}), (call: 'N0BAD', qso: const {})], operation: const {}, online: false, streakKey: 'test:lookups');
        }
      }, backend: backend);
      return backend;
    }

    test('a batch with answers among its failures is not the pipeline failing', () async {
      final host = FakeExtensionHost({
        'lookupService:core:lookupCallInfo': (Object? args) {
          if (((args as Map)['callInfo'] as Map)['call'] == 'N0BAD') throw Exception('call notes broke');
          return {'guess': <String, dynamic>{}};
        },
      });
      final backend = await lookUp(host, times: ErrorReportingService.repeatedFailureThreshold * 2);

      expect(backend.exceptions, isEmpty);
    });

    test('only batches that answered nothing, in a row, reach the report', () async {
      // Built so the two halves of the rule each decide it: an answer in a
      // mixed batch must clear the streak, and the failures beside it must
      // not start a new one.
      var answering = true;
      final host = FakeExtensionHost({
        'lookupService:core:lookupCallInfo': (Object? args) {
          if (!answering || ((args as Map)['callInfo'] as Map)['call'] == 'N0BAD') throw Exception('lookups broke');
          return {'guess': <String, dynamic>{}};
        },
      });
      final backend = FakeErrorReportingBackend();
      Future<void> batch({required bool answers}) async {
        answering = answers;
        await ExtensionServiceWithFakeHost(
          host,
        ).lookupCalls([(call: 'W1AW', qso: const {}), (call: 'N0BAD', qso: const {})], operation: const {}, online: false, streakKey: 'test:lookups');
      }

      await withErrorHooks(() async {
        for (final answers in [false, false, true, false, false]) {
          await batch(answers: answers);
        }
        expect(backend.exceptions, isEmpty);
        await batch(answers: false);
      }, backend: backend);

      expect(backend.exceptions, hasLength(1));
    });

    test('a batch that runs out of time reports once, as a timeout', () async {
      final backend = await lookUp(_TimingOutHost(), times: ErrorReportingService.repeatedFailureThreshold);

      expect(backend.exceptions, hasLength(1));
      // ErrorPolicy tracks timeouts by this class; reported as a plain host
      // exception, the board's timeouts fall out of that rule's count.
      expect(backend.exceptions.single.error, isA<HookTimeoutException>());
    });
  });
}

/// A batch whose time runs out, as the host reports it to a caller that
/// asked for no partials.
class _TimingOutHost extends FakeExtensionHost {
  @override
  Future<List<Map<String, dynamic>>> invokeHookBatch(
    List<HookCall> calls, {
    Duration timeout = const Duration(seconds: 10),
    bool partialOnTimeout = false,
  }) async => throw HookTimeoutException('hook batch:lookupCallInfo timed out after ${timeout.inMilliseconds}ms');
}

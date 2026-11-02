// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Ways an activity hook call can lose more than it has to. A save fans
// `processQsoBeforeSave` out under ONE timeout, so one stalled contest must
// cost only its own patch — not the exchange every other activity projected
// into the row and the ADIF export. The add-activity search, asked while
// the runtime is booting or being replaced, has no host to ask: it must wait
// for one rather than answer "nothing matched", which the picker never asks
// again about, and with none at all say no extension could answer. Nor may
// it throw: nothing above it catches, so a throw leaves the picker loading
// for good. And controls that tie on `order` keep their places, or a panel's
// fields shuffle from one load to the next.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/error_reporting_service.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';

import '../support/error_reporting_fakes.dart';
import '../support/fake_extension_host.dart';

const _park = {'type': 'potaActivation', 'ref': 'US-0001', 'name': 'Bear Mountain'};

/// A host whose fan-out runs out its budget with NAQP still out, answering as
/// the real host does: a [HookTimeoutException] unless partials were asked
/// for, and then the hooks that answered plus a timed-out entry for NAQP.
class _NaqpStuckHost extends FakeExtensionHost {
  _NaqpStuckHost(this.answered);

  final List<Map<String, dynamic>> answered;

  @override
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
    bool partialOnTimeout = false,
  }) async {
    if (!partialOnTimeout) throw HookTimeoutException('hook $category.$method* timed out after ${timeout.inMilliseconds}ms');
    return [
      ...answered,
      {'key': 'ham2k-naqp', 'ok': false, 'error': 'timed out after ${timeout.inMilliseconds}ms'},
    ];
  }
}

/// A runtime whose batch answer is missing an entry, which the host reports
/// as the runtime's bug rather than as any one hook failing.
class _BatchShortHost extends FakeExtensionHost {
  _BatchShortHost([super.stubs = const {}]);

  @override
  Future<List<Map<String, dynamic>>> invokeHookBatch(
    List<HookCall> calls, {
    Duration timeout = const Duration(seconds: 10),
    bool partialOnTimeout = false,
  }) async => throw StateError('the runtime answered a batch of ${calls.length} with no entry for call 0');
}

/// A runtime whose fan-out answer is not a list of entries, which the host
/// reads with a cast that throws.
class _GarbledHost extends FakeExtensionHost {
  @override
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
    bool partialOnTimeout = false,
  }) async => <Object>[42].cast<Map<String, dynamic>>().toList();
}

/// A service with no runtime up until [start] brings up [bootsTo] — which,
/// when null, is a runtime that failed to come up.
class _BootingExtensions extends ExtensionService {
  _BootingExtensions(this.bootsTo);

  final ExtensionHost? bootsTo;
  ExtensionHost? _host;

  @override
  ExtensionHost? get host => _host;

  @override
  Future<void> start() async {
    _host = bootsTo;
  }

  @override
  Future<void> setSyncCredentials({required String deviceKey, required String operatorCall}) async {}
}

void main() {
  setUp(ErrorReportingService.resetFailureStreaks);
  tearDown(ErrorReportingService.resetFailureStreaks);

  test('a stalled processQsoBeforeSave hook loses only its own patch', () async {
    final extensions = ExtensionServiceWithFakeHost(
      _NaqpStuckHost([
        {
          'key': 'ham2k-cqww',
          'ok': true,
          'value': {
            'their': {'exchange': '5'},
          },
          'refTypes': ['cqww'],
        },
      ]),
    );

    final qso = await extensions.decorateQsoBeforeSave(
      {
        'their': {'call': 'W1AW'},
      },
      {
        'refs': [
          {'type': 'cqww'},
          {'type': 'naqp'},
        ],
      },
    );
    expect(qso['their'], {'call': 'W1AW', 'exchange': '5'});
  });

  group('the add-activity search with no runtime up', () {
    test('waits for the runtime to come up and answers from it', () async {
      final extensions = _BootingExtensions(
        FakeExtensionHost({
          'activity:*:suggest': [
            {
              'key': 'ham2k-pota',
              'ok': true,
              'value': [_park],
            },
          ],
        }),
      );

      final result = await extensions.suggestActivities(const {'grid': 'FN21'});
      expect(result.suggestions.map((s) => s['ref']), ['US-0001']);
      expect(result.allSourcesFailed, isFalse);
    });

    test('says no extension could answer when none comes up', () async {
      final result = await _BootingExtensions(null).suggestActivities(const {'grid': 'FN21'});
      expect(result.suggestions, isEmpty);
      expect(result.allSourcesFailed, isTrue, reason: 'a dead runtime is not "nothing matched"');
    });
  });

  group('the add-activity search always ends', () {
    test('on an operation whose grid and station call are not strings, which it does not send', () async {
      Map<dynamic, dynamic>? asked;
      final extensions = ExtensionServiceWithFakeHost(
        FakeExtensionHost({
          'activity:*:suggest': (Object? args) {
            asked = args as Map;
            return [
              {
                'key': 'ham2k-pota',
                'ok': true,
                'value': [_park],
              },
            ];
          },
        }),
      );

      final result = await extensions.suggestActivities(const {'grid': 42, 'stationCall': 7});
      expect(result.suggestions.map((s) => s['ref']), ['US-0001']);
      // Neither is anything to search from: no settings, no fallback, so
      // nothing at all, never a `'7'` or a location made of a number.
      expect(asked, isNot(contains('callsign')));
      expect(asked, isNot(contains('location')));
    });

    test('on a runtime bug, as failed, reporting it once rather than per search', () async {
      final backend = FakeErrorReportingBackend();
      final results = <ActivitySuggestionResult>[];
      await withErrorHooks(() async {
        final extensions = ExtensionServiceWithFakeHost(_BatchShortHost());
        for (var i = 0; i < 3; i++) {
          results.add(await extensions.suggestActivities(const {'grid': 'FN21'}, activityKeys: const ['ham2k-pota']));
        }
      }, backend: backend);

      expect(results.map((r) => r.allSourcesFailed), everyElement(isTrue));
      expect(backend.exceptions.single.error, isA<StateError>(), reason: 'reported, not just absorbed, and not on every keystroke');
    });

    test('with what the others found when the preferred batch hits a runtime bug', () async {
      final backend = FakeErrorReportingBackend();
      late final ActivitySuggestionResult result;
      await withErrorHooks(() async {
        result = await ExtensionServiceWithFakeHost(
          _BatchShortHost({
            'activity:*:suggest': [
              {
                'key': 'ham2k-wwff',
                'ok': true,
                'value': [_park],
              },
            ],
          }),
        ).suggestActivities(const {'grid': 'FN21'}, preferredKeys: const ['ham2k-pota'], preferredSearchTerm: 'bear');
      }, backend: backend);

      expect(result.suggestions.map((s) => s['ref']), ['US-0001']);
      expect(backend.exceptions.single.error, isA<StateError>());
    });
  });

  test('controls the runtime answers garbled end as failed, not loading for good', () async {
    final backend = FakeErrorReportingBackend();
    late final ControlsResult result;
    await withErrorHooks(() async {
      result = await ExtensionServiceWithFakeHost(_GarbledHost()).loggingControls(const {});
    }, backend: backend);

    expect(result.loadFailed, isTrue);
    expect(backend.exceptions.single.error, isA<TypeError>());
  });

  test('controls that tie on order keep the order the extensions answered in', () async {
    // Past 32 elements `List.sort` is a quicksort, which reorders ties; this
    // many, with ties on both values, is what lets an unstable sort show.
    final answered = [
      for (var i = 0; i < 40; i++) {'key': 'c$i', 'label': 'c$i', if (i.isOdd) 'order': 1},
    ];
    final extensions = ExtensionServiceWithFakeHost(
      FakeExtensionHost({
        'activity:*:loggingControls': [
          {'key': 'ham2k-pota', 'ok': true, 'value': answered},
        ],
      }),
    );

    final result = await extensions.loggingControls(const {});
    expect(result.controls.map((c) => c['key']), [for (var i = 0; i < 40; i += 2) 'c$i', for (var i = 1; i < 40; i += 2) 'c$i']);
  });
}

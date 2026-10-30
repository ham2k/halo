// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Two ways an activity hook call can lose more than it has to. A save fans
// `processQsoBeforeSave` out under ONE timeout, so one stalled contest must
// cost only its own patch — not the exchange every other activity projected
// into the row and the ADIF export. And the add-activity search, asked while
// the runtime is booting or being replaced, has no host to ask: it must wait
// for one rather than answer "nothing matched", which the picker never asks
// again about, and with none at all say no extension could answer.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';

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
}

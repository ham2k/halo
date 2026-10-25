// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The nearby search asks every activity extension in one fan-out under one
// timeout. The trap: one extension stuck past it — POTA queued behind a busy
// database — must cost only its own answer, and must not read as "nothing
// nearby" when it was the one that would have answered. And with results on
// screen, nothing in the sheet says the list may be short — so the status bar
// names the one that did not answer, without reposting on every keystroke.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_extension_host.dart';

const _contestEntry = {'key': 'ham2k-cqww', 'ok': true, 'value': <Object>[]};
const _park = {'type': 'potaActivation', 'ref': 'US-0001', 'name': 'Bear Mountain'};

/// A host whose fan-out runs out its budget with POTA still out, answering as
/// the real host does: a [HookTimeoutException] unless partials were asked
/// for, and then the hooks that answered plus a timed-out entry for POTA.
class _PotaStuckHost extends FakeExtensionHost {
  _PotaStuckHost(this.answered);

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
      {'key': 'ham2k-pota', 'ok': false, 'error': 'timed out after ${timeout.inMilliseconds}ms'},
    ];
  }
}

void main() {
  test('one extension timing out keeps what the others found', () async {
    final extensions = ExtensionServiceWithFakeHost(
      _PotaStuckHost([
        {
          'key': 'ham2k-wwff',
          'ok': true,
          'value': [_park],
        },
      ]),
    );

    final result = await extensions.suggestActivities(const {'grid': 'FN21'});
    expect(result.suggestions.map((s) => s['ref']), ['US-0001']);
    expect(result.allSourcesFailed, isFalse);
    expect(result.someSourcesFailed, isTrue);
  });

  test('one extension timing out while the rest find nothing is told apart from nothing nearby', () async {
    final extensions = ExtensionServiceWithFakeHost(_PotaStuckHost(const [_contestEntry]));

    final result = await extensions.suggestActivities(const {'grid': 'FN21'});
    expect(result.suggestions, isEmpty);
    expect(result.someSourcesFailed, isTrue, reason: 'an empty list beside a failed POTA is not "no parks nearby"');
  });

  test('every extension answering is no failure at all', () async {
    final extensions = ExtensionServiceWithFakeHost(
      FakeExtensionHost({
        'activity:*:suggest': const [_contestEntry],
      }),
    );

    final result = await extensions.suggestActivities(const {'grid': 'FN21'});
    expect(result.allSourcesFailed, isFalse);
    expect(result.someSourcesFailed, isFalse);
  });

  group('the status bar', () {
    const failedKey = 'activity-search:failed';

    Future<(ExtensionServiceWithFakeHost, StatusBarService)> searching(List<Map<String, dynamic>> answered) async {
      SharedPreferences.setMockInitialValues({});
      final statusBar = StatusBarService(await SharedPreferences.getInstance());
      final extensions = ExtensionServiceWithFakeHost(_PotaStuckHost(answered))..statusBar = statusBar;
      return (extensions, statusBar);
    }

    test('names the extension that did not answer a search that found something, once in a while', () async {
      final (extensions, statusBar) = await searching([
        {
          'key': 'ham2k-wwff',
          'ok': true,
          'value': [_park],
        },
      ]);

      await extensions.suggestActivities(const {'grid': 'FN21'});
      expect(statusBar.itemForKey(failedKey)?.text, contains('ham2k-pota'));

      // The search runs again on the next pause in typing; a source that
      // stays down must not post every time.
      statusBar.clear(failedKey);
      await extensions.suggestActivities(const {'grid': 'FN21', 'lat': 41.0, 'lon': -73.0});
      expect(statusBar.itemForKey(failedKey), isNull);
    });

    test('says so when the fan-out failed whole beside a preferred extension that answered', () async {
      // A fan-out that failed before naming anyone leaves no extension to
      // name — and the sheet, holding the preferred one's results, says
      // nothing either.
      SharedPreferences.setMockInitialValues({});
      final statusBar = StatusBarService(await SharedPreferences.getInstance());
      final extensions = ExtensionServiceWithFakeHost(_FanOutDownHost())..statusBar = statusBar;

      final result = await extensions.suggestActivities(const {'grid': 'FN21'}, preferredKeys: const ['ham2k-pota'], preferredSearchTerm: 'bear');
      expect(result.suggestions, isNotEmpty);
      expect(statusBar.itemForKey(failedKey)?.text, isNotNull);
    });

    test('stays quiet when nothing was found, which the sheet already explains', () async {
      final (extensions, statusBar) = await searching(const [_contestEntry]);

      await extensions.suggestActivities(const {'grid': 'FN21'});
      expect(statusBar.itemForKey(failedKey), isNull);
    });
  });
}

/// A host whose everyone-else fan-out times out before the runtime named
/// anyone, while the preferred POTA batch answers.
class _FanOutDownHost extends FakeExtensionHost {
  @override
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
    bool partialOnTimeout = false,
  }) async => throw HookTimeoutException('hook $category.$method* timed out after ${timeout.inMilliseconds}ms');

  @override
  Future<List<Map<String, dynamic>>> invokeHookBatch(
    List<HookCall> calls, {
    Duration timeout = const Duration(seconds: 10),
    bool partialOnTimeout = false,
  }) async => [
    for (final (i, _) in calls.indexed)
      {
        'key': '$i',
        'ok': true,
        'value': [_park],
      },
  ];
}

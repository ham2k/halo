// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// FlagsService fetches per-callsign flag files and merges them into one map,
// then pushes qualifying notices. These tests verify the contract app-polo's
// fetchFeatureFlags established: the right file set is requested for a
// callsign+entity, files deep-merge most-specific-last (with `notices` arrays
// concatenating), a `more` pointer pulls in extra files, an unchanged
// callsign doesn't re-fetch, a timeout aborts the round, and evaluated
// notices reach the status bar exactly once (never resurrecting a dismissed
// one). The fetcher and annotator are injected — no network, no JS runtime.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/flags_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StatusBarService statusBar;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    statusBar = StatusBarService(await SharedPreferences.getInstance());
  });

  const env = NoticeEnvironment(
    appVersion: '26.8.0',
    appVersionName: "August '26",
    appBuild: '1234',
    platform: 'macos',
  );

  /// Builds a service whose fetcher serves [files] (keyed by location) and
  /// records the request order, annotating any call to [guess].
  ({FlagsService service, List<String> requested}) build(
    Map<String, Map<String, dynamic>> files, {
    Map<String, dynamic>? guess = const {'baseCall': 'KI2D', 'entityPrefix': 'K', 'continent': 'NA'},
    Set<String> timeoutAt = const {},
  }) {
    final requested = <String>[];
    final service = FlagsService(
      statusBar: statusBar,
      baseUrl: 'https://example.test/flags',
      annotate: guess == null ? null : (_) async => guess,
      environmentProvider: () async => env,
      fetcher: (location) async {
        requested.add(location);
        if (timeoutAt.contains(location)) throw TimeoutException('slow');
        return files[location];
      },
    );
    return (service: service, requested: requested);
  }

  group('location selection', () {
    test('fetches defaults, entity, and call files for a plain call', () async {
      final b = build({'defaults.json': {}, 'entities/k.json': {}, 'ki/ki2d.json': {}});
      await b.service.refreshForCall('KI2D');
      // cleanCall == cleanBaseCall, so no separate base-call file.
      expect(b.requested, ['defaults.json', 'entities/k.json', 'ki/ki2d.json']);
    });

    test('adds a base-call file when the entered call has a suffix', () async {
      final b = build(
        {'defaults.json': {}, 'entities/k.json': {}, 'ki/ki2d.json': {}, 'ki/ki2d-p.json': {}},
        guess: {'baseCall': 'KI2D', 'entityPrefix': 'K'},
      );
      await b.service.refreshForCall('KI2D/P');
      expect(b.requested, ['defaults.json', 'entities/k.json', 'ki/ki2d.json', 'ki/ki2d-p.json']);
    });

    test('fetches only defaults when there is no callsign', () async {
      final b = build({'defaults.json': {}});
      await b.service.refreshForCall('');
      expect(b.requested, ['defaults.json']);
    });
  });

  group('merging', () {
    test('deep-merges most-specific-last and concatenates arrays', () async {
      final b = build({
        'defaults.json': {
          'services': {'hamdb': true},
          'latestRelease': '26.6',
          'notices': [
            {'key': 'd1', 'text': 'x'},
          ],
        },
        'entities/k.json': {},
        'ki/ki2d.json': {
          'services': {'pota': true},
          'latestRelease': '25.9', // overrides the scalar
          'notices': [
            {'key': 'c1', 'text': 'x'},
          ],
        },
      });
      await b.service.refreshForCall('KI2D');
      final flags = b.service.flags;
      expect(flags['services'], {'hamdb': true, 'pota': true});
      expect(flags['latestRelease'], '25.9');
      expect((flags['notices'] as List).map((n) => n['key']), ['d1', 'c1']);
    });

    test('follows a `more` pointer', () async {
      final b = build({
        'defaults.json': {'more': 'extra/promo.json'},
        'entities/k.json': {},
        'ki/ki2d.json': {},
        'extra/promo.json': {'promo': true},
      });
      await b.service.refreshForCall('KI2D');
      expect(b.requested, contains('extra/promo.json'));
      expect(b.service.flags['promo'], true);
    });
  });

  group('refresh deduplication', () {
    test('does not re-fetch when the callsign is unchanged', () async {
      final b = build({'defaults.json': {}, 'entities/k.json': {}, 'ki/ki2d.json': {}});
      await b.service.refreshForCall('KI2D');
      final firstCount = b.requested.length;
      await b.service.refreshForCall('ki2d'); // same call, different case
      expect(b.requested.length, firstCount);
    });

    test('force re-fetches the same callsign', () async {
      final b = build({'defaults.json': {}, 'entities/k.json': {}, 'ki/ki2d.json': {}});
      await b.service.refreshForCall('KI2D');
      final firstCount = b.requested.length;
      await b.service.refreshForCall('KI2D', force: true);
      expect(b.requested.length, greaterThan(firstCount));
    });

    test('runs a refresh requested while one is in flight', () async {
      final gate = Completer<void>();
      final requested = <String>[];
      final service = FlagsService(
        statusBar: statusBar,
        baseUrl: 'https://example.test/flags',
        annotate: (call) async => {'baseCall': call, 'entityPrefix': 'K'},
        environmentProvider: () async => env,
        fetcher: (location) async {
          requested.add(location);
          if (location == 'defaults.json' && !gate.isCompleted) await gate.future;
          return {};
        },
      );

      final first = service.refreshForCall('KI2D'); // blocks on the gate
      await Future<void>.delayed(Duration.zero);
      final second = service.refreshForCall('W1AW'); // queued
      gate.complete();
      await Future.wait([first, second]);
      // The queued follow-up is fire-and-forget from the first round's
      // `finally`; give it time to run to completion.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(requested, contains('w1/w1aw.json'));
    });
  });

  group('failure handling', () {
    test('preserves previous flags (and stays retryable) when every fetch fails', () async {
      var failing = false;
      final requested = <String>[];
      final service = FlagsService(
        statusBar: statusBar,
        baseUrl: 'https://example.test/flags',
        annotate: (call) async => {'baseCall': call, 'entityPrefix': 'K'},
        environmentProvider: () async => env,
        fetcher: (location) async {
          requested.add(location);
          if (failing) throw Exception('offline');
          return {'latestRelease': '26.8'};
        },
      );

      await service.refreshForCall('KI2D');
      expect(service.flags['latestRelease'], '26.8');

      // Network goes down; a refresh for a NEW callsign fails entirely.
      failing = true;
      await service.refreshForCall('W1AW');
      // Old flags survive rather than being wiped to {}.
      expect(service.flags['latestRelease'], '26.8');

      // The failed callsign wasn't recorded, so it retries once back online.
      failing = false;
      requested.clear();
      await service.refreshForCall('W1AW');
      expect(requested, isNotEmpty);
      expect(service.flags['latestRelease'], '26.8');
    });

    test('a timeout aborts the round but keeps prior flags', () async {
      final b = build(
        {'defaults.json': {'a': 1}, 'entities/k.json': {}, 'ki/ki2d.json': {'b': 2}},
        timeoutAt: {'entities/k.json'},
      );
      await b.service.refreshForCall('KI2D');
      // Stopped at the timeout: defaults merged, ki/ki2d.json never requested.
      expect(b.service.flags['a'], 1);
      expect(b.service.flags.containsKey('b'), isFalse);
      expect(b.requested, ['defaults.json', 'entities/k.json']);
    });
  });

  group('notice pushing', () {
    Map<String, dynamic> plea(String key) => {
          'key': key,
          'title': 'Help',
          'text': 'Support Ham2K',
          'versions': ['26.8'],
        };

    test('combines `notices` and `halo-notices`', () async {
      final b = build({
        'defaults.json': {
          'notices': [plea('shared')],
          'halo-notices': [plea('halo-only')],
        },
        'entities/k.json': {},
        'ki/ki2d.json': {},
      });
      await b.service.refreshForCall('KI2D');
      expect(statusBar.activeNotices.map((n) => n.key), containsAll(['shared', 'halo-only']));
    });

    test('halo-notices take precedence over notices for a shared key', () async {
      final b = build({
        'defaults.json': {
          'notices': [
            {'key': 'k', 'title': 'from-notices', 'text': 'x', 'versions': ['26.8']},
          ],
          'halo-notices': [
            {'key': 'k', 'title': 'from-halo', 'text': 'x', 'versions': ['26.8']},
          ],
        },
        'entities/k.json': {},
        'ki/ki2d.json': {},
      });
      await b.service.refreshForCall('KI2D');
      // One active notice for key 'k', and it's the HaLo-specific one.
      expect(statusBar.activeNotices.where((n) => n.key == 'k'), hasLength(1));
      expect(statusBar.activeNotices.single.title, 'from-halo');
    });

    test('pushes qualifying notices from halo-notices alone', () async {
      final b = build({
        'defaults.json': {
          'halo-notices': [plea('halo-only')],
        },
        'entities/k.json': {},
        'ki/ki2d.json': {},
      });
      await b.service.refreshForCall('KI2D');
      expect(statusBar.activeNotices.map((n) => n.key), ['halo-only']);
    });

    test('pushes a qualifying notice to the status bar', () async {
      final b = build({
        'defaults.json': {'notices': [plea('plea')]},
        'entities/k.json': {},
        'ki/ki2d.json': {},
      });
      await b.service.refreshForCall('KI2D');
      expect(statusBar.activeNotices.map((n) => n.key), ['plea']);
    });

    test('does not push a notice targeted at another version', () async {
      final b = build({
        'defaults.json': {
          'notices': [
            {'key': 'old', 'text': 'x', 'versions': ['26.6']},
          ],
        },
        'entities/k.json': {},
        'ki/ki2d.json': {},
      });
      await b.service.refreshForCall('KI2D');
      expect(statusBar.activeNotices, isEmpty);
    });

    test('does not resurrect a dismissed notice on re-fetch', () async {
      final b = build({
        'defaults.json': {'notices': [plea('plea')]},
        'entities/k.json': {},
        'ki/ki2d.json': {},
      });
      await b.service.refreshForCall('KI2D');
      statusBar.dismissNotice('plea');
      expect(statusBar.activeNotices, isEmpty);

      await b.service.refreshForCall('KI2D', force: true);
      expect(statusBar.activeNotices, isEmpty);
      // Still just the one historical entry, now dismissed.
      expect(statusBar.history.where((n) => n.key == 'plea').length, 1);
    });

    test('does not reset an already-active notice on re-fetch', () async {
      final b = build({
        'defaults.json': {'notices': [plea('plea')]},
        'entities/k.json': {},
        'ki/ki2d.json': {},
      });
      await b.service.refreshForCall('KI2D');
      final createdAt = statusBar.activeNotices.single.createdAt;
      await b.service.refreshForCall('KI2D', force: true);
      expect(statusBar.activeNotices.single.createdAt, createdAt);
    });

    test('builds action buttons that dismiss and dispatch', () async {
      String? actedKey;
      Map<String, dynamic>? actedAction;
      final requested = <String>[];
      final service = FlagsService(
        statusBar: statusBar,
        baseUrl: 'https://example.test/flags',
        annotate: (_) async => {'baseCall': 'KI2D', 'entityPrefix': 'K'},
        environmentProvider: () async => env,
        onNoticeAction: (key, action) {
          actedKey = key;
          actedAction = action;
        },
        fetcher: (location) async {
          requested.add(location);
          if (location == 'defaults.json') {
            return {
              'notices': [
                {
                  'key': 'plea',
                  'text': 'x',
                  'versions': ['26.8'],
                  'actions': [
                    {'label': 'Give', 'action': 'link', 'args': {'url': 'https://ham2k.com'}},
                  ],
                },
              ],
            };
          }
          return {};
        },
      );

      await service.refreshForCall('KI2D');
      final notice = statusBar.activeNotices.single;
      expect(notice.actions.single.label, 'Give');

      notice.actions.single.onTap();
      expect(statusBar.activeNotices, isEmpty); // dismissed
      expect(actedKey, 'plea');
      expect(actedAction?['action'], 'link');
    });
  });
}

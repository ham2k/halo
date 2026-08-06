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
import 'package:ham2k_logger/config/version.dart';
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
    appCodePush: '',
    appSha: 'abc123',
    platform: 'macos',
  );

  group('the environment a real build reports', () {
    test('an official build reports the release build number, not the native metadata', () async {
      // A `builds` rule is authored against a RELEASED build number, so the
      // environment must report that same number. package_info_plus reports
      // the native one: `1` on any local run, and frozen at the shipped value
      // after a Shorebird patch — a rule naming the patched build would miss
      // every install it was written for.
      final e = await FlagsService.defaultNoticeEnvironment(
        edition: Edition.next,
        build: 126,
        sha: '04e3d1',
      );
      expect(e.appBuild, '126');
      expect(e.appSha, '04e3d1');
      expect(e.appVersion, kPublicVersion);
    });

    test('a Dev build reports no build number, so a release rule cannot fire on it', () async {
      // kBuildNumber in a Dev build names the last RELEASE. Dev is what the
      // hosted web app, every preview deploy and every local run are, so
      // reporting it would fire `builds: ["126"]` on all of them at once.
      final e = await FlagsService.defaultNoticeEnvironment(
        edition: Edition.dev,
        build: 126,
        sha: '04e3d1',
      );
      expect(e.appBuild, isEmpty);
      // The SHA is what remains to target it by — it names the running commit.
      expect(e.appSha, '04e3d1');
    });

    test('the code push is reported on its own, leaving the build number bare', () async {
      // The build must NOT become '126.2'. Both are matched by exact string
      // membership, so merging them would silently retire every existing
      // `builds` rule the first time a code push shipped.
      final e = await FlagsService.defaultNoticeEnvironment(
        edition: Edition.next,
        build: 126,
        sha: '04e3d1',
        codePush: 2,
      );
      expect(e.appBuild, '126');
      expect(e.appCodePush, '2');
    });

    test('a Dev build DOES report its code push, unlike its build number', () async {
      // The two are suppressed for opposite reasons: kBuildNumber is compiled
      // in and names the last release, while the code push is read from the
      // running updater and names this install. A Dev build carrying a push is
      // a real release build, and reachable by a rule.
      final e = await FlagsService.defaultNoticeEnvironment(
        edition: Edition.dev,
        build: 126,
        sha: '04e3d1',
        codePush: 2,
      );
      expect(e.appBuild, isEmpty);
      expect(e.appCodePush, '2');
    });

    test('no code push applied reports empty, not "0"', () async {
      // '0' would be a matchable value: a `codePushes: ["0"]` rule would then
      // hit every web, debug and local build at once.
      final e = await FlagsService.defaultNoticeEnvironment(edition: Edition.next, build: 126, sha: '');
      expect(e.appCodePush, isEmpty);
    });
  });

  /// Builds a service whose fetcher serves [files] (keyed by location) and
  /// records the request order, annotating any call to [guess].
  ///
  /// [isReleaseBuild] defaults to true — a test binary is always a debug
  /// build, so without it every update-available assertion would be checking
  /// the dev-build gate rather than the behavior it was written for.
  ({FlagsService service, List<String> requested}) build(
    Map<String, Map<String, dynamic>> files, {
    Map<String, dynamic>? guess = const {'baseCall': 'KI2D', 'entityPrefix': 'K', 'continent': 'NA'},
    Set<String> timeoutAt = const {},
    bool isReleaseBuild = true,
  }) {
    final requested = <String>[];
    final service = FlagsService(
      statusBar: statusBar,
      baseUrl: 'https://example.test/flags',
      annotate: guess == null ? null : (_) async => guess,
      environmentProvider: () async => env,
      isReleaseBuild: isReleaseBuild,
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

    test('the environment\'s SHA reaches the shas filter', () async {
      // The one assignment carrying appSha from the environment into the
      // matcher. Without it the whole feature is inert in the real app while
      // every unit test of the filter still passes, because those build a
      // NoticeContext directly.
      final b = build({
        'defaults.json': {
          'halo-notices': [
            {...plea('mine'), 'shas': ['abc123']},
            {...plea('theirs'), 'shas': ['deadbe']},
          ],
        },
        'entities/k.json': {},
        'ki/ki2d.json': {},
      });
      await b.service.refreshForCall('KI2D');
      expect(statusBar.activeNotices.map((n) => n.key), ['mine']);
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
        isReleaseBuild: true,
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

  group('update-available notice (latestRelease)', () {
    // env.appVersion is 26.8.0 (see the shared `env` above).
    test('prompts when latestRelease names a newer binary', () async {
      final b = build({
        'defaults.json': {'latestRelease': '26.9'},
        'entities/k.json': {},
        'ki/ki2d.json': {},
      });
      await b.service.refreshForCall('KI2D');

      final notice = statusBar.activeNotices.single;
      expect(notice.key, 'update:version');
      expect(notice.title, 'Update available');
      expect(notice.text, contains('26.9'));
      expect(notice.actions.single.label, 'Get it');
    });

    test('never prompts on a dev build, however far ahead the release is', () async {
      // A working copy updates by pulling, not by downloading a binary, and
      // its version is whatever the branch says — so a released latestRelease
      // routinely outranks it and would nag on every local run. The hosted
      // dev web app is a RELEASE build, which is why the gate is build mode
      // and not the Dev edition.
      final b = build({
        'defaults.json': {'latestRelease': '99.9'},
        'entities/k.json': {},
        'ki/ki2d.json': {},
      }, isReleaseBuild: false);
      await b.service.refreshForCall('KI2D');
      expect(statusBar.activeNotices, isEmpty);
    });

    test('a dev build clears a notice an earlier build left in the footer', () async {
      // Notices persist, so gating the push alone would leave one already on
      // file sitting there for every launch from now on. Cleared at
      // construction, not on refresh — an offline launch never refreshes.
      statusBar.showNotice(
        key: 'update:version',
        title: 'Update available',
        text: 'A new version (26.9) is available.',
      );
      build({'defaults.json': {}}, isReleaseBuild: false);
      expect(statusBar.activeNotices, isEmpty);
    });

    test("a dev build's cleanup is not read as the operator dismissing it", () async {
      // A debug and a shipped build share one prefs domain on desktop, so the
      // clear above lands in the very store the shipped build reads back. Left
      // holding `update:shownVersion`, that store says "a notice for 26.9 was
      // showing, and it is now dismissed" — which the promotion path takes for
      // the operator's own dismissal and writes into the durable high-water
      // mark, silencing the real notice for good.
      final prefs = await SharedPreferences.getInstance();
      FlagsService shipped() => FlagsService(
            statusBar: statusBar,
            baseUrl: 'https://example.test/flags',
            annotate: (_) async => {'baseCall': 'KI2D', 'entityPrefix': 'K'},
            environmentProvider: () async => env,
            isReleaseBuild: true,
            prefs: prefs,
            fetcher: (location) async =>
                location == 'defaults.json' ? {'latestRelease': '26.9'} : {},
          );

      await shipped().refreshForCall('KI2D');
      expect(statusBar.activeNotices.single.key, 'update:version');

      // A local `flutter run` against that same prefs clears the footer.
      FlagsService(statusBar: statusBar, prefs: prefs, isReleaseBuild: false);
      expect(statusBar.activeNotices, isEmpty);

      // Back on the shipped build: same release, still never dismissed by
      // anyone, so it is still worth telling the operator about.
      await shipped().refreshForCall('KI2D');
      expect(statusBar.activeNotices.single.text, contains('26.9'));
      expect(prefs.getString('update:dismissedVersion'), isNull);
    });

    test('stays quiet when latestRelease is the same line or older', () async {
      // 26.8 is the line 26.8.0 is already on — not a newer binary.
      final b = build({
        'defaults.json': {'latestRelease': '26.8'},
        'entities/k.json': {},
        'ki/ki2d.json': {},
      });
      await b.service.refreshForCall('KI2D');
      expect(statusBar.activeNotices, isEmpty);
    });

    test('"Get it" opens latestReleaseUrl through the shared link action', () async {
      String? actedKey;
      Map<String, dynamic>? actedAction;
      final service = FlagsService(
        statusBar: statusBar,
        baseUrl: 'https://example.test/flags',
        annotate: (_) async => {'baseCall': 'KI2D', 'entityPrefix': 'K'},
        environmentProvider: () async => env,
        isReleaseBuild: true,
        onNoticeAction: (key, action) {
          actedKey = key;
          actedAction = action;
        },
        fetcher: (location) async => location == 'defaults.json'
            ? {'latestRelease': '26.9', 'latestReleaseUrl': 'https://ham2k.com/halo'}
            : {},
      );

      await service.refreshForCall('KI2D');
      statusBar.activeNotices.single.actions.single.onTap();

      expect(statusBar.activeNotices, isEmpty); // tapping dismisses it
      expect(actedKey, 'update:version');
      expect(actedAction?['action'], 'link');
      expect((actedAction?['args'] as Map)['url'], 'https://ham2k.com/halo');
    });

    test('falls back to the Ham2K site when no latestReleaseUrl is set', () async {
      Map<String, dynamic>? actedAction;
      final service = FlagsService(
        statusBar: statusBar,
        baseUrl: 'https://example.test/flags',
        annotate: (_) async => {'baseCall': 'KI2D', 'entityPrefix': 'K'},
        environmentProvider: () async => env,
        isReleaseBuild: true,
        onNoticeAction: (_, action) => actedAction = action,
        fetcher: (location) async =>
            location == 'defaults.json' ? {'latestRelease': '26.9'} : {},
      );

      await service.refreshForCall('KI2D');
      statusBar.activeNotices.single.actions.single.onTap();
      expect((actedAction?['args'] as Map)['url'], 'https://ham2k.com');
    });

    test('a newer release replaces the notice instead of stacking a second', () async {
      var latest = '26.9';
      final service = FlagsService(
        statusBar: statusBar,
        baseUrl: 'https://example.test/flags',
        annotate: (_) async => {'baseCall': 'KI2D', 'entityPrefix': 'K'},
        environmentProvider: () async => env,
        isReleaseBuild: true,
        fetcher: (location) async =>
            location == 'defaults.json' ? {'latestRelease': latest} : {},
      );

      await service.refreshForCall('KI2D');
      expect(statusBar.activeNotices.single.text, contains('26.9'));

      latest = '26.10';
      await service.refreshForCall('KI2D', force: true);

      // One notice, updated in place — not two stacked.
      expect(statusBar.activeNotices, hasLength(1));
      expect(statusBar.activeNotices.single.text, contains('26.10'));
    });

    test('a dismissal persists in prefs, and only a newer release re-notifies', () async {
      // statusBar (from setUp) and the service share this same mock prefs.
      final prefs = await SharedPreferences.getInstance();
      var latest = '26.9';
      final service = FlagsService(
        statusBar: statusBar,
        baseUrl: 'https://example.test/flags',
        annotate: (_) async => {'baseCall': 'KI2D', 'entityPrefix': 'K'},
        environmentProvider: () async => env,
        isReleaseBuild: true,
        prefs: prefs,
        fetcher: (location) async =>
            location == 'defaults.json' ? {'latestRelease': latest} : {},
      );

      await service.refreshForCall('KI2D');
      statusBar.dismissNotice('update:version'); // user dismisses

      // Same release: stays dismissed, and the dismissal is now durable in prefs
      // (so it survives the capped status-bar history, unlike before).
      await service.refreshForCall('KI2D', force: true);
      expect(statusBar.activeNotices, isEmpty);
      expect(prefs.getString('update:dismissedVersion'), '26.9');

      // A genuinely newer release breaks through the dismissal.
      latest = '26.10';
      await service.refreshForCall('KI2D', force: true);
      expect(statusBar.activeNotices.single.text, contains('26.10'));
    });
  });
}

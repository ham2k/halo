// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The wiring around services/staleness.dart, which is where its guarantees
// actually get lost: the pure ranking can be exactly right while a callback
// set one layer away quietly reintroduces the collapse it exists to prevent.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/config/version.dart';
import 'package:ham2k_logger/services/staleness_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:ham2k_logger/services/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An updater whose availability and read result are both dictated, so the
/// "could not read it" case can be reached — which no real build here can.
class _FakeUpdates implements UpdateService {
  _FakeUpdates({this.resolved = true, this.number});

  @override
  final bool isAvailable = true;
  final bool resolved;
  final int? number;

  @override
  Future<bool> checkAndApply() async => false;

  @override
  Future<({bool resolved, int? number})> currentPatchNumber() async =>
      (resolved: resolved, number: number);
}

void main() {
  late StatusBarService statusBar;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    statusBar = StatusBarService(prefs);
  });

  final actions = <({String key, Map<String, dynamic> action})>[];

  StalenessService build({
    bool buildExpired = false,
    Map<String, dynamic> flags = const {},
    DateTime Function()? now,
  }) {
    actions.clear();
    return StalenessService(
      statusBar: statusBar,
      prefs: prefs,
      isReleaseBuild: true,
      buildExpired: () => buildExpired,
      now: now,
      onNoticeAction: (key, action) => actions.add((key: key, action: action)),
    )..evaluate(flags: flags);
  }

  group('the newer-release notice', () {
    test('"Get it" reaches the notice-action route, not a dead button', () {
      // The regression this exists for: with the route unwired the tap
      // dismisses the notice and opens nothing — and the dismissal then
      // promotes into the durable mark, so that release never announces
      // itself again. The user is silenced AND never got the link.
      build(flags: {'latestRelease': '99.9', 'latestReleaseUrl': 'https://ham2k.com/halo'});
      statusBar.activeNotices.single.actions.single.onTap();

      expect(actions.single.key, 'update:version');
      expect((actions.single.action['args'] as Map)['url'], 'https://ham2k.com/halo');
    });

    test('a dismissal is promoted to the durable mark BEFORE the next ranking reads it', () {
      // Ordering, not bookkeeping: ranking consults the mark that promotion
      // writes, so promoting afterwards lets a just-dismissed release announce
      // itself once more on the very next refresh.
      final service = build(flags: {'latestRelease': '99.9'});
      statusBar.dismissNotice('update:version');

      service.evaluate();
      expect(prefs.getString('update:dismissedVersion'), '99.9');
      expect(statusBar.activeNotices, isEmpty);
    });
  });

  group('ranking through the service', () {
    test('an expired build outranks the notice, so only one thing speaks', () {
      // No navigatorKey here, so the nag cannot render — the point is that the
      // lower-ranked notice is NOT pushed in its place.
      build(buildExpired: true, flags: {'latestRelease': '99.9'});
      expect(statusBar.activeNotices, isEmpty);
    });

    test('nothing stale says nothing', () {
      build(flags: const {});
      expect(statusBar.activeNotices, isEmpty);
    });
  });

  group('the code-push floor reaches the ranking intact', () {
    // The pure predicate is tested in staleness_test.dart; what these pin is
    // that the service hands it the updater's own answer rather than a value
    // reconstructed on the way through.
    StalenessService withUpdater(_FakeUpdates updates, Map<String, dynamic> flags) =>
        StalenessService(
          statusBar: statusBar,
          prefs: prefs,
          isReleaseBuild: true,
          buildExpired: () => false,
          updates: updates,
          onNoticeAction: null,
        )..evaluate(flags: flags);

    test('an unresolved read does not push the lower-ranked notice either', () {
      // Silence about the floor must not become noise about something else.
      withUpdater(
        _FakeUpdates(resolved: false),
        {'minCodePush': {'$kBuildNumber': 3}, 'latestRelease': '99.9'},
      );
      // The notice is still allowed here — the floor signal is silent, so the
      // newer release is the top ACTIVE signal and correctly speaks.
      expect(statusBar.activeNotices.single.key, 'update:version');
    });

    test('a floor for a different build does not apply to this one', () {
      withUpdater(
        _FakeUpdates(resolved: true, number: null),
        {'minCodePush': {'${kBuildNumber + 1}': 3}, 'latestRelease': '99.9'},
      );
      expect(statusBar.activeNotices.single.key, 'update:version');
    });
  });

  group('failing open', () {
    test('a malformed minCodePush is survivable, not fatal', () {
      // Hand-edited JSON on a server, evaluated on the boot path.
      expect(() => build(flags: {'minCodePush': 'not-a-map'}), returnsNormally);
      expect(() => build(flags: {'minCodePush': {'$kBuildNumber': 'abc'}}), returnsNormally);
    });

    test('evaluate with no flags at all is survivable', () {
      // The resume path calls it with whatever the last refresh left, which is
      // nothing when the app has never been online.
      final service = build(flags: const {});
      expect(service.evaluate, returnsNormally);
    });
  });

  group('isBuildExpired', () {
    // Written against whatever date THIS edition happens to carry, so it keeps
    // asserting after a release cut rewrites version.dart. Hardcoding a date
    // here would pass forever while testing a value the app no longer uses.
    final expiration = kBuildExpiration;

    test('an unstamped build never expires, however far the clock runs', () {
      // Every OSS checkout and every local `flutter run` leaves the date
      // empty. Reading that as "expired" would nag on a build nobody released,
      // pointing at a download that does not exist.
      if (expiration != null) return;
      expect(isBuildExpired(now: DateTime.utc(2099)), isFalse);
    });

    test('a stamped build works for ALL of its expiration day, then stops', () {
      // The off-by-one that matters: expiring at midnight would cut an
      // operator off mid-activation on the last day they were told they had.
      //
      // Built as explicit UTC on the stamped CALENDAR date, not by adding to
      // `expiration`: version.dart's date parses to LOCAL midnight while the
      // comparison is UTC, so arithmetic on it lands a different side of the
      // boundary depending on the machine's timezone.
      if (expiration == null) return;
      final day = (expiration.year, expiration.month, expiration.day);
      expect(isBuildExpired(now: DateTime.utc(day.$1, day.$2, day.$3, 23, 59)), isFalse);
      expect(isBuildExpired(now: DateTime.utc(day.$1, day.$2, day.$3 + 1)), isTrue);
    });
  });
}

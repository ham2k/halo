// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// AutoUpdateService's once-per-process feed URL contract.
//
// `setFeedURL` is not idempotent on Windows: auto_updater_windows registers
// the Flutter event sink inside that handler by *moving* its unique_ptr, so a
// second call leaves WinSparkle with a null sink and drops every later native
// callback — checkSilently() then times out and the About row reports "up to
// date" whatever the appcast says. Nothing about that is visible from macOS or
// from a plain read of the Dart, which is why it needs pinning here.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_updater_platform_interface/auto_updater_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:ham2k_logger/config/version.dart' show kBuildNumber, kEdition;
import 'package:ham2k_logger/services/auto_update_service.dart';

/// Stands in for the native plugin, counting calls and answering each check
/// with the terminal event the real updater would fire.
class _FakeAutoUpdaterPlatform extends AutoUpdaterPlatform with MockPlatformInterfaceMixin {
  final _events = StreamController<Map<Object?, Object?>>.broadcast();

  final List<String> feedUrls = [];
  int checkCalls = 0;
  final List<int> intervals = [];

  /// Every native call in the order it arrived. The WinSparkle shim has to run
  /// BEFORE setFeedURL (the plugin runs win_sparkle_init in that handler), and
  /// order is the only way to see that.
  final List<String> events = [];

  /// Fails the next [setFeedURL], as an offline box would at boot.
  bool failNextFeedUrl = false;

  void reset() {
    feedUrls.clear();
    intervals.clear();
    events.clear();
    checkCalls = 0;
    failNextFeedUrl = false;
  }

  @override
  Stream<Map<Object?, Object?>> get sparkleEvents => _events.stream;

  @override
  Future<void> setFeedURL(String feedUrl) async {
    if (failNextFeedUrl) {
      failNextFeedUrl = false;
      throw Exception('no route to host');
    }
    feedUrls.add(feedUrl);
    events.add('setFeedURL');
  }

  @override
  Future<void> checkForUpdates({bool? inBackground}) async {
    checkCalls++;
    _events.add({'type': 'update-not-available'});
  }

  @override
  Future<void> setScheduledCheckInterval(int interval) async {
    intervals.add(interval);
    events.add('setScheduledCheckInterval');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // One platform for the whole file, installed before anything touches
  // `autoUpdater`: the AutoUpdater singleton subscribes to
  // AutoUpdaterPlatform.instance.sparkleEvents exactly once, on first access,
  // so a per-test replacement would leave every test after the first
  // listening to a dead stream and timing out.
  final platform = _FakeAutoUpdaterPlatform();
  AutoUpdaterPlatform.instance = platform;

  /// Stands in for the Windows-only FFI shim, logging into the same ordered
  /// event list as the fake plugin. [applied] is what the real one returns:
  /// true on Windows, false everywhere else.
  ({List<String> builds, List<bool> automatic}) installShimStub({required bool applied}) {
    final builds = <String>[];
    final automatic = <bool>[];
    AutoUpdateService.debugConfigureWinSparkle = ({
      required String buildVersion,
      required int checkIntervalSeconds,
      required bool automaticChecks,
    }) {
      builds.add(buildVersion);
      automatic.add(automaticChecks);
      platform.events.add('winSparkleConfig');
      return applied;
    };
    return (builds: builds, automatic: automatic);
  }

  setUp(() {
    platform.reset();
    AutoUpdateService.debugSupportedOverride = true;
    AutoUpdateService.debugResetConfiguration();
    // Every test runs with debugSupportedOverride on, so without a stub here
    // the tests that don't install their own would reach the REAL shim — and
    // on a Windows dev box that means DynamicLibrary.open inside
    // flutter_tester, throwing and filing an error report from a unit test.
    // False is what the real one returns off Windows, so the plugin keeps the
    // interval, exactly as those tests already assert.
    installShimStub(applied: false);
  });

  tearDown(() {
    AutoUpdateService.debugSupportedOverride = null;
    AutoUpdateService.debugConfigureWinSparkle = null;
    AutoUpdateService.debugResetConfiguration();
  });

  /// Stands in for the Windows-only FFI shim, logging into the same ordered
  /// event list as the fake plugin. [applied] is what the real one returns:
  /// true on Windows, false everywhere else.

  test('sets the feed URL once across a boot and repeated checks', () async {
    const service = AutoUpdateService();

    await service.start();
    await service.checkSilently();
    await service.checkSilently();
    await service.checkForUpdatesInteractively();

    // A second setFeedURL is what kills the Windows event sink — the count,
    // not the URL, is the whole point of this test.
    expect(platform.feedUrls, [service.feedUrl]);
    expect(platform.intervals, hasLength(1));
    expect(platform.checkCalls, 3);
  });

  test('concurrent callers share the one call rather than racing into two', () async {
    const service = AutoUpdateService();

    await Future.wait([service.start(), service.checkSilently()]);

    expect(platform.feedUrls, hasLength(1));
  });

  test('a failed setFeedURL is not memoized, so a later check retries', () async {
    const service = AutoUpdateService();
    platform.failNextFeedUrl = true;

    await service.start(); // swallows the failure; must not strand what follows

    expect(platform.feedUrls, isEmpty);

    final result = await service.checkSilently();

    expect(platform.feedUrls, [service.feedUrl]);
    expect(result, SparkleCheckResult.upToDate);
    // The retry must restore the WHOLE configuration, not just the feed URL.
    // Only start() ever asked for the interval, and start() already failed and
    // will not run again — so if the retry skipped it, the process would sit
    // on the native default (a day) for its entire life, with nothing left to
    // notice or correct it.
    expect(platform.intervals, hasLength(1));
  });

  group('platform gating', () {
    test('is unsupported in a debug build', () {
      AutoUpdateService.debugSupportedOverride = null;
      // Only the kDebugMode branch: every test binary is a debug build, so the
      // kIsWeb, Dev-edition and platform gates are unreachable from here — do
      // not read this as covering them.
      expect(const AutoUpdateService().isSupported, isFalse);
    });

    test('the supported-override cannot escape a debug build', () {
      // The override short-circuits every gate, so shipping it live would let
      // a stray write point Sparkle at a feed the build has no business
      // polling. kDebugMode is true here, so this pins the wiring, not the
      // guard itself — the guard is what keeps the field inert in release.
      AutoUpdateService.debugSupportedOverride = true;
      expect(const AutoUpdateService().isSupported, isTrue);
      AutoUpdateService.debugSupportedOverride = false;
      expect(const AutoUpdateService().isSupported, isFalse);
    });

    test('the automatic-check setting is ours on Windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(const AutoUpdateService().ownsAutomaticCheckSetting, isTrue);
    });

    test('the automatic-check setting is NOT ours on macOS', () {
      // Sparkle asks the operator directly and we bind nothing for it there,
      // so showing the switch would be showing a control that changes
      // nothing. Inverting this check is otherwise invisible: the row simply
      // starts appearing on a platform where it does not work.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(const AutoUpdateService().ownsAutomaticCheckSetting, isFalse);
    });

    test('nothing is ours on a build with no self-update at all', () {
      // The isSupported conjunct: a Windows debug/Dev build has no appcast, so
      // offering the switch would promise checks that can never run.
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      AutoUpdateService.debugSupportedOverride = false;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(const AutoUpdateService().ownsAutomaticCheckSetting, isFalse);
    });

    test('names the exact appcast path this build polls', () {
      // Spelled out in full deliberately. Every installed app polls the URL
      // baked into it, so renaming a segment here strands every existing
      // install on a path that 404s silently and forever (see _platform's own
      // comment). A loose endsWith/contains assertion would wave that through.
      // Tests run off Windows, so _platform resolves to the macOS variant.
      expect(
        const AutoUpdateService().feedUrl,
        'https://updates.ham2k.net/halo-${kEdition.name}/macos-universal/appcast.xml',
      );
    });
  });

  test('does nothing at all when self-update does not apply to this build', () async {
    AutoUpdateService.debugSupportedOverride = false;
    const service = AutoUpdateService();

    await service.start();
    await service.checkForUpdatesInteractively();

    expect(platform.feedUrls, isEmpty);
    expect(platform.checkCalls, 0);
    expect(await service.checkSilently(), SparkleCheckResult.upToDate);
  });

  group('the WinSparkle settings the plugin exposes no channel for', () {
    test('are applied before setFeedURL, which is where init happens', () async {
      installShimStub(applied: true);

      await const AutoUpdateService().start();

      // Not merely "both happened": every setting the shim applies is
      // documented before-init only, and WinSparkle ignores a late one
      // silently rather than reporting it, so order IS the contract.
      expect(platform.events, ['winSparkleConfig', 'setFeedURL']);
    });

    test('carry the build number, not the display version', () async {
      final recorded = installShimStub(applied: true);

      await const AutoUpdateService().start();

      // win_sparkle_set_app_build_version switches WinSparkle onto an integer
      // comparison; handing it a display string like "26.9.0" would put it
      // straight back on the string comparison that stranded the pre-127
      // fleet.
      expect(recorded.builds, [kBuildNumber.toString()]);
    });

    test('take ownership of the check interval when they applied', () async {
      installShimStub(applied: true);

      await const AutoUpdateService().start();

      // The plugin's own setScheduledCheckInterval lands AFTER init, so it is
      // out of contract on Windows — asking it again would be the late call
      // the shim exists to avoid.
      expect(platform.intervals, isEmpty);
    });

    test('leave the interval to the plugin when they could not apply', () async {
      installShimStub(applied: false);

      await const AutoUpdateService().start();

      // Off Windows, and on a Windows box where the DLL or a symbol did not
      // resolve, the plugin remains the only way to set this at all.
      expect(platform.intervals, [3600]);
    });

    test('carry the operator\'s automatic-check preference, not a hardcoded yes', () async {
      final recorded = installShimStub(applied: true);

      await const AutoUpdateService().start(automaticChecks: false);

      // WinSparkle asks about this once, at first run, and offers no way back.
      // Forcing 1 here would override a "no" the operator could then never
      // restate, since the switch in the About panel is the only way back.
      expect(recorded.automatic, [false]);
    });

    test('default to checking when nobody has expressed a preference', () async {
      final recorded = installShimStub(applied: true);

      await const AutoUpdateService().start();

      // Matches SettingsService.automaticUpdateChecks' own default: an
      // operator who never opens Settings still hears about a release.
      expect(recorded.automatic, [true]);
    });

    test('are applied once per process, like the rest of the configuration', () async {
      installShimStub(applied: true);
      const service = AutoUpdateService();

      await service.start();
      await service.checkSilently();
      await service.checkForUpdatesInteractively();

      expect(platform.events.where((e) => e == 'winSparkleConfig'), hasLength(1));
    });
  });
}

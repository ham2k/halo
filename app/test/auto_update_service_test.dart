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

import 'package:flutter_test/flutter_test.dart';

import 'package:auto_updater_platform_interface/auto_updater_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:ham2k_logger/config/version.dart' show kEdition;
import 'package:ham2k_logger/services/auto_update_service.dart';

/// Stands in for the native plugin, counting calls and answering each check
/// with the terminal event the real updater would fire.
class _FakeAutoUpdaterPlatform extends AutoUpdaterPlatform with MockPlatformInterfaceMixin {
  final _events = StreamController<Map<Object?, Object?>>.broadcast();

  final List<String> feedUrls = [];
  int checkCalls = 0;
  final List<int> intervals = [];

  /// Fails the next [setFeedURL], as an offline box would at boot.
  bool failNextFeedUrl = false;

  void reset() {
    feedUrls.clear();
    intervals.clear();
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
  }

  @override
  Future<void> checkForUpdates({bool? inBackground}) async {
    checkCalls++;
    _events.add({'type': 'update-not-available'});
  }

  @override
  Future<void> setScheduledCheckInterval(int interval) async => intervals.add(interval);
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

  setUp(() {
    platform.reset();
    AutoUpdateService.debugSupportedOverride = true;
    AutoUpdateService.debugResetConfiguration();
  });

  tearDown(() {
    AutoUpdateService.debugSupportedOverride = null;
    AutoUpdateService.debugResetConfiguration();
  });

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
}

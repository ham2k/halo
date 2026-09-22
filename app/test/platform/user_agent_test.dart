// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The User-Agent must always be resolvable — a missing native build number
// (headless test host, an early-boot platform channel not yet ready) is no
// reason for a network call, or the extension runtime start, to fail. These
// pin the never-throwing fallback path that guarantees that: without it,
// `ham2kUserAgent()` rethrows a package_info MissingPluginException on hosts
// where the plugin isn't registered (e.g. Linux `flutter test`), which is
// what darkened every extension.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/config/user_agent.dart';
import 'package:ham2k_logger/config/version.dart';

void main() {
  // Without the binding the channel fails with "Binding has not yet been
  // initialized" instead of the MissingPluginException this file is about —
  // and the fallback's catch swallows either, so these tests were pinning a
  // failure they never actually reached.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ham2kUserAgentWithoutBuild omits the build number and never touches package_info', () {
    final ua = ham2kUserAgentWithoutBuild();
    expect(ua, startsWith('Ham2K Logger/$kPublicVersion ('));
    expect(ua, endsWith(' $kAppFlavor)')); // no build token trailing the flavor
    // The parenthetical is exactly platform + flavor (no build number).
    final inside = ua.substring(ua.indexOf('(') + 1, ua.length - 1);
    expect(inside.split(' '), hasLength(2));
  });

  test('ham2kUserAgentOrFallback always resolves to a valid UA, never throwing', () async {
    final ua = await ham2kUserAgentOrFallback();
    expect(ua, startsWith('Ham2K Logger/$kPublicVersion ('));
    expect(ua, contains(kAppFlavor));
  });

  test('a failed resolution answers every caller, whatever error zone it was called from', () async {
    // Two callers in two error zones is what `flutter test` hands us: each
    // test gets its own error zone, and background work outlives the test
    // that started it (setOperatorCall's un-awaited flags refresh is still
    // fetching while the next test runs). If this resolver memoized the
    // Future rather than the resolved String, the second caller would join
    // the first's pending Future — and dart:async will not carry an error
    // across an error-zone boundary. It hands it to the zone that CREATED
    // the future, reddening an unrelated and usually already-finished test
    // ("This test failed after it had already completed"), while the caller
    // that joined never hears back at all. Both must get their own answer.
    final uncaught = <Object>[];
    final answered = <String, Object?>{};

    Future<void> resolveIn(String zone) {
      final done = Completer<void>();
      runZonedGuarded(
        () async {
          try {
            answered[zone] = await ham2kUserAgent();
          } catch (e) {
            answered[zone] = e;
          }
          if (!done.isCompleted) done.complete();
        },
        (e, _) {
          uncaught.add(e);
          if (!done.isCompleted) done.complete();
        },
      );
      return done.future;
    }

    final first = resolveIn('first');
    // Starts while `first` is still parked on the platform channel.
    final second = resolveIn('second');
    await Future.wait([first, second]).timeout(const Duration(seconds: 5), onTimeout: () => <void>[]);

    expect(uncaught, isEmpty, reason: 'an error reached a zone no caller was listening in');
    expect(answered['first'], isA<MissingPluginException>(), reason: '`flutter test` registers no plugins');
    expect(answered['second'], isA<MissingPluginException>(), reason: 'the second caller must resolve in its own zone, not wait forever on the first');
  });
}

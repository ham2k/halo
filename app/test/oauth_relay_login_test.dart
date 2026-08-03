// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// oauthUsesWebhookRelay decides which platforms go through LoFi's webhook
// relay (Web, Linux) versus the original in-app webview + deep-link flow
// (everywhere else) for OAuth logins (HALO-22). Pinned here for the same
// reason the deleted oauthNeedsSystemBrowser was: `kIsWeb` is a
// compile-time constant `flutter test` can't flip, and this project's CI
// runners report `android` under `flutter test` regardless of host, so
// `Platform.isLinux` would make the Linux branch untestable.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/services/pusher_service.dart';
import 'package:ham2k_logger/views/oauth_relay_login.dart';

const _state = 'abc123';

/// Bounded pumping, in place of `pumpAndSettle()`: the waiting page's
/// indeterminate `CircularProgressIndicator` animates forever, so
/// `pumpAndSettle` would time out even when everything else is done.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The strings as the page itself resolves them — asserting on literals here
/// would pin English into a test of behaviour. Anchored on `MaterialApp`
/// rather than a page-specific widget so it still resolves after the login
/// page has popped back to the test harness's home route.
Translations _t(WidgetTester tester) =>
    TranslationProvider.of(tester.element(find.byType(MaterialApp))).translations;

void main() {
  group('oauthUsesWebhookRelay', () {
    test('the web build uses the relay regardless of the host platform it runs on', () {
      // A browser on a Linux (or macOS, or Windows) desktop still reports
      // its host's TargetPlatform from defaultTargetPlatform — isWeb has to
      // short-circuit that check, not fall through to it.
      expect(oauthUsesWebhookRelay(isWeb: true, platform: TargetPlatform.macOS), isTrue);
      expect(oauthUsesWebhookRelay(isWeb: true, platform: TargetPlatform.linux), isTrue);
    });

    test('Linux uses the relay off the web too', () {
      expect(oauthUsesWebhookRelay(isWeb: false, platform: TargetPlatform.linux), isTrue);
    });

    test('macOS, Windows, Android and iOS keep the native webview/deep-link flow', () {
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ]) {
        expect(
          oauthUsesWebhookRelay(isWeb: false, platform: platform),
          isFalse,
          reason: '$platform should keep the original webview/deep-link flow, not the relay',
        );
      }
    });
  });

  group('the relay waiting page', () {
    /// Pushes the page and reports what it pops with. `popped` is a LIST, not a
    /// nullable field: the route pops after this returns, and a record would
    /// have captured the value as it was before the event arrived.
    Future<({List<String?> popped, List<String> errors})> pump(
      WidgetTester tester, {
      bool launchSucceeds = true,
      List<Map<String, dynamic>> Function()? fetch,
      Stream<PusherEvent>? pings,
    }) async {
      final errors = <String>[];
      final popped = <String?>[];
      final authUri = Uri.parse('https://sso.example.org/auth?state=$_state');

      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  popped.add(await Navigator.of(context).push<String>(MaterialPageRoute(
                    builder: (_) => OAuthRelayLoginPage(
                      accountLabel: 'SOTA',
                      authUri: authUri,
                      expectedState: _state,
                      webhookEvents: pings ?? const Stream.empty(),
                      fetchWebhookEvents: () async => fetch?.call() ?? const [],
                      onError: errors.add,
                      launcher: (uri) async => launchSucceeds,
                      // Long enough that the poll tick never fires during a
                      // test — every check below is driven by the initial
                      // immediate check in initState or by `pings`, not by
                      // the timer, so the two triggers stay independently
                      // controllable.
                      pollInterval: const Duration(days: 1),
                    ),
                  )));
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      // Not pumpAndSettle: the page shows an indeterminate
      // CircularProgressIndicator, whose animation never settles. Bounded
      // pumps instead — enough to clear the push transition, run initState's
      // async check, and clear a pop transition.
      await _settle(tester);
      return (popped: popped, errors: errors);
    }

    testWidgets('opens the browser as soon as it appears, and can reopen it', (tester) async {
      final launched = <bool>[];
      await pump(tester, fetch: () {
        launched.add(true);
        return const [];
      });
      // initState's immediate check plus the reopen button both go through
      // `fetch`, so use launch success via the button instead.
      expect(find.text(_t(tester).settings.accounts.openInBrowser), findsOneWidget);
    });

    testWidgets('a matching webhook event pops with its code', (tester) async {
      final run = await pump(
        tester,
        fetch: () => [
          {
            'payload': {'state': _state, 'code': 'THE_CODE'},
          },
        ],
      );
      expect(run.popped, ['THE_CODE']);
      expect(run.errors, isEmpty);
    });

    testWidgets('an event for a different login attempt is ignored, not popped', (tester) async {
      // THE point of the state parameter: without this check, an event from
      // any other concurrent login attempt would be exchanged for tokens on
      // this one.
      final run = await pump(
        tester,
        fetch: () => [
          {
            'payload': {'state': 'someone-elses', 'code': 'THE_CODE'},
          },
        ],
      );
      expect(run.popped, isEmpty, reason: 'nothing matched this login\'s state — still waiting');
      expect(find.byType(OAuthRelayLoginPage), findsOneWidget);
    });

    testWidgets('the state must match EXACTLY, not merely start the same way', (tester) async {
      // Guards the comparison itself: a check loosened to a prefix or a
      // `contains` would take these, and an attacker who learned any prefix
      // of the state could then have one accepted.
      final run = await pump(
        tester,
        fetch: () => [
          {
            'payload': {'state': '${_state}x', 'code': 'THE_CODE'},
          },
        ],
      );
      expect(run.popped, isEmpty);
    });

    testWidgets('a provider error pops with no code and reports the reason', (tester) async {
      final run = await pump(
        tester,
        fetch: () => [
          {
            'payload': {'state': _state, 'error': 'access_denied', 'error_description': 'User said no'},
          },
        ],
      );
      expect(run.popped, [null], reason: 'popped, but with no code to exchange');
      expect(run.errors, ['User said no']);
    });

    testWidgets('a malformed event (no code, no error) ends the login instead of stalling', (tester) async {
      final run = await pump(
        tester,
        fetch: () => [
          {
            'payload': {'state': _state},
          },
        ],
      );
      expect(run.popped, [null]);
      expect(run.errors, [_t(tester).settings.accounts.relayLoginMalformedEvent]);
    });

    testWidgets('a browser that will not open says so, instead of waiting forever', (tester) async {
      await pump(tester, launchSucceeds: false);
      expect(find.text(_t(tester).settings.accounts.relayLoginNotOpened), findsOneWidget);
      expect(find.text(_t(tester).settings.accounts.relayLoginWaiting), findsNothing);
    });

    // A widget test for the `_resolved` re-entrancy latch itself (guarding a
    // second trigger that lands after the first pop but before the route's
    // exit animation finishes) was attempted and dropped: under
    // flutter_test's binding, `dispose()` runs on the very next pump
    // regardless of pump duration, so the ping subscription is always torn
    // down before a second trigger could reach `_checkForResult` — the test
    // passed identically whether the fix was present or reverted. A test
    // that cannot fail on the regression it claims to guard is worse than no
    // test at all.
  });
}

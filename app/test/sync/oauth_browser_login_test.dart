// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// oauthUsesWebhookRelay decides which platforms go through LoFi's webhook
// relay (Web, Linux, Windows) versus the deep-link flow
// (everywhere else) for OAuth logins (HALO-22). Pinned here for the same
// reason the deleted oauthNeedsSystemBrowser was: `kIsWeb` is a
// compile-time constant `flutter test` can't flip, and this project's CI
// runners report `android` under `flutter test` regardless of host, so
// `Platform.isLinux` would make the Linux branch untestable.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/pusher_service.dart';
import 'package:ham2k_logger/views/oauth_browser_login.dart';

const _state = 'abc123';

/// Bounded pumping, in place of `pumpAndSettle()`: the waiting body's
/// indeterminate `CircularProgressIndicator` animates forever, so
/// `pumpAndSettle` would time out even when everything else is done.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The strings as the body itself resolves them — asserting on literals here
/// would pin English into a test of behaviour.
Translations _t(WidgetTester tester) => TranslationProvider.of(tester.element(find.byType(MaterialApp))).translations;

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

    test('Windows uses the relay: it registers no scheme to catch the redirect with', () {
      // The sign-in page opens in the system browser there like everywhere
      // else, so without the relay the authorization code would have no way
      // back into the app at all (HALO-178 is the missing registration).
      expect(oauthUsesWebhookRelay(isWeb: false, platform: TargetPlatform.windows), isTrue);
    });

    test('macOS, Android and iOS take the code home as a deep link', () {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS]) {
        expect(oauthUsesWebhookRelay(isWeb: false, platform: platform), isFalse, reason: '$platform registers com.ham2k.*.auth:// and needs no relay');
      }
    });
  });

  group('the waiting body', () {
    /// Mounts the body inline, the way the account pane does, and collects
    /// what it reports. Lists rather than nullable fields: the point of
    /// several of these tests is that a callback fires exactly ONCE, which a
    /// field that simply holds the last value could never show.
    Future<({List<String> codes, List<String> errors, List<void> cancels, List<Uri> launched})> pump(
      WidgetTester tester, {
      bool launchSucceeds = true,
      List<Map<String, dynamic>> Function()? fetch,
      Stream<PusherEvent>? pings,
      Duration pollInterval = const Duration(days: 1),
    }) async {
      final codes = <String>[];
      final errors = <String>[];
      final cancels = <void>[];
      final launched = <Uri>[];
      final authUri = Uri.parse('https://sso.example.org/auth?state=$_state');

      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: OAuthBrowserLoginBody(
                authUri: authUri,
                expectedState: _state,
                webhookEvents: pings ?? const Stream.empty(),
                fetchWebhookEvents: () async => fetch?.call() ?? const [],
                onCode: codes.add,
                onError: errors.add,
                onCancel: () => cancels.add(null),
                launcher: (uri) async {
                  launched.add(uri);
                  return launchSucceeds;
                },
                // Defaults long enough that the poll tick never fires
                // during a test — every check below is driven by the
                // initial immediate check in initState or by `pings`,
                // not by the timer, so the two triggers stay
                // independently controllable. A test about the polling
                // itself passes its own.
                pollInterval: pollInterval,
              ),
            ),
          ),
        ),
      );
      // Not pumpAndSettle: the body shows an indeterminate
      // CircularProgressIndicator, whose animation never settles. Bounded
      // pumps instead — enough to run initState's async check.
      await _settle(tester);
      return (codes: codes, errors: errors, cancels: cancels, launched: launched);
    }

    testWidgets('opens the browser as soon as it appears, and offers to reopen it', (tester) async {
      // The launch is the whole reason this body exists — the operator never
      // asked for a spinner, they asked to sign in. Asserting only that the
      // reopen button is present would pass with the initState launch gone,
      // leaving a body that waits for a browser nobody opened.
      final run = await pump(tester);
      expect(run.launched, [Uri.parse('https://sso.example.org/auth?state=$_state')]);

      await tester.tap(find.text(_t(tester).settings.accounts.openInBrowser));
      await _settle(tester);
      expect(run.launched, hasLength(2), reason: 'the button reopens it');
    });

    testWidgets('it reports its result rather than popping a route', (tester) async {
      // The whole point of the inline move: this body lives in the account
      // pane's own subtree, so reaching for the Navigator would dismiss
      // whatever route happens to be under it — the settings screen — instead
      // of ending the login.
      await pump(
        tester,
        fetch: () => [
          {
            'payload': {'state': _state, 'code': 'THE_CODE'},
          },
        ],
      );
      expect(find.byType(OAuthBrowserLoginBody), findsOneWidget, reason: 'nothing popped it');
      expect(find.byType(Scaffold), findsOneWidget, reason: 'the host route is still there');
    });

    testWidgets('a matching webhook event reports its code', (tester) async {
      final run = await pump(
        tester,
        fetch: () => [
          {
            'payload': {'state': _state, 'code': 'THE_CODE'},
          },
        ],
      );
      expect(run.codes, ['THE_CODE']);
      expect(run.errors, isEmpty);
    });

    testWidgets('a result already reported is never reported twice', (tester) async {
      // The `_resolved` latch. The relay does NOT consume an event on GET, so
      // the same code keeps coming back on every subsequent poll — and the
      // pane's completer throws on a second completion, where the route pop
      // this replaced merely popped a second route. Nothing unmounts this
      // body when it reports, so the later ticks really do arrive.
      var fetches = 0;
      final run = await pump(
        tester,
        fetch: () {
          fetches++;
          return [
            {
              'payload': {'state': _state, 'code': 'THE_CODE'},
            },
          ];
        },
        pollInterval: const Duration(milliseconds: 10),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(fetches, greaterThanOrEqualTo(1));
      expect(run.codes, ['THE_CODE'], reason: 'reported once, however many times the event is seen again');
    });

    testWidgets('an event for a different login attempt is ignored, not reported', (tester) async {
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
      expect(run.codes, isEmpty, reason: 'nothing matched this login\'s state — still waiting');
      expect(find.text(_t(tester).settings.accounts.relayLoginWaiting), findsOneWidget);
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
      expect(run.codes, isEmpty);
    });

    testWidgets('a provider error reports the reason and no code', (tester) async {
      final run = await pump(
        tester,
        fetch: () => [
          {
            'payload': {'state': _state, 'error': 'access_denied', 'error_description': 'User said no'},
          },
        ],
      );
      expect(run.codes, isEmpty, reason: 'there is no code to exchange');
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
      expect(run.codes, isEmpty);
      expect(run.errors, [_t(tester).settings.accounts.loginIncompleteResponse]);
    });

    testWidgets('cancelling reports a cancel, and nothing else', (tester) async {
      // The pane's footer Cancel closes the whole dialog; this one abandons
      // just the sign-in. Without it the inline body has no way out at all —
      // the AppBar close button the pushed route carried is gone.
      final run = await pump(tester);
      await tester.tap(find.text(_t(tester).settings.accounts.cancelLogin));
      await _settle(tester);
      expect(run.cancels, hasLength(1));
      expect(run.codes, isEmpty);
      expect(run.errors, isEmpty);
    });

    testWidgets('a browser that will not open says so, instead of waiting forever', (tester) async {
      await pump(tester, launchSucceeds: false);
      expect(find.text(_t(tester).settings.accounts.relayLoginNotOpened), findsOneWidget);
      expect(find.text(_t(tester).settings.accounts.relayLoginWaiting), findsNothing);
    });

    testWidgets('with no relay wiring it opens the browser and waits, polling nothing', (tester) async {
      // The deep-link platforms' shape: the OS brings the code back and
      // `_doOAuth`'s listener ends the wait, so a body that resolved
      // anything on its own here would be racing that listener. A relay call
      // in this mode is a null-deref, not a wasted request — which is why
      // fetch is left null rather than wired to an empty list.
      final launched = <Uri>[];
      final codes = <String>[];
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: OAuthBrowserLoginBody(
                authUri: Uri.parse('https://sso.example.org/auth?state=$_state'),
                onCode: codes.add,
                onError: (_) {},
                onCancel: () {},
                launcher: (uri) async {
                  launched.add(uri);
                  return true;
                },
                pollInterval: const Duration(milliseconds: 1),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      // Well past several poll intervals: a timer left armed in this mode
      // would have fired by now, and firing means dereferencing a null hook.
      await tester.pump(const Duration(seconds: 1));

      expect(launched, hasLength(1));
      expect(codes, isEmpty);
      expect(tester.takeException(), isNull);
      expect(find.text(_t(tester).settings.accounts.relayLoginWaiting), findsOneWidget);
    });

    testWidgets('a relay it cannot reach stops calling it waiting', (tester) async {
      // fetchWebhookEvents reports a dead host as an EMPTY LIST, so a throw is
      // the only failure this body can see at all — and it must not read as
      // "the operator hasn't finished yet", which is what the waiting line
      // claims and what it would go on claiming forever.
      var calls = 0;
      await pump(
        tester,
        fetch: () {
          calls++;
          throw StateError('relay unreachable');
        },
        pollInterval: const Duration(milliseconds: 10),
      );
      // Three consecutive failures: one dropped request is what polling is for.
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump();

      expect(calls, greaterThanOrEqualTo(3));
      expect(find.text(_t(tester).settings.accounts.relayLoginUnavailable), findsOneWidget);
      expect(find.text(_t(tester).settings.accounts.relayLoginWaiting), findsNothing);
    });

    testWidgets('a code that never comes back stops calling it waiting too', (tester) async {
      // The deep-link platforms' failure mode: the OS never delivered the
      // redirect, or the operator finished on another device. Nothing here can
      // tell that from a slow password, so the body waits a good while — and
      // then says what the operator can actually do about it.
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: OAuthBrowserLoginBody(
                authUri: Uri.parse('https://sso.example.org/auth?state=$_state'),
                onCode: (_) {},
                onError: (_) {},
                onCancel: () {},
                launcher: (uri) async => true,
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text(_t(tester).settings.accounts.relayLoginWaiting), findsOneWidget);

      await tester.pump(const Duration(minutes: 2));
      expect(find.text(_t(tester).settings.accounts.loginNoResponse), findsOneWidget);
      expect(find.text(_t(tester).settings.accounts.relayLoginWaiting), findsNothing);
    });
  });
}

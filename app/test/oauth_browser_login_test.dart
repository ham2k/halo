// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The OAuth login leg for platforms with no in-app webview (#430). Two things
// are pinned here, because neither can be checked by running the app on this
// project's machines — the branch is Linux-only and the CI runners report
// `android` under `flutter test`:
//
//   * WHICH platforms take it. `oauthNeedsSystemBrowser` reads
//     `defaultTargetPlatform` precisely so a test can override it;
//     `Platform.isLinux` would have made this untestable.
//   * That a pasted redirect is validated the same way the webview and
//     deep-link paths validate one. That check is all that stands between a
//     link from somewhere else and this login's token exchange, so it is a
//     pure function with its own tests rather than a closure inside a page.
//
// What these CANNOT show, and the PR says so: that `launchUrl` really opens a
// browser on a Linux desktop, and that a real Keycloak redirect looks the way
// the fixtures here do.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/views/oauth_browser_login.dart';

const _redirect = 'com.ham2k.logger.next.auth://sota';
const _state = 'abc123';

/// The strings as the page itself resolves them — asserting on literals here
/// would pin English into a test of behaviour.
Translations _t(WidgetTester tester) =>
    TranslationProvider.of(tester.element(find.byType(TextField))).translations;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('which platforms need the browser', () {
    test('Linux does, because flutter_inappwebview ships no Linux implementation', () {
      expect(oauthNeedsSystemBrowser(platform: TargetPlatform.linux), isTrue);
    });

    test('the four platforms the plugin supports do not', () {
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ]) {
        expect(oauthNeedsSystemBrowser(platform: platform), isFalse, reason: '$platform has a webview');
      }
    });

    test('a platform nobody has considered gets the browser, not a crash', () {
      // Fuchsia has no webview implementation either. The point is the shape of
      // the check: an allowlist of what works, so the unknown case is the safe
      // one.
      expect(oauthNeedsSystemBrowser(platform: TargetPlatform.fuchsia), isTrue);
    });

    test('the web build keeps its webview, even when the host reports Linux', () {
      // On Flutter web `defaultTargetPlatform` answers the HOST platform, so a
      // browser on a Linux desktop reports `linux` — and the plugin does support
      // web. Without the kIsWeb guard, every Linux web user would be pushed
      // through a paste-the-link flow they have no need for.
      expect(oauthNeedsSystemBrowser(platform: TargetPlatform.linux, isWeb: true), isFalse);
    });

    test('it reads the overridable platform, so this branch is reachable in a test', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(oauthNeedsSystemBrowser(), isTrue);
    });
  });

  group('reading a pasted redirect', () {
    PastedLink read(String text) =>
        readPastedRedirect(text, redirectUrl: _redirect, expectedState: _state);

    test('the redirect the provider sends yields its code', () {
      final result = read('$_redirect?code=THE_CODE&state=$_state');
      expect(result.isUsable, isTrue);
      expect(result.code, 'THE_CODE');
      expect(result.error, isNull);
    });

    test('surrounding whitespace is what a paste actually looks like', () {
      expect(read('  $_redirect?code=THE_CODE&state=$_state\n').code, 'THE_CODE');
    });

    test('a lowercased scheme still matches — some browsers hand it back that way', () {
      final result = read('${_redirect.toUpperCase()}?code=THE_CODE&state=$_state');
      expect(result.isUsable, isTrue, reason: 'a URL scheme is case-insensitive');
    });

    test('a link from a different login attempt is refused', () {
      // THE point of the state parameter: without this check, a link captured
      // from any other login would be exchanged for tokens on this account.
      final result = read('$_redirect?code=THE_CODE&state=someone-elses');
      expect(result.isUsable, isFalse);
      expect(result.problem, PastedLinkProblem.wrongLogin);
      expect(result.code, isNull);
    });

    test('a link with no state at all is refused too', () {
      expect(read('$_redirect?code=THE_CODE').problem, PastedLinkProblem.wrongLogin);
    });

    test('the state must match EXACTLY, not merely start the same way', () {
      // Guards the comparison itself, not just its presence: a check loosened to
      // a prefix or a `contains` would take these, and an attacker who learned
      // any prefix of the state could then have one accepted.
      expect(read('$_redirect?code=THE_CODE&state=${_state}x').problem, PastedLinkProblem.wrongLogin);
      expect(read('$_redirect?code=THE_CODE&state=${_state.substring(0, 4)}').problem, PastedLinkProblem.wrongLogin);
    });

    test('a redirect addressed somewhere else is refused, not merely prefixed', () {
      // `startsWith` on the redirect string accepted this: same prefix, entirely
      // different host. Nothing here trusts the host, but there is no reason to
      // read parameters off a link addressed elsewhere.
      expect(read('$_redirect.example.com/?code=THE_CODE&state=$_state').problem, PastedLinkProblem.notARedirect);
      expect(
        read('com.ham2k.logger.next.auth://evil.example.com/sota?code=THE_CODE&state=$_state').problem,
        PastedLinkProblem.notARedirect,
      );
      // A path the provider chose to add is fine — only scheme and authority are
      // ours to insist on.
      expect(read('$_redirect/callback?code=THE_CODE&state=$_state').code, 'THE_CODE');
    });

    test('a paste whose escapes cannot be decoded is classified, not thrown', () {
      // `Uri.tryParse` accepts a percent-escape that is valid hex but invalid
      // UTF-8 — a localized provider error cut between the two bytes of one
      // character — and `queryParameters` throws while decoding it. That throw
      // used to escape this function into the button's callback, where Flutter
      // swallowed it: pressing Finish Login did nothing at all, reported nothing,
      // and left the operator unable to tell whether it was them or the app.
      for (final bad in [
        '$_redirect?state=$_state&error_description=Se%C3',
        '$_redirect?code=AbC%C3',
        '$_redirect?state=$_state&error_description=Se%F1al',
        '$_redirect?state=$_state&code=%80',
      ]) {
        expect(read(bad).problem, PastedLinkProblem.malformed, reason: bad);
      }
      // An escape that is not even hex is normalized by Uri and decodes fine, so
      // it is NOT this case.
      expect(read('$_redirect?state=$_state&code=%zz').code, isNotNull);
    });

    test('something that is not the redirect is refused', () {
      expect(read('https://www.sotadata.org.uk/').problem, PastedLinkProblem.notARedirect);
      expect(read('').problem, PastedLinkProblem.notARedirect);
      expect(read('not a url at all').problem, PastedLinkProblem.notARedirect);
    });

    test('a denied consent is USABLE — it ends the login with the provider’s reason', () {
      final result = read('$_redirect?error=access_denied&error_description=User+said+no&state=$_state');
      expect(result.isUsable, isTrue);
      expect(result.code, isNull);
      expect(result.error, 'User said no');
    });

    test('a redirect with neither code nor error says so', () {
      expect(read('$_redirect?state=$_state').problem, PastedLinkProblem.noCode);
    });
  });

  group('the waiting page', () {
    /// Pushes the page and reports what it pops with. `popped` is a LIST, not a
    /// nullable field: the route pops long after this returns, and a record would
    /// have captured the value as it was before the operator did anything.
    Future<({List<String?> popped, List<String> errors, List<Uri> launched})> pump(
      WidgetTester tester, {
      bool launchSucceeds = true,
    }) async {
      final launched = <Uri>[];
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
                    builder: (_) => OAuthBrowserLoginPage(
                      accountLabel: 'SOTA',
                      authUri: authUri,
                      redirectUrl: _redirect,
                      expectedState: _state,
                      onError: errors.add,
                      launcher: (uri) async {
                        launched.add(uri);
                        return launchSucceeds;
                      },
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
      await tester.pumpAndSettle();
      return (popped: popped, errors: errors, launched: launched);
    }

    testWidgets('opens the browser as soon as it appears, and can reopen it', (tester) async {
      final run = await pump(tester);
      expect(run.launched, hasLength(1), reason: 'the operator should not have to ask for the browser');

      await tester.tap(find.text(_t(tester).settings.accounts.openInBrowser));
      await tester.pumpAndSettle();
      expect(run.launched, hasLength(2));
    });

    testWidgets('a pasted redirect finishes the login', (tester) async {
      final run = await pump(tester);
      await tester.enterText(find.byType(TextField), '$_redirect?code=THE_CODE&state=$_state');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(run.popped, ['THE_CODE'], reason: 'the route pops with the code _doOAuth then exchanges');
    });

    testWidgets('an undecodable paste says so in the field, rather than doing nothing', (tester) async {
      final run = await pump(tester);
      await tester.enterText(find.byType(TextField), '$_redirect?state=$_state&error_description=Se%C3');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'the FormatException must never reach the framework');
      expect(run.popped, isEmpty);
      expect(find.text(_t(tester).settings.accounts.pastedLinkMalformed), findsOneWidget);
    });

    testWidgets('the paste box has focus on arrival — it is why the page exists', (tester) async {
      await pump(tester);
      expect(tester.widget<TextField>(find.byType(TextField)).autofocus, isTrue);
    });

    testWidgets('a link from another login is rejected in place, without ending the flow', (tester) async {
      final run = await pump(tester);
      await tester.enterText(find.byType(TextField), '$_redirect?code=THE_CODE&state=nope');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(run.popped, isEmpty, reason: 'nothing was popped — the flow is still live');
      expect(find.byType(OAuthBrowserLoginPage), findsOneWidget, reason: 'still open, so it can be corrected');
      // The message names the problem rather than failing silently.
      expect(find.text(_t(tester).settings.accounts.pastedLinkWrongLogin), findsOneWidget);
    });

    testWidgets('a denied consent pops with no code and reports the provider’s reason', (tester) async {
      final run = await pump(tester);
      await tester.enterText(
        find.byType(TextField),
        '$_redirect?error=access_denied&error_description=User+said+no&state=$_state',
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(run.popped, [null], reason: 'popped, but with no code to exchange');
      expect(run.errors, ['User said no'], reason: '_doOAuth raises this instead of failing mutely');
    });

    testWidgets('a browser that will not open says so, instead of waiting forever', (tester) async {
      await pump(tester, launchSucceeds: false);
      final t = _t(tester);
      // Still names the redirect prefix: this operator's browser never opened,
      // so they have the LEAST context for recognising the link to copy.
      expect(find.text(t.settings.accounts.browserLoginNotOpened(prefix: _redirect)), findsOneWidget);
      // The old patch launched unawaited, so this state was indistinguishable
      // from "waiting for the operator".
      expect(find.text(t.settings.accounts.browserLoginSteps(prefix: _redirect)), findsNothing);
    });

    testWidgets('the login link can be copied, for a desktop that opens nothing', (tester) async {
      final clipboard = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clipboard.add((call.arguments as Map)['text'] as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await pump(tester);
      await tester.tap(find.text(_t(tester).settings.accounts.copyLoginLink));
      await tester.pumpAndSettle();

      expect(clipboard, hasLength(1));
      expect(clipboard.single, startsWith('https://sso.example.org/auth'));
    });
  });
}

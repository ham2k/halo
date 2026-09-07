// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The account pane's half of the OAuth login: starting one, holding the
// completer the answer arrives on, and ending it.
// `oauth_browser_login_test.dart` covers the waiting body the pane hosts;
// this covers the pane that drives it.
//
// Everything here has to get through `_doOAuth`'s network prologue first —
// the OIDC discovery GET is a top-level `package:http` call with no
// injection point, so these run inside an `HttpOverrides` zone that answers
// the discovery and token endpoints. `oauthUsesWebhookRelay()` reports
// `android` under `flutter test`, so this is the DEEP-LINK path throughout:
// the code comes home through `HaLoServices.deepLinks`, faked here, which is
// the only way the completed-login path can be exercised at all.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/deep_link_service.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/oauth_browser_login.dart';
import 'package:ham2k_logger/views/settings/accounts_panel.dart';

import '../support/halo_test_support.dart';

const _issuer = 'https://sso.example.org/auth/realms/TEST';
const _redirect = 'com.ham2k.logger.test.auth://sota';

/// A JWT whose payload names an identity — the pane has no username to show
/// for an OAuth account, so this is what "logged in as" reads out of.
final _idToken = 'x.${base64Url.encode(utf8.encode(jsonEncode({'preferred_username': 'N0DEV'}))).replaceAll('=', '')}.y';

/// Feeds `_doOAuth` the two endpoints it fetches. Counting is the point for
/// the double-tap test: a second login is invisible in the UI (the first's
/// waiting body is already up) but shows here as a second discovery GET.
class _OAuthHttpOverrides extends HttpOverrides {
  int discoveryFetches = 0;
  int tokenExchanges = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient(this);
}

class _FakeHttpClient implements HttpClient {
  final _OAuthHttpOverrides owner;
  _FakeHttpClient(this.owner);

  Future<HttpClientRequest> _open(String method, Uri url) async {
    if (url.path.endsWith('/.well-known/openid-configuration')) {
      owner.discoveryFetches++;
      return _FakeRequest(url, method, jsonEncode({
        'authorization_endpoint': '$_issuer/protocol/openid-connect/auth',
        'token_endpoint': '$_issuer/protocol/openid-connect/token',
      }));
    }
    if (url.path.endsWith('/token')) {
      owner.tokenExchanges++;
      return _FakeRequest(url, method, jsonEncode({
        'access_token': 'ACCESS',
        'refresh_token': 'REFRESH',
        'id_token': _idToken,
      }));
    }
    return _FakeRequest(url, method, '{}', status: 404);
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => _open(method, url);
  @override
  Future<HttpClientRequest> getUrl(Uri url) => _open('GET', url);
  @override
  Future<HttpClientRequest> postUrl(Uri url) => _open('POST', url);
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRequest implements HttpClientRequest {
  @override
  final Uri uri;
  @override
  final String method;
  final String body;
  final int status;
  @override
  final HttpHeaders headers = _FakeHeaders();

  _FakeRequest(this.uri, this.method, this.body, {this.status = 200});

  @override
  Future<HttpClientResponse> close() async => _FakeResponse(body, status);
  @override
  void add(List<int> data) {}
  @override
  void write(Object? obj) {}
  @override
  Future<void> addStream(Stream<List<int>> stream) async {}
  @override
  Future<HttpClientResponse> get done async => _FakeResponse(body, status);
  // IOClient sets followRedirects, maxRedirects, contentLength and
  // persistentConnection before closing the request. Throwing on those (the
  // default noSuchMethod) surfaces as "Login failed: NoSuchMethodError"
  // through _doOAuth's catch, which reads exactly like a login that never
  // started.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  final String body;
  @override
  final int statusCode;
  _FakeResponse(this.body, this.statusCode);

  @override
  int get contentLength => body.length;
  @override
  HttpHeaders get headers => _FakeHeaders();
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => false;
  @override
  String get reasonPhrase => '';
  @override
  List<Cookie> get cookies => const [];
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(utf8.encode(body))
          .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stands in for the OS delivering a `com.ham2k.*.auth://` redirect.
class _FakeDeepLinkService extends DeepLinkService {
  final _controller = StreamController<Uri>.broadcast();
  @override
  Stream<Uri> get links => _controller.stream;
  void deliver(Uri uri) => _controller.add(uri);
  Future<void> dispose() => _controller.close();
}

/// Keeps credentials in memory so Save and the "already connected" read are
/// real rather than a null "storage unavailable" answer.
class _AccountExtensionService extends ExtensionServiceWithFakeHost {
  _AccountExtensionService(super.mockHost);
  final Map<String, Map<String, String>> store = {};

  @override
  Future<Map<String, String>> getAccountCredentials(String kvKey) async => store[kvKey] ?? const {};
  @override
  Future<void> setAccountCredentials(String kvKey, Map<String, String> credentials) async {
    store[kvKey] = credentials;
  }
  @override
  Future<String> testCredentials(String accountKey, Map<String, String> credentials) async => 'ok';

  /// Every `refreshWebhookToken` this pane asked for, in order.
  final registrationRefreshes = <bool>[];

  @override
  Future<LofiClientRegistration?> ensureLofiClientRegistered({bool refreshWebhookToken = false}) async {
    registrationRefreshes.add(refreshWebhookToken);
    return (pushChannelName: 'client-test-channel', webhookClientToken: 'signed--token');
  }
}

final _accountDefinition = {
  'key': 'testsso',
  'ok': true,
  'value': {
    'key': 'testsso',
    'kvKey': 'testsso',
    'label': 'Test SSO',
    'oauth2': {
      'issuer': _issuer,
      'clientId': 'com.ham2k.logger.test',
      'redirectUrl': _redirect,
      'webhookRedirectUrl': 'https://relay.example.net/oauth',
      'scopes': ['openid'],
    },
  },
};

typedef _Harness = ({
  HaLoServices services,
  _FakeDeepLinkService links,
  _OAuthHttpOverrides http,
  _AccountExtensionService extensions,
});

Future<_Harness> _harness(_OAuthHttpOverrides overrides) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService(await SharedPreferences.getInstance());
  final extensions = _AccountExtensionService(FakeExtensionHost({
    'account:*:getDefinition': [_accountDefinition],
  }));
  extensions.settings = settings;
  final links = _FakeDeepLinkService();
  final services = HaLoServices(HaLoDatabase(NativeDatabase.memory()), settings,
      extensions: extensions, deepLinks: links);
  return (services: services, links: links, http: overrides, extensions: extensions);
}

/// Opens the account pane and presses Connect, stopping while the login is
/// still waiting for the browser.
///
/// Bounded pumps rather than `pumpAndSettle`: the waiting body's
/// indeterminate progress indicator never settles.
Future<void> _pump(WidgetTester tester, {int times = 12}) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Lets the REAL event loop run, then rebuilds.
///
/// Everything that ends a login lands here rather than in `tester.pump`:
/// `_doOAuth` resumes from its completer onto the real loop, and its
/// `finally` — which clears `_oauthLogin` and re-enables Connect — plus the
/// token exchange after it are invisible to fake async. Without this the
/// wait appears to end while `_startingOAuth` is still set, so the NEXT
/// press of Connect silently does nothing.
Future<void> _flush(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  await _pump(tester);
}

/// Hands the pane a redirect the way the OS would, and lets it be acted on.
Future<void> _deliver(WidgetTester tester, _FakeDeepLinkService links, String uri) async {
  links.deliver(Uri.parse(uri));
  await _flush(tester);
}

Future<_Harness> _openPane(WidgetTester tester, _OAuthHttpOverrides overrides) async {
  final h = await _harness(overrides);
  await tester.pumpWidget(TranslationProvider(
    // showAccountDialogByKey opens on the app's root navigator, so it needs
    // the navigatorKey main.dart wires up rather than this test's context.
    child: MaterialApp(navigatorKey: navigatorKey, home: const Scaffold(body: SizedBox())),
  ));
  unawaited(showAccountDialogByKey(h.services, 'testsso'));
  await tester.pumpAndSettle();
  return h;
}

Finder get _connect => find.widgetWithText(OutlinedButton, t.settings.accounts.connect);
Finder get _cancelLogin => find.widgetWithText(TextButton, t.settings.accounts.cancelLogin);
Finder get _save => find.widgetWithText(FilledButton, t.common.save);
Finder get _footerCancel => find.widgetWithText(TextButton, t.common.cancel);

bool _enabled(WidgetTester tester, Finder f) => (tester.widget(f) as ButtonStyleButton).onPressed != null;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `_doOAuth` stamps every request with `ham2kUserAgent()`, which THROWS
  // when package_info_plus's channel can't answer — headless tests exactly.
  // Without this the login aborts in the prologue and never reaches the
  // waiting body, which looks identical to the login simply not starting.
  PackageInfo.setMockInitialValues(
    appName: 'Ham2K Logger',
    packageName: 'com.ham2k.logger.test',
    version: '0.1.0',
    buildNumber: '1',
    buildSignature: '',
  );

  testWidgets('the authorization code comes home and the pane offers to keep it', (tester) async {
    // The one path that has never run against a real provider: HALO-372 means
    // every live attempt dies at "Client not found" before a code exists. If
    // the deep-link listener, the completer, the token exchange and the
    // credential hand-off do not connect to each other, this is the only
    // place it shows.
    final overrides = _OAuthHttpOverrides();
    await HttpOverrides.runZoned(() async {
      final h = await _openPane(tester, overrides);
      await tester.tap(_connect);
      await _pump(tester);

      expect(find.text(t.settings.accounts.browserLoginTitle), findsOneWidget);

      final state = tester
          .widget<OAuthBrowserLoginBody>(find.byType(OAuthBrowserLoginBody))
          .authUri
          .queryParameters['state']!;
      await _deliver(tester, h.links, '$_redirect?code=THE_CODE&state=${Uri.encodeQueryComponent(state)}');

      expect(overrides.tokenExchanges, 1, reason: 'the code was actually exchanged');
      expect(find.text(t.settings.accounts.pressSaveToKeep), findsOneWidget);
      expect(find.textContaining('N0DEV'), findsOneWidget, reason: 'the id_token names who signed in');
      expect(h.extensions.store, isEmpty, reason: 'nothing is stored until Save');
      await h.links.dispose();
    }, createHttpClient: (c) => _FakeHttpClient(overrides));
  });

  testWidgets('a second press of Connect cannot start a second login', (tester) async {
    // Connect has no on-screen feedback during _doOAuth's network prologue —
    // the waiting body only appears after the discovery fetch returns — so
    // without the guard a double tap starts two logins. The second overwrites
    // the first, whose completer is then unreachable from _resolveOAuth AND
    // from dispose: its await never returns, its finally never runs, and its
    // deep-link subscription stays live, later resolving the WRONG attempt
    // and exchanging one attempt's code against the other's PKCE verifier.
    // Two logins are invisible in the UI, so count the prologue instead.
    final overrides = _OAuthHttpOverrides();
    await HttpOverrides.runZoned(() async {
      final h = await _openPane(tester, overrides);
      await tester.tap(_connect);
      await tester.tap(_connect);
      await _pump(tester);

      expect(overrides.discoveryFetches, 1, reason: 'the second press did not start a second login');
      expect(find.byType(OAuthBrowserLoginBody), findsOneWidget);
      await h.links.dispose();
    }, createHttpClient: (c) => _FakeHttpClient(overrides));
  });

  testWidgets('cancelling really ends an attempt, so its later redirect changes nothing', (tester) async {
    // Cancel has to end the LOGIN, not just take its spinner off screen. A
    // Cancel that only cleared `_oauthLogin` would leave `_doOAuth` parked on
    // its completer with its deep-link listener still subscribed — and the
    // abandoned attempt's code, arriving afterwards, would still be exchanged.
    // Pressing Connect a second time is what proves the first attempt was
    // really finished: `_startingOAuth` is only cleared by `_doOAuth`
    // returning.
    //
    // What this does NOT reach: the `state` comparison and `_resolveOAuth`'s
    // identity guard. The first attempt's subscription is cancelled by then,
    // so nothing is listening for the stale redirect at all — those two are
    // defence in depth here, and the test below is what pins the comparison.
    final overrides = _OAuthHttpOverrides();
    await HttpOverrides.runZoned(() async {
      final h = await _openPane(tester, overrides);
      await tester.tap(_connect);
      await _pump(tester);
      final firstState = tester
          .widget<OAuthBrowserLoginBody>(find.byType(OAuthBrowserLoginBody))
          .authUri
          .queryParameters['state']!;

      await tester.tap(_cancelLogin);
      await _flush(tester);
      expect(_enabled(tester, _connect), isTrue, reason: 'the pane is ready for another attempt');
      await tester.tap(_connect);
      await _pump(tester);
      final secondState = tester
          .widget<OAuthBrowserLoginBody>(find.byType(OAuthBrowserLoginBody))
          .authUri
          .queryParameters['state']!;
      expect(secondState, isNot(firstState), reason: 'each attempt gets its own nonce');

      await _deliver(tester, h.links, '$_redirect?code=STALE&state=${Uri.encodeQueryComponent(firstState)}');

      expect(overrides.tokenExchanges, 0, reason: 'the stale code was never exchanged');
      expect(find.text(t.settings.accounts.browserLoginTitle), findsOneWidget, reason: 'still waiting');
      await h.links.dispose();
    }, createHttpClient: (c) => _FakeHttpClient(overrides));
  });

  testWidgets('a redirect whose state merely starts the same way is ignored', (tester) async {
    // Guards the comparison itself, against a live listener — the case the
    // cancel test above cannot reach. Loosened to a prefix or a `contains`,
    // an attacker who learned any leading part of the state could have a code
    // of their choosing exchanged against this attempt's verifier.
    final overrides = _OAuthHttpOverrides();
    await HttpOverrides.runZoned(() async {
      final h = await _openPane(tester, overrides);
      await tester.tap(_connect);
      await _pump(tester);
      final state = tester
          .widget<OAuthBrowserLoginBody>(find.byType(OAuthBrowserLoginBody))
          .authUri
          .queryParameters['state']!;

      await _deliver(tester, h.links, '$_redirect?code=THEIRS&state=${Uri.encodeQueryComponent('${state}x')}');

      expect(overrides.tokenExchanges, 0, reason: 'a longer state is a different state');
      expect(find.byType(OAuthBrowserLoginBody), findsOneWidget, reason: 'this attempt is still waiting');
      await h.links.dispose();
    }, createHttpClient: (c) => _FakeHttpClient(overrides));
  });

  testWidgets('the relay path asks for a FRESH webhook token, never the cached one', (tester) async {
    // The token goes straight into this login's `state`, and the server mints
    // it with a one-hour life. A pane that accepted the cached copy works for
    // an hour after a device registers and never again — the relay answers an
    // expired token with "this login link has expired or is invalid", which
    // the operator cannot act on and retrying never clears.
    //
    // Windows, because `oauthUsesWebhookRelay` is what selects this path and
    // `flutter test` reports `android` (deep-link) otherwise.
    // Restored in a `finally`, not addTearDown: flutter_test asserts no
    // foundation debug variable outlived the test body, and it checks before
    // teardowns run.
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      final overrides = _OAuthHttpOverrides();
      await HttpOverrides.runZoned(() async {
        final h = await _openPane(tester, overrides);
        await tester.tap(_connect);
        await _pump(tester);

        expect(h.extensions.registrationRefreshes, [true],
            reason: 'one login, and it demanded a current token');
        expect(find.byType(OAuthBrowserLoginBody), findsOneWidget, reason: 'the wait actually started');
        await h.links.dispose();
      }, createHttpClient: (c) => _FakeHttpClient(overrides));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('while waiting, the pane offers nothing but the wait', (tester) async {
    // Save would persist the credentials the login is replacing; "Connected
    // as" can only report on those same stale credentials, and its own
    // spinner beside the login's reads as this login's progress. The footer
    // Cancel is disabled so the body's "Cancel sign-in" is the one way out of
    // the wait, rather than two adjacent cancels of different scope.
    final overrides = _OAuthHttpOverrides();
    await HttpOverrides.runZoned(() async {
      final h = await _openPane(tester, overrides);
      expect(find.text(t.settings.accounts.connectedAs), findsOneWidget);
      expect(_enabled(tester, _save), isTrue);

      await tester.tap(_connect);
      await _pump(tester);

      expect(find.text(t.settings.accounts.connectedAs), findsNothing);
      expect(_enabled(tester, _save), isFalse, reason: 'nothing to save yet');
      expect(_enabled(tester, _footerCancel), isFalse, reason: 'the inline Cancel sign-in is the way out');
      await h.links.dispose();
    }, createHttpClient: (c) => _FakeHttpClient(overrides));
  });

  testWidgets('cancelling the sign-in returns the pane to Connect', (tester) async {
    final overrides = _OAuthHttpOverrides();
    await HttpOverrides.runZoned(() async {
      final h = await _openPane(tester, overrides);
      await tester.tap(_connect);
      await _pump(tester);
      await tester.tap(_cancelLogin);
      await _flush(tester);

      expect(find.byType(OAuthBrowserLoginBody), findsNothing);
      // Enabled, not merely present: `_startingOAuth` is cleared in
      // `_doOAuth`'s finally, and a Connect button that is on screen but dead
      // looks exactly like one that works until it is pressed.
      expect(_enabled(tester, _connect), isTrue);
      expect(_enabled(tester, _footerCancel), isTrue, reason: 'the dialog is usable again');
      expect(find.text(t.settings.accounts.connectedAs), findsOneWidget);
      expect(h.extensions.store, isEmpty);
      await h.links.dispose();
    }, createHttpClient: (c) => _FakeHttpClient(overrides));
  });
}

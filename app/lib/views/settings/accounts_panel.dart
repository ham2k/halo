// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Accounts: the connections extensions declare (QRZ, SOTA, …) and the
// dialog that signs one in, by API key or by OAuth in the operator's own
// browser.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:http/http.dart' as http;

import '../../config/user_agent.dart';
import 'package:halo_i18n/halo_i18n.dart';
import '../../config/navigation.dart';
import '../../services/halo_services.dart';
import '../../services/deep_link_service.dart';
import '../../services/error_reporting_service.dart';
import '../../services/extension_service.dart';
import '../../services/pusher_service.dart';
import '../extensions_panel.dart';
import '../oauth_browser_login.dart';

/// What to say when secure storage cannot be reached.
///
/// The Linux advice names gnome-keyring/KWallet/KeePassXC, which would be
/// nonsense anywhere else — and this IS reachable elsewhere: the darwin plugin
/// turns any non-`noErr` OSStatus into a PlatformException, including the
/// -34018 this project already meets on macOS. Neither string claims WHY: on
/// Linux libsecret reports "nothing running", "no default collection" and
/// "locked" identically, so no message may pick one.
String storageUnavailableMessage(BuildContext context) {
  final t = context.t.settings.accounts;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) return t.noKeyringInline;
  return t.noSecureStorageInline;
}

class AccountsPanel extends StatefulWidget {
  final HaLoServices services;

  /// A SLIVER — this panel shares one scroll view with its sibling in the
  /// Accounts, Services & Data Sources panel (settings_view.dart).
  const AccountsPanel({super.key, required this.services});

  @override
  State<AccountsPanel> createState() => _AccountsPanelState();
}

class _AccountsPanelState extends State<AccountsPanel> {
  List<Map<String, dynamic>>? _accounts;
  bool _secureStorageUnavailable = false;
  final Map<String, String> _accountIdentities = {};

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    await widget.services.extensions.start();
    // A failure (null) shows the panel empty — but this panel
    // re-asks on every open and after every save, so it recovers on its own.
    final accounts = await widget.services.extensions.getAccounts() ?? const <Map<String, dynamic>>[];
    final identities = <String, String>{};
    var storageUnavailable = false;
    for (final account in accounts) {
      final kvKey = account['kvKey'] as String;
      // Null means secure storage could not be reached — not that the account is
      // disconnected. Stop asking (every account would fail the same way)
      // and let the pane say so, rather than throwing out of here and leaving
      // `_accounts` null, which would spin the panel's progress indicator forever.
      final creds = await widget.services.extensions.getAccountCredentials(kvKey);
      if (creds == null) {
        storageUnavailable = true;
        break;
      }
      if (creds.isNotEmpty) {
        identities[kvKey] = ExtensionService.identityFromCredentials(creds) ?? t.settings.accounts.connected;
      }
    }
    if (mounted) {
      setState(() {
        _secureStorageUnavailable = storageUnavailable;
        _accounts = accounts;
        _accountIdentities.clear();
        _accountIdentities.addAll(identities);
      });
    }
  }

  Future<void> _openAccountDialog(Map<String, dynamic> account) async {
    await showModalPane<void>(
      context,
      title: account['label'] as String,
      barrierDismissible: false,
      closeLabel: context.t.common.close,
      builder: (context) => AccountPane(services: widget.services, account: account, onSaved: _loadAccounts),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_accounts == null) {
      return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
    }

    // Grouped by the category of the extension each account belongs to, and
    // headed the same way the Extensions panel heads its own groups — a flat
    // list of every service the installed extensions offer reads as one
    // undifferentiated pile once there are more than a handful. An account's
    // `kvKey` defaults to its extension's key (docs/extensions/settings.md),
    // which is what ties the two together; anything that doesn't match a
    // known extension falls to "other" rather than being dropped.
    final categoryOf = {
      for (final info in widget.services.extensions.availableExtensions) info.key: info.category ?? 'other',
    };
    String categoryFor(Map<String, dynamic> account) => categoryOf[account['kvKey'] as String] ?? 'other';
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final account in _accounts!) {
      grouped.putIfAbsent(categoryFor(account), () => []).add(account);
    }

    final children = <Widget>[
        // Said once, at
        // the top — beats each row claiming to be disconnected.
        if (_secureStorageUnavailable)
          ListTile(
            leading: const Icon(MdiIcons.keyRemove),
            title: Text(storageUnavailableMessage(context)),
          ),
        if (_accounts!.isEmpty)
          ListTile(title: Text(context.t.settings.accounts.none))
        else
          for (final category in extensionCategoriesIn(grouped.keys)) ...[
            SectionHeader(extensionCategoryTitle(category)),
            ...grouped[category]!.map((account) {
              final kvKey = account['kvKey'] as String;
              final label = account['label'] as String;
              final description = account['description'] as String?;
              final identity = _accountIdentities[kvKey];
              return ListTile(
                leading: Icon(extensionCategoryIcon(category)),
                title: Text.rich(TextSpan(children: [
                  TextSpan(text: label, style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (identity != null) TextSpan(text: '  $identity'),
                ])),
                subtitle: Text(description ?? (identity == null ? context.t.settings.accounts.notConfigured : '')),
                onTap: () => _openAccountDialog(account),
                mouseCursor: SystemMouseCursors.click,
              );
            }),
          ],
    ];
    return SliverMainAxisGroup(slivers: sectionSlivers(context, children));
  }
}

/// Opens [accountKey]'s standalone account dialog from anywhere in the app
/// (declarative `account` actions — e.g. an extension's "reconnect your
/// account" dialog button). `accountKey` matches the account's kvKey.
Future<void> showAccountDialogByKey(HaLoServices services, String accountKey, {String? subkey}) async {
  // Same as the settings panel's own account field: this is a button press
  // with a dialog expected, so a failed lookup has to say so rather than
  // leave the press looking ignored. Nothing is cached here, so the next
  // press asks again.
  final accounts = await services.extensions.getAccounts();
  if (accounts == null) {
    services.statusBar.setMessage(key: 'accounts:lookup', text: t.settings.accounts.lookupFailed);
    return;
  }
  Map<String, dynamic>? account;
  for (final a in accounts) {
    if (a['kvKey'] == accountKey || a['key'] == accountKey) {
      account = a;
      break;
    }
  }
  if (account == null) {
    debugPrint('[accounts] no account "$accountKey" to open');
    return;
  }
  final context = navigatorKey.currentContext;
  if (context == null || !context.mounted) return;
  await showModalPane<void>(
    context,
    title: account['label'] as String? ?? accountKey,
    barrierDismissible: false,
    closeLabel: context.t.common.close,
    builder: (context) => AccountPane(services: services, account: account!, onSaved: () {}),
  );
}

/// A sign-in the account pane is waiting on: what the waiting body needs to
/// render, and the completer `_doOAuth` is parked on until something — the
/// relay, a deep link, the operator, or the pane's own disposal — ends it.
class _PendingOAuthLogin {
  final Uri authUri;
  final String? expectedState;
  final Stream<PusherEvent>? webhookEvents;
  final Future<List<Map<String, dynamic>>> Function()? fetchWebhookEvents;
  final Completer<String?> completer = Completer<String?>();

  /// Set alongside the completion when the login ended in a message rather
  /// than a code — read once, by the `_doOAuth` the completion wakes.
  String? error;

  _PendingOAuthLogin({
    required this.authUri,
    this.expectedState,
    this.webhookEvents,
    this.fetchWebhookEvents,
  });
}

/// One extension account's credentials, shown as a Modal Pane
/// (docs/design/layouts.md): a dialog on wide layouts, a full screen on
/// phones. The route provides the
/// title and chrome; the action row renders here because it depends on
/// this State (_testing, _loggedIn).
class AccountPane extends StatefulWidget {
  final HaLoServices services;
  final Map<String, dynamic> account;
  final VoidCallback onSaved;

  const AccountPane({super.key, required this.services, required this.account, required this.onSaved});

  @override
  State<AccountPane> createState() => _AccountPaneState();
}

class _AccountPaneState extends State<AccountPane> {
  final Map<String, TextEditingController> _controllers = {};
  bool _testing = false;
  String? _testResult;
  bool _loggedIn = false;
  bool _secureStorageUnavailable = false;

  /// OAuth tokens obtained from a Login that haven't been saved yet — only
  /// persisted when the user presses Save, discarded on Cancel/close.
  Map<String, String>? _pendingCredentials;

  /// The sign-in in flight, or null when none is. Non-null is what puts the
  /// waiting body on screen in place of the Connect button, and what
  /// `_doOAuth` is parked on.
  _PendingOAuthLogin? _oauthLogin;

  /// True from the press of Connect until `_doOAuth` returns. The login has no
  /// on-screen presence during its network prologue — the LoFi registration
  /// and the OIDC discovery fetch — so without this the button stays live
  /// through it, and a second press strands the first attempt: nothing holds
  /// its completer once `_oauthLogin` is overwritten, so its await never
  /// returns and its deep-link subscription is never cancelled.
  bool _startingOAuth = false;

  /// Ends [login], waking the `_doOAuth` parked on it.
  ///
  /// Takes the login rather than reading `_oauthLogin`, so a result can only
  /// end the attempt it belongs to: handing one attempt's code to another's
  /// completer would exchange it against the wrong PKCE verifier.
  ///
  /// Idempotent, and must stay that way: a Completer throws on a second
  /// `complete` where the route pop this replaces was forgiving, and two
  /// results really can race — a deep link the OS delivers while the operator
  /// is already pressing Cancel, or `dispose` after either.
  void _resolveOAuth(_PendingOAuthLogin? login, String? code, {String? error}) {
    if (login == null) return;
    if (login.completer.isCompleted) {
      // Dropping it is right — this login is already over — but dropping it
      // in silence leaves no record that an answer came back after the fact.
      debugPrint('[oauth] a result arrived after its login had already ended');
      return;
    }
    login.error = error;
    login.completer.complete(code);
  }

  String? _fieldError(String key, String value) {
    if (widget.account['key'] == 'qrz' && key == 'username' && value.contains('@')) {
      return "Don't use your email for login.";
    }
    return null;
  }

  List<Map<String, dynamic>> get _fields =>
      (widget.account['fields'] as List? ?? const []).cast<Map<String, dynamic>>();

  Map<String, dynamic>? get _oauth2 => widget.account['oauth2'] as Map<String, dynamic>?;

  String get _kvKey => widget.account['kvKey'] as String;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Null is "secure storage is unreachable", and it must not stop the rest of
    // this: the controllers below are what the fields render from, so throwing
    // here would leave the dialog with no fields at all.
    final stored = await widget.services.extensions.getAccountCredentials(_kvKey);
    final creds = stored ?? const <String, String>{};
    setState(() {
      _secureStorageUnavailable = stored == null;
      _loggedIn = creds.isNotEmpty;
    });
    for (final field in _fields) {
      final key = field['key'] as String;
      _controllers[key] = TextEditingController(text: creds[key] ?? '');
    }
    // Existing credentials get verified right away, so the "Connected as"
    // area reflects reality without a manual Test.
    if (creds.isNotEmpty) await _test();
  }

  @override
  void dispose() {
    // A login still parked on its completer would strand `_doOAuth`'s await
    // for the life of the isolate once this pane is gone.
    _resolveOAuth(_oauthLogin, null);
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    try {
      if (_oauth2 == null) {
        final creds = _controllers.map((key, controller) => MapEntry(key, controller.text.trim()));
        await widget.services.extensions.setAccountCredentials(_kvKey, creds);
      } else if (_pendingCredentials != null) {
        await widget.services.extensions.setAccountCredentials(_kvKey, _pendingCredentials!);
      }
    } catch (e) {
      debugPrint('[accounts] save failed for $_kvKey: $e');
      if (mounted) {
        widget.services.statusBar.setMessage(key: 'accounts:save', text: t.settings.accounts.saveFailed(error: e));
      }
      return;
    }
    widget.onSaved();
    if (mounted) Navigator.of(context).pop();
  }

  /// Bumped by [_clear] so an in-flight test's result can't repopulate the
  /// "Connected as" area after a disconnect.
  int _testGeneration = 0;

  Future<void> _clear() async {
    // Update the UI first — the keychain call shouldn't delay the visible
    // disconnect.
    _testGeneration++;
    setState(() {
      _loggedIn = false;
      _testing = false;
      _testResult = null;
      _pendingCredentials = null;
    });
    for (final c in _controllers.values) {
      c.clear();
    }
    await widget.services.extensions.clearAccount(_kvKey);
    widget.onSaved();
  }

  Future<void> _test() async {
    final generation = _testGeneration;
    setState(() {
      _testing = true;
      _testResult = null;
    });

    final Map<String, String> creds;
    if (_oauth2 != null) {
      final stored = _pendingCredentials ?? await widget.services.extensions.getAccountCredentials(_kvKey);
      if (stored == null) {
        // The read failed. Resetting `_testing` is the point: left true, it
        // disables Test AND Connect for as long as the dialog stays open.
        if (mounted && generation == _testGeneration) {
          setState(() {
            _testing = false;
            _secureStorageUnavailable = true;
          });
        }
        return;
      }
      creds = stored;
    } else {
      creds = _controllers.map((key, controller) => MapEntry(key, controller.text.trim()));
    }

    final res = await widget.services.extensions.testCredentials(widget.account['key'] as String, creds);

    if (mounted && generation == _testGeneration) {
      setState(() {
        _testing = false;
        _testResult = res;
      });
    }
  }

  Future<void> _doOAuth() async {
    if (_startingOAuth) return;
    setState(() => _startingOAuth = true);
    final oauth2 = _oauth2!;
    final issuer = oauth2['issuer'] as String;
    final clientId = oauth2['clientId'] as String;
    final scopes = (oauth2['scopes'] as List).cast<String>();
    // Every platform opens the sign-in page in the operator's own browser.
    // What differs is only how the code comes home: Web, Linux and Windows go
    // through LoFi's webhook relay, everywhere else the OS delivers the
    // native com.ham2k.*.auth:// redirect as a deep link. Web and Linux have
    // no choice; Windows registers the schemes and takes the relay anyway,
    // deliberately — oauth_browser_login.dart's header has the whole rule.
    final useRelay = oauthUsesWebhookRelay();
    final redirectUrl = (useRelay ? oauth2['webhookRedirectUrl'] : oauth2['redirectUrl']) as String?;

    try {
      if (redirectUrl == null) {
        // Only reachable if some future OAuth2 hook doesn't declare
        // webhookRedirectUrl — SOTA always does. Fail with the same relay
        // message rather than a null-check crash three lines down.
        throw Exception(t.settings.accounts.relayLoginUnavailable);
      }

      // Only the relay path needs this device's LoFi identity — the native
      // deep-link path (used on macOS/Android/iOS) never
      // touches LoFi at all. Goes through
      // `connectLofiRealtime` itself (register-and-subscribe, same as boot
      // does) rather than re-deriving that sequence inline — boot may not
      // have reached it yet on a fresh device, so it's still called here,
      // just through the one place that knows how, not a second copy of it.
      LofiClientRegistration? registration;
      if (useRelay) {
        // A CURRENT webhook token, not the cached one: it goes straight into
        // this login's `state`, and the relay refuses an expired one with a
        // message the operator cannot act on.
        registration = await widget.services.connectLofiRealtime(refreshWebhookToken: true);
        if (registration == null) {
          throw Exception(t.settings.accounts.relayLoginUnavailable);
        }
      }

      final userAgent = await ham2kUserAgent();
      final discoveryUrl = Uri.parse('$issuer/.well-known/openid-configuration');
      final response = await http.get(discoveryUrl, headers: {'User-Agent': userAgent});
      if (response.statusCode != 200) throw Exception('Failed to load OIDC discovery: ${response.statusCode}');
      final discovery = jsonDecode(response.body) as Map<String, dynamic>;
      final authEndpoint = discovery['authorization_endpoint'] as String;
      final tokenEndpoint = discovery['token_endpoint'] as String;

      final codeVerifier = _randomString(64);
      final codeChallenge = _sha256Challenge(codeVerifier);
      // On the relay path, `state` carries two jobs at once: a per-attempt
      // CSRF nonce (`n`, so a stale/replayed redirect from a previous
      // attempt can't be mistaken for this one — the whole encoded blob is
      // what gets compared, not just `n` in isolation), and this device's
      // signed webhook-relay token (`t`), which is how LoFi's public
      // callback endpoint knows which client's channel to notify
      // — every compliant OAuth provider is required to echo `state` back
      // unmodified, which is what makes this portable across providers
      // without a per-provider wildcard-redirect negotiation. On the
      // native path `state` is just a plain CSRF nonce, same as always —
      // the redirect_uri itself already identifies this device.
      final state = useRelay
          ? base64Url.encode(utf8.encode(jsonEncode({
              'n': _randomString(16),
              't': registration!.webhookClientToken,
              'p': widget.account['key'],
            })))
          : _randomString(16);

      final authUri = Uri.parse(authEndpoint).replace(
        queryParameters: {
          'response_type': 'code',
          'client_id': clientId,
          'redirect_uri': redirectUrl,
          'scope': scopes.join(' '),
          'state': state,
          'code_challenge': codeChallenge,
          'code_challenge_method': 'S256',
        },
      );

      if (!mounted) return;

      final login = _PendingOAuthLogin(
        authUri: authUri,
        // The waiting body only resolves a login on the relay platforms; on
        // the deep-link ones the listener below is what ends it, so it gets
        // no relay wiring at all.
        expectedState: useRelay ? state : null,
        webhookEvents: useRelay ? widget.services.webhookEvents : null,
        fetchWebhookEvents: useRelay ? widget.services.extensions.fetchLofiWebhookEvents : null,
      );

      StreamSubscription<Uri>? linkSub;
      if (!useRelay) {
        // The sign-in page opens in the operator's own browser, same as the
        // relay platforms; here the provider redirects to a
        // com.ham2k.*.auth:// URL these platforms register, and the OS hands
        // it back through DeepLinkService. This listener is what completes
        // the login — the waiting body carries no relay wiring and never
        // resolves on its own.
        linkSub = widget.services.deepLinks.links.listen((uri) {
          if (!DeepLinkService.isAuthCallback(uri)) return;
          if (uri.queryParameters['state'] != state) {
            // A redirect from an attempt the operator abandoned, or one meant
            // for another login. Dropping it is right; dropping it in silence
            // leaves a pane waiting with no record that anything came back.
            debugPrint('[oauth] ignoring an auth callback for a different attempt');
            return;
          }
          final callbackCode = uri.queryParameters['code'];
          final callbackError = uri.queryParameters['error_description'] ?? uri.queryParameters['error'];
          _resolveOAuth(
            login,
            callbackCode,
            // A redirect whose state matched but that carries neither a code
            // nor an error is the same incomplete answer the relay path
            // names, and it ends the login the same way: with a message,
            // rather than returning the operator to Connect with nothing
            // said and nothing to try differently.
            error: callbackError ?? (callbackCode == null ? t.settings.accounts.loginIncompleteResponse : null),
          );
        }, onError: (Object e, StackTrace st) => ErrorReportingService.report(e, st, context: 'deep-link:auth-callback'));
      }

      String? code;
      setState(() => _oauthLogin = login);
      try {
        code = await login.completer.future;
      } finally {
        // The UI comes back FIRST, and a cancel that misbehaves cannot stop
        // it: `linkSub` rides a plugin event channel, and one that throws (or
        // never returns) would otherwise leave the spinner up for good, with
        // Connect unreachable behind it and "login failed" in the status bar
        // beside it. Not `mounted` when the pane was closed mid-login:
        // `dispose` resolved the completer on the way out, and there is no
        // State left to update.
        if (mounted) setState(() => _oauthLogin = null);
        try {
          await linkSub?.cancel();
        } catch (e, stack) {
          ErrorReportingService.report(e, stack, context: 'oauth:cancelLinkSub');
        }
      }
      final authError = login.error;

      if (code == null) {
        if (authError != null) throw Exception(authError);
        return;
      }

      // The pane (an Escape-dismissible ModalPaneRoute) can have been closed
      // while the system-browser login above was in progress —
      // nothing left to update, and no Save button left to hold
      // `_pendingCredentials` for.
      if (!mounted) return;
      setState(() => _testing = true);

      final tokenResponse = await http.post(
        // Through Ham2K's CORS proxy on web, direct everywhere else — SOTA's
        // Keycloak sends this endpoint no Access-Control-Allow-Origin, so a
        // browser refuses the exchange after the sign-in has already
        // succeeded. The extension's own refresh grant takes the same route
        // (halo_extension_host's _resolveFetchUri).
        ham2kSsoFetchUri(Uri.parse(tokenEndpoint), onWeb: kIsWeb),
        headers: {'Content-Type': 'application/x-www-form-urlencoded', 'User-Agent': userAgent},
        body: {
          'grant_type': 'authorization_code',
          'client_id': clientId,
          'code': code,
          'redirect_uri': redirectUrl,
          'code_verifier': codeVerifier,
        },
      );

      if (tokenResponse.statusCode != 200) {
        // The status leads, and the body is capped: on web this went through
        // Ham2K's CORS proxy, so a failure body can be an HTML error page,
        // and a status bar showing `<!DOCTYPE html>…` buries the one fact
        // that identifies which hop refused.
        final detail = tokenResponse.body.length > 200
            ? '${tokenResponse.body.substring(0, 200)}…'
            : tokenResponse.body;
        throw Exception('Failed to exchange code (HTTP ${tokenResponse.statusCode}): $detail');
      }

      final tokens = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
      final credentials = <String, String>{};
      if (tokens['access_token'] != null) credentials['accessToken'] = tokens['access_token'] as String;
      if (tokens['refresh_token'] != null) credentials['refreshToken'] = tokens['refresh_token'] as String;
      if (tokens['id_token'] != null) credentials['idToken'] = tokens['id_token'] as String;

      // Same reason as above — the pane may have closed during the token
      // exchange itself.
      if (!mounted) return;
      // Held until the user presses Save — nothing is persisted yet.
      setState(() {
        _pendingCredentials = credentials;
        _testing = false;
      });
      // Verify the fresh tokens right away, same as opening with stored ones.
      await _test();
    } catch (e) {
      if (mounted) {
        setState(() => _testing = false);
        widget.services.statusBar.setMessage(key: 'accounts:login', text: t.settings.accounts.loginFailed(error: e));
      }
    } finally {
      if (mounted) {
        setState(() => _startingOAuth = false);
      } else {
        _startingOAuth = false;
      }
    }
  }

  String _randomString(int length) {
    final rand = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    return List.generate(length, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  String _sha256Challenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final oauthLogin = _oauthLogin;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_oauth2 != null) ...[
          if (oauthLogin != null) ...[
            OAuthBrowserLoginBody(
              // A second attempt is a fresh wait, not the previous one
              // carrying over its timers, its launch failure and its
              // 90-seconds-of-silence message.
              key: ObjectKey(oauthLogin),
              authUri: oauthLogin.authUri,
              expectedState: oauthLogin.expectedState,
              webhookEvents: oauthLogin.webhookEvents,
              fetchWebhookEvents: oauthLogin.fetchWebhookEvents,
              onCode: (code) => _resolveOAuth(oauthLogin, code),
              onError: (error) => _resolveOAuth(oauthLogin, null, error: error),
              onCancel: () => _resolveOAuth(oauthLogin, null),
            ),
          ] else if (_pendingCredentials != null) ...[
            Text(
              context.t.settings.accounts.loggedInAs(
                  identity: ExtensionService.identityFromCredentials(_pendingCredentials!) ??
                      '${widget.account['label']}'),
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.md),
            Text(
              context.t.settings.accounts.pressSaveToKeep,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ] else if (_secureStorageUnavailable) ...[
            Text(
              storageUnavailableMessage(context),
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ] else if (_loggedIn) ...[
            Text(
              context.t.settings.accounts.connectedTo(label: '${widget.account['label']}'),
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ] else ...[
            OutlinedButton(
                onPressed: (_testing || _startingOAuth) ? null : _doOAuth,
                child: Text(context.t.settings.accounts.connect)),
          ],
        ] else ...[
          ..._fields.map((field) {
            final key = field['key'] as String;
            final preface = field['preface'] as String?;
            final postface = field['postface'] as String?;
            final controller = _controllers[key];

            if (controller == null) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (preface != null && preface.isNotEmpty) ...[
                    MarkdownBody(data: preface, styleSheet: withEmojiFallback(MarkdownStyleSheet.fromTheme(theme))),
                    const SizedBox(height: Space.md),
                  ],
                  if (field['type'] == 'secret')
                    SecretTextField(
                      controller: controller,
                      style: theme.textTheme.bodyLarge?.copyWith(fontSize: 15),
                      decoration: poloFieldDecoration(
                        context,
                        field['label'] as String,
                      ).copyWith(errorText: _fieldError(key, controller.text)),
                      onChanged: (_) => setState(() {}),
                    )
                  else
                    TextField(
                      selectAllOnFocus: false,
                      controller: controller,
                      style: theme.textTheme.bodyLarge?.copyWith(fontSize: 15),
                      keyboardType: field['type'] == 'email' ? TextInputType.emailAddress : TextInputType.text,
                      decoration: poloFieldDecoration(
                        context,
                        field['label'] as String,
                      ).copyWith(errorText: _fieldError(key, controller.text)),
                      onChanged: (_) => setState(() {}),
                    ),
                  if (postface != null && postface.isNotEmpty) ...[
                    const SizedBox(height: Space.md),
                    MarkdownBody(data: postface, styleSheet: withEmojiFallback(MarkdownStyleSheet.fromTheme(theme))),
                  ],
                ],
              ),
            );
          }),
        ],
        if (_loggedIn && _pendingCredentials == null) ...[
          const SizedBox(height: Space.md),
          Center(
            child: OutlinedButton(
              onPressed: _clear,
              child: Text(context.t.settings.accounts.disconnect),
            ),
          ),
        ],
        // Hidden while a sign-in is in flight: it can only report on the
        // credentials this dialog opened with, which are the ones being
        // replaced — and a stale verdict beside a spinner reads as this
        // login's own progress.
        if (oauthLogin == null) ...[
          const SizedBox(height: Space.xl),
          const Divider(),
          const SizedBox(height: Space.md),
          Text(
            context.t.settings.accounts.connectedAs,
            style: theme.textTheme.titleSmall?.copyWith(color: HaLoColors.of(context).onSurfaceAccent),
          ),
          const SizedBox(height: Space.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(Space.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _testing
                      ? const SizedBox(
                          height: 20,
                          child: Center(child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                        )
                      : MarkdownBody(
                          data: _testResult ?? '—',
                          styleSheet: withEmojiFallback(MarkdownStyleSheet.fromTheme(theme)),
                        ),
                ),
              ),
              const SizedBox(width: Space.md),
              TextButton(onPressed: _testing ? null : _test, child: Text(context.t.settings.accounts.test)),
            ],
          ),
        ],
        const SizedBox(height: Space.xxl),
        haloDialogFooterRow(
          // Disabled during a sign-in, like Save: closing the whole dialog
          // abandons the login through `dispose`, which reads as the same
          // gesture as the waiting body's own "Cancel sign-in" and is not.
          // The pane's header close button remains, so this is about telling
          // the two apart, not about trapping the operator in the wait.
          cancel: TextButton(
              onPressed: oauthLogin == null ? () => Navigator.of(context).pop() : null,
              child: Text(context.t.common.cancel)),
          actions: [
            FilledButton(onPressed: oauthLogin == null ? _save : null, child: Text(context.t.common.save)),
          ],
        ),
      ],
    );
  }
}

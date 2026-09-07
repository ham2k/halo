// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The browser leg of an OAuth login, rendered INSIDE the account pane that
// started it rather than on a route of its own — on every platform and both
// paths below, so there is one waiting surface to reason about. That is why
// this carries no Scaffold, no AppBar and no `Navigator.pop`: it reports what
// came back through [OAuthBrowserLoginBody]'s callbacks, and the pane owns
// both the chrome around it and the completer waiting on the result.
//
// Every platform runs this leg: the provider's sign-in page belongs in the
// operator's OWN browser, where their session with that provider already is,
// and never in an embedded webview wearing the app's chrome (see
// `links_leave_the_app_test.dart` for the same rule applied to ordinary
// links).
//
// What differs per platform is only how the authorization code comes HOME,
// and `oauthUsesWebhookRelay` picks between the two:
//
// - **Deep link** (macOS, iOS, Android): the provider redirects to a
//   `com.ham2k.*.auth://` URL, which those platforms register and deliver
//   through `DeepLinkService`; `_doOAuth`'s own listener is what ends the
//   wait. This body then carries no relay wiring at all, and nothing in it
//   can resolve the login on its own.
// - **Relay** (Web, Linux, Windows): the `redirect_uri` is LoFi's fixed
//   webhook-relay URL instead
//   (https://lofi.ham2k.net/v1/webhooks/client/oauth), the browser lands on
//   LoFi's own confirmation page, and LoFi's server-side receiver creates a
//   WebhookEvent and Pusher-pings this device's channel — with periodic
//   polling as the fallback for a missed ping. Here the body itself is what
//   spots the result and hands it back.
//
// Web and Linux have no choice: a browser tab navigating to a non-http(s)
// scheme just fails, and nothing in Linux's .desktop/GTK setup receives the
// scheme (HALO-121). Windows DOES register the schemes — the Inno script and
// `windows_url_schemes.dart` both write them (HALO-178) — and stays on the
// relay anyway, deliberately. Do not "fix" that by moving Windows to the
// deep-link branch on the strength of the registration alone.
//
// The relay is not free, and the cost is worth stating because it is what a
// Windows sign-in failure will look like: a login depends on LoFi being
// reachable AND on this device holding a sync registration, neither of which
// the deep-link platforms need at all.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../services/error_reporting_service.dart';
import '../services/pusher_service.dart';

/// How long the body keeps saying it is waiting before it says instead that
/// nothing has come back. Generous: a first-time sign-in means finding a
/// password, and possibly a second factor.
const _noResponseAfter = Duration(seconds: 90);

/// Consecutive failed relay fetches before the body stops calling it waiting.
const _failuresBeforeSayingSo = 3;

/// Whether this platform gets the authorization code home through the webhook
/// relay rather than the native `com.ham2k.*.auth://` redirect: Web (a browser
/// tab navigating to a non-http(s) scheme just fails), Linux (nothing in the
/// `.desktop`/GTK setup receives the scheme — HALO-121) and Windows.
/// Everywhere else the redirect comes back through `DeepLinkService`.
///
/// Windows is the one that is a CHOICE, not a limitation: it registers the
/// schemes (HALO-178) and could take the deep link, and stays on the relay
/// regardless.
///
/// This is NOT a choice about where the sign-in page opens. That is settled:
/// the system browser, on every platform.
///
/// [isWeb] and [platform] are injectable so every answer is testable:
/// `kIsWeb` is a
/// compile-time constant `flutter test` can't flip, and `defaultTargetPlatform`
/// is overridable with `debugDefaultTargetPlatformOverride` while
/// `Platform.isLinux` is not — a Linux-only branch no test on this project's
/// macOS/Ubuntu CI runners could ever enter (`flutter test` reports `android`
/// regardless of host).
bool oauthUsesWebhookRelay({TargetPlatform? platform, bool? isWeb}) {
  if (isWeb ?? kIsWeb) return true;
  final resolved = platform ?? defaultTargetPlatform;
  return resolved == TargetPlatform.linux || resolved == TargetPlatform.windows;
}

/// The waiting body: opens [authUri] in the system browser, then waits for
/// the authorization code to come home.
///
/// On the relay platforms that means reacting instantly to a [webhookEvents]
/// Pusher ping when one arrives, and polling [fetchWebhookEvents] every
/// [pollInterval] regardless, since a missed ping shouldn't strand the
/// operator here. On the deep-link platforms all three are null and this body
/// only waits: `_doOAuth`'s own `DeepLinkService` listener is what ends it.
///
/// Reports through exactly one of [onCode], [onError] or [onCancel], and the
/// host is free to keep this mounted afterwards — the callbacks are the whole
/// contract, and none of them is allowed to fire twice (see `_resolved`).
/// [onError] carries a provider error out the same way a `code`-less webhook
/// event does — a redirect that says "access_denied" has no code to report.
class OAuthBrowserLoginBody extends StatefulWidget {
  final Uri authUri;

  /// The relay wiring — all three null together on the deep-link platforms,
  /// where nothing here is what completes the login. Anything less than all
  /// three is a caller that thinks it is on the relay and isn't: asserted in
  /// the constructor rather than discovered as a page that waits forever.
  ///
  /// [expectedState] is the exact `state` this login's authorization request
  /// was sent with — every compliant OAuth provider echoes it back unmodified,
  /// so an exact string match is what ties an incoming webhook event to this
  /// attempt (see settings/accounts_panel.dart's `_doOAuth` for how it's built: a nonce
  /// plus this device's signed webhook-relay token).
  final String? expectedState;

  final Stream<PusherEvent>? webhookEvents;
  final Future<List<Map<String, dynamic>>> Function()? fetchWebhookEvents;

  /// The authorization code came home.
  final void Function(String code) onCode;

  /// The login ended in a message rather than a code.
  final void Function(String error) onError;

  /// The operator gave up on it.
  final VoidCallback onCancel;

  /// Overridden in tests, where launching a browser is neither possible nor
  /// the point. Answers whether the browser was opened.
  final Future<bool> Function(Uri uri)? launcher;

  final Duration pollInterval;

  const OAuthBrowserLoginBody({
    super.key,
    required this.authUri,
    required this.onCode,
    required this.onError,
    required this.onCancel,
    this.expectedState,
    this.webhookEvents,
    this.fetchWebhookEvents,
    this.launcher,
    this.pollInterval = const Duration(seconds: 4),
  }) : assert(
          (expectedState == null) == (webhookEvents == null) &&
              (expectedState == null) == (fetchWebhookEvents == null),
          'the relay wiring is all three or none',
        );

  @override
  State<OAuthBrowserLoginBody> createState() => _OAuthBrowserLoginBodyState();
}

class _OAuthBrowserLoginBodyState extends State<OAuthBrowserLoginBody> {
  bool _launchFailed = false;
  bool _checking = false;
  // Set the instant a result is found, before the callback even fires — the
  // server doesn't consume a webhook event on GET (only a separate `consume`
  // call would, and nothing here makes it), so it stays fetchable by a poll
  // tick or ping that lands afterwards, and the host is free to leave this
  // body mounted once it has its answer. Reporting a second time would
  // complete an already-completed login. `_checking` alone doesn't cover that
  // window since it's cleared once `fetchWebhookEvents` returns.
  bool _resolved = false;
  StreamSubscription<PusherEvent>? _pingSub;
  Timer? _pollTimer;
  Timer? _deadline;

  /// Consecutive failed relay fetches. The relay's own transport reports a
  /// dead host as an EMPTY event list rather than an error
  /// (`ExtensionService.fetchLofiWebhookEvents`), so a throw reaching here is
  /// the only failure this body can actually see — and one is not yet news,
  /// since a single dropped request is what the polling exists to absorb.
  int _fetchFailures = 0;

  /// What to say instead of "waiting", once waiting has stopped being an
  /// honest description. Null while it still is.
  String Function(Translations t)? _trouble;

  @override
  void initState() {
    super.initState();
    unawaited(_openBrowser());
    // Waiting forever is the one thing this body must not do. Nothing here
    // can tell "the operator is still typing their password" from "the code is
    // never coming" — a deep link the OS never delivered, a browser that
    // refused the hand-off, a sign-in finished on another device — so after a
    // while it stops claiming the first and says what the operator can do.
    _deadline = Timer(_noResponseAfter, () {
      if (!mounted || _resolved || _trouble != null) return;
      setState(() => _trouble = (t) => t.settings.accounts.loginNoResponse);
    });

    final webhookEvents = widget.webhookEvents;
    // Nothing to listen to or poll on a deep-link platform — the code arrives
    // as a URL the OS hands back, and the caller's listener is what ends the
    // wait.
    if (webhookEvents == null) return;
    _pingSub = webhookEvents.listen((_) => unawaited(_checkForResult()));
    _pollTimer = Timer.periodic(widget.pollInterval, (_) => unawaited(_checkForResult()));
    // The operator may finish the browser leg before either the first poll
    // tick or a ping arrives — check once right away too, in case a
    // previous attempt's event (or an implausibly fast one) is already sitting
    // there.
    unawaited(_checkForResult());
  }

  @override
  void dispose() {
    unawaited(_pingSub?.cancel());
    _pollTimer?.cancel();
    _deadline?.cancel();
    super.dispose();
  }

  Future<void> _openBrowser() async {
    final launcher = widget.launcher ?? (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
    var opened = false;
    try {
      opened = await launcher(widget.authUri);
    } catch (e, stack) {
      // The operator's screen can only say "couldn't open your browser"; a
      // sandbox denial, a platform with no handler registered, and a plugin
      // that never registered at all all look identical from there, and a bug
      // report carrying that sentence is unanswerable without this.
      ErrorReportingService.report(e, stack, context: 'oauth:openBrowser');
      opened = false;
    }
    if (mounted) setState(() => _launchFailed = !opened);
  }

  /// Fetches pending webhook events and looks for the one this login's
  /// `state` matches. Re-entrant calls (a ping arriving mid-poll) are
  /// dropped rather than queued — the next tick or ping covers it.
  Future<void> _checkForResult() async {
    if (_checking || _resolved || !mounted) return;
    _checking = true;
    try {
      final fetch = widget.fetchWebhookEvents;
      // Not `!`: the assert that pairs the relay wiring is stripped in a
      // release build, where a caller that passed only some of it would throw
      // here on every tick — inside an unawaited future, leaving exactly the
      // page-that-waits-forever the assert exists to prevent.
      if (fetch == null) return;
      final events = await fetch();
      _fetchFailures = 0;
      if (!mounted || _resolved) return;
      for (final event in events) {
        final payload = event['payload'];
        if (payload is! Map || payload['state'] != widget.expectedState) continue;

        // Latched before reporting: the event stays fetchable server-side
        // (see the field comment), so a later trigger must not act on it a
        // second time.
        _resolved = true;
        final error = payload['error_description'] ?? payload['error'];
        final code = payload['code'];
        if (code is String && code.isNotEmpty) {
          widget.onCode(code);
        } else {
          // Either the provider's own `error`, or — no `code` and no
          // `error` — a malformed/incomplete relay payload. Both end the
          // login with a message rather than leaving the operator waiting on
          // an event that already arrived and will never look any different
          // on the next poll.
          widget.onError(error?.toString() ?? t.settings.accounts.loginIncompleteResponse);
        }
        return;
      }
    } catch (e, stack) {
      _fetchFailures++;
      if (_fetchFailures == _failuresBeforeSayingSo) {
        ErrorReportingService.report(e, stack, context: 'oauth:relayPoll');
        if (mounted && !_resolved) {
          setState(() => _trouble = (t) => t.settings.accounts.relayLoginUnavailable);
        }
      }
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.settings.accounts;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.browserLoginTitle,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Space.lg),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: Space.lg),
        Text(
          _trouble?.call(context.t) ?? (_launchFailed ? t.relayLoginNotOpened : t.relayLoginWaiting),
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Space.lg),
        OutlinedButton(
          onPressed: () => unawaited(_openBrowser()),
          child: Text(t.openInBrowser),
        ),
        const SizedBox(height: Space.md),
        // Distinct from the pane's own Cancel, which closes the whole dialog:
        // this abandons the sign-in and leaves the operator back at Connect.
        TextButton(
          onPressed: widget.onCancel,
          child: Text(t.cancelLogin),
        ),
      ],
    );
  }
}

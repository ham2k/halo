// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The browser leg of an OAuth login. Every platform runs it: the provider's
// sign-in page belongs in the operator's OWN browser, where their session with
// that provider already is, and never in an embedded webview wearing the app's
// chrome (see `links_leave_the_app_test.dart` for the same rule applied to
// ordinary links).
//
// What differs per platform is only how the authorization code comes HOME,
// and `oauthUsesWebhookRelay` picks between the two:
//
// - **Deep link** (macOS, iOS, Android): the provider redirects to a
//   `com.ham2k.*.auth://` URL, which those platforms register and deliver
//   through `DeepLinkService`; `_doOAuth`'s own listener pops this page with
//   the code. This page then carries no relay wiring at all.
// - **Relay** (Web, Linux, Windows): those platforms cannot receive that
//   redirect — a browser tab navigating to a non-http(s) scheme just fails,
//   and neither Linux nor Windows registers the schemes (HALO-178, HALO-121).
//   So the `redirect_uri` is LoFi's fixed webhook-relay URL instead
//   (https://lofi.ham2k.net/v1/webhooks/client/oauth), the browser lands on
//   LoFi's own confirmation page, and LoFi's server-side receiver creates a
//   WebhookEvent and Pusher-pings this device's channel — with periodic
//   polling as the fallback for a missed ping.
//
// The relay is not free: it makes a login depend on LoFi being reachable and
// on this device holding a sync registration, which the deep-link platforms
// need for nothing. That is the price Windows pays for signing in through the
// operator's own browser, and registering its schemes (HALO-178) is what would
// buy it back.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../i18n/strings.g.dart';
import '../services/error_reporting_service.dart';
import '../services/pusher_service.dart';

/// How long the page keeps saying it is waiting before it says instead that
/// nothing has come back. Generous: a first-time sign-in means finding a
/// password, and possibly a second factor.
const _noResponseAfter = Duration(seconds: 90);

/// Consecutive failed relay fetches before the page stops calling it waiting.
const _failuresBeforeSayingSo = 3;

/// Whether this platform needs the webhook relay to get the authorization code
/// home, because it cannot receive the native `com.ham2k.*.auth://` redirect:
/// Web (a browser tab navigating to a non-http(s) scheme just fails), Linux
/// (nothing in the `.desktop`/GTK setup receives the scheme — HALO-121) and
/// Windows (the schemes are not registered — HALO-178). Everywhere else the
/// redirect comes back through `DeepLinkService`.
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

/// The waiting page: opens [authUri] in the system browser, then waits for
/// the authorization code to come home.
///
/// On the relay platforms that means reacting instantly to a [webhookEvents]
/// Pusher ping when one arrives, and polling [fetchWebhookEvents] every
/// [pollInterval] regardless, since a missed ping shouldn't strand the
/// operator here. On the deep-link platforms all three are null and this page
/// only waits: `_doOAuth`'s own `DeepLinkService` listener is what pops it.
///
/// Pops with the authorization code, or null when the operator cancels.
/// [onError] carries a provider error out the same way a `code`-less
/// webhook event does — a redirect that says "access_denied" has no code
/// to pop.
class OAuthBrowserLoginPage extends StatefulWidget {
  final String accountLabel;
  final Uri authUri;

  /// The relay wiring — all three null together on the deep-link platforms,
  /// where nothing here is what completes the login. Anything less than all
  /// three is a caller that thinks it is on the relay and isn't: asserted in
  /// the constructor rather than discovered as a page that waits forever.
  ///
  /// [expectedState] is the exact `state` this login's authorization request
  /// was sent with — every compliant OAuth provider echoes it back unmodified,
  /// so an exact string match is what ties an incoming webhook event to this
  /// attempt (see settings_view.dart's `_doOAuth` for how it's built: a nonce
  /// plus this device's signed webhook-relay token).
  final String? expectedState;

  final Stream<PusherEvent>? webhookEvents;
  final Future<List<Map<String, dynamic>>> Function()? fetchWebhookEvents;
  final void Function(String error)? onError;

  /// Overridden in tests, where launching a browser is neither possible nor
  /// the point. Answers whether the browser was opened.
  final Future<bool> Function(Uri uri)? launcher;

  final Duration pollInterval;

  const OAuthBrowserLoginPage({
    super.key,
    required this.accountLabel,
    required this.authUri,
    this.expectedState,
    this.webhookEvents,
    this.fetchWebhookEvents,
    this.onError,
    this.launcher,
    this.pollInterval = const Duration(seconds: 4),
  }) : assert(
          (expectedState == null) == (webhookEvents == null) &&
              (expectedState == null) == (fetchWebhookEvents == null),
          'the relay wiring is all three or none',
        );

  @override
  State<OAuthBrowserLoginPage> createState() => _OAuthBrowserLoginPageState();
}

class _OAuthBrowserLoginPageState extends State<OAuthBrowserLoginPage> {
  bool _launchFailed = false;
  bool _checking = false;
  // Set the instant a result is found, before the pop even fires — the
  // server doesn't consume a webhook event on GET (only a separate `consume`
  // call would, and nothing here makes it), so it stays fetchable by a poll
  // tick or ping that lands while this route's pop is still transitioning
  // out (the widget stays `mounted` for that whole animation). `_checking`
  // alone doesn't cover that window since it's cleared once `fetchWebhookEvents`
  // returns, well before the pop completes.
  bool _resolved = false;
  StreamSubscription<PusherEvent>? _pingSub;
  Timer? _pollTimer;
  Timer? _deadline;

  /// Consecutive failed relay fetches. The relay's own transport reports a
  /// dead host as an EMPTY event list rather than an error
  /// (`ExtensionService.fetchLofiWebhookEvents`), so a throw reaching here is
  /// the only failure this page can actually see — and one is not yet news,
  /// since a single dropped request is what the polling exists to absorb.
  int _fetchFailures = 0;

  /// What to say instead of "waiting", once waiting has stopped being an
  /// honest description. Null while it still is.
  String Function(Translations t)? _trouble;

  @override
  void initState() {
    super.initState();
    unawaited(_openBrowser());
    // Waiting forever is the one thing this page must not do. Nothing here
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
    // as a URL the OS hands back, and the caller's listener pops this route.
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

        // Latched before popping: the event stays fetchable server-side
        // (see the field comment), so a later trigger landing during this
        // pop's exit transition must not act on it a second time.
        _resolved = true;
        final error = payload['error_description'] ?? payload['error'];
        final code = payload['code'];
        if (code is String && code.isNotEmpty) {
          Navigator.of(context).pop(code);
        } else {
          // Either the provider's own `error`, or — no `code` and no
          // `error` — a malformed/incomplete relay payload. Both end the
          // login with a message rather than leaving the page waiting on an
          // event that already arrived and will never look any different on
          // the next poll.
          widget.onError?.call(error?.toString() ?? t.settings.accounts.relayLoginMalformedEvent);
          Navigator.of(context).pop();
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
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: windowHeaderGestureArea(),
        title: Text(t.connectTo(label: widget.accountLabel)),
        leadingWidth: macOSAwareLeadingWidth(context),
        leading: isMacOSChromelessWindow
            ? Padding(
                padding: EdgeInsets.only(left: macOSTrafficLightClearance(context)),
                child: CloseButton(onPressed: () => Navigator.of(context).pop()),
              )
            : CloseButton(onPressed: () => Navigator.of(context).pop()),
        actions: [windowsCaptionSpacer(context)],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(Space.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t.browserLoginTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.xl),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: Space.xl),
                Text(
                  _trouble?.call(context.t) ?? (_launchFailed ? t.relayLoginNotOpened : t.relayLoginWaiting),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.xl),
                OutlinedButton(
                  onPressed: () => unawaited(_openBrowser()),
                  child: Text(t.openInBrowser),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The OAuth login leg for platforms that can't catch a custom-scheme
// redirect at all (HALO-22): Web (a browser tab navigating to a non-http(s)
// scheme just fails) and Linux (`flutter_inappwebview` ships no Linux
// implementation, and nothing in the app's `.desktop`/GTK setup can receive
// the scheme as a deep link either — see the git history of the now-deleted
// oauth_browser_login.dart for the full rationale). Everywhere else
// (macOS/Windows/Android/iOS) `_doOAuth` (settings_view.dart) still uses the
// original in-app webview + `DeepLinkService` interception, unchanged —
// `oauthUsesWebhookRelay` below is what picks between the two.
//
// Here, SOTA's `redirect_uri` is LoFi's fixed webhook-relay URL
// (https://lofi.ham2k.net/v1/webhooks/client/oauth) instead of a
// `com.ham2k.*.auth://` custom scheme, so there's no redirect for the device
// to intercept directly — the browser lands on LoFi's own confirmation page
// instead. The only way home is the relay: LoFi's server-side receiver
// (HALO-65) creates a WebhookEvent and Pusher-pings this device's channel
// (HALO-66), with periodic polling as the fallback for a missed ping.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../i18n/strings.g.dart';
import '../services/pusher_service.dart';

/// Whether this platform has to go through the webhook relay because it
/// can't catch SOTA's native `com.ham2k.*.auth://` redirect at all — Web (a
/// browser tab navigating to a non-http(s) scheme just fails) and Linux (no
/// in-app webview, no working deep-link delivery either). Everywhere else,
/// the original webview+deep-link flow in `_doOAuth` still applies.
///
/// [isWeb] and [platform] are injectable so both answers are testable, same
/// reasoning as the deleted `oauthNeedsSystemBrowser` had: `kIsWeb` is a
/// compile-time constant `flutter test` can't flip, and `defaultTargetPlatform`
/// is overridable with `debugDefaultTargetPlatformOverride` while
/// `Platform.isLinux` is not — a Linux-only branch no test on this project's
/// macOS/Ubuntu CI runners could ever enter (`flutter test` reports `android`
/// regardless of host).
bool oauthUsesWebhookRelay({TargetPlatform? platform, bool? isWeb}) {
  if (isWeb ?? kIsWeb) return true;
  return (platform ?? defaultTargetPlatform) == TargetPlatform.linux;
}

/// The waiting page: opens [authUri] in the system browser, then waits for
/// the webhook relay to deliver the authorization code (or a provider
/// error) — reacting instantly to a `webhookEvents` Pusher ping when one
/// arrives, and polling [fetchWebhookEvents] every [pollInterval]
/// regardless, since a missed ping shouldn't strand the operator here.
///
/// Pops with the authorization code, or null when the operator cancels.
/// [onError] carries a provider error out the same way a `code`-less
/// webhook event does — a redirect that says "access_denied" has no code
/// to pop.
class OAuthRelayLoginPage extends StatefulWidget {
  final String accountLabel;
  final Uri authUri;

  /// The exact `state` this login's authorization request was sent with —
  /// every compliant OAuth provider echoes it back unmodified, so an exact
  /// string match is what ties an incoming webhook event to this attempt
  /// (see settings_view.dart's `_doOAuth` for how it's built: a nonce plus
  /// this device's signed webhook-relay token).
  final String expectedState;

  final Stream<PusherEvent> webhookEvents;
  final Future<List<Map<String, dynamic>>> Function() fetchWebhookEvents;
  final void Function(String error)? onError;

  /// Overridden in tests, where launching a browser is neither possible nor
  /// the point. Answers whether the browser was opened.
  final Future<bool> Function(Uri uri)? launcher;

  final Duration pollInterval;

  const OAuthRelayLoginPage({
    super.key,
    required this.accountLabel,
    required this.authUri,
    required this.expectedState,
    required this.webhookEvents,
    required this.fetchWebhookEvents,
    this.onError,
    this.launcher,
    this.pollInterval = const Duration(seconds: 4),
  });

  @override
  State<OAuthRelayLoginPage> createState() => _OAuthRelayLoginPageState();
}

class _OAuthRelayLoginPageState extends State<OAuthRelayLoginPage> {
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

  @override
  void initState() {
    super.initState();
    unawaited(_openBrowser());
    _pingSub = widget.webhookEvents.listen((_) => unawaited(_checkForResult()));
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
    super.dispose();
  }

  Future<void> _openBrowser() async {
    final launcher = widget.launcher ?? (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
    var opened = false;
    try {
      opened = await launcher(widget.authUri);
    } catch (_) {
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
      final events = await widget.fetchWebhookEvents();
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
          // the next poll (Rule 12: fail loud, don't strand the operator on
          // a spinner that can't resolve).
          widget.onError?.call(error?.toString() ?? t.settings.accounts.relayLoginMalformedEvent);
          Navigator.of(context).pop();
        }
        return;
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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t.browserLoginTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 16),
                Text(
                  _launchFailed ? t.relayLoginNotOpened : t.relayLoginWaiting,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
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

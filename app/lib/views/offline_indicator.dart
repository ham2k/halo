// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The status bar's offline icon and the detail behind it.
//
// This is the operator's answer to "why is nothing updating?", which is why
// it is a permanent status at the left of the status bar rather than a
// notice: a notice is an event and gets dismissed, and connectivity is a
// state that lasts as long as it lasts. Everything it reports is about the
// INTERNET — peer sync over LAN and BLE keeps working while this icon says
// offline, and the detail says so.

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../services/connectivity_service.dart';

/// Opens the detail behind the connectivity status.
///
/// Takes the ROOT navigator's key rather than a context: the status footer is
/// drawn ABOVE the Navigator (it owns the bottom of the window, outside every
/// route), so the tapped row's own context has no Navigator ancestor and
/// `showDialog` on it throws. Same reason main.dart's other chrome-level
/// dialogs go through this key.
void showOfflineDetail({
  required GlobalKey<NavigatorState> navigatorKey,
  required Future<SyncRetryOutcome> Function() onRetry,
  required DateTime? Function() nextAttemptAt,
}) {
  final navigatorContext = navigatorKey.currentContext;
  if (navigatorContext == null) {
    // The operator opened a menu and chose this line; nothing happening at all
    // is worse than an error, and it means the chrome outlived the navigator.
    debugPrint('[status-bar] no navigator for the connectivity detail');
    return;
  }
  showHaloDialog<void>(
    context: navigatorContext,
    builder: (_) => _OfflineDetailDialog(onRetry: onRetry, nextAttemptAt: nextAttemptAt),
  );
}

class _OfflineDetailDialog extends StatefulWidget {
  final Future<SyncRetryOutcome> Function() onRetry;
  final DateTime? Function() nextAttemptAt;

  const _OfflineDetailDialog({required this.onRetry, required this.nextAttemptAt});

  @override
  State<_OfflineDetailDialog> createState() => _OfflineDetailDialogState();
}

class _OfflineDetailDialogState extends State<_OfflineDetailDialog> {
  bool _retrying = false;

  /// What the last retry came back with, or null before one has been tried.
  /// Held rather than shown as a transient: an operator who taps and sees the
  /// spinner come and go has learned nothing about whether we tried.
  SyncRetryOutcome? _outcome;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _outcome = null;
    });
    SyncRetryOutcome? outcome;
    try {
      outcome = await widget.onRetry();
    } finally {
      // The sheet no longer closes itself, so a throw here would leave the
      // button reading "Trying…" and disabled for as long as the operator
      // keeps it open — the one control on the sheet, dead, with the reason
      // somewhere in ErrorPolicy's hands rather than on screen.
      if (mounted) {
        setState(() {
          _retrying = false;
          _outcome = outcome;
        });
      }
    }
    // Deliberately does NOT close on success: the operator asked a question,
    // and the answer is on this sheet — the outcome line, and the services
    // list rewriting itself as they watch. A sheet that vanished on the good
    // outcome would be the one case where pressing the button tells you
    // nothing. Done is what closes it.
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilt on every connectivity edge, not just on a retry: the title now
    // ASSERTS a live state ("Internet: connected") and the sheet deliberately
    // stays open, so a probe that succeeds in the background while it is up
    // would otherwise leave it saying OFFLINE above a services list that has
    // rewritten itself to all-green.
    return StreamBuilder<bool>(
      stream: ConnectivityService.offlineChanges,
      initialData: ConnectivityService.isOffline,
      builder: (context, snapshot) => _dialog(context, snapshot.data ?? ConnectivityService.isOffline),
    );
  }

  Widget _dialog(BuildContext context, bool offline) {
    final t = context.t.offline;
    final theme = Theme.of(context);
    return HaloDialog(
      // The status bar's own line, verbatim: this sheet is what that line
      // opens, and a title saying something else reads as a different subject.
      title: Text(offline ? t.statusOffline : t.statusOnline),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Which half we are in. The operator sees one offline state, but
          // the two have different things to try: no route at all is a
          // radio or a coverage problem, while a route that answers nothing
          // is usually a sign-in page waiting in a browser.
          Text(offline ? (ConnectivityService.hasNoRoute ? t.noRoute : t.unreachable) : t.reachable),
          // What stops is only true while it is stopped — the same lines
          // read as a warning about nothing when everything is answering.
          if (offline) ...[const SizedBox(height: Space.md), Text(t.whatStops, style: theme.textTheme.bodySmall)],
          const SizedBox(height: Space.lg),
          Text(t.servicesTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: Space.xs),
          OncePerSecond(builder: (_, now) => _services(context, now)),
          // The outcome sits in the content, not the footer: it is a report
          // on what just happened and has to stay readable while the footer
          // wraps on a narrow window.
          if (_outcome != null && !_retrying) ...[const SizedBox(height: Space.md), Text(_outcomeMessage(t, _outcome!), style: theme.textTheme.bodySmall)],
        ],
      ),
      // Done is the emphasis AND the trailing button, and Retry is neither:
      // the sheet is read far more often than it is acted on, and the retry it
      // offers is one the app is already making on a schedule of its own (see
      // the next-attempt line above).
      //
      // Retry goes in `secondary:` — "something else to DO", which is exactly
      // what it is — rather than Done going in `actions:`: a way out of a
      // dialog belongs in `cancel:` (docs/design/user-interface.md §Dialogs),
      // and `dialog_footer_convention_test` fails the build on one passed
      // through `actions:`. With `actions` empty the cancel slot IS the
      // trailing edge, which is where the emphasis belongs.
      secondary: TextButton(onPressed: _retrying ? null : _retry, child: Text(_retrying ? t.retrying : t.retry)),
      cancel: FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.done)),
    );
  }

  String _outcomeMessage(Translations$offline$en t, SyncRetryOutcome outcome) => switch (outcome) {
    SyncRetryOutcome.reached => t.retryReached,
    SyncRetryOutcome.unreachable => t.retryUnreachable,
    SyncRetryOutcome.notAttempted => t.retryNotAttempted,
    SyncRetryOutcome.throttled => t.retryThrottled,
    SyncRetryOutcome.inFlight => t.retryInFlight,
    SyncRetryOutcome.disabled => t.retryDisabled,
  };

  Widget _services(BuildContext context, DateTime now) {
    final t = context.t.offline;
    final theme = Theme.of(context);
    final services = ConnectivityService.services;
    if (services.isEmpty) return Text(t.noServices, style: theme.textTheme.bodySmall);
    final nextAttempt = widget.nextAttemptAt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final service in services)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Emoji rather than an MDI glyph for the good case, and so
                // through [emojiStyle]: body text is Roboto, which resolves no
                // emoji at all under CanvasKit — the glyph would simply be
                // absent, with nothing in the log to say why.
                service.isFailing ? Icon(MdiIcons.alertCircleOutline, size: 16, color: theme.colorScheme.error) : Text('✅', style: emojiStyle(fontSize: 14)),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(service.label),
                      Text(
                        service.lastSuccessAt == null ? t.neverSucceeded : t.lastSuccess(when: _coarse(now.difference(service.lastSuccessAt!))),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (nextAttempt != null)
          Text(
            // Real clock: the schedule is a Timer's, which does not travel
            // (docs/design/time.md §1), so comparing it against the app clock
            // would print a wild number in a travelled session.
            nextAttempt.isAfter(realNowUtc()) ? t.nextAttempt(when: _coarse(nextAttempt.difference(realNowUtc()))) : t.nextAttemptNow,
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }
}

/// Coarse on purpose: this is read while deciding whether to walk uphill for
/// a bar of signal, not to time anything. Bare units so the sentence around
/// it stays translatable — the strings own "ago" and "in", this owns the
/// number.
String _coarse(Duration d) {
  final seconds = d.inSeconds < 0 ? 0 : d.inSeconds;
  if (seconds < 60) return '${seconds}s';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '${minutes}m';
  return '${minutes ~/ 60}h${minutes % 60}m';
}

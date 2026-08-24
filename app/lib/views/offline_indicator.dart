// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The status bar's offline icon and the detail behind it.
//
// This is the operator's answer to "why is nothing updating?", which is why
// it lives at the left of the status bar rather than in a notice: a notice is
// an event and gets dismissed, and being offline is a state that lasts as
// long as it lasts. Everything it reports is about the INTERNET — peer sync
// over LAN and BLE keeps working while this icon is up, and says so.

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../i18n/strings.g.dart';
import '../services/connectivity_service.dart';

/// The icon itself — absent entirely while online, so `StatusBarFooter`'s
/// `leading` is null and the bar goes back to collapsing on emptiness.
class OfflineIndicator extends StatelessWidget {
  /// Fires the sync probe immediately; the detail sheet's "retry now".
  final Future<SyncRetryOutcome> Function() onRetry;

  /// When the next scheduled probe is due, read at build time.
  final DateTime? Function() nextAttemptAt;

  /// The app's root navigator. Required, and not a convenience: the status
  /// footer is drawn ABOVE the Navigator (it owns the bottom of the window,
  /// outside every route), so this widget's own context has no Navigator
  /// ancestor and `showDialog` on it throws. Same reason main.dart's other
  /// chrome-level dialogs go through this key.
  final GlobalKey<NavigatorState> navigatorKey;

  final Color color;

  const OfflineIndicator({
    super.key,
    required this.onRetry,
    required this.nextAttemptAt,
    required this.navigatorKey,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.t.offline.iconLabel,
      child: InkResponse(
        onTap: () {
          final navigatorContext = navigatorKey.currentContext;
          if (navigatorContext == null) return;
          showHaloDialog<void>(
            context: navigatorContext,
            builder: (_) => _OfflineDetailDialog(onRetry: onRetry, nextAttemptAt: nextAttemptAt),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xs),
          child: Icon(MdiIcons.cloudOff, size: 16, color: color),
        ),
      ),
    );
  }
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
    final outcome = await widget.onRetry();
    if (!mounted) return;
    setState(() {
      _retrying = false;
      _outcome = outcome;
    });
    // A retry that worked has ended the thing this sheet is about, so there
    // is nothing left to read here.
    if (outcome == SyncRetryOutcome.reached) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.offline;
    final theme = Theme.of(context);
    return HaloDialog(
      title: Text(t.title),
      content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Which half we are in. The operator sees one offline state, but
            // the two have different things to try: no route at all is a
            // radio or a coverage problem, while a route that answers nothing
            // is usually a sign-in page waiting in a browser.
            Text(ConnectivityService.hasNoRoute ? t.noRoute : t.unreachable),
            const SizedBox(height: Space.md),
            Text(t.whatStops, style: theme.textTheme.bodySmall),
            const SizedBox(height: Space.lg),
            Text(t.servicesTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: Space.xs),
            OncePerSecond(builder: (_, now) => _services(context, now)),
            // The outcome sits in the content, not the footer: it is a report
            // on what just happened and has to stay readable while the footer
            // wraps on a narrow window.
            if (_outcome != null && !_retrying) ...[
              const SizedBox(height: Space.md),
              Text(_outcomeMessage(t, _outcome!), style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.done)),
      actions: [
        FilledButton(
          onPressed: _retrying ? null : _retry,
          child: Text(_retrying ? t.retrying : t.retry),
        ),
      ],
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
                Icon(
                  service.isFailing ? MdiIcons.alertCircleOutline : MdiIcons.checkCircleOutline,
                  size: 16,
                  color: service.isFailing ? theme.colorScheme.error : theme.colorScheme.primary,
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(service.label),
                      Text(
                        service.lastSuccessAt == null
                            ? t.neverSucceeded
                            : t.lastSuccess(when: _coarse(now.difference(service.lastSuccessAt!))),
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
            nextAttempt.isAfter(realNowUtc())
                ? t.nextAttempt(when: _coarse(nextAttempt.difference(realNowUtc())))
                : t.nextAttemptNow,
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

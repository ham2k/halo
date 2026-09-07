// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The nag tier of the staleness verdict (services/staleness.dart). One dialog
// for both nagging signals; only the title, body and action line differ.
//
// Always dismissible, on every platform. An expired build and a build below
// the code-push floor both keep working, and logging a contact always beats
// freshness — so there is no hard gate anywhere, only a nag that returns.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../services/link_opener.dart';
import '../services/restart_service.dart';
import '../services/staleness.dart';

/// Through the shared opener like every other link the app hands off, so the
/// download page lands in the operator's own browser rather than an in-app one.
void openStalenessUrl(String url) => openExternalUrl(url);

/// Shows the nag once the real app's Navigator exists — the boot-gate swap
/// lands a frame or two after services resolve.
///
/// [onClosed] fires when the dialog goes away, with true only when the user
/// chose to dismiss it — a programmatic pop (a deep link opening a pane over
/// it, a route reset) reports false, so the six-hour quiet period starts from
/// the operator's decision rather than from any route change that happened to
/// close a dialog they never read.
///
/// [onUnavailable] fires when no Navigator ever appeared, so the caller can
/// drop its "a nag is on screen" latch rather than wedging it forever.
void showStalenessNag({
  required GlobalKey<NavigatorState> navigatorKey,
  required StalenessSignal signal,
  required String body,
  required String? url,
  required void Function(bool dismissedByUser) onClosed,
  required VoidCallback onUnavailable,
  int attemptsLeft = 20,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      // Still fading out of the splash. Retry briefly, then give up quietly:
      // if the app never got a Navigator it is on the boot-error screen and
      // has bigger problems than staleness.
      if (attemptsLeft > 0) {
        Timer(
          const Duration(milliseconds: 250),
          () => showStalenessNag(
            navigatorKey: navigatorKey,
            signal: signal,
            body: body,
            url: url,
            onClosed: onClosed,
            onUnavailable: onUnavailable,
            attemptsLeft: attemptsLeft - 1,
          ),
        );
      } else {
        onUnavailable();
      }
      return;
    }
    // showHaloDialog, not showDialog: it applies haloDialogConstraints, the
    // size box every other modal in the app is held to.
    //
    // Guarded because a non-null context is not a usable Navigator: on a
    // defunct element this throws synchronously, inside a post-frame callback,
    // and `whenComplete` never attaches. The caller's "a nag is showing" latch
    // would then stay set for the process — and since one verdict is presented
    // per launch, that silences every staleness signal, permanently, quietly.
    try {
      unawaited(
        showHaloDialog<bool>(
          context: context,
          builder: (_) => StalenessNagDialog(signal: signal, body: body, url: url),
        ).then((dismissed) => onClosed(dismissed ?? false)),
      );
    } catch (e) {
      debugPrint('[staleness] could not present the nag: $e');
      onUnavailable();
    }
  });
}

class StalenessNagDialog extends StatelessWidget {
  const StalenessNagDialog({
    super.key,
    required this.signal,
    required this.body,
    this.url,
    this.restart = const RestartService(),
  });

  final StalenessSignal signal;
  final String body;

  /// Where to send the user for a new binary. Null for the code-push floor,
  /// whose remedy is a restart rather than a download.
  final String? url;

  final RestartService restart;

  bool get _isFloor => signal == StalenessSignal.codePushFloor;

  /// What the user has to do, in the words their platform allows.
  ///
  /// iOS deliberately gets a sentence rather than a button: it has no relaunch
  /// primitive, and quitting programmatically is both prohibited by the HIG and
  /// indistinguishable from a crash — so a button here would either lie or
  /// vanish the app mid-activation. Android's intent-based relaunch is fragile
  /// enough that it gets the same treatment.
  String get _floorAction {
    if (restart.isSupported) return t.staleness.restartToApply;
    if (!kIsWeb && Platform.isIOS) return t.staleness.quitAndReopen;
    return t.staleness.reopenToApply;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HaloDialog(
      title: Row(
        children: [
          Icon(MdiIcons.alertOutline, color: theme.colorScheme.error),
          const SizedBox(width: Space.md),
          Flexible(child: Text(_isFloor ? t.staleness.codePushFloorTitle : t.expiredBuild.title)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body),
          if (_isFloor) ...[
            const SizedBox(height: Space.md),
            Text(_floorAction, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ],
      ),
      // The way out sits in `cancel`, not in `actions`: only that slot gets
      // haloDialogCancelGap, and this is the button an operator reaches for at
      // speed. "Ignore for now" rather than Dismiss or Done — it names what is
      // actually happening, which is that the nag is coming back.
      cancel: TextButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: Text(t.staleness.ignoreForNow),
      ),
      actions: [
        if (_isFloor && restart.isSupported)
          FilledButton(
            onPressed: () {
              // Popped with false, not true: this is not "ignore", so a
              // relaunch that fails silently (RestartService swallows a failed
              // spawn) leaves the nag due again next launch rather than quiet
              // for six hours behind a button that did nothing.
              Navigator.of(context).pop(false);
              unawaited(restart.restart());
            },
            child: Text(t.updates.restartNow),
          )
        else if (!_isFloor && url != null)
          FilledButton(
            onPressed: () => openStalenessUrl(url!),
            child: Text(t.expiredBuild.visit),
          ),
      ],
    );
  }
}

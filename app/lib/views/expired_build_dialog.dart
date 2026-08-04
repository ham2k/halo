// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The expired-build nag: when this build's expiration date (written into
// version.dart by `halo-ops release` — see kBuildExpiration there) has
// passed, a dialog on EVERY launch asks the user to go get a newer build.
// Deliberately dismissible and deliberately not persisted: an expired build
// keeps working — logging a contact always beats freshness — but the nag
// returns next launch until the user updates.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/version.dart';
import '../i18n/strings.g.dart';

/// Shows [ExpiredBuildDialog] once this launch, if the build has expired.
/// Called from main() when services resolve; waits for the real app's
/// Navigator to exist (the boot-gate swap lands a frame or two later).
void maybeShowExpiredBuildDialog(GlobalKey<NavigatorState> navigatorKey, {int attemptsLeft = 20}) {
  if (!isBuildExpired()) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      // Navigator not mounted yet (still fading out of the splash). Retry
      // briefly; give up quietly if the app never got there (boot error
      // screen — it has bigger problems than staleness).
      if (attemptsLeft > 0) {
        Timer(const Duration(milliseconds: 250), () => maybeShowExpiredBuildDialog(navigatorKey, attemptsLeft: attemptsLeft - 1));
      }
      return;
    }
    unawaited(showDialog<void>(context: context, builder: (_) => const ExpiredBuildDialog()));
  });
}

class ExpiredBuildDialog extends StatelessWidget {
  const ExpiredBuildDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(MdiIcons.alertOutline, size: 48, color: Theme.of(context).colorScheme.error),
      title: Text(t.expiredBuild.title),
      content: Text(t.expiredBuild.body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.expiredBuild.dismiss),
        ),
        FilledButton(
          onPressed: () => unawaited(launchUrl(Uri.parse('https://ham2k.com'))),
          child: Text(t.expiredBuild.visit),
        ),
      ],
    );
  }
}

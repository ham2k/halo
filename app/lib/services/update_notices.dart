// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The "an update is ready" prompt for a downloaded Shorebird patch
// (docs/releases.md §4). main() calls [showPatchReadyNotice] when
// [UpdateService.checkAndApply] reports a freshly staged patch. A patch only
// loads at process start, so on desktop the notice offers a "Restart now" button
// (via [RestartService]); on mobile — where the app can't relaunch itself — it's
// informational and applies on the user's own next launch.
//
// The sibling "a newer *binary* is available" prompt lives in FlagsService (it's
// driven by the `latestRelease` feature flag, not the patch channel).

import 'dart:async';

import 'package:halo_i18n/halo_i18n.dart';
import 'restart_service.dart';
import 'status_bar_service.dart';

/// Stable key so a re-check within a session replaces rather than stacks; a
/// patch that's already been applied on restart won't re-report, so it doesn't
/// nag across launches.
const patchReadyNoticeKey = 'update:patch';

void showPatchReadyNotice(StatusBarService statusBar, RestartService restart) {
  statusBar.showNotice(
    key: patchReadyNoticeKey,
    icon: 'restart',
    title: t.updates.updateReady,
    text: restart.isSupported ? t.updates.restartToApply : t.updates.appliesNextLaunch,
    actions: [if (restart.isSupported) StatusBarAction(label: t.updates.restartNow, onTap: () => unawaited(restart.restart()))],
  );
}

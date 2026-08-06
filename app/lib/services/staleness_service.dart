// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Presents the one staleness verdict (services/staleness.dart ranks them) and
// owns when to say it again. It is the single launch path for all three
// signals: evaluated separately they would each present on their own schedule,
// stacking two dialogs and a notice on one launch.
//
// Everything here fails open. This is a field logging app: a failed flags
// fetch, an unreadable code-push number, a missing Navigator — each ends in
// silence, never in a blocked launch. There is no hard gate on any platform,
// and every presentation offers "Ignore for now".

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/version.dart';
import '../i18n/strings.g.dart';
import '../views/staleness_dialog.dart';
import 'staleness.dart';
import 'status_bar_service.dart';
import 'update_service.dart';

/// Status-bar key for the newer-release notice. Stable, NOT version-specific,
/// so a newer release replaces the notice rather than stacking a second one.
const stalenessNoticeKey = 'update:version';

/// prefs keys: the release currently being shown, and the newest one the user
/// has dismissed (the durable high-water mark).
const stalenessShownReleaseKey = 'update:shownVersion';
const _dismissedReleaseKey = 'update:dismissedVersion';

class StalenessService with WidgetsBindingObserver {
  StalenessService({
    required this.statusBar,
    this.navigatorKey,
    SharedPreferences? prefs,
    UpdateService? updates,
    bool isReleaseBuild = kReleaseMode,
    DateTime Function()? now,
    bool Function()? buildExpired,
    required void Function(String key, Map<String, dynamic> action)? onNoticeAction,
  })  : _prefs = prefs,
        _buildExpired = buildExpired ?? isBuildExpired,
        _updates = updates,
        _isReleaseBuild = isReleaseBuild,
        _now = now ?? DateTime.now,
        _onNoticeAction = onNoticeAction;

  final StatusBarService statusBar;
  /// Where the nag tier puts its dialog. Null where there is nowhere to put
  /// one — a test exercising only the notice tier, or any caller with no
  /// Navigator — and the nag then no-ops rather than inventing a surface.
  final GlobalKey<NavigatorState>? navigatorKey;
  final SharedPreferences? _prefs;
  final UpdateService? _updates;
  final bool _isReleaseBuild;
  final DateTime Function() _now;

  /// Injectable so a test can pin it. Left to the compiled-in expiration date,
  /// any test that reaches the ranking starts failing on the day this build's
  /// horizon passes — a wall-clock failure with no code change behind it.
  final bool Function() _buildExpired;

  /// The shared notice-action route (open a link, and track it). The notice
  /// tier goes through it rather than calling `launchUrl` directly, so a
  /// "Get it" tap is indistinguishable from any other notice action.
  ///
  /// REQUIRED though nullable, deliberately: it reaches the only button the
  /// notice has through exactly one assignment. Left to a default, omitting it
  /// makes "Get it" dismiss the notice and open nothing — and the dismissal
  /// then promotes into the durable high-water mark, so that release never
  /// announces itself again. Every call site states it, tests included.
  final void Function(String key, Map<String, dynamic> action)? _onNoticeAction;

  /// The flag values the last refresh carried. FlagsService owns fetching;
  /// this owns deciding, so the two are wired by a call rather than by this
  /// reaching into that.
  Map<String, dynamic> _flags = const {};

  /// When each signal was last dismissed, this process only. Deliberately not
  /// persisted: every signal returns on the next launch, and the quiet period
  /// exists for the session that never ends (a field laptop left running).
  /// The newer-release signal ALSO carries a durable mark in prefs — the two
  /// policies compose rather than replace each other.
  final Map<StalenessSignal, DateTime> _dismissedAt = {};

  /// True while a nag dialog is on screen, so a resume or a second flags
  /// refresh can't stack another behind it.
  bool _nagVisible = false;

  void start() => WidgetsBinding.instance.addObserver(this);

  void dispose() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-checked on resume rather than on a timer: the quiet period is
    // wall-clock, and no Timer survives a sleeping laptop or a backgrounded
    // phone accurately enough to be worth the wakeups.
    if (state == AppLifecycleState.resumed) evaluate();
  }

  /// Called by FlagsService after every refresh, and on resume. Idempotent:
  /// re-running with the same facts re-shows nothing that is already showing
  /// and re-nags nothing inside its quiet period.
  void evaluate({Map<String, dynamic>? flags}) {
    if (flags != null) _flags = flags;

    // BEFORE ranking, not after: ranking reads the durable mark this writes,
    // so promoting afterwards would let a release the user just dismissed
    // announce itself once more on the very next refresh. It also has to beat
    // the capped status-bar history, which is where the dismissal is read from.
    _promoteDismissedRelease();

    final floor = codePushFloorFor(_flags['minCodePush'], kBuildNumber);
    final signal = rankStaleness(
      belowCodePushFloor: isBelowCodePushFloor(
        updaterAvailable: _updates?.isAvailable ?? false,
        resolved: currentCodePushResolved,
        codePush: currentCodePush,
        floor: floor,
      ),
      buildExpired: _buildExpired(),
      releaseWorthAnnouncing: _isReleaseBuild &&
          isReleaseWorthAnnouncing(
            currentVersion: kPublicVersion,
            latest: _latestRelease,
            dismissed: _prefs?.getString(_dismissedReleaseKey),
          ),
    );
    // Logged every time, verdict or not: a mistyped build key in `minCodePush`
    // otherwise fails completely silently — no nag, no trace, and a server
    // that believes the floor is enforced on installs where it reaches nobody.
    debugPrint('[staleness] floor=$floor push=$currentCodePush resolved=$currentCodePushResolved '
        'expired=${_buildExpired()} latest=$_latestRelease → ${signal?.name ?? 'none'}');
    if (signal == null) return;

    if (!mayPresentAgain(dismissedAt: _dismissedAt[signal], now: _now())) return;

    switch (signal.tier) {
      case StalenessTier.notice:
        _presentNotice();
      case StalenessTier.nag:
        _presentNag(signal);
    }
  }

  String? get _latestRelease {
    final v = _flags['latestRelease'];
    return v is String && v.isNotEmpty ? v : null;
  }

  String get _releaseUrl {
    final u = _flags['latestReleaseUrl'];
    return u is String && u.isNotEmpty ? u : 'https://ham2k.com';
  }

  /// The server's explanation for the floor. A floor is only ever raised for
  /// something serious, so the dialog names it rather than showing a generic
  /// line — and falls back to one when the flag omits it.
  String get _floorMessage {
    final m = _flags['minCodePushMessage'];
    return m is String && m.isNotEmpty ? m : t.staleness.codePushFloorBody;
  }

  void _presentNotice() {
    final latest = _latestRelease;
    if (latest == null) return;
    // Already showing this exact release — don't reset it on every refresh.
    if (statusBar.activeNotices.any((n) => n.key == stalenessNoticeKey) &&
        _prefs?.getString(stalenessShownReleaseKey) == latest) {
      return;
    }
    _prefs?.setString(stalenessShownReleaseKey, latest);
    statusBar.showNotice(
      key: stalenessNoticeKey,
      icon: 'download',
      title: t.updates.updateAvailable,
      text: t.updates.newVersionAvailable(version: latest),
      actions: [
        StatusBarAction(
          label: t.updates.getIt,
          onTap: () {
            statusBar.dismissNotice(stalenessNoticeKey);
            _onNoticeAction?.call(stalenessNoticeKey, {
              'action': 'link',
              'args': {'url': _releaseUrl},
            });
          },
        ),
      ],
    );
  }

  void _presentNag(StalenessSignal signal) {
    final key = navigatorKey;
    if (key == null || _nagVisible) return;
    _nagVisible = true;
    showStalenessNag(
      navigatorKey: key,
      signal: signal,
      body: signal == StalenessSignal.codePushFloor ? _floorMessage : t.expiredBuild.body,
      url: signal == StalenessSignal.codePushFloor ? null : _releaseUrl,
      onClosed: (dismissedByUser) {
        _nagVisible = false;
        // Only the operator's own "Ignore for now" buys quiet. A dialog closed
        // by a route change was never read, and starting the period from it
        // would hide the nag for six hours on the strength of a deep link.
        if (dismissedByUser) _dismissedAt[signal] = _now();
      },
      onUnavailable: () => _nagVisible = false,
    );
  }

  /// Moves the release the user just dismissed in the status bar into the
  /// durable high-water mark, so only a release NEWER than it ever notifies
  /// again — a mute would hide every future release behind one impatient tap.
  void _promoteDismissedRelease() {
    final shown = _prefs?.getString(stalenessShownReleaseKey);
    if (shown == null) return;
    final dismissedInBar =
        statusBar.history.any((n) => n.key == stalenessNoticeKey && n.dismissedAt != null);
    if (!dismissedInBar) return;
    final mark = _prefs?.getString(_dismissedReleaseKey);
    if (mark == null || isReleaseWorthAnnouncing(currentVersion: mark, latest: shown, dismissed: null)) {
      _prefs?.setString(_dismissedReleaseKey, shown);
    }
    _prefs?.remove(stalenessShownReleaseKey);
  }
}

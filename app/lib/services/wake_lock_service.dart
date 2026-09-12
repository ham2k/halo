// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Holds the device awake while something is worth staying awake for, and
// only for as long as the operator has said it may.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:halo_core/halo_core.dart' show SyncProgress;
import 'package:wakelock_plus/wakelock_plus.dart';

import 'error_reporting_service.dart';
import 'settings_service.dart';

/// What a hold is for — diagnostics only; every hold is its own instance
/// (see [WakeLockService.hold]).
enum WakeReason {
  /// A logging view is open and the operator has touched it recently.
  logging,

  /// Account history is still downloading (`SyncProgress.backfilling`).
  syncBackfill,

  /// A push backlog is draining in back-to-back rounds.
  syncPush,
}

/// One claim on the device staying awake, owned by whoever took it. Each
/// hold has its own idle clock: [touch] restarts it, [release] ends it.
/// Two logging views stacked on each other take two holds, so the top one
/// closing does not drop the one the view beneath still relies on.
class WakeHold {
  final WakeReason reason;
  final WakeLockService _service;
  Timer? _timer;

  WakeHold._(this._service, this.reason);

  /// Whether this hold is inside its idle window.
  bool get active => _timer != null;

  /// Activity now; the idle window starts over.
  void touch() {
    _timer?.cancel();
    _timer = Timer(WakeLockService.idleTimeout, () {
      _timer = null;
      _service._holds.remove(this);
      _service._reconcile();
    });
    _service._holds.add(this);
    _service._reconcile();
  }

  /// Over — the view closed, the sync finished. The hold can be touched
  /// again later.
  void release() {
    _timer?.cancel();
    _timer = null;
    _service._holds.remove(this);
    _service._reconcile();
  }
}

/// The device stays awake while [SettingsService.keepDeviceAwake] is on AND
/// at least one [WakeHold] has been touched within [idleTimeout].
///
/// The hold is a plain OS wakelock (`wakelock_plus`) — the setting decides
/// whether it may be taken, the holds decide when. Turning the setting off
/// releases an active lock on the spot; the holds keep ticking so turning
/// it back on resumes without waiting for the next touch.
///
/// Idle expiry is a [Timer] and reads no clock, so developer time travel
/// cannot expire or extend it (docs/design/time.md).
///
/// A browser drops the lock when the tab is hidden and does not give it
/// back, so a held lock is re-taken on every resume — natively a repeat of
/// an enable is a no-op, so the same path serves every platform.
class WakeLockService with WidgetsBindingObserver {
  /// How long a hold stays active after its last touch. Fifteen minutes is
  /// long enough that a slow contest hour never lets the screen go, and short
  /// enough that a laptop left open at the end of the day still sleeps.
  static const idleTimeout = Duration(minutes: 15);

  final SettingsService settings;
  final Future<void> Function(bool enable) _apply;
  final Set<WakeHold> _holds = {};
  bool _held = false;
  bool _observing = false;

  /// [apply] is the platform call, injectable so a test can observe the hold
  /// without a plugin; the default is the real wakelock.
  WakeLockService(this.settings, {Future<void> Function(bool enable)? apply}) : _apply = apply ?? _applyWakelock {
    settings.addListener(_reconcile);
  }

  /// Whether the OS wakelock is currently taken.
  bool get held => _held;

  /// The reasons of the holds inside their idle window right now.
  Iterable<WakeReason> get activeReasons => _holds.map((hold) => hold.reason);

  /// A new, inactive hold for [reason]; touch it to take it.
  WakeHold hold(WakeReason reason) => WakeHold._(this, reason);

  late final WakeHold _backfill = hold(WakeReason.syncBackfill);
  late final WakeHold _push = hold(WakeReason.syncPush);

  /// The counts the last backfill report carried, so the next one can tell
  /// progress from repetition.
  (int?, int?)? _lastBackfillLeft;

  /// `SyncEngine.onProgress`, as far as the hold is concerned: backfill keeps
  /// the device awake while it MOVES. A report is progress only when its
  /// remaining counts differ from the last one's — a cursor the server keeps
  /// re-serving reports the same counts every loop delay, and a hold
  /// refreshed by those would never let the device sleep.
  void onBackfillProgress(SyncProgress progress) {
    if (!progress.backfilling) {
      _lastBackfillLeft = null;
      _backfill.release();
      return;
    }
    final left = (progress.qsosLeft, progress.operationsLeft);
    if (left == _lastBackfillLeft) return;
    _lastBackfillLeft = left;
    _backfill.touch();
  }

  /// `SyncEngine.onPushBacklog`: a backlog still draining is activity, and
  /// a round that caught up (or stalled) ends the hold.
  void onPushBacklog(bool draining) {
    if (draining) {
      _push.touch();
    } else {
      _push.release();
    }
  }

  void _reconcile() {
    final wanted = settings.keepDeviceAwake && _holds.isNotEmpty;
    if (wanted == _held) return;
    _held = wanted;
    // Registered on the first take rather than at construction: the service
    // is built with the service graph, which a headless test does without a
    // widgets binding to observe.
    if (wanted && !_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
    }
    unawaited(_apply(wanted));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _held) unawaited(_apply(true));
  }

  void dispose() {
    settings.removeListener(_reconcile);
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    for (final hold in _holds.toList()) {
      hold.release();
    }
  }

  /// Reported once per session: a platform that cannot hold the lock fails
  /// the same way on every transition, and one machine must not flood the
  /// backend with the same report per view opened.
  static bool _reportedFailure = false;

  static Future<void> _applyWakelock(bool enable) async {
    try {
      await WakelockPlus.toggle(enable: enable);
    } catch (e, st) {
      // A platform that cannot hold the lock (a Linux desktop without the
      // screensaver D-Bus service) has nothing the operator can do about
      // it; the device just sleeps as it always did. Uploaded so the rate
      // says which platforms those are.
      debugPrint('[wakelock] could not ${enable ? 'take' : 'release'} the wakelock: $e');
      // A browser refusing the lock is expected behaviour, not a platform
      // gap: it refuses whenever the tab is hidden, and the resume above
      // asks again. Nothing to learn from the rate.
      if (kIsWeb || _reportedFailure) return;
      _reportedFailure = true;
      ErrorReportingService.report(e, st, context: 'wakelock:${enable ? 'enable' : 'disable'}');
    }
  }
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// DEVTT, the developer's time travel (docs/design/time.md): moving the app
// clock, the status item that says it has moved, and the way back — on
// request, or when developer mode goes off.

part of 'halo_services.dart';

mixin _TimeTravel {
  SettingsService get settings;
  StatusBarService get statusBar;
  SyncEngine get syncEngine;
  void watchReceivedTestOperationPurges();

  void _enforceTimeTravelGate() {
    if (!AppClock.instance.isTravelling || settings.developerMode) return;
    // Said out loud: every clock, QSO default and spot age in the app jumps, and
    // the only visible cause is a developer-mode toggle several screens away.
    final was = AppClock.instance.travelLabel;
    statusBar.showNotice(
      key: 'clock:timeTravelEnded',
      icon: 'clock-check',
      title: 'Back to real time',
      text: 'Leaving developer mode ended time travel${was == null ? '' : ' ($was)'}.',
      persist: false,
    );
    // Guarded, not bare `unawaited`: the clock is reset FIRST inside, so a throw
    // later in the sequence (the status item, the heartbeat, restarting sync)
    // would otherwise surface only as an unhandled async error and leave the
    // chip on screen over a clock that is no longer travelling.
    unawaited(
      _endTimeTravel().catchError((Object e, StackTrace stack) {
        ErrorReportingService.report(e, stack, context: 'clock:end-time-travel');
      }),
    );
  }

  /// DEVTT: moves the app clock (docs/design/time.md).
  ///
  /// Both gates live here rather than in the command hook, because neither the
  /// sync account nor developer mode is visible from inside the extension
  /// sandbox — and because the sync account gate is the one thing in this
  /// feature that protects real user data, so it belongs where it cannot be
  /// bypassed by a different caller of the action.
  Future<CommandActionOutcome?> _travelTime(Map<String, dynamic>? params) async {
    if (params?['reset'] == true) {
      if (!AppClock.instance.isTravelling) return (text: 'The clock is already on real time', failed: false);
      await _endTimeTravel();
      return (text: 'Back to real time', failed: false);
    }

    if (!settings.developerMode) {
      return (text: 'Time travel needs developer mode', failed: true);
    }

    // Deliberately no sync-account gate: what the account is called says
    // nothing about what this session can damage, because `WritePolicy` admits
    // only test data while the clock is travelled. Keying on the account would
    // also mean reading `syncState['accountData']`, a cache refreshed only when
    // the operator opens Settings › Sync — a check that fails closed on absence
    // but open on staleness, which is the wrong way round for anything standing
    // between a dev tool and somebody's real log.

    // Applied BEFORE anything is changed on its behalf: `travel` refuses an
    // out-of-range offset or speed, and a refusal that had already switched
    // something off would leave that thing off with no travel to undo.
    final deltaMillis = (params?['deltaMillis'] as num?)?.toInt() ?? 0;
    final speed = (params?['speed'] as num?)?.toDouble();
    ClockListenerException? notFollowed;
    try {
      AppClock.instance.travel(
        delta: Duration(milliseconds: deltaMillis),
        speed: speed,
      );
    } on ArgumentError catch (e) {
      // Validation, which runs before any mutation: nothing moved.
      return (text: 'Time travel refused: ${e.message}', failed: true);
    } on ClockListenerException catch (e, stack) {
      // A listener threw (the sandbox push, the UI heartbeat). The clock HAS
      // moved — so everything below still has to happen, most of all the status
      // indicator: a travelled clock nobody can see is the one failure
      // docs/design/time.md §4 says must not be possible. Only the report at the
      // end differs.
      ErrorReportingService.report(e.cause, stack, context: 'clock:travel-listener');
      notFollowed = e;
    }

    // Nothing to switch off: SyncEngine's own `_mayRun` check now refuses every
    // path while the clock is travelled, including a round already on a timer.

    // Subscribing here rather than at construction: WallClock arms no timer
    // until something listens, so an app that never travels pays nothing.
    if (!_travelStatusTicking) {
      _travelStatusTicking = true;
      WallClock.seconds.addListener(_refreshTimeTravelStatus);
    }
    _refreshTimeTravelStatus();
    final now = 'Clock now ${_utcStamp(nowUtc())}${_travelSuffix()}';
    if (notFollowed != null) {
      return (text: '$now — but ${notFollowed.cause}', failed: true);
    }
    return (text: now, failed: false);
  }

  bool _travelStatusTicking = false;

  /// What the status item last said, so an unchanged label costs nothing.
  String? _travelStatusText;

  /// Keeps the status-bar item showing how far the clock is from real time and
  /// how fast it is running.
  ///
  /// Re-read once per second rather than posted once, because the offset GROWS:
  /// `DEVTT 100x` sets no offset at all, and a snapshot would sit at "at 100x"
  /// for the whole session while the clock ran days ahead. Posting only on a
  /// CHANGE is what keeps that affordable — every post notifies the whole
  /// status bar, and at 1x with a fixed offset the label never changes, so an
  /// ordinary travelled session is silent after the first one.
  void _refreshTimeTravelStatus() {
    final label = AppClock.instance.liveTravelLabel;
    if (label == _travelStatusText) return;
    _travelStatusText = label;
    if (label == null) {
      statusBar.clear(HaLoServices.timeTravelStatusKey);
      return;
    }
    statusBar.setMessage(
      key: HaLoServices.timeTravelStatusKey,
      icon: 'clock-fast',
      // Everything in the TITLE, with no separate `text`. The collapsed footer
      // — the always-visible one — renders `title ?? text`, so a title of
      // "Time travel" with the offset in `text` reads as a bare "Time travel"
      // until someone expands the bar, which is the one place this item must not
      // need. Phrased to read as one line: "Time travel +5m at 100x",
      // "Time travel at 100x", "Time travel +2h".
      title: 'Time travel $label',
    );
  }

  /// Returns to real time and undoes everything travel imposed.
  Future<void> _endTimeTravel() async {
    try {
      AppClock.instance.reset();
    } on ClockListenerException catch (e, stack) {
      // The clock IS back on real time — reset mutates before notifying — so
      // everything below still has to run, exactly as on the travel path. Left
      // to propagate, it would strand the status item on screen over an
      // untravelled clock and never restart sync.
      ErrorReportingService.report(e.cause, stack, context: 'clock:end-travel-listener');
    }
    if (_travelStatusTicking) {
      _travelStatusTicking = false;
      WallClock.seconds.removeListener(_refreshTimeTravelStatus);
    }
    _travelStatusText = null;
    statusBar.clear(HaLoServices.timeTravelStatusKey);
    // The engine stopped rescheduling itself while travelling, so nothing would
    // pick it up again on its own.
    syncEngine.start();
    watchReceivedTestOperationPurges();
  }

  String _travelSuffix() {
    final label = AppClock.instance.travelLabel;
    return label == null ? '' : ' ($label)';
  }

  /// `2026-08-11 14:03z` — a UTC stamp to the minute, which is the precision a
  /// logger's operator thinks in.
  static String _utcStamp(DateTime utc) => '${utc.toIso8601String().substring(0, 16).replaceFirst('T', ' ')}z';
}

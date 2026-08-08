// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A shared heartbeat for UI that displays live wall-clock time (the Time
// chip's HH:MM:SSz, relative "Ns ago" labels, etc.). Widgets that tick on
// their own timer each rebuild whatever State owns the timer — a per-State
// ticker can rebuild a whole panel once per second — and several independent
// timers tick out of phase, costing one frame each. One shared notifier
// fixes both: subscribers
// rebuild only their own leaf subtree, and every tick lands on a wall-clock
// second boundary so all of them coalesce into the same frame (and the
// displayed time never lags the real clock by a stray fraction).

import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/widgets.dart';
import 'package:halo_core/halo_core.dart';

/// An app-wide once-per-[period] heartbeat, aligned to wall-clock boundaries.
///
/// The timer is armed only while something listens, so an idle app (or a
/// disposed subtree) holds no timer at all. In widget tests it behaves like
/// any plain [Timer]: advance fake time with `tester.pump(duration)` to see
/// a tick.
class WallClock extends ChangeNotifier {
  WallClock._(this.period);

  /// The shared once-per-second clock. Prefer [OncePerSecond] over listening
  /// directly — it scopes the rebuild for you.
  static final WallClock seconds = WallClock._(const Duration(seconds: 1));

  final Duration period;
  Timer? _timer;

  @override
  void addListener(VoidCallback listener) {
    final wasIdle = !hasListeners;
    super.addListener(listener);
    if (wasIdle) AppClock.instance.addListener(_onClockTravel);
    _arm();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      AppClock.instance.removeListener(_onClockTravel);
      _timer?.cancel();
      _timer = null;
    }
  }

  /// The shortest real interval this heartbeat will ever run at, however fast
  /// the clock is set.
  ///
  /// [AppClock.maxSpeed] already bounds the factor; this is the second bound,
  /// on the thing that would actually break. Every subscriber rebuilds on each
  /// notification, so a heartbeat driven straight off the factor turns into a
  /// frame-rate-exceeding rebuild storm — and the only way back is typing DEVTT
  /// into a UI that has stopped answering. 100ms is faster than anyone can read
  /// a changing clock and slow enough to stay a rounding error in a frame
  /// budget; past it the displayed seconds simply skip, which is honest at
  /// speed.
  static const _minRealInterval = 100;

  /// The real milliseconds to wait for the next boundary of a [periodMs] clock
  /// currently reading [nowMillis], running at [speed].
  ///
  /// The boundaries are boundaries of the APP clock, but the wait to reach one is
  /// real time — a Timer knows nothing about time travel — so the remaining
  /// virtual milliseconds are divided by the speed. At 2x a displayed second
  /// lasts half a real second, which is the point of the factor.
  ///
  /// Pulled out as a pure function because the behaviour cannot be observed
  /// reliably through a widget test: the boundary comes from the REAL clock while
  /// the timer runs on the test's FAKE one, so how many ticks a pumped second
  /// produces depends on where the real clock happened to sit when the test ran.
  /// A test that counts ticks is therefore both flaky and able to pass for the
  /// wrong reason; one that checks this arithmetic is neither.
  @visibleForTesting
  static int delayToBoundary({required int periodMs, required int nowMillis, required double speed}) {
    final untilBoundaryMs = periodMs - nowMillis % periodMs;
    final scaled = (untilBoundaryMs / speed).ceil();
    return scaled < _minRealInterval ? _minRealInterval : scaled;
  }

  // A chain of one-shot timers re-aimed at the next boundary each time, rather
  // than a single Timer.periodic: a periodic timer only preserves its own
  // cadence, drifting off the wall-clock boundary it was aimed at.
  void _arm() {
    if (_timer != null) return;
    final delayMs = delayToBoundary(
      periodMs: period.inMilliseconds,
      nowMillis: nowMillis(),
      speed: AppClock.instance.speed,
    );
    _timer = Timer(Duration(milliseconds: delayMs), () {
      _timer = null;
      if (hasListeners) {
        notifyListeners();
        _arm();
      }
    });
  }

  // Time travel moves the displayed time NOW, and changes how long the wait to
  // the next boundary should be. Repaint immediately and re-aim, rather than
  // leaving every subscriber showing the old time until a stale timer fires.
  void _onClockTravel() {
    _timer?.cancel();
    _timer = null;
    notifyListeners();
    if (hasListeners) _arm();
  }
}

/// A [Listenable] view of whether — and how — the app clock is time-travelled,
/// for UI that renders that STATE rather than the time itself (the Sync
/// settings row's explanation of why sync is unavailable).
///
/// Such UI reads `AppClock.instance.travelLabel` at build time, and its own
/// rebuild triggers have nothing to do with the clock: ending travel writes no
/// setting, so a row listening only to settings keeps rendering
/// "unavailable while time travelling" over a control that works again.
///
/// Process-lifetime, like [WallClock.seconds], and cheap for the same reason:
/// [AppClock] notifies only when travel is configured or cleared, so this is
/// idle in every ordinary session.
class ClockTravel extends ChangeNotifier {
  ClockTravel._() {
    AppClock.instance.addListener(notifyListeners);
  }

  static final ClockTravel instance = ClockTravel._();

  /// Announces that something was REFUSED because of the clock, without the
  /// clock itself having changed.
  ///
  /// The declarative settings form holds an optimistic value for a field until
  /// something its group listens to fires, so a sync toggle whose commit was
  /// refused would otherwise keep rendering ON over a sync that is off. Nothing
  /// about the clock moved, so [AppClock] has nothing to report — this is the
  /// same audience being told the answer was no.
  void notifyRefused() => notifyListeners();
}

/// Rebuilds [builder] once per second, in the same frame as every other
/// [OncePerSecond] in the app. Wrap the smallest widget that actually shows
/// the time — the point is that the per-second rebuild stops at this leaf
/// instead of whatever State would otherwise own a timer.
class OncePerSecond extends StatelessWidget {
  const OncePerSecond({super.key, required this.builder});

  /// [nowUtc] is the current time at this tick, for convenience — most
  /// callers format some flavor of "now" or "since then".
  final Widget Function(BuildContext context, DateTime nowUtc) builder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: WallClock.seconds,
        builder: (context, _) => builder(context, nowUtc()),
      );
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A shared heartbeat for UI that displays live wall-clock time (the Time
// chip's HH:MM:SSz, relative "Ns ago" labels, etc.). Widgets that tick on
// their own timer each rebuild whatever State owns the timer — historically
// the Time chip's timer lived on _LoggingControlsState and rebuilt the whole
// logging panel once per second — and several independent timers tick out of
// phase, costing one frame each. One shared notifier fixes both: subscribers
// rebuild only their own leaf subtree, and every tick lands on a wall-clock
// second boundary so all of them coalesce into the same frame (and the
// displayed time never lags the real clock by a stray fraction).

import 'dart:async';

import 'package:flutter/widgets.dart';

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
    super.addListener(listener);
    _arm();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _timer?.cancel();
      _timer = null;
    }
  }

  // A chain of one-shot timers re-aimed at the next boundary each time,
  // rather than a single Timer.periodic: a periodic timer only preserves its
  // own cadence, drifting off the wall-clock boundary it was aimed at.
  void _arm() {
    if (_timer != null) return;
    final periodMs = period.inMilliseconds;
    final delayMs = periodMs - DateTime.now().millisecondsSinceEpoch % periodMs;
    _timer = Timer(Duration(milliseconds: delayMs), () {
      _timer = null;
      if (hasListeners) {
        notifyListeners();
        _arm();
      }
    });
  }
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
        builder: (context, _) => builder(context, DateTime.now().toUtc()),
      );
}

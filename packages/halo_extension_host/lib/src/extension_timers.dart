// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Extension timers, host side. The kernel keeps every extension's timers
// (extensions/sdk/src/timerQueue.ts) and asks for one wake at its earliest
// deadline, whoever owns it; this is the one Dart timer that answers, held by
// the host core beside the engine as the sockets are.

import 'dart:async';

/// Which extension had its timers suspended, and why: `budget`, `failures`
/// or `interrupted` (extensions/sdk/src/timerQueue.ts).
typedef TimerSuspension = ({String extensionKey, String reason});

class ExtensionTimerWake {
  /// Evaluates `__polo.runTimers()`, throwing when the engine could not finish.
  final void Function() runTimers;
  final void Function(String message) log;

  Timer? _timer;
  bool _failedLast = false;

  /// Set while a retry after a failed run is armed. The kernel's own wake
  /// requests are ignored meanwhile: one arriving first — a hook setting a
  /// timer a minute out — would otherwise put off the run that notices the
  /// interrupted callback by that minute, and the run re-arms anyway.
  bool _retrying = false;

  ExtensionTimerWake({required this.runTimers, required this.log});

  /// The kernel's `timerWake`. Replaces whatever was armed: the kernel sends
  /// its earliest deadline afresh whenever it changes, and null once nothing
  /// is pending.
  void arm(int? delayMillis) {
    if (!_retrying) _schedule(delayMillis);
  }

  void _schedule(int? delayMillis) {
    _timer?.cancel();
    _timer = delayMillis == null ? null : Timer(Duration(milliseconds: delayMillis), _fire);
  }

  /// A run that fails is the engine interrupting a callback that ran too long
  /// — and an interrupt unwinds past the kernel's own bookkeeping, so it never
  /// asked for its next wake. Running again is what lets it notice, suspend
  /// the extension that overran, and re-arm for everyone else; without it
  /// every extension's timers stop for good.
  ///
  /// At once the first time. After that, a second apart for as long as runs
  /// keep failing: a second stuck callback in the same run fails the retry
  /// too, and needs another; a failure that is not an interrupt at all would
  /// otherwise be retried at zero delay forever, spinning a core.
  void _fire() {
    _timer = null;
    _retrying = false;
    try {
      runTimers();
      _failedLast = false;
    } catch (e) {
      log('ERROR running timers: $e');
      _schedule(_failedLast ? 1000 : 0);
      _retrying = true;
      _failedLast = true;
    }
  }

  void dispose() => _timer?.cancel();
}

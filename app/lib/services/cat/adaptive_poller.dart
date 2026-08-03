// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Polls fast while the radio is moving, slowly while it isn't, and not at
// all while the radio is telling us things on its own.
//
// The measurements this is built on, from a live FT-891 at 4800 baud (see
// docs/design/cat.md):
//   - a poll cycle (`FA;` `MD0;` and the answers) is 24 bytes = 50 ms of
//     wire, so 200 ms polling is a 25% duty cycle;
//   - one Auto-Information `IF` frame is 28 bytes = 58 ms, MORE than a whole
//     poll cycle, and the radio emits one per dial step;
//   - CPU scales with BYTES, not elapsed time — the serial reader isolate
//     wakes once per byte received.
//
// So the expensive case is precisely the case where polling is redundant: a
// dial being spun with transceive on already saturates the link with pushed
// frames, and polling on top of that only queues behind them, delaying our
// own tune commands.

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Fast enough that a spun dial looks live.
const kPollFast = Duration(milliseconds: 200);

/// Slow enough to be free, often enough that a missed update is corrected
/// long before it could reach a logged QSO.
const kPollSlow = Duration(seconds: 3);

/// However much the radio chatters, ask it directly at least this often.
/// [noteData] defers the next poll, and it must not be able to defer it
/// forever: the poll is the backstop for transceive being off or wrong, and
/// a radio repeating one frame, or line noise decoding to a steady drip of
/// replacement characters, would otherwise starve it for the life of the
/// connection. Three slow intervals — rare enough to cost nothing, often
/// enough that a stale frequency cannot reach a logged QSO.
const _maxStalenessFactor = 3;

/// How many polls in a row must find nothing new before backing off a step.
/// One is too twitchy — a dial pauses mid-turn — and the ramp is geometric,
/// so the cost of being slightly slow to settle is small.
const _quietPollsBeforeBackoff = 2;

/// A self-rescheduling poll whose interval follows what the radio is doing.
///
/// Three inputs, and the interesting behaviour is in how they combine:
///
///  * [noteData] — anything at all arrived. The radio has just told us
///    something, so a poll right now would ask a question we already have
///    the answer to: the timer restarts. With transceive on, a spun dial
///    keeps resetting it and we poll *zero* times through the whole turn.
///  * [noteChange] — what arrived was different. The radio is moving, so
///    drop to [fast] in case the pushes stop mid-turn (transceive is a
///    radio-side setting, and nothing in CAT lets us read back whether it
///    is on).
///  * silence — nothing arrives, so the timer fires and we ask.
class AdaptivePoller {
  final Duration fast;
  final Duration slow;
  final void Function() onPoll;

  Timer? _timer;

  /// Never reset by [noteData] — see [_maxStalenessFactor].
  Timer? _ceiling;

  Duration _interval;
  int _quietPolls = 0;
  bool _sawChangeSinceLastPoll = false;

  AdaptivePoller({
    required this.onPoll,
    this.fast = kPollFast,
    this.slow = kPollSlow,
  }) : _interval = slow;

  /// The interval currently in use — for tests and diagnostics.
  Duration get interval => _interval;

  bool get isRunning => _timer != null;

  void start() {
    // Reset BEFORE the already-running guard: a second start (a resync, a
    // session reused across a reconnect) must not inherit whatever fast
    // interval the last dial turn left behind and poll a stationary radio
    // at 200ms forever.
    _interval = slow;
    _quietPolls = 0;
    _sawChangeSinceLastPoll = false;
    if (_timer != null) {
      _schedule();
      return;
    }
    _schedule();
    _ceiling = Timer.periodic(slow * _maxStalenessFactor, (_) => _fire());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _ceiling?.cancel();
    _ceiling = null;
  }

  /// Something arrived from the radio — defer the next poll.
  void noteData() {
    if (_timer == null) return;
    _schedule();
  }

  /// What arrived was a real change: the radio is moving.
  void noteChange() {
    _sawChangeSinceLastPoll = true;
    _quietPolls = 0;
    _interval = fast;
    if (_timer != null) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(_interval, _fire);
  }

  void _fire() {
    // Nothing new since the last time we asked — ease off, geometrically,
    // so a radio left alone costs nothing without a long ramp of near-fast
    // polls on the way there.
    if (!_sawChangeSinceLastPoll) {
      _quietPolls += 1;
      if (_quietPolls >= _quietPollsBeforeBackoff) {
        _quietPolls = 0;
        final doubled = _interval * 2;
        _interval = doubled >= slow ? slow : doubled;
      }
    }
    _sawChangeSinceLastPoll = false;

    try {
      onPoll();
    } catch (e) {
      // Caught, not just guarded against: a driver throwing here must not
      // end polling for the life of the connection, and it must not escape
      // into the zone either, which is how CatService already treats every
      // other call into a driver.
      debugPrint('[cat] poll failed, continuing: $e');
    }
    // After the callback, so a poll that provokes an immediate answer
    // (calling noteData) wins over this.
    if (_timer != null) _schedule();
  }
}

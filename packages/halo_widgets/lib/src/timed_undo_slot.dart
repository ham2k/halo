// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

/// A single-slot, timed undo stash: holds one value for [duration], then
/// forgets it — restarted on every [set]. For "press again to undo"
/// gestures (Escape-wipe, Escape-deselect) that only need to remember the
/// most recently discarded thing, not a history of them.
class TimedUndoSlot<T> {
  TimedUndoSlot({this.duration = const Duration(seconds: 5)});

  final Duration duration;
  T? _value;
  Timer? _timer;

  T? get value => _value;

  /// Stashes [value], (re)starting the expiry timer. [onExpire] fires when
  /// the window closes without the value having been taken or cleared.
  void set(T value, {required void Function() onExpire}) {
    _timer?.cancel();
    _value = value;
    _timer = Timer(duration, () {
      _value = null;
      onExpire();
    });
  }

  /// Clears the slot and cancels any pending expiry, without notifying.
  void clear() {
    _timer?.cancel();
    _timer = null;
    _value = null;
  }

  /// Takes and clears the stashed value, or null if empty/expired.
  T? take() {
    final v = _value;
    clear();
    return v;
  }

  void dispose() => _timer?.cancel();
}

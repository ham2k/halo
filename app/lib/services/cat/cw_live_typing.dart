// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Keying CW as it is typed: the keyer area's keyboard mode. What the
// operator types is held here and handed to the key in use in pieces —
// everything typed so far, each time the key falls idle — so a character
// stays editable until the piece holding it is handed over. Handed over is
// "sent": no keyer here can take back what it was given (a CAT buffer is
// write-only), so the line Backspace stops at is the one this class draws,
// and it is the same for every keyer, a peer's radio included, because all
// it ever calls is `sendCw`.
//
// A piece goes when the key is idle and there is something ready: every
// word finished with a space, at once, and the rest once the operator has
// paused for [cwLiveTypingDebounce]. Words are the natural piece — the
// queue ends every piece with a word gap, so a piece cut mid-word keys a
// gap inside the word — and the pause is what lets a half-typed word be
// fixed before it goes. Whatever is typed while a piece keys waits for the
// queue to report it drained, then goes by the same rule.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'drivers/cw_send_queue.dart';

/// How long keyboard mode waits for the next keystroke before ending as
/// Enter would.
const cwLiveTypingIdle = Duration(seconds: 5);

/// How long the operator must stop typing before a word they have not
/// finished with a space is handed over.
const cwLiveTypingDebounce = Duration(milliseconds: 500);

class CwLiveTyping extends ChangeNotifier {
  /// Hands a piece to the key in use.
  final void Function(String text) send;

  /// Stops everything the key in use still has to send.
  final void Function() stop;

  /// Whether the key in use is still keying — the next piece waits for it.
  final bool Function() busy;

  /// Reports the key in use going quiet (null) — when the next piece goes.
  final ValueListenable<CwSendProgress?> progress;

  /// Fires on every stop of the key, ahead of the quiet it causes. What is
  /// typed is dropped there, since the operator asked for silence, and a
  /// stop's quiet taken as "free" would key what is held right after it.
  final Listenable stops;

  /// Called once, when keyboard mode ends by any path.
  final VoidCallback? onDone;

  CwLiveTyping({required this.send, required this.stop, required this.busy, required this.progress, required this.stops, this.onDone}) {
    progress.addListener(_onProgress);
    stops.addListener(_onStopped);
    _restartIdle();
  }

  String _text = '';
  int _handedOff = 0;
  bool _done = false;
  Timer? _idle;

  /// Whether [cwLiveTypingDebounce] has passed since the last keystroke —
  /// what makes an unfinished word ready.
  bool _paused = false;
  Timer? _debounce;

  /// Everything typed since keyboard mode started.
  String get text => _text;

  /// How much of [text], from the start, the key in use already has — what
  /// no edit may change.
  int get handedOff => _handedOff;

  bool get done => _done;

  /// Whether [char] can be typed: the characters the keyers send, and the
  /// space between words.
  static bool accepts(String char) => char == ' ' || morseElements.containsKey(char);

  /// Takes the field's new text, uppercased and filtered to what [accepts].
  /// Returns false, changing nothing, when the edit would touch what was
  /// already handed over.
  bool update(String next) {
    if (_done) return false;
    // Any keystroke is the operator still here, a refused one included.
    _restartIdle();
    final filtered = next.toUpperCase().split('').where(accepts).join();
    if (!filtered.startsWith(_text.substring(0, _handedOff))) return false;
    if (filtered == _text) return true;
    _text = filtered;
    _paused = false;
    _debounce?.cancel();
    _debounce = Timer(cwLiveTypingDebounce, () {
      _paused = true;
      _feed();
    });
    _feed();
    notifyListeners();
    return true;
  }

  /// Enter: keyboard mode ends, and what is still held goes behind what is
  /// keying, all of it.
  void finish() {
    if (_done) return;
    _handOff();
    _end();
  }

  /// Escape: nothing more goes out, and what is keying stops.
  void cancel() {
    if (_done) return;
    // Ended BEFORE the stop: a stop drains the queue, and a drain heard
    // while still open would hand the held text straight back to the key.
    final keyed = _handedOff > 0;
    _end();
    if (keyed) stop();
  }

  /// How many times a stop has emptied [text] — what tells a field showing
  /// it that its text was taken away, rather than typed.
  int get clears => _clears;
  int _clears = 0;

  /// A stop from anywhere — a tap on the message, Escape reaching the
  /// operation view before the field — drops every word typed, handed over
  /// or held, and leaves the mode on and empty, ready for a fresh message:
  /// a stop is the operator abandoning what they were sending, all of it.
  /// (Escape in the field goes on to end the mode.)
  void _onStopped() {
    if (_done) return;
    _clears++;
    _text = '';
    _handedOff = 0;
    _paused = false;
    _debounce?.cancel();
    _restartIdle();
    notifyListeners();
  }

  void _onProgress() {
    if (progress.value == null) _feed();
  }

  void _feed() {
    if (_done || busy()) return;
    final held = _text.substring(_handedOff);
    _handOff(_paused ? held.length : held.lastIndexOf(' ') + 1);
  }

  /// Hands the first [length] held characters over — all of them, unless
  /// said otherwise.
  void _handOff([int? length]) {
    final held = _text.substring(_handedOff, _handedOff + (length ?? _text.length - _handedOff));
    // Spaces alone are kept back: the queue drops them, and the gap they
    // stand for is the idle time before the next letter anyway. Held, they
    // stay deletable.
    if (held.trim().isEmpty) return;
    _handedOff += held.length;
    send(held);
    notifyListeners();
  }

  void _restartIdle() {
    _idle?.cancel();
    _idle = Timer(cwLiveTypingIdle, finish);
  }

  void _end() {
    _done = true;
    _idle?.cancel();
    _debounce?.cancel();
    progress.removeListener(_onProgress);
    stops.removeListener(_onStopped);
    notifyListeners();
    onDone?.call();
  }

  @override
  void dispose() {
    _idle?.cancel();
    _debounce?.cancel();
    progress.removeListener(_onProgress);
    stops.removeListener(_onStopped);
    super.dispose();
  }
}

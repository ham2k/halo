// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Message 1, going again — the repeat chain behind `cwRepeatDelay` and
// `voiceRepeatDelay` (docs/design/cat.md § CW keying).
//
// ONE engine for both keyers: a CW message and a voice memory differ only in
// what is sent again, and the send is supplied by whoever armed it — a
// template has to be re-rendered against the draft contact, which is the
// operation view's job, while a memory needs nothing prepared.
//
// Only message 1 repeats. That rule is the caller's, not this file's: an
// exchange that repeated would key over the contact it is answering.
//
// Nothing here knows which side of a peer link the message goes out on. What
// starts a wait is the message ENDING, and [startWait] is called from
// whichever report says so — a local keyer's, or a peer's status.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

/// A repeat's wait: how long until message 1 goes again, and what went out
/// last time — the keyer area's countdown runs on the first and labels
/// itself with the second. [memory] names a VOICE memory instead, whose
/// label the strip resolves itself, since what is repeating there is audio
/// in the radio rather than text the app rendered.
class KeyerRepeatWait {
  final Duration delay;
  final String text;

  /// Null for a CW message; the memory number for a voice one.
  final int? memory;

  const KeyerRepeatWait({required this.delay, required this.text, this.memory});
}

/// How long a chain of repeats may run before it stops on its own — an
/// unattended CQ that keys forever is a transmitter nobody is watching.
const keyerRepeatLimit = Duration(minutes: 5);

/// How far the VFO may move from where a CW repeat went out before the chain
/// stops: further than a CQ's own caller can be zero-beat to, and the CQ is
/// going out somewhere it was never called.
const keyerRepeatCwToleranceHz = 50;

/// The same for a voice repeat, wider because a phone signal is: a few
/// hundred hertz is still the same CQ to anyone listening.
const keyerRepeatVoiceToleranceHz = 300;

class KeyerRepeat {
  /// The VFO now, or null when there is none to read.
  final Vfo? Function()? vfo;

  KeyerRepeat({this.vfo});

  /// The wait now running, or null — non-null only while it is, so the keyer
  /// area's countdown bar is mounted exactly then.
  final wait = ValueNotifier<KeyerRepeatWait?>(null);

  /// Whether a chain is running at all — armed, keying, waiting, or in the
  /// gap between the wait ending and the next message reaching the radio. Its
  /// own notifier rather than [running]: the strip has to REBUILD on the
  /// gap's edges, and a getter notifies nobody — the buttons would flash back
  /// for the length of a template render.
  final active = ValueNotifier<bool>(false);

  /// Keys message 1 again — see the header on why the caller supplies it.
  void Function()? _send;
  Duration _delay = Duration.zero;
  String _text = '';

  /// The voice memory repeating, or null for a CW message — so the wait is
  /// started by the right keyer's end and not by the other one's.
  int? memory;

  Timer? _timer;

  /// Where the VFO was when the last repeat went out — what a move is
  /// measured from, re-based at every send, so a slow walk across the band
  /// between repeats is a series of small moves rather than one big one.
  Vfo? _sentAt;

  /// When the repeats stop whatever else happens, as real milliseconds: a
  /// deadline whose remainder becomes a Timer duration must not travel with
  /// the app clock (docs/design/time.md).
  int? _until;

  /// Whether a repeat is armed or counting down.
  bool get running => _send != null;

  /// When this chain stops whatever else happens, or null while none is
  /// running. Read only to be asserted on: the deadline comes off the real
  /// clock (docs/design/time.md §7), so nothing can elapse fake timers past
  /// it, and a re-arm keeping the deadline it inherited is the part that IS
  /// testable.
  int? get deadlineMillis => _until;

  /// Every stop is one the operator makes — an entered call, Escape, a tap,
  /// the setting, or the VFO moving ([noteVfo]), whether in the app or
  /// on the radio's own knob. The radio keying on its own (a mic or a paddle
  /// during the wait) does NOT stop the chain, because nothing reports
  /// transmit state upward: no driver has a TX read wired to a sink, so there
  /// is no signal to listen to. Adding one is a driver capability, not a
  /// check here.

  /// Arms message 1 to go again [delay] after the one now keying finishes.
  /// Re-arming inside a chain keeps the deadline the chain started with, so
  /// five minutes is five minutes from the first send and not a limit that
  /// each repeat pushes further away.
  void arm({required Duration delay, required String text, required void Function() send, int? memory}) {
    if (delay <= Duration.zero) return;
    _timer?.cancel();
    _timer = null;
    _send = send;
    _delay = delay;
    _text = text;
    this.memory = memory;
    _sentAt = vfo?.call();
    _until ??= realNowMillis() + keyerRepeatLimit.inMilliseconds;
    wait.value = null;
    active.value = true;
  }

  /// Ends the chain — every stop the operator can make lands here.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _send = null;
    memory = null;
    _sentAt = null;
    _until = null;
    if (wait.value != null) wait.value = null;
    active.value = false;
  }

  /// The message the repeat was armed on has stopped keying: either the wait
  /// starts, or the chain has run its five minutes.
  void startWait() {
    final send = _send;
    if (send == null || _timer != null) return;
    if ((_until ?? 0) <= realNowMillis()) {
      cancel();
      return;
    }
    wait.value = KeyerRepeatWait(delay: _delay, text: _text, memory: memory);
    _timer = Timer(_delay, () {
      _timer = null;
      wait.value = null;
      // The deadline is checked again HERE, not only above: a wait that
      // started inside the five minutes can end outside them.
      if (_send == null) return;
      if ((_until ?? 0) <= realNowMillis()) {
        cancel();
        return;
      }
      send();
    });
  }

  /// The VFO is now [now]. On another band, or further from where the last
  /// repeat went out than its keyer's tolerance, and the operator has left
  /// the frequency the CQ is calling on: the chain ends. The band is what a
  /// station with no frequency to read — a keyer without CAT, a log kept by
  /// band — has to go on. A frequency gone missing on the same band, an
  /// emptied Frequency field, is not a move: the radio has not gone anywhere.
  /// A message keying now plays out — the same as a keypress, which stops
  /// nothing either.
  void noteVfo(Vfo? now) {
    final sentAt = _sentAt;
    if (_send == null || sentAt == null || now == null) return;
    if (sentAt.band != null && now.band != null && now.band != sentAt.band) return cancel();
    final from = sentAt.freq;
    final to = now.freq;
    if (from == null || to == null) return;
    final tolerance = memory != null ? keyerRepeatVoiceToleranceHz : keyerRepeatCwToleranceHz;
    // In whole hertz: a kHz difference of exactly 0.05 can come out a hair
    // over it in floating point.
    if (((to - from) * 1000).abs().round() > tolerance) cancel();
  }

  void dispose() {
    _timer?.cancel();
    wait.dispose();
    active.dispose();
  }
}

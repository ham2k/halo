// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What every voice-keying session has in common once the command is out:
// one activity at a time, reported as it starts and as it ends, a poll
// while it lasts (each protocol has a different question for "still
// going?"), and a ceiling past which it is over whatever the radio says —
// a rig whose protocol never answers the question would otherwise show a
// message playing forever (docs/design/cat.md § Voice keying). The ceiling
// STOPS the radio too: a recording never ends on its own, and an activity
// the app has stopped showing is one the operator can no longer stop.
//
// An answer of "not going" that arrives before any answer of "going" is
// the one thing the polls can say about a REFUSED play — the memory empty,
// the radio not in a voice mode — which most protocols here never report
// outright. It is shown as doubtful (a question mark) for a second rather
// than as a play that simply ended, so an unrecorded memory does not pass
// for a short one. A protocol that DOES refuse outright (SmartSDR's error
// answer) doubts at once through [VoiceActivityTracker.refuse], recording or
// not: a refusal is the radio's word, not a read that cannot tell. Doubt is not an end: the polls and the ceiling run on
// through it, a "going" answer takes the question mark away (a radio can
// need more than one poll to key up), and the doubt expiring stops the
// radio before clearing — an activity the app no longer shows must never
// be one it can no longer stop.
//
// A RECORDING is never doubted by a poll. The FT-891 answers its recording
// read with "idle" while its own panel blinks REC, so an unconfirmed
// recording says more about the read than about the radio — and a doubt
// that stopped one would take the operator's audio with it. A recording ends at its ceiling
// or when the operator stops it, which is what ends one anyway.

import 'dart:async';

import '../driver.dart';

/// How often a session asks its radio whether the memory is still going.
const voiceActivityPollInterval = Duration(seconds: 1);

class VoiceActivityTracker {
  final void Function(VoiceActivity?) report;

  /// Sends the protocol's own "still going?" — null for a session with
  /// nothing to ask, which then relies on [voiceActivityCeiling] alone.
  final void Function()? poll;

  /// The session's own stop — what its `stopVoice` does — for the ceiling
  /// to call: what the app stops showing it must also stop on the air. It
  /// is expected to [end] this tracker itself, the way a stop from the
  /// operator does.
  final void Function() stop;

  /// How long an activity may run before [stop] — the radio's own memory
  /// length where the entry knows it, [voiceActivityCeiling] otherwise
  /// ([VoiceKeyerSession.voiceMemoryCeiling]).
  final Duration Function() ceiling;

  /// Told when the ceiling, not the radio or the operator, ended an
  /// activity — for a developer diagnostic, since a memory that keeps
  /// ending at the default fifteen seconds is an entry missing its length.
  final void Function(Duration ceiling)? onCeiling;

  VoiceActivity? _activity;
  Timer? _poll;
  Timer? _ceiling;
  Timer? _doubt;
  Timer? _settle;

  /// Whether a poll has answered "still going" since [start] — see
  /// [endFromPoll].
  bool _confirmed = false;

  /// Whether [voiceActivityPollInterval] has elapsed since [start].
  ///
  /// The radio is given that long to key up before anything it says is read
  /// as a refusal — which used to be implicit, because the tracker's own
  /// poll was the only thing that ever asked. It is not any more: on CI-V
  /// the telemetry watch asks the same question ("are you transmitting?")
  /// several times a second, and its first answer lands while the rig is
  /// still keying. Read as a refusal, that puts a question mark on every
  /// play, and on a slow link stops a memory that is on the air.
  bool _settled = false;

  VoiceActivityTracker({required this.report, required this.stop, required this.ceiling, this.poll, this.onCeiling});

  VoiceActivity? get activity => _activity;

  bool get active => _activity != null;

  /// Reports [activity] and starts watching it. A second start replaces the
  /// first — the radio can only do one thing, and the command just sent
  /// is what it is doing now.
  void start(VoiceActivity activity) {
    _cancelTimers();
    _activity = activity;
    _confirmed = false;
    _settled = false;
    report(activity);
    // Reporting can synchronously end or replace this activity. Its old
    // start must not arm timers after that receiver has gone away.
    if (!identical(_activity, activity)) return;
    if (poll != null) {
      _poll = Timer.periodic(voiceActivityPollInterval, (_) {
        _settled = true;
        poll!();
      });
    } else {
      // Nothing to ask, so nothing can arrive early — but an answer may
      // still reach [endFromPoll] from elsewhere, and after this long it
      // means what it says.
      _settle = Timer(voiceActivityPollInterval, () => _settled = true);
    }
    final limit = ceiling();
    _ceiling = Timer(limit, () {
      onCeiling?.call(limit);
      stop();
      // Belt and braces: a stop that did not end the tracker would leave
      // the poll running with nothing to end it.
      end();
    });
  }

  /// A poll answered "still going": from here an end is an end, not a
  /// refusal — and a doubt in progress is withdrawn, the radio having
  /// merely taken more than one poll to key up.
  void confirm() {
    final activity = _activity;
    if (activity == null) return;
    _confirmed = true;
    if (!activity.doubtful) return;
    _doubt?.cancel();
    _doubt = null;
    _activity = VoiceActivity(memory: activity.memory, recording: activity.recording);
    report(_activity);
  }

  /// A poll answered "not going". After a [confirm] that is the memory
  /// over; before one it is the radio never having started — shown as
  /// doubtful for [voiceDoubtLinger], then stopped and ended. The polls and
  /// the ceiling run on through the doubt: a radio slow to key up answers
  /// "going" on the next one, and a refused play is still stopped — a stop
  /// to an idle radio costs nothing, while a memory on the air behind a
  /// cleared strip would be one the operator cannot stop.
  void endFromPoll() {
    final activity = _activity;
    if (activity == null) return;
    if (_confirmed) {
      end();
      return;
    }
    // Too early to mean anything: the radio has not had [voiceActivityPollInterval]
    // to key up, and something else on the link may be asking the same
    // question far faster than this tracker does.
    if (!_settled) return;
    // Doubt is about a REFUSED PLAY. A recording that has not yet answered
    // "still going" is far more likely a radio whose read cannot say so (the
    // FT-891's `LM` is exactly that), and stopping one costs the operator
    // the audio they are in the middle of recording — so a recording runs to
    // its ceiling instead, which is what ends it anyway.
    if (activity.recording) return;
    // A second "not going" while already in doubt changes nothing: the
    // linger runs its course, so the question mark is seen.
    if (activity.doubtful) return;
    _beginDoubt(activity);
  }

  /// The radio REFUSED the command outright — an error answer to it, which
  /// only some protocols give (SmartSDR's). Doubtful at once, recording or
  /// not and however soon: unlike a poll's "not going", a refusal cannot be
  /// a radio that has not keyed up yet, nor a read that cannot tell.
  void refuse() {
    final activity = _activity;
    if (activity == null || activity.doubtful) return;
    _beginDoubt(activity);
  }

  void _beginDoubt(VoiceActivity activity) {
    _activity = activity.asDoubtful();
    report(_activity);
    _doubt = Timer(voiceDoubtLinger, () {
      stop();
      end();
    });
  }

  /// Reports the end, if anything was going. Idempotent: a poll answer and
  /// an explicit stop both land here, in either order.
  void end() {
    _cancelTimers();
    if (_activity == null) return;
    _activity = null;
    report(null);
  }

  /// For teardown: stops the timers, and clears what was showing — a
  /// session that is gone is not playing anything.
  void dispose() => end();

  void _cancelTimers() {
    _poll?.cancel();
    _poll = null;
    _ceiling?.cancel();
    _ceiling = null;
    _doubt?.cancel();
    _doubt = null;
    _settle?.cancel();
    _settle = null;
  }
}

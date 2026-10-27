// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

// The app's single source of "now" — see docs/design/time.md.
//
// Nothing outside this file may call DateTime.now(): a logger is all about
// time, and a clock that only SOME of the app reads is worse than no override
// at all — a QSO stamped on the travelled clock next to a duplicate check run
// on the real one produces failures that look like logic bugs. Library code
// calls nowUtc()/nowLocal()/nowMillis(); scripts/test.sh fails the build on any
// other DateTime.now() that doesn't carry a `clock:allow` marker.
//
// Travel is DEVELOPER-ONLY and never persisted, so every launch starts on the
// real clock. The app gates it further (developer mode, and never against a
// real sync account) — those rules live at the command's host action, not here:
// this class is the mechanism, pure Dart so core, widgets, app and CLI can all
// share it.

import 'package:clock/clock.dart';
import 'package:meta/meta.dart';

/// A clock that can be offset and rescaled at runtime.
///
/// The travelled clock is defined by an ANCHOR pair rather than a bare offset:
/// the real and virtual instants at which travel was last configured. Virtual
/// time then advances from the virtual anchor at [speed] times the rate real
/// time advances from the real anchor. Anchoring is what makes a speed change
/// continuous — recomputing from a fixed epoch would teleport the clock by
/// hours the moment the factor changed — and it keeps virtual time monotonic
/// for any positive speed, which the whole UI (elapsed-time labels, sequence
/// numbers, staleness checks) assumes.
class AppClock {
  AppClock._();

  /// The app-wide clock. A singleton on purpose: every call site in every
  /// package must read the SAME travel state, and threading a clock through
  /// them would leave the ones that missed it silently on real time.
  static final AppClock instance = AppClock._();

  /// The furthest from real time the clock may be set, in either direction.
  ///
  /// A bound is required, not tidiness: `DateTime.add` WRAPS on int64
  /// microsecond overflow instead of throwing, so a large enough offset lands
  /// the clock in a negative epoch, and a QSO logged there is written with a
  /// negative `startAtMillis` that renders as garbage and loses every sync
  /// comparison. A century is far past any plausible test and nowhere near the
  /// wrap.
  static const maxTravel = Duration(days: 365 * 100);

  /// The fastest the clock may run.
  ///
  /// Also a safety bound rather than a preference: the per-second UI heartbeat
  /// divides its wait by this factor ([WallClock]), so an unbounded speed
  /// collapses it into a millisecond timer chain that notifies every
  /// subscriber a thousand times a second — and the only way back is typing
  /// into a UI that has stopped responding.
  static const maxSpeed = 1000.0;

  DateTime? _anchorReal;
  DateTime? _anchorVirtual;
  double _speed = 1.0;

  final List<void Function()> _listeners = [];

  /// Whether the clock currently departs from real time in any way.
  bool get isTravelling => _anchorReal != null;

  /// How far ahead (positive) or behind (negative) real time the clock reads
  /// right now. Under a speed factor it keeps growing.
  ///
  /// Derived from the anchors rather than by subtracting two clock reads: two
  /// reads are microseconds apart, and the difference of a `+1h` travel comes
  /// out as 59m 59.999s — which a label rounds down to "+59m 59s".
  Duration get offset {
    final anchorReal = _anchorReal;
    if (anchorReal == null) return Duration.zero;
    final atAnchor = _anchorVirtual!.difference(anchorReal);
    if (_speed == 1.0) return atAnchor;
    return atAnchor + _realNowUtc().difference(anchorReal) * (_speed - 1);
  }

  /// Virtual seconds per real second. Always > 0.
  double get speed => _speed;

  /// The offset that was SET — the gap between the anchors — as opposed to
  /// [offset], which is where the clock has drifted to since.
  ///
  /// This is what any label shows. Under a speed factor [offset] grows every
  /// second, so a string built from it is stale the moment after it is written:
  /// a status-bar item posted once would read "+0s at 100x" for a whole session
  /// while the clock sat four days out, and a settings row rebuilding on its own
  /// schedule would contradict it. The configured offset never goes stale, and
  /// the live reading is on the clock face itself.
  Duration get anchoredOffset {
    final anchorReal = _anchorReal;
    return anchorReal == null ? Duration.zero : _anchorVirtual!.difference(anchorReal);
  }

  /// The real instant travel was last configured, as epoch millis — 0 when not
  /// travelling. With [anchorVirtualMillis] and [speed] this is the whole clock:
  /// it is what gets handed to the extension sandbox, which reproduces the same
  /// formula rather than being told an offset that would already be stale.
  int get anchorRealMillis => _anchorReal?.millisecondsSinceEpoch ?? 0;

  /// The virtual instant matching [anchorRealMillis] — 0 when not travelling.
  int get anchorVirtualMillis => _anchorVirtual?.millisecondsSinceEpoch ?? 0;

  /// The current time, UTC — what nearly every caller wants, since QSO times,
  /// ADIF and the sync protocol are all UTC.
  DateTime nowUtc() => _virtualAt(_realNowUtc());

  /// The current time in the device's local zone.
  DateTime nowLocal() => nowUtc().toLocal();

  /// The current time as epoch milliseconds (UTC), for the `*Millis` columns.
  int nowMillis() => nowUtc().millisecondsSinceEpoch;

  /// Moves the clock by [delta] and/or sets its [speed], and re-anchors.
  ///
  /// [delta] is CUMULATIVE — it shifts from wherever the clock already reads,
  /// so `+1d` three times lands three days out. Resetting is [reset], not a
  /// delta that happens to cancel out.
  void travel({Duration? delta, double? speed}) {
    if (speed != null && (!speed.isFinite || speed <= 0 || speed > maxSpeed)) {
      throw ArgumentError.value(speed, 'speed', 'must be greater than 0 and at most ${maxSpeed.toInt()}');
    }
    if (delta != null && delta.abs() > maxTravel) {
      throw ArgumentError.value(delta.inDays, 'delta', 'must be within ${maxTravel.inDays} days');
    }
    // Checked on the RESULT, not just the argument: deltas accumulate, so a
    // hundred in-range hops would otherwise reach the same overflow one
    // out-of-range hop is refused for.
    if (delta != null && (anchoredOffset + delta).abs() > maxTravel) {
      throw ArgumentError.value(delta.inDays, 'delta', 'would put the clock more than ${maxTravel.inDays} days out');
    }
    // ONE real read, used for both anchors. Reading the real clock twice (once
    // for the virtual base, once for the new real anchor) leaves the anchors a
    // few microseconds out of step, so a clean `+1h` becomes 59m 59.999s.
    // Virtual now is read BEFORE the anchors change: it is the base the delta
    // applies to, and the old anchors are what define it.
    final real = _realNowUtc();
    final virtualNow = _virtualAt(real);
    _anchorReal = real;
    _anchorVirtual = delta == null ? virtualNow : virtualNow.add(delta);
    if (speed != null) _speed = speed;
    // A request that lands ON real time is real time, not a third state. Without
    // this, `DEVTT 1x` (or an offset that cancels out) leaves isTravelling true
    // with the clock reading exactly now — and everything gated on travel, above
    // all sync, silently stays barred behind a status chip that shows no offset
    // to explain it.
    if (_speed == 1.0 && _anchorVirtual!.difference(real).abs() < const Duration(seconds: 1)) {
      reset();
      return;
    }
    _notify();
  }

  /// Returns the clock to real time.
  void reset() {
    if (!isTravelling && _speed == 1.0) return;
    _anchorReal = null;
    _anchorVirtual = null;
    _speed = 1.0;
    _notify();
  }

  /// A compact description of how the clock is SET, e.g. `+3d 2h at 2x` — or
  /// null when not travelling.
  ///
  /// Built from [anchoredOffset], so it never changes on its own. This is the
  /// label for a surface that does NOT tick: it rebuilds on its own schedule,
  /// and a growing string there would be stale every time it was read. Use
  /// [liveTravelLabel] wherever something is actually refreshing.
  ///
  /// Developer-facing, so plain English with no i18n catalog.
  String? get travelLabel => _label(anchoredOffset);

  /// What the clock reads RIGHT NOW relative to real time, e.g. `+5m at 100x`
  /// — or null when not travelling.
  ///
  /// Built from the live [offset], which keeps growing under a speed factor, so
  /// only a surface that re-reads it may show it. `DEVTT 100x` sets no offset at
  /// all, and the interesting thing about it a minute later is exactly how far
  /// the clock has got — which [travelLabel] cannot say.
  String? get liveTravelLabel => _label(offset);

  String? _label(Duration delta) {
    if (!isTravelling) return null;
    final parts = <String>[];
    if (delta.inSeconds.abs() >= 1) parts.add(_formatOffset(delta));
    if (_speed != 1.0) parts.add('at ${_formatSpeed(_speed)}x');
    // Reachable while travelling with neither an offset nor a factor yet — the
    // instant after a bare `travel()`, or the first second of a speed-only hop.
    // Say something rather than rendering an empty chip.
    return parts.isEmpty ? 'now' : parts.join(' ');
  }

  /// Notified whenever travel changes, so UI that displays or ticks on the
  /// clock can rebuild and re-arm immediately instead of at its next tick.
  void addListener(void Function() listener) => _listeners.add(listener);

  void removeListener(void Function() listener) => _listeners.remove(listener);

  // Iterates a copy: a listener may remove itself (or another) in response.
  //
  // Each listener is isolated, the way ChangeNotifier isolates its own. By the
  // time this runs the anchors have already moved, so a listener that throws
  // must not skip the ones after it — that leaves travel half-applied (the
  // clock moved, but the sandbox was never told, or the heartbeat never
  // re-armed) and reports as the command having failed. Errors are collected
  // and rethrown together once every listener has had its turn.
  void _notify() {
    Object? firstError;
    for (final listener in List.of(_listeners)) {
      try {
        listener();
      } catch (e) {
        firstError ??= e;
      }
    }
    // Rethrown as its OWN type, not the listener's: by this point travel has
    // been applied, and a caller has to be able to tell "the clock did not
    // move" (an ArgumentError from validation, thrown before any mutation) from
    // "the clock moved but something did not hear about it". A listener raising
    // an ArgumentError of its own would otherwise be indistinguishable from a
    // rejected argument, and reported to the operator as a refusal.
    if (firstError != null) throw ClockListenerException(firstError);
  }

  /// The real clock, deliberately outside the app clock — see [realNowUtc].
  DateTime realNow() => _realNowUtc();

  /// What the clock reads at real instant [real] — a pure function of the
  /// anchors, so every caller in one operation can share a single real read.
  DateTime _virtualAt(DateTime real) {
    final anchorReal = _anchorReal;
    if (anchorReal == null) return real;
    final elapsed = real.difference(anchorReal);
    return _anchorVirtual!.add(_speed == 1.0 ? elapsed : elapsed * _speed);
  }

  /// Whether the real read follows package:clock's zone clock — the fake one
  /// `elapse` advances inside `fakeAsync` — instead of the system's, so a test
  /// that drives timers on fake time drives every [nowUtc] and [realNowUtc]
  /// read along with them (docs/design/time.md §7).
  ///
  /// Opt-in, and in a widget test never alongside `tester.runAsync`:
  /// `testWidgets` runs every test on a fake clock fixed at 2015, while a
  /// `runAsync` body reads the real one. Followed there, a fixture written in
  /// `runAsync` and a save the widgets make would be stamped a decade apart,
  /// and the save dropped as stale.
  @visibleForTesting
  static bool followZoneClock = false;

  /// The one real-time read in the codebase.
  DateTime _realNowUtc() => (followZoneClock ? clock.now() : DateTime.now()).toUtc(); // clock:allow — the clock itself
}

/// The current time, UTC. The default "now" for library code.
DateTime nowUtc() => AppClock.instance.nowUtc();

/// The current time in the device's local zone.
DateTime nowLocal() => AppClock.instance.nowLocal();

/// The current time as epoch milliseconds (UTC).
int nowMillis() => AppClock.instance.nowMillis();

/// **The real clock, immune to time travel.** Use this — never a bare
/// `DateTime.now()` — for the two kinds of read that must not travel. Both are
/// about the world outside this app's own sense of time, and both produce
/// WRONG ANSWERS on the travelled clock rather than merely surprising ones.
///
/// 1. **Values that leave the app and are compared against someone else's
///    clock.** A sync revision stamp (`updatedAtMillis`) is the case that
///    matters: it persists in the database and reaches the server the moment
///    sync resumes, long after the offset is gone, where it wins or loses
///    every conflict against another device for the length of that offset —
///    silently discarding the operator's real edits. Being unable to sync
///    *while* travelling does not help, because the value outlives the travel.
/// 2. **Real elapsed time.** Protocol timeouts and handshakes, rate-limit
///    cooldowns, throttles whose remainder becomes a `Timer` duration (a
///    `Timer` fires on real time and knows nothing about travel), and
///    diagnostics whose timestamps are read against the operator's own
///    wristwatch.
///
/// Everything else — QSO times, staleness, contest windows, anything the
/// operator reads as "the time" — uses [nowUtc]/[nowLocal]/[nowMillis] and
/// travels. In particular a QSO's `startAtMillis` MUST travel: logging into a
/// moved clock is the entire point of the feature.
///
/// The test for which one you want: *would a developer time-travelling three
/// days forward want this value three days forward?* For a QSO time, yes. For
/// the revision counter that decides whose edit wins, absolutely not.
///
/// docs/design/time.md §1 lists every call site and its reason.
DateTime realNowUtc() => AppClock.instance.realNow();

/// [realNowUtc] as epoch milliseconds — the form the `*Millis` columns take.
int realNowMillis() => AppClock.instance.realNow().millisecondsSinceEpoch;

/// The largest whole units of [delta], signed — `+3d 2h`, `-45m`. Two units is
/// the readable ceiling for a status chip; the seconds place only shows when
/// there is nothing bigger to say.
String _formatOffset(Duration delta) {
  final sign = delta.isNegative ? '-' : '+';
  final abs = delta.abs();
  final units = <String, int>{'d': abs.inDays, 'h': abs.inHours % 24, 'm': abs.inMinutes % 60, 's': abs.inSeconds % 60};
  // Zero units are SKIPPED, never a reason to stop: `+1d 45m` has a zero hours
  // place between its two, and breaking there reports "+1d" for a clock 45
  // minutes further out than it says — understating the one number the status
  // item exists to show.
  final shown = <String>[];
  for (final entry in units.entries) {
    if (entry.value == 0) continue;
    shown.add('${entry.value}${entry.key}');
    if (shown.length == 2) break;
  }
  return '$sign${shown.isEmpty ? '0s' : shown.join(' ')}';
}

/// `2` for 2.0, `0.5` for a half — no trailing `.0` on the common whole cases.
String _formatSpeed(double speed) => speed == speed.roundToDouble() ? speed.toStringAsFixed(0) : speed.toString();

/// A listener threw while being told about a change of travel.
///
/// The change IS applied — [AppClock] mutates its anchors before notifying, and
/// notifies every listener before raising this. It means some part of the app
/// has not heard about the new clock, which is a different thing from the change
/// having been refused.
class ClockListenerException implements Exception {
  /// What the listener threw.
  final Object cause;

  ClockListenerException(this.cause);

  @override
  String toString() => 'a clock listener failed: $cause';
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// AppClock is the whole app's "now" (docs/design/time.md), so the traps here
// are not about arithmetic — they are about what the rest of the app assumes of
// a clock and would break on:
//
//  • A delta is CUMULATIVE. If it were absolute, `DEVTT +1d` typed twice would
//    sit on day one forever, and stepping through a window (the reason the
//    command exists) would be impossible.
//  • Setting a speed must not MOVE the clock. Recomputing from a fixed epoch
//    instead of from the anchor pair would teleport it by hours the instant the
//    factor changed, which reads as "time travel is broken" rather than as a
//    formula bug.
//  • Time only ever moves forward. Elapsed-time labels, sequence numbers and
//    every staleness check assume it, so a zero or negative speed is refused
//    rather than passed through to break them subtly.

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

/// The clock is a singleton (deliberately — one clock for every package), so
/// every test has to hand it back.
void main() {
  tearDown(AppClock.instance.reset);

  /// Real time, for comparing against what the clock says.
  DateTime realNow() => DateTime.now().toUtc(); // clock:allow — the reference the tests compare to

  group('untravelled', () {
    test('reads real time', () {
      expect(AppClock.instance.isTravelling, isFalse);
      expect(nowUtc().difference(realNow()).abs(), lessThan(const Duration(seconds: 1)));
      expect(AppClock.instance.speed, 1.0);
      expect(AppClock.instance.offset, Duration.zero);
      expect(AppClock.instance.travelLabel, isNull);
    });

    test('nowMillis and nowLocal agree with nowUtc', () {
      final utc = nowUtc();
      expect((nowMillis() - utc.millisecondsSinceEpoch).abs(), lessThan(1000));
      // Same instant, different zone — never a different wall-clock reading
      // shifted by the offset twice.
      expect(nowLocal().toUtc().difference(utc).abs(), lessThan(const Duration(seconds: 1)));
    });
  });

  group('offset', () {
    test('moves the clock by the delta', () {
      final before = realNow();
      AppClock.instance.travel(delta: const Duration(hours: 3));
      expect(nowUtc().difference(before.add(const Duration(hours: 3))).abs(), lessThan(const Duration(seconds: 1)));
      expect(AppClock.instance.isTravelling, isTrue);
    });

    test('a negative delta moves it back', () {
      final before = realNow();
      AppClock.instance.travel(delta: const Duration(days: -1));
      expect(nowUtc().isBefore(before), isTrue);
      expect(AppClock.instance.offset.inHours, closeTo(-24, 1));
    });

    // Cumulative, NOT absolute: this is what makes DEVTT a step command.
    test('deltas accumulate across calls', () {
      AppClock.instance.travel(delta: const Duration(days: 1));
      AppClock.instance.travel(delta: const Duration(days: 1));
      AppClock.instance.travel(delta: const Duration(days: 1));
      expect(AppClock.instance.offset.inHours, closeTo(72, 1));
    });

    test('reset returns to real time', () {
      AppClock.instance.travel(delta: const Duration(days: 5));
      AppClock.instance.reset();
      expect(AppClock.instance.isTravelling, isFalse);
      expect(nowUtc().difference(realNow()).abs(), lessThan(const Duration(seconds: 1)));
    });
  });

  group('speed', () {
    // The anchoring test: were `now` computed from a fixed epoch rather than
    // from the anchor pair, this multiplication would apply to the WHOLE epoch
    // and land the clock decades away.
    test('setting a factor does not move the clock', () {
      AppClock.instance.travel(delta: const Duration(days: 2));
      final before = nowUtc();
      AppClock.instance.travel(speed: 1000);
      expect(
        nowUtc().difference(before).abs(),
        lessThan(const Duration(seconds: 2)),
        reason: 'a speed change is continuous — it changes the RATE, not the reading',
      );
    });

    test('virtual time advances faster than real time', () async {
      AppClock.instance.travel(speed: 1000);
      final start = nowUtc();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final virtualElapsed = nowUtc().difference(start);
      // 20ms of real time at 1000x is 20s of virtual time. Asserted well under
      // that (the delay only guarantees a LOWER bound on real elapsed time, and
      // a loaded machine overshoots), but far above the 20ms an unscaled clock
      // would report — which is the thing being proven.
      expect(virtualElapsed, greaterThan(const Duration(seconds: 5)));
    });

    test('the offset keeps growing under a factor', () async {
      AppClock.instance.travel(speed: 500);
      final first = AppClock.instance.offset;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(AppClock.instance.offset, greaterThan(first));
    });

    test('a fractional factor slows the clock without stopping it', () async {
      AppClock.instance.travel(speed: 0.5);
      final start = nowUtc();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final elapsed = nowUtc().difference(start);
      expect(elapsed, greaterThan(Duration.zero), reason: 'slower is not stopped');
      expect(elapsed, lessThan(const Duration(milliseconds: 20)));
    });

    test('reset restores 1x', () {
      AppClock.instance.travel(speed: 10);
      AppClock.instance.reset();
      expect(AppClock.instance.speed, 1.0);
    });

    for (final bad in [0.0, -1.0, double.nan, double.infinity]) {
      test('refuses a speed of $bad', () {
        expect(() => AppClock.instance.travel(speed: bad), throwsA(isA<ArgumentError>()));
        expect(AppClock.instance.isTravelling, isFalse, reason: 'a refused call must not half-apply');
      });
    }

    // The bound exists because of what the per-second UI heartbeat does with the
    // factor: it divides its wait by it, so an unbounded speed turns the shared
    // clock into a millisecond timer chain that rebuilds every subscriber a
    // thousand times a second — and the only way back is typing into a UI that
    // has stopped responding.
    test('refuses a speed past the cap', () {
      expect(() => AppClock.instance.travel(speed: AppClock.maxSpeed + 1), throwsA(isA<ArgumentError>()));
      expect(AppClock.instance.isTravelling, isFalse);
    });

    test('allows exactly the cap', () {
      AppClock.instance.travel(speed: AppClock.maxSpeed);
      expect(AppClock.instance.speed, AppClock.maxSpeed);
    });
  });

  // A request that resolves to real time must LEAVE real time, not sit in a
  // travelling state with a zero offset: everything gated on `isTravelling` —
  // above all sync — would stay barred with nothing on screen explaining it.
  group('a no-op request is not travel', () {
    test('1x with no offset stays on real time', () {
      AppClock.instance.travel(speed: 1);
      expect(AppClock.instance.isTravelling, isFalse);
      expect(AppClock.instance.travelLabel, isNull);
    });

    test('an offset that cancels out returns to real time', () {
      AppClock.instance.travel(delta: const Duration(hours: 3));
      expect(AppClock.instance.isTravelling, isTrue, reason: 'sanity');
      AppClock.instance.travel(delta: const Duration(hours: -3));
      expect(AppClock.instance.isTravelling, isFalse);
    });

    test('dropping a factor while an offset stands keeps travelling', () {
      AppClock.instance.travel(delta: const Duration(days: 2), speed: 4);
      AppClock.instance.travel(speed: 1);
      expect(AppClock.instance.isTravelling, isTrue);
      expect(AppClock.instance.travelLabel, '+2d');
    });
  });

  group('bounds on the offset', () {
    // `DateTime.add` WRAPS on int64 microsecond overflow instead of throwing, so
    // an unbounded offset lands the clock in a NEGATIVE epoch — where the Time
    // chip shows an impossible date and any QSO logged is written with a negative
    // startAtMillis that renders as garbage and loses every sync comparison.
    // Refusing is the only way that failure gets reported at all.
    test('refuses an offset past the cap', () {
      expect(() => AppClock.instance.travel(delta: AppClock.maxTravel + const Duration(days: 1)), throwsA(isA<ArgumentError>()));
      expect(AppClock.instance.isTravelling, isFalse);
    });

    test('refuses an absurd offset rather than wrapping the epoch', () {
      expect(() => AppClock.instance.travel(delta: const Duration(days: 400000000)), throwsA(isA<ArgumentError>()));
      expect(nowUtc().year, greaterThan(2000), reason: 'the clock must still be in this era');
    });

    // Checked on the RESULT, not just the argument: deltas accumulate, so
    // repeated in-range hops would otherwise reach the same overflow.
    test('refuses a hop that would put the ACCUMULATED offset past the cap', () {
      AppClock.instance.travel(delta: AppClock.maxTravel - const Duration(days: 1));
      expect(() => AppClock.instance.travel(delta: const Duration(days: 30)), throwsA(isA<ArgumentError>()));
      // The earlier, legitimate travel is untouched.
      expect(AppClock.instance.offset.inDays, closeTo(AppClock.maxTravel.inDays - 1, 1));
    });
  });

  group('travelLabel', () {
    test('names the offset and the factor', () {
      AppClock.instance.travel(delta: const Duration(days: 3, hours: 2), speed: 2);
      expect(AppClock.instance.travelLabel, '+3d 2h at 2x');
    });

    test('signs a backward offset', () {
      AppClock.instance.travel(delta: const Duration(minutes: -45));
      expect(AppClock.instance.travelLabel, '-45m');
    });

    // A zero unit between two non-zero ones must not swallow the smaller: this
    // label is the only visible statement of how far the clock is from real
    // time, and understating it by up to an hour defeats the point.
    test('keeps a smaller unit across a zero one', () {
      AppClock.instance.travel(delta: const Duration(days: 1, minutes: 45));
      expect(AppClock.instance.travelLabel, '+1d 45m');
    });

    test('omits a 1x factor', () {
      AppClock.instance.travel(delta: const Duration(hours: 1));
      expect(AppClock.instance.travelLabel, '+1h');
    });

    test('reports a factor with no offset', () {
      AppClock.instance.travel(speed: 4);
      expect(AppClock.instance.travelLabel, 'at 4x');
    });

    // Built from the CONFIGURED offset, not the live one. Under a factor the
    // live offset grows every second, so a label built from it is stale the
    // moment it is written: a status-bar item posted once would sit at
    // "+0s at 1000x" for a whole session while the clock ran days ahead, and a
    // settings row rebuilding on its own schedule would contradict it.
    test('does not drift under a speed factor', () async {
      AppClock.instance.travel(speed: AppClock.maxSpeed);
      final first = AppClock.instance.travelLabel;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(AppClock.instance.offset, greaterThan(const Duration(seconds: 5)), reason: 'sanity: the clock really did move a long way');
      expect(AppClock.instance.travelLabel, first);
    });

    // What the status-bar item shows: the offset it has actually reached, which
    // for a speed-only hop is the only interesting number about it.
    test('liveTravelLabel reports the offset the clock has reached', () async {
      AppClock.instance.travel(speed: AppClock.maxSpeed);
      expect(AppClock.instance.liveTravelLabel, 'at 1000x', reason: 'no offset yet in the first moment');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final label = AppClock.instance.liveTravelLabel!;
      expect(label, endsWith('at 1000x'));
      expect(label, startsWith('+'), reason: 'and by now it has travelled a measurable distance');
      expect(AppClock.instance.travelLabel, 'at 1000x', reason: 'the configured label stays put; only the live one moves');
    });

    test('liveTravelLabel names both the offset and the factor', () {
      AppClock.instance.travel(delta: const Duration(days: 2), speed: 3);
      expect(AppClock.instance.liveTravelLabel, startsWith('+2d'));
      expect(AppClock.instance.liveTravelLabel, endsWith('at 3x'));
    });

    test('liveTravelLabel omits a 1x factor and is null on real time', () {
      AppClock.instance.travel(delta: const Duration(hours: 5));
      expect(AppClock.instance.liveTravelLabel, '+5h');
      AppClock.instance.reset();
      expect(AppClock.instance.liveTravelLabel, isNull);
    });

    test('anchoredOffset is what was set; offset is where it has got to', () async {
      AppClock.instance.travel(delta: const Duration(hours: 1), speed: AppClock.maxSpeed);
      expect(AppClock.instance.anchoredOffset.inMinutes, closeTo(60, 1));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(AppClock.instance.anchoredOffset.inMinutes, closeTo(60, 1));
      expect(AppClock.instance.offset, greaterThan(const Duration(hours: 1)));
    });
  });

  group('listeners', () {
    // What makes the UI repaint and the extension sandbox get re-pushed the
    // moment travel changes, instead of at whatever tick comes next.
    test('fire on travel and on reset', () {
      var calls = 0;
      void listener() => calls++;
      AppClock.instance.addListener(listener);
      addTearDown(() => AppClock.instance.removeListener(listener));

      AppClock.instance.travel(delta: const Duration(hours: 1));
      expect(calls, 1);
      AppClock.instance.travel(speed: 2);
      expect(calls, 2);
      AppClock.instance.reset();
      expect(calls, 3);
    });

    test('a redundant reset fires nothing', () {
      var calls = 0;
      void listener() => calls++;
      AppClock.instance.addListener(listener);
      addTearDown(() => AppClock.instance.removeListener(listener));

      AppClock.instance.reset();
      expect(calls, 0, reason: 'already on real time — nothing changed to notify about');
    });

    // The contract the DEVTT action's error handling is built on: travel is
    // applied, then EVERY listener is told, and only then does the failure
    // surface — as its own type, so a caller can tell "the clock did not move"
    // from "the clock moved and something did not hear about it".
    test('one throwing listener does not stop the others', () {
      final heard = <String>[];
      void first() {
        heard.add('first');
        throw StateError('the sandbox push failed');
      }

      void second() => heard.add('second');
      AppClock.instance.addListener(first);
      AppClock.instance.addListener(second);
      addTearDown(() {
        AppClock.instance.removeListener(first);
        AppClock.instance.removeListener(second);
      });

      expect(() => AppClock.instance.travel(delta: const Duration(hours: 1)), throwsA(isA<ClockListenerException>()));
      expect(heard, ['first', 'second'], reason: 'a failure must not strand the listeners after it');
      // And the travel itself stands — the anchors moved before anyone was told.
      expect(AppClock.instance.isTravelling, isTrue);
      expect(AppClock.instance.offset.inMinutes, closeTo(60, 1));
    });

    test('the failure it raises carries the listener\'s own error', () {
      void boom() => throw StateError('nope');
      AppClock.instance.addListener(boom);
      addTearDown(() => AppClock.instance.removeListener(boom));

      try {
        AppClock.instance.travel(speed: 2);
        fail('should have thrown');
      } on ClockListenerException catch (e) {
        expect(e.cause, isA<StateError>());
      }
    });

    // An ArgumentError from a LISTENER must not look like a rejected argument:
    // the DEVTT action reports the first as "the clock moved, but…" and the
    // second as "refused", and telling the operator nothing happened when the
    // clock did move is the one wrong answer.
    test('a listener\'s ArgumentError is not mistaken for a refusal', () {
      void picky() => throw ArgumentError('from a listener');
      AppClock.instance.addListener(picky);
      addTearDown(() => AppClock.instance.removeListener(picky));

      expect(() => AppClock.instance.travel(delta: const Duration(hours: 1)), throwsA(isA<ClockListenerException>()));
      expect(AppClock.instance.isTravelling, isTrue, reason: 'it was applied, not refused');
    });

    test('a removed listener stops hearing', () {
      var calls = 0;
      void listener() => calls++;
      AppClock.instance.addListener(listener);
      AppClock.instance.removeListener(listener);
      AppClock.instance.travel(delta: const Duration(hours: 1));
      expect(calls, 0);
    });
  });

  group('sandbox anchors', () {
    // The extension sandbox reproduces the clock from these three numbers
    // rather than from an offset, which would already be stale by the time the
    // message arrived (and, under a factor, keep drifting).
    test('are zero while untravelled', () {
      expect(AppClock.instance.anchorRealMillis, 0);
      expect(AppClock.instance.anchorVirtualMillis, 0);
    });

    test('describe the same clock the Dart side reads', () {
      AppClock.instance.travel(delta: const Duration(hours: 6), speed: 2);
      final clock = AppClock.instance;
      final real = realNow().millisecondsSinceEpoch;
      // The kernel's formula, applied to what the kernel is told.
      final asSandboxSeesIt = clock.anchorVirtualMillis + (real - clock.anchorRealMillis) * clock.speed;
      expect((asSandboxSeesIt - nowMillis()).abs(), lessThan(1000));
    });
  });
}

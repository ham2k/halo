// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Hand angles for the analog and Swiss faces.
//
// The Swiss sweep is the part with a contract rather than a preference: the
// second hand reaches 12 EARLY and waits there. A hand that instead glides
// smoothly through the whole minute is a plausible-looking clock that is not
// the one being replicated, and nothing about it looks broken.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/operation/clock/clock_math.dart';

void main() {
  group('swissSecondAngle', () {
    test('sweeps the dial in 58.5 seconds, not 60', () {
      expect(swissSecondAngle(0), 0);
      expect(swissSecondAngle(swissSweepMillis ~/ 2), closeTo(180, 0.001));
      expect(swissSecondAngle(swissSweepMillis), 360);
      // The mutation this exists for: dividing by 60000. Every assertion
      // above still passes at the endpoints under that change if the constant
      // moves with it, so the discriminating case is a point in between —
      // 30000ms is past halfway on a 58.5s sweep and exactly halfway on a 60s
      // one.
      expect(swissSecondAngle(30000), greaterThan(180));
      expect(swissSecondAngle(30000), closeTo(184.615, 0.001));
    });

    test('waits at 12 for the rest of the minute', () {
      // Not `closeTo`: the hand is MOTIONLESS, and a tolerance would accept a
      // slow creep through the pause — which is exactly what dropping the
      // clamp produces.
      expect(swissSecondAngle(swissSweepMillis + 1), 360);
      expect(swissSecondAngle(58600), swissSecondAngle(59900));
      expect(swissSecondAngle(59999), 360);
    });

    test('never runs past 12', () {
      // A `%` in place of the clamp wraps 59999ms round to ~9°, putting the
      // hand just past 12 at the very moment it should be still.
      for (var ms = 0; ms < 60000; ms += 137) {
        expect(swissSecondAngle(ms), inInclusiveRange(0, 360), reason: 'at ${ms}ms');
      }
    });
  });

  group('swissMinuteAngle', () {
    test('rests on the mark for all but the first fifth of a second', () {
      expect(swissMinuteAngle(15, 200), 90);
      expect(swissMinuteAngle(15, 5000), 90);
      expect(swissMinuteAngle(15, 59999), 90);
      expect(swissMinuteAngle(0, 30000), 0);
    });

    test('starts the step at the previous mark', () {
      // The impulse arrives WITH the rollover; the hand has not moved yet.
      // Snapping instantly instead would lose the step that distinguishes
      // this face from the analog one.
      expect(swissMinuteAngle(15, 0), closeTo(84, 0.001));
    });

    test('overshoots the mark before settling on it', () {
      // The `y > 1` control point in the cubic. Replacing it with a linear or
      // ease curve leaves a step that is technically correct and visibly
      // wrong — the real hand bounces.
      var maxAngle = 0.0;
      for (var ms = 0; ms <= 200; ms++) {
        maxAngle = maxAngle > swissMinuteAngle(15, ms) ? maxAngle : swissMinuteAngle(15, ms);
      }
      expect(maxAngle, greaterThan(90));
    });

    test('wraps at the top of the hour', () {
      expect(swissMinuteAngle(60, 1000), 0);
      expect(swissMinuteAngle(59, 1000), 354);
    });
  });

  group('analogHandAngles', () {
    test('places the hands for a readable time', () {
      final at0930 = analogHandAngles(DateTime.utc(2026, 8, 8, 9, 30));
      // 285, not 270: the hour hand is HALFWAY between 9 and 10 at half past.
      // Dropping the minute term leaves a clock that is only right on the
      // hour, which is the state most people would not notice.
      expect(at0930.hour, closeTo(285, 0.001));
      expect(at0930.minute, closeTo(180, 0.001));
      expect(at0930.second, 0);
    });

    test('folds 24 hours onto the dial', () {
      expect(analogHandAngles(DateTime.utc(2026, 8, 8, 15)).hour, closeTo(90, 0.001));
      // Both ends of the fold: noon and midnight are 0, not 360.
      expect(analogHandAngles(DateTime.utc(2026, 8, 8, 12)).hour, 0);
      expect(analogHandAngles(DateTime.utc(2026, 8, 8)).hour, 0);
    });

    test('creeps the minute hand with the seconds', () {
      // A minute hand that only moves once a minute is the Swiss face's
      // behaviour; leaking it here makes the two faces identical.
      final at30s = analogHandAngles(DateTime.utc(2026, 8, 8, 0, 0, 30));
      expect(at30s.minute, closeTo(3, 0.001));
      expect(at30s.second, closeTo(180, 0.001));
      expect(at30s.hour, closeTo(0.25, 0.001));
    });
  });

  group('clock sizing', () {
    test('refuses a dial too small to resolve its marks', () {
      expect(clockDiameterFor(const Size(60, 60)), isNull);
      expect(clockDiameterFor(const Size(400, 60)), isNull);
      expect(clockDiameterFor(const Size(120, 200)), 120);
    });

    test('caps a dial rather than filling a whole window with one', () {
      expect(clockDiameterFor(const Size(2000, 2000)), maxClockDiameter);
    });

    test('drops a round face to text only when it cannot be drawn', () {
      expect(clockFormFor(const Size(200, 200), round: true, showSeconds: true), ClockForm.full);
      expect(clockFormFor(const Size(200, 40), round: true, showSeconds: true), ClockForm.compact);
    });

    test('drops seconds before it drops the face', () {
      // The order matters: a narrow pane should lose the seconds digits and
      // keep being a clock, rather than collapsing straight to plain text.
      expect(clockFormFor(const Size(220, 90), round: false, showSeconds: true), ClockForm.full);
      expect(clockFormFor(const Size(140, 90), round: false, showSeconds: true), ClockForm.short);
      expect(clockFormFor(const Size(140, 90), round: false, showSeconds: false), ClockForm.short);
      expect(clockFormFor(const Size(60, 90), round: false, showSeconds: false), ClockForm.compact);
    });
  });
}

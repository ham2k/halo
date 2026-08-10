// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Hand angles for the analog face.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/operation/clock/clock_math.dart';

void main() {
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

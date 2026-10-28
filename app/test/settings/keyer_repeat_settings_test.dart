// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Message 1's repeat as stored: a switch, and the cooldown before it goes
// again (keyer_repeat_settings.dart).

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/settings_service.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A stored delay with no switch beside it reads as both: 0 is off, any
  // other a repeat. Read as off instead, an operator's CQ quietly stops
  // repeating.
  test('a delay stored before the switch is the switch: any delay repeats, and 0 does not', () async {
    final settings = (await makeHaLoServices(prefs: {'settings.radio': '{"cwRepeatDelay":"7","voiceRepeatDelay":"0"}'})).settings;
    expect(settings.cwRepeat, isTrue);
    expect(settings.cwRepeatDelay, const Duration(seconds: 7));
    expect(settings.voiceRepeat, isFalse);
    expect(settings.voiceRepeatDelay, Duration.zero);
    expect(settings.voiceRepeatCooldown, const Duration(seconds: 5), reason: 'a 0 is no cooldown to keep');
  });

  test('turning the repeat off keeps the cooldown for when it is turned on again', () async {
    final settings = (await makeHaLoServices()).settings;
    await settings.setCwRepeatCooldown(3);
    await settings.setCwRepeat(true);
    expect(settings.cwRepeatDelay, const Duration(seconds: 3));

    await settings.setCwRepeat(false);
    expect(settings.cwRepeatDelay, Duration.zero, reason: 'what the keyer reads: no repeat');
    expect(settings.cwRepeatCooldown, const Duration(seconds: 3));
    await settings.setCwRepeat(true);
    expect(settings.cwRepeatDelay, const Duration(seconds: 3));
  });
}

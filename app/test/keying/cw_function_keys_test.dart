// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/cw_function_keys.dart';

void main() {
  test('F1-F8 name messages 1-8, in order', () {
    expect(cwMessageIndexForKey(LogicalKeyboardKey.f1), 1);
    expect(cwMessageIndexForKey(LogicalKeyboardKey.f8), 8);
    expect(SettingsService.cwMessageCount, 8, reason: 'the settings and the keys must agree on how many');
  });

  test('keys past the message count, and every other key, are nobody\'s', () {
    // F9 must fall through to whatever else wants it, not index past the
    // settings a message would be read from.
    expect(cwMessageIndexForKey(LogicalKeyboardKey.f9), isNull);
    expect(cwMessageIndexForKey(LogicalKeyboardKey.digit1), isNull);
    expect(cwMessageIndexForKey(LogicalKeyboardKey.escape), isNull);
  });

  test('⌥1-⌥8\'s digits name messages 1-8, and no other key does', () {
    expect(cwMessageIndexForDigit(PhysicalKeyboardKey.digit1), 1);
    expect(cwMessageIndexForDigit(PhysicalKeyboardKey.digit8), 8);
    expect(cwMessageIndexForDigit(PhysicalKeyboardKey.digit9), isNull);
    expect(cwMessageIndexForDigit(PhysicalKeyboardKey.digit0), isNull);
    expect(cwMessageIndexForDigit(PhysicalKeyboardKey.f1), isNull);
  });
}

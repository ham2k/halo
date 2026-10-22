// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/services/settings_service.dart';

void main() {
  // A message with no command can never be keyed from the keyboard, and a
  // command past the last message would read a setting that is not there.
  test('every CW message has a key command, and no command has no message', () {
    expect(keyerMessageKeyCount, SettingsService.cwMessageCount);
    for (var n = 1; n <= SettingsService.cwMessageCount; n++) {
      expect(keyCommandSpec('keyer.message$n'), isNotNull, reason: 'message $n');
    }
    expect(keyCommandSpec('keyer.message${SettingsService.cwMessageCount + 1}'), isNull);
  });
}

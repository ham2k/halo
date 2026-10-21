// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Every transceiver driver takes an extension's raw commands
// (`host.sendRadioRaw`), through its own queue where it keeps one. A driver
// added without them answers every raw command as unsupported, which nothing
// shows while it is being written: this is where it is caught.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/placeholder_radio_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';

class _Sink implements EquipmentSink {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('every transceiver model that reaches a radio takes raw commands', () {
    final missing = <String>[];
    for (final model in EquipmentRegistry().models.where((m) => m.category == kCategoryTransceiver)) {
      for (final variant in model.variants) {
        // A placeholder has no wire to send anything down.
        if (variant.driver is PlaceholderRadioDriver) continue;
        final session = variant.driver.createSession(_Sink(), variant.defaultConfig);
        if (session is! RawCommandSession) missing.add('${variant.key} (${variant.driver.key})');
      }
    }
    expect(missing, isEmpty);
  });
}

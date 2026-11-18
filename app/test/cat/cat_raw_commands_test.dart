// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Every transceiver driver takes an extension's raw commands
// (`host.sendRadioRaw`), through its own queue where it keeps one. A driver
// added without them answers every raw command as unsupported, which nothing
// shows while it is being written: this is where it is caught.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/echocat_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/placeholder_radio_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';

class _Sink implements EquipmentSink {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('every transceiver with a direct CAT command channel takes raw commands', () {
    final missing = <String>[];
    for (final model in EquipmentRegistry().models.where((m) => m.category == kCategoryTransceiver)) {
      for (final variant in model.variants) {
        // ECHOCAT controls whichever rig POTACAT has selected through
        // named operations. HaLo has no CAT protocol for that underlying rig.
        if (variant.driver is PlaceholderRadioDriver || variant.driver is EchocatDriver) continue;
        final session = variant.driver.createSession(_Sink(), variant.defaultConfig);
        if (session is! RawCommandSession) missing.add('${variant.key} (${variant.driver.key})');
      }
    }
    expect(missing, isEmpty);
  });
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A plain CW key: nothing to connect to, only a physical type worth
// recording. See type_only_equipment_driver.dart for the shape shared with
// antenna_driver.dart.

import 'package:halo_i18n/halo_i18n.dart';
import 'type_only_equipment_driver.dart';

/// ADIF's own MORSE_KEY_TYPE enumeration codes, stored as-is so a future
/// ADIF export needs no lookup table — only 'other' is not an ADIF code, and
/// an export that tracks it maps it to a freeform note instead.
const morseKeyTypeValues = ['SK', 'SS', 'BUG', 'FAB', 'SP', 'DP', 'CPU', 'other'];

class KeyDriver extends TypeOnlyEquipmentDriver {
  const KeyDriver();

  @override
  String get key => 'key';

  @override
  String get name => 'CW Key';

  @override
  bool get hardwareVerified => true;

  @override
  String get typeFieldKey => 'morseKeyType';

  @override
  List<String> get typeValues => morseKeyTypeValues;

  @override
  String get fieldLabel => t.settings.station.keyType;

  @override
  String get fieldRequiredError => t.settings.station.keyTypeRequired;

  @override
  String labelFor(String? value) {
    final types = t.settings.station.keyTypes;
    return switch (value) {
      'SK' => types.straight,
      'SS' => types.sideswiper,
      'BUG' => types.bug,
      'FAB' => types.fullyAutomatic,
      'SP' => types.singlePaddle,
      'DP' => types.dualPaddle,
      'CPU' => types.computerDriven,
      'other' => types.other,
      _ => '',
    };
  }
}

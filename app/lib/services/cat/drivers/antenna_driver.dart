// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A plain antenna: nothing to connect to, only a physical type worth
// recording. See type_only_equipment_driver.dart for the shape shared with
// key_driver.dart.

import 'package:halo_i18n/halo_i18n.dart';
import 'type_only_equipment_driver.dart';

/// Stable, not translated — an export or a future driver reads this value,
/// the operator only ever sees its label.
const antennaTypeValues = ['dipole', 'vertical', 'yagiBeam', 'loop', 'longWire', 'other'];

class AntennaDriver extends TypeOnlyEquipmentDriver {
  const AntennaDriver();

  @override
  String get key => 'antenna';

  @override
  String get name => 'Antenna';


  @override
  String get typeFieldKey => 'antennaType';

  @override
  List<String> get typeValues => antennaTypeValues;

  @override
  String get fieldLabel => t.settings.station.antennaType;

  @override
  String get fieldRequiredError => t.settings.station.antennaTypeRequired;

  @override
  String labelFor(String? value) {
    final types = t.settings.station.antennaTypes;
    return switch (value) {
      'dipole' => types.dipole,
      'vertical' => types.vertical,
      'yagiBeam' => types.yagiBeam,
      'loop' => types.loop,
      'longWire' => types.longWire,
      'other' => types.other,
      _ => '',
    };
  }
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Shared shape for an equipment category with nothing to connect to and
// only a single "what kind" field — antenna and CW key today. See
// antenna_driver.dart/key_driver.dart for what varies between them.

import '../driver.dart';

abstract class TypeOnlyEquipmentDriver extends EquipmentDriver {
  const TypeOnlyEquipmentDriver();

  /// The config field's key, e.g. `antennaType`.
  String get typeFieldKey;

  /// The field's allowed values, in the vocabulary's own preferred order.
  List<String> get typeValues;

  String get fieldLabel;
  String get fieldRequiredError;
  String labelFor(String? value);

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) =>
      throw UnsupportedError('$key has no session to create — nothing calls connect on it');

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
    {
      'type': 'field',
      'fieldType': 'select',
      'key': typeFieldKey,
      'label': fieldLabel,
      'options': [
        for (final value in typeValues) {'value': value, 'label': labelFor(value)},
      ],
    },
  ];

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) {
    if (key != typeFieldKey) return null;
    return typeValues.contains(value) ? null : fieldRequiredError;
  }

  /// The row's whole subtitle, not a suffix after a transport address — this
  /// pairing's transport target is always empty, so unlike every other
  /// driver's [describeSuffix] this carries no leading separator.
  @override
  String? describeSuffix(Map<String, dynamic> config, {Map<String, dynamic> overrides = const {}}) =>
      labelFor((overrides[typeFieldKey] ?? config[typeFieldKey]) as String?);
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The developer-mode fields through which a GENERIC catalogue entry learns
// what the named ones pin: whether the radio's CAT keys CW, and how many
// voice memories it holds. Shared by the Icom and Yaesu drivers (the
// Kenwood driver asks for dialects instead, and reuses the count field).
// Under developer mode only: an operator on a named entry never sees
// these, and one on a generic entry is told by the entry's own notes
// that the app does not know their radio.

import '../../../i18n/strings.g.dart';
import '../driver.dart';

/// The CW keyer checkbox and the voice memory count, each skipped when
/// [overrides] pins it.
List<Map<String, dynamic>> keyerConfigElements(Map<String, dynamic> overrides) => [
      if (!overrides.containsKey(cwKeyerConfigKey))
        {
          'type': 'field',
          'fieldType': 'checkbox',
          'key': cwKeyerConfigKey,
          'label': t.settings.station.cwKeyerField,
          'description': t.settings.station.cwKeyerFieldDescription,
          'devMode': true,
        },
      if (!overrides.containsKey(voiceMemoriesConfigKey)) voiceMemoriesConfigElement(),
    ];

Map<String, dynamic> voiceMemoriesConfigElement() => {
      'type': 'field',
      'fieldType': 'number',
      'key': voiceMemoriesConfigKey,
      'label': t.settings.station.voiceMemories,
      'description': t.settings.station.voiceMemoriesDescription,
      'devMode': true,
    };

/// Blank or a whole number from zero to [maxVoiceMemories]; anything else is
/// refused with the field's own words.
String? validateVoiceMemories(dynamic value) {
  if (value == null || (value is String && value.trim().isEmpty)) return null;
  final n = value is num ? value : num.tryParse('$value');
  return (n != null && n >= 0 && n <= maxVoiceMemories && n == n.roundToDouble())
      ? null
      : t.settings.station.voiceMemoriesInvalid;
}

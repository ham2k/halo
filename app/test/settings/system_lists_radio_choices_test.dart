// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `$core.radioChoices`: what a pane's form picks the radio it shows by.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/settings/system_lists.dart';

void main() {
  SystemLists lists({required bool so2r}) => SystemLists()
    ..so2r = (() => so2r)
    ..equipment = (kind) => [
      if (kind == 'radio') ...[
        {'label': 'FT-891', 'value': 'ft891'},
        {'label': 'Shack Flex', 'value': 'flex'},
      ],
    ];

  List<(String, String)> choices(List<Map<String, dynamic>>? options) => [for (final o in options!) (o['label'] as String, o['value'] as String)];

  // Offered outside SO2R, set B's radio is a pane showing nothing.
  test('outside SO2R, the radio being logged on, then each radio of the station', () async {
    expect(choices(await lists(so2r: false).resolve(r'$core.radioChoices')), [('Current Radio', 'A'), ('FT-891', 'ft891'), ('Shack Flex', 'flex')]);
  });

  test("under SO2R, each position's radio, then each radio of the station", () async {
    expect(choices(await lists(so2r: true).resolve(r'$core.radioChoices')), [
      ('Radio for Position A', 'A'),
      ('Radio for Position B', 'B'),
      ('FT-891', 'ft891'),
      ('Shack Flex', 'flex'),
    ]);
  });
}

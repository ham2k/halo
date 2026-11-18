// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A panel's own form as its settings dialog and Layout Setup both show it
// (`panelFormElements`).

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/settings/system_lists.dart';
import 'package:ham2k_logger/views/operation/panel_settings.dart';

void main() {
  final lists = SystemLists()
    ..equipment = (kind) => [
      if (kind == 'radio') {'label': 'FT-891', 'value': 'ft891'},
    ];
  const panel = PanelDefinition(
    id: 'scope',
    title: 'Band Scope',
    source: PanelSource.extension,
    formFields: [
      {'type': 'field', 'fieldType': 'select', 'key': 'radio', 'label': 'Radio', 'value': 'A', 'options': r'$core.radioChoices'},
      {'type': 'action', 'key': 'pick', 'label': 'Pick'},
    ],
  );

  // Handed on by name, a select holds a string where its options go, and the
  // form throws as it builds: the pane's settings never open.
  test("a panel's form names the station's radios in its system list, not the list's name", () async {
    final [radio, _] = await panelFormElements(lists, panel);
    expect(radio['options'], [
      {'label': 'Current Radio', 'value': 'A'},
      {'label': 'FT-891', 'value': 'ft891'},
    ]);
  });

  // Layout Setup has no route of its own for an action to close on.
  test('embedded in Layout Setup, it leaves out its action buttons', () async {
    expect([for (final field in await panelFormElements(lists, panel, embedded: true)) field['key']], ['radio']);
  });
}

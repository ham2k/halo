// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An extension reaches the Developer panel by tagging a settings field
// `target: 'developer'` (docs/extensions/settings.md, "Settings targets").
// The traps: the section embedded as slivers must still commit through the
// extension's own route, not just draw the row; its band must not appear
// while nothing targets it; and the panel declared only to carry such a
// field — every row `devMode` — must not leave an empty heading in the
// Settings list for an operator who is not a developer.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/views/settings/developer_panel.dart';
import 'package:ham2k_logger/views/settings/extension_settings_panel.dart';

import '../support/halo_test_support.dart';

Map<String, dynamic> _panelEntry(String panelKey) => {
  'key': panelKey,
  'ok': true,
  'value': {'panelKey': panelKey, 'hookKey': panelKey, 'extensionKey': panelKey, 'title': panelKey, 'kind': 'simple', 'order': 0, 'sidebar': false},
};

Map<String, dynamic> _devServersPanel({Object? target = 'developer'}) => {
  'settingsPanel:*:getPanels': [_panelEntry('pota')],
  'settingsPanel:pota:getDefinition': {
    'title': 'POTA',
    'elements': [
      {'type': 'field', 'fieldType': 'checkbox', 'key': 'useDevServers', 'label': 'Use POTA Dev Servers', 'value': false, 'devMode': true, 'target': ?target},
    ],
  },
};

Future<HaLoServices> _services(Map<String, dynamic> hooks, {required bool developerMode}) async {
  final services = (await makeHaLoServices(extensions: ExtensionServiceWithFakeHost(FakeExtensionHost(hooks)))).services;
  await services.settings.setDeveloperMode(developerMode);
  return services;
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the Developer panel', () {
    testWidgets("lists an extension's developer field, and the field commits to the extension's own storage", (tester) async {
      final services = await _services(_devServersPanel(), developerMode: true);
      await _pump(tester, DeveloperPanel(services: services));

      final row = find.widgetWithText(ListTile, 'Use POTA Dev Servers');
      await tester.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text('Extension Settings'), findsOneWidget);

      await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(services.settings.prefs.getString('settingsPanel.pota.useDevServers'), 'true');
    });

    // The section stays open, unlike the dialogs the same form serves, so a
    // value committed from the field's home panel must reach it.
    testWidgets('follows a value committed from elsewhere', (tester) async {
      final services = await _services(_devServersPanel(), developerMode: true);
      await _pump(tester, DeveloperPanel(services: services));
      final toggle = find.descendant(of: find.widgetWithText(ListTile, 'Use POTA Dev Servers'), matching: find.byType(Switch));
      await tester.scrollUntilVisible(toggle, 200, scrollable: find.byType(Scrollable).first);
      expect(tester.widget<Switch>(toggle).value, isFalse);

      await services.extensions.commitSettingsFieldValue(
        kind: 'simple',
        hookKey: 'pota',
        panelKey: 'pota',
        fieldKey: 'useDevServers',
        value: true,
        state: const {},
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(toggle).value, isTrue);
    });

    testWidgets('shows no Extension Settings band while no field targets it', (tester) async {
      final services = await _services(_devServersPanel(target: null), developerMode: true);
      await _pump(tester, DeveloperPanel(services: services));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(find.text('Extension Settings'), findsNothing);
    });
  });

  group('a panel whose every field is devMode', () {
    Future<void> pumpCategory(WidgetTester tester, HaLoServices services) => _pump(
      tester,
      ExtensionSettingsPanel(services: services, descriptor: _panelEntry('pota')['value'] as Map<String, dynamic>, embedded: true, sectionTitle: 'POTA'),
    );

    testWidgets('leaves no heading in the Settings list outside developer mode', (tester) async {
      await pumpCategory(tester, await _services(_devServersPanel(), developerMode: false));
      expect(find.text('POTA'), findsNothing);
    });

    testWidgets('is listed, field and all, in developer mode', (tester) async {
      await pumpCategory(tester, await _services(_devServersPanel(), developerMode: true));
      expect(find.text('POTA'), findsOneWidget);
      expect(find.text('Use POTA Dev Servers'), findsOneWidget);
    });
  });
}

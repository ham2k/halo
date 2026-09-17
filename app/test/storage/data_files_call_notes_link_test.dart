// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// HALO-53: the data sources' "Extensions" section shows a row per
// registered settingsPanel that explicitly opted INTO it (`dataFilesSection:
// true`) — NOT every panel that merely opted out of the top-level sidebar
// (`sidebar: false`). The two are independent settings; conflating them was
// itself a HALO-53 code review finding — a sidebar:false panel for some
// unrelated reason used to get swept in here too. The section is absent
// entirely when nothing qualifies, and tapping a row opens that extension's
// own settings panel.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/settings_view.dart';

import '../support/halo_test_support.dart';

Map<String, dynamic> _panelEntry({
  required String panelKey,
  required String title,
  bool sidebar = true,
  bool dataFilesSection = false,
}) =>
    {
      'key': panelKey,
      'ok': true,
      'value': {
        'panelKey': panelKey,
        'hookKey': panelKey,
        'extensionKey': panelKey,
        'title': title,
        'kind': 'dynamic',
        'order': 0,
        'sidebar': sidebar,
        'dataFilesSection': dataFilesSection,
      },
    };

Future<HaLoServices> _pumpDataFiles(WidgetTester tester, {required List<Map<String, dynamic>> panels}) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService(await SharedPreferences.getInstance());
  final db = HaLoDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final mockHost = FakeExtensionHost({
    'dataFile:*:getDefinition': [
      {
        'key': 'hams-of-note',
        'ok': true,
        'value': {'key': 'hams-of-note', 'name': "Ham2K's Hams of Note", 'category': 'call-notes'},
      },
    ],
    if (panels.isNotEmpty) 'settingsPanel:*:getPanels': panels,
    'settingsPanel:call-notes:getDefinition': {
      'title': 'Callsign Notes',
      'elements': [
        {'type': 'field', 'fieldType': 'checkbox', 'key': 'enabled.hams-of-note', 'label': "Ham2K's Hams of Note", 'value': true},
      ],
    },
    'settingsPanel:radio-commands:getDefinition': {
      'title': 'Radio Commands',
      'elements': [
        {'type': 'field', 'fieldType': 'checkbox', 'key': 'someToggle', 'label': 'Some Toggle', 'value': false},
      ],
    },
  });
  final extensions = ExtensionServiceWithFakeHost(mockHost)..settings = settings;
  final services = HaLoServices(db, settings, extensions: extensions);

  await tester.pumpWidget(TranslationProvider(
    child: MaterialApp(home: SettingsView(services: services, initialPanel: 'accounts')),
  ));
  await tester.pumpAndSettle();
  return services;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dataFilesSection: true keeps a panel out of the top-level nav and shows it under the data sources instead',
      (tester) async {
    await _pumpDataFiles(tester, panels: [
      _panelEntry(panelKey: 'call-notes', title: 'Callsign Notes', sidebar: false, dataFilesSection: true),
      _panelEntry(panelKey: 'radio-commands', title: 'Radio Commands'), // sidebar: true, the default
    ]);

    expect(find.text(t.settings.offlineData.extensionsSection), findsOneWidget);
    // call-notes (sidebar: false, dataFilesSection: true): only the data
    // sources row — no sidebar entry, since it's reached from here instead.
    expect(find.text('Callsign Notes'), findsOneWidget);
    // radio-commands (sidebar: true, the default; dataFilesSection: false):
    // only its own sidebar entry — NOT also duplicated under the data sources'
    // Extensions section.
    expect(find.text('Radio Commands'), findsOneWidget,
        reason: 'a sidebar:true panel already has its own nav entry; the data sources must not list it a second time');
  });

  testWidgets(
      'sidebar: false alone does NOT show a panel under the data sources — dataFilesSection must be set explicitly', (tester) async {
    // The regression this fix closed: a panel opting out of the sidebar for
    // some reason unrelated to data files (radio-commands is a stand-in for
    // one) used to be swept into the data sources anyway, just because
    // it shared `sidebar: false` with call-notes.
    await _pumpDataFiles(tester, panels: [
      _panelEntry(panelKey: 'radio-commands', title: 'Radio Commands', sidebar: false),
    ]);
    expect(find.text(t.settings.offlineData.extensionsSection), findsNothing,
        reason: 'sidebar: false without dataFilesSection: true must not appear here');
    expect(find.text('Radio Commands'), findsNothing, reason: 'nor anywhere else on this screen');
  });

  testWidgets('hides the "Extensions" section entirely when nothing qualifies', (tester) async {
    await _pumpDataFiles(tester, panels: []);
    expect(find.text(t.settings.offlineData.extensionsSection), findsNothing);
  });

  testWidgets('hides the "Extensions" section when nothing has dataFilesSection: true', (tester) async {
    await _pumpDataFiles(tester, panels: [
      _panelEntry(panelKey: 'radio-commands', title: 'Radio Commands'),
    ]);
    expect(find.text(t.settings.offlineData.extensionsSection), findsNothing,
        reason: 'nothing here opted into the data sources section, so there is nothing left for it to show');
  });

  testWidgets('tapping a data sources row opens that extension\'s own settings panel', (tester) async {
    await _pumpDataFiles(tester, panels: [
      _panelEntry(panelKey: 'call-notes', title: 'Callsign Notes', sidebar: false, dataFilesSection: true),
      _panelEntry(panelKey: 'radio-commands', title: 'Radio Commands', sidebar: false, dataFilesSection: true),
    ]);

    final row = find.text('Radio Commands');
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.text('Some Toggle'), findsOneWidget, reason: "radio-commands' own panel rendered, showing its field — not call-notes'");
  });
}

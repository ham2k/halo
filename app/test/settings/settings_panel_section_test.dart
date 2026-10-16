// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An extension settings panel that names one of the app's sections as its
// `section` is a single row inside that section, opening the panel in a
// pane — not a category and a sidebar entry of its own. One naming a section
// this build does not have is shown as if it named none, since that is all
// an app predating `section` can do with it either way.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/spotting_settings.dart';
import 'package:ham2k_logger/views/settings_view.dart';

import '../support/halo_test_support.dart';

Map<String, dynamic> _panelEntry({required String panelKey, required String title, String? section}) => {
  'key': panelKey,
  'ok': true,
  'value': {
    'panelKey': panelKey,
    'hookKey': panelKey,
    'extensionKey': panelKey,
    'title': title,
    'icon': 'forum',
    'kind': 'dynamic',
    'order': 0,
    'sidebar': true,
    'dataFilesSection': false,
    'section': section,
  },
};

Future<void> _pumpSettings(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // The Spotting category open, as the operator last left it.
  SharedPreferences.setMockInitialValues({'settingsOpenCategory': 'group:${SpottingSettings.group}'});
  final settings = SettingsService(await SharedPreferences.getInstance());
  final db = HaLoDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final host = FakeExtensionHost({
    'settingsPanel:*:getPanels': [
      _panelEntry(panelKey: 'discord', title: 'Discord Spotting', section: SpottingSettings.group),
      _panelEntry(panelKey: 'future', title: 'Future Panel', section: 'no-such-section'),
    ],
    'settingsPanel:discord:getDefinition': {
      'elements': [
        {'type': 'field', 'fieldType': 'text', 'key': 'channelName', 'label': 'Channel name', 'value': ''},
      ],
    },
    'settingsPanel:future:getDefinition': {
      'elements': [
        {'type': 'field', 'fieldType': 'text', 'key': 'something', 'label': 'Something', 'value': ''},
      ],
    },
  });
  final extensions = ExtensionServiceWithFakeHost(host)..settings = settings;
  final services = HaLoServices(db, settings, extensions: extensions);

  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: SettingsView(services: services, initialPanel: 'settings'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Collapsed categories stay mounted, so only what is hit-testable is
  // actually on screen.
  testWidgets('a panel placed in Spotting is one row there, and nowhere else', (tester) async {
    await _pumpSettings(tester);

    expect(find.text(t.settings.spotting.respotInterval).hitTestable(), findsOneWidget, reason: 'the Spotting category is open');
    expect(
      find.text('Discord Spotting').hitTestable(),
      findsOneWidget,
      reason: 'the row in Spotting — with no sidebar entry and no category of its own beside it',
    );
    expect(find.text('Channel name').hitTestable(), findsNothing, reason: "the panel's fields wait behind the row");

    await tester.tap(find.text('Discord Spotting'));
    await tester.pumpAndSettle();
    expect(find.text('Channel name').hitTestable(), findsOneWidget, reason: 'the row opens the panel');
  });

  testWidgets('a panel naming a section this app does not have keeps its sidebar entry and its own category', (tester) async {
    await _pumpSettings(tester);

    // The sidebar row, and the category band in All settings.
    expect(find.text('Future Panel').hitTestable(), findsNWidgets(2));
  });
}

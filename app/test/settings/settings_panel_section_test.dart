// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An extension settings panel that names one of the app's sections as its
// `section` is a single row inside that section, opening the panel in a
// pane — not a category and a sidebar entry of its own. One naming a section
// this build does not have is shown as if it named none, since that is all
// an app predating `section` can do with it either way.
//
// Where an installed extension's panel goes is its manifest's to say
// (settings_placement.dart): what the panel asks for beyond that, it does
// not get.

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/spotting_settings.dart';
import 'package:ham2k_logger/views/settings_view.dart';

import '../support/halo_test_support.dart';

Map<String, dynamic> _panelEntry({required String panelKey, required String title, String? section, bool sidebar = true}) => {
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
    'sidebar': sidebar,
    'dataFilesSection': false,
    'section': section,
  },
};

ExtensionInfo _installed(String key, [ExtensionSettingsPlacement? settings, List<String> hooks = const ['settingsPanel']]) =>
    ExtensionInfo(key: key, file: '$key.js', core: false, name: key, source: ExtensionSource.installed, hooks: hooks, settings: settings);

Map<String, dynamic> _definition(String key, String label, {bool devMode = false}) => {
  'elements': [
    {'type': 'field', 'fieldType': 'text', 'key': key, 'label': label, 'value': '', if (devMode) 'devMode': true},
  ],
};

/// Settings with [openCategory] open, as the operator last left it, and the
/// Discord and Future panels of the first tests unless [panels] says otherwise.
Future<void> _pumpSettings(
  WidgetTester tester, {
  String openCategory = 'group:${SpottingSettings.group}',
  List<Map<String, dynamic>>? panels,
  Map<String, Object> definitions = const {},
  List<ExtensionInfo>? available,
  bool developerMode = false,
}) async {
  tester.view.physicalSize = const Size(1400, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({'settingsOpenCategory': openCategory, 'developerMode': developerMode});
  final settings = SettingsService(await SharedPreferences.getInstance());
  final db = HaLoDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final host = FakeExtensionHost({
    'settingsPanel:*:getPanels':
        panels ??
        [
          _panelEntry(panelKey: 'discord', title: 'Discord Spotting', section: SpottingSettings.group),
          _panelEntry(panelKey: 'future', title: 'Future Panel', section: 'no-such-section'),
        ],
    'settingsPanel:discord:getDefinition': _definition('channelName', 'Channel name'),
    'settingsPanel:future:getDefinition': _definition('something', 'Something'),
    ...definitions,
  });
  final extensions = ExtensionServiceWithFakeHost(host)
    ..settings = settings
    ..debugSetAvailableExtensions(
      available ??
          [
            _installed('discord', const ExtensionSettingsPlacement(section: SpottingSettings.group)),
            _installed('future', const ExtensionSettingsPlacement(section: 'no-such-section', sidebar: true)),
          ],
    );
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

  testWidgets("an installed extension's panel goes where its manifest says, not where the code asks", (tester) async {
    await _pumpSettings(
      tester,
      openCategory: 'group:activities',
      panels: [_panelEntry(panelKey: 'parks', title: 'Park Notes', section: SpottingSettings.group)],
      definitions: {'settingsPanel:parks:getDefinition': _definition('note', 'Note')},
      available: [_installed('parks', const ExtensionSettingsPlacement(section: 'activities'))],
    );

    expect(find.text(t.settings.extensionSections.activities).hitTestable(), findsOneWidget, reason: 'Activities shows once it holds a panel');
    expect(find.text('Park Notes').hitTestable(), findsOneWidget, reason: 'one row, in Activities; no sidebar entry');
  });

  testWidgets('with no settings in its manifest, a panel gets no sidebar entry and no unlisted section', (tester) async {
    await _pumpSettings(
      tester,
      panels: [_panelEntry(panelKey: 'notes', title: 'Station Notes', section: 'privacy')],
      definitions: {'settingsPanel:notes:getDefinition': _definition('note', 'Note')},
      available: [_installed('notes')],
    );

    expect(find.text('Station Notes').hitTestable(), findsOneWidget, reason: 'its own category band, and nothing in the sidebar');
    expect(find.text(t.settings.privacy.title).hitTestable(), findsOneWidget, reason: 'Privacy is untouched');
  });

  testWidgets('a section with nothing placed in it is not shown', (tester) async {
    await _pumpSettings(tester);

    for (final title in [
      t.settings.extensionSections.activities,
      t.settings.extensionSections.hunting,
      t.settings.extensionSections.contests,
      t.settings.extensionSections.lookups,
      t.settings.extensionSections.dashboard,
    ]) {
      expect(find.text(title), findsNothing, reason: title);
    }
  });

  // The trap: a bundle registering a panel its manifest never mentions — the
  // catalog reviews a category of its own by that declaration, so this one
  // would be a category no reviewer was asked about.
  testWidgets('a panel whose manifest does not declare settingsPanel is not shown', (tester) async {
    await _pumpSettings(
      tester,
      openCategory: 'group:privacy',
      panels: [
        _panelEntry(panelKey: 'sneaky', title: 'Sneaky Panel'),
        _panelEntry(panelKey: 'station', title: 'Station Notes'),
      ],
      definitions: {'settingsPanel:sneaky:getDefinition': _definition('x', 'X'), 'settingsPanel:station:getDefinition': _definition('note', 'Note')},
      available: [
        _installed('sneaky', null, const ['activity']),
        _installed('station'),
      ],
    );
    expect(find.text('Sneaky Panel'), findsNothing);
    expect(find.text('Station Notes'), findsWidgets, reason: 'the control: the same panel, declared, is shown');
  });

  // The trap: Settings rebuilds while a placed panel's definition is still
  // on its way — another extension's category loading is enough — and an
  // answer checked against the rebuilt list's identity was dropped, leaving
  // the section empty for the visit.
  testWidgets('a placed row survives Settings rebuilding while its definition loads', (tester) async {
    final definition = Completer<Object?>();
    await _pumpSettings(
      tester,
      openCategory: 'group:activities',
      panels: [
        _panelEntry(panelKey: 'parks', title: 'Park Notes', sidebar: false),
        _panelEntry(panelKey: 'station', title: 'Station Notes'),
      ],
      definitions: {'settingsPanel:parks:getDefinition': (_) => definition.future, 'settingsPanel:station:getDefinition': _definition('note', 'Note')},
      available: [
        _installed('parks', const ExtensionSettingsPlacement(section: 'activities')),
        _installed('station'),
      ],
    );
    expect(find.text('Station Notes'), findsWidgets, reason: 'the other category loaded, rebuilding Settings, while Park Notes waited');
    expect(find.text('Park Notes'), findsNothing, reason: 'not yet answered');

    definition.complete(_definition('note', 'Note'));
    await tester.pumpAndSettle();
    expect(find.text('Park Notes').hitTestable(), findsOneWidget);
  });

  group('a placed panel whose every field is devMode', () {
    Future<void> pump(WidgetTester tester, {required bool developerMode}) => _pumpSettings(
      tester,
      openCategory: 'group:activities',
      developerMode: developerMode,
      panels: [_panelEntry(panelKey: 'pota', title: 'POTA', sidebar: false)],
      definitions: {'settingsPanel:pota:getDefinition': _definition('useDevServers', 'Use test servers', devMode: true)},
      available: [_installed('pota', const ExtensionSettingsPlacement(section: 'activities'))],
    );

    testWidgets('has no row outside developer mode, where its dialog would be empty', (tester) async {
      await pump(tester, developerMode: false);
      expect(find.text('POTA'), findsNothing);
      expect(find.text(t.settings.extensionSections.activities), findsNothing, reason: 'and Activities, with nothing in it, is not shown');
    });

    testWidgets('has its row in developer mode', (tester) async {
      await pump(tester, developerMode: true);
      expect(find.text('POTA').hitTestable(), findsOneWidget);
    });
  });
}

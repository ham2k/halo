// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The two registry-driven settings panels: Common Settings must show ONLY
// the whitelisted fields (commonSettingsFields) — the whole point of the
// panel is a short list — while All Settings must show every declared
// group (core + sync) plus each extension-contributed panel as its own
// section.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/settings_view.dart';

import 'operation_view_layout_test.dart' show MockExtensionHost, ExtensionServiceWithMockHost;

Future<HaLoServices> makeServices() async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService(await SharedPreferences.getInstance());
  final db = HaLoDatabase(NativeDatabase.memory());
  final extensions = ExtensionServiceWithMockHost(
    const MockExtensionHost({
      'settingsPanel:*:getPanels': [
        {
          'key': 'myext',
          'ok': true,
          'value': {
            'panelKey': 'myext',
            'hookKey': 'myext',
            'extensionKey': 'myext',
            'title': 'My Extension',
            'kind': 'dynamic',
            'order': 50,
          },
        },
      ],
      'settingsPanel:myext:getDefinition': {
        'title': 'My Extension',
        'elements': [
          {'type': 'field', 'fieldType': 'text', 'key': 'foo', 'label': 'Foo Field'},
        ],
      },
    }),
  )..settings = settings;
  return HaLoServices(db, settings, extensions: extensions);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Common Settings shows only the whitelisted fields', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final services = await makeServices();
    await tester.pumpWidget(MaterialApp(home: SettingsView(services: services)));
    await tester.pumpAndSettle();

    // Whitelisted: only the User Interface section.
    expect(find.text('User Interface'), findsOneWidget);
    expect(find.text('Theme Mode'), findsOneWidget);

    // Not whitelisted: privacy has its own panel; logging fields and the
    // sync toggle only appear under All Settings.
    expect(find.text('Share app usage data'), findsNothing);
    expect(find.text('Privacy Policy'), findsNothing);
    expect(find.text('Leftie Mode'), findsNothing);
    expect(find.text('Logging'), findsNothing);
    expect(find.text('Enable Sync'), findsNothing);

    // Privacy is a top-level sidebar panel with the consents and links.
    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();
    expect(find.text('Share app usage data'), findsOneWidget);
    expect(find.text('Share operation data'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
  });

  testWidgets('All Settings shows every group plus extension sections', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final services = await makeServices();
    await tester.pumpWidget(MaterialApp(home: SettingsView(services: services)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('All Settings'));
    await tester.pumpAndSettle();

    // Core groups, in registry order.
    expect(find.text('User Interface'), findsOneWidget);
    expect(find.text('Logging'), findsOneWidget);
    expect(find.text('Leftie Mode'), findsOneWidget);
    expect(find.text('Country Flags'), findsOneWidget);
    // 'Privacy' shows twice: the sidebar item and the group's section header.
    expect(find.text('Privacy'), findsNWidgets(2));
    expect(find.text('Enable Sync'), findsOneWidget);

    // Bands resolves its $core.bands system list and summarizes the
    // default selection.
    expect(find.textContaining('80m, 40m, 30m'), findsOneWidget);

    // The extension panel renders as its own section with its fields.
    expect(find.text('My Extension'), findsWidgets);
    expect(find.text('Foo Field'), findsOneWidget);

    // The search filters every section by key/title/description; sections
    // with no match vanish, headers included.
    final search = find.byKey(const ValueKey('all-settings-search'));
    expect(search, findsOneWidget);
    await tester.enterText(search, 'leftie');
    await tester.pumpAndSettle();
    expect(find.text('Leftie Mode'), findsOneWidget);
    expect(find.text('Logging'), findsOneWidget);
    expect(find.text('Theme Mode'), findsNothing);
    expect(find.text('User Interface'), findsNothing);
    expect(find.text('Foo Field'), findsNothing);
    // Only the sidebar's copy of the extension title remains.
    expect(find.text('My Extension'), findsOneWidget);

    // Matching an extension field brings its section (and title) back.
    await tester.enterText(search, 'foo');
    await tester.pumpAndSettle();
    expect(find.text('Foo Field'), findsOneWidget);
    expect(find.text('My Extension'), findsNWidgets(2), reason: 'sidebar + section title');
    expect(find.text('Leftie Mode'), findsNothing);

    // The X clears the filter.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Theme Mode'), findsOneWidget);
    expect(find.text('Leftie Mode'), findsOneWidget);
  });
}

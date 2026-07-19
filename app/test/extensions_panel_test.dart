// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Extension Management (Issue #25). The load-bearing rules: core extensions
// never appear in the panel; the rest group per category with the search
// field at the BOTTOM filtering by name/key/description; a toggle persists
// an override in the store that's kept OUTSIDE the app-settings groups; and
// enabled resolution is core || override ?? enabledByDefault.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/extensions_panel.dart';

import 'operation_view_layout_test.dart' show MockExtensionHost, ExtensionServiceWithMockHost;

const _testExtensions = [
  ExtensionInfo(key: 'adif', file: 'adif.js', core: true, name: 'ADIF Export'),
  ExtensionInfo(
      key: 'pota', file: 'pota.js', core: false, name: 'Parks on the Air', category: 'activity',
      description: 'Park references and spots'),
  ExtensionInfo(key: 'sota', file: 'sota.js', core: false, name: 'Summits on the Air', category: 'activity'),
  ExtensionInfo(
      key: 'qrz', file: 'qrz.js', core: false, name: 'QRZ.com Callsign Lookups', category: 'lookup',
      enabledByDefault: false),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('isExtensionEnabled: core always wins; overrides beat defaults', () async {
    SharedPreferences.setMockInitialValues({
      'extensionOverrides': '{"sota": false, "qrz": true}',
    });
    final settings = SettingsService(await SharedPreferences.getInstance());
    final extensions = ExtensionServiceWithMockHost(const MockExtensionHost({}))..settings = settings;

    bool enabled(String key) =>
        extensions.isExtensionEnabled(_testExtensions.firstWhere((e) => e.key == key));

    expect(enabled('adif'), isTrue, reason: 'core is always enabled');
    expect(enabled('pota'), isTrue, reason: 'no override → enabledByDefault true');
    expect(enabled('sota'), isFalse, reason: 'override false wins');
    expect(enabled('qrz'), isTrue, reason: 'override true beats enabledByDefault false');
  });

  test('disabling stamps disabledSince; re-enabling clears it', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    final extensions = ExtensionServiceWithMockHost(const MockExtensionHost({}))..settings = settings;
    extensions.debugSetAvailableExtensions(_testExtensions);
    HaLoServices(db, settings, extensions: extensions);

    await extensions.setExtensionsEnabled({'pota': false});
    expect(settings.extensionDisabledSince.keys, contains('pota'));
    // qrz defaults off → also stamped by the recompute.
    expect(settings.extensionDisabledSince.keys, contains('qrz'));

    await extensions.setExtensionsEnabled({'pota': true});
    expect(settings.extensionDisabledSince.keys, isNot(contains('pota')));
    await db.close();
  });

  test('ExtensionInfo.fromJson: a stale metadata-less index degrades to core', () {
    final info = ExtensionInfo.fromJson(const {'key': 'mystery', 'file': 'mystery.js'});
    expect(info.core, isTrue);
    expect(info.name, 'mystery');
    expect(info.enabledByDefault, isTrue);
  });

  test('listActiveExtensions surfaces the kernel-info listing', () async {
    final extensions = ExtensionServiceWithMockHost(const MockExtensionHost({
      'runtime:kernel:listExtensions': [
        {'key': 'pota', 'name': 'Parks on the Air', 'version': '0.0.1'},
      ],
    }));
    final listed = await extensions.listActiveExtensions();
    expect(listed.single['key'], 'pota');
    expect(listed.single['version'], '0.0.1');
  });

  testWidgets('panel hides core, groups per category, searches from the top field, and toggles persist',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    final extensions = ExtensionServiceWithMockHost(const MockExtensionHost({}))..settings = settings;
    extensions.debugSetAvailableExtensions(_testExtensions);
    final services = HaLoServices(db, settings, extensions: extensions);

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(home: Scaffold(body: ExtensionsPanel(services: services))),
    ));
    await tester.pumpAndSettle();

    // Core never listed; categories render in order with their headers.
    expect(find.text('ADIF Export'), findsNothing);
    expect(find.text('Activities'), findsOneWidget);
    expect(find.text('Callsign Lookups'), findsOneWidget);
    expect(find.text('Parks on the Air'), findsOneWidget);

    // QRZ defaults off, POTA on.
    bool switchValue(String title) =>
        tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title)).value;
    expect(switchValue('QRZ.com Callsign Lookups'), isFalse);
    expect(switchValue('Parks on the Air'), isTrue);

    // The top search filters across groups; empty groups lose headers.
    await tester.enterText(find.byKey(const ValueKey('extensions-search')), 'summits');
    await tester.pumpAndSettle();
    expect(find.text('Summits on the Air'), findsOneWidget);
    expect(find.text('Parks on the Air'), findsNothing);
    expect(find.text('Callsign Lookups'), findsNothing);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Toggling persists an override in the dedicated store (not the
    // settings groups).
    await tester.tap(find.widgetWithText(SwitchListTile, 'Summits on the Air'));
    await tester.pumpAndSettle();
    expect(settings.extensionOverrides, {'sota': false});
    expect(settings.extensionSettingsGroups(), isEmpty);
    expect(switchValue('Summits on the Air'), isFalse);
  });
}

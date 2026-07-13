// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/settings_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the General panel reflects a font scale change made outside the panel (e.g. the keyboard shortcut in main.dart)',
    (tester) async {
      // The keyboard shortcut handler in main.dart calls
      // SettingsService.increaseFontScale() directly — it never goes
      // through this panel's own _autosave/commit path. Without a listener
      // on SettingsService, the panel's cached FormDefinition (fetched once
      // in initState) would never reflect that external change.
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final db = HaLoDatabase(NativeDatabase.memory());

      final mockHost = MockExtensionHost({
        'settingsPanel:*:getPanels': [
          {
            'key': 'settings',
            'ok': true,
            'value': {'panelKey': 'settings', 'hookKey': 'settings', 'extensionKey': 'settings', 'title': 'General', 'kind': 'dynamic', 'order': 0},
          },
        ],
        'settingsPanel:settings:getDefinition': (Object? args) => {
          'title': 'General',
          'elements': [
            {
              'type': 'field',
              'fieldType': 'select',
              'key': 'fontScale',
              'label': 'Font Scale',
              'value': settings.fontScale.name,
              'options': [
                {'label': 'Normal', 'value': 'normal'},
                {'label': 'Larger', 'value': 'larger'},
              ],
            },
          ],
        },
      });
      final extensions = ExtensionServiceWithMockHost(mockHost)..settings = settings;
      final services = HaLoServices(db, settings, extensions: extensions);

      await tester.pumpWidget(MaterialApp(home: SettingsView(services: services)));
      await tester.pumpAndSettle();

      DropdownButtonFormField<dynamic> dropdown() =>
          tester.widget<DropdownButtonFormField<dynamic>>(find.byType(DropdownButtonFormField<dynamic>));

      expect(dropdown().initialValue, 'normal');

      // Simulate the keyboard shortcut: it never touches the panel widget.
      await settings.increaseFontScale();
      await tester.pumpAndSettle();

      expect(dropdown().initialValue, 'larger');
    },
  );
}

class MockExtensionHost implements ExtensionHost {
  final Map<String, dynamic> mockHookResults;
  MockExtensionHost(this.mockHookResults);

  @override
  Future<dynamic> invokeHook(
    String category, {
    String? key,
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final hookKey = '$category:$key:$method';
    if (mockHookResults.containsKey(hookKey)) {
      final res = mockHookResults[hookKey];
      if (res is Function) return res(args);
      return res;
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final hookKey = '$category:*:$method';
    if (mockHookResults.containsKey(hookKey)) {
      return (mockHookResults[hookKey] as List).cast<Map<String, dynamic>>();
    }
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ExtensionServiceWithMockHost extends ExtensionService {
  final MockExtensionHost mockHost;
  ExtensionServiceWithMockHost(this.mockHost);

  @override
  ExtensionHost? get host => mockHost;

  @override
  Future<void> start() async {}
}

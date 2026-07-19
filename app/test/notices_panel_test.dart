// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// "Recent Notices" (Issue #42 About restyle) moved out of the About panel
// into its own top-level "Notices & Messages" settings panel — this pins
// down that it's reachable from the sidebar and shows notice history there.

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

class _MockExtensionHost implements ExtensionHost {
  @override
  Future<dynamic> invokeHook(
    String category, {
    String? key,
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
  }) async => null;

  @override
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ExtensionServiceWithMockHost extends ExtensionService {
  final _MockExtensionHost mockHost = _MockExtensionHost();

  @override
  ExtensionHost? get host => mockHost;

  @override
  Future<void> start() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sidebar shows "Notices & Messages" (not "Recent Notices"), and selecting it lists notice history',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final extensions = _ExtensionServiceWithMockHost()..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);

    await tester.pumpWidget(MaterialApp(home: SettingsView(services: services)));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Recent Notices'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Notices & Messages'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Notices & Messages'));
    await tester.pumpAndSettle();

    // This mock extension host never starts (see `start()` above), which
    // itself raises a "settings unavailable" notice — that's already in
    // history by the time this panel loads, so its title proves the panel
    // body (not just the AppBar) actually rendered.
    expect(find.text('Some settings are unavailable'), findsOneWidget);
  });
}

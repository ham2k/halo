// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/data_file_manager.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/settings_view.dart';

import 'operation_view_layout_test.dart' show MockExtensionHost, ExtensionServiceWithMockHost;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the Data Files panel lists each registered data file with its last-download time', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 'alpha' was downloaded 2 days 7 hours ago; 'zeta' never was.
    final stamped = DateTime.now().subtract(const Duration(days: 2, hours: 7)).millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({'data_file_updated_alpha': stamped});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());

    const host = MockExtensionHost({
      'dataFile:*:getDefinition': [
        {
          'key': 'zeta',
          'ok': true,
          'value': {'key': 'zeta', 'name': 'Zeta Data', 'description': 'z', 'maxAgeInDays': 30, 'category': 'zeta'},
        },
        {
          'key': 'alpha',
          'ok': true,
          'value': {'key': 'alpha', 'name': 'Alpha Data', 'description': 'a', 'maxAgeInDays': 7, 'category': 'alpha'},
        },
      ],
    });
    final extensions = ExtensionServiceWithMockHost(host)..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);
    addTearDown(db.close);

    await tester.pumpWidget(TranslationProvider(child: MaterialApp(home: SettingsView(services: services))));
    await tester.pumpAndSettle();

    // Select the Data Files panel from the sidebar (wide/two-pane layout).
    await tester.tap(find.text('Data Files'));
    await tester.pumpAndSettle();

    // Both files render, sorted by name, each as its own row.
    expect(find.text('Alpha Data'), findsOneWidget);
    expect(find.text('Zeta Data'), findsOneWidget);
    // The day+hour relative-time branch, and the never-downloaded case.
    expect(find.text('Updated 2d 7h ago'), findsOneWidget);
    expect(find.text('Never downloaded'), findsOneWidget);
    // A Refresh control per row.
    expect(find.bySemanticsLabel('Refresh'), findsNWidgets(2));
  });

  testWidgets('tapping Refresh shows progress and updates the row from the returned time without re-listing',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final extensions = ExtensionServiceWithMockHost(const MockExtensionHost({}))..settings = settings;

    final fake = _FakeDataFiles(
      lookups: LookupRepository(db),
      extensions: extensions,
      prefs: await SharedPreferences.getInstance(),
    )..files = [DataFileStatus(key: 'alpha', name: 'Alpha Data')];

    final services = HaLoServices(db, settings, extensions: extensions, dataFiles: fake);

    await tester.pumpWidget(TranslationProvider(child: MaterialApp(home: SettingsView(services: services))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Data Files'));
    await tester.pumpAndSettle();

    expect(fake.listCalls, 1, reason: 'listed once on load');
    expect(find.text('Never downloaded'), findsOneWidget);

    // Tap Refresh — the refresh future stays pending on the gate.
    await tester.tap(find.bySemanticsLabel('Refresh'));
    await tester.pump();
    expect(find.text('Refreshing…'), findsOneWidget, reason: 'row shows live progress');
    expect(find.bySemanticsLabel('Refresh'), findsNothing, reason: 'button replaced by spinner while refreshing');

    // Let the refresh complete; the row updates from the returned time.
    fake.completeRefresh();
    await tester.pumpAndSettle();

    expect(fake.refreshed, ['alpha']);
    expect(find.text('Updated just now'), findsOneWidget, reason: 'patched from the refresh return value');
    expect(fake.listCalls, 1, reason: 'no second listDataFiles round-trip after refresh');
  });

  testWidgets('tapping Update All forces a full sync and reloads the list once it settles', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final extensions = ExtensionServiceWithMockHost(const MockExtensionHost({}))..settings = settings;

    final fake = _FakeDataFiles(
      lookups: LookupRepository(db),
      extensions: extensions,
      prefs: await SharedPreferences.getInstance(),
    )..files = [DataFileStatus(key: 'alpha', name: 'Alpha Data'), DataFileStatus(key: 'zeta', name: 'Zeta Data')];

    final services = HaLoServices(db, settings, extensions: extensions, dataFiles: fake);

    await tester.pumpWidget(TranslationProvider(child: MaterialApp(home: SettingsView(services: services))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Data Files'));
    await tester.pumpAndSettle();

    expect(fake.listCalls, 1, reason: 'listed once on load');
    expect(find.bySemanticsLabel('Refresh'), findsNWidgets(2));

    // Tap Update All — the sync future stays pending on the gate.
    await tester.tap(find.text('Update All'));
    await tester.pump();
    expect(find.text('Updating all data files…'), findsOneWidget, reason: 'summary row shows an in-progress state');
    expect(fake.syncAllForce, true, reason: 'forces a fresh fetch, same as an individual refresh');
    // Every row switches to its own live progress too, same as an individual
    // Refresh — not just the summary row above the list.
    expect(find.bySemanticsLabel('Refresh'), findsNothing, reason: 'per-row refresh buttons become progress rows');
    expect(find.text('Refreshing…'), findsNWidgets(2), reason: 'each file shows its own in-progress row');

    // Let the sync complete; the panel re-lists to pick up every row's new time.
    fake.completeSyncAll();
    await tester.pumpAndSettle();

    expect(fake.listCalls, 2, reason: 'reloads after the bulk sync settles');
    expect(find.text('Updating all data files…'), findsNothing);
    expect(find.bySemanticsLabel('Refresh'), findsNWidgets(2), reason: 'rows return to their normal state');
  });
}

/// A [DataFileManager] whose list/refresh are stubbed so the panel's
/// interaction (not the download machinery) is what's under test. The
/// refresh stays pending until [completeRefresh], to observe the in-progress
/// row.
class _FakeDataFiles extends DataFileManager {
  _FakeDataFiles({required super.lookups, required super.extensions, required super.prefs});

  List<DataFileStatus> files = [];
  int listCalls = 0;
  final List<String> refreshed = [];
  final Completer<void> _gate = Completer<void>();
  bool? syncAllForce;
  final Completer<void> _syncGate = Completer<void>();

  void completeRefresh() => _gate.complete();
  void completeSyncAll() => _syncGate.complete();

  @override
  Future<List<DataFileStatus>> listDataFiles() async {
    listCalls++;
    return files;
  }

  @override
  Future<DateTime?> refreshDataFile(String key) async {
    refreshed.add(key);
    await _gate.future;
    return files.any((f) => f.key == key) ? DateTime.now() : null;
  }

  @override
  Future<int> syncAllDataFiles({bool force = false, String? categoryFilter, bool notifyOnFailure = true}) async {
    syncAllForce = force;
    await _syncGate.future;
    return files.length;
  }
}

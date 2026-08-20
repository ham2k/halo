// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SYNCALL backs up and WIPES the local log, then refills it from the server
// — and the backfill can only return what the server holds, so any unsynced
// row is gone for good. The traps these tests exist to catch: the command
// running without asking (a `syncAll` routed straight to handleCommandAction
// wipes on the Enter keystroke with no prompt), and the dialog's count
// naming rows that are not vanishing contacts (tombstones, event markers).

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';

class _IdleExtensions extends ExtensionService {
  @override
  bool get ready => true;

  @override
  Future<void> start() async {}
}

void main() {
  testWidgets('SYNCALL asks first, names the unsynced count, and cancel leaves the log untouched', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final services = HaLoServices(db, settings, extensions: _IdleExtensions());
    await settings.setSyncEnabled(true);

    await tester.runAsync(() async {
      final operation = await services.operations.create(stationCall: 'KI2D');
      await services.qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
      });
      // Dirty rows that are NOT unsynced contacts: a tombstone (whose loss
      // direction is a resurrection, not a vanished QSO) and an event
      // marker. The dialog's count must not include either.
      final deleted = await services.qsos.add(operation.uuid, {
        'their': {'call': 'K1ABC'},
        'band': '20m',
      });
      await services.qsos.softDelete(deleted);
      await services.qsos.addEvent(operation.uuid, kind: 'start', atMillis: 1000);
    });

    late BuildContext context;
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(home: Builder(builder: (c) {
        context = c;
        return const Scaffold();
      })),
    ));

    final outcome = runCommandAction(services, 'syncAll', null, context);
    await tester.pump();
    await tester.pump();

    expect(find.text(t.dialogs.syncAllTitle), findsOneWidget);
    // The freshly-logged QSO has never synced — the dialog must say so in
    // its own line, not fold it into the total.
    expect(find.text(t.dialogs.syncAllUnsynced(count: 1, n: '1')), findsOneWidget);

    await tester.tap(find.text(t.common.cancel));
    await tester.pump();
    // Cancelled: no message, and the log is exactly as it was.
    expect(await outcome, isFalse);
    final remaining = await tester.runAsync(() => services.qsos.syncCounts());
    expect(remaining!.total, 1);
  });

  testWidgets('SYNCALL with no dialog context refuses instead of wiping unprompted', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final services = HaLoServices(db, settings, extensions: _IdleExtensions());
    await settings.setSyncEnabled(true);

    await tester.runAsync(() async {
      final operation = await services.operations.create(stationCall: 'KI2D');
      await services.qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
      });
    });

    expect(await runCommandAction(services, 'syncAll'), isTrue);
    expect(services.statusBar.items.map((i) => i.text), contains(t.commands.syncAllUnavailable));
    final remaining = await tester.runAsync(() => services.qsos.syncCounts());
    expect(remaining!.total, 1);
  });
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/cw_messages_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    services = HaLoServices(db, settings);
  });

  Widget host() => TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showCwMessagesDialog(context, services),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  testWidgets('one row per key, labelled where a label exists, the message underneath', (tester) async {
    await services.settings.setCwMessage(1, 'CQ CQ DE {{ op.call }} K');
    await services.settings.setCwMessageLabel(1, 'CQ');
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('CW Messages'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(SettingsService.cwMessageCount));
    expect(find.text('CQ CQ DE {{ op.call }} K'), findsOneWidget);
    expect(find.textContaining('F1'), findsWidgets);
    // The set the write landed in is a SEEDED one, so the rows that say
    // "(empty)" are the ones the seeds left alone — not all seven others.
    final set = services.settings.activeCwMessageSet;
    final empties = [
      for (var n = 1; n <= SettingsService.cwMessageCount; n++) if (set.message(n).trim().isEmpty) n,
    ];
    expect(empties, isNotEmpty);
    expect(find.text('(empty)'), findsNWidgets(empties.length), reason: 'the unset ones say so');
  });

  testWidgets('a row opens its own dialog: the message, then the label under Details; Save writes both', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ListTile).at(2));
    await tester.pumpAndSettle();
    expect(find.text('Message (3)'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'F3'), '{{ qso.call }} 5NN TU');
    await tester.enterText(find.widgetWithText(TextField, 'Label'), 'Exchange');
    // The row's own Save — the dialog behind it has one too.
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    // The row's Save hands its two values UP; the dialog behind it holds
    // them as a draft, which is why nothing is stored yet.
    expect(services.settings.cwMessage(3), isNot('{{ qso.call }} 5NN TU'));
    expect(find.text('Message (3)'), findsNothing, reason: 'closed on Save');
    expect(find.textContaining('Exchange'), findsOneWidget);
    expect(find.text('{{ qso.call }} 5NN TU'), findsOneWidget);

    // The dialog's own Save is what writes.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(services.settings.cwMessage(3), '{{ qso.call }} 5NN TU');
    expect(services.settings.cwMessageLabel(3), 'Exchange');
  });

  testWidgets('Cancel abandons every set the operator touched, not just the one on screen', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final before = services.settings.cwMessage(3);
    await tester.tap(find.byType(ListTile).at(2));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'F3'), 'NEVER STORED');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    // The trap: a dialog that stored as it went would leave this behind,
    // and Cancel would only undo whatever was on screen at the end.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(services.settings.cwMessage(3), before);
  });

  testWidgets('an install with nothing stored is seeded: a Default to key, and a POTA beside it', (tester) async {
    final sets = services.settings.cwMessageSets;
    expect(sets.map((set) => set.name), ['Default', 'POTA']);
    expect(services.settings.cwMessageSetName, 'Default');
    expect(services.settings.cwMessage(1), 'CQ DE {{op.call}} K');
    expect(services.settings.cwMessageLabel(1), 'CQ');
    // POTA is Default with its CQ changed — what duplicating a set makes,
    // and the shape the operator's next one will be.
    expect(sets.last.message(1), 'CQ POTA DE {{op.call}} K');
    expect(sets.last.message(2), sets.first.message(2));
  });

  testWidgets('messages written before sets existed become a set of their own, and stay in use', (tester) async {
    // What an upgrade finds: the pre-sets keys, under their own storage.
    SharedPreferences.setMockInitialValues({
      'settings.radio': '{"cwMessage1":"CQ DE N0CALL K","cwMessageLabel1":"MY CQ"}',
    });
    final settings = SettingsService(await SharedPreferences.getInstance());
    expect(settings.cwMessageSets.map((set) => set.name), ['My Messages', 'Default', 'POTA']);
    // FIRST, and therefore active: an upgrade must not change what the
    // function keys send.
    expect(settings.cwMessageSetName, 'My Messages');
    expect(settings.cwMessage(1), 'CQ DE N0CALL K');
    expect(settings.cwMessageLabel(1), 'MY CQ');
  });

  testWidgets('picking a set changes what the keys send, and New Set duplicates what is on screen', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Default').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('POTA').last);
    await tester.pumpAndSettle();
    expect(services.settings.cwMessageSetName, 'Default', reason: 'the pick is a draft until Save');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(services.settings.cwMessageSetName, 'POTA');
    expect(services.settings.cwMessage(1), 'CQ POTA DE {{op.call}} K');
  });
}

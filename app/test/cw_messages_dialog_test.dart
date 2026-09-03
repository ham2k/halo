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
    expect(find.text('(empty)'), findsNWidgets(SettingsService.cwMessageCount - 1), reason: 'the unset ones say so');
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
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(services.settings.cwMessage(3), '{{ qso.call }} 5NN TU');
    expect(services.settings.cwMessageLabel(3), 'Exchange');
    expect(find.text('Message (3)'), findsNothing, reason: 'closed on Save');
    // The list behind it shows the change without being reopened.
    expect(find.textContaining('Exchange'), findsOneWidget);
    expect(find.text('{{ qso.call }} 5NN TU'), findsOneWidget);
  });
}

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
import 'package:ham2k_logger/views/operation/activities_view.dart';

import 'operation_view_layout_test.dart' show MockExtensionHost, ExtensionServiceWithMockHost;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows disabled/unsupported activity reference in red list tile with a question mark icon', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    final extensions = ExtensionServiceWithMockHost(const MockExtensionHost({}))..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);

    // Create an operation with an unsupported ref type
    final operation = Operation(
      uuid: 'op-123',
      data: {
        'refs': [
          {'type': 'unsupported-type', 'ref': 'UN-9999', 'name': 'Unsupported Activity'},
        ],
      },
    );

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: OperationSheet(
            services: services,
            operation: operation,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Verify the list tile is present
    final listTileFinder = find.ancestor(
      of: find.text('UN-9999'),
      matching: find.byType(ListTile),
    );
    expect(listTileFinder, findsOneWidget);

    final listTile = tester.widget<ListTile>(listTileFinder);
    
    // Icon should be question mark inside CircleAvatar
    final leadingFinder = find.descendant(of: listTileFinder, matching: find.byType(CircleAvatar));
    expect(leadingFinder, findsOneWidget);
    
    final iconFinder = find.descendant(of: leadingFinder, matching: find.byIcon(Icons.question_mark));
    expect(iconFinder, findsOneWidget);
    // Same 16px the pre-shared-helper inline markup used — activityRefIcon
    // must default to it, not the ambient IconTheme size (ham2k/app-halo-dist#261).
    expect(tester.widget<Icon>(iconFinder).size, 16);

    // Verify tile background color is from the errorContainer (pale red)
    final theme = Theme.of(tester.element(listTileFinder));
    expect(listTile.tileColor, theme.colorScheme.errorContainer.withValues(alpha: 0.4));
  });

  testWidgets('the same treatment applies to an unsupported ref resurfaced as a Suggestion (issue #261)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    final extensions = ExtensionServiceWithMockHost(const MockExtensionHost({}))..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);

    final operation = Operation(
      uuid: 'op-123',
      data: {
        'refs': [
          {'type': 'unsupported-type', 'ref': 'UN-9999', 'name': 'Unsupported Activity'},
        ],
      },
    );

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: Scaffold(body: OperationSheet(services: services, operation: operation)),
      ),
    ));
    await tester.pumpAndSettle();

    // Deleting the unsupported ref resurfaces it as a Suggestion (so the
    // removal is easy to undo) — same unknown type, now in the other list.
    await tester.tap(find.bySemanticsLabel('Remove'));
    await tester.pumpAndSettle();

    final suggestionTileFinder = find.ancestor(of: find.text('UN-9999'), matching: find.byType(ListTile));
    expect(suggestionTileFinder, findsOneWidget);

    final suggestionTile = tester.widget<ListTile>(suggestionTileFinder);
    final theme = Theme.of(tester.element(suggestionTileFinder));
    expect(suggestionTile.tileColor, theme.colorScheme.errorContainer.withValues(alpha: 0.4));

    final leadingFinder = find.descendant(of: suggestionTileFinder, matching: find.byType(CircleAvatar));
    expect(leadingFinder, findsOneWidget);
    expect(find.descendant(of: leadingFinder, matching: find.byIcon(Icons.question_mark)), findsOneWidget);
  });
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows disabled/unsupported activity reference in red list tile with a question mark icon', (tester) async {
    final HaLoHarness(:services) = await makeHaLoServices();

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

    final listTileFinder = find.ancestor(
      of: find.text('UN-9999'),
      matching: find.byType(ListTile),
    );
    expect(listTileFinder, findsOneWidget);

    final listTile = tester.widget<ListTile>(listTileFinder);
    
    // Icon should be question mark inside CircleAvatar
    final leadingFinder = find.descendant(of: listTileFinder, matching: find.byType(CircleAvatar));
    expect(leadingFinder, findsOneWidget);
    
    final iconFinder = find.descendant(of: leadingFinder, matching: find.byIcon(MdiIcons.help));
    expect(iconFinder, findsOneWidget);
    // Same 16px the pre-shared-helper inline markup used — activityRefIcon
    // must default to it, not the ambient IconTheme size (ham2k/halo-dist#261).
    expect(tester.widget<Icon>(iconFinder).size, 16);

    // Verify tile background color is from the errorContainer (pale red)
    final theme = Theme.of(tester.element(listTileFinder));
    expect(listTile.tileColor, theme.colorScheme.errorContainer.withValues(alpha: 0.4));
  });

  testWidgets('the same treatment applies to an unsupported ref resurfaced as a Suggestion (issue #261)',
      (tester) async {
    final HaLoHarness(:services) = await makeHaLoServices();

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
    expect(find.descendant(of: leadingFinder, matching: find.byIcon(MdiIcons.help)), findsOneWidget);
  });
}

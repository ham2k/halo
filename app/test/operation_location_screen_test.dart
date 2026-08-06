// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/operation_location_screen.dart';

import 'operation_view_layout_test.dart' show MockExtensionHost, ExtensionServiceWithMockHost;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a suggested-location ref from an unsupported extension shows a pale-red tile and question mark (issue #261)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    // Empty host: no activity control is ever registered, so any ref type
    // is "unknown" — same setup as activities_disabled_extension_test.dart.
    final extensions = ExtensionServiceWithMockHost(const MockExtensionHost({}))..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);

    final operation = Operation(
      uuid: 'op-123',
      data: {
        'refs': [
          {'type': 'unsupported-type', 'ref': 'UN-9999', 'name': 'Unsupported Activity', 'grid': 'FN31pr'},
        ],
      },
    );

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: OperationLocationScreen(services: services, operation: operation),
      ),
    ));
    await tester.pumpAndSettle();

    final tileFinder = find.ancestor(of: find.text('UN-9999'), matching: find.byType(ListTile));
    expect(tileFinder, findsOneWidget);

    final tile = tester.widget<ListTile>(tileFinder);
    final theme = Theme.of(tester.element(tileFinder));
    expect(tile.tileColor, theme.colorScheme.errorContainer.withValues(alpha: 0.4));

    final leadingFinder = find.descendant(of: tileFinder, matching: find.byType(CircleAvatar));
    expect(leadingFinder, findsOneWidget);
    expect(find.descendant(of: leadingFinder, matching: find.byIcon(MdiIcons.help)), findsOneWidget);
  });

  testWidgets('does not flash the unknown-type treatment on the very first frame, before controls finish loading',
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
          {'type': 'unsupported-type', 'ref': 'UN-9999', 'name': 'Unsupported Activity', 'grid': 'FN31pr'},
        ],
      },
    );

    // pumpWidget's own single frame is the assertion point — before
    // operationControls()'s Future (started in initState) has a chance to
    // resolve and call setState; a further pump() would flush that
    // microtask first, hiding the very race this test guards against (the
    // controls list is empty either way here, so the *only* thing that can
    // distinguish "still loading" from "loaded and genuinely unknown" is
    // _loadingControls itself).
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: OperationLocationScreen(services: services, operation: operation),
      ),
    ));

    final tileFinder = find.ancestor(of: find.text('UN-9999'), matching: find.byType(ListTile));
    expect(tileFinder, findsOneWidget);
    final tile = tester.widget<ListTile>(tileFinder);
    final theme = Theme.of(tester.element(tileFinder));
    expect(tile.tileColor, isNot(theme.colorScheme.errorContainer.withValues(alpha: 0.4)),
        reason: 'must not show the unknown-type treatment while controls are still loading');
    expect(find.descendant(of: tileFinder, matching: find.byIcon(MdiIcons.help)), findsNothing);

    // Once loading finishes, THIS ref (its extension genuinely isn't
    // active) does become flagged — same end state as the test above.
    await tester.pumpAndSettle();
    final settledTile = tester.widget<ListTile>(tileFinder);
    expect(settledTile.tileColor, theme.colorScheme.errorContainer.withValues(alpha: 0.4));
  });

  group('grid validation', () {
    // Nothing downstream validates what this dialog returns, and a locator it
    // can't decode is worse than none: `gridToLocation` answers null, so the
    // search quietly loses its location while every control claims one is set.
    // The operator sees "No suggestions" and believes there is nothing nearby.
    Future<Map<String, dynamic>?> saveGrid(WidgetTester tester, String typed) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final db = HaLoDatabase(NativeDatabase.memory());
      final extensions = ExtensionServiceWithMockHost(const MockExtensionHost({}))..settings = settings;
      final services = HaLoServices(db, settings, extensions: extensions);
      final operation = Operation(uuid: 'op-1', data: const {'refs': []});

      Map<String, dynamic>? popped;
      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                popped = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (_) => OperationLocationScreen(services: services, operation: operation),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, typed);
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppLocale.en.buildSync().common.save));
      await tester.pumpAndSettle();
      return popped;
    }

    testWidgets('a half-typed locator is refused, and the dialog says why', (tester) async {
      final popped = await saveGrid(tester, 'FN');

      expect(popped, isNull, reason: 'nothing may be saved');
      expect(find.byType(OperationLocationScreen), findsOneWidget, reason: 'the dialog stays open to be corrected');
      expect(find.text(AppLocale.en.buildSync().operationLocationScreen.gridInvalid), findsOneWidget);
    });

    testWidgets('8- and 10-character locators are perfectly good', (tester) async {
      // Longer than the 6 the app itself generates, and legitimate Maidenhead.
      expect((await saveGrid(tester, 'FN31pr60'))?['grid'], 'FN31pr60');
      expect((await saveGrid(tester, 'FN31pr60ax'))?['grid'], 'FN31pr60ax');
    });

    testWidgets('an empty grid still means "no location", not an error', (tester) async {
      final popped = await saveGrid(tester, '');
      expect(popped, isNotNull);
      expect(popped!['grid'], isNull);
    });

    testWidgets('editing clears the complaint rather than making them Save to see it go', (tester) async {
      await saveGrid(tester, 'FN');
      final t = AppLocale.en.buildSync().operationLocationScreen;
      expect(find.text(t.gridInvalid), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'FN31');
      await tester.pumpAndSettle();
      expect(find.text(t.gridInvalid), findsNothing);
    });
  });
}

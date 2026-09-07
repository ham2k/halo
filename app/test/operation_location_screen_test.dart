// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/views/operation/operation_location_screen.dart';

import 'support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a suggested-location ref from an unsupported extension shows a pale-red tile and question mark (issue #261)',
      (tester) async {
    // Empty host: no activity control is ever registered, so any ref type
    // is "unknown" — same setup as activities_disabled_extension_test.dart.
    final HaLoHarness(:services) = await makeHaLoServices();

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
    final HaLoHarness(:services) = await makeHaLoServices();

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
      final HaLoHarness(:services) = await makeHaLoServices();
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

  // A locator is a cell; the coordinate behind it is what every distance and
  // nearby search actually measures from. This dialog is the main way one gets
  // onto an operation, and the one place an operator can overwrite it by hand.
  group('coordinates', () {
    Map<String, dynamic>? popped;

    Future<void> open(WidgetTester tester, Operation operation) async {
      popped = null;
      final HaLoHarness(:services) = await makeHaLoServices();

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
    }

    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.text(AppLocale.en.buildSync().common.save));
      await tester.pumpAndSettle();
    }

    Operation withPark({double? lat, double? lon}) => Operation(
          uuid: 'op-1',
          data: {
            'refs': [
              {
                'type': 'potaActivation',
                'ref': 'US-1234',
                'grid': 'FN31',
                'lat': ?lat,
                'lon': ?lon,
              },
            ],
          },
        );

    testWidgets("adopting a ref stores the coordinate its program published, not just the square", (tester) async {
      await open(tester, withPark(lat: 41.7135, lon: -72.7278));
      await tester.tap(find.text('US-1234'));
      await tester.pumpAndSettle();
      await save(tester);

      expect(popped!['lat'], closeTo(41.7135, 1e-9));
      expect(popped!['lon'], closeTo(-72.7278, 1e-9));
      // The ref's own `grid` is FN31 — four characters, a 9 x 5 km cell. What
      // gets stored is the locator for the coordinate instead, so the two
      // cannot describe different places.
      expect(popped!['grid'], locationToGrid8(41.7135, -72.7278));
    });

    testWidgets('adopting a ref whose program publishes no coordinate stores the grid alone', (tester) async {
      await open(tester, withPark());
      await tester.tap(find.text('US-1234'));
      await tester.pumpAndSettle();
      await save(tester);

      expect(popped!['grid'], 'FN31');
      expect(popped!['lat'], isNull, reason: 'claiming a coordinate here would invent one');
    });

    // One mechanism enforces the rule — the text listener drops the coordinate
    // the moment a key lands — so the case that pins it is the one no
    // after-the-fact comparison of the field could catch: text identical to
    // what was adopted, which is indistinguishable from an untouched field
    // unless something noticed a human typing it.
    testWidgets('retyping the very same locator by hand still drops the coordinate', (tester) async {
      await open(tester, withPark(lat: 41.7135, lon: -72.7278));
      await tester.tap(find.text('US-1234'));
      await tester.pumpAndSettle();

      // Character for character what adopting the park put there — so the
      // save's own "does the text still match?" check cannot tell this from
      // an untouched field. Only the listener knows a human typed it, and
      // what they stated is a square.
      final adopted = locationToGrid8(41.7135, -72.7278);
      await tester.enterText(find.byType(TextField).first, adopted);
      await tester.pumpAndSettle();
      await save(tester);

      expect(popped!['grid'], adopted);
      expect(popped!['lat'], isNull);
      expect(popped!['lon'], isNull);
    });

    testWidgets('typing a different locator over an adopted location drops its coordinate', (tester) async {
      await open(tester, withPark(lat: 41.7135, lon: -72.7278));
      await tester.tap(find.text('US-1234'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'DM33xk');
      await tester.pumpAndSettle();
      await save(tester);

      expect(popped!['grid'], 'DM33xk');
      // The operator stated a square, so a square is all that may be stored:
      // the coordinate outranks the grid everywhere it is read, and keeping
      // the park's would put the station straight back at the park.
      expect(popped!['lat'], isNull);
      expect(popped!['lon'], isNull);
    });

    testWidgets('opening the dialog and saving it unchanged keeps the location it arrived with', (tester) async {
      // The patch is spread over the operation's data, so every key this
      // dialog returns overwrites what was there — a field nobody touched
      // coming back null silently strips a stored fix (and the source that
      // says where it came from).
      await open(
        tester,
        Operation(uuid: 'op-1', data: {
          'grid': locationToGrid8(41.7135, -72.7278),
          'gridSource': 'gps',
          'lat': 41.7135,
          'lon': -72.7278,
          'refs': const [],
        }),
      );
      await save(tester);

      expect(popped!['lat'], closeTo(41.7135, 1e-9));
      expect(popped!['lon'], closeTo(-72.7278, 1e-9));
      expect(popped!['gridSource'], 'gps');
    });
  });
}

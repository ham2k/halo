// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The More pane's station fields: which ones it offers, what they write to
// the contact, and a grid against the coordinate stored beside it.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();

  group("the More pane's station fields", () {
    /// A panel whose lookup answers [guess] for W1AW — the pane's placeholders
    /// and its US-only fields both hang off what the lookup said.
    Widget hostWithGuess(Map<String, dynamic> guess) => MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          log: baseLog(),
          radio: baseRadio(),
          lookups: LookupHooks(
            lookup: (call, {required qso, required operation, required online, recentContext = false}) async => call == 'W1AW' ? {'guess': guess} : null,
          ),
        ),
      ),
    );

    Future<void> openPane(WidgetTester tester) async {
      await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    testWidgets('County and ARRL Section are offered for a US contact and withheld for a DX one', (tester) async {
      // Both name a US administrative division. Over a DX contact they are
      // fields with no possible answer, and an operator who fills one in has
      // written something no program will read.
      await tester.pumpWidget(hostWithGuess({'entityPrefix': 'I', 'entityName': 'Italy'}));
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump(const Duration(milliseconds: 400));
      await openPane(tester);
      expect(find.text('County'), findsNothing);
      expect(find.text('ARRL Section'), findsNothing);
      expect(find.text('Entity'), findsOneWidget, reason: 'the entity is shown whoever they are');
    });

    testWidgets('a city and a zone typed into the pane reach the logged QSO', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();

      await openPane(tester);
      await tester.enterText(find.widgetWithText(TextField, 'City'), 'Newington');
      await tester.enterText(find.widgetWithText(TextField, 'CQ Zone'), '5');
      await tester.enterText(find.widgetWithText(TextField, 'Their power'), '100');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 1);
      final their = logged.single.data['their'] as Map;
      expect(their['city'], 'Newington');
      expect(their['cqZone'], 5);
      expect(their['power'], 100);
    });

    testWidgets('opening the pane over a guess and saving does not make the guess an entered value', (tester) async {
      // The trap the whole `theirExtra` before/after comparison exists for:
      // a guess promoted to an entered value stops tracking the lookup, and
      // an operator who merely looked at the pane has stated nothing.
      await tester.pumpWidget(hostWithGuess({'city': 'Newington', 'state': 'CT', 'cqZone': 5}));
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump(const Duration(milliseconds: 400));

      await openPane(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 1);
      final their = logged.single.data['their'] as Map;
      expect(their.containsKey('city'), isFalse);
      expect(their.containsKey('cqZone'), isFalse);
      expect((their['guess'] as Map)['city'], 'Newington', reason: 'the lookup still answers for it');
    });

    testWidgets('editing the grid clears the coordinate, on screen and on the record', (tester) async {
      // A coordinate outranks a grid wherever one is read
      // (docs/design/locations.md), so a stale pair left beside a corrected
      // locator would silently discard the correction — and a pane still
      // showing that pair would be telling the operator the opposite of what
      // the save is about to do.
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW', 'grid': 'FN31pr', 'lat': 41.71, 'lon': -72.72},
        'band': '20m',
        'mode': 'SSB',
      });
      await tester.pumpWidget(host(session: LoggingSession(editingQso: existing)));
      await tester.pump();
      await openPane(tester);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Latitude')).controller!.text, '41.71');

      await tester.enterText(find.widgetWithText(TextField, 'Grid'), 'fn20aa');
      // onChange fires on blur, which is what an operator moving on does.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Latitude')).controller!.text, isEmpty);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Longitude')).controller!.text, isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      // The panel's own Log button, not Enter: the pane has just closed and
      // the keyboard is not back in a main field for a shortcut to reach.
      await tester.tap(find.byType(FilledButton));

      // The record already exists, so a count of one says nothing about
      // whether the edit landed — poll for the value itself.
      var saved = existing;
      for (var i = 0; i < 20 && saved.theirGrid != 'FN20aa'; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        saved = (await tester.runAsync(() => qsos.watchForOperation(operation.uuid).first))!.single;
      }
      expect(saved.theirGrid, 'FN20aa');
      // The stale pair is gone — what stands in its place is the typed
      // square's own center, which says nothing FN20aa did not. BOTH halves:
      // the writer decides them together, and a latitude paired with the
      // other square's longitude is a point nobody stated.
      final theirSaved = saved.data['their'] as Map;
      expect(theirSaved['lat'], closeTo(gridToLocation('FN20aa')!.latitude, 1e-9));
      expect(theirSaved['lon'], closeTo(gridToLocation('FN20aa')!.longitude, 1e-9));
      expect(theirSaved['lat'], isNot(closeTo(41.71, 0.01)));
    });

    testWidgets('a grid saved without leaving the field still clears the coordinate', (tester) async {
      // The pane's on-screen coordinate clear runs on BLUR, and `submit()`
      // snapshots its values before the unfocus it triggers is delivered — so
      // a grid typed and submitted straight from the field arrives with the
      // coordinate fields never blanked and nothing recorded to blank them.
      // The pair then outranks the grid just entered, everywhere it is read.
      //
      // It has to be a COMPOSED contact: on a saved record the coordinate
      // lives on the record itself, where the grid's own clear reaches it. On
      // a draft it lives in the pane's override map, which is what this
      // orders against.
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();

      await openPane(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Latitude'), '41.71');
      await tester.enterText(find.widgetWithText(TextField, 'Longitude'), '-72.72');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      await openPane(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Grid'), 'fn20aa');
      // The engine's own end-of-editing action, which the pane's single-line
      // fields wire straight to `submit()`. NOT a tap on Save: a tap moves
      // focus off the field first, firing the blur listener and hiding the
      // very ordering this test exists for.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FilledButton));
      final their = (await waitForQsos(tester, 1)).single.data['their'] as Map;
      expect(their['grid'], 'FN20aa');
      expect(their['lat'], closeTo(gridToLocation('FN20aa')!.latitude, 1e-9));
      expect(their['lon'], closeTo(gridToLocation('FN20aa')!.longitude, 1e-9));
      expect(their['lat'], isNot(closeTo(41.71, 0.01)), reason: 'the pane pair must not survive the typed grid');
    });

    testWidgets("the More pane's Grid hint is the same square the logging row hints", (tester) async {
      // Two Grid fields for one station, and they must not disagree. The pane
      // reads the guess's own stored square, which is six characters whatever
      // Grid Precision says — so with a coordinate in the guess and the
      // setting at eight, the row hinted the derived locator and the pane
      // hinted the coarser filed one. Both go through `guessGridDisplay` now.
      GridPrecision.configure(GridPrecision.eight);
      addTearDown(GridPrecision.reset);
      await tester.pumpWidget(hostWithGuess({'grid': 'FN31pr', 'lat': 41.7135, 'lon': -72.7278}));
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump(const Duration(milliseconds: 400));
      await openPane(tester);

      final paneHint = tester.widget<TextField>(find.widgetWithText(TextField, 'Grid')).decoration!.hintText;
      expect(paneHint, locationToGrid8(41.7135, -72.7278));
      expect(paneHint, isNot('FN31pr'), reason: 'the filed square is coarser than the coordinate beside it');
    });

    testWidgets('County and ARRL Section are offered to Alaska and Hawaii', (tester) async {
      // They are their own DXCC entities, so a bare `K` test hides both — and
      // per the scorer these stations carry no `state` of their own, which
      // makes the section the only place their location could be recorded.
      for (final prefix in const ['KL', 'KH6']) {
        await tester.pumpWidget(hostWithGuess({'entityPrefix': prefix}));
        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
        await tester.pump(const Duration(milliseconds: 400));
        await openPane(tester);
        expect(find.text('ARRL Section'), findsOneWidget, reason: '$prefix is US');
        expect(find.text('County'), findsOneWidget, reason: '$prefix is US');
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
      }
    });

    testWidgets("a typed grid drops the country-file tag that would make readers refuse its coordinate", (tester) async {
      // app-polo spreads lib-country-files' annotation onto `their` itself,
      // so a synced QSO arrives with a DXCC centroid AND `locSource: 'prefix'`
      // marking it as one. Typing a grid replaces the pair with the square's
      // own center — and a tag left behind would then describe THAT, so every
      // reader would refuse it (halo_core's `locationFromGuess`) and the grid
      // would carry no coordinate after all.
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW', 'lat': 41.71, 'lon': 72.72, 'locSource': 'prefix'},
        'band': '20m',
        'mode': 'SSB',
      });
      await tester.pumpWidget(host(session: LoggingSession(editingQso: existing)));
      await tester.pump();
      await openPane(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Grid'), 'fn20aa');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));

      var saved = existing;
      for (var i = 0; i < 20 && saved.theirGrid != 'FN20aa'; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        saved = (await tester.runAsync(() => qsos.watchForOperation(operation.uuid).first))!.single;
      }
      expect(saved.theirGrid, 'FN20aa');
      expect((saved.data['their'] as Map)['locSource'], isNull);
      // The point of clearing it: the pair is readable as a coordinate again.
      expect(saved.theirExactLocation, gridToLocation('FN20aa'));
    });

    testWidgets('half a coordinate in the pane does not fuse with the grid into a whole one', (tester) async {
      // The trap: a typed grid writes its square's center, and the pane
      // records Latitude and Longitude as two independent overrides. Decided
      // per-field, a stated latitude beside the center's longitude would be
      // stored as a coordinate — a point nobody named, outranking the grid
      // everywhere it is read (docs/design/locations.md). Half a pair is no
      // coordinate, so the grid must answer for both halves or neither.
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();

      await openPane(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Grid'), 'fn20aa');
      // Latitude alone, Longitude left empty.
      await tester.enterText(find.widgetWithText(TextField, 'Latitude'), '41.71');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FilledButton));
      final their = (await waitForQsos(tester, 1)).single.data['their'] as Map;
      expect(their['grid'], 'FN20aa');
      expect(their['lat'], closeTo(gridToLocation('FN20aa')!.latitude, 1e-9));
      expect(their['lon'], closeTo(gridToLocation('FN20aa')!.longitude, 1e-9));
      expect(their['lat'], isNot(closeTo(41.71, 0.01)), reason: 'half a stated pair is not a coordinate');
    });

    testWidgets('a coordinate typed into the pane outranks the grid it was stored beside', (tester) async {
      // The other half: the clear above exists to stop a STALE pair from
      // surviving a typed grid, not to overrule one the operator just stated.
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();

      await openPane(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Latitude'), '41.71');
      await tester.enterText(find.widgetWithText(TextField, 'Longitude'), '-72.72');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final their = (await waitForQsos(tester, 1)).single.data['their'] as Map;
      expect(their['lat'], 41.71);
      expect(their['lon'], -72.72);
    });
  });

  group("the More pane's Our grid", () {
    Future<void> openPane(WidgetTester tester) async {
      await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    Finder ourGrid() => find.widgetWithText(TextField, 'Our grid');

    Future<void> placeOperation(WidgetTester tester, String grid) async {
      operation = Operation(uuid: operation.uuid, data: {...operation.data, 'grid': grid});
      await tester.runAsync(() => operations.saveData(operation));
    }

    Future<Map> savedOur(WidgetTester tester, bool Function(Map our) until) async {
      final logged = await waitForQsosWhere(tester, 'the edit to land', (logged) => until(logged.single.data['our'] as Map));
      return logged.single.data['our'] as Map;
    }

    testWidgets("hints the operation's grid and, typed, gives the contact a place of its own", (tester) async {
      await placeOperation(tester, 'FN31pr');
      final existing = (await tester.runAsync(
        () => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW'},
          'our': {'call': 'KI2D'},
          'band': '20m',
          'mode': 'SSB',
        }),
      ))!;
      await tester.pumpWidget(host(session: LoggingSession(editingQso: existing)));
      await tester.pump();
      await openPane(tester);

      final field = tester.widget<TextField>(ourGrid());
      expect(field.controller!.text, isEmpty, reason: 'a contact recording no place shows none, or saving would stamp one');
      expect(field.decoration!.hintText, 'FN31pr', reason: 'the place the contact falls back to');

      await tester.enterText(ourGrid(), 'fn20aa');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));

      final our = await savedOur(tester, (our) => our['grid'] != null);
      final center = locationForStatedGrid('FN20aa')!;
      expect(our['grid'], 'FN20aa');
      // A grid without its pair would be outranked by any coordinate the
      // contact carried, and readers that measure would have nothing.
      expect((our['lat'], our['lon']), (center.latitude, center.longitude));
    });

    testWidgets('emptied, the contact follows its operation again', (tester) async {
      await placeOperation(tester, 'FN31pr');
      final existing = (await tester.runAsync(
        () => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW'},
          'our': {'call': 'KI2D', 'grid': 'FN20aa', 'lat': 40.02, 'lon': -73.95},
          'band': '20m',
          'mode': 'SSB',
        }),
      ))!;
      await tester.pumpWidget(host(session: LoggingSession(editingQso: existing)));
      await tester.pump();
      await openPane(tester);
      expect(tester.widget<TextField>(ourGrid()).controller!.text, isNotEmpty);

      await tester.enterText(ourGrid(), '');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));

      final our = await savedOur(tester, (our) => our['lat'] == null);
      // Only the grid cleared, the old pair would go on placing the contact.
      expect((our['grid'], our['lat'], our['lon']), (null, null, null));
      final saved = (await tester.runAsync(() => qsos.get(existing.uuid)))!;
      expect(saved.ourLocation, isNull, reason: 'the operation answers for a contact with no place of its own');
    });

    testWidgets('opened and saved untouched, a contact gains no place', (tester) async {
      // The hint is the operation's location: taken as a value, every
      // contact merely opened would be pinned there, and stop following a
      // later correction to the operation.
      await placeOperation(tester, 'FN31pr');
      await tester.pumpWidget(host());
      await tester.pump();
      await startContact(tester, 'W1AW');
      await openPane(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final our = (await waitForQsos(tester, 1)).single.data['our'] as Map;
      expect(our.containsKey('grid'), isFalse);
      expect(our.containsKey('lat'), isFalse);
    });

    testWidgets('a grid that names no square refuses the save and says why, for either station', (tester) async {
      // Accepted, "FN3" is a square that names no place. Quietly dropped, the
      // pane would close as if it had taken what was typed.
      final existing = (await tester.runAsync(
        () => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW', 'grid': 'FN31pr'},
          'our': {'call': 'KI2D', 'grid': 'FN20aa', 'lat': 40.02, 'lon': -73.95},
          'band': '20m',
          'mode': 'SSB',
        }),
      ))!;
      await tester.pumpWidget(host(session: LoggingSession(editingQso: existing)));
      await tester.pump();
      await openPane(tester);
      await tester.enterText(ourGrid(), 'FN3');
      await tester.enterText(find.widgetWithText(TextField, 'Grid').last, 'FN31z');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Edit QSO'), findsOneWidget, reason: 'the pane stays open on what was typed');
      expect(find.text('Needs 4, 6, 8 or 10 characters, like FN31pr'), findsNWidgets(2));

      await tester.enterText(ourGrid(), 'FN30');
      await tester.enterText(find.widgetWithText(TextField, 'Grid').last, 'FN31pq');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Edit QSO'), findsNothing, reason: 'corrected, it saves');
      await tester.tap(find.byType(FilledButton));

      final logged = await waitForQsosWhere(tester, 'the edit to land', (logged) => (logged.single.data['our'] as Map)['grid'] == 'FN30');
      expect((logged.single.data['their'] as Map)['grid'], 'FN31pq');
    });

    testWidgets('a malformed grid already on the contact does not stand in the way of an unrelated edit', (tester) async {
      // ADIF allows a two-character GRIDSQUARE, and an import stores it as
      // written. Checked although untouched, it would refuse a note — and
      // the only way past, retyping the grid, would trade the measured
      // coordinate beside it for a square's center.
      final existing = (await tester.runAsync(
        () => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW', 'grid': 'FN', 'lat': 41.71, 'lon': -72.73},
          'our': {'call': 'KI2D', 'grid': 'FN'},
          'band': '20m',
          'mode': 'SSB',
        }),
      ))!;
      await tester.pumpWidget(host(session: LoggingSession(editingQso: existing)));
      await tester.pump();
      await openPane(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Notes').last, 'Worked from the porch');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Edit QSO'), findsNothing, reason: 'the note saves');
      await tester.tap(find.byType(FilledButton));

      final logged = await waitForQsosWhere(tester, 'the note to land', (logged) => logged.single.data['notes'] == 'Worked from the porch');
      expect(logged.single.data['their'], allOf(containsPair('grid', 'FN'), containsPair('lat', 41.71), containsPair('lon', -72.73)));
      expect(logged.single.data['our'], containsPair('grid', 'FN'));
    });

    testWidgets("a contact made before a break hints its segment's grid, not the operation's latest", (tester) async {
      // A rover's whole log: each break moves the station, and a contact
      // from the first stop falls back to where that stop was.
      await placeOperation(tester, 'FN31pr');
      final rows = (await tester.runAsync(() async {
        await qsos.addEvent(operation.uuid, kind: 'start', atMillis: 500, operation: {'grid': 'FN20aa'});
        final early = await qsos.add(operation.uuid, {
          'their': {'call': 'W1AW'},
          'our': {'call': 'KI2D'},
          'band': '20m',
          'startAtMillis': 1000,
        });
        await qsos.addEvent(operation.uuid, kind: 'break', atMillis: 2000, operation: {'grid': 'FN42aa'});
        return (early, await qsos.forOperation(operation.uuid));
      }))!;
      await tester.pumpWidget(
        host(
          log: LogHooks(operation: operation, qsosRepository: qsos, qsos: rows.$2),
          session: LoggingSession(editingQso: rows.$1),
        ),
      );
      await tester.pump();
      await openPane(tester);

      expect(tester.widget<TextField>(ourGrid()).decoration!.hintText, 'FN20aa');
    });
  });
}

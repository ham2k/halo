// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Editing an event/annotation row (NOTE, TODO, BREAK, …) in the panel: the
// row it shows, the text and done state it reads and writes, and saving.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();

  group('editing an event/annotation row', () {
    IconButton secondButton(WidgetTester tester, IconData icon) =>
        tester.widget<IconButton>(find.ancestor(of: find.byIcon(icon), matching: find.byType(IconButton)));

    testWidgets('a NOTE swaps the main fields for its label and text, and disables every pill but Time', (tester) async {
      final note = Qso(
        uuid: 'note-uuid',
        operationUuid: operation.uuid,
        data: {
          'band': 'event',
          'freq': 0,
          'mode': 'note',
          'our': {'call': 'EVENT'},
          'their': {'call': 'NOTE'},
          'event': {'event': 'note', 'note': 'check later'},
        },
      );

      await tester.pumpWidget(host(session: LoggingSession(editingQso: note)));

      // No callsign field — this isn't a contact — and the kind is plain
      // text, not a field: only NOTE/TODO's actual value is editable.
      expect(find.widgetWithText(TextField, 'Their call'), findsNothing);
      expect(find.text('NOTE'), findsOneWidget);
      final noteField = tester.widget<TextField>(find.widgetWithText(TextField, 'Note'));
      expect(noteField.controller!.text, 'check later');

      // Every pill still shows — Radio included — but only Time can be
      // opened; nothing else applies to a non-contact row.
      expect(find.byIcon(MdiIcons.clockOutline), findsOneWidget);
      expect(find.byIcon(MdiIcons.radio), findsOneWidget);
      ChoiceChip chipFor(IconData icon) => tester.widget<ChoiceChip>(find.ancestor(of: find.byIcon(icon), matching: find.byType(ChoiceChip)));
      expect(chipFor(MdiIcons.clockOutline).onSelected, isNotNull);
      expect(chipFor(MdiIcons.radio).onSelected, isNull);
    });

    testWidgets('the Radio chip shows the current VFO, not the event\'s own sentinel freq/mode', (tester) async {
      fakeRadio.setVfo('vfoA', freq: 14285, mode: 'CW');
      final marker = Qso(
        uuid: 'marker-uuid',
        operationUuid: operation.uuid,
        // freq: 0, mode: 'break' — meaningless for a Radio-control display,
        // unlike an ordinary QSO's own recorded freq/mode.
        data: {
          'band': 'event',
          'freq': 0,
          'mode': 'break',
          'event': {'event': 'break'},
        },
      );

      await tester.pumpWidget(
        host(
          session: LoggingSession(editingQso: marker),
          radio: baseRadio().copyWith(radioService: fakeRadio),
        ),
      );

      expect(find.text('14,285 • CW'), findsOneWidget);

      // Keeps following, too — a rig retuned at its own front panel while
      // the event stays open should still show up here.
      fakeRadio.setVfo('vfoA', freq: 7100, mode: 'SSB');
      await tester.pump();
      expect(find.text('7,100 • SSB'), findsOneWidget);
    });

    testWidgets('a BREAK marker (no editable field) still fills the row to a text field\'s height', (tester) async {
      final note = Qso(
        uuid: 'note-uuid',
        operationUuid: operation.uuid,
        data: {
          'band': 'event',
          'freq': 0,
          'mode': 'note',
          'our': {'call': 'EVENT'},
          'their': {'call': 'NOTE'},
          'event': {'event': 'note', 'note': 'check later'},
        },
      );
      final marker = Qso(
        uuid: 'marker-uuid',
        operationUuid: operation.uuid,
        data: {
          'band': 'event',
          'freq': 0,
          'mode': 'break',
          'event': {'event': 'break'},
        },
      );

      await tester.pumpWidget(host(session: LoggingSession(editingQso: note)));
      final noteButtonHeight = tester.getSize(find.byType(FilledButton)).height;

      await tester.pumpWidget(host(session: LoggingSession(editingQso: marker)));
      await tester.pump();
      final markerButtonHeight = tester.getSize(find.byType(FilledButton)).height;

      // A BREAK's row is just the kind label, plain text with nothing as
      // tall as a text field — the invisible InputDecorator floor
      // `EventFieldRow` wraps it in reserves that height anyway, or
      // IntrinsicHeight would shrink the submit button beside it.
      expect(markerButtonHeight, noteButtonHeight);
    });

    testWidgets('a SOLAR row (read-only description, no editable field) also matches that height', (tester) async {
      final note = Qso(
        uuid: 'note-uuid',
        operationUuid: operation.uuid,
        data: {
          'band': 'event',
          'freq': 0,
          'mode': 'note',
          'our': {'call': 'EVENT'},
          'their': {'call': 'NOTE'},
          'event': {'event': 'note', 'note': 'check later'},
        },
      );
      final solar = Qso(
        uuid: 'solar-uuid',
        operationUuid: operation.uuid,
        data: {
          'band': 'event',
          'freq': 0,
          'mode': 'solar',
          'our': {'call': 'EVENT'},
          'their': {'call': 'SOLAR'},
          'event': {'event': 'solar', 'description': 'SFI 120, A 5, K 2'},
        },
      );

      await tester.pumpWidget(host(session: LoggingSession(editingQso: note)));
      final noteButtonHeight = tester.getSize(find.byType(FilledButton)).height;

      await tester.pumpWidget(host(session: LoggingSession(editingQso: solar)));
      await tester.pump();
      final solarButtonHeight = tester.getSize(find.byType(FilledButton)).height;

      // A real field's height comes from `poloFieldDecoration`'s own
      // explicit vertical content padding, which the app's ambient theme
      // never sets — a decorator that leaves contentPadding unset falls
      // back to the ambient default instead and drifts short.
      expect(solarButtonHeight, noteButtonHeight);
    });

    testWidgets('the pending-delete warning names the event kind, not "QSO"', (tester) async {
      final marker = (await tester.runAsync(
        () => qsos.add(operation.uuid, {
          'band': 'event',
          'freq': 0,
          'mode': 'break',
          'event': {'event': 'break'},
        }),
      ))!;

      await tester.pumpWidget(host(session: LoggingSession(editingQso: marker)));
      await tester.tap(find.byIcon(MdiIcons.trashCanOutline));
      await tester.pump();

      expect(find.textContaining('BREAK will be deleted'), findsOneWidget);
      expect(find.textContaining('QSO will be deleted'), findsNothing);
    });

    testWidgets('editing a NOTE and saving writes the new text back through the repository', (tester) async {
      final note = (await tester.runAsync(
        () => qsos.add(operation.uuid, {
          'band': 'event',
          'freq': 0,
          'mode': 'note',
          'our': {'call': 'EVENT'},
          'their': {'call': 'NOTE'},
          'event': {'event': 'note', 'note': 'check later'},
        }),
      ))!;

      var canceled = false;
      await tester.pumpWidget(
        host(
          session: LoggingSession(editingQso: note, onEditCanceled: () => canceled = true),
        ),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Note'), 'call back tomorrow');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await waitForQsosWhere(tester, 'the edited note', (logged) => logged.single.event?['note'] == 'call back tomorrow');

      expect(canceled, isTrue);
    });

    testWidgets("a TODO's checkbox and text both round-trip through save", (tester) async {
      final todo = (await tester.runAsync(
        () => qsos.add(operation.uuid, {
          'band': 'event',
          'freq': 0,
          'mode': 'todo',
          'our': {'call': 'EVENT'},
          'their': {'call': 'TODO'},
          'event': {
            'event': 'todo',
            'note': 'check later',
            'data': {'done': false},
          },
        }),
      ))!;

      var canceled = false;
      await tester.pumpWidget(
        host(
          session: LoggingSession(editingQso: todo, onEditCanceled: () => canceled = true),
        ),
      );

      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await waitForQsosWhere(tester, 'the TODO checked', (logged) => (logged.single.event?['data'] as Map?)?['done'] == true);
      expect(canceled, isTrue);
    });

    testWidgets('unchecking a legacy TODO (bare event.done, no event.data) actually sticks', (tester) async {
      final legacyTodo = (await tester.runAsync(
        () => qsos.add(operation.uuid, {
          'band': 'event',
          'freq': 0,
          'mode': 'todo',
          'our': {'call': 'EVENT'},
          'their': {'call': 'TODO'},
          // Older synced logs store done as a bare field, not event.data.done
          // (see eventFieldsFromData's fallback) — saving must clear
          // this one too, or the OR'd read-back keeps reviving `true`.
          'event': {'event': 'todo', 'note': 'check later', 'done': true},
        }),
      ))!;

      await tester.pumpWidget(host(session: LoggingSession(editingQso: legacyTodo)));
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      final stored = (await waitForQsosWhere(tester, 'the TODO unchecked', (logged) => (logged.single.event?['data'] as Map?)?['done'] == false)).single;
      expect(stored.event?['done'], isNot(true));
    });

    testWidgets('editing a NOTE synced in under "description" (not "note") saves back to that key', (tester) async {
      final synced = (await tester.runAsync(
        () => qsos.add(operation.uuid, {
          'band': 'event',
          'freq': 0,
          'mode': 'note',
          'our': {'call': 'EVENT'},
          'their': {'call': 'NOTE'},
          // AnnotationRow reads description before note (qso_list.dart)
          // — a row synced in under that key must keep agreeing with what
          // the log shows for it after an edit, not silently gain a
          // separate `note` nothing displays.
          'event': {'event': 'note', 'description': 'check later'},
        }),
      ))!;

      await tester.pumpWidget(host(session: LoggingSession(editingQso: synced)));
      final noteField = tester.widget<TextField>(find.widgetWithText(TextField, 'Note'));
      expect(noteField.controller!.text, 'check later');

      await tester.enterText(find.widgetWithText(TextField, 'Note'), 'call back tomorrow');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      final stored = (await waitForQsosWhere(tester, 'the edited description', (logged) => logged.single.event?['description'] == 'call back tomorrow')).single;
      expect(stored.event?['note'], isNull);
    });

    testWidgets('Enter from the QSO list focuses a NOTE\'s text field, not an unmounted callsign field', (tester) async {
      final note = Qso(
        uuid: 'note-uuid',
        operationUuid: operation.uuid,
        data: {
          'band': 'event',
          'freq': 0,
          'mode': 'note',
          'our': {'call': 'EVENT'},
          'their': {'call': 'NOTE'},
          'event': {'event': 'note', 'note': 'check later'},
        },
      );
      final controller = LoggingControlsController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              session: LoggingSession(editingQso: note, controller: controller),
              radio: baseRadio(),
            ),
          ),
        ),
      );
      final noteField = tester.widget<TextField>(find.widgetWithText(TextField, 'Note'));

      // Simulates logging_panel.dart's own Enter handler, which hands the
      // keyboard back to the panel through this same imperative call
      // (`_loggingController.focusLastPrimaryField()`).
      controller.focusLastPrimaryField();
      await tester.pump();

      expect(noteField.focusNode!.hasFocus, isTrue);
    });

    testWidgets('a NOTE synced in with incidental whitespace does not read as changed just from being selected', (tester) async {
      final untrimmed = Qso(
        uuid: 'note-uuid',
        operationUuid: operation.uuid,
        data: {
          'band': 'event',
          'freq': 0,
          'mode': 'note',
          'our': {'call': 'EVENT'},
          'their': {'call': 'NOTE'},
          'event': {'event': 'note', 'note': 'check later '},
        },
      );

      await tester.pumpWidget(host(session: LoggingSession(editingQso: untrimmed)));

      // Nothing was typed — the second button must still read Delete, not
      // Revert (which comparing an untrimmed load against a trimmed save
      // candidate would wrongly report as "already changed").
      expect(find.byIcon(MdiIcons.trashCanOutline), findsOneWidget);
      expect(find.byIcon(MdiIcons.undo), findsNothing);
    });

    testWidgets("a TODO with a non-Map event.data degrades instead of crashing the panel", (tester) async {
      final malformed = Qso(
        uuid: 'todo-uuid',
        operationUuid: operation.uuid,
        data: {
          'band': 'event',
          'freq': 0,
          'mode': 'todo',
          'our': {'call': 'EVENT'},
          'their': {'call': 'TODO'},
          // A cross-client/malformed record: `data` isn't a Map.
          'event': {'event': 'todo', 'note': 'check later', 'data': 'oops'},
        },
      );

      await tester.pumpWidget(host(session: LoggingSession(editingQso: malformed)));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    });

    testWidgets('an unmodified event offers Delete (not Revert); saving while pending soft-deletes it', (tester) async {
      final deleteIcon = MdiIcons.trashCanOutline;
      final undoIcon = MdiIcons.undo;
      final note = (await tester.runAsync(
        () => qsos.add(operation.uuid, {
          'band': 'event',
          'freq': 0,
          'mode': 'note',
          'our': {'call': 'EVENT'},
          'their': {'call': 'NOTE'},
          'event': {'event': 'note', 'note': 'check later'},
        }),
      ))!;

      var deleted = false;
      await tester.pumpWidget(
        host(
          session: LoggingSession(editingQso: note, onEditCanceled: () => deleted = true),
        ),
      );

      // Nothing was touched, so the second button reads Delete, exactly as
      // it would for an unmodified QSO — not Revert, which comparing against
      // `QsoDraft.toData()` (a QSO's own fields, all blank here) would
      // wrongly read as "always changed".
      expect(secondButton(tester, deleteIcon).onPressed, isNotNull);

      await tester.tap(find.byIcon(deleteIcon));
      await tester.pump();
      expect(find.byIcon(undoIcon), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      for (var i = 0; i < 20 && !deleted; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      final stored = (await tester.runAsync(() => qsos.watchForOperation(operation.uuid, includeDeleted: true).first))!.single;
      expect(stored.deleted, isTrue);
      expect(deleted, isTrue);
    });
  });
}

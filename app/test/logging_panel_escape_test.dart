// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Issue #199's follow-up: Escape must deselect the current QSO even when
// nothing inside LoggingControls' own compose form has focus — e.g. a QSO
// selected by tapping its row in the list, which never focuses anything
// inside LoggingControls (a sibling widget). LoggingPanel wraps both in its
// own CallbackShortcuts for exactly this gap; these tests exercise THAT
// outer path specifically (tapping a list row, not typing into a field),
// plus the "press Escape again to undo" behavior it and LoggingControls'
// own inner Escape handling share.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/logging_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;
  late Operation operation;
  late Qso qso;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    services = HaLoServices(db, settings);
    operation = await services.operations.create(stationCall: 'N0CALL', title: 'Test Op');
    qso = await services.qsos.add(operation.uuid, {
      'their': {'call': 'W1AW', 'sent': '59'},
      'mode': 'SSB',
    });
  });

  Widget wrap(Widget child) => TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      );

  // The info row's second button's tooltip is 'Wipe'/'Undo' while composing
  // a new QSO, 'Delete'/'Revert'/'Restore' while editing one — a more
  // direct signal for "is a QSO selected" than matching its icon, which
  // depends on whether the fields still exactly match the record (Delete
  // vs Revert), not on selection itself.
  bool isEditing(WidgetTester tester) {
    final tooltips = tester.widgetList<IconButton>(find.byType(IconButton)).map((b) => b.tooltip).toSet();
    return tooltips.contains('Delete') || tooltips.contains('Revert') || tooltips.contains('Restore');
  }

  // Same rationale as `isEditing` for using tooltip over icon/`find.byTooltip`
  // (which looks for a `Tooltip` widget, not `IconButton.tooltip`) — matches
  // the info row's second button regardless of which state it's showing.
  Finder infoRowButton(String tooltip) =>
      find.byWidgetPredicate((w) => w is IconButton && w.tooltip == tooltip);

  testWidgets('Escape deselects a QSO selected via the list, even though the tap never focused a compose field',
      (tester) async {
    await tester.pumpWidget(wrap(LoggingPanel(
      operation: operation,
      services: services,
      qsos: [qso],
      loggingControls: const [],
      onCommandAction: (action, [params]) async {},
    )));
    await tester.pump(const Duration(milliseconds: 100));

    expect(isEditing(tester), isFalse);

    await tester.tap(find.text('W1AW'));
    await tester.pump();
    expect(isEditing(tester), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    // Back to composing a new QSO — nothing is being edited anymore, even
    // though the tap that selected it never focused a compose field.
    expect(isEditing(tester), isFalse);
  });

  testWidgets('a second Escape re-selects the QSO the first one deselected', (tester) async {
    await tester.pumpWidget(wrap(LoggingPanel(
      operation: operation,
      services: services,
      qsos: [qso],
      loggingControls: const [],
      onCommandAction: (action, [params]) async {},
    )));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('W1AW'));
    await tester.pump();
    expect(isEditing(tester), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(isEditing(tester), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    // Re-selected: back to editing the same QSO, its own Rcvd value shown
    // ('their.sent' — what THEY sent, i.e. what we received).
    expect(isEditing(tester), isTrue);
    final rcvdField = tester.widget<TextField>(find.widgetWithText(TextField, 'Rcvd'));
    expect(rcvdField.controller!.text, '59');
  });

  testWidgets('Escape does not close an already-deleted QSO\'s locked, read-only view', (tester) async {
    // A deleted QSO's fields are locked read-only (disabled/AbsorbPointer'd),
    // so nothing inside LoggingControls can ever hold focus — the outer
    // CallbackShortcuts this panel added for issue #199's follow-up is the
    // only Escape handler that can fire here, and it must defer to
    // LoggingControls' own "must not blank a locked view" invariant instead
    // of blindly deselecting.
    final deletedQso = Qso(uuid: qso.uuid, operationUuid: qso.operationUuid, data: qso.data, deleted: true);

    await tester.pumpWidget(wrap(LoggingPanel(
      operation: operation,
      services: services,
      qsos: [deletedQso],
      loggingControls: const [],
      onCommandAction: (action, [params]) async {},
    )));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('W1AW'));
    await tester.pump();
    expect(infoRowButton('Restore'), findsOneWidget, reason: 'a deleted QSO offers Restore, not Delete');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    // Still locked on the same QSO — Escape must not have deselected it.
    expect(infoRowButton('Restore'), findsOneWidget);
  });

  testWidgets('selecting a different QSO drops a pending deselect-undo, so a later Escape does not resurrect it',
      (tester) async {
    final qso2 = await services.qsos.add(operation.uuid, {
      'their': {'call': 'K1ABC', 'sent': '55'},
      'mode': 'SSB',
    });

    await tester.pumpWidget(wrap(LoggingPanel(
      operation: operation,
      services: services,
      qsos: [qso, qso2],
      loggingControls: const [],
      onCommandAction: (action, [params]) async {},
    )));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('W1AW'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape); // deselects W1AW, offers undo
    await tester.pump();
    expect(isEditing(tester), isFalse);

    // Select K1ABC directly (not via Escape) — the pending "undo" for W1AW
    // must not survive this, since it's no longer the QSO the user most
    // recently backed out of. `find.widgetWithText(InkWell, ...)` targets
    // the list row specifically, since selecting it also echoes 'K1ABC'
    // into the compose form's own call field, which plain `find.text`
    // would ambiguously match too.
    final row = find.widgetWithText(InkWell, 'K1ABC');
    await tester.tap(row);
    await tester.pump();
    expect(isEditing(tester), isTrue);
    await tester.tap(row); // toggle it back off
    await tester.pump();
    expect(isEditing(tester), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    // Nothing to undo anymore — W1AW's stale undo slot was cleared by the
    // K1ABC selection, so this Escape is a no-op, not a resurrection of W1AW.
    expect(isEditing(tester), isFalse);
  });
}

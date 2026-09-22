// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Issue #199's follow-up: Escape must deselect the current QSO even when
// nothing inside LoggingControls' own compose form has focus — e.g. a QSO
// selected by tapping its row in the list, which never focuses anything
// inside LoggingControls (a sibling widget). LoggingPanel wraps both in its
// own CallbackShortcuts for exactly this gap; these tests exercise THAT
// outer path specifically (tapping a list row, not typing into a field).
//
// Escape deselects and stops there. It used to toggle — a second press
// re-selected what the first had dropped — until APP-19's focus ladder made
// Escape uniformly the way out of wherever the keyboard is.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/lookup_queue_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
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
    // Selecting a QSO for editing now enqueues it for a background lookup
    // (ham2k/halo-dist#279's follow-up) — the default LookupQueueService
    // waits (real time) for the extension runtime to report ready, which
    // never happens in these widget tests and leaves a timer pending past
    // teardown. A no-op lookup with no wait budget keeps the queue instant
    // and inert here; its own repos/status bar just read/write the same
    // underlying db as `services`' own (unused otherwise in these tests).
    services = HaLoServices(
      db,
      settings,
      lookupQueue: LookupQueueService(
        lookup: (call, {required qso, required operation, required online, recentContext = false}) async => null,
        qsos: QsosRepository(db),
        operations: OperationsRepository(db),
        statusBar: StatusBarService(settings.prefs),
        runtimeWaitBudget: Duration.zero,
      ),
    );
    operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');
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

  // The info row's second button's accessible name is 'Wipe'/'Undo' while
  // composing a new QSO, 'Delete'/'Revert'/'Restore' while editing one — a
  // more direct signal for "is a QSO selected" than matching its icon, which
  // depends on whether the fields still exactly match the record (Delete
  // vs Revert), not on selection itself. (The app has no hover tooltips —
  // user-interface.md — so the name lives on the Icon's semanticLabel.)
  bool isEditing(WidgetTester tester) {
    final labels = tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.semanticLabel).toSet();
    return labels.contains('Delete') || labels.contains('Revert') || labels.contains('Restore');
  }

  // Matches the info row's second button regardless of which state it's
  // showing. Finds the Icon (which carries the name) and walks up to the
  // button, so `tap` hits the whole target rather than the glyph.
  Finder infoRowButton(String label) => find.ancestor(
        of: find.byWidgetPredicate((w) => w is Icon && w.semanticLabel == label),
        matching: find.byType(IconButton),
      );

  testWidgets('Escape deselects a QSO selected via the list, even though the tap never focused a compose field',
      (tester) async {
    await tester.pumpWidget(wrap(LoggingPanel(
      operation: operation,
      services: services,
      qsos: [qso],
      loggingControls: const [],
      onCommandAction: (action, [params]) async {},
    )));
    // A single QSO is well under the count where QsoList's first build is
    // worth deferring behind a spinner (HALO-258), so it renders directly —
    // but the wrap above still needs a frame to settle before W1AW is
    // findable.
    await tester.pump();

    expect(isEditing(tester), isFalse);

    await tester.tap(find.text('W1AW'));
    await tester.pump();
    expect(isEditing(tester), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    // Back to composing a new QSO — nothing is being edited anymore, even
    // though the tap that selected it never focused a compose field.
    expect(isEditing(tester), isFalse);
    await drainLookupQueueTimer(tester);
  });

  testWidgets('an Escape that stops keying does not also end the QSO edit', (tester) async {
    // OperationView's HardwareKeyboard handler stops the keying, and the
    // logging fields hear the same keystroke AFTER it. Were they to ask
    // "is anything running?" again, the stop just made would read as
    // nothing, and one Escape would kill the repeat AND drop the edit.
    await services.settings.setExperimentEnabled('gato', true);
    await services.settings.setExperimentEnabled('keyer', true);
    // Stands in for OperationView's handler: same place in the dispatch,
    // same call.
    bool viewHandler(KeyEvent event) {
      if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape) return false;
      return services.cat.stopKeying();
    }

    HardwareKeyboard.instance.addHandler(viewHandler);
    addTearDown(() => HardwareKeyboard.instance.removeHandler(viewHandler));

    await tester.pumpWidget(wrap(LoggingPanel(
      operation: operation,
      services: services,
      qsos: [qso],
      loggingControls: const [],
      onCommandAction: (action, [params]) async {},
    )));
    await tester.pump();
    await tester.tap(find.text('W1AW'));
    await tester.pump();
    expect(isEditing(tester), isTrue);

    services.cat.armKeyerRepeat(delay: const Duration(seconds: 3), text: 'CQ', send: () {});
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(services.cat.keyerRepeating, isFalse, reason: 'the repeat stopped');
    expect(isEditing(tester), isTrue, reason: 'and that Escape was spent on it');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(isEditing(tester), isFalse, reason: 'with nothing running, Escape is the way out again');
    await drainLookupQueueTimer(tester);
  });

  testWidgets('the same holds with focus in a compose field', (tester) async {
    // The fields' own Escape (LoggingSession.escapeClaimed), not the
    // panel's: the two read the same answer from the one stop.
    await services.settings.setExperimentEnabled('gato', true);
    await services.settings.setExperimentEnabled('keyer', true);
    bool viewHandler(KeyEvent event) {
      if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape) return false;
      return services.cat.stopKeying();
    }

    HardwareKeyboard.instance.addHandler(viewHandler);
    addTearDown(() => HardwareKeyboard.instance.removeHandler(viewHandler));

    await tester.pumpWidget(wrap(LoggingPanel(
      operation: operation,
      services: services,
      qsos: [qso],
      loggingControls: const [],
      onCommandAction: (action, [params]) async {},
    )));
    await tester.pump();
    await tester.tap(find.text('W1AW'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextField, 'Their call'));
    await tester.pump();
    expect(isEditing(tester), isTrue);

    services.cat.armKeyerRepeat(delay: const Duration(seconds: 3), text: 'CQ', send: () {});
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(services.cat.keyerRepeating, isFalse);
    expect(isEditing(tester), isTrue);
    await drainLookupQueueTimer(tester);
  });

  testWidgets('a second Escape does NOT re-select the QSO the first one deselected', (tester) async {
    // Escape used to toggle: a second press within a few seconds brought the
    // QSO back, mirroring the compose form's wipe-undo. APP-19 removed that.
    // Under the focus ladder Escape is uniformly the way *out* of wherever the
    // keyboard is — an operator pressing it twice is backing further out, and
    // landing back in the editor they just left is the one outcome that makes
    // the gesture unpredictable.
    await tester.pumpWidget(wrap(LoggingPanel(
      operation: operation,
      services: services,
      qsos: [qso],
      loggingControls: const [],
      onCommandAction: (action, [params]) async {},
    )));
    await tester.pump();

    await tester.tap(find.text('W1AW'));
    await tester.pump();
    expect(isEditing(tester), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(isEditing(tester), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    // Still composing a new QSO — not back in the editor. The callsign is the
    // check that actually distinguishes the two: re-selecting would load
    // 'W1AW' back into the form. (Rcvd wouldn't — '59' is also the default
    // report for SSB, so it reads the same either way.)
    expect(isEditing(tester), isFalse);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, isEmpty);
    await drainLookupQueueTimer(tester);
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
    await tester.pump();

    await tester.tap(find.text('W1AW'));
    await tester.pump();
    expect(infoRowButton('Restore'), findsOneWidget, reason: 'a deleted QSO offers Restore, not Delete');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    // Still locked on the same QSO — Escape must not have deselected it.
    expect(infoRowButton('Restore'), findsOneWidget);
    await drainLookupQueueTimer(tester);
  });

  // A staged delete disables every field in LoggingControls, so nothing in
  // there holds the keyboard and its own chord handler never sees the key.
  // Drop the panel-level forwarder and this undo is reachable by mouse only.
  testWidgets('Cmd+Z takes back a staged delete, though no compose field can hold focus', (tester) async {
    // A record the form loads and reads back unchanged. The shared `qso` is
    // not one: selecting it offers Revert, and there is no Delete to stage.
    final complete = await services.qsos.add(operation.uuid, {
      'their': {'call': 'K2HAM', 'sent': '59'},
      'our': {'call': 'N0CALL', 'sent': '59'},
      'mode': 'SSB',
    });
    await tester.pumpWidget(wrap(LoggingPanel(
      operation: operation,
      services: services,
      qsos: [complete],
      loggingControls: const [],
      onCommandAction: (action, [params]) async {},
    )));
    await tester.pump();

    await tester.tap(find.text('K2HAM'));
    await tester.pump();
    await tester.tap(infoRowButton('Delete'));
    await tester.pump();
    expect(infoRowButton('Undo delete'), findsOneWidget, reason: 'the delete is staged');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    expect(infoRowButton('Delete'), findsOneWidget, reason: 'back to an unmodified QSO being edited');
    await drainLookupQueueTimer(tester);
  });
}

/// Selecting a QSO for editing now enqueues it for a background lookup
/// (ham2k/halo-dist#279's follow-up). Once that (stubbed, instant)
/// lookup completes, `StatusBarService.setProgress` schedules a 5s
/// auto-clear timer for the finished progress item — drain it before the
/// test ends, or the framework flags it as a leaked pending timer.
Future<void> drainLookupQueueTimer(WidgetTester tester) => tester.pump(const Duration(seconds: 5));

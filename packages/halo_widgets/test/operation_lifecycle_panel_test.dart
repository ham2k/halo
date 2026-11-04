// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the logging panel does with an operation's lifecycle: when
// the entry row is replaced by a status read, who is offered a transition,
// and the one way back in that does not need a button.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

const _minute = 60 * 1000;

String _label(String status) => switch (status) {
  OperationStatus.paused => 'Paused',
  OperationStatus.processed => 'Log Sent',
  OperationStatus.archived => 'Archived',
  _ => 'Operation Completed',
};

OperationLifecycleSpec _spec({
  String? status,
  int? lastActivityMillis,
  String? dateRange,
  VoidCallback? onStart,
  VoidCallback? onPause,
  VoidCallback? onReopen,
  VoidCallback? onEnd,
  VoidCallback? onExports,
}) => OperationLifecycleSpec(
  status: status,
  lastActivityMillis: lastActivityMillis,
  statusLabel: _label,
  dateRange: dateRange,
  onStart: onStart,
  onPause: onPause,
  onReopen: onReopen,
  onEnd: onEnd,
  onExports: onExports,
);

void main() {
  group('what the panel shows', () {
    test('a log being written keeps its entry row', () {
      final now = nowMillis();
      expect(_spec(status: OperationStatus.active, lastActivityMillis: now).readingAt(now), isNull);
      expect(_spec(status: OperationStatus.fresh).readingAt(now), isNull);
      expect(_spec(status: OperationStatus.ready).readingAt(now), isNull);
      // Nothing has derived a status yet — the operation is no less live for
      // it, and a panel that locked on a null would lock every operation the
      // sweep has not reached.
      expect(_spec().readingAt(now), isNull);
    });

    test('an empty status is not started, as the commands and the sweep take it', () {
      // A blob can carry the status as `''`. Read as started here, the panel
      // would hide START over a log the commands would happily start.
      expect(_spec(status: '').notStarted, isTrue);
      expect(_spec(status: 'someday').notStarted, isFalse, reason: 'a newer build wrote it; this one cannot say it is unstarted');
    });

    test('every closed state reads as itself', () {
      final now = nowMillis();
      expect(_spec(status: OperationStatus.paused).readingAt(now), 'Paused');
      expect(_spec(status: OperationStatus.completed).readingAt(now), 'Operation Completed');
      expect(_spec(status: OperationStatus.processed).readingAt(now), 'Log Sent');
      expect(_spec(status: OperationStatus.archived).readingAt(now), 'Archived');
    });

    test('an active operation reads as paused after half an hour of quiet', () {
      final now = 1000 * _minute;
      final quiet = _spec(status: OperationStatus.active, lastActivityMillis: now - 31 * _minute);
      final busy = _spec(status: OperationStatus.active, lastActivityMillis: now - 29 * _minute);
      expect(quiet.readingAt(now), 'Paused');
      expect(busy.readingAt(now), isNull);
      // And the RECORD is untouched by the reading: the stored status still
      // says `active`, which is what an uploader reads as "may still change".
      // Nothing may write a status from this.
      expect(quiet.status, OperationStatus.active);
    });

    test('restarting a quiet operation brings the row back', () {
      // The whole lifecycle rests on RESTART being one tap away — the export
      // panel locks the entry row mid-activation on that promise. The value
      // fed in here is what decides it: a restart writes `statusAtMillis` and
      // NEVER `startAtMillisMax`, because event rows are excluded from the
      // operation counters. Measured from the last contact alone, the reading
      // stays "Paused" after the tap and the operator is locked out of a log
      // they just asked to reopen, with no working control at all.
      final now = 1000 * _minute;
      final justRestarted = Operation(
        uuid: 'op',
        qsoCount: 40,
        // Last contact hours ago; the status stamped a moment ago.
        startAtMillisMax: now - 300 * _minute,
        data: {'status': OperationStatus.active, 'statusAtMillis': now},
      );
      final spec = _spec(status: OperationStatus.active, lastActivityMillis: operationLastActivityMillis(justRestarted));
      expect(spec.readingAt(now), isNull);
    });

    test('a quiet reading needs something to measure from', () {
      // A brand-new operation with no contacts and no status stamp has no
      // silence to speak of. Treating the missing value as zero would read
      // every such operation as quiet since 1970.
      final now = 1000 * _minute;
      expect(_spec(status: OperationStatus.active).readingAt(now), isNull);
    });

    test('a character held for a refused reopening is gone when the row comes back later', () {
      // Delivered whenever the row returns, the K typed at a refused
      // reopening would land in the call field minutes later, when the
      // operator presses Continue and has typed nothing.
      addTearDown(AppClock.instance.reset);
      final gate = OperationLifecycleGate()..spec = _spec(status: OperationStatus.completed);
      addTearDown(gate.dispose);
      gate.holdForReopen('K');
      AppClock.instance.travel(delta: const Duration(minutes: 2));
      gate.spec = _spec(status: OperationStatus.active, lastActivityMillis: nowMillis());
      expect(gate.takePendingCharacter(), isNull);
    });

    test('a callsign typed at a closed log reopens it once, and arrives whole', () {
      // Each key reopening on its own overwrites the one before: K1ABC typed
      // at speed lands as C, after five restarts of the same log.
      var reopens = 0;
      final gate = OperationLifecycleGate()..spec = _spec(status: OperationStatus.completed, onReopen: () => reopens++);
      addTearDown(gate.dispose);
      for (final key in 'K1ABC'.split('')) {
        gate.holdForReopen(key);
      }
      expect(reopens, 1);
      gate.spec = _spec(status: OperationStatus.active, lastActivityMillis: nowMillis());
      expect(gate.takePendingCharacter(), 'K1ABC');
    });

    test('pause yields the slot to the wipe for any draft, not just a typed call', () {
      // Keyed on the call field alone, ⏸ would take the slot from a draft
      // whose exchange or notes are already typed, leaving no way to clear it.
      final spec = _spec(status: OperationStatus.active, onPause: () {});
      List<String> slot({required bool composed}) => [
        for (final c in operationLifecycleControls(spec, locked: false, labelPause: false, hasComposedValues: composed, editing: false)) c.key,
      ];
      expect(slot(composed: false), ['pause']);
      expect(slot(composed: true), isEmpty);
    });
  });

  testWidgets('the corner slot reserves the whole of a labelled button', (tester) async {
    // Reserved short, the button paints over the end of the stats line beside it.
    const control = (key: 'start', icon: Icons.play_arrow, label: 'Mark the start', prominent: true, onPressed: _noop);
    late double reserved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) {
                reserved = operationLifecycleSlotWidth(context, const [control], diameter: 44);
                return OperationLifecycleSlot(controls: const [control], accentTheme: Theme.of(context), diameter: 44);
              },
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(FilledButton)).width, lessThanOrEqualTo(reserved));
  });

  testWidgets('a paused read fits a narrow panel', (tester) async {
    // A title that cannot shrink overflows the row at a phone's width, or
    // under a translation longer than "Paused for 3h 20m".
    final gate = OperationLifecycleGate()..spec = _spec(status: OperationStatus.paused, lastActivityMillis: nowMillis() - 3 * 3600 * 1000);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 120,
                child: Builder(
                  builder: (context) => OperationLifecycleRead(gate: gate, accentTheme: Theme.of(context), diameter: 44),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('Paused for'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Both the title and the gate ride the shared once-a-second clock, whose
    // timer stands while anything listens.
    await tester.pumpWidget(const SizedBox());
    gate.dispose();
  });

  testWidgets('a paused read with no rate to show keeps the count', (tester) async {
    // The pause leaves the count to its title and the rate below it; the
    // summary drops a rate that rounds to nothing, and with the count gone
    // too the read would say how long the log stood still and nothing of
    // what is in it.
    final gate = OperationLifecycleGate()..spec = _spec(status: OperationStatus.paused, lastActivityMillis: nowMillis() - 3 * 3600 * 1000);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => OperationLifecycleRead(gate: gate, accentTheme: Theme.of(context), diameter: 44, summary: const ['1 QSO in 11d']),
            ),
          ),
        ),
      ),
    );
    expect(find.text('1 QSO in 11d'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    gate.dispose();
  });

  group('the panel', () {
    late HaLoDatabase db;
    late QsosRepository qsos;

    setUp(() {
      db = HaLoDatabase(NativeDatabase.memory());
      qsos = QsosRepository(db);
    });

    tearDown(() async => db.close());

    Widget host(OperationLifecycleSpec spec, {Qso? editingQso}) => MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          log: LogHooks(
            operation: const Operation(uuid: 'op', data: {'stationCall': 'N0DEV'}),
            qsosRepository: qsos,
            lifecycle: spec,
          ),
          session: LoggingSession(editingQso: editingQso),
        ),
      ),
    );

    testWidgets('replaces the entry row with the status read', (tester) async {
      await tester.pumpWidget(host(_spec(status: OperationStatus.completed, dateRange: 'Apr 12 – Apr 14, 2026', onReopen: () {}, onExports: () {})));
      await tester.pump();

      expect(find.text('Operation Completed'), findsOneWidget);
      expect(find.text('Apr 12 – Apr 14, 2026'), findsOneWidget);
      // The row is GONE, not merely disabled. A dimmed callsign field reads
      // as "you may type here in a moment", which is what a finished log
      // does not mean.
      expect(find.bySemanticsIdentifier('field.call'), findsNothing);
    });

    testWidgets('labels pause after a few quiet minutes, with the row still live', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(_spec(status: OperationStatus.active, lastActivityMillis: nowMillis() - 4 * 60 * 1000, onPause: () {})));
      await tester.pump();

      expect(find.bySemanticsIdentifier('action.lifecycle.pause'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
      // The row is LIVE. An operator calling CQ into a dead band has not
      // paused, and nothing here writes a status — only the button does.
      expect(find.bySemanticsIdentifier('field.call'), findsOneWidget);
      expect(find.text('Paused'), findsNothing);
      handle.dispose();
    });

    testWidgets('the label arrives on the heartbeat, without its own timer', (tester) async {
      // The boundary has to cross while the operator sits there, so this
      // exercises the mechanism rather than the pure function: the clock the
      // panel READS is travelled, and the shared heartbeat is what notices.
      // Pumping a fake timer without moving that clock would pass while
      // testing nothing (time.md §7).
      addTearDown(AppClock.instance.reset);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(_spec(status: OperationStatus.active, lastActivityMillis: nowMillis(), onPause: () {})));
      await tester.pump();
      // Between contacts the slot is ⏸ from the start, as a bare glyph.
      expect(find.bySemanticsIdentifier('action.lifecycle.pause'), findsOneWidget);
      expect(find.text('Pause'), findsNothing);

      AppClock.instance.travel(delta: const Duration(minutes: 4));
      // One heartbeat tick. A minute-granular clock would leave this failing
      // for up to a minute after the boundary passed.
      await tester.pump(const Duration(seconds: 1));

      expect(find.bySemanticsIdentifier('action.lifecycle.pause'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('keeps the wipe button while something is composed', (tester) async {
      // The slot only takes the wipe button's place when there is nothing to
      // wipe. An operator part-way through a callsign wants the control they
      // reached for, and logging that contact ends the silence anyway.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(_spec(status: OperationStatus.active, lastActivityMillis: nowMillis() - 4 * 60 * 1000, onPause: () {})));
      await tester.pump();
      await tester.enterText(find.bySemanticsIdentifier('field.call'), 'K1A');
      await tester.pump();

      expect(find.bySemanticsIdentifier('action.lifecycle.pause'), findsNothing);
      expect(find.bySemanticsIdentifier('action.wipe'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the pause offer gives way to the read, not stacked on it', (tester) async {
      // Past the quiet boundary the read carries Reopen and the slot carries
      // DONE. A third control there would be one too many, and would be the
      // same slot offering two answers to the same question.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(_spec(status: OperationStatus.active, lastActivityMillis: nowMillis() - 40 * 60 * 1000, onPause: () {}, onReopen: () {}, onEnd: () {})),
      );
      await tester.pump();

      expect(find.bySemanticsIdentifier('action.lifecycle.pause'), findsNothing);
      expect(find.bySemanticsIdentifier('action.lifecycle.end'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a paused log offers Reopen beside the read and DONE in the slot', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(_spec(status: OperationStatus.paused, onReopen: () {}, onEnd: () {}, onExports: () {})));
      await tester.pump();

      expect(find.bySemanticsIdentifier('action.lifecycle.reopen'), findsOneWidget);
      // Keyed on the ROLE, never on the label: the id is a hook for agent and
      // browser tooling (#236), and a Spanish build's "Terminar" has to be
      // found by the same one as "Done".
      expect(find.bySemanticsIdentifier('action.lifecycle.end'), findsOneWidget);
      // Not yet finished, so exports are not what is left to do.
      expect(find.bySemanticsIdentifier('action.lifecycle.exports'), findsNothing);
      // The wipe button is what the slot gives up — there is nothing composed
      // to wipe, and two meanings in one corner is one too many.
      expect(find.bySemanticsIdentifier('action.wipe'), findsNothing);
      handle.dispose();
    });

    testWidgets('a finished log offers Exports instead of DONE', (tester) async {
      // DONE has nothing left to say to a log the operator already declared
      // finished; its exports are the only thing left to do with one.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(_spec(status: OperationStatus.completed, onReopen: () {}, onEnd: () {}, onExports: () {})));
      await tester.pump();

      expect(find.bySemanticsIdentifier('action.lifecycle.exports'), findsOneWidget);
      expect(find.bySemanticsIdentifier('action.lifecycle.end'), findsNothing);
      expect(find.bySemanticsIdentifier('action.lifecycle.reopen'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('offers START, labelled, before the operation has been logged into', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(_spec(status: OperationStatus.ready, onStart: () {})));
      await tester.pump();

      expect(find.bySemanticsIdentifier('action.lifecycle.start'), findsOneWidget);
      // Written out, not a bare glyph. START is the one lifecycle control an
      // operator has to FIND: the others answer a question the panel has just
      // put to them in the row below, while this one sits in a slot they last
      // saw holding a wipe button.
      expect(find.text('Mark the start'), findsOneWidget);
      // The row stays live: pressing START is never a precondition for
      // logging, and the first contact starts the operation on its own.
      expect(find.bySemanticsIdentifier('field.call'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the labelled button fits a narrow panel at a raised text scale', (tester) async {
      // The reserve the info area keeps clear is MEASURED (theme.dart's
      // `textWidth`), not a fixed number, because the label is translated and
      // the text scaler moves under it. A layout overflow throws in a widget
      // test, so this fails loudly rather than clipping "Start" on a phone.
      await tester.binding.setSurfaceSize(const Size(360, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.9), size: Size(360, 760)),
          child: host(_spec(status: OperationStatus.ready, onStart: () {})),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Mark the start'), findsOneWidget);
    });

    testWidgets('the way back names what it does: Continue a pause, Restart a finished log', (tester) async {
      // Both write the same `restart` row, but they answer different
      // sentences on the read's left: a paused log is picked back up, a
      // finished one is undone. One label for both misdescribes one of them.
      await tester.pumpWidget(host(_spec(status: OperationStatus.paused, onReopen: () {}, onEnd: () {})));
      await tester.pump();
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Restart'), findsNothing);
      expect(find.text('Finish operation'), findsOneWidget);

      await tester.pumpWidget(host(_spec(status: OperationStatus.completed, onReopen: () {}, onExports: () {})));
      await tester.pump();
      expect(find.text('Restart'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
    });

    testWidgets('without a spec the panel is the one it always was', (tester) async {
      // How the experiment is gated: no spec, no lifecycle. The failure this
      // guards is a half-gate — the controls hidden while the row still
      // locks, leaving the operator with nothing on screen to reopen it — so
      // the entry row is what gets asserted, not the buttons' absence.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: LogHooks(
                operation: const Operation(uuid: 'op', data: {'stationCall': 'N0DEV'}),
                qsosRepository: qsos,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.bySemanticsIdentifier('field.call'), findsOneWidget);
      expect(find.text('Operation Completed'), findsNothing);
    });

    testWidgets('leaves an existing QSO editable in a finished operation', (tester) async {
      // Locking says "you are not sitting at the radio any more", not "this
      // log is frozen" — and an edit is what reverts a sent log to
      // `completed`, so barring it would cut off the correction too.
      await tester.pumpWidget(
        host(
          _spec(status: OperationStatus.completed, onReopen: () {}, onExports: () {}),
          editingQso: Qso(
            uuid: 'q1',
            operationUuid: 'op',
            data: const {
              'band': '20m',
              'mode': 'CW',
              'their': {'call': 'W1AW'},
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Operation Completed'), findsNothing);
      expect(find.bySemanticsIdentifier('field.call'), findsOneWidget);
    });

    testWidgets('a typed character reopens the operation', (tester) async {
      // The one way back that needs no button: an operator who simply starts
      // typing a callsign should not have to find a control first. This is
      // the documented exception to logging-fields.md's "locked means
      // unfocusable".
      var restarts = 0;
      await tester.pumpWidget(host(_spec(status: OperationStatus.paused, onReopen: () => restarts++, onEnd: () {})));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.pump();
      expect(restarts, 1);
    });

    testWidgets('the typed character survives the rebuilds the reopening causes', (tester) async {
      // Reopening writes its event rows BEFORE it writes the status, and each
      // write wakes the operation's stream — so frames land with the row
      // still replaced. A character consumed by the first of those is the
      // operator's first keystroke vanishing.
      var spec = _spec(status: OperationStatus.paused, onReopen: () {}, onEnd: () {});
      late StateSetter setOuter;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setOuter = setState;
                return LoggingControls(
                  log: LogHooks(
                    operation: const Operation(uuid: 'op', data: {'stationCall': 'N0DEV'}),
                    qsosRepository: qsos,
                    lifecycle: spec,
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      // Two rebuilds with the operation still closed — the event rows landing.
      setOuter(() => spec = _spec(status: OperationStatus.paused, onReopen: () {}, onEnd: () {}));
      await tester.pump();
      setOuter(() => spec = _spec(status: OperationStatus.paused, onReopen: () {}, onEnd: () {}));
      await tester.pump();
      // And now the status write lands.
      setOuter(() => spec = _spec(status: OperationStatus.active, lastActivityMillis: nowMillis(), onEnd: () {}));
      await tester.pump();
      await tester.pump();

      // Upper-cased: this lands in the call field without meeting its own
      // formatters, and a stray lowercase character in a field that upper-
      // cases everything after it is the operator's callsign looking wrong.
      expect(find.text('W'), findsOneWidget);
    });

    testWidgets('a half-typed contact keeps the entry row', (tester) async {
      // An operator slow-working a rare station is more than half an hour
      // past their last LOGGED contact. Replacing the row on the heartbeat
      // would take the call they are typing away AND lock them out of
      // finishing it.
      var spec = _spec(status: OperationStatus.active, lastActivityMillis: nowMillis());
      late StateSetter setOuter;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setOuter = setState;
                return LoggingControls(
                  log: LogHooks(
                    operation: const Operation(uuid: 'op', data: {'stationCall': 'N0DEV'}),
                    qsosRepository: qsos,
                    lifecycle: spec,
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(find.bySemanticsIdentifier('field.call'), 'K1A');
      await tester.pump();

      // The boundary crosses under them, mid-callsign.
      setOuter(() => spec = _spec(status: OperationStatus.active, lastActivityMillis: nowMillis() - 40 * 60 * 1000, onReopen: () {}, onEnd: () {}));
      await tester.pump();

      expect(find.text('Paused'), findsNothing);
      expect(find.bySemanticsIdentifier('field.call'), findsOneWidget);
      expect(find.text('K1A'), findsOneWidget);
    });

    testWidgets('navigation keys do not reopen it', (tester) async {
      // Tab, the arrows and Escape move a operator PAST a paused operation.
      // Restarting on those would reopen a log they were only walking by.
      var restarts = 0;
      await tester.pumpWidget(host(_spec(status: OperationStatus.paused, onReopen: () => restarts++, onEnd: () {})));
      await tester.pump();

      for (final key in [LogicalKeyboardKey.tab, LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.escape, LogicalKeyboardKey.shiftLeft]) {
        await tester.sendKeyEvent(key);
        await tester.pump();
      }
      expect(restarts, 0);
    });
  });
}

void _noop() {}

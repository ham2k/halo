// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// START / BREAK / STOP / ROVERQTH through `HaLoServices.handleCommandAction`:
// the segment rows they write, and what a location edit afterwards does to
// them. The trap is the segments model itself (docs/design/contests.md
// §5.1.3): a `break` states what is true AFTER it and the base operation is
// only a default, so a break that merely restated the old square would pin
// every later contact to it, and a log with no `start` would move every
// EARLIER contact to the new one. `SegmentedOperation` is the judge here,
// not the row contents.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/operation_lifecycle_commands.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;
  late Operation operation;

  setUp(() async {
    // An empty host: the Location screen waits on a runtime for its
    // controls, and a service with none would keep it waiting forever. The one
    // stub is `ref:satellite`'s handler, which implements no
    // `suggestOperationTitle` — the runtime answers that with null.
    final harness = await makeHaLoServices(stubs: {'ref:satellite:null:suggestOperationTitle': null});
    services = harness.services;

    final created = await services.operations.create(stationCall: 'N0DEV');
    operation = Operation(uuid: created.uuid, data: {...created.data, 'grid': 'FN31pr'});
    await services.operations.saveData(operation);
    await services.qsos.add(operation.uuid, {
      'their': {'call': 'KN2X'},
      'band': '3cm',
      'startAtMillis': 10000,
    });
    await services.qsos.add(operation.uuid, {
      'their': {'call': 'W2ABC'},
      'band': '3cm',
      'startAtMillis': 20000,
    });
  });

  Future<List<Qso>> rows() => services.qsos.forOperation(operation.uuid);
  List<Qso> eventRows(List<Qso> all) => [
    for (final q in all)
      if (q.isEvent) q,
  ];
  List<Qso> segmentRows(List<Qso> all) => [
    for (final q in all)
      if (q.isEvent && eventKindOpensSegment(q.eventKind)) q,
  ];
  String? overrideGrid(Qso row) => (row.event?['operation'] as Map?)?['grid'] as String?;
  Future<CommandActionOutcome?> mark(String kind, {bool setLocation = false}) =>
      services.handleCommandAction('markSegment', {'kind': kind, 'uuid': operation.uuid, if (setLocation) 'setLocation': true});

  test('START puts a start row one second before the first contact, restating the operation', () async {
    expect(await mark('start'), isNull);
    final segments = segmentRows(await rows());
    expect(segments.map((q) => q.eventKind), ['start']);
    expect(segments.single.startAtMillis, 9000, reason: 'one second before the first contact, as polo places it');
    expect(overrideGrid(segments.single), 'FN31pr');
    // A complete statement: refs travel too, and an absent fix is said, not omitted.
    final override = segments.single.event!['operation'] as Map;
    expect(override.containsKey('refs'), isTrue);
    expect(override.containsKey('lat'), isTrue);
    // What the list shows — no refs here, so the square alone.
    expect(segments.single.event!['description'], 'At FN31pr');
  });

  test('START on a started log adds nothing, and says so rather than confirming a move', () async {
    await mark('start');
    final outcome = await mark('start');
    expect(segmentRows(await rows()).map((q) => q.eventKind), ['start']);
    // The hook's confirm already said "Operation started"; a silent success
    // would read as though the marker had moved to now.
    expect(outcome?.failed, isTrue);
  });

  test('START on a finished log is refused too, rather than reopening it with no restart', () async {
    // Let through, the log goes live with the finish still the last row of
    // its timeline, and nothing to show where it came back.
    await mark('start');
    await mark('stop');
    final outcome = await mark('start');
    expect(outcome?.failed, isTrue);
    expect((await services.operations.get(operation.uuid))!.status, OperationStatus.completed);
  });

  test('START on a paused log with no start row is refused, rather than reopening it with no restart', () async {
    // A log filled without pressing START has no `start` row to refuse on,
    // and the sweep pauses such logs; let through, START would back-date a
    // start and run the log on from a timeline that ends on its pause.
    await services.operations.setStatus(operation.uuid, OperationStatus.paused);
    final outcome = await mark('start');
    expect(outcome?.failed, isTrue);
    expect(eventRows(await rows()), isEmpty);
    expect((await services.operations.get(operation.uuid))!.status, OperationStatus.paused);
  });

  test('START on an active log missing its marker gets one', () async {
    // The contacts made it active; START still owes the timeline its start.
    await services.operations.setStatus(operation.uuid, OperationStatus.active);
    expect(await mark('start'), isNull);
    expect(segmentRows(await rows()).map((q) => q.eventKind), ['start']);
  });

  test('STOP on a sent log writes its stop and leaves it sent', () async {
    // Moved back to completed, the log would tell an uploader its uploads
    // went stale when no contact changed, and its archive clock would stop.
    await mark('start');
    await services.operations.setStatus(operation.uuid, OperationStatus.processed);
    expect(await mark('stop'), isNull);
    expect(eventRows(await rows()).map((q) => q.eventKind), ['start', 'stop']);
    expect((await services.operations.get(operation.uuid))!.status, OperationStatus.processed);
  });

  test('PAUSE writes a pause row of its own kind, which opens no segment', () async {
    // Written as a `break`, it would be a boundary: every contact after the
    // operator came back would resolve to whatever that break restated, or —
    // carrying nothing — the scorers would read a new segment out of a lunch
    // stop.
    await mark('start');
    expect(await mark('pause'), isNull);
    final all = await rows();
    expect(eventRows(all).map((q) => q.eventKind), ['start', 'pause']);
    expect(segmentRows(all).map((q) => q.eventKind), ['start']);
    expect((await services.operations.get(operation.uuid))!.status, OperationStatus.paused);
  });

  group('lifecycle rows collapse at the end of the log', () {
    // Each move the operator makes with nothing logged in between is a
    // correction of the last one, not a new fact. Stacked, a quiet hour of
    // stepping away leaves a ladder of markers, and every one of them is a
    // "Restarted after" row and a slice of paused time the stats count.
    // A test call: the travelled clock writes to nothing else.
    setUp(() async {
      addTearDown(AppClock.instance.reset);
      operation = Operation(uuid: operation.uuid, data: {...operation.data, 'stationCall': 'N0DEV/T'});
      await services.operations.saveData(operation);
    });
    Future<List<String?>> kinds() async => eventRows(await rows()).map((q) => q.eventKind).toList();
    Future<Qso> only(String kind) async => eventRows(await rows()).singleWhere((q) => q.eventKind == kind);

    test('a restart inside a minute takes the pause back outright', () async {
      await mark('start');
      await mark('pause');
      AppClock.instance.travel(delta: const Duration(seconds: 50));
      await mark('restart');
      expect(await kinds(), ['start']);
      expect((await services.operations.get(operation.uuid))!.status, OperationStatus.active);
    });

    test('pausing again with nothing logged folds back into the first pause', () async {
      await mark('start');
      await mark('pause');
      final pause = await only('pause');
      AppClock.instance.travel(delta: const Duration(minutes: 5));
      await mark('restart');
      expect(await kinds(), ['start', 'pause', 'restart']);
      AppClock.instance.travel(delta: const Duration(minutes: 5));
      await mark('pause');
      expect(await kinds(), ['start', 'pause']);
      expect((await only('pause')).uuid, pause.uuid);
      final stored = (await services.operations.get(operation.uuid))!;
      expect(stored.status, OperationStatus.paused);
      // Stamped now, the panel would read "Paused for 0m" over a pause ten
      // minutes old, and count those minutes as active.
      expect(stored.statusAtMillis, pause.startAtMillis);
    });

    test('a contact in between keeps both pauses', () async {
      await mark('start');
      await mark('pause');
      AppClock.instance.travel(delta: const Duration(minutes: 5));
      await mark('restart');
      await services.qsos.add(operation.uuid, {
        'their': {'call': 'K1AB'},
        'band': '3cm',
        'startAtMillis': nowMillis(),
      });
      AppClock.instance.travel(delta: const Duration(minutes: 5));
      await mark('pause');
      expect(await kinds(), ['start', 'pause', 'restart', 'pause']);
    });

    test('finishing a paused log turns the pause into the finish, at the pause', () async {
      await mark('start');
      await mark('pause');
      final pause = await only('pause');
      AppClock.instance.travel(delta: const Duration(hours: 2));
      await mark('stop');
      expect(await kinds(), ['start', 'stop']);
      final stop = await only('stop');
      // The same row, not a delete and a fresh write: what a peer already
      // holds is changed, not tombstoned beside a new one.
      expect(stop.uuid, pause.uuid);
      expect(stop.startAtMillis, pause.startAtMillis);
    });

    test('Finish on a log the panel shows as quiet dates the finish to where the silence began', () async {
      // With no pause row to fold into, a finish stamped at the press counts
      // every idle hour since the last contact as time spent on the air.
      await mark('start');
      final contactAt = nowMillis();
      await services.qsos.add(operation.uuid, {
        'their': {'call': 'K1AB'},
        'band': '3cm',
        'startAtMillis': contactAt,
      });
      AppClock.instance.travel(delta: const Duration(hours: 2));
      await services.moveOperationLifecycle(operation.uuid, 'stop');
      expect((await only('stop')).startAtMillis, contactAt);

      // Inside the panel's quiet window the operator is still at the radio,
      // and the finish is when they said so.
      await mark('restart');
      await services.qsos.add(operation.uuid, {
        'their': {'call': 'K2CD'},
        'band': '3cm',
        'startAtMillis': nowMillis(),
      });
      AppClock.instance.travel(delta: const Duration(minutes: 10));
      final pressedAt = nowMillis();
      await services.moveOperationLifecycle(operation.uuid, 'stop');
      expect((await only('stop')).startAtMillis, greaterThanOrEqualTo(pressedAt));
    });

    test('a typed STOP stops at now, however quiet the log has been', () async {
      // The panel's Finish dates from a pause it was showing; a typed STOP
      // was shown none, and back-dated it would move the log's end to a time
      // the operator never named. The row's time is theirs to edit.
      await mark('start');
      await services.qsos.add(operation.uuid, {
        'their': {'call': 'K1AB'},
        'band': '3cm',
        'startAtMillis': nowMillis(),
      });
      AppClock.instance.travel(delta: const Duration(hours: 2));
      final typedAt = nowMillis();
      await mark('stop');
      expect((await only('stop')).startAtMillis, greaterThanOrEqualTo(typedAt));
    });

    test('a finish counts the activity the panel saw, not only the record\'s', () async {
      // An old log being typed in leaves contacts dated hours back and no
      // write per entry. Dated from the record alone, finishing after an hour
      // of typing would put the finish at the first old contact.
      await mark('start');
      await services.qsos.add(operation.uuid, {
        'their': {'call': 'K1AB'},
        'band': '3cm',
        'startAtMillis': nowMillis() - 5 * 60 * 60 * 1000,
      });
      AppClock.instance.travel(delta: const Duration(hours: 1));
      final pressedAt = nowMillis();
      await services.moveOperationLifecycle(operation.uuid, 'stop', lastActivityMillis: pressedAt - 60 * 1000);
      expect((await only('stop')).startAtMillis, greaterThanOrEqualTo(pressedAt));
    });

    test('a move that fails for any other reason tells the operator, rather than leaving a button that did nothing', () async {
      // Caught for refusals alone, a database error escapes the unawaited
      // call as an unhandled one and the operator hears nothing.
      await services.db.close();
      await services.moveOperationLifecycle(operation.uuid, 'pause');
      expect(services.statusBar.activeNotices.map((notice) => notice.key), contains('operation-lifecycle'));
    });

    test('a double-tap on Continue reopens the log once', () async {
      // Both taps read the timeline before either has written: each sees no
      // restart yet, and the log gains two.
      await mark('start');
      await mark('pause');
      AppClock.instance.travel(delta: const Duration(minutes: 30));
      await Future.wait([services.moveOperationLifecycle(operation.uuid, 'restart'), services.moveOperationLifecycle(operation.uuid, 'restart')]);
      expect(await kinds(), ['start', 'pause', 'restart']);
    });

    test('restarting a finished log turns the finish into a pause, or takes it back inside a minute', () async {
      await mark('start');
      await mark('stop');
      await mark('restart');
      expect(await kinds(), ['start']);

      await mark('stop');
      final stop = await only('stop');
      AppClock.instance.travel(delta: const Duration(minutes: 30));
      await mark('restart');
      // A `stop` left behind would still close a segment in a log that runs on.
      expect(await kinds(), ['start', 'pause', 'restart']);
      final pause = await only('pause');
      expect(pause.uuid, stop.uuid);
      expect(pause.startAtMillis, stop.startAtMillis);
      expect(pause.event?['operation'], isNull);
    });

    test('pause, finish, restart, pause leaves one pause, the first row throughout', () async {
      await mark('start');
      await mark('pause');
      final pause = await only('pause');
      AppClock.instance.travel(delta: const Duration(minutes: 5));
      await mark('stop');
      AppClock.instance.travel(delta: const Duration(minutes: 5));
      await mark('restart');
      AppClock.instance.travel(delta: const Duration(minutes: 5));
      await mark('pause');
      expect(await kinds(), ['start', 'pause']);
      expect((await only('pause')).uuid, pause.uuid);
    });

    test('a restart taken back by a pause comes back as the same row, leaving no tombstone', () async {
      await mark('start');
      await mark('pause');
      await mark('stop');
      AppClock.instance.travel(delta: const Duration(minutes: 25));
      await mark('restart');
      final restart = await only('restart');
      await mark('pause');
      await mark('stop');
      AppClock.instance.travel(delta: const Duration(minutes: 3));
      await mark('restart');
      expect(await kinds(), ['start', 'pause', 'restart']);
      expect((await only('restart')).uuid, restart.uuid);
      final all = await services.qsos.forOperation(operation.uuid, includeDeleted: true);
      expect(all.where((q) => q.deleted), isEmpty);
    });

    test('a pause taken back at once is deleted, and the contact after it follows as usual', () async {
      await mark('start');
      await mark('pause');
      final pause = await only('pause');
      await mark('restart');
      await services.qsos.add(operation.uuid, {
        'their': {'call': 'K1AB'},
        'band': '3cm',
        'startAtMillis': nowMillis(),
      });
      expect(await kinds(), ['start']);
      final withDeleted = await services.qsos.forOperation(operation.uuid, includeDeleted: true);
      expect(withDeleted.singleWhere((q) => q.uuid == pause.uuid).deleted, isTrue);
      expect((await services.operations.get(operation.uuid))!.status, OperationStatus.active);
    });
  });

  test('an unrecognized kind names the real fault instead of borrowing the no-operation message', () async {
    // A word no kind will ever be: an example that later becomes a real kind
    // turns this red for a reason that has nothing to do with what it guards.
    final outcome = await services.handleCommandAction('markSegment', {'kind': 'zzz', 'uuid': operation.uuid});
    expect(outcome?.failed, isTrue);
    expect(outcome!.text, isNot(t.commands.noOperationOpen));
  });

  test('a reference that offers no title still gets a description written', () async {
    // Plenty of ref types legitimately have no `suggestOperationTitle`
    // (`ref:satellite` registers none, so its handler answers nothing).
    // Treating that as a failure would leave every segment row on such an
    // operation permanently without a description.
    await services.operations.saveData(
      Operation(
        uuid: operation.uuid,
        data: {
          ...operation.data,
          'refs': [
            {'type': 'satellite', 'ref': 'AO-91'},
          ],
        },
      ),
    );
    await mark('break');
    expect(segmentRows(await rows()).last.event!['description'], 'Now at FN31pr');
  });

  test('a restamp that cannot compose a description clears the old one rather than leaving it beside a new override', () async {
    // The dangerous shape: the row would say "Now at FN31pr" while its override
    // says FN20aa, and sync that contradiction everywhere. Cleared, the row
    // falls back to the square its own override states.
    await mark('break');
    expect(segmentRows(await rows()).last.event!['description'], 'Now at FN31pr');

    final throwing = HaLoServices(services.db, services.settings, extensions: ExtensionServiceWithFakeHost(_ThrowingTitleHost()));
    await throwing.operations.saveData(
      Operation(
        uuid: operation.uuid,
        data: {
          ...operation.data,
          'refs': [
            {'type': 'pota', 'ref': 'US-0001'},
          ],
          'grid': 'FN20aa',
        },
      ),
    );

    final row = segmentRows(await rows()).last;
    expect((row.event!['operation'] as Map)['grid'], 'FN20aa');
    expect(row.event!.containsKey('description'), isFalse);
  });

  test('a description that could not be composed IN FULL is not written on a new row', () async {
    // A hook that throws leaves a phrase missing from an otherwise complete
    // sentence, and nothing recomposes it: persisting the truncated line
    // would replace a good description with a worse one on every later
    // edit, on every device.
    final throwing = HaLoServices(services.db, services.settings, extensions: ExtensionServiceWithFakeHost(_ThrowingTitleHost()));
    await throwing.operations.saveData(
      Operation(
        uuid: operation.uuid,
        data: {
          ...operation.data,
          'refs': [
            {'type': 'pota', 'ref': 'US-0001'},
          ],
        },
      ),
    );
    await throwing.handleCommandAction('markSegment', {'kind': 'break', 'uuid': operation.uuid});
    final written = segmentRows(await rows()).last;
    expect(written.event!.containsKey('description'), isFalse);
  });

  test('BREAK on a log with no segments first adds the start, so the earlier contacts keep what they had', () async {
    // No navigator mounted, so nothing can open — the rows alone are the point.
    expect(await mark('break'), isNull);
    final segments = segmentRows(await rows());
    expect(segments.map((q) => q.eventKind), ['start', 'break']);
    expect(segments[0].startAtMillis, 9000);
    expect(overrideGrid(segments[1]), 'FN31pr', reason: 'until the operation moves, the break restates where it is');
  });

  test('a second BREAK adds only a break', () async {
    await mark('break');
    await mark('break');
    expect(segmentRows(await rows()).map((q) => q.eventKind), ['start', 'break', 'break']);
  });

  test('STOP writes a stop row, and a second STOP moves it rather than stacking another', () async {
    await mark('stop');
    final first = eventRows(await rows()).where((q) => q.eventKind == 'stop').single;
    await mark('stop');
    final stops = eventRows(await rows()).where((q) => q.eventKind == 'stop').toList();
    expect(stops, hasLength(1));
    expect(stops.single.uuid, first.uuid);
    // A stop opens no segment: the log still resolves to the base operation.
    expect(SegmentedOperation.from(operation: operation.data, qsos: await rows()).isSegmented, isFalse);
  });

  test('a plain location edit after BREAK restamps the break, not the start', () async {
    // The segments model replaces rather than tracks (contests.md §5.1.3):
    // without the restamp a rover who uses the Location screen instead of
    // ROVERQTH keeps scoring every later contact from the old square.
    await mark('break');
    await services.operations.saveData(Operation(uuid: operation.uuid, data: {...operation.data, 'grid': 'FN20aa'}));

    final all = await rows();
    final segments = segmentRows(all);
    expect(overrideGrid(segments[0]), 'FN31pr');
    expect(overrideGrid(segments[1]), 'FN20aa');
    expect(segments[1].event!['description'], 'Now at FN20aa', reason: 'the row says where the stretch is now');
    final segmented = SegmentedOperation.from(operation: {...operation.data, 'grid': 'FN20aa'}, qsos: all);
    expect(segmented.effectiveAt(10000)['grid'], 'FN31pr');
    expect(segmented.current['grid'], 'FN20aa');
  });

  test('a refs edit restamps too, and an edit that changes nothing a segment restates does not write', () async {
    await mark('break');
    final before = segmentRows(await rows()).last;
    await services.operations.saveData(Operation(uuid: operation.uuid, data: {...operation.data, 'userTitle': 'Renamed'}));
    final unchanged = segmentRows(await rows()).last;
    expect(unchanged.data['updatedAtMillis'], before.data['updatedAtMillis'], reason: 'a no-op restamp is a revision every device would receive');

    await services.operations.saveData(
      Operation(
        uuid: operation.uuid,
        data: {
          ...operation.data,
          'refs': [
            {'type': 'pota', 'ref': 'US-0001'},
          ],
        },
      ),
    );
    final restamped = segmentRows(await rows()).last;
    expect(((restamped.event!['operation'] as Map)['refs'] as List).single['ref'], 'US-0001');
  });

  test('every segment row is re-worded on save, not just the one whose override moved', () async {
    // A row's description is composed from the operation's title, so a change
    // to how a stretch is worded — a party naming its county, a reference
    // renamed — has to reach rows already written, and a plain save is when
    // the log is next in hand. Rows written by an earlier build carry its
    // wording until then.
    await mark('break');
    for (final row in segmentRows(await rows())) {
      await services.qsos.update(
        Qso(
          uuid: row.uuid,
          operationUuid: row.operationUuid,
          data: {
            ...row.data,
            'event': {...row.event!, 'description': 'at FN31pr'},
          },
        ),
      );
    }
    await services.operations.saveData(Operation(uuid: operation.uuid, data: {...operation.data, 'userTitle': 'Renamed'}));

    final segments = segmentRows(await rows());
    expect(segments[0].event!['description'], 'At FN31pr', reason: 'the start keeps its own override, re-worded');
    expect(segments[1].event!['description'], 'Now at FN31pr');
    expect(overrideGrid(segments[0]), 'FN31pr', reason: 're-wording never moves an earlier segment');
  });

  test('with no operation it reports that rather than writing nowhere', () async {
    final outcome = await services.handleCommandAction('markSegment', {'kind': 'break', 'uuid': 'no-such-operation'});
    expect(outcome?.failed, isTrue);
  });

  testWidgets('ROVERQTH: the location chosen afterwards lands on the operation AND the break, so only later contacts move', (tester) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(navigatorKey: navigatorKey, home: const Scaffold()),
      ),
    );

    final done = mark('break', setLocation: true);
    await tester.pumpAndSettle();

    final gridField = find.widgetWithText(TextField, t.operationLocationScreen.gridSquare);
    expect(gridField, findsOneWidget, reason: 'the Location screen opens on the app navigator');
    await tester.enterText(gridField, 'FN20aa');
    await tester.tap(find.widgetWithText(FilledButton, t.common.save));
    await tester.pumpAndSettle();
    expect(await done, isNull);

    final saved = await services.operations.get(operation.uuid);
    expect(saved!.grid, 'FN20aa');

    final all = await rows();
    final segments = segmentRows(all);
    expect(overrideGrid(segments[0]), 'FN31pr', reason: 'the start keeps the square the earlier contacts were made from');
    expect(overrideGrid(segments[1]), 'FN20aa', reason: 'the break now states the new square');

    // What scoring will actually read: the earlier contacts stay put, and a
    // contact made now is at the new square — even though the base operation
    // moved. A break left at FN31pr would fail the second; a missing start
    // would fail the first.
    final segmented = SegmentedOperation.from(operation: saved.data, qsos: all);
    expect(segmented.effectiveAt(10000)['grid'], 'FN31pr');
    expect(segmented.effectiveAt(20000)['grid'], 'FN31pr');
    expect(segmented.current['grid'], 'FN20aa');
  });

  testWidgets('ROVERQTH: cancelling the location screen leaves a break at the old square, which scores as before', (tester) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(navigatorKey: navigatorKey, home: const Scaffold()),
      ),
    );

    final done = mark('break', setLocation: true);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, t.common.cancel));
    await tester.pumpAndSettle();
    expect(await done, isNull);

    expect((await services.operations.get(operation.uuid))!.grid, 'FN31pr');
    final segmented = SegmentedOperation.from(operation: operation.data, qsos: await rows());
    expect(segmented.current['grid'], 'FN31pr');
  });
}

/// A host whose `suggestOperationTitle` throws — the failure the
/// description guard exists for, which an ordinary mock (answering null)
/// cannot express.
class _ThrowingTitleHost extends FakeExtensionHost {
  _ThrowingTitleHost();

  @override
  Future<dynamic> invokeHook(String category, {String? key, required String method, Object? args, Duration timeout = const Duration(seconds: 10)}) async {
    if (method == 'suggestOperationTitle') throw StateError('hook is down');
    return super.invokeHook(category, key: key, method: method, args: args, timeout: timeout);
  }
}

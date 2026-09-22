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

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;
  late Operation operation;

  setUp(() async {
    // An empty host: the Location screen waits on a runtime for its
    // controls, and a service with none would keep it waiting forever.
    final harness = await makeHaLoServices();
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

  test('an unrecognized kind names the real fault instead of borrowing the no-operation message', () async {
    final outcome = await services.handleCommandAction('markSegment', {'kind': 'pause', 'uuid': operation.uuid});
    expect(outcome?.failed, isTrue);
    expect(outcome!.text, isNot(t.commands.noOperationOpen));
  });

  test('a reference that offers no title still gets a description written', () async {
    // Plenty of ref types legitimately have no `suggestOperationTitle`
    // (`ref:satellite` registers none), and the mock host answers for none
    // of them. Treating that as a failure would leave every segment row on
    // such an operation permanently without a description.
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

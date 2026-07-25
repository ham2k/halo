// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Serial numbers are the one derived-looking value that is actually data of
// record: the number went out on the air, so re-issuing one puts a duplicate in
// a contest log and gets QSOs removed by the sponsor. These tests encode the
// three invariants from docs/design/contests.md §5.8 — allocate once at commit,
// never re-issue, and rebuild the counter from the log rather than trusting it.

import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

const _serial = SequenceDescriptor(refType: 'cqwpx', field: 'serial', key: 'cqwpx/serial');
const _perBand = SequenceDescriptor(
  refType: 'test',
  field: 'serial',
  key: 'test/serial',
  scope: ['band'],
);

Map<String, dynamic> _qsoData({String call = 'N0CALL', String band = '20m', List? refs}) => {
      'band': band,
      'mode': 'CW',
      'their': {'call': call},
      if (refs != null) 'refs': refs,
    };

int? _serialOf(Qso qso, {String type = 'cqwpx'}) {
  for (final ref in qso.refs) {
    if (ref['type'] == type) return (ref['serial'] as num?)?.toInt();
  }
  return null;
}

void main() {
  late HaLoDatabase db;
  late QsosRepository qsos;
  late SequencesRepository sequences;
  late String op;

  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    sequences = SequencesRepository(db);
    qsos = QsosRepository(db, sequences: sequences);
    op = (await OperationsRepository(db).create(stationCall: 'N0DEV')).uuid;
  });

  tearDown(() async => db.close());

  test('numbers are issued in order, one per QSO', () async {
    final first = await qsos.add(op, _qsoData(), serialSequences: [_serial]);
    final second = await qsos.add(op, _qsoData(call: 'W1AW'), serialSequences: [_serial]);

    expect(_serialOf(first), 1);
    expect(_serialOf(second), 2);
  });

  test('a QSO logged without a contest gets no serial at all', () async {
    final qso = await qsos.add(op, _qsoData());
    expect(_serialOf(qso), isNull);
  });

  test('event rows never consume a number', () async {
    // NOTE/TODO/SOLAR annotations reach `add` through this same path carrying
    // `band: 'event'`. Numbering them would gap the contest log invisibly.
    await qsos.addEvent(op, kind: 'start', atMillis: 1000);
    final qso = await qsos.add(op, _qsoData(), serialSequences: [_serial]);
    expect(_serialOf(qso), 1);
  });

  test('deleting a QSO does not free its number for reuse', () async {
    final first = await qsos.add(op, _qsoData(), serialSequences: [_serial]);
    final second = await qsos.add(op, _qsoData(call: 'W1AW'), serialSequences: [_serial]);
    await qsos.softDelete(second);

    // 2 was sent on the air. A gap is fine with every sponsor; a duplicate is
    // not — so the next QSO must be 3, not 2.
    final third = await qsos.add(op, _qsoData(call: 'K1ABC'), serialSequences: [_serial]);
    expect(_serialOf(first), 1);
    expect(_serialOf(third), 3);
  });

  test('the counter survives a cold start with no stored row', () async {
    await qsos.add(op, _qsoData(), serialSequences: [_serial]);
    await qsos.add(op, _qsoData(call: 'W1AW'), serialSequences: [_serial]);

    // A fresh repository stands in for a restart, an inbound sync, or an ADIF
    // import — none of which write the counter row, all of which must still
    // continue the series rather than restart it.
    final rebuilt = SequencesRepository(db);
    expect(await rebuilt.peek(op, _serial.requestFor(Qso(uuid: 'x', operationUuid: op, data: _qsoData()))), 3);
  });

  test('an operator-typed number is kept, and the counter jumps past it', () async {
    final typed = await qsos.add(
      op,
      _qsoData(refs: [
        {'type': 'cqwpx', 'serial': 57},
      ]),
      serialSequences: [_serial],
    );
    expect(_serialOf(typed), 57, reason: 'what they sent on the air wins over what we would have picked');

    final next = await qsos.add(op, _qsoData(call: 'W1AW'), serialSequences: [_serial]);
    expect(_serialOf(next), 58);
  });

  test('a band-scoped sequence numbers each band separately', () async {
    final a = await qsos.add(op, _qsoData(band: '20m'), serialSequences: [_perBand]);
    final b = await qsos.add(op, _qsoData(call: 'W1AW', band: '40m'), serialSequences: [_perBand]);
    final c = await qsos.add(op, _qsoData(call: 'K1ABC', band: '20m'), serialSequences: [_perBand]);

    expect(_serialOf(a, type: 'test'), 1);
    expect(_serialOf(b, type: 'test'), 1);
    expect(_serialOf(c, type: 'test'), 2);
  });

  test('the label is resolved from the committed band, not the descriptor', () async {
    // The descriptor is fetched when the callsign lookup resolves; the operator
    // can still change band before pressing Enter. Resolving the label at
    // commit is what makes that safe.
    await qsos.add(op, _qsoData(band: '20m'), serialSequences: [_perBand]);
    final moved = await qsos.add(op, _qsoData(call: 'W1AW', band: '15m'), serialSequences: [_perBand]);
    expect(_serialOf(moved, type: 'test'), 1);
  });

  test('a serial ref coexists with the contest exchange already on it', () async {
    final qso = await qsos.add(
      op,
      _qsoData(refs: [
        {'type': 'cqwpx', 'exchange': '05'},
      ]),
      serialSequences: [_serial],
    );
    final ref = qso.refs.firstWhere((r) => r['type'] == 'cqwpx');
    expect(ref['exchange'], '05');
    expect(ref['serial'], 1);
  });

  test('two contests in one operation keep independent counters', () async {
    const other = SequenceDescriptor(refType: 'other', field: 'serial', key: 'other/serial');
    final first = await qsos.add(op, _qsoData(), serialSequences: [_serial, other]);
    final second = await qsos.add(op, _qsoData(call: 'W1AW'), serialSequences: [_serial, other]);

    expect(_serialOf(second), 2);
    expect(_serialOf(second, type: 'other'), 2);
    expect(_serialOf(first, type: 'other'), 1);
  });

  test('a start the operator set is not undone by numbers already logged', () async {
    final request = _serial.requestFor(Qso(uuid: 'x', operationUuid: op, data: _qsoData()));
    await qsos.add(op, _qsoData(), serialSequences: [_serial]);
    await qsos.add(op, _qsoData(call: 'W1AW'), serialSequences: [_serial]);

    // "I logged the first hour on paper, start me at 100."
    await sequences.setStart(op, request, 100);
    expect(await sequences.peek(op, request), 100);

    // But a start BELOW what's already on the air can't un-issue those numbers.
    await sequences.setStart(op, request, 2);
    expect(await sequences.peek(op, request), 3);
  });

  test('a memoized high-water mark is dropped when a QSO is edited', () async {
    // The memo makes the hot path O(1), but it is only ever safe to be too
    // HIGH. An edit can change a serial by hand without passing through the
    // allocator, so the memo has to be dropped or the next QSO re-issues a
    // number that already went on the air.
    final request = _serial.requestFor(Qso(uuid: 'x', operationUuid: op, data: _qsoData()));
    final first = await qsos.add(op, _qsoData(), serialSequences: [_serial]);
    expect(await sequences.peek(op, request), 2);

    await qsos.update(Qso(
      uuid: first.uuid,
      operationUuid: op,
      data: {
        ..._qsoData(),
        'uuid': first.uuid,
        'refs': [
          {'type': 'cqwpx', 'serial': 500},
        ],
      },
    ));

    expect(await sequences.peek(op, request), 501, reason: 'the hand-edited number must not be re-issued');
  });

  test('inbound sync drops the memo, so another device\'s numbers are not re-issued', () async {
    final request = _serial.requestFor(Qso(uuid: 'x', operationUuid: op, data: _qsoData()));
    await qsos.add(op, _qsoData(), serialSequences: [_serial]);
    expect(await sequences.peek(op, request), 2);

    // A second device logged numbers 2..40 and they arrive by sync.
    await qsos.mergeFromSync([
      {
        ..._qsoData(call: 'DL1ABC'),
        'uuid': 'from-other-device',
        'operation': op,
        'refs': [
          {'type': 'cqwpx', 'serial': 40},
        ],
      },
    ]);

    expect(await sequences.peek(op, request), 41);
  });

  test('a QSO imported with a serial but no declared sequence still raises the mark', () async {
    // An ADIF import calls `add` with no descriptors; the serial rides in on
    // the ref. We cannot know which labels it touched, so the memo is dropped.
    final request = _serial.requestFor(Qso(uuid: 'x', operationUuid: op, data: _qsoData()));
    await qsos.add(op, _qsoData(), serialSequences: [_serial]);
    expect(await sequences.peek(op, request), 2);

    await qsos.add(op, _qsoData(call: 'K1ABC', refs: [
      {'type': 'cqwpx', 'serial': 77},
    ]));

    expect(await sequences.peek(op, request), 78);
  });

  test('the memo survives ordinary logging, and stays exact', () async {
    // The whole point: repeated peeks must not re-derive, and must still agree
    // with a cold repository that has no memo at all.
    final request = _serial.requestFor(Qso(uuid: 'x', operationUuid: op, data: _qsoData()));
    for (var i = 0; i < 25; i++) {
      await qsos.add(op, _qsoData(call: 'W${i}AW'), serialSequences: [_serial]);
    }
    expect(await sequences.peek(op, request), 26);
    expect(await SequencesRepository(db).peek(op, request), 26, reason: 'memo agrees with a cold derive');
  });

  test('a scan in flight when the log changes must not memoize what it read', () async {
    // The memo is a read-modify-write across an `await`: the scan reads the log,
    // then assigns into `_derived`. An invalidation landing in that window used
    // to be undone by the assignment, pinning the PRE-invalidation mark forever
    // — and stale-low re-issues a number that already went on the air.
    //
    // Driven through `debugAfterScan` rather than by timing: an in-memory
    // database finishes the scan before a test could interleave anything, which
    // is exactly why the first version of this test passed against the bug.
    final request = _serial.requestFor(Qso(uuid: 'x', operationUuid: op, data: _qsoData()));
    await qsos.add(op, _qsoData(), serialSequences: [_serial]);
    sequences.invalidate();

    var landed = false;
    sequences.debugAfterScan = () async {
      if (landed) return;
      landed = true;
      // Another device's numbers commit while our scan is mid-flight.
      await qsos.mergeFromSync([
        for (var n = 2; n <= 12; n++)
          {
            ..._qsoData(call: 'DL${n}ABC'),
            'uuid': 'other-$n',
            'operation': op,
            'refs': [
              {'type': 'cqwpx', 'serial': n},
            ],
          },
      ]);
    };

    await sequences.peek(op, request);
    sequences.debugAfterScan = null;

    expect(await sequences.peek(op, request), 13, reason: 'the in-flight scan must not have been memoized');
    final next = await qsos.add(op, _qsoData(call: 'K1ABC'), serialSequences: [_serial]);
    expect(
      (next.refs.firstWhere((r) => r['type'] == 'cqwpx')['serial'] as num).toInt(),
      13,
      reason: 'a stale memo would re-issue a serial another operator already sent',
    );
  });

  test('descriptors are read from the extension input, and malformed ones are ignored', () async {
    final good = SequenceDescriptor.fromInput({
      'kind': 'serial',
      'refType': 'cqwpx',
      'field': 'serial',
      'sequence': {'key': 'serial', 'scope': ['band'], 'start': 5},
    }, extensionKey: 'cqwpx');
    expect(good, isNotNull);
    expect(good!.key, 'cqwpx/serial', reason: 'namespaced so two contests never share a counter');
    expect(good.start, 5);
    expect(good.scope, ['band']);

    // A half-formed declaration must allocate nothing rather than allocate
    // against a wrong label.
    expect(SequenceDescriptor.fromInput({'kind': 'text', 'refType': 'x', 'field': 'y'}, extensionKey: 'x'), isNull);
    expect(SequenceDescriptor.fromInput({'kind': 'serial', 'refType': 'x'}, extensionKey: 'x'), isNull);
    expect(
      SequenceDescriptor.fromInput({'kind': 'serial', 'refType': 'x', 'field': 'y', 'sequence': {}}, extensionKey: 'x'),
      isNull,
    );
  });
}

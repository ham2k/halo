// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  late HaLoDatabase db;
  late InboundCaptureRepository captures;

  setUp(() {
    db = HaLoDatabase(NativeDatabase.memory());
    captures = InboundCaptureRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('captures a QSO and lists it as pending', () async {
    final row = await captures.capture(
      source: 'n1mm',
      dedupeKey: 'k3tn|20m|cw|123',
      qsoData: {
        'our': {'call': 'N0DEV'},
        'their': {'call': 'K3TN'},
      },
    );
    expect(row.qso['their'], containsPair('call', 'K3TN'));

    final pending = await captures.watchPending().first;
    expect(pending, hasLength(1));
    expect(pending.first.uuid, row.uuid);
  });

  test('the same dedupe key is captured only once', () async {
    final first = await captures.capture(
      source: 'n1mm',
      dedupeKey: 'same-key',
      qsoData: {
        'their': {'call': 'K3TN'},
      },
    );
    final second = await captures.capture(
      source: 'n1mm',
      dedupeKey: 'same-key',
      qsoData: {
        'their': {'call': 'W1AW'},
      },
    );
    expect(second.uuid, first.uuid);
    expect(second.qso['their'], containsPair('call', 'K3TN'));

    final pending = await captures.watchPending().first;
    expect(pending, hasLength(1));
  });

  test('markAdded removes a capture from the pending list but keeps its dedupe key alive', () async {
    final row = await captures.capture(
      source: 'n1mm',
      dedupeKey: 'k3tn',
      qsoData: {
        'their': {'call': 'K3TN'},
      },
    );

    await captures.markAdded([row.uuid], 'operation-uuid');
    expect(await captures.watchPending().first, isEmpty);

    // A resend of the same broadcast must not queue a second, already-added
    // capture back onto the pending list.
    final resent = await captures.capture(
      source: 'n1mm',
      dedupeKey: 'k3tn',
      qsoData: {
        'their': {'call': 'K3TN'},
      },
    );
    expect(resent.uuid, row.uuid);
    expect(await captures.watchPending().first, isEmpty);
  });

  test('discard removes a capture entirely', () async {
    final row = await captures.capture(
      source: 'n1mm',
      dedupeKey: 'k3tn',
      qsoData: {
        'their': {'call': 'K3TN'},
      },
    );
    await captures.discard([row.uuid]);
    expect(await captures.watchPending().first, isEmpty);

    // Discarding is a real delete, not a soft one — the same broadcast
    // arriving again is captured fresh rather than staying suppressed.
    final recaptured = await captures.capture(
      source: 'n1mm',
      dedupeKey: 'k3tn',
      qsoData: {
        'their': {'call': 'K3TN'},
      },
    );
    expect(recaptured.uuid, isNot(row.uuid));
  });

  test('pending captures from every source appear in one list', () async {
    // "Listen for other apps" is one feature to the operator, not one per
    // protocol — a capture from WSJT-X must show up alongside N1MM's.
    await captures.capture(
      source: 'n1mm',
      dedupeKey: 'n1mm-1',
      qsoData: {
        'their': {'call': 'K3TN'},
      },
    );
    await captures.capture(
      source: 'wsjtx',
      dedupeKey: 'wsjtx-1',
      qsoData: {
        'their': {'call': 'W1AW'},
      },
    );
    final pending = await captures.watchPending().first;
    expect(pending.map((r) => r.source), unorderedEquals(['n1mm', 'wsjtx']));
  });

  test('onChange fires only for a real insert, not for a deduped repeat', () async {
    var changeCount = 0;
    final notifying = InboundCaptureRepository(db, onChange: () => changeCount++);

    await notifying.capture(
      source: 'n1mm',
      dedupeKey: 'first',
      qsoData: {
        'their': {'call': 'K3TN'},
      },
    );
    expect(changeCount, 1);

    // An unrelated second insert is what makes this test actually exercise
    // the bug it guards against: `sqlite3`'s `last_insert_rowid()` only
    // changes on a successful insert ANYWHERE on the connection, so after
    // this it reads nonzero regardless of what the duplicate capture below
    // does — a naive "insert()'s return value != 0" check would pass this
    // far and then wrongly fire on the duplicate that follows.
    await notifying.capture(
      source: 'n1mm',
      dedupeKey: 'second',
      qsoData: {
        'their': {'call': 'W1AW'},
      },
    );
    expect(changeCount, 2);

    await notifying.capture(
      source: 'n1mm',
      dedupeKey: 'first',
      qsoData: {
        'their': {'call': 'K3TN'},
      },
    );
    expect(changeCount, 2, reason: 'the dedupe key already existed — nothing was actually inserted');
  });
}

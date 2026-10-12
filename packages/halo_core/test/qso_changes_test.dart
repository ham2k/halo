// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `QsosRepository.changes` is how claims follow the whole log (docs/design/
// claims.md §6). A write it misses leaves a checklist stale with nothing to
// say so; a derived write it reports makes every rescore look like a
// change to every contact the operation holds.

import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  late HaLoDatabase db;
  late QsosRepository qsos;
  late List<Set<String>?> seen;

  setUp(() {
    db = HaLoDatabase(NativeDatabase.memory());
    qsos = QsosRepository(db);
    seen = [];
    qsos.changes.listen(seen.add);
  });
  tearDown(() => db.close());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('a contact logged, deleted, or arriving by sync is reported, wherever it belongs', () async {
    final qso = await qsos.add('', {
      'band': '20m',
      'mode': 'CW',
      'their': {'call': 'W1AW'},
    });
    await qsos.softDelete(qso);
    await qsos.mergeFromSync([
      {
        'uuid': 'synced',
        'operation': 'elsewhere',
        'band': '40m',
        'their': {'call': 'K1ABC'},
        'updatedAtMillis': 1000,
      },
    ]);
    await settle();

    expect(seen, [
      {qso.uuid},
      {qso.uuid},
      {'synced'},
    ]);
  });

  test('scores and sync bookkeeping are not reported: they change no contact', () async {
    final qso = await qsos.add('op', {
      'band': '20m',
      'their': {'call': 'W1AW'},
    });
    await settle();
    seen.clear();

    await qsos.updateScoreCache('op', {qso.uuid: '{"core":{}}'});
    await qsos.markSynced([qso]);
    await settle();
    expect(seen, isEmpty);
  });

  // Each would read as "anything may have changed" and rescan the whole log
  // through every chasing program, after every sync round that tidies up.
  test('removing rows that were already deleted is not reported: no contact changed', () async {
    Future<void> purgedAndSynced(String operation) async {
      final qso = await qsos.add(operation, {
        'band': '20m',
        'their': {'call': 'W1AW'},
      });
      await qsos.purgeForOperation(operation);
      await qsos.markSynced([(await qsos.get(qso.uuid))!]);
    }

    await purgedAndSynced('op');
    await purgedAndSynced('gone');
    await settle();
    seen.clear();

    await qsos.hardDeletePurgedForOperation('op');
    expect(await qsos.hardDeletePurgedOrphans(), 1);
    await settle();
    expect(seen, isEmpty);
  });

  test('a write that may have reached any contact says so, rather than naming some', () async {
    await qsos.add('op', {
      'band': '20m',
      'their': {'call': 'W1AW'},
    });
    await settle();
    seen.clear();

    await qsos.hardDeleteAllForOperation('op');
    await settle();
    expect(seen, [null]);
  });

  // A contact in a deleted operation is still a live row, and counting it
  // would keep a deleted operation's entities on every checklist.
  test('the log a pass reads leaves out deleted contacts and deleted operations\' contacts', () async {
    final operations = OperationsRepository(db);
    final op = await operations.create(stationCall: 'KI2D');
    final kept = await qsos.add('', {
      'band': '20m',
      'their': {'call': 'W1AW'},
    });
    final gone = await qsos.add('', {
      'band': '20m',
      'their': {'call': 'K1ABC'},
    });
    final inOperation = await qsos.add(op.uuid, {
      'band': '20m',
      'their': {'call': 'N0CALL'},
    });
    await qsos.softDelete(gone);
    expect((await qsos.liveAmong([kept.uuid, gone.uuid, inOperation.uuid, 'missing'])).map((q) => q.uuid), unorderedEquals([kept.uuid, inOperation.uuid]));

    await operations.softDelete(op.uuid);
    expect((await qsos.liveAmong([kept.uuid, inOperation.uuid])).map((q) => q.uuid), [kept.uuid]);
    expect((await qsos.livePage()).map((q) => q.uuid), [kept.uuid]);
    expect(await qsos.liveCount(), 1);
  });

  // Deleting an operation writes none of its contacts, so `changes` never
  // hears of it, here or when the deletion arrives by sync.
  test('an operation deleted or restored is reported, here or by sync', () async {
    final operations = OperationsRepository(db);
    var heard = 0;
    operations.deletions.listen((_) => heard++);
    final op = await operations.create(stationCall: 'KI2D');
    await operations.saveData(op);
    await settle();
    expect(heard, 0, reason: 'an edit that leaves the operation in the log takes no contact out of it');

    await operations.softDelete(op.uuid);
    await operations.undelete(op.uuid);
    await settle();
    expect(heard, 2);

    final stored = (await operations.get(op.uuid))!;
    await operations.mergeFromSync([
      {...stored.data, 'uuid': op.uuid, 'deleted': true, 'updatedAtMillis': realNowMillis() + 1000},
    ]);
    await settle();
    expect(heard, 3);
  });
}

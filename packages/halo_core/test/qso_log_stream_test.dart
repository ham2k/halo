// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:drift/drift.dart'
    show ApplyInterceptor, BatchedStatements, QueryExecutor, QueryExecutorUser, QueryInterceptor, SqlDialect, TransactionExecutor, Value;
import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

/// Counts the two reads the log stream can make: the whole ordered log, and
/// touched rows by uuid. What a stream emits is the same either way — the
/// point of the stream is WHICH read it makes, and only the SQL shows that.
class _Reads extends QueryInterceptor {
  int log = 0;
  int rows = 0;

  /// Completed once the next whole-log read has returned its rows — before
  /// the stream has decoded them.
  Completer<void>? logReadDone;

  /// When set, the next transaction's commit waits on it — the transaction
  /// stays open, its lock held and its table update undispatched.
  Completer<void>? holdCommit;

  /// When set, the next by-uuid row read waits on it before touching the
  /// database, so writes can land while a pass is in flight.
  Completer<void>? holdRowRead;

  /// The next whole-log read, or by-uuid row read, throws instead.
  bool failNextLogRead = false;
  bool failNextRowRead = false;

  /// The held row read throws once released, instead of running.
  bool failHeldRead = false;

  @override
  TransactionExecutor beginTransaction(QueryExecutor parent) {
    final inner = parent.beginTransaction();
    final hold = holdCommit;
    if (hold == null) return inner;
    holdCommit = null;
    return _HeldCommit(inner, hold.future);
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(QueryExecutor executor, String statement, List<Object?> args) async {
    final isLogRead = statement.contains('FROM "qsos"') && statement.contains('ORDER BY');
    final isRowRead = statement.startsWith('SELECT * FROM "qsos" WHERE "uuid" IN');
    if (isLogRead && failNextLogRead) {
      failNextLogRead = false;
      throw StateError('the log read failed');
    }
    if (isRowRead && failNextRowRead) {
      failNextRowRead = false;
      throw StateError('the row read failed');
    }
    if (isRowRead && holdRowRead != null) {
      final hold = holdRowRead!;
      holdRowRead = null;
      await hold.future;
      if (failHeldRead) {
        failHeldRead = false;
        throw StateError('the held row read failed');
      }
    }
    final result = await executor.runSelect(statement, args);
    if (isLogRead) {
      log++;
      logReadDone?.complete();
      logReadDone = null;
    }
    if (isRowRead) rows++;
    return result;
  }
}

class _HeldCommit implements TransactionExecutor {
  _HeldCommit(this.inner, this.until);

  final TransactionExecutor inner;
  final Future<void> until;

  @override
  Future<void> send() async {
    await until;
    await inner.send();
  }

  @override
  Future<void> rollback() => inner.rollback();
  @override
  bool get supportsNestedTransactions => inner.supportsNestedTransactions;
  @override
  SqlDialect get dialect => inner.dialect;
  @override
  Future<bool> ensureOpen(QueryExecutorUser user) => inner.ensureOpen(user);
  @override
  Future<List<Map<String, Object?>>> runSelect(String statement, List<Object?> args) => inner.runSelect(statement, args);
  @override
  Future<int> runInsert(String statement, List<Object?> args) => inner.runInsert(statement, args);
  @override
  Future<int> runUpdate(String statement, List<Object?> args) => inner.runUpdate(statement, args);
  @override
  Future<int> runDelete(String statement, List<Object?> args) => inner.runDelete(statement, args);
  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) => inner.runCustom(statement, args);
  @override
  Future<void> runBatched(BatchedStatements statements) => inner.runBatched(statements);
  @override
  TransactionExecutor beginTransaction() => inner.beginTransaction();
  @override
  QueryExecutor beginExclusive() => inner.beginExclusive();
  @override
  Future<void> close() => inner.close();
}

void main() {
  late HaLoDatabase db;
  late OperationsRepository operations;
  late QsosRepository qsos;
  late _Reads reads;

  setUp(() {
    reads = _Reads();
    db = HaLoDatabase(NativeDatabase.memory().interceptWith(reads));
    operations = OperationsRepository(db);
    qsos = QsosRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Map<String, dynamic> contact(String call, int startAt) => {
    'their': {'call': call},
    'mode': 'CW',
    'startAtMillis': startAt,
  };

  /// Subscribes and returns the emissions so far, waiting for the first.
  Future<List<List<Qso>>> follow(String operationUuid, {bool includeDeleted = false}) async {
    final emissions = <List<Qso>>[];
    final subscription = qsos.watchForOperation(operationUuid, includeDeleted: includeDeleted).listen(emissions.add);
    addTearDown(subscription.cancel);
    await settled(emissions, 1);
    return emissions;
  }

  test('a logged contact reaches the stream through its own row, not a re-read of the log', () async {
    final op = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, contact('W1AW', 1000));
    final emissions = await follow(op.uuid);
    expect(reads.log, 1);

    await qsos.add(op.uuid, contact('K1ABC', 2000));
    await settled(emissions, 2);

    expect(emissions.last.map((q) => q.theirCall), ['W1AW', 'K1ABC']);
    expect(reads.log, 1, reason: 'the log was not read again');
    expect(reads.rows, 1, reason: 'only the new row was');
    expect(identical(emissions.first, emissions.last), isFalse, reason: 'a consumer may keep the previous list');
    expect(emissions.first, hasLength(1), reason: 'and it must not have been patched underneath them');
  });

  test('a write to another operation leaves the stream silent', () async {
    final op = await operations.create(stationCall: 'KI2D');
    final other = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, contact('W1AW', 1000));
    final emissions = await follow(op.uuid);

    final theirs = await qsos.add(other.uuid, contact('K1ABC', 2000));
    await qsos.update(Qso(uuid: theirs.uuid, operationUuid: other.uuid, data: {...theirs.data, 'notes': 'x'}));
    await qsos.updateScoreCache(other.uuid, {theirs.uuid: '{}'});
    await quiet();

    expect(emissions, hasLength(1));
    expect(reads.log, 1);
    expect(reads.rows, 0, reason: 'nothing of this operation was named, so nothing was re-read');
  });

  test('a write the ledger knows nothing about reads the log again', () async {
    final op = await operations.create(stationCall: 'KI2D');
    final qso = await qsos.add(op.uuid, contact('W1AW', 1000));
    final emissions = await follow(op.uuid);

    // Not through the repository — the shape of any writer it does not know.
    await (db.update(db.qsos)..where((q) => q.uuid.equals(qso.uuid))).write(const QsosCompanion(scoreCache: Value('{"x":1}')));
    await settled(emissions, 2);

    expect(emissions.last.single.scoreCache, '{"x":1}');
    expect(reads.log, 2, reason: 'nothing said which rows moved, so all of them were read');
    expect(reads.rows, 0);
  });

  test('an edit, a change of start time and a delete each patch the log in place, in order', () async {
    final op = await operations.create(stationCall: 'KI2D');
    final a = await qsos.add(op.uuid, contact('A1A', 1000));
    final b = await qsos.add(op.uuid, contact('B1B', 2000));
    final c = await qsos.add(op.uuid, contact('C1C', 3000));
    final emissions = await follow(op.uuid);

    var checks = 0;
    Future<void> matchesTheLog() async {
      checks++;
      final fresh = await qsos.forOperation(op.uuid);
      expect(
        emissions.last.map((q) => '${q.theirCall}:${q.notes ?? ''}:${q.startAtMillis}'),
        fresh.map((q) => '${q.theirCall}:${q.notes ?? ''}:${q.startAtMillis}'),
      );
    }

    await qsos.update(Qso(uuid: b.uuid, operationUuid: op.uuid, data: {...b.data, 'notes': 'edited'}));
    await settled(emissions, 2);
    expect(emissions.last.map((q) => q.notes), [null, 'edited', null], reason: 'replaced where it was');
    await matchesTheLog();

    await qsos.update(Qso(uuid: a.uuid, operationUuid: op.uuid, data: {...a.data, 'startAtMillis': 2500}));
    await settled(emissions, 3);
    expect(emissions.last.map((q) => q.theirCall), ['B1B', 'A1A', 'C1C'], reason: 'a moved start time re-places the row');
    await matchesTheLog();

    await qsos.softDelete(c);
    await settled(emissions, 4);
    expect(emissions.last.map((q) => q.theirCall), ['B1B', 'A1A']);
    await matchesTheLog();

    await qsos.undelete(c);
    await settled(emissions, 5);
    expect(emissions.last.map((q) => q.theirCall), ['B1B', 'A1A', 'C1C']);
    await matchesTheLog();

    expect(reads.log, 1 + checks, reason: 'every step was a patch; the log reads are the checks above');
  });

  test('a stream that shows deleted rows keeps a soft-deleted one, flagged', () async {
    final op = await operations.create(stationCall: 'KI2D');
    final qso = await qsos.add(op.uuid, contact('W1AW', 1000));
    final emissions = await follow(op.uuid, includeDeleted: true);

    await qsos.softDelete(qso);
    await settled(emissions, 2);

    expect(emissions.last.single.deleted, isTrue);
  });

  test('a contact logged with no start time sorts first, as the query orders it', () async {
    final op = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, contact('W1AW', 1000));
    final emissions = await follow(op.uuid);

    // `add` fills a missing start time in, so the null has to be written past it.
    final stampless = await qsos.add(op.uuid, contact('K1ABC', 2000));
    await settled(emissions, 2);
    await (db.update(db.qsos)..where((q) => q.uuid.equals(stampless.uuid))).write(const QsosCompanion(startAtMillis: Value(null)));
    await settled(emissions, 3);
    // Now patched in from a null start time to a real one.
    await qsos.update(Qso(uuid: stampless.uuid, operationUuid: op.uuid, data: {...stampless.data, 'startAtMillis': 500}));
    await settled(emissions, 4);

    expect(emissions.last.map((q) => q.theirCall), ['K1ABC', 'W1AW']);
    expect(emissions.last.map((q) => q.theirCall), (await qsos.forOperation(op.uuid)).map((q) => q.theirCall));
  });

  test('a sync merge that moves a contact between operations reaches both streams', () async {
    final from = await operations.create(stationCall: 'KI2D');
    final to = await operations.create(stationCall: 'KI2D');
    final qso = await qsos.add(from.uuid, contact('W1AW', 1000));
    final fromEmissions = await follow(from.uuid);
    final toEmissions = await follow(to.uuid);

    await qsos.mergeFromSync([
      {...qso.data, 'operation': to.uuid, 'updatedAtMillis': (qso.updatedAtMillis ?? 0) + 1},
    ]);
    await settled(fromEmissions, 2);
    await settled(toEmissions, 2);

    expect(fromEmissions.last, isEmpty);
    expect(toEmissions.last.single.theirCall, 'W1AW');
    expect(reads.log, 2, reason: 'one initial read per stream, and no more');
  });

  test('a write naming more rows than a patch is worth reads the log in full, and is still right', () async {
    final op = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, contact('W1AW', 1));
    final emissions = await follow(op.uuid);

    await qsos.writeBatch(operationUuid: op.uuid, inserts: [for (var i = 0; i < 250; i++) contact('K${i}AB', 1000 + i)]);
    await settled(emissions, 2);

    expect(emissions.last, hasLength(251));
    expect(reads.log, 2);
    expect(reads.rows, 0, reason: 'a re-read of 250 rows would only be a slower full read');
    expect(emissions.last.map((q) => q.theirCall), (await qsos.forOperation(op.uuid)).map((q) => q.theirCall));
  });

  test('marking rows synced emits nothing: the log a stream shows has not changed', () async {
    final op = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, contact('W1AW', 1000));
    final emissions = await follow(op.uuid);

    await qsos.markSynced(emissions.last);
    await quiet();

    expect(emissions, hasLength(1));
    expect(reads.rows, 0);
  });

  test('a footprint folded in before its own update arrives is paid for by that update, not read as a stranger', () async {
    // The stream can see a write's footprint while the write's transaction is
    // still open: the row re-read then waits on the lock, folds the committed
    // row in, and the table update that follows must be recognised as that
    // write's — without the debt it pays into, the update reads as one the
    // ledger missed, and the log is read again in full for nothing.
    //
    // Forced deterministically: a log above the decode threshold puts the
    // initial read's decode on an isolate, whose reply is an EVENT, so once
    // that read has returned its rows, every microtask below — a committed
    // write, then a write whose commit is held — runs before the initial
    // read completes. The pass that follows it takes its snapshot with the
    // held write's footprint in it and only the committed write's update.
    final op = await operations.create(stationCall: 'KI2D');
    await qsos.writeBatch(operationUuid: op.uuid, inserts: [for (var i = 0; i < 300; i++) contact('K${i}AB', 1000 + i)]);
    final emissions = <List<Qso>>[];
    final rowsRead = reads.logReadDone = Completer<void>();
    final subscription = qsos.watchForOperation(op.uuid).listen(emissions.add);
    addTearDown(subscription.cancel);
    await rowsRead.future;

    await qsos.add(op.uuid, contact('X2X', 5000));
    final commit = reads.holdCommit = Completer<void>();
    final held = qsos.add(op.uuid, contact('Y1Y', 6000));
    await settled(emissions, 1);
    commit.complete();
    await held;
    await settled(emissions, 2);
    await quiet();

    expect(emissions.last, hasLength(302));
    expect(emissions.last.skip(300).map((q) => q.theirCall), ['X2X', 'Y1Y']);
    expect(emissions, hasLength(2));
    expect(reads.log, 1, reason: "the second write's update was paid for by the footprint folded in early");
  });

  test('an edit that moves a contact to another operation leaves the log it came from', () async {
    // The row's operation is written from the editor's copy, so an edit saved
    // from a snapshot a sync pull has since moved puts the row back — and the
    // stream of the operation it leaves must hear it, not only the one it joins.
    final from = await operations.create(stationCall: 'KI2D');
    final to = await operations.create(stationCall: 'KI2D');
    final qso = await qsos.add(from.uuid, contact('W1AW', 1000));
    final fromEmissions = await follow(from.uuid);
    final toEmissions = await follow(to.uuid);

    await qsos.update(Qso(uuid: qso.uuid, operationUuid: to.uuid, data: qso.data));
    await settled(fromEmissions, 2);
    await settled(toEmissions, 2);

    expect(fromEmissions.last, isEmpty);
    expect(toEmissions.last.single.theirCall, 'W1AW');
    expect(reads.log, 2, reason: 'both were patches');
  });

  test('a batch that writes a contact back into its operation leaves the log it came from', () async {
    // The same hazard as an edit: an import plan built before a sync pull
    // moved a row writes the row's operation from the plan.
    final from = await operations.create(stationCall: 'KI2D');
    final to = await operations.create(stationCall: 'KI2D');
    final qso = await qsos.add(to.uuid, contact('W1AW', 1000));
    final fromEmissions = await follow(from.uuid);
    final toEmissions = await follow(to.uuid);

    await qsos.writeBatch(
      operationUuid: from.uuid,
      updates: [Qso(uuid: qso.uuid, operationUuid: from.uuid, data: qso.data)],
    );
    await settled(fromEmissions, 2);
    await settled(toEmissions, 2);

    expect(toEmissions.last, isEmpty);
    expect(fromEmissions.last.single.theirCall, 'W1AW');
    expect(reads.log, 2, reason: 'both were patches');
  });

  test('a sync batch spanning operations makes a stream re-read only its own rows', () async {
    // A backfill page carries hundreds of another operation's rows beside one
    // of this one's; filed per operation, that one row is a patch, not a
    // whole-log read the page's size forces.
    final op = await operations.create(stationCall: 'KI2D');
    final other = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, contact('W1AW', 1000));
    final emissions = await follow(op.uuid);

    await qsos.mergeFromSync([
      {...contact('K1ABC', 2000), 'uuid': 'own-1', 'operation': op.uuid, 'updatedAtMillis': 5},
      for (var i = 0; i < 250; i++) {...contact('X${i}XX', 1000 + i), 'uuid': 'foreign-$i', 'operation': other.uuid, 'updatedAtMillis': 5},
    ]);
    await settled(emissions, 2);

    expect(emissions.last.map((q) => q.theirCall), ['W1AW', 'K1ABC']);
    expect(reads.log, 1, reason: "the other operation's rows are not this stream's to re-read");
  });

  test("an operation's undelete restores its contacts to the stream by their rows", () async {
    // The one writer that lived outside the repository; through it, the
    // restore is a patch rather than the whole-log fallback.
    final op = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, contact('W1AW', 1000));
    await qsos.add(op.uuid, contact('K1ABC', 2000));
    await operations.softDelete(op.uuid);
    final stamp = (await operations.get(op.uuid))!.updatedAtMillis!;
    await (db.update(db.qsos)..where((q) => q.operation.equals(op.uuid))).write(QsosCompanion(deleted: const Value(true), updatedAtMillis: Value(stamp)));
    final emissions = await follow(op.uuid);
    expect(emissions.last, isEmpty);

    await undeleteOperationWithQsos(db: db, operations: operations, qsos: qsos, uuid: op.uuid);
    await settled(emissions, 2);

    expect(emissions.last.map((q) => q.theirCall), ['W1AW', 'K1ABC']);
    expect(reads.log, 1, reason: 'the restore named its rows');
  });

  test('a read that fails is one error, not a loop, and the next change reads the log afresh', () async {
    // Without a gate on the initial read, a log that cannot be read — one
    // corrupt row is enough — is re-read at database speed with an error per
    // turn until the listener gives up.
    final op = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, contact('W1AW', 1000));
    final emissions = <List<Qso>>[];
    final errors = <Object>[];
    reads.failNextLogRead = true;
    final subscription = qsos.watchForOperation(op.uuid).listen(emissions.add, onError: errors.add);
    addTearDown(subscription.cancel);
    await quiet();

    expect(errors, hasLength(1));
    expect(emissions, isEmpty);
    expect(reads.log, 0, reason: 'the failed read is not retried until the table changes');

    await qsos.add(op.uuid, contact('K1ABC', 2000));
    await settled(emissions, 1);

    expect(emissions.single.map((q) => q.theirCall), ['W1AW', 'K1ABC']);
    expect(errors, hasLength(1));
  });

  test('a patch that fails gives the held list up: the next change reads the log in full', () async {
    // The footprints of a failed pass are consumed. Patching later changes
    // onto the list they never reached would emit a log that silently
    // disagrees with the database.
    final op = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, contact('W1AW', 1000));
    final errors = <Object>[];
    final emissions = <List<Qso>>[];
    final subscription = qsos.watchForOperation(op.uuid).listen(emissions.add, onError: errors.add);
    addTearDown(subscription.cancel);
    await settled(emissions, 1);

    reads.failNextRowRead = true;
    await qsos.add(op.uuid, contact('K1ABC', 2000));
    await quiet();
    expect(errors, hasLength(1));
    expect(emissions, hasLength(1));

    await qsos.add(op.uuid, contact('N1XYZ', 3000));
    await settled(emissions, 2);

    expect(emissions.last.map((q) => q.theirCall), ['W1AW', 'K1ABC', 'N1XYZ'], reason: 'the contact the failed pass missed is back');
    expect(reads.log, 2);
  });

  test('a listener the ledger has outrun reads the log in full', () async {
    // The ledger is bounded; a pass held up while hundreds of writes land —
    // a sync backfill of another operation during a slow read — finds its
    // cursor behind what the ledger still holds.
    final op = await operations.create(stationCall: 'KI2D');
    final other = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, contact('W1AW', 1000));
    final emissions = await follow(op.uuid);

    final hold = reads.holdRowRead = Completer<void>();
    await qsos.add(op.uuid, contact('K1ABC', 2000));
    await quiet();
    for (var i = 0; i < 300; i++) {
      await qsos.add(other.uuid, contact('X${i}XX', 1000 + i));
    }
    await qsos.add(op.uuid, contact('N1XYZ', 3000));
    hold.complete();
    await settled(emissions, 3);
    await quiet();

    expect(emissions.last.map((q) => q.theirCall), ['W1AW', 'K1ABC', 'N1XYZ']);
    expect(reads.log, 2, reason: 'the second pass had no ledger to consult');
  });

  test('a write that reaches every row reads every log in full', () async {
    final op = await operations.create(stationCall: 'KI2D');
    final other = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, contact('W1AW', 1000));
    await qsos.add(other.uuid, contact('K1ABC', 2000));
    final emissions = await follow(op.uuid);

    await qsos.hardDeleteAllForOperation(other.uuid);
    await settled(emissions, 2);
    expect(emissions.last.single.theirCall, 'W1AW');
    expect(reads.log, 2, reason: 'nothing says which rows a predicate delete reached');

    await qsos.hardDeleteAllForOperation(op.uuid);
    await settled(emissions, 3);
    expect(emissions.last, isEmpty);
  });

  group('one follower per log', () {
    // The Operation View listens twice to one log; drift's keyed query streams
    // shared the query between identical watches, and so must this, or the
    // view reads and decodes the log twice at open and patches twice per write.
    test('two listeners share one read and one patch, and both are fed', () async {
      final op = await operations.create(stationCall: 'KI2D');
      await qsos.add(op.uuid, contact('W1AW', 1000));
      final first = await follow(op.uuid);
      final second = await follow(op.uuid);
      expect(reads.log, 1, reason: 'the second listener attached to the running follower');

      await qsos.add(op.uuid, contact('K1ABC', 2000));
      await settled(first, 2);
      await settled(second, 2);

      expect(reads.rows, 1, reason: 'one re-read for both');
      expect(first.last.map((q) => q.theirCall), ['W1AW', 'K1ABC']);
      expect(second.last.map((q) => q.theirCall), ['W1AW', 'K1ABC']);
    });

    test('a late listener is handed the list held so far, without a read', () async {
      final op = await operations.create(stationCall: 'KI2D');
      await qsos.add(op.uuid, contact('W1AW', 1000));
      await follow(op.uuid);
      final late = await follow(op.uuid);
      expect(late.single.single.theirCall, 'W1AW');
      expect(reads.log, 1);
    });

    test('showing deleted rows is its own follower', () async {
      final op = await operations.create(stationCall: 'KI2D');
      await qsos.add(op.uuid, contact('W1AW', 1000));
      await follow(op.uuid);
      await follow(op.uuid, includeDeleted: true);
      expect(reads.log, 2, reason: 'a different view of the log is a different follower');
    });

    test('the last cancel stops the follower; the next subscription starts a fresh one', () async {
      final op = await operations.create(stationCall: 'KI2D');
      await qsos.add(op.uuid, contact('W1AW', 1000));
      final a = <List<Qso>>[];
      final b = <List<Qso>>[];
      final subA = qsos.watchForOperation(op.uuid).listen(a.add);
      final subB = qsos.watchForOperation(op.uuid).listen(b.add);
      await settled(a, 1);
      await settled(b, 1);

      await subA.cancel();
      await qsos.add(op.uuid, contact('K1ABC', 2000));
      await settled(b, 2);
      expect(a, hasLength(1), reason: 'the cancelled listener hears nothing more');
      expect(reads.rows, 1, reason: 'the remaining listener is still fed by the one follower');

      await subB.cancel();
      await qsos.add(op.uuid, contact('N1XYZ', 3000));
      await quiet();
      expect(reads.rows, 1, reason: 'nobody listens, so nothing is read');

      final again = await follow(op.uuid);
      expect(again.single, hasLength(3));
      expect(reads.log, 2, reason: 'a fresh follower reads the log afresh');
    });
  });

  test('a listener attaching during the initial read gets that read, once for both', () async {
    final op = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, contact('W1AW', 1000));
    final first = <List<Qso>>[];
    final second = <List<Qso>>[];
    final rowsRead = reads.logReadDone = Completer<void>();
    final subA = qsos.watchForOperation(op.uuid).listen(first.add);
    addTearDown(subA.cancel);
    await rowsRead.future;
    // The rows are read but not decoded yet: the second listener attaches
    // while the first read is in flight.
    final subB = qsos.watchForOperation(op.uuid).listen(second.add);
    addTearDown(subB.cancel);
    await settled(first, 1);
    await settled(second, 1);
    expect(second.single.single.theirCall, 'W1AW');
    expect(reads.log, 1);
  });

  test('a listener attaching while writes are being folded in sees every write it awaited', () async {
    // The list held at attach predates the writes; handing it over — or the
    // first iteration's result — would make `.first` after two awaited adds
    // answer with the log short of the second.
    final op = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, contact('W1AW', 1000));
    final emissions = await follow(op.uuid);
    final hold = reads.holdRowRead = Completer<void>();
    await qsos.add(op.uuid, contact('K1ABC', 2000));
    await quiet();
    await qsos.add(op.uuid, contact('N1XYZ', 3000));
    final late = qsos.watchForOperation(op.uuid).first;
    hold.complete();
    expect((await late).map((q) => q.theirCall), ['W1AW', 'K1ABC', 'N1XYZ']);
    await settled(emissions, 3);
  });

  test('a listener attaching during a pass that fails gets a read of its own, not the error', () async {
    // The failure is the earlier listeners' to hear; the newcomer has heard
    // nothing and would otherwise wait for a table that may never change.
    final op = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, contact('W1AW', 1000));
    final errors = <Object>[];
    final first = <List<Qso>>[];
    final subA = qsos.watchForOperation(op.uuid).listen(first.add, onError: errors.add);
    addTearDown(subA.cancel);
    await settled(first, 1);
    final hold = reads.holdRowRead = Completer<void>();
    await qsos.add(op.uuid, contact('K1ABC', 2000));
    await quiet();
    final lateErrors = <Object>[];
    final late = <List<Qso>>[];
    final subB = qsos.watchForOperation(op.uuid).listen(late.add, onError: lateErrors.add);
    addTearDown(subB.cancel);
    reads.failHeldRead = true;
    hold.complete();
    await settled(late, 1);

    expect(errors, hasLength(1), reason: 'the listener that was there hears the failure');
    expect(lateErrors, isEmpty, reason: 'the newcomer never had the list the failure spoiled');
    expect(late.single.map((q) => q.theirCall), ['W1AW', 'K1ABC']);
    expect(reads.log, 2, reason: 'a read of its own');
  });

  test('a listener attaching after a failed read gets a read of its own', () async {
    // The earlier listeners heard the error; a new one has heard nothing and
    // would wait for a table that may never change again.
    final op = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, contact('W1AW', 1000));
    final errors = <Object>[];
    reads.failNextLogRead = true;
    final subA = qsos.watchForOperation(op.uuid).listen((_) {}, onError: errors.add);
    addTearDown(subA.cancel);
    await quiet();
    expect(errors, hasLength(1));

    final late = await follow(op.uuid);
    expect(late.single.single.theirCall, 'W1AW');
    expect(reads.log, 1, reason: 'the failed read counted nothing; this is the new listener\'s own');
  });

  test('every emission carries the digest of its non-deleted rows, however it was produced', () async {
    // The digest is maintained per patch — a term leaves with a replaced or
    // dropped row, one joins with a fresh row — and a drift anywhere would
    // make the checkpoint stamp disagree with a recomputation forever after.
    // Every way a list can change is driven here, and every emission is
    // checked against a walk over its own rows.
    final op = await operations.create(stationCall: 'KI2D');
    final other = await operations.create(stationCall: 'KI2D');
    final a = await qsos.add(op.uuid, contact('A1A', 1000));
    final b = await qsos.add(op.uuid, contact('B1B', 2000));
    final emissions = await follow(op.uuid, includeDeleted: true);
    void check(String step) {
      final log = emissions.last;
      expect(log, isA<QsoLog>(), reason: step);
      expect((log as QsoLog).digest, qsoLogDigestOf(log), reason: '$step: the carried digest drifted from the rows');
      expect(log.unstamped, qsoLogUnstampedOf(log), reason: '$step: the unstamped count drifted from the rows');
    }

    check('initial read');
    await qsos.add(op.uuid, contact('C1C', 3000));
    await settled(emissions, 2);
    check('add');
    await qsos.update(Qso(uuid: b.uuid, operationUuid: op.uuid, data: {...b.data, 'notes': 'edited'}));
    await settled(emissions, 3);
    check('edit');
    await qsos.update(Qso(uuid: a.uuid, operationUuid: op.uuid, data: {...a.data, 'startAtMillis': 2500}));
    await settled(emissions, 4);
    check('move in time');
    await qsos.softDelete(b);
    await settled(emissions, 5);
    check('delete');
    expect(
      (emissions.last as QsoLog).digest,
      qsoLogDigestOf(emissions.last.where((q) => q.uuid != b.uuid)),
      reason: 'a deleted row is out of the digest though in the list',
    );
    await qsos.undelete(b);
    await settled(emissions, 6);
    check('undelete');
    await qsos.updateScoreCache(op.uuid, {a.uuid: '{}'});
    await settled(emissions, 7);
    check('score cache');
    await qsos.mergeFromSync([
      {...contact('D1D', 4000), 'uuid': 'd', 'operation': op.uuid, 'updatedAtMillis': 7},
      {...contact('X1X', 4000), 'uuid': 'x', 'operation': other.uuid, 'updatedAtMillis': 7},
    ]);
    await settled(emissions, 8);
    check('sync merge');
    // A stampless record is stored as it comes, and a second one replaces
    // it: the one row a digest cannot vouch for, counted in, then counted
    // out again once a local edit stamps it.
    await qsos.mergeFromSync([
      {...contact('E1E', 5000), 'uuid': 'e', 'operation': op.uuid},
    ]);
    await settled(emissions, 9);
    check('stampless merge');
    expect((emissions.last as QsoLog).unstamped, 1);
    await qsos.mergeFromSync([
      {...contact('E1E', 5000), 'uuid': 'e', 'operation': op.uuid, 'notes': 'corrected, still stampless'},
    ]);
    await settled(emissions, 10);
    check('stampless replacement');
    expect((emissions.last as QsoLog).unstamped, 1);
    expect((emissions.last as QsoLog).digest, (emissions[8] as QsoLog).digest, reason: 'the content moved and the digest could not: what the count is for');
    final e = emissions.last.singleWhere((q) => q.uuid == 'e');
    await qsos.update(Qso(uuid: 'e', operationUuid: op.uuid, data: {...e.data, 'notes': 'stamped'}));
    await settled(emissions, 11);
    check('stamped by a local edit');
    expect((emissions.last as QsoLog).unstamped, 0);
    await (db.update(db.qsos)..where((q) => q.uuid.equals(a.uuid))).write(const QsosCompanion(scoreCache: Value('{"x":1}')));
    await settled(emissions, 12);
    check('full read after a stranger');
    expect(emissions.last.map((q) => q.theirCall), ['B1B', 'A1A', 'C1C', 'D1D', 'E1E']);
  });

  test('an emitted list cannot be written into', () async {
    final op = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, contact('W1AW', 1000));
    final emissions = await follow(op.uuid);
    expect(() => emissions.single.clear(), throwsUnsupportedError);
  });

  test('a listener that cancels mid-way leaves nothing running', () async {
    final op = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, contact('W1AW', 1000));
    final emissions = <List<Qso>>[];
    final subscription = qsos.watchForOperation(op.uuid).listen(emissions.add);
    await settled(emissions, 1);
    await subscription.cancel();

    await qsos.add(op.uuid, contact('K1ABC', 2000));
    await quiet();

    expect(emissions, hasLength(1));
    expect(reads.rows, 0, reason: 'a cancelled stream reads nothing');
  });
}

/// Waits until [emissions] holds [count] lists. Reads run on the event queue
/// and, above the decode threshold, on an isolate, so this polls rather than
/// pumping the queue a fixed number of times.
Future<void> settled(List<List<Qso>> emissions, int count) async {
  for (var i = 0; i < 400 && emissions.length < count; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(emissions, hasLength(count), reason: 'the stream did not emit in time');
}

/// Long enough for an emission that was coming to have come.
Future<void> quiet() => Future<void>.delayed(const Duration(milliseconds: 100));

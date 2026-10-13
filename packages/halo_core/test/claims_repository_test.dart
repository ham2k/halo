// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The claims table keeps one row per slot that every device must agree on
// (docs/design/claims.md §1, §5–§7). A slot that a device can lower without
// seeing the whole log, or a merge that two devices settle differently,
// makes checklists that disagree across devices and never converge.

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

const _program = 'dxcc';

StoredClaim _claim({
  String ref = '230',
  String? band,
  ClaimLevel level = ClaimLevel.worked,
  int? at = 1000,
  String? qso = 'q1',
  int version = 1,
  int epoch = 0,
  String? label,
  bool deleted = false,
  int? updatedAt,
  String source = kClaimSourceLog,
}) => StoredClaim(
  uuid: claimUuid(program: _program, holder: 'KI2D@291', edition: '', ref: ref, band: band, mode: null, source: source),
  program: _program,
  holder: 'KI2D@291',
  edition: '',
  ref: ref,
  band: band,
  mode: null,
  source: source,
  level: level,
  atMillis: at,
  qso: qso,
  version: version,
  epoch: epoch,
  data: {'label': ?label},
  deleted: deleted,
  updatedAtMillis: updatedAt,
);

void main() {
  late HaLoDatabase db;
  late ClaimsRepository claims;
  var changes = 0;

  setUp(() {
    db = HaLoDatabase(NativeDatabase.memory());
    changes = 0;
    claims = ClaimsRepository(db, onChange: () => changes++);
  });
  tearDown(() => db.close());

  Future<ClaimRow> row(StoredClaim claim) => (db.select(db.claims)..where((c) => c.uuid.equals(claim.uuid))).getSingle();
  Future<void> markAllSynced() => db.update(db.claims).write(const ClaimsCompanion(synced: Value(true)));

  group('the slot rule', () {
    test('a confirmation wins the slot even when its contact came later', () {
      expect(compareClaims(_claim(level: ClaimLevel.confirmed, at: 9000, qso: 'late'), _claim(at: 1000, qso: 'early')), greaterThan(0));
    });

    test('within a level the earliest contact wins, and the uuid settles a tie the same way on every device', () {
      expect(compareClaims(_claim(at: 1000, qso: 'b'), _claim(at: 2000, qso: 'a')), greaterThan(0));
      expect(compareClaims(_claim(at: 1000, qso: 'a'), _claim(at: 1000, qso: 'b')), greaterThan(0));
      expect(compareClaims(_claim(at: 1000, qso: 'b'), _claim(at: 1000, qso: 'a')), lessThan(0));
    });

    test('an import that does not say when loses to a contact at the same level that does', () {
      expect(compareClaims(_claim(at: null, qso: null, source: 'import:x'), _claim(at: 99999)), lessThan(0));
    });
  });

  group('slot uuids', () {
    // Every device must derive the same row for a slot, and no two slots
    // may share one: a `|` in a ref would merge two slots under a
    // separator-joined name.
    test('are the same everywhere and never shared between two slots', () {
      String uuid({String ref = 'A', String? band, String? mode}) => claimUuid(program: 'p', holder: 'H', edition: '', ref: ref, band: band, mode: mode);
      expect(uuid(), uuid());
      expect(uuid(band: '20m'), isNot(uuid()));
      expect(uuid(band: '20m'), isNot(uuid(mode: '20m')));
      expect(uuid(ref: 'A|20m'), isNot(uuid(band: '20m')));
    });

    test('a synced record filed under another slot\'s uuid is refused', () async {
      final record = {..._claim().toRecord(), 'ref': '291'};
      expect(StoredClaim.tryParseRecord(record), isNull);
      expect(await claims.mergeFromSync([record]), isEmpty);
    });
  });

  group('upgrades', () {
    test('a better contact takes the slot and keeps its epoch; a worse one changes nothing', () async {
      await claims.applyUpgrades([_claim(qso: 'first', at: 1000, epoch: 4)]);
      await claims.applyUpgrades([_claim(qso: 'later', at: 5000)]);
      expect((await row(_claim())).qso, 'first', reason: 'a later contact at the same level never displaces the earlier one');

      await claims.applyUpgrades([_claim(qso: 'confirmed', at: 5000, level: ClaimLevel.confirmed)]);
      final held = await row(_claim());
      expect([held.qso, held.level, held.epoch], ['confirmed', 'confirmed', 4], reason: 'an upgrade is not a rescan, so it outranks nothing by epoch');
    });

    // Lowering a slot needs the runner-up, which only the whole log has: a
    // device that wrote the worse claim here would publish it as the best.
    test('can never lower a slot, even from the contact holding it', () async {
      await claims.applyUpgrades([_claim(level: ClaimLevel.confirmed)]);
      await claims.applyUpgrades([_claim(level: ClaimLevel.worked)]);
      expect((await row(_claim())).level, 'confirmed');
    });

    test('the contact holding a slot can restate it, and an unchanged restatement writes nothing', () async {
      await claims.applyUpgrades([_claim(label: 'Germany')]);
      await markAllSynced();
      expect(await claims.applyUpgrades([_claim(label: 'Germany')]), 0);
      expect((await row(_claim())).synced, isTrue);

      expect(await claims.applyUpgrades([_claim(label: 'Fed. Rep. of Germany')]), 1);
      expect((await row(_claim())).data, contains('Fed. Rep. of Germany'));
    });

    test('several candidates for one slot settle among themselves first', () async {
      await claims.applyUpgrades([_claim(qso: 'b', at: 3000), _claim(qso: 'a', at: 2000), _claim(qso: 'c', at: 4000)]);
      expect((await row(_claim())).qso, 'a');
    });

    test('a withdrawn slot is filled again by any contact, at the withdrawal\'s epoch', () async {
      await claims.writeRescan(_program, 1, {});
      await claims.applyUpgrades([_claim(qso: 'old')]);
      await claims.writeRescan(_program, 1, {});
      expect((await row(_claim())).deleted, isTrue);

      await claims.applyUpgrades([_claim(qso: 'new', at: 9000)]);
      final held = await row(_claim());
      expect([held.deleted, held.qso, held.epoch], [false, 'new', 1], reason: 'at the same epoch a live claim must outrank the tombstone it replaced');
    });

    // An older extension (a rollback, another device) restating slots one
    // contact at a time would leave a checklist of mixed versions, which the
    // newer device then rebuilds whole.
    test('never replace what a newer version of the program computed, live or withdrawn', () async {
      await claims.applyUpgrades([_claim(ref: '230', version: 2)]);
      await claims.applyUpgrades([_claim(ref: '291', version: 2)]);
      await claims.writeRescan(_program, 2, {
        for (final c in [_claim(ref: '230', version: 2)]) c.uuid: c,
      });

      await claims.applyUpgrades([_claim(ref: '230', version: 1, level: ClaimLevel.confirmed), _claim(ref: '291', version: 1, qso: 'other')]);
      expect([(await row(_claim(ref: '230'))).level, (await row(_claim(ref: '230'))).version], ['worked', 2]);
      expect((await row(_claim(ref: '291'))).deleted, isTrue);
    });

    test('mark the rows they write for sync', () async {
      await claims.applyUpgrades([_claim()]);
      expect((await row(_claim())).synced, isFalse);
      expect(changes, 1);
    });
  });

  group('rescans', () {
    test('withdraw a slot no contact claims any more, under an epoch above every row', () async {
      await claims.applyUpgrades([_claim(ref: '230', epoch: 2), _claim(ref: '291', epoch: 0)]);
      await claims.writeRescan(_program, 1, {
        for (final c in [_claim(ref: '291')]) c.uuid: c,
      });

      final gone = await row(_claim(ref: '230'));
      expect([gone.deleted, gone.epoch], [true, 3]);
    });

    test('lower a slot to its runner-up, which an upgrade never could', () async {
      await claims.applyUpgrades([_claim(level: ClaimLevel.confirmed, qso: 'confirmed')]);
      final runnerUp = _claim(qso: 'runner-up', at: 2000);
      await claims.writeRescan(_program, 1, {runnerUp.uuid: runnerUp});

      final held = await row(_claim());
      expect([held.level, held.qso, held.epoch], ['worked', 'runner-up', 1]);
    });

    // Rewriting rows the rescan agrees with would push the whole checklist
    // to every device after every deletion.
    test('leave the rows they agree with untouched', () async {
      final kept = _claim(ref: '291');
      await claims.applyUpgrades([kept, _claim(ref: '230')]);
      await markAllSynced();
      await claims.writeRescan(_program, 1, {kept.uuid: kept});

      final row291 = await row(kept);
      expect([row291.synced, row291.epoch], [true, 0]);
    });

    // A row that went through a server can come back with its data in
    // another key order; read as a change, every rescan would push it again.
    test('agree with a row whose data differs only in key order', () async {
      await claims.mergeFromSync([
        {
          ..._claim().toRecord(),
          'data': {'label': 'Germany', 'by': 'lotw'},
        },
      ]);
      final recomputed = StoredClaim.tryParseRecord({
        ..._claim().toRecord(),
        'data': {'by': 'lotw', 'label': 'Germany'},
      })!;
      expect(await claims.writeRescan(_program, 1, {recomputed.uuid: recomputed}), 0);
    });

    test('leave alone what a newer version of the program computed', () async {
      await claims.applyUpgrades([_claim(ref: '230', version: 2), _claim(ref: '291', version: 2)]);
      final older = _claim(ref: '230', version: 1, level: ClaimLevel.verified);
      await claims.writeRescan(_program, 1, {older.uuid: older});

      expect((await row(_claim(ref: '230'))).level, 'worked');
      expect((await row(_claim(ref: '291'))).deleted, isFalse);
    });

    // A contact the program left out, or one not on this device yet, may
    // beat everything the pass found; withdrawing its slot would publish
    // that under an epoch every device obeys.
    test('keep a slot the pass could not judge, unless something it found beats it', () async {
      await claims.applyUpgrades([
        _claim(ref: '230', qso: 'left-out', level: ClaimLevel.confirmed),
        _claim(ref: '291', qso: 'not-here-yet'),
        _claim(ref: '100', qso: 'gone'),
        _claim(ref: '200', qso: 'on-its-way'),
      ]);
      final better = _claim(ref: '200', qso: 'here', level: ClaimLevel.verified);
      await claims.writeRescan(
        _program,
        1,
        {better.uuid: better},
        unanswered: {'left-out'},
        knownContacts: (uuids) async => uuids.toSet().difference({'not-here-yet', 'on-its-way'}),
      );

      expect([(await row(_claim(ref: '230'))).deleted, (await row(_claim(ref: '230'))).epoch], [false, 0]);
      expect((await row(_claim(ref: '291'))).deleted, isFalse);
      expect((await row(_claim(ref: '100'))).deleted, isTrue, reason: 'a contact this device holds and the pass saw claims nothing here');
      expect((await row(_claim(ref: '200'))).qso, 'here');
    });
  });

  group('merging synced rows', () {
    // Only a rescan raises an epoch, and a rescan is how a deletion lowers a
    // slot: if the better claim won instead, a deleted contact's claim would
    // come back from every device that had not heard of the deletion.
    test('a higher epoch wins even with the worse claim', () async {
      await claims.applyUpgrades([_claim(level: ClaimLevel.confirmed)]);
      final accepted = await claims.mergeFromSync([_claim(qso: 'runner-up', at: 5000, epoch: 1).toRecord()]);
      expect(accepted.single.qso, 'runner-up');
      final held = await row(_claim());
      expect([held.qso, held.synced], ['runner-up', true]);
    });

    test('at the same epoch the better claim wins, and a better local row goes back out', () async {
      await claims.applyUpgrades([_claim(qso: 'early', at: 1000)]);
      await markAllSynced();
      changes = 0;

      expect(await claims.mergeFromSync([_claim(qso: 'late', at: 9000).toRecord()]), isEmpty);
      final held = await row(_claim());
      expect([held.qso, held.synced], ['early', false], reason: 'the sender holds the worse row, so this device writes it back');
      expect(changes, 1);
    });

    // The server keeps the newer `updatedAtMillis` and knows nothing of the
    // slot rule: written back at its old stamp, the better row is dropped
    // there as stale and the worse one stands for every device.
    test('a row written back is stamped newer than the one it beat', () async {
      await claims.applyUpgrades([_claim(qso: 'early', at: 1000)]);
      final worse = _claim(qso: 'late', at: 9000, updatedAt: realNowMillis() + 60000);
      await claims.mergeFromSync([worse.toRecord()]);
      expect((await row(_claim())).updatedAtMillis, greaterThan(worse.updatedAtMillis!));
    });

    test('rows accepted from sync are announced, for the whole-log check', () async {
      final announced = <List<StoredClaim>>[];
      claims.merged.listen(announced.add);
      await claims.applyUpgrades([_claim(ref: '230', qso: 'early', at: 1000)]);

      await claims.mergeFromSync([_claim(ref: '230', qso: 'late', at: 9000).toRecord(), _claim(ref: '291', qso: 'new').toRecord()]);
      await Future<void>.delayed(Duration.zero);
      expect(announced.single.map((c) => c.ref), ['291'], reason: 'a row this device kept was not accepted');
    });

    // The withdrawal is stamped later than any local write, so only the rule
    // can keep the live row: an upgrade on a device that missed the rescan
    // refills the slot at the rescan's epoch, and must survive meeting it.
    test('at the same epoch a live claim beats a withdrawal, however much newer', () async {
      await claims.applyUpgrades([_claim(qso: 'live')]);
      expect(await claims.mergeFromSync([_claim(qso: 'live', deleted: true, updatedAt: 1 << 52).toRecord()]), isEmpty);
      expect((await row(_claim())).deleted, isFalse);
    });

    test('a row this device has never seen is taken as it is', () async {
      final accepted = await claims.mergeFromSync([_claim(epoch: 3).toRecord()]);
      final held = await row(_claim());
      expect([accepted.length, held.epoch, held.synced], [1, 3, true]);
    });

    test('both devices settle on the same row whichever order the rows arrive in', () async {
      final a = _claim(qso: 'a', at: 1000, label: 'A', updatedAt: 1);
      final b = _claim(qso: 'b', at: 1000, label: 'B', updatedAt: 2);
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
      final other = HaLoDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      final otherClaims = ClaimsRepository(other);

      await claims.mergeFromSync([a.toRecord()]);
      await claims.mergeFromSync([b.toRecord()]);
      await otherClaims.mergeFromSync([b.toRecord()]);
      await otherClaims.mergeFromSync([a.toRecord()]);

      final mine = await row(a);
      final theirs = await (other.select(other.claims)..where((c) => c.uuid.equals(a.uuid))).getSingle();
      expect(mine.qso, theirs.qso);
      expect(mine.qso, 'a');
    });
  });

  test('a checklist is the best live row per slot across sources', () async {
    await claims.applyUpgrades([_claim(ref: '230', qso: 'q1'), _claim(ref: '291', qso: 'q2')]);
    await claims.mergeFromSync([
      _claim(ref: '230', qso: null, at: null, level: ClaimLevel.verified, source: 'import:batch').toRecord(),
      _claim(ref: '110', qso: null, at: null, level: ClaimLevel.verified, source: 'import:batch', deleted: true).toRecord(),
    ]);

    final checklist = await claims.checklist(_program, 'KI2D@291');
    expect({for (final c in checklist) c.ref: c.level}, {'230': ClaimLevel.verified, '291': ClaimLevel.worked});
  });

  test('a contact\'s slots are found from the contact', () async {
    await claims.applyUpgrades([_claim(ref: '230', qso: 'q1'), _claim(ref: '230', band: '20m', qso: 'q1'), _claim(ref: '291', qso: 'q2')]);
    expect((await claims.heldBy(['q1'])).map((c) => c.band), unorderedEquals([null, '20m']));
  });

  group('pushing', () {
    test('a dirty row goes out, withdrawn ones included, and is marked synced once sent', () async {
      await claims.applyUpgrades([_claim(ref: '230'), _claim(ref: '291')]);
      await claims.writeRescan(_program, 1, {
        for (final c in [_claim(ref: '230')]) c.uuid: c,
      });
      final batch = await claims.unsyncedBatch(10);
      expect(batch.map((c) => (c.ref, c.deleted)), unorderedEquals([('230', false), ('291', true)]));

      await claims.markSynced(batch);
      expect(await claims.hasUnsynced(), isFalse);
      expect(await claims.unsyncedBatch(10, excluding: {_claim(ref: '230').uuid}), isEmpty);
    });

    // An upgrade landing while the push is on the network is a newer
    // revision the server has not seen. On a clock pinned to one millisecond
    // the rewrite carries the same reading as the revision that went out, and
    // a stamp taken from the clock alone would mark it synced.
    test('a row rewritten while its push was in flight stays dirty, within the same millisecond too', () async {
      final followed = AppClock.followZoneClock;
      AppClock.followZoneClock = true;
      addTearDown(() => AppClock.followZoneClock = followed);
      await withClock(Clock.fixed(DateTime.utc(2026, 10, 13)), () async {
        await claims.applyUpgrades([_claim(qso: 'worked')]);
        final sent = await claims.unsyncedBatch(10);
        await claims.applyUpgrades([_claim(qso: 'confirmed', level: ClaimLevel.confirmed)]);

        await claims.markSynced(sent);
        expect((await row(_claim())).synced, isFalse);
      });
    });

    test('clearing empties the table and says so', () async {
      var cleared = 0;
      claims.cleared.listen((_) => cleared++);
      await claims.applyUpgrades([_claim()]);

      await claims.clearAll();
      await Future<void>.delayed(Duration.zero);
      expect(await db.select(db.claims).get(), isEmpty);
      expect(cleared, 1);
    });

    // A pass that read the log before a clear — a device switching accounts
    // mid-rescan — would write the old log's rows into the emptied table,
    // naming contacts that are gone and that no later rescan here withdraws.
    test('a pass that began before a clear writes nothing after it', () async {
      final before = claims.generation;
      await claims.clearAll();
      expect(await claims.applyUpgrades([_claim()], generation: before), 0);
      expect(await claims.writeRescan(_program, 1, {_claim().uuid: _claim()}, generation: before), 0);
      expect(await db.select(db.claims).get(), isEmpty);
      expect(await claims.applyUpgrades([_claim()], generation: claims.generation), 1, reason: 'a pass begun since writes as usual');
    });
  });
}

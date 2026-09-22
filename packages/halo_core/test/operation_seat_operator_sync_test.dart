// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An operation's `data` merges whole-blob, last writer wins, and the operator
// of each operating position lives in it (`operator1`, `operator2`, …). Two
// seats naming their operators inside one sync window therefore race: each
// pushes a full copy built from its own snapshot, and the later one carries
// the other seat's slot as it was before that seat was filled.
//
// Who is at THIS key is the one thing a device knows better than any record
// arriving from elsewhere, so it survives the merge. Without that, the seat
// that loses the race finds itself empty again and stamps every contact it
// logs afterwards with nobody — silently, and into the exported log.

import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  late HaLoDatabase db;
  late OperationsRepository operations;

  setUp(() {
    db = HaLoDatabase(NativeDatabase.memory());
    operations = OperationsRepository(db);
  });

  tearDown(() async => db.close());

  /// A stored operation this device is logging from [position], with whatever
  /// operator slots it has named so far.
  Future<void> seatedAt(String position, Map<String, dynamic> operators) async {
    final operation = await operations.create(stationCall: 'K2SUL');
    await operations.saveData(Operation(uuid: operation.uuid, data: {...operation.data, ...operators}));
    if (position.isNotEmpty) await operations.updateLocalData(operation.uuid, {'multiIdentifier': position});
  }

  /// The same operation as it arrives from elsewhere — deliberately newer, so
  /// nothing but the seat rule can be what keeps a local value.
  Map<String, dynamic> inbound(Map<String, dynamic> operators) => {
    'uuid': (operators.remove('uuid') as String?) ?? 'op',
    'stationCall': 'K2SUL',
    'updatedAtMillis': 9999999999999,
    ...operators,
  };

  Future<Operation> stored() async => (await operations.watchAll().first).single;

  test("an inbound record may not rename the operator of this device's own seat", () async {
    await seatedAt('2', {'operator1': 'KI2D', 'operator2': 'W2ABC'});
    final uuid = (await stored()).uuid;

    // The other seat's push, built before this device named W2ABC.
    await operations.mergeFromSync([
      inbound({'uuid': uuid, 'operator1': 'N0DEV', 'operator2': 'STALE'}),
    ]);

    final after = await stored();
    expect(after.data['operator2'], 'W2ABC');
    // Every other seat is somebody else's to state — this rule defends one
    // slot, it does not freeze the record.
    expect(after.data['operator1'], 'N0DEV');
  });

  test('a defended seat goes back out, rather than being repaired here alone', () async {
    // The splice is a CHANGE to the record the sender holds, not a copy of
    // it. Left marked synced it never reaches `pendingOperations`, so the
    // server and every other device would keep naming the operator this
    // device just rejected — for good, and in their exports.
    await seatedAt('2', {'operator2': 'W2ABC'});
    final before = await stored();

    await operations.mergeFromSync([
      inbound({'uuid': before.uuid, 'operator2': 'STALE'}),
    ]);

    final after = await stored();
    expect(after.synced, isFalse);
    expect(await operations.unsyncedBatch(10), isNotEmpty);
    // And as a NEWER revision than the record it rejected — the inbound
    // stamp here is deliberately far in the future, the shape a sender with a
    // fast clock produces. At the sender's stamp, or at a real-clock reading
    // below it, this device's version loses the staleness gate (>=) wherever
    // it lands and the repair never leaves this device.
    expect(after.updatedAtMillis, greaterThan(9999999999999));
  });

  test('a record that changes nothing this device defends stays clean', () async {
    // The ordinary case — every operation merging in while a device happens
    // to sit in a seat must not turn into an outbound push.
    await seatedAt('2', {'operator2': 'W2ABC'});
    final uuid = (await stored()).uuid;

    await operations.mergeFromSync([
      inbound({'uuid': uuid, 'operator2': 'W2ABC', 'operator1': 'KI2D'}),
    ]);

    final after = await stored();
    expect(after.synced, isTrue);
    expect(after.data['operator1'], 'KI2D');
  });

  test('a device in no position keeps nothing of its own', () async {
    await seatedAt('', {'operatorCall': 'KI2D'});
    final uuid = (await stored()).uuid;

    await operations.mergeFromSync([
      inbound({'uuid': uuid, 'operatorCall': 'N0DEV'}),
    ]);

    expect((await stored()).data['operatorCall'], 'N0DEV');
  });

  test('a seat that names nobody takes what the record brings', () async {
    // Nothing to defend: the operator of seat 2 is being learned here, which
    // is exactly what syncing the slots is for.
    await seatedAt('2', const {});
    final uuid = (await stored()).uuid;

    await operations.mergeFromSync([
      inbound({'uuid': uuid, 'operator2': 'W2ABC'}),
    ]);

    expect((await stored()).data['operator2'], 'W2ABC');
  });

  test('an emptied seat stays emptied — it is a value this device stated', () async {
    await seatedAt('2', {'operator2': ''});
    final uuid = (await stored()).uuid;

    await operations.mergeFromSync([
      inbound({'uuid': uuid, 'operator2': 'W2ABC'}),
    ]);

    expect((await stored()).data['operator2'], '');
  });

  test('the same rule applies to a record from a peer', () async {
    // The peer path is a sibling of mergeFromSync, not a caller of it, so a
    // rule added to one is silently missing from the other.
    await seatedAt('3', {'operator3': 'KI2D'});
    final uuid = (await stored()).uuid;

    await operations.mergeFromPeer([
      inbound({'uuid': uuid, 'operator3': 'N0DEV'}),
    ]);

    expect((await stored()).data['operator3'], 'KI2D');
  });
}

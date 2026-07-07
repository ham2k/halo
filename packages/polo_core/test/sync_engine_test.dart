// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:drift/native.dart';
import 'package:polo_core/polo_core.dart';
import 'package:test/test.dart';

class _FakeSyncSettings implements SyncSettings {
  @override
  bool enabled = true;
  @override
  Map<String, dynamic> state = const {};

  @override
  Future<void> setState(Map<String, dynamic> newState) async => state = newState;
}

typedef _TransportResponder = Map<String, dynamic> Function(String method, Map<String, dynamic> args);

/// Records every call and answers with whatever [responder] returns —
/// standing in for the `ham2k-lofi` extension without a real network.
class _FakeTransport {
  final List<(String, Map<String, dynamic>)> calls = [];
  _TransportResponder responder;
  _FakeTransport(this.responder);

  Future<Map<String, dynamic>> call(String method, Map<String, dynamic> args) async {
    calls.add((method, args));
    return responder(method, args);
  }
}

void main() {
  late PoloDatabase db;
  late OperationsRepository operations;
  late QsosRepository qsos;
  late _FakeSyncSettings settings;
  late _FakeTransport transport;
  late SyncEngine engine;

  setUp(() {
    db = PoloDatabase(NativeDatabase.memory());
    operations = OperationsRepository(db);
    qsos = QsosRepository(db);
    settings = _FakeSyncSettings();
    transport = _FakeTransport((method, args) => const {});
    engine = SyncEngine(operations: operations, qsos: qsos, transport: transport.call, settings: settings);
  });

  tearDown(() async {
    engine.dispose();
    await db.close();
  });

  test('selectBatch is empty when nothing is dirty', () async {
    final batch = await engine.selectBatch(qsoBatchSize: 10, operationBatchSize: 10);
    expect(batch.isEmpty, isTrue);
  });

  test('selectBatch brings in QSOs and their still-unsynced parent operation', () async {
    final op = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, {'their': {'call': 'W1AW'}, 'startAtMillis': 1000});

    final batch = await engine.selectBatch(qsoBatchSize: 10, operationBatchSize: 10);
    expect(batch.qsos, hasLength(1));
    expect(batch.operations.map((o) => o.uuid), [op.uuid]);
  });

  test('selectBatch falls back to unsynced operations when no QSOs are pending', () async {
    final op = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, {'their': {'call': 'W1AW'}});
    await operations.markSynced([op.uuid]);
    await qsos.markSynced((await qsos.watchForOperation(op.uuid).first).map((q) => q.uuid));

    await operations.saveData(Operation(uuid: op.uuid, data: {...op.data, 'title': 'Renamed'}));

    final batch = await engine.selectBatch(qsoBatchSize: 10, operationBatchSize: 10);
    expect(batch.qsos, isEmpty);
    expect(batch.operations.map((o) => o.uuid), [op.uuid]);
  });

  test('runOneRound sends dirty rows, marks them synced, and merges the response', () async {
    final op = await operations.create(stationCall: 'KI2D');
    final qso = await qsos.add(op.uuid, {'their': {'call': 'W1AW'}, 'startAtMillis': 1000});

    transport.responder = (method, args) {
      expect(method, 'sync');
      final sentQsos = (args['qsos'] as List).cast<Map>();
      expect(sentQsos.single['uuid'], qso.uuid);
      expect(sentQsos.single['operation'], op.uuid);
      return {
        'qsos': [
          {
            'uuid': 'inbound-qso',
            'operation': op.uuid,
            'their': {'call': 'N1MM'},
            'startAtMillis': 2000,
          },
        ],
        'account': {'uuid': 'acct-1'},
      };
    };

    await engine.runOneRound();

    expect(transport.calls, hasLength(1));
    expect((await operations.byUuids([op.uuid])).single.deleted, isFalse); // sanity: still there
    expect(await operations.hasUnsynced(), isFalse);
    expect(await qsos.hasUnsynced(), isFalse);

    final merged = await qsos.watchForOperation(op.uuid).first;
    expect(merged.map((q) => q.theirCall), containsAll(['W1AW', 'N1MM']));
    expect(settings.state['lastSyncAccountUUID'], 'acct-1');
  });

  test('runOneRound does nothing when sync is disabled', () async {
    settings.enabled = false;
    await operations.create(stationCall: 'KI2D');

    await engine.runOneRound();

    expect(transport.calls, isEmpty);
  });

  test('a suggested batch size from the server is applied to the next round', () async {
    final op = await operations.create(stationCall: 'KI2D');
    for (var i = 0; i < 15; i++) {
      await qsos.add(op.uuid, {'their': {'call': 'W1AW$i'}, 'startAtMillis': i});
    }

    var round = 0;
    transport.responder = (method, args) {
      round++;
      final sent = (args['qsos'] as List).length;
      if (round == 1) {
        expect(sent, SyncEngine.defaultLargeBatchSize); // capped at the default (10) the first time
        return {
          'meta': {'suggestedSyncBatchSize': 20},
        };
      }
      expect(sent, 5); // the remaining 15 - 10 QSOs, now that the cap is 20
      return const {};
    };

    await engine.runOneRound();
    await engine.runOneRound();

    expect(round, 2);
    expect(await qsos.hasUnsynced(), isFalse);
  });

  test('notifyChanged debounces into a small-batch round', () async {
    await operations.create(stationCall: 'KI2D');

    engine.notifyChanged();
    expect(transport.calls, isEmpty); // not yet — still debouncing

    await Future<void>.delayed(SyncEngine.debounceDelay + const Duration(milliseconds: 200));
    expect(transport.calls, hasLength(1));
  });
}

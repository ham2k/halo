// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

class _FakeSyncSettings implements SyncSettings {
  @override
  bool enabled = true;
  @override
  Map<String, dynamic> state;

  _FakeSyncSettings({Map<String, dynamic>? state}) : state = state ?? const {};

  @override
  Future<void> setState(Map<String, dynamic> newState) async => state = newState;

  bool devModeVal = false;
  @override
  bool get developerMode => devModeVal;
  @override
  Future<void> setDeveloperMode(bool enabled) async => devModeVal = enabled;
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
  late HaLoDatabase db;
  late OperationsRepository operations;
  late QsosRepository qsos;
  late _FakeSyncSettings settings;
  late _FakeTransport transport;
  late SyncEngine engine;

  setUp(() {
    db = HaLoDatabase(NativeDatabase.memory());
    operations = OperationsRepository(db);
    qsos = QsosRepository(db);
    // Already linked and backfilled, by default — most tests exercise
    // ordinary forward push/pull, not the account-identity/backfill state
    // machine (see the "account identity and backfill" group below, which
    // starts from a genuinely blank state).
    settings = _FakeSyncSettings(state: {'lastSyncAccountUUID': 'acct-1', 'completedFullSync': true});
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
    await operations.markSynced([op]);
    await qsos.markSynced(await qsos.watchForOperation(op.uuid).first);

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

  test('a periodic round pulls even when there is nothing local to push', () async {
    transport.responder = (method, args) {
      expect(args.containsKey('operations'), isFalse);
      expect(args.containsKey('qsos'), isFalse);
      final meta = args['meta'] as Map;
      // The real server ignores `meta.sync` entirely unless this flag is
      // also set — a genuine bug this test caught: it's easy to port
      // `meta.sync` from sync.js and miss the separate `meta.inboundSync`
      // flag sitting right next to it, and get a silent, error-free
      // "nothing to pull, ever" response instead.
      expect(meta['inboundSync'], isTrue);
      final sync = meta['sync'] as Map;
      expect(sync['operations'], {'syncedSinceMillis': 0, 'limit': SyncEngine.defaultLargeBatchSize, 'anyClient': false});
      expect(sync['qsos'], {'syncedSinceMillis': 0, 'limit': SyncEngine.defaultLargeBatchSize, 'anyClient': false});
      return const {};
    };

    await engine.runOneRound();

    expect(transport.calls, hasLength(1));
  });

  test('a small-batch round never asks to pull', () async {
    await operations.create(stationCall: 'KI2D');

    transport.responder = (method, args) {
      expect((args['meta'] as Map).containsKey('sync'), isFalse);
      expect((args['meta'] as Map).containsKey('inboundSync'), isFalse);
      return const {};
    };

    await engine.runOneRound(smallBatch: true);

    expect(transport.calls, hasLength(1));
  });

  test('a periodic round tracks the sync watermark from inbound records and asks since it next time', () async {
    var round = 0;
    transport.responder = (method, args) {
      round++;
      final sync = (args['meta'] as Map)['sync'] as Map;
      if (round == 1) {
        expect((sync['qsos'] as Map)['syncedSinceMillis'], 0);
        return {
          'qsos': [
            {
              'uuid': 'q1',
              'operation': 'op1',
              'their': {'call': 'W1AW'},
              'startAtMillis': 1000,
              'syncedAtMillis': 5000,
            },
          ],
        };
      }
      expect((sync['qsos'] as Map)['syncedSinceMillis'], 5000);
      return const {};
    };

    await engine.runOneRound();
    await engine.runOneRound();

    expect(round, 2);
    expect(settings.state['latestQSOSyncedAtMillis'], 5000);
  });

  test('a full page of inbound records reschedules the loop immediately', () async {
    // A server with 15 pending QSOs to hand back: a full page (10) the
    // first call, a partial page (5) once the client's advancing
    // syncedSinceMillis catches up — the same "keep looping until caught
    // up" shape as app-polo's `receivedAllUpdates`.
    const totalAvailable = 15;
    transport.responder = (method, args) {
      final since = (((args['meta'] as Map)['sync'] as Map)['qsos'] as Map)['syncedSinceMillis'] as int;
      final remaining = [
        for (var i = since; i < totalAvailable; i++)
          {
            'uuid': 'inbound-$i',
            'operation': 'op1',
            'their': {'call': 'W1AW$i'},
            'startAtMillis': i,
            'syncedAtMillis': i + 1,
          },
      ];
      return {'qsos': remaining.take(SyncEngine.defaultLargeBatchSize).toList()};
    };

    await engine.runOneRound();
    expect(transport.calls, hasLength(1)); // first page: 10 records, a full page

    // A full page implies more is waiting server-side, so the loop
    // reschedules with no delay rather than waiting defaultLoopDelay (20s).
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(transport.calls, hasLength(2)); // second page: the remaining 5, not a full page — loop settles
  });

  test('notifyChanged debounces into a small-batch round', () async {
    await operations.create(stationCall: 'KI2D');

    engine.notifyChanged();
    expect(transport.calls, isEmpty); // not yet — still debouncing

    await Future<void>.delayed(SyncEngine.debounceDelay + const Duration(milliseconds: 200));
    expect(transport.calls, hasLength(1));
  });

  group('account identity and backfill', () {
    setUp(() {
      // A genuinely fresh device: no account linked yet, nothing backfilled.
      settings = _FakeSyncSettings();
      engine = SyncEngine(operations: operations, qsos: qsos, transport: transport.call, settings: settings);
    });

    test('a never-linked device only calls getAccountData, never pushes or pulls real data', () async {
      transport.responder = (method, args) {
        expect(method, 'getAccountData');
        return {
          'current_account': {'uuid': 'acct-new'},
        };
      };

      await engine.runOneRound();

      expect(transport.calls, hasLength(1));
      expect(settings.state['pendingAccountUUID'], 'acct-new');
      expect(settings.state['lastSyncAccountUUID'], isNull);
    });

    test('a pending account choice pauses sync entirely', () async {
      settings.state = {'pendingAccountUUID': 'acct-new'};
      await operations.create(stationCall: 'KI2D'); // some local data, just in case

      await engine.runOneRound();
      await engine.runOneRound(smallBatch: true);

      expect(transport.calls, isEmpty);
    });

    test('resolveAccountChange(combine) resets sync flags and starts a fresh backfill', () async {
      final op = await operations.create(stationCall: 'KI2D');
      await qsos.add(op.uuid, {'their': {'call': 'W1AW'}});
      await operations.markSynced([op]);
      await qsos.markSynced(await qsos.watchForOperation(op.uuid).first);
      settings.state = {'pendingAccountUUID': 'acct-new'};

      transport.responder = (method, args) => const {};
      await engine.resolveAccountChange(SyncAccountChoice.combine);

      // resetSyncedStatus runs synchronously inside resolveAccountChange,
      // before the round it schedules even starts.
      expect(settings.state['lastSyncAccountUUID'], 'acct-new');
      expect(settings.state['pendingAccountUUID'], isNull);
      expect(await operations.hasUnsynced(), isTrue); // reset, not deleted
      expect(await qsos.hasUnsynced(), isTrue);

      // Give the immediately-scheduled round a moment to run and confirm it
      // backfills (anyClient: true), not forward mode — and that local data
      // survived (combine keeps it, unlike replace).
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(transport.calls, isNotEmpty);
      final sync = (transport.calls.last.$2['meta'] as Map)['sync'] as Map;
      expect((sync['qsos'] as Map)['anyClient'], isTrue);
      expect(await operations.byUuids([op.uuid]), isNotEmpty);
    });

    test('resolveAccountChange(replace) backs up local data and clears it', () async {
      final op = await operations.create(stationCall: 'KI2D');
      await qsos.add(op.uuid, {'their': {'call': 'W1AW'}});
      settings.state = {'pendingAccountUUID': 'acct-new'};

      transport.responder = (method, args) => const {};
      await engine.resolveAccountChange(SyncAccountChoice.replace);

      expect(await operations.byUuids([op.uuid]), isEmpty);
      expect((await qsos.watchForOperation(op.uuid).first), isEmpty);

      final backedUpOps = await db.select(db.operationsBackup).get();
      final backedUpQsos = await db.select(db.qsosBackup).get();
      expect(backedUpOps.map((r) => r.uuid), [op.uuid]);
      expect(backedUpQsos, hasLength(1));
      expect(settings.state['lastSyncAccountUUID'], 'acct-new');
    });

    test('backfill pages backward and hands off to forward mode once caught up', () async {
      settings.state = {'lastSyncAccountUUID': 'acct-1'}; // linked, but completedFullSync is not yet true
      const totalAvailable = 15;
      // A server holding 15 historical QSOs (syncedAtMillis 0..14, oldest
      // first). Each call returns whatever's strictly older than `until`,
      // newest-first, capped at the page limit — the same "keep asking for
      // what's older than my cursor" shape the real server implements.
      transport.responder = (method, args) {
        final until = (((args['meta'] as Map)['sync'] as Map)['qsos'] as Map)['syncedUntilMillis'] as int;
        expect((((args['meta'] as Map)['sync'] as Map)['qsos'] as Map)['anyClient'], isTrue);
        final page = [
          for (var s = totalAvailable - 1; s >= 0; s--)
            if (s < until)
              {
                'uuid': 'hist-$s',
                'operation': 'op1',
                'their': {'call': 'W1AW$s'},
                'startAtMillis': s,
                'syncedAtMillis': s,
              },
        ].take(SyncEngine.defaultLargeBatchSize).toList();
        return {'qsos': page};
      };

      // First round: syncedUntilMillis defaults to "now" (a large number),
      // so it returns a full page and keeps backfilling.
      await engine.runOneRound();
      expect(settings.state['completedFullSync'], isNot(true));

      // Keep running rounds until the (small, 15-record) history is
      // exhausted and the engine flips over to forward mode.
      var guard = 0;
      while (settings.state['completedFullSync'] != true && guard < 10) {
        await engine.runOneRound();
        guard++;
      }

      expect(settings.state['completedFullSync'], isTrue);
      expect(settings.state['latestQSOSyncedAtMillis'], isNotNull);
      final merged = await qsos.watchForOperation('op1').first;
      expect(merged, hasLength(totalAvailable));
    });

    test('an account change mid-stream pauses sync without merging that response', () async {
      settings.state = {'lastSyncAccountUUID': 'acct-1', 'completedFullSync': true};
      transport.responder = (method, args) => {
            'account': {'uuid': 'acct-2'}, // a different account than expected
            'qsos': [
              {
                'uuid': 'suspect-qso',
                'operation': 'op1',
                'their': {'call': 'SHOULDNOTMERGE'},
              },
            ],
          };

      await engine.runOneRound();

      expect(settings.state['pendingAccountUUID'], 'acct-2');
      expect(settings.state['lastSyncAccountUUID'], 'acct-1'); // unchanged until resolved
      expect(await qsos.watchForOperation('op1').first, isEmpty); // not merged
    });

    test('forceFullResync (SYNCALL) backs up and clears data without touching account state', () async {
      settings.state = {'lastSyncAccountUUID': 'acct-1', 'completedFullSync': true};
      final op = await operations.create(stationCall: 'KI2D');
      await qsos.add(op.uuid, {'their': {'call': 'W1AW'}});

      transport.responder = (method, args) => const {};
      await engine.forceFullResync();

      expect(await operations.byUuids([op.uuid]), isEmpty);
      final backedUpOps = await db.select(db.operationsBackup).get();
      expect(backedUpOps.map((r) => r.uuid), [op.uuid]);
      expect(settings.state['lastSyncAccountUUID'], 'acct-1'); // untouched
      expect(settings.state['pendingAccountUUID'], isNull);
      expect(settings.state['completedFullSync'], isNot(true));
    });
  });
}

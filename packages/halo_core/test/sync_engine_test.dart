// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

// `extends`, not `implements`, so the fake inherits the interface's default
// developerMode stubs instead of restating them.
class _FakeSyncSettings extends SyncSettings {
  @override
  bool enabled = true;
  @override
  Map<String, dynamic> state;
  @override
  String operatorCall = 'KI2D';

  /// Fires after every write, so a test can act at the exact moment a
  /// particular key lands — the only way to hit a race whose window is one
  /// await wide.
  void Function(Map<String, dynamic> state)? onStateSet;

  _FakeSyncSettings({Map<String, dynamic>? state}) : state = state ?? const {};

  @override
  Future<void> setState(Map<String, dynamic> newState) async {
    state = newState;
    onStateSet?.call(newState);
  }
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

  // Ordinary rounds RUN on a travelled clock; only the destructive pair
  // refuse (docs/design/time.md §4). What a travelled session may write is
  // constrained instead — `WritePolicy` admits only test data — so a bar here
  // would protect nothing, while making sync itself untestable travelled.
  //
  // Asserted against the ENGINE, on the transport it would use: an assertion
  // on `AppClock.isTravelling` would restate the clock's own state and pass
  // whatever the engine did with it.
  group('time travel and sync', () {
    tearDown(AppClock.instance.reset);

    Future<void> dirtyRow() async {
      final op = await operations.create(stationCall: 'KI2D');
      await qsos.add(op.uuid, {'their': {'call': 'W1AW'}, 'startAtMillis': 1000});
    }

    test('an ordinary round reaches the transport while travelled', () async {
      await dirtyRow();
      AppClock.instance.travel(delta: const Duration(days: 3));

      await engine.runOneRound(smallBatch: false);

      expect(transport.calls, isNotEmpty,
          reason: 'the clock no longer bars a round — the write gate bounds what can be in it');
    });

    test('the loop keeps running too, not just a hand-driven round', () async {
      // `start`/`notifyChanged` is a second entry point into the same engine,
      // and the bar this replaced lived where both of them passed through.
      AppClock.instance.travel(delta: const Duration(days: 3));
      await dirtyRow();
      engine.start();
      engine.notifyChanged();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(transport.calls, isNotEmpty);
    });

    // The destructive pair still refuse while travelled, and have to do it
    // BEFORE they act: each wipes local data into the backup tables and relies
    // on a later round to refill it. That is a different hazard from the one
    // the write gate covers — it is about a dev tool triggering a wipe at all,
    // not about which records a round may carry — which is why removing the
    // bar on ordinary rounds did not remove these.
    test('forceFullResync refuses without wiping anything', () async {
      await dirtyRow();
      final before = (await operations.syncCounts()).total;
      expect(before, 1, reason: 'sanity: there is something to lose');
      AppClock.instance.travel(delta: const Duration(days: 3));

      expect(await engine.forceFullResync(), isFalse);
      expect((await operations.syncCounts()).total, before, reason: 'the log must still be there');
      expect((await qsos.syncCounts()).total, 1);
      expect(settings.state['completedFullSync'], isTrue, reason: 'and its bookkeeping untouched');
    });

    test('resolveAccountChange refuses without reconciling anything', () async {
      await dirtyRow();
      settings.state = {...settings.state, 'pendingAccountUUID': 'acct-2'};
      AppClock.instance.travel(delta: const Duration(days: 3));

      expect(await engine.resolveAccountChange(SyncAccountChoice.replace), isFalse);
      expect((await qsos.syncCounts()).total, 1, reason: 'replace must not have wiped');
      expect(settings.state['pendingAccountUUID'], 'acct-2',
          reason: 'and the question must still be pending, not silently answered');
    });

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

  test('a failing round reports the error via onError, in addition to log', () async {
    final loggedLines = <String>[];
    final reported = <(Object, StackTrace?, String?)>[];
    final reportingEngine = SyncEngine(
      operations: operations,
      qsos: qsos,
      transport: transport.call,
      settings: settings,
      log: loggedLines.add,
      onError: (error, stackTrace, {context}) => reported.add((error, stackTrace, context)),
    );
    addTearDown(reportingEngine.dispose);

    transport.responder = (method, args) => throw StateError('server unreachable');

    // Every failure mode (HTTP error, auth rejection, a dead extension
    // runtime) funnels into this one catch, and it must never be silent —
    // "not syncing" has to stay diagnosable. The log takes every failure
    // from the first.
    await reportingEngine.runOneRound();
    expect(loggedLines, hasLength(1));
    // ...but the loop retries forever, so crash-reporting the first failure
    // files an event every few minutes for as long as a device is offline.
    expect(reported, isEmpty);

    for (var i = 1; i < SyncEngine.errorReportThreshold; i++) {
      await reportingEngine.runOneRound();
    }
    expect(loggedLines, hasLength(SyncEngine.errorReportThreshold));
    expect(reported, hasLength(1));
    expect(reported.single.$1, isA<StateError>());
    expect(reported.single.$3, contains('sync:round'));

    // And exactly once: past the threshold a permanently offline device
    // would otherwise just trade a flood of first failures for a flood of
    // streak reports.
    await reportingEngine.runOneRound();
    await reportingEngine.runOneRound();
    expect(reported, hasLength(1));
  });

  test('a round that succeeds resets the streak, so the next failure is a blip again', () async {
    final reported = <(Object, StackTrace?, String?)>[];
    final resettingEngine = SyncEngine(
      operations: operations,
      qsos: qsos,
      transport: transport.call,
      settings: settings,
      onError: (error, stackTrace, {context}) => reported.add((error, stackTrace, context)),
    );
    addTearDown(resettingEngine.dispose);

    var failing = true;
    transport.responder = (method, args) {
      if (failing) throw StateError('server unreachable');
      return const {};
    };

    // Two failures, a success, then two more: four failures, never three in
    // a row. Without the reset, a flaky connection reports for what is
    // really an intermittent one.
    await resettingEngine.runOneRound();
    await resettingEngine.runOneRound();
    failing = false;
    await resettingEngine.runOneRound();
    failing = true;
    await resettingEngine.runOneRound();
    await resettingEngine.runOneRound();

    expect(reported, isEmpty);
  });

  test('runOneRound does nothing when sync is disabled', () async {
    settings.enabled = false;
    await operations.create(stationCall: 'KI2D');

    await engine.runOneRound();

    expect(transport.calls, isEmpty);
  });

  test('a suggested batch size from the server is applied to the next round', () async {
    final op = await operations.create(stationCall: 'KI2D');
    for (var i = 0; i < 120; i++) {
      await qsos.add(op.uuid, {'their': {'call': 'W1AW$i'}, 'startAtMillis': i});
    }

    var round = 0;
    transport.responder = (method, args) {
      round++;
      final sent = (args['qsos'] as List).length;
      if (round == 1) {
        expect(sent, SyncEngine.defaultLargeBatchSize); // capped at the default (100) the first time
        return {
          'meta': {'suggestedSyncBatchSize': 20},
        };
      }
      expect(sent, 20); // the remaining 120 - 100 QSOs, now that the cap is 20
      return const {};
    };

    await engine.runOneRound();
    await engine.runOneRound();

    expect(round, 2);
    expect(await qsos.hasUnsynced(), isFalse);
  });

  test('server tuning knobs nested under meta.flags (the real server shape) are honored', () async {
    final op = await operations.create(stationCall: 'KI2D');
    for (var i = 0; i < 120; i++) {
      await qsos.add(op.uuid, {'their': {'call': 'W1AW$i'}, 'startAtMillis': i});
    }

    var round = 0;
    transport.responder = (method, args) {
      round++;
      if (round == 1) {
        // api-lofi's Client#meta_for_client: snake_case, nested in flags —
        // NOT top-level camelCase. Reading only the latter silently keeps
        // the defaults and the loop then hammers the server's cooldown.
        return {
          'meta': {
            'flags': {'suggested_sync_batch_size': 20, 'suggested_sync_loop_delay': 35000},
          },
        };
      }
      expect((args['qsos'] as List).length, 20);
      return const {};
    };

    await engine.runOneRound();
    await engine.runOneRound();
    expect(round, 2);
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
    // A server with 150 pending QSOs to hand back: a full page (100) the
    // first call, a partial page (50) once the client's advancing
    // syncedSinceMillis catches up — the same "keep looping until caught
    // up" shape as app-polo's `receivedAllUpdates`.
    const totalAvailable = 150;
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
    expect(transport.calls, hasLength(1)); // first page: 100 records, a full page

    // A full page implies more is waiting server-side, so the loop
    // reschedules with no delay rather than waiting defaultLoopDelay (20s).
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(transport.calls, hasLength(2)); // second page: the remaining 50, not a full page — loop settles
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
      // Both sides hold a log, so the change is one only the user can
      // settle — see the silent-adoption tests below for the other case.
      final op = await operations.create(stationCall: 'KI2D');
      await qsos.add(op.uuid, {'their': {'call': 'W1AW'}});
      transport.responder = (method, args) {
        expect(method, 'getAccountData');
        return {
          'current_account': {'uuid': 'acct-new'},
          'operations': {'total': 3},
          'qsos': {'total': 42},
        };
      };

      await engine.runOneRound();

      expect(transport.calls, hasLength(1));
      expect(settings.state['pendingAccountUUID'], 'acct-new');
      expect(settings.state['lastSyncAccountUUID'], isNull);
    });

    test('a device with nothing logged adopts a new account without asking', () async {
      transport.responder = (method, args) => method == 'getAccountData'
          ? {
              'current_account': {'uuid': 'acct-new'},
              'operations': {'total': 3},
              'qsos': {'total': 42},
            }
          : const {};

      await engine.runOneRound();

      // Resolved as combine on the user's behalf: nothing local to lose, so
      // the banner would be a question with one answer.
      expect(settings.state['pendingAccountUUID'], isNull);
      expect(settings.state['lastSyncAccountUUID'], 'acct-new');
    });

    test('an operation with no QSOs in it is not data worth asking about', () async {
      // A container, not a log — combining merges it in rather than losing
      // it, which is why the test is on the QSO count alone.
      await operations.create(stationCall: 'KI2D');
      transport.responder = (method, args) => method == 'getAccountData'
          ? {
              'current_account': {'uuid': 'acct-new'},
              'qsos': {'total': 42},
              'operations': {'total': 3},
            }
          : const {};

      await engine.runOneRound();

      expect(settings.state['lastSyncAccountUUID'], 'acct-new');
      expect(settings.state['pendingAccountUUID'], isNull);
    });

    test('an empty account is adopted without asking even when this device has a log', () async {
      final op = await operations.create(stationCall: 'KI2D');
      await qsos.add(op.uuid, {'their': {'call': 'W1AW'}});
      transport.responder = (method, args) => method == 'getAccountData'
          ? {
              'current_account': {'uuid': 'acct-new'},
              'operations': {'total': 0},
              'qsos': {'total': 0},
            }
          : const {};

      await engine.runOneRound();

      expect(settings.state['lastSyncAccountUUID'], 'acct-new');
      expect(settings.state['pendingAccountUUID'], isNull);
      // Combine, not replace: the local log is still here and re-dirtied so
      // it uploads into the account.
      expect(await operations.byUuids([op.uuid]), isNotEmpty);
      expect(await qsos.hasUnsynced(), isTrue);
    });

    test('the user answering the banner mid-check wins over the silent adoption', () async {
      // The banner goes live the instant pendingAccountUUID is written, so
      // it can be answered while the emptiness check is still awaiting. If
      // that check then adopts anyway it overwrites a real decision with a
      // guess — and since Replace empties the local log, the check would
      // find nothing and adopt every time.
      final op = await operations.create(stationCall: 'KI2D');
      await qsos.add(op.uuid, {'their': {'call': 'W1AW'}});
      transport.responder = (method, args) => {
            'current_account': {'uuid': 'acct-new'},
            'operations': {'total': 0},
            'qsos': {'total': 0},
          };
      // Every account this device is told it belongs to, in order. The end
      // state alone proves nothing here: a de-link leaves `lastSyncAccountUUID`
      // null, the next round re-enters the never-linked branch, and — over
      // the log Replace just emptied — silently adopts the same account
      // again. The damage is real and the final value looks correct, so the
      // assertion has to be on the history.
      final linkedTo = <Object?>[];
      settings.onStateSet = (state) {
        if (state.containsKey('lastSyncAccountUUID')) linkedTo.add(state['lastSyncAccountUUID']);
        // Answer the banner the instant it goes live, the way a tap would —
        // which is the instant pendingAccountUUID is written, mid-round.
        if (state['pendingAccountUUID'] == null) return;
        unawaited(engine.resolveAccountChange(SyncAccountChoice.replace));
      };

      await engine.runOneRound();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(linkedTo, isNot(contains(null)), reason: 'a null lastSyncAccountUUID is a device that forgot its account');
      expect(settings.state['lastSyncAccountUUID'], 'acct-new');
      expect(settings.state['pendingAccountUUID'], isNull);
      // Replace's answer stands — the local log really was backed up and
      // cleared, not merged.
      expect(await operations.byUuids([op.uuid]), isEmpty);
    });

    test('an account reporting no counts at all is still asked about', () async {
      // Silence is not "empty". Reading a payload that predates these
      // fields as an empty account would merge this device's log into a
      // stranger's history without ever asking.
      final op = await operations.create(stationCall: 'KI2D');
      await qsos.add(op.uuid, {'their': {'call': 'W1AW'}});
      transport.responder = (method, args) => {
            'current_account': {'uuid': 'acct-new'},
          };

      await engine.runOneRound();

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
      const totalAvailable = 250;
      // A server holding 250 historical QSOs (syncedAtMillis 0..249, oldest
      // first). Each call returns whatever's strictly older than `until`,
      // newest-first, capped at the page limit — the same "keep asking for
      // what's older than my cursor" shape the real server implements. It
      // reports no recordsLeft meta, so this also covers the legacy-server
      // fallback: completion inferred from a shorter-than-limit page.
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

      // Keep running rounds until the (250-record) history is
      // exhausted and the engine flips over to forward mode.
      var guard = 0;
      while (settings.state['completedFullSync'] != true && guard < 10) {
        await engine.runOneRound();
        guard++;
      }

      expect(settings.state['completedFullSync'], isTrue);
      // The forward watermark is the largest *server* stamp seen across the
      // backfill (249) — never the local clock, which would permanently skip
      // records other devices synced while this backfill ran (or anything
      // in a clock-skew window).
      expect(settings.state['latestQSOSyncedAtMillis'], totalAvailable - 1);
      final merged = await qsos.watchForOperation('op1').first;
      expect(merged, hasLength(totalAvailable));
    });

    test('an empty backfill page with recordsLeft pending never completes backfill early', () async {
      settings.state = {'lastSyncAccountUUID': 'acct-1'};
      // A cooldown-gated server: it reports 5 records still waiting but
      // returns none of them for a while. Inferring completion from the
      // short page (the pre-20a23100 app-polo bug) would permanently set
      // completedFullSync and skip those records forever.
      var gated = true;
      transport.responder = (method, args) {
        if (gated) {
          return {
            'meta': {'qsos': {'recordsLeft': 5}},
          };
        }
        return {
          'qsos': [
            for (var s = 0; s < 5; s++)
              {
                'uuid': 'hist-$s',
                'operation': 'op1',
                'their': {'call': 'W1AW$s'},
                'startAtMillis': s,
                'syncedAtMillis': s,
              },
          ],
          // snake_case on purpose — the server has sent both spellings and
          // the engine must accept either, like app-polo does.
          'meta': {'qsos': {'records_left': 0}},
        };
      };

      await engine.runOneRound();
      await engine.runOneRound();
      expect(settings.state['completedFullSync'], isNot(true)); // empty pages, but the server says 5 remain

      gated = false;
      await engine.runOneRound();
      expect(settings.state['completedFullSync'], isTrue);
      expect(await qsos.watchForOperation('op1').first, hasLength(5));
    });

    test('backfill survives a page-sized timestamp tie without skipping records or hot-looping', () async {
      settings.state = {'lastSyncAccountUUID': 'acct-1'};
      // 120 QSOs all sharing syncedAtMillis 100 — a server-side bulk import
      // larger than a full page (100). The server pages with strict `<`
      // semantics: once the cursor reaches the tie's own stamp, a naive
      // client would get an empty page and conclude backfill was complete,
      // silently missing the tie's remaining 20 records.
      const totalAvailable = 120;
      transport.responder = (method, args) {
        final sync = ((args['meta'] as Map)['sync'] as Map)['qsos'] as Map;
        final until = sync['syncedUntilMillis'] as int;
        final limit = sync['limit'] as int;
        final page = [
          if (100 < until)
            for (var i = 0; i < totalAvailable; i++)
              {
                'uuid': 'tie-$i',
                'operation': 'op1',
                'their': {'call': 'W1AW$i'},
                'startAtMillis': i,
                'syncedAtMillis': 100,
              },
        ].take(limit).toList();
        return {'qsos': page};
      };

      var guard = 0;
      while (settings.state['completedFullSync'] != true && guard < 20) {
        await engine.runOneRound();
        guard++;
      }

      expect(settings.state['completedFullSync'], isTrue);
      expect(await qsos.watchForOperation('op1').first, hasLength(totalAvailable));
    });

    test('backfill rounds report server counts as progress, ending with a terminal update', () async {
      settings.state = {'lastSyncAccountUUID': 'acct-1'};
      final reports = <SyncProgress>[];
      engine.dispose();
      engine = SyncEngine(
        operations: operations,
        qsos: qsos,
        settings: settings,
        transport: transport.call,
        onProgress: reports.add,
      );

      // Round 1: a page plus counts. Round 2: a cooldown-gated response —
      // counts but NO records. Round 3: nothing left — backfill completes.
      var round = 0;
      transport.responder = (method, args) {
        round++;
        if (round == 1) {
          return {
            'qsos': [
              {'uuid': 'q1', 'operation': 'op1', 'their': {'call': 'W1AW'}, 'syncedAtMillis': 100},
            ],
            'meta': {
              'qsos': {'records_left': 41, 'total_records': 42},
              'operations': {'records_left': 0, 'total_records': 1},
            },
          };
        }
        if (round == 2) {
          return {
            'meta': {
              'qsos': {'records_left': 30, 'total_records': 42},
              'operations': {'records_left': 0, 'total_records': 1},
            },
          };
        }
        return {
          'meta': {
            'qsos': {'records_left': 0, 'total_records': 42},
            'operations': {'records_left': 0, 'total_records': 1},
          },
        };
      };

      await engine.runOneRound();
      expect(reports, hasLength(1));
      expect(reports.single.backfilling, isTrue);
      expect(reports.single.qsosLeft, 41);
      expect(reports.single.qsosTotal, 42);

      // A cooldown response still refreshes progress — no records needed.
      await engine.runOneRound();
      expect(reports, hasLength(2));
      expect(reports.last.backfilling, isTrue);
      expect(reports.last.qsosLeft, 30);
      expect(settings.state['completedFullSync'], isNot(true));

      await engine.runOneRound();
      expect(reports, hasLength(3));
      // The terminal update lets the surface (status bar) complete and
      // dismiss itself instead of showing a stale bar forever.
      expect(reports.last.backfilling, isFalse);
      expect(reports.last.qsosLeft, 0);
      expect(settings.state['completedFullSync'], isTrue);
    });

    test('a reconciliation during an in-flight round abandons that round\'s response', () async {
      settings.state = {'lastSyncAccountUUID': 'acct-1', 'completedFullSync': true};
      final op = await operations.create(stationCall: 'KI2D');
      await qsos.add(op.uuid, {'their': {'call': 'W1AW'}});

      final gate = Completer<Map<String, dynamic>>();
      final syncArgs = <Map<String, dynamic>>[];
      engine.dispose();
      engine = SyncEngine(
        operations: operations,
        qsos: qsos,
        settings: settings,
        transport: (method, args) {
          syncArgs.add(args);
          if (syncArgs.length == 1) return gate.future; // first round hangs on the network
          return Future.value(const {});
        },
      );

      final staleRound = engine.runOneRound();
      await Future<void>.delayed(const Duration(milliseconds: 10)); // let it reach the transport await

      // SYNCALL lands mid-flight: wipes the tables, resets backfill state.
      await engine.forceFullResync();

      // The hung response finally arrives — same account, server records,
      // and (captured pre-wipe) short-page flags that would otherwise set
      // completedFullSync on the freshly reset state.
      gate.complete({
        'account': {'uuid': 'acct-1'},
        'qsos': [
          {
            'uuid': 'stale-inbound',
            'operation': op.uuid,
            'their': {'call': 'SHOULDNOTMERGE'},
            'syncedAtMillis': 5,
          },
        ],
      });
      await staleRound;

      // Nothing from the abandoned response reached the wiped tables.
      expect(await qsos.watchForOperation(op.uuid).first, isEmpty);

      // The fresh generation's round does run afterward — and as a real
      // backfill (anyClient: true), proving the stale round didn't clobber
      // the reset flags with its pre-wipe snapshot.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(syncArgs.length, greaterThan(1));
      final followUpSync = (syncArgs.last['meta'] as Map)['sync'] as Map;
      expect((followUpSync['qsos'] as Map)['anyClient'], isTrue);
      expect(await qsos.watchForOperation(op.uuid).first, isEmpty);
    });

    test('transport failures are logged, never silent', () async {
      settings.state = {'lastSyncAccountUUID': 'acct-1', 'completedFullSync': true};
      final logs = <String>[];
      engine.dispose();
      engine = SyncEngine(
        operations: operations,
        qsos: qsos,
        settings: settings,
        log: logs.add,
        transport: (method, args) async => throw Exception('server exploded'),
      );

      await engine.runOneRound();

      expect(logs, hasLength(1));
      expect(logs.single, contains('server exploded'));
    });

    test('an account change mid-stream pauses sync without merging that response', () async {
      settings.state = {'lastSyncAccountUUID': 'acct-1', 'completedFullSync': true};
      // Local data, so the change is the user's to settle; without it the
      // engine would adopt acct-2 silently and this would prove nothing.
      final op = await operations.create(stationCall: 'KI2D');
      await qsos.add(op.uuid, {'their': {'call': 'W1AW'}});
      transport.responder = (method, args) => method == 'getAccountData'
          ? {
              'operations': {'total': 3},
              'qsos': {'total': 42},
            }
          : {
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

    test('a mid-stream change into an EMPTY account is adopted silently, fetching to find out', () async {
      // The only path that makes _canAdoptAccountSilently spend its own
      // network call: local log present, so the cheap check says nothing,
      // and the `sync` response carries no totals to judge the account by.
      settings.state = {'lastSyncAccountUUID': 'acct-1', 'completedFullSync': true};
      final op = await operations.create(stationCall: 'KI2D');
      await qsos.add(op.uuid, {'their': {'call': 'W1AW'}});
      final methods = <String>[];
      transport.responder = (method, args) {
        methods.add(method);
        return method == 'getAccountData'
            ? {'operations': {'total': 0}, 'qsos': {'total': 0}}
            : {'account': {'uuid': 'acct-2'}};
      };

      await engine.runOneRound();

      expect(methods, contains('getAccountData'));
      expect(settings.state['lastSyncAccountUUID'], 'acct-2');
      expect(settings.state['pendingAccountUUID'], isNull);
      // Combine, not replace — the local log is kept and re-dirtied so it
      // uploads into the account it just joined.
      expect(await operations.byUuids([op.uuid]), isNotEmpty);
      expect(await qsos.hasUnsynced(), isTrue);
    });

    test('an account change mid-stream is adopted silently when this device has nothing logged', () async {
      settings.state = {'lastSyncAccountUUID': 'acct-1', 'completedFullSync': true};
      transport.responder = (method, args) => method == 'getAccountData'
          ? const {}
          : {
              'account': {'uuid': 'acct-2'},
            };

      await engine.runOneRound();

      expect(settings.state['pendingAccountUUID'], isNull);
      expect(settings.state['lastSyncAccountUUID'], 'acct-2');
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
  group('transport not ready', () {
    // A cold start fires the first periodic round before the extension host
    // has finished loading, and the transport reaches the network THROUGH that
    // host. That is not a sync failure, but it used to be indistinguishable
    // from one: every launch counted an error, applied the failure backoff,
    // and called onError - which the app wires straight to crash reporting.
    test('is not counted as a failure and is not reported', () async {
      Object? reported;
      var errorRounds = 0;
      final notReady = _FakeTransport((method, args) => throw const SyncTransportNotReady());
      final e = SyncEngine(
        operations: operations,
        qsos: qsos,
        transport: notReady.call,
        settings: settings,
        log: (m) {
          if (m.contains('round failed')) errorRounds++;
        },
        onError: (error, st, {context}) => reported = error,
      );
      addTearDown(e.dispose);

      await e.runOneRound();

      expect(reported, isNull, reason: 'a host that has not loaded yet must not reach crash reporting');
      expect(errorRounds, 0, reason: 'and must not be logged as a failed round');
    });

    test('a real transport failure IS still counted, and reported once it persists', () async {
      // The point of the new exception type is to distinguish the two; if this
      // stopped reporting, the fix would have silenced genuine outages.
      // Reporting waits for a streak (errorReportThreshold) so an offline
      // device doesn't file an event every few minutes — but a genuine
      // outage must still arrive, and must still be COUNTED from the very
      // first round, which is what keeps it distinguishable from a
      // transport that simply hasn't loaded.
      Object? reported;
      var errorRounds = 0;
      final broken = _FakeTransport((method, args) => throw StateError('network exploded'));
      final e = SyncEngine(
        operations: operations,
        qsos: qsos,
        transport: broken.call,
        settings: settings,
        log: (m) {
          if (m.contains('round failed')) errorRounds++;
        },
        onError: (error, st, {context}) => reported = error,
      );
      addTearDown(e.dispose);

      await e.runOneRound();
      expect(errorRounds, 1, reason: 'counted from the first, unlike a not-ready transport');
      expect(reported, isNull, reason: 'one failure is the network, not a defect');

      for (var i = 1; i < SyncEngine.errorReportThreshold; i++) {
        await e.runOneRound();
      }

      expect(reported, isA<StateError>());
      expect(errorRounds, SyncEngine.errorReportThreshold);
    });
  });

  group('rejected registration', () {
    // The server can refuse a brand-new client registration (e.g. a stale
    // callsign that no longer matches its expected format) the same way it
    // can refuse any other authenticated call — ham2k-lofi's `sync` returns
    // this as `{error, error_status}` data rather than throwing, so it must
    // not be treated like an arbitrary transport failure.
    Map<String, dynamic> rejection() =>
        {'error': 'LoFi registration failed: HTTP 422', 'error_status': 422};

    test('a single rejected round is not counted or reported', () async {
      Object? reported;
      var errorRounds = 0;
      String? authNotice;
      final rejected = _FakeTransport((method, args) => rejection());
      final e = SyncEngine(
        operations: operations,
        qsos: qsos,
        transport: rejected.call,
        settings: settings,
        log: (m) {
          if (m.contains('round failed')) errorRounds++;
        },
        onError: (error, st, {context}) => reported = error,
        onAuthError: (message, {status}) => authNotice = message,
      );
      addTearDown(e.dispose);

      await e.runOneRound();

      expect(reported, isNull, reason: 'a rejected round is expected, not a bug — it must not reach crash reporting');
      expect(errorRounds, 0, reason: 'and must not be logged as a failed round');
      expect(authNotice, isNull, reason: 'one rejection is not yet a stuck registration');
    });

    test('onAuthError fires once the streak hits the threshold, not before or repeatedly after', () async {
      var authNoticeCount = 0;
      final rejected = _FakeTransport((method, args) => rejection());
      final e = SyncEngine(
        operations: operations,
        qsos: qsos,
        transport: rejected.call,
        settings: settings,
        onAuthError: (message, {status}) => authNoticeCount++,
      );
      addTearDown(e.dispose);

      for (var i = 0; i < SyncEngine.authErrorNotifyThreshold - 1; i++) {
        await e.runOneRound();
        expect(authNoticeCount, 0, reason: 'still short of the threshold');
      }
      await e.runOneRound();
      expect(authNoticeCount, 1, reason: 'the streak just hit the threshold');

      await e.runOneRound();
      expect(authNoticeCount, 1, reason: 'must not re-notify every round once already shown');
    });

    test('a round that succeeds resets the rejection streak', () async {
      var authNoticeCount = 0;
      var rejecting = true;
      final flaky = _FakeTransport((method, args) => rejecting ? rejection() : {'account': {'uuid': 'acct-1'}});
      final e = SyncEngine(
        operations: operations,
        qsos: qsos,
        transport: flaky.call,
        settings: settings,
        onAuthError: (message, {status}) => authNoticeCount++,
      );
      addTearDown(e.dispose);

      await e.runOneRound();
      await e.runOneRound();
      rejecting = false;
      await e.runOneRound(); // a clean round in between clears the streak
      rejecting = true;
      await e.runOneRound();
      await e.runOneRound();

      expect(authNoticeCount, 0, reason: 'each rejection streak was broken up before reaching the threshold');
    });

    test('a rejection with no callsign and nothing local to sync is fully silent', () async {
      Object? reported;
      String? authNotice;
      settings.operatorCall = '';
      final rejected = _FakeTransport((method, args) => rejection());
      final e = SyncEngine(
        operations: operations,
        qsos: qsos,
        transport: rejected.call,
        settings: settings,
        onError: (error, st, {context}) => reported = error,
        onAuthError: (message, {status}) => authNotice = message,
      );
      addTearDown(e.dispose);

      // Well past the notify threshold — it must never trip, since a device
      // with no callsign and no local data has nothing at stake yet.
      for (var i = 0; i < SyncEngine.authErrorNotifyThreshold + 2; i++) {
        await e.runOneRound();
      }

      expect(reported, isNull);
      expect(authNotice, isNull);
    });

    test('a rejection with local data to sync still surfaces, even with no callsign', () async {
      settings.operatorCall = '';
      await operations.create(stationCall: 'KI2D');
      var authNoticeCount = 0;
      final rejected = _FakeTransport((method, args) => rejection());
      final e = SyncEngine(
        operations: operations,
        qsos: qsos,
        transport: rejected.call,
        settings: settings,
        onAuthError: (message, {status}) => authNoticeCount++,
      );
      addTearDown(e.dispose);

      for (var i = 0; i < SyncEngine.authErrorNotifyThreshold; i++) {
        await e.runOneRound();
      }

      expect(authNoticeCount, 1, reason: 'there is real local data at risk, so this must still surface');
    });
  });

  // A QSO's purge tombstone arrives in a later batch than the operation it
  // belongs to, so it can land after that operation's row is already gone
  // (the operator confirmed a received purge, or an earlier round's sweep
  // removed it). Every other purge sweep takes an operation uuid that has to
  // still exist to be found, so the round is the only place these can ever
  // be reclaimed.
  group('orphaned purged QSOs', () {
    /// A purged, synced QSO whose operation row no longer exists.
    Future<Qso> makeOrphan(String call) async {
      final op = await operations.create(stationCall: 'KI2D/T');
      final qso = await qsos.add(op.uuid, {'their': {'call': call}, 'startAtMillis': 1000});
      await qsos.purgeForOperation(op.uuid);
      await qsos.markSynced([(await qsos.get(qso.uuid))!]);
      await operations.hardDeleteOperation(op.uuid);
      return qso;
    }

    setUp(() {
      transport.responder = (method, args) => {'account': {'uuid': 'acct-1'}};
    });

    test('a round reclaims orphans left behind by an earlier run', () async {
      final orphan = await makeOrphan('W1AW');

      await engine.runOneRound();

      expect(await qsos.get(orphan.uuid), isNull);
    });

    test('the sweep does not run on every round — only an inbound purge can strand a new orphan', () async {
      // The sweep scans the whole QSO table, and a small-batch round fires
      // seconds after every logged QSO, so it is gated. Nothing but an
      // inbound purge tombstone creates an orphan, and the once-per-run pass
      // above has already been spent by this point.
      await engine.runOneRound();
      final orphan = await makeOrphan('W1AW');

      await engine.runOneRound();
      expect(await qsos.get(orphan.uuid), isNotNull, reason: 'nothing arrived that could have stranded anything');

      transport.responder = (method, args) => {
            'account': {'uuid': 'acct-1'},
            'qsos': [
              {'uuid': 'inbound-qso', 'operation': 'gone-op', 'deleted': true, 'purged': true, 'updatedAtMillis': 1},
            ],
          };
      await engine.runOneRound();

      expect(await qsos.get(orphan.uuid), isNull, reason: 'an inbound purge tombstone re-arms the sweep');
    });
  });
}

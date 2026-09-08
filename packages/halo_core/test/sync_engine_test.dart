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
  /// Every write goes through [state]'s setter, which is what keeps the
  /// rewind default below from being defeated by a wholesale reassignment.
  Map<String, dynamic> _state;
  @override
  String operatorCall = 'KI2D';

  /// Fires after every write, so a test can act at the exact moment a
  /// particular key lands — the only way to hit a race whose window is one
  /// await wide.
  void Function(Map<String, dynamic> state)? onStateSet;

  /// Defaulted, not left absent: every test but the rewind's own describes a
  /// device that already took the one-time forward-cursor rewind, and without
  /// this its first round spends a state write, a log line and both forward
  /// cursors on a repair the test is not about. A test that wants the rewind
  /// assigns [state] itself, without the key.
  _FakeSyncSettings({Map<String, dynamic>? state}) : _state = _pastRewind(state ?? const {});

  /// Every test but the rewind's own describes a device that already took the
  /// one-time forward-cursor rewind — otherwise its first round spends a
  /// state write, a log line and BOTH forward cursors on a repair the test is
  /// not about, and a test that presets a forward watermark silently gets it
  /// zeroed and passes for the wrong reason.
  ///
  /// Applied on assignment as well as construction, because most tests here
  /// replace [state] wholesale rather than build a new fake. A test that
  /// wants the rewind says so, by spelling the key `false`.
  static Map<String, dynamic> _pastRewind(Map<String, dynamic> state) =>
      state.containsKey(SyncEngine.tombstoneRewindKey) ? state : {SyncEngine.tombstoneRewindKey: true, ...state};

  @override
  Map<String, dynamic> get state => _state;

  set state(Map<String, dynamic> value) => _state = _pastRewind(value);

  @override
  Future<void> setState(Map<String, dynamic> newState) async {
    // Straight to the field: this is the ENGINE writing, and a write of its
    // own must land verbatim — routing it through the setter would hand the
    // rewind back its own untaken flag.
    _state = newState;
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
  group('connectivity probe', _reachabilityTests);
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

  test('a contact belonging to no operation pushes as a null operation and comes back', () async {
    // The inbound half is what an ADIF import into the general log rests on:
    // the server accepts a loose contact and hands it back with a null
    // operation, so a merge that skips that shape keeps the contact off every
    // device, the sender's own included, however well the upload worked. Both
    // directions are asserted together because they are one contract: pushing
    // null while refusing to merge null back makes the loose half of a log a
    // one-way trip.
    await qsos.writeBatch(operationUuid: '', inserts: [
      {'their': {'call': 'W1AW'}, 'startAtMillis': 1000},
    ]);

    Map<String, dynamic>? sent;
    transport.responder = (method, args) {
      sent = ((args['qsos'] as List).cast<Map>().single).cast<String, dynamic>();
      return {
        'qsos': [
          {'uuid': 'inbound-loose', 'operation': null, 'their': {'call': 'N1MM'}, 'startAtMillis': 2000},
        ],
        'account': {'uuid': 'acct-1'},
      };
    };

    await engine.runOneRound();

    expect(sent, isNotNull);
    expect(sent!.containsKey('operation'), isTrue, reason: 'the key must be present, just null');
    expect(sent!['operation'], isNull);
    expect(await qsos.hasUnsynced(), isFalse);

    final inbound = await qsos.get('inbound-loose');
    expect(inbound, isNotNull, reason: 'a loose contact from the server must land, not be skipped');
    expect(inbound!.operationUuid, '');
  });

  test('an operation that is present but not a string is refused, not filed as loose', () async {
    // The other edge of the same rule. Absent and null both mean "belongs to
    // no operation", but a wrong-typed value NAMES one — it just cannot be
    // read — so treating it as loose would silently detach a contact from the
    // operation it belongs to, with nothing to show it ever happened.
    transport.responder = (method, args) => {
          'qsos': [
            {'uuid': 'inbound-typed', 'operation': 42, 'their': {'call': 'N1MM'}, 'startAtMillis': 2000},
            {'uuid': 'inbound-absent', 'their': {'call': 'W1AW'}, 'startAtMillis': 3000},
          ],
          'account': {'uuid': 'acct-1'},
        };

    await engine.runOneRound();

    expect(await qsos.get('inbound-typed'), isNull);
    // An absent key is the same statement as an explicit null, and must land.
    expect((await qsos.get('inbound-absent'))?.operationUuid, '');
  });

  group('records the server refuses', () {
    Future<Set<String>> unsyncedQsoUuids() async =>
        (await qsos.unsyncedBatch(100)).map((q) => q.uuid).toSet();

    test('stay dirty instead of being marked sent', () async {
      // Marking a refused record synced is how a local edit diverges from the
      // server forever: "pending" is the only thing that makes a later round
      // send anything, so a record flagged sent that the server never took is
      // offered again by nothing, ever.
      final op = await operations.create(stationCall: 'KI2D');
      final kept = await qsos.add(op.uuid, {'their': {'call': 'W1AW'}, 'startAtMillis': 1000});
      final refused = await qsos.add(op.uuid, {'their': {'call': 'K2ABC'}, 'startAtMillis': 2000});

      transport.responder = (method, args) => {
            'account': {'uuid': 'acct-1'},
            'errors': {
              'qsos': {
                refused.uuid: [
                  {'operation': [{'error': 'forbidden'}]},
                ],
              },
            },
          };

      await engine.runOneRound();

      expect(await unsyncedQsoUuids(), contains(refused.uuid), reason: 'a refused record must stay offerable');
      // The rest of the batch is unaffected — one refusal must not hold back
      // every record that WAS accepted, or a single bad row stalls the log.
      expect(await unsyncedQsoUuids(), isNot(contains(kept.uuid)));
    });

    test('are reported once, not once per round', () async {
      // A refused record is re-sent and re-refused every round by design, so
      // reporting on each one would upload thousands of copies of one fact.
      final op = await operations.create(stationCall: 'KI2D');
      final refused = await qsos.add(op.uuid, {'their': {'call': 'K2ABC'}, 'startAtMillis': 2000});

      final reported = <Object>[];
      final engineWithReporting = SyncEngine(
        operations: operations,
        qsos: qsos,
        transport: transport.call,
        settings: settings,
        onError: (error, stack, {context}) => reported.add(error),
      );

      transport.responder = (method, args) => {
            'account': {'uuid': 'acct-1'},
            'errors': {
              'qsos': {
                // `value:` is what Rails' own `:taken` and `:inclusion`
                // validators merge into the error options — the record's
                // field contents, in the payload, exactly where a walker that
                // takes any string would pick them up.
                refused.uuid: [
                  {'their': [{'error': 'taken', 'value': 'K2ABC'}]},
                ],
              },
            },
          };

      await engineWithReporting.runOneRound();
      await engineWithReporting.runOneRound();

      expect(reported, hasLength(1));
      expect(reported.single, isA<SyncRecordsRejected>());
      final rejection = reported.single as SyncRecordsRejected;
      expect(rejection.reasonsByUuid.keys, [refused.uuid]);
      // The server's error KEYS travel; the record's own field values must
      // not — they hold callsigns, names and notes, and this string leaves
      // the device.
      expect(rejection.toString(), contains('taken'), reason: 'the error name is the diagnostic');
      expect(rejection.toString(), isNot(contains('K2ABC')),
          reason: 'a field value must never reach the crash backend');
    });

    test('a round where nothing was accepted does not re-run at zero delay', () async {
      // The zero-delay reschedule exists to drain a backlog fast. A record
      // the server will never accept is pending forever, so without this a
      // single `forbidden` edit spins the loop against the server for as long
      // as the app runs.
      final op = await operations.create(stationCall: 'KI2D');
      final refused = await qsos.add(op.uuid, {'their': {'call': 'K2ABC'}, 'startAtMillis': 2000});

      transport.responder = (method, args) => {
            'account': {'uuid': 'acct-1'},
            'errors': {
              'qsos': {
                refused.uuid: [
                  {'operation': [{'error': 'forbidden'}]},
                ],
              },
              'operations': {
                op.uuid: [
                  {'operation': [{'error': 'forbidden'}]},
                ],
              },
            },
          };

      await engine.runOneRound();
      expect(transport.calls, hasLength(1));

      // Observed the way the full-page test above observes it: a zero-delay
      // reschedule lands inside 50ms, while `_loopDelay` (20s) does not.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Still pending — that is the point of leaving it dirty — but the round
      // made no progress, so the next one waits rather than firing instantly.
      expect(await qsos.hasUnsynced(), isTrue);
      expect(transport.calls, hasLength(1), reason: 'a stalled push must not spin the loop');
    });

    test('a refused record steps aside so the records behind it still go', () async {
      // `unsyncedBatch` is a LIMIT ordered newest-first, so a refused record
      // that sorts early would refill the batch every round and nothing behind
      // it would ever be sent again — for the life of the install. Keeping it
      // dirty without holding it back trades one silent loss for a worse one.
      final op = await operations.create(stationCall: 'KI2D');
      final refused = await qsos.add(op.uuid, {'their': {'call': 'K2ABC'}, 'startAtMillis': 9000});

      final sent = <List<String>>[];
      transport.responder = (method, args) {
        sent.add([for (final q in (args['qsos'] as List? ?? []).cast<Map>()) q['uuid'] as String]);
        return {
          'account': {'uuid': 'acct-1'},
          'errors': {
            'qsos': {
              refused.uuid: [
                {'operation': [{'error': 'forbidden'}]},
              ],
            },
          },
        };
      };

      await engine.runOneRound();
      expect(sent.single, contains(refused.uuid));

      // Logged after the refusal, so it sorts BEHIND the refused record and is
      // exactly what a starved queue would never deliver.
      final behind = await qsos.add(op.uuid, {'their': {'call': 'W1AW'}, 'startAtMillis': 1000});
      await engine.runOneRound();

      expect(sent.last, contains(behind.uuid), reason: 'the queue must keep moving');
      expect(sent.last, isNot(contains(refused.uuid)), reason: 'the refused record steps aside');
      // Still dirty — stepping aside is not being marked sent.
      expect(await unsyncedQsoUuids(), contains(refused.uuid));
    });

    test('a refused record is offered again once its quarantine passes', () async {
      // Stepping aside must not become "never again": a refusal is often
      // temporary — a permission granted, an owner adding this device — and a
      // record parked for good is the silent loss this all exists to end.
      final op = await operations.create(stationCall: 'KI2D');
      final refused = await qsos.add(op.uuid, {'their': {'call': 'K2ABC'}, 'startAtMillis': 9000});

      // The real clock cannot be wound forward, so the window is driven
      // instead — zero means every round is past it.
      final impatient = SyncEngine(
        operations: operations,
        qsos: qsos,
        transport: transport.call,
        settings: settings,
        refusalQuarantine: Duration.zero,
      );

      final sent = <List<String>>[];
      transport.responder = (method, args) {
        sent.add([for (final q in (args['qsos'] as List? ?? []).cast<Map>()) q['uuid'] as String]);
        return {
          'account': {'uuid': 'acct-1'},
          'errors': {
            'qsos': {
              refused.uuid: [
                {'operation': [{'error': 'forbidden'}]},
              ],
            },
          },
        };
      };

      await impatient.runOneRound();
      await impatient.runOneRound();

      expect(sent, hasLength(2));
      expect(sent.last, contains(refused.uuid), reason: 'the window passed, so try it again');
    });

    test('a count of unreadable entries is reported, not discarded', () async {
      // `_malformed` says N records this device sent were unreadable and
      // stored nowhere. No uuid comes with it, so none can be held dirty and
      // all of them are marked sent — which makes this the one refusal that
      // still loses data silently, and the only trace it happened. An
      // unusable payload is a fault in what this app WROTE.
      final op = await operations.create(stationCall: 'KI2D');
      await qsos.add(op.uuid, {'their': {'call': 'W1AW'}, 'startAtMillis': 1000});

      final reported = <Object>[];
      final engineWithReporting = SyncEngine(
        operations: operations,
        qsos: qsos,
        transport: transport.call,
        settings: settings,
        onError: (error, stack, {context}) => reported.add(error),
      );

      transport.responder = (method, args) => {
            'account': {'uuid': 'acct-1'},
            'errors': {
              'qsos': {
                '_malformed': [
                  {'error': 'unusable_payload', 'count': 2},
                ],
              },
            },
          };

      await engineWithReporting.runOneRound();

      expect(reported.whereType<SyncPayloadUnreadable>(), hasLength(1));
      expect((reported.single as SyncPayloadUnreadable).count, 2);
    });

    test('the pagination and _malformed keys are not reported as refused records', () async {
      // `errors.qsos` carries both alongside real uuids: `pagination` is the
      // cursor refusal `_cursorRefused` reads, and `_malformed` is a COUNT of
      // entries the server could not read — neither is a record.
      //
      // Asserting the REPORT, not the synced flag: neither key matches a real
      // uuid, so nothing stays dirty either way and a test watching `synced`
      // passes with the guard deleted. What breaks is the crash backend being
      // told records were refused when none were, naming a "uuid" no record
      // has.
      final op = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(op.uuid, {'their': {'call': 'W1AW'}, 'startAtMillis': 1000});

      final reported = <Object>[];
      final engineWithReporting = SyncEngine(
        operations: operations,
        qsos: qsos,
        transport: transport.call,
        settings: settings,
        onError: (error, stack, {context}) => reported.add(error),
      );

      transport.responder = (method, args) => {
            'account': {'uuid': 'acct-1'},
            'errors': {
              'qsos': {
                'pagination': {'cursor': 'refused'},
                '_malformed': [
                  {'error': 'unusable_payload', 'count': 2},
                ],
              },
            },
          };

      await engineWithReporting.runOneRound();

      // The unreadable COUNT is reported (see the test above) — what must not
      // happen is either key being read as a refused record, which would name
      // a "uuid" no record has.
      expect(reported.whereType<SyncRecordsRejected>(), isEmpty,
          reason: 'neither key names a record that was refused');
      expect(await unsyncedQsoUuids(), isNot(contains(qso.uuid)),
          reason: 'nothing in that block named this record');
    });
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

  // The server's two timing flags are two different waits, and the engine
  // must keep them apart: the loop delay is what api-lofi clamps to clear its
  // per-client cooldown, so a full page followed by anything shorter is a
  // request that comes back gated and empty; the check period is the idle
  // rate, and paging at it would make a 300-page backfill take hours.
  // Distinct values, so using either one for both jobs fails here.
  Map<String, dynamic> pagedResponse(List<Map<String, dynamic>> page) => {
        'qsos': page,
        'meta': {
          'flags': {'suggested_sync_loop_delay': 5500, 'suggested_sync_check_period': 60000},
        },
      };

  List<Map<String, dynamic>> inboundFrom(Map<String, dynamic> args, {required int totalAvailable}) {
    final since = (((args['meta'] as Map)['sync'] as Map)['qsos'] as Map)['syncedSinceMillis'] as int;
    return [
      for (var i = since; i < totalAvailable; i++)
        {
          'uuid': 'inbound-$i',
          'operation': 'op1',
          'their': {'call': 'W1AW$i'},
          'startAtMillis': i,
          'syncedAtMillis': i + 1,
        },
    ];
  }

  test('a full page of inbound records reschedules after the loop delay, not sooner', () async {
    // A server with 150 pending QSOs to hand back: a full page (100) the
    // first call, the rest on the next — the same "keep looping until caught
    // up" shape as app-polo's `receivedAllUpdates`.
    transport.responder = (method, args) =>
        pagedResponse(inboundFrom(args, totalAvailable: 150).take(SyncEngine.defaultLargeBatchSize).toList());

    await engine.runOneRound();
    expect(transport.calls, hasLength(1)); // first page: 100 records, a full page

    final wait = engine.nextAttemptAt!.difference(realNowUtc());
    expect(wait, greaterThan(const Duration(seconds: 4)));
    expect(wait, lessThanOrEqualTo(const Duration(milliseconds: 5500)));
    // Not the immediate follow-up: that request always landed inside the
    // server's cooldown and came back with no page.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(transport.calls, hasLength(1));
  });

  test('a partial page means caught up, and the loop idles at the check period', () async {
    transport.responder = (method, args) => pagedResponse(inboundFrom(args, totalAvailable: 50));

    await engine.runOneRound();
    expect(transport.calls, hasLength(1));

    final wait = engine.nextAttemptAt!.difference(realNowUtc());
    expect(wait, greaterThan(const Duration(seconds: 59)));
    expect(wait, lessThanOrEqualTo(const Duration(seconds: 60)));
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

    // LOFI-41. Against a server that offers no cursor the client is still on the millisecond
    // window - and that only works because the server extends a page to cover its whole edge
    // millisecond. The fake here does that, which the real one has always done; a fake that
    // simply takes `limit` models a server that does not exist, and would make
    // `syncedUntilMillis = earliest + 1` look necessary when it is the thing that stalls a real
    // backfill.
    test('backfill on the millisecond window loses nothing to a page-sized tie', () async {
      settings.state = {'lastSyncAccountUUID': 'acct-1'};
      // 40 newer records at distinct stamps, then 120 sharing stamp 100 - a bulk import whose
      // tie is larger than a full page (100). Mixed stamps on purpose: with a single stamp
      // throughout, a fake that mismodels the extension still passes.
      const totalAvailable = 160;
      transport.responder = (method, args) {
        final sync = ((args['meta'] as Map)['sync'] as Map)['qsos'] as Map;
        final until = sync['syncedUntilMillis'] as int;
        final limit = sync['limit'] as int;
        final all = [
          for (var i = 0; i < 40; i++)
            {
              'uuid': 'new-$i',
              'operation': 'op1',
              'their': {'call': 'K1AA$i'},
              'startAtMillis': 500 + i,
              'syncedAtMillis': 200 - i,
            },
          for (var i = 0; i < 120; i++)
            {
              'uuid': 'tie-$i',
              'operation': 'op1',
              'their': {'call': 'W1AW$i'},
              'startAtMillis': i,
              'syncedAtMillis': 100,
            },
        ];
        final matching = [
          for (final q in all)
            if ((q['syncedAtMillis'] as int) < until) q,
        ];
        // The edge extension, exactly as `process_pagination` builds it: the first `limit`
        // records, PLUS the rest of the millisecond the last of them falls in. Keeping only the
        // edge millisecond would drop every newer record in the page - which happens to be
        // invisible while they all share one stamp, and wrong the moment they do not.
        final List<Map<String, dynamic>> page;
        if (matching.length > limit) {
          final edgeStamp = matching[limit - 1]['syncedAtMillis'];
          page = [
            ...matching.take(limit).where((q) => q['syncedAtMillis'] != edgeStamp),
            ...matching.where((q) => q['syncedAtMillis'] == edgeStamp),
          ];
        } else {
          page = matching;
        }
        return {'qsos': page};
      };

      var guard = 0;
      while (settings.state['completedFullSync'] != true && guard < 20) {
        await engine.runOneRound();
        guard++;
      }

      expect(settings.state['completedFullSync'], isTrue);
      expect(await qsos.watchForOperation('op1').first, hasLength(totalAvailable));
      expect(settings.state['earliestQSOSyncedAtMillis'], 100,
          reason: 'with no cursor sent, the watermark is the page\'s earliest stamp and not one '
              'past it - `+ 1` asks the server for `< 101`, which re-requests the whole tie '
              'every round, forever');
    });

    // The N4TRD regression. A tie larger than a page cannot be paged by a millisecond cursor at
    // all: the page is entirely that tie, its edge never moves, and the same records come back
    // every round. Driven the way a real backfill runs - follow the server's cursor, stop when it
    // says nothing is left - because the bug was never a wrong page, it was a correct page forever.
    test('backfill follows the server cursor through a tie larger than any page', () async {
      settings.state = {'lastSyncAccountUUID': 'acct-1'};
      // The server caps a page at its own maximum however large a limit the client asks for
      // (`Paginable::MAX_LIMIT`), which is what puts a big enough tie permanently out of reach:
      // `_backfillLimitBoost` can grow the request, but not the answer. N4TRD's 7804 sat behind
      // that cap. Scaled down here - the ratio is what matters, not the size.
      const serverMaxLimit = 200;
      final all = [
        for (var i = 0; i < 300; i++)
          {
            'uuid': 'tie-$i',
            'operation': 'op1',
            'their': {'call': 'W1AW$i'},
            'startAtMillis': i,
            'syncedAtMillis': 100,
          },
        for (var i = 0; i < 30; i++)
          {
            'uuid': 'old-$i',
            'operation': 'op1',
            'their': {'call': 'K1AA$i'},
            'startAtMillis': 400 + i,
            'syncedAtMillis': 90 - i,
          },
      ];

      transport.responder = (method, args) {
        final sync = ((args['meta'] as Map)['sync'] as Map)['qsos'] as Map;
        final limit = (sync['limit'] as int).clamp(1, serverMaxLimit);
        // Opaque, as far as the client is concerned - it must echo this back untouched rather
        // than deriving a position of its own. Without one every round starts over at the top of
        // the tie, which is the stall.
        final from = sync['cursor'] == null ? 0 : int.parse((sync['cursor'] as String).split(':').last);
        final page = all.skip(from).take(limit).toList();
        final next = from + page.length;
        return {
          'qsos': page,
          'meta': {
            'qsos': {
              // A cursor names where the page stopped, however short it was; only an EMPTY page
              // has no record to name. A fake that emits one unconditionally cannot catch a
              // client that holds a stale cursor forever.
              if (page.isNotEmpty) 'next_cursor': 'row:$next',
              'records_left': all.length - next,
            },
            'operations': {'records_left': 0},
          },
        };
      };

      var guard = 0;
      while (settings.state['completedFullSync'] != true && guard < 20) {
        await engine.runOneRound();
        guard++;
      }

      expect(settings.state['completedFullSync'], isTrue,
          reason: 'a tie wider than any page the server will return must still terminate - '
              'this is the stall itself');
      expect(await qsos.watchForOperation('op1').first, hasLength(all.length));
      expect(settings.state[SyncEngine.backfillCursorKeys['qsos']], isNull,
          reason: 'a finished backfill clears its descending cursor, which forward mode cannot use');
    });

    // A cursor replaces the millisecond bound rather than accompanying it — LoFi's
    // `apply_pagination_param!` returns early and never looks at `syncedSinceMillis` once a valid
    // cursor arrives. So a cursor that stops advancing pins the window open: the same tail comes
    // back every round, forever, while `latestQSOSyncedAtMillis` climbs and is never consulted.
    test('a forward round that names no position drops its cursor rather than re-sending it', () async {
      settings.state = {'lastSyncAccountUUID': 'acct-1', 'completedFullSync': true};
      final cursorsSent = <String?>[];
      var round = 0;

      List<Map<String, dynamic>> rows(int count, int from) => [
            for (var i = 0; i < count; i++)
              {
                'uuid': 'fwd-${from + i}',
                'operation': 'op1',
                'their': {'call': 'W1AW${from + i}'},
                'startAtMillis': from + i,
                'syncedAtMillis': 1000 + from + i,
              },
          ];

      transport.responder = (method, args) {
        final sync = ((args['meta'] as Map)['sync'] as Map)['qsos'] as Map;
        cursorsSent.add(sync['cursor'] as String?);
        round++;
        if (round == 1) {
          // A full page, so the server names where it stopped.
          return {
            'qsos': rows(100, 0),
            'meta': {
              'qsos': {'next_cursor': 'fwd:100', 'records_left': 3},
              'operations': {'records_left': 0},
            },
          };
        }
        // Short pages from here on: records, but no cursor naming them.
        return {
          'qsos': rows(3, 100),
          'meta': {
            'qsos': {'records_left': 0},
            'operations': {'records_left': 0},
          },
        };
      };

      await engine.runOneRound();
      await engine.runOneRound();
      await engine.runOneRound();

      expect(cursorsSent, [null, 'fwd:100', null],
          reason: 'the short page named no position, so the cursor is dropped and the watermark '
              'takes over - holding it re-requests the same tail every round');
    });

    // The other half of the rule above, and the reason it cannot simply be "no cursor means drop
    // it": a cooldown-gated response carries counts and NO page at all. The cursor we hold is
    // still exactly where to resume, and throwing it away would restart the walk from the
    // millisecond bound - re-reading everything back to it.
    test('a cooldown-gated round with no page at all keeps the cursor it holds', () async {
      settings.state = {'lastSyncAccountUUID': 'acct-1'};
      final cursorsSent = <String?>[];
      var round = 0;

      transport.responder = (method, args) {
        final sync = ((args['meta'] as Map)['sync'] as Map)['qsos'] as Map;
        cursorsSent.add(sync['cursor'] as String?);
        round++;
        if (round == 1) {
          return {
            'qsos': [
              {'uuid': 'q1', 'operation': 'op1', 'their': {'call': 'W1AW'}, 'syncedAtMillis': 100},
            ],
            'meta': {
              'qsos': {'next_cursor': 'row:1', 'records_left': 5},
              'operations': {'records_left': 0},
            },
          };
        }
        // Cooldown: counts only, no `qsos` key whatsoever.
        return {
          'meta': {
            'qsos': {'records_left': 5},
            'operations': {'records_left': 0},
          },
        };
      };

      await engine.runOneRound();
      await engine.runOneRound();
      await engine.runOneRound();

      expect(cursorsSent, [null, 'row:1', 'row:1'],
          reason: 'a gated round returned no page, so it says nothing about where we are - the '
              'cursor has to survive it');
    });

    // Finding from review: the millisecond watermark is a FALLBACK, read only when the cursor
    // stops working - a rolling deploy landing on an older node, or a cursor refused after a
    // format bump. A cursor page stops mid-millisecond by design, so banking `earliest` there
    // means the fallback window `< earliest` skips the rest of that stamp permanently, with
    // `records_left` counting down to zero around the hole. Banking `earliest + 1` re-covers it.
    test('a cursor page banks a millisecond fallback that re-covers the stamp it stopped in', () async {
      settings.state = {'lastSyncAccountUUID': 'acct-1'};
      transport.responder = (method, args) {
        final sync = ((args['meta'] as Map)['sync'] as Map)['qsos'] as Map;
        final sentCursor = sync['cursor'] as String?;
        if (sentCursor == null) {
          // Round 1, the millisecond path: distinct stamps, so it ends cleanly on a boundary.
          return {
            'qsos': [
              for (var i = 0; i < 40; i++)
                {
                  'uuid': 'new-$i',
                  'operation': 'op1',
                  'their': {'call': 'K1AA$i'},
                  'startAtMillis': 500 + i,
                  'syncedAtMillis': 200 - i,
                },
            ],
            'meta': {
              'qsos': {'next_cursor': 'row:40', 'records_left': 200},
              'operations': {'records_left': 0},
            },
          };
        }
        // Round 2, cursor mode: a page that stops INSIDE stamp 100, with more of it behind.
        return {
          'qsos': [
            for (var i = 0; i < 100; i++)
              {
                'uuid': 'tie-$i',
                'operation': 'op1',
                'their': {'call': 'W1AW$i'},
                'startAtMillis': i,
                'syncedAtMillis': 100,
              },
          ],
          'meta': {
            'qsos': {'next_cursor': 'row:140', 'records_left': 100},
            'operations': {'records_left': 0},
          },
        };
      };

      await engine.runOneRound();
      expect(settings.state['earliestQSOSyncedAtMillis'], 161,
          reason: 'no cursor was sent, so the server extended over its edge stamp and `< 161` '
              'skips nothing - `+ 1` here is what stalls a real backfill');

      await engine.runOneRound();
      expect(settings.state['earliestQSOSyncedAtMillis'], 101,
          reason: 'this page stopped mid-stamp, so the fallback must re-cover 100 - banking 100 '
              'would ask for `< 100` and lose the rest of the tie for good, silently, with '
              'records_left counting down around the hole');
    });

    // `errors.<side>.pagination.cursor` is how the server says it refused a cursor (malformed, or
    // minted for another window) and answered the millisecond window instead. Holding the refused
    // cursor and re-sending it every round is the failure this prevents.
    test('a refused cursor is dropped rather than re-sent every round', () async {
      settings.state = {'lastSyncAccountUUID': 'acct-1', 'backfillQSOCursor': 'stale:9'};
      final cursorsSent = <String?>[];
      transport.responder = (method, args) {
        final sync = ((args['meta'] as Map)['sync'] as Map)['qsos'] as Map;
        cursorsSent.add(sync['cursor'] as String?);
        return {
          'qsos': const [],
          'meta': {
            'qsos': {'records_left': 7},
            'operations': {'records_left': 0},
          },
          'errors': {
            'qsos': {
              'pagination': {'cursor': 'Unsupported cursor version'},
            },
          },
        };
      };

      await engine.runOneRound();
      await engine.runOneRound();

      expect(cursorsSent, ['stale:9', null],
          reason: 'the server said it refused this cursor, so re-sending it just repeats the '
              'refusal - and an empty page alone must NOT clear one, or a cooldown round would');
    });

    // The error block is server-supplied and lands after the merge but before the state write, so
    // an unexpected shape must not throw: that would lose the round's cursor and watermark and
    // then re-throw on the identical page every round.
    test('an unrecognizable errors block is ignored rather than thrown on', () async {
      settings.state = {'lastSyncAccountUUID': 'acct-1', 'backfillQSOCursor': 'held:3'};
      transport.responder = (method, args) => {
            'qsos': [
              {'uuid': 'q1', 'operation': 'op1', 'their': {'call': 'W1AW'}, 'syncedAtMillis': 500},
            ],
            'meta': {
              'qsos': {'next_cursor': 'row:1', 'records_left': 2},
              'operations': {'records_left': 0},
            },
            // Not the documented `{side: {pagination: {...}}}` shape at all.
            'errors': 'something went wrong',
          };

      await engine.runOneRound();

      // A throw inside _processResponseMeta is swallowed by runOneRound's catch, so "no
      // exception escaped" proves nothing. These two only get written if it ran to the end.
      expect(settings.state['latestQSOSyncedAtMillis'], 500,
          reason: 'the watermark is written after the errors block is read - a throw there loses '
              'this round entirely and re-throws on the identical page every round after');
      expect(settings.state['backfillQSOCursor'], 'row:1');
    });

    // A cursor that will not move comes back on a full page, and a full page is rescheduled at
    // the loop delay — which is the right rate for it (the fastest the server's cooldown allows,
    // and the log says so), as long as nothing reads the stall as a timestamp tie and grows the
    // limit, or drops it to the idle rate.
    test('a server echoing back the cursor it was sent retries at the loop delay', () async {
      final logs = <String>[];
      engine.dispose();
      engine = SyncEngine(
        operations: operations,
        qsos: qsos,
        settings: settings,
        transport: transport.call,
        log: logs.add,
      );
      settings.state = {'lastSyncAccountUUID': 'acct-1', 'backfillQSOCursor': 'row:7'};
      transport.responder = (method, args) => {
            'qsos': [
              for (var i = 0; i < 100; i++)
                {
                  'uuid': 'q$i',
                  'operation': 'op1',
                  'their': {'call': 'W1AW$i'},
                  'startAtMillis': i,
                  'syncedAtMillis': 400 - i,
                },
            ],
            'meta': {
              // The same cursor back, on a full page: the next round would re-request this page.
              'qsos': {'next_cursor': 'row:7', 'records_left': 99},
              'operations': {'records_left': 0},
              'flags': {'suggested_sync_loop_delay': 5500, 'suggested_sync_check_period': 60000},
            },
          };

      await engine.runOneRound();

      expect(logs.where((l) => l.contains('came back unchanged')), isNotEmpty,
          reason: 'an unmoving cursor is named, or the boost logic reads it as a timestamp tie');
      final wait = engine.nextAttemptAt!.difference(realNowUtc());
      expect(wait, lessThanOrEqualTo(const Duration(milliseconds: 5500)),
          reason: 'the log promises the loop delay; idling at the check period would make a stuck '
              'backfill recover at the idle rate');
      expect(wait, greaterThan(const Duration(seconds: 4)));
    });

    test('a server flag that is not a number is ignored and named, and the round still lands', () async {
      final logs = <String>[];
      engine.dispose();
      engine = SyncEngine(
        operations: operations,
        qsos: qsos,
        settings: settings,
        transport: transport.call,
        log: logs.add,
      );
      settings.state = {'lastSyncAccountUUID': 'acct-1', 'backfillQSOCursor': 'row:7'};
      transport.responder = (method, args) => {
            'qsos': [
              for (var i = 0; i < 100; i++)
                {'uuid': 'q$i', 'operation': 'op1', 'their': {'call': 'W1AW$i'}, 'startAtMillis': i, 'syncedAtMillis': 400 - i},
            ],
            'meta': {
              'qsos': {'next_cursor': 'row:8', 'records_left': 5},
              'operations': {'records_left': 0},
              // A hand-edited plans.flags row: a throw on it would land after the merge and before
              // the state write, so the cursor never advances and this page is re-pulled forever.
              'flags': {'suggested_sync_check_period': 'a minute', 'suggested_sync_loop_delay': '5500'},
            },
          };

      await engine.runOneRound();

      expect(settings.state['backfillQSOCursor'], 'row:8');
      expect(logs.where((l) => l.contains('suggested_sync_check_period=a minute')), isNotEmpty);
      // A numeric string is a number: a full page waits the 5.5 s loop delay it carried, not the
      // 20 s default.
      expect(engine.nextAttemptAt!.difference(realNowUtc()), lessThanOrEqualTo(const Duration(milliseconds: 5500)));
    });

    // The ascending mirror of the backfill fallback: a forward cursor page also stops at the
    // limit wherever that lands, and the fallback window is `> watermark`, so banking the last
    // stamp delivered would skip whatever else shares it.
    test('a forward cursor page banks a watermark that re-covers the stamp it stopped in', () async {
      settings.state = {
        'lastSyncAccountUUID': 'acct-1',
        'completedFullSync': true,
        'forwardQSOCursor': 'fwd:5',
      };
      transport.responder = (method, args) => {
            'qsos': [
              {'uuid': 'f1', 'operation': 'op1', 'their': {'call': 'W1AW'}, 'syncedAtMillis': 900},
            ],
            'meta': {
              'qsos': {'next_cursor': 'fwd:6', 'records_left': 4},
              'operations': {'records_left': 0},
            },
          };

      await engine.runOneRound();

      expect(settings.state['latestQSOSyncedAtMillis'], 899,
          reason: 'the page stopped inside stamp 900, so banking 900 would ask for `> 900` and '
              'skip the rest of it with nothing counting the loss');
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

  // The sweep only ever runs from a round, so the round is the only place
  // its effect on the reported bug — a "removed on another device" notice
  // that comes back every single sync round for an operation this device
  // holds nothing of — can actually be pinned. Without the call in the
  // round, every repository-level test still passes and the notice still
  // returns forever.
  group('received purges with nothing held here', () {
    setUp(() {
      transport.responder = (method, args) => {'account': {'uuid': 'acct-1'}};
    });

    test('a round drops one an earlier build stranded', () async {
      await operations.mergeFromSync([
        {'uuid': 'stranded-op', 'stationCall': 'KI2D/T', 'updatedAtMillis': 1},
      ]);
      await operations.mergeFromSync([
        {'uuid': 'stranded-op', 'stationCall': 'KI2D/T', 'deleted': true, 'purged': true, 'updatedAtMillis': 2},
      ]);
      expect((await operations.watchReceivedPurgesPending().first).map((o) => o.uuid), ['stranded-op']);

      await engine.runOneRound();

      expect(await operations.get('stranded-op'), isNull);
      expect(await operations.watchReceivedPurgesPending().first, isEmpty);
    });

    test('a round leaves one whose QSOs are held here for the operator', () async {
      final op = await operations.create(stationCall: 'KI2D/T');
      await qsos.add(op.uuid, {'their': {'call': 'W1AW'}, 'startAtMillis': 1000});
      await operations.mergeFromSync([
        {'uuid': op.uuid, 'stationCall': 'KI2D/T', 'deleted': true, 'purged': true, 'updatedAtMillis': 9999999999999},
      ]);

      await engine.runOneRound();

      expect(await operations.get(op.uuid), isNotNull,
          reason: 'removing this device\'s own QSOs is exactly what the operator has to confirm');
      expect((await operations.watchReceivedPurgesPending().first).map((o) => o.uuid), [op.uuid]);
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

  // A device that dropped a tombstone it could not read has no local trace of
  // the mistake and never asks for the correcting record again — the forward
  // cursor moved past it rounds ago. The one-time rewind is the only thing
  // that puts those records back on the wire, and forward mode asks for other
  // clients' writes only, which is exactly where a foreign-dialect delete
  // came from.
  group('the one-time forward-cursor rewind', () {
    late List<Map<String, dynamic>> syncArgs;

    setUp(() {
      syncArgs = [];
      settings.state = {
        'lastSyncAccountUUID': 'acct-1',
        'completedFullSync': true,
        'latestOperationSyncedAtMillis': 5000,
        'latestQSOSyncedAtMillis': 6000,
        'forwardOperationCursor': 'fwd:op:9',
        'forwardQSOCursor': 'fwd:qso:9',
        // The one group that wants the rewind, so it says so — everywhere
        // else the fake defaults it away.
        SyncEngine.tombstoneRewindKey: false,
      };
      transport.responder = (method, args) {
        if (method == 'sync') syncArgs.add(args);
        return {
          'account': {'uuid': 'acct-1'},
          'meta': {
            'operations': {'records_left': 0},
            'qsos': {'records_left': 0},
          },
        };
      };
    });

    Map<String, dynamic> forwardWindow(Map<String, dynamic> args, String side) =>
        ((args['meta'] as Map)['sync'] as Map)[side] as Map<String, dynamic>;

    test('the first round asks for the account history again, from the beginning', () async {
      await engine.runOneRound();

      // Both halves matter: a banked watermark left behind asks `> 5000` and
      // a cursor left behind resumes mid-history, and either one alone skips
      // every record the repair exists to re-deliver.
      expect(forwardWindow(syncArgs.single, 'operations')['syncedSinceMillis'], 0);
      expect(forwardWindow(syncArgs.single, 'qsos')['syncedSinceMillis'], 0);
      expect(forwardWindow(syncArgs.single, 'operations').containsKey('cursor'), isFalse);
      expect(forwardWindow(syncArgs.single, 'qsos').containsKey('cursor'), isFalse);
      // Forward mode, not backfill: the account's history is already here, so
      // restarting the backward walk would re-pull it for nothing.
      expect(forwardWindow(syncArgs.single, 'operations')['anyClient'], isFalse);
    });

    test('it never spends a second round on itself', () async {
      await engine.runOneRound();
      settings.state = {...settings.state, 'latestQSOSyncedAtMillis': 7000};

      await engine.runOneRound();

      // Rewinding again would pin the device to the start of its history
      // forever, one wasted pass per round, and it would never catch up.
      expect(forwardWindow(syncArgs.last, 'qsos')['syncedSinceMillis'], 7000);
      expect(settings.state[SyncEngine.tombstoneRewindKey], isTrue);
    });

    test('a device still backfilling records the rewind without changing its walk', () async {
      // Backfill already pages the whole account history with `anyClient`, so
      // it delivers the correcting records on its own. What must not happen
      // is the flag going unwritten and the rewind firing later, mid-forward,
      // once the backfill has finished.
      settings.state = {'lastSyncAccountUUID': 'acct-1', SyncEngine.tombstoneRewindKey: false};

      await engine.runOneRound();

      expect(settings.state[SyncEngine.tombstoneRewindKey], isTrue);
      expect(forwardWindow(syncArgs.single, 'operations')['anyClient'], isTrue);
    });
  });
}

/// The sync round is also the app's connectivity probe. These
/// tests exist because the two jobs pull in different directions: sync's own
/// failure handling wants to be patient and count streaks, while the probe's
/// answer has to be a fact about the network — right on the first failure,
/// and never guessed from a failure that was not the network's fault.
void _reachabilityTests() {
  late HaLoDatabase db;
  late _FakeSyncSettings settings;
  late _FakeTransport transport;
  late List<bool> reported;

  SyncEngine build({bool Function(Object)? classify}) => SyncEngine(
        operations: OperationsRepository(db),
        qsos: QsosRepository(db),
        transport: transport.call,
        settings: settings,
        onReachability: reported.add,
        isTransportFailure: classify ?? (e) => e is _NoAnswer,
      );

  setUp(() {
    db = HaLoDatabase(NativeDatabase.memory());
    settings = _FakeSyncSettings(state: {'lastSyncAccountUUID': 'acct-1', 'completedFullSync': true});
    transport = _FakeTransport((method, args) => const {});
    reported = [];
  });

  tearDown(() async => db.close());

  test('a transport that answers reports reachable, whatever it answered with', () async {
    // A REJECTED round, deliberately: the server saying no is proof the
    // network is there. Reading reachability off "did the round succeed"
    // instead would put a device with a stale token into offline mode —
    // quietening real errors and suspending lookups that work fine.
    transport.responder = (method, args) => const {'error': 'registration refused'};
    final engine = build();
    await engine.runOneRound();
    engine.dispose();
    expect(reported, [true]);
  });

  test('only a transport-shaped failure reports unreachable', () async {
    transport.responder = (method, args) => throw _NoAnswer();
    final engine = build();
    await engine.runOneRound();
    engine.dispose();
    expect(reported, [false]);
  });

  test('a failure the classifier does not recognise reports nothing at all', () async {
    // Silence, not `true`. A dead extension host and a bug in our own payload
    // both throw here and neither says anything about the network; claiming
    // "reached" would clear a genuine offline state, and claiming
    // "unreachable" would fake one.
    transport.responder = (method, args) => throw StateError('runtime is gone');
    final engine = build();
    await engine.runOneRound();
    engine.dispose();
    expect(reported, isEmpty);
  });

  test('an unreachable round is rescheduled inside the probe ceiling', () async {
    transport.responder = (method, args) => throw _NoAnswer();
    final engine = build();
    // Eight, not fewer: the general backoff is loopDelay + 2^errorCount, so
    // it only passes the two-minute ceiling at the seventh failure. A shorter
    // loop would leave this test unable to fail with the cap deleted — the
    // uncapped value would already be inside the bound it asserts.
    for (var i = 0; i < 8; i++) {
      await engine.runOneRound();
    }
    final wait = engine.nextAttemptAt!.difference(realNowUtc());
    engine.dispose();
    expect(wait, lessThanOrEqualTo(SyncEngine.unreachableBackoffCeiling));
  });

  test('a failure that is not the network keeps the general backoff', () async {
    transport.responder = (method, args) => throw StateError('runtime is gone');
    final engine = build();
    for (var i = 0; i < 8; i++) {
      await engine.runOneRound();
    }
    final wait = engine.nextAttemptAt!.difference(realNowUtc());
    engine.dispose();
    expect(wait, greaterThan(SyncEngine.unreachableBackoffCeiling));
  });

  test('a failed retryNow does not push the schedule further out', () async {
    transport.responder = (method, args) => throw _NoAnswer();
    final engine = build();
    for (var i = 0; i < 4; i++) {
      await engine.runOneRound();
    }
    final before = engine.nextAttemptAt!;
    expect(await engine.retryNow(), SyncRetryOutcome.unreachable);
    final after = engine.nextAttemptAt!;
    engine.dispose();
    // Tapping retry is a question, not a failed attempt. If the round's own
    // catch were allowed to reschedule, an operator tapping three times would
    // push their own next automatic attempt out each time — the opposite of
    // what they asked for.
    expect(after.isAfter(before.add(const Duration(seconds: 1))), isFalse);
  });

  test('retryNow that reaches the service reports so', () async {
    final engine = build();
    expect(await engine.retryNow(), SyncRetryOutcome.reached);
    engine.dispose();
  });

  test('a second retryNow inside the floor is refused rather than sent', () async {
    final engine = build();
    await engine.retryNow();
    final callsAfterFirst = transport.calls.length;
    expect(await engine.retryNow(), SyncRetryOutcome.throttled);
    engine.dispose();
    // Refused, not merely reported as throttled: a held tap must not become
    // a request loop.
    expect(transport.calls.length, callsAfterFirst);
  });

  test('a round that never called the transport says so rather than guessing', () async {
    // An account change waiting on the operator: nothing was sent, so nothing
    // was learned. Reporting this as "still unreachable" would tell someone
    // who just walked into coverage that they had not.
    settings.state = {'pendingAccountUUID': 'acct-2'};
    final engine = build();
    expect(await engine.retryNow(), SyncRetryOutcome.notAttempted);
    engine.dispose();
    expect(reported, isEmpty);
  });

  test('a retry while a round is on the network says so, and keeps its throttle', () async {
    // The tap lands during an 8-second transport timeout — which is exactly
    // when this dialog is open. Answering "we never tried" and then refusing
    // the next tap as too soon gives the operator two wrong answers at the
    // one moment the button exists for.
    final gate = Completer<Map<String, dynamic>>();
    transport.responder = (method, args) => throw StateError('unused');
    final engine = SyncEngine(
      operations: OperationsRepository(db),
      qsos: QsosRepository(db),
      transport: (method, args) => gate.future,
      settings: settings,
      onReachability: reported.add,
      isTransportFailure: (e) => e is _NoAnswer,
    );
    final round = engine.runOneRound();
    await pumpEventQueue();

    expect(await engine.retryNow(), SyncRetryOutcome.inFlight);
    // The throttle is untouched, so the operator's next tap — once the round
    // has landed — is a real attempt rather than a refusal.
    gate.complete(const {});
    await round;
    expect(await engine.retryNow(), isNot(SyncRetryOutcome.throttled));
    engine.dispose();
  });

  test('a failed retry with nothing saved leaves the round\'s own backoff alone', () async {
    transport.responder = (method, args) => throw _NoAnswer();
    final engine = build();
    // Never started, so nothing was ever scheduled: there is no previous
    // schedule to restore. Falling back to the flat loop delay here would
    // replace the round's considered backoff with 20 seconds.
    expect(await engine.retryNow(), SyncRetryOutcome.unreachable);
    final wait = engine.nextAttemptAt!.difference(realNowUtc());
    engine.dispose();
    expect(wait, greaterThan(SyncEngine.defaultLoopDelay));
  });

  test('sync switched off has no probe to fire', () async {
    settings.enabled = false;
    final engine = build();
    expect(await engine.retryNow(), SyncRetryOutcome.disabled);
    engine.dispose();
  });
}

class _NoAnswer implements Exception {}

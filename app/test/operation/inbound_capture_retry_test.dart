// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An inbound WSJT-X/N1MM "QSO Logged" datagram is unreplayable — the source
// program never retransmits it, and the operator never typed it. The traps
// these tests exist to catch: a capture insert failure being swallowed (the
// QSO vanishes with nothing on screen), and the retry queue failing to drain
// once the database recovers. Also what a capture picks up from the operation
// it lands in — the parsers know nothing about who is at the key here.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/inbound_qso_listener_service.dart';
import 'package:ham2k_logger/services/lookup_queue_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';

import '../support/fake_clock.dart';

/// [capture] throws for the first [failures] calls, then behaves normally —
/// the transient-database-error stand-in.
class _FailingCaptures extends InboundCaptureRepository {
  _FailingCaptures(super.db, {required this.failures});
  int failures;

  @override
  Future<InboundCaptureRow> capture({required String source, required String dedupeKey, required Map<String, dynamic> qsoData}) {
    if (failures > 0) {
      failures--;
      throw StateError('disk full');
    }
    return super.capture(source: source, dedupeKey: dedupeKey, qsoData: qsoData);
  }
}

/// [add] throws while [failing] — stands in for the routing half
/// (addToOperation) staying broken after the capture insert recovers.
class _FailingQsos extends QsosRepository {
  _FailingQsos(super.db);
  bool failing = true;

  @override
  Future<Qso> add(String operationUuid, Map<String, dynamic> qsoData, {List<SequenceDescriptor> serialSequences = const []}) {
    if (failing) throw StateError('routing failed');
    return super.add(operationUuid, qsoData, serialSequences: serialSequences);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late OperationsRepository operations;
  late QsosRepository qsos;
  late SettingsService settings;
  late LookupQueueService lookupQueue;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HaLoDatabase(NativeDatabase.memory());
    operations = OperationsRepository(db);
    qsos = QsosRepository(db);
    settings = SettingsService(await SharedPreferences.getInstance());
    lookupQueue = LookupQueueService(
      lookup: (call, {required qso, required operation, bool online = true, bool recentContext = false}) async => null,
      qsos: qsos,
      operations: operations,
      statusBar: StatusBarService(await SharedPreferences.getInstance()),
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// What `watchPending` would emit, read once. These tests run on a fake
  /// clock, and a drift stream delivers through the real event loop, which
  /// the clock's steps hold up.
  Future<List<InboundCaptureRow>> pendingNow() => (db.select(db.inboundCaptures)..where((c) => c.addedToOperation.isNull())).get();

  InboundQsoListenerService service(InboundCaptureRepository captures) => InboundQsoListenerService(
    settings: settings,
    captures: captures,
    qsos: qsos,
    operations: operations,
    lookupQueue: lookupQueue,
    captureRetryInterval: const Duration(milliseconds: 20),
  );

  test(
    'a failed capture surfaces captureError and is retried until it lands, then the error clears',
    () => runOnFakeClock((_) async {
      final captures = _FailingCaptures(db, failures: 1);
      final listener = service(captures);
      addTearDown(listener.dispose);

      await listener.captureIncoming(
        source: wsjtxSource,
        dedupeKey: 'k1',
        qso: {
          'their': {'call': 'W1AW'},
          'band': '20m',
          'mode': 'FT8',
        },
      );

      // The insert threw: nothing stored yet, but the failure is visible and
      // the payload is queued — not silently dropped.
      expect(listener.captureError, contains('disk full'));
      expect(await pendingNow(), isEmpty);

      // After the retry interval the insert succeeds and the error clears.
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final pending = await pendingNow();
      expect(pending.map((r) => (r.qso['their'] as Map)['call']).toList(), ['W1AW']);
      expect(listener.captureError, isNull);
    }),
  );

  test(
    'a capture that keeps failing keeps the error visible and keeps retrying without duplicating',
    () => runOnFakeClock((_) async {
      final captures = _FailingCaptures(db, failures: 3);
      final listener = service(captures);
      addTearDown(listener.dispose);

      await listener.captureIncoming(
        source: n1mmSource,
        dedupeKey: 'k2',
        qso: {
          'their': {'call': 'K1ABC'},
        },
      );
      expect(listener.captureError, isNotNull);

      // Two more retries fail (failures: 3 in total); the error must still be
      // showing in between — a cleared error with the QSO still unsaved is the
      // silent-loss state this service exists to prevent.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(listener.captureError, isNotNull);

      await Future<void>.delayed(const Duration(milliseconds: 90));
      final pending = await pendingNow();
      expect(pending, hasLength(1));
      expect(listener.captureError, isNull);
    }),
  );

  test(
    'a routing failure mid-drain does not drop the rest of the retry queue',
    () => runOnFakeClock((_) async {
      // The trap: the drain clears the queue before iterating, so a throw
      // from the post-insert routing (addToOperation) escaping the loop
      // would vanish every not-yet-retried entry — unreplayable QSOs — and
      // leave no timer armed.
      final captures = _FailingCaptures(db, failures: 2);
      final failingQsos = _FailingQsos(db);
      final listener = InboundQsoListenerService(
        settings: settings,
        captures: captures,
        qsos: failingQsos,
        operations: operations,
        lookupQueue: lookupQueue,
        captureRetryInterval: const Duration(milliseconds: 20),
      );
      addTearDown(listener.dispose);
      final op = await operations.create(stationCall: 'KI2D');
      listener.setReceivingOperation(op.uuid);

      await listener.captureIncoming(
        source: wsjtxSource,
        dedupeKey: 'a',
        qso: {
          'their': {'call': 'W1AW'},
        },
      );
      await listener.captureIncoming(
        source: wsjtxSource,
        dedupeKey: 'b',
        qso: {
          'their': {'call': 'K1ABC'},
        },
      );

      // First drain: entry a's insert lands but its routing throws. Entry b
      // must survive to a later drain; once routing recovers, both rows
      // exist in the capture table.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      failingQsos.failing = false;
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final rows = await db.select(db.inboundCaptures).get();
      expect(rows.map((r) => r.dedupeKey).toSet(), {'a', 'b'});
    }),
  );

  test('a routed capture is stamped with the operator and position of the operation it lands in', () async {
    // The parsers stay pure — a datagram says nothing about which of this
    // station's positions is receiving it — so the stamp has to happen here,
    // or a WSJT-X contact is the one row in a multi-op log that names nobody.
    final captures = InboundCaptureRepository(db);
    final listener = service(captures);
    addTearDown(listener.dispose);
    final op = await operations.create(stationCall: 'KI2D');
    await operations.updateLocalData(op.uuid, {'operatorCall': 'W1ABC', 'multiIdentifier': '02'});
    listener.setReceivingOperation(op.uuid);

    await listener.captureIncoming(
      source: wsjtxSource,
      dedupeKey: 'a',
      qso: {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'FT8',
      },
    );

    final logged = await qsos.watchForOperation(op.uuid).first;
    expect((logged.single.data['our'] as Map)['operatorCall'], 'W1ABC');
    // Canonical, the same form the spot and the details dialog agree on.
    expect((logged.single.data['our'] as Map)['multiIdentifier'], '2');
  });

  test('an operator the source itself named survives the stamp', () async {
    // WSJT-X names an operator of its own when it differs from the station
    // call. That is a fact of the contact; ours is a default for when the
    // datagram is silent.
    final captures = InboundCaptureRepository(db);
    final listener = service(captures);
    addTearDown(listener.dispose);
    final op = await operations.create(stationCall: 'KI2D');
    await operations.updateLocalData(op.uuid, {'operatorCall': 'W1ABC'});
    listener.setReceivingOperation(op.uuid);

    await listener.captureIncoming(
      source: wsjtxSource,
      dedupeKey: 'a',
      qso: {
        'our': {'operatorCall': 'K2SUL'},
        'their': {'call': 'W1AW'},
      },
    );

    final logged = await qsos.watchForOperation(op.uuid).first;
    expect((logged.single.data['our'] as Map)['operatorCall'], 'K2SUL');
  });
}

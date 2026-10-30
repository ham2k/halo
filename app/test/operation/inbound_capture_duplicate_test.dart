// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One contact, two datagrams at once. WSJT-X sends every datagram once per
// outgoing interface it has ticked, and a listener joined on each of them
// receives both copies microseconds apart. The trap: `capture()`'s unique
// index collapses the two into one ROW, but the second copy reads that row
// while the first copy's routing has yet to mark it added — and logs the
// QSO a second time.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/inbound_qso_listener_service.dart';
import 'package:ham2k_logger/services/lookup_queue_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late OperationsRepository operations;
  late QsosRepository qsos;
  late InboundQsoListenerService listener;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HaLoDatabase(NativeDatabase.memory());
    operations = OperationsRepository(db);
    qsos = QsosRepository(db);
    final prefs = await SharedPreferences.getInstance();
    listener = InboundQsoListenerService(
      settings: SettingsService(prefs),
      captures: InboundCaptureRepository(db),
      qsos: qsos,
      operations: operations,
      lookupQueue: LookupQueueService(
        lookup: (call, {required qso, required operation, bool online = true, bool recentContext = false}) async => null,
        qsos: qsos,
        operations: operations,
        statusBar: StatusBarService(prefs),
      ),
    );
  });

  tearDown(() async {
    listener.dispose();
    await db.close();
  });

  test('a datagram delivered twice at once logs its QSO once', () async {
    final op = await operations.create(stationCall: 'KI2D');
    listener.setReceivingOperation(op.uuid);
    final qso = {
      'their': {'call': 'W1AW'},
      'band': '20m',
      'mode': 'FT8',
    };
    // Not one after the other: the second copy has to enter while the first
    // sits between its insert and its `markAdded`.
    await Future.wait([
      listener.captureIncoming(source: wsjtxSource, dedupeKey: 'same', qso: qso),
      listener.captureIncoming(source: wsjtxSource, dedupeKey: 'same', qso: qso),
    ]);

    final logged = await qsos.watchForOperation(op.uuid).first;
    expect(logged.map((q) => (q.data['their'] as Map)['call']).toList(), ['W1AW']);
    final rows = await db.select(db.inboundCaptures).get();
    expect(rows.single.addedToOperation, op.uuid);
  });
}

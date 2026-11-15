// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Neither N1MM's broadcast nor WSJT-X's protocol says who sent a datagram,
// and anyone on the network can send one. Added on arrival, a stranger's
// datagram would be a contact in the operator's log, synced to their account
// and looked up online, with nobody having seen it.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/inbound_qso_listener_service.dart';
import 'package:ham2k_logger/services/lookup_queue_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';

const _thisDevice = '192.168.1.10';
const _otherDevice = '192.168.1.20';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late OperationsRepository operations;
  late QsosRepository qsos;
  late SettingsService settings;
  late StatusBarService statusBar;
  late InboundQsoListenerService listener;
  late Operation op;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HaLoDatabase(NativeDatabase.memory());
    operations = OperationsRepository(db);
    qsos = QsosRepository(db);
    final prefs = await SharedPreferences.getInstance();
    settings = SettingsService(prefs);
    statusBar = StatusBarService(prefs);
    listener = InboundQsoListenerService(
      settings: settings,
      captures: InboundCaptureRepository(db),
      qsos: qsos,
      operations: operations,
      lookupQueue: LookupQueueService(
        lookup: (call, {required qso, required operation, bool online = true, bool recentContext = false}) async => null,
        qsos: qsos,
        operations: operations,
        statusBar: statusBar,
      ),
      statusBar: statusBar,
      isOwnAddress: (address) async => address == _thisDevice,
    );
    op = await operations.create(stationCall: 'KI2D');
    listener.setReceivingOperation(op.uuid);
  });

  tearDown(() async {
    listener.dispose();
    await db.close();
  });

  Future<void> arrive(String call, String sender) => listener.captureIncoming(
    source: wsjtxSource,
    dedupeKey: call,
    qso: {
      'their': {'call': call},
      'band': '20m',
      'mode': 'FT8',
    },
    sender: sender,
  );

  Future<List<String>> logged() async => [for (final q in await qsos.watchForOperation(op.uuid).first) (q.data['their'] as Map)['call'] as String];

  List<String> heldNotices() => [
    for (final notice in statusBar.activeNotices)
      if (notice.key.startsWith('inboundQsos:held')) notice.text,
  ];

  bool held() => heldNotices().isNotEmpty;

  test("this device's contacts are added as they arrive", () async {
    await arrive('W1AW', _thisDevice);
    expect(await logged(), ['W1AW']);
    expect(held(), isFalse);
  });

  test("another device's contact waits, says where from, and the operator is told", () async {
    await arrive('W1AW', _otherDevice);
    expect(await logged(), isEmpty);
    final waiting = await db.select(db.inboundCaptures).get();
    expect(waiting.single.addedToOperation, isNull);
    expect(waiting.single.sender, _otherDevice);
    expect(held(), isTrue);
  });

  test('a device the operator allows is added from then on', () async {
    await listener.allowSender(_otherDevice);
    expect(settings.inboundSendersAllowed, [_otherDevice], reason: 'kept, not for this session alone');
    expect(held(), isFalse);

    await arrive('W1AW', _otherDevice);
    expect(await logged(), ['W1AW']);

    await settings.setInboundSenderAllowed(_otherDevice, false);
    await arrive('K3TN', _otherDevice);
    expect(await logged(), ['W1AW'], reason: 'no longer allowed, so it waits again');
  });

  // The stored row is the capture: a copy that arrives from this device is
  // the same row, and adding it would log what the other device sent.
  test("a copy from this device of another's waiting contact still waits", () async {
    await arrive('W1AW', _otherDevice);
    await arrive('W1AW', _thisDevice);
    expect(await logged(), isEmpty);
  });

  test('each device waiting has its own notice, gone once its contacts are added', () async {
    await arrive('W1AW', _otherDevice);
    await arrive('K3TN', '192.168.1.30');
    expect(heldNotices(), hasLength(2));

    final waiting = await db.select(db.inboundCaptures).get();
    await listener.addToOperation(op.uuid, [...waiting.where((row) => row.sender == _otherDevice)]);
    expect(heldNotices(), ['A contact from 192.168.1.30 is waiting in Imports']);
  });

  // The panel's rows are a snapshot until the database says they were added,
  // so a second tap on Add hands over the same rows again.
  test('the same waiting contacts handed over twice are logged once', () async {
    await arrive('W1AW', _otherDevice);
    final waiting = await db.select(db.inboundCaptures).get();
    await Future.wait([listener.addToOperation(op.uuid, waiting), listener.addToOperation(op.uuid, waiting)]);
    expect(await logged(), ['W1AW']);
    await listener.addToOperation(op.uuid, waiting);
    expect(await logged(), ['W1AW'], reason: 'nor again once added, from the same stale rows');
  });
}

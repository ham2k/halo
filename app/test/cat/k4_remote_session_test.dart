// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/cat_traffic_log.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_remote_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_shared_session.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/cat/transports/k4_remote_connection.dart';
import 'package:ham2k_logger/services/cat/transports/k4_remote_transport.dart';
import 'package:ham2k_logger/services/panel_radio_service.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_clock.dart';
import '../support/fake_secure_storage.dart';
import '../support/fake_serial_ports.dart';

// Independently assembled synthetic packets; these tests exercise application
// boundaries, not compatibility with a particular radio firmware release.
Uint8List _envelope(List<int> payload) {
  final bytes = Uint8List(payload.length + 12);
  bytes.setRange(0, 4, [0xfe, 0xfd, 0xfc, 0xfb]);
  ByteData.sublistView(bytes).setUint32(4, payload.length, Endian.big);
  bytes.setRange(8, bytes.length - 4, payload);
  bytes.setRange(bytes.length - 4, bytes.length, [0xfb, 0xfc, 0xfd, 0xfe]);
  return bytes;
}

Uint8List _cat(String text) => _envelope([0, 0, 0, ...ascii.encode(text)]);

List<String> _commandsWithoutHeartbeat(_SecureConnection connection) =>
    connection.sent.map((frame) => ascii.decode(frame.sublist(11, frame.length - 4))).where((command) => command != 'PING;').toList();

Uint8List _pan({int receiver = 0, int centerHz = 14074000}) {
  final payload = Uint8List(27 + 1024);
  payload.setRange(0, 5, [2, 1, 42, 0, receiver]);
  final data = ByteData.sublistView(payload);
  data.setUint16(5, 1024, Endian.little);
  data.setInt64(11, centerHz, Endian.little);
  data.setInt32(19, 48, Endian.little);
  data.setInt32(23, -1300, Endian.little);
  payload.fillRange(27, payload.length, 45);
  return _envelope(payload);
}

String _info({bool tx = false}) => 'IF00014074000     +000000 00${tx ? 1 : 0}2000001 ;';

class _SecureConnection implements EquipmentConnection {
  final incoming = StreamController<Uint8List>(sync: true);
  final gone = Completer<void>();
  final sent = <List<int>>[];
  final lifecycle = <String>[];
  var closeCalls = 0;
  var throwOnSend = false;
  Completer<void>? closeBarrier;

  @override
  Stream<Uint8List> get data => incoming.stream;
  @override
  Future<void> get closed => gone.future;
  @override
  void send(List<int> bytes) {
    if (gone.isCompleted) return;
    if (throwOnSend) throw StateError('simulated transport write failure');
    sent.add(List.of(bytes));
    lifecycle.add('send:${ascii.decode(bytes.sublist(11, bytes.length - 4))}');
  }

  void receive(List<int> bytes) => incoming.add(Uint8List.fromList(bytes));

  void remoteEnd() {
    if (!gone.isCompleted) gone.complete();
    unawaited(incoming.close());
  }

  @override
  Future<void> close() async {
    closeCalls++;
    lifecycle.add('close');
    if (!gone.isCompleted) gone.complete();
    await closeBarrier?.future;
    if (!incoming.isClosed) await Future<void>.microtask(incoming.close);
  }
}

class _Sink implements EquipmentSink {
  final sent = <String>[];
  final readings = <VfoReading>[];
  final transmitting = <bool>[];
  var alive = 0;

  @override
  void send(List<int> bytes) => sent.add(ascii.decode(bytes));
  @override
  void report(VfoReading reading) => readings.add(reading);
  @override
  void reportTransmitting(bool value) => transmitting.add(value);
  @override
  void reportAlive() => alive++;
  @override
  void reportPower(num watts) {}
  @override
  void reportKeyerSpeed(int wpm) {}
  @override
  void reportVoiceActivity(VoiceActivity? activity) {}
  @override
  void reportVoiceMemories(List<VoiceMemory> memories) {}
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportProblem(String? message) {}
  @override
  void reportDiagnostic(String? note) {}
  @override
  void reportChannels(List<EquipmentChannel> channels) {}
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
  @override
  void reportMeter(RadioMeter meter, num value) {}
}

class _TrafficLog extends CatTrafficLog {
  final incoming = <String>[];
  @override
  void received(String node, List<int> bytes) => incoming.add(ascii.decode(bytes));
}

class _RemoteTransport extends K4RemoteTransport {
  final secureConnections = <_SecureConnection>[];
  final targets = <Map<String, dynamic>>[];
  Completer<void>? openBarrier;

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async {
    targets.add(Map.of(target));
    final secure = _SecureConnection();
    secureConnections.add(secure);
    await openBarrier?.future;
    return K4RemoteConnection(secure);
  }
}

class _PanSink extends _Sink implements SpectrumSink {
  @override
  void reportSpectrum(SpectrumFrame frame) {}
  @override
  void reportSpectrumSettings(SpectrumSettings settings) {}
  @override
  void reportSpectrumProblem(String? problem) {}
}

Future<({CatService cat, String uuid, _RemoteTransport transport, SettingsService settings, SharedPreferences prefs, PanelRadioService panel})>
_connectedRemote({bool connect = true}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsService(prefs, secureStorage: FakeSecureStorage());
  final radio = RadioService(prefs, writeDelay: Duration.zero);
  addTearDown(radio.dispose);
  final transport = _RemoteTransport();
  final builtIn = EquipmentRegistry();
  final original = builtIn.typeFor('k4-remote')!;
  final local = builtIn.typeFor('k4-tcp')!;
  final localTransport = builtIn.transportFor(local.transportKey)!;
  final cat = CatService(
    settings,
    radio: radio,
    registry: EquipmentRegistry(
      models: [
        EquipmentModel(
          key: 'remote-test',
          category: kCategoryTransceiver,
          name: () => 'Remote test',
          variants: [
            EquipmentVariant(
              key: 'k4-remote-test',
              driver: original.driver,
              transport: transport,
              defaultConfig: original.defaultConfig,
              overrides: original.overrides,
            ),
            EquipmentVariant(
              key: 'k4-local-test',
              driver: local.driver,
              transport: localTransport,
              defaultConfig: local.defaultConfig,
              overrides: local.overrides,
            ),
          ],
        ),
      ],
      transports: {transport.key: transport, localTransport.key: localTransport},
    ),
    reconnectDelay: Duration.zero,
    idleRetryFirst: const Duration(minutes: 5),
  );
  addTearDown(cat.dispose);
  final uuid = (await cat.addNode(typeKey: 'k4-remote-test', config: {'host': 'synthetic.invalid', 'remotePort': 9204, 'password': 'test-private-key'})).uuid;
  if (connect) await cat.connect(uuid);
  return (cat: cat, uuid: uuid, transport: transport, settings: settings, prefs: prefs, panel: PanelRadioService(cat, radio));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    useSerialPortsForTest(const []);
    AppClock.followZoneClock = true;
  });
  tearDown(() => AppClock.followZoneClock = false);

  test('fragmented and coalesced remote traffic delivers CAT and PAN on separate channels', () {
    fakeAsync((async) {
      final secure = _SecureConnection();
      final connection = K4RemoteConnection(secure);
      final cat = <int>[];
      final pan = <K4RemotePanPacket>[];
      final first = connection.data.listen(cat.addAll);
      final second = connection.pan.listen(pan.add);
      final audio = _envelope([1, 1, 0, 3, 240, 0, 0, ...ascii.encode('FA00099999999;TX;')]);
      final mini = _envelope([3, 1, 0, 0, 0, ...ascii.encode('MD9;')]);
      final wire = [..._cat('FA00014'), ..._pan(), ...audio, ...mini, ..._cat('074000;MD2;'), ..._pan(receiver: 1)];
      for (var offset = 0; offset < wire.length; offset += 19) {
        secure.receive(wire.sublist(offset, (offset + 19).clamp(0, wire.length)));
      }
      async.flushMicrotasks();
      expect(ascii.decode(cat), 'FA00014074000;MD2;');
      expect(pan.map((packet) => packet.receiver), [0, 1]);
      expect(pan.first.centerHz, 14074000);
      expect(secure.sent, isEmpty);

      connection.send(ascii.encode('FA00014250000;'));
      expect(secure.sent.single, _cat('FA00014250000;'));
      unawaited(first.cancel());
      unawaited(second.cancel());
      unawaited(connection.close());
      async.flushMicrotasks();
      expect(secure.closeCalls, 1);
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('bad envelopes and unsupported payloads cannot enter the CAT stream or block recovery', () {
    fakeAsync((async) {
      final secure = _SecureConnection();
      final connection = K4RemoteConnection(secure);
      final cat = <int>[];
      final subscription = connection.data.listen(cat.addAll);
      final corrupt = _cat('TX;')..[15] = 0;
      secure.receive([
        0x11,
        0x22,
        ...corrupt,
        ..._envelope([99, 1, 0, ...ascii.encode('FA00099999999;')]),
        ..._cat('PONG;'),
      ]);
      async.flushMicrotasks();
      expect(ascii.decode(cat), 'PONG;');
      expect(secure.closeCalls, 0);
      unawaited(subscription.cancel());
      unawaited(connection.close());
      async.flushMicrotasks();
    });
  });

  test('CAT demand and pause propagate to the source while cancellation preserves teardown writes', () {
    fakeAsync((async) {
      final secure = _SecureConnection();
      final connection = K4RemoteConnection(secure);
      final cat = <int>[];
      final pan = <K4RemotePanPacket>[];
      var panDone = false;
      connection.pan.listen(pan.add, onDone: () => panDone = true);
      expect(secure.incoming.isPaused, isTrue, reason: 'no consumer must not create an unbounded CAT queue');
      secure.receive(_cat('FA00014074000;'));
      async.flushMicrotasks();
      final subscription = connection.data.listen(cat.addAll);
      async.flushMicrotasks();
      expect(ascii.decode(cat), 'FA00014074000;');
      expect(secure.incoming.isPaused, isFalse);
      subscription.pause();
      expect(secure.incoming.isPaused, isTrue);
      secure.receive([..._cat('MD2;'), ..._pan()]);
      async.flushMicrotasks();
      expect(ascii.decode(cat), 'FA00014074000;');
      expect(pan, isEmpty);
      subscription.resume();
      async.flushMicrotasks();
      expect(ascii.decode(cat), 'FA00014074000;MD2;');
      expect(pan, hasLength(1));
      unawaited(subscription.cancel());
      async.flushMicrotasks();
      expect(secure.closeCalls, 0, reason: 'session teardown still needs to send RX before explicit close');
      expect(secure.incoming.isPaused, isTrue);
      expect(panDone, isFalse);
      connection.send(ascii.encode('RX;'));
      expect(secure.sent.last, _cat('RX;'));
      unawaited(connection.close());
      async.flushMicrotasks();
      expect(secure.closeCalls, 1);
      expect(panDone, isTrue);
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('heartbeat is framed CAT and watchdog measures valid receive activity', () {
    fakeAsync((async) {
      final secure = _SecureConnection();
      final connection = K4RemoteConnection(secure);
      var closed = false;
      unawaited(connection.closed.then((_) => closed = true));
      final subscription = connection.data.listen((_) {});
      async.elapse(const Duration(seconds: 9));
      expect(secure.sent, hasLength(9));
      expect(secure.sent, everyElement(_cat('PING;')));
      secure.receive(_cat('PONG;'));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 9));
      expect(closed, isFalse);
      secure.receive(_pan());
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 9));
      expect(closed, isFalse);
      secure.receive([1, 2, 3, 4]);
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(closed, isTrue, reason: 'unframed garbage must not keep a dead session alive');
      expect(secure.closeCalls, 1);
      final sentAtClose = secure.sent.length;
      connection.send(ascii.encode('IF;'));
      async.elapse(const Duration(seconds: 20));
      expect(secure.sent, hasLength(sentAtClose));
      expect(async.pendingTimers, isEmpty);
      unawaited(subscription.cancel());
    });
  });

  test('remote EOF and write failure close both channels once and cancel heartbeat', () {
    for (final failure in [false, true]) {
      fakeAsync((async) {
        final secure = _SecureConnection();
        final connection = K4RemoteConnection(secure);
        var catDone = false, panDone = false;
        connection.data.listen((_) {}, onDone: () => catDone = true);
        connection.pan.listen((_) {}, onDone: () => panDone = true);
        if (failure) {
          secure.throwOnSend = true;
          async.elapse(const Duration(seconds: 1));
        } else {
          secure.remoteEnd();
        }
        async.flushMicrotasks();
        expect(catDone, isTrue);
        expect(panDone, isTrue);
        expect(secure.closeCalls, 1);
        unawaited(connection.close());
        async.flushMicrotasks();
        expect(secure.closeCalls, 1);
        expect(async.pendingTimers, isEmpty);
      });
    }
  });

  test('synchronous CAT or PAN listeners can close without leaking later packets or cleanup errors', () {
    for (final closeFromPan in [false, true]) {
      fakeAsync((async) {
        final secure = _SecureConnection();
        final connection = K4RemoteConnection(secure);
        var catFrames = 0, panFrames = 0;
        var catDone = false, panDone = false, closed = false;
        unawaited(connection.closed.then((_) => closed = true));
        connection.data.listen((_) {
          catFrames++;
          if (!closeFromPan) unawaited(connection.close());
        }, onDone: () => catDone = true);
        connection.pan.listen((_) {
          panFrames++;
          if (closeFromPan) unawaited(connection.close());
        }, onDone: () => panDone = true);
        secure.receive(closeFromPan ? [..._pan(), ..._cat('FA00014250000;')] : [..._cat('FA00014250000;'), ..._pan()]);
        async.flushMicrotasks();
        expect(catFrames, closeFromPan ? 0 : 1);
        expect(panFrames, closeFromPan ? 1 : 0);
        expect((catDone, panDone, closed), (true, true, true));
        expect(secure.closeCalls, 1);
        unawaited(connection.close());
        async.flushMicrotasks();
        expect(secure.closeCalls, 1);
        expect(async.pendingTimers, isEmpty);
      });
    }
  });

  test('every close caller waits for the same underlying TLS drain after closed is notified', () {
    fakeAsync((async) {
      final barrier = Completer<void>();
      final secure = _SecureConnection()..closeBarrier = barrier;
      final connection = K4RemoteConnection(secure);
      connection.data.listen((_) {});
      var notified = false, firstDone = false, secondDone = false;
      unawaited(connection.closed.then((_) => notified = true));
      unawaited(connection.close().then((_) => firstDone = true));
      async.flushMicrotasks();
      expect(notified, isTrue, reason: 'closed marks the connection unusable before the graceful drain finishes');
      expect(firstDone, isFalse);
      unawaited(connection.close().then((_) => secondDone = true));
      async.flushMicrotasks();
      expect((firstDone, secondDone), (false, false));
      expect(secure.closeCalls, 1);
      barrier.complete();
      async.flushMicrotasks();
      expect((firstDone, secondDone), (true, true));
      expect(secure.closeCalls, 1);
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('remote startup uses RDY and never resumes idle or TX telemetry polling', () {
    fakeAsync((async) {
      final sink = _PanSink();
      final type = EquipmentRegistry().typeFor('k4-remote')!;
      final owner = K4SharedSession(send: sink.send, pan: const Stream.empty(), config: type.driverConfig(type.defaultConfig));
      final session = owner.attach(sink, receiver: 'main');
      expect(session, isA<SpectrumSession>(), reason: 'remote spectrum must retain the remote CAT policy');
      session.startUpdates();
      expect(sink.sent.take(2), ['K40;K31;', 'RDY;']);
      expect(sink.sent.join(), isNot(contains('AI2;')));
      expect(session.expectedUpdateInterval, isNull);
      owner.handleData(Uint8List.fromList(ascii.encode('FA00014074000;MD2;DV0;SB1;${_info()}')));
      expect(sink.readings.last, const VfoReading(freqKHz: 14074, mode: 'USB'));
      var baseline = sink.sent.length;
      async.elapse(const Duration(minutes: 1));
      expect(sink.sent, hasLength(baseline));
      for (final tx in [true, false, true, false]) {
        owner.handleData(Uint8List.fromList(ascii.encode(_info(tx: tx))));
        baseline = sink.sent.length;
        async.elapse(const Duration(seconds: 20));
        expect(sink.sent, hasLength(baseline), reason: 'TX transition $tx must not arm the telemetry poller');
      }
      expect(sink.transmitting, [false, true, false, true, false]);
      owner.handleData(Uint8List.fromList(ascii.encode('TQ1;TQ0;')));
      expect(sink.transmitting.skip(5), [true, false]);
      baseline = sink.sent.length;
      session.teardown();
      owner.teardown();
      expect(sink.sent, hasLength(baseline), reason: 'remote disconnect must not downgrade AI4 with AI0');
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('only valid PONG responses report remote CAT liveness', () {
    final remoteSink = _Sink();
    final localSink = _Sink();
    final remote = KenwoodSession(remoteSink, isK4: true, remote: true);
    final local = KenwoodSession(localSink, isK4: true);
    addTearDown(remote.teardown);
    addTearDown(local.teardown);
    for (final session in [remote, local]) {
      session.handleData(Uint8List.fromList(ascii.encode('PON')));
      session.handleData(Uint8List.fromList(ascii.encode('G;PONG1720000000;PONGbad;PO;PING;')));
    }
    expect(remoteSink.alive, 2);
    expect(localSink.alive, 0);
    expect(remoteSink.readings, isEmpty);
  });

  test('remote actions read their resulting state without starting recurring polls', () {
    fakeAsync((async) {
      final sink = _Sink();
      final owner = K4SharedSession(send: sink.send, pan: const Stream.empty(), config: const {});
      final session = owner.attach(sink, receiver: 'main');
      session.startUpdates();
      sink.sent.clear();
      (session as TransceiverSession).setFrequency(14250);
      expect(sink.sent, containsAllInOrder(['FA00014250000;', r'FA;FB;MD;MD$;DT;DT$;BW;BW$;IS;IS$;']));
      sink.sent.clear();
      final ptt = session as PttSession;
      ptt.setPtt(true);
      ptt.setPtt(false);
      expect(sink.sent, ['TX;', 'TQ;', 'RX;', 'TQ;']);
      sink.sent.clear();
      owner.handleData(Uint8List.fromList(ascii.encode('PC050;')));
      expect(sink.sent, ['PCX;'], reason: 'a bare AI4 power push needs the range before it is interpreted');
      owner.handleData(Uint8List.fromList(ascii.encode('PC050H;')));
      expect(sink.sent, ['PCX;']);
      async.elapse(const Duration(minutes: 1));
      expect(sink.sent, ['PCX;']);
      session.teardown();
      owner.teardown();
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('remote pairing uses its own port and secret field without changing local CAT', () {
    final registry = EquipmentRegistry();
    final remote = registry.typeFor('k4-remote')!;
    final local = registry.typeFor('k4-tcp')!;
    final serial = registry.typeFor('k4-serial')!;
    expect(remote.defaultConfig, {'remotePort': 9204});
    expect(local.defaultConfig, {'tcpPort': 9200});
    expect(remote.secretFields, {'password'});
    expect(local.secretFields, isEmpty);
    final retained = {'host': ' synthetic.invalid ', 'remotePort': 9204, 'tcpPort': 9200, 'port': '/dev/old-k4', 'password': 'secret'};
    expect(remote.targetFor(retained), {'host': 'synthetic.invalid', 'port': 9204, 'password': 'secret'});
    expect(local.targetFor(retained), {'host': 'synthetic.invalid', 'port': 9200});
    expect(serial.targetFor(retained)['port'], '/dev/old-k4');
    final fields = remote.configElements().where((element) => element['type'] == 'field').toList();
    expect(fields.singleWhere((element) => element['key'] == 'password')['fieldType'], 'secret');
    expect(fields.map((element) => element['key']), containsAll(['host', 'remotePort', 'password']));
    expect(fields.map((element) => element['key']), isNot(contains(anyOf('tcpPort', 'telemetryInterval', 'pollInterval'))));
    expect(remote.validate({...retained, 'remotePort': 0}), isNotNull);
    expect(remote.validate(retained), isNull);
  });

  test('CatService consumes the shared PAN side channel only while displays request it', () async {
    final (:cat, :uuid, :transport, :settings, :prefs, :panel) = await _connectedRemote();
    final secure = transport.secureConnections.single;
    expect(transport.targets.single, {'host': 'synthetic.invalid', 'port': 9204, 'password': 'test-private-key'});
    expect(cat.nodeFor(uuid)!.config.containsKey('password'), isFalse);
    expect(await settings.equipmentSecret(uuid, 'password'), 'test-private-key');
    for (final key in prefs.getKeys()) {
      expect(prefs.get(key).toString(), isNot(contains('test-private-key')), reason: 'plain preferences must not contain the key');
    }
    secure.receive(_pan());
    secure.receive(_cat('FA00014074000;MD2;DV0;SB1;${_info()}'));
    await pumpEventQueue();
    expect(cat.stateFor(uuid).spectrum, isNull);
    expect(cat.stateFor(uuid).vfo, const VfoReading(freqKHz: 14074, mode: 'USB'));
    expect(cat.spectrumSessionFor(uuid), isA<SpectrumSession>());
    final available = panel.read(uuid)['spectrum'] as Map<String, dynamic>;
    expect(available['problem'], isNull);
    expect(available['spansHz'], isNotEmpty, reason: 'the remote pairing offers controls before a display starts the PAN subscription');
    final frames = <SpectrumFrame>[];
    final first = cat.spectrumFrames(uuid).listen(frames.add);
    final second = cat.spectrumFrames(uuid).listen((_) {});
    addTearDown(first.cancel);
    addTearDown(second.cancel);
    await pumpEventQueue();
    final beforePan = _commandsWithoutHeartbeat(secure);
    secure.receive(_pan(receiver: 1, centerHz: 7100000));
    secure.receive(_pan());
    await pumpEventQueue();
    expect(frames, hasLength(1));
    expect(cat.stateFor(uuid).spectrum, isNotNull);
    final snapshot = panel.read(uuid)['spectrum'] as Map<String, dynamic>;
    expect(snapshot['problem'], isNull);
    expect((snapshot['spansHz'] as List<int>).last, 24000);
    expect(_commandsWithoutHeartbeat(secure), beforePan, reason: 'spectrum demand must not configure the shared radio');
    expect(cat.setSpectrum(uuid, const SpectrumRequest(refLevelDb: 3)), isTrue);
    expect(_commandsWithoutHeartbeat(secure), beforePan);
    await first.cancel();
    expect(secure.closeCalls, 0);
    await second.cancel();
    await pumpEventQueue();
    expect(cat.stateFor(uuid).spectrum, isNull);
    expect(cat.stateFor(uuid).status, EquipmentStatus.connected);
    expect(secure.closeCalls, 0, reason: 'closing the final display must leave the shared CAT connection alive');
    expect(cat.setSpectrum(uuid, const SpectrumRequest(spanHz: 10000)), isFalse);
    secure.receive(_cat('FA00014250000;PONG;'));
    await pumpEventQueue();
    expect(cat.stateFor(uuid).vfo.freqKHz, 14250);
    await cat.disconnect(uuid);
    expect(secure.closeCalls, 1);
    expect(transport.secureConnections, hasLength(1), reason: 'PAN must not create a second transport connection');
  });

  test('CatService disconnect sends RX over the still-open remote link before closing TLS', () async {
    final (:cat, :uuid, :transport, settings: _, prefs: _, panel: _) = await _connectedRemote();
    final secure = transport.secureConnections.single;
    secure.lifecycle.clear();
    secure.sent.clear();
    cat.togglePtt(uuid);
    expect(secure.sent, contains(orderedEquals(_cat('TX;'))), reason: 'all transmit commands in this test remain inside the fake connection');
    expect(secure.closeCalls, 0);
    await cat.disconnect(uuid);
    final receive = secure.lifecycle.indexOf('send:RX;');
    final close = secure.lifecycle.indexOf('close');
    expect(receive, greaterThanOrEqualTo(0), reason: 'canceling the CAT subscription must not discard the teardown unkey');
    expect(close, greaterThan(receive));
    expect(secure.sent, contains(orderedEquals(_cat('RX;'))));
    expect(secure.closeCalls, 1);
    expect(secure.lifecycle.last, 'close');
  });

  test('logical Main and Sub share one concurrent open while retaining independent CAT and spectrum state', () async {
    final f = await _connectedRemote(connect: false);
    final sub = await f.cat.addNode(typeKey: 'k4-remote-test', config: {'host': 'synthetic.invalid', 'remotePort': 9204, 'receiver': 'sub'});
    expect(f.cat.radio1, LocalRadio(f.uuid), reason: 'adding a sibling must not take over logging');
    expect(f.cat.logicalDeviceIdFor(sub.uuid), f.cat.logicalDeviceIdFor(f.uuid));
    expect(f.cat.logicalChannelFor(sub.uuid)?['key'], 'sub');
    expect(await f.cat.storedSecretFields(sub.uuid), {'password'}, reason: 'Sub inherits the saved physical-device credential');
    final barrier = f.transport.openBarrier = Completer<void>();
    final connecting = Future.wait([f.cat.connect(f.uuid), f.cat.connect(sub.uuid)]);
    await pumpEventQueue();
    expect(f.transport.targets, hasLength(1), reason: 'concurrent logical connects must share the pending TLS handshake');
    expect(f.transport.targets.single['password'], 'test-private-key');
    barrier.complete();
    await connecting;
    final secure = f.transport.secureConnections.single;
    expect(_commandsWithoutHeartbeat(secure).where((command) => command == 'RDY;'), hasLength(1));
    secure.receive(_cat('FA00014250000;FB00007045000;MD2;MD\$3;DV0;SB1;${_info()}'));
    await pumpEventQueue();
    expect(f.cat.stateFor(f.uuid).vfo, const VfoReading(freqKHz: 14250, mode: 'USB'), reason: 'IF must not replace the Main FA reading');
    expect(f.cat.stateFor(sub.uuid).vfo, const VfoReading(freqKHz: 7045, mode: 'CW'));
    expect(f.panel.read(sub.uuid)['frequencyHz'], 7045000);
    final mainFrames = <SpectrumFrame>[], subFrames = <SpectrumFrame>[];
    final mainDisplay = f.cat.spectrumFrames(f.uuid).listen(mainFrames.add);
    final subDisplay = f.cat.spectrumFrames(sub.uuid).listen(subFrames.add);
    addTearDown(mainDisplay.cancel);
    addTearDown(subDisplay.cancel);
    await pumpEventQueue();
    secure.receive([..._pan(centerHz: 14250000), ..._pan(receiver: 1, centerHz: 7045000)]);
    await pumpEventQueue();
    expect(mainFrames, hasLength(1));
    expect(subFrames, hasLength(1));
    expect(mainFrames.single.lowHz, greaterThan(14000000));
    expect(subFrames.single.highHz, lessThan(7100000));
    expect(f.cat.setSpectrum(f.uuid, const SpectrumRequest(refLevelDb: 2)), true);
    expect(f.cat.setSpectrum(sub.uuid, const SpectrumRequest(refLevelDb: 7)), true);
    expect(f.cat.stateFor(f.uuid).spectrum?.refLevelDb, 2);
    expect(f.cat.stateFor(sub.uuid).spectrum?.refLevelDb, 7);
    await f.cat.disconnect(f.uuid);
    expect(secure.closeCalls, 0);
    expect(f.cat.stateFor(sub.uuid).status, EquipmentStatus.connected);
    secure.receive(_cat('FB00007046000;'));
    await pumpEventQueue();
    expect(f.cat.stateFor(sub.uuid).vfo.freqKHz, 7046);
    await f.cat.disconnect(sub.uuid);
    expect(secure.closeCalls, 1);
  });

  test('shared CAT is recorded once while both receivers observe it', () async {
    final f = await _connectedRemote();
    final sub = await f.cat.addNode(typeKey: 'k4-remote-test', config: {'host': 'synthetic.invalid', 'remotePort': 9204, 'receiver': 'sub'});
    await f.cat.connect(sub.uuid);
    final log = _TrafficLog();
    f.cat.trafficLog = log;
    const reply = r'FA00014250000;FB00007045000;MD2;MD$3;DV0;SB1;';
    f.transport.secureConnections.single.receive(_cat(reply));
    await pumpEventQueue();
    expect(log.incoming, [reply]);
    expect(f.cat.stateFor(f.uuid).vfo.freqKHz, 14250);
    expect(f.cat.stateFor(sub.uuid).vfo.freqKHz, 7045);
  });

  for (final designatedMain in [true, false]) {
    test('both logical receivers reconnect after a physical drop (designated Main: $designatedMain)', () async {
      final f = await _connectedRemote();
      final sub = await f.cat.addNode(typeKey: 'k4-remote-test', config: {'host': 'synthetic.invalid', 'remotePort': 9204, 'receiver': 'sub'});
      await f.cat.connect(sub.uuid);
      await f.cat.setRadio1(LocalRadio(designatedMain ? f.uuid : sub.uuid));
      final old = f.transport.secureConnections.single;
      old.receive(_cat(r'FA00014250000;FB00007045000;MD2;MD$3;DV0;SB1;'));
      await pumpEventQueue();
      old.remoteEnd();
      await pumpEventQueue();
      expect(f.transport.secureConnections, hasLength(2), reason: 'both receivers must join one replacement physical connection');
      expect(old.closeCalls, 1);
      for (final id in [f.uuid, sub.uuid]) {
        expect(f.cat.stateFor(id).status, EquipmentStatus.connected, reason: 'the shared cooldown must not strand either sibling');
      }
      final replacement = f.transport.secureConnections.last;
      expect(_commandsWithoutHeartbeat(replacement).where((command) => command == 'RDY;'), hasLength(1));
      replacement.receive(_cat(r'FA00014251000;FB00007046000;MD2;MD$3;DV0;SB1;'));
      await pumpEventQueue();
      expect(f.cat.stateFor(f.uuid).vfo.freqKHz, 14251);
      expect(f.cat.stateFor(sub.uuid).vfo.freqKHz, 7046);
    });
  }

  test('logical sibling receivers preserve one CW queue and do not stop shared voice playback', () async {
    final f = await _connectedRemote();
    await f.settings.setExperimentEnabled('keyer', true);
    final sub = await f.cat.addNode(typeKey: 'k4-remote-test', config: {'host': 'synthetic.invalid', 'remotePort': 9204, 'receiver': 'sub'});
    await f.cat.connect(sub.uuid);
    await f.cat.setDesignated(kCategoryKey, f.uuid);
    final secure = f.transport.secureConnections.single;
    secure.receive(_cat(r'FA00014025000;FB00007045000;MD3;MD$3;DV0;SB1;KS020;'));
    await pumpEventQueue();
    expect(f.cat.canKeyCw, isTrue);
    secure.sent.clear();
    expect(f.cat.sendCw('CQ CQ CQ DE N0DEV N0DEV K'), isTrue);
    final first = f.cat.cwProgress.value!;
    final sent = _commandsWithoutHeartbeat(secure);
    expect(sent.where((command) => command.startsWith('KY ')), hasLength(1));
    expect(f.cat.sendCw('TU'), isTrue);
    final queued = f.cat.cwProgress.value!;
    expect(queued.id, first.id, reason: 'Sub observes the same queue; it must not be silenced as another transmitter');
    expect(queued.text, first.text);
    expect(queued.pending, ['TU']);
    expect(_commandsWithoutHeartbeat(secure), sent, reason: 'the second message queues without a stop or premature write');
    f.cat.stopCw();

    secure.receive(_cat(r'MD2;MD$2;'));
    await pumpEventQueue();
    expect(f.cat.canPlayVoice, isTrue);
    f.cat.playVoiceMemory(1, repeat: false);
    expect(f.cat.voiceActivity.value?.memory, 1);
    secure.sent.clear();
    f.cat.playVoiceMemory(2, repeat: false);
    expect(_commandsWithoutHeartbeat(secure), ['PB2;'], reason: 'a sibling voice report must not insert DA0 before the requested memory');
    expect(f.cat.voiceActivity.value?.memory, 2);
    f.cat.stopVoice();
  });

  test('disconnecting the CW initiator cancels queued chunks while its sibling stays connected', () async {
    final f = await _connectedRemote();
    await f.settings.setExperimentEnabled('keyer', true);
    final sub = await f.cat.addNode(typeKey: 'k4-remote-test', config: {'host': 'synthetic.invalid', 'remotePort': 9204, 'receiver': 'sub'});
    await f.cat.connect(sub.uuid);
    await f.cat.setDesignated(kCategoryKey, f.uuid);
    final secure = f.transport.secureConnections.single;
    secure.receive(_cat(r'FA00014025000;FB00007045000;MD3;MD$3;DV0;SB1;KS020;'));
    await pumpEventQueue();
    expect(f.cat.sendCw('CQ CQ CQ DE N0DEV N0DEV K'), isTrue);
    expect((f.cat.connectedSession(sub.uuid) as CwKeyerSession).cwSending, isTrue);
    secure.sent.clear();
    await f.cat.disconnect(f.uuid);
    expect(_commandsWithoutHeartbeat(secure), contains('KY @;'));
    expect((f.cat.connectedSession(sub.uuid) as CwKeyerSession).cwSending, isFalse, reason: 'a live sibling must not keep an abandoned keyer queue running');
    expect(f.cat.stateFor(sub.uuid).status, EquipmentStatus.connected);
    expect(secure.closeCalls, 0);
  });

  test('a peer stopping voice through Sub does not measure truncated Main playback', () async {
    final f = await _connectedRemote();
    await f.settings.setExperimentEnabled('keyer', true);
    await f.settings.setVoiceMessageDuration(1, 9000);
    final sub = await f.cat.addNode(typeKey: 'k4-remote-test', config: {'host': 'synthetic.invalid', 'remotePort': 9204, 'receiver': 'sub'});
    await f.cat.connect(sub.uuid);
    final secure = f.transport.secureConnections.single;
    secure.receive(_cat(r'FA00014250000;FB00007150000;MD2;MD$2;DV0;SB1;'));
    await pumpEventQueue();
    // Only playback lives on this clock; transport setup uses platform futures.
    runOnFakeClock((async) async {
      f.cat.playVoiceMemory(1, repeat: false);
      secure.receive(_cat('TQ1;'));
      await Future<void>.delayed(const Duration(seconds: 2));
      f.cat.handleKeyRequest(PeerKeyRequestPayload(radioId: sub.uuid, op: PeerKeyOp.stopVoice));
      await pumpEventQueue();
      expect(f.cat.voiceActivity.value, isNull);
      expect(f.settings.voiceMessageDuration(1), 9000, reason: 'a sibling STOP interrupts the same physical playback; it is not its natural end');
    });
    await f.cat.disconnect(f.uuid);
    await f.cat.disconnect(sub.uuid);
  });

  for (final subConnected in [false, true]) {
    test('shared connection edits update both receivers and reconnect only prior connections (Sub connected: $subConnected)', () async {
      final f = await _connectedRemote();
      final sub = await f.cat.addNode(typeKey: 'k4-remote-test', config: {'host': 'synthetic.invalid', 'remotePort': 9204, 'receiver': 'sub'});
      if (subConnected) await f.cat.connect(sub.uuid);
      final oldConnection = f.transport.secureConnections.single;
      await f.cat.updateNode(sub.copyWith(config: {...sub.config, 'host': 'changed.invalid', 'remotePort': 19204, 'password': 'replacement-private-key'}));
      expect(f.transport.targets, hasLength(2));
      expect(oldConnection.closeCalls, 1);
      expect(f.transport.targets.last, {'host': 'changed.invalid', 'port': 19204, 'password': 'replacement-private-key'});
      for (final id in [f.uuid, sub.uuid]) {
        final config = f.cat.nodeFor(id)!.config;
        expect(config['host'], 'changed.invalid');
        expect(config['remotePort'], 19204);
        expect(config.containsKey('password'), false);
      }
      expect(f.cat.nodeFor(f.uuid)!.config['receiver'], 'main');
      expect(f.cat.nodeFor(sub.uuid)!.config['receiver'], 'sub');
      expect(f.cat.stateFor(f.uuid).status, EquipmentStatus.connected);
      expect(f.cat.stateFor(sub.uuid).status, subConnected ? EquipmentStatus.connected : EquipmentStatus.disconnected);
      expect(f.cat.radio1, LocalRadio(f.uuid));
      expect(await f.settings.equipmentSecret(f.cat.logicalDeviceIdFor(sub.uuid)!, 'password'), 'replacement-private-key');
      for (final key in f.prefs.getKeys()) {
        expect(f.prefs.get(key).toString(), isNot(contains('replacement-private-key')));
      }
      await f.cat.disconnect(f.uuid);
      await f.cat.disconnect(sub.uuid);
    });
  }

  for (final passwordOnly in [false, true]) {
    test('returning from local CAT reconciles shared edits (password only: $passwordOnly)', () async {
      final f = await _connectedRemote();
      final sub = await f.cat.addNode(typeKey: 'k4-remote-test', config: {'host': 'synthetic.invalid', 'remotePort': 9204, 'receiver': 'sub'});
      await f.cat.connect(sub.uuid);
      final identity = f.cat.logicalDeviceIdFor(f.uuid);
      final originalConnection = f.transport.secureConnections.single;

      await f.cat.updateNode(f.cat.nodeFor(f.uuid)!.copyWith(typeKey: 'k4-local-test'));
      expect(f.cat.stateFor(f.uuid).status, EquipmentStatus.disconnected);
      expect(f.cat.stateFor(sub.uuid).status, EquipmentStatus.connected);
      expect(originalConnection.closeCalls, 0, reason: 'the sibling still owns the remote link');
      final host = passwordOnly ? 'synthetic.invalid' : 'returned.invalid';
      final port = passwordOnly ? 9204 : 19204;
      final local = f.cat.nodeFor(f.uuid)!;
      await f.cat.updateNode(local.copyWith(config: {...local.config, 'host': host, 'remotePort': port, 'password': 'returned-private-key'}));

      // The returning receiver has newer shared settings than its still-live
      // sibling. Joining the old socket would either reject or ignore them.
      await f.cat.updateNode(f.cat.nodeFor(f.uuid)!.copyWith(typeKey: 'k4-remote-test'));
      expect(originalConnection.closeCalls, 1);
      expect(f.transport.targets, hasLength(2));
      expect(f.transport.targets.last, {'host': host, 'port': port, 'password': 'returned-private-key'});
      for (final id in [f.uuid, sub.uuid]) {
        expect(f.cat.logicalDeviceIdFor(id), identity);
        expect(f.cat.nodeFor(id)!.config['host'], host);
        expect(f.cat.nodeFor(id)!.config['remotePort'], port);
        expect(f.cat.nodeFor(id)!.config.containsKey('password'), isFalse);
        expect(await f.cat.storedSecretFields(id), {'password'});
      }
      expect(f.cat.stateFor(f.uuid).status, EquipmentStatus.disconnected);
      expect(f.cat.stateFor(sub.uuid).status, EquipmentStatus.connected);
      await f.cat.connect(f.uuid);
      expect(f.cat.stateFor(f.uuid).status, EquipmentStatus.connected);
      expect(f.transport.targets, hasLength(2), reason: 'Main joins the updated shared link rather than opening a third connection');
      expect(f.cat.logicalChannelFor(f.uuid)?['key'], 'main');
      expect(f.cat.logicalChannelFor(sub.uuid)?['key'], 'sub');
      for (final key in f.prefs.getKeys()) {
        expect(f.prefs.get(key).toString(), isNot(contains('returned-private-key')));
      }
      await f.cat.disconnect(f.uuid);
      await f.cat.disconnect(sub.uuid);
    });
  }

  test('receiver-only edits preserve identity and refuse taking an occupied sibling', () async {
    final f = await _connectedRemote();
    final main = f.cat.nodeFor(f.uuid)!;
    await f.cat.updateNode(main.copyWith(config: {...main.config, 'receiver': 'sub'}));
    expect(f.cat.nodeFor(f.uuid)!.uuid, main.uuid);
    expect(f.cat.logicalDeviceIdFor(f.uuid), main.uuid);
    expect(f.cat.logicalChannelFor(f.uuid)?['key'], 'sub');
    expect(f.transport.targets, hasLength(2));
    final peer = await f.cat.addNode(typeKey: 'k4-remote-test', config: {'host': 'synthetic.invalid', 'remotePort': 9204, 'receiver': 'main'});
    await f.cat.connect(peer.uuid);
    expect(f.transport.targets, hasLength(2));
    final current = f.cat.nodeFor(f.uuid)!;
    await expectLater(f.cat.updateNode(current.copyWith(config: {...current.config, 'receiver': 'main'})), throwsArgumentError);
    expect(f.cat.logicalChannelFor(f.uuid)?['key'], 'sub');
    expect(f.cat.stateFor(peer.uuid).status, EquipmentStatus.connected);
    expect(f.transport.secureConnections.last.closeCalls, 0);
    await f.cat.disconnect(f.uuid);
    await f.cat.disconnect(peer.uuid);
  });

  test('different remote ports or passwords never silently join a physical connection group', () async {
    final f = await _connectedRemote(connect: false);
    final portPeer = await f.cat.addNode(
      typeKey: 'k4-remote-test',
      config: {'host': 'synthetic.invalid', 'remotePort': 9205, 'receiver': 'sub', 'password': 'test-private-key'},
    );
    final passwordPeer = await f.cat.addNode(
      typeKey: 'k4-remote-test',
      config: {'host': 'synthetic.invalid', 'remotePort': 9204, 'receiver': 'sub', 'password': 'different-private-key'},
    );
    final ids = [f.uuid, portPeer.uuid, passwordPeer.uuid];
    expect(ids.map(f.cat.logicalDeviceIdFor).toSet(), hasLength(3));
    await Future.wait(ids.map(f.cat.connect));
    expect(f.transport.targets, hasLength(3));
    expect(f.transport.targets.where((target) => target['port'] == 9205), hasLength(1));
    expect(f.transport.targets.where((target) => target['password'] == 'different-private-key'), hasLength(1));
    expect(await f.settings.equipmentSecret(f.uuid, 'password'), 'test-private-key');
    await Future.wait(ids.map(f.cat.disconnect));
  });

  test('logical IDs and shared credentials survive reload and removing Main until the last receiver is removed', () async {
    final f = await _connectedRemote(connect: false);
    final sub = await f.cat.addNode(typeKey: 'k4-remote-test', config: {'host': 'synthetic.invalid', 'remotePort': 9204, 'receiver': 'sub'});
    final restored = CatService(f.settings, registry: f.cat.registry, reconnectDelay: Duration.zero, idleRetryFirst: const Duration(minutes: 5));
    addTearDown(restored.dispose);
    expect(restored.nodes.map((node) => node.uuid), [f.uuid, sub.uuid]);
    expect(restored.radio1, LocalRadio(f.uuid));
    expect(restored.logicalDeviceIdFor(sub.uuid), f.uuid);
    expect(restored.logicalChannelFor(sub.uuid)?['key'], 'sub');
    await Future.wait([restored.connect(f.uuid), restored.connect(sub.uuid)]);
    expect(f.transport.targets, hasLength(1));
    final secure = f.transport.secureConnections.single;
    await restored.removeNode(f.uuid);
    expect(restored.radio1, isNull, reason: 'removing the logging receiver does not silently designate its sibling');
    expect(restored.nodeFor(sub.uuid), isNotNull);
    expect(restored.logicalDeviceIdFor(sub.uuid), f.uuid);
    expect(restored.stateFor(sub.uuid).status, EquipmentStatus.connected);
    expect(secure.closeCalls, 0);
    expect(await f.settings.equipmentSecret(f.uuid, 'password'), 'test-private-key');
    await restored.disconnect(sub.uuid);
    await restored.connect(sub.uuid);
    expect(f.transport.targets.last['password'], 'test-private-key', reason: 'Sub can reopen after the original Main node is gone');
    await restored.removeNode(sub.uuid);
    expect(await f.settings.equipmentSecret(f.uuid, 'password'), isNull);
    expect(restored.nodes, isEmpty);
    expect(f.transport.secureConnections.every((connection) => connection.closeCalls == 1), true);
  });
}

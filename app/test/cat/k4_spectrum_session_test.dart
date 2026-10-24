// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_spectrum.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_spectrum_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/panel_radio_service.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Sink implements EquipmentSink, SpectrumSink {
  final sent = <String>[];
  final readings = <VfoReading>[];
  final frames = <SpectrumFrame>[];
  final settings = <SpectrumSettings>[];
  final problems = <String?>[];
  final spectrumProblems = <String?>[];

  @override
  void send(List<int> bytes) => sent.add(ascii.decode(bytes));
  @override
  void report(VfoReading reading) => readings.add(reading);
  @override
  void reportSpectrum(SpectrumFrame frame) => frames.add(frame);
  @override
  void reportSpectrumSettings(SpectrumSettings value) => settings.add(value);
  @override
  void reportSpectrumProblem(String? message) => spectrumProblems.add(message);
  @override
  void reportProblem(String? message) => problems.add(message);
  @override
  void reportPower(num watts) {}
  @override
  void reportTransmitting(bool value) {}
  @override
  void reportKeyerSpeed(int wpm) {}
  @override
  void reportVoiceActivity(VoiceActivity? activity) {}
  @override
  void reportVoiceMemories(List<VoiceMemory> memories) {}
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportDiagnostic(String? note) {}
  @override
  void reportChannels(List<EquipmentChannel> channels) {}
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
  @override
  void reportMeter(RadioMeter meter, num value) {}
  @override
  void reportAlive() {}
}

class _Connection implements EquipmentConnection {
  final _data = StreamController<Uint8List>.broadcast(sync: true);
  final _closed = Completer<void>();
  final sent = <List<int>>[];
  bool get isClosed => _closed.isCompleted;

  @override
  Stream<Uint8List> get data => _data.stream;
  @override
  Future<void> get closed => _closed.future;
  @override
  void send(List<int> bytes) => sent.add(List.of(bytes));

  void receive(Uint8List bytes) => _data.add(bytes);

  @override
  Future<void> close() async {
    if (isClosed) return;
    _closed.complete();
    await _data.close();
  }
}

class _Attempt {
  final Map<String, dynamic> target;
  final CatCancelToken cancel;
  final ready = Completer<EquipmentConnection>();
  _Connection? connection;

  _Attempt(this.target, this.cancel);

  _Connection succeed() {
    final result = connection = _Connection();
    ready.complete(result);
    return result;
  }
}

class _Transport extends EquipmentTransport {
  @override
  final String key;
  final bool completeImmediately;
  final attempts = <_Attempt>[];

  _Transport({this.key = 'spectrum-test', this.completeImmediately = true});

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) {
    final attempt = _Attempt(Map.of(target), cancel);
    attempts.add(attempt);
    if (completeImmediately) attempt.succeed();
    return attempt.ready.future;
  }
}

Uint8List _capturedPans() => File('test/cat/fixtures/k4-spectrum/k4-lan-9201-ayb.bin').readAsBytesSync();

// Keep the captured main-pan payload, but vary the rate for notification tests.
// The 96001 Hz case is synthetic: it changes neither rounded edges nor options.
Uint8List _mainPanAtRate(int rate) {
  final bytes = Uint8List.fromList(_capturedPans().sublist(0, k4SpectrumPacketLength));
  bytes.setRange(7, 13, rate.toString().padLeft(6, '0').codeUnits);
  bytes[63] = (-bytes.take(63).fold<int>(0, (sum, byte) => sum + byte)) & 0xff;
  final payloadEnd = k4SpectrumPacketLength - 2;
  ByteData.sublistView(bytes).setUint16(payloadEnd, k4SpectrumCrc16(Uint8List.sublistView(bytes, 0, payloadEnd)), Endian.big);
  return bytes;
}

// K31 IF layout: main VFO 14.074 MHz, USB, receiving.
final _info = Uint8List.fromList(ascii.encode('IF00014074000     +000000 0002000001 ;'));

class _Driver extends EquipmentDriver {
  final _Transport spectrumTransport;

  _Driver(this.spectrumTransport);

  @override
  String get key => 'k4-spectrum-test';
  @override
  String get name => 'K4 spectrum test';

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => K4SpectrumSession(
    sink,
    spectrum: K4Spectrum(host: '192.0.2.4', sink: sink as SpectrumSink, transport: spectrumTransport),
  );
}

Future<({CatService cat, String uuid, _Transport spectrumTransport, _Transport catTransport})> _connectedK4() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final radio = RadioService(prefs, writeDelay: Duration.zero);
  addTearDown(radio.dispose);
  final spectrumTransport = _Transport();
  final catTransport = _Transport(key: 'cat-test');
  final cat = CatService(
    SettingsService(prefs),
    radio: radio,
    registry: EquipmentRegistry(
      models: [
        EquipmentModel(
          key: 'k4-spectrum-test',
          category: kCategoryTransceiver,
          name: () => 'K4 spectrum test',
          variants: [EquipmentVariant(key: 'k4-spectrum-test-tcp', driver: _Driver(spectrumTransport), transport: catTransport)],
        ),
      ],
      transports: {'cat-test': catTransport},
    ),
    reconnectDelay: Duration.zero,
    idleRetryFirst: const Duration(minutes: 5),
  );
  addTearDown(cat.dispose);
  final uuid = (await cat.addNode(typeKey: 'k4-spectrum-test-tcp', config: const {})).uuid;
  await cat.connect(uuid);
  return (cat: cat, uuid: uuid, spectrumTransport: spectrumTransport, catTransport: catTransport);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only the K4 LAN variant offers spectrum, even when serial retains a host', () {
    final registry = EquipmentRegistry();
    const retainedConfig = {'host': '192.0.2.4', 'tcpPort': 9200, 'port': '/dev/retained-k4', 'voiceDialect': 'k4'};
    for (final key in ['k4-tcp', 'k4-serial', 'k4-ble', 'kenwood-serial', 'kx3-serial']) {
      final type = registry.typeFor(key)!;
      final session = type.driver.createSession(_Sink(), type.driverConfig({...type.defaultConfig, ...retainedConfig}));
      addTearDown(session.teardown);
      if (key == 'k4-tcp') {
        expect(session, isA<SpectrumSession>());
        final scope = session as SpectrumSession;
        expect(scope.spectrumUnavailable, isNull);
        expect(scope.spectrumCapabilities.spansHz, isNotEmpty);
        expect(scope.setSpectrum(const SpectrumRequest(spanHz: 20000)), isFalse, reason: 'a scope without listeners must not queue settings');
      } else {
        expect(session, isNot(isA<SpectrumSession>()), reason: key);
      }
    }
  });

  test('connected serial radios report no spectrum in the panel snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final radio = RadioService(prefs, writeDelay: Duration.zero);
    addTearDown(radio.dispose);
    final registry = EquipmentRegistry();
    final transport = _Transport(key: registry.typeFor('k4-serial')!.transportKey);
    final cat = CatService(
      SettingsService(prefs),
      radio: radio,
      registry: EquipmentRegistry(transports: {transport.key: transport}),
    );
    addTearDown(cat.dispose);
    final panel = PanelRadioService(cat, radio);
    for (final key in ['k4-serial', 'kenwood-serial', 'kx3-serial']) {
      final type = registry.typeFor(key)!;
      final node = await cat.addNode(typeKey: key, config: {...type.defaultConfig, 'port': '/dev/retained-k4', 'host': '192.0.2.4', 'tcpPort': 9200});
      await cat.connect(node.uuid);
      transport.attempts.last.connection!.receive(_info);
      final snapshot = panel.read(node.uuid);
      expect(snapshot['status'], EquipmentStatus.connected.name, reason: key);
      expect(snapshot['frequencyHz'], 14074000, reason: 'a live CAT reading must not imply a spectrum capability');
      expect(cat.spectrumSessionFor(node.uuid), isNull, reason: key);
      expect(snapshot['spectrum'], isNull, reason: 'a radio without a scope must not expose unsupported scope controls');
      expect(cat.setSpectrum(node.uuid, const SpectrumRequest(spanHz: 20000)), isFalse);
      await cat.disconnect(node.uuid);
    }
  });

  test('K4 session delegates spectrum while CAT stays on its original byte path', () async {
    final sink = _Sink();
    final transport = _Transport();
    final session = K4SpectrumSession(
      sink,
      spectrum: K4Spectrum(host: '192.0.2.4', sink: sink, transport: transport),
    );
    addTearDown(session.teardown);
    expect(transport.attempts, isEmpty);

    session.startSpectrum();
    session.startSpectrum();
    await pumpEventQueue();
    expect(transport.attempts, hasLength(1));
    expect(transport.attempts.single.target, {'host': '192.0.2.4', 'port': 9201});
    final connection = transport.attempts.single.connection!;
    connection.receive(_capturedPans());
    await pumpEventQueue();
    expect(sink.frames, hasLength(1), reason: 'the captured sub and mini pans must not replace main A');
    expect(session.setSpectrum(const SpectrumRequest(refLevelDb: 3)), isTrue);
    expect(sink.settings.last.refLevelDb, 3);
    expect(sink.sent, isEmpty, reason: 'opening and adjusting the local scope must not write CAT settings');
    expect(connection.sent, isEmpty, reason: '9201 receives data without subscriptions, CAT, or keepalives');

    session.startUpdates();
    expect(sink.sent.join(), contains('K40;K31;'));
    session.handleData(_info);
    expect(sink.readings.last, const VfoReading(freqKHz: 14074, mode: 'USB'));
    session.setFrequency(14250);
    expect(sink.sent, contains('FA00014250000;'));
    expect(connection.sent, isEmpty, reason: 'tuning belongs to CAT, never the spectrum socket');

    session.teardown();
    await pumpEventQueue();
    expect(connection.isClosed, isTrue);
  });

  test('stopping CAT updates leaves the scope to CatService', () async {
    final sink = _Sink();
    final transport = _Transport(completeImmediately: false);
    final session = K4SpectrumSession(
      sink,
      spectrum: K4Spectrum(host: '192.0.2.4', sink: sink, transport: transport),
    );
    addTearDown(session.teardown);
    session.startSpectrum();
    await pumpEventQueue();
    session.stopUpdates();
    expect(
      transport.attempts.single.cancel.isCancelled,
      isFalse,
      reason: 'CatService still counts the scope as started, so a stop made here is never undone and an open display stays blank',
    );
  });

  test('a disconnect cancels a pending spectrum connect and closes its late result', () async {
    final sink = _Sink();
    final transport = _Transport(completeImmediately: false);
    final session = K4SpectrumSession(
      sink,
      spectrum: K4Spectrum(host: '192.0.2.4', sink: sink, transport: transport),
    );
    session.startSpectrum();
    await pumpEventQueue();
    final attempt = transport.attempts.single;
    session.teardown();
    expect(attempt.cancel.isCancelled, isTrue, reason: 'disconnect must cancel even before CAT updates have started');
    final late = attempt.succeed();
    await pumpEventQueue();
    expect(late.isClosed, isTrue, reason: 'a superseded connect must not leak a socket or revive the display');
    expect(sink.frames, isEmpty);
    expect(sink.spectrumProblems.whereType<String>(), isEmpty, reason: 'intentional cancellation is not a radio failure');
  });

  test('a spectrum failure does not stop CAT readings or tuning', () async {
    final sink = _Sink();
    final transport = _Transport(completeImmediately: false);
    final session = K4SpectrumSession(
      sink,
      spectrum: K4Spectrum(host: '192.0.2.4', sink: sink, transport: transport),
    );
    addTearDown(session.teardown);
    session.startSpectrum();
    await pumpEventQueue();
    transport.attempts.single.ready.completeError(const SocketException('Spectrum port unavailable'));
    await pumpEventQueue();
    expect(sink.spectrumProblems.whereType<String>(), isNotEmpty);
    expect(sink.problems.whereType<String>(), isEmpty, reason: 'scope failure must not become a whole-radio problem');
    session.handleData(_info);
    expect(sink.readings.last.freqKHz, 14074);
    session.setFrequency(14250);
    expect(sink.sent, contains('FA00014250000;'));
  });

  test('CAT polling and spectrum demand have separate lifetimes', () async {
    final sink = _Sink();
    final transport = _Transport();
    final session = K4SpectrumSession(
      sink,
      spectrum: K4Spectrum(host: '192.0.2.4', sink: sink, transport: transport),
    );
    addTearDown(session.teardown);
    session.startSpectrum();
    await pumpEventQueue();
    final connection = transport.attempts.single.connection!;
    connection.receive(_capturedPans());
    expect(sink.frames, hasLength(1));
    session.stopUpdates();
    await pumpEventQueue();
    expect(connection.isClosed, isFalse, reason: 'the mounted display still owns spectrum demand');
    session.stopSpectrum();
    await pumpEventQueue();
    expect(connection.isClosed, isTrue);
  });

  test('CatService opens the K4 stream for the first listener and releases it after the last', () async {
    final (:cat, :uuid, :spectrumTransport, :catTransport) = await _connectedK4();
    expect(spectrumTransport.attempts, isEmpty, reason: 'CAT connects before any spectrum pane exists');

    final frames = <SpectrumFrame>[];
    final first = cat.spectrumFrames(uuid).listen(frames.add);
    final second = cat.spectrumFrames(uuid).listen((_) {});
    addTearDown(first.cancel);
    addTearDown(second.cancel);
    await pumpEventQueue();
    expect(spectrumTransport.attempts, hasLength(1));
    final connection = spectrumTransport.attempts.single.connection!;
    connection.receive(_capturedPans());
    await pumpEventQueue();
    expect(frames, hasLength(1));
    expect(cat.stateFor(uuid).spectrum, isNotNull);
    expect(connection.sent, isEmpty);

    await first.cancel();
    await pumpEventQueue();
    expect(connection.isClosed, isFalse, reason: 'another pane still needs the same stream');
    await second.cancel();
    await pumpEventQueue();
    expect(connection.isClosed, isTrue);
    expect(cat.stateFor(uuid).spectrum, isNull);
    expect(cat.stateFor(uuid).status, EquipmentStatus.connected);
    expect(catTransport.attempts.single.connection!.isClosed, isFalse, reason: 'closing the last scope must leave CAT connected');
    expect(cat.setSpectrum(uuid, const SpectrumRequest(spanHz: 20000)), isFalse);
    await cat.disconnect(uuid);
  });

  test('CatService refreshes changed K4 span options even when the rounded crop is unchanged', () async {
    final (:cat, :uuid, :spectrumTransport, catTransport: _) = await _connectedK4();
    final subscription = cat.spectrumFrames(uuid).listen((_) {});
    addTearDown(subscription.cancel);
    await pumpEventQueue();
    final connection = spectrumTransport.attempts.single.connection!;
    connection.receive(_mainPanAtRate(96000));
    await pumpEventQueue();
    final settings = cat.stateFor(uuid).spectrum!;
    final session = cat.spectrumSessionFor(uuid)!;
    expect(session.spectrumCapabilities.spansHz.last, 48000);

    var changes = 0;
    void onChange() => changes++;
    cat.addListener(onChange);
    addTearDown(() => cat.removeListener(onChange));

    connection.receive(_mainPanAtRate(96001));
    await pumpEventQueue();
    expect(cat.stateFor(uuid).spectrum, settings);
    expect(session.spectrumCapabilities.spansHz.last, 48000);
    expect(changes, 0, reason: 'equivalent settings and newly allocated capabilities still dedupe by value');

    connection.receive(_mainPanAtRate(48000));
    await pumpEventQueue();
    expect(cat.stateFor(uuid).spectrum, settings, reason: 'both rates retain bins with the same rounded crop endpoints');
    expect(session.spectrumCapabilities.spansHz.last, 24000);
    expect(changes, 1, reason: 'controls must refresh the available zooms even when the selected window stays unchanged');
  });
}

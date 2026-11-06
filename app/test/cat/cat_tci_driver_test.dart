// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The TCI session (Thetis or ExpertSDR3), with no server. Built from the TCI
// 2.1 spec alone; what these pin is that reading, so a change that drifts
// from the document fails here rather than on the air.
//
// The traps: a server serves several receivers and channels, and another's
// frequency reported as this one's would retune the log; the two servers
// spell modes differently, and a set in the wrong spelling is ignored
// without a reply; drive is a percentage, so watts sent raw would put a
// 200 W radio at half the power asked for; and a push server that nothing
// changes on is silent, which the app takes for a dead radio unless the
// session asks it something.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart' show catStaleAfter;
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/rated_power_config.dart';
import 'package:ham2k_logger/services/cat/drivers/tci_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/tci_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/cat/transports/websocket_transport.dart';

class _FakeSink implements EquipmentSink, SpectrumSink, BinaryFramesSink, TuneCarrierSink {
  final sent = <String>[];
  final readings = <VfoReading>[];
  final power = <num>[];
  final txReports = <bool>[];
  final tuneReports = <bool>[];
  final meters = <(RadioMeter, num)>[];
  final keyerSpeeds = <int>[];
  final diagnostics = <String?>[];
  final frames = <SpectrumFrame>[];
  final spectrumProblems = <String?>[];
  final iq = StreamController<Uint8List>.broadcast(sync: true);

  @override
  Stream<Uint8List>? get binaryFrames => iq.stream;

  @override
  void send(List<int> bytes) => sent.add(utf8.decode(bytes));
  @override
  void report(VfoReading reading) => readings.add(reading);
  @override
  void reportPower(num watts) => power.add(watts);
  @override
  void reportTransmitting(bool transmitting) => txReports.add(transmitting);
  @override
  void reportTuneCarrier(bool on) => tuneReports.add(on);
  @override
  void reportMeter(RadioMeter meter, num value) => meters.add((meter, value));
  @override
  void reportKeyerSpeed(int wpm) => keyerSpeeds.add(wpm);
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportVoiceActivity(VoiceActivity? activity) {}
  @override
  void reportVoiceMemories(List<VoiceMemory> memories) {}
  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);
  @override
  void reportProblem(String? message) {}
  @override
  void reportChannels(List<EquipmentChannel> channels) {}
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
  @override
  void reportAlive() {}
  @override
  void reportSpectrum(SpectrumFrame frame) => frames.add(frame);
  @override
  void reportSpectrumSettings(SpectrumSettings settings) {}
  @override
  void reportSpectrumProblem(String? message) => spectrumProblems.add(message);
}

extension on TciSession {
  void feed(String text) => handleData(Uint8List.fromList(utf8.encode(text)));
}

/// A binary frame as the spec's `struct Stream` lays it out: a 64-byte
/// little-endian header, then [samples] as float32.
Uint8List _iqFrame(Float32List samples, {int rate = 48000, int receiver = 0, int type = tciIqStreamType}) {
  final header = ByteData(tciStreamHeaderBytes);
  for (final (index, value) in [(0, receiver), (1, rate), (2, TciSampleType.float32.index), (5, samples.length), (6, type), (7, 2)]) {
    header.setUint32(index * 4, value, Endian.little);
  }
  return Uint8List.fromList([...header.buffer.asUint8List(), ...samples.buffer.asUint8List()]);
}

/// [count] complex samples of a tone [offsetHz] above the centre.
Float32List _tone(int count, {required int offsetHz, int rate = 48000}) => Float32List.fromList([
  for (var n = 0; n < count; n++) ...[math.cos(2 * math.pi * offsetHz * n / rate), math.sin(2 * math.pi * offsetHz * n / rate)],
]);

void main() {
  late _FakeSink sink;
  late TciSession session;

  setUp(() {
    sink = _FakeSink();
    session = TciSession(sink);
  });

  tearDown(() => session.teardown());

  group('reading', () {
    test('a VFO answer is a frequency, even split across frames and in any case', () {
      session.feed('vfo:0,0,1407');
      session.feed('4150;MODULATION:0,USB;');
      expect(sink.readings, [const VfoReading(freqKHz: 14074.15), const VfoReading(mode: 'USB')]);
    });

    test('a command too long to hold is dropped whole, not read clipped', () {
      // Clipped, this list would lose its LSB and setMode('LSB') would find
      // no spelling to send. Dropped, the server's list is simply unknown.
      session.feed('modulations_list:usb,${'x' * 5000}');
      session.feed(',lsb;vfo:0,0,14074000;');
      expect(sink.readings, [const VfoReading(freqKHz: 14074)], reason: 'the next command still reads');
      sink.sent.clear();
      session.setMode('LSB');
      expect(sink.sent, ['MODULATION:0,LSB;']);
    });

    test("another receiver's, or VFO B's, frequency is not this node's", () {
      session.feed('vfo:1,0,7074000;vfo:0,1,7010000;modulation:1,cw;');
      expect(sink.readings, isEmpty);
    });

    test("both servers' spellings read as the app names them", () {
      // ExpertSDR3's NFM and CW; Thetis's CWU and CWL; both servers' DIGU/DIGL.
      session.feed('modulation:0,nfm;modulation:0,cw;modulation:0,cwu;modulation:0,cwl;modulation:0,digu;modulation:0,digl;');
      expect(sink.readings.map((r) => r.mode), ['FM', 'CW', 'CW', 'CW-R', 'DATA-USB', 'DATA-LSB']);
    });

    test('a mode the app has no name for is not reported as another one', () {
      session.feed('modulation:0,dsb;modulation:0,wfm;modulation:0,drm;');
      expect(sink.readings, isEmpty);
      session.feed('modulation:0,sam;');
      expect(sink.readings.single.mode, 'AM', reason: 'SAM is AM in a log');
    });

    test('READY says what answered, once a connection', () {
      session.startUpdates();
      session.feed('protocol:Thetis,1.9;device:ANAN-7000DLE;ready;ready;');
      expect(sink.diagnostics, ['TCI Thetis 1.9 · ANAN-7000DLE']);
    });
  });

  group('modes are set in the server\'s own spelling', () {
    test('ExpertSDR3 has NFM and one CW', () {
      session.feed('modulations_list:AM,SAM,DSB,LSB,USB,CW,NFM,DIGL,DIGU,WFM,DRM;');
      session.setMode('FM');
      session.setMode('CW');
      session.setMode('CW-R');
      expect(sink.sent, ['MODULATION:0,NFM;', 'MODULATION:0,CW;'], reason: 'no reverse CW to set');
    });

    test('Thetis has CWU and CWL', () {
      session.feed('modulations_list:LSB,USB,DSB,CWL,CWU,FM,AM,DIGU,SPEC,DIGL,SAM,DRM;');
      session.setMode('CW');
      session.setMode('CW-R');
      session.setMode('FM');
      expect(sink.sent, ['MODULATION:0,CWU;', 'MODULATION:0,CWL;', 'MODULATION:0,FM;']);
    });

    test('settable modes are ones every server has a spelling for', () {
      for (final offered in [
        ['AM', 'SAM', 'DSB', 'LSB', 'USB', 'CW', 'NFM', 'DIGL', 'DIGU', 'WFM', 'DRM'],
        ['LSB', 'USB', 'DSB', 'CWL', 'CWU', 'FM', 'AM', 'DIGU', 'SPEC', 'DIGL', 'SAM', 'DRM'],
      ]) {
        for (final mode in const TciDriver().settableModes(const {})) {
          expect(buildTciSetModulationCommand(mode, offered: offered), isNotNull, reason: '$mode in $offered');
        }
      }
    });
  });

  group('power is a share of the rated output', () {
    test('drive reads back as watts of the configured rating, and a set sends the share', () {
      session = TciSession(sink, config: {ratedWattsConfigKey: 200});
      session.feed('drive:0,50;');
      expect(sink.power, [100]);
      session.setPower(50);
      expect(sink.sent, ['DRIVE:0,25;', 'DRIVE:0;'], reason: 'DRIVE:0,50 would put a 200 W radio at 100 W');
    });
  });

  group('transmit state', () {
    test('TRX and TUNE are both on the air, and a tune is said as one', () {
      session.feed('trx:0,true;');
      session.feed('trx:0,false;');
      session.feed('tune:0,true;');
      session.feed('trx:0,false;'); // still tuning: nothing may switch under it
      session.feed('tune:0,false;');
      expect(sink.txReports, [true, false, true, false]);
      expect(sink.tuneReports, [true, false]);
    });

    test("another transceiver's TRX is not this one's", () {
      session.feed('trx:1,true;');
      expect(sink.txReports, isEmpty);
    });

    test('power and SWR are read only on the air', () {
      session.feed('tx_sensors:0,-30,0.0,0.0,0.0;');
      session.feed('trx:0,true;');
      session.feed('tx_sensors:0,-27.2,47.4,67.5,1.7;');
      expect(sink.meters, [(RadioMeter.powerOut, 47.4), (RadioMeter.swr, 1.7)]);
    });

    test('the signal level is a meter in dBm', () {
      session.feed('rx_sensors:0,-71.5;rx_sensors:1,-112.7;');
      expect(sink.meters, [(RadioMeter.signalDbm, -71.5)]);
    });

    test('a teardown while keyed unkeys first', () {
      session.setPtt(true);
      expect(sink.sent, ['TRX:0,true;']);
      session.teardown();
      expect(sink.sent[1], 'TRX:0,false;');
    });
  });

  group('CW through macros', () {
    test('a comma goes as the spec\'s ~, and a stop is CW_MACROS_STOP', () {
      session.sendCw('5nn, tu');
      expect(sink.sent.single, 'CW_MACROS:0,5NN~ TU;', reason: 'a raw comma would split the command');
      session.stopCw();
      expect(sink.sent.last, 'CW_MACROS_STOP;');
    });

    test('the macro speed is set, clamped, read back and reported', () {
      session.setKeyerSpeed(80);
      expect(sink.sent, ['CW_MACROS_SPEED:60;', 'CW_MACROS_SPEED;']);
      session.feed('cw_macros_speed:28;');
      expect(sink.keyerSpeeds, [28]);
    });
  });

  group('staying alive', () {
    test('connecting asks for the state and turns the meters on', () {
      session.startUpdates();
      expect(sink.sent, [
        'VFO:0,0;',
        'MODULATION:0;',
        'DRIVE:0;',
        'TRX:0;',
        'TUNE:0;',
        'CW_MACROS_SPEED;',
        'DDS:0;',
        'RX_SENSORS_ENABLE:true,250;',
        'TX_SENSORS_ENABLE:true,250;',
      ]);
    });

    test('a server nothing changes on is asked something inside the silence window', () {
      fakeAsync((async) {
        session.startUpdates();
        sink.sent.clear();
        async.elapse(catStaleAfter ~/ 2);
        expect(sink.sent, contains('VFO:0,0;'));
        session.teardown();
        sink.sent.clear();
        async.elapse(catStaleAfter);
        expect(sink.sent, isEmpty, reason: 'nothing after teardown');
      });
    });
  });

  group('band scope from IQ', () {
    test('starting asks for the rate and the stream; a tone lands at its frequency', () {
      session.feed('dds:0,14074000;');
      session.startSpectrum();
      expect(sink.sent, ['IQ_SAMPLERATE:48000;', 'IQ_START:0;']);
      sink.iq.add(_iqFrame(_tone(4096, offsetHz: 6000)));
      final frame = sink.frames.single;
      expect(frame.lowHz, lessThan(14074000));
      expect(frame.highHz, greaterThan(14074000));
      var peak = 0;
      for (var i = 1; i < frame.levels.length; i++) {
        if (frame.levels[i] > frame.levels[peak]) peak = i;
      }
      final peakHz = frame.lowHz + (peak + 0.5) * (frame.highHz - frame.lowHz) / frame.levels.length;
      expect(peakHz, closeTo(14080000, 100), reason: 'a sweep mirrored or off-centre puts every signal at the wrong frequency');
    });

    test("another receiver's IQ, or an audio stream, is not drawn", () {
      session.feed('dds:0,14074000;');
      session.startSpectrum();
      sink.iq.add(_iqFrame(_tone(4096, offsetHz: 6000), receiver: 1));
      sink.iq.add(_iqFrame(_tone(4096, offsetHz: 6000), type: 1));
      expect(sink.frames, isEmpty);
    });

    test('a wider span asks for a faster rate, and stopping stops the stream', () {
      session.startSpectrum();
      session.setSpectrum(const SpectrumRequest(spanHz: 80000));
      expect(sink.sent.last, 'IQ_SAMPLERATE:192000;');
      session.stopSpectrum();
      expect(sink.sent.last, 'IQ_STOP:0;');
      session.feed('dds:0,14074000;');
      sink.iq.add(_iqFrame(_tone(4096, offsetHz: 6000)));
      expect(sink.frames, isEmpty, reason: 'nothing drawn for a display that is gone');
    });

    test('a server that sends no IQ is said to, rather than waited on', () {
      fakeAsync((async) {
        session.startSpectrum();
        async.elapse(const Duration(seconds: 6));
        expect(sink.spectrumProblems.last, t.settings.station.spectrumTciNoIq);
        session.teardown();
      });
    });
  });

  test('integer samples are read at full scale ±1', () {
    final frame = ByteData(tciStreamHeaderBytes + 6 + 6);
    for (final (index, value) in [(2, TciSampleType.int16.index), (5, 2)]) {
      frame.setUint32(index * 4, value, Endian.little);
    }
    frame.setInt16(64, -32768, Endian.little);
    frame.setInt16(66, 16384, Endian.little);
    final bytes = frame.buffer.asUint8List();
    expect(tciSamples(bytes, parseTciStreamHeader(bytes)!), [-1.0, 0.5]);

    final wide = ByteData(tciStreamHeaderBytes + 6);
    for (final (index, value) in [(2, TciSampleType.int24.index), (5, 2)]) {
      wide.setUint32(index * 4, value, Endian.little);
    }
    // -8388608 and 4194304 as little-endian 24-bit.
    wide.buffer.asUint8List().setAll(64, [0x00, 0x00, 0x80, 0x00, 0x00, 0x40]);
    final wideBytes = wide.buffer.asUint8List();
    expect(tciSamples(wideBytes, parseTciStreamHeader(wideBytes)!), [-1.0, 0.5]);
  });

  test('the ANAN offers TCI first, and the SunSDR only TCI, both on 50001', () {
    final registry = EquipmentRegistry();
    final anan = registry.typeFor('anan-thetis-tci')!;
    expect(anan.driver, isA<TciDriver>());
    expect(anan.transportKey, WebSocketTransport.transportKey);
    expect(anan.defaultConfig[tciPortConfigKey], 50001, reason: "the ANAN's CAT variant prefills `port` with 13013");
    expect(registry.typeFor('sunsdr-tci')!.defaultConfig['port'], 50001);
    expect(registry.models.firstWhere((m) => m.key == 'anan-thetis').variants.first.key, 'anan-thetis-tci');
  });

  group('WebSocket transport', () {
    late HttpServer server;
    late WebSocket peer;
    late Completer<WebSocket> accepted;

    setUp(() async {
      accepted = Completer();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.transform(WebSocketTransformer()).listen(accepted.complete);
    });

    tearDown(() => server.close(force: true));

    test('text frames come up as data, binary ones apart, and a send is text', () async {
      final connection = await const WebSocketTransport().connect({'host': '127.0.0.1', 'port': server.port}, cancel: CatCancelToken());
      peer = await accepted.future;
      final text = connection.data.first;
      final binary = (connection as BinaryFramesConnection).binaryFrames.first;
      peer.add('vfo:0,0,14074000;');
      peer.add(Uint8List.fromList([1, 2, 3]));
      expect(utf8.decode(await text), 'vfo:0,0,14074000;');
      expect(await binary, [1, 2, 3], reason: 'IQ on the data stream would reach the command parser and the traffic log');

      final received = peer.first;
      connection.send(utf8.encode('VFO:0,0;'));
      expect(await received, isA<String>().having((s) => s, 'text', 'VFO:0,0;'));

      await connection.close();
      await connection.closed;
    });

    test('an attempt cancelled first never connects', () async {
      final cancel = CatCancelToken()..cancel();
      await expectLater(const WebSocketTransport().connect({'host': '127.0.0.1', 'port': server.port}, cancel: cancel), throwsA(isA<CatCancelledException>()));
    });

    test('an upgrade nobody answers times out and lets go of its socket', () async {
      // A TCP listener that never answers HTTP — Thetis's CAT port typed into
      // the TCI field. Without the forced close each retry leaves it a socket.
      final silent = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(silent.close);
      final released = Completer<void>();
      silent.listen((socket) => socket.listen((_) {}, onDone: released.complete, onError: (_) => released.complete()));

      const transport = WebSocketTransport(connectTimeout: Duration(milliseconds: 200));
      await expectLater(transport.connect({'host': '127.0.0.1', 'port': silent.port}, cancel: CatCancelToken()), throwsA(isA<TimeoutException>()));
      await released.future.timeout(const Duration(seconds: 2));
    });
  });
}

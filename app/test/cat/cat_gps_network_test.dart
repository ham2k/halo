// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A GPS receiver reached over the network (docs/design/cat.md § Over the
// network, and gpsd): datagrams pushed to a port here, the sentence
// splitting that a sender with no line endings needs, and gpsd.
//
// Imports the io implementation directly: the conditional export resolves
// to the web stub under the analyzer.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/gpsd_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/nmea_gps_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/cat/transports/udp_listen_transport_io.dart';

const _ggaNoFix = r'$GNGGA,,,,,,0,00,99.99,,,,,,*56';
const _ggaFix = r'$GNGGA,183014.00,4124.89630,N,07402.12340,W,1,07,1.20,152.3,M,-34.2,M,,*74';

class _FakeSink implements EquipmentSink, GpsSink {
  final readings = <GpsReading>[];
  final sent = <String>[];
  final problems = <String?>[];
  var alive = 0;

  @override
  void reportGps(GpsReading reading) => readings.add(reading);
  @override
  void reportAlive() => alive++;
  @override
  void send(List<int> bytes) => sent.add(utf8.decode(bytes));
  @override
  void reportProblem(String? message) => problems.add(message);
  @override
  void report(VfoReading reading) => fail('a GPS receiver has no VFO');
  @override
  void reportPower(num watts) => fail('a GPS receiver has no power');
  @override
  void reportTransmitting(bool transmitting) => fail('a GPS receiver does not transmit');
  @override
  void reportMeter(RadioMeter meter, num value) => fail('a GPS receiver has no meters');
  @override
  void reportKeyerSpeed(int wpm) => fail('a GPS receiver has no keyer');
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportVoiceActivity(VoiceActivity? activity) {}
  @override
  void reportVoiceMemories(List<VoiceMemory> memories) {}
  @override
  void reportDiagnostic(String? note) {}
  @override
  void reportChannels(List<EquipmentChannel> channels) => fail('a GPS receiver has no channels');
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) => fail('a GPS receiver routes nothing');
}

Uint8List _bytes(String text) => Uint8List.fromList(ascii.encode(text));

void main() {
  group('sentences without line endings', () {
    test('each datagram\'s sentence is read, the next \$ ending the one before', () {
      // A phone app pushing one sentence per datagram, no CRLF: framed by
      // line endings alone, the two would be one line failing its checksum,
      // and the receiver would never be heard at all.
      final sink = _FakeSink();
      final session = NmeaGpsSession(sink);
      session.handleData(_bytes(_ggaNoFix));
      expect(sink.readings, isEmpty, reason: 'nothing yet says the sentence has ended');
      session.handleData(_bytes(_ggaFix));
      expect(sink.readings, hasLength(1));
      expect(sink.readings.single.hasFix, isFalse);
      session.handleData(_bytes(_ggaNoFix));
      expect(sink.readings[1].hasFix, isTrue);
    });
  });

  group('gpsd', () {
    test('is asked for NMEA on connect, and its NMEA read as a receiver\'s', () {
      final sink = _FakeSink();
      final session = GpsdSession(sink)..startUpdates();
      // Without the WATCH gpsd sends its banner and waits.
      expect(sink.sent.single, gpsdWatchCommand);
      session.handleData(_bytes('{"class":"VERSION","release":"3.25"}\r\n$_ggaFix\r\n'));
      expect(sink.readings.single.hasFix, isTrue);
    });

    test('a gpsd with no receiver says so, and one that gains a receiver clears it', () {
      // Otherwise a daemon with nothing plugged in reads as a receiver that
      // went quiet, and the operator goes looking at the network.
      final sink = _FakeSink();
      final session = GpsdSession(sink);
      session.handleData(_bytes('{"class":"DEVICES","devices":[]}\r\n'));
      expect(sink.problems, hasLength(1));
      expect(sink.problems.single, isNotNull);
      expect(sink.alive, 1, reason: 'gpsd answering is gpsd there');
      session.handleData(_bytes('{"class":"DEVICES","devices":[{"path":"/dev/ttyACM0"}]}\r\n'));
      expect(sink.problems.last, isNull);
    });

    test('NMEA arriving clears "no receiver" — gpsd announces a late receiver only when asked', () {
      // Plugged in after the WATCH, a receiver gets a DEVICE, not a DEVICES;
      // waiting for the second, the row would say "no receiver" over a fix.
      final sink = _FakeSink();
      final session = GpsdSession(sink);
      session.handleData(_bytes('{"class":"DEVICES","devices":[]}\r\n'));
      session.handleData(_bytes('{"class":"DEVICE","path":"/dev/ttyACM0","activated":"2026-11-16T12:00:00Z"}\r\n'));
      expect(sink.sent.last, gpsdDevicesCommand, reason: 'a DEVICE asks for the count again');
      session.handleData(_bytes('$_ggaFix\r\n'));
      expect(sink.problems.last, isNull);
      expect(sink.readings.single.hasFix, isTrue);
    });

    test('a refusal from gpsd is shown, in its own words', () {
      final sink = _FakeSink();
      GpsdSession(sink).handleData(_bytes('{"class":"ERROR","message":"Unrecognized request \'WATCH\'"}\r\n'));
      expect(sink.problems.single, contains("Unrecognized request 'WATCH'"));
    });

    test('a \$ inside gpsd\'s JSON does not split the line', () {
      // Split, the `{` half fails to decode and "no receiver" goes unsaid.
      final sink = _FakeSink();
      GpsdSession(sink).handleData(_bytes('{"class":"DEVICES","devices":[],"note":"a\$b"}\r\n'));
      expect(sink.problems.single, isNotNull);
    });
  });

  group('the listening UDP transport', () {
    const transport = UdpListenTransport();

    test('takes datagrams from any sender on the port it listens on', () async {
      // A port with nothing on it, as far as a moment ago could tell.
      final probe = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0, reuseAddress: false);
      final port = probe.port;
      probe.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final listening = await transport.connect({'port': port}, cancel: CatCancelToken());
      addTearDown(listening.close);
      final received = <String>[];
      listening.data.listen((chunk) => received.add(ascii.decode(chunk)));

      final sender = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(sender.close);
      sender.send(_bytes(_ggaFix), InternetAddress.loopbackIPv4, port);
      for (var i = 0; i < 40 && received.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      expect(received, [_ggaFix]);
    });

    test('port 0 is refused rather than bound to whatever the OS picks', () async {
      // Bound, it would connect and hear nothing, ever.
      await expectLater(transport.connect({'port': 0}, cancel: CatCancelToken()), throwsA(isA<UdpListenFailed>()));
    });

    test('a port already in use is said as such, not as an unreachable host', () async {
      // There is no host here: "can't reach" would send the operator to the
      // network, when what to do is free the port.
      final holder = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0, reuseAddress: false);
      addTearDown(holder.close);
      await expectLater(transport.connect({'port': holder.port}, cancel: CatCancelToken()), throwsA(isA<UdpListenPortTaken>()));
    });
  });
}

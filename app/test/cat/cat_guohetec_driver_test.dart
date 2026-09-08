// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Guohetec session (Q900, PMR-171), with no radio and no serial port.
//
// Most of what is worth pinning here comes from one property of the
// protocol: THERE IS NO SINGLE-VFO COMMAND. Setting a frequency means
// transmitting a value for the other VFO too, so a session that tunes from
// a stale or absent picture of the radio moves a VFO the operator never
// touched. Every test in the `retuning` group exists for a specific way
// that goes wrong.
//
// Nothing here has met hardware, which is why the driver says
// `hardwareVerified` is false.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/guohetec_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/guohetec_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';

class _FakeSink implements EquipmentSink {
  final sent = <List<int>>[];
  final readings = <VfoReading>[];
  final diagnostics = <String?>[];
  final txReports = <bool>[];
  final meters = <(RadioMeter, num)>[];
  var aliveCount = 0;

  @override
  void send(List<int> bytes) => sent.add(bytes);
  @override
  void report(VfoReading reading) => readings.add(reading);
  @override
  void reportPower(num watts) {}
  @override
  void reportTransmitting(bool transmitting) => txReports.add(transmitting);
  @override
  void reportMeter(RadioMeter meter, num value) => meters.add((meter, value));
  @override
  void reportKeyerSpeed(int wpm) {}
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportVoiceActivity(VoiceActivity? activity) {}
  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);
  @override
  void reportProblem(String? message) {}
  @override
  void reportChannels(List<EquipmentChannel> channels) {}
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
  @override
  void reportAlive() => aliveCount++;
}

extension on GuohetecSession {
  void feed(List<int> bytes) => handleData(Uint8List.fromList(bytes));

  /// Hands the session a complete status packet, the way the radio would.
  void feedStatus({
    bool transmitting = false,
    int vfoAHz = 14074000,
    int vfoBHz = 7074000,
    int vfoAMode = 0x00,
    int vfoBMode = 0x01,
    bool vfoBActive = false,
    int signalByte = 0x12,
    int swrByte = 0x00,
  }) =>
      feed(buildGuohetecFrame(GuohetecOpcode.statusSync, [
        transmitting ? 1 : 0,
        vfoAMode,
        vfoBMode,
        ...encodeFrequency(vfoAHz),
        ...encodeFrequency(vfoBHz),
        vfoBActive ? 1 : 0,
        0, 0, 0, 20, 0, 138, 12, 34, 56, 0x00,
        signalByte,
        swrByte,
      ]));
}

/// The data bytes of a command the session sent — everything between the
/// command byte and the CRC.
List<int> _dataOf(List<int> frame) => frame.sublist(6, frame.length - 2);

/// The last command the session sent with this command byte, or null.
List<int>? _lastSent(_FakeSink sink, int command) {
  for (final frame in sink.sent.reversed) {
    if (frame.length > 5 && frame[5] == command) return frame;
  }
  return null;
}

void main() {
  late _FakeSink sink;
  late GuohetecSession session;

  setUp(() {
    sink = _FakeSink();
    session = GuohetecSession(sink);
  });

  group('reading', () {
    test('a status packet reports the ACTIVE vfo, not always A', () {
      session.feedStatus(vfoBActive: true);
      // Reporting A regardless would put the app on the receive frequency
      // of a split operator who is working on B.
      expect(sink.readings.single, const VfoReading(freqKHz: 7074.0, mode: 'LSB'));
    });

    test('the transmit flag is reported from the status packet', () {
      session.feedStatus(transmitting: true);
      expect(sink.txReports, [true]);
    });

    test('an unreadable status payload reports nothing about the radio', () {
      // A short payload has already passed its CRC, so it means the
      // firmware disagrees with the manual about the packet's shape.
      // Decoding it anyway builds a frequency out of whatever bytes are
      // there — and a wrong frequency that arrived through a valid checksum
      // is one nothing downstream would doubt.
      session.feed(buildGuohetecFrame(GuohetecOpcode.statusSync, List.filled(10, 0x01)));
      expect(sink.readings, isEmpty);
      expect(sink.diagnostics.single, contains('unreadable status'));
    });

    test('the radio identifies itself', () {
      session.feed(buildGuohetecFrame(GuohetecOpcode.equipmentType, [GuohetecEquipmentType.q900]));
      expect(sink.diagnostics.single, contains('Q900'));
    });

    test('an unknown equipment type is named, not assumed to be a Q900', () {
      // The PMR-171 shares this protocol, so an unexpected value is a real
      // radio a developer needs to see, not noise.
      session.feed(buildGuohetecFrame(GuohetecOpcode.equipmentType, [0x07]));
      expect(sink.diagnostics.single, contains('0x7'));
    });

    test('a set command acknowledgement counts as life and nothing more', () {
      session.feed(buildGuohetecFrame(GuohetecOpcode.powerLevel, [50]));
      expect(sink.aliveCount, 1);
      expect(sink.readings, isEmpty);
    });
  });

  group('retuning', () {
    test('carries the other VFO through untouched', () {
      session.feedStatus(vfoAHz: 14074000, vfoBHz: 7074000);
      session.setFrequency(14250.0);

      // The trap: this command sets BOTH VFOs. Sending anything but B's
      // real frequency in the second slot moves a VFO nobody touched.
      final data = _dataOf(_lastSent(sink, GuohetecOpcode.setFrequencies)!);
      expect(decodeFrequency(data.sublist(0, 4)), 14250000);
      expect(decodeFrequency(data.sublist(4, 8)), 7074000);
    });

    test('retunes B when B is the active VFO', () {
      session.feedStatus(vfoAHz: 14074000, vfoBHz: 7074000, vfoBActive: true);
      session.setFrequency(7100.0);

      final data = _dataOf(_lastSent(sink, GuohetecOpcode.setFrequencies)!);
      expect(decodeFrequency(data.sublist(0, 4)), 14074000);
      expect(decodeFrequency(data.sublist(4, 8)), 7100000);
    });

    test('a retune before the first status is held, not guessed at', () {
      // Sending now would mean inventing VFO B — and the invented value
      // lands on the radio as a real retune of a VFO the operator can see.
      session.setFrequency(14250.0);
      expect(_lastSent(sink, GuohetecOpcode.setFrequencies), isNull);

      session.feedStatus(vfoAHz: 14074000, vfoBHz: 7074000);
      final data = _dataOf(_lastSent(sink, GuohetecOpcode.setFrequencies)!);
      expect(decodeFrequency(data.sublist(0, 4)), 14250000);
      expect(decodeFrequency(data.sublist(4, 8)), 7074000);
    });

    test('consecutive retunes each carry the untouched VFO', () {
      // The radio has not answered in between, so both commands are built
      // from the same status — and B, which neither call names, has to
      // survive both of them intact.
      session.feedStatus(vfoAHz: 14074000, vfoBHz: 7074000);
      session.setFrequency(14250.0);
      session.setFrequency(14300.0);

      final data = _dataOf(_lastSent(sink, GuohetecOpcode.setFrequencies)!);
      expect(decodeFrequency(data.sublist(0, 4)), 14300000);
      expect(decodeFrequency(data.sublist(4, 8)), 7074000);
    });

    test('the app reports where the RADIO says it is, not where it was told to go', () {
      // No optimistic echo: a retune the radio rejects (out of band, locked)
      // must not leave the log showing a frequency nothing ever transmitted
      // on.
      session.feedStatus(vfoAHz: 14074000);
      sink.readings.clear();
      session.setFrequency(14250.0);
      expect(sink.readings, isEmpty);
    });

    test('a mode change carries the other VFO through untouched', () {
      session.feedStatus(vfoAMode: 0x00, vfoBMode: 0x01);
      session.setMode('CW');

      final data = _dataOf(_lastSent(sink, GuohetecOpcode.setModes)!);
      expect(guohetecModeNameForCode(data[0]), 'CW');
      expect(guohetecModeNameForCode(data[1]), 'LSB');
    });

    test('a mode the other VFO sits in and this driver cannot name sends nothing', () {
      // The command carries both modes, so an unnameable mode on the OTHER
      // VFO makes the whole command unbuildable. Guessing a code for it
      // moves a VFO the operator did not touch.
      session.feedStatus(vfoBMode: 0x7F);
      session.setMode('CW');
      expect(_lastSent(sink, GuohetecOpcode.setModes), isNull);
      expect(sink.diagnostics.last, contains('other VFO'));
    });

    test('a held frequency and a held mode both survive to the first status', () {
      session.setFrequency(14250.0);
      session.setMode('CW');
      session.feedStatus(vfoAHz: 14074000, vfoBHz: 7074000);

      expect(decodeFrequency(_dataOf(_lastSent(sink, GuohetecOpcode.setFrequencies)!).sublist(0, 4)), 14250000);
      expect(guohetecModeNameForCode(_dataOf(_lastSent(sink, GuohetecOpcode.setModes)!)[0]), 'CW');
    });

    test('a held retune is applied once, not on every later status', () {
      session.setFrequency(14250.0);
      session.feedStatus();
      final afterFirst = sink.sent.length;
      session.feedStatus();
      // Re-sending it would fight the operator's next dial turn for as long
      // as the session lives.
      expect(sink.sent.length, afterFirst);
    });
  });

  group('power', () {
    test('a rating stored as text does not take the session down with it', () {
      // Config comes back from stored JSON, where a number once typed into
      // a text field is a string. A cast here throws out of the
      // CONSTRUCTOR, so the whole session dies rather than one setting.
      final stored = GuohetecSession(sink, config: {guohetecMaxWattsConfigKey: '10'});
      stored.setPower(5);
      expect(_dataOf(_lastSent(sink, GuohetecOpcode.powerLevel)!), [50]);
    });

    test('a zero rating falls back rather than dividing by it', () {
      final zeroed = GuohetecSession(sink, config: {guohetecMaxWattsConfigKey: 0});
      zeroed.setPower(5);
      // Not an infinity, and not a thrown UnsupportedError out of setPower.
      expect(_dataOf(_lastSent(sink, GuohetecOpcode.powerLevel)!), [25]);
    });

    test('is scaled onto the protocol 0-100 against the radio rating', () {
      final scaled = GuohetecSession(sink, config: {guohetecMaxWattsConfigKey: 20});
      scaled.setPower(5);
      expect(_dataOf(_lastSent(sink, GuohetecOpcode.powerLevel)!), [25]);
    });

    test('more than the radio can do is its maximum, not an overflow', () {
      final scaled = GuohetecSession(sink, config: {guohetecMaxWattsConfigKey: 20});
      scaled.setPower(100);
      expect(_dataOf(_lastSent(sink, GuohetecOpcode.powerLevel)!), [100]);
    });
  });

  group('PTT', () {
    test('keying sends the press byte', () {
      session.setPtt(true);
      expect(_dataOf(_lastSent(sink, GuohetecOpcode.ptt)!), [0x00]);
    });

    test('teardown unkeys a radio the app keyed', () {
      // This protocol has no dead-man's switch. Disconnecting mid-transmission
      // leaves a radio keyed into an antenna with nothing left to turn it off.
      session.setPtt(true);
      session.teardown();
      expect(_dataOf(_lastSent(sink, GuohetecOpcode.ptt)!), [0x01]);
    });

    test('teardown does not key a radio the app never keyed', () {
      session.teardown();
      expect(_lastSent(sink, GuohetecOpcode.ptt), isNull);
    });
  });

  group('meters', () {
    test('the 0-34 scales report nothing without a calibration table', () {
      // The manual gives these a bare 0-34 and no units, and contradicts
      // itself over which scale is ALC. An invented SWR would be measured
      // against the threshold an operator is warned at.
      session.feedStatus(signalByte: 0x92, swrByte: 0x0A);
      expect(sink.meters.map((m) => m.$1), isNot(contains(RadioMeter.swr)));
      expect(sink.meters.map((m) => m.$1), isNot(contains(RadioMeter.powerOut)));
    });

    test('supply voltage is reported without any table at all', () {
      // The protocol states this one's unit outright — tenths of a volt —
      // so there is nothing left to calibrate, and it is the only reading
      // that means anything while the radio is merely receiving.
      session.feedStatus();
      expect(sink.meters, contains((RadioMeter.supplyVolts, 13.8)));
    });

    test('a power-scale reading means the radio is keyed', () {
      // Which scale the radio answers on follows the PTT, so this keeps the
      // transmit flag fresh between status polls — and it gates antenna
      // switching, so a stale one is not merely cosmetic.
      session.feed(buildGuohetecFrame(GuohetecOpcode.meters, [0x92, 0x00]));
      expect(sink.txReports, [true]);
    });

    test('an S-scale reading on the fast cadence unkeys', () {
      // The trap: reading this packet only for evidence of TRANSMIT latches
      // the flag on, because nothing else runs at this cadence — the
      // operator lets go and the TX indicator stays lit, with the meter
      // cycle still running, until the slow status poll comes round.
      session.feed(buildGuohetecFrame(GuohetecOpcode.meters, [0x92, 0x00]));
      session.feed(buildGuohetecFrame(GuohetecOpcode.meters, [0x12, 0x00]));
      expect(sink.txReports, [true, false]);
    });

    test('a status packet settles the transmit flag once, from its own field', () {
      // The trap: the meter byte carries the same fact as an inference, and
      // applying it after the explicit field makes the inference the winner
      // on every status packet. A firmware whose meter byte lags the PTT
      // would then flap the flag that gates antenna relays, forever.
      session.feedStatus(transmitting: false, signalByte: 0x92);
      // Exactly one report, and it is the packet's own field. With the
      // inference running second this reads [false, true].
      expect(sink.txReports, [false]);
    });
  });

  group('CRC health', () {
    test('a connection where nothing ever checksums says so, once', () {
      // The one failure this codec's provenance makes likely: the CRC is
      // inferred from the manual's C listing, and if that inference is
      // wrong every packet fails and the session just looks dead.
      final corrupt = buildGuohetecFrame(GuohetecOpcode.statusSync, List.filled(24, 0));
      corrupt[corrupt.length - 1] ^= 0xFF;
      session.feed(corrupt);
      session.feed(corrupt);

      expect(sink.diagnostics.where((d) => d?.contains('CRC') ?? false), hasLength(1));
    });

    test('a connection that framed something never blames the CRC', () {
      session.feedStatus();
      final corrupt = buildGuohetecFrame(GuohetecOpcode.meters, [0x12, 0x00]);
      corrupt[corrupt.length - 1] ^= 0xFF;
      session.feed(corrupt);

      expect(sink.diagnostics.where((d) => d?.contains('CRC') ?? false), isEmpty);
    });
  });
}

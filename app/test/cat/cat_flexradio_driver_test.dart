// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The FlexRadio SmartSDR protocol, exercised against lines captured from a
// live FLEX-6600 (SmartSDR v4.2.20.41343) over TCP port 4992 — carried over
// from app-polo's spec, which is the only place this protocol has ever been
// verified against real hardware.
//
// A session is pure given a fake sink, so all of this runs with no socket
// and no radio. `fakeAsync` for the resync interval: a test that starts
// updates without stopping them would otherwise leak a live 60 s timer.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart' show catStaleAfter;
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/flexradio_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/transports/flex_meter_socket.dart';

const _handshakeLines = ['V1.4.0.0', 'H5AC2F980'];
const _radioStatusLine = 'S5AC2F980|radio slices=3 panadapters=3 lineout_gain=60 nickname=RadioRoom callsign=N0CALL';
const _sliceStatusLine = 'S5AC2F980|slice 0 in_use=1 sample_rate=24000 RF_frequency=14.074000 client_handle=0x1C61D553 index_letter=A mode=DIGU wide=0';
const _sliceStatusLineWithDecimals =
    'S5AC2F980|slice 0 in_use=1 sample_rate=24000 RF_frequency=14.071820 client_handle=0x1C61D553 index_letter=A mode=CW wide=0';
const _otherSliceStatusLine = 'S5AC2F980|slice 1 in_use=1 RF_frequency=7.123000 mode=USB';
const _transmitStatusLine = 'S5AC2F980|transmit tune=0 show_tx_in_waterfall=0 rfpower=75 tunepower=10';
const _sliceBStatusLine = 'S5AC2F980|slice 1 in_use=1 RF_frequency=7.123000 client_handle=0x9F0012AB index_letter=B mode=LSB wide=0';
const _clientConnectedLine = 'S5AC2F980|client 0x9F0012AB connected client_id=42 local_ptt=0 program=SmartSDR-Win station=SHACK-PC';
const _clientDisconnectedLine = 'S5AC2F980|client 0x9F0012AB disconnected forced=0';

/// What `sub dvk all` answered on the FLEX-6600 (4.2.20), verbatim but for
/// the slots past 8 — the app offers one memory per function key.
const _dvkStatusLines = [
  'S7C1A8533|dvk status=idle enabled=1',
  'S7C1A8533|dvk added id=1 name="Recording 1" duration=2165',
  'S7C1A8533|dvk added id=2 name="Recording 2" duration=0',
  'S7C1A8533|dvk added id=3 name="59-NY-TU" duration=2165',
  'S7C1A8533|dvk added id=4 name="KI2D" duration=1925',
  'S7C1A8533|dvk added id=12 name="Recording 12" duration=1952',
];

class _FakeSink implements EquipmentSink, TunerSink, PassbandSink, RadioAntennaSink {
  final antennas = <RadioAntennas?>[];
  @override
  void reportAntennas(RadioAntennas? report) => antennas.add(report);

  final tuners = <TunerStatus?>[];
  @override
  void reportTuner(TunerStatus? status) => tuners.add(status);

  final passbands = <Passband?>[];
  @override
  void reportPassband(Passband? passband) => passbands.add(passband);

  final sent = <String>[];
  final readings = <VfoReading>[];
  final powers = <num>[];
  final diagnostics = <String?>[];
  final problems = <String?>[];
  List<EquipmentChannel> channels = const [];

  @override
  void send(List<int> bytes) => sent.add(utf8.decode(bytes));

  @override
  void report(VfoReading reading) => readings.add(reading);

  @override
  void reportPower(num watts) => powers.add(watts);

  final keyerSpeeds = <int>[];
  final txReports = <bool>[];
  final meterReports = <(RadioMeter, num)>[];
  @override
  void reportTransmitting(bool transmitting) => txReports.add(transmitting);
  @override
  void reportMeter(RadioMeter meter, num value) => meterReports.add((meter, value));

  @override
  void reportKeyerSpeed(int wpm) => keyerSpeeds.add(wpm);
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  final voices = <VoiceActivity?>[];
  @override
  void reportVoiceActivity(VoiceActivity? activity) => voices.add(activity);

  final memoryLists = <List<VoiceMemory>>[];
  @override
  void reportVoiceMemories(List<VoiceMemory> memories) => memoryLists.add(memories);

  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);

  @override
  void reportProblem(String? message) => problems.add(message);

  @override
  void reportChannels(List<EquipmentChannel> list) => channels = list;

  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}

  var alive = 0;
  @override
  void reportAlive() => alive++;

  EquipmentChannel channel(String key) => channels.firstWhere((c) => c.key == key);
}

class _FakeMeterSocket implements FlexMeterSocket {
  @override
  int get port => 4993;
  @override
  void close() {}
}

/// One VITA-49 meter packet carrying a single reading (SmartSDR metering
/// protocol: extension data, Flex OUI, meter class, then id/value pairs).
Uint8List _levelPacket({required int id, required double dbm}) {
  final data = ByteData(20);
  data.setUint32(0, 0x38000000 | (20 ~/ 4));
  data.setUint32(4, 0x80000000);
  data.setUint32(8, 0x001c2d);
  data.setUint32(12, 0x534c8002);
  data.setUint16(16, id);
  data.setInt16(18, (dbm * 128).round());
  return data.buffer.asUint8List();
}

extension on FlexRadioSession {
  void feed(String text) => handleData(Uint8List.fromList(utf8.encode(text)));
}

void main() {
  late _FakeSink sink;
  late FlexRadioSession session;

  setUp(() {
    sink = _FakeSink();
    session = FlexRadioSession(sink);
  });

  bool sentAny(String fragment) => sink.sent.any((line) => line.contains(fragment));

  group('handshake', () {
    test('defers the slice subscription until the handle (H) line, not the version (V) line', () {
      fakeAsync((async) {
        session.startUpdates();
        expect(sink.sent, isEmpty);

        session.feed('${_handshakeLines[0]}\n');
        expect(sink.sent, isEmpty, reason: 'the version banner is not the handshake');

        session.feed('${_handshakeLines[1]}\n');
        expect(sentAny('sub slice all'), isTrue);

        session.teardown();
        async.flushTimers();
      });
    });

    test('subscribes immediately when updates are requested after the handshake', () {
      fakeAsync((async) {
        session.feed('${_handshakeLines.join('\n')}\n');
        expect(sink.sent, isEmpty);

        session.startUpdates();
        expect(sentAny('sub slice all'), isTrue);

        session.teardown();
        async.flushTimers();
      });
    });

    test('unsubscribes when updates are stopped', () {
      fakeAsync((async) {
        session.feed('${_handshakeLines.join('\n')}\n');
        session.startUpdates();
        session.stopUpdates();
        expect(sentAny('unsub slice all'), isTrue);
        async.flushTimers();
      });
    });

    test('also subscribes to (and unsubscribes from) transmit status, for power', () {
      fakeAsync((async) {
        session.feed('${_handshakeLines.join('\n')}\n');
        session.startUpdates();
        expect(sentAny('sub tx all'), isTrue);
        session.stopUpdates();
        expect(sentAny('unsub tx all'), isTrue);
        async.flushTimers();
      });
    });
  });

  group('status parsing', () {
    test('reports slice 0 frequency and mode from a real status line, in kHz', () {
      session.feed('$_radioStatusLine\n$_sliceStatusLine\n');
      expect(sink.readings, [const VfoReading(freqKHz: 14074, mode: 'DATA-USB')]);
    });

    test('keeps decimals rather than rounding to whole kHz', () {
      session.feed('$_sliceStatusLineWithDecimals\n');
      expect(sink.readings, [const VfoReading(freqKHz: 14071.82, mode: 'CW')]);
    });

    test('ignores status for slices other than the tracked one', () {
      session.feed('$_otherSliceStatusLine\n');
      expect(sink.readings, isEmpty);
    });

    test('ignores a status line with neither frequency nor mode', () {
      session.feed('S5AC2F980|slice 0 in_use=1 wide=0\n');
      expect(sink.readings, isEmpty, reason: 'nothing to report is not a reading');
    });

    // This is the bug in the app-polo original: it split each chunk on '\n'
    // with no residual buffer, so a status line straddling two TCP reads was
    // silently mangled. TCP gives no frame boundaries at all, so this is not
    // a rare case — it is whatever the network happens to do.
    test('reassembles a status line split across chunks', () {
      final wholeLine = '$_sliceStatusLine\n';
      final splitAt = wholeLine.length ~/ 2;
      session.feed(wholeLine.substring(0, splitAt));
      expect(sink.readings, isEmpty, reason: 'a half-received line is not yet a line');

      session.feed(wholeLine.substring(splitAt));
      expect(sink.readings, [const VfoReading(freqKHz: 14074, mode: 'DATA-USB')]);
    });

    test('reassembles a handshake split across chunks', () {
      fakeAsync((async) {
        session.startUpdates();
        session.feed('H5AC2');
        expect(sentAny('sub slice all'), isFalse);

        session.feed('F980\n');
        expect(sentAny('sub slice all'), isTrue);

        session.teardown();
        async.flushTimers();
      });
    });

    test('handles CRLF line endings and several frames in one chunk', () {
      session.feed('$_otherSliceStatusLine\r\n$_sliceStatusLine\r\n');
      expect(sink.readings, [const VfoReading(freqKHz: 14074, mode: 'DATA-USB')]);
    });

    test('reports rfpower from a transmit status line', () {
      session.feed('$_transmitStatusLine\n');
      expect(sink.powers, [75]);
    });

    test('a slice status line with rfpower-shaped text does not report power', () {
      // rfpower belongs to `transmit`, not `slice` — a coincidental field
      // name on the wrong status object must not be read as one.
      session.feed('S5AC2F980|slice 0 in_use=1 mode=USB\n');
      expect(sink.powers, isEmpty);
    });
  });

  group('CW keying', () {
    test('subscribes to cwx with the rest, and lets go of it with the rest', () {
      fakeAsync((async) {
        session.feed('${_handshakeLines.join('\n')}\n');
        session.startUpdates();
        expect(sentAny('sub cwx all'), isTrue);
        session.teardown();
        expect(sentAny('unsub cwx all'), isTrue);
        async.flushTimers();
      });
    });

    test('a cwx status reports the keyer speed; so does speed= on the transmit object', () {
      session.feed('S5AC2F980|cwx wpm=25 break_in_delay=100 qsk_enabled=1\n');
      expect(sink.keyerSpeeds, [25]);
      session.feed('S5AC2F980|transmit speed=22 pitch=600\n');
      expect(sink.keyerSpeeds, [25, 22]);
      expect(sink.powers, isEmpty, reason: 'a transmit line without rfpower reports no power');
      expect(session.keyerSpeedRange, (min: 5, max: 100));
    });

    test('a cwx line whose fields carry no wpm reports nothing', () {
      // `sent=` progress and erase notices come on the same subscription.
      session.feed('S5AC2F980|cwx sent=12\n');
      expect(sink.keyerSpeeds, isEmpty);
    });

    test('sets the speed with cw wpm, clamped to 5-100', () {
      session.setKeyerSpeed(25);
      expect(sentAny('cw wpm 25'), isTrue);
      session.setKeyerSpeed(200);
      expect(sentAny('cw wpm 100'), isTrue);
    });

    test('keys a message through cwx send, spaces as 0x7F, and stops with cwx clear', () {
      fakeAsync((async) {
        session.sendCw('cq test');
        // The API's own rule: a space ends the argument, 0x7F is keyed as one.
        expect(sentAny('cwx send "CQ\x7FTEST"'), isTrue);
        expect(session.cwSending, isTrue);
        session.stopCw();
        expect(sentAny('cwx clear'), isTrue);
        expect(session.cwSending, isFalse);
        async.flushTimers();
      });
    });

    test('a whole message goes in one cwx send; the radio buffers it', () {
      fakeAsync((async) {
        session.sendCw('CQ CQ CQ DE N0DEV N0DEV N0DEV K CQ CQ CQ DE N0DEV N0DEV N0DEV K');
        expect(sink.sent.where((l) => l.contains('cwx send')), hasLength(1));
        async.flushTimers();
      });
    });
  });

  group('GUI client power', () {
    test('binds to the tracked slice owner regardless of discovery order', () {
      for (final clientFirst in [false, true]) {
        fakeAsync((async) {
          final localSink = _FakeSink();
          final rig = FlexRadioSession(localSink);
          rig.startUpdates();
          rig.feed('H5AC2F980\n');
          final owner = 'S5AC2F980|client 0x1C61D553 connected client_id=owner-id program=SmartSDR\n';
          final other = 'S5AC2F980|client 0x12345678 connected client_id=other-id program=SmartSDR\n';
          rig.feed(other);
          rig.feed(clientFirst ? owner : '$_sliceStatusLine\n');
          rig.feed(clientFirst ? '$_sliceStatusLine\n' : owner);
          expect(localSink.sent.where((s) => s.contains('client bind')), hasLength(1));
          expect(localSink.sent.any((s) => s.contains('client bind client_id=owner-id')), true);
          expect(localSink.sent.last, contains('sub tx all'));
          rig.feed(owner);
          expect(localSink.sent.where((s) => s.contains('client bind')), hasLength(1));
          rig.feed('S5AC2F980|slice 0 client_handle=0x12345678\n');
          expect(localSink.sent.any((s) => s.contains('client bind client_id=other-id')), true);
          rig.teardown();
        });
      }
    });
    test('saved band powers do not overwrite the current transmit power', () {
      session.feed('S5AC2F980|transmit freq=14.074000 rfpower=60\n');
      session.feed('S5AC2F980|transmit band 0 band_name=160 rfpower=100\n');
      session.feed('S5AC2F980|transmit band 13 band_name=15 rfpower=0\n');
      expect(sink.powers, [60]);
      session.feed('S5AC2F980|transmit rfpower=45\n');
      expect(sink.powers, [60, 45]);
    });
  });

  group('commands', () {
    test('reads back a tune without relying on an echo or inventing confirmation', () {
      fakeAsync((async) {
        session.startUpdates();
        session.feed('H5AC2F980\n$_sliceStatusLine\n');
        sink.sent.clear();
        sink.readings.clear();
        session.setFrequency(14141.4);
        session.setMode('USB');
        // A successful acknowledgement need not contain any slice status.
        session.feed('R6|0|\n');
        expect(sink.readings, isEmpty);
        async.elapse(const Duration(milliseconds: 100));
        expect(sink.sent.where((line) => line.contains('sub slice all')), hasLength(1));
        expect(sink.readings, isEmpty);
        // The radio's actual result, even if different, is authoritative.
        session.feed('S5AC2F980|slice 0 RF_frequency=14.141000 mode=USB\n');
        expect(sink.readings.last.freqKHz, 14141);
        expect(sink.readings.last.mode, 'USB');
        session.teardown();
      });
    });

    test('cancels a queued tune read-back when updates stop or the session closes', () {
      for (final teardown in [false, true]) {
        fakeAsync((async) {
          final rig = FlexRadioSession(sink);
          rig.startUpdates();
          rig.feed('H5AC2F980\n');
          rig.setMode('CW');
          if (teardown) {
            rig.teardown();
          } else {
            rig.stopUpdates();
          }
          sink.sent.clear();
          async.elapse(const Duration(seconds: 1));
          expect(sink.sent, isEmpty);
        });
      }
    });

    test('reads back power bursts and reports only the radio-confirmed value', () {
      fakeAsync((async) {
        session.startUpdates();
        session.feed('H5AC2F980\n');
        sink.sent.clear();
        session.setPower(50);
        session.setPower(75);
        session.feed('R6|0|\n');
        expect(sink.powers, isEmpty);
        async.elapse(const Duration(milliseconds: 100));
        expect(sink.sent.where((line) => line.contains('sub tx all')), hasLength(1));
        expect(sink.powers, isEmpty);
        session.feed('S5AC2F980|transmit rfpower=70\n');
        expect(sink.powers, [70]);
        session.setPower(80);
        async.elapse(const Duration(milliseconds: 100));
        expect(sink.sent.where((line) => line.contains('sub tx all')), hasLength(2));
        session.teardown();
      });
    });

    test('cancels power read-back when updates stop or the session closes', () {
      for (final teardown in [false, true]) {
        fakeAsync((async) {
          final rig = FlexRadioSession(sink);
          rig.startUpdates();
          rig.feed('H5AC2F980\n');
          rig.setPower(50);
          if (teardown) {
            rig.teardown();
          } else {
            rig.stopUpdates();
          }
          sink.sent.clear();
          async.elapse(const Duration(seconds: 1));
          expect(sink.sent, isEmpty);
        });
      }
    });

    test('builds a tune command in MHz from a frequency in kHz', () {
      session.setFrequency(14074);
      expect(sentAny('slice tune 0 14.074000'), isTrue);
    });

    test('sets the mode on the tracked slice', () {
      session.setMode('usb');
      expect(sentAny('slice set 0 mode=USB'), isTrue);
    });

    // SmartSDR has no DATA-USB: a raw pass-through is refused, and the slice
    // stays in whatever mode a band change left it in.
    test("puts a data mode on SmartSDR's own name for it", () {
      session.setMode('DATA-USB');
      expect(sentAny('slice set 0 mode=DIGU'), isTrue);
    });

    test('sets power on the transmit object, in watts', () {
      session.setPower(75);
      expect(sentAny('transmit set rfpower=75'), isTrue);
    });

    test('numbers each command with an increasing sequence', () {
      session.setFrequency(14074);
      session.setMode('USB');
      expect(sink.sent[0], startsWith('C1|'));
      expect(sink.sent[1], startsWith('C2|'));
    });
  });

  group('resync', () {
    // A Flex subscription can go stale with no error to react to — a dropped
    // WiFi/NAT mapping, a radio-side hiccup. Re-subscribing is idempotent and
    // Flex answers with a full refresh, so it doubles as a resync. Without
    // this the panel shows Connected next to a frozen frequency.
    test('periodically re-subscribes while updates are wanted', () {
      fakeAsync((async) {
        session.feed('${_handshakeLines.join('\n')}\n');
        session.startUpdates();
        sink.sent.clear();

        async.elapse(const Duration(seconds: 60));
        expect(sentAny('sub slice all'), isTrue);

        sink.sent.clear();
        session.stopUpdates();
        sink.sent.clear();

        async.elapse(const Duration(minutes: 2));
        expect(sentAny('sub slice all'), isFalse, reason: 'the resync timer must stop with updates');
      });
    });

    test('teardown says goodbye and cancels the resync timer', () {
      fakeAsync((async) {
        session.feed('${_handshakeLines.join('\n')}\n');
        session.startUpdates();
        sink.sent.clear();

        session.teardown();
        expect(sentAny('unsub slice all'), isTrue);

        sink.sent.clear();
        async.elapse(const Duration(minutes: 5));
        expect(sink.sent, isEmpty);
      });
    });

    test('teardown before any subscription sends nothing', () {
      fakeAsync((async) {
        session.teardown();
        expect(sink.sent, isEmpty);
        async.flushTimers();
      });
    });
  });

  group('the receive meter socket', () {
    // Every 60 s resync re-enters the meter setup. A host that cannot be
    // resolved would otherwise cost a 5 s lookup and a diagnostic per resync,
    // for as long as the radio stays connected.
    test('an open that fails is not retried on every resync, only by a new subscription', () {
      fakeAsync((async) {
        var opens = 0;
        session = FlexRadioSession(
          sink,
          meterHost: 'flex.invalid',
          openMeterSocket: (host, onData, onError) async {
            opens++;
            throw StateError('no such host');
          },
        );
        session.feed('${_handshakeLines.join('\n')}\n');
        session.startUpdates();
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 3));
        expect(opens, 1);
        expect(sink.diagnostics.where((note) => note?.contains('receive meter') ?? false), hasLength(1));

        session.teardown();
        session.startUpdates();
        async.flushMicrotasks();
        expect(opens, 2);

        session.teardown();
        async.flushTimers();
      });
    });

    // Both lines are as a FLEX-6600 on 4.2.20 sent them, shortened to the two
    // meters that matter. Nothing else feeds a meter line through the session,
    // and a pattern that misses either form learns no LEVEL meter: the signal
    // then reads as absent for good, with no error anywhere.
    const levelStatusLine =
        'S3555AEC|meter 13.src=SLC#13.num=0#13.nam=LEVEL#13.low=-150.0#13.hi=20.0'
        '#13.desc=Signal strength of signals in the filter passband#13.unit=dBm#13.fps=10#';
    const meterListReply =
        'R2|0|meter 1.src=COD-#1.num=1#1.nam=MICPEAK#1.low=-150.0#1.hi=20.0#1.unit=dBFS#1.fps=40'
        '#13.src=SLC#13.num=0#13.nam=LEVEL#13.low=-150.0#13.hi=20.0#13.unit=dBm#13.fps=10#';

    for (final (form, line) in [('pushed as status', levelStatusLine), ('the meter list reply', meterListReply)]) {
      test('the slice LEVEL meter is learned from $form', () {
        fakeAsync((async) {
          void Function(Uint8List)? deliver;
          session = FlexRadioSession(
            sink,
            meterHost: '10.0.0.5',
            openMeterSocket: (host, onData, onError) async {
              deliver = onData;
              return _FakeMeterSocket();
            },
          );
          session.feed('${_handshakeLines.join('\n')}\n');
          session.startUpdates();
          async.flushMicrotasks();
          expect(sentAny('client udpport 4993'), isTrue);
          expect(sentAny('meter list'), isTrue);

          deliver!(_levelPacket(id: 13, dbm: -93.5));
          expect(sink.meterReports, isEmpty, reason: 'meter 13 means nothing until the radio has described it');

          session.feed('$line\n');
          async.elapse(const Duration(seconds: 1));
          deliver!(_levelPacket(id: 13, dbm: -93.5));
          expect(sink.meterReports, [(RadioMeter.signalDbm, -94)]);

          session.teardown();
          async.flushTimers();
        });
      });
    }

    test('a platform with no socket to give is asked once', () {
      fakeAsync((async) {
        var opens = 0;
        session = FlexRadioSession(
          sink,
          meterHost: '10.0.0.5',
          openMeterSocket: (host, onData, onError) async {
            opens++;
            return null;
          },
        );
        session.feed('${_handshakeLines.join('\n')}\n');
        session.startUpdates();
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 3));
        expect(opens, 1);
        expect(sentAny('sub meter all'), isFalse);

        session.teardown();
        async.flushTimers();
      });
    });
  });

  group('a radio nobody is touching', () {
    // A slice status is pushed only when something changes, so a still dial
    // is total silence — and the manager marks 30 s of it "Not responding".
    // The 60 s resync then clears it, so without a ping an idle radio reads
    // as dead for the second half of every minute.
    test('pings inside the silence window, and the acknowledgement counts as life', () {
      fakeAsync((async) {
        session.feed('${_handshakeLines.join('\n')}\n');
        session.startUpdates();
        sink.sent.clear();

        expect(flexRadioPingInterval, lessThan(catStaleAfter));
        async.elapse(flexRadioPingInterval);
        final pings = sink.sent.where((line) => line.endsWith('|ping\n')).toList();
        expect(pings, hasLength(1));

        expect(sink.alive, 0, reason: 'sending the ping proves nothing; the answer does');
        final seq = RegExp(r'^C(\d+)\|').firstMatch(pings.single)!.group(1);
        session.feed('R$seq|0|\n');
        expect(sink.alive, 1);

        session.teardown();
        async.flushTimers();
      });
    });

    test('a status push is reported as a reading, not as bare life', () {
      // Two reports for one line would be harmless today, but the sink's
      // contract is that a reading already counts — a driver that also
      // reports life for it has misread which of the two it is holding.
      fakeAsync((async) {
        session.feed('${_handshakeLines.join('\n')}\n');
        session.startUpdates();
        session.feed('$_sliceStatusLine\n');
        expect(sink.readings, hasLength(1));
        expect(sink.alive, 0);

        session.teardown();
        async.flushTimers();
      });
    });

    test('stops pinging with updates', () {
      fakeAsync((async) {
        session.feed('${_handshakeLines.join('\n')}\n');
        session.startUpdates();
        session.stopUpdates();
        sink.sent.clear();

        // The callback also checks _wantUpdates, so silence alone would pass
        // over a leaked timer; the timer itself has to be gone.
        expect(async.periodicTimerCount, 0, reason: 'a leaked ping timer retains the session for the process lifetime');
        async.elapse(const Duration(minutes: 2));
        expect(sentAny('ping'), isFalse);
      });
    });
  });

  group('choosing a slice', () {
    // A Flex runs several slices at once. Tracking whichever one is index 0
    // is only right for an operator who happens to be working slice A —
    // everyone else was reading a frequency they were not transmitting on.
    late FlexRadioSession sliceB;

    setUp(() => sliceB = FlexRadioSession(sink, slice: 1));

    test('reads the configured slice, and ignores the others', () {
      sliceB.feed('$_sliceStatusLine\n$_sliceBStatusLine\n');
      expect(sink.readings, [const VfoReading(freqKHz: 7123, mode: 'LSB')], reason: 'slice 0 is another slice now, not the tracked one');
    });

    // Read and write must name the SAME slice: a node watching B while
    // tuning A logs a frequency the radio never transmitted on, and nothing
    // about the row would say so.
    test('tunes and sets the mode on the configured slice', () {
      sliceB.setFrequency(7123);
      sliceB.setMode('lsb');
      expect(sink.sent.any((line) => line.contains('slice tune 1 7.123000')), isTrue);
      expect(sink.sent.any((line) => line.contains('slice set 1 mode=LSB')), isTrue);
    });

    test('power stays radio-wide, not per slice', () {
      sliceB.setPower(50);
      expect(sink.sent.any((line) => line.contains('transmit set rfpower=50')), isTrue);
    });

    test('a node stored before this setting existed still tracks slice A', () {
      expect(FlexRadioDriver.sliceFromConfig(const {}), 0);
      expect(FlexRadioDriver.sliceFromConfig(const {'slice': '3'}), 3);
      // A value round-tripped through JSON arrives as a num on some paths.
      expect(FlexRadioDriver.sliceFromConfig(const {'slice': 3}), 3);
      // Out of range falls back to slice A here, and the reason that is not
      // a silent wrong answer is the validator below: a value this rejects
      // cannot be saved, so the fallback only ever covers a config no form
      // produced.
      expect(FlexRadioDriver.sliceFromConfig(const {'slice': '99'}), 0);
    });

    // The trap: a node stored before this setting existed carries no `slice`
    // key, and the service validates every recognized key on the way to
    // connect. Rejecting the absent one stops a radio that had been working
    // for months from connecting at all, with a form error as the only clue.
    test('an unset slice validates, so an existing node still connects', () {
      const driver = FlexRadioDriver();
      expect(driver.validateField('slice', null, const {}), isNull);
      expect(driver.validateField('slice', '', const {}), isNull);
      expect(driver.validateField('slice', '2', const {}), isNull);
      expect(driver.validateField('slice', '9', const {}), isNotNull);
    });

    test('the equipment row always says which slice, like the CI-V row says its address', () {
      const driver = FlexRadioDriver();
      expect(driver.describeSuffix(const {}), contains('A'));
      expect(driver.describeSuffix(const {'slice': '1'}), contains('B'));
      // A pairing that fixes the slice shows no field, so it shows no
      // suffix either — the value is not something the operator picked.
      expect(driver.describeSuffix(const {'slice': '1'}, overrides: const {'slice': '1'}), isNull);
    });
  });

  group('slice inventory', () {
    test('reports every slice the radio has, with what it is doing', () {
      session.feed('$_sliceStatusLine\n$_sliceBStatusLine\n');
      expect(sink.channel('0').label, 'A');
      expect(sink.channel('0').inUse, isTrue);
      expect(sink.channel('0').freqKHz, 14074);
      expect(sink.channel('0').mode, 'DATA-USB');
      expect(sink.channel('1').label, 'B');
      expect(sink.channel('1').freqKHz, 7123);
      // A slice the radio has never mentioned is offered, and empty.
      expect(sink.channel('7').inUse, isFalse);
      expect(sink.channel('7').freqKHz, isNull);
    });

    // A status push carries only what CHANGED. Replacing rather than merging
    // would blank the mode out of the inventory on every retune, which reads
    // as a slice that lost its mode rather than one that moved.
    test('merges a partial status push into what the slice already said', () {
      session.feed('$_sliceBStatusLine\n');
      session.feed('S5AC2F980|slice 1 RF_frequency=7.150000\n');
      expect(sink.channel('1').freqKHz, 7150);
      expect(sink.channel('1').mode, 'LSB');
      expect(sink.channel('1').inUse, isTrue);
    });

    test('names the client holding a slice, not its handle', () {
      session.feed('$_clientConnectedLine\n$_sliceBStatusLine\n');
      expect(sink.channel('1').usedBy, 'SmartSDR-Win (SHACK-PC)');
    });

    // Losing the name must not turn into "nobody has it": the slice still
    // carries a client handle, and the operator's answer to a slice held by
    // something unnamed is the same as to one held by SmartSDR — leave it.
    test('a client that goes away leaves the slice held, not free', () {
      session.feed('$_clientConnectedLine\n$_sliceBStatusLine\n');
      session.feed('$_clientDisconnectedLine\n');
      expect(sink.channel('1').usedBy, isNull);
      expect(sink.channel('1').heldByUnknown, isTrue);
    });

    // The trap: `sub client all` refused, or a handle the radio formats
    // differently in the two places it appears, leaves every held slice
    // looking free — worse than showing no inventory at all, because by then
    // the operator believes they checked.
    test('a slice whose owner we never learn still reads as held', () {
      session.feed('$_sliceBStatusLine\n');
      expect(sink.channel('1').usedBy, isNull);
      expect(sink.channel('1').heldByUnknown, isTrue);
      // A slice with no client handle at all is genuinely unheld.
      session.feed('S5AC2F980|slice 2 in_use=1 RF_frequency=21.030000 mode=USB index_letter=C\n');
      expect(sink.channel('2').heldByUnknown, isFalse);
    });

    test('a removed slice drops out of the inventory', () {
      session.feed('$_sliceBStatusLine\n');
      expect(sink.channel('1').inUse, isTrue);
      session.feed('S5AC2F980|slice 1 in_use=0 removed=1\n');
      expect(sink.channel('1').inUse, isFalse);
      expect(sink.channel('1').freqKHz, isNull, reason: 'a removed slice keeps nothing');
    });

    test('subscribes to client status, so a slice can name who holds it', () {
      fakeAsync((async) {
        session.feed('${_handshakeLines.join('\n')}\n');
        session.startUpdates();
        expect(sentAny('sub client all'), isTrue);
        session.stopUpdates();
        expect(sentAny('unsub client all'), isTrue);
        async.flushTimers();
      });
    });
  });

  group('a slice that is not there', () {
    // Connected, link healthy, and nothing ever arrives: identical to a dead
    // radio from the row, which is the failure error-reporting.md exists to
    // prevent. Reconnecting cannot fix it, so it is a problem and not an
    // error — see EquipmentState.problem.
    test('a slice the radio never mentions is reported once the refresh has settled', () {
      fakeAsync((async) {
        final sliceD = FlexRadioSession(sink, slice: 3);
        sliceD.feed('${_handshakeLines.join('\n')}\n');
        sliceD.startUpdates();
        sliceD.feed('$_sliceStatusLine\n$_sliceBStatusLine\n');
        expect(sink.problems, isEmpty, reason: 'the refresh is still arriving');

        async.elapse(const Duration(seconds: 4));
        expect(sink.problems.last, contains('D'));

        sliceD.teardown();
        async.flushTimers();
      });
    });

    test('a slice that is present raises nothing', () {
      fakeAsync((async) {
        session.feed('${_handshakeLines.join('\n')}\n');
        session.startUpdates();
        session.feed('$_sliceStatusLine\n');

        async.elapse(const Duration(seconds: 4));
        expect(sink.problems.where((p) => p != null), isEmpty);

        session.teardown();
        async.flushTimers();
      });
    });

    test('a slice torn down while connected is reported, and cleared when it returns', () {
      fakeAsync((async) {
        final sliceB = FlexRadioSession(sink, slice: 1);
        sliceB.feed('${_handshakeLines.join('\n')}\n');
        sliceB.startUpdates();
        sliceB.feed('$_sliceBStatusLine\n');
        async.elapse(const Duration(seconds: 4));
        // Nulls are the driver saying "nothing wrong" — CatService holds the
        // value and dedupes them, so what matters here is that no MESSAGE
        // was raised.
        expect(sink.problems.where((p) => p != null), isEmpty);

        sliceB.feed('S5AC2F980|slice 1 in_use=0\n');
        expect(sink.problems.last, contains('B'));

        sliceB.feed('$_sliceBStatusLine\n');
        expect(sink.problems.last, isNull, reason: 'null is how a problem is withdrawn');

        sliceB.teardown();
        async.flushTimers();
      });
    });

    // A slice the radio has not described is a DIFFERENT fault from one it
    // has described as idle, and they take different remedies: the first is
    // a subscription or handshake that failed, and telling that operator to
    // pick another slice sends them to change a setting that was right.
    test('no slices at all is reported as no slices, not as the wrong slice', () {
      fakeAsync((async) {
        session.feed('${_handshakeLines.join('\n')}\n');
        session.startUpdates();

        async.elapse(const Duration(seconds: 4));
        expect(sink.problems.last, isNotNull);
        expect(sink.problems.last, isNot(contains('Slice A')));

        session.teardown();
        async.flushTimers();
      });
    });

    // The trap: every path that would say a slice is missing hangs off the
    // subscription, and the subscription hangs off a handshake that may
    // never land. The staleness watchdog would eventually flag the row, but
    // with the same word it uses for a radio that was unplugged.
    test('a handshake that never lands is still reported', () {
      fakeAsync((async) {
        session.startUpdates();
        expect(sink.sent, isEmpty, reason: 'nothing is subscribed without the handshake');

        async.elapse(const Duration(seconds: 4));
        expect(sink.problems.last, isNotNull);

        session.teardown();
        async.flushTimers();
      });
    });

    // The trap: a slice the radio has mentioned WITHOUT ever saying whether
    // it runs is not evidence of anything, and guessing goes wrong in both
    // directions — guess "running" and a real missing-slice warning is
    // withdrawn with no transition left to raise it again, guess "not
    // running" and the operator is sent to change a setting that was right.
    // So it changes no verdict at all.
    test('a slice mentioned without saying whether it runs accuses nobody', () {
      fakeAsync((async) {
        final sliceD = FlexRadioSession(sink, slice: 3);
        sliceD.feed('${_handshakeLines.join('\n')}\n');
        sliceD.startUpdates();
        // Slice 3 named, with no in_use= anywhere in the line.
        sliceD.feed('$_sliceStatusLine\nS5AC2F980|slice 3 RF_frequency=21.030000\n');

        async.elapse(const Duration(seconds: 4));
        expect(sink.problems.where((p) => p != null), isEmpty);
        // And the picker shows it as running: it has an entry, which no idle
        // slice gets.
        expect(sink.channel('3').inUse, isTrue);
        expect(sink.channel('3').freqKHz, 21030);

        sliceD.teardown();
        async.flushTimers();
      });
    });
  });

  group('the antennas', () {
    test('are the tracked slice\'s, receive and transmit each its own, from the lists the radio offers', () {
      fakeAsync((async) {
        session.feed('${_handshakeLines.join('\n')}\n');
        session.startUpdates();
        // As RadioRoom (FLEX-6600, 4.2.20) states slice A.
        session.feed('S0|slice 0 in_use=1 rxant=ANT1 txant=ANT1 ant_list=ANT1,ANT2,RX_A,RX_B,XVTA,XVTB tx_ant_list=ANT1,ANT2,XVTA,XVTB\n');
        session.feed('S0|slice 0 rxant=RX_A\n');
        expect(
          sink.antennas.last,
          const RadioAntennas(
            rxPorts: ['ANT1', 'ANT2', 'RX_A', 'RX_B', 'XVTA', 'XVTB'],
            txPorts: ['ANT1', 'ANT2', 'XVTA', 'XVTB'],
            rx: 'RX_A',
            tx: 'ANT1',
            separate: true,
          ),
        );
        sink.sent.clear();
        session.setAntenna(tx: 'ANT2');
        expect(sink.sent.single.split('|').last.trim(), 'slice set 0 txant=ANT2');
        session.teardown();
        async.flushTimers();
      });
    });
  });

  group('the passband', () {
    test('is the tracked slice\'s filter, in Hz from its frequency as the radio states it', () {
      fakeAsync((async) {
        session.feed('${_handshakeLines.join('\n')}\n');
        session.startUpdates();
        // As RadioRoom (FLEX-6600, 4.2.20) states slice A in USB.
        session.feed('S0|slice 0 in_use=1 RF_frequency=14.243000 mode=USB filter_lo=100 filter_hi=2800\n');
        // Another slice's filter is not this one's.
        session.feed('S0|slice 1 in_use=1 RF_frequency=7.200000 mode=LSB filter_lo=-2400 filter_hi=-300\n');
        // A push carries only what changed: the other edge stands.
        session.feed('S0|slice 0 filter_hi=2400\n');
        expect(sink.passbands, [const Passband(100, 2800), const Passband(100, 2400)]);
        session.teardown();
        async.flushTimers();
      });
    });

    test('is set with `filt`, and read back since the radio clamps it', () {
      fakeAsync((async) {
        session.feed('${_handshakeLines.join('\n')}\n');
        session.startUpdates();
        sink.sent.clear();
        session.setPassband(const Passband(200, 2900));
        expect(sink.sent.single.split('|').last.trim(), 'filt 0 200 2900');
        async.elapse(const Duration(milliseconds: 200));
        expect(sink.sent.last, endsWith('|sub slice all\n'));
        session.teardown();
        async.flushTimers();
      });
    });
  });

  group('the tuner', () {
    test('reads the radio\'s ATU status, which arrives on its own subscription', () {
      fakeAsync((async) {
        session.feed('${_handshakeLines.join('\n')}\n');
        session.startUpdates();
        expect(sink.sent.any((c) => c.endsWith('|sub atu all\n')), isTrue);
        // As RadioRoom (FLEX-6600, 4.2.20) answers the subscription.
        session.feed('S0|atu status=TUNE_SUCCESSFUL atu_enabled=1 memories_enabled=1 using_mem=1\n');
        // A push carries only what changed: the status alone still means a tuner that is fitted.
        session.feed('S0|atu status=TUNE_MANUAL_BYPASS\n');
        session.feed('S0|atu status=TUNE_FAIL\n');
        session.feed('S0|atu status=TUNE_IN_PROGRESS\n');
        expect(sink.tuners, [TunerStatus.inline, TunerStatus.bypassed, TunerStatus.failed, TunerStatus.tuning]);
        // A radio without the tuner fitted, or with it off in its setup, has nothing to put in line.
        session.feed('S0|atu atu_enabled=0\n');
        expect(sink.tuners.last, isNull);
        session.teardown();
        async.flushTimers();
      });
    });

    test('bypass transmits nothing; in line is a tune, the only way a Flex tuner engages', () {
      fakeAsync((async) {
        session.feed('${_handshakeLines.join('\n')}\n');
        session.startUpdates();
        sink.sent.clear();
        session.setTuner(inline: false);
        session.setTuner(inline: true);
        expect(sink.sent.map((c) => c.split('|').last.trim()), ['atu bypass', 'atu start']);
        // In line already is the tune: a separate Tune beside it would be the same carrier twice over.
        expect(session.canStartTune, isFalse);
        // The radio may not echo a status to the client that asked, so the
        // outcome is read back rather than waited for.
        async.elapse(const Duration(seconds: 1));
        expect(sink.sent.last, endsWith('|sub atu all\n'));
        session.teardown();
        async.flushTimers();
      });
    });
  });

  group('the interlock', () {
    test('says when the radio is on the air, without being asked', () {
      // A Flex is the one radio here that costs nothing to watch: the
      // interlock object arrives on the `tx` subscription this driver
      // already takes, so there is no TX poll at all.
      session.feed('S40000001|interlock state=RECEIVE\n');
      expect(sink.txReports, [false]);
      session.feed('S40000001|interlock state=TRANSMITTING\n');
      expect(sink.txReports, [false, true]);
      // Every subscribe refreshes the whole object; a restatement is not
      // news, and reporting one would wake every listener on each refresh.
      session.feed('S40000001|interlock state=TRANSMITTING reason=\n');
      expect(sink.txReports, [false, true]);
    });

    test('counts the two states either side of TRANSMITTING as keyed', () {
      // What reads this is the rule that no relay moves under RF. RF is
      // imminent on PTT_REQUESTED and still present on UNKEY_REQUESTED, so
      // reading only TRANSMITTING would open the gate exactly at the two
      // edges of a transmission.
      session.feed('S40000001|interlock state=PTT_REQUESTED\n');
      expect(sink.txReports, [true]);
      session.feed('S40000001|interlock state=UNKEY_REQUESTED\n');
      expect(sink.txReports, [true], reason: 'still keyed, so still not news');
      session.feed('S40000001|interlock state=READY\n');
      expect(sink.txReports, [true, false]);
    });

    test('a push with no state says nothing about transmitting', () {
      // Status pushes carry only what CHANGED, so a line about some other
      // interlock field must not be read as "receiving".
      session.feed('S40000001|interlock timeout=180\n');
      expect(sink.txReports, isEmpty);
    });
  });

  group('PTT', () {
    // The SmartSDR command is `xmit`, bare: the radio keys its transmit
    // slice. Commands carry a sequence number, so only what follows the
    // `|` is compared.
    List<String> commands() => [for (final line in sink.sent) line.substring(line.indexOf('|') + 1).trim()];

    test('keys with xmit 1 and unkeys with xmit 0', () {
      fakeAsync((async) {
        session.feed('${_handshakeLines.join('\n')}\n');
        session.startUpdates();
        sink.sent.clear();
        session.setPtt(true);
        session.setPtt(false);
        expect(commands(), ['xmit 1', 'xmit 0']);
        expect(sink.txReports, isEmpty, reason: 'keyed is what the interlock says, never what was asked');
        session.teardown();
        async.flushTimers();
      });
    });

    test('teardown unkeys a radio the app keyed, before unsubscribing', () {
      // Closing the API connection does not unkey a Flex: a teardown that
      // forgets the unkey leaves the transmitter on the air with nothing
      // left to turn it off.
      fakeAsync((async) {
        session.feed('${_handshakeLines.join('\n')}\n');
        session.startUpdates();
        session.setPtt(true);
        sink.sent.clear();
        session.teardown();
        expect(commands().first, 'xmit 0');
        async.flushTimers();
      });
    });

    test('teardown sends no xmit on a radio the app never keyed', () {
      // An unkey from a session that never keyed would cut off the operator
      // transmitting from SmartSDR or a footswitch.
      fakeAsync((async) {
        session.feed('${_handshakeLines.join('\n')}\n');
        session.startUpdates();
        session.teardown();
        expect(commands().where((c) => c.startsWith('xmit')), isEmpty);
        async.flushTimers();
      });
    });
  });

  group('the voice keyer (DVK)', () {
    List<String> commands() => [for (final line in sink.sent) line.substring(line.indexOf('|') + 1).trim()];

    /// The sequence number [command] last went out under, which its reply names.
    int seqOf(String command) => int.parse(RegExp(r'^C(\d+)\|').firstMatch(sink.sent.lastWhere((line) => line.contains(command)))!.group(1)!);

    void connect() {
      session.feed('${_handshakeLines.join('\n')}\n');
      session.startUpdates();
      session.feed('${_dvkStatusLines.join('\n')}\n');
      sink.sent.clear();
    }

    test('subscribes to the keyer and the licence with the rest, and lets go of both', () {
      fakeAsync((async) {
        session.feed('${_handshakeLines.join('\n')}\n');
        session.startUpdates();
        expect(commands(), containsAll(['sub dvk all', 'sub license all']));
        session.stopUpdates();
        expect(commands(), containsAll(['unsub dvk all', 'unsub license all']));
        async.flushTimers();
      });
    });

    test("reports the radio's names and lengths, the first eight, with its default names as none", () {
      session.feed('${_dvkStatusLines.join('\n')}\n');
      final slots = sink.memoryLists.last;
      expect(slots, hasLength(maxVoiceMemories), reason: 'one per function key; slot 12 has no key to play it');
      // "Recording 1" is only what SmartSDR calls a slot nobody named: shown,
      // it would push the key ("M1") out of the strip with a word that says
      // nothing about the audio.
      expect(slots[0], const VoiceMemory(memory: 1, durationMs: 2165));
      expect(slots[2], const VoiceMemory(memory: 3, name: '59-NY-TU', durationMs: 2165));
      expect(slots[3], const VoiceMemory(memory: 4, name: 'KI2D', durationMs: 1925));
      expect(slots[4], const VoiceMemory(memory: 5), reason: 'a slot the radio has not described is empty, not missing');
    });

    test('a name with spaces in it is read whole', () {
      session.feed('S7C1A8533|dvk added id=2 name="CQ POTA K-1234" duration=3100\n');
      expect(sink.memoryLists.last[1], const VoiceMemory(memory: 2, name: 'CQ POTA K-1234', durationMs: 3100));
    });

    test('a refresh that changes nothing reports nothing', () {
      // The keyer is re-asked every second while a memory plays; reporting
      // each answer would rebuild every keying surface once a second.
      session.feed('${_dvkStatusLines.join('\n')}\n');
      final before = sink.memoryLists.length;
      session.feed('${_dvkStatusLines.join('\n')}\n');
      expect(sink.memoryLists, hasLength(before));
    });

    test('a deleted slot is reported empty', () {
      session.feed('${_dvkStatusLines.join('\n')}\n');
      session.feed('S7C1A8533|dvk deleted id=3\n');
      expect(sink.memoryLists.last[2], const VoiceMemory(memory: 3));
    });

    test('plays with playback_start, and the radio saying idle is the end', () {
      fakeAsync((async) {
        connect();
        session.playVoiceMemory(3);
        expect(commands(), ['dvk playback_start id=3']);
        expect(sink.voices, [const VoiceActivity(memory: 3)]);
        session.feed('S7C1A8533|dvk status=playback id=3\n');
        async.elapse(const Duration(seconds: 2));
        session.feed('S7C1A8533|dvk status=idle\n');
        expect(sink.voices.last, isNull);
        expect(sink.voices.whereType<VoiceActivity>().where((a) => a.doubtful), isEmpty, reason: 'a play the radio confirmed is not doubted at its end');
        session.teardown();
        async.flushTimers();
      });
    });

    test('asks the radio nothing while it plays: the status is pushed', () {
      // The API reference publishes every DVK state change to every
      // subscribed client, the radio's own end of a play included; a poll
      // would cost thirteen lines a second for nothing.
      fakeAsync((async) {
        connect();
        session.playVoiceMemory(3);
        sink.sent.clear();
        async.elapse(const Duration(seconds: 2));
        expect(commands(), isEmpty);
        session.teardown();
        async.flushTimers();
      });
    });

    test('another slot, or another client previewing, is not this play going on', () {
      fakeAsync((async) {
        connect();
        session.playVoiceMemory(3);
        session.feed('S7C1A8533|dvk status=playback id=3\n');
        async.elapse(const Duration(seconds: 1));
        session.feed('S7C1A8533|dvk status=preview id=4\n');
        expect(sink.voices.last, isNull);
        session.teardown();
        async.flushTimers();
      });
    });

    test('a refused start is doubted at once, then stopped and cleared', () {
      // An error answer arrives in milliseconds — before the tracker would
      // believe a poll's "not going" — and is the only word a radio without
      // the licence, or with an empty slot, ever gives.
      fakeAsync((async) {
        connect();
        session.playVoiceMemory(5);
        session.feed('R${seqOf('dvk playback_start id=5')}|50000016|\n');
        expect(sink.voices.last, const VoiceActivity(memory: 5, doubtful: true));
        expect(sink.diagnostics.last, contains('0x50000016'));
        async.elapse(voiceDoubtLinger);
        expect(commands(), contains('dvk playback_stop'));
        expect(sink.voices.last, isNull);
        session.teardown();
        async.flushTimers();
      });
    });

    test('an accepted start is not doubted by its reply', () {
      fakeAsync((async) {
        connect();
        session.playVoiceMemory(3);
        session.feed('R${seqOf('dvk playback_start id=3')}|0|\n');
        expect(sink.voices, [const VoiceActivity(memory: 3)]);
        session.teardown();
        async.flushTimers();
      });
    });

    test("a play the radio never ends is stopped just past the slot's own length", () {
      // The radio said how long slot 3 runs, so fifteen seconds of
      // "playing" for a two-second memory would be a guess beaten by a fact.
      fakeAsync((async) {
        connect();
        session.playVoiceMemory(3);
        // Kept "going" by every poll, so only the ceiling can end it.
        void playing() => session.feed('S7C1A8533|dvk status=playback id=3\n');
        playing();
        async.elapse(const Duration(milliseconds: 2165 + 2900));
        playing();
        expect(sink.voices.last, isNotNull);
        async.elapse(const Duration(milliseconds: 200));
        expect(commands(), contains('dvk playback_stop'));
        expect(sink.voices.last, isNull);
        session.teardown();
        async.flushTimers();
      });
    });

    test('records with rec_start and stops with a bare rec_stop', () {
      fakeAsync((async) {
        connect();
        expect(session.canRecordVoice, isTrue);
        session.recordVoiceMemory(2);
        expect(commands(), ['dvk rec_start id=2']);
        expect(sink.voices.last, const VoiceActivity(memory: 2, recording: true));
        sink.sent.clear();
        session.stopVoice();
        expect(commands(), ['dvk rec_stop'], reason: 'the radio pushes the new length itself');
        expect(sink.voices.last, isNull);
        session.teardown();
        async.flushTimers();
      });
    });

    test('a memory pressed while another plays stops the one on the air first', () {
      // Once the tracker follows M4, nothing would stop M1 — it would
      // transmit to its end behind a strip showing M4 — and the API
      // reference warns that an operation started over another can leave
      // the keyer inconsistent.
      fakeAsync((async) {
        connect();
        session.playVoiceMemory(1);
        sink.sent.clear();
        session.playVoiceMemory(4);
        expect(commands(), ['dvk playback_stop', 'dvk playback_start id=4']);
        session.teardown();
        async.flushTimers();
      });
    });

    test('a refusal of an earlier start does not doubt a later play of the same memory', () {
      fakeAsync((async) {
        connect();
        session.playVoiceMemory(1);
        final first = seqOf('dvk playback_start id=1');
        session.playVoiceMemory(1);
        session.feed('R${seqOf('dvk playback_start id=1')}|0|\n');
        session.feed('R$first|50000016|\n');
        expect(sink.voices.last, const VoiceActivity(memory: 1), reason: 'the play the radio accepted is the one on the air');
        session.teardown();
        async.flushTimers();
      });
    });

    test('a refused rename asks the radio again, so the slot does not keep a name it never took', () {
      fakeAsync((async) {
        connect();
        session.renameVoiceMemory(3, 'CQ contest');
        final rename = seqOf('dvk set_name');
        sink.sent.clear();
        session.feed('R$rename|50000016|\n');
        expect(commands(), ['sub dvk all']);
        expect(sink.diagnostics.last, contains('rename memory 3'));
        session.teardown();
        async.flushTimers();
      });
    });

    test('a stop names no slot: there is one keyer, doing one thing', () {
      fakeAsync((async) {
        connect();
        session.playVoiceMemory(4);
        sink.sent.clear();
        session.stopVoice();
        expect(commands(), ['dvk playback_stop']);
        session.teardown();
        async.flushTimers();
      });
    });

    test('renames on the radio, as the radio will hold the name, an empty one back to its default', () {
      fakeAsync((async) {
        connect();
        session.renameVoiceMemory(3, 'Say "hi"  |  there');
        // No `"` or `|`, which the API forbids; runs of spaces collapse as
        // the radio collapses them, so what shows is what it will hold.
        expect(commands(), ['dvk set_name id=3 name="Say hi there"']);
        expect(
          sink.memoryLists.last[2],
          const VoiceMemory(memory: 3, name: 'Say hi there', durationMs: 2165),
          reason: 'shown at once, not after the round trip',
        );
        sink.sent.clear();
        session.renameVoiceMemory(3, 'x' * 70);
        expect(commands().single, 'dvk set_name id=3 name="${'x' * 61}"', reason: 'the radio takes 61 characters inside the quotes');
        sink.sent.clear();
        session.renameVoiceMemory(3, '  ');
        expect(commands().single, 'dvk set_name id=3 name="Recording 3"');
        expect(sink.memoryLists.last[2].name, '');
        session.teardown();
        async.flushTimers();
      });
    });

    test('the radio pushing a slot back renamed updates it', () {
      // The bare `id=` form, pushed after a rename, a recording or a clear.
      session.feed('${_dvkStatusLines.join('\n')}\n');
      session.feed('S5A3C2B1F|dvk id=3 name="CQ Contest" duration=4210\n');
      expect(sink.memoryLists.last[2], const VoiceMemory(memory: 3, name: 'CQ Contest', durationMs: 4210));
    });

    test('an empty slot is refused here, never sent', () {
      // Per the API reference a play of an empty slot answers 0 and can
      // leave the radio keyed.
      fakeAsync((async) {
        connect();
        session.playVoiceMemory(2);
        expect(commands().where((c) => c.startsWith('dvk playback_start')), isEmpty);
        expect(sink.voices.last, const VoiceActivity(memory: 2, doubtful: true));
        async.elapse(voiceDoubtLinger);
        expect(sink.voices.last, isNull);
        session.teardown();
        async.flushTimers();
      });
    });

    test('an unlicensed answer to any dvk command turns the keyer off', () {
      // The API reference's own word for an unlicensed radio — the status
      // line's enabled= says nothing about the licence.
      fakeAsync((async) {
        connect();
        session.playVoiceMemory(3);
        session.feed('R${seqOf('dvk playback_start id=3')}|50004001|\n');
        expect(session.voiceMemoryCount, 0);
        expect(sink.memoryLists.last, isEmpty);
        expect(sink.voices.last, const VoiceActivity(memory: 3, doubtful: true));
        session.teardown();
        async.flushTimers();
      });
    });

    test('a status saying disabled, or enabled=0, holds no memories until it says otherwise', () {
      session.feed('${_dvkStatusLines.join('\n')}\n');
      session.feed('S7C1A8533|dvk status=disabled enabled=1\n');
      expect(session.voiceMemoryCount, 0);
      session.feed('S7C1A8533|dvk status=idle enabled=0\n');
      expect(session.voiceMemoryCount, 0);
      session.feed('S7C1A8533|dvk status=idle enabled=1\n');
      expect(session.voiceMemoryCount, maxVoiceMemories);
      expect(sink.memoryLists.last, hasLength(maxVoiceMemories));
    });

    test('a licence value that is neither 0 nor 1 says nothing', () {
      session.feed('S53C4018F|license feature name=DIGITAL_VOICE_KEYER enabled=maybe reason=PLUS\n');
      expect(session.voiceMemoryCount, maxVoiceMemories);
    });

    test('a keyer the licence turns off holds no memories, and says so the moment it is told', () {
      // A FLEX without SmartSDR+ is a radio with no voice keyer: its keys
      // disabled and F1-F8 free, like any other radio without one — not
      // eight live keys whose every press the radio refuses.
      fakeAsync((async) {
        connect();
        expect(session.voiceMemoryCount, maxVoiceMemories, reason: 'nothing said about the licence yet: offered');
        // As captured, but for the flag.
        session.feed('S53C4018F|license feature name=DIGITAL_VOICE_KEYER enabled=0 reason=PLUS\n');
        expect(session.voiceMemoryCount, 0);
        expect(sink.memoryLists.last, isEmpty, reason: 'the report is what makes the surfaces read the new count');
        expect(sink.problems.whereType<String>(), isEmpty, reason: 'a radio without the licence is not a radio with a problem');
        session.feed('S53C4018F|license feature name=DIGITAL_VOICE_KEYER enabled=1 reason=PLUS\n');
        expect(session.voiceMemoryCount, maxVoiceMemories);
        expect(sink.memoryLists.last[2].name, '59-NY-TU', reason: 'the slots come back with the licence');
        session.teardown();
        async.flushTimers();
      });
    });

    test('an unlicensed answer before the slots still holds none', () {
      fakeAsync((async) {
        session.feed('${_handshakeLines.join('\n')}\n');
        session.startUpdates();
        session.feed('S53C4018F|license feature name=DIGITAL_VOICE_KEYER enabled=0 reason=PLUS\n');
        session.feed('${_dvkStatusLines.join('\n')}\n');
        expect(sink.memoryLists.last, isEmpty);
        session.teardown();
        async.flushTimers();
      });
    });

    test('other licence features say nothing about the keyer', () {
      session.feed('S53C4018F|license feature name=ALPHA enabled=0 reason=LICENSE_FILE\n');
      expect(session.voiceMemoryCount, maxVoiceMemories);
    });

    test('teardown stops a memory on the air', () {
      // A memory transmits, and nothing else will stop it once this client
      // has gone.
      fakeAsync((async) {
        connect();
        session.playVoiceMemory(3);
        sink.sent.clear();
        session.teardown();
        expect(commands().first, 'dvk playback_stop');
        expect(sink.voices.last, isNull);
        async.flushTimers();
      });
    });

    test('the driver offers a memory per function key, before any connection', () {
      expect(const FlexRadioDriver().voiceMemoryCountWith(const {}), maxVoiceMemories);
    });
  });

  group('a raw command', () {
    test('takes the next sequence number, so the driver\'s next command does not reuse it', () {
      // Sent to the socket as given, `C1|…` would collide with whatever the
      // driver numbers next, and the driver would take the extension's answer
      // for its own.
      fakeAsync((async) {
        final answers = <String>[];
        expect(session.sendRaw(utf8.encode('slice set 0 nr=1\n'), onAnswer: (r) => answers.add(utf8.decode(r))), 1);
        session.setFrequency(14200);
        expect(sink.sent.first, 'C1|slice set 0 nr=1\n');
        expect(sink.sent[1], startsWith('C2|slice tune 0 '));

        session.feed('S0|slice 0 nr=1\n');
        session.feed('R2|0|\n');
        expect(answers, isEmpty, reason: 'neither a status push nor another command\'s answer is its answer');
        session.feed('R1|50000015|Invalid slice\n');
        expect(answers, ['R1|50000015|Invalid slice\n']);

        session.teardown();
        async.flushTimers();
      });
    });

    test('of several lines numbers each one, and each is answered by its own R line', () {
      // Numbered as one, the second line would reach the radio with no
      // `C<seq>|` at all — not a command it takes.
      final answers = <String>[];
      expect(session.sendRaw(utf8.encode('slice set 0 nr=1\r\n\nslice set 0 nb=1\n'), onAnswer: (r) => answers.add(utf8.decode(r))), 2);
      expect(sink.sent, ['C1|slice set 0 nr=1\n', 'C2|slice set 0 nb=1\n'], reason: 'blank lines are no command');
      session.feed('R1|0|\n');
      session.feed('R2|0|\n');
      expect(answers, ['R1|0|\n', 'R2|0|\n']);
    });

    test('with no command in it is not sent', () {
      expect(() => session.sendRaw(utf8.encode(' \n ')), throwsFormatException);
      expect(sink.sent, isEmpty);
    });
  });
}

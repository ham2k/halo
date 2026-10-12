// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Icom CI-V driver and its serial equipment type, with no radio.
//
// Most of what's asserted here is bus discipline. CI-V is a shared bus: the
// radio echoes what you send it, other controllers may be talking on the
// same wire, and a wrong address produces silence rather than an error.
// app-polo's driver checked none of that.

import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/civ_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/icom_civ_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/drivers/meter_calibration.dart';
import 'package:ham2k_logger/services/cat/drivers/poll_config.dart';
import 'package:ham2k_logger/services/cat/telemetry_poller.dart';
import 'package:ham2k_logger/services/cat/transports/serial_transport.dart';

/// Just long enough for the radio's silence to count as no answer.
final _pastAnswerTimeout = civAnswerTimeout + const Duration(milliseconds: 10);

class _FakeSink implements EquipmentSink, TunerSink, PassbandSink {
  final problems = <String?>[];
  List<EquipmentChannel> channels = const [];
  final sent = <List<int>>[];
  final readings = <VfoReading>[];
  final powers = <num>[];
  final keyerSpeeds = <int>[];
  final diagnostics = <String?>[];

  /// The radio's side of the bus, for a CI-V session: answers every command
  /// with an ACK, as a radio does, so the driver's one-command-at-a-time
  /// sending moves on. Null is a radio that answers nothing.
  void Function(Uint8List frame)? answer;

  @override
  void send(List<int> bytes) {
    sent.add(bytes);
    answer?.call(Uint8List.fromList([0xFE, 0xFE, bytes[3], bytes[2], 0xFB, 0xFD]));
  }

  @override
  void report(VfoReading reading) => readings.add(reading);

  @override
  void reportPower(num watts) => powers.add(watts);

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
  @override
  void reportVoiceActivity(VoiceActivity? activity) {}

  @override
  void reportVoiceMemories(List<VoiceMemory> memories) {}

  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);
  @override
  void reportProblem(String? message) => problems.add(message);

  @override
  void reportChannels(List<EquipmentChannel> channels) => this.channels = channels;

  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
  var alive = 0;
  @override
  void reportAlive() => alive++;

  final tuners = <TunerStatus?>[];
  @override
  void reportTuner(TunerStatus? status) => tuners.add(status);

  final passbands = <Passband?>[];
  @override
  void reportPassband(Passband? passband) => passbands.add(passband);
}

void main() {
  const ic705 = 0xA4;
  const us = civDefaultControllerAddress;

  late _FakeSink sink;
  late IcomCivSession session;

  setUp(() {
    sink = _FakeSink();
    session = IcomCivSession(sink, radioAddress: ic705, controllerAddress: us);
    sink.answer = session.handleData;
  });

  void feed(List<int> bytes) => session.handleData(Uint8List.fromList(bytes));

  group('reading the radio', () {
    test('an answer to our read becomes a VFO reading in kHz', () {
      feed([0xFE, 0xFE, us, ic705, 0x03, 0x00, 0x40, 0x07, 0x14, 0x00, 0xFD]);
      expect(sink.readings, [const VfoReading(freqKHz: 14074)]);
    });

    test('an unsolicited transceive announcement is read the same way', () {
      // Broadcast, command 0x00 — what the radio sends on its own when
      // transceive is on and the operator turns the dial.
      feed([0xFE, 0xFE, 0x00, ic705, 0x00, 0x00, 0x40, 0x07, 0x14, 0x00, 0xFD]);
      expect(sink.readings, [const VfoReading(freqKHz: 14074)]);
    });

    group('expectedUpdateInterval', () {
      // Nothing in CI-V asks whether transceive is on, so the driver has to
      // notice. Getting it wrong is invisible either way — readings arrive —
      // but Smart VFO Snap adds this to its settle delay, so claiming the
      // 5s poll on a radio that announces in milliseconds makes the feature
      // feel broken, and claiming none when the poll IS the cadence settles
      // a snap in the silence between polls.
      test('claims the poll rate until the radio proves it announces', () {
        expect(session.expectedUpdateInterval, const Duration(seconds: 5));
        // An answer to OUR read (0x03) proves nothing about transceive.
        feed([0xFE, 0xFE, us, ic705, 0x03, 0x00, 0x40, 0x07, 0x14, 0x00, 0xFD]);
        expect(session.expectedUpdateInterval, const Duration(seconds: 5));
      });

      test("the poll rate claimed is the node's own, when it sets one", () {
        // The claim is what Smart VFO Snap waits on, so it has to move with
        // the poll it describes.
        final slow = IcomCivDriver().createSession(sink, const {'civAddress': 'A4', pollIntervalConfigKey: 10000}) as IcomCivSession;
        expect(slow.expectedUpdateInterval, const Duration(seconds: 10));
      });

      test('stops claiming one as soon as the radio announces on its own', () {
        feed([0xFE, 0xFE, 0x00, ic705, 0x00, 0x00, 0x40, 0x07, 0x14, 0x00, 0xFD]);
        expect(session.expectedUpdateInterval, isNull);
        // Transceive is a menu setting, not something that lapses between
        // frames — a later poll answer must not take the claim back.
        feed([0xFE, 0xFE, us, ic705, 0x03, 0x00, 0x40, 0x07, 0x14, 0x00, 0xFD]);
        expect(session.expectedUpdateInterval, isNull);
      });
    });

    test('mode comes through, filter byte and all', () {
      feed([0xFE, 0xFE, us, ic705, 0x04, 0x03, 0x01, 0xFD]);
      expect(sink.readings, [const VfoReading(mode: 'CW')]);
    });

    // The mode answer never says DATA. Reported as plain USB, a rig running
    // FT8 in USB-D would put USB in the log.
    test('USB with the DATA submode on reports as DATA-USB', () {
      feed([0xFE, 0xFE, us, ic705, 0x04, 0x01, 0x01, 0xFD]);
      feed([0xFE, 0xFE, us, ic705, 0x1A, 0x06, 0x01, 0x01, 0xFD]);
      expect(sink.readings.last, const VfoReading(mode: 'DATA-USB'));
      feed([0xFE, 0xFE, us, ic705, 0x1A, 0x06, 0x00, 0x00, 0xFD]);
      expect(sink.readings.last, const VfoReading(mode: 'USB'));
    });

    // A band recall can bring DATA with it, and the announcement is only the
    // base mode: without the follow-up read the flag stays stale until the
    // next poll.
    test('a mode the radio announces on its own asks after the DATA submode', () {
      feed([0xFE, 0xFE, 0x00, ic705, 0x01, 0x01, 0x01, 0xFD]);
      expect(sink.sent.single, [0xFE, 0xFE, ic705, us, 0x1A, 0x06, 0xFD]);
    });

    test('keeps sub-kHz precision the way CI-V reports it', () {
      // CI-V carries down to 1 Hz; 14074123 Hz.
      feed([0xFE, 0xFE, us, ic705, 0x03, 0x23, 0x41, 0x07, 0x14, 0x00, 0xFD]);
      expect(sink.readings.single.freqKHz, closeTo(14074.123, 0.0001));
    });

    test('a 0x14 0x0A reply reports power, against the assumed 100W ceiling', () {
      // Level 255 (0x02 0x55 BCD) is 100% of the assumed maximum.
      feed([0xFE, 0xFE, us, ic705, 0x14, 0x0A, 0x02, 0x55, 0xFD]);
      expect(sink.powers, [100]);
    });

    test('a 0x14 reply for a DIFFERENT level (not RF power) is ignored', () {
      // 0x14 covers AF/RF gain/squelch too; only sub-command 0x0A is power.
      feed([0xFE, 0xFE, us, ic705, 0x14, 0x01, 0x02, 0x55, 0xFD]);
      expect(sink.powers, isEmpty);
    });

    test('a level that is not a clean multiple of the 100W ceiling rounds to whole watts', () {
      // Level 195 (0x01 0x95 BCD) -> 195/255*100 = 76.47...W. Reporting
      // that raw double would overflow the Power field's 4-digit width
      // and store false precision on a captured QSO.
      feed([0xFE, 0xFE, us, ic705, 0x14, 0x0A, 0x01, 0x95, 0xFD]);
      expect(sink.powers, [76]);
    });

    test('a QRP radio configured with a real ceiling reports fractional watts', () {
      // Below _preciseWattsCeiling the 0-255 level actually resolves to
      // sub-watt steps, unlike the assumed-100W case above — rounding away
      // the decimal would throw away real information, not false precision.
      final qrpSession = IcomCivSession(sink, radioAddress: ic705, controllerAddress: us, maxWatts: 10);
      // Level 195 (0x01 0x95 BCD) -> 195/255*10 = 7.647...W -> 7.6W.
      qrpSession.handleData(Uint8List.fromList([0xFE, 0xFE, us, ic705, 0x14, 0x0A, 0x01, 0x95, 0xFD]));
      expect(sink.powers, [7.6]);
    });

    test('setPower against a 10W ceiling scales the level down accordingly', () {
      final qrpSession = IcomCivSession(sink, radioAddress: ic705, controllerAddress: us, maxWatts: 10);
      qrpSession.setPower(5);
      // 5/10*255 = 127.5 -> rounds to 128 (0x01 0x28 BCD).
      expect(sink.sent.single, [0xFE, 0xFE, ic705, us, 0x14, 0x0A, 0x01, 0x28, 0xFD]);
    });

    test('a 0x15 0x15 reply is kept as DC input, decivolts — the raw voltage is not surfaced itself', () {
      // Level 115 (BCD 0x01 0x15) -> 11.5V, matching a bench IC-705 on its
      // internal battery. No power level has been read yet, so there is
      // nothing for batteryMaxWatts to recompute — see the battery group
      // below for that.
      feed([0xFE, 0xFE, us, ic705, 0x15, 0x15, 0x01, 0x15, 0xFD]);
      expect(session.dcInputMeterLevel, 115);
      expect(sink.powers, isEmpty);
    });

    test('a 0x15 reply for a DIFFERENT meter (not DC input) is ignored', () {
      // 0x15 covers several meters (S-meter, RF power…) sharing one command
      // number; only sub-command 0x15 is DC input.
      feed([0xFE, 0xFE, us, ic705, 0x15, 0x11, 0x00, 0x50, 0xFD]);
      expect(session.dcInputMeterLevel, isNull);
    });
  });

  group('one command on the wire at a time', () {
    // An IC-7300 keeps only the LAST of several commands that arrive back to
    // back: sent as a burst, the poll's five queries get one answer, and the
    // frequency read, being first, never does. Each test here runs against a
    // serial radio that answers only when the test says so.
    setUp(() => session = IcomCivSession(sink, radioAddress: ic705, controllerAddress: us, config: const {'baudRate': 19200}));

    List<int> commands() => [for (final frame in sink.sent) frame[4]];

    /// The radio acknowledging whatever is on the wire, [times] times.
    void ack([int times = 1]) {
      for (var i = 0; i < times; i++) {
        feed(_fromRadio([0xFB]));
      }
    }

    test('the next command waits for the radio to answer the last', () {
      fakeAsync((async) {
        session.startUpdates();
        expect(commands(), [0x03], reason: 'the frequency read alone, not the burst');
        feed(_fromRadio([0x03, 0x00, 0x40, 0x07, 0x14, 0x00]));
        expect(commands(), [0x03, 0x1A]);
        // An ACK or a NAK answers too: CI-V's answers name no command.
        feed(_fromRadio([0xFB]));
        feed(_fromRadio([0xFA]));
        expect(commands(), [0x03, 0x1A, 0x04, 0x14]);
        session.teardown();
      });
    });

    test('a command the radio never answers holds the rest back only briefly', () {
      // Without the timeout one lost frame would stop the session talking.
      fakeAsync((async) {
        session.startUpdates();
        async.elapse(_pastAnswerTimeout);
        expect(commands(), [0x03, 0x1A]);
        // Said, once: a command the radio ignores costs a timeout on every
        // poll, and nothing else would show it.
        expect(sink.diagnostics, ['radio did not answer CI-V command 0x03 in time']);
        async.elapse(const Duration(seconds: 1));
        expect(sink.diagnostics, hasLength(1));
        session.teardown();
      });
    });

    test('a radio that answers slowly is not talked over', () {
      // Inside the radio CI-V is one half-duplex line: a command sent while an
      // answer is still going out collides with it, and the radio may take
      // the wreckage for a command of its own — a tuning step, a frequency
      // nobody asked for. hamlib waits 700-1000 ms on these radios.
      fakeAsync((async) {
        session.startUpdates();
        async.elapse(const Duration(milliseconds: 900));
        expect(commands(), [0x03]);
        feed(_fromRadio([0x03, 0x00, 0x40, 0x07, 0x14, 0x00]));
        expect(commands(), [0x03, 0x1A]);
        expect(sink.diagnostics, isEmpty, reason: 'a slow answer is an answer');
        session.teardown();
      });
    });

    test('the network pairing waits as long, since its answers cross WiFi', () {
      // A timeout under the link's jitter sends the next command over one
      // still pending — the burst the wait exists to prevent.
      fakeAsync((async) {
        final network = IcomCivSession(sink, radioAddress: ic705, controllerAddress: us);
        network.startUpdates();
        async.elapse(const Duration(milliseconds: 900));
        expect(commands(), [0x03]);
        network.teardown();
      });
    });

    test('an answer arriving after its command timed out does not free the wire', () {
      // Taken as the answer to what is waiting now, a late reply would send
      // the next command over it.
      fakeAsync((async) {
        session.startUpdates();
        async.elapse(_pastAnswerTimeout);
        expect(commands(), [0x03, 0x1A]);
        feed(_fromRadio([0x03, 0x00, 0x40, 0x07, 0x14, 0x00]));
        expect(commands(), [0x03, 0x1A]);
        session.teardown();
      });
    });

    test('a band change reaches the radio whole and in order, behind a busy wire', () {
      // A band change restates its frequency after its mode (cat.md § The
      // VFO); merged with the first as a duplicate, the restatement would
      // be lost exactly when the queue was busy.
      fakeAsync((async) {
        session.startUpdates();
        sink.sent.clear();
        session.setFrequency(14074);
        session.setMode('USB');
        session.setFrequency(14074);
        ack(20);
        final sets = commands().where((c) => c == 0x05 || c == 0x06).toList();
        expect(sets, [0x05, 0x06, 0x05]);
        session.teardown();
      });
    });

    test('a keyer speed set twice is read back after the second set', () {
      // Merging the second read-back into the first would read the speed
      // before the radio took the second set, and pace CW at the old one.
      session.setKeyerSpeed(20);
      session.setKeyerSpeed(25);
      ack(4);
      expect(
        [for (final f in sink.sent) f.sublist(4, 6)],
        [
          [0x14, 0x0C],
          [0x14, 0x0C],
          [0x14, 0x0C],
          [0x14, 0x0C],
        ],
      );
      expect(sink.sent[1].length, 7, reason: 'a read');
      expect(sink.sent[2].length, greaterThan(7), reason: 'the second set, after the first read');
      expect(sink.sent[3].length, 7, reason: 'its own read');
    });

    test('a stop goes ahead of everything waiting, and takes queued CW with it', () {
      // Behind the telemetry reads a stop waits while the rig keeps
      // keying, and a CW chunk still in the queue would key after it.
      fakeAsync((async) {
        session.startUpdates();
        session.sendCw('CQ CQ');
        session.stopCw();
        sink.sent.clear();
        ack();
        expect(sink.sent.first.sublist(4), [0x17, 0xFF, 0xFD]);
        ack(10);
        expect(sink.sent.where((f) => f[4] == 0x17), hasLength(1), reason: 'the stop, and no text after it');
        session.teardown();
      });
    });

    test('a PTT set goes ahead of everything waiting, and a newer one replaces it', () {
      // Behind the poll's reads an unkey waits an exchange per read with the
      // transmitter on. And a key still queued behind an unkey placed ahead
      // of it would go out second and put the radio back on the air.
      fakeAsync((async) {
        session.startUpdates();
        session.setPtt(true);
        session.setPtt(false);
        sink.sent.clear();
        ack();
        expect(sink.sent.first.sublist(4), [0x1C, 0x00, 0x00, 0xFD]);
        ack(10);
        expect(sink.sent.where((f) => f.length == 8 && f[4] == 0x1C), hasLength(1), reason: 'the unkey, and no key after it');
        session.teardown();
      });
    });

    test('teardown unkeys straight to the wire, not behind the exchange in flight', () {
      // The connection closes right after: an unkey left in the queue for an
      // answer that never comes is never sent, and the transmitter stays on
      // the air with nothing left to turn it off.
      fakeAsync((async) {
        session.startUpdates();
        session.setPtt(true);
        sink.sent.clear();
        session.teardown();
        expect(sink.sent, [
          [0xFE, 0xFE, ic705, us, 0x1C, 0x00, 0x00, 0xFD],
        ]);
      });
    });

    test('an announcement the radio makes on its own does not free the wire', () {
      // A transceive broadcast arrives whenever the dial moves; taken as an
      // answer, it would send the next command over the one still pending.
      fakeAsync((async) {
        session.startUpdates();
        feed([0xFE, 0xFE, 0x00, ic705, 0x00, 0x00, 0x40, 0x07, 0x14, 0x00, 0xFD]);
        expect(commands(), [0x03]);
        session.teardown();
      });
    });

    test('a radio that answers nothing does not pile up polls behind it', () {
      // The TX watch alone asks five times a second; queued without merging,
      // a radio switched off for a minute would be answered a minute of
      // stale questions when it came back.
      fakeAsync((async) {
        session.startUpdates();
        async.elapse(const Duration(seconds: 30));
        sink.sent.clear();
        sink.answer = session.handleData;
        feed(_fromRadio([0xFB]));
        expect(sink.sent.length, lessThan(8));
        session.teardown();
      });
    });
  });

  group('the link is alive whenever the radio speaks', () {
    test('an answer carrying no VFO reading still proves the radio is there', () {
      // Without this, a radio answering only the TX watch is marked not
      // responding while it answers five times a second.
      feed(_fromRadio([0x1C, 0x00, 0x00]));
      feed(_fromRadio([0x15, 0x15, 0x01, 0x27]));
      expect(sink.alive, 2);
    });

    test('another radio on the bus proves nothing about ours', () {
      feed([0xFE, 0xFE, us, 0x94, 0x1C, 0x00, 0x00, 0xFD]);
      expect(sink.alive, 0);
    });
  });

  group('batteryMaxWatts — a lower cap while off external DC', () {
    IcomCivSession qrpSession() => IcomCivSession(sink, radioAddress: ic705, controllerAddress: us, maxWatts: 10, batteryMaxWatts: 5);
    void feedTo(IcomCivSession s, List<int> bytes) => s.handleData(Uint8List.fromList(bytes));
    List<int> levelFrame(int hi, int lo) => [0xFE, 0xFE, us, ic705, 0x14, 0x0A, hi, lo, 0xFD];
    List<int> dcInputFrame(int hi, int lo) => [0xFE, 0xFE, us, ic705, 0x15, 0x15, hi, lo, 0xFD];

    test('a level above the cap is clamped once the radio is known to be on battery', () {
      final s = qrpSession();
      feedTo(s, dcInputFrame(0x01, 0x15)); // 11.5V — battery.
      // Level 255 (0x02 0x55) -> 10W against the 10W ceiling, capped to 5.
      feedTo(s, levelFrame(0x02, 0x55));
      expect(sink.powers, [5]);
    });

    test('the same level is reported uncapped once external DC is seen', () {
      final s = qrpSession();
      feedTo(s, dcInputFrame(0x01, 0x95)); // 19.5V — external supply.
      feedTo(s, levelFrame(0x02, 0x55));
      expect(sink.powers, [10]);
    });

    test('a level below the cap is unaffected either way', () {
      final s = qrpSession();
      feedTo(s, dcInputFrame(0x01, 0x15)); // battery
      // Level 102 (0x01 0x02) -> 102/255*10 = 4W.
      feedTo(s, levelFrame(0x01, 0x02));
      expect(sink.powers, [4]);
    });

    test('unplugging mid-session re-caps the already-reported level', () {
      final s = qrpSession();
      feedTo(s, dcInputFrame(0x01, 0x95)); // starts on external DC
      feedTo(s, levelFrame(0x02, 0x55)); // 10W, unaffected
      feedTo(s, dcInputFrame(0x01, 0x15)); // now on battery
      expect(sink.powers, [10, 5], reason: 'the DC-input reading alone recomputes the last known level');
    });

    test('with no batteryMaxWatts configured, battery power is never capped', () {
      final s = IcomCivSession(sink, radioAddress: ic705, controllerAddress: us, maxWatts: 10);
      feedTo(s, dcInputFrame(0x01, 0x15)); // battery
      feedTo(s, levelFrame(0x02, 0x55));
      expect(sink.powers, [10]);
    });

    test('with no DC-input reading yet, power is reported uncapped', () {
      final s = qrpSession();
      feedTo(s, levelFrame(0x02, 0x55));
      expect(sink.powers, [10], reason: 'unknown DC input must not be treated as battery');
    });
  });

  group('bus discipline — what polo did not do', () {
    test('our own echo is not read back as the radio reporting', () {
      // The radio reflects what we send. Without this the driver reads its
      // own set-frequency as confirmation, so every command looks like it
      // worked — including ones the radio went on to reject.
      session.setFrequency(14074);
      final ourFrame = sink.sent.single;
      feed(ourFrame);
      expect(sink.readings, isEmpty);
    });

    test('traffic for another controller on the same bus is ignored', () {
      feed([0xFE, 0xFE, 0xE1, ic705, 0x03, 0x00, 0x40, 0x07, 0x14, 0x00, 0xFD]);
      expect(sink.readings, isEmpty);
    });

    test('a different radio on the same bus is ignored', () {
      // An IC-7300 (0x94) answering its own controller.
      feed([0xFE, 0xFE, us, 0x94, 0x03, 0x00, 0x40, 0x07, 0x14, 0x00, 0xFD]);
      expect(sink.readings, isEmpty);
    });

    test('an NG is not mistaken for data, and does not report a reading', () {
      feed([0xFE, 0xFE, us, ic705, 0xFA, 0xFD]);
      expect(sink.readings, isEmpty);
    });

    test('an ACK is consumed quietly', () {
      feed([0xFE, 0xFE, us, ic705, 0xFB, 0xFD]);
      expect(sink.readings, isEmpty);
    });
  });

  group('commanding the radio', () {
    test('PTT keys with 0x1C 0x00 0x01 and unkeys with 0x1C 0x00 0x00', () {
      session.setPtt(true);
      session.setPtt(false);
      expect(sink.sent, [
        [0xFE, 0xFE, ic705, us, 0x1C, 0x00, 0x01, 0xFD],
        [0xFE, 0xFE, ic705, us, 0x1C, 0x00, 0x00, 0xFD],
      ]);
      expect(sink.txReports, isEmpty, reason: 'keyed is what the TX watch hears, never what was asked');
    });

    test('teardown sends no unkey on a radio the app never keyed', () {
      // An unkey from a session that never keyed would cut off the operator
      // transmitting from the radio's own mic.
      session.teardown();
      expect(sink.sent.where((f) => f.length == 8 && f[4] == 0x1C), isEmpty);
    });

    test('set frequency is a CI-V frame with BCD payload', () {
      session.setFrequency(14074);
      expect(sink.sent.single, [0xFE, 0xFE, ic705, us, 0x05, 0x00, 0x40, 0x07, 0x14, 0x00, 0xFD]);
    });

    test('set mode leaves the operator filter alone', () {
      session.setMode('USB');
      // No trailing filter byte: polo sent 01 every time, forcing FIL1.
      expect(sink.sent.first, [0xFE, 0xFE, ic705, us, 0x06, 0x01, 0xFD]);
    });

    // CI-V has no FT8 or DATA-USB mode code. Without the submode, a data mode
    // sends nothing and the rig keeps whatever a band recall brought back.
    test('a data mode is its base mode with the DATA submode switched on', () {
      feed([0xFE, 0xFE, us, ic705, 0x04, 0x01, 0x02, 0xFD]);
      sink.sent.clear();
      session.setMode('DATA-USB');
      expect(sink.sent, [
        [0xFE, 0xFE, ic705, us, 0x06, 0x01, 0xFD],
        [0xFE, 0xFE, ic705, us, 0x1A, 0x06, 0x01, 0x02, 0xFD],
      ], reason: "D1 with USB's own filter, not a forced FIL1");
    });

    // Some radios keep DATA across a 0x06 mode set: plain USB after FT8 would
    // stay USB-D, and the log would say USB for a rig still in data.
    test('plain USB switches the DATA submode off', () {
      session.setMode('USB');
      expect(sink.sent.last, [0xFE, 0xFE, ic705, us, 0x1A, 0x06, 0x00, 0x00, 0xFD]);
    });

    // The poll's mode answer arrives before its DATA answer. Reported
    // against the flag from before the set, it says USB, and the log loses
    // the FT8 it was just told.
    test('a data mode just set is reported as set, before the radio confirms it', () {
      session.setMode('DATA-USB');
      feed([0xFE, 0xFE, us, ic705, 0x04, 0x01, 0x01, 0xFD]);
      expect(sink.readings.last, const VfoReading(mode: 'DATA-USB'));
    });

    test('the poll asks for DATA before the mode it is reported against', () {
      session.startUpdates();
      final commands = sink.sent.map((f) => f[4]).toList();
      expect(commands.indexOf(CivCommand.settings), lessThan(commands.indexOf(CivCommand.readMode)));
      session.teardown();
    });

    // The generic entry cannot pin the submode off for a radio that lacks it.
    // Left on, a flag taken as set reports DATA-USB for a rig in plain USB
    // for as long as the session lasts.
    group('on a serial radio without the submode', () {
      const readData = [0xFE, 0xFE, ic705, us, 0x1A, 0x06, 0xFD];

      setUp(() {
        session = IcomCivSession(sink, radioAddress: ic705, controllerAddress: us, config: const {'baudRate': 19200});
        sink.answer = null;
      });

      /// ACKs whatever is on the wire until the DATA read is, then answers
      /// the read with [reply] — a NAK, or nothing at all.
      void pollAndAnswerDataWith(FakeAsync async, List<int>? reply) {
        for (var i = 0; i < 20 && !listEquals(sink.sent.last, readData); i++) {
          feed(_fromRadio([0xFB]));
        }
        expect(sink.sent.last, readData);
        if (reply != null) {
          feed(_fromRadio(reply));
        } else {
          async.elapse(_pastAnswerTimeout);
        }
        // The mode answer behind it: the radio answering, so a silence was the read's own.
        feed(_fromRadio([0x04, 0x01, 0x01]));
        async.elapse(const Duration(seconds: 5));
      }

      test('a radio that refuses the DATA read twice stops being asked, and says so', () {
        fakeAsync((async) {
          session.startUpdates();
          session.setMode('DATA-USB');
          pollAndAnswerDataWith(async, [0xFA]);
          expect(sink.diagnostics.whereType<String>(), isNot(contains(contains('0x1A 0x06'))));
          pollAndAnswerDataWith(async, [0xFA]);
          expect(sink.readings.last, const VfoReading(mode: 'USB'));
          expect(sink.diagnostics.whereType<String>(), contains(contains('0x1A 0x06')));
          sink.sent.clear();
          session.setMode('DATA-USB');
          for (var i = 0; i < 20; i++) {
            feed(_fromRadio([0xFB]));
          }
          expect(sink.sent, contains(equals([0xFE, 0xFE, ic705, us, 0x06, 0x01, 0xFD])));
          expect(sink.sent.where((f) => f[4] == 0x1A && f[5] == 0x06), isEmpty, reason: 'the base mode alone, and no more DATA reads');
          session.teardown();
        });
      });

      test('one that ignores it takes a third silence, and stops being asked too', () {
        fakeAsync((async) {
          session.startUpdates();
          for (var i = 0; i < 2; i++) {
            pollAndAnswerDataWith(async, null);
          }
          expect(sink.diagnostics.whereType<String>(), isNot(contains(contains('0x1A 0x06'))), reason: 'two lost answers are a busy link');
          pollAndAnswerDataWith(async, null);
          expect(sink.diagnostics.whereType<String>(), contains(contains('0x1A 0x06')));
          session.teardown();
        });
      });
    });

    test('CW leaves the DATA submode alone, since it has none', () {
      session.setMode('CW');
      expect(sink.sent.single, [0xFE, 0xFE, ic705, us, 0x06, 0x03, 0xFD]);
    });

    test('a radio without the DATA submode is still put in the base mode', () {
      final ic706 = IcomCivSession(sink, radioAddress: 0x58, controllerAddress: us, config: const {civDataModeConfigKey: false});
      ic706.setMode('DATA-USB');
      expect(sink.sent.single, [0xFE, 0xFE, 0x58, us, 0x06, 0x01, 0xFD]);
    });

    test('a mode CI-V has no code for sends nothing', () {
      session.setMode('SSB');
      expect(sink.sent, isEmpty);
    });

    // A G90 ignores a mode set with no filter byte — frequency control works
    // and the mode never changes. Sending a fixed filter instead would force
    // the operator's selection, as polo did; the radio's own is sent back.
    group('on an entry that must send a filter', () {
      late IcomCivSession g90;
      setUp(() {
        g90 = IcomCivSession(sink, radioAddress: 0x88, controllerAddress: us, config: const {civModeWithFilterConfigKey: true, civDataModeConfigKey: false});
        // A CW answer asks after the filter width, and a radio that answered
        // nothing would hold every set behind that read.
        sink.answer = g90.handleData;
      });
      void feedG90(List<int> bytes) => g90.handleData(Uint8List.fromList(bytes));

      test('a mode not yet seen gets the filter currently in use', () {
        feedG90([0xFE, 0xFE, us, 0x88, 0x04, 0x01, 0x02, 0xFD]);
        sink.sent.clear();
        g90.setMode('CW');
        expect(sink.sent.single, [0xFE, 0xFE, 0x88, us, 0x06, 0x03, 0x02, 0xFD]);
      });

      // The radio keeps a filter per mode: sending USB's back to CW would
      // change the operator's CW filter on every switch.
      test('a mode already seen gets back the filter it had', () {
        feedG90([0xFE, 0xFE, us, 0x88, 0x04, 0x03, 0x03, 0xFD]);
        feedG90([0xFE, 0xFE, us, 0x88, 0x04, 0x01, 0x01, 0xFD]);
        sink.sent.clear();
        g90.setMode('CW');
        expect(sink.sent.single, [0xFE, 0xFE, 0x88, us, 0x06, 0x03, 0x03, 0xFD]);
      });

      // CatService never sends the same mode twice, so one dropped for want
      // of a filter would be lost rather than retried. And the answer that
      // releases it is the mode being replaced: reporting that would put the
      // operator's pick back on screen until the next poll.
      test('holds a mode set until the radio has answered, then sends it without reporting the old mode', () {
        g90.setMode('USB');
        expect(sink.sent, isEmpty);
        feedG90([0xFE, 0xFE, us, 0x88, 0x01, 0x00, 0x03, 0xFD]);
        expect(sink.sent.single, [0xFE, 0xFE, 0x88, us, 0x06, 0x01, 0x03, 0xFD]);
        expect(sink.readings, isEmpty);
      });

      // Waiting for a filter the radio never sends is the dead mode control
      // this entry exists to fix, reached by another road.
      test('a radio whose answers carry no filter still gets its mode set, with FIL1', () {
        g90.setMode('CW');
        feedG90([0xFE, 0xFE, us, 0x88, 0x04, 0x01, 0xFD]);
        expect(sink.sent.single, [0xFE, 0xFE, 0x88, us, 0x06, 0x03, 0x01, 0xFD]);
      });
    });

    test('set power is a 0x14 0x0A frame, watts converted against the assumed 100W ceiling', () {
      session.setPower(100);
      // Level 255 (0x02 0x55 BCD) for 100W against the assumed 100W max.
      expect(sink.sent.single, [0xFE, 0xFE, ic705, us, 0x14, 0x0A, 0x02, 0x55, 0xFD]);
    });

    group('CW keying', () {
      test('the keyer speed level is linear over 6-48 WPM, within a step of the radio\'s own table', () {
        expect(civLevelForKeyerSpeed(6), 0);
        expect(civLevelForKeyerSpeed(48), 255);
        // hamlib's table says 84; one step off is a rounding difference the
        // radio cannot display.
        expect(civLevelForKeyerSpeed(20), 85);
        expect(civKeyerSpeedForLevel(84), 20);
        expect(civKeyerSpeedForLevel(255), 48);
        expect(civLevelForKeyerSpeed(100), 255, reason: 'clamped, not sent out of range');
      });

      test('a 0x14 0x0C reply reports the keyer speed, and is not mistaken for power', () {
        feed([0xFE, 0xFE, us, ic705, 0x14, 0x0C, 0x00, 0x85, 0xFD]);
        expect(sink.keyerSpeeds, [20]);
        expect(sink.powers, isEmpty);
        expect(session.keyerSpeedRange, (min: 6, max: 48));
      });

      test('setting the speed sets the level and reads it back', () {
        session.setKeyerSpeed(20);
        expect(sink.sent, [
          [0xFE, 0xFE, ic705, us, 0x14, 0x0C, 0x00, 0x85, 0xFD],
          [0xFE, 0xFE, ic705, us, 0x14, 0x0C, 0xFD],
        ]);
      });

      test('a message is keyed with 0x17 as ASCII, and stopped with 0x17 0xFF', () {
        session.sendCw('cq k');
        expect(sink.sent.single, [0xFE, 0xFE, ic705, us, 0x17, 0x43, 0x51, 0x20, 0x4B, 0xFD]);
        session.stopCw();
        expect(sink.sent.last, [0xFE, 0xFE, ic705, us, 0x17, 0xFF, 0xFD]);
      });

      test('a message over 30 characters goes in paced pieces the radio will not NAK', () {
        fakeAsync((async) {
          feed([0xFE, 0xFE, us, ic705, 0x14, 0x0C, 0x00, 0x85, 0xFD]); // 20 WPM
          sink.sent.clear();

          session.sendCw('CQ CQ CQ DE N0DEV N0DEV N0DEV K');
          expect(sink.sent, hasLength(1));
          expect(sink.sent.single.length - 6, 29, reason: 'the first 29 characters end on a word boundary');
          expect(session.cwSending, isTrue);

          async.elapse(const Duration(seconds: 5));
          expect(sink.sent, hasLength(1), reason: 'the second 0x17 waits for the first to key');
          async.elapse(const Duration(seconds: 20));
          expect(sink.sent, hasLength(2));
          expect(sink.sent.last, [0xFE, 0xFE, ic705, us, 0x17, 0x4B, 0xFD]);

          async.flushTimers();
          expect(session.cwSending, isFalse);
        });
      });

      test('teardown drops a message still going out', () {
        fakeAsync((async) {
          session.sendCw('CQ CQ CQ DE N0DEV N0DEV N0DEV K');
          session.teardown();
          async.elapse(const Duration(minutes: 1));
          expect(sink.sent, hasLength(1));
        });
      });
    });

    test('a power outside 0-100W is clamped to the level range, not sent malformed', () {
      session.setPower(1000);
      expect(sink.sent.single, [0xFE, 0xFE, ic705, us, 0x14, 0x0A, 0x02, 0x55, 0xFD], reason: 'clamped to level 255');
    });

    test('polls for frequency and mode, and stops when told', () {
      fakeAsync((async) {
        session.startUpdates();
        expect(sink.sent, hasLength(7), reason: 'asks once immediately, the keyer speed and the tuner included');
        sink.sent.clear();

        // Counted apart from the TX watch, which runs on its own much
        // faster cadence (telemetry_poller.dart) and would otherwise swamp
        // any count of the state poll.
        async.elapse(const Duration(seconds: 5));
        final state = sink.sent.where((f) => !_isTxWatch(f)).toList();
        expect(state, hasLength(6), reason: 'the keyer speed is not polled; the tuner is');

        sink.sent.clear();
        session.stopUpdates();
        async.elapse(const Duration(minutes: 1));
        expect(sink.sent, isEmpty, reason: 'the TX watch stops with everything else');
      });
    });

    test('watches for the operator to key the rig, far faster than it polls state', () {
      // The five-second state poll cannot carry this: a whole over can begin
      // and end inside one of those, and CI-V announces nothing about the
      // PTT on its own — transceive covers the dial and the mode.
      fakeAsync((async) {
        session.startUpdates();
        sink.sent.clear();
        async.elapse(const Duration(seconds: 1));
        expect(sink.sent.where(_isTxWatch).length, greaterThan(1));
        expect(sink.sent.where((f) => !_isTxWatch(f)), isEmpty, reason: 'nothing else is asked this often');
        session.teardown();
      });
    });

    test('a keyed radio is announced, and its meters read on their own scales', () {
      // Through the DRIVER, not the session's constructor: which calibration
      // describes a CI-V radio is the driver's own default (Icom publishes
      // one table for the line), and a session built by hand would carry no
      // table and report no meters — a green test over a strip that stayed
      // empty on every Icom in the catalogue.
      MeterCalibrations.instance.setForTesting({
        'icom/civ-generic': MeterCalibration(
          model: 'CI-V',
          tables: const {
            MeterTable.swr: [MeterPoint(0, 1.0), MeterPoint(80, 2.0)],
          },
        ),
      });
      addTearDown(() => MeterCalibrations.instance.setForTesting({}));
      final session = const IcomCivDriver().createSession(sink, const {}) as IcomCivSession;
      sink.answer = session.handleData;
      void feed(List<int> bytes) => session.handleData(Uint8List.fromList(bytes));

      fakeAsync((async) {
        session.startUpdates();
        feed(_fromRadio([0x1C, 0x00, 0x01]));
        expect(sink.txReports, [true]);

        // Every meter, on the transition — a short over must not be missed
        // waiting for the first tick.
        final asked = sink.sent.where((f) => f.length > 5 && f[4] == 0x15).map((f) => f[5]).toSet();
        expect(asked, {civMeterRfPower, civMeterSwr, civMeterAlc, civMeterDcInputVoltage});

        sink.meterReports.clear();
        // 80 is the published 2.0 point on Icom's SWR scale — the shipped
        // table's own numbers are checked in cat_meter_calibration_test.
        feed(_fromRadio([0x15, civMeterSwr, 0x00, 0x80]));
        expect(sink.meterReports.single.$1, RadioMeter.swr);
        expect(sink.meterReports.single.$2, closeTo(2.0, 0.001));

        // The radio is ASKED again on every cycle, which is the only way an
        // unkey is ever heard: CI-V announces nothing about the PTT, so a
        // cycle that only read meters would leave the app believing the rig
        // was still keyed for the life of the connection — blocking every
        // antenna switch and every snap, and reading four meters at 200 ms
        // forever. (This is why the unkey below is fed as an ANSWER: the
        // radio never volunteers one.)
        sink.sent.clear();
        async.elapse(const Duration(milliseconds: 250));
        expect(sink.sent.where(_isTxWatch), isNotEmpty, reason: 'the TX watch runs during transmit too');

        // And the radio saying it has stopped ends the meter reading.
        sink.sent.clear();
        feed(_fromRadio([0x1C, 0x00, 0x00]));
        expect(sink.txReports, [true, false]);
        async.elapse(const Duration(seconds: 2));
        expect(
          sink.sent.where((f) => f.length > 5 && f[4] == 0x15 && f[5] != civMeterDcInputVoltage),
          isEmpty,
          reason: 'a receiving radio has no meters worth reading',
        );
        session.teardown();
      });
    });
  });

  group('the antenna tuner', () {
    const readTuner = [0xFE, 0xFE, ic705, us, 0x1C, 0x01, 0xFD];

    test('in line and through are 0x1C 0x01 0x01 and 0x00, each read back', () {
      // A set is answered with a bare ACK, so what is shown is what the
      // radio read back, not what was asked for.
      session.setTuner(inline: true);
      session.setTuner(inline: false);
      expect(sink.sent, [
        [0xFE, 0xFE, ic705, us, 0x1C, 0x01, 0x01, 0xFD],
        readTuner,
        [0xFE, 0xFE, ic705, us, 0x1C, 0x01, 0x00, 0xFD],
        readTuner,
      ]);
    });

    test('nothing the app sends starts a tune', () {
      // 0x1C 0x01 0x02 puts a carrier on the air. Driven through every path
      // that writes the tuner, polling included, the byte must never appear.
      fakeAsync((async) {
        session.startUpdates();
        session.setTuner(inline: true);
        session.setTuner(inline: false);
        feed(_fromRadio([0x1C, 0x01, 0x02]));
        async.elapse(const Duration(seconds: 11));
        expect(sink.sent.where((f) => f.length > 6 && f[4] == 0x1C && f[5] == 0x01 && f[6] == 0x02), isEmpty);
        session.teardown();
      });
    });

    test('a reply reports the tuner state, a tune in progress included', () {
      feed(_fromRadio([0x1C, 0x01, 0x00]));
      feed(_fromRadio([0x1C, 0x01, 0x01]));
      feed(_fromRadio([0x1C, 0x01, 0x02]));
      expect(sink.tuners, [TunerStatus.bypassed, TunerStatus.inline, TunerStatus.tuning]);
    });

    test('the poll restating the same state is not reported again', () {
      // Every state poll asks; a sink told each time would wake every
      // listener on a tuner nobody touched.
      feed(_fromRadio([0x1C, 0x01, 0x01]));
      feed(_fromRadio([0x1C, 0x01, 0x01]));
      expect(sink.tuners, [TunerStatus.inline]);
    });

    test('the TX watch and the tuner share 0x1C without being read as each other', () {
      feed(_fromRadio([0x1C, 0x00, 0x01]));
      expect(sink.tuners, isEmpty, reason: 'a keyed radio says nothing about its tuner');
      feed(_fromRadio([0x1C, 0x01, 0x01]));
      expect(sink.txReports, [true], reason: 'a tuner in line is not the radio unkeying');
    });

    test('our own set, echoed on the bus, is not the radio confirming it', () {
      session.setTuner(inline: true);
      feed(sink.sent.first);
      expect(sink.tuners, isEmpty);
    });

    group('on a serial radio that answers only when told', () {
      setUp(() {
        session = IcomCivSession(sink, radioAddress: ic705, controllerAddress: us, config: const {'baudRate': 19200});
        sink.answer = null;
      });

      /// ACKs whatever is on the wire until the tuner read is.
      void ackUntilTunerRead() {
        for (var i = 0; i < 20 && !listEquals(sink.sent.last, readTuner); i++) {
          feed(_fromRadio([0xFB]));
        }
        expect(sink.sent.last, readTuner);
      }

      test('a radio that refuses the read twice in a row has no tuner, and is not asked again', () {
        // An IC-705 has no internal tuner and NAKs 0x1C 0x01. Asked anyway,
        // it costs an exchange and a refusal on every poll for the session.
        fakeAsync((async) {
          session.startUpdates();
          ackUntilTunerRead();
          feed(_fromRadio([0xFA]));
          // Once is not enough: a NAK names no command, and one arriving late
          // for a command that timed out lands on whatever went out next.
          expect(sink.tuners, isEmpty);
          async.elapse(const Duration(seconds: 5));
          ackUntilTunerRead();
          feed(_fromRadio([0xFA]));
          expect(sink.tuners, [null]);
          expect(sink.diagnostics.where((d) => d!.contains('antenna tuner')), hasLength(1));

          sink.answer = session.handleData;
          sink.sent.clear();
          session.setTuner(inline: true);
          async.elapse(const Duration(seconds: 16));
          expect(sink.sent.where((f) => f.length > 5 && f[4] == 0x1C && f[5] == 0x01), isEmpty);
          expect(sink.tuners, [null], reason: 'said once');
          session.teardown();
        });
      });

      test('a radio that ignores the read three times in a row has no tuner, and is not asked again', () {
        // A Xiegu answers a read it lacks with neither data nor a NAK. Counted
        // as nothing, each one would hold the wire for a whole answer timeout
        // on every poll, for the whole connection.
        fakeAsync((async) {
          session.startUpdates();
          for (var i = 0; i < 3; i++) {
            if (i > 0) async.elapse(const Duration(seconds: 5));
            ackUntilTunerRead();
            async.elapse(_pastAnswerTimeout);
            if (i == 2) expect(sink.tuners, isEmpty, reason: 'two lost answers are a busy link');
            // It answers the next command, so the silence was the read's own.
            feed(_fromRadio([0xFB]));
          }
          expect(sink.tuners, [null]);
          expect(sink.diagnostics.where((d) => d!.contains('antenna tuner')), hasLength(1));

          sink.answer = session.handleData;
          sink.sent.clear();
          async.elapse(const Duration(seconds: 16));
          expect(sink.sent.where((f) => f.length > 5 && f[4] == 0x1C && f[5] == 0x01), isEmpty);
          session.teardown();
        });
      });

      test('refusals and silences on the air are no strikes', () {
        // A radio may set aside on the air a read it answers on receive.
        // Counted, a long over would cost the readout for the connection.
        fakeAsync((async) {
          session.startUpdates();
          feed(_fromRadio([0x1C, 0x00, 0x01]));
          for (var i = 0; i < 4; i++) {
            if (i > 0) async.elapse(const Duration(seconds: 5));
            ackUntilTunerRead();
            if (i.isEven) {
              feed(_fromRadio([0xFA]));
            } else {
              async.elapse(_pastAnswerTimeout);
            }
          }
          feed(_fromRadio([0xFB]));
          expect(sink.tuners, isEmpty);
          expect(sink.diagnostics.where((d) => d!.contains('antenna tuner')), isEmpty);
          session.teardown();
        });
      });

      test('a radio switched off for a while keeps its tuner', () {
        // Silent to everything, it is off, not lacking the read: losing the
        // tuner for the session over it would leave the readout blank when
        // the radio comes back on the same connection.
        fakeAsync((async) {
          session.startUpdates();
          async.elapse(const Duration(seconds: 60));
          ackUntilTunerRead();
          feed(_fromRadio([0x1C, 0x01, 0x01]));
          expect(sink.tuners, [TunerStatus.inline]);
          expect(sink.diagnostics.where((d) => d!.contains('antenna tuner')), isEmpty);
          session.teardown();
        });
      });

      test('an answer between two refusals keeps the tuner', () {
        // Two in a ROW: a radio that has a tuner and loses one read to a stray
        // NAK each hour must not lose the readout at the second.
        fakeAsync((async) {
          session.startUpdates();
          ackUntilTunerRead();
          feed(_fromRadio([0xFA]));
          async.elapse(const Duration(seconds: 5));
          ackUntilTunerRead();
          feed(_fromRadio([0x1C, 0x01, 0x01]));
          async.elapse(const Duration(seconds: 5));
          ackUntilTunerRead();
          feed(_fromRadio([0xFA]));
          expect(sink.tuners, [TunerStatus.inline]);
          async.elapse(const Duration(seconds: 5));
          ackUntilTunerRead();
          session.teardown();
        });
      });

      test('a NAK to another command says nothing about the tuner', () {
        // ACK and NAK name no command; only the one on the wire is refused.
        // Read as a tuner refusal, a rejected frequency read would hide the
        // tuner of a radio that has one.
        fakeAsync((async) {
          session.startUpdates();
          feed(_fromRadio([0xFA]));
          ackUntilTunerRead();
          feed(_fromRadio([0x1C, 0x01, 0x01]));
          expect(sink.tuners, [TunerStatus.inline]);
          sink.answer = session.handleData;
          sink.sent.clear();
          async.elapse(const Duration(seconds: 5));
          expect(sink.sent.where((f) => listEquals(f, readTuner)), hasLength(1), reason: 'still on the state poll');
          session.teardown();
        });
      });

      test('a PTT set does not take a queued tuner set with it', () {
        // The PTT clears queued 0x1C frames so a stale key cannot follow an
        // unkey — but the tuner shares 0x1C, and its set would be lost.
        fakeAsync((async) {
          session.startUpdates();
          session.setTuner(inline: true);
          session.setPtt(true);
          for (var i = 0; i < 20; i++) {
            feed(_fromRadio([0xFB]));
          }
          expect(sink.sent, contains(equals([0xFE, 0xFE, ic705, us, 0x1C, 0x01, 0x01, 0xFD])));
          session.teardown();
        });
      });
    });
  });

  group('the receive passband', () {
    const readWidth = [0xFE, 0xFE, ic705, us, 0x1A, 0x03, 0xFD];
    final cw = _fromRadio([0x04, 0x03, 0x01]);
    List<List<int>> widthReads() => sink.sent.where((f) => listEquals(f, readWidth)).toList();

    test("the width tables are Icom's, with the step change at index 10", () {
      // An off-by-one at the step change reads every width above 500 Hz
      // 100 Hz wrong.
      expect(civFilterWidthsSsbCw, hasLength(41));
      expect([civFilterWidthsSsbCw[0], civFilterWidthsSsbCw[9], civFilterWidthsSsbCw[10], civFilterWidthsSsbCw[40]], [50, 500, 600, 3600]);
      expect(civFilterWidthsAm, hasLength(50));
      expect([civFilterWidthsAm[0], civFilterWidthsAm[49]], [200, 10000]);
    });

    test('in CW the width is a passband centred on the dial, read as BCD', () {
      feed(cw);
      expect(widthReads(), hasLength(1), reason: 'a mode with a passband asks for it');
      // 0x15 is index 15 (1100 Hz) in BCD; read as hex it would be 21 (1700 Hz).
      feed(_fromRadio([0x1A, 0x03, 0x15]));
      expect(sink.passbands.last, const Passband(-550, 550));
    });

    test('AM reads its own table', () {
      feed(_fromRadio([0x04, 0x02, 0x01]));
      feed(_fromRadio([0x1A, 0x03, 0x49]));
      expect(sink.passbands.last, const Passband(-5000, 5000));
    });

    test('SSB, RTTY and FM report none, and are not asked', () {
      // Where an Icom's SSB filter sits against the carrier is nothing CI-V
      // says; a passband drawn there would be a guess shown as a reading.
      for (final mode in [0x01, 0x00, 0x04, 0x05]) {
        feed(cw);
        feed(_fromRadio([0x1A, 0x03, 0x10]));
        sink.sent.clear();
        feed(_fromRadio([0x04, mode, 0x01]));
        expect(sink.passbands.last, isNull, reason: 'mode 0x${mode.toRadixString(16)}');
        expect(widthReads(), isEmpty, reason: 'mode 0x${mode.toRadixString(16)}');
        // A width answer landing anyway is not read through CW's table.
        feed(_fromRadio([0x1A, 0x03, 0x10]));
        expect(sink.passbands.last, isNull);
      }
    });

    test('a change of mode or filter forgets the width and asks again', () {
      // Each mode and each filter keeps its own width: CW's index read through
      // AM's table would be 2200 Hz for a 600 Hz filter.
      feed(cw);
      feed(_fromRadio([0x1A, 0x03, 0x10]));
      expect(sink.passbands.last, const Passband(-300, 300));
      sink.sent.clear();
      feed(_fromRadio([0x04, 0x02, 0x01]));
      expect(sink.passbands.last, isNull);
      expect(widthReads(), hasLength(1));

      feed(_fromRadio([0x04, 0x03, 0x01]));
      feed(_fromRadio([0x1A, 0x03, 0x10]));
      sink.sent.clear();
      feed(_fromRadio([0x04, 0x03, 0x02]));
      expect(widthReads(), hasLength(1), reason: 'FIL2 has a width of its own');
      sink.sent.clear();
      feed(_fromRadio([0x04, 0x03, 0x02]));
      expect(widthReads(), isEmpty, reason: 'the mode poll restating itself is no change');
    });

    test('the state poll reads the width, and a restated width is not reported again', () {
      // CI-V announces no width change, so the poll is how a turn of the
      // radio's own control is heard.
      fakeAsync((async) {
        session.startUpdates();
        feed(cw);
        feed(_fromRadio([0x1A, 0x03, 0x10]));
        sink.sent.clear();
        async.elapse(const Duration(seconds: 5));
        expect(widthReads(), hasLength(1));
        final reports = sink.passbands.length;
        feed(_fromRadio([0x1A, 0x03, 0x10]));
        expect(sink.passbands, hasLength(reports));
        feed(_fromRadio([0x1A, 0x03, 0x12]));
        expect(sink.passbands.last, const Passband(-400, 400));
        session.teardown();
      });
    });

    test('a set writes the nearest width and reads it back, touching nothing else', () {
      expect(session, isA<PassbandSession>(), reason: 'CatService offers the set only to a PassbandSession');
      feed(cw);
      sink.sent.clear();
      // 520 Hz: 500 is nearer than 600.
      session.setPassband(const Passband(-260, 260));
      // 2450 Hz sits halfway between 2400 (28) and 2500 (29): the narrower,
      // and 28 goes out as BCD 0x28, not 0x1C.
      session.setPassband(const Passband(300, 2750));
      expect(sink.sent, [
        [0xFE, 0xFE, ic705, us, 0x1A, 0x03, 0x09, 0xFD],
        readWidth,
        [0xFE, 0xFE, ic705, us, 0x1A, 0x03, 0x28, 0xFD],
        readWidth,
      ], reason: 'no mode, filter-slot or PBT frame rides along');

      feed(_fromRadio([0x04, 0x02, 0x01]));
      sink.sent.clear();
      session.setPassband(const Passband(-2500, 2500));
      expect(sink.sent.first, [0xFE, 0xFE, ic705, us, 0x1A, 0x03, 0x24, 0xFD], reason: "AM's table: 5000 Hz is index 24");
    });

    test('a set in a mode with no passband sends nothing', () {
      // The report would stay null, so a set there lands where nobody sees.
      feed(_fromRadio([0x04, 0x01, 0x01]));
      sink.sent.clear();
      session.setPassband(const Passband(100, 2800));
      expect(sink.sent, isEmpty);
    });

    group('on a serial radio that answers only when told', () {
      setUp(() {
        session = IcomCivSession(sink, radioAddress: ic705, controllerAddress: us, config: const {'baudRate': 19200});
        sink.answer = null;
      });

      test('a radio that refuses the read twice in a row is not asked again, and says so', () {
        feed(cw);
        expect(sink.sent.last, readWidth);
        feed(_fromRadio([0xFA]));
        expect(sink.diagnostics, isEmpty, reason: 'one NAK may be a late answer to something else');
        feed(_fromRadio([0x04, 0x03, 0x02]));
        expect(sink.sent.last, readWidth);
        feed(_fromRadio([0xFA]));
        expect(sink.diagnostics.where((d) => d!.contains('filter width')), hasLength(1));
        expect(sink.passbands.last, isNull);

        sink.sent.clear();
        feed(_fromRadio([0x04, 0x03, 0x03]));
        session.setPassband(const Passband(-250, 250));
        expect(sink.sent, isEmpty);
      });

      test('a radio that ignores the read three times in a row is not asked again, and says so', () {
        // The Xiegu way with a read it lacks — see the tuner's test. Each mode
        // answer is the radio answering after the last silence.
        fakeAsync((async) {
          feed(cw);
          for (final filter in [0x02, 0x03, 0x01]) {
            expect(sink.sent.last, readWidth);
            async.elapse(_pastAnswerTimeout);
            if (filter == 0x01) {
              expect(sink.diagnostics.where((d) => d!.contains('filter width')), isEmpty, reason: 'two lost answers are a busy link');
            }
            feed(_fromRadio([0x04, 0x03, filter]));
          }
          expect(sink.diagnostics.where((d) => d!.contains('filter width')), hasLength(1));
          expect(sink.passbands.last, isNull);

          sink.sent.clear();
          feed(_fromRadio([0x04, 0x03, 0x02]));
          expect(sink.sent.where((f) => listEquals(f, readWidth)), isEmpty);
        });
      });

      test('a late answer to a read that timed out keeps asking', () {
        // Silence followed by the answer is a slow radio, not a missing read.
        fakeAsync((async) {
          feed(cw);
          async.elapse(_pastAnswerTimeout);
          feed(_fromRadio([0x1A, 0x03, 0x10]));
          for (final filter in [0x02, 0x03]) {
            feed(_fromRadio([0x04, 0x03, filter]));
            async.elapse(_pastAnswerTimeout);
          }
          sink.sent.clear();
          feed(_fromRadio([0x04, 0x03, 0x01]));
          expect(sink.sent.last, readWidth, reason: 'two silences since the answer, not three');
          expect(sink.diagnostics.where((d) => d!.contains('filter width')), isEmpty);
        });
      });

      test('a radio switched off with the read out keeps it, however often', () {
        // Back on in a mode without a width, nothing answers the read to clear
        // its silence: were the first frame back to count it, three power
        // cycles on one connection would lose the passband for good.
        fakeAsync((async) {
          for (var cycle = 0; cycle < 3; cycle++) {
            feed(cw);
            expect(sink.sent.last, readWidth);
            session.setFrequency(14074);
            async.elapse(_pastAnswerTimeout * 2);
            feed(_fromRadio([0x04, 0x01, 0x01]));
          }
          expect(sink.diagnostics.where((d) => d!.contains('filter width')), isEmpty);
          feed(cw);
          expect(sink.sent.last, readWidth);
        });
      });

      test('the Xiegus never ask it: neither has the command', () {
        // hamlib's x1ax03_supported. Asked anyway, the read costs each of them
        // three answer timeouts before the session learns what the entry knows.
        for (final model in [g90Model, x6100Model]) {
          sink.sent.clear();
          session = IcomCivSession(sink, radioAddress: ic705, controllerAddress: us, config: {...model.variants.first.overrides, 'baudRate': 19200});
          feed(cw);
          // Not even after an answer: the pin is a fact about the model, and a
          // stray frame must not turn the read on.
          feed(_fromRadio([0x1A, 0x03, 0x10]));
          feed(_fromRadio([0x04, 0x03, 0x02]));
          session.setPassband(const Passband(-250, 250));
          expect(sink.sent.where((f) => f.length > 5 && f[4] == 0x1A && f[5] == 0x03), isEmpty, reason: model.key);
        }
      });

      test('an answer between two refusals keeps asking', () {
        feed(cw);
        feed(_fromRadio([0xFA]));
        feed(_fromRadio([0x04, 0x03, 0x02]));
        feed(_fromRadio([0x1A, 0x03, 0x10]));
        feed(_fromRadio([0x04, 0x03, 0x03]));
        feed(_fromRadio([0xFA]));
        sink.sent.clear();
        feed(_fromRadio([0x04, 0x03, 0x01]));
        expect(sink.sent.last, readWidth);
        expect(sink.diagnostics, isEmpty);
      });

      test('a NAK to the DATA read is not a width refusal, though both are 0x1A', () {
        // A transceive mode announcement asks after the width and then the
        // DATA submode; a radio without DATA refuses the second.
        final announceCw = [0xFE, 0xFE, 0x00, ic705, 0x01, 0x03, 0x01, 0xFD];
        for (final filter in [0x01, 0x02]) {
          feed([...announceCw.sublist(0, 6), filter, 0xFD]);
          expect(sink.sent.last, readWidth);
          feed(_fromRadio([0xFB]));
          expect(sink.sent.last, [0xFE, 0xFE, ic705, us, 0x1A, 0x06, 0xFD]);
          feed(_fromRadio([0xFA]));
        }
        expect(sink.diagnostics.where((d) => d!.contains('filter width')), isEmpty);
        feed([...announceCw.sublist(0, 6), 0x03, 0xFD]);
        expect(sink.sent.last, readWidth, reason: 'still asked');
      });
    });
  });

  group('maxWatts', () {
    test('comes from config, defaulting to the assumed 100W ceiling', () {
      const driver = IcomCivDriver();
      expect((driver.createSession(sink, {}) as IcomCivSession).maxWatts, 100);
      expect((driver.createSession(sink, {'maxWatts': 10}) as IcomCivSession).maxWatts, 10);
    });

    test('batteryMaxWatts comes from config too, defaulting to no cap at all', () {
      const driver = IcomCivDriver();
      expect((driver.createSession(sink, {}) as IcomCivSession).batteryMaxWatts, isNull);
      expect((driver.createSession(sink, {'maxWatts': 10, 'batteryMaxWatts': 5}) as IcomCivSession).batteryMaxWatts, 5);
    });
  });

  group('the address is configuration, not a constant', () {
    test('a driver session honours a non-default radio address', () {
      // An IC-7300 on the same driver.
      const driver = IcomCivDriver();
      final other = driver.createSession(sink, {'civAddress': '94'}) as IcomCivSession;
      expect(other.radioAddress, 0x94);

      other.setFrequency(7074);
      expect(sink.sent.single[2], 0x94, reason: 'addressed to the configured radio');
    });

    test('an address round-tripped through JSON as a number still works', () {
      const driver = IcomCivDriver();
      expect((driver.createSession(sink, {'civAddress': 0xA4}) as IcomCivSession).radioAddress, 0xA4);
      expect((driver.createSession(sink, {'civAddress': '0xA4'}) as IcomCivSession).radioAddress, 0xA4);
    });

    test('an unusable address falls back to the IC-705 default rather than sending garbage', () {
      const driver = IcomCivDriver();
      expect((driver.createSession(sink, {}) as IcomCivSession).radioAddress, 0xA4);
      expect((driver.createSession(sink, {'civAddress': 'zz'}) as IcomCivSession).radioAddress, 0xA4);
    });
  });

  group('the equipment type', () {
    final type = EquipmentRegistry().typeFor('icom-generic-serial')!;

    test('rides the serial transport that already shipped — no new transport code', () {
      expect(type.transportKey, SerialTransport.transportKey);
      expect(type.category, kCategoryTransceiver);
      // CI-V over a serial port is proven separately from CI-V over the
      // network — an IC-7300 and an IC-706MKIIG both run on this pairing.
      // Asserting on the TYPE rather than the driver is the point: the two
      // answers are allowed to differ, and a pairing that goes back to
      // unproven has to say so here rather than inheriting a driver's word
      // for a transport it was never tested on.
    });

    test('defaults to the IC-705 address and Icom\'s CI-V default speed', () {
      expect(type.defaultConfig['civAddress'], 'A4');
      expect(type.defaultConfig['baudRate'], 19200);
    });

    test('asks for port, speed and address — and, of a developer, the keyer facts the generic entry cannot pin', () {
      final fields = [
        for (final e in type.configElements())
          if (e['type'] == 'field') e,
      ];
      expect(fields.map((e) => e['key']), [
        'port',
        'baudRate',
        serialRtsHighConfigKey,
        serialDtrHighConfigKey,
        'civAddress',
        'cwKeyer',
        'voiceMemories',
        telemetryIntervalConfigKey,
        pollIntervalConfigKey,
      ]);
      expect(fields.where((e) => e['devMode'] == true).map((e) => e['key']), ['cwKeyer', 'voiceMemories'], reason: 'an operator sees the first three only');
    });

    test('warns about a radio offering two serial ports at once', () {
      // Several Icom radios (the IC-705 among them) expose two USB serial
      // ports simultaneously, and neither the OS nor this app can tell them
      // apart beyond a `#n` suffix — found by an operator confused by
      // exactly that after granting access to one and seeing two.
      final note = type.configElements().firstWhere((e) => e['type'] == 'markdown');
      expect(note['text'], contains('Port A'), reason: 'which one to pick');
    });

    test('a bad address is refused in the editor, not discovered at the bench', () {
      // A wrong address is silent on the wire — the radio ignores frames
      // addressed elsewhere, which looks exactly like a dead cable.
      expect(type.validate({'port': 'COM3', 'civAddress': 'A4'}), isNull);
      expect(type.validate({'port': 'COM3', 'civAddress': ''}), isNotNull);
      expect(type.validate({'port': 'COM3', 'civAddress': 'zz'}), isNotNull);
      expect(type.validate({'port': 'COM3', 'civAddress': '00'}), isNotNull, reason: '0x00 is broadcast');
      expect(type.validate({'port': '', 'civAddress': 'A4'}), isNotNull, reason: 'no port');
    });

    test('the row says where it is and which radio it is addressing', () {
      expect(type.describeTarget({'port': 'COM3', 'baudRate': 19200, 'civAddress': 'a4'}), 'COM3 @ 19200 · CI-V A4');
    });

    test('the registry offers it alongside the others', () {
      final registry = EquipmentRegistry();
      expect(registry.typeFor('icom-generic-serial')?.key, 'icom-generic-serial');
      // The CI-V driver is shared between the serial and WiFi types — the
      // transport/driver split paying off directly.
      expect(registry.typeFor('ic705-network')?.driver.key, 'icom-civ');
      expect(registry.typeFor('icom-generic-serial')?.driver.key, 'icom-civ');
      expect(registry.transports.keys, containsAll(['tcp', 'serial', 'icom-network']));
    });
  });
}

/// A frame the session sends to ask whether the radio is transmitting —
/// 0x1C 0x00, not the tuner's 0x1C 0x01 that shares its command byte.
bool _isTxWatch(List<int> frame) => frame.length > 5 && frame[4] == 0x1C && frame[5] == 0x00;

/// A complete frame FROM the IC-705 addressed to us, wrapped around
/// [payload] — the command byte and its data.
List<int> _fromRadio(List<int> payload) => [0xFE, 0xFE, civDefaultControllerAddress, 0xA4, ...payload, 0xFD];

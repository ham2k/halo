// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Yaesu GS-232 rotator protocol and its session.
//
// What is asserted here comes from the GS-232A manual — commands are not
// echoed, angles are three digits, `C`/`C2` answer `+0aaa`/`+0aaa+0eee` —
// and from the GS-232B's `AZ=`/`EL=` dialect the emulators answer in. No
// rotator has been on the bench, so none of it is a capture.
//
// A session is pure given a fake sink, so all of this runs with no rotator.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/gs232_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/gs232_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/rotator_config.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';

class _FakeSink implements EquipmentSink, RotatorSink {
  final sent = <String>[];
  final positions = <RotatorPosition>[];
  final problems = <String?>[];
  var alive = 0;

  @override
  void send(List<int> bytes) => sent.add(ascii.decode(bytes));

  @override
  void reportRotator(RotatorPosition position) => positions.add(position);

  @override
  void reportProblem(String? message) => problems.add(message);

  @override
  void reportAlive() => alive++;

  @override
  void report(VfoReading reading) => fail('a rotator has no VFO to report');
  @override
  void reportPower(num watts) => fail('a rotator has no power to report');
  @override
  void reportTransmitting(bool transmitting) => fail('a rotator does not transmit');
  @override
  void reportMeter(RadioMeter meter, num value) => fail('a rotator has no meters');
  @override
  void reportKeyerSpeed(int wpm) => fail('a rotator has no keyer');
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportVoiceActivity(VoiceActivity? activity) {}
  @override
  void reportVoiceMemories(List<VoiceMemory> memories) {}
  @override
  void reportDiagnostic(String? note) {}
  @override
  void reportChannels(List<EquipmentChannel> channels) => fail('a rotator has no channels');
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) => fail('a rotator routes nothing');
}

extension on Gs232Session {
  void feed(String text) => handleData(Uint8List.fromList(ascii.encode(text)));
}

void main() {
  group('GS-232 commands', () {
    test('an angle is three digits and the command ends with a bare CR', () {
      // `M5` is not `M005` to a GS-232A: it reads the digits that follow as
      // more of the angle. And a CRLF leaves the LF to prefix the next
      // command, which the controller then refuses.
      expect(gs232AzimuthCommand(5), 'M005\r');
      expect(gs232AzimuthCommand(270), 'M270\r');
      expect(gs232AzimuthElevationCommand(90, 5), 'W090 005\r');
      expect(gs232AzimuthQuery, isNot(contains('\n')));
    });

    test('a fractional heading rounds, and one out of range is held to the protocol', () {
      expect(gs232AzimuthCommand(123.6), 'M124\r');
      // Four digits would be read as a different command entirely.
      expect(gs232AzimuthCommand(1000), 'M450\r');
      expect(gs232AzimuthCommand(-3), 'M000\r');
      expect(gs232AzimuthElevationCommand(10, 200), 'W010 180\r');
    });
  });

  group('GS-232 position answers', () {
    test('both dialects read, with and without an elevation', () {
      expect(parseGs232Position('+0123'), const RotatorPosition(azimuth: 123));
      expect(parseGs232Position('+0123+0045'), const RotatorPosition(azimuth: 123, elevation: 45));
      expect(parseGs232Position('AZ=123'), const RotatorPosition(azimuth: 123));
      expect(parseGs232Position('AZ=123  EL=045'), const RotatorPosition(azimuth: 123, elevation: 45));
      // A 450° rotator in its overlap.
      expect(parseGs232Position('+0420'), const RotatorPosition(azimuth: 420));
    });

    test('anything that is not a position is not read as one', () {
      // A refusal carries no digits; a banner or help line carries digits
      // that are not a heading. Either read as one would swing the readout.
      expect(parseGs232Position('?>'), isNull);
      expect(parseGs232Position(''), isNull);
      expect(parseGs232Position('GS-232A Ver 1.2'), isNull);
      expect(isGs232Refusal('?>'), isTrue);
      expect(isGs232Refusal('+0123'), isFalse);
    });
  });

  group('Gs232Session', () {
    test('asks for the azimuth on connect and every poll, and only the azimuth on an az-only rotator', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = Gs232Session(sink)..startUpdates();
        // At once, not a poll later: the readout is blank until it answers.
        expect(sink.sent, ['C\r']);
        async.elapse(gs232PollInterval * 3);
        expect(sink.sent, List.filled(4, 'C\r'));
        session.teardown();
        async.elapse(gs232PollInterval * 3);
        expect(sink.sent, hasLength(4), reason: 'a torn-down session keeps polling a port it no longer owns');
      });
    });

    test('an az/el rotator is asked for both axes', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        Gs232Session(sink, elevation: true).startUpdates();
        expect(sink.sent, ['C2\r']);
      });
    });

    test('an answer split across reads, CRLF-terminated, is one reading', () {
      final sink = _FakeSink();
      Gs232Session(sink, elevation: true)
        ..feed('+012')
        ..feed('3+0045\r')
        ..feed('\n');
      expect(sink.positions, [const RotatorPosition(azimuth: 123, elevation: 45)]);
    });

    test('an az-only rotator drops an elevation the interface volunteers', () {
      // An az-only rotator on an az/el interface reads its unconnected
      // elevation input; shown, it is a heading the antenna does not have.
      final sink = _FakeSink();
      Gs232Session(sink).feed('+0123+0031\r\n');
      expect(sink.positions, [const RotatorPosition(azimuth: 123)]);
    });

    test('turning sends the heading, with the elevation only where the rotator has one', () {
      final azOnly = _FakeSink();
      Gs232Session(azOnly).rotateTo(azimuth: 45, elevation: 30);
      expect(azOnly.sent, ['M045\r']);

      final azEl = _FakeSink();
      Gs232Session(azEl, elevation: true)
        ..rotateTo(azimuth: 45, elevation: 30)
        // No elevation-only or "keep elevation" form of W exists, so a
        // heading with no elevation must not become W045 000 and drop the
        // antenna to the horizon.
        ..rotateTo(azimuth: 90);
      expect(azEl.sent, ['W045 030\r', 'M090\r']);
    });

    // Everything above the session speaks true headings. An offset applied
    // one way and not the other turns the mast to the reading's error twice
    // over; applied with the wrong sign, it doubles it.
    test('an offset is added to every reading and taken off every turn', () {
      final sink = _FakeSink();
      final session = Gs232Session(sink, calibration: const RotatorCalibration(azimuthOffset: -20))..feed('+0005\r\n');
      expect(sink.positions, [const RotatorPosition(azimuth: 345)], reason: 'wrapped past north, not -15');
      expect(session.rotateTo(azimuth: 350), const RotatorPosition(azimuth: 350));
      expect(sink.sent, ['M010\r']);
    });

    test('with overlap a turn takes the nearer of the two ways to a heading', () {
      final sink = _FakeSink();
      final session = Gs232Session(sink, calibration: const RotatorCalibration(azimuthMax: 450))..feed('+0400\r\n');
      session.rotateTo(azimuth: 30);
      session.feed('+0010\r\n');
      session.rotateTo(azimuth: 30);
      // From 400, 390 is ten degrees on; 30 is a turn back through the whole
      // circle. From 10 it is the other way round.
      expect(sink.sent, ['M390\r', 'M030\r']);
    });

    test('a heading past the limits turns to the nearer limit, and says so', () {
      final sink = _FakeSink();
      final session = Gs232Session(sink, calibration: const RotatorCalibration(azimuthMin: 90, azimuthMax: 270));
      // The target CatService holds is what this returns: told 300, the mast
      // stops at 270, and a target of 300 would never be arrived at.
      expect(session.rotateTo(azimuth: 300), const RotatorPosition(azimuth: 270));
      expect(session.rotateTo(azimuth: 60), const RotatorPosition(azimuth: 90));
      expect(sink.sent, ['M270\r', 'M090\r']);
    });

    test('elevation takes its own offset and stays within its limits', () {
      final sink = _FakeSink();
      final session = Gs232Session(sink, elevation: true, calibration: const RotatorCalibration(elevationOffset: 5, elevationMax: 80))..feed('+0100+0010\r\n');
      expect(sink.positions, [const RotatorPosition(azimuth: 100, elevation: 15)]);
      // 80 is the controller's ceiling; 85 is where that points, and so the
      // elevation there is any arriving at.
      expect(session.rotateTo(azimuth: 100, elevation: 90), const RotatorPosition(azimuth: 100, elevation: 85));
      expect(sink.sent.last, 'W100 080\r');
    });

    test('the node\'s poll interval is the session\'s, and blank is a second', () {
      const driver = Gs232Driver();
      expect(driver.createSession(_FakeSink(), const {'pollInterval': 2500}).expectedUpdateInterval, const Duration(milliseconds: 2500));
      expect(driver.createSession(_FakeSink(), const {}).expectedUpdateInterval, gs232PollInterval);
    });

    test('offsets, limits and the poll interval refuse what the controller cannot mean', () {
      const driver = Gs232Driver();
      expect(driver.validateField('azimuthOffset', -15, const {}), isNull);
      expect(driver.validateField('azimuthOffset', 200, const {}), isNotNull);
      expect(driver.validateField('azimuthMax', 450, const {}), isNull);
      expect(driver.validateField('azimuthMax', 80, const {'azimuthMin': 90}), isNotNull, reason: 'a range with nothing in it');
      expect(driver.validateField('elevationMax', '', const {}), isNull, reason: 'blank is the default');
      expect(driver.validateField('pollInterval', 100, const {}), isNotNull);
    });

    test('stop is the all-axes stop', () {
      final sink = _FakeSink();
      Gs232Session(sink, elevation: true).stopRotation();
      expect(sink.sent, ['S\r']);
    });

    test('a refusal is a problem until the controller answers a position again', () {
      final sink = _FakeSink();
      final session = Gs232Session(sink)
        ..feed('?>\r\n')
        ..feed('?>\r\n');
      // Once, not per poll: the row would otherwise rebuild every second.
      expect(sink.problems, hasLength(1));
      expect(sink.problems.single, isNotNull);
      // A refusal is still the controller talking — without this the row
      // reads Not Responding over a link that is answering every poll.
      expect(sink.alive, 2);
      session.feed('+0010\r\n');
      expect(sink.problems, [isNotNull, isNull]);
      session.feed('+0011\r\n');
      expect(sink.problems, hasLength(2), reason: 'only the answer after a refusal clears it');
    });
  });
}

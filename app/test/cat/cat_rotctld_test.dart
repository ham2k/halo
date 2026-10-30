// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Hamlib's rotctld protocol and its session.
//
// The lines fed here are a capture of `rotctld -m 1` (Hamlib 4.7.2, the
// dummy rotator): `p` answers two bare lines, an azimuth that can be
// negative on a backend whose range starts at -180; `P` and `S` answer
// `RPRT n`; `\dump_state` names the limits as `key=value` lines and ends in
// `done`, with no `RPRT`. Version 0's `\dump_state` is Hamlib 4.3's source.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/rotator_config.dart';
import 'package:ham2k_logger/services/cat/drivers/rotctld_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/rotctld_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';

class _FakeSink implements EquipmentSink, RotatorSink {
  final sent = <String>[];
  final positions = <RotatorPosition>[];
  final problems = <String?>[];
  final diagnostics = <String?>[];
  var alive = 0;

  @override
  void send(List<int> bytes) => sent.add(utf8.decode(bytes));
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
  void reportDiagnostic(String? note) => diagnostics.add(note);
  @override
  void reportChannels(List<EquipmentChannel> channels) => fail('a rotator has no channels');
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) => fail('a rotator routes nothing');
}

extension on RotctldSession {
  void feed(String text) => handleData(Uint8List.fromList(utf8.encode(text)));
}

/// The dummy rotator's `\dump_state`, byte for byte.
const _dummyState = '1\n1\nmin_az=-180.000000\nmax_az=450.000000\nmin_el=0.000000\nmax_el=90.000000\nsouth_zero=0\nrot_type=AzEl\ndone\n';

/// A session that has asked for the state and been told it.
RotctldSession _connected(_FakeSink sink, {bool elevation = false, RotatorCalibration calibration = const RotatorCalibration(), String state = _dummyState}) =>
    RotctldSession(sink, elevation: elevation, calibration: calibration)
      ..startUpdates()
      ..feed(state);

void main() {
  final st = t.settings.station;

  group('rotctld lines', () {
    test('read as the capture has them', () {
      expect(parseRotctldNumber('-5.41'), -5.41);
      expect(parseRotctldNumber('rot_type=AzEl'), isNull);
      expect(parseRotctldReport('RPRT -21'), -21);
      expect(parseRotctldReport('RPRT 0'), 0);
      expect(parseRotctldStateVersion('1'), 1);
      // Hamlib prints a position with decimals: `0.00` is an azimuth, not
      // the version a `\dump_state` answer starts with.
      expect(parseRotctldStateVersion('0.00'), isNull);
      expect(parseRotctldStateLimit('min_az=-180.000000'), (max: false, elevation: false, degrees: -180));
      expect(parseRotctldStateLimit('max_el=90.000000'), (max: true, elevation: true, degrees: 90));
      expect(isRotctldStateField('rot_type=AzEl'), isTrue);
      // `P 90` alone makes the daemon take the NEXT line as the elevation.
      expect(rotctldTurnCommand(90, 0), 'P 90 0\n');
    });
  });

  group('RotctldSession', () {
    // A `p` asked while `\dump_state` is outstanding answers bare numbers
    // among its own; one asked while a `p` is outstanding queues behind a
    // backend that is timing out, and every turn waits behind the queue.
    test('asks for the state first, then polls one question at a time', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = RotctldSession(sink)..startUpdates();
        expect(sink.sent, [rotctldStateQuery]);
        async.elapse(rotctldPollInterval);
        expect(sink.sent, [rotctldStateQuery], reason: 'no poll while the state is unanswered');
        session.feed(_dummyState);
        expect(sink.sent, [rotctldStateQuery, rotctldPositionQuery], reason: 'the first poll goes as soon as it is answered');
        async.elapse(rotctldPollInterval * 3);
        expect(sink.sent.where((sent) => sent == rotctldPositionQuery), hasLength(1), reason: 'that poll is still unanswered');
        session.feed('5.00\n0.00\n');
        async.elapse(rotctldPollInterval);
        expect(sink.sent.where((sent) => sent == rotctldPositionQuery), hasLength(2));
      });
    });

    test('a daemon that never answers the state is polled anyway, inside a full turn', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = RotctldSession(sink)..startUpdates();
        async.elapse(rotctldStateWait);
        expect(sink.sent.last, rotctldPositionQuery);
        expect(sink.diagnostics.last, contains('no \\dump_state answer'));
        session
          ..feed('90.00\n0.00\n')
          ..rotateTo(azimuth: 270);
        expect(sink.sent.last, 'P 270 0\n');
      });
    });

    test('pairs the two bare lines of an answer, and reads a negative azimuth as a heading', () {
      final sink = _FakeSink();
      _connected(sink, elevation: true)
        ..feed('-5.41\n')
        ..feed('0.00\n0.61\n10.0\n');
      expect(sink.positions, [const RotatorPosition(azimuth: 355, elevation: 0), const RotatorPosition(azimuth: 1, elevation: 10)]);
    });

    // A 270° heading sent as 270 to a daemon that enforces -180 to 180 is
    // refused (RPRT -21); within the limits it reported it is -90.
    test('a turn goes out inside the limits the daemon reported', () {
      final sink = _FakeSink();
      final session = _connected(sink, elevation: true, state: _dummyState.replaceFirst('max_az=450', 'max_az=180'))..feed('0.00\n0.00\n');
      expect(sink.diagnostics.last, 'limits from \\dump_state: azimuth -180..180, elevation 0..90');
      expect(session.rotateTo(azimuth: 270, elevation: 0), const RotatorPosition(azimuth: 270, elevation: 0));
      expect(sink.sent.last, 'P -90 0\n');
    });

    test('a version 0 state names the limits as four bare numbers, none of them a position', () {
      final sink = _FakeSink();
      final session = _connected(sink, elevation: true, state: '0\n1\n-180.000000\n180.000000\n0.000000\n90.000000\n')..feed('0.00\n0.00\n');
      expect(sink.positions, [const RotatorPosition(azimuth: 0, elevation: 0)]);
      session.rotateTo(azimuth: 270, elevation: 0);
      expect(sink.sent.last, 'P -90 0\n');
    });

    // Placed inside 0 to 0, every turn would go to north.
    test('a reported range that is not one keeps a full turn', () {
      final sink = _FakeSink();
      _connected(sink, state: _dummyState.replaceFirst('max_az=450', 'max_az=-180'))
        ..feed('0.00\n0.00\n')
        ..rotateTo(azimuth: 270);
      expect(sink.sent.last, 'P 270 0\n');
    });

    test("a turn's refusal is the turn's, on a daemon that does not know the state", () {
      final sink = _FakeSink();
      RotctldSession(sink)
        ..startUpdates()
        ..rotateTo(azimuth: 270)
        ..feed('RPRT -21\n');
      expect(sink.problems, [st.rotctldPastLimits(code: -21)]);
      expect(sink.sent.last, rotctldPositionQuery, reason: 'the state was never going to be answered');
    });

    test('an azimuth-only turn keeps the elevation the rotator reported', () {
      final sink = _FakeSink();
      final session = _connected(sink, elevation: true)..feed('10.00\n35.00\n');
      session.rotateTo(azimuth: 20);
      // `P 20 0` would drop the antenna to the horizon.
      expect(sink.sent.last, 'P 20 35\n');
    });

    // An az-only node is the variant's default: an az/el rotator behind it
    // would drop to the horizon on every turn, sent 0.
    test('an az-only node reports no elevation and leaves it where it is', () {
      final sink = _FakeSink();
      _connected(sink)
        ..feed('10.00\n35.00\n')
        ..rotateTo(azimuth: 20, elevation: 40);
      expect(sink.positions, [const RotatorPosition(azimuth: 10)]);
      expect(sink.sent.last, 'P 20 35\n');
    });

    test('before any reading, an azimuth-only turn keeps the elevation last sent', () {
      final sink = _FakeSink();
      _connected(sink, elevation: true)
        ..rotateTo(azimuth: 20, elevation: 40)
        ..rotateTo(azimuth: 30);
      expect(sink.sent.last, 'P 30 40\n');
    });

    test('offsets apply both ways', () {
      final sink = _FakeSink();
      final session = _connected(sink, calibration: const RotatorCalibration(azimuthOffset: -20))..feed('5.00\n0.00\n');
      expect(sink.positions, [const RotatorPosition(azimuth: 345)]);
      expect(session.rotateTo(azimuth: 350), const RotatorPosition(azimuth: 350));
      expect(sink.sent.last, 'P 10 0\n');
    });

    // A refused turn stays said until a command is answered again: the next
    // poll answering is not a turn that worked. A read that failed is cleared
    // by the next read that did not.
    test('a refused turn and a failed read are problems, each cleared by its own kind of answer', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = _connected(sink)..feed('5.00\n0.00\n');
        expect(sink.problems, isEmpty);
        session
          ..rotateTo(azimuth: 90)
          ..feed('RPRT -21\n');
        async.elapse(rotctldPollInterval);
        session.feed('5.00\n0.00\n');
        expect(sink.problems, [st.rotctldPastLimits(code: -21)]);
        session
          ..rotateTo(azimuth: 80)
          ..feed('RPRT 0\n');
        expect(sink.problems, [isNotNull, isNull]);

        async.elapse(rotctldPollInterval);
        session.feed('RPRT -6\n');
        expect(sink.problems.last, st.rotctldReadFailed(code: -6));
        async.elapse(rotctldPollInterval);
        session.feed('6.00\n0.00\n');
        expect(sink.problems.last, isNull);
      });
    });

    // Counted as the turn's, a poll's timeout reads as a refused turn that
    // stays up although the turn worked — or a real refusal reads as a
    // failed read, which the next poll then clears away.
    test("a failed poll ahead of a turn is the poll's, and the turn's answer is the turn's", () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = _connected(sink)
          ..rotateTo(azimuth: 90)
          ..feed('RPRT -5\nRPRT 0\n');
        expect(sink.problems, [st.rotctldTimedOut(code: -5), isNull]);

        async.elapse(rotctldPollInterval);
        session
          ..rotateTo(azimuth: 120)
          ..feed('RPRT -5\nRPRT -21\n');
        async.elapse(rotctldPollInterval);
        session.feed('90.00\n0.00\n');
        expect(sink.problems.last, st.rotctldPastLimits(code: -21), reason: 'a position does not clear a refused turn');
      });
    });

    // Left waiting, it would take the next failed poll's RPRT as its own.
    test('a stop the server never answers is given up on at the next position after it', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = _connected(sink)
          ..stopRotation()
          ..feed('5.00\n0.00\n');
        async.elapse(rotctldPollInterval);
        session.feed('5.00\n0.00\n');
        async.elapse(rotctldPollInterval);
        session.feed('RPRT -6\n');
        expect(sink.problems, [st.rotctldReadFailed(code: -6)]);
      });
    });

    // Kept alive by it, the node reads as connected with no heading and no
    // reason, for as long as whatever is on that port keeps answering.
    test('an answer that is not rotctld is a problem, not a sign of life', () {
      final sink = _FakeSink();
      final session = _connected(sink);
      final aliveBefore = sink.alive;
      session.feed('?>\n');
      expect(sink.alive, aliveBefore);
      expect(sink.problems, [st.rotctldUnreadable]);
      session.feed('5.00\n0.00\n');
      expect(sink.problems.last, isNull);
    });

    // Paired across an RPRT, one stray line — an emulator that answers a
    // `p` with its azimuth alone — would shift every answer after it by
    // half, reading each azimuth as the last one's elevation.
    test('an answer cut short by an RPRT starts the pairing over', () {
      final sink = _FakeSink();
      _connected(sink, elevation: true)
        ..stopRotation()
        ..feed('7.00\nRPRT 0\n5.00\n0.00\n');
      expect(sink.positions, [const RotatorPosition(azimuth: 5, elevation: 0)]);
    });

    test('stop is S', () {
      final sink = _FakeSink();
      RotctldSession(sink).stopRotation();
      expect(sink.sent, [rotctldStopCommand]);
    });
  });

  test('a rotctld node offers offsets but no limits: the daemon reports its own', () {
    final keys = const RotctldDriver().configElements().map((element) => element['key']).toSet();
    expect(keys, containsAll(['rotatorAxes', 'azimuthOffset', 'pollInterval']));
    expect(keys, isNot(contains('azimuthMax')));
  });

  test('a heading in a range that starts below 0 takes the nearer of its ways round', () {
    const calibration = RotatorCalibration(azimuthMin: -180, azimuthMax: 450);
    expect(calibration.controllerAzimuth(270, from: 0), -90);
    expect(calibration.controllerAzimuth(270, from: 300), 270);
    expect(const RotatorCalibration(azimuthMin: -180, azimuthMax: 180).controllerAzimuth(180), -180);
  });
}

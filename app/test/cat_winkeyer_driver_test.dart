// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The K1EL WinKeyer host protocol, against the documents rather than a
// keyer — see winkeyer_driver.dart's header.

import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/winkeyer_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';

class _FakeSink implements EquipmentSink {
  final sent = <List<int>>[];
  final keyerSpeeds = <int>[];
  final progress = <CwSendProgress?>[];
  final diagnostics = <String?>[];
  final problems = <String?>[];

  @override
  void send(List<int> bytes) => sent.add(List.of(bytes));
  @override
  void report(VfoReading reading) => fail('a keyer has no VFO');
  @override
  void reportPower(num watts) => fail('a keyer has no power');
  @override
  void reportKeyerSpeed(int wpm) => keyerSpeeds.add(wpm);
  @override
  void reportCwProgress(CwSendProgress? p) => progress.add(p);
  @override
  void reportVoiceActivity(VoiceActivity? activity) => fail('a keyer has no voice memories');
  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);
  @override
  void reportProblem(String? message) => problems.add(message);
  @override
  void reportChannels(List<EquipmentChannel> channels) {}
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
  @override
  void reportAlive() {}
}

void main() {
  late _FakeSink sink;
  late WinkeyerSession session;

  setUp(() {
    sink = _FakeSink();
    session = WinkeyerSession(sink);
  });
  // The session owns timers once updates start; none may outlive its test.
  tearDown(() => session.teardown());

  void feed(List<int> bytes) => session.handleData(Uint8List.fromList(bytes));
  String sentText() => String.fromCharCodes(sink.sent.expand((b) => b));

  test('the driver says it keys, and its sessions are keyers with no VFO', () {
    expect(const WinkeyerDriver().canKeyCw, isTrue);
    expect(const WinkeyerDriver().hardwareVerified, isFalse, reason: 'written from the documents');
    expect(session, isA<CwKeyerSession>());
    expect(session, isNot(isA<TransceiverSession>()));
    expect(session.expectedUpdateInterval, isNull, reason: 'status, echo and pot arrive as they happen');
  });

  test('startUpdates opens host mode with serial echoback, and reads the version byte back', () {
    session.startUpdates();
    expect(sink.sent, [
      [0x00, 0x02], // host open
      [0x0E, 0x04], // set mode: serial echoback
      [0x05, 5, 40, 0x00], // pot range 5..45
      [0x07], // get speed pot: the speed is known from connect
    ]);
    feed([31]);
    expect(sink.diagnostics, ['WinKeyer v3.1']);
    // The version byte is a one-off: a later 31 is a character echo, not a
    // version.
    session.sendCw('E');
    feed([31]);
    expect(sink.diagnostics, hasLength(1));
  });

  group('speed', () {
    test('a set is sent as 0x02 and reported as taken, clamped to 5-99', () {
      session.setKeyerSpeed(25);
      expect(sink.sent.last, [0x02, 25]);
      expect(sink.keyerSpeeds, [25]);
      session.setKeyerSpeed(200);
      expect(sink.sent.last, [0x02, 99]);
      expect(session.keyerSpeedRange, (min: 5, max: 99));
    });

    test('a speed-pot report is 0x80 plus the position over the requested range', () {
      feed([0x80 | 15]);
      expect(sink.keyerSpeeds, [20]);
      session.refreshKeyerSpeed();
      expect(sink.keyerSpeeds, [20, 20], reason: 'nothing to ask the keyer; re-reports what it last said');
    });
  });

  group('sending', () {
    test('a message goes to the keyer as text, in bursts, and its echoes are its progress', () {
      session.sendCw('cq test');
      expect(sentText(), 'CQ TEST');
      expect(sink.progress.last!.text, 'CQ TEST');
      expect(sink.progress.last!.sentCount, 0, reason: 'reported, not estimated');

      feed('CQ '.codeUnits);
      expect(sink.progress.last!.sentCount, 3);
      feed([0xC0 | 0x04]); // busy
      feed('TEST'.codeUnits);
      expect(sink.progress.last!.sentCount, 7);
      expect(session.cwSending, isTrue, reason: 'the last element is still keying until the keyer says idle');
      feed([0xC0]); // idle
      expect(sink.progress.last, isNull);
      expect(session.cwSending, isFalse);
    });

    test('a long message is handed over 24 characters at a time, each echo freeing a slot, XOFF holding it', () {
      final text = List.filled(60, 'E').join();
      session.sendCw(text);
      expect(sentText().length, 24);
      // The keyer sends no status while it just keys along; an echo is what
      // says a slot is free — without this the rest waits for the keyer to
      // go idle, and the CW breaks at character 24.
      feed('E'.codeUnits);
      expect(sentText().length, 48);
      feed([0xC0 | 0x01]); // xoff: the buffer is two thirds full
      feed('E'.codeUnits);
      expect(sentText().length, 48, reason: 'an echo under XOFF is not permission');
      feed([0xC0]); // xon
      expect(sentText().length, 60);
    });

    test('a paddle break-in aborts the message and the queue — the keyer emptied its buffer', () {
      session.sendCw('CQ CQ');
      session.sendCw('TU');
      feed('C'.codeUnits);
      feed([0xC0 | 0x04 | 0x02]); // busy, break-in
      expect(sink.progress.last, isNull);
      expect(session.cwSending, isFalse);
      feed([0xC0]);
      expect(sentText(), 'CQ CQ', reason: 'TU was dropped with the rest, not started');
    });

    test('idle after everything was handed over ends the message even if an echo went missing', () {
      session.sendCw('CQ');
      feed('C'.codeUnits); // the Q's echo never arrives
      feed([0xC0 | 0x04]);
      feed([0xC0]);
      expect(sink.progress.last, isNull);
      expect(session.cwSending, isFalse);
    });

    test('a message pressed during another waits, and shows behind it', () {
      session.sendCw('CQ');
      session.sendCw('TU');
      expect(sentText(), 'CQ');
      expect(sink.progress.last!.pending, ['TU']);
      feed([0xC0 | 0x04]); // busy with CQ
      feed('CQ'.codeUnits);
      expect(sentText(), 'CQ', reason: 'echoed, but the keyer is still busy with its last element');
      feed([0xC0]); // idle: CQ is over, TU starts
      expect(sink.progress.last!.text, 'TU');
      expect(sentText(), 'CQTU');
    });

    test('dropQueuedCw drops one waiting message by id', () {
      session.sendCw('CQ');
      session.sendCw('5NN');
      session.sendCw('TU');
      final ids = sink.progress.last!.pendingIds;
      session.dropQueuedCw(ids.first);
      expect(sink.progress.last!.pending, ['TU']);
    });

    test('stopCw clears the keyer\'s buffer and drops everything', () {
      session.sendCw('CQ CQ');
      session.sendCw('TU');
      session.stopCw();
      expect(sink.sent.last, [0x0A]);
      expect(sink.progress.last, isNull);
      expect(session.cwSending, isFalse);
      feed('C'.codeUnits);
      expect(sink.progress.last, isNull, reason: 'a late echo of the cleared message reports nothing');
    });

    test('teardown clears and closes host mode, so the paddle keys standalone again', () {
      session.sendCw('CQ');
      session.teardown();
      expect(sink.sent.sublist(sink.sent.length - 2), [
        [0x0A],
        [0x00, 0x03],
      ]);
    });
  });

  test('a status or pot byte left over from an unclosed session is not read as the version', () {
    session.startUpdates();
    feed([0xC0]);
    feed([0x80 | 15]);
    expect(sink.diagnostics, isEmpty, reason: 'a version is never 0x80 or above');
    expect(sink.keyerSpeeds, [20], reason: 'and the pot report was still a pot report');
    feed([23]);
    expect(sink.diagnostics, ['WinKeyer v2.3']);
  });

  test('the pot answers the connect-time question, and that is the speed until the app sets one', () {
    session.startUpdates();
    expect(sink.sent.last, [0x07]);
    feed([0x80 | 20]);
    expect(sink.keyerSpeeds, [25]);
  });

  test('a set below the range is clamped up to 5', () {
    session.setKeyerSpeed(1);
    expect(sink.sent.last, [0x02, 5]);
  });

  test('idle, the keyer is asked for its status every 10 s, and the answer restates the speed', () {
    // The trap: a keyer in host mode pushes nothing while idle, so without
    // the poll the node reads as stale 30 s after every connect.
    fakeAsync((async) {
      session.startUpdates();
      feed([31]);
      feed([0x80 | 15]);
      expect(sink.keyerSpeeds, [20]);
      async.elapse(winkeyerStatusPoll);
      expect(sink.sent.last, [0x15]);
      feed([0xC0]);
      expect(sink.keyerSpeeds, [20, 20], reason: 'the status reply is the keyer saying it is there');
      async.elapse(winkeyerStatusPoll);
      expect(sink.sent.last, [0x15]);
      session.stopUpdates();
      final sentBefore = sink.sent.length;
      async.elapse(winkeyerStatusPoll * 3);
      expect(sink.sent.length, sentBefore, reason: 'stopUpdates ends the poll');
    });
  });

  test('a status reply with no speed known asks for the pot rather than saying nothing', () {
    fakeAsync((async) {
      session.startUpdates();
      feed([31]);
      async.elapse(winkeyerStatusPoll);
      feed([0xC0]);
      expect(sink.sent.last, [0x07]);
      expect(sink.keyerSpeeds, isEmpty);
    });
  });

  test('a port with no keyer on it is reported within 3 s, and the first byte back withdraws that', () {
    fakeAsync((async) {
      session.startUpdates();
      async.elapse(winkeyerAnswerTimeout - const Duration(milliseconds: 1));
      expect(sink.problems, isEmpty);
      async.elapse(const Duration(milliseconds: 1));
      expect(sink.problems, [isNotNull]);
      feed([31]);
      expect(sink.problems.last, isNull);
      expect(sink.diagnostics, ['WinKeyer v3.1']);
    });
  });

  test('a version that arrives in time raises nothing', () {
    fakeAsync((async) {
      session.startUpdates();
      feed([31]);
      async.elapse(winkeyerAnswerTimeout * 2);
      expect(sink.problems, isEmpty);
    });
  });

  test('a keyer that stops echoing mid-message is given up on, queue and all, and the operator told', () {
    fakeAsync((async) {
      session.startUpdates();
      feed([31]);
      session.sendCw('CQ');
      session.sendCw('TU');
      feed('C'.codeUnits);
      final timeline = cwCharacterEnds('CQ', defaultCwSpeedWpm).last;
      async.elapse(timeline + winkeyerSendGrace - const Duration(milliseconds: 1));
      expect(session.cwSending, isTrue, reason: 'still within the message\'s own time plus grace');
      async.elapse(const Duration(milliseconds: 1));
      expect(session.cwSending, isFalse);
      expect(sink.progress.last, isNull);
      expect(sink.sent.last, [0x0A], reason: 'whatever the keyer still holds is cleared');
      expect(sink.problems, [isNotNull]);
      feed([0xC0]);
      expect(sink.problems.last, isNull, reason: 'a byte from the keyer withdraws the problem');
    });
  });

  test('a message the keyer finishes leaves no watchdog behind', () {
    fakeAsync((async) {
      session.startUpdates();
      feed([31]);
      session.sendCw('CQ');
      feed([0xC0 | 0x04]);
      feed('CQ'.codeUnits);
      feed([0xC0]);
      expect(session.cwSending, isFalse);
      async.elapse(const Duration(minutes: 1));
      expect(sink.problems, isEmpty);
    });
  });
}

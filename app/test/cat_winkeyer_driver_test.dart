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
import 'package:ham2k_logger/services/cat/drivers/placeholder_radio_driver.dart';
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
  final txReports = <bool>[];
  final meterReports = <(RadioMeter, num)>[];
  @override
  void reportTransmitting(bool transmitting) => txReports.add(transmitting);
  @override
  void reportMeter(RadioMeter meter, num value) => meterReports.add((meter, value));

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

/// Opens host mode on [session]: the open, then the version byte it waits
/// for before it will configure anything.
void openHost(WinkeyerSession session) {
  session.startUpdates();
  session.handleData(Uint8List.fromList([31]));
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

  test('startUpdates sends the host open ALONE, and waits for the version byte to configure', () {
    // The trap: sending the setup alongside the open. Until the version byte
    // comes back the keyer is still closed and takes admin commands only, so
    // a mode or PINCFG write landing there is read against the wrong state
    // and silently lost — leaving the keyer keying on the previous
    // program's routing, which is the dead carrier.
    session.startUpdates();
    expect(sink.sent, [
      [0x00, 0x02], // host open, and NOTHING else
    ]);

    feed([31]);
    expect(sink.diagnostics, ['WinKeyer v3.1']);
    expect(sink.sent.sublist(1), [
      [0x0E, 0x04], // set mode: serial echoback
      [0x09, 0x08], // PINCFG: key port 1, no PTT
      [0x03, 50], // weight: no adjustment
      [0x17, 50], // dit/dah ratio: no adjustment
      [0x11, 0], // key compensation: none
      [0x04, 0, 0], // PTT lead-in and tail
      [0x05, 5, 40, 0x00], // pot range 5..45
      [0x02, 20], // a speed of our own, not the box's
      [0x07], // get speed pot: a real pot outranks it
    ]);

    // The version byte is a one-off: a later 31 is a character echo, not a
    // version, and must not re-run the configuration.
    final afterConfigure = sink.sent.length;
    session.sendCw('E');
    feed([31]);
    expect(sink.diagnostics, hasLength(1));
    expect(sink.sent.length, afterConfigure + 1, reason: 'the echo sent the text on, and nothing else');
  });

  group('PINCFG — which jack the keyer drives', () {
    // Every one of these is a register the keyer REMEMBERS between sessions.
    // A driver that writes none of them keys with whatever the last program
    // chose, and a PINCFG holding PTT with no key output makes the keyer sit
    // on a dead carrier for a whole message and key nothing.
    List<int> pinConfigFor({int? keyPort, bool? ptt}) {
      final probe = _FakeSink();
      final s = WinkeyerSession(
        probe,
        keyPort: keyPort ?? winkeyerDefaultKeyPort,
        ptt: ptt ?? false,
      );
      openHost(s);
      s.teardown();
      return probe.sent.firstWhere((b) => b.isNotEmpty && b.first == 0x09);
    }

    test('port 1 and port 2 each enable their own key output', () {
      expect(pinConfigFor(keyPort: 1), [0x09, 0x08]);
      expect(pinConfigFor(keyPort: 2), [0x09, 0x04]);
    });

    test('a key output is ALWAYS enabled, whatever PTT is set to', () {
      // The mutation this catches: composing PINCFG from the PTT bit alone.
      // 0x01 is a valid-looking byte the keyer accepts and answers normally
      // — it just never keys.
      for (final ptt in [true, false]) {
        for (final port in [1, 2]) {
          final pin = pinConfigFor(keyPort: port, ptt: ptt);
          expect(
            pin[1] & (0x08 | 0x04),
            isNonZero,
            reason: 'port $port with ptt=$ptt left the keyer with no key output',
          );
        }
      }
    });

    test('PTT is off unless asked for, so connecting cannot key an amplifier', () {
      expect(pinConfigFor(ptt: false)[1] & 0x01, 0);
      expect(pinConfigFor(ptt: true)[1] & 0x01, 0x01);
    });

    test('an entry saved before the field existed keys on port 1 rather than nothing', () {
      const driver = WinkeyerDriver();
      expect(winkeyerKeyPortFromConfig(const {}), 1);
      expect(winkeyerKeyPortFromConfig(const {'winkeyerKeyPort': '2'}), 2);
      expect(winkeyerKeyPortFromConfig(const {'winkeyerKeyPort': 2}), 2);
      // Nothing the hardware has: two jacks, so anything else is port 1.
      expect(winkeyerKeyPortFromConfig(const {'winkeyerKeyPort': '9'}), 1);
      expect(winkeyerKeyPortFromConfig(const {'winkeyerKeyPort': ''}), 1);
      expect(
        driver.configElements().map((e) => e['key']),
        containsAll(<String>['winkeyerKeyPort', 'winkeyerPtt']),
        reason: 'neither is discoverable, so both must be askable',
      );
    });
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

  test('a speed of our own on connect, which a real pot then outranks', () {
    // The trap this closes: taking the box's speed. On a keyer whose speed
    // is pot-locked and whose pot is absent — the WKmini has none — an
    // unwritten speed is whatever the ADC floats at.
    openHost(session);
    expect(sink.sent[sink.sent.length - 2], [0x02, defaultCwSpeedWpm]);
    expect(sink.sent.last, [0x07]);
    expect(sink.keyerSpeeds, [defaultCwSpeedWpm]);
    feed([0x80 | 20]);
    expect(sink.keyerSpeeds, [defaultCwSpeedWpm, 25], reason: 'a pot that reports wins');
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
      expect(sink.keyerSpeeds, [defaultCwSpeedWpm, 20]);
      async.elapse(winkeyerStatusPoll);
      expect(sink.sent.last, [0x15]);
      feed([0xC0]);
      expect(sink.keyerSpeeds, [defaultCwSpeedWpm, 20, 20],
          reason: 'the status reply is the keyer saying it is there');
      async.elapse(winkeyerStatusPoll);
      expect(sink.sent.last, [0x15]);
      session.stopUpdates();
      final sentBefore = sink.sent.length;
      async.elapse(winkeyerStatusPoll * 3);
      expect(sink.sent.length, sentBefore, reason: 'stopUpdates ends the poll');
    });
  });

  test('no text reaches a keyer that never opened host mode', () {
    // The same dead carrier by the other road: a keyer that never answered
    // our open may still be OPEN from the last program, and would key this
    // text on that program's routing. The operator is told by the watchdog
    // rather than left thinking it went out.
    fakeAsync((async) {
      session.startUpdates();
      session.sendCw('CQ');
      async.elapse(winkeyerAnswerTimeout);
      expect(sentText(), isNot(contains('CQ')), reason: 'host mode never opened');
      // And it is not lost: the version arriving releases it.
      feed([31]);
      expect(sentText(), contains('CQ'));
    });
  });

  group('the remembered speed', () {
    test('a reconnect keys at the speed the operator chose, not the default', () {
      // The trap: the service builds a NEW session per connect, so a session
      // that seeds its speed from nothing resets the operator to 20 WPM on
      // every USB glitch — mid-contest, a CQ going out slow with no notice.
      final probe = _FakeSink();
      final s = const WinkeyerDriver().createSession(probe, const {keyerSpeedConfigKey: 32}) as WinkeyerSession;
      openHost(s);
      expect(probe.sent, contains(equals([0x02, 32])));
      expect(probe.keyerSpeeds.first, 32);
      s.teardown();
    });

    test('a keyer nobody has set keys at the default', () {
      expect(winkeyerSpeedFromConfig(const {}), defaultCwSpeedWpm);
    });

    test('a stored speed outside what the keyer accepts is clamped, not sent raw', () {
      expect(winkeyerSpeedFromConfig(const {keyerSpeedConfigKey: 300}), winkeyerSpeedMax);
      expect(winkeyerSpeedFromConfig(const {keyerSpeedConfigKey: 1}), winkeyerSpeedMin);
      expect(winkeyerSpeedFromConfig(const {keyerSpeedConfigKey: 'nonsense'}), defaultCwSpeedWpm);
      // The blob is JSON, so a number that round-tripped as a string still
      // has to mean the speed the operator picked.
      expect(winkeyerSpeedFromConfig(const {keyerSpeedConfigKey: '32'}), 32);
    });

    test('only a keyer that cannot be asked opts into being remembered', () {
      expect(const WinkeyerDriver().remembersKeyerSpeed, isTrue);
      // A radio reads its own keyer menu, so storing a copy beside it would
      // only go stale against the front panel.
      expect(const PlaceholderRadioDriver().remembersKeyerSpeed, isFalse);
    });
  });

  test('the PTT flag reads the string spelling an override would carry', () {
    expect(winkeyerPttFromConfig(const {}), isFalse);
    expect(winkeyerPttFromConfig(const {winkeyerPttConfigKey: true}), isTrue);
    expect(winkeyerPttFromConfig(const {winkeyerPttConfigKey: 'true'}), isTrue,
        reason: 'the catalogue writes config values as strings');
    expect(winkeyerPttFromConfig(const {winkeyerPttConfigKey: 'false'}), isFalse);
  });

  test('a byte that is not the version leaves the open watch standing', () {
    // The trap, and the one that put the dead carrier back: a keyer the last
    // program left open pushes a status before answering our open. Treating
    // any byte as "the keyer answered" cancels the watch, so a keyer that
    // then never opens is never configured, never reported, and keys on
    // whatever routing it was left holding.
    fakeAsync((async) {
      session.startUpdates();
      feed([0xC0]);
      async.elapse(winkeyerAnswerTimeout * 3);
      expect(sink.problems.whereType<String>(), isNotEmpty, reason: 'the operator is told');
      expect(sink.sent.any((b) => b.isNotEmpty && b.first == 0x09), isFalse,
          reason: 'and nothing was configured, because host mode never opened');
    });
  });

  test('a version arriving late still opens host mode and withdraws the problem', () {
    fakeAsync((async) {
      session.startUpdates();
      feed([0xC0]);
      async.elapse(winkeyerAnswerTimeout * 3);
      expect(sink.problems.last, isNotNull);
      feed([31]);
      expect(sink.problems.last, isNull);
      expect(sink.sent.any((b) => b.isNotEmpty && b.first == 0x09), isTrue);
    });
  });

  test('the operator\'s stored key port reaches the wire', () {
    // The gap the session-level tests leave: they construct WinkeyerSession
    // directly, so dropping the config read in createSession — or renaming
    // the select's option values out from under the parser — keys port 1 for
    // everyone and stays green.
    const driver = WinkeyerDriver();
    List<int> pinFor(Map<String, dynamic> config) {
      final probe = _FakeSink();
      final s = driver.createSession(probe, config) as WinkeyerSession;
      openHost(s);
      s.teardown();
      return probe.sent.firstWhere((b) => b.isNotEmpty && b.first == 0x09);
    }

    expect(pinFor(const {winkeyerKeyPortConfigKey: '2'})[1] & 0x04, 0x04);
    expect(pinFor(const {winkeyerKeyPortConfigKey: '1'})[1] & 0x08, 0x08);
    expect(pinFor(const {winkeyerPttConfigKey: true})[1] & 0x01, 0x01);

    // Every value the picker offers must mean a port to the parser, or the
    // operator's choice silently becomes the default.
    final element = driver.configElements().firstWhere((e) => e['key'] == winkeyerKeyPortConfigKey);
    final ports = [
      for (final option in element['options'] as List)
        winkeyerKeyPortFromConfig({winkeyerKeyPortConfigKey: (option as Map)['value']}),
    ];
    expect(ports, [1, 2], reason: 'each option selects its own port');
  });

  test('an entry that pins the key port is not asked about it', () {
    expect(
      const WinkeyerDriver().configElements(overrides: {winkeyerKeyPortConfigKey: '2'}).map((e) => e['key']),
      isNot(contains(winkeyerKeyPortConfigKey)),
    );
  });

  test('a status reply restates the speed, which after connect is always known', () {
    fakeAsync((async) {
      openHost(session);
      async.elapse(winkeyerStatusPoll);
      feed([0xC0]);
      // Counted, not just inspected: the connect-time set already put one
      // speed in the list, so a `last` check passes with the restatement
      // deleted — the very thing this test names.
      expect(sink.keyerSpeeds, [defaultCwSpeedWpm, defaultCwSpeedWpm],
          reason: 'the poll answer is a sign of life, and there is always a speed to restate');
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

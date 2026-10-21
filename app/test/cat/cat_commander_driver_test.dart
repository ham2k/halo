// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The DXLab Commander driver with no Commander and no socket. This pins the
// messages as Commander's "TCPIP Messages" document gives them — ADIF field
// syntax, kHz, the locale a set is read in — and nothing more; no exchange
// with a real Commander has been captured, and HaLo does not emulate one.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/commander_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/commander_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';

class _FakeSink implements EquipmentSink {
  final sent = <String>[];
  final readings = <VfoReading>[];
  final txReports = <bool>[];
  final diagnostics = <String?>[];

  @override
  void send(List<int> bytes) => sent.add(ascii.decode(bytes));

  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);

  @override
  void report(VfoReading reading) => readings.add(reading);

  @override
  void reportTransmitting(bool transmitting) => txReports.add(transmitting);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

extension on CommanderSession {
  void feed(String text) => handleData(Uint8List.fromList(latin1.encode(text)));
}

/// A session past its locale question, answered in [locale] form.
({CommanderSession session, _FakeSink sink}) _started({String locale = '14,074.000'}) {
  final sink = _FakeSink();
  final session = CommanderSession(sink)..startUpdates();
  session
    ..feed(commanderField('CmdFreq', locale))
    ..feed(commanderField('CmdFreq', '14,074.000'))
    ..feed(commanderField('CmdMode', 'DATA-U'));
  return (session: session, sink: sink);
}

/// Steps time until a message naming [command] goes out.
void _untilAsked(FakeAsync async, _FakeSink sink, String command) {
  final seen = sink.sent.length;
  for (var i = 0; i < 400; i++) {
    async.elapse(const Duration(milliseconds: 50));
    if (sink.sent.length > seen && sink.sent.last.contains(command)) return;
  }
  fail('never asked $command');
}

void main() {
  group('the codec', () {
    test('writes a request as the document spells it', () {
      expect(commanderMessage('CmdGetFreq'), '<command:10>CmdGetFreq<parameters:0>');
      expect(commanderMessage('CmdSetFreq', commanderField('xcvrfreq', '21230')), '<command:10>CmdSetFreq<parameters:17><xcvrfreq:5>21230');
      expect(commanderMessage('CmdSetMode', commanderField('1', 'CW')), '<command:10>CmdSetMode<parameters:7><1:2>CW');
    });

    test('reads a field split across reads only once it is whole', () {
      expect(takeCommanderField('<CmdFreq:10>14,01'), isNull);
      expect(takeCommanderField('<CmdFr'), isNull);
      final field = takeCommanderField('<CmdFreq:10>14,010.500<CmdMode:2>CW')!;
      expect((field.name, field.value, field.consumed), ('CmdFreq', '14,010.500', 22));
    });

    test('reads kHz with thousands separators, and `.000` as no frequency', () {
      expect(commanderKHz('14,010.500'), 14010.5);
      expect(commanderKHz('.000'), isNull);
      // The locale form, landing on this question out of step: read as the
      // fixed form it would be 14.074 kHz.
      expect(commanderKHz('14.074,000'), isNull);
    });

    test('a header claiming an impossible length is not a header', () {
      // Parsed, the first throws on overflow and the second holds every
      // answer behind it until 64K of them pile up.
      expect(takeCommanderField('<x:99999999999999999999><CmdFreq:10>14,074.000')?.value, '14,074.000');
      expect(takeCommanderField('<x:99999><CmdFreq:10>14,074.000')?.value, '14,074.000');
    });

    test('tells the locale\'s decimal separator from a locale-form answer', () {
      expect(commanderDecimalSeparator('14,010.500'), '.');
      expect(commanderDecimalSeparator('14.010,500'), ',');
      expect(commanderDecimalSeparator('14 010,500'), ',');
      expect(commanderDecimalSeparator('.000'), '.');
      expect(commanderDecimalSeparator('14074,500'), ',', reason: 'a locale with no thousands separator');
    });

    test('does not guess at a separator that could be either', () {
      // Without decimals, `14,010` is a thousands separator — taken as the
      // decimal, a set would go out as `14074,5` to a period-locale Commander.
      expect(commanderDecimalSeparator('14,010'), isNull);
      // Two of the SAME separator prove nothing: 23 cm without decimals.
      expect(commanderDecimalSeparator('1,296,100'), isNull);
    });
  });

  test('opens by learning the locale, then reads frequency and mode, one message at a time', () {
    fakeAsync((async) {
      final sink = _FakeSink();
      final session = CommanderSession(sink)..startUpdates();
      expect(sink.sent, ['<command:11>CmdSendFreq<parameters:0>']);
      session.feed('<CmdFreq:10>14,074.000');
      expect(sink.sent.last, '<command:10>CmdGetFreq<parameters:0>');
      session.feed('<CmdFreq:10>14,074.000');
      expect(sink.sent.last, '<command:11>CmdSendMode<parameters:0>');
      session.feed('<CmdMode:6>DATA-U');
      // The locale answer is not a reading: it is the same frequency again.
      expect(sink.readings, [const VfoReading(freqKHz: 14074), const VfoReading(mode: 'DATA-USB')]);
      session.teardown();
    });
  });

  test('a fractional kHz is set in the locale Commander reads it in', () {
    fakeAsync((async) {
      final comma = _started(locale: '14.074,000');
      comma.session.setFrequency(14074.5);
      async.elapse(const Duration(milliseconds: 10));
      // With a period, a comma-locale Commander reads 14074.5 as 140745.
      expect(comma.sink.sent.last, '<command:10>CmdSetFreq<parameters:19><xcvrfreq:7>14074,5');
      comma.session.teardown();

      final period = _started();
      period.session.setFrequency(14074.5);
      async.elapse(const Duration(milliseconds: 10));
      expect(period.sink.sent.last, '<command:10>CmdSetFreq<parameters:19><xcvrfreq:7>14074.5');
      period.session.teardown();
    });
  });

  test('a whole kHz carries no separator at all', () {
    expect(commanderFrequency(21230, decimal: ','), '21230');
    expect(commanderFrequency(7030.25, decimal: '.'), '7030.25');
    expect(commanderFrequency(7030.6, decimal: null), '7031');
  });

  test('a set asked for before the locale is known waits for it', () {
    fakeAsync((async) {
      final sink = _FakeSink();
      final session = CommanderSession(sink)..startUpdates();
      session.setFrequency(7030.5);
      session.feed('<CmdFreq:9>7.030,000');
      session.feed('<CmdFreq:9>7,030.000');
      session.feed('<CmdMode:2>CW');
      expect(sink.sent.last, contains('<xcvrfreq:6>7030,5'));
      session.teardown();
    });
  });

  test('a set is followed by a pause, since Commander does not answer it', () {
    fakeAsync((async) {
      final (:session, :sink) = _started();
      session
        ..setFrequency(21074)
        ..setMode('CW');
      expect(sink.sent.last, contains('CmdSetFreq'));
      async.elapse(const Duration(milliseconds: 150));
      expect(sink.sent.last, '<command:10>CmdSetMode<parameters:7><1:2>CW');
      session.teardown();
    });
  });

  test('modes cross in Commander\'s own names', () {
    expect(appModeForCommanderMode('DATA-L'), 'DATA-LSB');
    expect(appModeForCommanderMode('RTTY-R'), 'RTTY-USB');
    expect(commanderModeForAppMode('DATA-USB'), 'DATA-U');
    // Outside Commander's list: nothing is sent rather than a mode it
    // ignores.
    expect(commanderModeForAppMode('FT8'), isNull);
  });

  /// Answers the state polls as they come, and CmdSendTX only when
  /// [answerTx] says so; returns how many of each were asked.
  ({int tx, int freq}) runAnswering(FakeAsync async, CommanderSession session, _FakeSink sink, Duration span, {required bool Function() answerTx}) {
    var seen = sink.sent.length;
    var tx = 0, freq = 0;
    for (var t = Duration.zero; t < span; t += const Duration(milliseconds: 50)) {
      async.elapse(const Duration(milliseconds: 50));
      if (sink.sent.length == seen) continue;
      seen = sink.sent.length;
      final last = sink.sent.last;
      if (last.contains('CmdGetFreq')) {
        freq++;
        session.feed('<CmdFreq:10>14,074.000');
      } else if (last.contains('CmdSendMode')) {
        session.feed('<CmdMode:6>DATA-U');
      } else if (last.contains('CmdSendTX')) {
        tx++;
        if (answerTx()) session.feed('<CmdTX:3>OFF');
      }
    }
    return (tx: tx, freq: freq);
  }

  test('a radio Commander cannot read PTT from is asked rarely, and its frequency still follows', () {
    fakeAsync((async) {
      final (:session, :sink) = _started();
      // Each unanswered CmdSendTX holds the wire for a second.
      final counts = runAnswering(async, session, sink, const Duration(seconds: 20), answerTx: () => false);
      expect(counts.tx, lessThanOrEqualTo(6), reason: 'two misses, then one ask every five seconds');
      expect(counts.freq, greaterThanOrEqualTo(5));
      session.teardown();
    });
  });

  test('PTT survives Commander going quiet for a few seconds', () {
    fakeAsync((async) {
      final (:session, :sink) = _started();
      // Busy for a while — a band change, a Windows hiccup — then back.
      runAnswering(async, session, sink, const Duration(seconds: 4), answerTx: () => false);
      final later = runAnswering(async, session, sink, const Duration(seconds: 15), answerTx: () => true);
      // Stopped for good, the watch would never ask again; slowed, it asks,
      // is answered, and is back to every tick.
      expect(later.tx, greaterThan(20));
      session.teardown();
    });
  });

  test('a late locale answer is not read as a frequency, and the locale is asked again', () {
    fakeAsync((async) {
      final sink = _FakeSink();
      final session = CommanderSession(sink)..startUpdates();
      async.elapse(const Duration(milliseconds: 1100));
      // The CmdSendFreq answer arrives after its timeout. Taken as the
      // answer to CmdGetFreq, `14.074,500` would report 14.0745 kHz.
      session.feed('<CmdFreq:10>14.074,500');
      async.elapse(const Duration(milliseconds: 600));
      expect(sink.readings, isEmpty);
      expect(sink.sent.last, '<command:10>CmdGetFreq<parameters:0>');
      session
        ..feed('<CmdFreq:10>14,074.500')
        ..feed('<CmdMode:2>CW');
      expect(sink.readings.first, const VfoReading(freqKHz: 14074.5));
      _untilAsked(async, sink, 'CmdSendFreq');
      session.feed('<CmdFreq:10>14.074,500');
      session.setFrequency(7030.5);
      session
        ..feed('<CmdFreq:10>14,074.500')
        ..feed('<CmdMode:2>CW');
      expect(sink.sent.last, contains('<xcvrfreq:6>7030,5'));
      session.teardown();
    });
  });

  test('an answer that cannot settle the separator is asked again, and sets go out whole until it is', () {
    fakeAsync((async) {
      // A radio that is off: `0,000` could be either separator.
      final (:session, :sink) = _started(locale: '0,000');
      session.setFrequency(14025.4);
      async.elapse(const Duration(milliseconds: 150));
      // Guessed as a period, a comma-locale Commander would read 14025.4 a
      // thousand times off; whole kHz reads the same everywhere.
      expect(sink.sent.last, contains('<xcvrfreq:5>14025'));
      _untilAsked(async, sink, 'CmdSendFreq');
      session.feed('<CmdFreq:10>14.025,000');
      session.setFrequency(14025.5);
      session
        ..feed('<CmdFreq:10>14,025.000')
        ..feed('<CmdMode:2>CW');
      expect(sink.sent.last, contains('<xcvrfreq:7>14025,5'));
      session.teardown();
    });
  });

  test('a Commander that never answers the locale question stops being asked it', () {
    fakeAsync((async) {
      final sink = _FakeSink();
      final session = CommanderSession(sink)..startUpdates();
      var seen = 0;
      var freq = 0;
      // Twenty seconds, answering everything but CmdSendFreq. Asked on every
      // poll, each one would stall the frequency behind it for a second and
      // a half.
      for (var i = 0; i < 400; i++) {
        async.elapse(const Duration(milliseconds: 50));
        if (sink.sent.length == seen) continue;
        seen = sink.sent.length;
        final last = sink.sent.last;
        if (last.contains('CmdGetFreq')) {
          freq++;
          session.feed('<CmdFreq:10>14,074.000');
        } else if (last.contains('CmdSendMode')) {
          session.feed('<CmdMode:2>CW');
        } else if (last.contains('CmdSendTX')) {
          session.feed('<CmdTX:3>OFF');
        }
      }
      expect(sink.sent.where((s) => s.contains('CmdSendFreq')), hasLength(3));
      expect(freq, greaterThanOrEqualTo(5));
      // And sets stay in whole kHz, which read the same in every locale.
      session.setFrequency(14074.4);
      async.elapse(const Duration(seconds: 2));
      expect(sink.sent.where((s) => s.contains('CmdSetFreq')).last, contains('<xcvrfreq:5>14074'));
      session.teardown();
    });
  });

  test('an unanswered question and an answer under the wrong name each say so, once', () {
    fakeAsync((async) {
      final sink = _FakeSink();
      final session = CommanderSession(sink)..startUpdates();
      session.feed('<CmdFreq:10>14,074.000');
      // CmdGetFreq answered as something else: a Commander version whose
      // names differ from the document's.
      session.feed('<CmdFrequency:10>14,074.000');
      expect(sink.diagnostics.single, contains('CMDFREQUENCY'));
      async.elapse(const Duration(seconds: 2));
      expect(sink.diagnostics, hasLength(2));
      expect(sink.diagnostics.last, contains('did not answer a frequency'));
      session.teardown();
    });
  });

  test('PTT is read from CmdSendTX where the radio answers it', () {
    fakeAsync((async) {
      final (:session, :sink) = _started();
      async.elapse(const Duration(milliseconds: 250));
      expect(sink.sent.last, '<command:9>CmdSendTX<parameters:0>');
      session.feed('<CmdTX:2>ON');
      expect(sink.txReports, [true]);
      session.teardown();
    });
  });

  group('a raw message', () {
    test('unanswered is answered empty, and leaves the driver\'s diagnostic for its own questions', () {
      fakeAsync((async) {
        final (:session, :sink) = _started();
        final answers = <List<int>>[];
        session.sendRaw(latin1.encode('<command:9>CmdNothing<parameters:0>'), onAnswer: answers.add);
        expect(sink.sent.last, contains('CmdNothing'));
        // Just past its answer timeout: any longer, and the driver's own polls
        // queued behind it go unanswered too, which is theirs to report.
        async.elapse(const Duration(milliseconds: 1001));
        expect(answers, [<int>[]]);
        expect(sink.diagnostics, isEmpty);
        session.teardown();
      });
    });

    test('wanting a reply is asked in its turn, and answered by the field that comes, as Commander sent it', () {
      fakeAsync((async) {
        final (:session, :sink) = _started();
        final answers = <String>[];
        final readings = sink.readings.length;
        expect(session.sendRaw(latin1.encode('<command:10>CmdGetFreq<parameters:0>'), onAnswer: (a) => answers.add(latin1.decode(a))), 1);
        expect(sink.sent.last, '<command:10>CmdGetFreq<parameters:0>');
        session.feed('<CmdFreq:10>14,200.000');
        expect(answers, ['<CmdFreq:10>14,200.000']);
        expect(sink.readings, hasLength(readings), reason: 'the extension\'s answer, not a reading');
        session.teardown();
      });
    });

    test('wanting none goes out as a set does, and holds nothing up waiting for an answer', () {
      // Asked, a raw set — which Commander never answers — would hold the
      // line for the whole answer timeout and its drain.
      fakeAsync((async) {
        final (:session, :sink) = _started();
        expect(session.sendRaw(latin1.encode('<command:5>CmdTX<parameters:0>')), 0);
        expect(sink.sent.last, '<command:5>CmdTX<parameters:0>');
        session.setFrequency(14200);
        async.elapse(const Duration(milliseconds: 150));
        expect(sink.sent.last, contains('CmdSetFreq'));
        session.teardown();
      });
    });
  });
}

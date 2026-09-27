// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The HRD driver with no HRD and no socket. This pins the protocol as its
// published descriptions give it — the frame, the context prefix, the
// dropdown a mode lives in — and the discipline that keeps an answer
// matched to its question. It does NOT establish that a real HRD answers
// this way; nothing has been captured from one.

import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/hrd_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/hrd_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';

class _FakeSink implements EquipmentSink {
  final sent = <String>[];
  final readings = <VfoReading>[];
  final txReports = <bool>[];
  final diagnostics = <String?>[];

  @override
  void send(List<int> bytes) {
    final frame = takeHrdFrame(Uint8List.fromList(bytes), maxLength: 1 << 20)!;
    expect(frame.consumed, bytes.length, reason: 'one frame per send');
    sent.add(frame.text);
  }

  @override
  void report(VfoReading reading) => readings.add(reading);

  @override
  void reportTransmitting(bool transmitting) => txReports.add(transmitting);

  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

extension on HrdSession {
  void answer(String text) => handleData(encodeHrdFrame(text));
}

/// A session past its opening questions, on a radio whose mode dropdown is
/// [dropdown] with [items].
({HrdSession session, _FakeSink sink}) _started({String dropdown = 'Mode', String items = 'LSB,USB,CW,CW-R,USB-D,LSB-D,FM,AM', String buttons = 'TX,Tune'}) {
  final sink = _FakeSink();
  final session = HrdSession(sink)..startUpdates();
  session
    ..answer('1')
    ..answer('$dropdown,AGC')
    ..answer(buttons)
    ..answer('14074000')
    ..answer('$dropdown: USB')
    ..answer(items);
  return (session: session, sink: sink);
}

/// Steps time until a question ending [command] is the one on the wire.
void _untilAsked(FakeAsync async, _FakeSink sink, String command) {
  final seen = sink.sent.length;
  for (var i = 0; i < 200; i++) {
    async.elapse(const Duration(milliseconds: 50));
    if (sink.sent.length > seen && sink.sent.last.endsWith(command)) return;
  }
  fail('never asked $command');
}

void main() {
  test('opens by learning the context, the mode dropdown and its items, one question at a time', () {
    fakeAsync((async) {
      final sink = _FakeSink();
      final session = HrdSession(sink)..startUpdates();
      // A reply names no command, so a second question on the wire would
      // leave its answer unattributable.
      expect(sink.sent, ['get context']);

      session.answer('1');
      // Everything after the context carries its prefix.
      expect(sink.sent.last, '[1] get dropdowns');

      session.answer('Main Mode,Sub Mode,AGC');
      expect(sink.sent.last, '[1] get buttons');
      session.answer('TX');
      expect(sink.sent.last, '[1] get frequency');
      session.answer('14074000');
      // The mode read was queued before the dropdown was known, and still
      // names it: the text is built when it is sent.
      expect(sink.sent.last, '[1] get dropdown-text {Main Mode}');
      session.answer('Main Mode: USB-D');
      expect(sink.sent.last, '[1] get dropdown-list {Main Mode}');

      expect(sink.readings, [const VfoReading(freqKHz: 14074), const VfoReading(mode: 'DATA-USB')]);
      session.teardown();
    });
  });

  test('an opening question that goes unanswered is asked again, ahead of the polls that need it', () {
    fakeAsync((async) {
      final sink = _FakeSink();
      final session = HrdSession(sink)..startUpdates();
      session.answer('1');
      expect(sink.sent.last, '[1] get dropdowns');
      // HRD busy at connect. Asked only once, a missed answer would leave the
      // session without a mode dropdown — no mode read, no mode set — until
      // a reconnect.
      async.elapse(const Duration(milliseconds: 2600));
      expect(sink.sent.last, '[1] get dropdowns');
      session.answer('Mode');
      session.answer('TX');
      session.answer('14074000');
      expect(sink.sent.last, '[1] get dropdown-text {Mode}');
      session.teardown();
    });
  });

  test('an opening question answered with an error is asked again once HRD can answer it', () {
    fakeAsync((async) {
      final sink = _FakeSink();
      final session = HrdSession(sink)..startUpdates();
      // HRD running, its radio not connected yet.
      session
        ..answer('1')
        ..answer('ERROR: no radio')
        ..answer('ERROR: no radio')
        ..answer('ERROR: no radio');
      // The radio comes up. Only questions that go UNANSWERED are retried on
      // a timeout, so without the poll asking again, mode and PTT would stay
      // dead for the connection while the frequency kept the row healthy.
      var seen = sink.sent.length;
      for (var i = 0; i < 100; i++) {
        async.elapse(const Duration(milliseconds: 50));
        if (sink.sent.length == seen) continue;
        seen = sink.sent.length;
        final asked = sink.sent.last;
        session.answer(switch (asked) {
          _ when asked.endsWith('get dropdowns') => 'Mode',
          _ when asked.contains('dropdown-list') => 'LSB,USB,CW',
          _ when asked.endsWith('get buttons') => 'TX',
          _ when asked.endsWith('get frequency') => '14074000',
          _ when asked.contains('dropdown-text') => 'Mode: CW',
          _ => '0',
        });
      }
      expect(sink.readings.where((r) => r.mode == 'CW'), isNotEmpty);
      expect(sink.sent.where((s) => s.contains('button-select')), isNotEmpty);
      session.setMode('USB');
      async.elapse(const Duration(milliseconds: 50));
      expect(sink.sent.where((s) => s.contains('set dropdown Mode USB 1')), isNotEmpty);
      session.teardown();
    });
  });

  test('a radio whose dropdowns name no mode says which it has', () {
    fakeAsync((async) {
      final sink = _FakeSink();
      final session = HrdSession(sink)..startUpdates();
      session
        ..answer('1')
        ..answer('AGC,Filter,Band');
      expect(sink.diagnostics.single, contains('AGC, Filter, Band'));
      session.teardown();
    });
  });

  test('a reply that is not an HRD frame says so', () {
    fakeAsync((async) {
      final sink = _FakeSink();
      final session = HrdSession(sink)..startUpdates();
      // A peer answering in plain text, or another service on the port.
      session.handleData(Uint8List.fromList('14074000\n'.codeUnits));
      expect(sink.diagnostics.single, contains('not an HRD frame'));
      session.teardown();
    });
  });

  test('the mode dropdown is the one named for the mode, not the first naming one', () {
    fakeAsync((async) {
      final sink = _FakeSink();
      final session = HrdSession(sink)..startUpdates();
      session
        ..answer('1')
        // Taken as the mode dropdown, AGC Mode's FAST/SLOW would be reported
        // as the radio's mode, and set as one.
        ..answer('AGC Mode,Scope Mode,Mode A,Mode B')
        ..answer('Tune')
        ..answer('14074000');
      expect(sink.sent.last, '[1] get dropdown-text {Mode A}');
      session.teardown();
    });
  });

  test('a mode is read in whichever spelling the radio family uses', () {
    expect(appModeForHrdMode('PKT-U'), 'DATA-USB');
    expect(appModeForHrdMode('USB-D'), 'DATA-USB');
    expect(appModeForHrdMode('DATA-U'), 'DATA-USB');
    expect(appModeForHrdMode('FSK'), 'RTTY-LSB');
    expect(appModeForHrdMode('FSK-R'), 'RTTY-USB');
    // A Yaesu's CW-U is its ordinary CW; reading it as reverse would log
    // every CW contact on a Yaesu as CW-R.
    expect(appModeForHrdMode('CW-U'), 'CW');
    expect(appModeForHrdMode('CW-L'), 'CW-R');
    expect(appModeForHrdMode('DV'), 'DV');
  });

  test('a mode is set by the radio\'s own item name and its place in the list', () {
    fakeAsync((async) {
      final (:session, :sink) = _started(dropdown: 'Main Mode');
      session.setMode('DATA-USB');
      expect(sink.sent.last, '[1] set dropdown Main~Mode USB-D 4');
      session.teardown();
    });
  });

  test('no mode is set before HRD has listed them, or for one the radio lacks', () {
    fakeAsync((async) {
      final sink = _FakeSink();
      final session = HrdSession(sink)..startUpdates();
      session.setMode('USB');
      async.elapse(const Duration(seconds: 10));
      // A guessed name and index selects whatever sits at that index.
      expect(sink.sent.where((s) => s.contains('set dropdown')), isEmpty);
      session.teardown();

      final started = _started(items: 'LSB,USB,CW');
      started.session.setMode('DATA-USB');
      expect(started.sink.sent.where((s) => s.contains('set dropdown')), isEmpty);
      started.session.teardown();
    });
  });

  test('a frequency is set in Hz', () {
    fakeAsync((async) {
      final (:session, :sink) = _started();
      session.setFrequency(7030.5);
      expect(sink.sent.last, '[1] set frequency-hz 7030500');
      session.teardown();
    });
  });

  test('frames split and joined across reads are each taken once, in order', () {
    fakeAsync((async) {
      final sink = _FakeSink();
      final session = HrdSession(sink)..startUpdates();
      final both = [...encodeHrdFrame('1'), ...encodeHrdFrame('Mode')];
      session.handleData(Uint8List.fromList(both.sublist(0, 7)));
      session.handleData(Uint8List.fromList(both.sublist(7, 30)));
      session.handleData(Uint8List.fromList(both.sublist(30)));
      expect(sink.sent, ['get context', '[1] get dropdowns', '[1] get buttons']);
      session.teardown();
    });
  });

  test('a question HRD never answers is given up on, so the polls behind it still run', () {
    fakeAsync((async) {
      final sink = _FakeSink();
      final session = HrdSession(sink)..startUpdates();
      // `get context` goes unanswered — an HRD that does not know it. Asked
      // three times, then the session goes on without a prefix.
      async.elapse(const Duration(seconds: 8));
      expect(sink.sent.take(4), ['get context', 'get context', 'get context', 'get dropdowns']);
      expect(sink.diagnostics.single, contains('context'));
      session.teardown();
    });
  });

  test('an answer that arrives after its question was given up on is dropped, not given to the next one', () {
    fakeAsync((async) {
      final (:session, :sink) = _started(buttons: 'Tune');
      _untilAsked(async, sink, 'get frequency');
      async.elapse(const Duration(milliseconds: 2100));
      // HRD answers late. The mode read has not gone out: nothing is sent
      // while the line drains.
      session.answer('14075000');
      expect(sink.sent.last, '[1] get frequency');
      async.elapse(const Duration(milliseconds: 600));
      expect(sink.sent.last, '[1] get dropdown-text {Mode}');
      session.answer('Mode: CW');
      // In step: the mode read got the mode, and the late frequency went
      // nowhere — read as the next answer, `14075000` would be a mode.
      expect(sink.readings.last, const VfoReading(mode: 'CW'));
      expect(sink.readings.where((r) => r.mode == '14075000'), isEmpty);
      session.teardown();
    });
  });

  test('after a question is given up on, nothing is sent until its late answer has had time to land', () {
    fakeAsync((async) {
      final (:session, :sink) = _started(buttons: 'Tune');
      _untilAsked(async, sink, 'get frequency');
      async.elapse(const Duration(milliseconds: 2100));
      // Sent at once, the set's `OK` would follow the late frequency, and
      // each would be read as the answer to the question after its own.
      session.setFrequency(7030);
      expect(sink.sent.last, '[1] get frequency');
      async.elapse(const Duration(milliseconds: 600));
      expect(sink.sent.last, '[1] get dropdown-text {Mode}');
      session.teardown();
    });
  });

  test('an answer shaped wrong for its question is not taken for it', () {
    fakeAsync((async) {
      final (:session, :sink) = _started(buttons: 'Tune');
      _untilAsked(async, sink, 'get frequency');
      final before = sink.readings.length;
      // The PTT watch's `1`, out of step.
      session.answer('1');
      expect(sink.readings, hasLength(before));
      session.teardown();
    });
  });

  test('RTTY is set by whatever the radio calls it', () {
    fakeAsync((async) {
      // The app sends RTTY; a Kenwood's dropdown says FSK.
      final (:session, :sink) = _started(items: 'LSB,USB,CW,FSK,FSK-R,PKT-U');
      session.setMode('RTTY');
      expect(sink.sent.last, '[1] set dropdown Mode FSK 3');
      session.teardown();
    });
  });

  test('a PTT question HRD ignores is asked rarely, and the frequency still follows', () {
    fakeAsync((async) {
      final (:session, :sink) = _started();
      var seen = sink.sent.length;
      var tx = 0, freq = 0;
      for (var i = 0; i < 400; i++) {
        async.elapse(const Duration(milliseconds: 50));
        if (sink.sent.length == seen) continue;
        seen = sink.sent.length;
        final asked = sink.sent.last;
        if (asked.contains('button-select')) {
          tx++;
        } else if (asked.endsWith('get frequency')) {
          freq++;
          session.answer('14074000');
        } else if (asked.contains('dropdown-text')) {
          session.answer('Mode: USB');
        }
      }
      // Twenty seconds. Each ignored question holds the wire for two; asked
      // on every tick behind one another, they would leave the frequency a
      // gap that almost never opens.
      expect(tx, lessThanOrEqualTo(5));
      expect(freq, greaterThanOrEqualTo(5));
      session.teardown();
    });
  });

  test('an error reply answers its question with nothing', () {
    fakeAsync((async) {
      final (:session, :sink) = _started();
      final before = sink.readings.length;
      async.elapse(const Duration(seconds: 4));
      expect(sink.sent.last, '[1] get frequency');
      session.answer('ERROR: no frequency');
      expect(sink.readings, hasLength(before));
      session.teardown();
    });
  });

  test('PTT is watched only where the radio has a TX button', () {
    fakeAsync((async) {
      final keyed = _started();
      async.elapse(const Duration(milliseconds: 250));
      expect(keyed.sink.sent.last, '[1] get button-select TX');
      keyed.session.answer('1');
      expect(keyed.sink.txReports, [true]);
      keyed.session.teardown();

      final noButton = _started(buttons: 'Tune,Lock');
      async.elapse(const Duration(seconds: 5));
      expect(noButton.sink.sent.where((s) => s.contains('button-select')), isEmpty);
      noButton.session.teardown();
    });
  });

  test('the TX watch\'s answers do not defer the frequency poll', () {
    fakeAsync((async) {
      final (:session, :sink) = _started();
      // An HRD that answers everything, on a radio sitting still.
      var answered = sink.sent.length;
      void run(Duration span) {
        for (var t = Duration.zero; t < span; t += const Duration(milliseconds: 50)) {
          async.elapse(const Duration(milliseconds: 50));
          if (sink.sent.length == answered) continue;
          answered = sink.sent.length;
          final asked = sink.sent.last;
          session.answer(
            asked.endsWith('get frequency')
                ? '14074000'
                : asked.contains('dropdown-text')
                ? 'Mode: USB'
                : '0',
          );
        }
      }

      // Long enough for the poller to settle on its slow cadence.
      run(const Duration(seconds: 20));
      final before = sink.sent.where((s) => s.endsWith('get frequency')).length;
      // Two slow intervals, well inside AdaptivePoller's staleness ceiling.
      // Counted as news about the radio, the PTT answers arriving several
      // times a second would defer every frequency read to that ceiling.
      run(const Duration(seconds: 6));
      expect(sink.sent.where((s) => s.endsWith('get frequency')).length - before, greaterThanOrEqualTo(2));
      session.teardown();
    });
  });
}

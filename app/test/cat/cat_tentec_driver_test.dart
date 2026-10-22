// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Ten-Tec session (Eagle, Orion, Orion II) against a stand-in radio
// that answers from its own state the way the guides say the real ones do.
// Nothing here has met hardware.
//
// The trap most of these guard: the Eagle's refusal is a bare `Z`. Two
// questions on the wire, or a set's refusal landing on the read-back behind
// it, and the session pins a refusal on a read the radio has — and stops
// asking it for the rest of the connection.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/tentec_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/tentec_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';

class _FakeSink implements EquipmentSink, PassbandSink {
  final sent = <String>[];
  final readings = <VfoReading>[];
  final txReports = <bool>[];
  final meters = <(RadioMeter, num)>[];
  final powers = <num>[];
  final diagnostics = <String?>[];
  final problems = <String?>[];
  final passbands = <Passband?>[];

  @override
  void send(List<int> bytes) => sent.add(ascii.decode(bytes));
  @override
  void report(VfoReading reading) => readings.add(reading);
  @override
  void reportPower(num watts) => powers.add(watts);
  @override
  void reportTransmitting(bool transmitting) => txReports.add(transmitting);
  @override
  void reportMeter(RadioMeter meter, num value) => meters.add((meter, value));
  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);
  @override
  void reportProblem(String? message) => problems.add(message);
  @override
  void reportPassband(Passband? passband) => passbands.add(passband);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A radio that answers each query from its state, and takes each set into
/// it — or refuses what [refuse] names with the dialect's refusal.
class _Radio {
  final TenTecDialect dialect;
  String kv = 'AAA';
  int a = 14074000, b = 7074000;
  String mode = '0';
  int power = 50, filter = 2400, shift = 0;
  String signal = '@SRM10';
  bool keyer = true;
  int speed = 22;
  final refuse = <String>{};

  /// Commands the radio leaves unanswered, for a test to answer by hand.
  final withhold = <String>{};

  _Radio(this.dialect);

  String _refusal(String command) => dialect == TenTecDialect.orion ? 'Z!${command.substring(0, 2)}' : 'Z';

  String? answer(String line) {
    final command = line.substring(0, line.length - 1);
    if (command.startsWith('/') || withhold.contains(command)) return null;
    final name = command.substring(1).replaceAll(RegExp(r'[-+]?\d+$'), '');
    // A bare name refuses the set and the query; `*RMF` or `?RMF` only one.
    if (refuse.any((r) => name.startsWith(r) || command.startsWith(r))) return _refusal(command);
    if (command.startsWith('*')) {
      final value = command.substring(1 + name.length);
      switch (name) {
        case 'AF':
          a = int.parse(value);
        case 'BF':
          b = int.parse(value);
        case 'RMM':
          mode = value;
        case 'TP':
          power = int.parse(value);
        case 'RMF':
          filter = int.parse(value);
        case 'RMP':
          shift = int.parse(value);
        case 'CS':
          speed = int.parse(value);
        default:
          if (name.startsWith('KV')) kv = name.substring(2);
      }
      return null;
    }
    return switch (name) {
      'KV' => '@KV$kv',
      'AF' => '@AF${a.toString().padLeft(8, '0')}',
      'BF' => '@BF${b.toString().padLeft(8, '0')}',
      'RMM' => '@RMM$mode',
      'TP' => '@TP$power',
      'RMF' => '@RMF$filter',
      'RMP' => '@RMP$shift',
      'S' => signal,
      'CK' => '@CK${keyer ? 1 : 0}',
      'CS' => '@CS$speed',
      // The Eagle's version answer ends LF CR, which the framer must take as
      // one line; the Orion's guide documents no version query.
      'V' => dialect == TenTecDialect.eagle ? '599 Ver 01.736\n' : _refusal(command),
      _ => _refusal(command),
    };
  }
}

/// A session wired to [radio], stepped by [run].
class _Bench {
  final _Radio radio;
  final _FakeSink sink = _FakeSink();
  late final TenTecSession session = TenTecSession(sink, config: {TenTecDriver.dialectConfigKey: radio.dialect.name});
  var _answered = 0;

  /// Replies on their way back, and when each lands.
  final _inFlight = <(Duration, String)>[];

  _Bench(TenTecDialect dialect) : radio = _Radio(dialect);

  /// How long the radio takes to answer. Not zero: a refusal that arrives
  /// in the same instant as its command lands inside any gap at all, and a
  /// bench that answers that fast cannot tell a set's pause from none.
  static const latency = Duration(milliseconds: 10);

  /// Lets [time] pass, the radio answering what it is sent as it goes.
  void run(FakeAsync async, [Duration time = const Duration(milliseconds: 500)]) {
    final end = async.elapsed + time;
    do {
      while (_answered < sink.sent.length) {
        final reply = radio.answer(sink.sent[_answered++]);
        if (reply != null) _inFlight.add((async.elapsed + latency, reply));
      }
      while (_inFlight.isNotEmpty && _inFlight.first.$1 <= async.elapsed) {
        session.handleData(Uint8List.fromList(ascii.encode('${_inFlight.removeAt(0).$2}\r')));
      }
      async.elapse(const Duration(milliseconds: 1));
    } while (async.elapsed < end);
  }

  void feed(String line) => session.handleData(Uint8List.fromList(ascii.encode('$line\r')));

  List<String> get queries => [
    for (final line in sink.sent)
      if (line.startsWith('?')) line.trim(),
  ];
}

void main() {
  test('opens one question at a time, and reads frequency, mode and power', () {
    fakeAsync((async) {
      final bench = _Bench(TenTecDialect.eagle);
      bench.session.startUpdates();
      // Nothing answered yet: a second question out would leave a bare `Z`
      // unattributable.
      expect(bench.sink.sent, ['?V\r']);
      bench.run(async);
      expect(bench.sink.readings, containsAllInOrder([const VfoReading(freqKHz: 14074), const VfoReading(mode: 'USB')]));
      expect(bench.sink.powers.last, 50);
      expect(bench.sink.diagnostics, contains('radio identifies as "599 Ver 01.736"'));
      bench.session.teardown();
    });
  });

  test('never sends X, which restarts an Orion', () {
    fakeAsync((async) {
      final bench = _Bench(TenTecDialect.orion);
      bench.session.startUpdates();
      bench.run(async, const Duration(seconds: 10));
      expect(bench.sink.sent.where((line) => line.startsWith('X')), isEmpty);
      // Undocumented on the Orion: one it ignored would hold every connect a
      // timeout before the first frequency.
      expect(bench.queries, isNot(contains('?V')));
      bench.session.teardown();
    });
  });

  test('an Orion with its main receiver on VFO B is read and tuned on VFO B', () {
    fakeAsync((async) {
      final bench = _Bench(TenTecDialect.orion)..radio.kv = 'BAB';
      bench.session.startUpdates();
      bench.run(async, const Duration(seconds: 4));
      expect(bench.sink.readings.where((r) => r.freqKHz != null).last.freqKHz, 7074);
      bench.session.setFrequency(7030);
      bench.run(async);
      expect(bench.radio.b, 7030000);
      expect(bench.radio.a, 14074000, reason: 'VFO A is not the one being listened to');
      bench.session.teardown();
    });
  });

  test("an Eagle's VFO B is never taken for the main receiver", () {
    fakeAsync((async) {
      // An Eagle answering `@KVBAA` would be off its guide; it still receives on A.
      final bench = _Bench(TenTecDialect.eagle)..radio.kv = 'BAA';
      bench.session.startUpdates();
      bench.run(async, const Duration(seconds: 4));
      expect(bench.queries, isNot(contains('?BF')));
      expect(bench.sink.readings.where((r) => r.freqKHz != null).last.freqKHz, 14074);
      bench.session.teardown();
    });
  });

  group('refusals', () {
    test("a set's refusal is not taken for its read-back's", () {
      fakeAsync((async) {
        // An Eagle before firmware 1.736 refuses the width SET and answers
        // the width query. Pinned on the read-back, the refusal would be
        // blamed on a read the radio has, and the refused set never named.
        final bench = _Bench(TenTecDialect.eagle)..radio.mode = '2';
        bench.radio.refuse.add('*RMF');
        bench.session.startUpdates();
        bench.run(async);
        bench.session.setPassband(const Passband(-200, 200));
        bench.run(async);
        bench.session.setPassband(const Passband(-300, 300));
        bench.run(async);
        expect(bench.sink.diagnostics, contains('radio refused *RMF400'));
        final before = bench.queries.length;
        bench.run(async, const Duration(seconds: 10));
        expect(bench.queries.skip(before), contains('?RMF'));
        bench.session.teardown();
      });
    });

    test('a filter read the radio refuses is given up, and the poll carries on', () {
      fakeAsync((async) {
        final bench = _Bench(TenTecDialect.eagle)..radio.mode = '2';
        bench.radio.refuse.add('?RMF');
        bench.session.startUpdates();
        bench.run(async, const Duration(seconds: 20));
        final widthReads = bench.queries.where((q) => q == '?RMF').length;
        expect(widthReads, 2, reason: 'given up after the second refusal');
        final before = bench.queries.length;
        bench.run(async, const Duration(seconds: 10));
        expect(bench.queries.length, greaterThan(before), reason: 'the poll did not stall on the refused read');
        expect(bench.queries.skip(before), isNot(contains('?RMF')));
        bench.session.teardown();
      });
    });
  });

  group('transmitting', () {
    test("the shape of ?S's answer is the transmit state, and the meters ride with it", () {
      fakeAsync((async) {
        final bench = _Bench(TenTecDialect.eagle);
        bench.session.startUpdates();
        bench.run(async);
        expect(bench.sink.txReports, [false]);
        bench.radio.signal = '@STF99R10';
        bench.run(async);
        expect(bench.sink.txReports, [false, true]);
        expect(bench.sink.meters, contains((RadioMeter.powerOut, 99.0)));
        final swr = bench.sink.meters.lastWhere((m) => m.$1 == RadioMeter.swr).$2;
        expect(swr, closeTo(1.22, 0.01));
        // The receive answer's number has no known unit: no signal meter.
        expect(bench.sink.meters.where((m) => m.$1 == RadioMeter.signalDbm), isEmpty);
        bench.session.teardown();
      });
    });

    test('PTT goes ahead of the queued polls, and teardown unkeys', () {
      fakeAsync((async) {
        final bench = _Bench(TenTecDialect.eagle);
        bench.session.startUpdates();
        // ?V is on the wire, the first poll queued behind it.
        bench.session.setPtt(true);
        bench.run(async, const Duration(milliseconds: 20));
        expect(bench.sink.sent.take(2), ['?V\r', '*TK\r']);
        bench.session.teardown();
        expect(bench.sink.sent.last, '*TU\r', reason: 'both radios stay keyed until told otherwise');
      });
    });

    test('a set behind a PTT waits out the gap the Eagle asks for', () {
      fakeAsync((async) {
        final bench = _Bench(TenTecDialect.eagle);
        bench.session.startUpdates();
        bench.run(async);
        bench.session.setPtt(true);
        bench.session.setFrequency(14030);
        bench.run(async, const Duration(milliseconds: 150));
        expect(bench.sink.sent, contains('*TK\r'));
        expect(bench.sink.sent, isNot(contains('*AF14030000\r')));
        bench.run(async, const Duration(milliseconds: 200));
        expect(bench.sink.sent, contains('*AF14030000\r'));
        bench.session.teardown();
      });
    });

    test('a quick key and unkey go out in order, never leaving it keyed', () {
      fakeAsync((async) {
        final bench = _Bench(TenTecDialect.eagle);
        bench.session.startUpdates();
        // Both asked for while ?V is out: queued at the front one after the
        // other, they would go out unkey first.
        bench.session.setPtt(true);
        bench.session.setPtt(false);
        bench.run(async);
        final keying = bench.sink.sent.where((line) => line.startsWith('*T')).toList();
        expect(keying.last, '*TU\r');
        bench.session.teardown();
      });
    });
  });

  group("an Eagle's split", () {
    test('a retune to another band takes it out of split first', () {
      fakeAsync((async) {
        final bench = _Bench(TenTecDialect.eagle)
          ..radio.kv = 'AAB'
          ..radio.b = 14080000;
        bench.session.startUpdates();
        bench.run(async, const Duration(seconds: 4));
        bench.session.setFrequency(7074);
        bench.run(async);
        final sets = bench.sink.sent.where((line) => line.startsWith('*')).toList();
        expect(sets, ['*KVAAA\r', '*AF07074000\r'], reason: 'cross-band split is what its guide warns against');
        bench.session.teardown();
      });
    });

    test('a retune within the band keeps it', () {
      fakeAsync((async) {
        final bench = _Bench(TenTecDialect.eagle)
          ..radio.kv = 'AAB'
          ..radio.b = 14080000;
        bench.session.startUpdates();
        bench.run(async, const Duration(seconds: 4));
        bench.session.setFrequency(14030);
        bench.run(async);
        expect(bench.sink.sent.where((line) => line.startsWith('*')), ['*AF14030000\r']);
        expect(bench.radio.kv, 'AAB');
        bench.session.teardown();
      });
    });
  });

  group('passband', () {
    test('is drawn only where the filter is centred, with the shift applied', () {
      fakeAsync((async) {
        final bench = _Bench(TenTecDialect.eagle)
          ..radio.mode = '2'
          ..radio.filter = 500
          ..radio.shift = 100;
        bench.session.startUpdates();
        bench.run(async, const Duration(seconds: 4));
        expect(bench.sink.passbands.last, const Passband(-150, 350));
        bench.radio.mode = '0';
        bench.run(async, const Duration(seconds: 4));
        expect(bench.sink.passbands.last, isNull, reason: 'an SSB filter sits at an offset neither guide states');
        bench.session.teardown();
      });
    });

    test('an Eagle sets only the width; an Orion centres it too', () {
      fakeAsync((async) {
        final eagle = _Bench(TenTecDialect.eagle)..radio.mode = '2';
        eagle.session.startUpdates();
        eagle.run(async, const Duration(seconds: 4));
        eagle.session.setPassband(const Passband(-100, 300));
        eagle.run(async);
        expect(eagle.radio.filter, 400);
        expect(eagle.sink.sent, isNot(contains(startsWith('*RMP'))));
        eagle.session.teardown();

        final orion = _Bench(TenTecDialect.orion)..radio.mode = '2';
        orion.session.startUpdates();
        orion.run(async, const Duration(seconds: 4));
        orion.session.setPassband(const Passband(-100, 300));
        orion.run(async);
        expect((orion.radio.filter, orion.radio.shift), (400, 100));
        orion.session.teardown();
      });
    });
  });

  group('CW', () {
    test('only the Orion keys CW from the app', () {
      const driver = TenTecDriver();
      expect(driver.canKeyCwWith({TenTecDriver.dialectConfigKey: 'orion'}), isTrue);
      expect(driver.canKeyCwWith({TenTecDriver.dialectConfigKey: 'eagle'}), isFalse);
    });

    test('an Orion is sent one character per command, each at its own start', () {
      fakeAsync((async) {
        final bench = _Bench(TenTecDialect.orion)..radio.speed = 20;
        bench.session.startUpdates();
        bench.run(async);
        bench.session.sendCw('cq-');
        bench.run(async, const Duration(milliseconds: 100));
        // Sent all at once, a radio that does not buffer keys only the C.
        expect(bench.sink.sent.where((line) => line.startsWith('/')), ['/c\r']);
        bench.run(async, const Duration(seconds: 1));
        expect(bench.sink.sent.where((line) => line.startsWith('/')), ['/c\r', '/q\r'], reason: 'the - is not in the Orion table');
        bench.session.teardown();
      });
    });

    test('with its keyer off, the operator is told why nothing goes out', () {
      fakeAsync((async) {
        final bench = _Bench(TenTecDialect.orion)..radio.keyer = false;
        bench.session.startUpdates();
        bench.run(async);
        expect(bench.sink.problems.whereType<String>(), isEmpty, reason: 'not before they try: an external keyer is a fine setup');
        bench.session.sendCw('test');
        expect(bench.sink.problems.last, isNotNull);
        bench.session.teardown();
      });
    });
  });

  test("an Orion's VFO out-of-range report is not taken for the frequency read", () {
    fakeAsync((async) {
      final bench = _Bench(TenTecDialect.orion)..radio.withhold.add('?AF');
      bench.session.startUpdates();
      bench.run(async, const Duration(milliseconds: 100));
      expect(bench.sink.sent.last, '?AF\r');
      // What a refused `*KV` says: VFO A out of range. `?AF` starts with A.
      bench.feed('Z!A');
      bench.run(async, const Duration(milliseconds: 50));
      expect(bench.sink.sent.last, '?AF\r', reason: 'still waiting for its own answer');
      bench.session.teardown();
    });
  });

  test("a mode change drops the last mode's filter until it is read again", () {
    fakeAsync((async) {
      final bench = _Bench(TenTecDialect.eagle)
        ..radio.mode = '2'
        ..radio.filter = 500;
      bench.session.startUpdates();
      bench.run(async, const Duration(seconds: 4));
      expect(bench.sink.passbands.last, const Passband(-250, 250));
      bench.radio
        ..mode = '4'
        ..withhold.add('?RMF');
      bench.run(async, const Duration(seconds: 4));
      // AM has a passband too, so the CW width would have been drawn there.
      expect(bench.sink.passbands.last, isNull);
      bench.session.teardown();
    });
  });

  test("an extension's raw command is written as given, not behind the poll", () {
    fakeAsync((async) {
      final bench = _Bench(TenTecDialect.eagle);
      bench.session.startUpdates();
      // ?V is on the wire, the first poll queued behind it.
      bench.session.sendRaw(ascii.encode('?RMNA'));
      expect(bench.sink.sent.last, '?RMNA\r');
      bench.session.teardown();
    });
  });

  test('a data mode puts the radio in its base mode, which neither radio lacks', () {
    fakeAsync((async) {
      final bench = _Bench(TenTecDialect.eagle)..radio.mode = '2';
      bench.session.startUpdates();
      bench.run(async);
      // FT8 reaches a driver as DATA-USB; left unsent, the radio stays in CW.
      bench.session.setMode('DATA-USB');
      bench.run(async);
      expect(bench.radio.mode, '0');
      bench.session.teardown();
    });
  });

  test('an answer it cannot read is said, and does not stall the poll', () {
    fakeAsync((async) {
      final bench = _Bench(TenTecDialect.orion)..radio.withhold.add('?AF');
      bench.session.startUpdates();
      bench.run(async, const Duration(milliseconds: 100));
      // The MHz form the guide allows for a set, if a firmware answered in it.
      bench.feed('@AF14.074000');
      bench.run(async, const Duration(milliseconds: 50));
      expect(bench.sink.diagnostics, contains('unreadable answer "@AF14.074000"'));
      expect(bench.sink.diagnostics.where((d) => d?.startsWith('radio did not answer') ?? false), isEmpty);
      expect(bench.queries.last, isNot('?AF'), reason: 'the next question went out without waiting out a timeout');
      bench.session.teardown();
    });
  });

  test("an Orion's refusal of another command costs the outstanding read nothing", () {
    fakeAsync((async) {
      final bench = _Bench(TenTecDialect.orion)..radio.mode = '2';
      bench.session.startUpdates();
      bench.run(async);
      bench.radio.withhold.add('?RMF');
      while (bench.sink.sent.last != '?RMF\r') {
        bench.run(async, const Duration(milliseconds: 50));
      }
      // A refusal of a PTT written past the queue. Taken as ?RMF's, it would
      // strike the width read and settle the question it did not answer.
      bench.feed('Z!*T');
      bench.run(async, const Duration(milliseconds: 50));
      expect(bench.sink.sent.last, '?RMF\r', reason: 'still waiting for its own answer');
      bench.feed('@RMF2400');
      bench.radio.withhold.clear();
      final before = bench.queries.length;
      bench.run(async, const Duration(seconds: 10));
      expect(bench.queries.skip(before), contains('?RMF'));
      bench.session.teardown();
    });
  });

  test('PTT waits out the gap after a set, and teardown unkeys regardless', () {
    fakeAsync((async) {
      final bench = _Bench(TenTecDialect.eagle);
      bench.session.startUpdates();
      bench.run(async);
      bench.session.setPower(20);
      bench.run(async, const Duration(milliseconds: 20));
      bench.session.setPtt(true);
      // Inside the 200 ms the Eagle's guide asks for after the set.
      expect(bench.sink.sent, isNot(contains('*TK\r')));
      bench.run(async, const Duration(milliseconds: 250));
      expect(bench.sink.sent, contains('*TK\r'));
      bench.session.setPtt(false);
      bench.session.teardown();
      expect(bench.sink.sent.last, '*TU\r', reason: 'an unkey still waiting is sent at teardown, not dropped');
    });
  });

  group('Orion CW', () {
    test('stop drops the characters not yet written', () {
      fakeAsync((async) {
        final bench = _Bench(TenTecDialect.orion)..radio.speed = 20;
        bench.session.startUpdates();
        bench.run(async);
        bench.session.sendCw('cq cq');
        bench.run(async, const Duration(milliseconds: 100));
        bench.session.stopCw();
        bench.run(async, const Duration(seconds: 3));
        expect(bench.sink.sent.where((line) => line.startsWith('/')), ['/c\r']);
        expect(bench.session.cwSending, isFalse);
        bench.session.teardown();
      });
    });

    test('follows the speed knob, so characters land where the keyer expects them', () {
      fakeAsync((async) {
        // Neither speed the app's 20 WPM default: a session that never read
        // the radio would pass by coincidence.
        final bench = _Bench(TenTecDialect.orion)..radio.speed = 15;
        bench.session.startUpdates();
        bench.run(async);
        bench.radio.speed = 30;
        bench.run(async, const Duration(seconds: 4));
        bench.session.sendCw('cq');
        // At 30 WPM Q starts 560 ms in; at the 15 read at connect, 1120.
        bench.run(async, const Duration(milliseconds: 700));
        expect(bench.sink.sent.where((line) => line.startsWith('/')), ['/c\r', '/q\r']);
        bench.session.teardown();
      });
    });

    test('firmware with no CW over CAT is said, and nothing is queued', () {
      fakeAsync((async) {
        final bench = _Bench(TenTecDialect.orion)..radio.refuse.addAll({'CK', 'CS'});
        bench.session.startUpdates();
        bench.run(async, const Duration(seconds: 8));
        bench.session.sendCw('test');
        expect(bench.sink.problems.last, isNotNull);
        expect(bench.session.cwSending, isFalse);
        bench.session.teardown();
      });
    });
  });
}

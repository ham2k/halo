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
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/flexradio_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';

const _handshakeLines = ['V1.4.0.0', 'H5AC2F980'];
const _radioStatusLine =
    'S5AC2F980|radio slices=3 panadapters=3 lineout_gain=60 nickname=RadioRoom callsign=N0CALL';
const _sliceStatusLine =
    'S5AC2F980|slice 0 in_use=1 sample_rate=24000 RF_frequency=14.074000 client_handle=0x1C61D553 index_letter=A mode=DIGU wide=0';
const _sliceStatusLineWithDecimals =
    'S5AC2F980|slice 0 in_use=1 sample_rate=24000 RF_frequency=14.071820 client_handle=0x1C61D553 index_letter=A mode=CW wide=0';
const _otherSliceStatusLine = 'S5AC2F980|slice 1 in_use=1 RF_frequency=7.123000 mode=USB';
const _transmitStatusLine = 'S5AC2F980|transmit tune=0 show_tx_in_waterfall=0 rfpower=75 tunepower=10';
const _sliceBStatusLine =
    'S5AC2F980|slice 1 in_use=1 RF_frequency=7.123000 client_handle=0x9F0012AB index_letter=B mode=LSB wide=0';
const _clientConnectedLine =
    'S5AC2F980|client 0x9F0012AB connected client_id=42 local_ptt=0 program=SmartSDR-Win station=SHACK-PC';
const _clientDisconnectedLine = 'S5AC2F980|client 0x9F0012AB disconnected forced=0';

class _FakeSink implements EquipmentSink {
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

  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);

  @override
  void reportProblem(String? message) => problems.add(message);

  @override
  void reportChannels(List<EquipmentChannel> list) => channels = list;

  EquipmentChannel channel(String key) => channels.firstWhere((c) => c.key == key);
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
      expect(sink.readings, [const VfoReading(freqKHz: 14074, mode: 'DIGU')]);
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
      expect(sink.readings, [const VfoReading(freqKHz: 14074, mode: 'DIGU')]);
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
      expect(sink.readings, [const VfoReading(freqKHz: 14074, mode: 'DIGU')]);
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

  group('commands', () {
    test('builds a tune command in MHz from a frequency in kHz', () {
      session.setFrequency(14074);
      expect(sentAny('slice tune 0 14.074000'), isTrue);
    });

    test('sets the mode on the tracked slice', () {
      session.setMode('usb');
      expect(sentAny('slice set 0 mode=USB'), isTrue);
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

  group('choosing a slice', () {
    // A Flex runs several slices at once. Tracking whichever one is index 0
    // is only right for an operator who happens to be working slice A —
    // everyone else was reading a frequency they were not transmitting on.
    late FlexRadioSession sliceB;

    setUp(() => sliceB = FlexRadioSession(sink, slice: 1));

    test('reads the configured slice, and ignores the others', () {
      sliceB.feed('$_sliceStatusLine\n$_sliceBStatusLine\n');
      expect(sink.readings, [const VfoReading(freqKHz: 7123, mode: 'LSB')],
          reason: 'slice 0 is another slice now, not the tracked one');
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
      expect(sink.channel('0').mode, 'DIGU');
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

}

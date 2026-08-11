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

class _FakeSink implements EquipmentSink {
  final sent = <String>[];
  final readings = <VfoReading>[];
  final powers = <num>[];
  final diagnostics = <String?>[];

  @override
  void send(List<int> bytes) => sent.add(utf8.decode(bytes));

  @override
  void report(VfoReading reading) => readings.add(reading);

  @override
  void reportPower(num watts) => powers.add(watts);

  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);
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
}

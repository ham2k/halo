// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The flrig driver with no flrig and no socket. This pins the protocol as
// captured from flrig 2.0.12 — HTTP/1.1 framing, XML-RPC bodies, the
// lowercase `Content-length` header — and above all the one-outstanding
// request discipline: responses carry no method name and flrig drops a
// request sent before the previous response, so correlation-by-order is
// the protocol's only correlation. It does NOT establish that a rig
// behind a real flrig behaves; that claim rests on a live pass against
// an IC-705 behind flrig, which is what `hardwareVerified` reports.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/adaptive_poller.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/flrig_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';

class _FakeSink implements EquipmentSink {
  final problems = <String?>[];
  List<EquipmentChannel> channels = const [];
  final sent = <String>[];
  final readings = <VfoReading>[];
  final powers = <num>[];
  final diagnostics = <String?>[];

  @override
  void send(List<int> bytes) => sent.add(ascii.decode(bytes));

  @override
  void report(VfoReading reading) => readings.add(reading);

  @override
  void reportPower(num watts) => powers.add(watts);

  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);
  @override
  void reportProblem(String? message) => problems.add(message);

  @override
  void reportChannels(List<EquipmentChannel> channels) => this.channels = channels;
}

extension on FlrigSession {
  void feed(String text) => handleData(Uint8List.fromList(ascii.encode(text)));
}

/// A response as flrig 2.0.12 actually frames one: XMLRPC++ 0.8 headers,
/// lowercase `Content-length`, CRLF line endings inside the body.
String _response(String inner) {
  final body = '<?xml version="1.0"?>\r\n'
      '<methodResponse><params><param>\r\n'
      '\t<value>$inner</value>\r\n'
      '</param></params></methodResponse>\r\n';
  return 'HTTP/1.1 200 OK\r\n'
      'Server: XMLRPC++ 0.8\r\n'
      'Content-Type: text/xml\r\n'
      'Content-length: ${body.length}\r\n'
      '\r\n'
      '$body';
}

String _fault() {
  const body = '<?xml version="1.0"?>\r\n'
      '<methodResponse><fault>\r\n'
      '\t<value><struct><member><name>faultCode</name><value><i4>-1</i4></value></member></struct></value>\r\n'
      '</fault></methodResponse>\r\n';
  return 'HTTP/1.1 200 OK\r\n'
      'Server: XMLRPC++ 0.8\r\n'
      'Content-Type: text/xml\r\n'
      'Content-length: ${body.length}\r\n'
      '\r\n'
      '$body';
}

void main() {
  group('mode names', () {
    test('translate between the app\'s spellings and flrig\'s', () {
      expect(flrigModeForAppMode('DATA-USB'), 'USB-D');
      expect(flrigModeForAppMode('usb'), 'USB', reason: 'case-insensitive');
      expect(appModeForFlrigMode('LSB-D'), 'DATA-LSB');
      expect(appModeForFlrigMode('CW-R'), 'CW-R', reason: 'already the app\'s spelling');
    });

    test('RTTY round-trips instead of answering back in flrig spelling', () {
      // Without the reverse entries, setting RTTY-USB shows raw "RTTY-R" on
      // the next poll — a spelling no other surface of the app uses.
      expect(flrigModeForAppMode('RTTY-USB'), 'RTTY-R');
      expect(appModeForFlrigMode('RTTY-R'), 'RTTY-USB');
      expect(appModeForFlrigMode('RTTY'), 'RTTY-LSB');
    });

    test('a name with no app spelling passes through instead of vanishing', () {
      // The IC-705's list includes DV and WFM; on the dial they must not
      // read as "no mode".
      expect(appModeForFlrigMode('DV'), 'DV');
      expect(flrigModeForAppMode('WFM'), 'WFM');
    });
  });

  group('requests', () {
    test('go out as complete HTTP/1.1 POSTs with an accurate length', () {
      final sink = _FakeSink();
      final session = FlrigSession(sink);
      session.startUpdates();
      final request = sink.sent.single;
      expect(request, startsWith('POST /RPC2 HTTP/1.1\r\n'));
      expect(request, contains('rig.get_vfo'));
      final body = request.substring(request.indexOf('\r\n\r\n') + 4);
      final declared = RegExp(r'Content-Length: (\d+)').firstMatch(request)!.group(1);
      // A wrong length desyncs flrig's HTTP parser for the rest of the
      // connection — every later request would be misread.
      expect(declared, '${body.length}');
      session.teardown();
    });

    test('only one request rides the wire at a time', () {
      // flrig DROPS — not defers — a request that arrives before the
      // previous response went out, and its responses carry no method
      // name. Bursting the poll pair would lose the second question and
      // desync every answer after it.
      final sink = _FakeSink();
      final session = FlrigSession(sink);
      session.startUpdates();
      expect(sink.sent, hasLength(1));
      expect(sink.sent.single, contains('rig.get_vfo'));
      session.feed(_response('14070000'));
      expect(sink.sent, hasLength(2));
      expect(sink.sent[1], contains('rig.get_mode'));
      session.teardown();
    });
  });

  group('reading', () {
    test('a frequency answer reports in kHz', () {
      final sink = _FakeSink();
      final session = FlrigSession(sink);
      session.startUpdates();
      session.feed(_response('14070000'));
      expect(sink.readings, [const VfoReading(freqKHz: 14070)]);
      session.teardown();
    });

    test('answers correlate to questions by order, not content', () {
      // "7074000" and a mode name are both bare <value> strings; only the
      // ask queue tells them apart.
      final sink = _FakeSink();
      final session = FlrigSession(sink);
      session.startUpdates();
      session.feed(_response('7074000'));
      session.feed(_response('USB-D'));
      expect(sink.readings, [
        const VfoReading(freqKHz: 7074),
        const VfoReading(mode: 'DATA-USB'),
      ]);
      session.teardown();
    });

    test('a response split across chunks still parses', () {
      // TCP delivers arbitrary chunks; a split inside the headers and
      // another inside the body are the expected case, not a rare one.
      final sink = _FakeSink();
      final session = FlrigSession(sink);
      session.startUpdates();
      final response = _response('7074000');
      session.feed(response.substring(0, 30));
      expect(sink.readings, isEmpty);
      session.feed(response.substring(30, 90));
      expect(sink.readings, isEmpty);
      session.feed(response.substring(90));
      expect(sink.readings, [const VfoReading(freqKHz: 7074)]);
      session.teardown();
    });

    test('a set acknowledgement is never mistaken for a reading', () {
      // set_frequency answers <i4>1</i4>: read as a frequency it would
      // report a 0.001 kHz QSY. The ask queue must consume it silently.
      final sink = _FakeSink();
      final session = FlrigSession(sink);
      session.startUpdates();
      session.feed(_response('7074000'));
      session.feed(_response('USB'));
      session.setFrequency(14250);
      session.feed(_response('<i4>1</i4>'));
      expect(sink.readings, [
        const VfoReading(freqKHz: 7074),
        const VfoReading(mode: 'USB'),
      ]);
      session.teardown();
    });

    test('a power answer reports watts', () {
      final sink = _FakeSink();
      final session = FlrigSession(sink);
      session.startUpdates();
      session.feed(_response('14070000'));
      session.feed(_response('USB'));
      session.feed(_response('100'));
      expect(sink.powers, [100]);
      session.teardown();
    });

    test('a fault answers the question and unblocks the next', () {
      // A fault consumes the outstanding ask; leaving it outstanding would
      // stall the queue forever on the first unsupported method.
      final sink = _FakeSink();
      final session = FlrigSession(sink);
      session.startUpdates();
      session.feed(_fault());
      expect(sink.readings, isEmpty);
      expect(sink.sent, hasLength(2), reason: 'the mode question must still go out');
      session.teardown();
    });
  });

  group('writing', () {
    test('frequency goes out as an XML-RPC double in Hz', () {
      final sink = _FakeSink();
      final session = FlrigSession(sink);
      session.setFrequency(7074.5);
      expect(sink.sent.single, contains('rig.set_frequency'));
      expect(sink.sent.single, contains('<double>7074500</double>'));
    });

    test('mode goes out translated', () {
      final sink = _FakeSink();
      final session = FlrigSession(sink);
      session.setMode('DATA-USB');
      expect(sink.sent.single, contains('rig.set_mode'));
      expect(sink.sent.single, contains('<value>USB-D</value>'));
    });

    test('power goes out as an XML-RPC double, in watts', () {
      final sink = _FakeSink();
      final session = FlrigSession(sink);
      session.setPower(75);
      expect(sink.sent.single, contains('rig.set_power'));
      expect(sink.sent.single, contains('<double>75</double>'));
    });
  });

  group('polling', () {
    test('a backed-up queue is not asked again, and recovery is one ask deep', () {
      // An unanswered flrig is behind, not forgetful; piling polls onto
      // the queue would replay a burst of stale questions on recovery —
      // observable as sends released by the answers with no poll tick
      // in between.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = FlrigSession(sink);
        session.startUpdates();
        async.elapse(kPollSlow * 3);
        expect(sink.sent, hasLength(1));
        // flrig catches up: the answers release exactly the queued
        // mode/power questions, not the missed ticks' worth of stale polls.
        session.feed(_response('14070000'));
        session.feed(_response('USB'));
        session.feed(_response('100'));
        expect(sink.sent, hasLength(3));
        expect(sink.sent[1], contains('rig.get_mode'));
        expect(sink.sent[2], contains('rig.get_power'));
        // The next fresh trio waits for its own tick.
        async.elapse(kPollSlow + const Duration(milliseconds: 10));
        expect(sink.sent, hasLength(4));
        expect(sink.sent[3], contains('rig.get_vfo'));
        session.teardown();
      });
    });

    test('a set issued while a request is outstanding still goes out', () {
      // The queue exists so a busy poll cycle cannot swallow the
      // operator's write — dropping it here would lose a QSY with no
      // error surfacing anywhere.
      final sink = _FakeSink();
      final session = FlrigSession(sink);
      session.startUpdates();
      expect(sink.sent, hasLength(1), reason: 'get_vfo on the wire');
      session.setFrequency(7074);
      expect(sink.sent, hasLength(1), reason: 'one request on the wire, set queued');
      session.feed(_response('14070000'));
      session.feed(_response('USB'));
      session.feed(_response('100'));
      expect(sink.sent, hasLength(4));
      expect(sink.sent[3], contains('rig.set_frequency'));
      session.teardown();
    });

    test('a peer that never frames a header cannot grow the buffer forever', () {
      // A non-flrig service on the configured port streams newline text
      // with no blank line; holding it wedges the outstanding ask and
      // re-decodes an ever-growing buffer on every chunk.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = FlrigSession(sink);
        session.startUpdates();
        for (var i = 0; i < 100; i++) {
          session.feed('spotted W1AW on 14074.0 with no blank line ever\n' * 10);
        }
        // The junk (and the ask wedged behind it) is dropped, so polling
        // resumes instead of waiting forever on a header.
        async.elapse(kPollSlow + const Duration(milliseconds: 10));
        expect(sink.sent, hasLength(4));
        expect(sink.sent.last, contains('rig.get_vfo'));
        session.feed(_response('14070000'));
        expect(sink.readings, [const VfoReading(freqKHz: 14070)]);
        session.teardown();
      });
    });

    test('an answered cycle is followed by the next ask, never a pile-up', () {
      // However many poll ticks elapse unanswered, exactly one question
      // may ride the wire — flrig drops the rest, so sending them only
      // desyncs the ask queue from reality.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = FlrigSession(sink);
        session.startUpdates();
        session.feed(_response('14070000'));
        session.feed(_response('USB'));
        session.feed(_response('100'));
        sink.sent.clear();
        async.elapse(kPollSlow + const Duration(milliseconds: 10));
        expect(sink.sent, hasLength(1));
        expect(sink.sent.single, contains('rig.get_vfo'));
        session.teardown();
      });
    });

    test('a moving radio drops the poll to the fast cadence', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = FlrigSession(sink);
        session.startUpdates();
        session.feed(_response('14250000'));
        expect(session.pollInterval, kPollSlow,
            reason: 'the first reading is the answer to startUpdates, not movement');
        session.feed(_response('USB'));
        session.feed(_response('100'));
        async.elapse(kPollSlow + const Duration(milliseconds: 10));
        session.feed(_response('14260000'));
        expect(session.pollInterval, kPollFast);
        session.teardown();
      });
    });

    test('teardown stops the polling', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = FlrigSession(sink);
        session.startUpdates();
        session.feed(_response('14070000'));
        session.feed(_response('USB'));
        session.teardown();
        sink.sent.clear();
        async.elapse(kPollSlow * 5);
        expect(sink.sent, isEmpty);
      });
    });
  });
}

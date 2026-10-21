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
import 'package:ham2k_logger/services/cat/telemetry_poller.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
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

  final txReports = <bool>[];
  final meterReports = <(RadioMeter, num)>[];
  @override
  void reportTransmitting(bool transmitting) => txReports.add(transmitting);
  @override
  void reportMeter(RadioMeter meter, num value) => meterReports.add((meter, value));

  @override
  void reportKeyerSpeed(int wpm) {}
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportVoiceActivity(VoiceActivity? activity) {}

  @override
  void reportVoiceMemories(List<VoiceMemory> memories) {}

  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);
  @override
  void reportProblem(String? message) => problems.add(message);

  @override
  void reportChannels(List<EquipmentChannel> channels) => this.channels = channels;

  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
  @override
  void reportAlive() {}
}

/// Keeps the bytes, which a raw call need not spell in ASCII.
class _BytesSink extends _FakeSink {
  final bytes = <List<int>>[];
  @override
  void send(List<int> bytes) => this.bytes.add(bytes);
}

extension on FlrigSession {
  void feed(String text) => handleData(Uint8List.fromList(ascii.encode(text)));
}

/// A response as flrig 2.0.12 actually frames one: XMLRPC++ 0.8 headers,
/// lowercase `Content-length`, CRLF line endings inside the body.
String _response(String inner) {
  final body =
      '<?xml version="1.0"?>\r\n'
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
  const body =
      '<?xml version="1.0"?>\r\n'
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

/// A session whose TX watch is set so slow it never fires inside a test.
///
/// Every test below is about the STATE poll — its queue discipline, its
/// cadence, its framing — and the two pollers share one request queue, so an
/// unsilenced watch would interleave `rig.get_ptt` into sequences these
/// assert on positionally. That is not a fiction: an XML-RPC answer
/// correlates to the oldest unanswered question and nothing else, so a test
/// that fed a frequency to a PTT question would be lying about what the
/// driver saw. The watch has tests of its own below.
FlrigSession _stateOnlySession(EquipmentSink sink) => FlrigSession(sink, const {telemetryIntervalConfigKey: 600000});

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
      final session = _stateOnlySession(sink);
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
      final session = _stateOnlySession(sink);
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
      final session = _stateOnlySession(sink);
      session.startUpdates();
      session.feed(_response('14070000'));
      expect(sink.readings, [const VfoReading(freqKHz: 14070)]);
      session.teardown();
    });

    test('answers correlate to questions by order, not content', () {
      // "7074000" and a mode name are both bare <value> strings; only the
      // ask queue tells them apart.
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      session.startUpdates();
      session.feed(_response('7074000'));
      session.feed(_response('USB-D'));
      expect(sink.readings, [const VfoReading(freqKHz: 7074), const VfoReading(mode: 'DATA-USB')]);
      session.teardown();
    });

    test('a response split across chunks still parses', () {
      // TCP delivers arbitrary chunks; a split inside the headers and
      // another inside the body are the expected case, not a rare one.
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
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
      final session = _stateOnlySession(sink);
      session.startUpdates();
      session.feed(_response('7074000'));
      session.feed(_response('USB'));
      session.setFrequency(14250);
      session.feed(_response('<i4>1</i4>'));
      expect(sink.readings, [const VfoReading(freqKHz: 7074), const VfoReading(mode: 'USB')]);
      session.teardown();
    });

    test('a power answer reports watts', () {
      // flrig types this answer as <i4>, unlike the bare frequency and mode
      // before it. A parse that reads only bare values drops it, and the
      // radio's power never reaches the app.
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      session.startUpdates();
      session.feed(_response('14070000'));
      session.feed(_response('USB'));
      session.feed(_response('<i4>100</i4>'));
      expect(sink.powers, [100]);
      session.teardown();
    });

    test('a power of 0 is no reading', () {
      // flrig answers 0 with no rig behind it; passed on, it would reset the
      // operator's power to nothing on every poll.
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      session.startUpdates();
      session.feed(_response('14070000'));
      session.feed(_response('USB'));
      session.feed(_response('<i4>0</i4>'));
      expect(sink.powers, isEmpty);
      session.teardown();
    });

    test('a fault answers the question and unblocks the next', () {
      // A fault consumes the outstanding ask; leaving it outstanding would
      // stall the queue forever on the first unsupported method.
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
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
      final session = _stateOnlySession(sink);
      session.setFrequency(7074.5);
      expect(sink.sent.single, contains('rig.set_frequency'));
      expect(sink.sent.single, contains('<double>7074500</double>'));
    });

    test('mode goes out translated', () {
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      session.setMode('DATA-USB');
      expect(sink.sent.single, contains('rig.set_mode'));
      expect(sink.sent.single, contains('<value>USB-D</value>'));
    });

    test('power goes out as an XML-RPC double, in watts', () {
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      session.setPower(75);
      expect(sink.sent.single, contains('rig.set_power'));
      expect(sink.sent.single, contains('<double>75</double>'));
    });
  });

  group('PTT', () {
    test('keys and unkeys with rig.set_ptt, as an int', () {
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      session.setPtt(true);
      expect(sink.sent.single, contains('<methodName>rig.set_ptt</methodName>'));
      expect(sink.sent.single, contains('<i4>1</i4>'));
      session.feed(_response('<i4>1</i4>'));
      session.setPtt(false);
      expect(sink.sent.last, contains('rig.set_ptt'));
      expect(sink.sent.last, contains('<i4>0</i4>'));
    });

    test('an unkey goes ahead of the queue, and takes a queued key with it', () {
      // Queued at the tail, an unkey waits a round-trip for every poll ahead
      // of it with the transmitter on; put at the head over a key still
      // waiting, it goes out FIRST and the stale key after it re-keys the
      // radio.
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      session.startUpdates();
      session.setPtt(true);
      session.setPtt(false);
      session.feed(_response('14070000'));
      expect(sink.sent[1], contains('rig.set_ptt'));
      expect(sink.sent[1], contains('<i4>0</i4>'));
      session.feed(_response('<i4>1</i4>'));
      expect(sink.sent.skip(2).where((r) => r.contains('rig.set_ptt')), isEmpty, reason: 'the superseded key never goes out');
      session.teardown();
    });

    test('teardown unkeys a radio the app keyed, even with a request in flight', () {
      // flrig drives the radio, and closing the connection does not unkey
      // it: a teardown that forgets the unkey leaves the transmitter on the
      // air with nothing left to turn it off.
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      session.startUpdates();
      session.setPtt(true);
      sink.sent.clear();
      session.teardown();
      expect(sink.sent.single, contains('rig.set_ptt'));
      expect(sink.sent.single, contains('<i4>0</i4>'));
    });

    test('teardown sends no PTT on a radio the app never keyed', () {
      // An unkey from a session that never keyed would cut off the operator
      // transmitting from the radio's own mic.
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      session.startUpdates();
      session.teardown();
      expect(sink.sent.where((r) => r.contains('rig.set_ptt')), isEmpty);
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
        final session = _stateOnlySession(sink);
        session.startUpdates();
        async.elapse(kPollSlow * 3);
        // The TX watch runs several times a second on its own cadence and
        // is held back by the SAME backlog guard — which is the point here:
        // an flrig that has gone quiet must not accumulate a queue of
        // questions whose answers are stale before they arrive.
        expect(sink.sent, hasLength(1));
        // flrig catches up: the answers release exactly the queued
        // mode/power questions, not the missed ticks' worth of stale polls.
        session.feed(_response('14070000'));
        session.feed(_response('USB'));
        session.feed(_response('<i4>100</i4>'));
        expect(sink.sent, hasLength(3));
        expect(sink.sent[1], contains('rig.get_mode'));
        expect(sink.sent[2], contains('rig.get_power'));
        session.teardown();
      });
    });

    test('a set issued while a request is outstanding still goes out', () {
      // The queue exists so a busy poll cycle cannot swallow the
      // operator's write — dropping it here would lose a QSY with no
      // error surfacing anywhere.
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      session.startUpdates();
      expect(sink.sent, hasLength(1), reason: 'get_vfo on the wire');
      session.setFrequency(7074);
      expect(sink.sent, hasLength(1), reason: 'one request on the wire, set queued');
      session.feed(_response('14070000'));
      session.feed(_response('USB'));
      session.feed(_response('<i4>100</i4>'));
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
        final session = _stateOnlySession(sink);
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
        final session = _stateOnlySession(sink);
        session.startUpdates();
        session.feed(_response('14070000'));
        session.feed(_response('USB'));
        session.feed(_response('<i4>100</i4>'));
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
        final session = _stateOnlySession(sink);
        session.startUpdates();
        session.feed(_response('14250000'));
        expect(session.pollInterval, kPollSlow, reason: 'the first reading is the answer to startUpdates, not movement');
        session.feed(_response('USB'));
        session.feed(_response('<i4>100</i4>'));
        async.elapse(kPollSlow + const Duration(milliseconds: 10));
        session.feed(_response('14260000'));
        expect(session.pollInterval, kPollFast);
        session.teardown();
      });
    });

    test('teardown stops the polling', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = _stateOnlySession(sink);
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
  group('the meters', () {
    /// The real thing: a session whose watch actually runs.
    FlrigSession watching(_FakeSink sink) => FlrigSession(sink, const {telemetryIntervalConfigKey: 200});

    /// Answers whatever the session has actually asked for, the way flrig
    /// does — by method name, not by position in a script the test wrote.
    ///
    /// The two pollers share one request queue and interleave, so which
    /// question is on the wire at any moment is not something a test should
    /// be asserting by counting. What matters is that every answer is
    /// correlated to the question it belongs to, and a responder keyed on
    /// the method name is the only way to hold a test to that.
    ///
    /// Answers in flrig 2.0.12's captured shapes — typed where it types —
    /// and faults any method it does not have. Returns the methods asked.
    List<String> answerAll(FlrigSession session, _FakeSink sink, {bool transmitting = false, Map<String, String> overrides = const {}}) {
      final answers = {
        'rig.get_vfo': '14070000',
        'rig.get_mode': 'USB',
        'rig.get_power': '<i4>100</i4>',
        'rig.get_pwrmeter': '48.5',
        'rig.get_swrmeter': '1.4',
        ...overrides,
      };
      final asked = <String>[];
      var guard = 0;
      while (sink.sent.isNotEmpty && guard++ < 50) {
        final request = sink.sent.removeAt(0);
        final method = RegExp(r'<methodName>([^<]+)</methodName>').firstMatch(request)!.group(1)!;
        asked.add(method);
        final value = method == 'rig.get_ptt' ? '<i4>${transmitting ? 1 : 0}</i4>' : answers[method];
        session.feed(value == null ? _fault() : _response(value));
      }
      return asked;
    }

    test('a receiving rig is watched and nothing else is measured', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = watching(sink);
        session.startUpdates();
        answerAll(session, sink);
        async.elapse(const Duration(milliseconds: 250));
        answerAll(session, sink);
        expect(sink.txReports, [false], reason: 'a receiving rig is a fact worth reporting, not silence');
        expect(sink.meterReports, isEmpty, reason: 'SWR and power out mean nothing at rest');
        session.teardown();
      });
    });

    test('a keyed rig has every meter read, each in its own units', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = watching(sink);
        session.startUpdates();
        answerAll(session, sink);

        async.elapse(const Duration(milliseconds: 250));
        answerAll(session, sink, transmitting: true);
        expect(sink.txReports.last, isTrue);
        // The burst goes out on the transition and is answered on the next
        // pass, which is where it lands.
        async.elapse(const Duration(milliseconds: 250));
        answerAll(session, sink, transmitting: true);

        expect(sink.meterReports.toSet(), {(RadioMeter.powerOut, 48.5), (RadioMeter.swr, 1.4)});
        session.teardown();
      });
    });

    test('a keyed rig is asked only for meters flrig has', () {
      // One request at a time on the wire, several meter cycles a second:
      // a method flrig lacks answers nothing and costs a round-trip every
      // cycle the rig is keyed.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = watching(sink);
        session.startUpdates();
        final asked = answerAll(session, sink);
        async.elapse(const Duration(milliseconds: 250));
        asked.addAll(answerAll(session, sink, transmitting: true));
        async.elapse(const Duration(milliseconds: 250));
        asked.addAll(answerAll(session, sink, transmitting: true));
        // Methods flrig 2.0.12's `system.listMethods` offers.
        const offered = {'rig.get_vfo', 'rig.get_mode', 'rig.get_power', 'rig.get_ptt', 'rig.get_pwrmeter', 'rig.get_swrmeter'};
        expect(asked, everyElement(isIn(offered)));
        expect(asked, containsAll(['rig.get_pwrmeter', 'rig.get_swrmeter']), reason: 'the rig was keyed, so its meters were read');
        session.teardown();
      });
    });

    test('an SWR below 1 is dropped rather than shown', () {
      // Physically impossible, so it is an flrig that does not implement the
      // method answering 0 — and a 0.0 on the strip reads as a perfect
      // match, the most reassuring possible way to be wrong. The 0 must
      // answer the SWR question itself: an answer correlates only by order,
      // so a 0 fed to whatever else is outstanding tests nothing.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = watching(sink);
        const noSwr = {'rig.get_swrmeter': '0'};
        session.startUpdates();
        final asked = answerAll(session, sink);
        async.elapse(const Duration(milliseconds: 250));
        asked.addAll(answerAll(session, sink, transmitting: true, overrides: noSwr));
        async.elapse(const Duration(milliseconds: 250));
        asked.addAll(answerAll(session, sink, transmitting: true, overrides: noSwr));
        expect(asked, contains('rig.get_swrmeter'), reason: 'the rig was keyed, so SWR was asked');
        expect(sink.meterReports.map((m) => m.$1), isNot(contains(RadioMeter.swr)));
        session.teardown();
      });
    });
  });

  group('a raw call', () {
    const call = '<?xml version="1.0"?><methodCall><methodName>rig.get_bw</methodName><params></params></methodCall>';

    test('is posted in its turn, and answered by its response\'s body, not read as the driver\'s', () {
      // flrig's responses carry no method name: written beside the queue, the
      // raw call's response would answer the frequency read in flight.
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      session.startUpdates();
      final answers = <String>[];
      expect(session.sendRaw(utf8.encode(call), onAnswer: (a) => answers.add(utf8.decode(a))), 1);
      expect(sink.sent, hasLength(1), reason: 'the frequency read is on the wire');

      session.feed(_response('14074000'));
      session.feed(_response('USB'));
      session.feed(_response('<i4>5</i4>'));
      expect(sink.sent.last, endsWith(call));
      session.feed(_response('2400'));
      expect(answers.single, contains('<value>2400</value>'));
      expect(sink.readings.map((r) => r.freqKHz).nonNulls, [14074], reason: 'the bandwidth is not read as a frequency');
      session.teardown();
    });

    test('states its length in bytes, which a call may spell in more than ASCII', () {
      final sink = _BytesSink();
      final session = _stateOnlySession(sink);
      const body = '<?xml version="1.0"?><methodCall><methodName>rig.set_notes</methodName><params><param><value>73 — é</value></param></params></methodCall>';
      session.sendRaw(utf8.encode(body));
      final request = sink.bytes.single;
      final headerEnd = latin1.decode(request).indexOf('\r\n\r\n') + 4;
      expect(RegExp(r'Content-Length: (\d+)').firstMatch(latin1.decode(request))!.group(1), '${request.length - headerEnd}');
      session.teardown();
    });

    test('whose response is lost is answered empty, and the queue moves on', () {
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      final answers = <List<int>>[];
      session.sendRaw(utf8.encode(call), onAnswer: answers.add);
      session.feed('HTTP/1.1 200 OK\r\n\r\n');
      expect(answers, [<int>[]]);
      session.teardown();
    });
  });
}

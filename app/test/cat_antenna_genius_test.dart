// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The 4O3A Antenna Genius protocol, against lines captured from a real 8x2 on
// firmware 4.1.16 (HALO-414 carries the session). 4O3A does not publish the
// protocol, so these fixtures are the specification — every constant below is
// something the switch actually said, not something inferred from a document.
//
// A session is pure given a fake sink, so all of this runs with no switch.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/antenna_genius_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/antenna_genius_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';

const _banner = 'V4.1.16 AG';
const _infoLine = 'R1|0|info v=4.1.16 date=2024-10-18 btl=1.6 hw=4.0 serial=00-00-00 '
    'name=Antenna_Genius ports=2 antennas=8 mode=master uptime=6139922';
const _bandLines = [
  'R2|0|band 0 name=None freq_start=0.000000 freq_stop=0.000000',
  'R2|0|band 5 name=20m freq_start=13.800000 freq_stop=14.550000',
  'R2|0|',
];
const _antennaLines = [
  'R3|0|antenna 1 name=Hex tx=07E1 rx=07E1 inband=0000 hotkey=0',
  'R3|0|antenna 2 name=DXC tx=07F9 rx=07F9 inband=0000 hotkey=0',
  'R3|0|antenna 3 name=EFHW tx=0FFF rx=0FFF inband=0000 hotkey=0',
  // The switch reports all eight ports whether or not anything is wired to
  // them, and an all-zero band mask is the only thing that distinguishes a
  // placeholder from an antenna nobody renamed.
  'R3|0|antenna 4 name=Antenna_4 tx=0000 rx=0000 inband=0000 hotkey=0',
  'R3|0|',
];
/// The same 8x2 with a FlexRadio driving it — captured live. A port carries
/// the driving radio's own nickname, its band and its frequency, and `source`
/// names what is doing the driving.
const _drivenPortLines = [
  'S0|port 1 auto=1 source=FLEX band=5 freq=14.074000 nickname=RadioRoom rxant=1 txant=1 inband=0 tx=0 inhibit=0',
  // Configured to follow the same radio, but that radio is not on a band —
  // so the nickname is there and the band and frequency are not.
  'S0|port 2 auto=1 source=FLEX band=0 freq=0.000000 nickname=RadioRoom rxant=3 txant=3 inband=0 tx=0 inhibit=0',
];

const _portLines = [
  'S0|port 1 auto=1 source=AUTO band=0 rxant=1 txant=1 inband=0 tx=0 inhibit=0',
  'S0|port 2 auto=1 source=AUTO band=5 rxant=3 txant=3 inband=0 tx=0 inhibit=0',
];

class _FakeSink implements EquipmentSink {
  final sent = <String>[];
  final diagnostics = <String?>[];
  final problems = <String?>[];
  List<SwitchAntenna> antennas = const [];
  List<SwitchPort> ports = const [];

  /// How many times the whole picture was republished — the subscription
  /// pushes one port at a time, and a driver that rebuilt on every line the
  /// switch volunteers would redraw the panel for a band table.
  int reports = 0;

  @override
  void send(List<int> bytes) => sent.add(utf8.decode(bytes));

  @override
  void report(VfoReading reading) => fail('a switch has no VFO to report');

  @override
  void reportPower(num watts) => fail('a switch has no power to report');

  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);

  @override
  void reportProblem(String? message) => problems.add(message);

  @override
  void reportChannels(List<EquipmentChannel> channels) => fail('a switch has no channels');

  @override
  void reportSwitchState(List<SwitchAntenna> a, List<SwitchPort> p) {
    antennas = a;
    ports = p;
    reports++;
  }

  SwitchPort port(String key) => ports.firstWhere((p) => p.key == key);

  SwitchAntenna antenna(String key) => antennas.firstWhere((a) => a.key == key);
}

extension on AntennaGeniusSession {
  void feed(String text) => handleData(Uint8List.fromList(utf8.encode(text)));

  void feedLines(List<String> lines) => feed('${lines.join('\n')}\n');
}

void main() {
  late _FakeSink sink;
  late AntennaGeniusSession session;

  setUp(() {
    sink = _FakeSink();
    session = AntennaGeniusSession(sink);
    // startUpdates arms a periodic resync; a test that never tears the
    // session down would leak it into the next one.
    addTearDown(session.teardown);
  });

  /// Everything the switch says between connecting and the first steady
  /// frame, in the order it says it.
  void bringUp() {
    session.startUpdates();
    session.feed('$_banner\n');
    session.feedLines([_infoLine, ..._bandLines, ..._antennaLines, ..._portLines]);
    // C4 is `sub port all` — its reply is what ends bring-up and releases
    // the first published picture.
    session.feed('R4|0|\n');
  }

  bool sentAny(String fragment) => sink.sent.any((line) => line.contains(fragment));

  group('bringing a switch up', () {
    test('asks for the inventory before subscribing, so no port arrives unresolvable', () {
      session.startUpdates();
      final antennaAt = sink.sent.indexWhere((line) => line.contains('antenna list'));
      final subAt = sink.sent.indexWhere((line) => line.contains('sub port all'));
      expect(antennaAt, isNonNegative);
      expect(subAt, isNonNegative);
      expect(
        antennaAt,
        lessThan(subAt),
        reason: 'the subscription answers at once with ports naming antennas by key',
      );
    });

    test('commands carry an increasing sequence number in the C<seq>| envelope', () {
      session.startUpdates();
      expect(sink.sent.first, startsWith('C1|'));
      expect(sink.sent.first, endsWith('\n'));
      final seqs = [for (final line in sink.sent) int.parse(line.substring(1, line.indexOf('|')))];
      expect(seqs, orderedEquals([for (var i = 1; i <= seqs.length; i++) i]));
    });

    test('the version banner is not an error and not a reading', () {
      session.startUpdates();
      session.feed('$_banner\n');
      expect(sink.problems, isEmpty);
      expect(sink.reports, 0);
    });

    test('names the box, its firmware and its shape as a diagnostic', () {
      bringUp();
      expect(sink.diagnostics.last, contains('4.1.16'));
      expect(sink.diagnostics.last, contains('00-00-00'));
      // 8 antennas by 2 ports, as the front of the box is labelled.
      expect(sink.diagnostics.last, contains('8x2'));
    });
  });

  group('what the switch is routing', () {
    test('reports every antenna port with the name the operator gave it', () {
      bringUp();
      expect(sink.antennas.map((a) => a.key), ['1', '2', '3', '4']);
      expect(sink.antenna('1').name, 'Hex');
      expect(sink.antenna('3').name, 'EFHW');
    });

    // The switch stores a name typed with spaces using underscores, so an
    // antenna called "Hex Beam" comes back as "Hex_Beam". Undone once here
    // rather than at every display site.
    test('restores the spaces the switch stores as underscores', () {
      bringUp();
      session.feed('R9|0|antenna 1 name=80m_Inverted_V tx=07E1 rx=07E1\n');
      expect(sink.antenna('1').name, '80m Inverted V');
    });

    // An 8x2 with three antennas set up still reports eight ports. Without
    // this the operator picks their antenna from a list padded with five
    // entries called Antenna_4 upwards.
    test('an all-zero band mask marks a port with nothing wired to it', () {
      bringUp();
      expect(sink.antenna('1').configured, isTrue);
      expect(sink.antenna('4').configured, isFalse, reason: 'tx=0000 rx=0000 is an empty port');
    });

    test('letters the device ports the way the front panel does', () {
      bringUp();
      expect(sink.ports.map((p) => p.label), ['A', 'B']);
      expect(sink.ports.map((p) => p.key), ['1', '2'], reason: 'the wire still numbers them');
    });

    test('reads the selection from rxant, which the switch keeps txant on', () {
      bringUp();
      expect(sink.port('1').selectedAntennaKey, '1');
      expect(sink.port('2').selectedAntennaKey, '3');
    });

    // The switch uses the same field for "nothing selected" as for a
    // selection. Read literally, `rxant=0` routes the panel at an antenna
    // port that does not exist, and the dropdown shows a blank selection on
    // a switch that is answering perfectly well.
    test('rxant=0 is no antenna, not antenna zero', () {
      bringUp();
      session.feed('S0|port 1 auto=0 band=0 rxant=0 txant=0 inband=0 tx=0 inhibit=0\n');
      expect(sink.port('1').selectedAntennaKey, isNull);
    });

    test('resolves a port band through the switch own band table', () {
      bringUp();
      expect(sink.port('2').band, '20m', reason: 'band=5 indexes the band list, it is not a band');
      expect(sink.port('1').band, isNull, reason: 'band=0 is the table entry named None');
    });

    test('carries the flags that decide whether a selection will stick', () {
      bringUp();
      expect(sink.port('1').auto, isTrue);
      expect(sink.port('1').transmitting, isFalse);
      expect(sink.port('1').inhibited, isFalse);

      session.feed('S0|port 1 auto=0 band=0 rxant=1 txant=1 inband=0 tx=1 inhibit=1\n');
      expect(sink.port('1').auto, isFalse);
      expect(sink.port('1').transmitting, isTrue);
      expect(sink.port('1').inhibited, isTrue);
    });

    // The subscription pushes one port at a time. Rebuilding the list from
    // insertion order would put the moved port last and reorder the panel's
    // rows under the operator's finger.
    test('keeps the ports in the switch own order when one of them moves', () {
      bringUp();
      session.feed('S0|port 1 auto=0 band=0 rxant=2 txant=2 inband=0 tx=0 inhibit=0\n');
      expect(sink.ports.map((p) => p.key), ['1', '2']);
      expect(sink.port('1').selectedAntennaKey, '2');
    });

    test('a port update keeps the antennas learned earlier', () {
      bringUp();
      session.feed('S0|port 1 auto=0 band=0 rxant=2 txant=2 inband=0 tx=0 inhibit=0\n');
      expect(sink.antennas, hasLength(4), reason: 'the two lists are reported together, not replaced');
    });

    // TCP gives no frame boundaries, so this is whatever the network happens
    // to do rather than a rare case — app-polo's FlexRadio driver split each
    // chunk with no residual and mangled straddling lines.
    test('reassembles a status line split across chunks', () {
      bringUp();
      const line = 'S0|port 1 auto=0 band=0 rxant=2 txant=2 inband=0 tx=0 inhibit=0\n';
      final before = sink.reports;
      session.feed(line.substring(0, line.length ~/ 2));
      expect(sink.reports, before, reason: 'half a line is not yet a line');
      session.feed(line.substring(line.length ~/ 2));
      expect(sink.port('1').selectedAntennaKey, '2');
    });

    // Measured on a real 8x2: it sends the inventory one line per antenna
    // port, each in its own TCP segment, so publishing per line — or even
    // per chunk — rebuilt the Station panel seven to ten times on every
    // connect, each showing one more antenna than the last.
    test('bring-up publishes once, however many segments the switch splits it into', () {
      session.startUpdates();
      // One feed per line, which is what the switch actually does.
      for (final line in [_infoLine, ..._bandLines, ..._antennaLines, ..._portLines]) {
        session.feed('$line\n');
      }
      expect(sink.reports, 0, reason: 'the port subscription has not answered yet');

      session.feed('R4|0|\n');
      expect(sink.reports, 1);
      expect(sink.antennas, hasLength(4));
      expect(sink.ports, hasLength(2));
    });

    // A blank panel on a connection that is otherwise fine is worse than a
    // picture assembled from what did arrive.
    test('a refused subscription still releases what the inventory said', () {
      session.startUpdates();
      session.feedLines([..._antennaLines, ..._portLines]);
      session.feed('R4|30|\n');
      expect(sink.reports, 1);
      expect(sink.problems.last, isNotNull);
    });

    // A sequence left outstanding from the previous connection would hold
    // the new picture back for the life of the session.
    test('a reconnect is not held back by the last connection bring-up', () {
      session.startUpdates();
      session.teardown();
      session.startUpdates();
      session.feedLines(_portLines);
      session.feed('R9|0|\n');
      expect(sink.reports, greaterThan(0));
    });

    test('a band table line alone does not redraw the routing', () {
      bringUp();
      final before = sink.reports;
      session.feed('R9|0|band 3 name=40m freq_start=6.800000 freq_stop=7.400000\n');
      expect(sink.reports, before);
    });
  });

  group('routing a port', () {
    test('sends one port set, because the switch moves txant to follow rxant', () {
      bringUp();
      sink.sent.clear();
      session.selectAntenna('1', '3');
      expect(sink.sent.single, endsWith('|port set 1 rxant=3\n'));
    });

    // A relay switched under RF is a relay destroyed, and the switch accepted
    // every `port set` it was given on the bench — it does not refuse this
    // for us.
    test('refuses to switch a port that is transmitting, and says why', () {
      bringUp();
      session.feed('S0|port 1 auto=0 band=0 rxant=1 txant=1 inband=0 tx=1 inhibit=0\n');
      sink.sent.clear();
      session.selectAntenna('1', '3');
      expect(sink.sent, isEmpty);
      expect(sink.problems.last, isNotNull);
    });

    // Nothing else clears a problem except a later command succeeding, and an
    // operator who gives up and reaches for the switch's own panel never
    // sends one — so without this the row warns about a transmission that
    // ended minutes ago, for the rest of the session.
    test('the refusal clears itself once the port stops transmitting', () {
      bringUp();
      session.feed('S0|port 1 auto=0 band=0 rxant=1 txant=1 inband=0 tx=1 inhibit=0\n');
      session.selectAntenna('1', '3');
      expect(sink.problems.last, isNotNull);

      session.feed('S0|port 1 auto=0 band=0 rxant=1 txant=1 inband=0 tx=0 inhibit=0\n');
      expect(sink.problems.last, isNull);
    });

    test('a different port unkeying does not clear the refusal', () {
      bringUp();
      session.feed('S0|port 1 auto=0 band=0 rxant=1 txant=1 inband=0 tx=1 inhibit=0\n');
      session.selectAntenna('1', '3');
      session.feed('S0|port 2 auto=0 band=5 rxant=3 txant=3 inband=0 tx=0 inhibit=0\n');
      expect(sink.problems.last, isNotNull, reason: 'port 1 is still keyed');
    });

    test('switches a port that has stopped transmitting', () {
      bringUp();
      session.feed('S0|port 1 auto=0 band=0 rxant=1 txant=1 inband=0 tx=1 inhibit=0\n');
      session.feed('S0|port 1 auto=0 band=0 rxant=1 txant=1 inband=0 tx=0 inhibit=0\n');
      sink.sent.clear();
      session.selectAntenna('1', '3');
      expect(sink.sent, hasLength(1));
    });
  });

  group('what the switch refuses', () {
    // Verified on hardware: `version` answers 10, a bad subcommand 20, a bad
    // noun after `sub` 30. None of them is a broken link — the switch is
    // answering — so none may feed the reconnect ladder.
    test('a non-zero response code is a problem, never a connection error', () {
      session.startUpdates();
      session.feed('R1|20|\n');
      expect(sink.problems.last, isNotNull);
      expect(sink.problems.last, contains('20'));
    });

    test('names the command that was refused, since the code alone says nothing', () {
      session.startUpdates();
      // C1| is `info get` — the first thing startUpdates sends.
      session.feed('R1|10|\n');
      expect(sink.problems.last, contains('info get'));
    });

    test('a later success clears the problem', () {
      session.startUpdates();
      session.feed('R1|20|\n');
      expect(sink.problems.last, isNotNull);
      session.feed('R2|0|\n');
      expect(sink.problems.last, isNull);
    });

    test('a line no firmware version we know produces is ignored, not fatal', () {
      bringUp();
      final before = sink.reports;
      session.feed('R9|0|somethingnew 1 a=b\n');
      session.feed('what even is this\n');
      expect(sink.reports, before);
      expect(sink.problems.where((p) => p != null), isEmpty);
    });
  });

  group('announcing itself', () {
    // Captured off the real 8x2 on UDP 9007. CRLF-terminated, no VITA-49
    // wrapper — unlike the FlexRadio broadcast this otherwise resembles.
    const announcement = 'AG ip=10.0.0.67 port=9007 v=4.1.16 serial=00-00-00 '
        'name=Antenna_Genius ports=2 antennas=8 mode=master uptime=6143110\r\n';

    AgAnnouncement? parse(String text) => parseAgAnnouncement(utf8.encode(text));

    test('reads where to connect, and what the switch is', () {
      final found = parse(announcement)!;
      expect(found.host, '10.0.0.67');
      expect(found.port, 9007);
      expect(found.serial, '00-00-00');
      expect(found.name, 'Antenna Genius');
      expect(found.firmware, '4.1.16');
      expect(found.antennas, 8);
      expect(found.ports, 2);
    });

    // The announcement states where to connect, which is not necessarily the
    // datagram's sender — and without an address there is nothing to offer.
    test('an announcement with no address is not a device', () {
      expect(parse('AG port=9007 serial=00-00-00\r\n'), isNull);
    });

    // 9007 is a port number, not a protocol. Anything else broadcasting there
    // must not be offered as an antenna switch.
    test('a datagram from something else on the same port is ignored', () {
      expect(parse('HELLO ip=10.0.0.99 port=9007\r\n'), isNull);
      expect(parse('ip=10.0.0.99 port=9007\r\n'), isNull);
    });

    // The switch re-announces every few seconds. Without a stable id the Add
    // dialog fills with copies of the one switch on the bench.
    test('the serial is what keeps a re-announcing switch from duplicating', () {
      expect(parse(announcement)!.serial, parse(announcement.replaceAll('10.0.0.67', '10.0.0.5'))!.serial);
    });
  });

  group('a switch wired backwards', () {
    // The same box run the other way is a 2x8. Nothing about the wire
    // changes — `port set N rxant=X` still names the same relay banks — so
    // the only thing this may touch is what the operator is shown.
    test('numbers the ports instead of lettering them', () {
      final reversed = AntennaGeniusSession(sink, reversed: true);
      addTearDown(reversed.teardown);
      reversed.startUpdates();
      reversed.handleData(
        Uint8List.fromList(utf8.encode('${_portLines.join('\n')}\nR4|0|\n')),
      );
      expect(sink.ports.map((p) => p.label), ['1', '2'], reason: 'Port A is not where the radios are');
    });

    test('sends exactly the same command', () {
      final reversed = AntennaGeniusSession(sink, reversed: true);
      addTearDown(reversed.teardown);
      reversed.startUpdates();
      reversed.handleData(
        Uint8List.fromList(utf8.encode('${_portLines.join('\n')}\nR4|0|\n')),
      );
      sink.sent.clear();
      reversed.selectAntenna('1', '3');
      expect(sink.sent.single, endsWith('|port set 1 rxant=3\n'));
    });
  });

  group('the radio driving a port', () {
    test('names the radio, its band and its frequency', () {
      bringUp();
      session.feedLines(_drivenPortLines);

      expect(sink.port('1').radioName, 'RadioRoom');
      expect(sink.port('1').band, '20m');
      // MHz on the wire, kHz everywhere past the driver's own boundary.
      expect(sink.port('1').freqKHz, 14074.0);
    });

    // The switch names the radio a port is CONFIGURED to follow, whether or
    // not that radio is on a band. Reading the nickname as "a radio is using
    // this port right now" would be wrong on exactly this line.
    test('names a configured radio that is not on a band', () {
      bringUp();
      session.feedLines(_drivenPortLines);

      expect(sink.port('2').radioName, 'RadioRoom');
      expect(sink.port('2').band, isNull);
      expect(sink.port('2').freqKHz, isNull, reason: 'freq=0.000000 is not 0 Hz');
    });

    // Same convention rxant=0 and band=0 use — one field, two meanings.
    test('freq=0.000000 is nothing to say, not a frequency', () {
      bringUp();
      session.feed('S0|port 1 auto=1 source=AUTO band=0 freq=0.000000 rxant=1 txant=1 inband=0 tx=0 inhibit=0\n');
      expect(sink.port('1').freqKHz, isNull);
    });

    // The fixtures this file was built from predate the radio being switched
    // on, so nothing must require the newer fields to be present.
    test('a port line without them is still a port', () {
      bringUp();
      expect(sink.port('1').radioName, isNull);
      expect(sink.port('1').freqKHz, isNull);
      expect(sink.port('1').selectedAntennaKey, '1');
    });
  });

  group('a problem stands until the thing that caused it goes away', () {
    // The 10 s resync's own acknowledgement is a successful reply. Clearing
    // the problem on any success therefore wiped a live warning within ten
    // seconds while the condition still held — and the other tests in this
    // file could not see it, because none of them let the timer fire.
    test('a transmitting refusal survives the resync that follows it', () {
      fakeAsync((async) {
        bringUp();
        session.feed('S0|port 1 auto=0 band=0 rxant=1 txant=1 inband=0 tx=1 inhibit=0\n');
        session.selectAntenna('1', '3');
        expect(sink.problems.last, isNotNull);

        // The resync goes out and is acknowledged, and the port is still keyed.
        async.elapse(antennaGeniusResyncInterval);
        session.feed('R9|0|\n');
        expect(sink.problems.last, isNotNull, reason: 'the port is still transmitting');

        session.feed('S0|port 1 auto=0 band=0 rxant=1 txant=1 inband=0 tx=0 inhibit=0\n');
        expect(sink.problems.last, isNull, reason: 'and now it is not');

        session.teardown();
        async.flushTimers();
      });
    });

    // A refusal IS about the command, so a command going through is evidence
    // it no longer describes the switch.
    test('a refused command clears once one succeeds', () {
      bringUp();
      session.feed('R9|20|\n');
      expect(sink.problems.last, isNotNull);
      session.feed('R10|0|\n');
      expect(sink.problems.last, isNull);
    });

    // Two different conditions; a success says nothing about the keyed one.
    test('a success does not clear a transmitting refusal', () {
      bringUp();
      session.feed('S0|port 1 auto=0 band=0 rxant=1 txant=1 inband=0 tx=1 inhibit=0\n');
      session.selectAntenna('1', '3');
      session.feed('R9|0|\n');
      expect(sink.problems.last, isNotNull);
    });
  });

  group('a switch nobody is touching', () {
    // The manager marks a connection stale after 30 s of silence, and a
    // switch that pushes only on change is silent for as long as nothing
    // moves — so without a backstop an idle switch reads as "Not Responding"
    // while its socket is perfectly healthy.
    test('re-asks for its ports often enough to stay ahead of the silence watch', () {
      fakeAsync((async) {
        session.startUpdates();
        sink.sent.clear();

        async.elapse(antennaGeniusResyncInterval);
        expect(sentAny('sub port all'), isTrue);

        // Comfortably inside the 30 s the manager allows, with room for one
        // to go missing.
        expect(antennaGeniusResyncInterval * 2, lessThan(const Duration(seconds: 30)));

        session.teardown();
        async.flushTimers();
      });
    });

    test('stops re-asking once updates are stopped', () {
      fakeAsync((async) {
        session.startUpdates();
        session.stopUpdates();
        sink.sent.clear();
        async.elapse(antennaGeniusResyncInterval * 3);
        expect(sentAny('sub port all'), isFalse);
        async.flushTimers();
      });
    });

    // A resync that leaked would keep writing into a closed connection's
    // sink for the life of the process.
    test('the timer does not outlive teardown', () {
      fakeAsync((async) {
        session.startUpdates();
        session.teardown();
        sink.sent.clear();
        async.elapse(antennaGeniusResyncInterval * 3);
        expect(sink.sent, isEmpty);
      });
    });

    // Verified idempotent against a real 8x2: re-subscribing answers with the
    // full port list and accumulates nothing, so the command that proves the
    // link is alive also repairs a push that never arrived.
    test('a resync answer refreshes the routing', () {
      fakeAsync((async) {
        bringUp();
        expect(sink.port('1').selectedAntennaKey, '1');

        async.elapse(antennaGeniusResyncInterval);
        session.feed('S0|port 1 auto=1 source=AUTO band=0 rxant=2 txant=2 inband=0 tx=0 inhibit=0\n');
        expect(sink.port('1').selectedAntennaKey, '2');

        session.teardown();
        async.flushTimers();
      });
    });
  });

  group('the subscription', () {
    test('is dropped on teardown, so the switch stops pushing at a closed socket', () {
      bringUp();
      sink.sent.clear();
      session.teardown();
      expect(sentAny('unsub port all'), isTrue);
    });

    test('is not unsubscribed twice', () {
      bringUp();
      session.stopUpdates();
      sink.sent.clear();
      session.teardown();
      expect(sink.sent, isEmpty);
    });

    /// Null is a claim, not a missing answer: it says every quiet moment is
    /// evidence the switch has not moved. See EquipmentSession.
    test('pushes rather than polls', () {
      expect(session.expectedUpdateInterval, isNull);
    });
  });
}

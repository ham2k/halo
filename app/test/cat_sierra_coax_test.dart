// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Sierra Radio Systems DCN envelope and the CX-1 coax relay module.
//
// Unlike the Antenna Genius fixtures next door, most of what is asserted
// here comes from a published specification — the Station Controller
// Advanced Technical Manual rev 3, the USB-C Console Port Reference Manual
// and the #321 GPIO manual, which is where the coax module's own `SELn`
// happens to be documented.
//
// The fixtures below are bytes a real CX-1 sent (HALO-426 carries the
// capture), which matters for the two things no manual gets right: `LABEL`
// is answered in bare console text with no envelope, and `SELn` answers with
// the new state on its own.
//
// A session is pure given a fake sink, so all of this runs with no module.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/line_framer.dart';
import 'package:ham2k_logger/services/cat/drivers/sierra_coax_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/sierra_dcn_codec.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';

/// The module at the factory default address, answering the master.
///
/// Byte-for-byte what a CX-1 sends, lowercase check value and CRLF included
/// — both of which differ from what the manual prints and from what this app
/// transmits, which is the reason neither is matched on anywhere.
String _update(String mask, {String from = '02', String type = 'CX1'}) =>
    '/${from}00:UPDATE,$type,$mask:xx\r\n';

class _FakeSink implements EquipmentSink {
  final sent = <String>[];
  final diagnostics = <String?>[];
  final problems = <String?>[];
  List<SwitchAntenna> antennas = const [];
  List<SwitchPort> ports = const [];

  /// How many times the whole picture was republished. A bare count, because
  /// the panel is rebuilt per report and the labels arrive on a separate
  /// exchange from the state — a driver that published on each would redraw
  /// the Station panel once per label.
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

extension on SierraCoaxSession {
  void feed(String text) => handleData(Uint8List.fromList(utf8.encode(text)));
}

void main() {
  group('DCN envelope', () {
    test('a command is addressed and terminated by a bare CR', () {
      // The terminator is the whole test. A module scans its input buffer
      // for CR and evaluates there; sending CRLF leaves the LF to prefix the
      // next packet, whose parse then fails and flushes the buffer — so
      // every OTHER command would silently do nothing.
      expect(buildDcnPacket('SEL1', to: '02'), '/0002:SEL1:XX\r');
      expect(buildDcnPacket('SEL1', to: '02'), isNot(contains('\n')));
    });

    test('the broadcast form names no sender', () {
      expect(buildDcnBroadcast('STATE'), '//STATE\r');
    });

    test('an address is two characters, however the operator typed it', () {
      expect(dcnAddress('2'), '02');
      expect(dcnAddress(2), '02');
      expect(dcnAddress('15'), '15');
      // A software-assigned 16-99 is already two characters; re-padding it
      // would address a different module.
      expect(dcnAddress('99'), '99');
      // Nothing configured is the master's own address, which is what the
      // driver's default guards against ever being used as a target.
      expect(dcnAddress(''), dcnMasterAddress);
      expect(dcnAddress(null), dcnMasterAddress);
    });

    test('an addressed packet parses into its two addresses and payload', () {
      final packet = parseDcnPacket('/0200:UPDATE,CX1,0010:XX')!;
      expect(packet.from, '02');
      expect(packet.to, '00');
      expect(packet.payload, 'UPDATE,CX1,0010');
      expect(packet.command, 'UPDATE');
      expect(packet.isBroadcast, isFalse);
    });

    test('a broadcast packet parses with no sender', () {
      final packet = parseDcnPacket('//STATE')!;
      expect(packet.isBroadcast, isTrue);
      expect(packet.from, isNull);
      expect(packet.payload, 'STATE');
    });

    test('a packet with no check value is still readable', () {
      // The field is a documented placeholder that no shipping firmware
      // computes or verifies. A parser that required it would drop packets
      // from a module that simply left it off.
      expect(parseDcnPacket('/0200:UPDATE,CX1,0010')?.payload, 'UPDATE,CX1,0010');
    });

    test('anything that is not a packet is null, not an exception', () {
      // A module's boot banner and console prompt share this stream. A
      // parser that threw would turn a greeting into a dead connection.
      expect(parseDcnPacket('Sierra Radio Systems CX-1 v1.2'), isNull);
      expect(parseDcnPacket(''), isNull);
      expect(parseDcnPacket('/'), isNull);
      expect(parseDcnPacket('/0200:'), isNull);
      // Four address characters and a delimiter are the minimum; a short
      // frame must not be read as an address plus a payload.
      expect(parseDcnPacket('/020:X:XX'), isNull);
    });
  });

  group('CX-1 payloads', () {
    test('the mask names the selected port by position', () {
      // The one worked example the manual gives: "0001 indicating that port
      // 4 is currently selected".
      final state = parseCoaxUpdate(parseDcnPacket(_update('0001'))!)!;
      expect(state.selectedPort, 4);
      expect(state.moduleType, 'CX1');
      expect(state.mask, '0001');

      expect(parseCoaxUpdate(parseDcnPacket(_update('1000'))!)!.selectedPort, 1);
      expect(parseCoaxUpdate(parseDcnPacket(_update('0010'))!)!.selectedPort, 3);
    });

    test('an all-zero mask is nothing selected, not a parse failure', () {
      // The relays latch, so a module that has never been told anything
      // holds no port at all. Returning null here would make a fresh module
      // look like a module that is not answering.
      final state = parseCoaxUpdate(parseDcnPacket(_update('0000'))!)!;
      expect(state.selectedPort, isNull);
    });

    test('a mask with two bits set is refused rather than guessed', () {
      // A CX-1 connects one port at a time. Two bits means the payload is
      // not what this parser thinks it is, and taking the first would show
      // one of two connected antennas as though it were the only one.
      expect(parseCoaxUpdate(parseDcnPacket(_update('1001'))!), isNull);
    });

    test('the mask is found rather than taken from a fixed field index', () {
      // The GPIO module's UPDATE carries several fields after its type
      // token, and the coax module's field order is not published. A parser
      // pinned to field 2 would break on a firmware that puts anything ahead
      // of the mask.
      final packet = parseDcnPacket('/0200:UPDATE,CX1,13.85,0100:XX')!;
      expect(parseCoaxUpdate(packet)!.selectedPort, 2);
    });

    test('a wider mask is a different module, and is refused', () {
      // A GPIO board reports eight relays, in a run of 0s and 1s that looks
      // exactly like a port mask. The driver's sender filter normally keeps
      // it out; this is what stands behind a node pointed at the wrong
      // address, where that filter is satisfied and wrong. Without it,
      // `00000001` publishes a selection on port 8 that no antenna list can
      // name.
      expect(parseCoaxUpdate(parseDcnPacket('/0100:UPDATE,GPIO1,01000000,0110:XX')!), isNull);
      expect(parseCoaxUpdate(parseDcnPacket('/0100:UPDATE,GPIO1,00000001:XX')!), isNull);
    });

    test('a packet that is not an UPDATE yields nothing', () {
      expect(parseCoaxUpdate(parseDcnPacket('/0200:PONG,CX1:XX')!), isNull);
      expect(parseCoaxUpdate(parseDcnPacket('/0200:UPDATE,CX1:XX')!), isNull);
    });

    test('a label is plain console text, not a packet', () {
      // The one reply with no envelope. A reader that only parses packets
      // loses every antenna name and never notices.
      final label = parseCoaxLabel('Label 2 = 20M YAGI')!;
      expect(label.$1, 2);
      expect(label.$2, '20M YAGI');
    });

    test('the LABELS header is not a label', () {
      expect(parseCoaxLabel('LABELS'), isNull);
    });

    test('an unset label is nothing, so the port falls back to its number', () {
      // Exactly what the captured module sends for all four: `Label 1 = `
      // with a trailing space and no text.
      expect(parseCoaxLabel('Label 1 = '), isNull);
    });

    test('a STATUS line is not read as a label', () {
      // `STATUS` answers in the same plain-text form and includes a mask of
      // its own. A looser reader would take `1000` for an antenna name — and
      // worse, a mask-hunting one would take it for a port selection.
      expect(parseCoaxLabel('Node 02 Status'), isNull);
      expect(parseCoaxLabel('Relays     : 1000'), isNull);
    });

    test('a label outside the four ports is refused', () {
      expect(parseCoaxLabel('Label 9 = NOPE'), isNull);
      expect(parseCoaxLabel('Label 0 = NOPE'), isNull);
    });
  });

  group('CR framing', () {
    test('a CR-terminated peer yields one line per packet', () {
      final framer = LineFramer(crTerminates: true);
      expect(
        framer.add(Uint8List.fromList(utf8.encode('/0200:A:XX\r/0200:B:XX\r'))),
        ['/0200:A:XX', '/0200:B:XX'],
      );
    });

    test('the CX-1 sends CRLF, which is still one line per packet', () {
      // What the module actually does, against a specification that says the
      // end of packet is CR. Without the empty-line suppression this yields
      // a blank after every packet, and the label reader would see one too.
      final framer = LineFramer(crTerminates: true);
      expect(
        framer.add(Uint8List.fromList(utf8.encode('/0200:UPDATE,CX1,1000:xx\r\nLabel 1 = HEX\r\n'))),
        ['/0200:UPDATE,CX1,1000:xx', 'Label 1 = HEX'],
      );
    });

    test('a packet split across chunks is reassembled', () {
      // Serial delivers whatever the driver buffer happened to hold. A
      // framer with no residual mangles a packet that straddles two reads —
      // the app-polo bug docs/design/cat.md § Framing records.
      final framer = LineFramer(crTerminates: true);
      expect(framer.add(Uint8List.fromList(utf8.encode('/0200:UPD'))), isEmpty);
      expect(framer.add(Uint8List.fromList(utf8.encode('ATE,CX1,0001:XX\r'))), [
        '/0200:UPDATE,CX1,0001:XX',
      ]);
    });

    test('the default framer is unchanged: CR is dropped, a blank line kept', () {
      // The Antenna Genius terminates a multi-line answer WITH a blank line,
      // and the FlexRadio driver shares this framer. Letting CR termination
      // leak into the default would split its lines and swallow that
      // terminator — a break in two shipped drivers that no test of this
      // driver would ever see.
      final framer = LineFramer();
      expect(framer.add(Uint8List.fromList(utf8.encode('R1|0|info\r\n\n'))), ['R1|0|info', '']);
    });
  });

  group('session', () {
    late _FakeSink sink;
    late SierraCoaxSession session;

    setUp(() {
      sink = _FakeSink();
      session = SierraCoaxSession(sink, address: '02');
    });

    tearDown(() => session.teardown());

    test('bring-up asks for the labels, then waits before asking the state', () {
      fakeAsync((async) {
        final starting = SierraCoaxSession(sink, address: '02');
        starting.startUpdates();
        // Not pipelined. The labels take most of a second to arrive one line
        // at a time, and on half-duplex RS-485 a second command sent over
        // them destroys the module's reply rather than our own command — so
        // the symptom would be missing antenna names, not an error.
        expect(sink.sent, ['/0002:LABEL:XX\r']);

        async.elapse(sierraCoaxHandshakeGap);
        expect(sink.sent, ['/0002:LABEL:XX\r', '/0002:STATE:XX\r']);
        starting.stopUpdates();
      });
    });

    test('nothing is published until the state arrives', () {
      session.startUpdates();
      session.feed('Label 1 = HEX\r\n');
      session.feed('Label 2 = DIPOLE\r\n');
      expect(sink.reports, 0);

      session.feed(_update('0100'));
      expect(sink.reports, 1);
    });

    test('as sold: four antennas feeding one common port', () {
      session.startUpdates();
      session.feed('Label 1 = HEX\r\n');
      session.feed(_update('0010'));

      expect(sink.antennas.map((a) => a.key), ['1', '2', '3', '4']);
      expect(sink.antenna('1').name, 'HEX');
      // Every port is offered whether or not it is labelled — a CX-1 has
      // four relays whatever is screwed to them, and a label is a
      // convenience somebody may never have typed in. Unnamed rather than
      // "Port 4": the panel supplies that wording and would otherwise
      // render "Antenna on port 4 - Port 4".
      expect(sink.antenna('4').name, '');

      expect(sink.ports.length, 1);
      expect(sink.port(sierraCommonPortKey).selectedAntennaKey, '3');
    });

    test('reversed: four device ports sharing one antenna', () {
      // Not a relabelling, unlike the Antenna Genius. The module still has
      // one relay, so exactly one of the four ports holds the antenna and
      // the other three hold nothing.
      final reversed = SierraCoaxSession(sink, address: '02', reversed: true);
      addTearDown(reversed.teardown);
      reversed.startUpdates();
      reversed.feed(_update('0010'));

      expect(sink.antennas.map((a) => a.key), [sierraCommonPortKey]);
      expect(sink.ports.map((p) => p.key), ['1', '2', '3', '4']);
      // A bare identifier, as the Antenna Genius passes when reversed. The
      // panel words it as "Port 3"; a driver that words it too gets
      // "Port Port 3".
      expect(sink.port('3').label, '3');
      expect(sink.port('3').selectedAntennaKey, sierraCommonPortKey);
      expect(sink.port('1').selectedAntennaKey, isNull);
      expect(sink.port('4').selectedAntennaKey, isNull);
    });

    test('nothing selected leaves the port on no antenna', () {
      session.startUpdates();
      session.feed(_update('0000'));
      expect(sink.port(sierraCommonPortKey).selectedAntennaKey, isNull);
    });

    test('another module on the bus is ignored', () {
      // RS-485 is one pair shared by every device, so a GPIO board answering
      // the operator's own dashboard arrives here too. Without the sender
      // check its eight-relay mask parses as a port change and the panel
      // shows an antenna nobody selected.
      session.startUpdates();
      session.feed(_update('1000'));
      expect(sink.port(sierraCommonPortKey).selectedAntennaKey, '1');

      session.feed('/0100:UPDATE,GPIO1,00010000:XX\r');
      expect(sink.reports, 1);
      expect(sink.port(sierraCommonPortKey).selectedAntennaKey, '1');
    });

    test('our own command echoed back is ignored', () {
      // A two-wire RS-485 dongle with no echo suppression puts everything we
      // send back on our own receive line. It is addressed FROM the master,
      // which is the only thing distinguishing it from an answer.
      session.startUpdates();
      session.feed('/0002:STATE:XX\r');
      expect(sink.reports, 0);
    });

    test('selecting an antenna sends one command and nothing else', () {
      session.startUpdates();
      session.feed(_update('1000'));
      sink.sent.clear();

      session.selectAntenna(sierraCommonPortKey, '3');
      // No follow-up query. The module answers a select with the new state
      // on its own about a second later, and a second command sent onto a
      // half-duplex bus while that answer is coming back is what breaks it.
      expect(sink.sent, ['/0002:SEL3:XX\r']);
    });

    test('the answer to a select is the new state', () {
      session.startUpdates();
      session.feed(_update('1000'));
      session.selectAntenna(sierraCommonPortKey, '3');
      // A second or so later, once the relay has settled.
      session.feed(_update('0010'));
      expect(sink.port(sierraCommonPortKey).selectedAntennaKey, '3');
    });

    test('a STATUS answer does not move the selection', () {
      // STATUS comes back as plain console text carrying a relay mask of its
      // own — `Relays     : 1000`. Nothing asks for it, but a module may be
      // answering somebody else's console on the same bus.
      session.startUpdates();
      session.feed(_update('0010'));
      sink.reports = 0;

      session.feed('Node 02 Status\r\nRelays     : 1000\r\n');
      expect(sink.reports, 0);
      expect(sink.port(sierraCommonPortKey).selectedAntennaKey, '3');
    });

    test('reversed, the relay is named by the port rather than the antenna', () {
      final reversed = SierraCoaxSession(sink, address: '02', reversed: true);
      addTearDown(reversed.teardown);
      reversed.startUpdates();
      sink.sent.clear();

      // The operator picks which radio gets the one antenna there is, so the
      // numbered side — and the number the module needs — is the PORT.
      reversed.selectAntenna('2', sierraCommonPortKey);
      expect(sink.sent.first, '/0002:SEL2:XX\r');
    });

    test('a key outside the four ports sends nothing', () {
      // SEL9 is not a command the module has. Sending it would put a refusal
      // on the bus for a selection the panel could not have offered.
      session.startUpdates();
      sink.sent.clear();
      session.selectAntenna(sierraCommonPortKey, '9');
      session.selectAntenna(sierraCommonPortKey, sierraCommonPortKey);
      expect(sink.sent, isEmpty);
    });

    test('the module is polled, because nothing announces a button press', () {
      fakeAsync((async) {
        final polled = SierraCoaxSession(sink, address: '02');
        polled.startUpdates();
        async.elapse(sierraCoaxHandshakeGap);
        sink.sent.clear();

        async.elapse(sierraCoaxPollInterval * 3);
        expect(sink.sent, List.filled(3, '/0002:STATE:XX\r'));

        // Stopping must actually stop: a timer surviving stopUpdates keeps
        // a disconnected node's traffic on a shared bus forever.
        polled.stopUpdates();
        sink.sent.clear();
        async.elapse(sierraCoaxPollInterval * 3);
        expect(sink.sent, isEmpty);
      });
    });

    test('a select restarts the poll, so nothing lands on its answer', () {
      fakeAsync((async) {
        final polled = SierraCoaxSession(sink, address: '02');
        polled.startUpdates();
        async.elapse(sierraCoaxHandshakeGap);

        // Four seconds in: one more second and the poll would fire straight
        // into the module's reply, which takes about a second to arrive
        // while the relay settles. On a half-duplex pair it is the REPLY
        // that is destroyed, so the panel would sit unmoved for a further
        // full period.
        async.elapse(sierraCoaxPollInterval - const Duration(seconds: 1));
        sink.sent.clear();
        polled.selectAntenna(sierraCommonPortKey, '2');
        expect(sink.sent, ['/0002:SEL2:XX\r']);

        async.elapse(const Duration(seconds: 2));
        expect(sink.sent, ['/0002:SEL2:XX\r']);

        async.elapse(sierraCoaxPollInterval);
        expect(sink.sent, ['/0002:SEL2:XX\r', '/0002:STATE:XX\r']);
        polled.stopUpdates();
      });
    });

    test('the poll period is declared, since this session never gets told', () {
      // Null would claim the module pushes, and the staleness watchdog and
      // Smart VFO Snap both read this to tell "nothing has happened" from
      // "nobody has asked yet".
      expect(session.expectedUpdateInterval, sierraCoaxPollInterval);
    });

    test('teardown forgets the selection', () {
      // The relays latch and may well be moved by hand while the app is
      // away, so a reconnect that redrew the last known selection would
      // assert something about the relays that nothing had checked.
      session.startUpdates();
      session.feed(_update('1000'));
      session.teardown();
      sink.reports = 0;

      session.startUpdates();
      session.feed('Label 1 = HEX\r\n');
      expect(sink.reports, 0);
    });
  });

  group('driver', () {
    const driver = SierraCoaxDriver();

    test('it is hardware-verified', () {
      // Every payload shape in the codec is bytes a real CX-1 sent, including
      // the two the manuals get wrong.
      expect(driver.hardwareVerified, isTrue);
    });

    test('a device address outside 1-99 is refused', () {
      // 0 is the master — ours. A node addressed there talks to itself and
      // the module never hears a word, which on screen is indistinguishable
      // from a dead cable.
      expect(driver.validateField(sierraAddressConfigKey, '0', {}), isNotNull);
      expect(driver.validateField(sierraAddressConfigKey, '100', {}), isNotNull);
      expect(driver.validateField(sierraAddressConfigKey, 'two', {}), isNotNull);
      expect(driver.validateField(sierraAddressConfigKey, '2', {}), isNull);
      // Blank is the factory default, not a missing answer.
      expect(driver.validateField(sierraAddressConfigKey, '', {}), isNull);
    });

    test('the session is built for the configured address and layout', () {
      final session = driver.createSession(_FakeSink(), {
        sierraAddressConfigKey: '7',
        'switchLayout': 'antennaPorts',
      }) as SierraCoaxSession;
      addTearDown(session.teardown);
      expect(session.address, '07');
      expect(session.reversed, isTrue);
    });

    test('an unconfigured node addresses the factory default', () {
      final session = driver.createSession(_FakeSink(), {}) as SierraCoaxSession;
      addTearDown(session.teardown);
      expect(session.address, '02');
      expect(session.reversed, isFalse);
    });

    test('a CLEARED address field falls back too, and never addresses 00', () {
      // The validator accepts a blank on purpose, and the editor stores a
      // cleared text field as '' rather than dropping the key — so a plain
      // `??` leaves dcnAddress to return the master's own address. Every
      // command would go to /0000 and the session's sender filter would drop
      // every real reply: connected, green, polling forever, no ports.
      final session = driver.createSession(_FakeSink(), {
        sierraAddressConfigKey: '',
      }) as SierraCoaxSession;
      addTearDown(session.teardown);
      expect(session.address, '02');
      expect(session.address, isNot(dcnMasterAddress));

      expect(driver.describeSuffix({sierraAddressConfigKey: '  '}), contains('DCN 02'));
    });
  });
}

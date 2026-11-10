// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Green Heron Everyware protocol, its hub, and the rotor and switch
// sessions behind it.
//
// The lines fed here are a capture of a live Everyware server (WU2X's
// station): three rotors and seven switches, every display type
// but a bank among them, pushed in full on connect and then repeated — each
// heading about once a second, each switch's position every few seconds —
// whether or not anything moves. The login exchange and its test vector are
// GHMac's (docs/PROTOCOL.md), which a capture of an open server cannot show.

import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/everyware_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/everyware_devices.dart';
import 'package:ham2k_logger/services/cat/drivers/everyware_server.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';

import '../support/fake_clock.dart';

const _us = '\u001F';
const _gs = '\u001D';

/// A line as the server sends it: the capture's visible separators made real.
String _wire(String visible) => visible.replaceAll('|', _us).replaceAll('^', _gs);

Uint8List _bytes(String text) => Uint8List.fromList(cp1252Encode(text));

/// The capture's opening, in the order the server sent it.
final _captured = [
  "ADD|Tower 2 - 150'",
  "POINT|Tower 2 - 150'|213.7|0|0",
  'POINT|Tower 3 - OB12-4|276.0|0|0',
  'SWITCHUPDATE|2xArrays Stack|IN Phase|0|0',
  "ADD|Tower 1 - 180'",
  'ADD|Tower 3 - OB12-4',
  'SWITCHUPDATE|80m 4 sq|SW|0|0',
  'SWITCHADD|2|160m-CROSSFIRE|NE^45^90^false|SE^135^90^false|SW^225^90^false|NW^315^90^false',
  'SWITCHADD|1| OB12-4 switch|K3-RADIO 1-AMP1-5b^0^0^false|K3-RADIO 2--AMP2-6b^0^0^false|K3-RADIO 3^0^0^false',
  'SWITCHADD|3|OB80-2S|3.770 - 4.000 Mhz^3.77^4.0|3.736 - 3.770 Mhz^3.736^3.77|3.670 - 3.736 Mhz^3.67^3.736|3.500 - 3.670 Mhz^3.5^3.67',
  'SWITCHADD|1|2xArrays Stack|IN Phase^0^0^false|OUT Of Phase^0^0^false|Lower Pair Only^0^0^false|Higher Pair Only^0^0^false',
  'SWITCHADD|2|80m 4 sq|NE^45^90^false|SE^135^90^false|SW^225^90^false|NW^315^90^false',
  'SWITCHUPDATE|SW, W, NW BEV|W PHASED BEV|0|-68',
].map(_wire).toList();

class _Sink implements EquipmentSink, RotatorSink {
  final sent = <List<int>>[];
  final positions = <RotatorPosition>[];
  final problems = <String?>[];
  final channels = <List<EquipmentChannel>>[];
  var antennas = <SwitchAntenna>[];
  var ports = <SwitchPort>[];
  var alive = 0;

  List<String> get commands => [
    for (final bytes in sent)
      if (!(bytes.length == 1 && bytes.first == 0)) everywareCommandText(bytes),
  ];
  int get keepalives => sent.where((bytes) => bytes.length == 1 && bytes.first == 0).length;

  @override
  void send(List<int> bytes) => sent.add(bytes);
  @override
  void reportRotator(RotatorPosition position) => positions.add(position);
  @override
  void reportProblem(String? message) => problems.add(message);
  @override
  void reportChannels(List<EquipmentChannel> channels) => this.channels.add(channels);
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {
    this.antennas = antennas;
    this.ports = ports;
  }

  @override
  void reportAlive() => alive++;
  @override
  void report(VfoReading reading) => fail('nothing here has a VFO');
  @override
  void reportPower(num watts) => fail('nothing here has power');
  @override
  void reportTransmitting(bool transmitting) => fail('nothing here transmits');
  @override
  void reportMeter(RadioMeter meter, num value) => fail('nothing here has meters');
  @override
  void reportKeyerSpeed(int wpm) => fail('nothing here keys');
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportVoiceActivity(VoiceActivity? activity) {}
  @override
  void reportVoiceMemories(List<VoiceMemory> memories) {}
  @override
  void reportDiagnostic(String? note) {}
}

extension on EquipmentSession {
  void feed(String line) => handleData(_bytes('$line\r\n'));
}

void main() {
  final st = t.settings.station;

  group('Everyware lines', () {
    test('read as the capture has them', () {
      expect(parseEverywareLine(_wire("POINT|Tower 1 - 180'|279.5|0|0")), isA<EverywarePoint>().having((p) => p.heading, 'heading', 279.5));
      final crossfire = parseEverywareLine(_captured[7]) as EverywareSwitchAdded;
      expect(crossfire.kind, EverywareSwitchKind.map);
      expect(crossfire.positions.map((p) => (p.name, p.heading, p.beamwidth)), [('NE', 45, 90), ('SE', 135, 90), ('SW', 225, 90), ('NW', 315, 90)]);
      final band = parseEverywareLine(_captured[9]) as EverywareSwitchAdded;
      expect(band.kind, EverywareSwitchKind.band);
      expect(band.positions.first.covers(3.85), isTrue);
      // The name keeps its leading space: it is how the server spells it, and
      // a SET_SWITCH naming it any other way names nothing.
      expect((parseEverywareLine(_captured[8]) as EverywareSwitchAdded).name, ' OB12-4 switch');
    });

    test('a map or band switch whose numbers do not read is refused, not read as zero', () {
      // A direction read as 0 would point the array north for a station
      // that is south of it.
      expect(parseEverywareLine(_wire('SWITCHADD|2|4sq|NE^north^90^false')), isA<EverywareOther>());
      expect(parseEverywareLine(_wire('SWITCHADD|3|bands|80m^three^4.0')), isA<EverywareOther>());
      // Buttons only ever use the name, so their numbers are not checked.
      expect(parseEverywareLine(_wire('SWITCHADD|1|btn|A^x^y^false')), isA<EverywareSwitchAdded>());
    });

    test('a band range left blank is no range, not an unreadable switch', () {
      final added = parseEverywareLine(_wire('SWITCHADD|3|bands|Spare^^')) as EverywareSwitchAdded;
      expect(added.positions.single.covers(14.0), isFalse);
    });

    test('a direction written with decimals is still a direction', () {
      final added = parseEverywareLine(_wire('SWITCHADD|2|4sq|NE^45.0^90.0^false')) as EverywareSwitchAdded;
      expect((added.positions.single.heading, added.positions.single.beamwidth), (45, 90));
    });

    test('a status-less POINT is a stopped rotor, as the oldest servers mean it', () {
      expect((parseEverywareLine(_wire('POINT|R|90')) as EverywarePoint).status, '2');
      expect((parseEverywareLine(_wire('POINT|R|90|5|0')) as EverywarePoint).unreachable, isTrue);
    });

    test('lines split on LF, CR LF or a lone CR, across chunk boundaries', () {
      final splitter = EverywareLineSplitter();
      expect(splitter.add(_bytes('ADD${_us}A\r')), ['ADD${_us}A']);
      // The LF finishing the CR above is not a second, empty line.
      expect(splitter.add(_bytes('\nADD${_us}B\nADD${_us}C\r\n')), ['ADD${_us}B', 'ADD${_us}C']);
    });

    test('names in CP1252 survive the round trip that a SET_SWITCH depends on', () {
      // A curly quote typed on the server's Windows machine: read as Latin-1
      // it would be a control character, and the command naming it would
      // name a switch the server does not have.
      const name = 'Tower ’1’ – 80m';
      expect(cp1252Decode(cp1252Encode(name)), name);
      expect(cp1252Encode('’'), [0x92]);
    });

    test('commands are one CR LF line each', () {
      expect(everywareTurn('Tower 3 - OB12-4', 250), [...cp1252Encode('TURN${_us}Tower 3 - OB12-4${_us}250'), 13, 10]);
      expect(everywareCommandText(everywareSetSwitch('80m 4 sq', 'NE')), 'SET_SWITCH${_us}80m 4 sq${_us}NE');
      expect(everywareCommandText(everywareStop('R')), 'STOP${_us}R');
    });

    test('the password proof matches the published test vector', () {
      final proof = everywarePasswordProof(user: 'alice', password: 'secret1', challenge: '0.7316931046151538-81283467123456789011665432101234');
      expect(proof.map((b) => b.toRadixString(16).padLeft(2, '0')).join(), '1912ccc6bb389e47bf97c8877c7b6eeba9110f5c1f0ac6cdd345f7d7135a37c7');
    });
  });

  group('EverywareServerSession', () {
    test('lists every device the server announced, the ones nothing here drives included', () {
      final sink = _Sink();
      final hub = EverywareServerSession(sink);
      for (final line in _captured) {
        hub.feed(line);
      }
      hub.feed(_wire('SWITCHADD|4|Bank|A^0^0^false|B^0^0^false'));
      hub.feed(_wire('STACKADD|Upper,Lower'));
      // In announcement order, not first mention: Tower 3's heading came in
      // ahead of the ADD that names it. A bank and a stack are listed, by
      // kind, so the editor can show them greyed rather than not at all.
      expect(hub.devices.map((d) => (d.key, d.mode)), [
        ("rotor:Tower 2 - 150'", null),
        ("rotor:Tower 1 - 180'", null),
        ('rotor:Tower 3 - OB12-4', null),
        ('switchBox:160m-CROSSFIRE', 'map'),
        ('switchBox: OB12-4 switch', 'buttons'),
        ('switchBox:OB80-2S', 'band'),
        ('switchBox:2xArrays Stack', 'buttons'),
        ('switchBox:80m 4 sq', 'map'),
        ('switchBox:Bank', 'bank'),
        ('stack:Upper,Lower', 'stack'),
      ]);
      expect(sink.channels.last, hub.devices);
      hub.feed(_wire('STACKREMOVE|Upper,Lower'));
      expect(sink.channels.last.map((d) => d.key), isNot(contains('stack:Upper,Lower')));
      // Every line is the server answering — the repeats are what keep an
      // idle server's node from reading "not responding".
      expect(sink.alive, _captured.length + 3);
    });

    test('a device link opened late starts from everything already said about it', () async {
      final hub = EverywareServerSession(_Sink());
      for (final line in _captured) {
        hub.feed(line);
      }
      final link = hub.openDevice('switchBox:80m 4 sq');
      final lines = <String>[];
      link.data.listen((chunk) => lines.addAll(EverywareLineSplitter().add(chunk)));
      hub.feed(_wire('SWITCHUPDATE|80m 4 sq|NE|0|0'));
      hub.feed(_wire("POINT|Tower 2 - 150'|214.0|0|0"));
      await pumpEventQueue();
      // The announcement first, then the last position known, then what came
      // after — and nothing about any other device.
      expect(lines.map(everywareVisible), [
        'SWITCHADD␟2␟80m 4 sq␟NE␝45␝90␝false␟SE␝135␝90␝false␟SW␝225␝90␝false␟NW␝315␝90␝false',
        'SWITCHUPDATE␟80m 4 sq␟SW␟0␟0',
        'SWITCHUPDATE␟80m 4 sq␟NE␟0␟0',
      ]);
    });

    test("a link's commands go out over the server's connection, and it closes with it", () async {
      final sink = _Sink();
      final hub = EverywareServerSession(sink);
      final link = hub.openDevice('rotor:R');
      link.send(everywareTurn('R', 90));
      expect(sink.commands, ['TURN${_us}R${_us}90']);
      var closed = false;
      unawaited(link.closed.then((_) => closed = true));
      hub.teardown();
      await pumpEventQueue();
      expect(closed, isTrue, reason: 'a device node whose server dropped must drop with it, not sit "connected" to nothing');
    });

    test('logs in when asked, and says so when it cannot', () {
      final sink = _Sink();
      final hub = EverywareServerSession(sink, user: 'alice', password: 'secret1');
      hub.feed('USER:');
      expect(sink.commands, ['alice']);
      hub.feed('PASS:0.7316931046151538-81283467123456789011665432101234');
      // 32 raw bytes and no line ending: the server reads exactly 32.
      expect(sink.sent.last, hasLength(32));
      hub.feed('INVALID USER/PASS');
      expect(sink.problems.last, st.everywareLoginRefused);

      final anonymous = _Sink();
      EverywareServerSession(anonymous).feed('USER:');
      expect(anonymous.sent, isEmpty, reason: 'an empty user name is not an answer worth sending');
      expect(anonymous.problems.last, st.everywareNeedsLogin);
    });

    test('keeps the connection with a NUL from 10 s, every 5 s, but never right behind a command', () {
      followFakeClock();
      fakeAsync((async) {
        final sink = _Sink();
        final hub = EverywareServerSession(sink)..startUpdates();
        async.elapse(const Duration(seconds: 9));
        expect(sink.keepalives, 0);
        async.elapse(const Duration(seconds: 1));
        expect(sink.keepalives, 1);
        async.elapse(const Duration(seconds: 2));
        hub.openDevice('rotor:R').send(everywareStop('R'));
        // The next one is due at 15 s, 3 s after a command: a NUL landing
        // right behind a command corrupts it, so that one is skipped.
        async.elapse(const Duration(seconds: 3));
        expect(sink.keepalives, 1);
        async.elapse(const Duration(seconds: 5));
        expect(sink.keepalives, 2);
        hub.teardown();
        async.elapse(const Duration(seconds: 30));
        expect(sink.keepalives, 2);
      });
    });
  });

  group('EverywareRotorSession', () {
    test('reports whole degrees from its own POINTs only', () {
      final sink = _Sink();
      final rotor = EverywareRotorSession(sink, 'Tower 3 - OB12-4');
      for (final line in _captured) {
        rotor.feed(line);
      }
      expect(sink.positions, [const RotatorPosition(azimuth: 276)]);
      // The capture's resting flicker, 248.6 and 249.2, is one heading.
      rotor.feed(_wire('POINT|Tower 3 - OB12-4|248.6|0|0'));
      rotor.feed(_wire('POINT|Tower 3 - OB12-4|249.2|0|0'));
      expect(sink.positions.skip(1), [const RotatorPosition(azimuth: 249), const RotatorPosition(azimuth: 249)]);
    });

    test("a turn's first seconds of standing still are not a stop", () {
      followFakeClock();
      fakeAsync((async) {
        final sink = _Sink();
        final rotor = EverywareRotorSession(sink, 'R');
        rotor.feed(_wire('POINT|R|276.0|0|0'));
        expect(rotor.rotateTo(azimuth: 250), const RotatorPosition(azimuth: 250));
        expect(sink.commands, ['TURN${_us}R${_us}250']);
        // Live, the first movement showed ~6 s after the command, with a
        // repeat of the old heading every second until then. Reported, five
        // of those end the turn as stalled before the mast moves.
        for (var i = 0; i < 6; i++) {
          async.elapse(const Duration(seconds: 1));
          rotor.feed(_wire('POINT|R|276.0|0|0'));
        }
        expect(sink.positions, [const RotatorPosition(azimuth: 276)]);
        expect(sink.alive, 7, reason: 'the first reading and the six held back: every one is the server answering');
        rotor.feed(_wire('POINT|R|272.6|0|0'));
        rotor.feed(_wire('POINT|R|272.6|0|0'));
        // Moving now: from here a repeat is a mast standing still again.
        expect(sink.positions.skip(1), [const RotatorPosition(azimuth: 273), const RotatorPosition(azimuth: 273)]);
      });
    });

    test('a turn that never starts is reported once the wait is over', () {
      followFakeClock();
      fakeAsync((async) {
        final sink = _Sink();
        final rotor = EverywareRotorSession(sink, 'R')..feed(_wire('POINT|R|90|0|0'));
        rotor.rotateTo(azimuth: 180);
        async.elapse(everywareTurnStartWait);
        rotor.feed(_wire('POINT|R|90|0|0'));
        expect(sink.positions, [const RotatorPosition(azimuth: 90), const RotatorPosition(azimuth: 90)]);
      });
    });

    test('a rotor the server never names says so, rather than reading connected to nothing', () {
      followFakeClock();
      fakeAsync((async) {
        final sink = _Sink();
        final gone = EverywareRotorSession(sink, 'Renamed on the server')..startUpdates();
        for (final line in _captured) {
          gone.feed(line);
        }
        async.elapse(everywareAnnounceWait);
        expect(sink.problems.last, st.everywareDeviceGone);
        gone.teardown();

        final named = _Sink();
        final here = EverywareRotorSession(named, 'Tower 3 - OB12-4')..startUpdates();
        for (final line in _captured) {
          here.feed(line);
        }
        async.elapse(everywareAnnounceWait * 2);
        expect(named.problems, isNot(contains(st.everywareDeviceGone)));
        here.teardown();
      });
    });

    test('a rotor with no heading to report is still the server answering', () {
      // A fixed antenna repeats 999, an unreachable controller its stale
      // heading: neither is a reading, and without a sign of life each would
      // go "not responding" over the reason it has.
      final sink = _Sink();
      EverywareRotorSession(sink, 'R')
        ..feed(_wire('POINT|R|999|7|0'))
        ..feed(_wire('POINT|R|90|5|0'));
      expect(sink.alive, 2);
    });

    test('a turn to where it already points arrives at once', () {
      followFakeClock();
      fakeAsync((async) {
        final sink = _Sink();
        final rotor = EverywareRotorSession(sink, 'R')..feed(_wire('POINT|R|245.3|0|0'));
        rotor.rotateTo(azimuth: 245);
        async.elapse(const Duration(seconds: 1));
        rotor.feed(_wire('POINT|R|245.3|0|0'));
        expect(sink.positions, hasLength(2), reason: 'nothing to wait for: held, the turn would read in progress for the whole wait');
      });
    });

    test("an unreachable controller's heading is withheld and said why", () {
      final sink = _Sink();
      EverywareRotorSession(sink, 'R')
        ..feed(_wire('POINT|R|90|5|0'))
        ..feed(_wire('POINT|R|999|7|0'));
      expect(sink.positions, isEmpty, reason: '999 is a fixed antenna saying it has no heading, not a direction');
      expect(sink.problems.first, st.everywareRotorUnreachable);
    });

    test('a full turn is north, and stop names the rotor', () {
      final sink = _Sink();
      final rotor = EverywareRotorSession(sink, 'R');
      expect(rotor.rotateTo(azimuth: 360), const RotatorPosition(azimuth: 0));
      rotor.stopRotation();
      expect(sink.commands, ['TURN${_us}R${_us}0', 'STOP${_us}R']);
    });
  });

  group('EverywareDirectionalSession', () {
    EverywareDirectionalSession connected(_Sink sink, {bool follow = false}) {
      final session = EverywareDirectionalSession(sink, '80m 4 sq', follow: follow);
      for (final line in _captured) {
        session.feed(line);
      }
      return session;
    }

    test('points where its selected direction does, every time the server repeats it', () {
      final sink = _Sink();
      final session = connected(sink);
      // SW, with the beam its direction announced — what the rotator panel
      // draws in place of its own setting.
      expect(sink.positions, [const RotatorPosition(azimuth: 225, beamWidth: 90)]);
      // The repeats are readings, as a rotator's are: they feed its silence
      // watch, and count toward a turn that never arrives.
      session.feed(_wire('SWITCHUPDATE|80m 4 sq|SW|0|0'));
      expect(sink.positions, hasLength(2));
    });

    test('a turn picks the nearest open direction, and arrives at its heading', () {
      final sink = _Sink();
      final session = connected(sink);
      // Answered with where it will arrive, not where it was asked: a target
      // of 30 on an array that only points 45 would never be reached.
      expect(session.rotateTo(azimuth: 30), const RotatorPosition(azimuth: 45));
      expect(sink.commands, ['SET_SWITCH${_us}80m 4 sq${_us}NE']);
      session.feed(_wire('SWITCHLOCKS|80m 4 sq|NE'));
      expect(session.rotateTo(azimuth: 10), const RotatorPosition(azimuth: 315), reason: 'NE is locked out; NW is the nearest open');
      // Already there: nothing to send.
      expect(session.rotateTo(azimuth: 225), const RotatorPosition(azimuth: 225));
      session.feed(_wire('SWITCHUPDATE|80m 4 sq|SW|0|0'));
      session.rotateTo(azimuth: 220);
      expect(sink.commands, hasLength(3));
    });

    test('with every direction locked out it says why, and claims no turn', () {
      final sink = _Sink();
      final session = connected(sink)..feed(_wire('SWITCHLOCKS|80m 4 sq|NE|SE|SW|NW'));
      // The heading it already has: answered with the one asked for, the
      // panel would draw a turn toward somewhere it never goes.
      expect(session.rotateTo(azimuth: 40), const RotatorPosition(azimuth: 225));
      expect(sink.commands, isEmpty);
      expect(sink.problems.last, st.everywareNoDirectionOpen);
      session.feed(_wire('SWITCHLOCKS|80m 4 sq'));
      session.rotateTo(azimuth: 40);
      expect(sink.problems.last, isNull, reason: 'the refusal ends with the turn that goes through');
    });

    test('a direction fired both ways is drawn along the lobe it was turned toward', () {
      final sink = _Sink();
      final session = EverywareDirectionalSession(sink, 'Array')
        ..feed(_wire('SWITCHADD|2|Array|NE/SW^45^60^true|NW/SE^315^60^true'))
        ..feed(_wire('SWITCHUPDATE|Array|NW/SE|0|0'));
      // Toward 225 the NE/SW array fires off its back: drawn along its front
      // it would point away from the station it was turned to.
      expect(session.rotateTo(azimuth: 225), const RotatorPosition(azimuth: 225));
      session.feed(_wire('SWITCHUPDATE|Array|NE/SW|0|0'));
      expect(sink.positions.last.azimuth, 225);
    });

    test('a direction the server cannot name is still the server answering', () {
      final sink = _Sink();
      final session = connected(sink);
      final before = sink.alive;
      session.feed(_wire('SWITCHUPDATE|80m 4 sq|UNKNOWN|0|0'));
      expect(sink.alive, before + 1);
    });

    test('points toward the station worked only when told to', () {
      final quiet = _Sink();
      connected(quiet).followBearing(30);
      expect(quiet.commands, isEmpty);
      final sink = _Sink();
      connected(sink, follow: true).followBearing(30);
      expect(sink.commands, ['SET_SWITCH${_us}80m 4 sq${_us}NE']);
    });
  });

  group('EverywareSwitchSession', () {
    EverywareSwitchSession connected(_Sink sink, String name, {bool follow = false}) {
      final session = EverywareSwitchSession(sink, name, follow: follow);
      for (final line in _captured) {
        session.feed(line);
      }
      return session;
    }

    test('is one port whose antennas are its positions', () {
      final sink = _Sink();
      connected(sink, '80m 4 sq');
      expect(sink.antennas.map((a) => a.key), ['NE', 'SE', 'SW', 'NW']);
      expect(sink.ports.single.label, '80m 4 sq');
      expect(sink.ports.single.selectedAntennaKey, 'SW');
    });

    test('a position another switch locked out is not offered, and not sent', () {
      final sink = _Sink();
      final session = connected(sink, '80m 4 sq')..feed(_wire('SWITCHLOCKS|80m 4 sq|NE|SE'));
      expect(
        [
          for (final a in sink.antennas)
            if (a.configured) a.key,
        ],
        ['SW', 'NW'],
      );
      session.selectAntenna(everywareSwitchPortKey, 'NE');
      expect(sink.commands, isEmpty);
      expect(sink.problems.last, st.everywarePositionLocked(position: 'NE'));
      session.feed(_wire('SWITCHLOCKS|80m 4 sq'));
      session.selectAntenna(everywareSwitchPortKey, 'NE');
      expect(sink.commands, ['SET_SWITCH${_us}80m 4 sq${_us}NE']);
      expect(sink.problems.last, isNull, reason: 'the refusal ends with the selection that goes through');
    });

    test("follows the radio's band only when told to", () {
      final quiet = _Sink();
      connected(quiet, 'OB80-2S').followFrequency(3520);
      expect(quiet.commands, isEmpty, reason: 'the station is shared: a switch moves by itself only when its node opts in');

      final sink = _Sink();
      final session = connected(sink, 'OB80-2S', follow: true)..feed(_wire('SWITCHUPDATE|OB80-2S|3.770 - 4.000 Mhz|0|0'));
      session.followFrequency(3850);
      expect(sink.commands, isEmpty, reason: 'still inside the current range');
      session.followFrequency(3520);
      expect(sink.commands, ['SET_SWITCH${_us}OB80-2S${_us}3.500 - 3.670 Mhz']);
      // The server repeats the old position until the relay moves; the
      // next reading of the dial must not send the same command again.
      session.feed(_wire('SWITCHUPDATE|OB80-2S|3.770 - 4.000 Mhz|0|0'));
      session.followFrequency(3521);
      expect(sink.commands, hasLength(1));
    });

    test('a selection the server never confirms stops standing in for the switch', () {
      followFakeClock();
      fakeAsync((async) {
        final sink = _Sink();
        final session = connected(sink, 'OB80-2S', follow: true)..feed(_wire('SWITCHUPDATE|OB80-2S|3.770 - 4.000 Mhz|0|0'));
        session.followFrequency(3520);
        async.elapse(everywareSelectionPending);
        session.followFrequency(3521);
        expect(sink.commands, hasLength(2), reason: 'a refused switch would otherwise never be asked again');
      });
    });

    test('band selection keeps a parked switch, skips locked ranges and leaves an uncovered frequency alone', () {
      const positions = [
        EverywarePosition('OFF', lowMHz: 0, highMHz: 100),
        EverywarePosition('A', lowMHz: 3.5, highMHz: 3.8),
        EverywarePosition('B', lowMHz: 3.5, highMHz: 4.0),
      ];
      expect(everywareBandPosition(positions, current: 'OFF', freqMHz: 3.6), isNull, reason: 'parked on purpose');
      expect(everywareBandPosition(positions, current: 'Dummy load', freqMHz: 3.6), isNull);
      expect(everywareBandPosition(positions.skip(1).toList(), current: null, freqMHz: 3.6), 'A');
      expect(everywareBandPosition(positions.skip(1).toList(), current: null, freqMHz: 3.6, locked: {'A'}), 'B');
      expect(everywareBandPosition(positions.skip(1).toList(), current: 'A', freqMHz: 7.0), isNull);
    });

    test('points a following map switch the nearest open way, an array fired both ways included', () {
      const positions = [
        EverywarePosition('NE', heading: 45),
        EverywarePosition('SE', heading: 135),
        EverywarePosition('SW', heading: 225),
        EverywarePosition('NW', heading: 315),
      ];
      expect(everywareMapPosition(positions, bearing: 350), 'NW');
      expect(everywareMapPosition(positions, bearing: 10), 'NE');
      expect(everywareMapPosition(positions, bearing: 10, locked: {'NE'}), 'NW');
      expect(everywareMapPosition(const [EverywarePosition('E-W', heading: 90, bidirectional: true), EverywarePosition('N', heading: 0)], bearing: 265), 'E-W');

      final sink = _Sink();
      connected(sink, '80m 4 sq', follow: true).followBearing(30);
      expect(sink.commands, ['SET_SWITCH${_us}80m 4 sq${_us}NE']);
      final band = _Sink();
      connected(band, 'OB80-2S', follow: true).followBearing(30);
      expect(band.commands, isEmpty, reason: 'a band switch has no direction to follow');
    });
  });
}

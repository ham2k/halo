// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Yaesu receive passband (`SH`/`IS`/`NA`), with no radio and no serial
// port. The tables are pinned against the CAT manuals — FT-891, FT-991,
// FT-991A, FTDX10, and the FT-710's Japanese edition — not against a radio:
// none of this has met one.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/ft891_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/yaesu_cat_codec.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/telemetry_poller.dart';

class _Sink implements EquipmentSink, PassbandSink {
  final sent = <String>[];
  final passbands = <Passband?>[];

  @override
  void reportPassband(Passband? passband) => passbands.add(passband);

  @override
  void send(List<int> bytes) => sent.add(ascii.decode(bytes));

  @override
  void report(VfoReading reading) {}
  @override
  void reportPower(num watts) {}
  @override
  void reportTransmitting(bool transmitting) {}
  @override
  void reportMeter(RadioMeter meter, num value) {}
  @override
  void reportKeyerSpeed(int wpm) {}
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportVoiceActivity(VoiceActivity? activity) {}
  @override
  void reportVoiceMemories(List<VoiceMemory> memories) {}
  @override
  void reportDiagnostic(String? note) {}
  @override
  void reportProblem(String? message) {}
  @override
  void reportChannels(List<EquipmentChannel> channels) {}
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
  @override
  void reportAlive() {}
}

extension on Ft891Session {
  void feed(String text) => handleData(Uint8List.fromList(ascii.encode(text)));
}

const _ft891 = '0650';
const _ft991 = '0570';
const _ft991a = '0670';
const _ftdx10 = '0761';
const _ft710 = '0800';

YaesuWidthProfile _profile(String id) => yaesuWidthProfilesById[id]!;

/// Every width in [table], index 1 up, as the manual lists them.
List<int> _widths(YaesuWidthTable table) => [for (var i = 1; table.widths.containsKey(i); i++) table.widths[i]!];

void main() {
  group('the tables', () {
    // Each list is the manual's, read off its SH table. The radios share a
    // command and disagree on what most of its indices mean, so a table
    // crossed with its neighbour's shows and sets the wrong filter with
    // nothing to say so.
    const ft891Ssb = [200, 400, 600, 850, 1100, 1350, 1500, 1650, 1800, 1950, 2100, 2200, 2300, 2400, 2500, 2600, 2700, 2800, 2900, 3000, 3200];
    const ft891Cw = [50, 100, 150, 200, 250, 300, 350, 400, 450, 500, 800, 1200, 1400, 1700, 2000, 2400, 3000];
    const ftdx10Ssb = [300, 400, 600, 850, 1100, 1200, 1500, 1650, 1800, 1950, 2100, 2250, 2400, 2450, 2500, 2600, 2700, 2800, 2900, 3000, 3200, 3500, 4000];
    const ftdx10Cw = [50, 100, 150, 200, 250, 300, 350, 400, 450, 500, 600, 800, 1200, 1400, 1700, 2000, 2400, 3000, 3200, 3500, 4000];
    const ft710Cw = [50, 100, 150, 200, 250, 300, 350, 400, 450, 500, 600, 800, 1200, 1400, 1700, 2000, 2400, 3000, 3500, 4000];

    test('the FT-891, FT-991 and FT-991A share one table', () {
      for (final id in [_ft891, _ft991, _ft991a]) {
        expect(_widths(_profile(id).ssb), ft891Ssb, reason: id);
        expect(_widths(_profile(id).cw), ft891Cw, reason: id);
      }
    });

    test('the FTDX10 and FT-710 share SSB and part ways in CW', () {
      expect(_widths(_profile(_ftdx10).ssb), ftdx10Ssb);
      expect(_widths(_profile(_ft710).ssb), ftdx10Ssb);
      expect(_widths(_profile(_ftdx10).cw), ftdx10Cw);
      // No 3200 Hz on the FT-710: from index 19 its CW widths are the
      // FTDX10's one place earlier.
      expect(_widths(_profile(_ft710).cw), ft710Cw);
    });

    test('a radio without a profile has no passband: the FT-450, the FTX-1, an unknown ID', () {
      // The FT-450's two IDs; the FTX-1's `SH` is a different command by
      // hamlib's account, with no manual here. Guessing a table for either
      // would show a filter the radio does not have.
      for (final id in ['0241', '0244', '0840', '9999']) {
        expect(yaesuWidthProfilesById[id], isNull, reason: id);
      }
    });

    test('00 is the NARROW state\'s default on the FT-891 line, and unknowable on the FTDX10', () {
      final ssb = _profile(_ft891).ssb;
      expect(ssb.widthHz(0, narrowOn: true), 1500);
      expect(ssb.widthHz(0, narrowOn: false), 2400);
      expect(ssb.widthHz(0), isNull, reason: 'NARROW not yet read');
      expect(_profile(_ft891).cw.widthHz(0, narrowOn: true), 500);
      expect(_profile(_ft891).cw.widthHz(0, narrowOn: false), 2400);
      // The FTDX10's default follows the roofing filter, which nothing reads.
      expect(_profile(_ftdx10).ssb.widthHz(0, narrowOn: false), isNull);
    });
  });

  group('the codec', () {
    test('each radio sets the width in its own shape', () {
      expect(buildSetWidthCommand(_profile(_ft891), 17), 'SH0117;', reason: 'P2 ON, as hamlib writes it');
      expect(buildSetWidthCommand(_profile(_ft991), 17), 'SH017;');
      expect(buildSetWidthCommand(_profile(_ftdx10), 5), 'SH0005;');
      expect(buildSetWidthCommand(_profile(_ft710), 5), 'SH0005;');
    });

    test('a width answer is read only at its radio\'s own length', () {
      expect(parseWidthParams('0018', _profile(_ft891)), 18);
      expect(parseWidthParams('0118', _profile(_ft891)), 18);
      expect(parseWidthParams('018', _profile(_ft991)), 18);
      // `0118` losing its `1` reads `018` — a valid FT-991 answer naming a
      // different filter. Length is what tells the two apart.
      expect(parseWidthParams('011', _profile(_ft891)), isNull);
      expect(parseWidthParams('0018', _profile(_ft991)), isNull);
      expect(parseWidthParams('0A18', _profile(_ftdx10)), isNull);
    });

    test('an IF shift is read in its radio\'s own layout', () {
      expect(parseShiftParams('01+0100', _profile(_ft891)), 100);
      expect(parseShiftParams('01-0240', _profile(_ft891)), -240);
      expect(parseShiftParams('00+0100', _profile(_ft891)), 0, reason: 'P2 OFF is the shift switched off');
      expect(parseShiftParams('00-0200', _profile(_ftdx10)), -200);
      expect(parseShiftParams('01-0200', _profile(_ftdx10)), isNull, reason: 'P2 is a fixed 0 there');
      expect(parseShiftParams('0+0100', _profile(_ft991)), 100);
      expect(parseShiftParams('00+0100', _profile(_ft991)), isNull);
      expect(parseShiftParams('00+010', _profile(_ftdx10)), isNull);
    });

    test('the nearest width is taken from what the NARROW state offers', () {
      final ssb = _profile(_ft891).ssb;
      expect(ssb.nearestIndex(2700, narrowOn: false), 17);
      // Narrow tops out at 1800: a set does not flip NARROW to reach 2700.
      expect(ssb.nearestIndex(2700, narrowOn: true), 9);
      expect(ssb.nearestIndex(300, narrowOn: false), 9, reason: 'and wide bottoms out at 1800');
      expect(ssb.nearestIndex(2700), isNull, reason: 'NARROW unknown, so which indices exist is too');
      // 650 Hz sits halfway between 500 and 800: the narrower wins.
      expect(_profile(_ft891).cw.nearestIndex(650, narrowOn: false), 10);
      expect(_profile(_ftdx10).ssb.nearestIndex(2420), 13);
      expect(_profile(_ftdx10).cw.nearestIndex(3200), 19);
      expect(_profile(_ft710).cw.nearestIndex(3200), 18, reason: 'the FT-710 has no 3200: 3000 is nearer than 3500');
    });
  });

  group('the session', () {
    late _Sink sink;
    late Ft891Session session;

    setUp(() {
      sink = _Sink();
      session = Ft891Session(sink, config: const {telemetryIntervalConfigKey: 600000});
    });

    /// [id] answering, in [mode], and the filter read that follows.
    void connect(String id, String modeCode) {
      session.feed('ID$id;');
      sink.sent.clear();
      session.feed('MD0$modeCode;');
    }

    List<String> passbandReads() => sink.sent.where((c) => c == 'SH0;' || c == 'IS0;' || c == 'NA0;').toList();

    test('asks which radio it is, and reads the filter once the mode is known', () {
      fakeAsync((async) {
        session.startUpdates();
        expect(sink.sent.take(2), ['AI1;', 'ID;']);
        expect(passbandReads(), isEmpty, reason: 'no table yet');
        session.feed('ID$_ft891;');
        expect(passbandReads(), isEmpty, reason: 'no mode yet, and no table without one');
        session.feed('MD02;');
        // NARROW and the shift ahead of the width, so the SH answer is
        // placed with both already in.
        expect(passbandReads(), ['NA0;', 'IS0;', 'SH0;']);
        session.teardown();
      });
    });

    test('the FTDX10 is not asked NARROW, which does not change its table', () {
      connect(_ftdx10, '2');
      expect(passbandReads(), ['IS0;', 'SH0;']);
    });

    test('USB sits above the carrier, LSB mirrors it, and the shift moves USB', () {
      connect(_ft891, '2');
      session.feed('NA00;IS00+0000;SH0014;');
      expect(sink.passbands.last, const Passband(300, 2700));

      session.feed('IS01+0200;SH0014;');
      expect(sink.passbands.last, const Passband(500, 2900), reason: '+ is up in pitch and frequency alike in USB');

      session.feed('MD01;IS00+0000;SH0014;');
      expect(sink.passbands.last, const Passband(-2700, -300));
    });

    test('a shifted LSB or CW-R filter is not placed: which way + moves it there is undocumented', () {
      connect(_ftdx10, '1');
      session.feed('IS00+0000;SH0013;');
      expect(sink.passbands.last, const Passband(-2700, -300));
      session.feed('IS00+0200;SH0013;');
      expect(sink.passbands.last, isNull);
      sink.passbands.clear();
      session.feed('MD07;IS00-0100;SH0010;');
      expect(sink.passbands, isEmpty, reason: 'still null, so nothing new to say');
      session.feed('IS00+0000;SH0010;');
      expect(sink.passbands.last, const Passband(-250, 250));
    });

    test('CW is centred on the tuned frequency, and a shift moves it', () {
      connect(_ft991, '3');
      session.feed('NA00;IS0+0000;SH010;');
      expect(sink.passbands.last, const Passband(-250, 250));
      session.feed('IS0+0100;SH010;');
      expect(sink.passbands.last, const Passband(-150, 350));
    });

    test('the default index is placed from NARROW where the table depends on it', () {
      connect(_ft891, '2');
      session.feed('NA01;IS00+0000;SH0000;');
      expect(sink.passbands.last, const Passband(750, 2250));
    });

    test('a width with no shift read yet is not placed', () {
      // An IS answer in another radio's layout parses to nothing; taking the
      // shift as zero then would put a shifted filter where it is not.
      connect(_ft891, '2');
      session.feed('NA00;IS0+0200;SH0014;');
      expect(sink.passbands, isEmpty);
    });

    test('the same width reported again says nothing new', () {
      connect(_ft891, '2');
      session.feed('NA00;IS00+0000;SH0014;');
      session.feed('NA00;IS00+0000;SH0014;');
      expect(sink.passbands, [const Passband(300, 2700)]);
    });

    test('a mode it cannot place reports no passband, and is not asked about', () {
      fakeAsync((async) {
        session.startUpdates();
        connect(_ft891, '2');
        session.feed('NA00;IS00+0000;SH0014;');
        sink.sent.clear();
        session.feed('MD05;');
        // An AM filter shown with an SSB width would be a filter the radio
        // does not have.
        expect(sink.passbands.last, isNull);
        async.elapse(const Duration(minutes: 1));
        expect(passbandReads(), isEmpty);
        session.teardown();
      });
    });

    test('a mode change reads the new mode\'s filter at once', () {
      connect(_ft891, '2');
      session.feed('NA00;IS00+0000;SH0014;');
      sink.sent.clear();
      session.feed('MD03;');
      // The radio keeps a width per mode: USB's index read as CW's would
      // show a 1700 Hz CW filter until the next slow read.
      expect(passbandReads(), ['NA0;', 'IS0;', 'SH0;']);
    });

    test('is read far less often than the frequency, but still read', () {
      fakeAsync((async) {
        session.startUpdates();
        connect(_ftdx10, '2');
        session.feed('IS00+0000;SH0013;');
        sink.sent.clear();
        async.elapse(const Duration(minutes: 2));
        final fa = sink.sent.where((c) => c == 'FA;').length;
        final sh = sink.sent.where((c) => c == 'SH0;').length;
        expect(sh, greaterThan(1), reason: 'a filter changed from the front panel must still be seen');
        expect(sh, lessThanOrEqualTo(fa ~/ 4), reason: 'not riding on every state poll');
        session.teardown();
      });
    });

    test('a radio with no profile is never asked, and a set sends nothing', () {
      fakeAsync((async) {
        session.startUpdates();
        connect('0241', '2');
        async.elapse(const Duration(minutes: 1));
        session.setPassband(const Passband(300, 2700));
        expect(sink.sent.where((c) => c.startsWith('SH') || c.startsWith('IS') || c.startsWith('NA')), isEmpty);
        expect(sink.passbands, isEmpty);
        session.teardown();
      });
    });

    test('a set writes the nearest width and reads it back, and touches nothing else', () {
      connect(_ft891, '2');
      session.feed('NA00;IS01+0100;SH0014;');
      sink.sent.clear();
      session.setPassband(const Passband(100, 2820));
      // 2720 wide: 2700 is nearest. No MD, no NA or IS set — the operator's
      // mode, NARROW and shift are theirs.
      expect(sink.sent, ['SH0117;', 'NA0;', 'IS0;', 'SH0;']);
      session.feed('NA00;IS01+0100;SH0017;');
      expect(sink.passbands.last, const Passband(250, 2950), reason: 'where it landed, the radio\'s shift kept');
    });

    test('a set waits for NARROW on a radio whose table depends on it', () {
      connect(_ft891, '2');
      session.feed('IS00+0000;SH0014;');
      sink.sent.clear();
      session.setPassband(const Passband(300, 2700));
      expect(sink.sent.where((c) => c.startsWith('SH0') && c != 'SH0;'), isEmpty);
    });

    test('a set in a mode it cannot place sends nothing', () {
      connect(_ftdx10, '9');
      session.setPassband(const Passband(-250, 250));
      expect(sink.sent.where((c) => c.startsWith('SH')), isEmpty);
    });

    test('a radio that refuses SH is reported as having no passband, once, and is not asked again', () {
      fakeAsync((async) {
        session.startUpdates();
        connect(_ftdx10, '2');
        session.feed('?;');
        session.feed('MD01;');
        expect(passbandReads(), contains('SH0;'), reason: 'one refusal is not yet proof: `?;` names no command');
        session.feed('?;');
        sink.sent.clear();
        session.feed('MD02;');
        expect(passbandReads(), isEmpty);
        expect(sink.passbands, isEmpty, reason: 'nothing was ever reported, so null is not news');

        async.elapse(const Duration(minutes: 2));
        session.setPassband(const Passband(300, 2700));
        expect(sink.sent.where((c) => c.startsWith('SH')), isEmpty);
        session.teardown();
      });
    });

    test('a refusal beside an SH answer is not SH refused', () {
      // `?;` names no command: a radio refusing something else in the same
      // batch must not lose its passband to it.
      connect(_ftdx10, '2');
      for (final mode in ['1', '2', '1', '2']) {
        session.feed('?;IS00+0000;SH0013;');
        sink.sent.clear();
        session.feed('MD0$mode;');
        expect(passbandReads(), contains('SH0;'), reason: 'mode $mode');
      }
    });

    test('nothing is read while a voice memory plays', () {
      // The FT-891 ends a DVS recording at the next read; the state poll
      // holds for it, and a filter read is a read.
      final voiced = Ft891Session(sink, config: const {telemetryIntervalConfigKey: 600000});
      voiced.feed('ID$_ft891;MD02;');
      voiced.recordVoiceMemory(1);
      sink.sent.clear();
      voiced.feed('MD01;');
      expect(passbandReads(), isEmpty);
      voiced.teardown();
    });
  });
}

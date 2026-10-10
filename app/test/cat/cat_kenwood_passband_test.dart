// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The receive passband over Kenwood CAT, written from Kenwood's TS-590S/SG
// command guide and Elecraft's K3/KX3 and K4 programmer's references rather
// than a capture. The hazards: one driver serves radios whose filter commands
// share letters but not units or meanings, the TS-590SG's `SL`/`SH` change
// meaning with a menu, and a width set nothing reads back is one nobody sees
// land.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_cat_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';

class _FakeSink implements EquipmentSink, PassbandSink {
  final sent = <String>[];
  final passbands = <Passband?>[];
  final diagnostics = <String?>[];

  @override
  void send(List<int> bytes) => sent.add(ascii.decode(bytes));
  @override
  void reportPassband(Passband? passband) => passbands.add(passband);
  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);

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
  void reportProblem(String? message) {}
  @override
  void reportChannels(List<EquipmentChannel> channels) {}
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
  @override
  void reportAlive() {}
}

/// Long enough for [kenwoodPassbandReadEvery] idle polls to go by.
const _onePassbandRead = Duration(seconds: 20);

/// A K4 status packet in its K31 layout — see k4_codec.dart.
String _k4Info({String mode = '2', bool tx = false}) => 'IF00014074000     +000000 00${tx ? 1 : 0}${mode}000001 ;';

void main() {
  late _FakeSink sink;

  setUp(() => sink = _FakeSink());

  void receive(KenwoodSession session, String text) => session.handleData(Uint8List.fromList(ascii.encode(text)));
  int reads(String command) => sink.sent.where((c) => c == command).length;

  group('the codec', () {
    test('an Elecraft centre at 9000 Hz or above is never sent', () {
      // `IS 9xxx` is the K3 line's "re-centre for the mode", not a frequency:
      // a passband dragged high would silently snap back to the default.
      expect(buildElecraftSetCentreCommand(8999), 'IS 8999;');
      expect(buildElecraftSetCentreCommand(9000), isNull);
      expect(buildElecraftSetCentreCommand(-10), isNull);
    });

    test('the K4\'s unspaced IS is in 10 Hz units, and only the K4\'s', () {
      // The spaced form is Hz on every radio here; the unspaced one is the K4
      // format in tens. Read on another radio, it would be a tenth of the truth.
      expect(parseKenwoodShiftParams(' 0600'), 600);
      expect(parseKenwoodShiftParams(' 0600', k4: true), 600);
      expect(parseKenwoodShiftParams('0060', k4: true), 600);
      expect(parseKenwoodShiftParams('0060'), isNull);
      expect(parseKenwoodShiftParams('+0100'), isNull, reason: 'a signed shift is some other radio\'s IS');
    });

    test('BW is in 10 Hz units both ways', () {
      expect(parseElecraftBandwidthParams('0270'), 2700);
      expect(buildElecraftSetBandwidthCommand(2400), 'BW0240;');
      expect(parseElecraftBandwidthParams('270'), isNull);
    });

    test('a menu answer is read only in the guide\'s shape', () {
      expect(parseKenwoodMenuParams('02800001'), (menu: 28, value: 1));
      expect(parseKenwoodMenuParams('0400000'), isNull, reason: 'no setting');
      expect(parseKenwoodMenuParams('02810001'), isNull);
    });
  });

  group('choosing the dialect', () {
    test('the TS-590SG dialect needs the DATA flag, and the K4 needs no pin', () {
      // Without `DA` an SSB-DATA filter would be read through the SSB menu's
      // meaning of SL/SH — cuts taken for width and shift.
      KenwoodSession make(KenwoodDriver driver, Map<String, dynamic> config) => driver.createSession(sink, config) as KenwoodSession;
      expect(make(const KenwoodDriver(), {KenwoodDriver.passbandDialectKey: 'ts590sg'}).passbandDialect, isNull);
      expect(
        make(const KenwoodDriver(), {KenwoodDriver.passbandDialectKey: 'ts590sg', KenwoodDriver.dataModeKey: true}).passbandDialect,
        KenwoodPassbandDialect.ts590sg,
      );
      expect(make(const KenwoodDriver(), {KenwoodDriver.passbandDialectKey: 'elecraft'}).passbandDialect, KenwoodPassbandDialect.elecraft);
      expect(make(const KenwoodDriver(), {}).passbandDialect, isNull);
      expect(make(const KenwoodDriver.k4(), {}).passbandDialect, KenwoodPassbandDialect.elecraft);
    });

    test('an unpinned radio is never asked, believed or written to', () {
      // A QMX or a generic Kenwood: `IS`/`BW` there may carry other units or
      // meanings, so even an answer arriving by itself is not a passband.
      fakeAsync((async) {
        final session = KenwoodSession(sink)..startUpdates();
        receive(session, 'MD2;BW0270;IS 1500;');
        async.elapse(const Duration(minutes: 1));
        expect(sink.sent.where((c) => c.startsWith('BW') || c.startsWith('IS') || c.startsWith('SL')), isEmpty);
        expect(sink.passbands, isEmpty);
        sink.sent.clear();
        session.setPassband(const Passband(300, 2700));
        expect(sink.sent, isEmpty);
        session.stopUpdates();
      });
    });
  });

  group('an Elecraft K3/KX', () {
    late KenwoodSession session;
    setUp(() => session = KenwoodSession(sink, passbandDialect: KenwoodPassbandDialect.elecraft));

    test('SSB edges are the AF passband, mirrored below the carrier in LSB', () {
      receive(session, 'MD2;BW0270;IS 1500;');
      expect(sink.passbands.last, const Passband(150, 2850));
      receive(session, 'MD1;BW0270;IS 1500;');
      expect(sink.passbands.last, const Passband(-2850, -150));
    });

    test('CW is centred while the filter sits on the pitch, and unknown once shifted', () {
      // Shifted, the side the radio receives CW on decides which way the
      // passband moves, and no reference says which side CW and CW-R are.
      receive(session, 'MD3;BW0040;IS 0600;CW60;');
      expect(sink.passbands.last, const Passband(-200, 200));
      receive(session, 'IS 0700;');
      expect(sink.passbands.last, isNull);
    });

    test('DATA, AM and FM report none and ask nothing', () {
      // An Elecraft refuses IS in FM; asking anyway would spend refusals.
      for (final mode in ['6', '5', '4']) {
        sink.sent.clear();
        receive(session, 'MD$mode;BW0270;IS 1500;');
        expect(sink.passbands.last, isNull, reason: 'MD$mode');
        expect(sink.sent, isEmpty, reason: 'MD$mode');
      }
    });

    test('a mode change forgets the old filter and reads the new one at once', () {
      // The width and centre the radio gave in CW are not its SSB filter;
      // placed in USB until the next poll they would draw a filter that is not.
      receive(session, 'MD3;BW0040;IS 0600;CW60;');
      sink.sent.clear();
      receive(session, 'MD2;');
      expect(sink.passbands.last, isNull);
      expect(sink.sent, ['BW;', 'IS;']);
    });

    test('rides the state poll at a fraction of its rate', () {
      fakeAsync((async) {
        session.startUpdates();
        receive(session, 'MD2;');
        async.elapse(const Duration(minutes: 1));
        final polls = reads('FA;');
        expect(polls, greaterThan(kenwoodPassbandReadEvery * 2));
        // Every Nth poll — the first falls due before the mode is known, and
        // the mode's arrival reads in its place.
        expect(reads('BW;'), (polls / kenwoodPassbandReadEvery).ceil());
        session.stopUpdates();
      });
    });

    test('SSB sets width and centre, then reads back', () {
      receive(session, 'MD1;BW0270;IS 1500;');
      sink.sent.clear();
      session.setPassband(const Passband(-2700, -300));
      expect(sink.sent, ['BW0240;', 'IS 1500;', 'BW;', 'IS;']);
    });

    test('CW sets the width and keeps the shift', () {
      // The centre is the pitch, which the operator owns.
      receive(session, 'MD3;BW0040;IS 0600;CW60;');
      sink.sent.clear();
      session.setPassband(const Passband(-125, 125));
      expect(sink.sent, ['BW0025;', 'BW;', 'IS;', 'CW;']);
    });

    test('writes nothing before the passband has been read in this mode', () {
      // Until the radio answers, BW/IS are not known to mean a filter on it.
      session.setPassband(const Passband(300, 2700));
      expect(sink.sent, isEmpty);
      receive(session, 'MD2;BW0270;');
      sink.sent.clear();
      session.setPassband(const Passband(300, 2700));
      expect(sink.sent, isEmpty, reason: 'width alone places nothing');
    });
  });

  group('a radio that refuses the filter reads', () {
    late KenwoodSession session;
    setUp(() => session = KenwoodSession(sink, passbandDialect: KenwoodPassbandDialect.elecraft));

    test('reports none once and stops asking', () {
      fakeAsync((async) {
        session.startUpdates();
        receive(session, 'MD2;');
        receive(session, '?;');
        async.elapse(_onePassbandRead);
        // The tuner, asked in the same poll, draws its own diagnostic.
        Iterable<String?> passbandNotes() => sink.diagnostics.where((d) => d!.contains('passband'));
        expect(passbandNotes(), isEmpty, reason: 'one refusal is not proof');
        receive(session, '?;');
        async.elapse(_onePassbandRead);
        expect(passbandNotes(), hasLength(1));
        expect(sink.passbands.last, isNull);

        sink.sent.clear();
        async.elapse(const Duration(minutes: 2));
        expect(reads('BW;'), 0, reason: 'not asked again');
        session.setPassband(const Passband(300, 2700));
        expect(sink.sent.where((c) => c.startsWith('BW')), isEmpty, reason: 'nor written to');
        session.stopUpdates();
      });
    });

    test('a refusal beside an answered read is no strike', () {
      // `?;` names no command: the `AC;` in the same poll draws one on every
      // Elecraft. Only an unanswered filter read beside it counts.
      fakeAsync((async) {
        session.startUpdates();
        receive(session, 'MD2;');
        for (var i = 0; i < 4; i++) {
          receive(session, '?;BW0270;IS 1500;');
          async.elapse(_onePassbandRead);
        }
        expect(sink.passbands.last, const Passband(150, 2850));
        sink.sent.clear();
        async.elapse(_onePassbandRead);
        expect(reads('BW;'), greaterThan(0), reason: 'still asked');
        session.stopUpdates();
      });
    });
    test('a refusal beside an answered read is no strike against the next', () {
      // The trap: an answered read still counted as unanswered. Then a stray
      // refusal on it plus one answer lost to noise reads as two refusals in
      // a row, and the radio loses its passband for the connection.
      fakeAsync((async) {
        session.startUpdates();
        receive(session, 'MD2;');
        receive(session, '?;BW0270;IS 1500;');
        async.elapse(_onePassbandRead);
        receive(session, '?;');
        async.elapse(_onePassbandRead);
        expect(sink.diagnostics.where((d) => d!.contains('passband')), isEmpty);
        session.stopUpdates();
      });
    });
  });

  group('the K4', () {
    late KenwoodSession session;
    setUp(() => session = KenwoodSession(sink, isK4: true, passbandDialect: KenwoodPassbandDialect.elecraft));

    test('reads its IS in either documented format', () {
      receive(session, '${_k4Info()}BW0270;IS0150;');
      expect(sink.passbands.last, const Passband(150, 2850));
      receive(session, 'IS 1400;');
      expect(sink.passbands.last, const Passband(50, 2750));
    });

    test('sets the width only', () {
      // Which IS format it takes under K40 is not settled; a centre written
      // in the wrong units would land the passband a factor of ten away.
      receive(session, '${_k4Info()}BW0270;IS0150;');
      sink.sent.clear();
      session.setPassband(const Passband(300, 2700));
      expect(sink.sent, ['BW0240;', 'BW;', 'IS;']);
    });

    test('its DATA modes report none', () {
      receive(session, '${_k4Info(mode: '6')}BW0270;IS0150;');
      expect(sink.passbands.last, isNull);
    });

    test('is not asked while transmitting', () {
      // The K3 line answers `?;` to commands it will not take on the air;
      // a long transmission would otherwise cost the reads for the session.
      fakeAsync((async) {
        session.startUpdates();
        receive(session, _k4Info(tx: true));
        sink.sent.clear();
        async.elapse(const Duration(minutes: 1));
        expect(reads('BW;'), 0);
        session.stopUpdates();
      });
    });
  });

  group('a TS-590SG', () {
    late KenwoodSession session;
    setUp(() => session = KenwoodSession(sink, dataMode: true, passbandDialect: KenwoodPassbandDialect.ts590sg));

    test('SSB reads its menu first, then cuts or width/shift as the menu says', () {
      receive(session, 'MD2;');
      expect(sink.sent, ['EX0280000;', 'SL;', 'SH;']);
      receive(session, 'EX02800000;SL03;SH09;');
      expect(sink.passbands.last, const Passband(200, 2800));
      // The same indexes under WIDTH/SHIFT are another filter entirely.
      receive(session, 'EX02800001;SL13;SH05;');
      expect(sink.passbands.last, const Passband(250, 2750));
      receive(session, 'MD1;EX02800000;SL03;SH09;');
      expect(sink.passbands.last, const Passband(-2800, -200));
    });

    test('SSB-DATA follows its own menu, not SSB\'s', () {
      // Menus 028 and 029 are set independently on the radio.
      receive(session, 'MD2;EX02800000;');
      sink.sent.clear();
      receive(session, 'DA1;MD2;');
      expect(sink.sent, contains('EX0290000;'));
      receive(session, 'SL13;SH05;');
      expect(sink.passbands.last, isNull, reason: 'SSB-DATA\'s menu unread');
      receive(session, 'EX02900001;');
      expect(sink.passbands.last, const Passband(250, 2750));
    });

    test('CW reads width, shift and pitch, and is centred only on the pitch', () {
      receive(session, 'MD3;');
      expect(sink.sent, ['FW;', 'IS;', 'EX0400000;']);
      receive(session, 'FW0500;IS 0600;EX04000006;');
      expect(sink.passbands.last, const Passband(-250, 250));
      receive(session, 'IS 0650;');
      expect(sink.passbands.last, isNull);
    });

    test('sets the nearest cuts, or the nearest width and shift', () {
      receive(session, 'MD2;EX02800000;SL03;SH09;');
      sink.sent.clear();
      session.setPassband(const Passband(310, 2750));
      expect(sink.sent, ['SL04;', 'SH09;', 'EX0280000;', 'SL;', 'SH;']);

      receive(session, 'EX02800001;');
      sink.sent.clear();
      session.setPassband(const Passband(600, 2400));
      expect(sink.sent.take(2), ['SL12;', 'SH05;']);
    });

    test('LSB edges are mirrored before choosing cuts', () {
      receive(session, 'MD1;EX02800000;SL03;SH09;');
      sink.sent.clear();
      session.setPassband(const Passband(-2750, -310));
      expect(sink.sent.take(2), ['SL04;', 'SH09;']);
    });

    test('CW sets the nearest listed width, not one the radio rounds down', () {
      // FW takes an unlisted width as the next LOWER one: 950 Hz sent raw
      // would land at 600.
      receive(session, 'MD3;FW0500;IS 0600;EX04000006;');
      sink.sent.clear();
      session.setPassband(const Passband(-475, 475));
      expect(sink.sent, ['FW1000;', 'FW;', 'IS;', 'EX0400000;']);
    });

    test('AM and FM report none and ask nothing', () {
      receive(session, 'MD2;EX02800000;SL03;SH09;');
      sink.sent.clear();
      receive(session, 'MD5;');
      expect(sink.passbands.last, isNull);
      expect(sink.sent, isEmpty);
    });
  });
}

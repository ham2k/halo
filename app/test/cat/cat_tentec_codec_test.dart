// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Ten-Tec Orion command set as the Orion, Orion II and Eagle guides
// write it. Nothing here has met a radio; these pin the guides' own
// examples, so a change that drifts from them fails here before it fails
// on someone's bench.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/drivers/tentec_codec.dart';

const _eagle = TenTecDialect.eagle;
const _orion = TenTecDialect.orion;

void main() {
  group('commands', () {
    test('a frequency goes out as eight digits of Hz', () {
      // The Eagle's own example, and the form its eight-character field
      // takes: a MHz form with a decimal point runs past it.
      expect(tenTecSetFrequency('B', 1403000), '*BF01403000\r');
      expect(tenTecSetFrequency('A', 14074000), '*AF14074000\r');
      expect(tenTecSetFrequency('A', 0), isNull);
      expect(tenTecSetFrequency('A', 100000000), isNull, reason: 'nine digits would overrun the field');
    });

    test('each dialect offers only the modes it can be put in', () {
      // An Eagle turns lower CW into upper CW by itself, and has no FSK:
      // offering either would be offering a mode that does not land.
      expect(tenTecSetMode(_eagle, 'CW-R'), isNull);
      expect(tenTecSetMode(_eagle, 'RTTY'), isNull);
      expect(tenTecSetMode(_orion, 'CW-R'), '*RMM3\r');
      expect(tenTecSetMode(_orion, 'RTTY'), '*RMM6\r');
      expect(tenTecSetMode(_eagle, 'LSB'), '*RMM1\r');
    });

    test('values are clamped to what each radio takes, not sent to be refused', () {
      expect(tenTecSetFilterWidth(_orion, 9000), '*RMF6000\r');
      expect(tenTecSetFilterWidth(_eagle, 9000), '*RMF9000\r');
      expect(tenTecSetFilterWidth(_eagle, 20), '*RMF100\r');
      expect(tenTecSetPower(150), '*TP100\r');
      expect(tenTecSetKeyerSpeed(5), '*CS10\r');
    });

    test('CW characters are written as the Orion guide spells them', () {
      // Its commands are case-sensitive and its examples are lowercase.
      expect(tenTecCwCharacter('B'), '/b\r');
      expect(tenTecCwCharacter('5'), '/5\r');
      expect(tenTecCwCharacter('+'), '/+\r');
      // In the app's Morse table but not in the Orion's: what the radio does
      // with them is undocumented, so they never reach it.
      expect(tenTecCwCharacter('-'), isNull);
      expect(tenTecCwCharacter('@'), isNull);
      expect(tenTecCwText('cq-de @k'), 'cqde k');
    });

    test('a CW chunk is scheduled character by character on PARIS timing', () {
      // 20 WPM: a 60 ms dit. C (-.-.) is 11 dits, then the 3-dit gap: Q at
      // 14 dits. After Q (--.-, 13 dits) a space makes the gap 7: D at 34.
      final schedule = tenTecCwSchedule('CQ D', 20);
      expect(schedule, [(Duration.zero, '/c\r'), (const Duration(milliseconds: 840), '/q\r'), (const Duration(milliseconds: 2040), '/d\r')]);
    });
  });

  group('replies', () {
    test('frequencies and VFO assignments, from the guides\' examples', () {
      final freq = parseTenTecReply('@AF14200000', _eagle) as TenTecFrequency;
      expect((freq.vfo, freq.hz), ('A', 14200000));
      final kv = parseTenTecReply('@KVABA', _orion) as TenTecVfoAssignment;
      expect((kv.mainRx, kv.subRx, kv.tx), ('A', 'B', 'A'));
      final none = parseTenTecReply('@KVANN', _orion) as TenTecVfoAssignment;
      expect((none.subRx, none.tx), (null, null), reason: "the Orion's N is no VFO, not a VFO named N");
    });

    test('an Eagle answering lower CW is read as the CW it switched to', () {
      expect(_eagle.modeFor('3'), 'CW');
      expect(_orion.modeFor('3'), 'CW-R');
      expect(_orion.modeFor('6'), 'RTTY');
      expect(_eagle.modeFor('6'), isNull);
    });

    test('a refusal names its command on an Orion and nothing on an Eagle', () {
      expect((parseTenTecReply('Z!AF', _orion) as TenTecRefusal).command, 'AF');
      expect((parseTenTecReply('Z', _eagle) as TenTecRefusal).command, isNull);
    });

    test('the transmit meters read reflected power in each dialect\'s unit', () {
      // The Eagle's `R10` is "1.0 watt reflected" — tenths. Read as watts it
      // would be an SWR of 1.9 on a 99 W carrier, over the alert threshold.
      final eagle = parseTenTecReply('@STF99R10', _eagle) as TenTecTransmitting;
      expect(eagle.reflectedWatts, 1.0);
      expect(eagle.swr, closeTo(1.22, 0.01));
      // The Orion states watts, and its own SWR, which is taken as given.
      final orion = parseTenTecReply('@STF50R2S1.1', _orion) as TenTecTransmitting;
      expect((orion.forwardWatts, orion.reflectedWatts, orion.swr), (50, 2, 1.1));
    });

    test('the receive answer says the radio is receiving, with or without a sub reading', () {
      expect(parseTenTecReply('@SRM16', _eagle), isA<TenTecReceiving>());
      expect(parseTenTecReply('@SRM10S5', _orion), isA<TenTecReceiving>());
    });

    test('the version answer and the start banners name the radio', () {
      expect((parseTenTecReply('599 Ver 01.736', _eagle) as TenTecIdentity).text, '599 Ver 01.736');
      // Both banners lead with spaces; the Eagle's guide counts two.
      expect((parseTenTecReply('  EAGLE START', _eagle) as TenTecIdentity).text, 'EAGLE START');
      expect(parseTenTecReply(' ORION START', _orion), isA<TenTecIdentity>());
    });

    test('a malformed answer is unreadable, not a zero, and not silence', () {
      // Read as null, the question it answers would look unanswered.
      expect(parseTenTecReply('@AF', _eagle), isA<TenTecUnreadable>());
      expect(parseTenTecReply('@AF14.2', _eagle), isA<TenTecUnreadable>());
      expect(parseTenTecReply('@KVAX', _orion), isA<TenTecUnreadable>());
      expect(parseTenTecReply('@STFxxR1', _orion), isA<TenTecUnreadable>());
      // An answer to a query the driver never asks is nobody's business.
      expect(parseTenTecReply('@RMNA1', _orion), isNull);
    });

    test('no SWR comes from a reading that cannot have one', () {
      expect(tenTecSwr(0, 0), isNull);
      expect(tenTecSwr(10, 10), isNull);
      expect(tenTecSwr(100, 0), 1.0);
    });
  });
}

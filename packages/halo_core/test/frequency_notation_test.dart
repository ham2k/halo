// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Frequencies are written with periods for grouping and decimal alike —
// `14.285.5` — whatever the device's number conventions.
//
// The first trap is a frequency that follows the device after all: one
// surface wired to `NumberFormatting` shows `14.285,5` beside another's
// `14.285.5`, and the operator cannot tell which is right. Every group below
// that configures comma conventions exists to catch that.
//
// The second is the band-plan tie-break. With one mark doing two jobs, the
// same digits have up to three readings a thousandfold apart, and the wrong
// one puts the operator on a different band — the kind of wrong that reaches
// the air. Each reading is asserted where it must win AND where it must not.

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  tearDown(NumberFormatting.instance.reset);

  void useComma() => NumberFormatting.instance.configure(decimal: ',', grouping: '.', locale: 'es_ES');

  group('writing', () {
    test('periods for both marks', () {
      expect(fmtFreq(14285.5), '14.285.5');
      expect(fmtFreq(14074.25), '14.074.25');
      expect(fmtFreqToTheHz(14285.4), '14.285.400');
      expect(fmtFreq(1296000), '1296.000', reason: 'whole MHz past a GHz takes no mark of its own');
      expect(fmtFreq(10368100.5), '10368.100.5');
    });

    test('not the device conventions, on any device', () {
      for (final configure in [
        useComma,
        () => NumberFormatting.instance.configure(decimal: ',', grouping: ' ', locale: 'fr_FR'),
        () => NumberFormatting.instance.configure(decimal: '.', grouping: ',', locale: 'en_US'),
      ]) {
        configure();
        expect(fmtFreq(14285.5), '14.285.5');
        expect(fmtFreqInput(14074.25), '14074.25');
        expect(fmtFreq(1296000), '1296.000');
      }
    });
  });

  group('reading one mark', () {
    test('a comma reads as a period', () {
      // The only mark a comma-decimal phone keypad offers, and what US habit
      // types as grouping: both name the same frequency.
      expect(parseFreq('14,285'), 14285.0);
      expect(parseFreq('7,1'), 7100.0);
      expect(parseFreq('14285,5'), 14285.5);
    });

    test('and so on a comma-conventions device the period still is one', () {
      useComma();
      expect(parseFreq('14.285'), 14285.0, reason: '14.285 MHz, not the device grouping 14285 kHz');
      expect(parseFreq('14285.5'), 14285.5);
      expect(parseFreq('7.1'), 7100.0);
    });

    test('MHz wins whenever it names a band', () {
      // The ordinary case, and the one a reordered tie-break must not lose:
      // `146.52` read as GHz would be the 2mm band, were `bands` to grow it.
      expect(parseFreq('146.52'), 146520.0);
      expect(parseFreq('7.1'), 7100.0);
    });

    test('kHz rescues 2200m and 630m', () {
      expect(parseFreq('472.5'), 472.5);
      expect(parseFreq('136.5'), 136.5);
    });

    test('GHz rescues the microwave bands', () {
      expect(parseFreq('1.296'), closeTo(1296000.0, 1e-6));
      expect(parseFreq('1.3'), closeTo(1300000.0, 1e-6));
      expect(parseFreq('2.304'), closeTo(2304000.0, 1e-6));
      expect(parseFreq('10.368'), closeTo(10368000.0, 1e-6));
    });

    test('but never over an HF band', () {
      // 30m read as MHz sits inside 3cm read as GHz, and 3.5 is 80m.
      expect(parseFreq('10.125'), 10125.0);
      expect(parseFreq('3.5'), 3500.0);
    });

    test('from 1000, MHz rescues the microwave bands as the display writes them', () {
      // 23cm displays as `1296.000`; read as kHz it is 1296 kHz, no band.
      expect(parseFreq('1296.000'), 1296000.0);
      expect(parseFreq('1296,2'), closeTo(1296200.0, 1e-6));
      expect(parseFreq('10368.1'), closeTo(10368100.0, 1e-6));
      expect(parseFreq('14285.5'), 14285.5, reason: 'kHz still wins where it names a band');
      expect(parseFreq('10125.000'), 10125.0, reason: '30m, not 3cm');
    });

    test('but not over a bare band name', () {
      // 1.25 GHz is inside 23cm, and `1.25` is also the 1.25m band typed on
      // an iOS keypad. Read as a frequency it would shadow the band, because
      // the field tries a frequency first.
      expect(parseFreq('1.25'), 1250.0, reason: 'no band, so the band name gets its turn');
      expect(parseBandInput('1.25'), '1.25m');
      expect(parseFreq('1,25'), 1250.0);
      expect(parseBandInput('1,25'), '1.25m', reason: 'the same band from a comma-decimal keypad');
      expect(parseBandInput('2,190m'), '2190m', reason: 'and a comma can still be grouping');
    });

    test('MHz is the reading when none names a band', () {
      // 5 MHz is WWV, not an allocation — and neither 5 kHz nor 5 GHz is
      // anything. Someone typing a decimal into a frequency box means MHz.
      expect(parseFreq('5.0'), 5000.0);
    });

    test('a frequency survives the trip through an editable field', () {
      for (final configure in [NumberFormatting.instance.reset, useComma]) {
        configure();
        for (final khz in [472.5, 137.5, 1810.0, 7025.0, 14074.25, 21300.5, 50313.0, 1296000.0]) {
          expect(parseFreq(fmtFreqInput(khz)), khz, reason: '$khz did not round-trip');
        }
      }
    });
  });

  group('reading two or more marks', () {
    test('the last mark is the decimal: MHz.kHz.Hz below a GHz', () {
      expect(parseFreq('14.200.5'), 14200.5);
      expect(parseFreq('14.200.505'), 14200.505);
      expect(parseFreq('432.100.000'), 432100.0, reason: '70cm, read as MHz.kHz.Hz');
      expect(parseFreq('14,285.5'), 14285.5, reason: 'US grouping, typed out of habit');
    });

    test('every mark is grouping where only that names a band', () {
      // How kHz display writes 23cm. Read with a decimal it is 1296 kHz, which
      // is no band, so the grouped reading must win.
      expect(parseFreq('1.296.000'), 1296000.0);
      expect(parseFreq('10.368.100'), 10368100.0);
    });

    test('a first group past three digits is whole MHz, only in a microwave band', () {
      // How the display writes a microwave frequency with Hz.
      expect(parseFreq('10368.100.5'), closeTo(10368100.5, 1e-6));
      expect(parseFreq('1296.200.25'), closeTo(1296200.25, 1e-6));
    });

    test('a group that is not three digits is refused, not guessed at', () {
      // `14.2.5` has no reading that is a grouped number; joining the digits
      // would invent 142.5 kHz.
      expect(parseFreq('14.2.5'), isNull);
      expect(parseFreq('14.2850.5'), isNull);
      expect(parseFreq('.285.5'), isNull);
      expect(parseFreq('14.285.'), isNull);
      // A stray mark after a kHz entry: the grouped reading is about 14 GHz,
      // which the field would keep with no band and no complaint.
      expect(parseFreq('14285.200.5'), isNull);
    });

    test('what the display writes reads back as the same frequency', () {
      for (final khz in [7200.5, 14074.25, 14285.0, 146520.0, 1296000.0, 1296200.0, 2304100.5, 10368100.25, 24192000.0]) {
        expect(parseFreq(fmtFreq(khz)), khz, reason: '${fmtFreq(khz)} did not read back');
      }
    });
  });

  test('whitespace and junk', () {
    expect(parseFreq(' 14 285.5 '), 14285.5);
    expect(parseFreq('14 285.5'), 14285.5);
    expect(parseFreq(''), isNull);
    expect(parseFreq('abc'), isNull);
    expect(parseFreq('-5'), isNull);
    expect(parseFreq('0'), isNull);
  });
}

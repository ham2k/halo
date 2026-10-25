// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  const modes = [null, 'CW', 'SSB', 'USB', 'LSB', 'AM', 'FM', 'FT8', 'FT4', 'RTTY', 'DATA'];

  group('defaultFrequencyForBand', () {
    test('every default lies on the band it is the default for', () {
      // A default off its own band would move the radio to a different band
      // from the one picked, and the picked band would then never be reached.
      for (final band in bands) {
        for (final mode in modes) {
          for (final place in [(1, null), (2, 'us'), (3, null), (null, null)]) {
            final freq = defaultFrequencyForBand(band.name, mode, ituRegion: place.$1, countryCode: place.$2);
            expect(freq, isNotNull, reason: '${band.name} $mode');
            expect(bandForFrequency(freq!), band.name, reason: '${band.name} $mode $place → $freq');
          }
        }
      }
    });

    test('a US operator starts where a General licence does, not an Extra', () {
      // The band plan's US segments are the Extra class's: 14150 on 20m phone
      // is outside a General's privileges.
      expect(defaultFrequencyForBand('20m', 'USB', ituRegion: 2, countryCode: 'us'), 14225);
      expect(defaultFrequencyForBand('20m', 'CW', ituRegion: 2, countryCode: 'us'), 14025.1);
      expect(defaultFrequencyForBand('15m', 'USB', ituRegion: 2, countryCode: 'us'), 21275);
    });

    test('a US territory is placed by the US plan, not its region\'s', () {
      // A KP4 or KH2 holds an FCC licence: the region's 40m phone start is
      // below even an Extra's edge.
      expect(defaultFrequencyForBand('40m', 'LSB', ituRegion: 2, countryCode: 'pr'), 7178);
      expect(defaultFrequencyForBand('20m', 'USB', ituRegion: 3, countryCode: 'gu'), 14225);
      expect(defaultFrequencyForBand('40m', 'RTTY', ituRegion: 2, countryCode: 'vi'), 7080);
    });

    test('lower-sideband phone starts far enough in for the sideband to fit', () {
      // At 7175 exactly, LSB occupies 7172-7175: below a General's edge.
      expect(defaultFrequencyForBand('40m', 'LSB', ituRegion: 2, countryCode: 'us'), 7178);
      expect(defaultFrequencyForBand('80m', 'LSB', ituRegion: 2, countryCode: 'us'), 3803);
    });

    test('CW starts far enough in not to straddle the segment edge', () {
      // On the edge itself, half the signal is outside the segment — at
      // 7000, outside the band.
      expect(defaultFrequencyForBand('40m', 'CW', ituRegion: 1), 7000.1);
      expect(defaultFrequencyForBand('40m', 'CW', ituRegion: 2, countryCode: 'us'), 7025.1);
    });

    test('elsewhere, the start of the segment in the operator\'s own region', () {
      expect(defaultFrequencyForBand('40m', 'LSB', ituRegion: 1), 7063);
      expect(defaultFrequencyForBand('20m', 'USB', ituRegion: 1), 14112);
    });

    test('every default is inside the operator\'s allocation', () {
      // A default from another region's plan puts the transmitter out of
      // band: Region 2's 146.520 is out of band in Region 1.
      for (final region in [1, 2, 3]) {
        for (final band in bands) {
          for (final mode in ['CW', 'USB', 'LSB', 'FM', 'RTTY', 'FT8']) {
            final freq = defaultFrequencyForBand(band.name, mode, ituRegion: region)!;
            expect(isOutOfBandFrequency(freq, ituRegion: region), isFalse, reason: 'R$region ${band.name} $mode → $freq');
          }
        }
      }
    });

    test('a digital mode lands on its dial frequency', () {
      // Anywhere else on the band an FT8 operator hears nobody.
      expect(defaultFrequencyForBand('20m', 'FT8'), 14074);
      expect(defaultFrequencyForBand('40m', 'FT8', ituRegion: 2, countryCode: 'us'), 7074);
      expect(defaultFrequencyForBand('20m', 'FT4'), 14080);
      expect(defaultFrequencyForBand('6m', 'DATA-USB'), 50313);
    });

    test('a band whose plan has no phone segment starts phone at CW\'s start', () {
      expect(defaultFrequencyForBand('30m', 'USB'), 10100);
    });

    test('FM goes to the calling frequency of the operator\'s own region', () {
      expect(defaultFrequencyForBand('2m', 'FM', ituRegion: 2), 146520);
      expect(defaultFrequencyForBand('2m', 'FM', ituRegion: 1), 145500);
      expect(defaultFrequencyForBand('70cm', 'FM', ituRegion: 1), 433500);
      expect(defaultFrequencyForBand('2m', 'FM', ituRegion: 3), 145000, reason: 'much of Region 3 stops at 146 MHz');
      expect(defaultFrequencyForBand('10m', 'FM', ituRegion: 1), 29600);
    });

    test('from 6m up, a band starts where people call, not at a segment edge', () {
      expect(defaultFrequencyForBand('2m', 'USB', ituRegion: 2), 144200);
      expect(defaultFrequencyForBand('2m', 'USB', ituRegion: 1), 144300);
      expect(defaultFrequencyForBand('2m', 'CW', ituRegion: 1), 144050);
      expect(defaultFrequencyForBand('6m', 'USB', ituRegion: 2, countryCode: 'us'), 50125);
      expect(defaultFrequencyForBand('23cm', 'USB', ituRegion: 1), 1296200);
    });

    test('every band the app names has a default, the microwave bands included', () {
      for (final band in extendedBands.where((b) => b != 'other')) {
        expect(defaultFrequencyForBand(band, 'USB'), isNotNull, reason: band);
      }
      expect(defaultFrequencyForBand('13cm', 'USB', ituRegion: 1), 2320200);
      expect(defaultFrequencyForBand('13cm', 'USB', ituRegion: 2), 2304100);
      expect(defaultFrequencyForBand('3cm', 'CW'), 10368100);
      expect(defaultFrequencyForBand('2190m', 'CW'), 135.8, reason: 'to the Hz, not 135.79999');
    });

    test('60m is channels: the US ones in Region 2, WRC-15\'s elsewhere', () {
      // The US channels are outside the allocation most of Regions 1 and 3
      // have.
      expect(defaultFrequencyForBand('60m', 'USB', ituRegion: 2), 5330.5);
      expect(defaultFrequencyForBand('60m', 'CW', ituRegion: 2), 5332);
      expect(defaultFrequencyForBand('60m', 'USB', ituRegion: 1), 5354);
      expect(defaultFrequencyForBand('60m', 'CW', ituRegion: 3), 5351.6);
    });

    test('RTTY goes to its own segment, not the phone one', () {
      expect(defaultFrequencyForBand('20m', 'RTTY', ituRegion: 2, countryCode: 'us'), 14070);
      expect(defaultFrequencyForBand('40m', 'RTTY', ituRegion: 2, countryCode: 'us'), 7080);
      expect(defaultFrequencyForBand('40m', 'RTTY', ituRegion: 1), 7074, reason: 'no RTTY segment: where FT8 is');
    });

    test('a default on a segment edge is checked from inside the allocation', () {
      // The allocation test above reads an edge as inside: 1800 is the start
      // of 160m's worldwide RTTY segment and the end of Region 1's gap.
      expect(defaultFrequencyForBand('160m', 'RTTY', ituRegion: 1), isNot(1800));
      expect(defaultFrequencyForBand('160m', 'RTTY', ituRegion: 2), 1800);
      // No phone segment on 630m: from its edge the sideband would be below
      // the band.
      expect(defaultFrequencyForBand('630m', 'LSB'), 475);
    });

    test('an unknown band has none', () {
      expect(defaultFrequencyForBand('nope', 'CW'), isNull);
    });
  });

  group('bandModeFamily', () {
    test('a radio\'s report and the app\'s mode for it land in the same family', () {
      // The memory is written from the radio's reports and read under the
      // app's mode; FT8 must find what DATA-USB left.
      expect(bandModeFamily('FT8'), bandModeFamily('DATA-USB'));
      expect(bandModeFamily('CW'), bandModeFamily('CW-R'));
      expect(bandModeFamily('SSB'), bandModeFamily('LSB'));
    });

    test('RTTY is remembered apart from phone', () {
      // Shared, a 20m pick in USB would return to the RTTY frequency.
      expect(bandModeFamily('RTTY'), isNot(bandModeFamily('USB')));
      expect(bandModeFamily('RTTY'), isNot(bandModeFamily('FT8')));
    });

    test('a radio\'s own spelling of a mode is in that mode\'s family', () {
      // The app's mode keeps what the radio reported: a Yaesu's RTTY-LSB
      // read as phone would remember RTTY's frequency for SSB.
      for (final mode in ['RTTY-LSB', 'RTTY-USB', 'RTTY-R']) {
        expect(bandModeFamily(mode), 'RTTY', reason: mode);
      }
      expect(bandModeFamily('FM-N'), 'FM');
      expect(bandModeFamily('DATA-FM'), 'DATA');
    });

    test('the families are apart', () {
      expect({
        for (final m in ['CW', 'USB', 'FM', 'FT8', 'RTTY']) bandModeFamily(m),
      }, hasLength(5));
      expect(bandModeFamily(null), 'PHONE');
    });
  });
}

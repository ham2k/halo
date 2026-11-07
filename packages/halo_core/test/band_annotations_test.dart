// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An annotation taken in part would be drawn as something it does not say,
// so each is read whole or refused; and a source holds what it put by key,
// so putting one again moves it rather than drawing it twice.

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  group('bandAnnotationFrom', () {
    test('finds its band from its frequencies, and sets its importance', () {
      expect(bandAnnotationFrom({'type': 'edge', 'fromHz': 14000000, 'toHz': 14350000}), {
        'type': 'edge',
        'fromHz': 14000000,
        'toHz': 14350000,
        'band': '20m',
        'importance': 'primary',
      });
      // A stretch reaching into a band from outside it is on that band.
      expect(bandAnnotationFrom({'type': 'plan', 'fromHz': 13990000, 'toHz': 14010000})['band'], '20m');
      expect(bandAnnotationFrom({'type': 'general', 'fromHz': 13000000, 'band': '20M'})['band'], '20m');
    });

    test('refuses what it cannot read whole', () {
      for (final bad in <Object?>[
        'edge',
        {'fromHz': 14000000},
        {'type': 'zone', 'fromHz': 14000000},
        {'type': 'edge'},
        {'type': 'edge', 'fromHz': -1},
        {'type': 'edge', 'fromHz': 14100000, 'toHz': 14000000},
        {'type': 'edge', 'fromHz': 14000000, 'importance': 'urgent'},
        {'type': 'edge', 'fromHz': 14000000, 'label': 7},
        {'type': 'edge', 'fromHz': 14000000, 'expiresAt': 'tomorrow'},
        {'type': 'edge', 'fromHz': 14000000, 'shade': 'blue'},
        // A color the scene cannot read fails the whole picture, not just this one.
        {'type': 'edge', 'fromHz': 14000000, 'color': 'red'},
        {'type': 'edge', 'fromHz': 14000000, 'color': '#f00'},
        // Nowhere on a band, and none named.
        {'type': 'general', 'fromHz': 13000000},
      ]) {
        expect(() => bandAnnotationFrom(bad), throwsFormatException, reason: '$bad');
      }
    });
  });

  group('BandAnnotationStore', () {
    test('a key put again replaces it; one put without a key is only ever added', () {
      final store = BandAnnotationStore()
        ..put('a', [
          {'type': 'general', 'key': 'net', 'fromHz': 14300000, 'label': 'Net'},
          {'type': 'general', 'fromHz': 14310000, 'label': 'Loose'},
        ])
        ..put('a', [
          {'type': 'general', 'key': 'net', 'fromHz': 14305000, 'label': 'Net'},
          {'type': 'general', 'fromHz': 14310000, 'label': 'Loose'},
        ]);
      expect(store.forBand('20m', now: 0).map((a) => (a['label'], a['fromHz'])), [('Net', 14305000), ('Loose', 14310000), ('Loose', 14310000)]);
    });

    test('all of a put or none of it, and no more than a source may hold', () {
      final store = BandAnnotationStore();
      expect(
        () => store.put('a', [
          {'type': 'general', 'fromHz': 14300000},
          {'type': 'general'},
        ]),
        throwsFormatException,
      );
      expect(store.forBand('20m', now: 0), isEmpty);
      final many = [
        for (var i = 0; i <= maxBandAnnotationsPerSource; i++) {'type': 'general', 'key': '$i', 'fromHz': 14000000 + i},
      ];
      expect(() => store.put('a', many), throwsFormatException);
      expect(store.forBand('20m', now: 0), isEmpty);
    });

    test('an expired one is gone, and the next to expire is known', () {
      final store = BandAnnotationStore()
        ..put('a', [
          {'type': 'general', 'fromHz': 14300000, 'expiresAt': 100},
          {'type': 'general', 'fromHz': 14310000, 'expiresAt': 200},
          {'type': 'general', 'fromHz': 14320000},
        ]);
      expect(store.nextExpiry, 100);
      expect(store.forBand('20m', now: 100), hasLength(2), reason: 'expired at the moment it expires');
      expect(store.nextExpiry, 200);
    });
  });
}

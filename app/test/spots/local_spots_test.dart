// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Spots this device makes from the station being worked: what a draft turns
// into, and which spots one replaces on the board
// (docs/design/logging-fields.md § Local spots).

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/local_spots.dart';
import 'package:ham2k_logger/services/spot_board.dart' show mergedSpotBoard, spotOperatorCalls;
import 'package:ham2k_logger/services/spots_service.dart';
import 'package:ham2k_logger/services/spotting_settings.dart';

import '../support/halo_harness.dart';

Map<String, dynamic> draft(String call, {double freq = 14250, String mode = 'SSB', List<Map<String, dynamic>> refs = const []}) => {
  'their': {'call': call},
  'freq': freq,
  'band': bandForFrequency(freq),
  'mode': mode,
  'refs': refs,
};

Map<String, dynamic> fetched(String call, {double freq = 14250, String mode = 'SSB', int ageMinutes = 5, String source = 'pota'}) => {
  'their': {'call': call},
  'freq': freq,
  'band': bandForFrequency(freq),
  'mode': mode,
  'hookKey': source,
  'spot': {'timeInMillis': nowMillis() - Duration(minutes: ageMinutes).inMilliseconds, 'source': source},
};

Map<String, dynamic> local(String call, {double freq = 14250, String mode = 'SSB'}) => localSpotFromQso(
  draft(call, freq: freq, mode: mode),
  now: nowMillis(),
)!;

SpotsFetch feed(List<Map<String, dynamic>> spots) =>
    () async =>
        (items: spots, succeeded: {for (final spot in spots) spot['hookKey'] as String}.toList(), unreachable: const <String>[], failed: const <String>[]);

List<String> callsOn(SpotsService service, String source) => [
  for (final spot in service.spotsBySource[source] ?? const <Map<String, dynamic>>[]) callOfSpot(spot)!,
];

void main() {
  group('localSpotFromQso', () {
    test('carries the call, where it was heard, and the references it names', () {
      final spot = localSpotFromQso(
        draft(
          'w1aw',
          refs: [
            {'type': 'pota', 'ref': 'US-0001'},
          ],
        ),
        now: 1000,
      )!;
      expect(callOfSpot(spot), 'W1AW');
      expect(spot['freq'], 14250);
      expect(spot['band'], '20m');
      expect(spot['hookKey'], localSpotSource);
      expect(timeOfSpot(spot), 1000);
      expect(spot['refs'], [
        {'type': 'pota', 'ref': 'US-0001'},
      ]);
    });

    test("a contest's received exchange becomes the label, not a reference", () {
      // Exchange values ride the refs with no `ref` of their own; as spot refs
      // they would read as an activity reference nobody can look up.
      final spot = localSpotFromQso(
        draft(
          'W1AW',
          refs: [
            {'type': 'nyqp', 'location': 'NY'},
          ],
        ),
        now: 1000,
      )!;
      expect(spot.containsKey('refs'), isFalse);
      expect((spot['spot'] as Map)['label'], 'NY');
    });

    test('makes no spot without a callsign, a frequency, or in a digital mode', () {
      expect(localSpotFromQso(draft('W1'), now: 0), isNull);
      expect(localSpotFromQso({...draft('W1AW')}..remove('freq'), now: 0), isNull);
      // Every FT8 station on the band shares the dial frequency.
      expect(localSpotFromQso(draft('W1AW', mode: 'FT8'), now: 0), isNull);
      expect(localSpotFromQso(draft('W1AW', mode: 'CW'), now: 0), isNotNull);
    });
  });

  group('incomplete calls', () {
    test('a call not fully copied is spotted: someone is there', () {
      expect(callOfSpot(localSpotFromQso(draft('W1A?'), now: 0)!), 'W1A?');
      expect(localSpotFromQso(draft('W1A?', mode: 'FT8'), now: 0), isNull, reason: 'still a station, so still not in digital');
      expect(localSpotFromQso(draft('QRM'), now: 0), isNull, reason: 'text that is no callsign is not spotted');
    });

    test('isLocalSpotWithoutStation: the local spots whose call is no callsign', () {
      expect(isLocalSpotWithoutStation(localSpotFromQso(draft('W1A?'), now: 0)!), isTrue);
      expect(isLocalSpotWithoutStation(local('W1AW')), isFalse);
      // A network spot's call is the network's to vouch for.
      expect(isLocalSpotWithoutStation(fetched('W1A?')), isFalse);
    });

    test('a call stack or list is never one spot, a call not fully copied in it included', () {
      for (final text in ['K1ABC//W1A?', 'W1AW,K1A?']) {
        expect(localSpotFromQso(draft(text), now: 0), isNull, reason: text);
      }
    });

    test('calls not fully copied replace by frequency only, never by their text', () {
      Map<String, dynamic> older(Map<String, dynamic> spot) => {
        ...spot,
        'spot': {...spot['spot'] as Map, 'timeInMillis': nowMillis() - 60000},
      };
      // Two stations both copied as W1A? are two places on the band.
      expect(localSpotReplaces(local('W1A?'), older(local('W1A?', freq: 14200))), isFalse);
    });

    test('name no operator: nothing reads their text as a callsign', () {
      expect(spotOperatorCalls(local('W1A?')), isEmpty);
      expect(spotOperatorCalls(local('W1AW')), ['W1AW']);
    });

    test('on the board, never merged with a spot by their text', () {
      // Each within the call-merge pass's 0.5 kHz, beyond a signal's width.
      final board = mergedSpotBoard(
        {
          localSpotSource: [local('W1A?', freq: 14200.0), local('W1A?', freq: 14200.3)],
          'pota': [fetched('W1AW', freq: 14230.3)],
        },
        const {},
        entityOf: (_) => 'K',
      );
      expect(board, hasLength(3), reason: 'two stations copied as W1A? are two places');
    });
  });

  group('band tags', () {
    test('a tag marks the band where the radio is, as the operator\'s own annotation, for as long as a local spot stands', () {
      final service = SpotsService(fetchSpots: feed(const []));
      addTearDown(service.dispose);
      expect(putBandTag(service, ' QRM ', {'freq': 14285.0, 'band': '20m', 'mode': 'SSB'}, enabled: true), isTrue);
      final [tag] = service.bandAnnotations.forBand('20m');
      expect(tag, containsPair('type', 'general'));
      expect(tag, containsPair('fromHz', 14285000));
      expect(tag, containsPair('label', 'QRM'));
      expect(tag, containsPair('source', userBandAnnotationSource));
      expect(tag['expiresAt'] as int, closeTo(nowMillis() + SpotsService.maxSpotAge.inMilliseconds, 1000));
      // A place on the band, not a station: nothing on the Spots list, and no spot it hides.
      expect(service.spotsBySource, isEmpty);
    });

    test('a tag in a digital mode, or two of one text, are each their own', () {
      final service = SpotsService(fetchSpots: feed(const []));
      addTearDown(service.dispose);
      putBandTag(service, 'QRM', {'freq': 14074.0, 'band': '20m', 'mode': 'FT8'}, enabled: true);
      putBandTag(service, 'QRM', {'freq': 14074.0, 'band': '20m', 'mode': 'FT8'}, enabled: true);
      expect(service.bandAnnotations.forBand('20m'), hasLength(2));
    });

    test('none with the local spots off, or nowhere on a band', () {
      final service = SpotsService(fetchSpots: feed(const []));
      addTearDown(service.dispose);
      expect(putBandTag(service, 'QRM', {'freq': 14285.0, 'band': '20m'}, enabled: false), isFalse);
      expect(putBandTag(service, 'QRM', {'freq': 13000.0}, enabled: true), isFalse);
      expect(service.bandAnnotations.forBand('20m'), isEmpty);
    });
  });

  group('localSpotReplaces', () {
    test('a voice within 100 Hz, a CW note within 20 Hz', () {
      expect(localSpotReplaces(local('W1AW'), fetched('K2ABC', freq: 14250.1)), isTrue);
      expect(localSpotReplaces(local('W1AW'), fetched('K2ABC', freq: 14250.2)), isFalse);
      expect(localSpotReplaces(local('W1AW', freq: 14030, mode: 'CW'), fetched('K2ABC', freq: 14030.02, mode: 'CW')), isTrue);
      // 50 Hz is inside the phone window, so this fails if CW is held to it.
      expect(localSpotReplaces(local('W1AW', freq: 14030, mode: 'CW'), fetched('K2ABC', freq: 14030.05, mode: 'CW')), isFalse);
    });

    test('the same station anywhere on the band and mode, but not on another band or mode', () {
      expect(localSpotReplaces(local('W1AW'), fetched('W1AW', freq: 14320)), isTrue);
      expect(localSpotReplaces(local('W1AW'), fetched('W1AW', freq: 7200)), isFalse);
      expect(localSpotReplaces(local('W1AW'), fetched('W1AW', mode: 'CW')), isFalse);
      // USB and SSB are one family: the same voice, spelled by another source.
      expect(localSpotReplaces(local('W1AW'), fetched('W1AW', freq: 14320, mode: 'USB')), isTrue);
    });

    test('never a spot posted after it', () {
      // Someone else on that frequency since, or the station back again, is
      // news the local spot cannot speak for.
      expect(localSpotReplaces(local('W1AW'), fetched('K2ABC', ageMinutes: -1)), isFalse);
    });
  });

  group('withoutReplacedSpots', () {
    List<String> calls(List<Map<String, dynamic>> spots) => [for (final spot in spots) callOfSpot(spot)!];

    test('a newer local spot hides an older one on its frequency, and the older one is still held', () {
      final older = {
        ...local('W1AW'),
        'spot': {'timeInMillis': nowMillis() - 60000, 'source': localSpotSource},
      };
      expect(calls(withoutReplacedSpots([older, local('K2ABC', freq: 14250.05)])), ['K2ABC'], reason: 'K2ABC is who is on 14250 now');
      // A tie at one millisecond must not hide both.
      expect(calls(withoutReplacedSpots([local('W1AW'), local('W1AW', freq: 14300)])), hasLength(1));
    });

    test('agrees with each spot asked against each local spot', () {
      // The index narrows by band, mode, call and frequency before asking;
      // a bound off by a window, or a bucket keyed apart from what
      // localSpotReplaces compares, shows here as a spot kept or hidden wrongly.
      // Tags, some reading as callsigns, and calls not fully copied replace by
      // frequency alone, which the index's call bucket must leave to the scan.
      final random = Random(7);
      final calls = ['W1AW', 'K2ABC', 'N3XYZ', 'W1AW,K2ABC', 'VE3ABC', 'G4ABC', 'W1A?', 'Q65'];
      final freqs = [14030.0, 14030.015, 14030.025, 14250.0, 14250.09, 14250.11, 14300.0, 7200.0, 7200.05];
      final modes = ['SSB', 'USB', 'CW', 'FT8'];
      Map<String, dynamic> pick(String source) {
        final freq = freqs[random.nextInt(freqs.length)];
        return {
          'their': {'call': calls[random.nextInt(calls.length)]},
          'freq': freq,
          'band': bandForFrequency(freq),
          'mode': modes[random.nextInt(modes.length)],
          'hookKey': source,
          'spot': {'timeInMillis': 1000 + random.nextInt(20) * 1000, 'source': source, if (source == localSpotSource && random.nextBool()) 'tag': true},
        };
      }

      for (var round = 0; round < 50; round++) {
        final spots = [for (var i = 0; i < 40; i++) pick(i.isEven ? 'pota' : localSpotSource)];
        final locals = spots.where((s) => s['hookKey'] == localSpotSource).toList()..sort((a, b) => (timeOfSpot(b) ?? 0).compareTo(timeOfSpot(a) ?? 0));
        final kept = <Map<String, dynamic>>[];
        for (final l in locals) {
          if (!kept.any((k) => localSpotReplaces(k, l))) kept.add(l);
        }
        final expected = [
          for (final spot in spots)
            if (spot['hookKey'] == localSpotSource ? kept.any((k) => identical(k, spot)) : !kept.any((k) => localSpotReplaces(k, spot))) spot,
        ];
        expect(withoutReplacedSpots(spots), orderedEquals(expected), reason: 'round $round');
      }
    });
  });

  group('the board', () {
    List<String> board(SpotsService service, {Set<String> disabled = const {}}) => [
      for (final spot in mergedSpotBoard(service.spotsBySource, disabled, entityOf: (_) => null)) callOfSpot(spot)!,
    ];

    test('a local spot hides what it replaces, which comes back when it goes, and is never deleted', () async {
      final service = SpotsService(fetchSpots: feed([fetched('K2ABC'), fetched('W1AW', freq: 14300), fetched('N3XYZ', freq: 14280)]));
      addTearDown(service.dispose);
      await service.refresh();

      service.putLocalSpot('a', local('W1AW'));
      expect(board(service), unorderedEquals(['W1AW', 'N3XYZ']));
      // Held, so the lookup still finds the park K2ABC was spotted at.
      expect(callsOn(service, 'pota'), hasLength(3));
      expect(service.spotsForCall('K2ABC', maxAge: const Duration(hours: 1)), hasLength(1));

      service.removeLocalSpot('a');
      expect(board(service), unorderedEquals(['K2ABC', 'W1AW', 'N3XYZ']));
    });

    test('with the local source switched off, what it replaced is the board', () async {
      // Replaced before the source filter, the station would vanish from both.
      final service = SpotsService(fetchSpots: feed([fetched('K2ABC')]));
      addTearDown(service.dispose);
      await service.refresh();
      service.putLocalSpot('a', local('W1AW'));

      expect(board(service, disabled: {localSpotSource}), ['K2ABC']);
    });

    test('a busted call taken back brings back the local spot it replaced', () {
      final service = SpotsService(fetchSpots: feed(const []));
      addTearDown(service.dispose);
      service.putLocalSpot('a', {
        ...local('W1AW'),
        'spot': {'timeInMillis': nowMillis() - 60000, 'source': localSpotSource},
      });
      service.putLocalSpot('b', local('W1AX', freq: 14250.05));
      expect(board(service), ['W1AX']);

      service.removeLocalSpot('b');
      expect(board(service), ['W1AW']);
    });

    test('local spots outlive a refresh, which no source answers for', () async {
      final service = SpotsService(fetchSpots: feed([fetched('K2ABC', freq: 7200, mode: 'CW')]));
      addTearDown(service.dispose);
      service.putLocalSpot('a', local('W1AW'));

      await service.refresh();
      expect(callsOn(service, localSpotSource), ['W1AW']);
      expect(callsOn(service, 'pota'), ['K2ABC']);
    });

    test('a spot that only moved in time tells no one, and anything else does', () {
      // Every keystroke in the draft's other fields re-sends the same spot;
      // each notice repaints the board and judges it all again.
      final service = SpotsService(fetchSpots: feed(const []));
      addTearDown(service.dispose);
      var notices = 0;
      service.addListener(() => notices++);

      service.putLocalSpot('a', localSpotFromQso(draft('W1AW'), now: 1000)!);
      service.putLocalSpot('a', localSpotFromQso(draft('W1AW'), now: 2000)!);
      expect(notices, 1);
      expect(timeOfSpot(service.spotsBySource[localSpotSource]!.single), 2000);

      service.putLocalSpot('a', localSpotFromQso(draft('W1AX'), now: 3000)!);
      expect(notices, 2);
    });

    test('clearLocalSpotsAt takes down every local spot and band tag within a signal of the radio, those hidden included', () {
      final service = SpotsService(fetchSpots: feed(const []));
      addTearDown(service.dispose);
      service.putLocalSpot('hidden', {
        ...local('W1AW'),
        'spot': {'timeInMillis': nowMillis() - 60000, 'source': localSpotSource},
      });
      service.putLocalSpot('away', local('K2ABC', freq: 14300));
      service.putLocalSpot('cw', local('N3XYZ', freq: 14250.02, mode: 'CW'));
      putBandTag(service, 'QRM', {'freq': 14250.05, 'band': '20m', 'mode': 'FT8'}, enabled: true);
      putBandTag(service, 'NET', {'freq': 14300.0, 'band': '20m', 'mode': 'SSB'}, enabled: true);

      clearLocalSpotsAt(service, {'freq': 14250.0, 'band': null, 'mode': 'USB'});

      // Taking only the newest would bring W1AW back from under it.
      expect(callsOn(service, localSpotSource), unorderedEquals(['K2ABC', 'N3XYZ']));
      // A tag within a voice's width goes too, whatever mode it was tagged in.
      expect(service.bandAnnotations.forBand('20m').map((a) => a['label']), ['NET']);
    });

    test('clearLocalSpots takes every local spot down', () {
      final service = SpotsService(fetchSpots: feed(const []));
      addTearDown(service.dispose);
      service.putLocalSpot('a', local('W1AW'));
      service.putLocalSpot('b', local('K2ABC', freq: 7200));

      service.clearLocalSpots();
      expect(service.spotsBySource.containsKey(localSpotSource), isFalse);
    });
  });

  test('turning Local Spots off takes down the ones already up, however it is turned off', () async {
    // Left up, they would hide what they replace until they age out.
    final h = await makeHaLoServices();
    final spots = h.services.spots;
    spots.putLocalSpot('a', local('W1AW'));

    await h.settings.setSettingValue(SpottingSettings.group, SpottingSettings.localSpotsKey, true);
    expect(callsOn(spots, localSpotSource), ['W1AW']);
    await h.settings.setSettingValue(SpottingSettings.group, SpottingSettings.localSpotsKey, false);
    expect(spots.spotsBySource.containsKey(localSpotSource), isFalse);
  });
}

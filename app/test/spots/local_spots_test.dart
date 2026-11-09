// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Spots this device makes from the station being worked: what a draft turns
// into, and what one does to the spots on the board — another local one it
// replaces, another station's it hides, its own station's it takes in
// (docs/design/logging-fields.md § Local spots).

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/local_spots.dart';
import 'package:collection/collection.dart';
import 'package:ham2k_logger/services/spot_board.dart' show mergedSpotBoard, spotCallsIn, spotOperatorCalls;
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

Map<String, dynamic> fetched(
  String call, {
  double freq = 14250,
  String? mode = 'SSB',
  int ageMinutes = 5,
  String source = 'pota',
  List<Map<String, dynamic>>? refs,
  String? label,
}) => {
  'their': {'call': call},
  'freq': freq,
  'band': bandForFrequency(freq),
  'mode': ?mode,
  'refs': ?refs,
  'hookKey': source,
  'spot': {'timeInMillis': nowMillis() - Duration(minutes: ageMinutes).inMilliseconds, 'source': source, 'label': ?label},
};

Map<String, dynamic> local(String call, {double freq = 14250, String mode = 'SSB', List<Map<String, dynamic>> refs = const [], int ageMinutes = 0}) =>
    localSpotFromQso(
      draft(call, freq: freq, mode: mode, refs: refs),
      now: nowMillis() - Duration(minutes: ageMinutes).inMilliseconds,
    )!;

const park = {'type': 'potaHunter', 'ref': 'US-1131'};
const parkLine = 'US-1131: CA • Bothe-Napa Valley State Park';

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

  group('localSpotReplaces, between local spots', () {
    test('a voice within 100 Hz, a CW note within 20 Hz', () {
      expect(localSpotReplaces(local('W1AW'), local('K2ABC', freq: 14250.1, ageMinutes: 5)), isTrue);
      expect(localSpotReplaces(local('W1AW'), local('K2ABC', freq: 14250.2, ageMinutes: 5)), isFalse);
      expect(localSpotReplaces(local('W1AW', freq: 14030, mode: 'CW'), local('K2ABC', freq: 14030.02, mode: 'CW', ageMinutes: 5)), isTrue);
      // 50 Hz is inside the phone window, so this fails if CW is held to it.
      expect(localSpotReplaces(local('W1AW', freq: 14030, mode: 'CW'), local('K2ABC', freq: 14030.05, mode: 'CW', ageMinutes: 5)), isFalse);
    });

    test('the same station anywhere on the band and mode, but not on another band or mode', () {
      expect(localSpotReplaces(local('W1AW'), local('W1AW', freq: 14320, ageMinutes: 5)), isTrue);
      expect(localSpotReplaces(local('W1AW'), local('W1AW', freq: 7200, ageMinutes: 5)), isFalse);
      expect(localSpotReplaces(local('W1AW'), local('W1AW', mode: 'CW', ageMinutes: 5)), isFalse);
      // USB and SSB are one family: the same voice, spelled another way.
      expect(localSpotReplaces(local('W1AW'), local('W1AW', freq: 14320, mode: 'USB', ageMinutes: 5)), isTrue);
    });

    test('never one posted after it', () {
      expect(localSpotReplaces(local('W1AW', ageMinutes: 5), local('K2ABC')), isFalse);
    });
  });

  group('localSpotHides, a spot from another source', () {
    test('another station within a signal of it, posted no later', () {
      expect(localSpotHides(local('W1AW'), fetched('K2ABC', freq: 14250.1)), isTrue);
      expect(localSpotHides(local('W1AW'), fetched('K2ABC', freq: 14250.2)), isFalse);
      expect(localSpotHides(local('W1AW', freq: 14030, mode: 'CW'), fetched('K2ABC', freq: 14030.05, mode: 'CW')), isFalse);
      // Someone else on that frequency since is news the local spot cannot speak for.
      expect(localSpotHides(local('W1AW'), fetched('K2ABC', ageMinutes: -1)), isFalse);
    });

    test('never its own station, anywhere: that one is taken in', () {
      // Hidden, the network's park and status for the station would be gone
      // from the board while the operator is working it.
      expect(localSpotHides(local('W1AW'), fetched('W1AW')), isFalse);
      expect(localSpotHides(local('W1AW'), fetched('W1AW', freq: 14320)), isFalse);
      expect(localSpotSameStation(local('W1AW'), fetched('W1AW', freq: 14320, mode: 'USB')), isTrue);
      expect(localSpotSameStation(local('W1AW'), fetched('W1AW', freq: 7200)), isFalse);
      expect(localSpotSameStation(local('W1AW'), fetched('W1AW', mode: 'CW')), isFalse);
    });
  });

  group('withLocalSpots', () {
    List<String> calls(List<Map<String, dynamic>> spots) => [for (final spot in spots) callOfSpot(spot)!];

    test('a newer local spot hides an older one on its frequency, and the older one is still held', () {
      final older = {
        ...local('W1AW'),
        'spot': {'timeInMillis': nowMillis() - 60000, 'source': localSpotSource},
      };
      expect(calls(withLocalSpots([older, local('K2ABC', freq: 14250.05)])), ['K2ABC'], reason: 'K2ABC is who is on 14250 now');
      // A tie at one millisecond must not hide both.
      expect(calls(withLocalSpots([local('W1AW'), local('W1AW', freq: 14300)])), hasLength(1));
    });

    test('agrees with each spot asked against each local spot', () {
      // The index narrows by band, mode, call and frequency before asking;
      // a bound off by a window, or a bucket keyed apart from what the
      // predicates compare, shows here as a spot kept, hidden or taken in wrongly.
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
          if (random.nextBool())
            'refs': [
              {'type': 'potaHunter', 'ref': 'US-${random.nextInt(3)}'},
            ],
          'hookKey': source,
          // Minutes apart, some past the merge window either way.
          'spot': {'timeInMillis': 1000 + random.nextInt(20) * 3 * 60000, 'source': source, if (source == localSpotSource && random.nextBool()) 'tag': true},
        };
      }

      for (var round = 0; round < 50; round++) {
        final spots = [for (var i = 0; i < 40; i++) pick(i.isEven ? 'pota' : localSpotSource)];
        final locals = spots.where((s) => s['hookKey'] == localSpotSource).toList()..sort((a, b) => (timeOfSpot(b) ?? 0).compareTo(timeOfSpot(a) ?? 0));
        final kept = <Map<String, dynamic>>[];
        for (final l in locals) {
          if (!kept.any((k) => localSpotReplaces(k, l))) kept.add(l);
        }
        Map<String, dynamic>? stationOf(Map<String, dynamic> spot) {
          for (final call in spotCallsIn(callOfSpot(spot))) {
            for (final k in kept) {
              if (callOfSpot(k) == call && localSpotTakesIn(k, spot)) return k;
            }
          }
          return null;
        }

        final takenIn = Map<Map<String, dynamic>, List<Map<String, dynamic>>>.identity();
        for (final spot in spots) {
          if (spot['hookKey'] != localSpotSource) {
            if (stationOf(spot) case final station?) takenIn.putIfAbsent(station, () => []).add(spot);
          }
        }
        bool moved(Map<String, dynamic> k) => (takenIn[k] ?? const []).any(
          (s) =>
              timeOfSpot(s)! > timeOfSpot(k)! &&
              ((s['freq'] as double) - (k['freq'] as double)).abs() > (superModeForMode(k['mode'] as String) == 'CW' ? 0.02 : 0.1) + 1e-9,
        );
        final expected = <Map<String, dynamic>>[];
        for (final spot in spots) {
          if (spot['hookKey'] == localSpotSource) {
            if (kept.any((k) => identical(k, spot))) expected.add(spot);
          } else if (stationOf(spot) == null && !kept.any((k) => !moved(k) && localSpotHides(k, spot))) {
            expected.add(spot);
          }
        }
        final actual = withLocalSpots(spots);
        expect(actual, hasLength(expected.length), reason: 'round $round');
        for (var i = 0; i < expected.length; i++) {
          final want = expected[i];
          if (want['hookKey'] != localSpotSource) {
            expect(actual[i], same(want), reason: 'round $round, row $i');
          } else {
            // A local spot's row is built anew, from the newest of what it
            // took in: its time and its frequency are that one's, never
            // another row's, and never left behind at the local spot's.
            final group = [want, ...?takenIn[want]];
            final newest = group.map((s) => timeOfSpot(s)!).reduce(max);
            expect(timeOfSpot(actual[i]), newest, reason: 'round $round, row $i');
            expect(group.where((s) => timeOfSpot(s) == newest).map((s) => s['freq']), contains(actual[i]['freq']), reason: 'round $round, row $i');
            expect(spotCallsIn(callOfSpot(actual[i])), containsAll(spotCallsIn(callOfSpot(want))), reason: 'round $round, row $i');
            // Every reference of every spot it took in, and no other row's.
            expect(
              [for (final r in (actual[i]['refs'] as List?) ?? const []) r['ref']],
              unorderedEquals({
                for (final s in group)
                  for (final r in (s['refs'] as List?) ?? const []) r['ref'],
              }),
              reason: 'round $round, row $i',
            );
          }
        }
      }
    });

    test("a local spot takes in its station's spots: every reference, and where, when and how from the newest", () {
      final row = withLocalSpots([
        fetched('N6LY', freq: 14266, refs: [park], label: parkLine, ageMinutes: 2),
        fetched(
          'N6LY',
          freq: 14262,
          source: 'cluster',
          ageMinutes: 10,
          refs: [
            {'type': 'sotaActivation', 'ref': 'W6/NC-001'},
          ],
        ),
        local('N6LY', freq: 14266.2),
      ]).single;
      expect(row['freq'], 14266.2);
      expect(row['hookKey'], localSpotSource);
      expect((row['refs'] as List).map((r) => r['ref']), unorderedEquals(['US-1131', 'W6/NC-001']));
      // The park line still says what the station is doing; the local spot has none.
      expect((row['spot'] as Map)['label'], parkLine);
    });

    test("a spot of its station from another outing is not taken in, and stays a row of its own", () {
      // Taken in, a park activated hours ago would ride on a row stamped now,
      // and the age filter, which reads the row's time, could never drop it.
      final rows = withLocalSpots([
        fetched('N6LY', refs: [park], label: parkLine, ageMinutes: 31),
        local('N6LY'),
      ]);
      expect(rows, hasLength(2));
      final row = rows.firstWhere((r) => r['hookKey'] == localSpotSource);
      expect(row.containsKey('refs'), isFalse);
      expect((row['spot'] as Map).containsKey('label'), isFalse);
    });

    test('a row moved by a newer spot of its station no longer hides the frequency it left', () {
      // The network says N6LY is on 14310 now; K2ABC hidden on 14266 would
      // leave a frequency where the board shows nobody.
      final rows = withLocalSpots([
        local('N6LY', freq: 14266, ageMinutes: 3),
        fetched('K2ABC', freq: 14266.05, ageMinutes: 5),
        fetched('N6LY', freq: 14310, ageMinutes: 1),
      ]);
      expect(rows.map(callOfSpot), unorderedEquals(['N6LY', 'K2ABC']));
      // Moved only within its own signal, it still says who is there.
      expect(
        withLocalSpots([
          local('N6LY', freq: 14266, ageMinutes: 3),
          fetched('K2ABC', freq: 14266.05, ageMinutes: 5),
          fetched('N6LY', freq: 14266.02, ageMinutes: 1),
        ]).map(callOfSpot),
        ['N6LY'],
      );
    });

    test('spots of one moment make the same row in whatever order the sources arrive', () {
      final pota = fetched('N6LY', freq: 14266, ageMinutes: 1);
      final cluster = {...fetched('N6LY', freq: 14262, source: 'cluster'), 'spot': pota['spot']};
      final mine = local('N6LY', ageMinutes: 3);
      expect(withLocalSpots([mine, pota, cluster]).single['freq'], withLocalSpots([mine, cluster, pota]).single['freq']);
    });

    test('a spot posted after the local one gives the row its frequency and its word', () {
      final row = withLocalSpots([
        local('N6LY', freq: 14266, refs: [park], ageMinutes: 3),
        fetched('N6LY', freq: 14310, ageMinutes: 1, label: 'QRT'),
      ]).single;
      expect(row['freq'], 14310);
      expect(row['hookKey'], 'pota');
      expect((row['spot'] as Map)['label'], 'QRT');
      expect((row['refs'] as List).single, park, reason: "the local spot's park stays on the row");
    });

    test("a reference both name keeps the newer spot's fields, and the older one's that the newer lacks", () {
      final row = withLocalSpots([
        fetched(
          'N6LY',
          refs: [
            {...park, 'location': 'US-CA'},
          ],
        ),
        local('N6LY', refs: [park]),
      ]).single;
      expect(row['refs'], [
        {...park, 'location': 'US-CA'},
      ]);
    });

    test('a local spot standing alone names its references when it has no label', () {
      expect(
        (withLocalSpots([
              local('N6LY', refs: [park]),
            ]).single['spot']
            as Map)['label'],
        'US-1131',
      );
      expect((withLocalSpots([local('N6LY')]).single['spot'] as Map).containsKey('label'), isFalse);
    });

    test('held spots are never changed in place', () {
      // They are SpotsService's own lists; a row built into one would stay
      // on the board after its local spot is gone.
      final held = fetched('N6LY', refs: [park], label: parkLine);
      final before = const DeepCollectionEquality().hash(held);
      withLocalSpots([
        held,
        local(
          'N6LY',
          refs: [
            {'type': 'sotaActivation', 'ref': 'W6/NC-001'},
          ],
        ),
      ]);
      expect(const DeepCollectionEquality().hash(held), before);
    });
  });

  group('a fetched spot that names no mode', () {
    test("takes the band plan's for its frequency, where the plan settles on one", () {
      expect(withBandPlanMode(fetched('W1AW', freq: 14074, mode: null))['mode'], 'FT8');
      expect(withBandPlanMode(fetched('W1AW', freq: 14030, mode: null))['mode'], 'CW');
      expect(withBandPlanMode(fetched('W1AW', freq: 14250, mode: null))['mode'], 'SSB');
      // Blank reads as Digital to the mode filter, which is worse than none.
      expect(withBandPlanMode(fetched('W1AW', freq: 14250, mode: ''))['mode'], 'SSB');
      expect(withBandPlanMode(fetched('W1AW', freq: 5332, mode: null)).containsKey('mode'), isFalse, reason: 'a channel the plan leaves to any mode');
      expect(withBandPlanMode(fetched('W1AW', freq: 14250, mode: 'CW'))['mode'], 'CW', reason: "a source's own word stands");
    });

    test('has it as it arrives, so the mode filter can place it and a local spot of its station can take it in', () async {
      final service = SpotsService(
        fetchSpots: feed([
          fetched('N6LY', freq: 14266, mode: null, refs: [park], label: parkLine),
        ]),
      );
      addTearDown(service.dispose);
      await service.refresh();
      expect(service.spotsBySource['pota']!.single['mode'], 'SSB');

      service.putLocalSpot('a', local('N6LY', freq: 14266));
      final [row] = mergedSpotBoard(service.spotsBySource, const {}, entityOf: (_) => null);
      expect((row['spot'] as Map)['label'], parkLine);
    });

    test('a pushed one has it too: a cluster that pushes is where most spots without one come from', () {
      final service = SpotsService(fetchSpots: feed(const []));
      addTearDown(service.dispose);
      service.replaceSpots('cluster', [fetched('N6LY', freq: 14030, mode: null)]);
      service.putSpots('cluster', [fetched('K2ABC', freq: 14074, mode: null)]);
      expect([for (final spot in service.spotsBySource['cluster']!) spot['mode']], ['CW', 'FT8']);
    });
  });

  group('the board', () {
    List<String> board(SpotsService service, {Set<String> disabled = const {}}) => [
      for (final spot in mergedSpotBoard(service.spotsBySource, disabled, entityOf: (_) => null)) callOfSpot(spot)!,
    ];

    test('a local spot hides another station on its frequency and takes in its own, both back as they were when it goes', () async {
      final service = SpotsService(
        fetchSpots: feed([
          fetched('K2ABC'),
          fetched('W1AW', freq: 14300, refs: [park], label: parkLine),
          fetched('N3XYZ', freq: 14280),
        ]),
      );
      addTearDown(service.dispose);
      await service.refresh();

      service.putLocalSpot('a', local('W1AW'));
      expect(board(service), unorderedEquals(['W1AW', 'N3XYZ']));
      final w1aw = mergedSpotBoard(service.spotsBySource, const {}, entityOf: (_) => null).firstWhere((s) => callOfSpot(s) == 'W1AW');
      expect(w1aw['freq'], 14250);
      expect((w1aw['spot'] as Map)['label'], parkLine);
      // Held, so the lookup still finds the park K2ABC was spotted at.
      expect(callsOn(service, 'pota'), hasLength(3));
      expect(service.spotsForCall('K2ABC', maxAge: const Duration(hours: 1)), hasLength(1));

      service.removeLocalSpot('a');
      expect(board(service), unorderedEquals(['K2ABC', 'W1AW', 'N3XYZ']));
    });

    test('with the local source switched off, what it hid is the board', () async {
      // Hidden before the source filter, the station would vanish from both.
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

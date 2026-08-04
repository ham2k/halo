// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/spots_service.dart';

Map<String, dynamic> spot(
  String call, {
  required int ageMinutes,
  String source = 'pota',
  List<Map<String, String>> refs = const [],
}) =>
    {
      'their': {'call': call},
      'refs': refs,
      'hookKey': source,
      'spot': {
        'timeInMillis': DateTime.now().millisecondsSinceEpoch - Duration(minutes: ageMinutes).inMilliseconds,
        'source': source,
      },
    };

void main() {
  test('spotsForCall drops spots older than maxAge', () {
    // Age is the spot's OWN posting time, not when the cache fetched it — a
    // freshly fetched but hours-old spot describes where a station WAS.
    final service = SpotsService(
      fetchSpots: () async => [
        spot('KI2D', ageMinutes: 5, refs: [
          {'type': 'potaHunter', 'ref': 'US-1234'}
        ]),
        spot('N0DEV', ageMinutes: 90, refs: [
          {'type': 'potaHunter', 'ref': 'US-9999'}
        ]),
      ],
    );
    addTearDown(service.dispose);

    return service.refresh().then((_) {
      expect(service.spotsForCall('KI2D', maxAge: const Duration(minutes: 30)), hasLength(1));
      expect(service.spotsForCall('N0DEV', maxAge: const Duration(minutes: 30)), isEmpty);
      // The stale spot is still cached — only the age window hides it, so a
      // wider window finds it again.
      expect(service.spotsForCall('N0DEV', maxAge: const Duration(hours: 2)), hasLength(1));
    });
  });

  test('spotsForCall matches the callsign case- and whitespace-insensitively', () async {
    // The logging field's text arrives however the operator typed it; spot
    // sources are not consistent about case either.
    final service = SpotsService(fetchSpots: () async => [spot('ki2d', ageMinutes: 1)]);
    addTearDown(service.dispose);
    await service.refresh();

    expect(service.spotsForCall('KI2D', maxAge: const Duration(minutes: 30)), hasLength(1));
    expect(service.spotsForCall(' ki2d ', maxAge: const Duration(minutes: 30)), hasLength(1));
    expect(service.spotsForCall('KI2X', maxAge: const Duration(minutes: 30)), isEmpty);
  });

  test('spotsForCall returns the newest spot first', () async {
    // The lookup takes the first spot to offer each ref type, so this
    // ordering is what makes an activator who moved parks contribute the one
    // they are on now.
    final service = SpotsService(
      fetchSpots: () async => [
        spot('KI2D', ageMinutes: 20, refs: [
          {'type': 'potaHunter', 'ref': 'US-0001'}
        ]),
        spot('KI2D', ageMinutes: 2, refs: [
          {'type': 'potaHunter', 'ref': 'US-0002'}
        ]),
      ],
    );
    addTearDown(service.dispose);
    await service.refresh();

    final found = service.spotsForCall('KI2D', maxAge: const Duration(minutes: 30));
    expect(found, hasLength(2));
    expect(((found.first['refs'] as List).first as Map)['ref'], 'US-0002');
  });

  test('nothing is fetched until something subscribes, and fetching stops when the last one leaves', () {
    // An app sitting on the Home screen must make no spot requests at all —
    // this is what keeps the always-on cache from being always-on traffic.
    return fakeAsync((async) {
      var fetches = 0;
      final service = SpotsService(
        fetchSpots: () async {
          fetches++;
          return [];
        },
        refreshInterval: const Duration(minutes: 2),
      );

      async.elapse(const Duration(minutes: 10));
      expect(fetches, 0, reason: 'no subscribers, no fetching');

      final release = service.subscribe();
      async.flushMicrotasks();
      expect(fetches, 1, reason: 'subscribing fetches immediately rather than waiting out the first interval');

      async.elapse(const Duration(minutes: 5));
      expect(fetches, 3);

      release();
      async.elapse(const Duration(minutes: 10));
      expect(fetches, 3, reason: 'the timer stops with the last subscriber');

      service.dispose();
    });
  });

  test('a second subscriber leaving does not stop the fetching the first still needs', () {
    // The Spots Panel opens and closes inside an Operation View that holds
    // its own subscription; refcounting is what keeps the panel's dispose
    // from silently ending the lookups' supply of spots.
    return fakeAsync((async) {
      var fetches = 0;
      final service = SpotsService(
        fetchSpots: () async {
          fetches++;
          return [];
        },
        refreshInterval: const Duration(minutes: 2),
      );

      final releaseView = service.subscribe();
      final releasePanel = service.subscribe();
      async.flushMicrotasks();
      final afterSubscribe = fetches;

      releasePanel();
      async.elapse(const Duration(minutes: 5));
      expect(fetches, greaterThan(afterSubscribe), reason: 'the view still holds a subscription');

      releaseView();
      final afterRelease = fetches;
      async.elapse(const Duration(minutes: 10));
      expect(fetches, afterRelease);

      service.dispose();
    });
  });

  test('a failing fetch is reported, not thrown, and clears on the next success', () async {
    // One dead spot source must not take the panel down with it.
    var fail = true;
    final service = SpotsService(fetchSpots: () async {
      if (fail) throw StateError('network down');
      return [spot('KI2D', ageMinutes: 1)];
    });
    addTearDown(service.dispose);

    await service.refresh();
    expect(service.error, isA<StateError>());
    expect(service.loaded, isTrue, reason: 'a failed fetch still settles the loading state');

    fail = false;
    await service.refresh();
    expect(service.error, isNull);
    expect(service.spotsForCall('KI2D', maxAge: const Duration(minutes: 30)), hasLength(1));
  });

  test('disposing while a fetch is in flight does not throw', () async {
    // Nothing cancels a fetch already on the wire, so its completion lands
    // after the dispose. Notifying listeners at that point is a hard error —
    // and it would surface from inside the fetch's own future, far from the
    // dispose that actually caused it.
    final completer = Completer<List<Map<String, dynamic>>>();
    final service = SpotsService(fetchSpots: () => completer.future);
    service.addListener(() {});

    final pending = service.refresh();
    service.dispose();
    completer.complete([spot('KI2D', ageMinutes: 1)]);

    await expectLater(pending, completes);
  });

  test('subscribing to a disposed service is inert', () async {
    // A widget disposed in the same frame as the service it subscribes to
    // must not restart the timer on the way out.
    var fetches = 0;
    final service = SpotsService(fetchSpots: () async {
      fetches++;
      return [];
    });
    service.dispose();

    final release = service.subscribe();
    await Future<void>.delayed(Duration.zero);
    expect(fetches, 0);
    release(); // must not throw either
  });

  test('overlapping refreshes coalesce into one fan-out', () async {
    // A timer tick landing on a pull-to-refresh must not double the requests
    // to every spot source's API.
    var fetches = 0;
    final completer = Completer<List<Map<String, dynamic>>>();
    final service = SpotsService(fetchSpots: () {
      fetches++;
      return completer.future;
    });
    addTearDown(service.dispose);

    final first = service.refresh();
    final second = service.refresh();
    expect(fetches, 1);

    completer.complete([]);
    await Future.wait([first, second]);
    expect(fetches, 1);
  });
}

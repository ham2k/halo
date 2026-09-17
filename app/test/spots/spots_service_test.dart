// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
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

/// A fetch that answers with [spots] and reports every source that offered
/// one healthy — what the great majority of these tests are about. Only the
/// tests that care about a source in trouble build the record themselves.
SpotsFetch feed(FutureOr<List<Map<String, dynamic>>> Function() spots) => () async {
      final items = await spots();
      return (
        items: items,
        succeeded: {for (final item in items) item['hookKey'] as String? ?? 'unknown'}.toList(),
        unreachable: const <String>[],
        failed: const <String>[],
      );
    };

void main() {
  test('spotsForCall drops spots older than maxAge', () {
    // Age is the spot's OWN posting time, not when the cache fetched it — a
    // freshly fetched but hours-old spot describes where a station WAS.
    final service = SpotsService(
      fetchSpots: feed(() async => [
        spot('KI2D', ageMinutes: 5, refs: [
          {'type': 'potaHunter', 'ref': 'US-1234'}
        ]),
        spot('N0DEV', ageMinutes: 90, refs: [
          {'type': 'potaHunter', 'ref': 'US-9999'}
        ]),
      ]),
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
    final service = SpotsService(fetchSpots: feed(() async => [spot('ki2d', ageMinutes: 1)]));
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
      fetchSpots: feed(() async => [
        spot('KI2D', ageMinutes: 20, refs: [
          {'type': 'potaHunter', 'ref': 'US-0001'}
        ]),
        spot('KI2D', ageMinutes: 2, refs: [
          {'type': 'potaHunter', 'ref': 'US-0002'}
        ]),
      ]),
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
        fetchSpots: feed(() async {
          fetches++;
          return [];
        }),
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
        fetchSpots: feed(() async {
          fetches++;
          return [];
        }),
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
    final service = SpotsService(fetchSpots: feed(() async {
      if (fail) throw StateError('network down');
      return [spot('KI2D', ageMinutes: 1)];
    }));
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
    final service = SpotsService(fetchSpots: feed(() => completer.future));
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
    final service = SpotsService(fetchSpots: feed(() async {
      fetches++;
      return [];
    }));
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
    final service = SpotsService(fetchSpots: feed(() {
      fetches++;
      return completer.future;
    }));
    addTearDown(service.dispose);

    final first = service.refresh();
    final second = service.refresh();
    expect(fetches, 1);

    completer.complete([]);
    await Future.wait([first, second]);
    expect(fetches, 1);
  });

  test('a source that never answered is named, while the rest of the board stays live', () async {
    // The distinction the whole partial-results path exists to preserve: one
    // unreachable feed must cost its own spots and nobody else's, and the
    // operator has to be able to tell an empty band from a silent server.
    final service = SpotsService(
      fetchSpots: () async => (items: [spot('KI2D', ageMinutes: 1)], succeeded: const ['pota'], unreachable: const ['sota'], failed: const <String>[]),
    );
    addTearDown(service.dispose);
    addTearDown(service.subscribe());

    await service.refresh();

    expect(service.unavailableSources, ['sota']);
    expect(service.spotsForCall('KI2D', maxAge: const Duration(minutes: 30)), hasLength(1),
        reason: "the answering source's spots must survive");
    expect(service.error, isNull, reason: 'one silent source is not the whole fetch failing');
  });

  test('the last subscriber leaving clears the outage it can no longer clear', () async {
    // The status message lives above the whole app, but only a fetch can
    // retract it — and unsubscribing stops the fetching. Left set, "SOTAWatch
    // did not respond" follows the operator to the Home screen and stays for
    // the session, outliving the outage by hours.
    final service = SpotsService(
      fetchSpots: () async => (items: const <Map<String, dynamic>>[], succeeded: const <String>[], unreachable: const ['sota'], failed: const <String>[]),
    );
    addTearDown(service.dispose);

    final release = service.subscribe();
    await service.refresh();
    expect(service.unavailableSources, ['sota']);

    release();
    expect(service.unavailableSources, isEmpty);
  });

  test('the last subscriber leaving notifies after dispose, not during it', () async {
    // The last subscriber leaves from a State's dispose, while the widget
    // tree is locked. A synchronous notice reaches the status bar's
    // ListenableBuilder there and throws "setState() called when widget tree
    // was locked" on every return to Home after an outage.
    final service = SpotsService(
      fetchSpots: () async => (items: const <Map<String, dynamic>>[], succeeded: const <String>[], unreachable: const ['sota'], failed: const <String>[]),
    );
    addTearDown(service.dispose);

    final release = service.subscribe();
    await service.refresh();
    var notices = 0;
    service.addListener(() => notices++);

    release();
    expect(notices, 0, reason: 'a notice inside dispose runs while the tree is locked');
    await Future<void>.delayed(Duration.zero);
    expect(notices, 1, reason: 'the cleared outage must still reach the status bar');
  });

  test('a fetch that lands after the last subscriber left records no outage', () async {
    // The race the guard above does NOT cover: `release()` clears what is
    // already recorded, but a fetch still on the wire settles afterwards and
    // would re-arm it. A stalled source is precisely the case that takes ten
    // seconds to settle — ample time to close the operation — and by then
    // the timer is cancelled, so nothing would ever retract the message.
    //
    // See the resubscribe test below for why this asks who is watching NOW
    // rather than whether the subscription ever lapsed.
    final gate = Completer<
        ({List<Map<String, dynamic>> items, List<String> succeeded, List<String> unreachable, List<String> failed})>();
    final service = SpotsService(fetchSpots: () => gate.future);
    addTearDown(service.dispose);

    final release = service.subscribe();
    final inFlight = service.refresh();
    release();
    gate.complete((items: const <Map<String, dynamic>>[], succeeded: const <String>[], unreachable: const ['sota'], failed: const <String>[]));
    await inFlight;

    expect(service.unavailableSources, isEmpty);
  });

  test('reopening the operation before the fetch lands still reports the outage', () async {
    // The trap in the guard above: `refresh()` coalesces, so an operator who
    // closes the operation and reopens it inside the stall window is handed
    // the SAME in-flight fetch. Asking "did the subscription ever lapse?"
    // throws that outage away while somebody is watching and the timer is
    // running again — no notice until the next two-minute tick, for an
    // outage already known. The question has to be who is watching NOW.
    final gate = Completer<
        ({List<Map<String, dynamic>> items, List<String> succeeded, List<String> unreachable, List<String> failed})>();
    final service = SpotsService(fetchSpots: () => gate.future);
    addTearDown(service.dispose);

    final release = service.subscribe();
    final inFlight = service.refresh();
    release();
    addTearDown(service.subscribe()); // straight back in, same fetch still on the wire
    gate.complete((items: const <Map<String, dynamic>>[], succeeded: const <String>[], unreachable: const ['sota'], failed: const <String>[]));
    await inFlight;

    expect(service.unavailableSources, ['sota']);
  });

  test('a fetch that throws outright drops the per-source outage list', () async {
    // Last cycle's list describes nothing current: naming one source while
    // the whole fetch is failing points the operator at the wrong problem.
    var fail = false;
    final service = SpotsService(
      fetchSpots: () async {
        if (fail) throw StateError('network down');
        return (items: const <Map<String, dynamic>>[], succeeded: const <String>[], unreachable: const ['sota'], failed: const <String>[]);
      },
    );
    addTearDown(service.dispose);
    addTearDown(service.subscribe());

    await service.refresh();
    expect(service.unavailableSources, ['sota']);

    fail = true;
    await service.refresh();
    expect(service.error, isA<StateError>());
    expect(service.unavailableSources, isEmpty);
  });

  test('a source that answered with an error is kept apart from one that never replied', () async {
    // Merging the two would tell the operator to wait out a server that is
    // up and answering 503 — it will still be answering 503 in ten minutes.
    final service = SpotsService(
      fetchSpots: () async => (
        items: [spot('KI2D', ageMinutes: 1)],
        succeeded: const <String>[], unreachable: const ['sota'],
        failed: const ['pota'],
      ),
    );
    addTearDown(service.dispose);
    addTearDown(service.subscribe());

    await service.refresh();

    expect(service.unavailableSources, ['sota']);
    expect(service.failedSources, ['pota']);
    expect(service.spotsForCall('KI2D', maxAge: const Duration(minutes: 30)), hasLength(1),
        reason: "a third source's spots must survive both");
    expect(service.error, isNull, reason: 'one source erroring is not the whole fetch failing');
  });

  test('the last subscriber leaving clears an error the same way it clears an outage', () async {
    // Same hazard as the timed-out list: with the timer stopped nothing will
    // fetch again, so nothing can ever retract "POTA.app returned an error"
    // — it follows the operator to the Home screen for the rest of the
    // session.
    final service = SpotsService(
      fetchSpots: () async => (items: const <Map<String, dynamic>>[], succeeded: const <String>[], unreachable: const <String>[], failed: const ['pota']),
    );
    addTearDown(service.dispose);

    final release = service.subscribe();
    await service.refresh();
    expect(service.failedSources, ['pota']);

    release();
    expect(service.failedSources, isEmpty);
  });

  test('a fetch that throws outright drops the failed list too', () async {
    // Same reason the timed-out list goes: naming one source while the whole
    // fetch is failing points the operator at the wrong problem.
    var fail = false;
    final service = SpotsService(
      fetchSpots: () async {
        if (fail) throw StateError('network down');
        return (items: const <Map<String, dynamic>>[], succeeded: const <String>[], unreachable: const <String>[], failed: const ['pota']);
      },
    );
    addTearDown(service.dispose);
    addTearDown(service.subscribe());

    await service.refresh();
    expect(service.failedSources, ['pota']);

    fail = true;
    await service.refresh();
    expect(service.error, isA<StateError>());
    expect(service.failedSources, isEmpty);
  });

  test('a source that comes back stops being named', () async {
    // Otherwise the status message outlives the outage that justified it.
    var down = true;
    final service = SpotsService(
      fetchSpots: () async => (
        items: <Map<String, dynamic>>[],
        succeeded: down ? const <String>[] : const ['sota'],
        unreachable: down ? const ['sota'] : const <String>[],
        failed: const <String>[],
      ),
    );
    addTearDown(service.dispose);
    addTearDown(service.subscribe());

    await service.refresh();
    expect(service.unavailableSources, ['sota']);

    down = false;
    await service.refresh();
    expect(service.unavailableSources, isEmpty);
  });

  test('a brief blackout leaves every source\'s spots standing', () async {
    // Rebuild the board from the fetch alone and a source that never
    // answered contributes nothing, so it disappears — every source at once
    // on a brief Wi-Fi drop, emptying the board and refilling it a minute
    // later, taking the three-minute-old spot a hunter is working with.
    // Nothing answered, so nothing is known to have changed.
    var reachable = true;
    final service = SpotsService(
      fetchSpots: () async => reachable
          ? (
              items: [spot('KI2D', ageMinutes: 3, source: 'pota'), spot('N0DEV', ageMinutes: 4, source: 'sota')],
              succeeded: const ['pota', 'sota'],
              unreachable: const <String>[],
              failed: const <String>[],
            )
          : (items: <Map<String, dynamic>>[], succeeded: const <String>[], unreachable: const ['pota', 'sota'], failed: const <String>[]),
    );
    addTearDown(service.dispose);
    addTearDown(service.subscribe());

    await service.refresh();
    expect(service.spotsBySource.keys, unorderedEquals(['pota', 'sota']));

    reachable = false;
    await service.refresh();

    expect(service.spotsBySource['pota'], hasLength(1), reason: 'an unreachable source replaces nothing');
    expect(service.spotsBySource['sota'], hasLength(1));
    // The by-call index is rebuilt on every fetch, so retention that stopped
    // at spotsBySource would still lose the lookup path — the surface the
    // logging panel actually reads.
    expect(service.spotsForCall('KI2D', maxAge: const Duration(minutes: 30)), hasLength(1));
  });

  test('a fan-out that never ran leaves the whole board standing', () async {
    // The trap: no spots, no outages and no successes is the same record a
    // board of genuinely quiet sources produces, and reads as "every band is
    // empty". It is what getSpots answers with when there is no extension
    // host — true for as long as it takes to replace the runtime, on every
    // extension enable/disable — and when the fan-out itself throws. Nothing
    // was asked, so nothing is known.
    var host = true;
    final service = SpotsService(
      fetchSpots: () async => host
          ? (
              items: [spot('KI2D', ageMinutes: 2, source: 'pota')],
              succeeded: const ['pota'],
              unreachable: const <String>[],
              failed: const <String>[],
            )
          : (
              items: <Map<String, dynamic>>[],
              succeeded: const <String>[],
              unreachable: const <String>[],
              failed: const <String>[],
            ),
    );
    addTearDown(service.dispose);
    addTearDown(service.subscribe());

    await service.refresh();
    host = false;
    await service.refresh();

    expect(service.spotsBySource['pota'], hasLength(1));
    expect(service.spotsForCall('KI2D', maxAge: const Duration(minutes: 30)), hasLength(1));
  });

  test('nothing older than the ceiling is held, retained or fresh', () async {
    // What stops retention becoming a board furnished out of a morning that
    // is over: a source down since breakfast holds spots nobody could see
    // anyway, since the panel offers no age filter wider than this. The
    // ceiling binds a live source too — retention is not a licence to keep
    // what a healthy feed would never have shown.
    var down = false;
    final service = SpotsService(
      fetchSpots: () async => down
          ? (
              items: <Map<String, dynamic>>[],
              succeeded: const <String>[],
              unreachable: const ['pota'],
              failed: const <String>[]
            )
          : (
              items: [
                spot('KI2D', ageMinutes: 179, source: 'pota'),
                spot('N0DEV', ageMinutes: 181, source: 'sota'),
              ],
              succeeded: const ['pota', 'sota'],
              unreachable: const <String>[],
              failed: const <String>[],
            ),
    );
    addTearDown(service.dispose);
    addTearDown(service.subscribe());

    await service.refresh();
    expect(service.spotsBySource.containsKey('sota'), isFalse,
        reason: 'a fresh answer does not license an over-age spot either');
    expect(service.spotsBySource['pota'], hasLength(1));

    // The retained copy is judged on the same clock, so the spot that was
    // inside the window when it arrived falls out of it while its source is
    // down — and takes the source with it, having nothing left to hold.
    down = true;
    await service.refresh();
    expect(service.spotsBySource['pota'], hasLength(1), reason: 'still inside the window');

    AppClock.instance.travel(delta: const Duration(minutes: 5));
    addTearDown(AppClock.instance.reset);
    await service.refresh();
    expect(service.spotsBySource.containsKey('pota'), isFalse);
    expect(service.spotsForCall('KI2D', maxAge: const Duration(hours: 4)), isEmpty);
  });

  test('a source that stops being consulted takes its spots with it', () async {
    // The other side of retaining what nobody answered for: a source the
    // operator switches off is not in trouble, it is gone, and holding its
    // last spots would leave them on the board for the rest of the session
    // with nothing left to ever clear them.
    var both = true;
    final service = SpotsService(
      fetchSpots: () async => both
          ? (
              items: [spot('KI2D', ageMinutes: 1, source: 'pota'), spot('N0DEV', ageMinutes: 1, source: 'sota')],
              succeeded: const ['pota', 'sota'],
              unreachable: const <String>[],
              failed: const <String>[],
            )
          : (
              items: [spot('KI2D', ageMinutes: 1, source: 'pota')],
              succeeded: const ['pota'],
              unreachable: const <String>[],
              failed: const <String>[],
            ),
    );
    addTearDown(service.dispose);
    addTearDown(service.subscribe());

    await service.refresh();
    both = false;
    await service.refresh();

    expect(service.spotsBySource.containsKey('sota'), isFalse);
    expect(service.spotsForCall('N0DEV', maxAge: const Duration(minutes: 30)), isEmpty);
  });

  test('a source that answers with no spots empties, while a failing one holds', () async {
    // The half that keeps retention honest: "keep what we had" must not
    // become "never clear anything". An empty band and a silent server are
    // the distinction the whole partial-results record exists to carry, and
    // a source that says "nothing here" has to be believed.
    var quiet = false;
    final service = SpotsService(
      fetchSpots: () async => quiet
          ? (items: <Map<String, dynamic>>[], succeeded: const ['pota'], unreachable: const <String>[], failed: const ['sota'])
          : (
              items: [spot('KI2D', ageMinutes: 1, source: 'pota'), spot('N0DEV', ageMinutes: 1, source: 'sota')],
              succeeded: const ['pota', 'sota'],
              unreachable: const <String>[],
              failed: const <String>[],
            ),
    );
    addTearDown(service.dispose);
    addTearDown(service.subscribe());

    await service.refresh();
    quiet = true;
    await service.refresh();

    expect(service.spotsBySource.containsKey('pota'), isFalse, reason: 'POTA answered, and answered with nothing');
    expect(service.spotsForCall('KI2D', maxAge: const Duration(minutes: 30)), isEmpty);
    expect(service.spotsBySource['sota'], hasLength(1), reason: 'a source that errored told us nothing about its band');
  });

  test('spots outrank an outage report that contradicts them', () async {
    // A source named unreachable that nonetheless returned spots: the fan-out
    // builds the two records separately, so nothing upstream forbids it.
    // Whatever it means, spots in hand describe the band and a retained list
    // does not — retaining here would hide the fresh answer behind the stale
    // one for as long as the contradiction lasted.
    var second = false;
    final service = SpotsService(
      fetchSpots: () async => second
          ? (items: [spot('KI2D', ageMinutes: 1, source: 'pota')], succeeded: const <String>[], unreachable: const ['pota'], failed: const <String>[])
          : (items: [spot('N0DEV', ageMinutes: 1, source: 'pota')], succeeded: const ['pota'], unreachable: const <String>[], failed: const <String>[]),
    );
    addTearDown(service.dispose);
    addTearDown(service.subscribe());

    await service.refresh();
    second = true;
    await service.refresh();

    expect(service.spotsBySource['pota'], hasLength(1));
    expect(service.spotsForCall('KI2D', maxAge: const Duration(minutes: 30)), hasLength(1));
    expect(service.spotsForCall('N0DEV', maxAge: const Duration(minutes: 30)), isEmpty,
        reason: 'the retained list must not survive an answer that replaces it');
  });
}

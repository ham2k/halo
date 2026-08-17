// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The translation step between the bridge's settled entries and everything
// the operator is eventually told. `spot_network_test.dart` proves the wire
// shape a failing feed produces; the SpotsService and reporter suites prove
// what happens to the buckets afterwards. This is the join between them, and
// the buckets are only as meaningful as the split that fills them.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/error_reporting_service.dart';
import 'package:ham2k_logger/services/extension_service.dart';

import 'error_reporting_test.dart' show FakeErrorReportingBackend, withErrorHooks;

Map<String, dynamic> ok(String key, List<Object?> value) => {'key': key, 'ok': true, 'value': value};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(ErrorReportingService.resetFailureStreaks);
  tearDown(ErrorReportingService.resetFailureStreaks);

  test('a hook that errored and one that never answered land in different buckets', () {
    // The whole feature rests on this line. Merged, the operator is told to
    // wait out a server that is up and answering 503 — it will still be
    // answering 503 in ten minutes — or to give up on one that is merely
    // slow. Worse, a single source would be named in BOTH clauses of one
    // footer message: "SOTAWatch did not respond. SOTAWatch returned an
    // error."
    final parts = partitionHookEntries([
      {'key': 'sota', 'ok': false, 'timedOut': true},
      {'key': 'pota', 'ok': false, 'error': 'POTA API returned HTTP 503'},
    ]);

    expect(parts.unreachable, ['sota']);
    expect([for (final f in parts.failed) f.key], ['pota']);
    expect(parts.succeeded, isEmpty);
  });

  test('the failure carries the reason, not just the key', () {
    // The only place the actual cause survives: it is what reaches Sentry,
    // and ErrorPolicy classifies on the message's first characters — so the
    // string must arrive whole, not summarised down to a key.
    final parts = partitionHookEntries([
      {'key': 'pota', 'ok': false, 'error': 'POTA API returned HTTP 503'},
    ]);

    expect(parts.failed.single.error, 'POTA API returned HTTP 503');
  });

  test('a request that never reached the network is unreachable, not a service error', () {
    // The commonest way this fan-out fails, and the one where the advice
    // matters most: a device with no signal must not report every healthy
    // feed it has as broken. "Did not respond" tells the operator to wait,
    // which is right; "returned an error" tells them to stop expecting spots
    // from services that are perfectly fine.
    //
    // Prefixes, not substrings — a feed whose own error message happens to
    // mention a timeout is still a feed that answered.
    final parts = partitionHookEntries([
      {'key': 'pota', 'ok': false, 'error': "ClientException: Failed host lookup: 'api.pota.app'"},
      {'key': 'sota', 'ok': false, 'error': 'SocketException: Failed host lookup: api-db2.sota.org.uk'},
      {'key': 'wwff', 'ok': false, 'error': 'TimeoutException after 0:00:15.000000'},
      {'key': 'wwbota', 'ok': false, 'error': 'WWBOTA API returned HTTP 503 (upstream timed out)'},
    ]);

    expect(parts.unreachable, ['pota', 'sota', 'wwff']);
    expect([for (final f in parts.failed) f.key], ['wwbota'],
        reason: 'a service that answered badly is not the network');
  });

  test('IOClient\'s socket-wrapping ClientException shape is still unreachable', () {
    // http's IOClient wraps a DNS/connection failure in a subclass whose
    // toString() reads "ClientException with $cause, uri=$uri" rather than
    // plain ClientException's "ClientException: $message" — the same shape
    // ErrorPolicy._isFetchTransportTransient matches. Missing this prefix
    // here would route a native app's own dead-network hook into `failed`
    // instead of `unreachable`, telling the operator to stop expecting spots
    // from a source that never got a chance to answer.
    final parts = partitionHookEntries([
      {
        'key': 'pota',
        'ok': false,
        'error': "ClientException with SocketException: Failed host lookup: 'api.pota.app', uri=https://api.pota.app/spots",
      },
    ]);

    expect(parts.unreachable, ['pota']);
    expect(parts.failed, isEmpty);
  });

  test('a transport failure is not counted as a service error for reporting', () {
    // Only `failed` feeds the failure streak. Counting a dead network would
    // upload one report per source every time an operator drives out of
    // range — the noise the threshold exists to prevent, arriving by a route
    // the threshold cannot see.
    final parts = partitionHookEntries([
      {'key': 'pota', 'ok': false, 'error': 'ClientException: Connection closed before full header was received'},
    ]);

    expect(parts.failed, isEmpty);
    expect(parts.unreachable, ['pota']);
  });

  test('a healthy hook is recorded as succeeding even when it offers nothing', () {
    // What resets the failure streak. Counting only hooks that returned a
    // non-empty list would leave a source that recovered into a quiet band
    // stuck at its old count, and the next single failure could fire a
    // report captioned "failed 10 times in a row".
    final parts = partitionHookEntries([
      ok('pota', []),
      {'key': 'sota', 'ok': true, 'value': null},
    ]);

    expect(parts.succeeded, ['pota', 'sota']);
    expect(parts.items, isEmpty);
    expect(parts.failed, isEmpty);
  });

  test('items are tagged with the hook that offered them', () {
    // The tag is what lets the panel group and filter by source, and what
    // routes a later sendSpot back to the right hook.
    final parts = partitionHookEntries([
      ok('pota', [
        {'their': 'K1ABC'}
      ]),
      ok('sota', [
        {'their': 'G1XYZ'}
      ]),
    ]);

    expect(parts.items.map((i) => i['hookKey']), ['pota', 'sota']);
  });

  test('one unreadable entry does not discard what the others reported', () {
    // The reason each entry is read under its own guard. A payload whose keys
    // are not Strings throws when spread; aborting the loop there would drop
    // every later entry's bucket too, and the operator would be told fewer
    // sources are in trouble than actually are — silently, and less alarming
    // than the truth.
    final parts = partitionHookEntries([
      {
        'key': 'bad',
        'ok': true,
        'value': [
          {1: 'not a string key'}
        ],
      },
      {'key': 'sota', 'ok': false, 'timedOut': true},
      {'key': 'pota', 'ok': false, 'error': 'HTTP 503'},
    ]);

    expect(parts.unreachable, ['sota'], reason: 'learned after the bad entry');
    expect([for (final f in parts.failed) f.key], ['pota']);
  });

  test('an entry with no key is not counted as anything', () {
    // Nothing downstream can name it, so putting it in a bucket would produce
    // a message about a source that cannot be identified.
    final parts = partitionHookEntries([
      {'ok': false, 'error': 'HTTP 503'},
    ]);

    expect(parts.failed, isEmpty);
    expect(parts.succeeded, isEmpty);
    expect(parts.unreachable, isEmpty);
  });

  group('validSpots', () {
    // The crash getSpots() exists to prevent: spots_panel.dart's readers
    // trust `freq` is a num once the item survives here, so a numeric string
    // from a hook that skipped its own coercion must be dropped before it
    // reaches the panel, not merely tolerated once there.
    test('drops a spot with a wrong-typed freq, keeps the rest of that hook and every other', () async {
      final backend = FakeErrorReportingBackend();
      await withErrorHooks(() async {
        final items = [
          {
            'hookKey': 'wwff',
            'their': {'call': 'K1ABC'},
            'freq': '14285.0',
          },
          {
            'hookKey': 'wwff',
            'their': {'call': 'W1XYZ'},
            'freq': 14285.0,
          },
          {
            'hookKey': 'pota',
            'their': {'call': 'G1ABC'},
            'freq': 7040.0,
          },
        ];

        final valid = validSpots(items);

        expect(valid.map((s) => (s['their'] as Map)['call']), ['W1XYZ', 'G1ABC']);
      }, backend: backend);
    });

    test('reports the malformed spot once, tagged with the offending source', () async {
      // Whether that report reaches the operator as a notice, rather than
      // just the backend, is `malformed-spot-data`'s own disposition —
      // proved in error_policy_test.dart, not here: report() never calls
      // notify() on any path this test could exercise, so an empty
      // `statusBar.activeNotices` here would pass even if that rule were
      // loosened to `notify`.
      final backend = FakeErrorReportingBackend();
      await withErrorHooks(() async {
        validSpots([
          {
            'hookKey': 'wwff',
            'their': {'call': 'K1ABC'},
            'freq': '14285.0',
          },
        ]);

        expect(backend.exceptions, hasLength(1));
        expect(backend.exceptions.single.context, contains('wwff'));
      }, backend: backend);
    });

    test('a repeat offender from the same source reports only the first time', () async {
      final backend = FakeErrorReportingBackend();
      await withErrorHooks(() async {
        final malformed = {
          'hookKey': 'wwff',
          'their': {'call': 'K1ABC'},
          'freq': '14285.0',
        };

        validSpots([malformed]);
        validSpots([malformed]);
        validSpots([malformed]);

        expect(backend.exceptions, hasLength(1));
      }, backend: backend);
    });

    test('a spot simply missing freq is untouched — absence is not a type violation', () async {
      final backend = FakeErrorReportingBackend();
      await withErrorHooks(() async {
        final valid = validSpots([
          {
            'hookKey': 'wwff',
            'their': {'call': 'K1ABC'},
          },
        ]);

        expect(valid, hasLength(1));
        expect(backend.exceptions, isEmpty);
      }, backend: backend);
    });
  });
}

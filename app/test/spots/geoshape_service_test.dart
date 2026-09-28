// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/geoshape_service.dart';

const _url = 'https://az.sotl.as/W2/GC/116.geojson';
const _summit = {'type': 'sotaActivation', 'ref': 'W2/GC-116'};
const _shape = '{"type":"FeatureCollection","features":[]}';

/// Answers `geojsonUrlsForRefs` with one fixed value per ref, already parsed
/// — overriding the method rather than stubbing the hook keeps this about
/// GeoshapeService, not about how a hook's answer becomes a [RefGeojson].
class _FakeExtensions extends ExtensionService {
  _FakeExtensions(this.answer, {this.answered = true});
  final RefGeojson? answer;
  final bool answered;

  @override
  Future<List<RefGeojsonAnswer>> geojsonUrlsForRefs(List<Map<String, dynamic>> refs) async => [for (final _ in refs) (source: answer, answered: answered)];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // ham2kUserAgent() reads the package info before every fetch.
  PackageInfo.setMockInitialValues(appName: 'HaLo', packageName: 'com.ham2k.halo', version: '1.0.0', buildNumber: '1', buildSignature: '');

  late HaLoDatabase db;
  late LookupRepository lookups;

  setUp(() => db = HaLoDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  GeoshapeService serviceFor(
    RefGeojson? source, {
    required http.Client Function() client,
    Duration timeout = GeoshapeService.defaultFetchTimeout,
    bool answered = true,
  }) {
    lookups = LookupRepository(db);
    return GeoshapeService(
      extensions: _FakeExtensions(source, answered: answered),
      lookups: lookups,
      httpClientFactory: client,
      fetchTimeout: timeout,
    );
  }

  /// A cache row as it would look [age] ago. Written directly rather than by
  /// letting the service fetch and then waiting: the stamps are real time
  /// (docs/design/time.md §1 — they persist), so a test cannot move them.
  Future<void> seed({String? geojson, required Duration age}) => LookupRepository(
    db,
  ).insertLookupBatch([LookupRow(category: geoshapeLookupCategory, key: _url, data: geojson, updated: realNowMillis() - age.inMilliseconds)]);

  test('a fresh cached shape is served without a request', () async {
    var requests = 0;
    final service = serviceFor(
      const RefGeojson(url: _url, maxAge: Duration(days: 30), missMaxAge: Duration(days: 1)),
      client: () => http.MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );
    await seed(geojson: _shape, age: const Duration(days: 3));

    expect((await service.shapeForRef(_summit)).geojson, _shape);
    expect(requests, 0, reason: 'the point of the cache is that an offline activator never needs the network');
  });

  test('a shape past its age is fetched again', () async {
    final service = serviceFor(
      const RefGeojson(url: _url, maxAge: Duration(days: 30), missMaxAge: Duration(days: 1)),
      client: () => http.MockClient((_) async => http.Response('{"type":"FeatureCollection","features":[1]}', 200)),
    );
    await seed(geojson: _shape, age: const Duration(days: 31));

    expect((await service.shapeForRef(_summit)).geojson, contains('[1]'));
  });

  test('a summit with no zone is remembered on the SHORTER age, not the shape age', () async {
    var requests = 0;
    final service = serviceFor(
      const RefGeojson(url: _url, maxAge: Duration(days: 30), missMaxAge: Duration(days: 1)),
      client: () => http.MockClient((_) async {
        requests++;
        return http.Response(_shape, 200);
      }),
    );
    // A miss recorded two days ago: still fresh against the 30-day shape age,
    // which is the mix-up that would leave a newly surveyed zone invisible for
    // a month.
    await seed(geojson: null, age: const Duration(days: 2));

    expect((await service.shapeForRef(_summit)).geojson, _shape);
    expect(requests, 1);
  });

  test('a program that could not be asked settles nothing', () async {
    // "No outline" is remembered for the life of a map pane; "could not ask"
    // (a runtime still booting, a handler that threw or ran out of time) must
    // not be, or one busy moment blanks every outline until the pane rebuilds.
    final service = serviceFor(null, client: () => http.MockClient((_) async => fail('nothing to fetch')), answered: false);

    final shape = await service.shapeForRef(_summit);
    expect(shape.geojson, isNull);
    expect(shape.resolved, false);
  });

  test('403 records the miss — object storage declines an absent key without a 404', () async {
    var requests = 0;
    final service = serviceFor(
      const RefGeojson(url: _url, maxAge: Duration(days: 30), missMaxAge: Duration(days: 1)),
      client: () => http.MockClient((_) async {
        requests++;
        return http.Response('<Error>AccessDenied</Error>', 403);
      }),
    );

    expect((await service.shapeForRef(_summit)).geojson, isNull);
    expect((await service.shapeForRef(_summit)).geojson, isNull);
    expect(requests, 1, reason: 'a 403 that is not stored costs a request every time the map is opened');
  });

  test('a failed fetch falls back to the stale shape rather than to nothing', () async {
    final service = serviceFor(
      const RefGeojson(url: _url, maxAge: Duration(days: 30), missMaxAge: Duration(days: 1)),
      client: () => http.MockClient((_) async => throw http.ClientException('offline')),
    );
    await seed(geojson: _shape, age: const Duration(days: 400));

    expect(
      (await service.shapeForRef(_summit)).geojson,
      _shape,
      reason: 'a boundary a year old is still where the boundary is; the summit is where the signal is not',
    );
  });

  test('a body that is not JSON is never stored', () async {
    var requests = 0;
    final service = serviceFor(
      const RefGeojson(url: _url, maxAge: Duration(days: 30), missMaxAge: Duration(days: 1)),
      client: () => http.MockClient((_) async {
        requests++;
        return http.Response('<html>captive portal</html>', 200);
      }),
    );

    expect((await service.shapeForRef(_summit)).geojson, isNull);
    expect(await lookups.getLookup(geoshapeLookupCategory, _url), isNull, reason: 'stored, it would be re-read and re-fail for the whole 30 days');
    expect(requests, 1);
  });

  test('one fetch serves both ref types of the same summit', () async {
    var requests = 0;
    final service = serviceFor(
      const RefGeojson(url: _url, maxAge: Duration(days: 30), missMaxAge: Duration(days: 1)),
      client: () => http.MockClient((_) async {
        requests++;
        return http.Response(_shape, 200);
      }),
    );

    // `sota` and `sotaActivation` name one summit and resolve to one file; the
    // map asks for every reference on the operation in the same frame.
    final both = await Future.wait([
      service.shapeForRef({'type': 'sota', 'ref': 'W2/GC-116'}),
      service.shapeForRef(_summit),
    ]);

    expect(both.map((s) => s.geojson), [_shape, _shape]);
    expect(requests, 1);
  });

  test('a reference whose handler offers no url asks for nothing', () async {
    final service = serviceFor(null, client: () => http.MockClient((_) async => fail('a reference with no shape must not be fetched')));
    expect((await service.shapeForRef({'type': 'pota', 'ref': 'US-0001'})).geojson, isNull);
  });

  test('a summit the program says has no zone reads as RESOLVED', () async {
    // The map remembers a resolved miss and stops asking about it.
    final service = serviceFor(
      const RefGeojson(url: _url, maxAge: Duration(days: 30), missMaxAge: Duration(days: 1)),
      client: () => http.MockClient((_) async => http.Response('', 403)),
    );
    expect((await service.shapeForRef(_summit)).resolved, isTrue);
  });

  test('a fetch that fails with nothing cached settles NOTHING', () async {
    // Read as "no shape", this would have the map stop asking on the strength
    // of a dropped connection — and an activator whose signal comes back
    // while the map is open would never get their outline.
    final service = serviceFor(
      const RefGeojson(url: _url, maxAge: Duration(days: 30), missMaxAge: Duration(days: 1)),
      client: () => http.MockClient((_) async => throw http.ClientException('offline')),
    );
    final answer = await service.shapeForRef(_summit);
    expect(answer.geojson, isNull);
    expect(answer.resolved, isFalse);
  });

  test('a reference whose program has no shapes at all is resolved, not unknown', () async {
    // The hook builds its URL from the reference and never asks the network,
    // so a null answer cannot change while the app runs — asking again every
    // rebuild would be pure waste.
    final service = serviceFor(null, client: () => http.MockClient((_) async => http.Response('', 200)));
    expect((await service.shapeForRef({'type': 'pota', 'ref': 'US-0001'})).resolved, isTrue);
  });

  test('an outline grown past the ceiling keeps the one this device already holds', () async {
    final service = serviceFor(
      const RefGeojson(url: _url, maxAge: Duration(days: 30), missMaxAge: Duration(days: 1)),
      client: () =>
          http.MockClient.streaming((_, _) async => http.StreamedResponse(const Stream.empty(), 200, contentLength: GeoshapeService.maxBodyBytes + 1)),
    );
    await seed(geojson: _shape, age: const Duration(days: 400));

    // The document grew past what can be kept; the boundary it had is still
    // the best this device can draw.
    expect((await service.shapeForRef(_summit)).geojson, _shape);
    expect((await lookups.getLookup(geoshapeLookupCategory, _url))?.data, _shape, reason: 'not overwritten by a miss');
  });

  test('a failure that is not the network is the caller\'s to report, not an outage to retry', () async {
    final service = serviceFor(
      const RefGeojson(url: _url, maxAge: Duration(days: 30), missMaxAge: Duration(days: 1)),
      client: () => http.MockClient((_) async => throw StateError('a bug here')),
    );
    // Read as offline, a bug would be retried every 30 seconds and never
    // reported.
    await expectLater(service.shapeForRef(_summit), throwsStateError);
  });

  test('a body past the ceiling is refused on its declared length, before it is read', () async {
    var bytesRead = 0;
    final service = serviceFor(
      const RefGeojson(url: _url, maxAge: Duration(days: 30), missMaxAge: Duration(days: 1)),
      client: () => http.MockClient.streaming((_, body) async {
        // Declared far past the ceiling. Reading it to find out would cost the
        // operator's memory for a shape that can never draw, which is what the
        // pre-check exists to avoid.
        return http.StreamedResponse(
          body.map((chunk) {
            bytesRead += chunk.length;
            return chunk;
          }),
          200,
          contentLength: GeoshapeService.maxBodyBytes + 1,
        );
      }),
    );

    final answer = await service.shapeForRef(_summit);
    expect(bytesRead, 0);
    // Unresolved, an open map would download the same oversized document again
    // on every retry, for a shape it can never keep.
    expect(answer.resolved, isTrue);
    expect(answer.geojson, isNull);
    final row = await lookups.getLookup(geoshapeLookupCategory, _url);
    expect(row, isNotNull, reason: 'remembered as a miss, so it is asked again on the miss age, not the next rebuild');
    expect(row!.data, isNull);
  });

  test('a body that declared no length is refused once read past the ceiling, and remembered as a miss', () async {
    var requests = 0;
    final service = serviceFor(
      const RefGeojson(url: _url, maxAge: Duration(days: 30), missMaxAge: Duration(days: 1)),
      client: () => http.MockClient.streaming((_, _) async {
        requests++;
        return http.StreamedResponse(Stream.value(List.filled(GeoshapeService.maxBodyBytes + 1, 0x20)), 200);
      }),
    );

    expect((await service.shapeForRef(_summit)).resolved, isTrue);
    expect((await service.shapeForRef(_summit)).geojson, isNull);
    expect(requests, 1, reason: 'the pre-check cannot see an undeclared length; the post-read check is the only thing keeping it out');
  });

  test('a server that connects and then says nothing is given up on, not waited on forever', () async {
    // The deadline has to cover the CONNECT and the headers, not just the body
    // read: a `.timeout` on the body alone leaves this hanging, and with it the
    // in-flight entry for this URL — so that reference's outline would be dead
    // for the rest of the session, with nothing saying why.
    var attempts = 0;
    final service = serviceFor(
      const RefGeojson(url: _url, maxAge: Duration(days: 30), missMaxAge: Duration(days: 1)),
      timeout: const Duration(milliseconds: 50),
      client: () => http.MockClient((_) {
        attempts++;
        return Completer<http.Response>().future;
      }),
    );

    expect((await service.shapeForRef(_summit)).resolved, isFalse);
    // And the in-flight entry cleared with it, so the next ask is a fresh
    // attempt rather than a second wait on the dead one.
    expect((await service.shapeForRef(_summit)).resolved, isFalse);
    expect(attempts, 2);
  });

  test('a redirect is refused, not followed — the https check is on the url a hook NAMES', () async {
    // Followed, a `Location: http://…` would complete the fetch in the clear
    // and walk straight past refGeojsonFromHookResult's scheme check, on a
    // program server's say-so. (A browser blocks mixed content itself, and
    // BrowserClient throws on a request that declines redirects, so the flag
    // is set only off the web.)
    var declinedRedirects = false;
    final service = serviceFor(
      const RefGeojson(url: _url, maxAge: Duration(days: 30), missMaxAge: Duration(days: 1)),
      client: () => http.MockClient((request) async {
        declinedRedirects = !request.followRedirects;
        return http.Response('', 302, headers: {'location': 'http://az.sotl.as/W2/GC/116.geojson'});
      }),
    );

    final answer = await service.shapeForRef(_summit);
    expect(declinedRedirects, !kIsWeb);
    // And a 3xx settles nothing: it is a server misconfigured, not a summit
    // without a zone, so it must not be cached as a miss for a day.
    expect(answer.resolved, isFalse);
    expect(await lookups.getLookup(geoshapeLookupCategory, _url), isNull);
  });

  group('refGeojsonFromHookResult', () {
    test('rejects a plaintext url — this one is fetched, not handed to the platform', () {
      expect(refGeojsonFromHookResult({'url': 'http://az.sotl.as/W2/GC/116.geojson'}, type: 'sotaActivation'), isNull);
    });

    test('takes the defaults when a hook names no ages', () {
      final source = refGeojsonFromHookResult({'url': _url}, type: 'sotaActivation');
      expect(source?.maxAge, const Duration(days: 30));
      expect(source?.missMaxAge, const Duration(days: 1));
    });

    test('ignores a non-positive age instead of honoring it', () {
      // Honored, a zero would re-fetch on every rebuild of the map — a
      // request per keystroke in the search field above it.
      final source = refGeojsonFromHookResult({'url': _url, 'maxAgeInDays': 0, 'missMaxAgeInDays': -1}, type: 'sotaActivation');
      expect(source?.maxAge, const Duration(days: 30));
      expect(source?.missMaxAge, const Duration(days: 1));
    });

    test('ignores an age too vast to be one, instead of throwing', () {
      // Converting a day count this large overflows and throws — and the
      // reference's answer is read in the same pass as every other on the map,
      // so one program's wild number would cost them all their outlines.
      final source = refGeojsonFromHookResult({'url': _url, 'maxAgeInDays': 1e308}, type: 'sotaActivation');
      expect(source?.maxAge, const Duration(days: 30));
    });

    test('reads a fractional age, so a program can ask for hours', () {
      expect(refGeojsonFromHookResult({'url': _url, 'missMaxAgeInDays': 0.5}, type: 'sotaActivation')?.missMaxAge, const Duration(hours: 12));
    });

    test('credits the source a hook names, and the url\'s host when it names none', () {
      // Every outline on a map is credited to someone: a blank or missing
      // name falls back to the server, never to an empty credit line.
      expect(refGeojsonFromHookResult({'url': _url, 'sourceName': ' OSM '}, type: 'pota')?.sourceName, 'OSM');
      expect(refGeojsonFromHookResult({'url': _url}, type: 'sotaActivation')?.sourceName, 'az.sotl.as');
      expect(refGeojsonFromHookResult({'url': _url, 'sourceName': '  '}, type: 'sotaActivation')?.sourceName, 'az.sotl.as');
      expect(refGeojsonFromHookResult({'url': _url, 'sourceName': 42}, type: 'sotaActivation')?.sourceName, 'az.sotl.as');
    });
  });
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Spot feeds and spot posting, over a stubbed transport.
//
// These could not be written until `ExtensionHost.start` grew an `httpClient`
// seam, and their absence had already cost something real: WWBOTA's spot POST
// body was written from inference, was wrong in a way that posted spots
// carrying no bunker at all, and survived to code review because nothing could
// observe the request.
//
// The seam sits BELOW the interesting code on purpose — the manifest allowlist,
// the https requirement and the canonical User-Agent all still run, so this
// exercises the real path and not a mock of it.

import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  requireBundles();

  /// Captures every request and answers each with [body].
  ({List<http.Request> sent, MockClient client}) recorder(String body, {int status = 200}) {
    final sent = <http.Request>[];
    return (
      sent: sent,
      client: MockClient((request) async {
        sent.add(request);
        return http.Response(body, status, headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );
  }

  Future<ExtensionHost> hostWith(String key, List<String> domains, http.Client client) async {
    final host = await ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: [ExtensionBundle(key: key, source: bundleSource(key))],
      fetchAllowlists: {key: domains},
      httpClient: client,
      userAgent: 'Ham2K-Test/1.0',
      onHostCall: nullHostCall,
    );
    addTearDown(host.dispose);
    return host;
  }

  group('wwbota feed', () {
    test('converts MHz to kHz and types the references', () async {
      // The only feed in this batch publishing MHz; the rest of HaLo works in
      // kHz, so a missed conversion puts every spot on the wrong band.
      final rec = recorder('[{"call":"g1abc","freq":14.285,"mode":"ssb",'
          '"time":"2026-07-01T12:00:00Z","type":"Live","comment":"B/G-0001",'
          '"spotter":"G1ABC","references":[{"reference":"B/G-0001"}]}]');
      final host = await hostWith('wwbota', ['api.wwbota.org'], rec.client);

      final spots = (await host.invokeHook('spots', key: 'wwbota', method: 'fetchSpots',
          args: {'online': true}, timeout: const Duration(seconds: 20)) as List).cast<Map>();

      expect(spots.length, 1);
      expect(spots.first['freq'], 14285);
      expect(spots.first['band'], '20m');
      expect((spots.first['their'] as Map)['call'], 'G1ABC');
      expect((spots.first['refs'] as List).first, {'ref': 'B/G-0001', 'type': 'wwbota'});
      expect(((spots.first['spot'] as Map)['sourceInfo'] as Map)['spotter'], 'G1ABC');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('the canonical User-Agent is stamped on the request', () async {
      // Proof the seam is below the host's own behaviour rather than replacing
      // it: an extension cannot quietly become anonymous by being tested.
      final rec = recorder('[]');
      final host = await hostWith('wwbota', ['api.wwbota.org'], rec.client);
      await host.invokeHook('spots', key: 'wwbota', method: 'fetchSpots',
          args: {'online': true}, timeout: const Duration(seconds: 20));

      expect(rec.sent.single.headers['User-Agent'], 'Ham2K-Test/1.0');
      expect(rec.sent.single.url.host, 'api.wwbota.org');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('wwbota posting', () {
    Future<Map<String, dynamic>> postedBodyFor(Map<String, dynamic> args, String method) async {
      final rec = recorder('{}', status: 201);
      final host = await hostWith('wwbota', ['api.wwbota.org'], rec.client);
      final result = await host.invokeHook('spots', key: 'wwbota', method: method,
          args: args, timeout: const Duration(seconds: 20)) as Map;
      expect(result['ok'], true, reason: 'post should succeed');
      return jsonDecode(rec.sent.single.body) as Map<String, dynamic>;
    }

    test('references go in the COMMENT, grouped by scheme', () async {
      // This is the bug that got here uncaught: the endpoint takes ONE FLAT
      // RECORD. A `references` array posts a spot carrying no bunker at all.
      final body = await postedBodyFor({
        'operation': {
          'stationCall': 'G1ABC',
          'refs': [
            {'type': 'wwbotaActivation', 'ref': 'B/G-0001'},
            {'type': 'wwbotaActivation', 'ref': 'B/G-0002'},
          ],
        },
        'freq': 14285,
        'mode': 'SSB',
        'comment': 'up 5',
      }, 'postSelfSpot');

      expect(body['comment'], 'B/G-0001,0002 up 5');
      expect(body.containsKey('references'), isFalse);
      // MHz, like the feed.
      expect(body['freq'], closeTo(14.285, 0.0001));
      expect(body['type'], 'Live');
      // The activator spots themselves.
      expect(body['spotter'], 'G1ABC');
      expect(body['call'], 'G1ABC');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('QRT is read out of the comment, and an unknown mode stays null', () async {
      final body = await postedBodyFor({
        'operation': {'stationCall': 'G1ABC', 'refs': [{'type': 'wwbotaActivation', 'ref': 'B/G-0001'}]},
        'freq': 14285,
        'comment': 'QRT',
      }, 'postSelfSpot');

      expect(body['type'], 'QRT');
      // Null rather than a guessed SSB — the feed would rather know.
      expect(body['mode'], isNull);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('spotting somebody else names them, and us as the spotter', () async {
      final body = await postedBodyFor({
        'qso': {
          'their': {'call': 'M0XYZ'},
          'our': {'call': 'G1ABC'},
          'freq': 7120,
          'mode': 'SSB',
          'refs': [{'type': 'wwbota', 'ref': 'B/G-0511'}],
        },
        'comment': 'loud',
      }, 'postOtherSpot');

      expect(body['call'], 'M0XYZ');
      expect(body['spotter'], 'G1ABC');
      expect(body['comment'], 'B/G-0511 loud');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('an in-progress QSO with no callsign of our own omits the spotter', () async {
      // Rather than naming the SPOTTED station as its own spotter, which would
      // be a plain lie.
      final body = await postedBodyFor({
        'qso': {
          'their': {'call': 'M0XYZ'},
          'freq': 7120,
          'refs': [{'type': 'wwbota', 'ref': 'B/G-0511'}],
        },
      }, 'postOtherSpot');

      expect(body.containsKey('spotter'), isFalse);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('an EMPTY callsign of our own still falls back to the spotter', () async {
      // The case a `??` chain misses: absent falls back, `''` does not, and the
      // operator's own callsign is silently dropped instead of used.
      final body = await postedBodyFor({
        'qso': {
          'their': {'call': 'M0XYZ'},
          'our': {'call': ''},
          'freq': 7120,
          'refs': [{'type': 'wwbota', 'ref': 'B/G-0511'}],
        },
        'spotterCall': 'G1ABC',
      }, 'postOtherSpot');

      expect(body['spotter'], 'G1ABC');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  test('zlota folds one row per reference back into one spot', () async {
    // The feed emits a ROW PER REFERENCE, so a station at two places arrives as
    // two rows sharing an id. Left unfolded they show as two spots for the same
    // station on the same frequency.
    final rec = recorder('['
        '{"id":7,"activator":"zl1abc","reference":"ZLH/AA-001","frequency":"14285",'
        '"mode":"SSB","referenced_time":"2026-07-01T12:00:00Z","name":"Angelus Hut"},'
        '{"id":7,"activator":"zl1abc","reference":"ZLI/AA-002","frequency":"14285",'
        '"mode":"SSB","referenced_time":"2026-07-01T12:00:00Z","name":"Some Island"}'
        ']');
    final host = await hostWith('zlota', ['ontheair.nz'], rec.client);

    final spots = (await host.invokeHook('spots', key: 'zlota', method: 'fetchSpots',
        args: {'online': true}, timeout: const Duration(seconds: 20)) as List).cast<Map>();

    expect(spots.length, 1);
    expect((spots.first['refs'] as List).length, 2);
    expect((spots.first['their'] as Map)['call'], 'ZL1ABC');
    // With more than one reference the label lists them rather than naming one.
    expect((spots.first['spot'] as Map)['label'], 'ZLI/AA-002 ZLH/AA-001');
  }, timeout: const Timeout(Duration(seconds: 60)));

  group('the cqgma family', () {
    test('posts a form body — QuickJS has no URLSearchParams', () async {
      // This threw `URLSearchParams is not defined` at the first real spot, and
      // shipped that way through two steps of the port because nothing could
      // reach the request. Six awards post through this one endpoint.
      final rec = recorder('OK');
      final host = await hostWith('gma', ['www.cqgma.org'], rec.client);

      final result = await host.invokeHook('spots', key: 'gma', method: 'postSelfSpot', args: {
        'operation': {'stationCall': 'DL1ABC', 'refs': [{'type': 'gmaActivation', 'ref': 'DL/AL-001'}]},
        'freq': 14285,
        'mode': 'SSB',
        'comment': 'up 5',
      }, timeout: const Duration(seconds: 20)) as Map;

      expect(result['ok'], true);
      final request = rec.sent.single;
      expect(request.headers['Content-Type'], contains('application/x-www-form-urlencoded'));
      // Spaces as `+`, matching what app-polo's URLSearchParams produced and
      // what the endpoint has always been fed.
      expect(request.body, contains('ycall=DL1ABC'));
      expect(request.body, contains('yreference=DL%2FAL-001'));
      expect(request.body, contains('ycomment=up+5'));
      expect(request.body, contains('B1=Submit'));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('spots the first reference and names the rest in the comment', () async {
      // The endpoint takes ONE reference; app-polo puts the others in the
      // comment rather than dropping them.
      final rec = recorder('OK');
      final host = await hostWith('gma', ['www.cqgma.org'], rec.client);

      await host.invokeHook('spots', key: 'gma', method: 'postSelfSpot', args: {
        'operation': {
          'stationCall': 'DL1ABC',
          'refs': [
            {'type': 'gmaActivation', 'ref': 'DL/AL-001'},
            {'type': 'gmaActivation', 'ref': 'DL/AL-002'},
          ],
        },
        'freq': 14285,
      }, timeout: const Duration(seconds: 20));

      expect(rec.sent.single.body, contains('yreference=DL%2FAL-001'));
      expect(rec.sent.single.body, contains('also+DL%2FAL-002'));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('an EMPTY callsign of our own still falls back to the spotter', () async {
      // The case `??` misses. An absent `our.call` fell back correctly and was
      // tested; an empty STRING did not, and posted `yspotter=` — a spot that
      // reads on the cluster as one nobody sent. `models.dart`'s `ourCall`
      // getter coerces a null column to '', so that is the likelier shape of
      // "no callsign yet" of the two.
      final rec = recorder('OK');
      final host = await hostWith('gma', ['www.cqgma.org'], rec.client);

      Future<String> spotWith(Map<String, dynamic>? our) async {
        rec.sent.clear();
        await host.invokeHook('spots', key: 'gma', method: 'postOtherSpot', args: {
          'qso': {
            'their': {'call': 'M0XYZ'},
            'our': ?our,
            'freq': 7120,
            'mode': 'SSB',
            'refs': [{'type': 'gma', 'ref': 'DL/AL-001'}],
          },
          'spotterCall': 'DL1ABC',
        }, timeout: const Duration(seconds: 20));
        return rec.sent.single.body;
      }

      expect(await spotWith(null), contains('yspotter=DL1ABC'));
      expect(await spotWith({'call': ''}), contains('yspotter=DL1ABC'));
      expect(await spotWith({'call': '  '}), contains('yspotter=DL1ABC'));
      expect(await spotWith({'call': 'G1ABC'}), contains('yspotter=G1ABC'));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a QSO with no callsign is refused rather than spotted blank', () async {
      // Guarded like the frequency already was, and for the same reason: an
      // empty `ycall` reaches everybody watching the cluster.
      final rec = recorder('OK');
      final host = await hostWith('gma', ['www.cqgma.org'], rec.client);

      final result = await host.invokeHook('spots', key: 'gma', method: 'postOtherSpot', args: {
        'qso': {
          'their': {'call': ''},
          'freq': 7120,
          'refs': [{'type': 'gma', 'ref': 'DL/AL-001'}],
        },
        'spotterCall': 'DL1ABC',
      }, timeout: const Duration(seconds: 20)) as Map;

      expect(result['ok'], false);
      expect(rec.sent, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('the key-gated awards', () {
    // Every field name below is transcribed from app-polo's own request
    // builders, not inferred. Inferring them is how three of these shipped
    // wrong: LLOTA posted to the feed's collection instead of `spots/spot`,
    // and TOTA both read and wrote field names the API has never used.

    test('wwff posts the fields the award names', () async {
      final rec = recorder('{}', status: 201);
      final host = await ExtensionHost.start(
        kernelSource: bundleSource('kernel'),
        extensions: [ExtensionBundle(key: 'wwff', source: bundleSource('wwff'))],
        secrets: const {'wwff': {'WWFF_API_KEY': 'k'}},
        fetchAllowlists: const {'wwff': ['wwff.co', 'spots.wwff.co']},
        httpClient: rec.client,
        onHostCall: (m, p) async => null,
      );
      addTearDown(host.dispose);

      final result = await host.invokeHook('spots', key: 'wwff', method: 'postSelfSpot', args: {
        'operation': {'stationCall': 'W1AW', 'refs': [{'type': 'wwffActivation', 'ref': 'KFF-0001'}]},
        'freq': 14285,
        'mode': 'SSB',
        'comment': 'up 5',
      }, timeout: const Duration(seconds: 20)) as Map;

      expect(result['ok'], true);
      final body = jsonDecode(rec.sent.single.body) as Map<String, dynamic>;
      expect(rec.sent.single.url.path, '/api/spots/add');
      expect(body['activator'], 'W1AW');
      expect(body['reference'], 'KFF-0001');
      expect(body['frequency_khz'], 14285);
      expect(body['remarks'], 'up 5');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('llota posts to spots/spot with operator_callsign, not the feed collection', () async {
      final rec = recorder('{}', status: 201);
      final host = await ExtensionHost.start(
        kernelSource: bundleSource('kernel'),
        extensions: [ExtensionBundle(key: 'llota', source: bundleSource('llota'))],
        secrets: const {'llota': {'LLOTA_API_KEY': 'k'}},
        fetchAllowlists: const {'llota': ['llota.app']},
        httpClient: rec.client,
        onHostCall: (m, p) async => null,
      );
      addTearDown(host.dispose);

      await host.invokeHook('spots', key: 'llota', method: 'postSelfSpot', args: {
        'operation': {
          'stationCall': 'W1AW',
          'refs': [
            {'type': 'llotaActivation', 'ref': 'LLUS-0001'},
            {'type': 'llotaActivation', 'ref': 'LLUS-0002'},
          ],
        },
        'freq': 14285,
      }, timeout: const Duration(seconds: 20));

      // `spots/spot`, not `spots` — that one is the feed, and POSTing to it
      // silently does nothing useful.
      expect(rec.sent.single.url.path, '/api/public/spots/spot');
      final body = jsonDecode(rec.sent.single.body) as Map<String, dynamic>;
      expect(body['callsign'], 'W1AW');
      expect(body['operator_callsign'], 'W1AW');
      expect(body['reference'], 'LLUS-0001');
      // The endpoint takes one lake, so the rest go in the comment.
      expect(body['comments'], contains('2-fer: LLUS-0001 LLUS-0002'));
      expect(body['source'], isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('tota reads its spots out of the feed envelope, not off a bare array', () async {
      // The trap the port fell into: `cluster.php` answers
      // `{api, version, generated_utc, count, spots, error}`, and mapping the
      // parsed body directly throws `not a function` before a single spot is
      // read — the whole source reports failed and the board shows no TOTA at
      // all. The field-by-field mapping and the age/QRT/dedupe chain are
      // covered by extensions/activities/tota/src/spotMapping.test.ts; this
      // one exists to hold the SHAPE the live award actually sends.
      //
      // A live timestamp, because the mapping drops anything over an hour old
      // and a fixed date would age past the cutoff the day after it was
      // written.
      final recent = nowUtc().subtract(const Duration(minutes: 5)).toIso8601String();
      final rec = recorder('{"api":"TOTA Cluster","version":"1.0","count":1,"error":null,'
          '"spots":[{"callsign":"ok1abc","frequency":14285,"mode":"ssb",'
          '"tower_ref":"OKR-0001","time_utc":"$recent","comment":"hi"}]}');
      final host = await ExtensionHost.start(
        kernelSource: bundleSource('kernel'),
        extensions: [ExtensionBundle(key: 'tota', source: bundleSource('tota'))],
        secrets: const {'tota': {'TOTA_API_KEY': 'k'}},
        fetchAllowlists: const {'tota': ['rozhledny.eu', 'www.rozhledny.eu']},
        httpClient: rec.client,
        onHostCall: (m, p) async => null,
      );
      addTearDown(host.dispose);

      final spots = (await host.invokeHook('spots', key: 'tota', method: 'fetchSpots',
          args: {'online': true}, timeout: const Duration(seconds: 20)) as List).cast<Map>();

      expect((spots.single['their'] as Map)['call'], 'OK1ABC');
      expect(spots.single['freq'], 14285);
      expect((spots.single['refs'] as List).single, {'ref': 'OKR-0001', 'type': 'tota'});
      expect((spots.single['spot'] as Map)['timeInMillis'], isNot(0));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('tota reports a refusal the cluster dresses as success', () async {
      // The cluster answers a missing or expired key with HTTP **200** and an
      // `error` code — the tower list 401s, this one does not. Reading only
      // `spots` turns a dead key into a permanently quiet band: the panel
      // treats a source that answered with no spots as a genuinely empty one,
      // clears what it held and reports the source healthy, so nothing on
      // either side of the bridge ever says the key stopped working. Exactly
      // the silence this card was opened for.
      final rec = recorder('{"api":"TOTA Cluster","version":"1.0","count":0,'
          '"spots":[],"error":"invalid_api_key"}');
      final host = await ExtensionHost.start(
        kernelSource: bundleSource('kernel'),
        extensions: [ExtensionBundle(key: 'tota', source: bundleSource('tota'))],
        secrets: const {'tota': {'TOTA_API_KEY': 'k'}},
        fetchAllowlists: const {'tota': ['rozhledny.eu', 'www.rozhledny.eu']},
        httpClient: rec.client,
        onHostCall: (m, p) async => null,
      );
      addTearDown(host.dispose);

      await expectLater(
        host.invokeHook('spots', key: 'tota', method: 'fetchSpots',
            args: {'online': true}, timeout: const Duration(seconds: 20)),
        throwsA(predicate((e) => '$e'.contains('invalid_api_key'))),
      );
      // The key rides in the query string, so the refusal may name the award's
      // own code but never the URL that carried it.
      expect('${rec.sent.single.url}', isNot(contains('invalid_api_key')));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('tota self-spots with a POST body, one per tower', () async {
      final rec = recorder('{}');
      final host = await ExtensionHost.start(
        kernelSource: bundleSource('kernel'),
        extensions: [ExtensionBundle(key: 'tota', source: bundleSource('tota'))],
        // Nothing injected: TOTA's key is a constant in its own bundle.
        secrets: const {},
        fetchAllowlists: const {'tota': ['rozhledny.eu', 'www.rozhledny.eu']},
        httpClient: rec.client,
        onHostCall: (m, p) async => null,
      );
      addTearDown(host.dispose);

      final result = await host.invokeHook('spots', key: 'tota', method: 'postSelfSpot', args: {
        'operation': {
          'stationCall': 'OK1ABC',
          'refs': [
            {'type': 'totaActivation', 'ref': 'OKR-0001'},
            {'type': 'totaActivation', 'ref': 'OKR-0002'},
          ],
        },
        'freq': 14285,
        'mode': 'SSB',
      }, timeout: const Duration(seconds: 20)) as Map;

      expect(result['ok'], true);
      // The endpoint takes a single tower_ref, so an n-fer is several posts.
      expect(rec.sent.length, 2);
      expect(rec.sent.first.method, 'POST');
      // Only the KEY rides in the query string — asserted as present, never
      // against the literal, which lives in the extension and nowhere else.
      expect(rec.sent.first.url.queryParameters['key'], isNotEmpty);
      expect(rec.sent.first.url.queryParameters.keys, ['key']);
      final body = jsonDecode(rec.sent.first.body) as Map<String, dynamic>;
      expect(body['callsign'], 'OK1ABC');
      expect(body['tower_ref'], 'OKR-0001');
      expect(body['frequency'], 14285);
      expect(jsonDecode(rec.sent[1].body)['tower_ref'], 'OKR-0002');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('what the award considers a failure', () {
    // All three divergences found by reading app-polo's own `*PostSelfSpot.js`
    // rather than the API docs. Each makes HaLo stricter than the award is, and
    // each is invisible until an operator is standing on a hill wondering why
    // the app says their spot failed.

    Future<ExtensionHost> keyed(String key, List<String> domains, http.Client client) async {
      final host = await ExtensionHost.start(
        kernelSource: bundleSource('kernel'),
        extensions: [ExtensionBundle(key: key, source: bundleSource(key))],
        secrets: {key: {'${key.toUpperCase()}_API_KEY': 'k'}},
        fetchAllowlists: {key: domains},
        httpClient: client,
        onHostCall: (m, p) async => null,
      );
      addTearDown(host.dispose);
      return host;
    }

    test('an unset mode is sent as null, not guessed as SSB', () async {
      // app-polo passes `vfo.mode` straight through for both of these. Telling
      // the cluster SSB when the activator is on CW sends hunters to the wrong
      // mode. (LLOTA is the exception and keeps its default — polo's own
      // LLOTAPostSpotAPI really does write `mode ?? 'SSB'`.)
      final wwff = recorder('{}');
      await (await keyed('wwff', ['wwff.co', 'spots.wwff.co'], wwff.client))
          .invokeHook('spots', key: 'wwff', method: 'postSelfSpot', args: {
        'operation': {'stationCall': 'W1AW', 'refs': [{'type': 'wwffActivation', 'ref': 'KFF-0001'}]},
        'freq': 14285,
      }, timeout: const Duration(seconds: 20));
      expect(jsonDecode(wwff.sent.single.body)['mode'], isNull);

      final tota = recorder('{}');
      await (await keyed('tota', ['rozhledny.eu', 'www.rozhledny.eu'], tota.client))
          .invokeHook('spots', key: 'tota', method: 'postSelfSpot', args: {
        'operation': {'stationCall': 'OK1ABC', 'refs': [{'type': 'totaActivation', 'ref': 'OKR-0001'}]},
        'freq': 14285,
      }, timeout: const Duration(seconds: 20));
      expect(jsonDecode(tota.sent.single.body)['mode'], isNull);
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('a duplicate spot is a success, not an error', () async {
      // Re-spotting is routine — a new comment, back after a break. app-polo
      // matches these messages by name and swallows them; reporting them paints
      // a red failure over a spot that is fine, and invites a pointless retry.
      final wwff = recorder('{"message":"Duplicate spot detected"}', status: 400);
      final wwffResult = await (await keyed('wwff', ['wwff.co', 'spots.wwff.co'], wwff.client))
          .invokeHook('spots', key: 'wwff', method: 'postSelfSpot', args: {
        'operation': {'stationCall': 'W1AW', 'refs': [{'type': 'wwffActivation', 'ref': 'KFF-0001'}]},
        'freq': 14285, 'mode': 'SSB',
      }, timeout: const Duration(seconds: 20)) as Map;
      expect(wwffResult['ok'], true);

      final tota = recorder('{"message":"Duplicate self-spot"}', status: 400);
      final totaResult = await (await keyed('tota', ['rozhledny.eu', 'www.rozhledny.eu'], tota.client))
          .invokeHook('spots', key: 'tota', method: 'postSelfSpot', args: {
        'operation': {'stationCall': 'OK1ABC', 'refs': [{'type': 'totaActivation', 'ref': 'OKR-0001'}]},
        'freq': 14285, 'mode': 'SSB',
      }, timeout: const Duration(seconds: 20)) as Map;
      expect(totaResult['ok'], true);

      // A real error is still an error.
      final broken = recorder('{"message":"Bad reference"}', status: 400);
      final brokenResult = await (await keyed('tota', ['rozhledny.eu', 'www.rozhledny.eu'], broken.client))
          .invokeHook('spots', key: 'tota', method: 'postSelfSpot', args: {
        'operation': {'stationCall': 'OK1ABC', 'refs': [{'type': 'totaActivation', 'ref': 'OKR-0001'}]},
        'freq': 14285, 'mode': 'SSB',
      }, timeout: const Duration(seconds: 20)) as Map;
      expect(brokenResult['ok'], false);
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('every tower is attempted even when one fails, and the failure is named', () async {
      // The one that compounds: TOTA posts one request per tower, and returning
      // early left a tower the operator IS activating unspotted, with nothing
      // saying which. Tower 2 fails here; tower 3 must still go out.
      final sent = <http.Request>[];
      final client = MockClient((request) async {
        sent.add(request);
        final ref = jsonDecode(request.body)['tower_ref'];
        return ref == 'OKR-0002'
            ? http.Response('{"message":"Server exploded"}', 500)
            : http.Response('{}', 200);
      });
      final host = await keyed('tota', ['rozhledny.eu', 'www.rozhledny.eu'], client);

      final result = await host.invokeHook('spots', key: 'tota', method: 'postSelfSpot', args: {
        'operation': {
          'stationCall': 'OK1ABC',
          'refs': [
            {'type': 'totaActivation', 'ref': 'OKR-0001'},
            {'type': 'totaActivation', 'ref': 'OKR-0002'},
            {'type': 'totaActivation', 'ref': 'OKR-0003'},
          ],
        },
        'freq': 14285, 'mode': 'SSB',
      }, timeout: const Duration(seconds: 20)) as Map;

      expect(sent.length, 3, reason: 'all three towers attempted');
      expect(sent.map((r) => jsonDecode(r.body)['tower_ref']), ['OKR-0001', 'OKR-0002', 'OKR-0003']);
      expect(result['ok'], false);
      // Named, because "one of your three failed" is not actionable. The URL
      // carries the key and must never appear here.
      expect(result['message'], contains('OKR-0002'));
      expect(result['message'], isNot(contains('key=')));
    }, timeout: const Timeout(Duration(seconds: 90)));
  });

  group('an empty callsign is not a callsign', () {
    // The case a `??` chain misses everywhere it appears: `'' ?? fallback` is
    // `''`, so an empty string defeats the fallback that an ABSENT key takes
    // correctly. `models.dart`'s `ourCall` getter coerces a null column to '',
    // which is the likelier of the two shapes for "no callsign yet".
    //
    // Two consequences, both silent: the operator's own callsign is dropped
    // instead of used as the spotter, and a spot can go out naming no station
    // at all — which reaches everybody watching.

    Future<ExtensionHost> keyed(String key, List<String> domains, http.Client client) async {
      final host = await ExtensionHost.start(
        kernelSource: bundleSource('kernel'),
        extensions: [ExtensionBundle(key: key, source: bundleSource(key))],
        secrets: {key: {'${key.toUpperCase()}_API_KEY': 'k'}},
        fetchAllowlists: {key: domains},
        httpClient: client,
        onHostCall: (m, p) async => null,
      );
      addTearDown(host.dispose);
      return host;
    }

    test('wwff falls back to the spotter rather than dropping it', () async {
      final rec = recorder('{}');
      final host = await keyed('wwff', ['wwff.co', 'spots.wwff.co'], rec.client);

      await host.invokeHook('spots', key: 'wwff', method: 'postOtherSpot', args: {
        'qso': {
          'their': {'call': 'M0XYZ'},
          'our': {'call': ''},
          'freq': 7120,
          'refs': [{'type': 'wwff', 'ref': 'GFF-0001'}],
        },
        'spotterCall': 'W1AW',
      }, timeout: const Duration(seconds: 20));

      expect(rec.sent.single.body, contains('W1AW'));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('llota falls back to the spotter rather than dropping it', () async {
      final rec = recorder('{}', status: 201);
      final host = await keyed('llota', ['llota.app'], rec.client);

      await host.invokeHook('spots', key: 'llota', method: 'postOtherSpot', args: {
        'qso': {
          'their': {'call': 'M0XYZ'},
          'our': {'call': '  '},
          'freq': 7120,
          'refs': [{'type': 'llota', 'ref': 'LLUS-0001'}],
        },
        'spotterCall': 'W1AW',
      }, timeout: const Duration(seconds: 20));

      expect(jsonDecode(rec.sent.single.body)['operator_callsign'], 'W1AW');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('none of them post a spot naming no station', () async {
      // TOTA has no spotter field of its own, so the empty CALLSIGN is the
      // whole exposure there — and it is the one that reaches the cluster.
      for (final (key, domains, hunting) in [
        ('wwff', ['wwff.co', 'spots.wwff.co'], 'wwff'),
        ('llota', ['llota.app'], 'llota'),
        ('tota', ['rozhledny.eu', 'www.rozhledny.eu'], 'tota'),
      ]) {
        final rec = recorder('{}');
        final host = await keyed(key, domains, rec.client);

        final result = await host.invokeHook('spots', key: key, method: 'postOtherSpot', args: {
          'qso': {
            'their': {'call': ''},
            'freq': 7120,
            'refs': [{'type': hunting, 'ref': 'X-0001'}],
          },
          'spotterCall': 'W1AW',
        }, timeout: const Duration(seconds: 20)) as Map;

        expect(result['ok'], false, reason: '$key should refuse');
        expect(rec.sent, isEmpty, reason: '$key should send nothing');
      }
    }, timeout: const Timeout(Duration(seconds: 120)));
  });

  group('the sota epoch gate', () {
    // The endpoint answers a bare UUID, and the extension requires that shape
    // before it will trust one — see the bogus-body test below.
    const epochOne = 'ed0601ac-a1f9-4666-98ba-2b0e52c07f5e';
    const epochTwo = '11112222-3333-4444-5555-666677778888';
    const sotaSpots = '[{"id":1,"timeStamp":"2026-08-05T21:46:18.348572Z","comments":"",'
        '"callsign":"N0SPOT","summitCode":"W7O/WV-096","summitName":"Sylvania, Mount",'
        '"activatorCallsign":"KK7ER","activatorName":"Michael","frequency":14.062,"mode":"cw",'
        '"points":1,"AltM":297,"AltFt":975,"type":null,"epoch":"ed0601ac-a1f9-4666-98ba-2b0e52c07f5e"}]';

    /// Answers `/spots/epoch` from [epochs], one entry per call, and every
    /// other request with the spot list. Recording the paths is the point:
    /// what this gate does is NOT send a request.
    ({List<String> paths, MockClient client}) sotaRecorder(List<String> epochs,
        {int epochStatus = 200, bool epochThrows = false}) {
      final paths = <String>[];
      var call = 0;
      return (
        paths: paths,
        client: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path.endsWith('/epoch')) {
            if (epochThrows) throw http.ClientException('connection reset', request.url);
            final epoch = epochs[call < epochs.length ? call : epochs.length - 1];
            call++;
            return http.Response(epoch, epochStatus, headers: {'content-type': 'text/plain'});
          }
          return http.Response(sotaSpots, 200, headers: {'content-type': 'application/json'});
        }),
      );
    }

    Future<List> fetchSota(ExtensionHost host) async =>
        (await host.invokeHook('spots', key: 'sota', method: 'fetchSpots',
            args: {'online': true}, timeout: const Duration(seconds: 20)) as List);

    test('an unchanged epoch answers from cache without asking for spots again', () async {
      // The point of the whole gate: SpotsService polls every two minutes for
      // as long as an operation is open, and SOTAwatch only moves the epoch
      // when a spot actually changes.
      final rec = sotaRecorder([epochOne, epochOne]);
      final host = await hostWith('sota', ['api-db2.sota.org.uk'], rec.client);

      final first = await fetchSota(host);
      final second = await fetchSota(host);

      expect(first.length, 1);
      expect(second, first, reason: 'the cached list must be the same spots, not an empty one');
      expect(rec.paths.where((p) => !p.endsWith('/epoch')).length, 1,
          reason: 'the second poll should have cost one epoch request and nothing else');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a moved epoch fetches the spots again', () async {
      // The other half: a gate that never reopens would freeze the board.
      final rec = sotaRecorder([epochOne, epochTwo]);
      final host = await hostWith('sota', ['api-db2.sota.org.uk'], rec.client);

      await fetchSota(host);
      await fetchSota(host);

      expect(rec.paths.where((p) => !p.endsWith('/epoch')).length, 2);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('an epoch the server refuses costs the saving, not the spots', () async {
      final rec = sotaRecorder(['nope'], epochStatus: 503);
      final host = await hostWith('sota', ['api-db2.sota.org.uk'], rec.client);

      final spots = await fetchSota(host);

      expect(spots.length, 1, reason: 'a 503 body must not be mistaken for an epoch');
      expect(rec.paths.where((p) => !p.endsWith('/epoch')).length, 1);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a 200 that is not a UUID never becomes the epoch', () async {
      // A captive portal or proxy answering 200 with a constant page would
      // otherwise pin the epoch to it: every later poll short-circuits, the
      // spots request never runs so nothing can throw, and the board freezes
      // silently instead of reporting an error.
      final rec = sotaRecorder(const ['<html>Sign in to continue</html>']);
      final host = await hostWith('sota', ['api-db2.sota.org.uk'], rec.client);

      await fetchSota(host);
      final second = await fetchSota(host);

      expect(second.length, 1, reason: 'the board must keep refreshing, not freeze on a bogus epoch');
      expect(rec.paths.where((p) => !p.endsWith('/epoch')).length, 2);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('an epoch request that throws costs the saving, not the spots', () async {
      // The host rethrows anything that isn't a DNS failure, so without the
      // catch a reset connection on the OPTIMISATION request empties the
      // board of SOTA spots for that cycle while the spots endpoint is fine.
      final rec = sotaRecorder(const [], epochThrows: true);
      final host = await hostWith('sota', ['api-db2.sota.org.uk'], rec.client);

      final spots = await fetchSota(host);

      expect(spots.length, 1);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('one stalled source', () {
    const potaSpots = '[{"spotId":1,"activator":"KI2D","frequency":"14285","mode":"SSB",'
        '"reference":"US-1234","name":"Somewhere","locationDesc":"US-CA",'
        '"spotTime":"2026-08-05T21:46:18","spotter":"N0SPOT","comments":"","source":"Web","count":1}]';

    /// POTA answers at once; SOTA's spots request never completes, the way a
    /// server that accepted the connection and then went quiet behaves. Its
    /// epoch probe still answers, so the stall lands on the request that
    /// matters rather than being absorbed by the probe's own timeout.
    ({MockClient client}) potaFastSotaStalled() => (
          client: MockClient((request) async {
            if (request.url.host == 'api.pota.app') {
              return http.Response(potaSpots, 200, headers: {'content-type': 'application/json'});
            }
            if (request.url.path.endsWith('/epoch')) {
              return http.Response('ed0601ac-a1f9-4666-98ba-2b0e52c07f5e', 200,
                  headers: {'content-type': 'text/plain'});
            }
            return Completer<http.Response>().future; // never settles
          }),
        );

    Future<ExtensionHost> hostWithBoth(http.Client client) async {
      final host = await ExtensionHost.start(
        kernelSource: bundleSource('kernel'),
        extensions: [
          ExtensionBundle(key: 'pota', source: bundleSource('pota')),
          ExtensionBundle(key: 'sota', source: bundleSource('sota')),
        ],
        fetchAllowlists: const {
          'pota': ['api.pota.app'],
          'sota': ['api-db2.sota.org.uk'],
        },
        httpClient: client,
        userAgent: 'Ham2K-Test/1.0',
        onHostCall: nullHostCall,
      );
      addTearDown(host.dispose);
      return host;
    }

    test('costs only its own spots, not everybody elses', () async {
      // The runtime answers a fan-out with ONE message, so without the
      // narration a host that stops waiting discards POTA's spots — finished
      // and sitting there — because SOTA never replied.
      final host = await hostWithBoth(potaFastSotaStalled().client);

      final entries = await host.invokeHookAll('spots',
          method: 'fetchSpots',
          args: {'online': true},
          timeout: const Duration(seconds: 3),
          partialOnTimeout: true);

      final byKey = {for (final e in entries) e['key']: e};
      expect(byKey.keys, containsAll(['pota', 'sota']));
      expect(byKey['pota']!['ok'], true, reason: 'POTA answered and must survive SOTA stalling');
      expect((byKey['pota']!['value'] as List), hasLength(1));
      expect(byKey['sota']!['ok'], false);
      expect(byKey['sota']!['timedOut'], true,
          reason: 'a source that never answered must be distinguishable from one that answered with an error');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a feed answering 503 is an error entry, not a timeout', () async {
      // The wire contract the operator-facing distinction rests on: an
      // unhappy server is `ok:false` with no `timedOut`, which is what lets
      // the app say "returned an error" rather than "did not respond" — the
      // second would have the operator waiting out a server that is up and
      // will still be refusing in ten minutes. A feed that swallowed its own
      // HTTP status and answered with an empty list would look identical to a
      // quiet band here, and nothing downstream could recover the difference.
      final host = await hostWithBoth(MockClient((request) async {
        if (request.url.host.contains('pota')) {
          return http.Response(potaSpots, 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('<html>down</html>', 503);
      }));

      final entries = await host.invokeHookAll('spots',
          method: 'fetchSpots', args: {'online': true}, timeout: const Duration(seconds: 20));

      final byKey = {for (final e in entries) e['key']: e};
      expect(byKey['sota']!['ok'], false);
      expect(byKey['sota']!['timedOut'], isNot(true), reason: 'answering badly is not failing to answer');
      expect(byKey['sota']!['error'], contains('503'));
      expect(byKey['pota']!['ok'], true, reason: "the healthy feed's spots must survive");
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('still throws when the caller did not ask for partial results', () async {
      // Partial results are wrong for most categories — half an ADIF field
      // set writes a silently incomplete export — so they stay opt-in.
      final host = await hostWithBoth(potaFastSotaStalled().client);

      await expectLater(
        host.invokeHookAll('spots',
            method: 'fetchSpots', args: {'online': true}, timeout: const Duration(seconds: 3)),
        throwsA(isA<HookTimeoutException>()),
      );
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('FetchOptions.timeout', () {
    test('an extension can give up on its own request before the host would', () async {
      // SOTA's epoch probe asks for 3s. Against a server that never answers
      // it, the probe is abandoned and the spots fetch still happens — where
      // the host's own 15s allowance would have spent the whole fan-out
      // budget on an optimisation.
      final paths = <String>[];
      final client = MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith('/epoch')) return Completer<http.Response>().future;
        return http.Response('[]', 200, headers: {'content-type': 'application/json'});
      });
      final host = await ExtensionHost.start(
        kernelSource: bundleSource('kernel'),
        extensions: [ExtensionBundle(key: 'sota', source: bundleSource('sota'))],
        fetchAllowlists: const {'sota': ['api-db2.sota.org.uk']},
        httpClient: client,
        userAgent: 'Ham2K-Test/1.0',
        onHostCall: nullHostCall,
      );
      addTearDown(host.dispose);

      final spots = await host.invokeHook('spots',
          key: 'sota', method: 'fetchSpots', args: {'online': true}, timeout: const Duration(seconds: 12)) as List;

      expect(spots, isEmpty);
      expect(paths.where((p) => !p.endsWith('/epoch')), hasLength(1),
          reason: 'the spots request must still be made after the probe is abandoned');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  test('a feed the manifest never declared is still blocked', () async {
    // The allowlist runs above the transport, so a stub does not become a way
    // around it.
    final rec = recorder('[]');
    final host = await hostWith('zlota', const [], rec.client);

    await expectLater(
      host.invokeHook('spots', key: 'zlota', method: 'fetchSpots',
          args: {'online': true}, timeout: const Duration(seconds: 20)),
      throwsA(anything),
    );
    expect(rec.sent, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));
}

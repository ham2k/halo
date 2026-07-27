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

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final assets = Directory('../../app/assets/extensions');
  File bundle(String key) => File('${assets.path}/$key.js');
  bool missing(String key) => !bundle('kernel').existsSync() || !bundle(key).existsSync();

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
      kernelSource: bundle('kernel').readAsStringSync(),
      extensions: [ExtensionBundle(key: key, source: bundle(key).readAsStringSync())],
      fetchAllowlists: {key: domains},
      httpClient: client,
      userAgent: 'Ham2K-Test/1.0',
      onHostCall: (method, params) async => null,
    );
    addTearDown(host.dispose);
    return host;
  }

  group('wwbota feed', () {
    test('converts MHz to kHz and types the references', () async {
      if (missing('wwbota')) {
        markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
        return;
      }
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
      if (missing('wwbota')) {
        markTestSkipped('bundles not built');
        return;
      }
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
      if (missing('wwbota')) {
        markTestSkipped('bundles not built');
        return;
      }
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
      if (missing('wwbota')) {
        markTestSkipped('bundles not built');
        return;
      }
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
      if (missing('wwbota')) {
        markTestSkipped('bundles not built');
        return;
      }
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
      if (missing('wwbota')) {
        markTestSkipped('bundles not built');
        return;
      }
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
      if (missing('wwbota')) {
        markTestSkipped('bundles not built');
        return;
      }
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
    if (missing('zlota')) {
      markTestSkipped('bundles not built');
      return;
    }
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
      if (missing('gma')) {
        markTestSkipped('bundles not built');
        return;
      }
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
      if (missing('gma')) {
        markTestSkipped('bundles not built');
        return;
      }
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
      if (missing('gma')) {
        markTestSkipped('bundles not built');
        return;
      }
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
            if (our != null) 'our': our,
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
      if (missing('gma')) {
        markTestSkipped('bundles not built');
        return;
      }
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

  test('a feed the manifest never declared is still blocked', () async {
    if (missing('zlota')) {
      markTestSkipped('bundles not built');
      return;
    }
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

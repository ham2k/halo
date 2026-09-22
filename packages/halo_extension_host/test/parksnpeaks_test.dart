// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ParksnPeaks — a spot source with no references of its own, feeding WWFF and
// SiOTA activity in VK/ZL and posting back to them.
//
// What each test here pins is a way the real service differs from what the
// code would look like if written from inference: the feed publishes MHz in a
// string, stamps UTC without saying so, misspells `actSpoter`, carries other
// awards' spots that HaLo already has from their own sources, and answers a
// REJECTED spot with HTTP 200.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  requireBundles();

  ({List<http.Request> sent, MockClient client}) recorder(String body, {int status = 200}) {
    final sent = <http.Request>[];
    return (
      sent: sent,
      client: MockClient((request) async {
        sent.add(request);
        return http.Response(body, status, headers: {'content-type': 'text/html; charset=utf-8'});
      }),
    );
  }

  /// The host call the kernel makes to resolve an extension's account. Null
  /// credentials is what a build with no ParksnPeaks login sees.
  Future<dynamic> Function(String, Map<String, dynamic>) accountCall(Map<String, String>? credentials) {
    return (method, params) async {
      if (method == 'getAccount') return credentials == null ? null : {'credentials': credentials};
      return null;
    };
  }

  Future<ExtensionHost> hostWith(http.Client client, {Map<String, String>? credentials}) async {
    final host = await ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: [ExtensionBundle(key: 'parksnpeaks', source: bundleSource('parksnpeaks'))],
      fetchAllowlists: const {
        'parksnpeaks': ['www.parksnpeaks.org'],
      },
      httpClient: client,
      userAgent: 'Ham2K-Test/1.0',
      onHostCall: accountCall(credentials),
    );
    addTearDown(host.dispose);
    return host;
  }

  Future<List<Map>> fetchSpots(http.Client client) async {
    final host = await hostWith(client);
    final result =
        await host.invokeHook('spots', key: 'parksnpeaks', method: 'fetchSpots', args: {'online': true}, timeout: const Duration(seconds: 20)) as List;
    return result.cast<Map>();
  }

  String spotJson({
    required String call,
    String cls = 'WWFF',
    String site = 'VKFF-1997',
    String freq = '7.160',
    String time = '2026-08-05 00:07:27',
    String mode = 'SSB',
    String location = 'Stony Creek Nature Reserve',
    String spotter = 'vk2vw',
    String comments = 'Calling now',
  }) =>
      '{"actTime":"$time","actSiteID":"$site","actCallsign":"$call","actMode":"$mode",'
      '"actFreq":"$freq","actClass":"$cls","actLocation":"$location",'
      '"actComments":"$comments","actSpoter":"$spotter"}';

  group('feed', () {
    test('reads MHz strings as kHz and the unmarked timestamp as UTC', () async {
      final rec = recorder('[${spotJson(call: 'vk2ozo')}]');
      final spots = await fetchSpots(rec.client);

      expect(spots.length, 1);
      // '7.160' is MHz in a string; everything downstream is kHz, so a missed
      // conversion puts the spot 1000x off and on no band at all.
      expect(spots.first['freq'], 7160);
      expect(spots.first['band'], '40m');
      expect((spots.first['their'] as Map)['call'], 'VK2OZO');
      expect((spots.first['refs'] as List).first, {'ref': 'VKFF-1997', 'type': 'wwff'});
      // `actTime` carries no 'Z' and no offset but IS UTC. Parsed as local
      // time, a VK activator lands hours away from now and sorts wrong.
      expect((spots.first['spot'] as Map)['timeInMillis'], DateTime.utc(2026, 8, 5, 0, 7, 27).millisecondsSinceEpoch);
      // The API's own spelling of "spotter" — matching the typo is what makes
      // the field arrive at all.
      expect(((spots.first['spot'] as Map)['sourceInfo'] as Map)['spotter'], 'VK2VW');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('keeps only WWFF and SiOTA, dropping the awards HaLo has its own source for', () async {
      // The endpoint is /ALL and answers with every class it knows. POTA and
      // SOTA arrive from their own extensions, so mapping these copies too
      // would show one activator twice with nothing marking them the same.
      final rec = recorder(
        '['
        '${spotJson(call: 'vk1aa', cls: 'WWFF', site: 'VKFF-0001')},'
        '${spotJson(call: 'vk1bb', cls: 'SiOTA', site: 'VK-SI0001')},'
        '${spotJson(call: 'vk1cc', cls: 'POTA', site: 'VK-0001')},'
        '${spotJson(call: 'vk1dd', cls: 'SOTA', site: 'VK1/AC-001')}'
        ']',
      );
      final spots = await fetchSpots(rec.client);

      expect(spots.map((s) => (s['their'] as Map)['call']), ['VK1AA', 'VK1BB']);
      expect(spots.map((s) => (s['refs'] as List).first['type']), ['wwff', 'siota']);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a spot with an unreadable time never evicts a good one, in either feed order', () async {
      // The malformed row FIRST is the case that matters and the one a
      // good-row-first fixture cannot catch: an unreadable time left as NaN
      // fails every comparison, so it holds the slot and discards every good
      // row after it — and NaN crosses the bridge as null, reads as time 0,
      // and the panel's age filter then drops the station entirely. Feed
      // order is the service's choice, not ours, so both orders are pinned.
      for (final malformedFirst in [true, false]) {
        final good = spotJson(call: 'vk4aaa', freq: '7.090', time: '2026-08-05 01:00:00', site: 'VKFF-0004');
        final bad = spotJson(call: 'vk4aaa', freq: '14.310', time: 'not a time', site: 'VKFF-0005');
        final rec = recorder('[${malformedFirst ? "$bad,$good" : "$good,$bad"}]');
        final spots = await fetchSpots(rec.client);

        expect(spots.length, 1, reason: 'malformedFirst=$malformedFirst');
        expect(spots.first['freq'], 7090, reason: 'malformedFirst=$malformedFirst');
        expect((spots.first['spot'] as Map)['timeInMillis'], DateTime.utc(2026, 8, 5, 1).millisecondsSinceEpoch, reason: 'malformedFirst=$malformedFirst');
      }
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('an empty mode falls back to the VK band plan rather than hiding the spot', () async {
      // The panel's default mode filter compares super-modes, and a null mode
      // matches nothing — so a spot with no mode never appears at all.
      final rec = recorder('[${spotJson(call: 'vk6zzz', freq: '7.090', mode: '')}]');
      final spots = await fetchSpots(rec.client);

      expect(spots.single['mode'], isNotNull);
      expect(spots.single['mode'], 'SSB');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('an operator on two awards at once keeps both rows', () async {
      // A VK activator running a WWFF park and a SiOTA silo from the same
      // spot is published as two rows. Collapsing them to one hides an award
      // the operator is actually working — and the panel's own call+freq
      // merge would have combined the two into a single row carrying both
      // references, which it cannot do for a row dropped here.
      final rec = recorder(
        '['
        '${spotJson(call: 'vk7bb', cls: 'WWFF', site: 'VKFF-0300', freq: '7.090')},'
        '${spotJson(call: 'vk7bb', cls: 'SiOTA', site: 'VK-SI0300', freq: '7.090')}'
        ']',
      );
      final spots = await fetchSpots(rec.client);

      expect(spots.length, 2);
      expect(spots.map((s) => (s['refs'] as List).first['type']).toSet(), {'wwff', 'siota'});
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('one row per station per award, keeping the newest spot rather than the first', () async {
      // app-polo keeps whichever the API returned first. A station that moved
      // band then shows where it WAS, and which spot wins depends on feed
      // order rather than on time.
      final rec = recorder(
        '['
        '${spotJson(call: 'vk3xyz', freq: '7.090', time: '2026-08-05 01:00:00', site: 'VKFF-0002')},'
        '${spotJson(call: 'vk3xyz', freq: '14.310', time: '2026-08-05 02:30:00', site: 'VKFF-0003')}'
        ']',
      );
      final spots = await fetchSpots(rec.client);

      expect(spots.length, 1);
      expect(spots.first['freq'], 14310);
      expect((spots.first['refs'] as List).first['ref'], 'VKFF-0003');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('spotting', () {
    Map<String, dynamic> operation() => {
      'stationCall': 'VK2ABC',
      'refs': [
        {'type': 'wwffActivation', 'ref': 'VKFF-1997'},
      ],
    };

    test('posts the callsign, class and MHz-shaped frequency the API expects', () async {
      final rec = recorder('Success');
      final host = await hostWith(rec.client, credentials: {'userId': 'vk2abc', 'apiKey': 'k'});

      final result =
          await host.invokeHook(
                'spots',
                key: 'parksnpeaks',
                method: 'postSelfSpot',
                args: {'operation': operation(), 'freq': 7160, 'mode': 'SSB', 'comment': 'up 5'},
                timeout: const Duration(seconds: 20),
              )
              as Map;

      expect(result['ok'], true);
      final body = jsonDecode(rec.sent.single.body) as Map;
      expect(body['actCallsign'], 'VK2ABC');
      // The ref TYPE picks the class; posting the raw type would file the spot
      // under an award the service doesn't know.
      expect(body['actClass'], 'WWFF');
      expect(body['actSite'], 'VKFF-1997');
      // 7160 kHz goes out as '7.160' — `fmtFreq` grouping thousands, not a
      // unit conversion. Sending 7160 or 7.16 spots a different frequency.
      expect(body['freq'], '7.160');
      expect(body['userID'], 'vk2abc');
      expect(body['APIKey'], 'k');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('spotting someone else reads the HUNTING ref a QSO carries', () async {
      // A logged contact with a park carries `wwff`, never `wwffActivation` —
      // that one is the operation's. Matching the activation type here leaves
      // the whole other-spot path dead with no error anywhere.
      final rec = recorder('Success');
      final host = await hostWith(rec.client, credentials: {'userId': 'vk2abc', 'apiKey': 'k'});
      final qso = {
        'their': {'call': 'VK5DEF'},
        'freq': 14310,
        'mode': 'SSB',
        'refs': [
          {'type': 'wwff', 'ref': 'VKFF-0100'},
        ],
      };

      expect(
        (await host.invokeHook('spots', key: 'parksnpeaks', method: 'isOtherSpotEnabled', args: {'qso': qso}, timeout: const Duration(seconds: 20))
            as Map)['enabled'],
        true,
      );

      final result =
          await host.invokeHook('spots', key: 'parksnpeaks', method: 'postOtherSpot', args: {'qso': qso, 'comment': ''}, timeout: const Duration(seconds: 20))
              as Map;

      expect(result['ok'], true);
      final body = jsonDecode(rec.sent.single.body) as Map;
      expect(body['actCallsign'], 'VK5DEF');
      expect(body['actClass'], 'WWFF');
      expect(body['actSite'], 'VKFF-0100');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a frequency off a whole kHz still posts a well-formed MHz string', () async {
      // A radio reporting 7160.5 kHz is ordinary — CAT drivers divide Hz by
      // 1000. app-polo's `fmtFreq` compact mode emits '7.160.' for it, and
      // '475' on 630m, which the service reads as MHz.
      final rec = recorder('Success');
      final host = await hostWith(rec.client, credentials: {'userId': 'vk2abc', 'apiKey': 'k'});

      await host.invokeHook(
        'spots',
        key: 'parksnpeaks',
        method: 'postSelfSpot',
        args: {'operation': operation(), 'freq': 7160.5},
        timeout: const Duration(seconds: 20),
      );
      expect((jsonDecode(rec.sent.single.body) as Map)['freq'], '7.160');

      final lf = recorder('Success');
      final lfHost = await hostWith(lf.client, credentials: {'userId': 'vk2abc', 'apiKey': 'k'});
      await lfHost.invokeHook(
        'spots',
        key: 'parksnpeaks',
        method: 'postSelfSpot',
        args: {'operation': operation(), 'freq': 475},
        timeout: const Duration(seconds: 20),
      );
      expect((jsonDecode(lf.sent.single.body) as Map)['freq'], '0.475');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a rejected spot answers HTTP 200, so the body decides', () async {
      // The status alone never proves a spot landed: the service returns 200
      // with 'Failure' in the body. Trusting the status reports success for a
      // spot nobody can see.
      final rec = recorder('Failure: bad API key');
      final host = await hostWith(rec.client, credentials: {'userId': 'vk2abc', 'apiKey': 'wrong'});

      final result =
          await host.invokeHook(
                'spots',
                key: 'parksnpeaks',
                method: 'postSelfSpot',
                args: {'operation': operation(), 'freq': 7160},
                timeout: const Duration(seconds: 20),
              )
              as Map;

      expect(result['ok'], false);
      expect(result['message'], contains('VKFF-1997'));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('offers spotting only once an API key is stored', () async {
      // Reading the feed needs no account, so the extension is useful without
      // one — but the spotting button must not invite a post that can only be
      // rejected.
      final without = await hostWith(recorder('[]').client);
      expect(
        (await without.invokeHook(
              'spots',
              key: 'parksnpeaks',
              method: 'isSelfSpotEnabled',
              args: {'operation': operation()},
              timeout: const Duration(seconds: 20),
            )
            as Map)['enabled'],
        false,
      );

      // Half a login is not a login: posting sends both fields, so offering
      // the source with only the key invites a post that can only be rejected.
      final halfway = await hostWith(recorder('[]').client, credentials: {'apiKey': 'k'});
      expect(
        (await halfway.invokeHook(
              'spots',
              key: 'parksnpeaks',
              method: 'isSelfSpotEnabled',
              args: {'operation': operation()},
              timeout: const Duration(seconds: 20),
            )
            as Map)['enabled'],
        false,
      );

      final with_ = await hostWith(recorder('[]').client, credentials: {'userId': 'vk2abc', 'apiKey': 'k'});
      expect(
        (await with_.invokeHook(
              'spots',
              key: 'parksnpeaks',
              method: 'isSelfSpotEnabled',
              args: {'operation': operation()},
              timeout: const Duration(seconds: 20),
            )
            as Map)['enabled'],
        true,
      );
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}

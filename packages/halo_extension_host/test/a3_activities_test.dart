// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// WWFF, LLOTA and TOTA — the three awards that sit behind an API key.
//
// What each decides for itself: its list's shape, its feed's shape, and how
// much of it survives a build with no key. TOTA is the sharp case — its LIST
// needs the key, so a keyless build has no towers at all, while WWFF and LLOTA
// keep their references and lose only spots.

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
        return http.Response(body, status, headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );
  }

  /// No `secrets` go in: the three key-gated awards carry their own keys as
  /// constants now, so an injected value would be ignored and a test asserting
  /// on one would be asserting about the harness.
  Future<ExtensionHost> hostFor(String key,
      {http.Client? client, List<String> domains = const []}) async {
    final host = await ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: [ExtensionBundle(key: key, source: bundleSource(key))],
      secrets: const {},
      fetchAllowlists: {key: domains},
      httpClient: client,
      onHostCall: nullHostCall,
    );
    addTearDown(host.dispose);
    return host;
  }

  group('keys and degradation', () {
    test('WWFF carries its own key, and sends it as a header', () async {
      // The key is a constant in the bundle, not a build secret, so there is
      // no keyless build to degrade for — what still matters is WHERE it
      // travels. A header keeps it out of the URL, and so out of any log,
      // error report or proxy trace of one.
      final rec = recorder('[]');
      final host = await hostFor('wwff', client: rec.client, domains: ['wwff.co', 'spots.wwff.co']);

      await host.invokeHook('spots', key: 'wwff', method: 'fetchSpots',
          args: {'online': true}, timeout: const Duration(seconds: 20));

      // Asserted as "present and non-empty", never against the literal: the
      // value lives in one place and a copy here would be a second one to
      // rotate.
      final sentKey = rec.sent.single.headers['X-API-Key'];
      expect(sentKey, isNotNull);
      expect(sentKey, isNotEmpty);
      expect(rec.sent.single.url.toString(), isNot(contains(sentKey!)));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('WWFF resolves park references with no network at all', () async {
      // The directory is public and compiled in; only the feed is remote. A
      // fork with the key rotated out, or an operator with no signal, must
      // still resolve park references.
      final rec = recorder('[]');
      final host = await hostFor('wwff', client: rec.client, domains: ['wwff.co', 'spots.wwff.co']);

      final ref = await host.invokeHook('ref:wwffActivation', method: 'validateRef',
          args: {'ref': {'type': 'wwffActivation', 'ref': 'kff-0001'}}) as Map;
      expect(ref['valid'], true);
      expect(ref['normalized'], 'KFF-0001');
      expect(rec.sent, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('TOTA puts its key in the list URL, which is the one that needs it', () async {
      // TOTA gates its LIST, not just its spots — the one award here whose
      // data file is unreachable without the key, which is why the key ships
      // in the bundle rather than being something a build may lack.
      final host = await hostFor('tota');
      // `getDefinition` is a fan-out, not a single-hook call — DataFileManager
      // reaches it the same way.
      final entries = await host.invokeHookAll('dataFile', method: 'getDefinition');
      final tota = entries
          .map((e) => (e['value'] as Map))
          .firstWhere((d) => d['key'] == 'tota-all-towers');
      // `url` is a function resolved per refresh, not a static string. Asserted
      // on the PARAMETER rather than the value, which lives in one place.
      expect(tota['url'], contains('key='));
      expect(Uri.parse(tota['url'] as String).queryParameters['key'], isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 120)));
  });

  group('data files', () {
    Future<List<Map<String, dynamic>>> mapRows(
        String ext, String dfKey, String method, String argName, List<dynamic> rows) async {
      final host = await hostFor(ext);
      final result = await host.invokeHook('dataFile', key: dfKey, method: method,
          args: {argName: rows}, timeout: const Duration(seconds: 20)) as List;
      return result.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }

    test('wwff keeps active parks and resolves the DXCC entity prefix', () async {
      final entries = await mapRows('wwff', 'wwff-all-parks', 'mapCsvBatch', 'rows', [
        {'reference': 'KFF-0001', 'name': 'Acadia', 'status': 'active', 'latitude': '44.35',
         'longitude': '-68.21', 'iaruLocator': 'FN54VH', 'dxccEnum': '291'},
        {'reference': 'KFF-9999', 'name': 'Retired', 'status': 'deleted', 'latitude': '44.0',
         'longitude': '-68.0', 'dxccEnum': '291'},
      ]);

      expect(entries.map((e) => e['key']), ['KFF-0001']);
      // The prefix, not the raw numeric id, so `suggest` narrows the same way
      // it does for POTA and SOTA.
      expect(entries.first['subCategory'], 'K');
      expect(entries.first['data']['grid'], 'FN54vh');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('llota reads reference_code and scopes by its country part', () async {
      final entries = await mapRows('llota', 'llota-all-references', 'mapJsonBatch', 'entries', [
        {'reference_code': 'LLUS-0001', 'name': 'Lake Placid', 'latitude': 44.28, 'longitude': -73.98},
      ]);

      expect(entries.first['key'], 'LLUS-0001');
      expect(entries.first['subCategory'], 'LLUS');
      expect(entries.first['lat'], closeTo(44.28, 0.01));
      expect(entries.first['data']['grid'], isNotNull);
      // `name` is the field the live list publishes; read under any other name
      // every reference is nameless, and nothing else here would notice.
      expect(entries.first['name'], 'Lake Placid');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('tota keeps the award fields it publishes', () async {
      // Every numeric field arrives as a STRING — 'lat': '50.730000', not
      // 50.73 — in all 5293 rows of the live tower list. A row written with
      // real numbers here is a row no source ever sends, and it hides a
      // `typeof === 'number'` guard that drops the coordinates of every tower.
      final entries = await mapRows('tota', 'tota-all-towers', 'mapJsonBatch', 'entries', [
        {'ref': 'OKR-0001', 'name': 'Ještěd', 'lat': '50.730000', 'lon': '15.000000', 'height': '94.00'},
      ]);

      expect(entries.first['key'], 'OKR-0001');
      expect(entries.first['subCategory'], 'OKR');
      expect(entries.first['name'], 'Ještěd');
      expect(entries.first['lat'], closeTo(50.73, 0.001));
      expect(entries.first['lon'], closeTo(15.0, 0.001));
      // Without coordinates there is no grid, so distance and the map go with
      // them — the visible cost of dropping the pair.
      expect(entries.first['data']['grid'], 'JO70mr');
      // `data` carries the parsed pair, not the published strings, so a
      // consumer reading it gets the same shape every other award writes.
      expect(entries.first['data']['lat'], closeTo(50.73, 0.001));
      // The whole published record is kept — the award has fields HaLo has no
      // opinion about, and dropping them would lose them silently.
      expect(entries.first['data']['height'], '94.00');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('feeds', () {
    test('wwff reads spot times in SECONDS', () async {
      // The only feed in the port publishing epoch seconds; treated as millis
      // every spot would land in January 1970.
      final rec = recorder('[{"activator":"w1aw","reference":"KFF-0001","frequency_khz":14285,'
          '"mode":"ssb","spot_time":1782000000,"remarks":"up 5","spotter":"g1abc"}]');
      final host = await hostFor('wwff', client: rec.client, domains: ['wwff.co', 'spots.wwff.co']);

      final spots = (await host.invokeHook('spots', key: 'wwff', method: 'fetchSpots',
          args: {'online': true}, timeout: const Duration(seconds: 20)) as List).cast<Map>();

      expect(spots.single['freq'], 14285);
      expect((spots.single['spot'] as Map)['timeInMillis'], 1782000000000);
      expect((spots.single['their'] as Map)['call'], 'W1AW');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('llota drops spots whose comments say QRT', () async {
      // Showing an operator who has packed up is worse than showing nothing.
      final rec = recorder('['
          '{"id":1,"callsign":"W1AW","reference":"LLUS-0001","reference_name":"Placid",'
          '"frequency":14285,"mode":"SSB","updated_at":"2026-07-01T12:00:00Z","comments":"QRT now"},'
          '{"id":2,"callsign":"K2ABC","reference":"LLUS-0002","reference_name":"George",'
          '"frequency":7120,"mode":"SSB","updated_at":"2026-07-01T12:05:00Z"}'
          ']');
      final host = await hostFor('llota', client: rec.client, domains: ['llota.app']);

      final spots = (await host.invokeHook('spots', key: 'llota', method: 'fetchSpots',
          args: {'online': true}, timeout: const Duration(seconds: 20)) as List).cast<Map>();

      expect(spots.length, 1);
      expect((spots.single['their'] as Map)['call'], 'K2ABC');
      expect((spots.single['spot'] as Map)['label'], 'LLUS-0002: George');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  test('llota splits a multi-lake contact and names each in LLOTA_REF', () async {
    // LLOTA is POTA-shaped: one record per hunted lake, and the award's own
    // field names the single lake that record is for.
    final host = await hostFor('llota');
    final combos = (await host.invokeHook('adifFields', key: 'llota',
        method: 'fieldCombinationsForOneQSO', args: {
      'qso': {
        'their': {'call': 'W1AW'},
        'refs': [
          {'type': 'llota', 'ref': 'LLUS-9001'},
          {'type': 'llota', 'ref': 'LLUS-9002'},
        ],
      },
      'operation': {'refs': [{'type': 'llotaActivation', 'ref': 'LLUS-0001'}]},
    }, timeout: const Duration(seconds: 20)) as List).cast<List>();

    expect(combos.length, 2);
    String valueOf(List fields, String name) =>
        (fields.cast<Map>().firstWhere((f) => f['name'] == name))['value'] as String;
    expect(valueOf(combos[0], 'LLOTA_REF'), 'LLUS-9001');
    expect(valueOf(combos[1], 'LLOTA_REF'), 'LLUS-9002');
    expect(valueOf(combos[0], 'MY_LLOTA_REF'), 'LLUS-0001');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('wwff joins its hunted parks into one record', () async {
    // Unlike LLOTA — app-polo registers no combinations for WWFF at all.
    final host = await hostFor('wwff');
    expect(
      await host.invokeHook('adifFields', key: 'wwff', method: 'fieldCombinationsForOneQSO',
          args: {'qso': {'refs': <Map>[]}, 'operation': {'refs': <Map>[]}},
          timeout: const Duration(seconds: 20)),
      isNull,
    );

    final fields = (await host.invokeHook('adifFields', key: 'wwff', method: 'fieldsForOneQSO', args: {
      'qso': {
        'their': {'call': 'W1AW'},
        'refs': [
          {'type': 'wwff', 'ref': 'KFF-9001'},
          {'type': 'wwff', 'ref': 'KFF-9002'},
        ],
      },
      'operation': {'refs': [{'type': 'wwffActivation', 'ref': 'KFF-0001'}]},
    }, timeout: const Duration(seconds: 20)) as List).cast<Map>();

    final wwffRef = fields.firstWhere((f) => f['name'] == 'WWFF_REF');
    expect(wwffRef['value'], 'KFF-9001,KFF-9002');
    expect(fields.firstWhere((f) => f['name'] == 'MY_WWFF_REF')['value'], 'KFF-0001');
  }, timeout: const Timeout(Duration(seconds: 60)));
}

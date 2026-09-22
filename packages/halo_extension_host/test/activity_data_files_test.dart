// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The per-award data-file mappers. Everything else about the six castle and
// lighthouse extensions comes from the shared `referenceActivity` factory, so
// this is where each one's own bugs live: a misread column name, a swapped
// coordinate pair, a filter that keeps retired references.
//
// The published lists are large and change; these feed each mapper one row in
// the shape its real source uses (transcribed from app-polo's loaders) and
// check what comes out.

import 'package:flutter_test/flutter_test.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  /// Runs rows through an extension's registered mapper, the way
  /// DataFileManager does.
  Future<List<Map<String, dynamic>>> map(String extension, String dataFileKey, String method, String argName, List<dynamic> rows) async {
    final host = await sharedHost([extension]);
    final result = await host.invokeHook('dataFile', key: dataFileKey, method: method, args: {argName: rows}, timeout: const Duration(seconds: 20)) as List;
    return result.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<List<Map<String, dynamic>>> mapJson(String ext, String dfKey, List<dynamic> entries) => map(ext, dfKey, 'mapJsonBatch', 'entries', entries);
  Future<List<Map<String, dynamic>>> mapCsv(String ext, String dfKey, List<dynamic> rows) => map(ext, dfKey, 'mapCsvBatch', 'rows', rows);

  /// GeoJSON as the Belgian lists publish it.
  Map<String, dynamic> feature(String ref, String name, double lon, double lat) => {
    'type': 'Feature',
    'properties': {'reference': ref, 'name': name},
    'geometry': {
      'type': 'Point',
      'coordinates': [lon, lat],
    },
  };

  group('bca', () {
    test('reads GeoJSON coordinates as [lon, lat], not [lat, lon]', () async {
      // Beersel: 50.766 N, 4.307 E. Swapped, this lands in the Indian Ocean.
      final entries = await mapJson('bca', 'bca-all-castles', [feature('ON-00558', ' Kasteel van Beersel ', 4.307, 50.766)]);

      expect(entries.length, 1);
      expect(entries.first['key'], 'ON-00558');
      expect(entries.first['lat'], closeTo(50.766, 0.001));
      expect(entries.first['lon'], closeTo(4.307, 0.001));
      // Grid is derived, so a swap shows up here too.
      expect(entries.first['data']['grid'], startsWith('JO20'));
      // Names arrive padded in the published list.
      expect(entries.first['name'], 'Kasteel van Beersel');
      expect(entries.first['subCategory'], 'ON');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('an unforeseen reference shape is stored, not silently dropped', () async {
      // app-polo stores whatever the list publishes. Filtering here on the
      // reference pattern would turn a stray space or an unexpected prefix into
      // a castle that simply does not exist, with nothing to show for it —
      // exactly how three real ECA references went missing.
      final entries = await mapJson('bca', 'bca-all-castles', [feature('ON-1', 'Odd but published', 4.0, 50.0), feature('ON-00558', 'Beersel', 4.307, 50.766)]);
      expect(entries.map((e) => e['key']), ['ON-1', 'ON-00558']);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a reference with no code at all is dropped', () async {
      final entries = await mapJson('bca', 'bca-all-castles', [
        feature('', 'Nameless', 4.0, 50.0),
        feature('  ', 'Blank', 4.0, 50.0),
        feature('ON-00558', 'Beersel', 4.307, 50.766),
      ]);
      expect(entries.map((e) => e['key']), ['ON-00558']);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  test('blha keeps the space INSIDE a `BEL 001` reference while trimming the ends', () async {
    // The inner space is part of the reference; only the ends are trimmed.
    final entries = await mapJson('blha', 'blha-all-lighthouses', [feature(' BEL 001 ', 'Oostende', 2.93, 51.23)]);
    expect(entries.map((e) => e['key']), ['BEL 001']);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('eca reads the reference from WCA, not from a column named ECA', () async {
    // English castles are catalogued by their WCA code; there is no ECA column.
    final entries = await mapJson('eca', 'eca-all-castles', [
      {'WCA': 'G-00001', 'NAME_OF_CASTLE': ' Windsor Castle ', 'LOCATION': 'Berkshire', 'LATITUDE': '51.4839', 'LONGITUDE': '-0.6044'},
    ]);

    expect(entries.length, 1);
    expect(entries.first['key'], 'G-00001');
    expect(entries.first['name'], 'Windsor Castle');
    expect(entries.first['subCategory'], 'Berkshire');
    expect(entries.first['lat'], closeTo(51.4839, 0.001));
    // Coordinates arrive as strings and must be parsed.
    expect(entries.first['lon'], closeTo(-0.6044, 0.001));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('eca keeps the three references published with a trailing space', () async {
    // Not hypothetical: 'G-01516 ', 'G-02048 ' and 'G-03350 ' are in the live
    // list exactly like this, and an untrimmed pattern check dropped all three.
    final entries = await mapJson('eca', 'eca-all-castles', [
      {'WCA': 'G-01516 ', 'NAME_OF_CASTLE': 'Padded', 'LOCATION': 'Kent', 'LATITUDE': '51.2', 'LONGITUDE': '0.5'},
    ]);
    expect(entries.length, 1);
    expect(entries.first['key'], 'G-01516');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('eca tolerates a row with unparseable coordinates', () async {
    final entries = await mapJson('eca', 'eca-all-castles', [
      {'WCA': 'G-00002', 'NAME_OF_CASTLE': 'No coords', 'LOCATION': 'Kent', 'LATITUDE': '', 'LONGITUDE': ''},
    ]);
    // Kept — the castle is real, it just has no position yet.
    expect(entries.length, 1);
    expect(entries.first['lat'], isNull);
    expect(entries.first['data']['grid'], isNull);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('ela reads the underscored `NAME_OF_LIGHTHOUSE` column', () async {
    // The live file underscores the name column, same as ECA — verified
    // against ham2k.com/data/cached/ela/ELA_References.json. A spaced
    // 'NAME OF LIGHTHOUSE' key reads nothing and yields nameless references.
    final entries = await mapJson('ela', 'ela-all-lighthouses', [
      {'ELA': 'ENG 001', 'NAME_OF_LIGHTHOUSE': 'Beachy Head', 'LOCATION': 'East Sussex', 'LATITUDE': '50.7361', 'LONGITUDE': '0.2494'},
    ]);

    expect(entries.length, 1);
    expect(entries.first['key'], 'ENG 001');
    expect(entries.first['name'], 'Beachy Head');
  }, timeout: const Timeout(Duration(seconds: 60)));

  group('pga', () {
    test('keeps active gminas and their published grid', () async {
      final entries = await mapCsv('pga', 'pga-gminas', [
        {
          'PGA REF.': 'ZP01',
          'GMINA': 'Szczecin',
          'GRID LOCATOR': 'JO73gl',
          'POWIAT': 'Szczecin',
          'VOIVODESHIP': 'Zachodniopomorskie',
          'LAT': '53.4285',
          'LONG': '14.5528',
          'ACTIVE': 'YES',
        },
      ]);

      expect(entries.length, 1);
      expect(entries.first['key'], 'ZP01');
      expect(entries.first['name'], 'Szczecin');
      // A gmina is an area, so the award's own grid is used rather than one
      // derived from the centroid.
      expect(entries.first['data']['grid'], 'JO73gl');
      expect(entries.first['subCategory'], 'Szczecin');
      expect(entries.first['data']['province'], 'Zachodniopomorskie');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('drops retired gminas rather than storing them inactive', () async {
      final entries = await mapCsv('pga', 'pga-gminas', [
        {'PGA REF.': 'ZP01', 'GMINA': 'Active one', 'ACTIVE': 'YES', 'LAT': '53.4', 'LONG': '14.5'},
        {'PGA REF.': 'ZP02', 'GMINA': 'Retired one', 'ACTIVE': 'NO', 'LAT': '53.4', 'LONG': '14.5'},
      ]);
      expect(entries.map((e) => e['key']), ['ZP01']);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  test('pga registers no scoring hook, because the award counts nothing', () async {
    // app-polo's PGA has no scoringForQSO at all: a gmina is recorded and
    // exported, never measured against a threshold. Registering the shared
    // scorer "for consistency" would invent a rule the award does not have.
    final host = await sharedHost(['pga']);
    await expectLater(
      host.invokeHook(
        'scoring',
        key: 'pga',
        method: 'scoreQsos',
        args: {
          'operation': {'uuid': 'op', 'refs': []},
          'qsos': [],
        },
        timeout: const Duration(seconds: 10),
      ),
      throwsA(anything),
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('wca splits the single COORDINATES column into lat and lon', () async {
    // WCA publishes one column holding "lat,lon" — the only list here that does.
    final entries = await mapCsv('wca', 'wca-all-castles', [
      {'REF': 'ON-00558', 'PREFIX': 'ON', 'CLEAN NAME': 'Kasteel van Beersel', 'CLEAN LOCATION': 'Vlaams-Brabant', 'COORDINATES': '50.766,4.307'},
    ]);

    expect(entries.length, 1);
    expect(entries.first['lat'], closeTo(50.766, 0.001));
    expect(entries.first['lon'], closeTo(4.307, 0.001));
    expect(entries.first['data']['location'], 'Vlaams-Brabant');
    expect(entries.first['subCategory'], 'ON');
  }, timeout: const Timeout(Duration(seconds: 60)));
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// End-to-end verification that POTA/SOTA's `dataFile` definitions really
// populate the lookup table through the real bundled JS extensions (not a
// mocked host, like data_file_manager_test.dart's fixtures), and that their
// new `suggest` hook then serves nearby/search results from that data.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/services/data_file_manager.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';

class _CannedDataFileManager extends DataFileManager {
  final Map<String, String> bodiesByKey;
  _CannedDataFileManager({required this.bodiesByKey, required super.lookups, required super.extensions, required super.prefs});

  @override
  Future<String?> downloadFile(String key, String url, {bool force = false, String? encoding}) async => bodiesByKey[key];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late LookupRepository lookups;
  late ExtensionService extensions;

  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    lookups = LookupRepository(db);
    SharedPreferences.setMockInitialValues({});
    // SOTA is not in the default set — only POTA is — so a runtime booted
    // from the defaults alone carries no SOTA extension to exercise.
    final settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setExtensionOverrides({'sota': true});
    extensions = ExtensionService()
      ..lookups = lookups
      ..settings = settings;
    await extensions.start();
  });

  tearDown(() async {
    await db.close();
  });

  test('POTA and SOTA dataFile definitions populate the lookup table via the real extensions', () async {
    final host = extensions.host;
    expect(host, isNotNull, reason: 'extension runtime failed to boot');

    final defs = await host!.invokeHookAll('dataFile', method: 'getDefinition');
    final potaDef = Map<String, dynamic>.from(
      (defs.firstWhere((e) => (e['value'] as Map?)?['key'] == 'pota-all-parks')['value'] as Map),
    );
    final sotaDef = Map<String, dynamic>.from(
      (defs.firstWhere((e) => (e['value'] as Map?)?['key'] == 'sota-all-summits')['value'] as Map),
    );

    final prefs = await SharedPreferences.getInstance();
    final manager = _CannedDataFileManager(
      lookups: lookups,
      extensions: extensions,
      prefs: prefs,
      bodiesByKey: {
        'pota-all-parks': 'reference,name,active,entityId,locationDesc,latitude,longitude,grid\n'
            'US-1234,Test State Park,1,291,US-CA,37.7749,-122.4194,\n',
        'sota-all-summits': 'SOTA Summits List\n'
            'SummitCode,SummitName,AssociationName,RegionName,Latitude,Longitude,AltM,Points,ValidFrom,ValidTo\n'
            'W6/CT-001,Test Peak,USA-California,Central,37.5,-122.1,1200,4,01/01/2020,31/12/2099\n',
      },
    );

    await manager.processDataFile('pota-all-parks', potaDef);
    await manager.processDataFile('sota-all-summits', sotaDef);

    final potaRow = await lookups.getLookup('pota', 'US-1234');
    expect(potaRow, isNotNull);
    expect(potaRow!.name, 'Test State Park');
    expect(potaRow.lat, closeTo(37.7749, 0.001));
    expect(potaRow.flags, 1);
    // subCategory is the DXCC entity prefix (from entityId 291), not the
    // raw numeric id — same representation SOTA uses below.
    expect(potaRow.subCategory, 'K');

    final sotaRow = await lookups.getLookup('sota', 'W6/CT-001');
    expect(sotaRow, isNotNull);
    expect(sotaRow!.name, 'Test Peak');
    expect(sotaRow.lat, closeTo(37.5, 0.001));
    // subCategory is derived from the "W6" association code, resolving to
    // the same "K" (USA) DXCC prefix POTA uses for a US entityId.
    expect(sotaRow.subCategory, 'K');
  });

  test('SOTA subCategory resolves sub-associations and the two hand-verified overrides', () async {
    final host = extensions.host!;
    final defs = await host.invokeHookAll('dataFile', method: 'getDefinition');
    final sotaDef = Map<String, dynamic>.from(
      (defs.firstWhere((e) => (e['value'] as Map?)?['key'] == 'sota-all-summits')['value'] as Map),
    );

    final prefs = await SharedPreferences.getInstance();
    final manager = _CannedDataFileManager(
      lookups: lookups,
      extensions: extensions,
      prefs: prefs,
      bodiesByKey: {
        'sota-all-summits': 'SOTA Summits List\n'
            'SummitCode,SummitName,AssociationName,RegionName,Latitude,Longitude,AltM,Points,ValidFrom,ValidTo\n'
            // KLA has no valid-prefix reading on its own; stripping the
            // trailing region letter recovers "KL", a real Alaska prefix
            // under the USA DXCC entity.
            'KLA/AK-001,Test Alaska Peak,Alaska - Anchorage,Anchorage,61.2,-149.9,1200,4,01/01/2020,31/12/2099\n'
            // VP0 has no valid-prefix reading at all — hand-verified override.
            'VP0/SG-001,Test South Georgia Peak,South Georgia,South Georgia,-54.3,-36.5,1200,4,01/01/2020,31/12/2099\n'
            // ZD spans three DXCC entities — stored as the literal family marker.
            'ZD/AI-001,Test Ascension Peak,UK South Atlantic,Ascension Island,-7.9,-14.4,800,4,01/01/2020,31/12/2099\n',
      },
    );

    await manager.processDataFile('sota-all-summits', sotaDef);

    expect((await lookups.getLookup('sota', 'KLA/AK-001'))!.subCategory, 'K');
    expect((await lookups.getLookup('sota', 'VP0/SG-001'))!.subCategory, 'VP8/g');
    expect((await lookups.getLookup('sota', 'ZD/AI-001'))!.subCategory, 'ZD');
  });

  test('suggest() treats "ZD" as a family match for any ZD7/ZD8/ZD9 caller', () async {
    final host = extensions.host!;

    await lookups.insertLookupBatch([
      LookupRow(
        category: 'sota',
        key: 'ZD/AI-001',
        name: 'Test Ascension Peak',
        subCategory: 'ZD',
        lat: -7.9,
        lon: -14.4,
        flags: 1,
        data: '{"ref":"ZD/AI-001","name":"Test Ascension Peak"}',
      ),
    ]);

    // ZD8 = Ascension — a real callsign there should match the "ZD" row.
    final results = await host.invokeHookAll(
      'activity',
      method: 'suggest',
      args: {
        'operation': <String, dynamic>{},
        'callsign': 'ZD8XYZ',
        'searchTerm': 'Test Ascension Peak',
      },
    );
    final sotaSuggestions = (results.firstWhere((e) => e['key'] == 'sota')['value'] as List).cast<Map>();
    expect(sotaSuggestions.any((s) => s['ref'] == 'ZD/AI-001'), isTrue);
  });

  test('suggest() filters name/code search to the caller\'s own DXCC entity, but not nearby results', () async {
    final host = extensions.host!;

    await lookups.insertLookupBatch([
      LookupRow(
        category: 'pota',
        key: 'US-1234',
        name: 'Test State Park',
        subCategory: 'K',
        lat: 37.7749,
        lon: -122.4194,
        flags: 1,
        data: '{"reference":"US-1234","name":"Test State Park"}',
      ),
      LookupRow(
        category: 'pota',
        key: 'EA-1234',
        name: 'Test State Park', // same name, different country
        subCategory: 'EA',
        lat: 40.0,
        lon: -3.7,
        flags: 1,
        data: '{"reference":"EA-1234","name":"Test State Park"}',
      ),
    ]);

    // Search by name: a US caller (W1AW) should only see the US match.
    final searchResults = await host.invokeHookAll(
      'activity',
      method: 'suggest',
      args: {
        'operation': <String, dynamic>{},
        'callsign': 'W1AW',
        'searchTerm': 'Test State Park',
      },
    );
    final searchSuggestions = (searchResults.firstWhere((e) => e['key'] == 'pota')['value'] as List).cast<Map>();
    expect(searchSuggestions.map((s) => s['ref']), ['US-1234']);

    // Nearby (location-based, no search term): both should be reachable —
    // entity filtering only applies to text search, not proximity.
    final nearbyResults = await host.invokeHookAll(
      'activity',
      method: 'suggest',
      args: {
        'operation': <String, dynamic>{},
        'callsign': 'W1AW',
        'location': {'lat': 40.0, 'lon': -3.7},
      },
    );
    final nearbySuggestions = (nearbyResults.firstWhere((e) => e['key'] == 'pota')['value'] as List).cast<Map>();
    expect(nearbySuggestions.any((s) => s['ref'] == 'EA-1234'), isTrue);
  });

  test('POTA and SOTA suggest() serves nearby results from the populated lookup table', () async {
    final host = extensions.host!;

    // Seed the lookup table directly — this test targets `suggest`, not the
    // dataFile pipeline (covered above).
    await lookups.insertLookupBatch([
      LookupRow(
        category: 'pota',
        key: 'US-1234',
        name: 'Test State Park',
        lat: 37.7749,
        lon: -122.4194,
        flags: 1,
        data: '{"reference":"US-1234","name":"Test State Park","active":true}',
      ),
      LookupRow(
        category: 'sota',
        key: 'W6/CT-001',
        name: 'Test Peak',
        lat: 37.5,
        lon: -122.1,
        flags: 1,
        data: '{"ref":"W6/CT-001","name":"Test Peak"}',
      ),
    ]);

    final results = await host.invokeHookAll(
      'activity',
      method: 'suggest',
      args: {
        'operation': <String, dynamic>{},
        'location': {'lat': 37.7, 'lon': -122.2},
      },
    );

    final potaSuggestions = (results.firstWhere((e) => e['key'] == 'pota')['value'] as List).cast<Map>();
    expect(potaSuggestions.any((s) => s['ref'] == 'US-1234'), isTrue);
    final potaMatch = potaSuggestions.firstWhere((s) => s['ref'] == 'US-1234');
    expect(potaMatch['type'], 'potaActivation');
    expect((potaMatch['distance'] as num).toDouble(), greaterThan(0));
    expect(potaMatch['relevance'], 1);

    final sotaSuggestions = (results.firstWhere((e) => e['key'] == 'sota')['value'] as List).cast<Map>();
    expect(sotaSuggestions.any((s) => s['ref'] == 'W6/CT-001'), isTrue);
  });

  test('POTA suggest() ranks nearby results by real distance before truncating to MAX_SUGGESTIONS', () async {
    final host = extensions.host!;

    // 40 parks scattered further out, all still inside the ~150km bounding
    // box `suggest` queries with, plus one right next to the caller. If
    // truncation ever again happens before sorting by distance (the actual
    // bug reported: a 5km-away park missing from nearby suggestions), this
    // close park can get cut by the 30-result cap in favor of arbitrary
    // farther ones.
    final farRows = [
      for (var i = 0; i < 40; i++)
        LookupRow(
          category: 'pota',
          key: 'US-9$i',
          name: 'Far Park $i',
          // Spread out within the bounding box, all farther than ~40km.
          lat: 37.7749 + (i.isEven ? 1 : -1) * (0.4 + i * 0.01),
          lon: -122.4194 + (i.isEven ? -1 : 1) * (0.4 + i * 0.01),
          flags: 1,
          data: '{"reference":"US-9$i","name":"Far Park $i","active":true}',
        ),
      LookupRow(
        category: 'pota',
        key: 'US-CLOSE',
        name: 'Nearby Park',
        lat: 37.7794, // ~5km from the query location below
        lon: -122.4194,
        flags: 1,
        data: '{"reference":"US-CLOSE","name":"Nearby Park","active":true}',
      ),
    ];
    await lookups.insertLookupBatch(farRows);

    final results = await host.invokeHookAll(
      'activity',
      method: 'suggest',
      args: {
        'operation': <String, dynamic>{},
        'location': {'lat': 37.7749, 'lon': -122.4194},
      },
    );

    final potaSuggestions = (results.firstWhere((e) => e['key'] == 'pota')['value'] as List).cast<Map>();
    expect(potaSuggestions.length, lessThanOrEqualTo(30));
    expect(potaSuggestions.any((s) => s['ref'] == 'US-CLOSE'), isTrue);
    expect(potaSuggestions.first['ref'], 'US-CLOSE');
  });

  test('POTA suggest() always offers a fully-formed reference typed in the search, even when absent from the lookup table', () async {
    final host = extensions.host!;
    // Deliberately empty lookup table — a brand-new park, or one the local
    // data file hasn't synced yet, must still be offered as an option.

    final results = await host.invokeHookAll(
      'activity',
      method: 'suggest',
      args: {
        'operation': <String, dynamic>{},
        'callsign': 'W1AW',
        'searchTerm': 'US-15000',
      },
    );

    final potaSuggestions = (results.firstWhere((e) => e['key'] == 'pota')['value'] as List).cast<Map>();
    expect(potaSuggestions.map((s) => s['ref']), contains('US-15000'));
    final synthetic = potaSuggestions.firstWhere((s) => s['ref'] == 'US-15000');
    expect(synthetic['type'], 'potaActivation');
    expect(synthetic['name'], 'Unknown Park');
  });

  test('POTA suggest() accepts a fully-formed reference typed without its dash', () async {
    final host = extensions.host!;

    final results = await host.invokeHookAll(
      'activity',
      method: 'suggest',
      args: {
        'operation': <String, dynamic>{},
        'callsign': 'W1AW',
        'searchTerm': 'US15000',
      },
    );

    final potaSuggestions = (results.firstWhere((e) => e['key'] == 'pota')['value'] as List).cast<Map>();
    // Normalized to the canonical dashed form, not left as typed.
    expect(potaSuggestions.map((s) => s['ref']), contains('US-15000'));
    expect(potaSuggestions.map((s) => s['ref']), isNot(contains('US15000')));
  });

  test('POTA suggest() allows the special "K-TEST" reference (dashed or not), labeled "Test Park"', () async {
    final host = extensions.host!;

    for (final searchTerm in ['K-TEST', 'KTEST']) {
      final results = await host.invokeHookAll(
        'activity',
        method: 'suggest',
        args: {
          'operation': <String, dynamic>{},
          'callsign': 'W1AW',
          'searchTerm': searchTerm,
        },
      );

      final potaSuggestions = (results.firstWhere((e) => e['key'] == 'pota')['value'] as List).cast<Map>();
      expect(potaSuggestions.map((s) => s['ref']), contains('K-TEST'), reason: searchTerm);
      expect(potaSuggestions.firstWhere((s) => s['ref'] == 'K-TEST')['name'], 'Test Park', reason: searchTerm);
    }
  });

  test('POTA suggest() prefers a real matching row over the synthetic fully-formed-reference entry', () async {
    final host = extensions.host!;
    await lookups.insertLookupBatch([
      LookupRow(
        category: 'pota',
        key: 'US-1234',
        name: 'Test State Park',
        subCategory: 'K',
        lat: 37.7749,
        lon: -122.4194,
        flags: 1,
        data: '{"reference":"US-1234","name":"Test State Park"}',
      ),
    ]);

    final results = await host.invokeHookAll(
      'activity',
      method: 'suggest',
      args: {
        'operation': <String, dynamic>{},
        'callsign': 'W1AW',
        'searchTerm': 'US-1234',
      },
    );

    final potaSuggestions = (results.firstWhere((e) => e['key'] == 'pota')['value'] as List).cast<Map>();
    // Exactly one entry for US-1234 — the real row's name, not a duplicate
    // bare synthetic one.
    expect(potaSuggestions.where((s) => s['ref'] == 'US-1234'), hasLength(1));
    expect(potaSuggestions.firstWhere((s) => s['ref'] == 'US-1234')['name'], 'Test State Park');
  });
}

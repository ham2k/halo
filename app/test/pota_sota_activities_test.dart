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

class _CannedDataFileManager extends DataFileManager {
  final Map<String, String> bodiesByKey;
  _CannedDataFileManager({required this.bodiesByKey, required super.lookups, required super.extensions, required super.prefs});

  @override
  Future<String?> downloadFile(String key, String url) async => bodiesByKey[key];
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
    extensions = ExtensionService()..lookups = lookups;
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

    final sotaRow = await lookups.getLookup('sota', 'W6/CT-001');
    expect(sotaRow, isNotNull);
    expect(sotaRow!.name, 'Test Peak');
    expect(sotaRow.lat, closeTo(37.5, 0.001));
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
}

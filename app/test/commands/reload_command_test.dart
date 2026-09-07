// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// End-to-end verification of the RELOAD call-field command (dev-commands
// extension) and the DataFileManager.syncAllDataFiles categoryFilter it
// drives: "RELOAD POTA"/"RELOAD SOTA" target one activity, "RELOAD ALL",
// "RELOADALL", or "RELOAD!" targets every data file, and a bare "RELOAD"
// expects params (recognized prefix, not executable yet) rather than being
// either a no-op or immediately runnable.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/services/data_file_manager.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';

class _CannedDataFileManager extends DataFileManager {
  final Map<String, String> bodiesByKey;
  int callsForPota = 0;
  int callsForSota = 0;

  _CannedDataFileManager({required this.bodiesByKey, required super.lookups, required super.extensions, required super.prefs});

  @override
  Future<String?> downloadFile(String key, String url, {bool force = false, String? encoding}) async {
    if (key == 'pota-all-parks') callsForPota++;
    if (key == 'sota-all-summits') callsForSota++;
    return bodiesByKey[key];
  }
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
    // SOTA is not in the default set — only POTA is — and this exercises
    // both extensions' real data files.
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

  Future<Map<String, dynamic>?> interpret(String input) async {
    final entries = await extensions.host!.invokeHookAll(
      'command',
      method: 'interpret',
      args: {'input': input},
    );
    for (final entry in entries) {
      if (entry['ok'] == true && entry['value'] is Map) {
        return (entry['value'] as Map).cast<String, dynamic>();
      }
    }
    return null;
  }

  group('RELOAD command interpretation (real dev-commands extension)', () {
    test('"RELOAD POTA" targets just the POTA category', () async {
      final result = await interpret('RELOAD POTA');
      expect(result, isNotNull);
      final commands = (result!['commands'] as List).cast<Map>();
      expect(commands.single['reloadDataFiles'], {'target': 'POTA'});
    });

    test('"RELOAD SOTA" targets just the SOTA category', () async {
      final result = await interpret('reload sota'); // case-insensitive
      expect(result, isNotNull);
      final commands = (result!['commands'] as List).cast<Map>();
      expect(commands.single['reloadDataFiles'], {'target': 'SOTA'});
    });

    test('"RELOAD ALL", "RELOADALL", and "RELOAD!" all target everything', () async {
      for (final input in ['RELOAD ALL', 'RELOADALL', 'reloadall', 'RELOAD!']) {
        final result = await interpret(input);
        expect(result, isNotNull, reason: 'for input "$input"');
        final commands = (result!['commands'] as List).cast<Map>();
        expect(commands.single['reloadDataFiles'], {'target': 'ALL'}, reason: 'for input "$input"');
      }
    });

    test('a bare "RELOAD" expects params — it is recognized but not executable yet', () async {
      final result = await interpret('RELOAD');
      expect(result, {'expectsParams': true});
    });

    test('"RELOAD! POTA" and "RELOADALL POTA" are ambiguous and are not commands', () async {
      expect(await interpret('RELOAD! POTA'), isNull);
      expect(await interpret('RELOADALL POTA'), isNull);
    });
  });

  test('syncAllDataFiles(categoryFilter:) reprocesses only the matching category, force bypasses ETag', () async {
    final defs = await extensions.host!.invokeHookAll('dataFile', method: 'getDefinition');
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

    // Seed both, as syncAllDataFiles() would at boot.
    await manager.processDataFile('pota-all-parks', potaDef);
    await manager.processDataFile('sota-all-summits', sotaDef);
    expect(manager.callsForPota, 1);
    expect(manager.callsForSota, 1);

    // "RELOAD POTA" — only POTA's downloadFile should be called again.
    final matched = await manager.syncAllDataFiles(force: true, categoryFilter: 'POTA');
    expect(matched, 1);
    expect(manager.callsForPota, 2);
    expect(manager.callsForSota, 1); // untouched
  });
}

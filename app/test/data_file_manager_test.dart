// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/data_file_manager.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late LookupRepository lookups;
  late SharedPreferences prefs;
  late ExtensionService extensions;
  late DataFileManager manager;

  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    lookups = LookupRepository(db);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    extensions = ExtensionService();
    manager = DataFileManager(
      lookups: lookups,
      extensions: extensions,
      prefs: prefs,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('DataFileManager: resolveDownloadUrl logic', () {
    expect(
      manager.resolveDownloadUrl('https://www.dropbox.com/s/abcdef/file.csv?dl=0'),
      'https://www.dropbox.com/s/abcdef/file.csv?dl=1&raw=1',
    );
    expect(
      manager.resolveDownloadUrl('https://drive.google.com/file/d/123456_789/view?usp=sharing'),
      'https://drive.google.com/uc?id=123456_789&export=download',
    );
  });

  test('DataFileManager: parseCsvRow matches standard CSV expectations', () {
    // Basic comma separated
    expect(manager.parseCsvRow('val1,val2,val3', ','), ['val1', 'val2', 'val3']);
    // Delimiter in quotes
    expect(manager.parseCsvRow('val1,"val2,with,comma",val3', ','), ['val1', 'val2,with,comma', 'val3']);
    // Escaped quotes inside quotes
    expect(manager.parseCsvRow('val1,"val2 ""nested"" quotes",val3', ','), ['val1', 'val2 "nested" quotes', 'val3']);
  });

  test('DataFileManager: resolveRootPath navigates nested JSON maps', () {
    final Map<String, dynamic> doc = {
      'metadata': {
        'version': '1.0'
      },
      'results': [
        {'id': 1},
        {'id': 2}
      ]
    };

    expect(manager.resolveRootPath(doc, 'metadata.version'), '1.0');
    expect(manager.resolveRootPath(doc, 'results'), [
      {'id': 1},
      {'id': 2}
    ]);
    expect(manager.resolveRootPath(doc, 'nonexistent.path'), null);
  });

  test('DataFileManager: CSV parsing and Drift batch write integration', () async {
    final mockResults = <String, dynamic>{
      'dataFile:*:getDefinition': [
        {
          'key': 'test-csv-file',
          'ok': true,
          'value': {
            'key': 'test-csv-file',
            'name': 'Test CSV',
            'description': 'Testing CSV mapping',
            'url': 'https://example.com/test.csv',
            'maxAgeInDays': 10,
            'fetchType': 'csv',
            'category': 'test_category',
            'csvOptions': {
              'hasHeaders': true,
              'delimiter': ',',
            },
          }
        }
      ],
      'dataFile:test-csv-file:mapCsvBatch': (args) {
        final rows = args['rows'] as List;
        return rows.map((r) {
          final row = r as Map;
          return {
            'key': row['id'],
            'name': row['title'],
            'lat': double.tryParse(row['latitude'] ?? ''),
            'lon': double.tryParse(row['longitude'] ?? ''),
            'flags': 1,
            'data': {'note': 'Mapped in test'},
          };
        }).toList();
      }
    };

    final mockHost = MockExtensionHost(mockResults);
    final mockExtensions = MockExtensionService(mockHost);

    final managerWithMock = TestDataFileManager(
      lookups: lookups,
      extensions: mockExtensions,
      prefs: prefs,
    );

    managerWithMock.mockDownloadBody = '''id,title,latitude,longitude
REF-001,Summit One,45.12,-122.34
REF-002,Summit Two,45.56,-122.78
''';

    final def = {
      'key': 'test-csv-file',
      'fetchType': 'csv',
      'category': 'test_category',
      'csvOptions': {
        'hasHeaders': true,
        'delimiter': ',',
      },
      'url': 'https://example.com/test.csv',
    };

    await managerWithMock.processDataFile('test-csv-file', def);

    // Verify lookup rows are inserted in DB
    final row1 = await lookups.getLookup('test_category', 'REF-001');
    expect(row1, isNotNull);
    expect(row1!.name, 'Summit One');
    expect(row1.lat, 45.12);
    expect(row1.lon, -122.34);

    final row2 = await lookups.getLookup('test_category', 'REF-002');
    expect(row2, isNotNull);
    expect(row2!.name, 'Summit Two');
  });

  test('DataFileManager: JSON parsing and Drift batch write integration', () async {
    final mockResults = <String, dynamic>{
      'dataFile:test-json-file:mapJsonBatch': (args) {
        final entries = args['entries'] as List;
        return entries.map((e) {
          final entry = e as Map;
          return {
            'key': entry['key'],
            'name': entry['value']['name'],
            'lat': entry['value']['lat'],
            'lon': entry['value']['lon'],
            'flags': 1,
            'data': {'note': 'Mapped in test'},
          };
        }).toList();
      }
    };

    final mockHost = MockExtensionHost(mockResults);
    final mockExtensions = MockExtensionService(mockHost);

    final managerWithMock = TestDataFileManager(
      lookups: lookups,
      extensions: mockExtensions,
      prefs: prefs,
    );

    managerWithMock.mockDownloadBody = jsonEncode({
      'G/LD-001': {'name': 'Scafell Pike', 'lat': 54.45, 'lon': -3.21},
      'G/LD-002': {'name': 'Helvellyn', 'lat': 54.52, 'lon': -3.01},
    });

    final def = {
      'key': 'test-json-file',
      'fetchType': 'json',
      'category': 'test_json_category',
      'jsonOptions': {
        'rootPath': '',
      },
      'url': 'https://example.com/test.json',
    };

    await managerWithMock.processDataFile('test-json-file', def);

    // Verify lookup rows are inserted in DB
    final row1 = await lookups.getLookup('test_json_category', 'G/LD-001');
    expect(row1, isNotNull);
    expect(row1!.name, 'Scafell Pike');
    expect(row1.lat, 54.45);
    expect(row1.lon, -3.21);

    final row2 = await lookups.getLookup('test_json_category', 'G/LD-002');
    expect(row2, isNotNull);
    expect(row2!.name, 'Helvellyn');
  });

  test('DataFileManager: syncAllDataFiles isolates one malformed definition from the rest', () async {
    final mockResults = <String, dynamic>{
      'dataFile:*:getDefinition': [
        {
          // Missing 'key' — throws when cast during syncAllDataFiles, before
          // this entry can even be counted as "matched". Must not prevent
          // the other, well-formed entry below from being processed.
          'key': 'malformed',
          'ok': true,
          'value': {'name': 'Missing key field'},
        },
        {
          'key': 'good-csv-file',
          'ok': true,
          'value': {
            'key': 'good-csv-file',
            'name': 'Good CSV',
            'description': 'test',
            'url': 'https://example.com/good.csv',
            'maxAgeInDays': 10,
            'fetchType': 'csv',
            'category': 'good_category',
            'csvOptions': {'hasHeaders': true, 'delimiter': ','},
          },
        },
      ],
      'dataFile:good-csv-file:mapCsvBatch': (args) {
        final rows = args['rows'] as List;
        return rows.map((r) {
          final row = r as Map;
          return {'key': row['id'], 'name': row['title'], 'flags': 1};
        }).toList();
      },
    };

    final mockHost = MockExtensionHost(mockResults);
    final mockExtensions = MockExtensionService(mockHost);

    final managerWithMock = TestDataFileManager(
      lookups: lookups,
      extensions: mockExtensions,
      prefs: prefs,
    );
    managerWithMock.mockDownloadBody = 'id,title\nGOOD-1,Something\n';

    final matched = await managerWithMock.syncAllDataFiles();

    // The well-formed entry was still downloaded and processed despite the
    // other entry's cast throwing.
    final row = await lookups.getLookup('good_category', 'GOOD-1');
    expect(row, isNotNull);
    expect(row!.name, 'Something');
    // Only the entry that got far enough to determine its category counts.
    expect(matched, 1);
  });

  test('DataFileManager: listDataFiles reports definitions sorted by name with last-download time', () async {
    final host = MockExtensionHost({
      'dataFile:*:getDefinition': [
        {
          'key': 'zeta',
          'ok': true,
          'value': {'key': 'zeta', 'name': 'Zeta Data', 'description': 'z', 'maxAgeInDays': 30, 'category': 'zeta'},
        },
        {
          'key': 'alpha',
          'ok': true,
          'value': {'key': 'alpha', 'name': 'Alpha Data', 'description': 'a', 'maxAgeInDays': 7, 'category': 'alpha'},
        },
        // Dropped: not ok.
        {'key': 'broken', 'ok': false, 'value': null},
      ],
    });
    final m = DataFileManager(lookups: lookups, extensions: MockExtensionService(host), prefs: prefs);

    // Only 'alpha' has ever been downloaded.
    await prefs.setInt('data_file_updated_alpha', 5000);

    final files = await m.listDataFiles();
    expect(files.map((f) => f.key), ['alpha', 'zeta'], reason: 'sorted by name, malformed dropped');
    expect(files[0].name, 'Alpha Data');
    expect(files[0].updatedAt, DateTime.fromMillisecondsSinceEpoch(5000));
    expect(files[1].name, 'Zeta Data');
    expect(files[1].updatedAt, isNull, reason: 'never downloaded');
  });

  test('DataFileManager: refreshDataFile force-fetches one file, stamps its time, and reports unknown keys', () async {
    final host = MockExtensionHost({
      'dataFile:*:getDefinition': [
        {
          'key': 'refresh-csv',
          'ok': true,
          'value': {
            'key': 'refresh-csv',
            'name': 'Refreshable',
            'url': 'https://example.com/r.csv',
            'maxAgeInDays': 10,
            'fetchType': 'csv',
            'category': 'refresh_category',
            'csvOptions': {'hasHeaders': true, 'delimiter': ','},
          },
        },
      ],
      'dataFile:refresh-csv:mapCsvBatch': (args) => [
            for (final r in (args['rows'] as List)) {'key': (r as Map)['ref'], 'name': r['name']},
          ],
    });
    final m = TestDataFileManager(lookups: lookups, extensions: MockExtensionService(host), prefs: prefs)
      ..mockDownloadBody = 'ref,name\nR-1,Refreshed\n';

    final stampedAt = await m.refreshDataFile('refresh-csv');
    expect(stampedAt, isNotNull, reason: 'returns the stamped last-download time');
    expect((await lookups.getLookup('refresh_category', 'R-1'))?.name, 'Refreshed');
    expect(
      prefs.getInt('data_file_updated_refresh-csv'),
      stampedAt!.millisecondsSinceEpoch,
      reason: 'returned time matches what was persisted',
    );

    expect(await m.refreshDataFile('does-not-exist'), isNull, reason: 'unknown key');
  });

  group('stale extension data purge', () {
    // Syncs a CSV data file owned by extension `pota` (category `pota`), so
    // ownership + lookup rows exist to purge. Returns the manager holding
    // that state.
    late StatusBarService statusBar;
    Future<TestDataFileManager> syncPotaDataFile() async {
      statusBar = StatusBarService(prefs);
      final host = MockExtensionHost({
        'dataFile:*:getDefinition': [
          {
            'key': 'pota-all-parks',
            'ok': true,
            'value': {
              'key': 'pota-all-parks',
              'extensionKey': 'pota',
              'name': 'Parks',
              'description': '',
              'url': 'https://example.com/parks.csv',
              'maxAgeInDays': 10,
              'fetchType': 'csv',
              'category': 'pota',
            },
          },
        ],
        'dataFile:pota-all-parks:mapCsvBatch': (args) => [
              for (final r in (args['rows'] as List)) {'key': (r as Map)['ref'], 'name': r['name']},
            ],
      });
      final m = TestDataFileManager(
        lookups: lookups,
        extensions: MockExtensionService(host),
        prefs: prefs,
        statusBar: statusBar,
      )..mockDownloadBody = 'ref,name\nUS-0001,A Park\n';
      await m.syncAllDataFiles();
      return m;
    }

    test('purges data of an extension disabled beyond the grace period', () async {
      final m = await syncPotaDataFile();
      expect(await lookups.getLookup('pota', 'US-0001'), isNotNull);
      expect(prefs.getString('data_file_ownership'), contains('pota'));

      final now = DateTime.fromMillisecondsSinceEpoch(1000 * 24 * 3600 * 1000);
      // Disabled 8 days ago → past the 7-day grace.
      await m.purgeStaleExtensionData(
        {'pota': now.subtract(const Duration(days: 8)).millisecondsSinceEpoch},
        now: now,
      );

      expect(await lookups.getLookup('pota', 'US-0001'), isNull, reason: 'stale data purged');
      expect(prefs.getString('data_file_ownership'), isNot(contains('pota')), reason: 'ownership pruned');
      expect(prefs.getString('data_file_updated_pota-all-parks'), isNull);
      // A status message reports the cleanup.
      final notice = statusBar.items.firstWhere((i) => i.key == 'dataFile:purge');
      expect(notice.text, contains('1 data file'));
    });

    test('keeps data of an extension disabled within the grace period', () async {
      final m = await syncPotaDataFile();
      final now = DateTime.fromMillisecondsSinceEpoch(1000 * 24 * 3600 * 1000);
      await m.purgeStaleExtensionData(
        {'pota': now.subtract(const Duration(days: 3)).millisecondsSinceEpoch},
        now: now,
      );
      expect(await lookups.getLookup('pota', 'US-0001'), isNotNull, reason: 'recent disable keeps data');
    });

    test('leaves an enabled extension (no disabledSince entry) untouched', () async {
      final m = await syncPotaDataFile();
      await m.purgeStaleExtensionData(const {});
      expect(await lookups.getLookup('pota', 'US-0001'), isNotNull);
    });
  });
}

class MockExtensionHost implements ExtensionHost {
  final Map<String, dynamic> mockHookResults;
  MockExtensionHost(this.mockHookResults);

  @override
  Future<dynamic> invokeHook(
    String category, {
    String? key,
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final hookKey = '$category:$key:$method';
    if (mockHookResults.containsKey(hookKey)) {
      final res = mockHookResults[hookKey];
      if (res is Function) {
        return res(args);
      }
      return res;
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final hookKey = '$category:*:$method';
    if (mockHookResults.containsKey(hookKey)) {
      return (mockHookResults[hookKey] as List).cast<Map<String, dynamic>>();
    }
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockExtensionService extends ExtensionService {
  final MockExtensionHost mockHost;
  MockExtensionService(this.mockHost);

  @override
  ExtensionHost? get host => mockHost;
}

class TestDataFileManager extends DataFileManager {
  String? mockDownloadBody;

  TestDataFileManager({
    required super.lookups,
    required super.extensions,
    required super.prefs,
    super.statusBar,
  });

  @override
  Future<String?> downloadFile(String key, String url, {bool force = false}) async {
    return mockDownloadBody;
  }
}

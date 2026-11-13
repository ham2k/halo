// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A `sqlite` data file through the app's DataFileManager — Super Check
// Partial's SCP.DB is the one it exists for. Reading the file is halo_core's,
// tested there; these cover what reaches Lookups, and the ETag: kept only
// once the rows are in, so a file downloaded and never imported is
// downloaded again rather than answered 304, which would stamp it fresh with
// nothing in the table.

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:ham2k_logger/services/data_file_manager.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';

import '../support/halo_test_support.dart';

const _url = 'https://example.test/SCP.DB';

const _def = <String, dynamic>{
  'key': 'scp',
  'name': 'Super Check Partial',
  'fetchType': 'sqlite',
  'category': 'scp',
  'url': _url,
  'sqliteQuery': 'SELECT callsign, annual_rate AS rate, modes FROM callsigns',
  'fields': {'key': 'callsign'},
};

Uint8List _scpDb(List<(String, int)> calls) {
  final dir = Directory.systemTemp.createTempSync('scp');
  final path = '${dir.path}/SCP.DB';
  final db = sqlite3.open(path)..execute('CREATE TABLE callsigns (callsign TEXT PRIMARY KEY, annual_rate INTEGER, modes INTEGER)');
  for (final (call, rate) in calls) {
    db.execute('INSERT INTO callsigns VALUES (?, ?, 5)', [call, rate]);
  }
  db.dispose();
  final bytes = File(path).readAsBytesSync();
  dir.deleteSync(recursive: true);
  return bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late LookupRepository lookups;
  late SharedPreferences prefs;
  late List<http.BaseRequest> requested;
  late http.Response Function(http.BaseRequest) answer;

  setUp(() async {
    PackageInfo.setMockInitialValues(appName: 'test', packageName: 'test', version: '1.0', buildNumber: '1', buildSignature: '');
    db = HaLoDatabase(NativeDatabase.memory());
    lookups = LookupRepository(db);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    requested = [];
    answer = (_) => http.Response('', 404);
  });
  tearDown(() => db.close());

  DataFileManager manager({ExtensionService? extensions}) => DataFileManager(
    lookups: lookups,
    extensions: extensions ?? _Granting(),
    prefs: prefs,
    isWeb: false,
    httpClientFactory: ({required guarded}) => http.MockClient((request) async {
      requested.add(request);
      return answer(request);
    }),
  );

  test("the rows land as the query selects them, keyed by the definition's field, and the next sync asks with the ETag", () async {
    answer = (request) => request.headers['If-None-Match'] == '"v1"'
        ? http.Response('', 304)
        : http.Response.bytes(_scpDb([('K1AB', 807), ('W1AW', 12)]), 200, headers: {'etag': '"v1"'});
    final m = manager();

    expect(await m.processDataFile('scp', _def), isTrue);
    final row = await lookups.getLookup('scp', 'K1AB');
    expect(row?.data, '{"callsign":"K1AB","rate":807,"modes":5}');
    expect(await lookups.countCategory('scp'), 2);
    expect(requested.single.headers['User-Agent'], contains('1.0'), reason: "SCP asks every client to name itself and its version");

    expect(await m.processDataFile('scp', _def), isFalse, reason: 'unchanged: 304');
    expect(await lookups.countCategory('scp'), 2);
  });

  test("without fields, each row goes to the extension's mapper as an object, and its entries land", () async {
    answer = (_) => http.Response.bytes(_scpDb([('K1AB', 807)]), 200);
    final mapped = <Object?>[];
    final extensions = _GrantingWithHost(
      FakeExtensionHost({
        'dataFile:scp:mapJsonBatch': (Map<String, dynamic> args) {
          mapped.addAll(args['entries'] as List);
          return [
            for (final row in (args['entries'] as List).cast<Map<dynamic, dynamic>>())
              {
                'key': row['callsign'],
                'data': {'rate': row['rate']},
              },
          ];
        },
      }),
    );

    await manager(extensions: extensions).processDataFile('scp', {..._def}..remove('fields'));

    expect(mapped, [
      {'callsign': 'K1AB', 'rate': 807, 'modes': 5},
    ]);
    expect((await lookups.getLookup('scp', 'K1AB'))?.data, '{"rate":807}');
  });

  test('a page answered in place of the database fails the download, and leaves no ETag to answer the next sync with 304', () async {
    answer = (_) => http.Response.bytes('<html>Sign in to the hotel Wi-Fi</html>'.codeUnits, 200, headers: {'etag': '"v1"'});
    await expectLater(manager().processDataFile('scp', _def), throwsA(isA<DataFileNotADatabase>()));
    expect(prefs.getString('data_file_etag_scp'), isNull);
  });

  // An offline boot's failed sync must not cost the next one its 304: the
  // whole file downloaded and imported again with nothing changed.
  test('a download that fails keeps the ETag; an import that fails drops it', () async {
    answer = (_) => http.Response.bytes(_scpDb([('K1AB', 807)]), 200, headers: {'etag': '"v1"'});
    await manager().processDataFile('scp', _def);
    answer = (_) => throw http.ClientException('offline');
    await expectLater(manager().processDataFile('scp', _def), throwsA(isA<http.ClientException>()));
    expect(prefs.getString('data_file_etag_scp'), '"v1"');

    // A new file the query cannot read: downloaded, its ETag stored, and the
    // import failing after.
    answer = (_) => http.Response.bytes(_scpDb([('K1AB', 807)]), 200, headers: {'etag': '"v2"'});
    await expectLater(manager().processDataFile('scp', {..._def, 'sqliteQuery': 'SELECT nothing FROM callsigns'}), throwsA(isA<SqliteDataFileUnreadable>()));
    expect(prefs.getString('data_file_etag_scp'), isNull, reason: 'kept, the next sync would be answered 304 with the new file never imported');
  });

  test('a definition with no query fails before the file is downloaded', () async {
    answer = (_) => http.Response.bytes(_scpDb([('K1AB', 807)]), 200);
    await expectLater(manager().processDataFile('scp', {..._def}..remove('sqliteQuery')), throwsFormatException);
    expect(requested, isEmpty, reason: 'every sync would fetch the whole file only to fail on it');
  });

  test('a key column of numbers keys by their text, and a key column no row has fails rather than importing nothing', () async {
    answer = (_) => http.Response.bytes(_scpDb([('K1AB', 807)]), 200);
    await manager().processDataFile('scp', {
      ..._def,
      'fields': {'key': 'rate'},
    });
    expect(await lookups.getLookup('scp', '807'), isNotNull);

    await expectLater(
      manager().processDataFile('scp', {
        ..._def,
        'fields': {'key': 'call'},
      }),
      throwsA(isA<SqliteDataFileUnreadable>()),
    );
    await expectLater(
      manager().processDataFile('scp', {
        ..._def,
        'fields': {'name': 'callsign'},
      }),
      throwsFormatException,
      reason: 'fields with no key',
    );
  });

  test('a file that brings far fewer rows than the category holds is refused, and what it held stays', () async {
    answer = (_) => http.Response.bytes(_scpDb([for (var i = 0; i < 200; i++) ('K${i}AB', i)]), 200);
    await manager().processDataFile('scp', _def);
    answer = (_) => http.Response.bytes(_scpDb([('K1AB', 807)]), 200);

    await expectLater(manager().processDataFile('scp', _def), throwsA(isA<DataFileImportShrank>()));
    expect(await lookups.countCategory('scp'), 200);
  });
}

class _GrantingWithHost extends ExtensionServiceWithFakeHost {
  _GrantingWithHost(super.host);

  @override
  ExtensionNetworkGrant networkGrantFor(String? extensionKey) => const ExtensionNetworkGrant(extensionKey: 'lookups', domains: ['example.test']);
}

class _Granting extends ExtensionService {
  @override
  ExtensionNetworkGrant networkGrantFor(String? extensionKey) => const ExtensionNetworkGrant(extensionKey: 'lookups', domains: ['example.test']);
}

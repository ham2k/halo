// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A `ham2k` data file through the app's DataFileManager: where the version
// held is kept, when the delta is asked for, and what a failure leaves behind.
// The import itself is halo_core's, tested there.

import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/services/data_file_manager.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';

const _def = <String, dynamic>{
  'key': 'calls-hf',
  'name': 'HF calls',
  'fetchType': 'ham2k',
  'category': 'calls-hf',
  'url': 'https://example.test/download?set=hf',
  'deltaUrl': 'https://example.test/delta?set=hf&since={since}',
  'fields': {'key': 'call', 'name': 'name'},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late LookupRepository lookups;
  late SharedPreferences prefs;
  late List<String> requested;
  late Map<String, http.Response> answers;

  setUp(() async {
    PackageInfo.setMockInitialValues(appName: 'test', packageName: 'test', version: '1.0', buildNumber: '1', buildSignature: '');
    db = HaLoDatabase(NativeDatabase.memory());
    lookups = LookupRepository(db);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    requested = [];
    answers = {};
  });
  tearDown(() => db.close());

  DataFileManager manager({StatusBarService? statusBar}) => DataFileManager(
    lookups: lookups,
    extensions: ExtensionService(),
    prefs: prefs,
    statusBar: statusBar,
    isWeb: false,
    httpClientFactory: () => http.MockClient((request) async {
      requested.add('${request.url}');
      return answers['${request.url}'] ?? http.Response('', 404);
    }),
  );

  http.Response answer(String body, {String? version, int status = 200}) => http.Response(body, status, headers: {'x-lookups-version': ?version});

  String ndjson(List<Map<String, Object?>> records) => records.map((r) => '${jsonEncode(r)}\n').join();

  test('the version a snapshot brings is held, and the next sync asks for the delta from it', () async {
    answers['https://example.test/download?set=hf'] = answer(
      ndjson([
        {'call': 'W1AW', 'name': 'ARRL'},
      ]),
      version: 'v1',
    );
    answers['https://example.test/delta?set=hf&since=v1'] = answer(
      jsonEncode({
        'added': [
          {'call': 'K2A'},
        ],
        'changed': <Object>[],
        'removed': ['W1AW'],
      }),
      version: 'v2',
    );
    final m = manager();

    expect(await m.processDataFile('calls-hf', _def), isTrue);
    expect(prefs.getString('data_file_etag_calls-hf'), 'ham2k:v1');

    expect(await m.processDataFile('calls-hf', _def), isTrue);
    expect(requested.last, 'https://example.test/delta?set=hf&since=v1', reason: 'a device holding a version must not download the snapshot again');
    expect(prefs.getString('data_file_etag_calls-hf'), 'ham2k:v2');
    expect([for (final row in await lookups.queryLookups('calls-hf', '')) row.key], ['K2A']);
  });

  test('an ETag left by another kind of file is not taken for a version', () async {
    await prefs.setString('data_file_etag_calls-hf', '"abc123"');
    answers['https://example.test/download?set=hf'] = answer(
      ndjson([
        {'call': 'W1AW'},
      ]),
      version: 'v1',
    );

    await manager().processDataFile('calls-hf', _def);

    expect(requested, ['https://example.test/download?set=hf']);
  });

  test('a forced refresh takes the snapshot even with a version held', () async {
    await prefs.setString('data_file_etag_calls-hf', 'ham2k:v1');
    answers['https://example.test/download?set=hf'] = answer(
      ndjson([
        {'call': 'W1AW'},
      ]),
      version: 'v2',
    );

    await manager().processDataFile('calls-hf', _def, force: true);

    expect(requested, ['https://example.test/download?set=hf']);
    expect(prefs.getString('data_file_etag_calls-hf'), 'ham2k:v2');
  });

  test('a failed delta keeps the version held, so the next sync asks for the delta again', () async {
    await lookups.insertLookupBatch([LookupRow(category: 'calls-hf', key: 'W1AW', updated: 1)]);
    await prefs.setString('data_file_etag_calls-hf', 'ham2k:v1');
    answers['https://example.test/delta?set=hf&since=v1'] = answer('oops', status: 500);
    final statusBar = StatusBarService(prefs);

    await expectLater(manager(statusBar: statusBar).processDataFile('calls-hf', _def), throwsA(isA<DataFileUnavailable>()));

    // Dropped, a device that tries its sync offline downloads the whole
    // snapshot when it reconnects, for a category the failure never touched.
    expect(prefs.getString('data_file_etag_calls-hf'), 'ham2k:v1');
    final notice = statusBar.activeNotices.singleWhere((n) => n.key == 'dataFile:calls-hf');
    expect(notice.title, t.dataFiles.downloadFailedTitle(name: 'HF calls'), reason: 'a failed fetch reads as a download failure, not a processing one');
  });

  test('a snapshot cut partway leaves no version held, and reads as a download failure', () async {
    await prefs.setString('data_file_etag_calls-hf', 'ham2k:v0');
    final statusBar = StatusBarService(prefs);
    final m = DataFileManager(
      lookups: lookups,
      extensions: ExtensionService(),
      prefs: prefs,
      statusBar: statusBar,
      isWeb: false,
      httpClientFactory: () => http.MockClient.streaming((request, _) async {
        // The rows before the cut are written: the category is now at no
        // version, and a delta from v0 would build on rows it no longer holds.
        Stream<List<int>> body() async* {
          yield utf8.encode(
            ndjson([
              for (var i = 0; i < 5001; i++) {'call': 'C$i'},
            ]),
          );
          // What a dropped connection is on iOS and Android: not a
          // ClientException, and worded as a file the app could not process
          // unless every IOException counts as a failed fetch.
          throw const SocketException('Connection reset by peer');
        }

        return http.StreamedResponse(body(), 200, headers: {'x-lookups-version': 'v1'});
      }),
    );

    await expectLater(m.processDataFile('calls-hf', _def), throwsA(isA<SocketException>()));

    expect(prefs.getString('data_file_etag_calls-hf'), isNull);
    final notice = statusBar.activeNotices.singleWhere((n) => n.key == 'dataFile:calls-hf');
    expect(notice.title, t.dataFiles.downloadFailedTitle(name: 'HF calls'));
  });

  test('a server that names no version leaves none held', () async {
    await prefs.setString('data_file_etag_calls-hf', 'ham2k:v0');
    answers['https://example.test/delta?set=hf&since=v0'] = answer('', status: 410);
    answers['https://example.test/download?set=hf'] = answer(
      ndjson([
        {'call': 'W1AW'},
      ]),
    );

    await manager().processDataFile('calls-hf', _def);

    expect(prefs.getString('data_file_etag_calls-hf'), isNull);
  });
}

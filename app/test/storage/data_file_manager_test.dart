// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http;
import 'package:path/path.dart' as p;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/app_storage.dart' show kDataFilesDirName;
import 'package:ham2k_logger/services/data_file_manager.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';

import '../support/halo_test_support.dart';

/// Mirrors the zip the real kernel performs (`extensions/sdk/src/kernel.ts`).
///
/// The host sends CSV rows POSITIONALLY plus one `headers` list per chunk, and
/// the kernel rebuilds the `Record<string,string>` that `csvToLookupEntry`
/// actually sees — that split is what keeps ~61% of the payload (a repeat of
/// every column name on every row) off the boundary (APP-16). The mocks below
/// stand in for the kernel, so they have to zip the same way; a mock that read
/// `rows` as maps would pass while the real extensions received lists.
List<Map<String, dynamic>> zipCsvRows(dynamic args) {
  final headers = (args['headers'] as List?)?.cast<String>();
  if (headers == null) {
    // `hasHeaders: false` — the kernel hands the mapper the positional row
    // untouched. Mirrored here so this helper stays a faithful stand-in rather
    // than throwing an opaque cast error the day a fixture needs that path.
    return [
      for (final row in (args['rows'] as List)) {for (var j = 0; j < (row as List).length; j++) '$j': row[j]},
    ];
  }
  return [
    for (final row in (args['rows'] as List)) {for (var j = 0; j < headers.length && j < (row as List).length; j++) headers[j]: row[j]},
  ];
}

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
    manager = DataFileManager(lookups: lookups, extensions: extensions, prefs: prefs);
  });

  tearDown(() async {
    await db.close();
  });

  test('DataFileManager: resolveDownloadUrl logic', () {
    expect(manager.resolveDownloadUrl('https://www.dropbox.com/s/abcdef/file.csv?dl=0'), 'https://www.dropbox.com/s/abcdef/file.csv?dl=1&raw=1');
    expect(
      manager.resolveDownloadUrl('https://drive.google.com/file/d/123456_789/view?usp=sharing'),
      'https://drive.google.com/uc?id=123456_789&export=download',
    );
    expect(
      // The share page is HTML, not the file's content — `/raw` (no
      // filename) redirects to the latest revision's raw content.
      manager.resolveDownloadUrl('https://gist.github.com/octocat/6cad326836d38bd3a7ae'),
      'https://gist.githubusercontent.com/octocat/6cad326836d38bd3a7ae/raw',
    );
    expect(
      // Pre-2018 anonymous gists have no username in their URL at all.
      manager.resolveDownloadUrl('https://gist.github.com/6cad326836d38bd3a7ae'),
      'https://gist.githubusercontent.com/6cad326836d38bd3a7ae/raw',
      reason: 'an owner-less gist URL must still resolve, not silently pass through unchanged',
    );
    expect(
      // Dropbox serves share links from both hosts; only www. is in the web
      // CORS-proxy allowlist (_resolveFetchUrl), so the bare host must be
      // normalized here or a web download would still fail.
      manager.resolveDownloadUrl('https://dropbox.com/s/abcdef/file.csv?dl=0'),
      'https://www.dropbox.com/s/abcdef/file.csv?dl=1&raw=1',
    );
    expect(
      // Already a direct link to one specific file in a multi-file gist —
      // rewriting it to the generic latest-revision `/raw` form would
      // discard the filename and silently fetch a different file
      //.
      manager.resolveDownloadUrl('https://gist.github.com/octocat/6cad326836d38bd3a7ae/raw/notes.txt'),
      'https://gist.github.com/octocat/6cad326836d38bd3a7ae/raw/notes.txt',
      reason: 'a URL naming a specific file must pass through unchanged, not be collapsed to the generic /raw form',
    );
    expect(
      // `raw` must be matched as a PATH SEGMENT, not a substring: an owner
      // whose username merely starts with "raw" is a share page like any
      // other, and skipping the rewrite would download the page's HTML and
      // ingest it as callsign entries.
      manager.resolveDownloadUrl('https://gist.github.com/rawmilk/6cad326836d38bd3a7ae'),
      'https://gist.githubusercontent.com/rawmilk/6cad326836d38bd3a7ae/raw',
      reason: 'a gist owner named raw* must not disable the raw rewrite',
    );
  });

  test('DataFileManager: refreshDataFile with no matching definition raises a notice, not silence', () async {
    // The no-definition null return never reaches processDataFile, so
    // without a notice HERE a Refresh tap ends in nothing: spinner stops,
    // timestamp unchanged, no signal anywhere (the host being mid-restart —
    // exactly when the user is editing these settings — is the common way
    // to get here).
    final statusBar = StatusBarService(prefs);
    final m = TestDataFileManager(
      lookups: lookups,
      extensions: MockExtensionService(FakeExtensionHost({'dataFile:*:getDefinition': <Map<String, dynamic>>[]})),
      prefs: prefs,
      statusBar: statusBar,
    );
    final result = await m.refreshDataFile('vanished-key');
    expect(result, isNull);
    final notice = statusBar.activeNotices.singleWhere((n) => n.key == 'dataFile:vanished-key');
    expect(notice.text, isNotEmpty, reason: 'a user-driven refresh that cannot run must say so');
  });

  group('friendlyDownloadError', () {
    test('a browser fetch failure (Chromium wording) on web gets a plain-language hint appended', () {
      final result = friendlyDownloadError(http.ClientException('Failed to fetch', Uri.parse('https://example.com')), isWeb: true);
      expect(result, contains('Failed to fetch'), reason: 'the raw detail is kept, not hidden');
      expect(result, contains(t.dataFiles.downloadFailedWebHint));
    });

    test('the same failure phrased in Firefox/Safari wording still gets the hint — checked by TYPE, not message text', () {
      // The whole point of matching on `error is http.ClientException` rather
      // than the literal string 'Failed to fetch' (Chromium/V8's own
      // wording): a non-Chromium browser's identical underlying failure is
      // still a ClientException, just phrased differently — this must not
      // silently miss it.
      final result = friendlyDownloadError(
        http.ClientException('NetworkError when attempting to fetch resource.', Uri.parse('https://example.com')),
        isWeb: true,
      );
      expect(result, contains(t.dataFiles.downloadFailedWebHint));
    });

    test('the same exception type on a non-web platform is shown as-is — this hint is web-only', () {
      final result = friendlyDownloadError(http.ClientException('Failed to fetch', Uri.parse('https://example.com')), isWeb: false);
      expect(result, isNot(contains(t.dataFiles.downloadFailedWebHint)));
    });

    test('an unrelated failure (e.g. a 404) is shown as-is, even on web — guessing would mislead', () {
      final result = friendlyDownloadError(Exception('HttpException: Failed to download x: HTTP 404'), isWeb: true);
      expect(result, isNot(contains(t.dataFiles.downloadFailedWebHint)));
    });
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
            'csvOptions': {'hasHeaders': true, 'delimiter': ','},
          },
        },
      ],
      'dataFile:test-csv-file:mapCsvBatch': (args) {
        return zipCsvRows(args).map((row) {
          return {
            'key': row['id'],
            'name': row['title'],
            'lat': double.tryParse(row['latitude'] as String? ?? ''),
            'lon': double.tryParse(row['longitude'] as String? ?? ''),
            'flags': 1,
            'data': {'note': 'Mapped in test'},
          };
        }).toList();
      },
    };

    final mockHost = FakeExtensionHost(mockResults);
    final mockExtensions = MockExtensionService(mockHost);

    final managerWithMock = TestDataFileManager(lookups: lookups, extensions: mockExtensions, prefs: prefs);

    managerWithMock.mockDownloadBody = '''id,title,latitude,longitude
REF-001,Summit One,45.12,-122.34
REF-002,Summit Two,45.56,-122.78
''';

    final def = {
      'key': 'test-csv-file',
      'fetchType': 'csv',
      'category': 'test_category',
      'csvOptions': {'hasHeaders': true, 'delimiter': ','},
      'url': 'https://example.com/test.csv',
    };

    await managerWithMock.processDataFile('test-csv-file', def);

    final row1 = await lookups.getLookup('test_category', 'REF-001');
    expect(row1, isNotNull);
    expect(row1!.name, 'Summit One');
    expect(row1.lat, 45.12);
    expect(row1.lon, -122.34);

    final row2 = await lookups.getLookup('test_category', 'REF-002');
    expect(row2, isNotNull);
    expect(row2!.name, 'Summit Two');
  });

  // An open Activities sheet re-searches on this tick: a tick for nothing
  // re-runs every open search, a tick per file runs one per file of a sweep,
  // and a missed tick leaves a freshly enabled extension's results empty
  // until the operator types again.
  group('dataRevision', () {
    Map<String, dynamic> csvDef(String key) => {
      'key': key,
      'fetchType': 'csv',
      'category': '${key}_category',
      'csvOptions': {'hasHeaders': true, 'delimiter': ','},
      'url': 'https://example.com/$key.csv',
    };

    test('ticks once for a sync pass that ingested files, never for a pass of 304s', () async {
      final host = FakeExtensionHost({
        'dataFile:*:getDefinition': [
          {'ok': true, 'value': csvDef('one')},
          {'ok': true, 'value': csvDef('two')},
        ],
        'dataFile:one:mapCsvBatch': (args) => zipCsvRows(args).map((row) => {'key': row['id'], 'name': row['id']}).toList(),
        'dataFile:two:mapCsvBatch': (args) => zipCsvRows(args).map((row) => {'key': row['id'], 'name': row['id']}).toList(),
      });
      final manager = TestDataFileManager(lookups: lookups, extensions: MockExtensionService(host), prefs: prefs);

      manager.mockDownloadBody = null;
      await manager.syncAllDataFiles();
      expect(manager.dataRevision.value, 0);

      manager.mockDownloadBody = 'id\nREF-1\n';
      await manager.syncAllDataFiles(force: true);
      expect(manager.dataRevision.value, 1);
    });

    test('ticks when cached raw files are imported into the runtime, and not when there are none', () async {
      final dir = await Directory.systemTemp.createTemp('halo-raw-');
      addTearDown(() => dir.delete(recursive: true));
      final imported = <Object?>[];
      final host = FakeExtensionHost({
        'dataFile:*:getDefinition': [
          {
            'ok': true,
            'value': {'key': 'rawfile', 'fetchType': 'raw'},
          },
        ],
        'dataFile:rawfile:onLoadRawData': (args) {
          imported.add(args);
          return null;
        },
      });
      final manager = DataFileManager(lookups: lookups, extensions: MockExtensionService(host), prefs: prefs, isWeb: false, dataDirectory: () async => dir);

      await manager.loadRawDataFiles();
      expect(manager.dataRevision.value, 0, reason: 'no cache on disk, nothing imported');

      final cache = File(p.join(dir.path, kDataFilesDirName, 'rawfile.json'));
      await cache.create(recursive: true);
      await cache.writeAsString('{"a": 1}');
      await manager.loadRawDataFiles();
      expect(imported, hasLength(1));
      expect(manager.dataRevision.value, 1);
    });

    test('ticks for an import that fails part way, since the rows it committed are searchable', () async {
      final host = FakeExtensionHost({
        'dataFile:half:mapCsvBatch': (args) => {'error': 'mapper blew up'},
      });
      final manager = TestDataFileManager(lookups: lookups, extensions: MockExtensionService(host), prefs: prefs)..mockDownloadBody = 'id\nREF-1\n';
      await expectLater(manager.processDataFile('half', csvDef('half'), notifyOnFailure: false), throwsA(anything));
      expect(manager.dataRevision.value, 1);
    });

    test('ticks when a data file is removed', () async {
      final dir = await Directory.systemTemp.createTemp('halo-remove-');
      addTearDown(() => dir.delete(recursive: true));
      final host = FakeExtensionHost({'dataFile:gone:onRemoveRawData': (args) => null});
      final manager = DataFileManager(lookups: lookups, extensions: MockExtensionService(host), prefs: prefs, isWeb: false, dataDirectory: () async => dir);
      await manager.removeDataFile('gone');
      expect(manager.dataRevision.value, 1);
    });
  });

  test('DataFileManager: a mapper that returns a non-list fails the file instead of emptying it', () async {
    // Regression guard for the worst shape of the old silent skip (APP-16).
    // A chunk whose response was not a List used to be passed over, so a
    // broken or absent mapper imported nothing — and then `deleteCategoryStale`
    // at the end of the run swept every row this run had not stamped, wiping
    // the whole category. Failing loudly is what keeps the last good copy of a
    // 181k-row list on disk when an extension update breaks its mapper.
    await lookups.insertLookupBatch([LookupRow(category: 'fragile_category', key: 'KEEP-1', name: 'Previously imported', updated: 1)]);

    final host = FakeExtensionHost({
      'dataFile:fragile-csv:mapCsvBatch': (args) => {'error': 'mapper blew up'}, // a Map, not a List
    });
    final m = TestDataFileManager(lookups: lookups, extensions: MockExtensionService(host), prefs: prefs)..mockDownloadBody = 'ref,name\nR-1,Fresh\n';

    await expectLater(
      m.processDataFile('fragile-csv', {
        'key': 'fragile-csv',
        'fetchType': 'csv',
        'category': 'fragile_category',
        'url': 'https://example.com/fragile.csv',
        'csvOptions': {'hasHeaders': true, 'delimiter': ','},
      }),
      throwsA(isA<ExtensionHostException>()),
      reason: 'the caller has to learn the file failed — settings_view surfaces it, syncAllDataFiles reports it',
    );

    expect(
      await lookups.getLookup('fragile_category', 'KEEP-1'),
      isNotNull,
      reason: 'bailing out must skip the stale sweep, leaving the previous import intact',
    );
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
      },
    };

    final mockHost = FakeExtensionHost(mockResults);
    final mockExtensions = MockExtensionService(mockHost);

    final managerWithMock = TestDataFileManager(lookups: lookups, extensions: mockExtensions, prefs: prefs);

    managerWithMock.mockDownloadBody = jsonEncode({
      'G/LD-001': {'name': 'Scafell Pike', 'lat': 54.45, 'lon': -3.21},
      'G/LD-002': {'name': 'Helvellyn', 'lat': 54.52, 'lon': -3.01},
    });

    final def = {
      'key': 'test-json-file',
      'fetchType': 'json',
      'category': 'test_json_category',
      'jsonOptions': {'rootPath': ''},
      'url': 'https://example.com/test.json',
    };

    await managerWithMock.processDataFile('test-json-file', def);

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
        return zipCsvRows(args).map((row) {
          return {'key': row['id'], 'name': row['title'], 'flags': 1};
        }).toList();
      },
    };

    final mockHost = FakeExtensionHost(mockResults);
    final mockExtensions = MockExtensionService(mockHost);

    final managerWithMock = TestDataFileManager(lookups: lookups, extensions: mockExtensions, prefs: prefs);
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

  test('DataFileManager: processDataFile raises a persistent notice and rethrows on a download failure', () async {
    final statusBar = StatusBarService(prefs);
    final managerWithMock = TestDataFileManager(lookups: lookups, extensions: extensions, prefs: prefs, statusBar: statusBar)
      ..mockDownloadError = Exception('ClientException: Failed to fetch, uri=https://example.com/notes.txt');

    final def = {'key': 'my-custom-file', 'name': 'My Custom File', 'url': 'https://example.com/notes.txt', 'fetchType': 'raw', 'category': 'call-notes'};

    await expectLater(
      managerWithMock.processDataFile('my-custom-file', def),
      throwsA(isA<Exception>()),
      reason: "the caller (a Refresh tap, Update All) still needs to know it failed — this doesn't swallow it",
    );

    final notice = statusBar.activeNotices.singleWhere((n) => n.key == 'dataFile:my-custom-file');
    expect(notice.title, t.dataFiles.downloadFailedTitle(name: 'My Custom File'));
    expect(notice.text, contains('Failed to fetch'));
    expect(statusBar.itemForKey('dataFile:my-custom-file'), isNull, reason: 'the transient progress line is cleared, not left spinning');
  });

  test('DataFileManager: a runtime that went away mid-import fails the file instead of stamping it fresh', () async {
    // A restart (an extension toggled, the catalog upgrade) nulls the host
    // between the download and the import. Returning quietly there reads as
    // success to the sync loop, which then stamps the file fresh for
    // maxAgeInDays with NOTHING imported — parks look present for a fortnight
    // while every lookup misses — and leaves the progress bar in the footer
    // with nobody left to clear it.
    final statusBar = StatusBarService(prefs);
    final managerWithMock = TestDataFileManager(lookups: lookups, extensions: _HostlessExtensionService(), prefs: prefs, statusBar: statusBar)
      ..mockDownloadBody = 'anything at all';

    final def = {'key': 'parks', 'name': 'All Parks', 'url': 'https://example.com/parks.txt', 'fetchType': 'raw', 'category': 'parks'};

    await expectLater(
      managerWithMock.processDataFile('parks', def, showProgress: true),
      throwsA(isA<ExtensionHostException>()),
      reason: 'the sync loop stamps the file fresh unless this throws',
    );

    expect(statusBar.itemForKey('dataFile:parks'), isNull, reason: 'the progress line is left spinning forever');
  });

  test('DataFileManager: a malformed definition (missing url/fetchType) still raises a notice, not a silent throw', () async {
    // _fetchDefinitions only checks that `value` is a Map — an extension's
    // getDefinition() could still return one missing url/fetchType. Before
    // this fix, def['url'] as String threw BEFORE the try block that shows
    // a notice, so callers like settings_view's _refresh (which now trusts
    // processDataFile to always notify before rethrowing) got nothing at all.
    final statusBar = StatusBarService(prefs);
    final managerWithMock = TestDataFileManager(lookups: lookups, extensions: extensions, prefs: prefs, statusBar: statusBar);

    final malformedDef = {'key': 'malformed-file', 'name': 'Malformed File', 'category': 'test'};

    await expectLater(managerWithMock.processDataFile('malformed-file', malformedDef), throwsA(isA<TypeError>()));

    final notice = statusBar.activeNotices.singleWhere((n) => n.key == 'dataFile:malformed-file');
    expect(
      notice.title,
      t.dataFiles.downloadFailedTitle(name: 'Malformed File'),
      reason: 'some notice must show — even a generically-labeled one beats total silence',
    );
  });

  test('DataFileManager: a failure AFTER a successful download (JSON parsing) gets a distinct "processing failed" '
      'notice, not "download failed"', () async {
    final statusBar = StatusBarService(prefs);
    final managerWithMock = TestDataFileManager(
      lookups: lookups,
      extensions: extensions,
      prefs: prefs,
      statusBar: statusBar,
      // A well-formed download, so the failure below can only come from
      // parsing — a misconfigured rootPath resolving to a scalar rather than
      // an Array or Object.
    )..mockDownloadBody = '{"meta": "not a list or map of entries"}';

    final def = {
      'key': 'my-json-file',
      'name': 'My JSON File',
      'url': 'https://example.com/data.json',
      'fetchType': 'json',
      'category': 'test',
      'jsonOptions': {'rootPath': 'meta'},
    };

    await expectLater(managerWithMock.processDataFile('my-json-file', def), throwsA(isA<FormatException>()));

    final notice = statusBar.activeNotices.singleWhere((n) => n.key == 'dataFile:my-json-file');
    expect(
      notice.title,
      t.dataFiles.processingFailedTitle(name: 'My JSON File'),
      reason: 'the download itself succeeded — mislabeling this "download failed" would misdiagnose a config bug as a network one',
    );
    expect(notice.title, isNot(t.dataFiles.downloadFailedTitle(name: 'My JSON File')));
  });

  test('DataFileManager: a download failure during syncAllDataFiles (the background/boot/onboarding path) also raises a notice', () async {
    // syncAllDataFiles is what app boot, onboarding completion, and "Update
    // All" call — not just an explicit per-file Refresh tap. This proves the
    // same processDataFile notice fires through THAT path too, not only when
    // called directly (see the test above), closing that coverage gap.
    final statusBar = StatusBarService(prefs);
    final mockHost = FakeExtensionHost({
      'dataFile:*:getDefinition': [
        {
          'key': 'flaky-file',
          'ok': true,
          'value': {
            'key': 'flaky-file',
            'name': 'Flaky File',
            'url': 'https://example.com/flaky.txt',
            'maxAgeInDays': 10,
            'fetchType': 'raw',
            'category': 'flaky',
          },
        },
      ],
    });
    final managerWithMock = TestDataFileManager(lookups: lookups, extensions: MockExtensionService(mockHost), prefs: prefs, statusBar: statusBar)
      ..mockDownloadError = Exception('ClientException: Failed to fetch, uri=https://example.com/flaky.txt');

    // syncAllDataFiles isolates each entry's failure (per its own doc
    // comment) rather than letting it propagate — so this must not throw.
    await managerWithMock.syncAllDataFiles();

    final notice = statusBar.activeNotices.singleWhere((n) => n.key == 'dataFile:flaky-file');
    expect(notice.title, t.dataFiles.downloadFailedTitle(name: 'Flaky File'));
  });

  // The unattended sweeps (boot, reconnect) refresh files the device already
  // has; narrating each one in the footer turns every app start into a wall
  // of "Downloading… / Imported N records" for data nothing asked about. A
  // FIRST download is different: until it lands, its feature is simply
  // missing, so even an unattended pass says so. The mutation these three
  // exist to catch is the gate drifting to all-or-nothing — silencing first
  // downloads along with the refreshes, or narrating refreshes again.
  group('DataFileManager: unattended sync progress', () {
    late StatusBarService statusBar;
    late TestDataFileManager m;
    late Set<String> postedKeys;

    setUp(() {
      statusBar = StatusBarService(prefs);
      final mockHost = FakeExtensionHost({
        'dataFile:*:getDefinition': [
          {
            'key': 'sweep-file',
            'ok': true,
            'value': {
              'key': 'sweep-file',
              'name': 'Sweep File',
              'url': 'https://example.com/sweep.csv',
              'maxAgeInDays': 10,
              'fetchType': 'csv',
              'category': 'sweep',
              'csvOptions': {'hasHeaders': true, 'delimiter': ','},
            },
          },
        ],
        'dataFile:sweep-file:mapCsvBatch': (args) => zipCsvRows(args).map((row) => {'key': row['ref'], 'name': row['name']}).toList(),
      });
      m = TestDataFileManager(lookups: lookups, extensions: MockExtensionService(mockHost), prefs: prefs, statusBar: statusBar)
        ..mockDownloadBody = 'ref,name\nS-1,Swept\n';
      // itemForKey after the fact can't tell "never posted" from "posted and
      // cleared", so record every key that ever appears.
      postedKeys = {};
      statusBar.addListener(() => postedKeys.addAll(statusBar.items.map((i) => i.key)));
    });

    test('a known-but-stale file refreshes silently on an unattended pass', () async {
      await prefs.setInt('data_file_updated_sweep-file', 1);

      await m.syncAllDataFiles(notifyOnFailure: false);

      expect(await lookups.getLookup('sweep', 'S-1'), isNotNull, reason: 'silent must not mean skipped');
      expect(postedKeys.where((k) => k.startsWith('dataFile:')), isEmpty);
    });

    test('a first download narrates itself even on an unattended pass', () async {
      await m.syncAllDataFiles(notifyOnFailure: false);

      final item = statusBar.itemForKey('dataFile:sweep-file');
      expect(item?.text, t.dataFiles.importedRecords(count: 1, label: 'Sweep File'));
    });

    test('a user-driven pass (Update All, RELOAD) keeps progress for known files', () async {
      await prefs.setInt('data_file_updated_sweep-file', 1);

      await m.syncAllDataFiles(force: true);

      expect(statusBar.itemForKey('dataFile:sweep-file'), isNotNull);
    });
  });

  test('DataFileManager: listDataFiles reports definitions sorted by name with last-download time', () async {
    final host = FakeExtensionHost({
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

  // A stamp in the FUTURE means this file's freshness cannot be judged, so the
  // safe answer is to fetch — not to treat it as freshly updated. Read the other
  // way, the file is frozen for as long as the future stamp stands, which is
  // forever: nothing ever rewrites it, and Settings › Offline Data cheerfully
  // reports "updated just now" the whole time. A developer who time-travelled
  // forward and let a refresh stamp itself is one way to get here; a device whose
  // clock was wrong when it last synced is another.
  test('DataFileManager: a future last-updated stamp counts as stale, not as fresh', () async {
    final host = FakeExtensionHost({
      'dataFile:*:getDefinition': [
        {
          'key': 'future-csv',
          'ok': true,
          'value': {
            'key': 'future-csv',
            'name': 'Future Stamped',
            'url': 'https://example.com/f.csv',
            'maxAgeInDays': 30,
            'fetchType': 'csv',
            'category': 'future_category',
            'csvOptions': {'hasHeaders': true, 'delimiter': ','},
          },
        },
      ],
      'dataFile:future-csv:mapCsvBatch': (args) => [
        for (final r in zipCsvRows(args)) {'key': r['ref'], 'name': r['name']},
      ],
    });
    final m = TestDataFileManager(lookups: lookups, extensions: MockExtensionService(host), prefs: prefs)..mockDownloadBody = 'ref,name\nF-1,Fetched\n';

    // A year ahead — well inside the 30-day window if the age is read as-is.
    final future = DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch;
    await prefs.setInt('data_file_updated_future-csv', future);

    await m.syncAllDataFiles();

    expect((await lookups.getLookup('future_category', 'F-1'))?.name, 'Fetched', reason: 'the file must have been re-fetched, not skipped as fresh');
    expect(prefs.getInt('data_file_updated_future-csv'), lessThan(future), reason: 'and the future stamp must have been replaced');
  });

  test('DataFileManager: refreshDataFile force-fetches one file, stamps its time, and reports unknown keys', () async {
    final host = FakeExtensionHost({
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
        for (final r in zipCsvRows(args)) {'key': r['ref'], 'name': r['name']},
      ],
    });
    final m = TestDataFileManager(lookups: lookups, extensions: MockExtensionService(host), prefs: prefs)..mockDownloadBody = 'ref,name\nR-1,Refreshed\n';

    final stampedAt = await m.refreshDataFile('refresh-csv');
    expect(stampedAt, isNotNull, reason: 'returns the stamped last-download time');
    expect((await lookups.getLookup('refresh_category', 'R-1'))?.name, 'Refreshed');
    expect(prefs.getInt('data_file_updated_refresh-csv'), stampedAt!.millisecondsSinceEpoch, reason: 'returned time matches what was persisted');

    expect(await m.refreshDataFile('does-not-exist'), isNull, reason: 'unknown key');
  });

  group('stale extension data purge', () {
    // Syncs a CSV data file owned by extension `pota` (category `pota`), so
    // ownership + lookup rows exist to purge. Returns the manager holding
    // that state.
    late StatusBarService statusBar;
    Future<TestDataFileManager> syncPotaDataFile() async {
      statusBar = StatusBarService(prefs);
      final host = FakeExtensionHost({
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
          for (final r in zipCsvRows(args)) {'key': r['ref'], 'name': r['name']},
        ],
      });
      final m = TestDataFileManager(lookups: lookups, extensions: MockExtensionService(host), prefs: prefs, statusBar: statusBar)
        ..mockDownloadBody = 'ref,name\nUS-0001,A Park\n';
      await m.syncAllDataFiles();
      return m;
    }

    test('purges data of an extension disabled beyond the grace period', () async {
      final m = await syncPotaDataFile();
      expect(await lookups.getLookup('pota', 'US-0001'), isNotNull);
      expect(prefs.getString('data_file_ownership'), contains('pota'));

      final now = DateTime.fromMillisecondsSinceEpoch(1000 * 24 * 3600 * 1000);
      // Disabled 8 days ago → past the 7-day grace.
      await m.purgeStaleExtensionData({'pota': now.subtract(const Duration(days: 8)).millisecondsSinceEpoch}, now: now);

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
      await m.purgeStaleExtensionData({'pota': now.subtract(const Duration(days: 3)).millisecondsSinceEpoch}, now: now);
      expect(await lookups.getLookup('pota', 'US-0001'), isNotNull, reason: 'recent disable keeps data');
    });

    test('leaves an enabled extension (no disabledSince entry) untouched', () async {
      final m = await syncPotaDataFile();
      await m.purgeStaleExtensionData(const {});
      expect(await lookups.getLookup('pota', 'US-0001'), isNotNull);
    });
  });

  test('syncAllDataFiles purges a still-enabled extension\'s OLD key once it stops registering it', () async {
    // call-notes derives a customFiles entry's dataFile key (and, in this
    // fixture, its lookup category) from its URL, so editing the URL changes
    // both — the extension itself stays enabled and loaded the whole time.
    // Distinct categories per key isolate "orphan cleanup" from "the new
    // key's own resync happens to reinsert the same row" (the two share a
    // category in the real extension, but that's incidental to this fix).
    Map<String, dynamic> definitionFor(String key) => {
      'key': key,
      'ok': true,
      'value': {
        'key': key,
        'extensionKey': 'call-notes',
        'name': 'Custom Notes',
        'description': '',
        'url': 'https://example.com/notes.txt',
        'fetchType': 'csv',
        'category': key,
      },
    };

    final host = FakeExtensionHost({
      'dataFile:*:getDefinition': [definitionFor('custom-old')],
      'dataFile:custom-old:mapCsvBatch': (args) => [
        for (final r in zipCsvRows(args)) {'key': r['call'], 'name': r['note']},
      ],
      'dataFile:custom-new:mapCsvBatch': (args) => [
        for (final r in zipCsvRows(args)) {'key': r['call'], 'name': r['note']},
      ],
    });
    final m = TestDataFileManager(lookups: lookups, extensions: MockExtensionService(host), prefs: prefs, statusBar: StatusBarService(prefs))
      ..mockDownloadBody = 'call,note\nKI2D,Test Note\n';

    await m.syncAllDataFiles();
    expect(await lookups.getLookup('custom-old', 'KI2D'), isNotNull);
    expect(prefs.getString('data_file_ownership'), contains('custom-old'));
    expect(prefs.getInt('data_file_updated_custom-old'), isNotNull);

    // The user edited the custom file's URL — call-notes re-derives a new
    // identifier and no longer registers the old one, but is still enabled.
    host.stubs['dataFile:*:getDefinition'] = [definitionFor('custom-new')];
    await m.syncAllDataFiles();

    expect(prefs.getString('data_file_ownership'), isNot(contains('custom-old')), reason: 'the old key\'s ownership record must not linger forever');
    expect(prefs.getInt('data_file_updated_custom-old'), isNull, reason: 'orphaned prefs cleaned up');
    expect(await lookups.getLookup('custom-old', 'KI2D'), isNull, reason: 'orphaned lookup rows cleaned up');
    expect(await lookups.getLookup('custom-new', 'KI2D'), isNotNull, reason: 'the new key registers and syncs normally');
  });

  group('the orphan purge stands down on an untrustworthy snapshot', () {
    // Purging is destructive and the definition fan-out is its only
    // evidence. A snapshot that is provably partial — one record failed, or
    // activation never settled — must purge NOTHING: the cost of deferring
    // is a stale cache file, the cost of purging is destroying data that
    // cannot be re-downloaded offline.
    Map<String, dynamic> definitionFor(String key) => {
      'key': key,
      'ok': true,
      'value': {
        'key': key,
        'extensionKey': 'call-notes',
        'name': 'Custom Notes',
        'description': '',
        'url': 'https://example.com/notes.txt',
        'fetchType': 'csv',
        'category': key,
      },
    };

    Future<(TestDataFileManager, FakeExtensionHost, MockExtensionService)> seeded() async {
      final host = FakeExtensionHost({
        'dataFile:*:getDefinition': [definitionFor('custom-old')],
        'dataFile:custom-old:mapCsvBatch': (args) => [
          for (final r in zipCsvRows(args)) {'key': r['call'], 'name': r['note']},
        ],
      });
      final extensions = MockExtensionService(host);
      final m = TestDataFileManager(lookups: lookups, extensions: extensions, prefs: prefs, statusBar: StatusBarService(prefs))
        ..mockDownloadBody = 'call,note\nKI2D,Test Note\n';
      await m.syncAllDataFiles();
      expect(prefs.getInt('data_file_updated_custom-old'), isNotNull);
      return (m, host, extensions);
    }

    test('one failed getDefinition record vetoes the whole purge pass', () async {
      final (m, host, _) = await seeded();
      // The dangerous shape: the extension is LIVE via a sibling key (so
      // the whole-extension-absent skip does not apply), the old key is
      // missing, and a record FAILED — the missing key could be the failed
      // one (a failed record carries no extensionKey to match it by).
      host.stubs['dataFile:*:getDefinition'] = [
        definitionFor('custom-new'),
        {'key': 'broken', 'ok': false, 'error': 'url() threw'},
      ];
      host.stubs['dataFile:custom-new:mapCsvBatch'] = (args) => [
        for (final r in zipCsvRows(args)) {'key': r['call'], 'name': r['note']},
      ];
      await m.syncAllDataFiles();
      expect(prefs.getInt('data_file_updated_custom-old'), isNotNull, reason: 'a transient hook failure must never cost cached data');
      expect(await lookups.getLookup('custom-old', 'KI2D'), isNotNull);
    });

    test('an activation-incomplete start vetoes the purge; the next clean pass purges', () async {
      final (m, host, extensions) = await seeded();
      // The extension stays live via a sibling key; only custom-old is gone
      // from the snapshot — exactly the shape the purge exists for.
      host.stubs['dataFile:*:getDefinition'] = [definitionFor('custom-new')];
      host.stubs['dataFile:custom-new:mapCsvBatch'] = (args) => [
        for (final r in zipCsvRows(args)) {'key': r['call'], 'name': r['note']},
      ];
      // Boot proceeded past the bounded activation wait: registrations may
      // be missing (call-notes registers custom files only after its own
      // internal await), so a missing key proves nothing...
      extensions.activationIncompleteOverride = true;
      await m.syncAllDataFiles();
      expect(prefs.getInt('data_file_updated_custom-old'), isNotNull, reason: 'a partial registration set must never cost cached data');

      // ...but once activation settles, a clean pass purges normally — the
      // guard defers the cleanup, it does not disable it.
      extensions.activationIncompleteOverride = false;
      await m.syncAllDataFiles();
      expect(prefs.getInt('data_file_updated_custom-old'), isNull, reason: 'the guard must not turn the purge into dead code');
    });
  });

  test('a runtimeGeneration tick syncs data files once; ticks mid-sync queue exactly one follow-up', () async {
    // Every successful runtime start can register dataFile hooks that did
    // not exist before (a just-added custom file, a just-enabled extension,
    // a crash recovery finally coming up) — the generation listener is what
    // downloads them without waiting for the next boot. Serialized: a tick
    // landing mid-sync must queue ONE follow-up pass, not run concurrently
    // (concurrent passes double-download) and not be dropped (its snapshot
    // may carry registrations the running pass predates).
    final host = FakeExtensionHost({'dataFile:*:getDefinition': <Map<String, dynamic>>[]});
    final extensions = MockExtensionService(host);
    final m = _SyncCountingDataFileManager(lookups: lookups, extensions: extensions, prefs: prefs);

    extensions.runtimeGeneration.value++;
    await pumpEventQueue();
    expect(m.syncCalls, 1, reason: 'a successful restart triggers a sync');

    m.blockNextSync = Completer<void>();
    extensions.runtimeGeneration.value++;
    await pumpEventQueue();
    extensions.runtimeGeneration.value++; // lands mid-sync
    extensions.runtimeGeneration.value++; // and another — still one queued pass
    m.blockNextSync!.complete();
    m.blockNextSync = null;
    await pumpEventQueue();
    expect(m.syncCalls, 3, reason: 'the blocked pass plus exactly one queued follow-up');
  });

  group('downloadFile conditional-GET retry (web CORS preflight)', () {
    // The failure mode this guards: `If-None-Match` is not a CORS-safelisted
    // header, so on web a conditional GET forces an OPTIONS preflight that
    // static file hosts commonly reject — the file downloads fine ONCE,
    // caches an ETag, then every later refresh fails with a browser-level
    // ClientException. The retry must strip the conditional header AND drop
    // the stored ETag, or the very next sync re-arms the same failure.
    setUp(() {
      PackageInfo.setMockInitialValues(appName: 'test', packageName: 'test', version: '1.0', buildNumber: '1', buildSignature: '');
    });

    // A fresh client per factory call: the manager closes its client after
    // every fetch, so a factory that hands back the same instance only works
    // while MockClient.close() stays a no-op.
    DataFileManager buildManager({required bool isWeb, required Future<http.Response> Function(http.Request) handler}) =>
        DataFileManager(lookups: lookups, extensions: extensions, prefs: prefs, httpClientFactory: () => http.MockClient(handler), isWeb: isWeb);

    test('on web, a failed conditional GET retries unconditionally, drops the ETag, and stops conditioning', () async {
      await prefs.setString('data_file_etag_hams', '"abc"');
      final requests = <http.Request>[];
      final m = buildManager(
        isWeb: true,
        handler: (request) async {
          requests.add(request);
          if (request.headers.containsKey('If-None-Match')) {
            throw http.ClientException('NetworkError when attempting to fetch resource.', request.url);
          }
          // The etag header is the trap: a preflight-hostile host DOES
          // serve ETags on plain GETs, and re-storing this one would
          // re-arm the identical failure on the next sync.
          return http.Response('CONTENT', 200, headers: {'etag': '"fresh"'});
        },
      );

      final body = await m.downloadFile('hams', 'https://example.com/f.txt');

      expect(body, 'CONTENT', reason: 'the retry must surface the file, not the preflight failure');
      expect(requests, hasLength(2));
      expect(requests.last.headers.containsKey('If-None-Match'), isFalse);
      expect(prefs.getString('data_file_etag_hams'), isNull, reason: 'a kept or re-stored ETag re-arms the identical failure on the next sync');
      expect(
        prefs.getBool('data_file_skip_conditional_hams'),
        isTrue,
        reason:
            'without the skip mark, the next unconditional 200 stores an ETag and the '
            'fail-and-refetch cycle resumes one sync later',
      );

      // The next sync must be unconditional outright — no failed attempt,
      // no retry.
      final again = await m.downloadFile('hams', 'https://example.com/f.txt');
      expect(again, 'CONTENT');
      expect(requests, hasLength(3));
      expect(requests.last.headers.containsKey('If-None-Match'), isFalse);
      expect(prefs.getString('data_file_etag_hams'), isNull, reason: 'a skip-marked key must not accumulate ETags it will never send');
    });

    test('on native, a failed conditional GET rethrows without retrying', () async {
      // Native fetches never preflight, so a ClientException there is a real
      // network failure — a blind retry would just double every outage.
      await prefs.setString('data_file_etag_hams', '"abc"');
      var calls = 0;
      final m = buildManager(
        isWeb: false,
        handler: (request) async {
          calls++;
          throw http.ClientException('Connection failed', request.url);
        },
      );

      await expectLater(m.downloadFile('hams', 'https://example.com/f.txt'), throwsA(isA<http.ClientException>()));
      expect(calls, 1);
      expect(prefs.getString('data_file_etag_hams'), '"abc"', reason: 'a native failure says nothing about the ETag being poisonous');
    });

    test('on web with no cached ETag, a failure rethrows — there is no conditional header to strip', () async {
      var calls = 0;
      final m = buildManager(
        isWeb: true,
        handler: (request) async {
          calls++;
          throw http.ClientException('Failed to fetch', request.url);
        },
      );

      await expectLater(m.downloadFile('hams', 'https://example.com/f.txt'), throwsA(isA<http.ClientException>()));
      expect(calls, 1, reason: 'retrying an unconditional request repeats the identical failure');
    });

    test('a genuine web outage keeps the ETag: the failed retry proves nothing about it', () async {
      // Dropping the ETag before the retry settles converts every outage
      // into a post-recovery full re-download of files that would have
      // 304'd.
      await prefs.setString('data_file_etag_hams', '"abc"');
      final m = buildManager(
        isWeb: true,
        handler: (request) async {
          throw http.ClientException('Failed to fetch', request.url);
        },
      );

      await expectLater(m.downloadFile('hams', 'https://example.com/f.txt'), throwsA(isA<http.ClientException>()));
      expect(prefs.getString('data_file_etag_hams'), '"abc"', reason: 'the ETag must survive to earn a 304 once the network returns');
      expect(
        prefs.getBool('data_file_skip_conditional_hams'),
        isNot(isTrue),
        reason: 'only a SUCCESSFUL unconditional retry proves the host is preflight-hostile',
      );
    });

    test('a processing failure drops the stored ETag so the next sync cannot 304 past it', () async {
      // The download precedes the processing failure, so the ETag points at
      // a body this device never ingested: kept, the next sync's
      // conditional GET answers 304, reads as "unchanged", and the file is
      // stamped fresh for maxAgeDays with the data still missing.
      final m = buildManager(isWeb: false, handler: (request) async => http.Response('not json at all', 200, headers: {'etag': '"e1"'}));

      await expectLater(m.processDataFile('bad', {'url': 'https://example.com/f.json', 'fetchType': 'json'}, notifyOnFailure: false), throwsA(anything));
      expect(prefs.getString('data_file_etag_bad'), isNull);
    });
  });

  test('downloadFile times out instead of hanging on a dead connection', () {
    // Without a ceiling on client.send, one unresponsive host stalls a sync
    // pass forever — nothing downstream (notices, follow-up syncs, RELOAD
    // completion) ever runs.
    PackageInfo.setMockInitialValues(appName: 'test', packageName: 'test', version: '1.0', buildNumber: '1', buildSignature: '');
    fakeAsync((fake) {
      final m = DataFileManager(lookups: lookups, extensions: extensions, prefs: prefs, httpClientFactory: _HangingClient.new);
      Object? caught;
      m
          .downloadFile('hams', 'https://example.com/f.txt')
          .then<void>(
            (_) {},
            onError: (Object e) {
              caught = e;
            },
          );
      fake.elapse(DataFileManager.headersTimeout + const Duration(seconds: 1));
      fake.flushMicrotasks();
      expect(caught, isA<TimeoutException>());
    });
  });

  group('connectivity-driven resync', () {
    test('coming back online runs one unattended sync pass', () async {
      final offline = StreamController<bool>();
      final m = _SyncCountingDataFileManager(
        lookups: lookups,
        extensions: MockExtensionService(FakeExtensionHost({'dataFile:*:getDefinition': <Map<String, dynamic>>[]})),
        prefs: prefs,
        offlineChanges: offline.stream,
      );

      offline.add(true);
      await pumpEventQueue();
      expect(m.syncCalls, 0, reason: 'going offline is not a download opportunity');

      offline.add(false);
      await pumpEventQueue();
      expect(m.syncCalls, 1);
      expect(
        m.notifyFlags.single,
        isFalse,
        reason:
            'a reconnect is unattended, like the boot sync — failure notices on every '
            'flaky-network recovery would be pure noise',
      );
      await offline.close();
    });

    test('unattended passes are skipped outright while offline', () async {
      // The trigger is not lost by being refused: everything that fires this
      // loop — a runtime replacement, a reconnect — fires again on the far
      // side of an outage, and the reconnect edge fires precisely then.
      // Attempting anyway would spend a timeout per data file to write
      // nothing.
      var offline = true;
      final m = _SyncCountingDataFileManager(
        lookups: lookups,
        extensions: MockExtensionService(FakeExtensionHost({'dataFile:*:getDefinition': <Map<String, dynamic>>[]})),
        prefs: prefs,
        isOffline: () => offline,
      );

      m.extensions.runtimeGeneration.value++;
      await pumpEventQueue();
      expect(m.syncCalls, 0);

      offline = false;
      m.extensions.runtimeGeneration.value++;
      await pumpEventQueue();
      expect(m.syncCalls, 1);
    });

    test('a reconnect trigger cannot overlap a direct sync pass', () async {
      // The coalescing loop only covers listener triggers; the lock in
      // syncAllDataFiles is what keeps a direct pass (boot, RELOAD, Update
      // All) and a reconnect pass from double-downloading — and from
      // interleaving the per-pass stale sweeps that delete each other's
      // freshly written rows.
      final offline = StreamController<bool>();
      final host = FakeExtensionHost({
        'dataFile:*:getDefinition': [
          {
            'ok': true,
            'value': {'key': 'f1', 'url': 'https://example.com/f1', 'fetchType': 'json'},
          },
        ],
      });
      final m = _BlockingDownloadManager(lookups: lookups, extensions: MockExtensionService(host), prefs: prefs, offlineChanges: offline.stream);

      m.blockDownload = Completer<void>();
      final direct = m.syncAllDataFiles(notifyOnFailure: false);
      await pumpEventQueue();
      expect(m.downloadCalls, 1, reason: 'the direct pass is mid-download');

      offline.add(false);
      await pumpEventQueue();
      expect(m.downloadCalls, 1, reason: 'the reconnect pass must queue behind the direct pass, not race it');

      m.blockDownload!.complete();
      m.blockDownload = null;
      await direct;
      await pumpEventQueue();
      expect(m.downloadCalls, 1, reason: 'the serialized follow-up pass sees the fresh stamp and age-skips the file');
      await offline.close();
    });

    test('an offline-stream error degrades silently and keeps the subscription alive', () async {
      final offline = StreamController<bool>();
      final m = _SyncCountingDataFileManager(
        lookups: lookups,
        extensions: MockExtensionService(FakeExtensionHost({'dataFile:*:getDefinition': <Map<String, dynamic>>[]})),
        prefs: prefs,
        offlineChanges: offline.stream,
      );

      // Without an onError, this escapes as an unhandled zone error — an
      // ErrorPolicy-default notice and upload for a background blip whose
      // correct degradation is "no reconnect resync".
      offline.addError(StateError('backend gone'));
      await pumpEventQueue();
      expect(m.syncCalls, 0);

      offline.add(false);
      await pumpEventQueue();
      expect(m.syncCalls, 1, reason: 'an error event must not kill the subscription');
      await offline.close();
    });
  });
  group('a replaced runtime re-loads the raw cache (HALO-429)', () {
    test('a generation tick loads the cache BEFORE syncing', () async {
      final manager = _RecordingDataFileManager(lookups: lookups, extensions: MockExtensionService(FakeExtensionHost(const {})), prefs: prefs);

      manager.extensions.runtimeGeneration.value++;
      await pumpEventQueue();

      // Both, and in this order. The raw cache-to-runtime import is
      // per-generation state that nothing else replays, and the sync cannot
      // stand in for it: an unchanged file answers 304 and the 304 path
      // returns before _processRaw, so the fresh runtime would keep running
      // without data the old one had, for the whole session.
      expect(manager.calls, ['load', 'sync']);
    });

    test('rapid replacements still coalesce to one follow-up pass', () async {
      final manager = _RecordingDataFileManager(lookups: lookups, extensions: MockExtensionService(FakeExtensionHost(const {})), prefs: prefs);

      manager.blockNextSync = Completer<void>();
      manager.extensions.runtimeGeneration.value++;
      await pumpEventQueue();
      manager.extensions.runtimeGeneration.value++; // lands mid-pass
      manager.extensions.runtimeGeneration.value++; // and another
      manager.blockNextSync!.complete();
      manager.blockNextSync = null;
      await pumpEventQueue();

      // The reload must be consumed INSIDE the serialized region. Awaiting it
      // before the `_syncRunning` check would let each of these ticks slip
      // past the coalescing and start its own pass — double-downloading every
      // stale file, which is exactly what the coalescing exists to prevent.
      expect(manager.calls, ['load', 'sync', 'load', 'sync']);
    });

    test('a failing re-load still lets the sync run, and does not escape', () async {
      final manager = _RecordingDataFileManager(lookups: lookups, extensions: MockExtensionService(FakeExtensionHost(const {})), prefs: prefs)
        ..loadThrows = true;

      manager.extensions.runtimeGeneration.value++;
      await pumpEventQueue();

      // Nothing awaits this listener, so an escaping throw would become an
      // unhandled zone error — an operator notice and an upload — for a cache
      // re-import whose correct degradation is "the sync still runs".
      expect(manager.calls, ['sync']);
    });
  });

  group('loadRawDataFiles abandons a superseded pass (HALO-429)', () {
    test('a host that died mid-pass stops the loop instead of reporting each file', () async {
      final host = FakeExtensionHost({
        'dataFile:*:getDefinition': [
          {
            'ok': true,
            'value': {'key': 'one', 'fetchType': 'raw'},
          },
          {
            'ok': true,
            'value': {'key': 'two', 'fetchType': 'raw'},
          },
        ],
      })..dead = true;
      final manager = DataFileManager(lookups: lookups, extensions: MockExtensionService(host), prefs: prefs, isWeb: false);

      // Returns without touching the filesystem at all. The guard has to
      // precede `appDataDirectory()`, not just the import loop: a pass whose
      // runtime has gone should cost nothing, and in a test environment that
      // call is the first thing to blow up. Without it, every remaining file
      // is imported into a disposed host and reported once each — noise for
      // work the generation listener is already going to redo.
      await manager.loadRawDataFiles();
    });
  });
}

class _SyncCountingDataFileManager extends DataFileManager {
  int syncCalls = 0;
  final notifyFlags = <bool>[];
  Completer<void>? blockNextSync;

  _SyncCountingDataFileManager({required super.lookups, required super.extensions, required super.prefs, super.offlineChanges, super.isOffline});

  @override
  Future<int> syncAllDataFiles({bool force = false, String? categoryFilter, bool notifyOnFailure = true}) async {
    syncCalls++;
    notifyFlags.add(notifyOnFailure);
    final block = blockNextSync;
    if (block != null) await block.future;
    return 0;
  }
}

/// A client whose requests never complete — the shape of a dead host that
/// accepts the connection and then says nothing.
class _HangingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => Completer<http.StreamedResponse>().future;
}

/// Downloads block on [blockDownload] and resolve as a 304 (null body), so a
/// test can hold one sync pass mid-download while another tries to start.
class _BlockingDownloadManager extends DataFileManager {
  int downloadCalls = 0;
  Completer<void>? blockDownload;

  _BlockingDownloadManager({required super.lookups, required super.extensions, required super.prefs, super.offlineChanges});

  @override
  Future<String?> downloadFile(String key, String url, {bool force = false, String? encoding}) async {
    downloadCalls++;
    final block = blockDownload;
    if (block != null) await block.future;
    return null;
  }
}

/// A service whose runtime is gone — what every caller sees between a
/// dispose and the next generation's start.
class _HostlessExtensionService extends ExtensionServiceWithFakeHost {
  @override
  ExtensionHost? get host => null;
}

class MockExtensionService extends ExtensionServiceWithFakeHost {
  MockExtensionService(super.host);

  bool activationIncompleteOverride = false;

  @override
  bool get activationIncomplete => activationIncompleteOverride;
}

/// Records which halves of the post-restart sequence ran, and in what order.
class _RecordingDataFileManager extends DataFileManager {
  final List<String> calls = [];
  bool loadThrows = false;

  /// Holds a sync open, so a test can land further generation ticks inside a
  /// running pass.
  Completer<void>? blockNextSync;

  _RecordingDataFileManager({required super.lookups, required super.extensions, required super.prefs});

  @override
  Future<void> loadRawDataFiles() async {
    if (loadThrows) throw StateError('no data directory');
    calls.add('load');
  }

  @override
  Future<int> syncAllDataFiles({bool force = false, String? categoryFilter, bool notifyOnFailure = true}) async {
    calls.add('sync');
    final blocker = blockNextSync;
    if (blocker != null) await blocker.future;
    return 0;
  }
}

class TestDataFileManager extends DataFileManager {
  String? mockDownloadBody;

  /// Set to make [downloadFile] throw instead of returning [mockDownloadBody]
  /// — simulates a real network/CORS failure without an actual HTTP call.
  Object? mockDownloadError;

  TestDataFileManager({required super.lookups, required super.extensions, required super.prefs, super.statusBar});

  @override
  Future<String?> downloadFile(String key, String url, {bool force = false, String? encoding}) async {
    final error = mockDownloadError;
    if (error != null) throw error;
    return mockDownloadBody;
  }
}

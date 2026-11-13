// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `data-files sync` on a `sqlite` data file — Super Check Partial's SCP.DB.
// The CLI is the app's pipeline reduced, and a type it lacked would download
// the database and then fail on it: it must read the file with the same
// halo_core rules the app does, and write the same rows.

import 'dart:io';

import 'package:halo_cli/src/bundles.dart';
import 'package:halo_cli/src/config.dart';
import 'package:halo_cli/src/data_files.dart';
import 'package:halo_cli/src/host_calls.dart';
import 'package:halo_cli/src/lookup_store.dart';
import 'package:halo_cli/src/runtime.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Directory cache;
  late LookupStore store;
  late ExtRuntime runtime;
  late HttpServer server;
  late String base;

  setUp(() async {
    cache = Directory.systemTemp.createTempSync('halo-cli-sqlite');
    store = LookupStore.open(cache.path);
    final config = CliConfig();
    final index = BundleIndex.load();
    // No extension is needed: rows read by `fields` never reach the runtime.
    runtime = await ExtRuntime.start(
      index: index,
      config: config,
      onHostCall: CliHostCalls(config: config, index: index, lookups: store).call,
      only: const {},
    );
    final dbPath = '${cache.path}/SCP.DB';
    sqlite3.open(dbPath)
      ..execute('CREATE TABLE callsigns (callsign TEXT PRIMARY KEY, annual_rate INTEGER)')
      ..execute("INSERT INTO callsigns VALUES ('K1AB', 807), ('W1AW', 12)")
      ..dispose();
    final bytes = File(dbPath).readAsBytesSync();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://${server.address.host}:${server.port}';
    server.listen((request) async {
      request.response.add(bytes);
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await runtime.stop();
    await store.close();
    cache.deleteSync(recursive: true);
  });

  test('reads the database with its query and writes the rows its fields key', () async {
    final result = await DataFileSync(runtime: runtime, store: store, userAgent: 'test').import(
      DataFileDef(
        key: 'scp',
        extensionKey: 'test',
        raw: {
          'key': 'scp',
          'fetchType': 'sqlite',
          'category': 'scp',
          'url': '$base/SCP.DB',
          'sqliteQuery': 'SELECT callsign, annual_rate AS rate FROM callsigns',
          'fields': {'key': 'callsign'},
        },
      ),
    );

    expect(result.error, isNull);
    expect(result.rows, 2);
    expect((await store.repository.getLookup('scp', 'K1AB'))?.data, '{"callsign":"K1AB","rate":807}');
  });
}

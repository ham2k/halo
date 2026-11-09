// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `data-files sync` on a `ham2k` data file: the version it brings is kept
// beside the cache, so the next sync asks for the delta, and `--force` takes
// the snapshot. The import itself is halo_core's, tested there.

import 'dart:convert';
import 'dart:io';

import 'package:halo_cli/src/bundles.dart';
import 'package:halo_cli/src/config.dart';
import 'package:halo_cli/src/data_files.dart';
import 'package:halo_cli/src/host_calls.dart';
import 'package:halo_cli/src/lookup_store.dart';
import 'package:halo_cli/src/runtime.dart';
import 'package:test/test.dart';

void main() {
  late Directory cache;
  late LookupStore store;
  late ExtRuntime runtime;
  late HttpServer server;
  late List<String> requested;
  late String base;

  setUp(() async {
    cache = Directory.systemTemp.createTempSync('halo-cli-ham2k');
    store = LookupStore.open(cache.path);
    final config = CliConfig();
    final index = BundleIndex.load();
    // No extension is needed: a ham2k file's rows never reach the runtime.
    runtime = await ExtRuntime.start(
      index: index,
      config: config,
      onHostCall: CliHostCalls(config: config, index: index, lookups: store).call,
      only: const {},
    );
    requested = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://${server.address.host}:${server.port}';
    server.listen((request) async {
      requested.add('${request.uri}');
      final response = request.response;
      if (request.uri.path == '/download') {
        response.headers.set('x-lookups-version', 'v1');
        response.write('${jsonEncode({'call': 'W1AW', 'name': 'ARRL'})}\n');
      } else if (request.uri.path == '/delta' && request.uri.queryParameters['since'] == 'v1') {
        response.headers.set('x-lookups-version', 'v2');
        response.write(
          jsonEncode({
            'added': [
              {'call': 'K2A'},
            ],
            'changed': <Object>[],
            'removed': ['W1AW'],
          }),
        );
      } else {
        response.statusCode = 410;
      }
      await response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await runtime.stop();
    await store.close();
    cache.deleteSync(recursive: true);
  });

  DataFileDef def() => DataFileDef(
    key: 'calls-hf',
    extensionKey: 'test',
    raw: {
      'key': 'calls-hf',
      'fetchType': 'ham2k',
      'category': 'calls-hf',
      'url': '$base/download',
      'deltaUrl': '$base/delta?since={since}',
      'fields': {'key': 'call', 'name': 'name'},
    },
  );

  Future<List<String>> keys() async => [for (final row in await store.repository.queryLookups('calls-hf', '')) row.key];

  test('the next sync asks for the delta from the version the last one brought', () async {
    final first = await DataFileSync(runtime: runtime, store: store, userAgent: 'test').import(def());
    expect(first.error, isNull);
    expect(await keys(), ['W1AW']);

    final second = await DataFileSync(runtime: runtime, store: store, userAgent: 'test').import(def());

    expect(second.error, isNull);
    expect(requested, ['/download', '/delta?since=v1'], reason: 'without the kept version every CLI sync downloads the whole snapshot');
    expect(await keys(), ['K2A']);
  });

  test('--force takes the snapshot even with a version kept', () async {
    await DataFileSync(runtime: runtime, store: store, userAgent: 'test').import(def());

    await DataFileSync(runtime: runtime, store: store, userAgent: 'test', force: true).import(def());

    expect(requested, ['/download', '/download']);
  });
}

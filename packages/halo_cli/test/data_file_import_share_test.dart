// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A body that maps to far fewer rows than the cache holds is refused, not
// swept in: the sweep deletes every row the import did not restamp, so a short
// body — an error page served as a 200, a file caught mid-regeneration —
// would empty the category. Run against POTA's real mapper, so the rows are
// the ones the app would write.

import 'dart:io';

import 'package:halo_cli/src/bundles.dart';
import 'package:halo_cli/src/config.dart';
import 'package:halo_cli/src/data_files.dart';
import 'package:halo_cli/src/host_calls.dart';
import 'package:halo_cli/src/lookup_store.dart';
import 'package:halo_cli/src/runtime.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory cache;
  late BundleIndex index;
  late LookupStore store;
  late ExtRuntime runtime;

  setUpAll(() => index = BundleIndex.load());

  setUp(() async {
    cache = Directory.systemTemp.createTempSync('halo-cli-share');
    store = LookupStore.open(cache.path);
    final config = CliConfig();
    runtime = await ExtRuntime.start(
      index: index,
      config: config,
      onHostCall: CliHostCalls(config: config, index: index, lookups: store).call,
      only: const {'ham2k-pota'},
    );
    await store.repository.insertLookupBatch([for (var i = 1; i <= 10; i++) LookupRow(category: 'pota', key: 'US-000$i', name: 'Stored $i', updated: 1)]);
  });

  tearDown(() async {
    await runtime.stop();
    await store.close();
    cache.deleteSync(recursive: true);
  });

  Future<DataFileDef> potaDef() async =>
      (await DataFileSync(runtime: runtime, store: store, userAgent: 'test').definitions()).singleWhere((d) => d.key == 'ham2k-pota-all-parks');

  const shortBody = 'reference,name,active,entityId\nUS-0001,Fresh,1,291\n';

  test('an unforced sync keeps every cached row and says how to accept it', () async {
    final sync = DataFileSync(runtime: runtime, store: store, userAgent: 'test');

    final result = await sync.importBody(await potaDef(), shortBody);

    expect(await store.repository.countCategory('pota'), 10);
    // A script tells a refusal from a download failure by the field, not by
    // matching the message; `rows` is what the refused import still wrote.
    expect(result.toJson(), containsPair('refused', true));
    expect(result.rows, 1);
    expect(result.error, contains('--force'));
  });

  test('--force accepts it and sweeps what the source dropped', () async {
    final sync = DataFileSync(runtime: runtime, store: store, userAgent: 'test', force: true);

    final result = await sync.importBody(await potaDef(), shortBody);

    expect(result.rows, 1);
    expect(await store.repository.countCategory('pota'), 1);
    expect((await store.repository.getLookup('pota', 'US-0001'))!.name, 'Fresh');
  });
}

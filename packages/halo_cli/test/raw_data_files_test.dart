// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Raw data files survive between invocations.
//
// A raw file never becomes lookup rows: its extension parses it into whatever
// shape it keeps in module state, and that state dies with the process. So
// unlike the parks and summits table — which is just there, in SQLite, for
// whoever opens it next — this needs the host to feed the cached copy back in
// at boot, and nothing else in the suite would notice if it stopped.
//
// The fixture is two entries trimmed out of a real downloaded Hams of Note
// payload, so the shape is the one call-notes' own rawToJSONData produces
// rather than one invented here.

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
  late BundleIndex index;

  setUpAll(() => index = BundleIndex.load());
  setUp(() => cache = Directory.systemTemp.createTempSync('halo-cli-raw'));
  tearDown(() => cache.deleteSync(recursive: true));

  /// Boots call-notes against [cache], replaying whatever it holds, and
  /// answers how many callsigns the extension ended up knowing.
  Future<int> callsKnown({required bool replay}) async {
    final store = LookupStore.open(cache.path);
    final config = CliConfig();
    final runtime = await ExtRuntime.start(
      index: index,
      config: config,
      onHostCall: CliHostCalls(config: config, index: index, lookups: store).call,
      only: const {'call-notes'},
    );
    try {
      if (replay) await DataFileSync.replayRawDataFiles(runtime, store);
      final calls = await runtime.host.invokeHook('callNotes', key: 'call-notes', method: 'allCalls');
      return calls is List ? calls.length : 0;
    } finally {
      await runtime.stop();
      await store.close();
    }
  }

  test('a cached raw file is replayed into a fresh runtime', () async {
    // Without the replay this is the state every invocation after the sync
    // sees: the file on disk, `data-files list` reporting it as present, and
    // the extension knowing nothing.
    expect(await callsKnown(replay: true), 0, reason: 'nothing cached yet');

    Directory(DataFileSync.rawCacheDir(LookupStore.open(cache.path))).createSync(recursive: true);
    File('${DataFileSync.rawCacheDir(LookupStore.open(cache.path))}/hams-of-note.json')
        .writeAsStringSync(File('test/fixtures/hams-of-note.json').readAsStringSync());

    expect(await callsKnown(replay: true), 2);
    // And the proof that it is the replay doing it, not the file's mere
    // presence: the same cache, the same boot, without the replay step.
    expect(await callsKnown(replay: false), 0);
  });

  test('a cached file whose extension is not loaded is reported, not fatal', () async {
    // `--only pota` with call notes in the cache must still run pota.
    Directory('${cache.path}/data-files').createSync(recursive: true);
    File('${cache.path}/data-files/no-such-extension.json').writeAsStringSync('{}');

    final store = LookupStore.open(cache.path);
    final config = CliConfig();
    final runtime = await ExtRuntime.start(
      index: index,
      config: config,
      onHostCall: CliHostCalls(config: config, index: index, lookups: store).call,
      only: const {'call-notes'},
    );
    try {
      expect(await DataFileSync.replayRawDataFiles(runtime, store), isEmpty);
    } finally {
      await runtime.stop();
      await store.close();
    }
  });
}

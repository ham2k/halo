// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Relocating the log database off the operator's Documents folder. This runs
// once, unattended, on an existing install that already holds every QSO the
// operator has ever logged — so the tests here are about the ways it could
// destroy or hide that log, not about the happy path.
//
// The `-wal` sidecar is the sharp edge: it holds committed transactions that
// aren't in the main file yet, so a database that arrives without it is a
// database missing its most recent QSOs.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/app_storage.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late Directory legacy;
  late Directory target;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('halo_app_storage_test');
    legacy = await Directory(p.join(root.path, 'Documents')).create();
    target = await Directory(p.join(root.path, 'AppData')).create();
  });

  tearDown(() async => root.delete(recursive: true));

  File legacyFile(String name) => File(p.join(legacy.path, name));
  File targetFile(String name) => File(p.join(target.path, name));

  Future<void> writeLegacyDatabase({String contents = 'db', bool sidecars = true}) async {
    await legacyFile('$kDatabaseName.sqlite').writeAsString(contents);
    if (sidecars) {
      await legacyFile('$kDatabaseName.sqlite-wal').writeAsString('wal');
      await legacyFile('$kDatabaseName.sqlite-shm').writeAsString('shm');
    }
  }

  test('moves the database with its sidecars and clears the old location', () async {
    await writeLegacyDatabase();

    final resolved = await migrateLegacyAppData(legacy: legacy, target: target);

    expect(resolved.path, target.path);
    expect(await targetFile('$kDatabaseName.sqlite').readAsString(), 'db');
    expect(await targetFile('$kDatabaseName.sqlite-wal').readAsString(), 'wal');
    expect(await targetFile('$kDatabaseName.sqlite-shm').readAsString(), 'shm');
    // The point of the exercise: nothing of ours is left in Documents.
    expect(await legacyFile('$kDatabaseName.sqlite').exists(), isFalse);
    expect(await legacyFile('$kDatabaseName.sqlite-wal').exists(), isFalse);
    expect(await legacyFile('$kDatabaseName.sqlite-shm').exists(), isFalse);
  });

  test('a checkpointed database with no sidecars still moves', () async {
    await writeLegacyDatabase(sidecars: false);

    expect((await migrateLegacyAppData(legacy: legacy, target: target)).path, target.path);
    expect(await targetFile('$kDatabaseName.sqlite').readAsString(), 'db');
  });

  test('never overwrites a database already in the new location', () async {
    await writeLegacyDatabase(contents: 'stale');
    await targetFile('$kDatabaseName.sqlite').writeAsString('live');

    final resolved = await migrateLegacyAppData(legacy: legacy, target: target);

    expect(resolved.path, target.path);
    expect(await targetFile('$kDatabaseName.sqlite').readAsString(), 'live');
    // Left where it is rather than deleted: it is the operator's data, and
    // this branch means we can't tell which of the two they'd want.
    expect(await legacyFile('$kDatabaseName.sqlite').readAsString(), 'stale');
  });

  test('keeps running from the old location when the move fails', () async {
    await writeLegacyDatabase();
    // A directory squatting on the sidecar's destination makes its copy throw
    // mid-migration, standing in for a locked or unwritable target.
    await Directory(p.join(target.path, '$kDatabaseName.sqlite-wal')).create();

    final resolved = await migrateLegacyAppData(legacy: legacy, target: target);

    // Answering `target` here would open an empty database and greet the
    // operator with an empty log while their real one sat in Documents.
    expect(resolved.path, legacy.path);
    expect(await legacyFile('$kDatabaseName.sqlite').readAsString(), 'db');
    expect(await legacyFile('$kDatabaseName.sqlite-wal').readAsString(), 'wal');
    // The half-written copy is rolled back, so the next launch retries
    // instead of finding a lone database file and adopting it as complete —
    // `migrateLegacyAppData` decides purely on the target file's existence
    // and cannot tell a finished migration from an abandoned one.
    expect(await targetFile('$kDatabaseName.sqlite').exists(), isFalse);

    await Directory(p.join(target.path, '$kDatabaseName.sqlite-wal')).delete();
    expect((await migrateLegacyAppData(legacy: legacy, target: target)).path, target.path);
    expect(await targetFile('$kDatabaseName.sqlite').readAsString(), 'db');
    expect(await targetFile('$kDatabaseName.sqlite-wal').readAsString(), 'wal');
  });

  test('moves the data file cache along with the database', () async {
    await writeLegacyDatabase();
    final legacyCache = await Directory(p.join(legacy.path, kDataFilesDirName)).create();
    await File(p.join(legacyCache.path, 'pota.json')).writeAsString('[]');

    await migrateLegacyAppData(legacy: legacy, target: target);

    expect(await File(p.join(target.path, kDataFilesDirName, 'pota.json')).readAsString(), '[]');
    expect(await legacyCache.exists(), isFalse);
  });

  test('picks up a cache left behind after the database has already moved', () async {
    // The database migration returns early on every launch after the first,
    // so a cache move interrupted back then — a locked file, a killed
    // process — only ever gets a second chance if it runs independently.
    await targetFile('$kDatabaseName.sqlite').writeAsString('db');
    final legacyCache = await Directory(p.join(legacy.path, kDataFilesDirName)).create();
    await File(p.join(legacyCache.path, 'sota.json')).writeAsString('[]');

    await migrateLegacyAppData(legacy: legacy, target: target);

    expect(await File(p.join(target.path, kDataFilesDirName, 'sota.json')).readAsString(), '[]');
    expect(await legacyCache.exists(), isFalse);
  });

  test('leaves the cache with the database when the move failed', () async {
    await writeLegacyDatabase();
    await Directory(p.join(target.path, '$kDatabaseName.sqlite-wal')).create();
    final legacyCache = await Directory(p.join(legacy.path, kDataFilesDirName)).create();
    await File(p.join(legacyCache.path, 'sota.json')).writeAsString('[]');

    // Still running from Documents, so the cache belongs there too — the
    // data file manager reads it from whichever directory the app resolved.
    expect((await migrateLegacyAppData(legacy: legacy, target: target)).path, legacy.path);
    expect(await File(p.join(legacyCache.path, 'sota.json')).exists(), isTrue);
  });

  test('does nothing when there is no database to move', () async {
    final resolved = await migrateLegacyAppData(legacy: legacy, target: target);

    expect(resolved.path, target.path);
    expect(await targetFile('$kDatabaseName.sqlite').exists(), isFalse);
  });

  test('is a no-op when both directories are the same', () async {
    await writeLegacyDatabase();

    final resolved = await migrateLegacyAppData(legacy: legacy, target: legacy);

    expect(resolved.path, legacy.path);
    expect(await legacyFile('$kDatabaseName.sqlite').readAsString(), 'db');
  });

  // The preferences file comes from a different old location than the
  // database — wherever the shared_preferences plugin picked for itself — and
  // its move gates whether the plugin gets redirected at all. Answering "yes,
  // moved" when it hasn't points the plugin at a directory with no file in
  // it, which reads as every setting reset to its default.
  group('preferences', () {
    late Directory prefsLegacy;

    setUp(() async => prefsLegacy = await Directory(p.join(root.path, 'AppSupport')).create());

    File prefsIn(Directory dir) => File(p.join(dir.path, kPreferencesFileName));

    test('moves the file and clears the directory it was alone in', () async {
      await prefsIn(prefsLegacy).writeAsString('{"flutter.call":"N0DEV"}');

      expect(await migratePreferencesFile(legacy: prefsLegacy, target: target), isTrue);
      expect(await prefsIn(target).readAsString(), '{"flutter.call":"N0DEV"}');
      expect(await prefsLegacy.exists(), isFalse);
    });

    test('leaves a directory that holds anything else', () async {
      await prefsIn(prefsLegacy).writeAsString('{}');
      await File(p.join(prefsLegacy.path, 'something_else.json')).writeAsString('{}');

      expect(await migratePreferencesFile(legacy: prefsLegacy, target: target), isTrue);
      expect(await prefsLegacy.exists(), isTrue);
    });

    test('reports failure and keeps the file when the move fails', () async {
      await prefsIn(prefsLegacy).writeAsString('{"flutter.call":"N0DEV"}');
      await Directory(p.join(target.path, kPreferencesFileName)).create();

      // False is what stops the caller redirecting the plugin — with the
      // file still in the old directory, redirecting would lose the settings.
      expect(await migratePreferencesFile(legacy: prefsLegacy, target: target), isFalse);
      expect(await prefsIn(prefsLegacy).readAsString(), '{"flutter.call":"N0DEV"}');
    });

    test('a fresh install has nothing to move and is still ready to redirect', () async {
      expect(await migratePreferencesFile(legacy: prefsLegacy, target: target), isTrue);
      // Cleared even though nothing moved: asking path_provider where the
      // plugin's directory is CREATES it, so leaving the empty one means
      // every later launch has to ask again — and re-create it again.
      expect(await prefsLegacy.exists(), isFalse);
    });

    test('never overwrites preferences already in the new location', () async {
      await prefsIn(prefsLegacy).writeAsString('{"stale":true}');
      await prefsIn(target).writeAsString('{"live":true}');

      expect(await migratePreferencesFile(legacy: prefsLegacy, target: target), isTrue);
      expect(await prefsIn(target).readAsString(), '{"live":true}');
    });
  });
}

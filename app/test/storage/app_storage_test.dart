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
import 'package:ham2k_logger/services/app_storage_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:path/path.dart' as p;

import '../support/error_reporting_fakes.dart';

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

  test('never overwrites a database already in the new location, and says so', () async {
    await writeLegacyDatabase(contents: 'stale');
    await targetFile('$kDatabaseName.sqlite').writeAsString('live');

    final backend = FakeErrorReportingBackend();
    await withErrorHooks(backend: backend, () async {
      final resolved = await migrateLegacyAppData(legacy: legacy, target: target);
      expect(resolved.path, target.path);
    });

    expect(await targetFile('$kDatabaseName.sqlite').readAsString(), 'live');
    // Left where it is rather than deleted: it is the operator's data, and
    // this branch means we can't tell which of the two they'd want.
    expect(await legacyFile('$kDatabaseName.sqlite').readAsString(), 'stale');
    // Two databases is how a launch that could not see Documents strands the
    // old log: silently, this state reads as a finished migration, and the
    // QSOs left behind are found only when someone knows to look.
    expect(backend.exceptions.map((e) => e.context), ['app-storage:legacy-database-stranded']);
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

  // The plugin decodes its file with a bare `json.decode` and has no recovery
  // of any kind, so one truncated write ends EVERY later launch at the boot
  // error screen — with deleting the file by hand the only way out, and every
  // setting in it gone with it. These tests are about that: the trap is a
  // guard that "handles" a bad file by deleting it, which trades a launch
  // that never completes for settings that silently never come back.
  group('guardPreferencesFile', () {
    File prefs() => File(p.join(target.path, kPreferencesFileName));
    File backup() => File(p.join(target.path, kPreferencesBackupFileName));

    Future<List<String>> quarantined() async =>
        target.list().map((e) => p.basename(e.path)).where((name) => name.startsWith(kPreferencesQuarantinePrefix)).toList();

    test('takes a backup of a file it can read', () async {
      await prefs().writeAsString('{"flutter.call":"N0DEV"}');

      expect(await guardPreferencesFile(target), PreferencesRecovery.none);
      // Without this the restore below has nothing to restore FROM: the good
      // launches are the only chance to capture a good copy.
      expect(await backup().readAsString(), '{"flutter.call":"N0DEV"}');
    });

    test('restores the backup over a truncated file, and keeps the bad one', () async {
      await backup().writeAsString('{"flutter.call":"N0DEV"}');
      await prefs().writeAsString('{"flutter.call":"N0D');

      expect(await guardPreferencesFile(target), PreferencesRecovery.restoredFromBackup);
      expect(await prefs().readAsString(), '{"flutter.call":"N0DEV"}');
      // Moved aside, never deleted: it is both the evidence of what went
      // wrong and the only remaining copy of whatever the backup predates.
      expect(await quarantined(), hasLength(1));
    });

    test('a zero-byte file is a dead write, not an empty settings file', () async {
      await backup().writeAsString('{"flutter.call":"N0DEV"}');
      await prefs().writeAsString('');

      // The plugin tolerates an empty file and starts from defaults, so
      // treating it as readable here would be the worse of two silent
      // failures: it would copy the emptiness over the backup and destroy
      // the last good settings this launch could have restored.
      expect(await guardPreferencesFile(target), PreferencesRecovery.restoredFromBackup);
      expect(await prefs().readAsString(), '{"flutter.call":"N0DEV"}');
    });

    test('an unusable backup means defaults, not a second bad file', () async {
      await backup().writeAsString('{"flutter.ca');
      await prefs().writeAsString('{"flutter.call":"N0D');

      expect(await guardPreferencesFile(target), PreferencesRecovery.reset);
      // No file at all is what the plugin reads as a fresh install. Putting
      // the corrupt backup back would reproduce the launch failure exactly.
      expect(await prefs().exists(), isFalse);
      expect(await quarantined(), hasLength(1));
    });

    test('a missing file is a first run, and never triggers a restore', () async {
      await backup().writeAsString('{"flutter.call":"N0DEV"}');

      expect(await guardPreferencesFile(target), PreferencesRecovery.none);
      // An operator who deleted the file — following exactly the advice this
      // exists to retire — has to stay deleted, or the workaround stops
      // working before the fix has reached them.
      expect(await prefs().exists(), isFalse);
    });

    test('a restore that cannot be written destroys nothing', () async {
      await backup().writeAsString('{"flutter.call":"N0DEV"}');
      await prefs().writeAsString('{"flutter.call":"N0D');
      // Squats the name the restore stages through, so writing it throws —
      // a full disk or a lock on the temporary, mid-repair.
      await Directory('${prefs().path}.restore.tmp').create();

      await expectLater(guardPreferencesFile(target), throwsA(isA<FileSystemException>()));
      // The bad file is still where it was. Quarantining it first would leave
      // the live file gone with nothing put back — a state no later launch
      // can see, because a missing file reads as a first run and the backup
      // is never consulted again.
      expect(await prefs().readAsString(), '{"flutter.call":"N0D');
      expect(await quarantined(), isEmpty);
    });

    test('a write cut mid-character is corruption, not a file we cannot read', () async {
      await backup().writeAsString('{"flutter.call":"N0DEV"}');
      // '{"flutter.call":"ñ' with the second byte of the ñ missing — the
      // ordinary shape of a torn write, reachable from any accented callsign
      // or note. dart:io reports the failed UTF-8 decode as a
      // FileSystemException, indistinguishable from a permission or a lock,
      // so classifying on `readAsString` sends this file down the
      // leave-it-alone path and the launch stays broken forever.
      await prefs().writeAsBytes([0x7b, 0x22, 0x63, 0x22, 0x3a, 0x22, 0xc3]);

      expect(await guardPreferencesFile(target), PreferencesRecovery.restoredFromBackup);
      expect(await prefs().readAsString(), '{"flutter.call":"N0DEV"}');
      expect(await quarantined(), hasLength(1));
    });

    test('a staging file an earlier write died holding is swept', () async {
      await prefs().writeAsString('{"flutter.call":"N0DEV"}');
      await File('${prefs().path}.tmp').writeAsString('half a write');

      await guardPreferencesFile(target);
      // The atomic write only ever overwrites this name, so nothing else
      // would clear it; it would sit in the operator's data folder looking
      // like a file that means something.
      expect(await File('${prefs().path}.tmp').exists(), isFalse);
    });

    test('a file the OS will not let us read is left alone, not replaced', () async {
      await backup().writeAsString('{"flutter.call":"STALE"}');
      await prefs().writeAsString('{"flutter.call":"N0DEV"}');
      await Process.run('chmod', ['000', prefs().path]);
      addTearDown(() => Process.run('chmod', ['644', prefs().path]));

      // Unreadable is not corrupt. A lock, a permission or an antivirus hook
      // can refuse a perfectly good file, and a rename would often SUCCEED
      // anyway — on POSIX it needs write permission on the DIRECTORY, not on
      // the file — so repairing here would swap live settings for stale ones
      // over a failure that clears by itself.
      await expectLater(guardPreferencesFile(target), throwsA(isA<FileSystemException>()));
      expect(await quarantined(), isEmpty);
      expect(await backup().readAsString(), '{"flutter.call":"STALE"}');
    }, skip: Platform.isWindows ? 'chmod has no effect on Windows ACLs' : false);

    test('a second failure does not erase the first one it quarantined', () async {
      await prefs().writeAsString('{"a');
      await guardPreferencesFile(target);
      await prefs().writeAsString('{"b');
      await guardPreferencesFile(target);

      expect(await quarantined(), hasLength(2));
    });
  });

  group('dev data sandbox preferences', () {
    late SharedPreferencesStorePlatform original;

    setUp(() {
      original = SharedPreferencesStorePlatform.instance;
    });

    tearDown(() {
      SharedPreferencesStorePlatform.instance = original;
      SharedPreferences.resetStatic();
    });

    File sandboxPreferences() => targetFile(kPreferencesFileName);

    test('settings are written into the sandbox, not the platform store', () async {
      // The half a sandboxed DATA directory cannot deliver on its own: macOS,
      // iOS and Android keep preferences in NSUserDefaults keyed by bundle
      // id, with no path anywhere in the API. Without this substitution two
      // sandboxed builds isolate their logs and then quietly overwrite each
      // other's settings — the same entanglement, wearing a disguise.
      await installSandboxPreferencesStore(target.path);
      SharedPreferences.resetStatic();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('operatorCall', 'N0DEV');

      expect(await sandboxPreferences().exists(), isTrue, reason: 'the sandbox owns its settings file, wherever the platform would have put one');
      expect(await sandboxPreferences().readAsString(), contains('N0DEV'));
    });

    test('a second sandbox reads its own settings, not the first one\'s', () async {
      // One sandbox per checkout is the entire point: if the second launch
      // could see the first one's settings, it could see — and migrate — its
      // log too.
      await installSandboxPreferencesStore(target.path);
      SharedPreferences.resetStatic();
      await (await SharedPreferences.getInstance()).setString('operatorCall', 'N0DEV');

      await installSandboxPreferencesStore(legacy.path);
      SharedPreferences.resetStatic();

      expect((await SharedPreferences.getInstance()).getString('operatorCall'), isNull);
    });
  });
}

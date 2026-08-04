// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Where the app's own files live: the log database, the data-file cache and
// the preferences file, in one directory per edition.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:halo_build_tools/halo_build_tools.dart' show Edition, kEdition;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_storage_prefs.dart';
import 'error_reporting_service.dart';

/// The database's base name; drift appends `.sqlite`, and sqlite the
/// `-wal`/`-shm` sidecars.
const kDatabaseName = 'ham2k_logger';

/// Subdirectory holding the processed data-file cache.
const kDataFilesDirName = 'data_files';

/// What the shared_preferences plugin calls its file on desktop.
const kPreferencesFileName = 'shared_preferences.json';

/// The app's directory under `%LOCALAPPDATA%`, per edition so that a Next or
/// Dev build never writes into the log the operator flies with. Spelled the
/// way the app is spoken about rather than after the Windows product name, so
/// an operator finds it by looking for what they installed.
String get windowsDataFolderName => switch (kEdition) {
  Edition.prod => 'Ham2K Logger',
  Edition.next => 'Ham2K Logger Next',
  Edition.dev => 'Ham2K Logger Dev',
};

/// The directory holding the log database, the data-file cache and (on
/// Windows) the preferences file.
///
/// On iOS, macOS and Android "documents" is a private per-app directory inside
/// the sandbox, so that's where the files stay. On Windows and Linux it is the
/// operator's real, visible Documents folder — a file they can delete while
/// tidying up, and (on Windows, where OneDrive's Known Folder Move redirects
/// it by default) a continuously-syncing one, which is no place for a live
/// SQLite database and its sidecars. There we use a private per-user
/// directory instead, migrating anything left behind on the way.
///
/// Memoized, so every caller agrees on one answer even if a migration failed
/// and the answer is "we're still on the old location".
Future<Directory> appDataDirectory() async => (await _storage()).directory;

/// Resolves [appDataDirectory] and moves the preferences file to match, so
/// that everything the app owns sits together.
///
/// Call this before anything awaits `SharedPreferences.getInstance()` —
/// see [redirectPreferencesDirectory].
Future<void> initializeAppStorage() async {
  final storage = await _storage();
  // A failed relocation leaves us running from Documents; dragging the
  // preferences file there too would spread the mess rather than contain it.
  if (!storage.relocated || kIsWeb || !Platform.isWindows) return;

  try {
    // Asking where the preferences file used to live has a side effect on
    // Windows — path_provider CREATES the directory it names — so once ours
    // holds the file there is nothing to ask: doing it anyway would re-make
    // the empty tree the migration removed, on every single launch.
    if (await File(p.join(storage.directory.path, kPreferencesFileName)).exists()) {
      await redirectPreferencesDirectory(storage.directory.path);
      return;
    }
    final legacy = await getApplicationSupportDirectory();
    if (p.equals(legacy.path, storage.directory.path)) return;
    if (await migratePreferencesFile(legacy: legacy, target: storage.directory)) {
      await redirectPreferencesDirectory(storage.directory.path);
    }
  } catch (e, st) {
    // Preferences keep working from wherever the plugin puts them; the app
    // must still boot.
    ErrorReportingService.report(e, st, context: 'app-storage:initialize-preferences');
  }
}

/// [directory] is where the app's files are; [relocated] is false when that's
/// the platform's documents directory — either because the platform's is
/// private already, or because a migration failed and we stayed put.
typedef _Storage = ({Directory directory, bool relocated});

Future<_Storage>? _resolved;

Future<_Storage> _storage() => _resolved ??= _resolveStorage().then((storage) {
  // Logged on every platform, relocated or not: "where are my files?" is a
  // support question, and this is the answer for the build in front of you.
  debugPrint('[storage] app data: ${storage.directory.path}');
  return storage;
});

Future<_Storage> _resolveStorage() async {
  final documents = await getApplicationDocumentsDirectory();
  if (kIsWeb) return (directory: documents, relocated: false);

  try {
    final Directory target;
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData == null || localAppData.isEmpty) {
        // Always set for an interactive session; the support directory is a
        // sane stand-in because it is at least private and out of Documents.
        debugPrint('[storage] %LOCALAPPDATA% is not set — falling back to the support directory');
        target = await getApplicationSupportDirectory();
      } else {
        target = Directory(p.join(localAppData, windowsDataFolderName));
      }
    } else if (Platform.isLinux) {
      // `$XDG_DATA_HOME/<application id>`, which is where the preferences file
      // already sits — so on Linux moving the database there IS the
      // consolidation, with no preferences migration to run.
      target = await getApplicationSupportDirectory();
    } else {
      return (directory: documents, relocated: false);
    }

    await target.create(recursive: true);
    final resolved = await migrateLegacyAppData(legacy: documents, target: target);
    return (directory: resolved, relocated: p.equals(resolved.path, target.path));
  } catch (e, st) {
    // Creating the directory can fail outright — group policy, an antivirus
    // product holding it, an unwritable %LOCALAPPDATA%. Boot must survive
    // that: this whole exercise moves a working install to a tidier place,
    // and failing it must never be worse than not having tried. Everything
    // keeps working from documents, and the next launch retries.
    ErrorReportingService.report(e, st, context: 'app-storage:resolve');
    return (directory: documents, relocated: false);
  }
}

/// Moves a database left behind in [legacy] over to [target], and returns the
/// directory the app should actually use.
///
/// Returns [legacy] — meaning "keep running from the old location" — when the
/// move can't be completed, so a locked or unreadable file can never silently
/// present the operator with an empty log. Copies the whole set first and
/// deletes the originals only once they are all in place: the `-wal` sidecar
/// holds committed transactions that aren't in the main file yet, so a
/// half-moved set is a corrupt one.
@visibleForTesting
Future<Directory> migrateLegacyAppData({required Directory legacy, required Directory target}) async {
  if (p.equals(legacy.path, target.path)) return target;

  final resolved = await _migrateDatabase(legacy: legacy, target: target);
  // Runs whatever the database did on THIS launch, because the database may
  // have moved on an earlier one: an interrupted cache move has to be able to
  // finish later, and by then the database migration returns early. Skipped
  // only while we're still running from `legacy`, where the cache belongs
  // with the database it was fetched for.
  if (p.equals(resolved.path, target.path)) await _migrateDataFilesCache(legacy, target);
  return resolved;
}

Future<Directory> _migrateDatabase({required Directory legacy, required Directory target}) async {
  final legacyDb = File(p.join(legacy.path, '$kDatabaseName.sqlite'));
  final targetDb = File(p.join(target.path, '$kDatabaseName.sqlite'));
  if (!await legacyDb.exists() || await targetDb.exists()) return target;

  const suffixes = ['', '-wal', '-shm'];
  // Destinations are recorded BEFORE their copy, not after: a copy that
  // throws part-way still leaves a partial file behind, and a partial
  // database left in place is one the next launch adopts as complete —
  // `targetDb.exists()` above can't tell the difference.
  final destinations = <File>[];
  try {
    for (final suffix in suffixes) {
      final source = File('${legacyDb.path}$suffix');
      if (!await source.exists()) continue;
      final destination = File('${targetDb.path}$suffix');
      destinations.add(destination);
      await source.copy(destination.path);
    }
  } catch (e, st) {
    await _deleteQuietly(destinations);
    ErrorReportingService.report(e, st, context: 'app-storage:migrate-database');
    return legacy;
  }

  for (final suffix in suffixes) {
    final source = File('${legacyDb.path}$suffix');
    try {
      if (await source.exists()) await source.delete();
    } catch (e) {
      // The copies are good, so the app is fine; the operator just still has
      // the old file sitting in Documents.
      debugPrint('[storage] could not remove legacy ${p.basename(source.path)}: $e');
    }
  }

  return target;
}

/// Moves the preferences file from the directory the shared_preferences
/// plugin picks for itself into [target]. Answers whether preferences now
/// live in [target] — false means the caller must NOT redirect the plugin,
/// because its file is still in [legacy].
@visibleForTesting
Future<bool> migratePreferencesFile({required Directory legacy, required Directory target}) async {
  final legacyFile = File(p.join(legacy.path, kPreferencesFileName));
  final targetFile = File(p.join(target.path, kPreferencesFileName));

  if (!await targetFile.exists() && await legacyFile.exists()) {
    try {
      await legacyFile.copy(targetFile.path);
      await legacyFile.delete();
    } catch (e, st) {
      // Rolled back rather than left half-done: a copy the plugin doesn't
      // know about would go stale behind every settings change, and then
      // surface as a set of reverted settings if a later launch did redirect.
      await _deleteQuietly([targetFile]);
      ErrorReportingService.report(e, st, context: 'app-storage:migrate-preferences');
      return false;
    }
  }

  // Also on the nothing-to-move path: merely ASKING path_provider for this
  // directory creates it, so a fresh install has an empty one to clear away
  // — and clearing it is what keeps later launches from asking again.
  try {
    if (await legacy.list().isEmpty) await legacy.delete();
  } catch (e) {
    debugPrint('[storage] could not remove the old preferences directory: $e');
  }
  return true;
}

/// Moves the processed data-file cache alongside the database. Purely
/// best-effort: every file here is a cache that re-downloads on demand.
Future<void> _migrateDataFilesCache(Directory legacy, Directory target) async {
  final legacyCache = Directory(p.join(legacy.path, kDataFilesDirName));
  if (!await legacyCache.exists()) return;

  try {
    final targetCache = Directory(p.join(target.path, kDataFilesDirName));
    await targetCache.create(recursive: true);
    await for (final entity in legacyCache.list()) {
      if (entity is! File) continue;
      final destination = File(p.join(targetCache.path, p.basename(entity.path)));
      if (!await destination.exists()) await entity.copy(destination.path);
      await entity.delete();
    }
    if (await legacyCache.list().isEmpty) await legacyCache.delete();
  } catch (e) {
    debugPrint('[storage] could not migrate data file cache: $e');
  }
}

/// Undoes a partial copy. Whatever survives here is harmless as long as the
/// caller goes back to the old location, so a failure to clean up is not
/// worth propagating over the failure that caused it.
Future<void> _deleteQuietly(Iterable<File> files) async {
  for (final file in files) {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}

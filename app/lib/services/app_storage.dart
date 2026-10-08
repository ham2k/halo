// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Where the app's own files live: the log database, the data-file cache and
// the preferences file, in one directory per edition.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart' show DriftNativeOptions;
import 'package:flutter/foundation.dart';
import 'package:halo_build_tools/halo_build_tools.dart' show Edition, kEdition;
import 'package:halo_core/halo_core.dart' show realNowUtc;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;

import '../config/dev_flags.dart';
import 'app_storage_prefs.dart';
import 'error_reporting_service.dart';

/// The database's base name; drift appends `.sqlite`, and sqlite the
/// `-wal`/`-shm` sidecars.
const kDatabaseName = 'ham2k_logger';

/// Subdirectory holding the processed data-file cache.
const kDataFilesDirName = 'data_files';

/// What the shared_preferences plugin calls its file on desktop.
const kPreferencesFileName = 'shared_preferences.json';

/// The known-good copy [guardPreferencesFile] takes of a preferences file it
/// found readable, and restores from when it finds an unreadable one.
const kPreferencesBackupFileName = 'shared_preferences.backup.json';

/// Prefix of the name an unreadable preferences file is moved aside under.
/// The rest is a UTC timestamp, so a second failure cannot erase the evidence
/// of the first.
const kPreferencesQuarantinePrefix = 'shared_preferences.corrupt-';

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

/// The log database's full path, or null on web, where it lives in browser
/// storage rather than a file. drift_flutter names the file the same way.
Future<String?> databaseFilePath() async => kIsWeb ? null : p.join((await appDataDirectory()).path, '$kDatabaseName.sqlite');

/// How the log's file is opened on every native platform. One function, so
/// the test that proves the busy timeout opens the file exactly as bootstrap
/// does.
DriftNativeOptions logDatabaseOptions() => const DriftNativeOptions(databaseDirectory: appDataDirectory, setup: _configureLogConnection);

/// How long a statement on the log's connection waits for a lock held by
/// another connection to the file before failing — see
/// [_configureLogConnection]. The quit's drain budget is sized from it.
const logBusyTimeout = Duration(seconds: 5);

/// Lets a statement on the log's connection wait [logBusyTimeout] for a lock
/// held by another connection to the file.
///
/// The app reaches the log through one connection only, so a lock it runs
/// into belongs to something else — another process with the file open.
/// SQLite's default is to give up at once, which fails the statement (a sync
/// round's COMMIT, a saved QSO) with `database is locked` over a lock that
/// would have cleared moments later. SQLite still fails at once where waiting
/// could deadlock: a transaction that has read and now wants to write while
/// the other side already holds the write lock. The bound matters too: the
/// connection is serialized, so every query behind the waiting one waits
/// with it.
///
/// Top-level because drift sends it to the isolate that opens the file.
void _configureLogConnection(CommonDatabase db) => db.execute('PRAGMA busy_timeout = ${logBusyTimeout.inMilliseconds}');

/// What [guardPreferencesFile] had to do to hand the plugin a file it can
/// read. Anything but [none] is worth telling the operator about, because
/// settings they had made are missing.
enum PreferencesRecovery {
  /// The file parsed, or there wasn't one yet.
  none,

  /// The file was unreadable and the backup took its place. The operator
  /// loses whatever changed after the backup was taken — one session at most.
  restoredFromBackup,

  /// The file was unreadable and there was no usable backup, so preferences
  /// start from defaults.
  reset,
}

/// A launch that found an unreadable preferences file and had to repair it.
///
/// Its own type rather than a StateError with a recognizable message, for the
/// reason [UncleanDatabaseQuit] gives: this is the payload of an ErrorPolicy
/// rule, and a rule that matches on message text eventually claims a real
/// error that merely reads the same.
class PreferencesFileUnreadable implements Exception {
  const PreferencesFileUnreadable(this.recovery);

  final PreferencesRecovery recovery;

  @override
  String toString() =>
      'PreferencesFileUnreadable: the preferences file could not be parsed '
      '(${recovery.name})';
}

/// A log database still sitting in the legacy Documents location beside the
/// one the app runs from.
///
/// Its own type so the upload names the state rather than reading as a
/// generic StateError.
class LegacyDatabaseStranded implements Exception {
  const LegacyDatabaseStranded(this.legacyPath, {this.cause});

  /// Where the legacy database is.
  final String legacyPath;

  /// Why a migration that copied it could not delete it, or null when it was
  /// found beside an existing log.
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'LegacyDatabaseStranded: a legacy database at $legacyPath sits beside the live log'
      : 'LegacyDatabaseStranded: the legacy database at $legacyPath was migrated but could not be removed ($cause)';
}

/// Resolves [appDataDirectory], moves the preferences file to match so that
/// everything the app owns sits together, and makes sure the plugin is handed
/// a file it can actually parse.
///
/// Call this before anything awaits `SharedPreferences.getInstance()` — the
/// store caches what it first read, so every repair here has exactly one
/// moment to happen in.
Future<PreferencesRecovery> initializeAppStorage() async {
  final storage = await _storage();
  if (kIsWeb) return PreferencesRecovery.none;

  // Before the atomic-write wrapper below, which wraps whichever store is
  // installed when it runs — installing the sandbox store afterwards would
  // replace the wrapped store with a bare one and reopen the truncation
  // window. Before anything awaits SharedPreferences.getInstance() too, for
  // the reason this whole function is sequenced the way it is.
  if (storage.sandboxed) {
    try {
      await installSandboxPreferencesStore(storage.directory.path);
    } catch (e, st) {
      // Reported, not swallowed into a shared store: preferences that keep
      // going to the platform's own location are preferences two sandboxed
      // builds still fight over, which reads as settings changing by
      // themselves rather than as a failure here.
      ErrorReportingService.report(e, st, context: 'app-storage:sandbox-preferences');
    }
  }

  // FIRST, and on its own: this is the half that stops the file being
  // truncated in the first place, and it depends on nothing below. Sequenced
  // after the repair — or inside its try — a launch that cannot resolve its
  // directory, or cannot write a backup, would spend the whole session
  // writing preferences the old unsafe way. Those are exactly the hostile
  // environments most likely to be force-quit mid-write.
  try {
    await installAtomicPreferenceWrites();
  } catch (e, st) {
    ErrorReportingService.report(e, st, context: 'app-storage:atomic-writes-unavailable');
  }

  try {
    final directory = await _preferencesDirectory(storage);
    if (directory == null) return PreferencesRecovery.none;
    final recovery = await guardPreferencesFile(directory);
    if (recovery != PreferencesRecovery.none) {
      // Uploaded HERE rather than beside the notice, which boot does not
      // reach for another hundred-odd steps: anything that throws in between
      // would lose the only record that an operator's settings were just
      // quarantined. The notice can wait for a screen; the fact cannot.
      ErrorReportingService.report(PreferencesFileUnreadable(recovery), StackTrace.current, context: 'app-storage:preferences-recovered');
    }
    return recovery;
  } catch (e, st) {
    // Boot outranks every repair here: a guard that throws must not become
    // the very failure it exists to prevent. Note this covers resolving the
    // directory too — `getApplicationSupportDirectory` creates the directory
    // it names and throws when it cannot, and the branch that calls it is
    // reached precisely because that family of calls has ALREADY failed once.
    ErrorReportingService.report(e, st, context: 'app-storage:guard-preferences');
    return PreferencesRecovery.none;
  }
}

/// The directory the shared_preferences plugin will read its file from, after
/// any relocation this launch performs — or null on the platforms that keep
/// preferences in a store of the system's own.
Future<Directory?> _preferencesDirectory(_Storage storage) async {
  // A sandbox has just been given a file-backed store pointed at its own
  // directory, on every platform — so the file is ours to guard there even on
  // the ones whose preferences normally belong to the system.
  if (storage.sandboxed) return storage.directory;

  // macOS, iOS and Android hand preferences to NSUserDefaults or Android's
  // SharedPreferences, which write atomically and own their own storage.
  // Only the two Dart, file-backed stores are ours to guard.
  if (!Platform.isWindows && !Platform.isLinux) return null;

  // A failed relocation leaves us running from Documents; dragging the
  // preferences file there too would spread the mess rather than contain it.
  // The file is still wherever the plugin has always put it, which is where
  // the guard has to look.
  if (!storage.relocated) return getApplicationSupportDirectory();

  // On Linux the target IS the plugin's own directory, so the relocation is
  // the database moving to join the preferences file rather than the reverse:
  // nothing to migrate, and nothing to redirect.
  if (Platform.isLinux) return storage.directory;

  try {
    // Asking where the preferences file used to live has a side effect on
    // Windows — path_provider CREATES the directory it names — so once ours
    // holds the file there is nothing to ask: doing it anyway would re-make
    // the empty tree the migration removed, on every single launch.
    if (await File(p.join(storage.directory.path, kPreferencesFileName)).exists()) {
      await redirectPreferencesDirectory(storage.directory.path);
      return storage.directory;
    }
    final legacy = await getApplicationSupportDirectory();
    if (p.equals(legacy.path, storage.directory.path)) return storage.directory;
    if (await migratePreferencesFile(legacy: legacy, target: storage.directory)) {
      await redirectPreferencesDirectory(storage.directory.path);
      return storage.directory;
    }
    return legacy;
  } catch (e, st) {
    // Preferences keep working from wherever the plugin puts them; the app
    // must still boot.
    ErrorReportingService.report(e, st, context: 'app-storage:initialize-preferences');
    return null;
  }
}

/// Makes sure the preferences file in [directory] is one the plugin can parse,
/// and keeps a spare of the last one that was.
///
/// The plugin decodes its file with a bare `json.decode` and no recovery of
/// any kind, so a single truncated write ends every launch from then on at the
/// boot error screen — with deleting the file by hand the only way back, and
/// every setting in it gone. Both halves of that are unacceptable, so an
/// unreadable file is moved aside (never deleted: it is the evidence, and the
/// only remaining copy of those settings) and the backup takes its place.
///
/// A MISSING file is a first run — or an operator who deleted it deliberately,
/// following exactly the advice this exists to retire — so it never triggers a
/// restore.
@visibleForTesting
Future<PreferencesRecovery> guardPreferencesFile(Directory directory) async {
  final file = File(p.join(directory.path, kPreferencesFileName));
  final backup = File(p.join(directory.path, kPreferencesBackupFileName));

  // Nothing is mid-write at boot, so any staging file here is one an earlier
  // write or repair died holding. Left alone it stays in the operator's data
  // folder forever — the atomic write only ever overwrites it, never clears
  // it — looking exactly like a file that means something.
  await _deleteQuietly([File('${file.path}.tmp'), File('${file.path}.restore.tmp'), File('${backup.path}.tmp')]);

  if (!await file.exists()) return PreferencesRecovery.none;

  switch (await _readPreferences(file)) {
    case _PreferencesRead(:final text?):
      // Through a temporary, so that a kill during the copy cannot leave the
      // backup itself truncated — the failure this whole function is about.
      await _writeAtomically(backup, text);
      return PreferencesRecovery.none;
    case _PreferencesRead(unreadable: true):
      // Read as text but not parseable is corruption; refused by the OS is
      // not. A lock, a permission, an antivirus hook — the file may be
      // perfectly good, and quarantining it would replace it with a stale
      // backup and destroy settings over a failure that clears by itself.
      // (Renaming would often SUCCEED here: on POSIX a rename needs write
      // permission on the directory, not readability of the file.)
      throw FileSystemException('preferences unreadable', file.path);
    case _:
      break;
  }

  // Staged BEFORE the bad file is moved aside, and renamed into place after:
  // a restore that throws — a full disk, a lock on the temporary — must not
  // leave the live file gone with nothing put back. That state is invisible
  // and permanent, because the next launch reads a missing file as a first
  // run and never looks at the backup again.
  final replacement = await _readPreferences(backup);
  final restore = File('${file.path}.restore.tmp');
  if (replacement.text != null) await restore.writeAsString(replacement.text!, flush: true);

  await file.rename((await _quarantineName(directory)).path);

  // Past the rename the live file is GONE, so every later failure still has
  // to answer `reset`. Letting one propagate would have the caller swallow it
  // into `none`: the session starts on defaults, the operator is told
  // nothing, and no later launch can tell either — a missing file reads as a
  // first run. That silence is the whole failure the notice exists to end.
  try {
    if (replacement.text != null) {
      await restore.rename(file.path);
      return PreferencesRecovery.restoredFromBackup;
    }
  } catch (e, st) {
    ErrorReportingService.report(e, st, context: 'app-storage:preferences-restore');
  }
  // No file at all, which is what the plugin treats as a fresh install.
  return PreferencesRecovery.reset;
}

/// The outcome of reading a preferences file: its [text] when it holds a JSON
/// object, and otherwise whether the file could be read at all — the one
/// distinction that decides between repairing it and leaving it alone.
typedef _PreferencesRead = ({String? text, bool unreadable});

/// A name no quarantined file already has.
///
/// The timestamp alone is not enough: two failures inside the same
/// millisecond — which a test, or a boot loop, reaches easily — would rename
/// onto each other, and a rename that lands on an existing file DELETES it.
/// Losing the first bad file loses the settings only it still holds.
Future<File> _quarantineName(Directory directory) async {
  final stamp = realNowUtc().toIso8601String().replaceAll(RegExp('[:-]'), '').replaceFirst('.', '');
  File named(String suffix) => File(p.join(directory.path, '$kPreferencesQuarantinePrefix$stamp$suffix.json'));
  var candidate = named('');
  for (var n = 2; await candidate.exists(); n++) {
    candidate = named('-$n');
  }
  return candidate;
}

/// Reads [file] if it holds what the plugin expects: a JSON object.
///
/// An EMPTY file counts as corrupt even though the plugin tolerates one. The
/// plugin writes `{}` for empty preferences and never a zero-byte file, so
/// zero bytes means a write that died between `createSync` and the write
/// itself — the same interrupted write as a truncation, and the same answer.
/// Letting it pass would instead copy nothing over a good backup and lose the
/// only surviving settings.
Future<_PreferencesRead> _readPreferences(File file) async {
  final List<int> bytes;
  try {
    // BYTES, not `readAsString`: dart:io reports a UTF-8 decode failure as a
    // FileSystemException, exactly like a permission or a lock. Deciding
    // "the OS refused us" from that call would classify the most ordinary
    // torn write there is — one cut mid-multi-byte sequence, which any
    // accented callsign or note in the file makes reachable — as a file to
    // leave alone, and leaving it alone is the permanent boot failure this
    // whole guard exists to end. Reading bytes cannot fail on content.
    bytes = await file.readAsBytes();
  } catch (_) {
    // Includes the file simply not being there, which is not a failure —
    // callers distinguish by whether they expected one.
    return (text: null, unreadable: await file.exists());
  }
  try {
    final text = utf8.decode(bytes);
    if (text.isNotEmpty && jsonDecode(text) is Map) return (text: text, unreadable: false);
  } catch (_) {
    // Malformed UTF-8 or malformed JSON, which is what a truncated or
    // half-written file gives: corrupt rather than unreadable, and the case
    // worth repairing.
  }
  return (text: null, unreadable: false);
}

/// Writes [contents] to [file] via a temporary and a rename, which is the
/// atomic replace this file's whole problem is the absence of.
Future<void> _writeAtomically(File file, String contents) async {
  final temp = File('${file.path}.tmp');
  await temp.writeAsString(contents, flush: true);
  await temp.rename(file.path);
}

/// [directory] is where the app's files are; [relocated] is false when that's
/// the platform's documents directory — either because the platform's is
/// private already, or because a migration failed and we stayed put.
/// [sandboxed] is a dev data sandbox ([devDataDirectory]), which every
/// platform treats the same way and which owns its preferences too.
typedef _Storage = ({Directory directory, bool relocated, bool sandboxed});

Future<_Storage>? _resolved;

Future<_Storage> _storage() => _resolved ??= _resolveStorage().then((storage) {
  // Logged on every platform, relocated or not: "where are my files?" is a
  // support question, and this is the answer for the build in front of you.
  debugPrint('[storage] app data: ${storage.directory.path}');
  return storage;
});

Future<_Storage> _resolveStorage() async {
  // Web resolves before the first path_provider call — the plugin has no web
  // implementation, so asking it anything throws. The placeholder is never
  // consumed there: drift opens IndexedDB, and every other user of this path
  // (data-file cache, the Developer panel's data-folder row) is
  // !kIsWeb-guarded.
  if (kIsWeb) return (directory: Directory('.'), relocated: false, sandboxed: false);

  // A dev data sandbox owns EVERYTHING under this directory — the database,
  // the data-file cache and (below) the preferences — so that two builds from
  // two checkouts never share a log. Nothing is migrated into it and nothing
  // out: it is a scratch environment, and a half-adopted one would be exactly
  // the entanglement it exists to end.
  //
  // Deliberately ahead of every platform branch and outside the try: a
  // sandbox that cannot be created must FAIL, not quietly fall back to the
  // shared directory — falling back is how one build migrates another
  // worktree's log, which is the whole failure this prevents. Debug builds
  // only, by construction ([debugEnvFlag] answers '' in release).
  final sandbox = devDataDirectory;
  if (sandbox.isNotEmpty) {
    // A RELATIVE path would resolve against the process working directory,
    // which for a bundled desktop app is nothing the developer typed — so it
    // would quietly succeed and put the log somewhere they cannot find,
    // which is the one outcome this branch promises never to produce.
    if (!p.isAbsolute(sandbox)) {
      throw ArgumentError.value(sandbox, 'HALO_DEV_DATA', 'must be an absolute path');
    }
    final directory = Directory(sandbox);
    await directory.create(recursive: true);
    return (directory: directory, relocated: true, sandboxed: true);
  }

  // On the platforms that stay put, Documents IS the app's home and a failure
  // to resolve it is fatal. On the two that relocate it is only where an OLD
  // install left its files, and Windows in particular can fail to answer —
  // Documents redirected by OneDrive's Known Folder Move or by group policy
  // to a location that is not there — for an operator who never had a file
  // in it. That must not stop the app from booting into %LOCALAPPDATA%.
  if (!Platform.isWindows && !Platform.isLinux) {
    return (directory: await getApplicationDocumentsDirectory(), relocated: false, sandboxed: false);
  }

  Directory? documents;
  try {
    documents = await getApplicationDocumentsDirectory();
  } catch (e, st) {
    ErrorReportingService.report(e, st, context: 'app-storage:resolve-documents');
  }

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
    } else {
      // `$XDG_DATA_HOME/<application id>`, which is where the preferences file
      // already sits — so on Linux moving the database there IS the
      // consolidation, with no preferences migration to run.
      target = await getApplicationSupportDirectory();
    }

    await target.create(recursive: true);
    final resolved = documents == null ? target : await migrateLegacyAppData(legacy: documents, target: target);
    return (directory: resolved, relocated: p.equals(resolved.path, target.path), sandboxed: false);
  } catch (e, st) {
    // Creating the directory can fail outright — group policy, an antivirus
    // product holding it, an unwritable %LOCALAPPDATA%. Boot must survive
    // that: this whole exercise moves a working install to a tidier place,
    // and failing it must never be worse than not having tried. Everything
    // keeps working from documents, and the next launch retries — unless
    // Documents itself was the directory we could not get, in which case
    // there is nowhere left to run from and boot fails on THIS error, the
    // one that actually stopped it. Note the retry only covers THIS branch:
    // a launch that booted without Documents has started a log in the
    // target, and a later one that can see Documents again will not move an
    // old log over it (see `_migrateDatabase`).
    if (documents == null) rethrow;
    ErrorReportingService.report(e, st, context: 'app-storage:resolve');
    return (directory: documents, relocated: false, sandboxed: false);
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
/// half-moved set is a corrupt one. An original that will not delete leaves
/// the app on [target], which holds the complete copies, and keeps its
/// sidecars beside it.
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

/// Holds the fingerprint of the legacy database last reported as stranded,
/// so each one is reported once rather than on every launch.
const _kLegacyReportedFileName = '$kDatabaseName.legacy-reported';

Future<Directory> _migrateDatabase({required Directory legacy, required Directory target}) async {
  final legacyDb = File(p.join(legacy.path, '$kDatabaseName.sqlite'));
  final targetDb = File(p.join(target.path, '$kDatabaseName.sqlite'));
  if (!await legacyDb.exists()) return target;
  if (await targetDb.exists()) {
    // Both exist: a migration copied the log but could not delete the
    // original (OneDrive holding it), a sync client restored it, or a launch
    // that could not see Documents started a fresh log in the target. The
    // target is the log the operator has been writing to since, so it stays.
    // The legacy file is never touched: every edition shares that one path,
    // so it may be another edition's live log — or another PC's, through the
    // same OneDrive.
    await _reportStrandedOnce(legacyDb, target);
    return target;
  }

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
      if (suffix.isEmpty) {
        // The copies are good, so the app runs from them — but the original
        // is now a second log beside this one. Its sidecars stay with it: a
        // main file whose -wal was deleted is missing committed QSOs.
        await _reportStrandedOnce(legacyDb, target, cause: e, context: 'app-storage:migrate-database-cleanup');
        break;
      }
      debugPrint('[storage] could not remove legacy ${p.basename(source.path)}: $e');
    }
  }

  return target;
}

/// Reports [legacyDb] as stranded unless this exact file — same path, size
/// and modification time — was already reported. A file that changes is
/// reported again: something is still writing to it.
///
/// A fingerprint that cannot be read or recorded is reported too, because
/// without it the stranded report repeats on every launch.
Future<void> _reportStrandedOnce(File legacyDb, Directory target, {Object? cause, String context = 'app-storage:legacy-database-stranded'}) async {
  final marker = File(p.join(target.path, _kLegacyReportedFileName));
  try {
    final stat = await legacyDb.stat();
    final fingerprint = '${legacyDb.path}|${stat.size}|${stat.modified.millisecondsSinceEpoch}';
    if (await marker.exists() && await marker.readAsString() == fingerprint) return;
    await marker.writeAsString(fingerprint);
  } catch (e, st) {
    ErrorReportingService.report(e, st, context: 'app-storage:legacy-database-fingerprint');
  }
  ErrorReportingService.report(LegacyDatabaseStranded(legacyDb.path, cause: cause), StackTrace.current, context: context);
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

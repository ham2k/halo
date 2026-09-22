// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Periodic file-level backups of the database, via SQLite's `VACUUM INTO`.
//
// The in-file backup tables (`OperationsBackup`/`QsosBackup`) live inside
// the same database file, so real corruption takes them with it — and
// nothing else ever copies the file. Cloud sync is the primary net, but it
// can only hold what was pushed: a silently-unsynced batch, or a log on a
// device that was offline for a while, has no second copy anywhere. A
// rotating snapshot next to the database is cheap insurance against both
// corruption and the wipe-flows' worst cases; recovery is opening the
// snapshot with sqlite3 (or swapping the file in), a developer-assisted
// path by design.
//
// Native only: on web the database lives inside OPFS/IndexedDB where there
// is no file to vacuum into, and web durability is handled by
// `reportWebStorageHealth` instead.

import 'dart:async';
import 'dart:io';

import 'package:halo_core/halo_core.dart';
import 'package:path/path.dart' as p;

import 'app_storage.dart' show kDatabaseName;
import 'error_reporting_service.dart';

class DatabaseSnapshotService {
  final HaLoDatabase db;

  /// Resolves the directory the database lives in; snapshots go into a
  /// `snapshots/` folder beside it.
  final Future<Directory> Function() dataDirectory;

  /// How many snapshots to keep. Three dailies cover "the corruption
  /// happened sometime this week" without ever holding more than a few
  /// copies of the log on disk.
  static const keepCount = 3;

  /// A fresh snapshot is taken only once the newest one is at least this
  /// old (by file modification time — deliberately not the app clock, so
  /// developer time travel neither floods nor starves the rotation).
  static const minInterval = Duration(hours: 24);

  /// How often the staleness check runs while the app stays open.
  static const checkInterval = Duration(hours: 6);

  Timer? _timer;

  DatabaseSnapshotService(this.db, {required this.dataDirectory});

  /// Arms the periodic check and runs the first one now. The caller delays
  /// this past boot — a vacuum on the statement queue during first paint
  /// would be paid by the first screen's queries.
  void start() {
    _timer ??= Timer.periodic(checkInterval, (_) => unawaited(maybeSnapshot()));
    unawaited(maybeSnapshot());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  /// Takes a snapshot if the newest one is older than [minInterval] (or
  /// none exists), then prunes to [keepCount]. Failures are reported, never
  /// surfaced: this is background insurance, and the operator can do
  /// nothing with a transient vacuum error — a persistent one shows up in
  /// crash reporting instead.
  Future<void> maybeSnapshot() async {
    try {
      final dir = Directory(p.join((await dataDirectory()).path, 'snapshots'));
      await dir.create(recursive: true);

      final existing = await _snapshots(dir);
      // A `.tmp` left behind is a snapshot whose vacuum crashed mid-write —
      // a torn page image that must never be mistaken for a usable backup.
      for (final stray in await _strayTemps(dir)) {
        await stray.delete();
      }
      if (existing.isNotEmpty) {
        final newest = existing.last;
        // Real clock against a real file mtime: a travelled app clock must
        // neither flood the rotation nor starve it (docs/design/time.md).
        // A NEGATIVE age (a snapshot stamped before a backward wall-clock
        // correction) must read as stale, not fresh — treating it as fresh
        // would stall the rotation for the whole clock error on top of the
        // interval.
        final age = realNowUtc().difference((await newest.stat()).modified.toUtc());
        if (age >= Duration.zero && age < minInterval) return;
      }

      // Vacuum into a temp name and rename only once SQLite has finished:
      // `VACUUM INTO` writes a complete, compacted copy in one pass, but a
      // crash mid-vacuum leaves a partial file, and the rename is what
      // keeps such a file out of the rotation. The stamp is the REAL clock
      // (a snapshot name persists past the session, so it must not travel
      // — docs/design/time.md).
      final stamp = realNowUtc().millisecondsSinceEpoch;
      final tempPath = p.join(dir.path, '$kSnapshotPrefix$stamp$kSnapshotTempSuffix');
      await db.customStatement('VACUUM INTO ?', [tempPath]);
      await File(tempPath).rename(p.join(dir.path, '$kSnapshotPrefix$stamp$kSnapshotSuffix'));

      final all = await _snapshots(dir);
      for (final old in all.take(all.length > keepCount ? all.length - keepCount : 0)) {
        await old.delete();
      }
    } catch (e, stack) {
      ErrorReportingService.report(e, stack, context: 'DatabaseSnapshotService:maybeSnapshot');
    }
  }

  /// Snapshot files, oldest first, ordered by the epoch stamp in the name.
  Future<List<File>> _snapshots(Directory dir) async {
    final files = <(int, File)>[];
    await for (final entry in dir.list()) {
      if (entry is! File) continue;
      final name = p.basename(entry.path);
      if (!name.startsWith(kSnapshotPrefix) || !name.endsWith(kSnapshotSuffix)) continue;
      final stamp = int.tryParse(name.substring(kSnapshotPrefix.length, name.length - kSnapshotSuffix.length));
      if (stamp == null) continue;
      files.add((stamp, entry));
    }
    files.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final f in files) f.$2];
  }

  Future<List<File>> _strayTemps(Directory dir) async => [
    await for (final entry in dir.list())
      if (entry is File && p.basename(entry.path).endsWith(kSnapshotTempSuffix)) entry,
  ];
}

const kSnapshotPrefix = '$kDatabaseName-';
const kSnapshotSuffix = '.snapshot.sqlite';
const kSnapshotTempSuffix = '.snapshot.tmp';

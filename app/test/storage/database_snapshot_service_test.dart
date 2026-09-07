// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The snapshots are the only copy of the log outside the live database
// file. The traps these tests exist to catch: a snapshot that isn't a
// usable database (torn temp adopted into the rotation), the rotation
// deleting the wrong copies, and the interval check re-vacuuming on every
// tick.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:ham2k_logger/services/database_snapshot_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late Directory dir;

  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('halo-snapshot-test');
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  DatabaseSnapshotService service() => DatabaseSnapshotService(db, dataDirectory: () async => dir);

  Future<List<File>> snapshotFiles() async {
    final snapshots = Directory(p.join(dir.path, 'snapshots'));
    if (!await snapshots.exists()) return const [];
    return [
      await for (final f in snapshots.list())
        if (f is File) f,
    ]..sort((a, b) => a.path.compareTo(b.path));
  }

  test('a snapshot is a complete, openable copy of the log', () async {
    final operations = OperationsRepository(db);
    final qsos = QsosRepository(db);
    final op = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, {
      'their': {'call': 'W1AW'},
      'band': '20m',
    });

    await service().maybeSnapshot();

    final files = await snapshotFiles();
    expect(files, hasLength(1));
    expect(files.single.path, endsWith('.snapshot.sqlite'));
    // Openable by plain sqlite3 with the row present — the whole point of a
    // file-level backup is recovery without the app.
    final copy = sqlite3.sqlite3.open(files.single.path);
    try {
      final rows = copy.select('SELECT COUNT(*) AS n FROM qsos');
      expect(rows.first['n'], 1);
    } finally {
      copy.dispose();
    }
  });

  test('a fresh snapshot is not retaken before the interval, and stray temps are removed', () async {
    final svc = service();
    await svc.maybeSnapshot();
    final first = await snapshotFiles();
    expect(first, hasLength(1));

    // A crash mid-vacuum leaves a temp — it must never join the rotation.
    final stray = File(p.join(dir.path, 'snapshots', 'ham2k_logger-999.snapshot.tmp'));
    await stray.writeAsString('torn');

    await svc.maybeSnapshot();
    final after = await snapshotFiles();
    expect(after.map((f) => f.path), first.map((f) => f.path), reason: 'newest snapshot is fresh — no re-vacuum');
    expect(await stray.exists(), isFalse);
  });

  test('the rotation keeps only the newest snapshots', () async {
    final snapshots = Directory(p.join(dir.path, 'snapshots'));
    await snapshots.create(recursive: true);
    // Old snapshots planted directly, stamps oldest-first; the aged mtime on
    // the newest lets maybeSnapshot take a real one on top.
    for (final stamp in [1000, 2000, 3000]) {
      final f = File(p.join(snapshots.path, 'ham2k_logger-$stamp.snapshot.sqlite'));
      await f.writeAsString('old $stamp');
      await f.setLastModified(DateTime(2020));
    }

    await service().maybeSnapshot();

    final files = await snapshotFiles();
    expect(files, hasLength(DatabaseSnapshotService.keepCount));
    expect(files.map((f) => p.basename(f.path)), isNot(contains('ham2k_logger-1000.snapshot.sqlite')));
  });
}

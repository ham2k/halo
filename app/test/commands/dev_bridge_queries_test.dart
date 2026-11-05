// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/dev_bridge_queries.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('devSql', () {
    late HaLoDatabase db;

    setUp(() async {
      db = HaLoDatabase(NativeDatabase.memory());
      await db.customStatement("INSERT INTO lookups (category, \"key\", data) VALUES ('call', 'W1AW', '{}')");
    });
    tearDown(() => db.close());

    Future<int> lookupCount() async => (await db.customSelect('SELECT count(*) AS n FROM lookups').getSingle()).read<int>('n');

    test('answers a SELECT as columns and rows', () async {
      final answer = await devSql(db, "SELECT \"key\", data, NULL AS missing, x'0102' AS bytes FROM lookups");
      expect(answer, {
        'columns': ['key', 'data', 'missing', 'bytes'],
        'rows': [
          ['W1AW', '{}', null, '<blob, 2 bytes>'],
        ],
        'rowCount': 1,
        'truncated': false,
      });
    });

    test('keeps both of two columns that share a name, in order', () async {
      // Drift answers rows as maps by column name: unwrapped, the first `a`
      // vanishes and the answer looks complete.
      final answer = await devSql(db, 'SELECT 1 AS a, 2 AS a UNION ALL SELECT 3, 4 ORDER BY 1 DESC;\n-- newest first');
      expect(answer['columns'], ['a', 'a:1']);
      expect(answer['rows'], [
        [3, 4],
        [1, 2],
      ]);
    });

    test('refuses a PRAGMA that sets something, and reads one that does not', () async {
      // The setting would outlive the rollback and stay on the app's
      // connection until it restarts.
      Future<Object?> busyTimeout() async => ((await devSql(db, 'PRAGMA busy_timeout'))['rows']! as List).single;
      final before = await busyTimeout();
      for (final setting in ['PRAGMA busy_timeout = 1', 'pragma busy_timeout(1)']) {
        expect((await devSql(db, setting))['error'], contains('stays set'), reason: setting);
      }
      expect(await busyTimeout(), before);
    });

    test('throws what is not SQLite refusing the statement', () async {
      // Answered as `{error}`, a closed database would read as a typo in
      // the query, and never reach the run's log.
      await db.close();
      await expectLater(devSql(db, 'SELECT 1'), throwsA(isNot(isA<Map<String, Object?>>())));
      db = HaLoDatabase(NativeDatabase.memory());
    });

    test('refuses a write out loud and leaves the data as it was', () async {
      // Without query_only the DELETE would run and be rolled back, answering
      // an empty table as if it had worked.
      final answer = await devSql(db, 'DELETE FROM lookups');
      expect(answer['error'], contains('readonly'));
      expect(await lookupCount(), 1);
    });

    test("the app's own writes work again once a query is done", () async {
      // A query_only left on would fail every save the app makes after the
      // first dev query, and only on the developer's build.
      await devSql(db, 'SELECT 1');
      await devSql(db, 'DELETE FROM lookups');
      await db.customStatement("INSERT INTO lookups (category, \"key\", data) VALUES ('call', 'K1ABC', '{}')");
      expect(await lookupCount(), 2);
    });

    test('a broken statement answers the SQLite error', () async {
      expect((await devSql(db, 'SELECT * FROM nowhere'))['error'], contains('no such table'));
    });

    test('caps what it sends and says it did', () async {
      final answer = await devSql(db, 'WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n LIMIT ${devSqlRowLimit + 5}) SELECT i FROM n');
      expect((answer['rows']! as List).length, devSqlRowLimit);
      expect(answer['rowCount'], devSqlRowLimit + 5);
      expect(answer['truncated'], isTrue);
    });
  });

  test('devSettings answers the matching keys, with JSON text decoded', () async {
    SharedPreferences.setMockInitialValues({'syncEnabled': false, 'peerSyncEnabled': true, 'profiles': '[{"operatorCall":"N0DEV"}]', 'fontScale': 'normal'});
    expect(await devSettings('SYNC'), {
      'settings': {'peerSyncEnabled': true, 'syncEnabled': false},
    });
    expect((await devSettings('profiles'))['settings'], {
      'profiles': [
        {'operatorCall': 'N0DEV'},
      ],
    });
    expect(((await devSettings(''))['settings']! as Map).keys, ['fontScale', 'peerSyncEnabled', 'profiles', 'syncEnabled']);
  });
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

const _url = 'https://example.test/download?set=hf';
const _deltaUrl = 'https://example.test/delta?set=hf&since={since}';
const _fields = Ham2kFields(key: 'call', name: 'name', subCategory: 'country');

/// A server answering each URL from [answers]: a status, a version, a body.
class _Server {
  final Map<String, (int, String?, String)> answers;
  final requested = <String>[];
  _Server(this.answers);

  Future<Ham2kResponse> fetch(Uri url, {required bool goneIsAnswer}) async {
    requested.add('$url');
    final (status, version, body) = answers['$url'] ?? (404, null, '');
    if (status != 200 && !(goneIsAnswer && status == 410)) throw StateError('HTTP $status');
    return Ham2kResponse(status: status, version: version, body: Stream.fromIterable([utf8.encode(body)]));
  }
}

String _ndjson(List<Map<String, Object?>> records) => records.map((r) => '${jsonEncode(r)}\n').join();

void main() {
  late HaLoDatabase db;
  late LookupRepository lookups;

  setUp(() {
    db = HaLoDatabase(NativeDatabase.memory());
    lookups = LookupRepository(db);
  });
  tearDown(() => db.close());

  /// Rows in the category when the host is told a snapshot starts writing,
  /// once per call.
  late List<int> snapshotWrites;
  setUp(() => snapshotWrites = []);

  Future<Ham2kSyncResult> sync(_Server server, {String? held, bool snapshot = false, bool force = false, int batchSize = 5000}) => syncHam2kDataFile(
    key: 'calls-hf',
    category: 'calls-hf',
    url: _url,
    deltaUrl: _deltaUrl,
    fields: _fields,
    heldVersion: held,
    snapshot: snapshot,
    force: force,
    fetch: server.fetch,
    lookups: lookups,
    onSnapshotWrites: () async => snapshotWrites.add(await lookups.countCategory('calls-hf')),
    batchSize: batchSize,
  );

  Future<void> seed() => lookups.insertLookupBatch([LookupRow(category: 'calls-hf', key: 'HELD', updated: 1)]);

  Future<List<String>> keys() async => [for (final row in await lookups.queryLookups('calls-hf', '')) row.key]..sort();

  test('a snapshot replaces the category, each row keyed and named by the fields, the record kept whole', () async {
    await lookups.insertLookupBatch([LookupRow(category: 'calls-hf', key: 'GONE1', updated: 1)]);
    final line = jsonEncode({'call': 'W1AW', 'name': 'ARRL', 'country': 'US', 'grid': 'FN31pr'});
    // Batches of 2 across 3 records: the last, partial batch is the one a
    // missing final flush would drop.
    final server = _Server({
      _url: (
        200,
        '2026-11-09',
        '$line\n${_ndjson([
          {'call': 'VE3X', 'name': 'X'},
          {'call': 'K2A'},
        ])}',
      ),
    });

    final result = await sync(server, batchSize: 2);

    expect(result.kind, Ham2kSyncKind.snapshot);
    expect(result.version, '2026-11-09');
    expect(result.rows, 3);
    expect(await keys(), ['K2A', 'VE3X', 'W1AW'], reason: 'a row the snapshot does not carry is gone');
    final w1aw = await lookups.getLookup('calls-hf', 'W1AW');
    expect(w1aw!.name, 'ARRL');
    expect(w1aw.subCategory, 'US');
    expect(w1aw.data, line, reason: 'the record is stored as the server sent it, not re-encoded');
  });

  test('a delta writes and deletes only what changed, and sweeps nothing else', () async {
    await sync(
      _Server({
        _url: (
          200,
          'v1',
          _ndjson([
            for (var i = 0; i < 1200; i++) {'call': 'OLD$i'},
            {'call': 'KEEP'},
            {'call': 'EDIT', 'name': 'before'},
          ]),
        ),
      }),
    );
    // 1,200 removals: past the parameters one SQLite statement may bind.
    final delta = jsonEncode({
      'added': [
        {'call': 'NEW', 'name': 'new'},
      ],
      'changed': [
        {'call': 'EDIT', 'name': 'after'},
      ],
      'removed': [for (var i = 0; i < 1200; i++) 'OLD$i'],
    });
    final server = _Server({'https://example.test/delta?set=hf&since=v1': (200, 'v2', delta)});

    final result = await sync(server, held: 'v1');

    expect(server.requested, ['https://example.test/delta?set=hf&since=v1']);
    expect(result.kind, Ham2kSyncKind.delta);
    expect(result.version, 'v2');
    expect(result.rows, 2, reason: 'a removal is not an imported record, and may name a key this device never held');
    expect(await keys(), ['EDIT', 'KEEP', 'NEW'], reason: 'KEEP is in no delta list, and a delta must never sweep it');
    expect((await lookups.getLookup('calls-hf', 'EDIT'))!.name, 'after');
  });

  test('a delta naming the version already held writes nothing', () async {
    await seed();
    final server = _Server({'https://example.test/delta?set=hf&since=v2': (200, 'v2', '{"added":[],"changed":[],"removed":[]}')});

    final result = await sync(server, held: 'v2');

    expect(result.kind, Ham2kSyncKind.unchanged);
    expect(server.requested, hasLength(1), reason: 'an up-to-date device downloads no snapshot');
  });

  test('a delta the server refuses (410) falls back to the snapshot', () async {
    await seed();
    final server = _Server({
      'https://example.test/delta?set=hf&since=ancient': (410, null, '{"error":"gone"}'),
      _url: (
        200,
        'v9',
        _ndjson([
          {'call': 'W1AW'},
        ]),
      ),
    });

    final result = await sync(server, held: 'ancient');

    expect(server.requested, ['https://example.test/delta?set=hf&since=ancient', _url]);
    expect(result.kind, Ham2kSyncKind.snapshot);
    expect(result.version, 'v9');
  });

  test('a forced refresh takes the snapshot even with a version held', () async {
    final server = _Server({
      _url: (
        200,
        'v3',
        _ndjson([
          {'call': 'W1AW'},
        ]),
      ),
    });

    await sync(server, held: 'v2', snapshot: true);

    expect(server.requested, [_url], reason: 'the delta would carry only what changed, not repair what the device lost');
  });

  test('a snapshot far smaller than the category is refused unless forced', () async {
    await sync(
      _Server({
        _url: (
          200,
          'v1',
          _ndjson([
            for (var i = 0; i < 100; i++) {'call': 'C$i'},
          ]),
        ),
      }),
    );
    final short = _Server({
      _url: (
        200,
        'v2',
        _ndjson([
          {'call': 'C0'},
        ]),
      ),
    });

    await expectLater(sync(short), throwsA(isA<DataFileImportShrank>()));
    expect(await keys(), hasLength(100), reason: 'a cut-short body must not sweep the rows it left out');

    final forced = await sync(short, force: true);
    expect(forced.forcedShrink, isNotNull);
    expect(await keys(), ['C0']);
  });

  test('a line that is not a keyed record, or not JSON at all, is skipped, not fatal', () async {
    final server = _Server({
      _url: (
        200,
        'v1',
        '${_ndjson([
          {'call': 'W1AW'},
          {'name': 'no key'},
        ])}[1,2]\n\n{"call":"CUT\n',
      ),
    });

    final result = await sync(server);

    expect(result.rows, 1);
    expect(await keys(), ['W1AW']);
  });

  test('an empty category takes the snapshot whatever version the host holds', () async {
    final server = _Server({
      _url: (
        200,
        'v9',
        _ndjson([
          {'call': 'W1AW'},
          {'call': 'K2A'},
        ]),
      ),
    });

    final result = await sync(server, held: 'v8');

    // A purge, or an extension that moved its category, empties it with the
    // version still held: a delta would leave only the day's changes, and the
    // category, no longer empty, would never be repaired.
    expect(server.requested, [_url]);
    expect(result.kind, Ham2kSyncKind.snapshot);
  });

  test('the host hears a snapshot start writing before its first row, and a delta never', () async {
    await lookups.insertLookupBatch([for (var i = 0; i < 3; i++) LookupRow(category: 'calls-hf', key: 'OLD$i', updated: 1)]);
    await sync(
      _Server({
        'https://example.test/delta?set=hf&since=v1': (
          200,
          'v2',
          jsonEncode({
            'added': [
              {'call': 'NEW'},
            ],
            'changed': <Object>[],
            'removed': <Object>[],
          }),
        ),
      }),
      held: 'v1',
    );
    expect(snapshotWrites, isEmpty, reason: 'a delta writes in one transaction: a failure leaves the version held true');

    await sync(
      _Server({
        _url: (
          200,
          'v3',
          _ndjson([
            for (var i = 0; i < 4; i++) {'call': 'SNAP$i'},
          ]),
        ),
      }),
      snapshot: true,
    );
    // Told after the first batch, a host whose import then fails still holds
    // a version for a category that no longer matches it.
    expect(snapshotWrites, [4]);
  });
}

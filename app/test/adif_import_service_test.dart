// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Dart half of the `adifImport` crossing. These are the invariants that
// live on THIS side of the bridge and that no extension test can reach:
// batching, positional matching of results to records, and what happens when a
// hook misbehaves. The hook's own logic is proven against the real runtime in
// packages/halo_extension_host/test/adif_import_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'package:ham2k_logger/services/adif_import_service.dart';

/// Records the batches it was asked about, and replies with whatever the test
/// set up per hook key.
class _RecordingHost implements ExtensionHost {
  /// hook key -> a reply for one batch, given that batch's field maps.
  final Map<String, Object? Function(List<Map<String, String>>)> replies;
  final List<int> batchSizes = [];

  _RecordingHost(this.replies);

  @override
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
    bool partialOnTimeout = false,
  }) async {
    final records = ((args as Map)['records'] as List)
        .map((r) => ((r as Map)['fields'] as Map).cast<String, String>())
        .toList();
    batchSizes.add(records.length);
    return [
      for (final entry in replies.entries) {'ok': true, 'key': entry.key, 'value': entry.value(records)},
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<AdifRecord> _records(int count) => [
      for (var i = 0; i < count; i++)
        AdifRecord(number: i + 1, fields: {'call': 'W$i'}, qso: <String, dynamic>{'their': {}}),
    ];

List<Map<String, dynamic>> _refs(AdifRecord record) =>
    ((record.qso['refs'] as List?) ?? const []).cast<Map<String, dynamic>>();

void main() {
  test('applies each hook\'s refs to the matching record', () async {
    final host = _RecordingHost({
      'pota': (records) => [
            for (final r in records) r['call'] == 'W1' ? {'refs': [{'type': 'pota', 'ref': 'K-1'}]} : null,
          ],
    });

    final records = _records(3);
    await AdifImportService(host).applyHooks(records);

    expect(_refs(records[0]), isEmpty);
    expect(_refs(records[1]), [{'type': 'pota', 'ref': 'K-1'}]);
    expect(_refs(records[2]), isEmpty);
  });

  test('accumulates refs from different hooks on one QSO', () async {
    // A park-to-park contact made during a summit activation carries both
    // programs' references; neither hook may overwrite the other's.
    final host = _RecordingHost({
      'pota': (records) => [for (final _ in records) {'refs': [{'type': 'pota', 'ref': 'K-1'}]}],
      'sota': (records) => [for (final _ in records) {'refs': [{'type': 'sota', 'ref': 'W2/GC-001'}]}],
    });

    final records = _records(1);
    await AdifImportService(host).applyHooks(records);

    expect(_refs(records[0]), [
      {'type': 'pota', 'ref': 'K-1'},
      {'type': 'sota', 'ref': 'W2/GC-001'},
    ]);
  });

  test('dedupes a ref two hooks both recognized', () async {
    // Duplicates would be scored and exported twice, so the same reference
    // arriving from two hooks must land once.
    final host = _RecordingHost({
      'pota': (records) => [for (final _ in records) {'refs': [{'type': 'pota', 'ref': 'K-1'}]}],
      'legacy': (records) => [for (final _ in records) {'refs': [{'type': 'pota', 'ref': 'K-1'}]}],
    });

    final records = _records(1);
    await AdifImportService(host).applyHooks(records);

    expect(_refs(records[0]), hasLength(1));
  });

  test('discards a reply whose length does not match the batch', () async {
    // The core matches results to records BY INDEX. A hook that filtered its
    // own empties out would silently shift every later record's references
    // onto the wrong QSO — a corruption that looks like a successful import.
    final host = _RecordingHost({
      'buggy': (records) => [{'refs': [{'type': 'pota', 'ref': 'K-1'}]}],
    });

    final records = _records(3);
    await AdifImportService(host).applyHooks(records);

    expect(records.every((r) => _refs(r).isEmpty), isTrue);
  });

  test('splits a large log into batches instead of one giant crossing', () async {
    final host = _RecordingHost({'pota': (records) => [for (final _ in records) null]});

    await AdifImportService(host).applyHooks(_records(1200));

    expect(host.batchSizes, [500, 500, 200]);
  });

  test('imports ref-less rather than failing when there is no host', () async {
    // No extension runtime is a degraded import, never a refused one.
    final records = _records(2);
    final outcome = await AdifImportService(null).applyHooks(records);

    expect(records.every((r) => _refs(r).isEmpty), isTrue);
    // Ref-less because there is no runtime is NOT a clean import.
    expect(outcome.degraded, isTrue);
    expect(outcome.recordsAtRisk, 2);
  });

  test('a crossing that throws loses the batch, and says so', () async {
    // invokeHookAll throws for the WHOLE crossing, so every hook loses this
    // batch — not just one. The outcome has to carry that.
    final records = _records(2);

    final outcome = await AdifImportService(_ThrowingHost()).applyHooks(records);

    expect(records.every((r) => _refs(r).isEmpty), isTrue);
    expect(outcome.degraded, isTrue);
    expect(outcome.recordsAtRisk, 2);
  });

  test('a hook reporting ok:false is recorded, not discarded in silence', () async {
    // The designed per-hook failure channel and the likeliest failure in the
    // feature. Losing every POTA reference in a batch must not look like a
    // file that had none.
    final host = _FailingHookHost();
    final records = _records(3);

    final outcome = await AdifImportService(host).applyHooks(records);

    expect(outcome.failedHooks, contains('pota'));
    expect(outcome.recordsAtRisk, 3);
    expect(outcome.degraded, isTrue);
  });

  test('a ref with no type or no value is refused', () async {
    // Persisting it would put {type: pota} on the operator's QSO.
    final host = _RecordingHost({
      'pota': (records) => [
            for (final _ in records)
              {'refs': [{'type': 'pota'}, {'type': 'pota', 'ref': 'K-1'}]},
          ],
    });

    final records = _records(1);
    final outcome = await AdifImportService(host).applyHooks(records);

    expect(_refs(records[0]), [{'type': 'pota', 'ref': 'K-1'}]);
    expect(outcome.failedHooks, contains('pota'));
  });

  test('a hook broken for the whole file counts every record it cost', () async {
    // The failure set spans the import, so asking whether it GREW is only ever
    // true on the first batch — reporting 500 lost records out of 1,200. The
    // number this class exists to report would be the one it understates.
    final host = _FailingHookHost();
    final records = _records(1200);

    final outcome = await AdifImportService(host).applyHooks(records);

    expect(outcome.recordsAtRisk, 1200);
    expect(outcome.failedHooks, contains('pota'));
  });

  test('a clean import reports no degradation', () async {
    // Guards every assertion above: if everything degraded, none of it would
    // mean anything.
    final host = _RecordingHost({
      'pota': (records) => [for (final _ in records) {'refs': [{'type': 'pota', 'ref': 'K-1'}]}],
    });

    final outcome = await AdifImportService(host).applyHooks(_records(2));

    expect(outcome.degraded, isFalse);
    expect(outcome.recordsAtRisk, 0);
  });
}

/// One hook replies `ok: false`, the runtime's per-hook failure channel.
class _FailingHookHost implements ExtensionHost {
  @override
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
    bool partialOnTimeout = false,
  }) async =>
      [
        {'key': 'pota', 'ok': false, 'error': 'TypeError: normalize is not a function'},
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThrowingHost implements ExtensionHost {
  @override
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
    bool partialOnTimeout = false,
  }) async =>
      throw ExtensionHostException('runtime is dead');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

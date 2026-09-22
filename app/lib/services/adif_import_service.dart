// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The extension half of an ADIF import: `halo_core`'s parser produces QSON
// with no references at all, and this runs the `adifImport` hooks that put
// them back (docs/extensions/hooks.md).
//
// It sits in the app rather than in `halo_core` because `halo_core` is pure
// Dart with no extension-host dependency, and keeping it that way is what lets
// the parser and its ten-file corpus be tested without booting QuickJS.
//
// **Batched.** Every other per-QSO hook runs inside the extension runtime,
// where a call per QSO costs nothing; this one is driven from Dart, so each
// call is a bridge crossing. A ten-thousand-contact import is twenty
// crossings, not ten thousand.

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

/// How many records ride one bridge crossing. Large enough that the crossing
/// disappears into the parse, small enough that one batch's JSON stays a
/// reasonable string to build on both sides.
const _batchSize = 500;

/// Timeout per batch. Generous because a hook may be resolving references
/// against its own offline dataset, and losing a whole batch's refs is worse
/// than waiting.
const _batchTimeout = Duration(seconds: 30);

/// What the hook pass could not do, so an import summary can say so.
///
/// Degrading to a ref-less import is defensible ONLY if the degradation is
/// visible. Without this, "the file had no references" and "every POTA
/// reference in 500 contacts was lost to a broken hook" are the same outcome
/// to the operator.
class AdifImportOutcome {
  final List<AdifRecord> records;

  /// Hook keys that errored or replied unusably, plus `'*'` when the whole
  /// crossing failed or there was no runtime at all.
  ///
  /// NOT covered: a live runtime with no `adifImport` hook registered. That is
  /// indistinguishable here from a user who simply has no activity extensions
  /// enabled, whose import genuinely has no references — and reporting it as
  /// degradation would cry wolf on the common case. A caller that knows which
  /// extensions the user expects can tell the difference; this service cannot.
  final Set<String> failedHooks;

  /// Records in a batch that never reached the runtime, so NO hook ran for
  /// them and nothing could have been recovered.
  final int recordsUnreachable;

  /// Records in a batch where a NAMED hook failed. Every other hook still ran
  /// for these, so their references may be incomplete rather than absent.
  ///
  /// Separate from [recordsUnreachable] because the two support different
  /// sentences, and one total shared between them makes the stronger sentence
  /// false: a file big enough to hit both failures in different batches would
  /// otherwise report "nothing was recovered" over records whose other hooks
  /// answered in full.
  final int recordsWithFailedHooks;

  const AdifImportOutcome({required this.records, this.failedHooks = const {}, this.recordsUnreachable = 0, this.recordsWithFailedHooks = 0});

  /// Every record whose references may be short, however they came to be.
  int get recordsAtRisk => recordsUnreachable + recordsWithFailedHooks;

  bool get degraded => failedHooks.isNotEmpty;
}

class AdifImportService {
  final ExtensionHost? _host;

  AdifImportService(this._host);

  /// Fills in each record's `refs` from the `adifImport` hooks.
  ///
  /// Mutates the records' `qso` maps in place; the returned outcome carries
  /// them plus whatever went wrong, so a caller can hand the parser's output
  /// straight through and still report a partial result honestly.
  ///
  /// Degrades rather than fails: with no host, no hooks, or a failing batch,
  /// the QSOs import ref-less rather than not at all.
  /// [onBatch], when given, is called after every batch with (records
  /// processed so far, total records) — the natural checkpoint for a caller
  /// showing real progress rather than an indeterminate spinner for however
  /// long the crossings take.
  Future<AdifImportOutcome> applyHooks(List<AdifRecord> records, {void Function(int done, int total)? onBatch}) async {
    final host = _host;
    if (host == null || records.isEmpty) {
      return AdifImportOutcome(
        records: records,
        // No runtime is a known-incomplete import, not a clean one: every
        // reference in the file is silently absent.
        failedHooks: host == null && records.isNotEmpty ? const {'*'} : const {},
        recordsUnreachable: host == null ? records.length : 0,
      );
    }

    final failed = <String>{};
    var unreachable = 0;
    var withFailedHooks = 0;
    for (var start = 0; start < records.length; start += _batchSize) {
      final end = start + _batchSize < records.length ? start + _batchSize : records.length;
      final batch = records.sublist(start, end);
      // Each batch gets its own failure set. Testing whether the RUNNING set
      // grew would only ever be true the first time a given hook failed, so a
      // hook broken for the whole file would report one batch's worth of
      // damage — understating exactly the number this exists to report.
      final batchFailed = <String>{};
      await _applyBatch(host, batch, batchFailed);
      // A caller's progress UI throwing (a disposed notifier, a formatting
      // edge case) must not fail the import itself, or discard the
      // failure/unreachable counts already accumulated from batches that
      // actually ran clean.
      try {
        onBatch?.call(end, records.length);
      } catch (e) {
        debugPrint('[extensions] adifImport onBatch callback failed: $e');
      }
      // Split by KIND, not just counted. Within one batch these are mutually
      // exclusive — the crossing's catch returns before any named key is added
      // — but across batches a long file can hit both, and then each number has
      // to answer for its own sentence.
      if (batchFailed.contains('*')) unreachable += batch.length;
      if (batchFailed.any((key) => key != '*')) withFailedHooks += batch.length;
      failed.addAll(batchFailed);
    }
    return AdifImportOutcome(records: records, failedHooks: failed, recordsUnreachable: unreachable, recordsWithFailedHooks: withFailedHooks);
  }

  Future<void> _applyBatch(ExtensionHost host, List<AdifRecord> batch, Set<String> failed) async {
    final List<Map<String, dynamic>> entries;
    try {
      entries = await host.invokeHookAll(
        'adifImport',
        method: 'refsForRecords',
        args: {
          'records': [
            for (final record in batch) {'fields': record.fields},
          ],
        },
        timeout: _batchTimeout,
      );
    } catch (e) {
      debugPrint('[extensions] adifImport batch failed: $e');
      failed.add('*');
      return;
    }

    // Refs accumulate across hooks — a park-to-park contact logged during a
    // summit activation legitimately carries both programs' references — but
    // the same ref must not arrive twice from two hooks that both recognized
    // it, since duplicates would be scored and exported twice.
    final seen = List.generate(batch.length, (_) => <String>{}, growable: false);

    for (final entry in entries) {
      final key = (entry['key'] as String?) ?? '?';
      // `ok: false` is the DESIGNED channel for "this one hook blew up" and
      // the likeliest failure in the feature. Discarding it silently makes a
      // batch that lost every POTA reference indistinguishable from a file
      // that never had one.
      if (entry['ok'] != true) {
        debugPrint('[extensions] adifImport hook $key failed: ${entry['error']}');
        failed.add(key);
        continue;
      }
      final value = entry['value'];
      if (value is! List) {
        debugPrint('[extensions] adifImport hook $key returned ${value.runtimeType}, expected a list');
        failed.add(key);
        continue;
      }
      // Results are positional. A hook that returned the wrong number of them
      // has lost track of which record is which, and applying the overlap
      // would put one QSO's references on another — drop the whole reply.
      if (value.length != batch.length) {
        debugPrint('[extensions] adifImport hook $key returned ${value.length} results for ${batch.length} records');
        failed.add(key);
        continue;
      }

      for (var i = 0; i < batch.length; i++) {
        final result = value[i];
        if (result is! Map) continue;
        final refs = result['refs'];
        if (refs is! List) continue;

        for (final ref in refs) {
          if (ref is! Map) continue;
          final typed = ref.cast<String, dynamic>();
          // A ref with no type or no value is not a reference. Persisting one
          // would put `{type: pota}` on the operator's QSO and dedupe it
          // under the key "pota|null".
          if (typed['type'] is! String || typed['ref'] is! String) {
            debugPrint('[extensions] adifImport hook $key returned a ref with no type/ref: $typed');
            failed.add(key);
            continue;
          }
          if (!seen[i].add('${typed['type']}|${typed['ref']}')) continue;
          final existing = batch[i].qso['refs'];
          if (existing is List) {
            existing.add(typed);
          } else {
            batch[i].qso['refs'] = <Map<String, dynamic>>[typed];
          }
        }
      }
    }
  }
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Builds an operation's title/subtitle from its refs (ham2k/app-halo-dist#174):
// each ref's `ref:<type>` hook gets one `suggestOperationTitle` call (mirrors
// `decorateRef`'s per-ref dispatch), and the merged fragments are cached into
// `operations.local_data` — device-local like `ScoringService`'s summaries,
// since it's cheaply regenerable from `refs` and never needs to sync.

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

import 'extension_service.dart';

class OperationTitleService {
  final ExtensionService extensions;
  final OperationsRepository operations;

  /// One generation counter per operation, so an OLDER call's cache write
  /// can't land after a NEWER one's and clobber it with stale data — unlike
  /// a fingerprint dedup (which only catches redundant *identical* calls),
  /// this catches two DIFFERENT ref-sets racing out of issue order (e.g. the
  /// plain Activities modal now persists each ref edit immediately, so
  /// adding two refs in quick succession fires two overlapping retitles;
  /// nothing guarantees the one for the smaller ref-set resolves first).
  final Map<String, int> _generationByUuid = {};

  OperationTitleService({required this.extensions, required this.operations});

  /// Suggests and caches [operation]'s title/subtitle fragments from its
  /// current refs. Degrades silently if the extension runtime isn't ready or
  /// a hook call fails — like scoring, this is a display enhancement, never
  /// load-bearing.
  Future<void> retitleOperation(Operation operation) async {
    final host = extensions.host;
    if (host == null) return;

    // Captured synchronously, before any await — a call issued after this
    // point (even one that finishes first) bumps this past our value, so our
    // eventual write(s) below can detect they've been superseded.
    final generation = (_generationByUuid[operation.uuid] ?? 0) + 1;
    _generationByUuid[operation.uuid] = generation;
    bool superseded() => _generationByUuid[operation.uuid] != generation;

    final refs = operation.refs;
    if (refs.isEmpty) {
      if (superseded()) return;
      await operations.updateLocalData(operation.uuid, {'titleSuggestion': null});
      return;
    }

    final operationPayload = {...operation.data, 'uuid': operation.uuid};

    // In parallel, like ExtensionService.sendSpot's per-hook fan-out — a
    // multi-ref operation shouldn't pay the SUM of each ref's hook latency
    // when the MAX is all that's needed (each ref's suggestion is
    // independent of the others).
    final results = await Future.wait(refs.map((ref) async {
      final type = ref['type'] as String?;
      if (type == null) return null;
      try {
        final result = await host.invokeHook(
          'ref:$type',
          method: 'suggestOperationTitle',
          args: {'ref': ref, 'operation': operationPayload},
          timeout: const Duration(seconds: 10),
        );
        if (result is! Map) return null;
        return OperationTitleSuggestion(
          title: result['title'] as String?,
          forText: result['for'] as String?,
          atText: result['at'] as String?,
          subtitle: result['subtitle'] as String?,
          priority: (result['priority'] as num?) ?? 0,
        );
      } catch (e) {
        debugPrint('[operationTitle] suggestOperationTitle failed for ref:$type: $e');
        return null;
      }
    }));

    if (superseded()) return;

    final fragments = mergeOperationTitleSuggestions(results.whereType<OperationTitleSuggestion>());
    await operations.updateLocalData(operation.uuid, {
      'titleSuggestion': fragments.isEmpty
          ? null
          : {
              'title': fragments.title,
              'for': fragments.forText,
              'at': fragments.atText,
              'subtitle': fragments.subtitle,
            },
    });
  }
}

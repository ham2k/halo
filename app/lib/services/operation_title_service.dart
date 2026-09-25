// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Builds an operation's title/subtitle from its refs:
// each ref's `ref:<type>` hook gets one `suggestOperationTitle` call (mirrors
// `decorateRef`'s per-ref dispatch), and the merged fragments are cached into
// `operations.local_data` — device-local like `ScoringService`'s summaries,
// since it's cheaply regenerable from `refs` and never needs to sync.

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

import 'extensions/extension_service.dart';

class OperationTitleService {
  final ExtensionService extensions;
  final OperationsRepository operations;

  /// One generation counter per operation, so an OLDER call's cache write
  /// can't land after a NEWER one's and clobber it with stale data — unlike
  /// a fingerprint dedup (which only catches redundant *identical* calls),
  /// this catches two DIFFERENT ref-sets racing out of issue order (the
  /// plain Activities modal persists each ref edit immediately, so
  /// adding two refs in quick succession fires two overlapping retitles;
  /// nothing guarantees the one for the smaller ref-set resolves first).
  final Map<String, int> _generationByUuid = {};

  OperationTitleService({required this.extensions, required this.operations});

  /// Suggests and caches [operation]'s title/subtitle fragments from its
  /// current refs. Degrades silently if the extension runtime isn't ready or
  /// a hook call fails — like scoring, this is a display enhancement, never
  /// load-bearing.
  Future<void> retitleOperation(Operation operation) async {
    if (extensions.host == null) return;

    // Captured synchronously, before any await — a call issued after this
    // point (even one that finishes first) bumps this past our value, so our
    // eventual write(s) below can detect they've been superseded.
    final generation = (_generationByUuid[operation.uuid] ?? 0) + 1;
    _generationByUuid[operation.uuid] = generation;
    bool superseded() => _generationByUuid[operation.uuid] != generation;

    final fragments = await suggestFragments(operation);
    if (fragments == null || superseded()) return;

    await operations.updateLocalData(operation.uuid, {
      'titleSuggestion': fragments.isEmpty
          ? null
          : {'title': fragments.title, 'for': fragments.forText, 'at': fragments.atText, 'subtitle': fragments.subtitle},
    });
  }

  /// The same per-ref fan-out and merge, but returning the fragments instead
  /// of caching them — for an operation that has no saved row to cache into
  /// yet, i.e. the operation sheet's buffered draft, whose refs change as the
  /// user picks activities and only reach the database on Save. `null` when
  /// the extension runtime isn't up (nothing could be suggested).
  Future<OperationTitleFragments?> suggestFragments(Operation operation) async {
    final result = await suggestForRefs(operation);
    if (result == null) return null;
    return mergeOperationTitleSuggestions(result.suggestions);
  }

  /// One suggestion per ref that answered, in ref order — the unmerged form
  /// a segment row's description is composed from (polo's
  /// `describeOperation` phrases each ref separately). `null` when the
  /// extension runtime isn't up at all.
  ///
  /// [RefTitleSuggestions.complete] separates a ref that answered with
  /// NOTHING from one that could not be asked. Plenty of ref types
  /// legitimately offer no title (`ref:satellite` registers no
  /// `suggestOperationTitle`, and the SDK's own handler declines a
  /// half-entered reference), so counting those as failures would keep a
  /// caller that persists what it composed — a segment row's description —
  /// from ever writing one. Only a hook that THREW or timed out clears the
  /// flag: that phrase is missing from an otherwise complete sentence, and
  /// nothing recomposes it later.
  Future<RefTitleSuggestions?> suggestForRefs(Operation operation) async {
    final host = extensions.host;
    if (host == null) return null;

    final refs = operation.refs;
    if (refs.isEmpty) return const RefTitleSuggestions(suggestions: [], complete: true);

    final operationPayload = {...operation.data, 'uuid': operation.uuid};

    // In parallel, like ExtensionService.sendSpot's per-hook fan-out — a
    // multi-ref operation shouldn't pay the SUM of each ref's hook latency
    // when the MAX is all that's needed (each ref's suggestion is
    // independent of the others).
    var complete = true;
    final results = await Future.wait(
      refs.map((ref) async {
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
          complete = false;
          return null;
        }
      }),
    );

    return RefTitleSuggestions(suggestions: results.whereType<OperationTitleSuggestion>().toList(), complete: complete);
  }
}

/// What every ref that HAS a title to offer said, and whether each ref was
/// actually reached — see [OperationTitleService.suggestForRefs].
class RefTitleSuggestions {
  final List<OperationTitleSuggestion> suggestions;

  /// False when a `suggestOperationTitle` hook threw or timed out, so a
  /// phrase is missing rather than absent by choice.
  final bool complete;

  const RefTitleSuggestions({required this.suggestions, required this.complete});
}

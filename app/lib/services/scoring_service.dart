// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Scoring flow: the extension runtime scores every QSO in an operation in
// one coarse batched call (DESIGN.md §4: "score 500 QSOs in one call, not
// 500 calls"). The core writes the per-QSO verdicts into `qsos.score_cache`
// and the day/operation summaries into `operations.local_data`, so list
// scroll and score displays both read from SQLite and never wait on the JS
// runtime.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

import 'extension_service.dart';

class ScoringService {
  final ExtensionService extensions;
  final QsosRepository qsos;
  final OperationsRepository operations;

  ScoringService({required this.extensions, required this.qsos, required this.operations});

  /// Scores every QSO currently logged for [operation] and caches the
  /// results. Degrades silently if the extension runtime isn't ready or the
  /// hook call fails — scoring is a display enhancement, never load-bearing,
  /// so callers don't need to handle a thrown error.
  Future<void> rescoreOperation(Operation operation) async {
    final host = extensions.host;
    if (host == null) return;

    final qsoList = await qsos.watchForOperation(operation.uuid).first;
    if (qsoList.isEmpty) return;

    try {
      final result = await host.invokeHook(
        'scoring',
        key: 'core',
        method: 'scoreQsos',
        args: qsonPayloadFor(operation: operation, qsos: qsoList),
        timeout: const Duration(seconds: 10),
      ) as Map;

      final qsoScores = (result['qsoScores'] as Map?) ?? const {};
      final scoreCacheByUuid = <String, String>{
        for (final entry in qsoScores.entries) entry.key as String: jsonEncode(entry.value),
      };
      await qsos.updateScoreCache(scoreCacheByUuid);

      await operations.updateLocalData(operation.uuid, {
        'scoring': {
          'daySections': result['daySections'],
          'operationSummary': result['operationSummary'],
        },
      });
    } catch (e) {
      debugPrint('[scoring] rescoreOperation failed: $e');
    }
  }
}

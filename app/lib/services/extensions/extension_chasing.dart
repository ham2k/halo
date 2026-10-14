// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The `chasing` hook calls `ExtensionService` makes: what programs exist, what
// a batch of contacts claims under one of them, whose checklists a station
// keeps, how one reads, and what an imported file claims
// (docs/design/claims.md). A mixin rather than an
// extension so a test double can still override one call.

import 'package:flutter/foundation.dart' show ValueNotifier, debugPrint;
import 'package:halo_core/halo_core.dart' show ChasingProgram, Hooks, ImportedClaim, QsoClaim;
import 'package:halo_extension_host/halo_extension_host.dart';

import '../error_reporting_service.dart';

/// A `chasing` hook that threw, timed out, or answered something that is not
/// what the hook promises. Per program and per method, like scoring's: one
/// program failing costs only its own answer. Classified `report` in
/// [ErrorPolicy] — a defect in that extension, which the operator cannot act
/// on. What it costs is absence: that program's claims for the batch are
/// missing, so a checklist reads as less worked than it is.
class ChasingHookFailure implements Exception {
  ChasingHookFailure(this.programKey, this.method, this.cause);
  final String programKey;
  final String method;
  final Object cause;

  @override
  String toString() => 'ChasingHookFailure: program "$programKey" failed $method: $cause';
}

String _failureKey(String programKey, String method) => 'chasing:$programKey:$method';

/// Once per program per method until it answers again: a log rescan asks a
/// program about every batch of contacts, and one broken program is one
/// event, not one per batch.
void _reportFailure(String programKey, String method, Object error, StackTrace stackTrace) {
  ErrorReportingService.reportIfRepeated(
    _failureKey(programKey, method),
    ChasingHookFailure(programKey, method, error),
    stackTrace,
    context: 'chasing:$programKey:$method',
    threshold: 1,
  );
}

/// A whole batch of contacts goes in one call, so this is per batch, not per
/// contact.
const kClaimsForQsosTimeout = Duration(seconds: 20);

/// A whole file goes in one call: a sponsor's export runs to thousands of
/// lines.
const kImportClaimsTimeout = Duration(seconds: 60);

/// What a program read from an imported file: its claims, and how many of
/// the file's records it could not read, malformed answers included.
typedef ImportedClaims = ({List<ImportedClaim> claims, int skipped});

mixin ExtensionChasing {
  ExtensionHost? get host;
  ValueNotifier<int> get runtimeGeneration;

  Map<String, ChasingProgram>? _programs;
  int? _programsGeneration;

  /// [getChasingPrograms], asked once per runtime: only a new one can bring
  /// or take away a program, and asking per contact logged or per spot
  /// refresh is a crossing into every extension each time. A null answer is
  /// not kept.
  Future<Map<String, ChasingProgram>?> chasingPrograms() async {
    final generation = runtimeGeneration.value;
    if (_programs == null || _programsGeneration != generation) {
      final programs = await getChasingPrograms();
      if (programs == null) return null;
      _programs = programs;
      _programsGeneration = generation;
    }
    return _programs;
  }

  /// Every registered program, keyed by its hook key. A program whose
  /// `program` member is malformed is left out and reported; the others are
  /// unaffected. Null when the runtime could not be asked at all (none yet,
  /// or the call failed): that says nothing about which programs exist, and
  /// read as "none" it would withdraw every program's bookkeeping.
  Future<Map<String, ChasingProgram>?> getChasingPrograms() async {
    final host = this.host;
    if (host == null) return null;
    final List<Map<String, dynamic>> entries;
    try {
      entries = await host.invokeAll(Hooks.chasingProgram, timeout: const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[extensions] getChasingPrograms failed: $e');
      return null;
    }
    final programs = <String, ChasingProgram>{};
    for (final entry in entries) {
      final key = entry['key'];
      if (key is! String || entry['ok'] != true) continue;
      final program = ChasingProgram.tryParse(key, entry['value']);
      if (program == null) {
        _reportFailure(key, Hooks.chasingProgram.method, FormatException('not a program description', '${entry['value']}'), StackTrace.current);
        continue;
      }
      ErrorReportingService.recordSuccess(_failureKey(key, Hooks.chasingProgram.method));
      programs[key] = program;
    }
    return programs;
  }

  /// What each of [qsos] claims under [programKey], keyed by contact uuid.
  /// Null when the program failed — distinct from a map that holds no claims,
  /// which is the program saying none of these count. A contact with any
  /// malformed entry is left out of the answer, and reported: an answer
  /// missing some of its claims would read as the contact no longer claiming
  /// them. The other contacts' answers stand.
  Future<Map<String, List<QsoClaim>>?> claimsForQsos(String programKey, List<Map<String, dynamic>> qsos) async {
    final host = this.host;
    if (host == null) return null;
    final method = Hooks.chasingClaimsForQsos.method;
    try {
      final result = await host.invoke(Hooks.chasingClaimsForQsos, key: programKey, args: {'qsos': qsos}, timeout: kClaimsForQsosTimeout);
      if (result is! Map) throw FormatException('claimsForQsos answered ${result.runtimeType}, not a map by contact');
      final claims = <String, List<QsoClaim>>{};
      var malformed = 0;
      for (final MapEntry(:key, :value) in result.entries) {
        if (key is! String || value is! List) {
          malformed++;
          continue;
        }
        final parsed = [for (final item in value) QsoClaim.tryParse(item)];
        if (parsed.contains(null)) {
          malformed++;
          continue;
        }
        claims[key] = parsed.nonNulls.toList();
      }
      if (malformed > 0) {
        _reportFailure(programKey, method, FormatException('$malformed contacts answered with malformed claims'), StackTrace.current);
      } else {
        ErrorReportingService.recordSuccess(_failureKey(programKey, method));
      }
      return claims;
    } catch (e, stackTrace) {
      _reportFailure(programKey, method, e, stackTrace);
      return null;
    }
  }

  /// The holders [station] claims as under [programKey], or null when the
  /// program failed.
  Future<List<String>?> holdersFor(String programKey, Map<String, dynamic> station) async {
    final host = this.host;
    if (host == null) return null;
    final method = Hooks.chasingHoldersFor.method;
    try {
      final result = await host.invoke(Hooks.chasingHoldersFor, key: programKey, args: {'station': station}, timeout: const Duration(seconds: 5));
      if (result is! List) throw FormatException('holdersFor answered ${result.runtimeType}, not a list');
      ErrorReportingService.recordSuccess(_failureKey(programKey, method));
      return [
        for (final holder in result)
          if (holder is String && holder.isNotEmpty) holder,
      ];
    } catch (e, stackTrace) {
      _reportFailure(programKey, method, e, stackTrace);
      return null;
    }
  }

  /// [programKey]'s tallies for one holder's filled [slots] (`{ref, band,
  /// mode, level, label?}` each), keyed as the program keys them; null when
  /// the program failed.
  Future<Map<String, Map<String, dynamic>>?> summarizeClaims(
    String programKey, {
    required String holder,
    String edition = '',
    required List<Map<String, dynamic>> slots,
  }) async {
    final host = this.host;
    if (host == null) return null;
    final method = Hooks.chasingSummarizeClaims.method;
    try {
      final result = await host.invoke(
        Hooks.chasingSummarizeClaims,
        key: programKey,
        args: {'holder': holder, if (edition.isNotEmpty) 'edition': edition, 'slots': slots},
        timeout: const Duration(seconds: 10),
      );
      if (result is! Map) throw FormatException('summarizeClaims answered ${result.runtimeType}, not a map of tallies');
      ErrorReportingService.recordSuccess(_failureKey(programKey, method));
      return {
        for (final MapEntry(:key, :value) in result.entries)
          if (key is String && value is Map) key: value.cast<String, dynamic>(),
      };
    } catch (e, stackTrace) {
      _reportFailure(programKey, method, e, stackTrace);
      return null;
    }
  }

  /// What the file [name], read as [text], claims under [programKey]'s
  /// [importer], for [station] — the file may not say whose it is. Null
  /// when the program failed.
  Future<ImportedClaims?> importClaims(
    String programKey, {
    required String importer,
    required String name,
    required String text,
    required Map<String, dynamic> station,
  }) async {
    final host = this.host;
    if (host == null) return null;
    final method = Hooks.chasingImportClaims.method;
    try {
      final result = await host.invoke(
        Hooks.chasingImportClaims,
        key: programKey,
        args: {
          'importer': importer,
          'file': {'name': name, 'text': text},
          'station': station,
        },
        timeout: kImportClaimsTimeout,
      );
      if (result is! Map || result['claims'] is! List) throw FormatException('importClaims answered ${result.runtimeType}, not {claims}');
      final parsed = [for (final item in result['claims'] as List) ImportedClaim.tryParse(item)];
      final malformed = parsed.where((claim) => claim == null).length;
      final skipped = result['skipped'];
      // Optional, but one that is not a count is a defect like a malformed
      // claim: read as none, the operator is told the file read cleanly.
      final badSkipped = skipped != null && skipped is! num;
      if (malformed > 0 || badSkipped) {
        _reportFailure(
          programKey,
          method,
          FormatException([if (malformed > 0) '$malformed malformed claims', if (badSkipped) 'skipped is ${skipped.runtimeType}, not a count'].join('; ')),
          StackTrace.current,
        );
      } else {
        ErrorReportingService.recordSuccess(_failureKey(programKey, method));
      }
      return (claims: parsed.nonNulls.toList(), skipped: (skipped is num ? skipped.toInt() : 0) + malformed);
    } catch (e, stackTrace) {
      _reportFailure(programKey, method, e, stackTrace);
      return null;
    }
  }
}

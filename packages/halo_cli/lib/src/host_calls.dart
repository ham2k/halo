// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the CLI answers when an extension asks the host something.
//
// The method names and result shapes are ExtensionService's — an extension
// cannot tell which host it is talking to, and must not have to. Where a
// method has no meaning outside the app, it degrades to a stated no-op rather
// than throwing: a hook that shows a status-bar message on its way to
// returning data still has to return the data.
//
// `fetch`, `secret`, `kvGet` and `kvSet` never arrive here — ExtensionHost
// answers those itself.

import 'dart:convert';
import 'dart:io';

import 'package:halo_core/halo_core.dart';

import 'bundles.dart';
import 'config.dart';
import 'lookup_store.dart';
import 'runtime.dart' show cliVersion;

/// The log data one invocation was given: the `--op` operation and its
/// `--qsos`, which back the `getOperation`/`getQsos` context reads. Empty by
/// default — a CLI has no open log, and a hook asking for one gets the same
/// "no log access" answer the app gives before a log is loaded.
class LogContext {
  final Map<String, Object?>? operation;
  final List<Map<String, Object?>>? qsos;
  final List<Map<String, Object?>> spots;

  const LogContext({this.operation, this.qsos, this.spots = const []});

  static const empty = LogContext();

  /// Resolves what the invocation was given: a whole log from `--qson`, its
  /// halves from `--op`/`--qsos`, or a mix.
  ///
  /// A QSON file is `{operation: {…}, qsos: […]}` — the payload shape every
  /// coarse hook already takes (ExtensionService's `qsonPayloadFor`) and what
  /// PoLo writes when it exports one, so a real exported log works unedited.
  ///
  /// `--op`/`--qsos` OVERRIDE the file's halves rather than merging with
  /// them: replaying a real log against a different operation ("what would
  /// these QSOs export as, activating a different park?") is the reason to
  /// pass both, and a merge would leave you guessing which operation the
  /// answer used.
  ///
  /// **A QSON is a whole log, so its QSOs default to `[]`, not null.** The
  /// distinction is the one `HookContext.getQsos` draws and hooks branch on:
  /// null is "this host has no log access", `[]` is "the operation is real
  /// and has no QSOs yet". Handing over a QSON file IS granting log access,
  /// and a file that lists no contacts is describing an empty log, not a
  /// missing one. `--op` alone keeps null — an operation is not a claim to
  /// have supplied the log's contents.
  factory LogContext.resolve({
    Map<String, Object?>? qson,
    Map<String, Object?>? operation,
    List<Map<String, Object?>>? qsos,
    List<Map<String, Object?>> spots = const [],
  }) {
    if (qson != null && !qson.containsKey('operation') && !qson.containsKey('qsos')) {
      // Naming both keys matters: the likely mistakes are handing it a bare
      // operation or a bare QSO array, and neither says so on its own.
      throw QsonShapeError('--qson: expected an object with `operation` and/or `qsos` — '
          'a QSON file as PoLo exports it. Got keys: ${qson.keys.take(6).join(', ')}');
    }
    return LogContext(
      operation: operation ?? _mapAt(qson, 'operation'),
      qsos: qsos ?? _listAt(qson, 'qsos') ?? (qson != null ? const [] : null),
      spots: spots,
    );
  }

  static Map<String, Object?>? _mapAt(Map<String, Object?>? source, String key) {
    final value = source?[key];
    if (value == null) return null;
    if (value is! Map) throw QsonShapeError('--qson: `$key` must be an object, got ${value.runtimeType}');
    return value.cast<String, Object?>();
  }

  static List<Map<String, Object?>>? _listAt(Map<String, Object?>? source, String key) {
    final value = source?[key];
    if (value == null) return null;
    if (value is! List) throw QsonShapeError('--qson: `$key` must be an array, got ${value.runtimeType}');
    return [
      for (final entry in value)
        if (entry is Map) entry.cast<String, Object?>() else throw QsonShapeError('--qson: `$key` must hold objects'),
    ];
  }
}

/// A `--qson` payload that isn't one. Separate from the JSON parse errors in
/// json_args.dart: the file parsed fine, it just isn't a log.
class QsonShapeError implements Exception {
  final String message;
  QsonShapeError(this.message);

  @override
  String toString() => message;
}

/// Answers host calls for one CLI invocation.
class CliHostCalls {
  final CliConfig config;
  final BundleIndex index;
  final LookupStore? lookups;
  final LogContext log;

  /// Where `getLocation` answers from — `--location lat,lon`, since a CLI has
  /// no GPS. Null means "no fix", which is a normal answer the extensions
  /// already handle (permission denied on a device looks the same).
  final ({double lat, double lon})? location;

  /// Extension keys that declared `requiresLocation`, resolved from the
  /// manifests — the same capability gate the app applies, kept because an
  /// extension that quietly gains location access in the CLI would be a real
  /// difference in what the code under test is allowed to do.
  final Set<String> locationAllowlist;

  /// Whether to narrate host calls on stderr (`--verbose`). Off by default:
  /// stdout is JSON somebody is piping into jq.
  final bool verbose;

  CliHostCalls({
    required this.config,
    required this.index,
    this.lookups,
    this.log = LogContext.empty,
    this.location,
    this.locationAllowlist = const {},
    this.verbose = false,
  });

  Future<dynamic> call(String method, Map<String, dynamic> params) async {
    if (verbose) stderr.writeln('[host] $method ${_briefly(params)}');
    switch (method) {
      case 'getSettings':
        return {...config.settings, 'extensions': config.settingsGroups};

      case 'setSettings':
        final ns = params['ns'] as String?;
        final values = params['values'];
        if (ns == null || ns.isEmpty || values is! Map) {
          stderr.writeln('halo-ext: setSettings without ns or values — ignored');
          return null;
        }
        config.setExtensionSettings(ns, values.cast<String, Object?>());
        return null;

      case 'getAccount':
        return config.accountFor(params['kvKey'] as String);

      case 'setAccountSession':
        config.setAccountSession(
          params['kvKey'] as String,
          (params['session'] as Map).cast<String, Object?>(),
        );
        return null;

      case 'translate':
        // The app's own localized strings (strings.g.dart), which this
        // process does not have. Null is the honest answer and the one the
        // SDK already handles — an extension localizing its OWN strings uses
        // createTranslator and never comes here.
        return null;
      case 'translateAll':
        return {for (final key in (params['keys'] as List).cast<String>()) key: null};

      case 'getOperation':
        final operation = log.operation;
        if (operation == null) return null;
        final uuid = params['uuid'] as String;
        // The CLI holds exactly one operation, so a request naming a
        // DIFFERENT one is a miss rather than a silent substitution.
        //
        // An operation supplied without a uuid of its own answers to any —
        // hand-written `--op` JSON rarely carries one, and refusing every
        // request would make `ctx.getOperation` useless for exactly the
        // input people type. It is the same operation either way; what is
        // ruled out is answering as one the operator did NOT supply.
        final ours = operation['uuid'];
        if (ours != null && ours != uuid) return null;
        return {...operation, 'uuid': uuid};

      case 'getQsos':
        // Null, not [] — "no log access" is distinct from "an operation with
        // no QSOs yet" (HookContext.getQsos), and hooks branch on it.
        if (log.qsos == null) return null;
        final operationUuid = params['operationUuid'] as String;
        // Same uuid rule as getOperation above.
        final ours = log.operation?['uuid'];
        if (ours != null && ours != operationUuid) return null;
        // Soft-deleted QSOs are not in the log the app hands over, and
        // `asQsonBool` reads `deleted` the way the app does.
        return [
          for (final qso in log.qsos!)
            if (!asQsonBool(qso['deleted'])) qso,
        ];

      case 'getSpotsForCall':
        final call = (params['call'] as String?)?.toUpperCase();
        if (call == null) return const <Map<String, Object?>>[];
        final maxAge = params['maxAgeMinutes'];
        final cutoff = nowMillis() -
            (maxAge is num ? maxAge.toInt() : 30) * Duration.millisecondsPerMinute;
        return [
          for (final spot in log.spots)
            if (_spotCall(spot) == call && _spotMillis(spot) >= cutoff) spot,
        ];

      case 'getHistoryForCall':
        // Backs `call-history`'s `ctx.getHistoryForCall`. The app answers
        // across every operation; the CLI only ever has the one log handed
        // to it via `--qson`/`--qsos`, so that's what this filters — same
        // "no log access" vs "no match" distinction as `getQsos` above.
        // Parsed before any early return, so a malformed option rejects
        // even when the invocation was given no log.
        final filter = HistoryFilter.fromParams(params);
        if (log.qsos == null) return const <Map<String, Object?>>[];
        // trim(), not just toUpperCase() — matches historyForCall's own
        // normalization (qsos_repository.dart); the sole caller today already
        // trims first, but this shouldn't depend on that.
        final historyCall = (params['call'] as String?)?.trim().toUpperCase();
        if (historyCall == null) return const <Map<String, Object?>>[];
        final operationUuid = log.operation?['uuid'] as String?;
        final matches = [
          for (final qso in log.qsos!)
            // `band != 'event'` mirrors `Qso.isEvent`/`historyForCall`'s own
            // exclusion — an event marker is a timeline annotation, not a
            // contact, and must not stand in as someone's "most recent QSO".
            // `asQsonBool` is the app's reading of `deleted`, so every client's
            // spelling of it drops the QSO here as it does there.
            if (qso['band'] != 'event' &&
                !asQsonBool(qso['deleted']) &&
                ((qso['their'] as Map?)?['call'] as String?)?.toUpperCase() == historyCall &&
                filter.matches(qso, operationUuid: operationUuid))
              qso,
        ];
        matches.sort((a, b) => _startAtMillis(b).compareTo(_startAtMillis(a)));
        return matches.take(filter.limit).toList();

      case 'dbLookupSelectOne':
        return await lookups?.selectOne(params['category'] as String, params['key'] as String);
      case 'dbLookupSelectAll':
        return await lookups?.selectAll(
              params['category'] as String,
              params['query'] as String,
              activeOnly: params['activeOnly'] as bool? ?? false,
            ) ??
            const [];
      case 'dbLookupSelectByLocation':
        return await lookups?.selectByLocation(
              params['category'] as String,
              (params['lat'] as num).toDouble(),
              (params['lon'] as num).toDouble(),
              (params['delta'] as num).toDouble(),
              activeOnly: params['activeOnly'] as bool? ?? false,
            ) ??
            const [];

      case 'getLocation':
        final extensionKey = params['extensionKey'] as String?;
        if (extensionKey == null || !locationAllowlist.contains(extensionKey)) {
          throw HostCallRefused(
            "getLocation blocked: extension '${extensionKey ?? 'unknown'}' does not declare requiresLocation",
          );
        }
        final fix = location;
        return fix == null ? null : {'latitude': fix.lat, 'longitude': fix.lon};

      case 'getVersionInfo':
        return {
          'platform': Platform.operatingSystem,
          'edition': config.settings['edition'] ?? 'dev',
          'version': cliVersion(index),
          'versionName': 'halo-ext',
          // Null for the same reason the app nulls it on Dev: naming a build
          // that isn't running is worse than naming none.
          'buildNumber': null,
          'gitSha': null,
        };

      // Everything below wants a user looking at a screen. Reported on
      // stderr so a hook's side effects are still observable, then answered
      // the way an absent/dismissed UI answers.
      case 'showMessage':
        stderr.writeln('[extension message] ${params['title'] ?? ''} ${params['text'] ?? ''}'.trim());
        return null;
      case 'statusBarSetMessage':
      case 'statusBarSetProgress':
      case 'statusBarShowNotice':
        if (verbose) stderr.writeln('[status] ${params['title'] ?? ''} ${params['text'] ?? ''}'.trim());
        return null;
      case 'statusBarClear':
      case 'statusBarDismissNotice':
        return null;
      case 'showForm':
        // Null is "the user cancelled" — the one answer that cannot be
        // mistaken for a form somebody filled in.
        stderr.writeln('halo-ext: extension asked for the form "${params['formId']}"; no UI here, answering cancelled');
        return null;

      default:
        throw HostCallRefused('host call $method is not implemented by halo-ext');
    }
  }

  static String _spotCall(Map<String, Object?> spot) =>
      ((spot['their'] as Map?)?['call'] as String? ?? '').toUpperCase();

  static int _spotMillis(Map<String, Object?> spot) {
    final value = (spot['spot'] as Map?)?['timeInMillis'];
    return value is num ? value.toInt() : 0;
  }

  static int _startAtMillis(Map<String, Object?> qso) {
    final value = qso['startAtMillis'];
    return value is num ? value.toInt() : 0;
  }

  static String _briefly(Map<String, dynamic> params) {
    final text = jsonEncode(params);
    return text.length <= 160 ? text : '${text.substring(0, 160)}…';
  }
}

/// A host call the CLI will not or cannot answer.
///
/// Thrown rather than returned as null: the kernel turns a rejected host call
/// into a rejected promise, so the extension takes its ERROR path — which is
/// the truthful one. A null would read as "asked and got nothing", and an
/// extension would cache that as an answer.
class HostCallRefused implements Exception {
  final String message;
  HostCallRefused(this.message);

  @override
  String toString() => message;
}

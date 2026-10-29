// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The options an extension passes to `ctx.getSpots` — one parse and one set
// of explicit narrowings for both hosts. The app applies them on top of its
// spots board (app/lib/services/spot_board.dart); the CLI, which holds the
// spots it was handed as a list, applies them alone.

import '../app_clock.dart';
import '../repo/history_filter.dart';

/// Which spots a `getSpots` call starts from, before its explicit options
/// narrow them.
enum SpotsBase {
  /// What the operator's own Spots Panel filters admit: their sources,
  /// bands, mode, age and continents, the "auto" band and mode following the
  /// radio — merged and ordered as that panel shows them.
  user,

  /// Every spot the host holds, one per source report, newest first.
  all,
}

class SpotsQuery {
  final SpotsBase base;

  /// Inclusive: a spot exactly this old is kept. Measured on the spot's own
  /// `spot.timeInMillis`, like `getSpotsForCall`.
  final num? maxAgeMinutes;

  /// Lowercase, as bands are spelled (`20m`).
  final Set<String> bands;
  final HistoryModeMatch? modes;

  /// Spot-source hook keys, matched against a spot's `hookKey`.
  final Set<String> sources;

  /// False only when the caller asked for raw spots. Whether there is an
  /// operation to judge them against is [operationUuid]'s to say.
  final bool annotate;
  final String? operationUuid;

  const SpotsQuery({
    this.base = SpotsBase.user,
    this.maxAgeMinutes,
    this.bands = const {},
    this.modes,
    this.sources = const {},
    this.annotate = true,
    this.operationUuid,
  });

  /// Parses the host-call params. A present but malformed value throws
  /// [FormatException], which the host turns into a rejected promise, and so
  /// does an unknown key or an include option given no values — as with
  /// [HistoryFilter.fromParams], answering a narrower question with the
  /// whole board would be trusted by the caller. Null reads as absent: the
  /// kernel sends the keys it was not given as `undefined`.
  factory SpotsQuery.fromParams(Map<String, dynamic> params) {
    final unknown = params.keys.where((key) => !_knownParams.contains(key));
    if (unknown.isNotEmpty) throw FormatException('getSpots: unknown option `${unknown.first}`');

    final base = switch (params['filter']) {
      null || 'user' => SpotsBase.user,
      'all' => SpotsBase.all,
      final other => throw FormatException("getSpots: `filter` must be 'user' or 'all', not `$other`"),
    };
    final maxAge = params['maxAgeMinutes'];
    if (maxAge != null && (maxAge is! num || !maxAge.isFinite || maxAge < 0)) {
      throw const FormatException('getSpots: `maxAgeMinutes` must be a finite, non-negative number');
    }
    final annotate = params['annotate'];
    if (annotate != null && annotate is! bool) throw const FormatException('getSpots: `annotate` must be a boolean');
    final operationUuid = params['operationUuid'];
    if (operationUuid != null && operationUuid is! String) throw const FormatException('getSpots: `operationUuid` must be a string');

    final modes = _strings(params, 'mode');
    return SpotsQuery(
      base: base,
      maxAgeMinutes: maxAge as num?,
      bands: {...?_strings(params, 'band')?.map((b) => b.trim().toLowerCase())},
      modes: modes == null ? null : HistoryModeMatch.parse(modes),
      sources: {...?_strings(params, 'source')},
      annotate: annotate as bool? ?? true,
      operationUuid: operationUuid is String && operationUuid.isNotEmpty ? operationUuid : null,
    );
  }

  /// `extensionKey` is no option: the kernel names the caller on every host call it makes, and
  /// refusing it refuses every call.
  static const _knownParams = {'filter', 'maxAgeMinutes', 'band', 'mode', 'source', 'annotate', 'operationUuid', 'extensionKey'};

  static List<String>? _strings(Map<String, dynamic> params, String key) {
    final value = params[key];
    if (value == null) return null;
    final list = value is List ? value : [value];
    if (list.isEmpty || list.any((v) => v is! String || v.trim().isEmpty)) {
      throw FormatException('getSpots: `$key` must be a non-empty string or list of them');
    }
    return list.cast<String>();
  }

  /// The [spots] that pass the explicit narrowings — never the operator's
  /// filters, which are the app's alone to apply. A spot missing the field an
  /// option tests fails it: a band-less spot is not on 20m. One clock read
  /// for the whole list, so every spot is held to the same cutoff.
  List<T> narrow<T extends Map<String, dynamic>>(Iterable<T> spots) {
    final cutoff = maxAgeMinutes == null ? null : nowMillis() - maxAgeMinutes! * Duration.millisecondsPerMinute;
    return [
      for (final spot in spots)
        if (_passes(spot, cutoff)) spot,
    ];
  }

  bool _passes(Map<String, dynamic> spot, num? cutoff) {
    if (cutoff != null) {
      final postedAt = _num(_map(spot['spot'])?['timeInMillis']);
      if (postedAt == null || postedAt < cutoff) return false;
    }
    if (bands.isNotEmpty && !bands.contains(_string(spot['band'])?.toLowerCase())) return false;
    if (modes != null && !modes!.matches(_string(spot['mode']))) return false;
    if (sources.isNotEmpty && !sources.contains(_string(spot['hookKey']))) return false;
    return true;
  }
}

// Spots cross the bridge from JS untyped, so every read is a probe.
Map<String, dynamic>? _map(dynamic value) => value is Map ? value.cast<String, dynamic>() : null;
String? _string(dynamic value) => value is String ? value : null;
num? _num(dynamic value) => value is num ? value : null;

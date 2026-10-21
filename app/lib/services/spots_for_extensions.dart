// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The app half of `ctx.getSpots`: the spots board as an extension asks for
// it — the operator's own filtered view or everything held, narrowed by the
// caller's options, and judged against the open operation the way the Spots
// Panel strikes and accents its rows. Every rule it applies is the panel's
// own, from spot_board.dart, and every lookup and verdict it reads is the one
// SpotBoardService already worked out for that panel.
//
// It only reads. A call can arrive from inside a panel render, which has a
// few seconds to answer, or from inside a lookup, whose pipeline a lookup of
// its own would re-enter; neither may wait on a scorer pass or a fan-out of
// lookups.

import 'package:halo_core/halo_core.dart';

import 'halo_services.dart';
import 'spot_board.dart';
import 'spot_board_service.dart';

class ExtensionSpotsReader {
  ExtensionSpotsReader(this._services);

  final HaLoServices _services;

  /// Answers a `getSpots` host call. Reads the caches only — like
  /// `getSpotsForCall`, it never makes a spot source fetch.
  Future<List<Map<String, dynamic>>> read(Map<String, dynamic> params) async {
    final query = SpotsQuery.fromParams(params);
    final board = _services.spotBoard;
    // Narrowed by source BEFORE the merge: a merged spot keeps only one of
    // its reports' `hookKey`, so filtering after it would drop a station two
    // sources spotted from the answer for either.
    final bySource = {
      for (final entry in _services.spots.spotsBySource.entries)
        if (query.sources.isEmpty || query.sources.contains(entry.key)) entry.key: entry.value,
    };

    final List<Map<String, dynamic>> spots;
    if (query.base == SpotsBase.user) {
      final settings = _services.settings;
      final filters = SpotBoardFilters.fromSettings(settings);
      final vfo = _services.radio.vfoA;
      final callInfo = board.callInfo;
      spots = filterSpotBoard(
        mergedSpotBoard(bySource, filters.disabledSources, entityOf: (call) => callInfo[call]?.entityPrefix),
        filters,
        vfoBand: vfo.band,
        vfoMode: vfo.mode,
        enabledBands: settings.enabledBands.toSet(),
        continentOf: (call) => callInfo[call]?.continent,
      ).filtered;
    } else {
      spots = sortSpots([for (final list in bySource.values) ...list], 'time');
    }

    final narrowed = query.narrow(spots);
    final operation = board.operation;
    // Unannotated rather than "nothing worked" until the board has judged
    // this operation: a lookup reading once has no repaint to correct it.
    final scores = query.operationUuid == null ? null : board.scoresFor(query.operationUuid!);
    if (!query.annotate || scores == null || operation == null) return narrowed;
    return _annotate(narrowed, operation, scores);
  }

  /// Copies of [spots], each with `annotations` — `worked`, `isSelf` and
  /// `notices`, as [spotDisplayFlags] reads them for the Spots Panel's rows —
  /// from [scores], the verdicts the board holds for [operation]. The cache
  /// is shared, so the spots themselves are never written.
  List<Map<String, dynamic>> _annotate(List<Map<String, dynamic>> spots, Operation operation, Map<String, SpotScore> scores) {
    final ourBaseCalls = {
      for (final call in operation.stationCalls)
        if (baseCallOf(call) case final base when base.isNotEmpty) base,
    };
    return [
      for (final spot in spots)
        if (spotDisplayFlags(spot, scores: scores, ourBaseCalls: ourBaseCalls) case final flags)
          {
            ...spot,
            'annotations': {'worked': flags.worked, 'isSelf': flags.isSelf, 'notices': flags.notices.toList()..sort()},
          },
    ];
  }
}

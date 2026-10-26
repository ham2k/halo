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
import 'package:halo_widgets/halo_widgets.dart';

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
    // The board still holds what an earlier operation fetched; an operation
    // without assistance shows its panels none of it.
    if (board.operation?.assistance == false) return const [];
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
    if (!query.annotate) return narrowed;
    final operation = board.operation;
    // Unannotated rather than "nothing worked" until the board has judged
    // this operation: a lookup reading once has no repaint to correct it.
    final scores = query.operationUuid == null ? null : board.scoresFor(query.operationUuid!);
    if (scores == null || operation == null) return _display(narrowed);
    return _display(narrowed, judged: (operation: operation, scores: scores, scoreIcons: board.scoreIconsFor(query.operationUuid!) ?? const {}));
  }

  /// Copies of [spots], each with `display` — what the Spots Panel's row
  /// shows beside the call — and, where [judged] holds the board's verdicts
  /// for the operation, `annotations`. The cache is shared, so the spots
  /// themselves are never written.
  ///
  /// `display.icons` is every icon the row may show, as [spotIcons] reads
  /// them, each marked with what put it there (`scoring`, `chasing` or
  /// `reference`); the panel draws the few [spotIconsWithin] picks. `icon`
  /// and `iconColor` are the first reference's, and `emoji` the first
  /// operator with a note's.
  ///
  /// `annotations` is `worked`, `isSelf` and `notices`, as [spotDisplayFlags]
  /// reads them for the Spots Panel's rows.
  List<Map<String, dynamic>> _display(
    List<Map<String, dynamic>> spots, {
    ({Operation operation, Map<String, SpotScore> scores, Map<String, List<SpotIcon>> scoreIcons})? judged,
  }) {
    final board = _services.spotBoard;
    final controls = board.activityControlsForDisplay(), callInfo = board.callInfo;
    final ourBaseCalls = {
      for (final call in judged?.operation.stationCalls ?? const <String>[])
        if (baseCallOf(call) case final base when base.isNotEmpty) base,
    };
    String? hex(String? declared) => switch (resolveExtensionColor(declared)) {
      final color? => '#${(color.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0')}',
      null => null,
    };
    Map<String, dynamic> entry(SpotIcon icon, String kind) => {'icon': icon.icon, 'iconColor': ?hex(icon.color), 'kind': kind};

    Map<String, dynamic> displayed(Map<String, dynamic> spot) {
      final flags = judged == null ? null : spotDisplayFlags(spot, scores: judged.scores, ourBaseCalls: ourBaseCalls);
      // The first is read before the kinds give up names they share: a
      // scorer's icon can be the one a reference would show.
      final refIcons = spotRefIcons(spot, controls);
      final first = refIcons.first;
      final icons = spotIcons(
        spot,
        controls: controls,
        scoreIcons: judged?.scoreIcons ?? const {},
        notices: flags?.notices ?? const {},
        judgements: judged == null ? const {} : board.judgements,
        programs: board.chase?.programs ?? const {},
        refIcons: refIcons,
      );
      return {
        ...spot,
        'display': {
          'icon': first.icon,
          'iconColor': ?hex(first.color),
          'icons': [
            for (final icon in icons.scores) entry(icon, 'scoring'),
            for (final icon in icons.judgements) entry(icon, 'chasing'),
            for (final icon in icons.refs) entry(icon, 'reference'),
          ],
          'emoji': ?spotOperatorCalls(spot).map((call) => callInfo[call]?.emoji).nonNulls.firstOrNull,
        },
        if (flags != null) 'annotations': {'worked': flags.worked, 'isSelf': flags.isSelf, 'notices': flags.notices.toList()..sort()},
      };
    }

    return [for (final spot in spots) displayed(spot)];
  }
}

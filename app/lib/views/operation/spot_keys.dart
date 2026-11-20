// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The spot keys — the `spots.*` commands, the nearest spot or new
// multiplier up or down the band — as the Operation and Chasing views hear
// them (docs/design/keyboard-shortcuts.md).

import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:halo_core/halo_core.dart' show Operation, baseCallOf;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../services/halo_services.dart';
import '../../services/spot_board.dart';
import '../../services/spot_board_service.dart' show SpotScore;
import '../../services/spots_service.dart';
import '../../services/status_bar_service.dart';
import 'spots_panel.dart' show suggestedQsoFromSpot;

const _commands = [
  (id: spotsNextCommandId, higher: true, mult: false),
  (id: spotsPreviousCommandId, higher: false, mult: false),
  (id: spotsNextMultCommandId, higher: true, mult: true),
  (id: spotsPreviousMultCommandId, higher: false, mult: true),
];

final _arrows = {LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowRight};

/// How far from a spot the VFO can sit and still be on it: past the widest
/// zero-beat offset a suggestion takes (75 Hz), short of the 100 Hz the
/// clusters report frequencies in.
const spotKeysOnSpotKHz = 0.08;

/// Where the next press steps on from: the station last suggested on a VFO
/// — by a press or a tap on its spot — and, for a press, where the VFO stood
/// when it was made.
typedef SpotKeysLanding = ({double freq, String key, double? from});

/// The spot keys for one view that logs. Holds the station last suggested,
/// so the next press steps on from it in the list's order: two stations
/// spotted on one frequency are both reached, one already struck by logging
/// it included, and a zero-beat offset that left the VFO a few Hz below the
/// spot does not land the next press up the band on the same one.
class SpotKeys {
  final _landed = <String, SpotKeysLanding>{};

  /// Every suggestion the view makes, as it is made — a tap on a spot as
  /// much as a press here — so the next press steps on from the station
  /// suggested on VFO [vfo]. One with no call or frequency is no station.
  void suggested(Map<String, dynamic> qso, {required String vfo}) {
    final freq = asSpotNum(qso['freq'])?.toDouble();
    if (freq == null || (asSpotString(asSpotMap(qso['their'])?['call']) ?? '').isEmpty) return;
    final key = spotKeysKey(qso);
    // A press records where the VFO stood first; its own suggestion keeps it.
    if (_landed[vfo]?.key == key) return;
    _landed[vfo] = (freq: freq, key: key, from: null);
  }

  /// A spot key while the view is the front-most route: suggests the
  /// nearest spot up or down the band from VFO [vfo] through [suggest], as a
  /// tap on it in the Spots Panel would. True when [event] was one.
  ///
  /// The spots are the ones the operator's Spots Panel filters show on the
  /// VFO's band, less an assistant's hidden ones, the operator's own and the
  /// ones already worked or worth nothing to the operation; a multiplier is
  /// one a scorer marks `newMult` for [operation].
  ///
  /// Stands aside as the VFO keys do ([onVfoKey]): while a logged contact is
  /// loaded, where ⌘↑/⌘↓ go to the ends of the QSO list; in any text field
  /// but the main logging fields; and on a control that steps on the
  /// arrows. Taken even with no spot to go to, saying so on the status bar.
  bool onKey(
    KeyEvent event, {
    required HaLoServices services,
    required String vfo,
    required bool qsoLoaded,
    required Operation operation,
    required void Function(Map<String, dynamic> qso) suggest,
  }) {
    final bindings = keyBindings.value;
    for (final command in _commands) {
      if (bindings.claim(command.id, event) == null) continue;
      if (qsoLoaded) return false;
      if (_arrows.contains(event.logicalKey) && (focusInFreeText() || ArrowKeysOwner.hasFocus())) return false;
      takeKeyEvent(event);
      final tuned = services.radio.vfo(vfo);
      final spots = spotKeysCandidates(services, operation, vfo: vfo, mult: command.mult);
      final spot = spotKeysStep(spots, freqKHz: tuned.freq, higher: command.higher, landed: _landed[vfo]);
      if (spot == null) {
        // Said once a press: a held key's repeats would restate it each time.
        if (event is KeyDownEvent) {
          final o = t.operation;
          services.statusBar.setMessage(
            key: 'spot-keys:none',
            icon: 'keyboard',
            text: switch ((command.mult, command.higher)) {
              (false, true) => o.spotKeysNoneUp,
              (false, false) => o.spotKeysNoneDown,
              (true, true) => o.spotKeysNoMultUp,
              (true, false) => o.spotKeysNoMultDown,
            },
            dismissAfter: StatusBarService.completedDismissDelay,
          );
        }
        return true;
      }
      // Where the VFO stood: the suggestion tunes it a frame later, and a
      // repeat arriving first must step on rather than find this spot again.
      _landed[vfo] = (freq: asSpotNum(spot['freq'])!.toDouble(), key: spotKeysKey(spot), from: tuned.freq);
      suggest(suggestedQsoFromSpot(spot));
      return true;
    }
    return false;
  }
}

/// The spots a spot key steps through on VFO [vfo]'s band, in no order
/// ([spotKeysPick]).
List<Map<String, dynamic>> spotKeysCandidates(HaLoServices services, Operation operation, {required String vfo, required bool mult}) {
  final board = services.spotBoard;
  // An operation without assistance shows none of what the board holds.
  if (board.operation?.assistance == false) return const [];
  final tuned = services.radio.vfo(vfo);
  final band = tuned.band;
  if (band == null) return const [];
  final marks = services.extensions.spotMarks;
  return spotKeysPick(
    [
      for (final spot in board.filteredByOperator(vfo: tuned))
        if (marks.isEmpty || (marks.markingFor(spotIdsOf(spot))?.hiddenBy.isEmpty ?? true)) spot,
    ],
    band: band,
    scores: board.scoresFor(operation.uuid) ?? const {},
    values: board.scoreValuesFor(operation.uuid) ?? const {},
    ourBaseCalls: {
      for (final call in operation.stationCalls)
        if (baseCallOf(call) case final base when base.isNotEmpty) base,
    },
    mult: mult,
  );
}

/// Of [spots], the ones on [band] worth a press: not the operator's own,
/// which suggest no one to work; not one [scores] calls worked, as the Spots
/// Panel strikes it ([spotDisplayFlags]); and not one every operator on which
/// is worth 0 points by [values] — out of the contest's category, band, mode
/// or hours — unless it is a new multiplier. With [mult], only those a scorer marks `newMult`. Before the
/// board has judged the operation both are empty, and every spot counts.
List<Map<String, dynamic>> spotKeysPick(
  List<Map<String, dynamic>> spots, {
  required String band,
  required Map<String, SpotScore> scores,
  required Map<String, num> values,
  required Set<String> ourBaseCalls,
  required bool mult,
}) => [
  for (final spot in spots)
    if (asSpotString(spot['band']) == band && !spotIsSelfOnly(spot, ourBaseCalls: ourBaseCalls))
      if (spotDisplayFlags(spot, scores: scores, ourBaseCalls: ourBaseCalls) case final flags
          when !flags.worked &&
              (!mult || flags.notices.contains('newMult')) &&
              // A new multiplier counts whatever its points: in CQ WW a station
              // in our own country is worth none and can still be a new zone.
              (flags.notices.contains('newMult') || !_worthNothing(spot, values)))
        spot,
];

/// Every operator on [spot] valued at 0: as with the worked strike, one
/// operator still worth points keeps the station worth a press.
bool _worthNothing(Map<String, dynamic> spot, Map<String, num> values) {
  final calls = spotOperatorCalls(spot);
  return calls.isNotEmpty && calls.every((call) => values[spotCandidateKey(call, spot)] == 0);
}

/// What a spot is known by from one press to the next: its call on its
/// frequency. Read the same from a spot and from the suggestion made of it,
/// whose frequency is a double where a spot's may be an integer.
String spotKeysKey(Map<String, dynamic> spot) => '${asSpotString(asSpotMap(spot['their'])?['call'])}@${asSpotNum(spot['freq'])?.toDouble()}';

/// The spot one press [higher] or lower goes to among [spots], or null with
/// none that way.
///
/// From [landed], the station last suggested, while the VFO is still on it
/// ([spotKeysOnSpotKHz]) or still where it stood for the press that suggested
/// it: the next in frequency order, then call order among spots on one
/// frequency — whether or not that station is still among [spots], since
/// logging it strikes it. Otherwise the nearest spot clear of the VFO's
/// frequency [freqKHz]: the lowest or highest on the band when the VFO has none.
Map<String, dynamic>? spotKeysStep(List<Map<String, dynamic>> spots, {required double? freqKHz, required bool higher, SpotKeysLanding? landed}) {
  double freqOf(Map<String, dynamic> spot) => asSpotNum(spot['freq'])?.toDouble() ?? 0;
  int order(double freqA, String keyA, double freqB, String keyB) => switch (freqA.compareTo(freqB)) {
    0 => keyA.compareTo(keyB),
    final byFreq => byFreq,
  };
  final sorted = [
    for (final spot in spots)
      if (freqOf(spot) > 0) spot,
  ]..sort((a, b) => order(freqOf(a), spotKeysKey(a), freqOf(b), spotKeysKey(b)));
  if (sorted.isEmpty) return null;
  if (freqKHz == null || freqKHz <= 0) return higher ? sorted.first : sorted.last;
  if (landed != null && ((landed.freq - freqKHz).abs() <= spotKeysOnSpotKHz || landed.from == freqKHz)) {
    int fromLanded(Map<String, dynamic> spot) => order(freqOf(spot), spotKeysKey(spot), landed.freq, landed.key);
    return higher ? sorted.where((spot) => fromLanded(spot) > 0).firstOrNull : sorted.where((spot) => fromLanded(spot) < 0).lastOrNull;
  }
  if (higher) {
    for (final spot in sorted) {
      if (freqOf(spot) > freqKHz + spotKeysOnSpotKHz) return spot;
    }
  } else {
    for (final spot in sorted.reversed) {
      if (freqOf(spot) < freqKHz - spotKeysOnSpotKHz) return spot;
    }
  }
  return null;
}

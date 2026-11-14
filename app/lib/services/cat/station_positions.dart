// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Operating positions and the logging sets bound to them
// (docs/design/station-model.md § 5 and § 6), as they are stored. Pure data:
// no I/O.

import '../peer/peer_station_radios.dart';
import 'main_vfo.dart';

/// The logging set every station has.
const kSetA = 'A';

/// SO2R's second logging set.
const kSetB = 'B';

/// One operating position: a radio, and what the operator picked to go with
/// it.
///
/// A radio has one position, made the first time something is picked for
/// it, so the antenna and key picked for a rig come back whenever that rig
/// is picked again. [radio] is null for the position of "no radio", which an
/// operator can sit in and pick a key for.
class StationPosition {
  final String id;
  MainVfo? radio;

  /// Kind → a node id, or null. Three states, not two: an ABSENT kind is
  /// never decided, and the service answers it with a default (a radio that
  /// keys is its own key); a kind stored as null is the operator having
  /// answered None, which a default never overrides.
  final Map<String, String?> slots;

  StationPosition(this.id, this.radio, [Map<String, String?>? slots]) : slots = slots ?? {};
}

/// Every position the station has, and which one each logging set logs from.
class StationPositions {
  final Map<String, StationPosition> _byId = {};

  /// Set name → position id. Set A with no position is the "no radio" one.
  final Map<String, String> _sets = {};

  final String Function() _newId;

  StationPositions(this._newId);

  Iterable<StationPosition> get all => _byId.values;

  /// [radio]'s position, or null when nothing was ever picked for it.
  StationPosition? positionOf(MainVfo? radio) {
    for (final position in _byId.values) {
      if (position.radio == radio) return position;
    }
    return null;
  }

  /// [radio]'s position, made now when it has none.
  StationPosition positionFor(MainVfo? radio) {
    if (positionOf(radio) case final existing?) return existing;
    final made = StationPosition(_newId(), radio);
    _byId[made.id] = made;
    return made;
  }

  StationPosition? positionOfSet(String set) => switch (_sets[set]) {
    final id? => _byId[id],
    null => null,
  };

  /// The radio [set] logs from: null for none, and for a set with no position.
  MainVfo? radioOf(String set) => positionOfSet(set)?.radio;

  /// Binds [set] to [radio]'s position. Set B with no radio is no set B at
  /// all; set A always has one, the "no radio" position included.
  ///
  /// A [radio] equal to the position's own replaces it: a peer's radio is the
  /// same pick under a new name, and the new name is the one to keep.
  void setRadio(String set, MainVfo? radio) {
    if (radio == null && set != kSetA) {
      _sets.remove(set);
      return;
    }
    final position = positionFor(radio)..radio = radio;
    _sets[set] = position.id;
  }

  /// [radio]'s picks, or null when it has no position.
  Map<String, String?>? slotsOf(MainVfo? radio) => positionOf(radio)?.slots;

  /// [radio]'s picks, its position made now when it has none.
  Map<String, String?> slotsFor(MainVfo? radio) => positionFor(radio).slots;

  /// A removed node, gone from everywhere it was named: its own position,
  /// any set bound to that, and every pick of it. A pick removed this way is
  /// never decided again, not None, so a radio that keys goes back to keying
  /// for itself.
  void forgetNode(String uuid) {
    final own = positionOf(LocalRadio(uuid));
    if (own != null) {
      _byId.remove(own.id);
      _sets.removeWhere((_, id) => id == own.id);
    }
    for (final position in _byId.values) {
      position.slots.removeWhere((_, picked) => picked == uuid);
    }
  }

  /// As stored. A position with nothing picked that no set logs from is
  /// left out: it says nothing a fresh one would not.
  Map<String, dynamic> toJson() => {
    'positions': {
      for (final position in _byId.values)
        if (position.slots.isNotEmpty || _sets.containsValue(position.id)) position.id: {'radio': _radioToJson(position.radio), 'slots': position.slots},
    },
    'sets': _sets,
  };

  /// What [json] stored, keeping only what this station still has: a
  /// position whose radio did not load goes, with its picks, and a pick
  /// naming a node that did not load is dropped (an explicit None is kept).
  /// A set bound to a position that went is unbound, which for set A is "no
  /// radio": never some other radio, since a corrupt record is not the
  /// operator's choice.
  static StationPositions fromJson(Map<String, dynamic> json, {required bool Function(String uuid) hasNode, required String Function() newId}) {
    final loaded = StationPositions(newId);
    final positions = json['positions'];
    if (positions is Map) {
      for (final MapEntry(:key, :value) in positions.entries) {
        if (value is! Map) continue;
        final rawRadio = value['radio'];
        final radio = _radioFromJson(rawRadio);
        if (rawRadio != null && radio == null) continue;
        if (radio case LocalRadio(:final uuid) when !hasNode(uuid)) continue;
        // One position per radio: a second for the same one, which only a
        // hand-edited blob can hold, is dropped.
        if (loaded.positionOf(radio) != null) continue;
        final position = StationPosition('$key', radio);
        final slots = value['slots'];
        if (slots is Map) {
          for (final MapEntry(key: kind, value: picked) in slots.entries) {
            if (picked == null || (picked is String && hasNode(picked))) position.slots['$kind'] = picked as String?;
          }
        }
        loaded._byId[position.id] = position;
      }
    }
    final sets = json['sets'];
    if (sets is Map) {
      for (final MapEntry(:key, :value) in sets.entries) {
        if (value is String && loaded._byId.containsKey(value)) loaded._sets['$key'] = value;
      }
    }
    loaded._dropSetBUnlessItsOwnLocalRadio();
    return loaded;
  }

  /// What a blob written before positions existed (version 3 and older)
  /// said: [radioA] and [radioB] as already read from it, and its
  /// `designated` picks, radio → kind → node, keyed by a node id, a peer's
  /// picker value, or `none`.
  static StationPositions fromLegacy({
    required MainVfo? radioA,
    required String? radioB,
    required Map<String, Map<String, String?>> designated,
    required bool Function(String uuid) hasNode,
    required String Function() newId,
  }) {
    final migrated = StationPositions(newId);
    for (final MapEntry(key: owner, value: picks) in designated.entries) {
      final radio = switch (owner) {
        'none' => null,
        // A peer's picks carry only its ids, as the picker value did. The peer
        // driving vfoA gets its names back from [radioA] just below.
        _ when owner.startsWith('peer:') => switch (peerRadioSelectionFromValue(owner)) {
          final selection? => PeerRadio(selection),
          null => null,
        },
        _ => LocalRadio(owner),
      };
      if (radio == null && owner != 'none') continue;
      if (radio case LocalRadio(:final uuid) when !hasNode(uuid)) continue;
      migrated.slotsFor(radio).addAll(picks);
    }
    migrated.setRadio(kSetA, radioA);
    if (radioB != null && hasNode(radioB)) migrated.setRadio(kSetB, LocalRadio(radioB));
    migrated._dropSetBUnlessItsOwnLocalRadio();
    return migrated;
  }

  /// Set B logs from a radio of this station's own, and never set A's: two
  /// sets tuning one rig would fight over it.
  void _dropSetBUnlessItsOwnLocalRadio() {
    final b = radioOf(kSetB);
    if (positionOfSet(kSetB) != null && (b is! LocalRadio || b == radioOf(kSetA))) _sets.remove(kSetB);
  }

  static Map<String, dynamic>? _radioToJson(MainVfo? radio) => switch (radio) {
    LocalRadio(:final uuid) => {'local': uuid},
    PeerRadio(:final selection) => {'peer': selection.toJson()},
    null => null,
  };

  static MainVfo? _radioFromJson(Object? raw) {
    if (raw is! Map) return null;
    if (raw['local'] case final String uuid when uuid.isNotEmpty) return LocalRadio(uuid);
    if (PeerRadioSelection.from(raw['peer']) case final selection?) return PeerRadio(selection);
    return null;
  }
}

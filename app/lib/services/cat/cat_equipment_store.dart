// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The configured equipment read back from settings. Secret fields live
// in the keychain, managed by cat_credentials.dart.

part of 'cat_service.dart';

extension _EquipmentStore on CatService {
  void _load() {
    final raw = _settings.stationEquipment;
    final nodes = raw['nodes'];
    if (nodes is Map) {
      for (final entry in nodes.entries) {
        final node = EquipmentNode.fromJson('${entry.key}', entry.value);
        // A single corrupt record drops that node, not the whole list.
        if (node != null) _nodes[node.uuid] = node;
      }
    }
    if (raw['forwarded'] case final Map<dynamic, dynamic> forwarded) {
      for (final MapEntry(:key, :value) in forwarded.entries) {
        if (key is String && value is String) _forwarded[key] = value;
      }
    }
    _settleDeviceIds();
    // Everything that names a node by id, read as naming what it is now.
    // Not the nodes' own settings: a K4's connection id is the old id of a
    // Sub configured first, and keeps naming its keychain entry.
    final stored = {
      for (final MapEntry(:key, :value) in raw.entries) key: key == 'nodes' || key == 'forwarded' || _peerKeys.contains(key) ? value : _forwardIds(value),
    };
    final storedVersion = stored['version'];
    if (storedVersion is int && storedVersion >= 4) {
      _positions = StationPositions.fromJson(stored, hasNode: _nodes.containsKey, newId: uuidGenerator.v4);
      // Written for an older build's sake ([_storedNode]); the position
      // says it here.
      for (final node in [..._nodes.values]) {
        if (_isSdr(node) && node.config.containsKey(_legacySdrRadioKey)) {
          _nodes[node.uuid] = node.copyWith(config: {...node.config}..remove(_legacySdrRadioKey));
        }
      }
    } else {
      _positions = _legacyPositions(stored, storedVersion);
      _moveSdrLinks();
    }
    _moveLoggedKeys();
    _moveAudioChoices();
    if (stored['so2rSwitch'] case final String pick when pick == so2rSwitchRadios || _nodes.containsKey(pick)) _so2rSwitch = pick;
    if (stored['gpsSource'] case final String pick when pick == gpsSourceSystem || _nodes.containsKey(pick)) _gpsSource = pick;
  }

  /// A paddle stored as a radio's CW Keying pick, as builds before the
  /// logged key had its own did: it is that radio's logged key
  /// ([kDesignationLoggedKey]), and its CW Keying goes back to its default.
  void _moveLoggedKeys() {
    for (final position in _positions.all) {
      final pick = position.slots[kCategoryKey];
      final node = pick == null ? null : _nodes[pick];
      if (node == null || typeFor(node)?.category != kCategoryKey) continue;
      position.slots.remove(kCategoryKey);
      position.slots[kDesignationLoggedKey] ??= pick;
    }
  }

  /// A blob written before positions existed: which radio drove `vfoA`, SO2R's
  /// Radio B, and the picks made for each radio, read the way the build that
  /// wrote it read them.
  StationPositions _legacyPositions(Map<String, dynamic> stored, Object? storedVersion) {
    // Read, not derived. A stored uuid whose node did not load — a corrupt
    // record, or one written by a newer build — leaves this None rather than
    // silently designating some other radio.
    //
    // There is no equivalent node check for a peer, and there cannot be one:
    // a peer radio's existence is a fact about another device, which this
    // one cannot ask about at load. An absent peer reads as an unavailable
    // selection, not as a corrupt one.
    //
    // Version 2 and older wrote the same thing as two keys, which a
    // hand-edited or newer-build blob could set both of; the local one wins,
    // as the version that stored them decided.
    // Told apart by the VERSION the blob was written under, not by whether
    // the key is there: version 3 writes an explicit null for None, which a
    // shape probe would read as a version 2 blob and answer out of whatever
    // `radio1` a future writer happened to leave behind — resurrecting a
    // pick the operator had cleared. Same rule as `designated` below.
    MainVfo? radioA;
    final storedVfo = stored['mainVfo'];
    if (storedVersion is int && storedVersion >= 3) {
      if (storedVfo is Map) {
        final uuid = storedVfo['radio'];
        if (uuid is String && _nodes.containsKey(uuid)) {
          radioA = LocalRadio(uuid);
        } else if (PeerRadioSelection.from(storedVfo['peer']) case final selection?) {
          radioA = PeerRadio(selection);
        }
      }
    } else {
      final legacyRadio1 = stored['radio1'];
      if (legacyRadio1 is String && _nodes.containsKey(legacyRadio1)) {
        radioA = LocalRadio(legacyRadio1);
      } else if (PeerRadioSelection.from(stored['remoteRadio1']) case final selection?) {
        radioA = PeerRadio(selection);
      }
    }
    final storedRadio2 = stored['radio2'];
    final radioB = storedRadio2 is String ? storedRadio2 : null;
    final picksByRadio = <String, Map<String, String?>>{};
    final designated = stored['designated'];
    if (designated is Map) {
      // Two shapes, told apart by the version the blob was written under
      // rather than by the shape of its values — a probe would have to
      // assume no category value is ever a Map, which is an invariant
      // nothing enforces, and would read a half-migrated blob as whichever
      // branch its first Map happened to select.
      //
      // Version 1 is one flat category → uuid map, and it belongs to
      // whatever was selected when it was written — which is what is being
      // loaded here, a few lines up.
      //
      // A blob with no key entry at all needs no special case either way: an
      // absent category is "never decided", which is exactly what
      // [_defaultDesignation] answers, so a station that keyed through
      // radio1 goes on doing so.
      final perRadio = storedVersion is int && storedVersion >= 2;
      final byRadio = perRadio ? designated : {_legacyOwnerKey(radioA): designated};
      for (final entry in byRadio.entries) {
        final picks = entry.value;
        if (picks is! Map) continue;
        for (final pick in picks.entries) {
          final uuid = pick.value;
          // A pick whose node did not load is dropped, for radio A's
          // reason. An explicit null is kept: that is the operator having
          // answered None, not a missing node.
          if (uuid != null && !(uuid is String && _nodes.containsKey(uuid))) continue;
          (picksByRadio['${entry.key}'] ??= {})['${pick.key}'] = uuid as String?;
        }
      }
    }
    return StationPositions.fromLegacy(radioA: radioA, radioB: radioB, designated: picksByRadio, hasNode: _nodes.containsKey, newId: uuidGenerator.v4);
  }

  /// The setting a version 3 or older SDR kept for the radio it showed the
  /// spectrum for: a node id, or `main` (also what an absent one meant).
  static const _legacySdrRadioKey = 'sdrRadio';

  /// [_legacySdrRadioKey] for an SDR no radio picked: a value naming no
  /// node, which that build reads as linked to nothing.
  static const _legacySdrRadioNone = 'none';

  /// What a build from before positions reads (version 3), written beside
  /// the positions so a station opened in one keeps its radios and every
  /// radio's picks. That build saves without the positions, and this one
  /// then migrates from these.
  Map<String, dynamic> _legacyKeys() => {
    'mainVfo': switch (_positions.radioOf(kSetA)) {
      LocalRadio(:final uuid) => {'radio': uuid},
      PeerRadio(:final selection) => {'peer': selection.toJson()},
      null => null,
    },
    'radio2': switch (_positions.radioOf(kSetB)) {
      LocalRadio(:final uuid) => uuid,
      _ => null,
    },
    'designated': {
      for (final position in _positions.all)
        if (position.slots.isNotEmpty) _legacyOwnerKey(position.radio): position.slots,
    },
  };

  /// [node] as stored. An SDR also carries the radio it shows the spectrum
  /// for, for [_legacyKeys]' reason: without it, that build reads the SDR
  /// as following whichever radio is Main.
  Map<String, dynamic> _storedNode(EquipmentNode node) {
    if (registry.typeFor(node.typeKey)?.category != kCategorySdr) return node.toJson();
    return node.copyWith(config: {...node.config, _legacySdrRadioKey: linkedRadioFor(node.uuid) ?? _legacySdrRadioNone}).toJson();
  }

  bool _isSdr(EquipmentNode node) => registry.typeFor(node.typeKey)?.category == kCategorySdr;

  /// What each SDR of a version 3 or older blob says it shows the spectrum
  /// for, as the scope of that radio's position: the radio it names, or set
  /// A's for one following "the Main radio". The setting goes from the node,
  /// since the position holds it now. One position holds one scope, so the
  /// first SDR in station order takes a radio two named, as it took that
  /// radio's picture, and the second is nobody's.
  ///
  /// A blob this build wrote and an older one saved also holds the scope
  /// picks themselves ([_legacyKeys]); several positions may hold one SDR,
  /// and the setting names one of them, or [_legacySdrRadioNone]. Naming a
  /// radio whose position does not pick the SDR, it was moved there, and
  /// that build links an SDR to one radio: it leaves the others and takes
  /// that one, over the radio's own scope as well. Naming anything else,
  /// including a radio that went, it says nothing new and the picks stand.
  /// Main changed there moves nothing, though the setting names a set A's
  /// radio: it is compared with the picks, never with set A.
  ///
  /// An SDR following "the Main radio" while that was a peer's or none is
  /// nobody's scope: a peer's radio has no spectrum here to stand in for.
  void _moveSdrLinks() {
    final radioA = _positions.radioOf(kSetA);
    for (final node in [..._nodes.values]) {
      if (!_isSdr(node)) continue;
      final link = _forwardIds(node.config[_legacySdrRadioKey]);
      _nodes[node.uuid] = node.copyWith(config: {...node.config}..remove(_legacySdrRadioKey));
      final radio = switch (link) {
        null || '' || 'main' => radioA,
        final String uuid when _nodes.containsKey(uuid) => LocalRadio(uuid),
        _ => null,
      };
      if (radio is! LocalRadio) continue;
      final slots = _positions.slotsFor(radio);
      if (slots[kCapabilityScope] == node.uuid) continue;
      final picking = [
        for (final position in _positions.all)
          if (position.slots[kCapabilityScope] == node.uuid) position,
      ];
      // Nobody's scope yet, it takes the radio unless another SDR already
      // has it. An explicit None gives way: a blob from before positions
      // holds none, so this build wrote it, and the SDR was pointed here
      // since.
      if (picking.isEmpty && slots[kCapabilityScope] != null) continue;
      for (final position in picking) {
        position.slots.remove(kCapabilityScope);
      }
      slots[kCapabilityScope] = node.uuid;
    }
  }

  /// The key a version 2 or 3 blob filed [radio]'s picks under.
  static String _legacyOwnerKey(MainVfo? radio) => switch (radio) {
    LocalRadio(:final uuid) => uuid,
    PeerRadio(:final selection) => peerRadioValue(selection),
    null => 'none',
  };
}

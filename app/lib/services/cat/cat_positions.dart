// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The antenna and key picked for each radio, kept as that radio's position
// (docs/design/station-model.md § 5; the stored shape is
// station_positions.dart).

part of 'cat_service.dart';

mixin _Positions on _So2r {
  StationPositions get _positions;
  MainVfo? get _radio1;
  Map<String, EquipmentNode> get _nodes;
  EquipmentRegistry get registry;

  /// The position whose picks [designatedFor] and [setDesignated] are
  /// talking about: [radio]'s, a local transceiver's uuid, or radio1's.
  ///
  /// Per radio because that is what an antenna and a key are physically
  /// attached to. A shack whose second rig runs a different wire and its own
  /// paddle states that once; switching radio1 restores what that radio was
  /// last set to, and switching back restores the first one's.
  MainVfo? _ownerOf(String? radio) => radio == null ? _radio1 : LocalRadio(radio);

  /// [category]'s pick for [radio] — a local transceiver's uuid, SO2R's
  /// Radio B being the one caller that names one — or for radio1.
  ///
  /// Never one key for both SO2R radios: a key keys one message at a time,
  /// and two keyers sharing it stop each other's. Nor one SDR as both
  /// radios' scope: it follows one dial, and the other radio would draw the
  /// wrong band under its own. Radio B's answers None while it is radio1's,
  /// which a change of radio1 can make it, restoring that radio's own picks.
  @override
  String? designatedFor(String category, {String? radio}) {
    final pick = _pickFor(category, radio);
    if (_oneSetAtATime(category) && radio != null && radio == radio2 && pick != null && pick == _pickFor(category, null)) return null;
    return pick;
  }

  /// What one SO2R set at a time may have: see [designatedFor].
  static bool _oneSetAtATime(String category) => category == kCategoryKey || category == kCapabilityScope;

  String? _pickFor(String category, String? radio) {
    final picks = _positions.slotsOf(_ownerOf(radio));
    if (picks != null && picks.containsKey(category)) return picks[category];
    return _defaultDesignation(category, radio ?? _localRadio1);
  }

  /// What a radio that has never been asked keys through: itself, when its
  /// own CAT can key. Computed rather than written, so it follows the radio
  /// without an operator ever confirming it — and only a default, which is
  /// what [setDesignated]'s stored entry then outranks, None included.
  ///
  /// Antennas have no equivalent: nothing about a radio says which wire is
  /// on it. Neither does a peer's radio, whose keying is the other device's
  /// key in use — that default is [peerKeyIsInUse] rather than an answer
  /// here, because what keys there is not a node of this station to name.
  String? _defaultDesignation(String category, String? uuid) {
    if (category != kCategoryKey) return null;
    if (!_settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */ ) return null;
    if (uuid == null) return null;
    final node = _nodes[uuid];
    if (node == null) return null;
    return _radioKeysCw(node) ? uuid : null;
  }

  /// Whether [node]'s CAT keys CW — the driver's answer for THIS node's
  /// merged config, since on a generic entry that is a per-node fact.
  bool _radioKeysCw(EquipmentNode node) {
    final type = registry.typeFor(node.typeKey);
    return type != null && type.driver.canKeyCwWith(type.driverConfig(node.config));
  }

  bool isDesignated(String category, String uuid) => designatedFor(category) == uuid;

  /// Writes a pick for the radio in use without saving or notifying — the
  /// shared half of [setDesignated] and the rules [addNode] applies.
  void _designateNow(String category, String? uuid) => _positions.slotsFor(_radio1)[category] = uuid;

  /// Picks [uuid] as [category] for [radio] — see [designatedFor].
  @override
  Future<void> setDesignated(String category, String? uuid, {String? radio}) async {
    final owner = _ownerOf(radio);
    final previousUuid = designatedFor(category, radio: radio);
    // An ANSWER is stored even when it matches the default it replaces:
    // "nothing chosen" and "chose None" resolve alike right now but are not
    // the same state, and the difference decides whether a default can take
    // over later — a peer radio whose operator said None keys nothing, and
    // one whose operator said nothing keys through that peer.
    final answered = _positions.slotsOf(owner)?.containsKey(category) ?? false;
    if (answered && previousUuid == uuid) return;
    // One key, and one SDR scope, per SO2R radio: Radio B is refused
    // radio1's, and radio1 taking Radio B's leaves Radio B with None.
    final b = radio2;
    final exclusive = _oneSetAtATime(category) && uuid != null && b != null;
    if (exclusive && radio == b && uuid == designatedFor(category)) return;
    final takesB = exclusive && radio == null && uuid == designatedFor(category, radio: b);
    // Only a real CHANGE of the key IN USE owes the outgoing one anything. A
    // dropdown reports the already-selected item being tapped, and abandoning
    // the message going out because the operator re-picked the key that is
    // keying it would stop a CQ mid-word — and under SO2R the radio being
    // edited may not be the one keying at all.
    _withKeyInUseTidied(() {
      _positions.slotsFor(owner)[category] = uuid;
      if (takesB) _positions.slotsFor(LocalRadio(b))[category] = null;
    });
    await _save();
    notifyListeners();
  }
}

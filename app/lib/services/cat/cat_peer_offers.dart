// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// This station's side of peer device sync's radio sharing: the radios it
// offers to other devices, what it hears back about the ones they offer, and
// keying requests in both directions (peer_station_radios.dart).

part of 'cat_service.dart';

mixin _PeerOffers on ChangeNotifier implements PeerStationRadios {
  EquipmentRegistry get registry;
  Map<String, EquipmentNode> get _nodes;
  RadioService? get _radio;
  String? get _localRadio1;
  set _radio1(MainVfo? value);
  CatKeying get _keying;
  bool get _keyingEnabled;
  EquipmentState stateFor(String uuid);
  void tuneNode(String uuid, VfoReading requested);
  Future<void> _save();

  @override
  List<PeerRadioOffer> get offeredRadios => [
    for (final node in _nodes.values)
      if (registry.typeFor(node.typeKey)?.category == kCategoryTransceiver && stateFor(node.uuid).status == EquipmentStatus.connected)
        PeerRadioOffer(
          id: node.uuid,
          name: node.name,
          // CW is the STATION's answer, the same for every radio it
          // offers: a request is keyed by whatever this device keys
          // with, which may be a paddle-side keyer rather than the rig
          // named. Voice is the RADIO's, because the audio is in it.
          //
          // What this device keys with ITSELF, never [canKeyCw]: a
          // station whose own radio1 is some third device's rig keys
          // nothing here, and offering that as keyable would advertise a
          // relay nothing implements.
          //
          // All of it behind this device's own keying experiment: a
          // station whose operator has no keyer area and no Escape
          // handler must not be keyed from elsewhere, because nothing
          // here could stop it.
          keysCw: _keyingEnabled && _keying.keysCwLocally,
          voiceMemories: _keyingEnabled ? (_keying.voiceKeyerFor(node.uuid)?.voiceMemoryCount ?? 0) : 0,
          recordsVoice: _keyingEnabled && (_keying.voiceKeyerFor(node.uuid)?.canRecordVoice ?? false),
        ),
  ];

  @override
  void noteOffer(String deviceId, String deviceName, List<PeerRadioOffer> radios) {
    // Kept for every radio that device offers, picked or not — see
    // [_adoptPeerKeying]. The whole of that device's offer replaces what it
    // last said, absences included: an offer that stops naming a radio is
    // how a station says that rig went away.
    _peerKeying.rememberOffers(deviceId, radios);
    _adoptPeerKeying();
    final selection = followedPeerRadio;
    if (selection == null || selection.deviceId != deviceId) return;
    for (final radio in radios) {
      if (radio.id != selection.radioId) continue;
      if (selection.deviceName == deviceName && selection.radioName == radio.name) return;
      // The ids are unchanged, so this is the same pick under new names —
      // which is why [PeerRadioSelection] compares only the ids. Written
      // through rather than held in memory: the name is wanted precisely
      // when the peer is not here to state it, relaunches included.
      _radio1 = PeerRadio(PeerRadioSelection(deviceId: deviceId, radioId: radio.id, deviceName: deviceName, radioName: radio.name));
      unawaited(_save());
      notifyListeners();
      return;
    }
  }

  @override
  VfoReading? vfoForOfferedRadio(String radioId) {
    // Through the offer, not straight to the runtime: a radio that is not
    // offered must not report either, or a controller would keep hearing
    // from a rig it can no longer be given.
    if (!offeredRadios.any((radio) => radio.id == radioId)) return null;
    return stateFor(radioId).vfo;
  }

  @override
  void tuneOfferedRadio(String radioId, {double? freqKHz, String? mode}) {
    if (!offeredRadios.any((radio) => radio.id == radioId)) return;
    // The designated radio keeps going through `RadioService`, which is the
    // funnel a local keystroke takes: the logging panel follows it and Smart
    // VFO Snap measures it. Tuning it directly would move the rig with the
    // operator's own app still showing where it was.
    if (radioId == _localRadio1) {
      _radio?.setVfo('vfoA', freq: freqKHz, mode: mode);
      return;
    }
    tuneNode(radioId, VfoReading(freqKHz: freqKHz, mode: resolveSideband(mode, freqKHz)));
  }

  // --------------------------------------------- keying, over the link

  /// The picked peer radio's keying — what it says it can be asked to do,
  /// what it last reported, and how a request reaches it (peer_keying.dart).
  /// Every keying surface reads it through the same getters a local rig
  /// answers, so a peer that walks off mid-message leaves them empty rather
  /// than addressing a device that is not there.
  final _peerKeying = PeerKeying();

  @override
  Listenable get keyingChanges => _keying.keyingChanges;

  @override
  void Function(PeerKeyRequestPayload request)? get sendPeerKeyRequest => _peerKeying.send;

  @override
  set sendPeerKeyRequest(void Function(PeerKeyRequestPayload request)? send) => _peerKeying.send = send;

  /// What one of [offeredRadios] is keying, for a controller — null for a
  /// radio this device is not offering, the same guard [vfoForOfferedRadio]
  /// applies and for the same reason.
  ///
  /// The CW half is the STATION's, so two controllers following two radios
  /// of this station are both told about the one message going out. There is
  /// one key in use here, and that message is what it is keying. The labels
  /// and lengths are this device's because the audio is: these memories were
  /// named and timed here.
  @override
  PeerKeyStatusPayload? keyStatusForOfferedRadio(String radioId) {
    // Behind the same experiment the offer is: with keying off there is
    // nothing to report, and the memory labels are this operator's own words.
    if (!_keyingEnabled) return null;
    if (!offeredRadios.any((radio) => radio.id == radioId)) return null;
    return _keying.statusForOfferedRadio(radioId);
  }

  /// Keys, stops, or sets a speed on this device's own station for a peer —
  /// through the same funnels a local function key takes, and only for a
  /// radio this device is currently offering.
  ///
  /// Every arm keys HERE or not at all. A request is never relayed onward to
  /// whatever radio1 this device is itself following: an operator who picked
  /// this station's rig asked for this station's rig, and a chain of them
  /// would put a transmitter two devices away on the air for somebody who
  /// picked neither.
  @override
  void handleKeyRequest(PeerKeyRequestPayload request) {
    // Checked again rather than trusted to the offer: the experiment can go
    // off under an established session, and a controller holding a stale
    // offer would go on keying a station that can no longer see it.
    if (!_keyingEnabled) return;
    if (!offeredRadios.any((radio) => radio.id == request.radioId)) return;
    _keying.handleRequest(request);
  }

  /// The far side's account of what the picked radio is keying. Dropped
  /// unless it is about the radio this operator picked — a device offering
  /// radios hears its own controllers' reports too, and a second source
  /// writing the strip fights the first.
  @override
  void notePeerKeyStatus(String deviceId, PeerKeyStatusPayload status) {
    _peerKeying.rememberStatus(deviceId, status);
    if (!(followedPeerRadio?.matches(deviceId, status.radioId) ?? false)) return;
    final before = _keying.peerShownState;
    _keying.notePeerStatus(status);
    // Only when what the SURFACES read has moved. The notifiers this wrote
    // rebuild the strip on their own, and a status arrives per character from
    // a keyer that echoes them — a full notification each would rebuild every
    // equipment row in the Station panel, which is the cost [cwProgress] is a
    // notifier at all to avoid.
    if (_keying.peerShownState != before) notifyListeners();
  }

  /// Points the keying half at whatever the CURRENT pick's device last said
  /// about it — on a new pick, and on a fresh offer. What it remembers, and
  /// why it has to, is [PeerKeying]'s.
  void _adoptPeerKeying() {
    final selection = followedPeerRadio;
    final deviceId = selection?.deviceId;
    final radioId = selection?.radioId;
    if (!_keying.adoptPeer(_peerKeying.offerFor(deviceId, radioId), _peerKeying.statusFor(deviceId, radioId))) {
      return;
    }
    notifyListeners();
  }

  /// That peer's radios are out of reach — it left. The PICK stands, the
  /// same as it does for tuning: what goes is only what it could do, so the
  /// surfaces go quiet instead of addressing a device that is not there.
  @override
  void forgetPeerRadios(String deviceId) {
    _peerKeying.forgetDevice(deviceId);
    if (followedPeerRadio?.deviceId != deviceId) return;
    if (!_keying.forgetPeer()) return;
    notifyListeners();
  }
}

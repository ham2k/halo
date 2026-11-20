// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A radio heard in HaLo (docs/design/audio.md): the link to the audio engine
// a session asks its sink for as it opens its network link.

part of 'cat_service.dart';

extension _RadioAudioLinks on CatService {
  /// The engine's link for [node]'s receive audio, while the operator hears
  /// it in HaLo: the experiment on, an engine on this device, and the node
  /// asking. A change takes effect at the next connect.
  RadioAudioLink? _receiveAudioLink(EquipmentNode node) {
    if (!hearsInHalo(node.uuid) || !_inASet(node.uuid)) return null;
    if (!radioAudioAvailable(_settings)) return null;
    final delay = node.config[receiveAudioDelayConfigKey];
    return _engineAudio.link(radio: node.uuid, delayMs: delay is num && receiveAudioDelays.contains(delay.toInt()) ? delay.toInt() : receiveAudioDelayDefault);
  }

  /// The engine's link for the operator's microphone to [node], while they
  /// talk through HaLo on it — the same conditions as [_receiveAudioLink]'s.
  TalkAudioLink? _talkAudioLink(EquipmentNode node) {
    if (!talksThroughHalo(node.uuid) || !_inASet(node.uuid)) return null;
    if (!radioAudioAvailable(_settings)) return null;
    return _engineAudio.talkLink();
  }

  /// What [kComputerDevice] offers: its sound cards as the engine lists
  /// them ([RadioAudio.soundCards]), and the mixer even with none.
  List<Capability> _computerOffers() {
    final audio = _audioOffered;
    final cards = audio ? _engineAudio.soundCards : (playback: const <AudioDevice>[], capture: const <AudioDevice>[]);
    // The keying's own field rather than [computerVoiceAudio], which starts
    // looking for the recordings' directory as it answers.
    return computerOffers(voice: _keying.voiceAudio != null, audio: audio, playback: cards.playback, capture: cards.capture);
  }

  RadioAudio get _engineAudio => _radioAudio ??= RadioAudio(
    microphone: () => operatorMicrophone,
    output: () => operatorHeadphones,
    volume: () => _settings.stationVolumeMuted ? 0 : (_mixVolume ?? _settings.stationVolume),
    level: (radio) => _settings.radioMuted(radio) ? 0 : (_mixLevels[radio] ?? _settings.radioLevel(radio)),
    ear: earInMix,
    onOutputGone: () => unawaited(_routeHeardAgain()),
  );

  /// Every radio heard in HaLo reconnected, so its audio is routed again
  /// into the operator's headphones as they now are.
  Future<void> _routeHeardAgain() async {
    // A radio heard from its sound card too: its route went with the old
    // output, and asked again for the same card it would do nothing.
    for (final uuid in [..._nodes.keys]) {
      _radioAudio?.dropCard(uuid);
      _cardHeardFollows(uuid);
    }
    for (final node in [..._nodes.values]) {
      if (!hearsInHalo(node.uuid) || !_inASet(node.uuid) || stateFor(node.uuid).status != EquipmentStatus.connected) continue;
      await disconnect(node.uuid, byUser: false);
      await connect(node.uuid);
    }
  }

  /// A connected radio heard here whose buffering changed reconnects to
  /// take it: its link to the engine is made as it connects.
  ///
  /// Only a radio heard here: the editor shows the buffering set to its
  /// default, and a save of an unrelated field would otherwise reconnect
  /// every radio, mid-QSO.
  void _audioSettingsEdited(EquipmentNode previous, EquipmentNode node) {
    if (_bufferingDiffers(previous.config, node.config) && hearsInHalo(node.uuid) && _inASet(node.uuid)) _reconnectForAudio(node.uuid);
  }

  /// Whether [a] and [b] buffer a radio's receive audio differently: an
  /// unset buffering is its default.
  bool _bufferingDiffers(Map<String, dynamic> a, Map<String, dynamic> b) {
    int delay(Map<String, dynamic> config) => (config[receiveAudioDelayConfigKey] as num?)?.toInt() ?? receiveAudioDelayDefault;
    return delay(a) != delay(b);
  }

  /// Whether [uuid] is a logging set's radio: the only ones heard here. A
  /// slice the operator moved away from stays heard otherwise, with its
  /// Listen choice, a set's, out of reach.
  bool _inASet(String uuid) => isRadio1(uuid) || isRadio2(uuid);

  /// Runs [change] to which radios are a set's, then hears each radio it
  /// brought into a set and stops hearing each it took out, once [change]
  /// is whole: run inside it, a reconnect notifies while one rig is still
  /// both sets' radio.
  ///
  /// A radio coming in reconnects to be heard by its own audio, as its link
  /// is made at connect. One going out is muted at once ([earInMix]) and
  /// left connected: its CAT, scope and meters are no reason to drop, and
  /// its stream goes at its next connect.
  void _audioFollowsSets(void Function() change) {
    final before = {
      for (final node in _nodes.values)
        if (_inASet(node.uuid)) node.uuid,
    };
    change();
    final after = {
      for (final node in _nodes.values)
        if (_inASet(node.uuid)) node.uuid,
    };
    final moved = before.union(after).difference(before.intersection(after));
    if (moved.isEmpty) return;
    scheduleMicrotask(() {
      if (_disposed) return;
      for (final uuid in moved) {
        if (after.contains(uuid) && hearsInHalo(uuid)) _reconnectForAudio(uuid);
        _cardHeardFollows(uuid);
      }
      _radioAudio?.applyGains();
    });
  }

  /// [uuid] heard from its sound card while it is connected, and not once it
  /// is not: a radio switched off is not heard as its codec's hiss. Called
  /// at each change of its state.
  void _cardHeardFollows(String uuid) {
    final card = _audioOffered && _inASet(uuid) && stateFor(uuid).status == EquipmentStatus.connected ? heardCard(uuid) : null;
    if (card == null) {
      _radioAudio?.dropCard(uuid);
      return;
    }
    _engineAudio.hearCard(uuid, card, (reason) {
      trafficLog?.note(_logLabel(uuid), 'audio: $reason');
      _setState(uuid, stateFor(uuid).copyWith(audioProblem: reason));
    });
  }

  /// [slot]'s pick on [uuid]'s position, while it is a sound card on this
  /// computer.
  CapabilityAddress? _cardPick(String uuid, String slot) {
    final picked = _positions.slotsOf(LocalRadio(uuid))?[slot];
    final address = picked == null ? null : CapabilityAddress.parse(picked);
    return address != null && address.device == kComputerDevice && address.kind == kCapabilityAudio ? address : null;
  }

  /// A connected radio reconnects, so its links to the engine are made again.
  void _reconnectForAudio(String uuid) {
    if (stateFor(uuid).status != EquipmentStatus.connected) return;
    unawaited(disconnect(uuid, byUser: false).then((_) => connect(uuid)));
  }

  /// The radio's own `audio`, as an audio slot holds it: its address on
  /// [uuid], keyed as the node's entry offers it.
  String? _ownAudioAddress(String uuid) {
    final node = _nodes[uuid];
    final type = node == null ? null : typeFor(node);
    if (node == null || type == null) return null;
    return '${CapabilityAddress(uuid, kCapabilityAudio, key: type.driver.offerKeyWith(type.driverConfig(node.config)))}';
  }

  /// [slot]'s pick on [uuid]'s position, while it is the radio's own audio:
  /// the one thing an audio slot picks before the mixer routes sound cards.
  String? _ownAudioPick(String uuid, String slot) {
    final picked = _positions.slotsOf(LocalRadio(uuid))?[slot];
    final address = picked == null ? null : CapabilityAddress.parse(picked);
    return address != null && address.device == uuid && address.kind == kCapabilityAudio ? picked : null;
  }

  /// The operator's key on [target] with their microphone through its sound
  /// card ([CatPtt.talkThroughCard]): null for a radio whose transmit audio
  /// is not a card, or that cannot take the computer's audio, which keys as
  /// any other. A source the radio refuses lets go of the key, as the voice
  /// keyer's does, and says so on the radio's row.
  bool? _keyThroughCard(PttSession target, bool on) {
    if (target is! ComputerAudioPttSession) return null;
    // Asked only to end an over that went out through the card: ended
    // whatever changed during it — the pick, the set, the experiment — or
    // the radio stays keyed with the microphone open.
    if (!on) {
      try {
        target.setPttWithComputerAudio(false);
      } finally {
        _radioAudio?.endCardOver();
      }
      return true;
    }
    if (!_audioOffered || !target.switchesToComputerAudio) return null;
    final uuid = nodes.map((node) => node.uuid).firstWhereOrNull((uuid) => identical(connectedSession(uuid), target));
    final card = uuid == null || !_inASet(uuid) ? null : talkCard(uuid);
    if (uuid == null || card == null) return null;
    void why(String reason) {
      trafficLog?.note(_logLabel(uuid), 'audio: $reason');
      _setState(uuid, stateFor(uuid).copyWith(audioProblem: reason));
    }

    if (!_engineAudio.speakToCard(card, why)) return false;
    try {
      // A radio may refuse from inside the key, before [CatPtt] holds it as
      // an over through the card: the over is closed here, not by its unkey.
      target.setPttWithComputerAudio(
        true,
        refused: () {
          why(t.settings.station.audioProblemTalkCardRefused);
          _radioAudio?.endCardOver();
          _ptt.release();
        },
      );
    } catch (_) {
      _radioAudio?.endCardOver();
      rethrow;
    }
    return true;
  }

  /// [card] for [slot] on [uuid]'s position, kept with its name beside.
  Future<void> _setCardPick(String uuid, String slot, AudioDevice card) async {
    final address = '${CapabilityAddress(kComputerDevice, kCapabilityAudio, key: card.id)}';
    if (_positions.slotsOf(LocalRadio(uuid))?[slot] == address) return;
    final wasOwn = _ownAudioPick(uuid, slot) != null;
    _positions.slotsFor(LocalRadio(uuid))[slot] = address;
    _positions.names[address] = card.name;
    await _save();
    _changed();
    if (wasOwn) _reconnectForAudio(uuid);
  }

  /// Picks the radio's own audio for [slot] on [uuid]'s position, or None.
  Future<void> _setOwnAudioPick(String uuid, String slot, bool on) async {
    final wasOwn = _ownAudioPick(uuid, slot) != null;
    if (wasOwn == on && (on || _cardPick(uuid, slot) == null)) return;
    final address = on ? _ownAudioAddress(uuid) : null;
    if (on && address == null) return;
    _positions.slotsFor(LocalRadio(uuid))[slot] = address;
    await _save();
    _changed();
    if (wasOwn != on) _reconnectForAudio(uuid);
  }

  /// A sound card the operator picked ([kOperatorMicrophone],
  /// [kOperatorHeadphones]), as the engine matches it: null for the
  /// system's default.
  ({String? id, String? name})? _operatorDevice(String kind) {
    final address = switch (_positions.operatorPicks[kind]) {
      final picked? => CapabilityAddress.parse(picked),
      null => null,
    };
    final id = address?.key;
    if (address == null || id == null) return null;
    return (id: id, name: _positions.names['${address.capability}']);
  }

  Future<void> _setOperatorDevice(String kind, AudioDevice? device) async {
    if (device == null) {
      _positions.operatorPicks[kind] = null;
    } else {
      final address = '${CapabilityAddress(kComputerDevice, kCapabilityAudio, key: device.id)}';
      _positions.operatorPicks[kind] = address;
      _positions.names[address] = device.name;
    }
    await _save();
    _changed();
  }

  /// The choices builds before positions held them kept elsewhere: each
  /// radio's own flags, and the station's microphone and output among the
  /// settings. Moved only where nothing was decided here, so a choice made
  /// since is never undone; the old keys stay for an older build to read.
  void _moveAudioChoices() {
    for (final node in _nodes.values) {
      for (final (flag, slot) in [(receiveAudioConfigKey, kSlotReceiveAudio), (talkAudioConfigKey, kSlotTransmitAudio)]) {
        if (node.config[flag] != true || (_positions.slotsOf(LocalRadio(node.uuid))?.containsKey(slot) ?? false)) continue;
        if (_ownAudioAddress(node.uuid) case final address?) _positions.slotsFor(LocalRadio(node.uuid))[slot] = address;
      }
    }
    for (final (kind, stored) in [(kOperatorMicrophone, _settings.stationMicrophone), (kOperatorHeadphones, _settings.stationOutput)]) {
      final id = stored?.id;
      if (_positions.operatorPicks.containsKey(kind) || id == null || id.isEmpty) continue;
      final address = '${CapabilityAddress(kComputerDevice, kCapabilityAudio, key: id)}';
      _positions.operatorPicks[kind] = address;
      if (stored?.name case final name? when name.isNotEmpty) _positions.names[address] = name;
    }
  }
}

/// Hearing a set's radio in HaLo, and talking through HaLo on it: chosen
/// per receiver, since a slice of a Flex is an entry of its own, which the
/// radio's editor does not reach.
extension CatRadioAudioChoices on CatService {
  /// Whether [uuid] could be heard in HaLo: its `audio` brings channels in,
  /// which it offers only under the experiment with an engine on this
  /// device ([CatService.capabilitiesOf]).
  bool offersReceiveAudio(String uuid) => capabilitiesOf(uuid).any((c) => c.kind == kCapabilityAudio && c.inputs.isNotEmpty);

  /// Whether the station's microphone could reach [uuid] through HaLo: its
  /// `audio` sends channels out.
  bool offersTalkAudio(String uuid) => capabilitiesOf(uuid).any((c) => c.kind == kCapabilityAudio && c.outputs.isNotEmpty);

  /// Whether the operator hears [uuid] in HaLo: its position's receive
  /// audio is the radio's own ([kSlotReceiveAudio]).
  bool hearsInHalo(String uuid) => _ownAudioPick(uuid, kSlotReceiveAudio) != null;

  /// The logging sets' radios whose audio goes through this computer,
  /// either way: what the station's audio mixing is about.
  List<EquipmentNode> get radiosThroughComputer => [
    for (final node in _nodes.values)
      if (heardThroughComputer(node.uuid) ||
          (_inASet(node.uuid) && ((talksThroughHalo(node.uuid) && offersTalkAudio(node.uuid)) || (talkCard(node.uuid) != null && _audioOffered))))
        node,
  ];

  /// The mix's overall volume, 0 to 1: as a slider has it while it moves,
  /// or as stored.
  double get mixVolume => _mixVolume ?? _settings.stationVolume;

  /// What [radio] is mixed at, 0 to 1, before the overall volume.
  double mixLevel(String radio) => _mixLevels[radio] ?? _settings.radioLevel(radio);

  /// Sets the overall volume, heard at once; stored only when [store] says,
  /// as a slider's drag ends, rather than on every step of it.
  Future<void> setMixVolume(double volume, {bool store = false}) async {
    _mixVolume = volume;
    _radioAudio?.applyGains();
    _changed();
    if (!store) return;
    await _settings.setStationVolume(volume);
    _mixVolume = null;
  }

  /// Whether the whole mix is muted, and whether [radio] is: its volume or
  /// level kept, to come back at as it is unmuted.
  bool get mixVolumeMuted => _settings.stationVolumeMuted;
  bool mixMuted(String radio) => _settings.radioMuted(radio);

  Future<void> setMixVolumeMuted(bool muted) async {
    await _settings.setStationVolumeMuted(muted);
    _radioAudio?.applyGains();
    _changed();
  }

  Future<void> setMixMuted(String radio, bool muted) async {
    await _settings.setRadioMuted(radio, muted);
    _radioAudio?.applyGains();
    _changed();
  }

  /// Sets what [radio] is mixed at, as [setMixVolume] sets the volume.
  Future<void> setMixLevel(String radio, double level, {bool store = false}) async {
    _mixLevels[radio] = level;
    _radioAudio?.applyGains();
    _changed();
    if (!store) return;
    await _settings.setRadioLevel(radio, level);
    _mixLevels.remove(radio);
  }

  /// The operator's headphones, where every radio heard in HaLo plays, and
  /// their microphone, read at each over: null for the system's default.
  ({String? id, String? name})? get operatorHeadphones => _operatorDevice(kOperatorHeadphones);
  ({String? id, String? name})? get operatorMicrophone => _operatorDevice(kOperatorMicrophone);

  /// Plays every radio heard in HaLo on [device] (null for the system's
  /// default output): each is routed again into it, then the old one goes.
  Future<void> setOperatorHeadphones(AudioDevice? device) async {
    await _setOperatorDevice(kOperatorHeadphones, device);
    await _routeHeardAgain();
    _radioAudio?.closeOtherOutputs();
  }

  /// Takes [device] (null for the system's default input) at the next over.
  Future<void> setOperatorMicrophone(AudioDevice? device) => _setOperatorDevice(kOperatorMicrophone, device);

  /// Whether the operator talks through HaLo on [uuid]: its position sends
  /// their microphone to the radio's own audio ([kSlotTransmitAudio]).
  bool talksThroughHalo(String uuid) => _ownAudioPick(uuid, kSlotTransmitAudio) != null;

  /// Hears [uuid] in HaLo, or on the radio: a connected one reconnects to
  /// take it.
  Future<void> setHearsInHalo(String uuid, bool on) async {
    await _setOwnAudioPick(uuid, kSlotReceiveAudio, on);
    _cardHeardFollows(uuid);
  }

  /// The sound card [uuid] is heard from (a radio on a USB codec), as the
  /// engine matches it: null for none.
  ({String? id, String? name})? heardCard(String uuid) => switch (_cardPick(uuid, kSlotReceiveAudio)) {
    final address? => (id: address.key, name: _positions.names['$address']),
    null => null,
  };

  /// Hears [uuid] from [card], a sound card on this computer: at once if
  /// it is connected.
  Future<void> setHeardCard(String uuid, AudioDevice card) async {
    await _setCardPick(uuid, kSlotReceiveAudio, card);
    _cardHeardFollows(uuid);
  }

  /// Whether the operator hears [uuid] through this computer: a logging
  /// set's radio, its own audio carried here (the experiment on, and the
  /// radio's driver carrying it) or from a sound card here. What has a level
  /// of its own in the mix.
  bool heardThroughComputer(String uuid) => _inASet(uuid) && ((hearsInHalo(uuid) && offersReceiveAudio(uuid)) || (heardCard(uuid) != null && _audioOffered));

  /// [uuid]'s gain in each ear of the mix, as the engine is built here.
  @visibleForTesting
  (double, double) mixGains(String uuid) => _engineAudio.gainsFor(uuid);

  /// The logging set [uuid] is the radio of, `A` or `B`, or null.
  String? setOfRadio(String uuid) => isRadio1(uuid)
      ? kSetA
      : isRadio2(uuid)
      ? kSetB
      : null;

  /// [uuid]'s ears in the mix: muted for a radio the mixer does not list, so
  /// only what it lists is heard, whatever stream is still open; otherwise
  /// as the computer's SO2R switcher puts it, null for both.
  So2rEar? earInMix(String uuid) => heardThroughComputer(uuid) ? so2rComputerEar(uuid) : So2rEar.muted;

  /// The sound cards this computer offers [input] (that HaLo hears from) or
  /// not (that it plays into), as a picker lists them.
  List<Capability> computerCards({required bool input}) => [
    for (final card in capabilitiesOf(kComputerDevice))
      if (card.kind == kCapabilityAudio && (input ? card.inputs : card.outputs).isNotEmpty) card,
  ];

  /// Whether [uuid] can take the operator's microphone from a sound card:
  /// its session keys it with the computer's audio. Known only while it is
  /// connected: a driver says so per model, which its session reads.
  bool takesCardMicrophone(String uuid) =>
      _audioOffered &&
      switch (connectedSession(uuid)) {
        final ComputerAudioPttSession session => session.switchesToComputerAudio,
        _ => false,
      };

  /// The sound card [uuid] takes the operator's microphone from (a radio on
  /// a USB codec), as the engine matches it: null for none.
  ({String? id, String? name})? talkCard(String uuid) => switch (_cardPick(uuid, kSlotTransmitAudio)) {
    final address? => (id: address.key, name: _positions.names['$address']),
    null => null,
  };

  /// Sends the operator's microphone into [uuid] through [card], a sound
  /// card on this computer, from their next key.
  Future<void> setTalkCard(String uuid, AudioDevice card) => _setCardPick(uuid, kSlotTransmitAudio, card);

  /// Sends the operator's microphone to [uuid] through HaLo, or leaves the
  /// radio on its own microphone.
  Future<void> setTalksThroughHalo(String uuid, bool on) => _setOwnAudioPick(uuid, kSlotTransmitAudio, on);
}

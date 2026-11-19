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
    if (!hearsInHalo(node.uuid)) return null;
    if (!radioAudioAvailable(_settings)) return null;
    final delay = node.config[receiveAudioDelayConfigKey];
    return _engineAudio.link(radio: node.uuid, delayMs: delay is num && receiveAudioDelays.contains(delay.toInt()) ? delay.toInt() : receiveAudioDelayDefault);
  }

  /// The engine's link for the operator's microphone to [node], while they
  /// talk through HaLo on it — the same conditions as [_receiveAudioLink]'s.
  TalkAudioLink? _talkAudioLink(EquipmentNode node) {
    if (!talksThroughHalo(node.uuid)) return null;
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
    volume: () => _mixVolume ?? _settings.stationVolume,
    level: (radio) => _mixLevels[radio] ?? _settings.radioLevel(radio),
    onOutputGone: () => unawaited(_routeHeardAgain()),
  );

  /// Every radio heard in HaLo reconnected, so its audio is routed again
  /// into the operator's headphones as they now are.
  Future<void> _routeHeardAgain() async {
    for (final node in [..._nodes.values]) {
      if (!hearsInHalo(node.uuid) || stateFor(node.uuid).status != EquipmentStatus.connected) continue;
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
    if (_bufferingDiffers(previous.config, node.config) && hearsInHalo(node.uuid)) _reconnectForAudio(node.uuid);
  }

  /// Whether [a] and [b] buffer a radio's receive audio differently: an
  /// unset buffering is its default.
  bool _bufferingDiffers(Map<String, dynamic> a, Map<String, dynamic> b) {
    int delay(Map<String, dynamic> config) => (config[receiveAudioDelayConfigKey] as num?)?.toInt() ?? receiveAudioDelayDefault;
    return delay(a) != delay(b);
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

  /// Picks the radio's own audio for [slot] on [uuid]'s position, or None.
  Future<void> _setOwnAudioPick(String uuid, String slot, bool on) async {
    if ((_ownAudioPick(uuid, slot) != null) == on) return;
    final address = on ? _ownAudioAddress(uuid) : null;
    if (on && address == null) return;
    _positions.slotsFor(LocalRadio(uuid))[slot] = address;
    await _save();
    _changed();
    _reconnectForAudio(uuid);
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

  /// The radios whose audio goes through this computer, either way: what
  /// the station's audio mixing is about.
  List<EquipmentNode> get radiosThroughComputer => [
    for (final node in _nodes.values)
      if ((hearsInHalo(node.uuid) && offersReceiveAudio(node.uuid)) || (talksThroughHalo(node.uuid) && offersTalkAudio(node.uuid))) node,
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
  Future<void> setHearsInHalo(String uuid, bool on) => _setOwnAudioPick(uuid, kSlotReceiveAudio, on);

  /// Sends the operator's microphone to [uuid] through HaLo, or leaves the
  /// radio on its own microphone.
  Future<void> setTalksThroughHalo(String uuid, bool on) => _setOwnAudioPick(uuid, kSlotTransmitAudio, on);
}

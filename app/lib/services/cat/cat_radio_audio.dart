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
    if (node.config[receiveAudioConfigKey] != true) return null;
    if (!radioAudioAvailable(_settings)) return null;
    final delay = node.config[receiveAudioDelayConfigKey];
    return _engineAudio.link(radio: node.uuid, delayMs: delay is num && receiveAudioDelays.contains(delay.toInt()) ? delay.toInt() : receiveAudioDelayDefault);
  }

  /// The engine's link for the station's microphone to [node], while the
  /// operator talks through HaLo on it — the same conditions as
  /// [_receiveAudioLink]'s.
  TalkAudioLink? _talkAudioLink(EquipmentNode node) {
    if (node.config[talkAudioConfigKey] != true) return null;
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
    microphone: () => _settings.stationMicrophone,
    output: () => _settings.stationOutput,
    volume: () => _mixVolume ?? _settings.stationVolume,
    level: (radio) => _mixLevels[radio] ?? _settings.radioLevel(radio),
    onOutputGone: () => unawaited(_routeHeardAgain()),
  );

  /// Every radio heard in HaLo reconnected, so its audio is routed again
  /// into the station's output as it now is.
  Future<void> _routeHeardAgain() async {
    for (final node in [..._nodes.values]) {
      if (node.config[receiveAudioConfigKey] != true || stateFor(node.uuid).status != EquipmentStatus.connected) continue;
      await disconnect(node.uuid, byUser: false);
      await connect(node.uuid);
    }
  }

  /// A connected radio whose audio settings changed reconnects to take
  /// them: its links to the engine are made as it connects.
  ///
  /// The buffering alone matters only to a radio heard here: the editor
  /// shows it set to its default, and a save of an unrelated field would
  /// otherwise reconnect every radio, mid-QSO.
  void _audioSettingsEdited(EquipmentNode previous, EquipmentNode node) {
    if (!_audioDiffers(previous.config, node.config)) return;
    final heard = previous.config[receiveAudioConfigKey] == true || node.config[receiveAudioConfigKey] == true;
    final talks = previous.config[talkAudioConfigKey] == true || node.config[talkAudioConfigKey] == true;
    final onlyBuffering =
        previous.config[receiveAudioConfigKey] == node.config[receiveAudioConfigKey] && previous.config[talkAudioConfigKey] == node.config[talkAudioConfigKey];
    if (onlyBuffering ? !heard : !(heard || talks)) return;
    if (stateFor(node.uuid).status != EquipmentStatus.connected) return;
    unawaited(disconnect(node.uuid, byUser: false).then((_) => connect(node.uuid)));
  }

  /// Whether [a] and [b] differ in how a radio's audio goes through this
  /// computer: an unset buffering is its default.
  bool _audioDiffers(Map<String, dynamic> a, Map<String, dynamic> b) {
    int delay(Map<String, dynamic> config) => (config[receiveAudioDelayConfigKey] as num?)?.toInt() ?? receiveAudioDelayDefault;
    return (a[receiveAudioConfigKey] == true) != (b[receiveAudioConfigKey] == true) ||
        (a[talkAudioConfigKey] == true) != (b[talkAudioConfigKey] == true) ||
        delay(a) != delay(b);
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

  bool hearsInHalo(String uuid) => _nodes[uuid]?.config[receiveAudioConfigKey] == true;

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

  /// Plays every radio heard in HaLo on [device] (null for the system's
  /// default output): each is routed again into it, then the old one goes.
  Future<void> setStationOutput(AudioDevice? device) async {
    await _settings.setStationOutput(device);
    _changed();
    await _routeHeardAgain();
    _radioAudio?.closeOtherOutputs();
  }

  bool talksThroughHalo(String uuid) => _nodes[uuid]?.config[talkAudioConfigKey] == true;

  /// Hears [uuid] in HaLo, or on the radio: a connected one reconnects to
  /// take it ([_audioSettingsEdited]).
  Future<void> setHearsInHalo(String uuid, bool on) => _setAudioChoice(uuid, receiveAudioConfigKey, on);

  /// Sends the station's microphone to [uuid] through HaLo, or leaves the
  /// radio on its own microphone.
  Future<void> setTalksThroughHalo(String uuid, bool on) => _setAudioChoice(uuid, talkAudioConfigKey, on);

  Future<void> _setAudioChoice(String uuid, String key, bool on) async {
    final node = _nodes[uuid];
    if (node == null || (node.config[key] == true) == on) return;
    await updateNode(node.copyWith(config: {...node.config, key: on}));
  }
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a configured node offers (docs/design/station-model.md § 4.3): known
// from its catalogue entry and configuration alone, so a picker works with
// the equipment switched off, and corrected by what the equipment says once
// it is on.

import 'package:halo_audio/halo_audio.dart' show AudioDevice;

import 'capability.dart';
import 'equipment.dart';
import 'equipment_registry.dart';

/// [offered] as one line for a developer: each capability by kind and key,
/// with its name where it has one, and a switch's ports or an audio's
/// channels.
String describeOffers(List<Capability> offered) => [
  for (final capability in offered)
    [
      '${capability.kind}:${capability.key}',
      if (capability.name case final name?) '"$name"',
      if (capability.inputs.isNotEmpty || capability.outputs.isNotEmpty) '(in: ${capability.inputs.join(', ')}; out: ${capability.outputs.join(', ')})',
    ].join(' '),
].join(', ');

/// Channels `0` to `count - 1`, as an audio's ports are keyed.
List<String> audioChannels(int count) => [for (var i = 0; i < count; i++) '$i'];

/// What this computer offers ([kComputerDevice]): its own voice recordings
/// where it plays audio at all, and, where [audio] (the experiment on and
/// the engine here), each sound card it lists and the mixer over them.
///
/// A card is keyed by the system's id for it, with its name beside, and is
/// one capability in each direction it is listed in. CoreAudio lists a card
/// that records and plays under one id, so it is one capability with both;
/// WASAPI gives each direction an id of its own, so it is two. A count the
/// backend does not say is what the engine opens a device at when it is
/// given none: one channel in, two out.
List<Capability> computerOffers({required bool voice, required bool audio, List<AudioDevice> playback = const [], List<AudioDevice> capture = const []}) {
  final cards = <String, ({String name, int ins, int outs})>{};
  for (final (devices, isCapture) in [(capture, true), (playback, false)]) {
    // An id of nothing is how a backend with no ids of its own (JACK, the
    // null backend) lists its defaults: no address can name it, and both
    // directions would merge under it.
    for (final device in devices.where((d) => d.id.isNotEmpty)) {
      final known = cards[device.id] ?? (name: device.name, ins: 0, outs: 0);
      final channels = device.channels > 0 ? device.channels : (isCapture ? 1 : 2);
      cards[device.id] = isCapture ? (name: known.name, ins: channels, outs: known.outs) : (name: known.name, ins: known.ins, outs: channels);
    }
  }
  return [
    if (voice) const Capability(kCapabilityVoice),
    if (audio) ...[
      const Capability(kCapabilityAudioMixer),
      for (final MapEntry(key: id, value: card) in cards.entries)
        Capability(kCapabilityAudio, key: id, name: card.name, inputs: audioChannels(card.ins), outputs: audioChannels(card.outs)),
    ],
  ];
}

extension EquipmentOffers on EquipmentType {
  /// What a node on this pairing, configured like [config], offers, without
  /// asking the equipment.
  ///
  /// Each entry is a promise about the sessions this pairing creates: a
  /// receiver is offered only where the session tunes, a scope only where it
  /// is a `SpectrumSession`. So a receive-only SDR offers its scope and no
  /// receiver: nothing can tune or log from it.
  List<Capability> offers(Map<String, dynamic> config) {
    final merged = driverConfig(config);
    final key = driver.offerKeyWith(merged);
    return switch (category) {
      kCategoryTransceiver => [
        Capability(kCapabilityReceiver, key: key),
        // One transmitter however many receivers: a Flex's rides whichever
        // slice holds the TX flag.
        const Capability(kCapabilityTransmitter),
        if (driver.offersScopeWith(merged)) Capability(kCapabilityScope, key: key),
        if (driver.offersIqWith(merged)) Capability(kCapabilityIq, key: key),
        // Withheld from pickers and the resolver while the audio experiment
        // is off (CatService.capabilitiesOf); a report lists it regardless.
        if (driver.carriesReceiveAudio || driver.carriesTalkAudio)
          Capability(kCapabilityAudio, key: key, inputs: audioChannels(driver.receiveAudioChannels), outputs: audioChannels(driver.talkAudioChannels)),
        if (driver.canKeyCwWith(merged)) const Capability(kCapabilityKeyer),
        if (driver.voiceMemoryCountWith(merged) > 0) const Capability(kCapabilityVoice),
        if (driver.so2rAudioReceiverWith(merged) != null) const Capability(kCapabilityAudioMixer),
      ],
      kCategorySdr => [const Capability(kCapabilityScope), if (driver.offersIqWith(merged)) const Capability(kCapabilityIq)],
      kCategoryAntennaSwitch => [Capability(kCapabilitySwitch, key: key)],
      kCategoryRotator => [Capability(kCapabilityRotator, key: key)],
      kCategoryKeyer => const [Capability(kCapabilityKeyer)],
      kCategorySo2rSwitch => const [Capability(kCapabilitySo2rController)],
      kCategoryAntenna => const [Capability(kCapabilityAntenna)],
      kCategoryKey => const [Capability(kCapabilityKey)],
      _ => const [],
    };
  }

  /// [offers], corrected by what the equipment has said in [state]: a
  /// switch's ports as it reports them, and a radio's own antenna ports as a
  /// switch of its own once the radio names them.
  List<Capability> offersWith(Map<String, dynamic> config, EquipmentState state) => [
    for (final offered in offers(config))
      if (offered.kind == kCapabilitySwitch && (state.switchAntennas.isNotEmpty || state.switchPorts.isNotEmpty))
        Capability(
          kCapabilitySwitch,
          key: offered.key,
          inputs: [for (final antenna in state.switchAntennas) antenna.key],
          outputs: [for (final port in state.switchPorts) port.key],
        )
      else
        offered,
    // A list with nothing in it names no port to address, and an empty
    // switch would read as one that has not said yet and accept any port.
    if (state.antennas case final antennas? when antennas.rxPorts.isNotEmpty || antennas.txPorts.isNotEmpty)
      Capability(kCapabilitySwitch, key: radioSwitchKey, inputs: {...antennas.txPorts, ...antennas.rxPorts}.toList(), outputs: radioSwitchOutputs),
  ];
}

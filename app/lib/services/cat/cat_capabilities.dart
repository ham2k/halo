// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What each node offers, and which node and capability an address names
// (docs/design/station-model.md § 4).

part of 'cat_service.dart';

mixin _Capabilities on ChangeNotifier {
  EquipmentNode? nodeFor(String uuid);
  EquipmentType? typeFor(EquipmentNode node);
  EquipmentState stateFor(String uuid);

  /// Whether a radio's `audio`, and the computer's sound cards and mixer,
  /// are offered: the audio experiment on, and the engine on this device.
  bool get _audioOffered;

  /// What [kComputerDevice] offers now ([computerOffers]).
  List<Capability> get _computerOffered;

  /// What [uuid] offers: what its entry declares for its configuration,
  /// corrected by what the equipment has said, or what this computer
  /// offers for [kComputerDevice]. Empty for a device that offers nothing
  /// itself (a server, a MIDI controller), and also for a node this station
  /// does not have or whose entry the catalogue no longer knows: a caller
  /// that must tell those apart asks [nodeFor] and [typeFor] first.
  List<Capability> capabilitiesOf(String uuid) {
    if (uuid == kComputerDevice) return _computerOffered;
    final node = nodeFor(uuid);
    final type = node == null ? null : typeFor(node);
    if (node == null || type == null) return const [];
    final offered = type.offersWith(node.config, stateFor(node.uuid));
    return _audioOffered
        ? offered
        : [
            for (final capability in offered)
              if (capability.kind != kCapabilityAudio) capability,
          ];
  }

  /// The node and capability [address] names, or null when this station has
  /// no such thing. A bare device is its first receiver, or the one thing it
  /// offers when it has no receiver: a rotator's node id is its rotator.
  /// The node is null for [kComputerDevice], which has none, and which as a
  /// bare address is nothing: it offers several things, and which of them
  /// would change with the audio experiment.
  ///
  /// A sound card is keyed by an id that may not survive a reboot on Linux,
  /// so a pick of one also stores the card's [name], and an id no longer
  /// listed finds the one card of that name, as the station's microphone
  /// is found (`matchAudioDevice`). Two cards of one name match neither.
  ///
  /// Only a switch and an audio have ports, a switch's antenna ports and an
  /// audio's channels. One the capability says it does not have resolves
  /// to nothing; one on a switch that has not listed its ports resolves,
  /// since what it has is not known yet and an address stored against it
  /// must survive the switch being off. An audio lists the channels the app
  /// can carry on it, which it always knows.
  ({EquipmentNode? node, Capability capability})? resolveCapability(CapabilityAddress address, {String? name}) {
    final node = nodeFor(address.device);
    if (node == null && address.device != kComputerDevice) return null;
    if (node == null && address.isDevice) return null;
    final offered = capabilitiesOf(address.device);
    // An IQ stream or an audio beside a device's one thing is how that thing
    // is fed, not a second thing: an SDR's id is still its scope.
    final capability = address.isDevice
        ? (offered.firstWhereOrNull((c) => c.kind == kCapabilityReceiver) ??
              offered.where((c) => c.kind != kCapabilityIq && c.kind != kCapabilityAudio).singleOrNull)
        : offered.firstWhereOrNull((c) => c.kind == address.kind && c.key == address.key) ??
              (address.kind == kCapabilityAudio && name != null && name.isNotEmpty
                  ? offered.where((c) => c.kind == kCapabilityAudio && c.name == name).singleOrNull
                  : null);
    if (capability == null) return null;
    if (address.port case final port?) {
      final ports = address.portIsInput! ? capability.inputs : capability.outputs;
      final listed = switch (capability.kind) {
        kCapabilitySwitch => ports.isEmpty || ports.contains(port),
        kCapabilityAudio => ports.contains(port),
        _ => false,
      };
      if (!listed) return null;
    }
    return (node: node, capability: capability);
  }
}

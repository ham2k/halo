// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a configured node offers (docs/design/station-model.md § 4.3): known
// from its catalogue entry and configuration alone, so a picker works with
// the equipment switched off, and corrected by what the equipment says once
// it is on.

import 'capability.dart';
import 'equipment.dart';
import 'equipment_registry.dart';

/// [offered] as one line for a developer: each capability by kind and key,
/// a switch with its ports.
String describeOffers(List<Capability> offered) => [
  for (final capability in offered)
    capability.inputs.isEmpty && capability.outputs.isEmpty
        ? '${capability.kind}:${capability.key}'
        : '${capability.kind}:${capability.key} (in: ${capability.inputs.join(', ')}; out: ${capability.outputs.join(', ')})',
].join(', ');

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
        if (driver.canKeyCwWith(merged)) const Capability(kCapabilityKeyer),
        if (driver.voiceMemoryCountWith(merged) > 0) const Capability(kCapabilityVoice),
        if (driver.so2rAudioReceiverWith(merged) != null) const Capability(kCapabilityAudioMixer),
      ],
      kCategorySdr => const [Capability(kCapabilityScope)],
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

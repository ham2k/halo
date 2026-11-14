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

  /// What [uuid] offers: what its entry declares for its configuration,
  /// corrected by what the equipment has said. Empty for a device that
  /// offers nothing itself (a server, a MIDI controller), and also for a
  /// node this station does not have or whose entry the catalogue no longer
  /// knows: a caller that must tell those apart asks [nodeFor] and
  /// [typeFor] first.
  List<Capability> capabilitiesOf(String uuid) {
    final node = nodeFor(uuid);
    final type = node == null ? null : typeFor(node);
    return node == null || type == null ? const [] : type.offersWith(node.config, stateFor(node.uuid));
  }

  /// The node and capability [address] names, or null when this station has
  /// no such thing. A bare device is its first receiver, or the one thing it
  /// offers when it has no receiver: a rotator's node id is its rotator.
  ///
  /// Only a switch has ports. One the switch says it does not have resolves
  /// to nothing; one on a switch that has not listed its ports resolves,
  /// since what it has is not known yet and an address stored against it
  /// must survive the switch being off.
  ({EquipmentNode node, Capability capability})? resolveCapability(CapabilityAddress address) {
    final node = nodeFor(address.device);
    if (node == null) return null;
    final offered = capabilitiesOf(node.uuid);
    final capability = address.isDevice
        ? (offered.firstWhereOrNull((c) => c.kind == kCapabilityReceiver) ?? offered.singleOrNull)
        : offered.firstWhereOrNull((c) => c.kind == address.kind && c.key == address.key);
    if (capability == null) return null;
    if (address.port case final port?) {
      if (capability.kind != kCapabilitySwitch) return null;
      final ports = address.portIsInput! ? capability.inputs : capability.outputs;
      if (ports.isNotEmpty && !ports.contains(port)) return null;
    }
    return (node: node, capability: capability);
  }
}

// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

part of 'cat_service.dart';

const _k4ConnectionId = 'k4ConnectionId';

extension _K4Nodes on CatService {
  Map<String, String>? _k4LogicalChannelFor(String uuid) {
    final node = _nodes[uuid];
    if (node == null || !_isK4Remote(node)) return null;
    final receiver = _k4Receiver(node);
    return {'key': receiver, 'label': receiver == 'sub' ? t.settings.station.k4ReceiverSub : t.settings.station.k4ReceiverMain};
  }

  void _logK4Sent(String identity, List<int> bytes) {
    final node = _nodes.values.firstWhereOrNull((node) => _isK4Remote(node) && _k4Identity(node) == identity);
    if (node != null) trafficLog?.sent(_logLabel(node.uuid), bytes);
  }

  void _logK4Received(String identity, List<int> bytes) {
    final node = _nodes.values.firstWhereOrNull((node) => _isK4Remote(node) && _k4Identity(node) == identity);
    if (node != null) trafficLog?.received(_logLabel(node.uuid), bytes);
  }

  Set<String> _k4SiblingIds(String? uuid) {
    final device = uuid == null ? null : logicalDeviceIdFor(uuid);
    return {
      if (device != null)
        for (final node in _nodes.values)
          if (logicalDeviceIdFor(node.uuid) == device) node.uuid,
    };
  }

  bool _isK4Remote(EquipmentNode node) {
    final type = typeFor(node);
    return type?.transportKey == K4RemoteTransport.transportKey && type?.driver is KenwoodDriver && (type!.driver as KenwoodDriver).remote;
  }

  // The connection id, apart from the entry's own: it names the shared
  // connection and the keychain entry both receivers use, and for a K4
  // whose Sub was configured first it is that Sub's old id, which now
  // forwards to the Sub ([_Devices._settleDeviceIds]).
  String _k4Identity(EquipmentNode node) {
    final stored = node.config[_k4ConnectionId];
    return stored is String && stored.isNotEmpty ? stored : node.uuid;
  }

  String _k4Receiver(EquipmentNode node) => node.config['receiver'] == 'sub' ? 'sub' : 'main';

  Map<String, dynamic> _k4SharedConfig(Map<String, dynamic> config) => {
    for (final entry in config.entries)
      if (entry.key != 'receiver' && entry.key != _k4ConnectionId && !registry.allSecretFields.contains(entry.key)) entry.key: entry.value,
  };

  /// A remote K4 added is a device of its own, made as its Main
  /// ([_settleDeviceIds] gives it its Sub): its connection is its own, and
  /// so is the keychain entry its password goes in.
  Future<EquipmentNode> _prepareK4Node(EquipmentNode node) async {
    if (!_isK4Remote(node)) return node;
    return node.copyWith(config: {...node.config, _k4ConnectionId: node.uuid, k4ReceiverConfigKey: K4Receiver.main.name});
  }

  Future<void> _updateK4Node(EquipmentNode previous, EquipmentNode edited) async {
    final identity = _k4Identity(previous);
    // Which receiver an entry is never changes: it is part of its id.
    final node = edited.copyWith(config: {...edited.config, _k4ConnectionId: identity, k4ReceiverConfigKey: _k4Receiver(previous)});
    final group = _nodes.values.where((other) => other.uuid == previous.uuid || (_isK4Remote(other) && _k4Identity(other) == identity)).toList();
    final sharedChanged = group.any((other) => !const DeepCollectionEquality().equals(_k4SharedConfig(other.config), _k4SharedConfig(node.config)));
    final secretChanged = registry.allSecretFields.any((key) => node.config[key] is String && (node.config[key] as String).isNotEmpty);
    final typeChanged = previous.typeKey != node.typeKey;
    // Save secrets before disrupting working sessions: a locked keychain
    // cannot turn a failed form save into a radio disconnect.
    final stored = await _stashSecrets(node);
    final affected = sharedChanged || secretChanged || typeChanged ? group : <EquipmentNode>[];
    final reconnect = <String>[];
    for (final other in affected) {
      final status = stateFor(other.uuid).status;
      if (status == EquipmentStatus.connected || status == EquipmentStatus.connecting) reconnect.add(other.uuid);
      await disconnect(other.uuid, byUser: false);
    }
    _nodes[node.uuid] = stored;
    if (sharedChanged || secretChanged) {
      for (final other in group) {
        if (other.uuid == node.uuid) continue;
        _nodes[other.uuid] = other.copyWith(config: {...stored.config, 'receiver': _k4Receiver(other)});
      }
    }
    await _save();
    await Future.wait(reconnect.map(connect));
  }
}

/// Station-editor validation that depends on the configured equipment.
extension CatEquipmentValidation on CatService {
  String? validateEquipmentEditorField(EquipmentType type, EquipmentNode? node, String key, dynamic value, Map<String, dynamic> values) =>
      type.validateEditorField(key, value, values);
}

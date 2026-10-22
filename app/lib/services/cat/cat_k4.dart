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

  // The identity outlives the original Main node: removing Main must leave
  // Sub's credentials usable, including after a restart or a transport edit.
  String _k4Identity(EquipmentNode node) {
    final stored = node.config[_k4ConnectionId];
    return stored is String && stored.isNotEmpty ? stored : node.uuid;
  }

  String _k4Receiver(EquipmentNode node) => node.config['receiver'] == 'sub' ? 'sub' : 'main';

  Map<String, dynamic> _k4SharedConfig(Map<String, dynamic> config) => {
    for (final entry in config.entries)
      if (entry.key != 'receiver' && entry.key != _k4ConnectionId && !registry.allSecretFields.contains(entry.key)) entry.key: entry.value,
  };

  Future<EquipmentNode> _prepareK4Node(EquipmentNode node) async {
    if (!_isK4Remote(node)) return node;
    final type = typeFor(node)!;
    final receiver = _k4Receiver(node);
    final shared = _k4SharedConfig(type.driverConfig(node.config));
    for (final other in _nodes.values) {
      if (!_isK4Remote(other) || _k4Receiver(other) == receiver) continue;
      if (!const DeepCollectionEquality().equals(shared, _k4SharedConfig(typeFor(other)!.driverConfig(other.config)))) continue;
      final identity = _k4Identity(other);
      // An address alone cannot prove that two entries use the same account.
      // Blank means reuse the saved password, exactly as in the editor.
      final entered = node.config['password'];
      if (entered is String && entered.isNotEmpty && entered != await _settings.equipmentSecret(identity, 'password')) continue;
      // Do not put two logical nodes for one receiver in the same group.
      if (_nodes.values.any((candidate) => _isK4Remote(candidate) && _k4Identity(candidate) == identity && _k4Receiver(candidate) == receiver)) continue;
      return node.copyWith(config: {...node.config, _k4ConnectionId: identity, 'receiver': receiver});
    }
    return node.copyWith(config: {...node.config, _k4ConnectionId: node.uuid, 'receiver': receiver});
  }

  Future<void> _updateK4Node(EquipmentNode previous, EquipmentNode edited) async {
    final identity = _k4Identity(previous);
    final node = edited.copyWith(config: {...edited.config, _k4ConnectionId: identity});
    final group = _nodes.values.where((other) => other.uuid == previous.uuid || (_isK4Remote(other) && _k4Identity(other) == identity)).toList();
    final sharedChanged = group.any((other) => !const DeepCollectionEquality().equals(_k4SharedConfig(other.config), _k4SharedConfig(node.config)));
    final secretChanged = registry.allSecretFields.any((key) => node.config[key] is String && (node.config[key] as String).isNotEmpty);
    final receiverChanged = _k4Receiver(previous) != _k4Receiver(node);
    final typeChanged = previous.typeKey != node.typeKey;
    final receiverError = _validateReceiverSelection(node);
    if (receiverError != null) throw ArgumentError(receiverError);
    // Save secrets before disrupting working sessions: a locked keychain
    // cannot turn a failed form save into a radio disconnect.
    final stored = await _stashSecrets(node);
    final affected = sharedChanged || secretChanged || typeChanged
        ? group
        : receiverChanged
        ? [previous]
        : <EquipmentNode>[];
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

/// Station-editor validation that depends on the configured radio inventory.
extension CatEquipmentValidation on CatService {
  String? validateEquipmentEditorField(EquipmentType type, EquipmentNode? node, String key, dynamic value, Map<String, dynamic> values) {
    final error = type.validateEditorField(key, value, values);
    if (error != null) return error;
    if (node == null || key != type.driver.channelKey) return null;
    return _validateReceiverSelection(node.copyWith(typeKey: type.key, config: values));
  }

  /// A receiver already represented by a sibling cannot be selected again.
  /// The editor checks this before closing so the operator can correct it.
  String? _validateReceiverSelection(EquipmentNode edited) {
    final previous = _nodes[edited.uuid];
    if (previous == null || !_isK4Remote(edited)) return null;
    if (previous.typeKey == edited.typeKey && _k4Receiver(previous) == _k4Receiver(edited)) return null;
    final identity = _k4Identity(previous);
    return _nodes.values.any(
          (other) => other.uuid != edited.uuid && _isK4Remote(other) && _k4Identity(other) == identity && _k4Receiver(other) == _k4Receiver(edited),
        )
        ? t.settings.station.k4ReceiverAlreadyConfigured
        : null;
  }
}

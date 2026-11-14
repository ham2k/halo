// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Devices that offer several receivers, rotors or switches, each one an
// entry of its own keyed by its capability's address
// (docs/design/station-model.md § 3, § 4.2 and § 9), and where an id stored
// before that points now.

part of 'cat_service.dart';

/// The namespace of the id [_Devices._settleDeviceIds] makes a K4's Main
/// under, from its connection id. Any fixed uuid: it only has to be the same
/// at every load.
const _k4MainNamespace = 'b4f0f0c2-6a77-4f0c-9d2e-2f8a3c1d4e95';

/// The keys a stored station names a peer's radio under: `peer` in a
/// position and in version 3's `mainVfo`, `remoteRadio1` in version 2.
const _peerKeys = {'peer', 'remoteRadio1'};

extension _Devices on CatService {
  /// The id [node] has as a capability of its device, or null when its own
  /// uuid is that: a remote K4's Sub is `<device>/rx:sub`, where the device
  /// is its Main's id, and an Everyware rotor or switch is
  /// `<server>/rotator:<name>` or `<server>/switch:<name>`.
  ///
  /// A K4's Main keeps its uuid, which is the device's: a bare device id is
  /// its first receiver. An Everyware device's kind in its address is what
  /// it is on the wire, a rotor or a switch box, so a map switch retyped once
  /// the server says what it is keeps its id.
  String? _capabilityIdOf(EquipmentNode node) {
    if (_isK4Remote(node)) {
      if (_k4Receiver(node) == K4Receiver.main.name) return null;
      final device = _k4DeviceOf(_k4Identity(node));
      return device == null ? null : CapabilityAddress(device, kCapabilityReceiver, key: _k4Receiver(node)).toString();
    }
    if (_isEverywareDevice(node)) {
      final server = node.config[everywareServerConfigKey];
      final name = node.config[everywareDeviceConfigKey];
      if (server is! String || server.isEmpty || name is! String || name.isEmpty) return null;
      final kind = node.typeKey == everywareRotorTypeKey ? kCapabilityRotator : kCapabilitySwitch;
      return CapabilityAddress(server, kind, key: name).toString();
    }
    return null;
  }

  /// The id of the remote K4 whose connection is [identity]: its Main's.
  String? _k4DeviceOf(String identity) =>
      _nodes.values.firstWhereOrNull((node) => _isK4Remote(node) && _k4Identity(node) == identity && _k4Receiver(node) == K4Receiver.main.name)?.uuid;

  /// Every node under the id [_capabilityIdOf] gives it, in the order the
  /// station lists them, and every remote K4 with both its receivers: a
  /// Main or a Sub configured alone is the device, and the device has both.
  /// What an entry was called before is forwarded ([_forwardTo]).
  ///
  /// A K4 with only a Sub gets a Main under an id made from its connection
  /// id, never the Sub's old one: that id is forwarded to the Sub, and a
  /// forwarded id is never another entry's. Made the same way at every load,
  /// so a station that is not saved in between gets the same Main again, and
  /// whatever picked it still finds it.
  void _settleDeviceIds() {
    for (final node in [..._nodes.values]) {
      if (!_isK4Remote(node) || _k4DeviceOf(_k4Identity(node)) != null) continue;
      final main = EquipmentNode(
        uuid: uuidGenerator.v5(_k4MainNamespace, _k4Identity(node)),
        typeKey: node.typeKey,
        name: node.name,
        config: {...node.config, k4ReceiverConfigKey: K4Receiver.main.name, _k4ConnectionId: _k4Identity(node)},
      );
      _nodes[main.uuid] = main;
    }
    final withSub = {
      for (final node in _nodes.values)
        if (_isK4Remote(node) && _k4Receiver(node) == K4Receiver.sub.name) _k4Identity(node),
    };
    final settled = <String, EquipmentNode>{};
    for (final node in _nodes.values) {
      final id = _capabilityIdOf(node);
      if (id == null || id == node.uuid || settled.containsKey(id) || _nodes.containsKey(id)) {
        settled[node.uuid] = node;
      } else {
        settled[id] = EquipmentNode(uuid: id, typeKey: node.typeKey, name: node.name, config: node.config);
        _forwardTo(node.uuid, id);
      }
      // A Main configured alone gets its Sub beside it.
      if (_isK4Remote(node) && _k4Receiver(node) == K4Receiver.main.name && withSub.add(_k4Identity(node))) {
        final sub = CapabilityAddress(node.uuid, kCapabilityReceiver, key: K4Receiver.sub.name).toString();
        settled[sub] = EquipmentNode(
          uuid: sub,
          typeKey: node.typeKey,
          name: node.name,
          config: {...node.config, k4ReceiverConfigKey: K4Receiver.sub.name, _k4ConnectionId: _k4Identity(node)},
        );
      }
    }
    // A Main made for a Sub goes where the Sub was, ahead of it.
    final ordered = <String, EquipmentNode>{};
    for (final node in settled.values) {
      if (_isK4Remote(node) && _k4Receiver(node) == K4Receiver.sub.name) {
        final main = settled[CapabilityAddress.parse(node.uuid)?.device];
        if (main != null) ordered.putIfAbsent(main.uuid, () => main);
      }
      ordered.putIfAbsent(node.uuid, () => node);
    }
    _nodes
      ..clear()
      ..addAll(ordered);
  }

  /// Records that [from] now names [to], following any id already forwarded
  /// to [from] on to [to] as well, so a lookup is one step.
  void _forwardTo(String from, String to) {
    for (final entry in _forwarded.entries.toList()) {
      if (entry.value == from) _forwarded[entry.key] = to;
    }
    _forwarded[from] = to;
  }

  /// [json] with every id that was forwarded replaced by what it names now,
  /// in map keys as in values, at any depth. Not under a [_peerKeys] key: a peer's
  /// radio is named by that device's own ids, which this station's forwarding
  /// says nothing about.
  Object? _forwardIds(Object? json) => switch (json) {
    final String id => _forwarded[id] ?? id,
    final Map<dynamic, dynamic> map => {
      for (final MapEntry(:key, :value) in map.entries) _forwardIds(key): _peerKeys.contains(key) ? value : _forwardIds(value),
    },
    final List<dynamic> list => [for (final value in list) _forwardIds(value)],
    _ => json,
  };
}

/// What Station Configuration lists of the devices with several entries.
extension CatDevices on CatService {
  /// The entry listed for the device [id] is part of: a remote K4's Main for
  /// its Sub, [id] itself for everything else.
  String deviceEntryFor(String id) {
    final node = _nodes[id];
    if (node == null || !_isK4Remote(node) || _k4Receiver(node) == K4Receiver.main.name) return id;
    return _k4DeviceOf(_k4Identity(node)) ?? id;
  }

  /// What to call [node] wherever a radio is picked or shown: its device's
  /// name, and which receiver it is when the device has several, as
  /// "K4 · Sub". A QSO's station info takes [CatService.displayNameFor],
  /// the device alone.
  String radioNameFor(EquipmentNode node) {
    final name = displayNameFor(node);
    return switch (logicalChannelFor(node.uuid)?['label']) {
      final receiver? => '$name · $receiver',
      null => name,
    };
  }

  /// Every entry of the device whose listed entry is [id]: a remote K4's
  /// receivers, Main first, and [id] alone for everything else.
  List<String> entriesOf(String id) => [
    id,
    for (final entry in _k4SiblingIds(id))
      if (entry != id) entry,
  ];
}

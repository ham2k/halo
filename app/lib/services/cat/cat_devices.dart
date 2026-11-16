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

/// The namespace of the id a Flex gets, from its address, when no node
/// tracked its slice A: the device is its slice A's entry.
const _flexNamespace = '5d3a8e41-0c7b-4b8e-a6f2-91c4e07d2b63';

/// The slices a Flex last said were open, on its device's settings: what its
/// picker offers while the radio is off, as `{key, label, usedBy}` maps.
const flexKnownSlicesConfigKey = 'flexKnownSlices';

/// The keys a stored station names a peer's radio under: `peer` in a
/// position and in version 3's `mainVfo`, `remoteRadio1` in version 2.
const _peerKeys = {'peer', 'remoteRadio1'};

extension _Devices on CatService {
  /// The id [node] has as a capability of its device, or null when its own
  /// uuid is that: a remote K4's Sub is `<device>/rx:sub`, where the device
  /// is its Main's id, a Flex's slice B is `<device>/rx:1`, where the device
  /// is its slice A's, and an Everyware rotor or switch is
  /// `<server>/rotator:<name>` or `<server>/switch:<name>`.
  ///
  /// A K4's Main and a Flex's slice A keep their uuid, which is the device's:
  /// a bare device id is its first receiver. An Everyware device's kind in its address is what
  /// it is on the wire, a rotor or a switch box, so a map switch retyped once
  /// the server says what it is keeps its id.
  String? _capabilityIdOf(EquipmentNode node) {
    if (_isK4Remote(node)) {
      if (_k4Receiver(node) == K4Receiver.main.name) return null;
      final device = _k4DeviceOf(_k4Identity(node));
      return device == null ? null : CapabilityAddress(device, kCapabilityReceiver, key: _k4Receiver(node)).toString();
    }
    if (_isFlex(node)) {
      final slice = FlexRadioDriver.sliceFromConfig(node.config);
      final address = _flexAddressOf(node);
      if (slice == 0 || address == null) return null;
      final device = _flexDeviceOf(address);
      return device == null ? null : CapabilityAddress(device, kCapabilityReceiver, key: '$slice').toString();
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

  bool _isFlex(EquipmentNode node) => typeFor(node)?.driver is FlexRadioDriver;

  /// Where a Flex node reaches its radio, which is what two slices of one
  /// radio share: its host and port. Null for a node not given a host yet.
  String? _flexAddressOf(EquipmentNode node) {
    final host = node.config['host'];
    if (host is! String || host.trim().isEmpty) return null;
    final port = int.tryParse('${node.config['port'] ?? ''}'.trim()) ?? FlexRadioDriver.defaultPort;
    return '${host.trim().toLowerCase()}:$port';
  }

  /// What every slice of the Flex [node] is part of shares, and so what its
  /// one connection is opened with: the device's connection settings, not
  /// a slice's own (its slice, its computer voice settings).
  Map<String, dynamic> _flexRadioConfig(EquipmentNode node) {
    final device = _nodes[deviceEntryFor(node.uuid)] ?? node;
    final shared = _flexSharedKeys(device);
    return {
      for (final MapEntry(:key, :value) in device.config.entries)
        if (shared.contains(key)) key: value,
    };
  }

  /// The config keys a Flex's slices take from its device: its connection
  /// settings and the driver's, except which slice.
  Set<String> _flexSharedKeys(EquipmentNode device) => switch (typeFor(device)) {
    final type? => {...type.transport.recognizedConfigKeys, ...type.driver.recognizedConfigKeys}..remove(FlexRadioDriver.sliceConfigKey),
    null => const {},
  };

  void _logFlexSent(String address, List<int> bytes) {
    if (_flexDeviceOf(address) case final device?) trafficLog?.sent(_logLabel(device), bytes);
  }

  void _logFlexReceived(String address, List<int> bytes) {
    if (_flexDeviceOf(address) case final device?) trafficLog?.received(_logLabel(device), bytes);
  }

  /// The id of the Flex at [address]: its slice A's entry.
  String? _flexDeviceOf(String address) =>
      _nodes.values.firstWhereOrNull((node) => _isFlex(node) && _flexAddressOf(node) == address && FlexRadioDriver.sliceFromConfig(node.config) == 0)?.uuid;

  /// A Flex's slices reach it as its slice A does: an edit to the device's
  /// connection settings is every slice's, and a slice connected on the old
  /// ones reconnects on the new. Only those: the rest of an entry's config is
  /// its own, as a set's computer voice settings on the radio it logs from
  /// ([KeyingSurface.updateVoiceKeyingConfig]), which copied across would
  /// put set A's sound devices on set B and reconnect set B's slice mid-QSO.
  Future<void> _flexSlicesFollow(String deviceId) async {
    final device = _nodes[deviceId];
    if (device == null || !_isFlex(device)) return;
    final shared = _flexSharedKeys(device);
    for (final id in entriesOf(deviceId).skip(1)) {
      final entry = _nodes[id];
      if (entry == null) continue;
      final config = {
        for (final MapEntry(:key, :value) in entry.config.entries)
          if (!shared.contains(key)) key: value,
        for (final key in shared)
          if (device.config.containsKey(key)) key: device.config[key],
      };
      if (entry.typeKey == device.typeKey && const DeepCollectionEquality().equals(config, entry.config)) continue;
      final status = stateFor(id).status;
      final reconnect = status == EquipmentStatus.connected || status == EquipmentStatus.connecting;
      if (reconnect) await disconnect(id, byUser: false);
      _nodes[id] = EquipmentNode(uuid: id, typeKey: device.typeKey, name: entry.name, config: config);
      if (reconnect) unawaited(connect(id));
    }
  }

  /// A slice of a Flex its connection has settled is not open on the radio
  /// ([FlexRadioSession.cannotTransmit]) goes, when nothing of the
  /// operator's is on it: no set logs from it, no position has picked it,
  /// it has no picks of its own (an antenna, a key) and no settings of its
  /// own (a set's computer voice settings). A slice closed in SmartSDR
  /// leaves no entry behind, and the picker offers it again once it is
  /// open. Slice A never goes, being the radio's own entry; a slice a set
  /// logs from stays, and says it is not open.
  void _flexSliceProblem(String uuid) {
    if (!_flexSliceDisposable(uuid)) return;
    // Not from inside the session's own report: removing disconnects it. And
    // only if still so: the same chunk can close the slice and open it again.
    scheduleMicrotask(() {
      if (!_flexSliceDisposable(uuid)) return;
      trafficLog?.note(_logLabel(uuid), 'slice not open on the radio: entry removed');
      unawaited(_removeOne(uuid));
    });
  }

  bool _flexSliceDisposable(String uuid) {
    final node = _nodes[uuid];
    if (node == null || !_isFlex(node) || deviceEntryFor(uuid) == uuid) return false;
    final notOpen = switch (_runtimes[uuid]?.session) {
      final TransmitGatedSession session => session.cannotTransmit,
      _ => null,
    };
    if (notOpen == null) return false;
    final radio = LocalRadio(uuid);
    if ([kSetA, kSetB].any((set) => _positions.radioOf(set) == radio) || _so2rSwitch == uuid) return false;
    if (_positions.positionOf(radio)?.slots.isNotEmpty ?? false) return false;
    if (_positions.all.any((position) => position.slots.values.contains(uuid))) return false;
    final device = _nodes[deviceEntryFor(uuid)];
    final own = {if (device != null) ..._flexSharedKeys(device), FlexRadioDriver.sliceConfigKey};
    return node.config.keys.every(own.contains);
  }

  /// A Flex entry reported the radio's slices: the open ones are kept on its
  /// device, for the picker to offer while the radio is off. Only on a
  /// change, so the repeats the radio sends write nothing.
  void _flexSlicesAnnounced(String uuid, List<EquipmentChannel> channels) {
    final node = _nodes[uuid];
    if (node == null || !_isFlex(node) || channels.isEmpty) return;
    final deviceId = deviceEntryFor(uuid);
    final device = _nodes[deviceId];
    if (device == null) return;
    final open = [
      for (final channel in channels)
        if (channel.inUse) {'key': channel.key, 'label': channel.label, 'usedBy': ?channel.usedBy, 'holder': ?channel.holder},
    ];
    if (const DeepCollectionEquality().equals(device.config[flexKnownSlicesConfigKey], open)) return;
    _nodes[deviceId] = device.copyWith(config: {...device.config, flexKnownSlicesConfigKey: open});
    unawaited(_save());
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
  /// whatever picked it still finds it. A Flex with no node on slice A gets
  /// one the same way, from its address: the device is its slice A's entry,
  /// whether or not that slice is open.
  void _settleDeviceIds() {
    for (final node in [..._nodes.values]) {
      if (!_isFlex(node)) continue;
      final address = _flexAddressOf(node);
      if (address == null || _flexDeviceOf(address) != null) continue;
      final device = EquipmentNode(
        uuid: uuidGenerator.v5(_flexNamespace, address),
        typeKey: node.typeKey,
        name: node.name,
        config: {...node.config, FlexRadioDriver.sliceConfigKey: '0'},
      );
      _nodes[device.uuid] = device;
    }
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
    // A device made for a receiver goes where that receiver was, ahead of it.
    final ordered = <String, EquipmentNode>{};
    for (final node in settled.values) {
      if (CapabilityAddress.parse(node.uuid) case CapabilityAddress(:final device, kind: kCapabilityReceiver)) {
        if (settled[device] case final listed?) ordered.putIfAbsent(device, () => listed);
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
  /// The entry listed for the device [id] is part of: the device's own for
  /// a receiver addressed under it, a K4's Sub or a Flex's slice B, and [id]
  /// itself for everything else. A second Sub of one K4, which keeps its own
  /// id because the first holds the address, is its Main's too: listed on
  /// its own, removing it would remove the whole K4 ([CatService.removeNode]).
  String deviceEntryFor(String id) => switch (CapabilityAddress.parse(id)) {
    CapabilityAddress(:final device, kind: kCapabilityReceiver) when _nodes.containsKey(device) => device,
    _ => switch (_nodes[id]) {
      final node? when _isK4Remote(node) && _k4Receiver(node) != K4Receiver.main.name => _k4DeviceOf(_k4Identity(node)) ?? id,
      _ => id,
    },
  };

  /// What to call [node] wherever a radio is picked or shown: its device's
  /// name, and which receiver it is when the device has several, as
  /// "K4 · Sub" or "FLEX-6600 · Slice B". A QSO's station info takes
  /// [CatService.displayNameFor], the device alone.
  String radioNameFor(EquipmentNode node) {
    final name = displayNameFor(node);
    if (entriesOf(deviceEntryFor(node.uuid)).length < 2) return name;
    return switch (channelNameFor(node)) {
      final receiver? => '$name · $receiver',
      null => name,
    };
  }

  /// Which receiver of its radio [node] is, as a picker's row says beside
  /// its name: "Sub", "Slice B", or "Slice A on CUBAGUA" for a Flex whose
  /// slices two stations hold ([flexSliceName]). Null for a radio that has
  /// one.
  String? channelNameFor(EquipmentNode node) {
    if (!_isFlex(node)) return typeFor(node)?.describeChannel(node.config);
    return flexSliceName(deviceEntryFor(node.uuid), '${FlexRadioDriver.sliceFromConfig(node.config)}');
  }

  /// Slice [key] of the Flex [deviceId], as the radio letters it and, while
  /// its open slices are held by more than one station, whose it is:
  /// "Slice A on CUBAGUA". Each station letters its own slices from A, so
  /// under multiFLEX two slices are both "Slice A", and the station is what
  /// tells them apart.
  String flexSliceName(String deviceId, String key) {
    final open = _flexOpenSlices(deviceId);
    final letter = open[key]?.label ?? FlexRadioDriver.sliceLabel(int.tryParse(key) ?? 0);
    final holders = {for (final slice in open.values) ?slice.holder};
    return switch (open[key]?.holder) {
      final holder? when holders.length > 1 => t.settings.station.flexSliceOnStation(letter: letter, station: holder),
      _ => t.settings.station.flexSliceLabel(letter: letter),
    };
  }

  /// The slices open on the Flex [deviceId], by key: as a connected entry of
  /// it reports them, or as it last reported them while none is.
  Map<String, EquipmentChannel> _flexOpenSlices(String deviceId) {
    final device = _nodes[deviceId];
    if (device == null || !_isFlex(device)) return const {};
    final live = <String, EquipmentChannel>{
      for (final id in entriesOf(deviceId))
        for (final channel in stateFor(id).channels)
          if (channel.inUse) channel.key: channel,
    };
    if (live.isNotEmpty) return live;
    return {
      if (device.config[flexKnownSlicesConfigKey] case final List<Object?> list)
        for (final slice in list)
          if (slice case {'key': final String key, 'label': final String label})
            key: EquipmentChannel(key: key, label: label, inUse: true, usedBy: slice['usedBy'] as String?, holder: slice['holder'] as String?),
    };
  }

  /// The slices of the Flex [deviceId] a picker can add: those open on the
  /// radio with no entry yet. Empty for anything else.
  List<EquipmentChannel> flexSlicesToAdd(String deviceId) {
    final taken = {for (final id in entriesOf(deviceId)) '${FlexRadioDriver.sliceFromConfig(_nodes[id]?.config ?? const {})}'};
    return [
      for (final channel in _flexOpenSlices(deviceId).values)
        if (!taken.contains(channel.key)) channel,
    ];
  }

  /// Every entry of the device whose listed entry is [id], that one first:
  /// a remote K4's receivers, a Flex's slices, and [id] alone for everything
  /// else.
  List<String> entriesOf(String id) => [
    id,
    for (final node in _nodes.values)
      if (node.uuid != id && deviceEntryFor(node.uuid) == id) node.uuid,
  ];
}

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
      final own = _ownedFlexSlice(node);
      final address = _flexAddressOf(node);
      if ((slice == 0 && own == null) || address == null) return null;
      final device = _flexDeviceOf(address);
      return device == null ? null : CapabilityAddress(device, kCapabilityReceiver, key: own == null ? '$slice' : '$flexOwnSlicePrefix$own').toString();
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
  String? _flexAddressOf(EquipmentNode node) => _flexAddressIn(node.config);

  String? _flexAddressIn(Map<String, dynamic> config) {
    final host = config['host'];
    if (host is! String || host.trim().isEmpty) return null;
    final port = int.tryParse('${config['port'] ?? ''}'.trim()) ?? FlexRadioDriver.defaultPort;
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

  /// What [node]'s connection is opened with: the radio's settings, and for
  /// HaLo's own slice, HaLo's station: the id the radio keeps its slices
  /// by, and the name others see it as.
  Map<String, dynamic> _flexConnectionConfig(EquipmentNode node) => {
    ..._flexRadioConfig(node),
    if (_ownedFlexSlice(node) != null) flexGuiConfigKey: true,
    flexBindConfigKey: ?_flexSliceStation(node),
  };

  /// Which of the radio's connections [node] rides, as its pool key: HaLo's
  /// own station's, the one bound to the station holding its slice, or —
  /// for a slice no station is known to hold yet — the one that binds to
  /// the owner of the first slice it is asked to follow.
  String _flexPoolKey(EquipmentNode node, String address) => switch ((_ownedFlexSlice(node), _flexSliceStation(node))) {
    (_?, _) => '$address#station',
    (null, final station?) => '$address#$station',
    (null, null) => address,
  };

  /// The station holding [node]'s slice, by the radio's id for it, as the
  /// radio last said; null for HaLo's own slice, and for one the radio has
  /// not described as held.
  ///
  /// A slice held by a station the radio has not listed yet (it describes
  /// its slices before its stations as a connection opens) keeps the one it
  /// was last known to be held by: read as held by none, it would move off
  /// its station's connection, and back once the station is listed, at
  /// every connect.
  String? _flexSliceStation(EquipmentNode node) {
    if (_ownedFlexSlice(node) != null) return null;
    final deviceId = deviceEntryFor(node.uuid);
    final key = '${FlexRadioDriver.sliceFromConfig(node.config)}';
    final slice = _flexOpenSlices(deviceId)[key];
    final id = slice != null && slice.heldByUnknown ? _flexKnownHolder(deviceId, key) : slice?.holderId;
    if (slice == null || id == null || id.isEmpty || _isHalos(deviceId, slice)) return null;
    return id;
  }

  /// Who the Flex [deviceId] last said holds slice [key], by its id.
  String? _flexKnownHolder(String deviceId, String key) => switch (_nodes[deviceId]?.config[flexKnownSlicesConfigKey]) {
    final List<Object?> known => known.whereType<Map<Object?, Object?>>().firstWhereOrNull((slice) => slice['key'] == key)?['holderId'] as String?,
    _ => null,
  };

  /// Each connected slice of [deviceId] on a connection other than the one
  /// for its station ([_flexPoolKey]) — one connected before the radio said
  /// whose it is, or whose station changed — connects again, onto its own.
  ///
  /// Only onto a station the radio has named for it: a slice not described
  /// yet, as each connection's refresh arrives one slice at a time, stays
  /// where it is, or every connect would move the others off and back.
  void _flexSlicesRebind(String deviceId) {
    bool moves(String id) {
      final node = _nodes[id];
      final address = node == null ? null : _flexAddressOf(node);
      final station = node == null ? null : _flexSliceStation(node);
      final key = _runtimes[id]?.flexPoolKey;
      final status = stateFor(id).status;
      return address != null &&
          station != null &&
          key != null &&
          key != '$address#$station' &&
          (status == EquipmentStatus.connected || status == EquipmentStatus.connecting);
    }

    // Once the report that said so has reached every entry's state, which
    // is what says whose each slice is; not from inside it, since
    // disconnecting closes the session reporting it; and one after another,
    // since the last to leave the old connection closes it under any still
    // on it. A report while a pass runs asks for another, which looks again.
    final device = _runtimeFor(deviceId);
    device.flexRebindAgain = true;
    if (device.flexRebinding) return;
    device.flexRebinding = true;
    scheduleMicrotask(() async {
      try {
        while (device.flexRebindAgain) {
          device.flexRebindAgain = false;
          for (final id in entriesOf(deviceId).where(moves).toList()) {
            try {
              if (_runtimes[id]?.userDisconnected ?? true) continue;
              await disconnect(id, byUser: false);
              // The operator's Disconnect during the teardown stands.
              if (_runtimes[id]?.userDisconnected ?? true) continue;
              await connect(id);
            } catch (e, st) {
              ErrorReportingService.report(e, st, context: 'cat:flex-rebind:$id');
            }
          }
        }
      } finally {
        device.flexRebinding = false;
      }
    });
  }

  /// The config keys a Flex's connection is opened with: its transport's
  /// and the driver's, except which slice.
  Set<String> _flexSharedKeys(EquipmentNode device) => switch (typeFor(device)) {
    final type? => {...type.transport.recognizedConfigKeys, ...type.driver.recognizedConfigKeys}..remove(FlexRadioDriver.sliceConfigKey),
    null => const {},
  };

  /// The config keys a Flex's slices take from its device: [_flexSharedKeys],
  /// and how far behind its audio may fall when it is heard in HaLo, which
  /// the radio's editor sets for all of them.
  Set<String> _flexFollowedKeys(EquipmentNode device) => {..._flexSharedKeys(device), receiveAudioDelayConfigKey};

  /// What a new slice entry of [device] takes from it.
  Map<String, dynamic> _flexFollowedConfig(EquipmentNode device) {
    final followed = _flexFollowedKeys(device);
    return {
      for (final MapEntry(:key, :value) in device.config.entries)
        if (followed.contains(key)) key: value,
    };
  }

  /// A pool key names the radio, and after a `#` the station a connection
  /// is for: HaLo's own, or the one it is bound to.
  void _logFlexSent(String key, List<int> bytes) {
    if (_flexDeviceOf(key.split('#').first) case final device?) trafficLog?.sent(_logLabel(device), bytes);
  }

  void _logFlexReceived(String key, List<int> bytes) {
    if (_flexDeviceOf(key.split('#').first) case final device?) trafficLog?.received(_logLabel(device), bytes);
  }

  /// The letter of HaLo's own slice [node] is, on HaLo's station on the
  /// radio; null for a slice another station holds.
  String? _ownedFlexSlice(EquipmentNode node) => switch (node.config[flexOwnSliceConfigKey]) {
    final String letter when letter.isNotEmpty => letter,
    _ => null,
  };

  /// Whether [slice] of the Flex [deviceId] is held by HaLo's own station:
  /// by the radio's id for it, since SmartSDR on the same computer goes by
  /// the same station name.
  bool _isHalos(String deviceId, EquipmentChannel slice) {
    final id = _nodes[deviceId]?.config[flexClientIdConfigKey];
    return id is String && id.isNotEmpty && slice.holderId == id;
  }

  /// What HaLo's station on a Flex is called: this computer's name, with
  /// anything the radio's status could not carry (a space) made a dash.
  String _flexStationOf(EquipmentNode? device) {
    final given = device?.config[flexStationNameConfigKey];
    final name = (given is String && given.trim().isNotEmpty ? given : resolvedDeviceIdentity?.name ?? '').trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-');
    return name.isEmpty ? flexProgramName : name;
  }

  /// The station name for a station connection opened with [config]: read
  /// as it opens, as the station's id is ([_flexStationOpened]).
  String? _flexStationIn(Map<String, dynamic> config) {
    if (config[flexGuiConfigKey] != true) return null;
    final address = _flexAddressIn(config);
    return _flexStationOf(address == null ? null : _nodes[_flexDeviceOf(address)]);
  }

  /// What an edit to [node]'s settings asks of what is live: its audio
  /// reconnected, its station renamed.
  void _deviceSettingsEdited(EquipmentNode previous, EquipmentNode node) {
    _audioSettingsEdited(previous, node);
    _flexStationEdited(previous, node);
  }

  /// What the radio keeps for HaLo's station, kept through an edit: the
  /// editor saves the settings it read as it opened, and a station
  /// registered since would otherwise lose the id its slices are kept by,
  /// and the sweeps' pans it left would never be removed.
  EquipmentNode _flexKeepStationRecord(EquipmentNode current, EquipmentNode edited) {
    if (!_isFlex(edited)) return edited;
    final kept = {
      for (final key in const [flexClientIdConfigKey, flexSweepPansConfigKey])
        if (current.config[key] case final value? when edited.config[key] == null) key: value,
    };
    return kept.isEmpty ? edited : edited.copyWith(config: {...edited.config, ...kept});
  }

  /// A Flex renamed for this computer is renamed on the radio at once, on
  /// HaLo's station's live connection.
  void _flexStationEdited(EquipmentNode previous, EquipmentNode node) {
    if (!_isFlex(node) || previous.config[flexStationNameConfigKey] == node.config[flexStationNameConfigKey]) return;
    final name = _flexStationOf(node);
    for (final id in _flexOwnedEntries(deviceEntryFor(node.uuid))) {
      if (_runtimes[id]?.session case final FlexRadioSession session) session.renameStation(name);
    }
  }

  /// A Flex's connection, with what its device keeps for HaLo's station:
  /// read as the connection opens, not from a lease's settings, since the
  /// radio gives it after the first lease asked.
  FlexRadio _flexStationOpened(Map<String, dynamic> config, void Function(List<int>) send) {
    final address = config[flexGuiConfigKey] == true ? _flexAddressIn(config) : null;
    final kept = address == null ? null : _nodes[_flexDeviceOf(address)]?.config;
    return FlexRadio.fromConfig(
      config,
      send: send,
      clientId: switch (kept?[flexClientIdConfigKey]) {
        final String id when id.isNotEmpty => id,
        _ => null,
      },
      station: _flexStationIn(config),
      onClientId: (id) => _flexDeviceKeeps(config, flexClientIdConfigKey, id),
      sweepPans: [...?(kept?[flexSweepPansConfigKey] as List?)?.whereType<String>()],
      onSweepPans: (pans) => _flexDeviceKeeps(config, flexSweepPansConfigKey, pans.isEmpty ? null : pans),
    );
  }

  /// [value] kept on the device entry of the Flex a connection opened with
  /// [config] is to, so the next connection reads it.
  void _flexDeviceKeeps(Map<String, dynamic> config, String key, Object? value) {
    final address = _flexAddressIn(config);
    final device = address == null ? null : _flexDeviceOf(address);
    final node = device == null ? null : _nodes[device];
    if (node == null || const DeepCollectionEquality().equals(node.config[key], value)) return;
    _nodes[node.uuid] = node.copyWith(config: {...node.config, key: value}..removeWhere((k, v) => k == key && v == null));
    unawaited(_save());
  }

  /// The id of the Flex at [address]: its slice A's entry.
  String? _flexDeviceOf(String address) => _nodes.values
      .firstWhereOrNull(
        (node) => _isFlex(node) && _flexAddressOf(node) == address && FlexRadioDriver.sliceFromConfig(node.config) == 0 && _ownedFlexSlice(node) == null,
      )
      ?.uuid;

  /// A Flex's slices reach it as its slice A does: an edit to the device's
  /// connection settings, or to its audio's buffering, is every slice's, and a
  /// slice connected on the old ones reconnects on the new. Only those
  /// ([_flexFollowedKeys]): the rest of an entry's config is
  /// its own, as a set's computer voice settings on the radio it logs from
  /// ([KeyingSurface.updateVoiceKeyingConfig]), which copied across would
  /// put set A's sound devices on set B and reconnect set B's slice mid-QSO.
  Future<void> _flexSlicesFollow(String deviceId) async {
    final device = _nodes[deviceId];
    if (device == null || !_isFlex(device)) return;
    final shared = _flexFollowedKeys(device);
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
      // Only for what the slice's connection is made with: a change to how
      // its audio is buffered is no reason to drop a slice nobody hears here.
      final connectionChanged =
          entry.typeKey != device.typeKey ||
          _flexSharedKeys(device).any((key) => config[key] != entry.config[key]) ||
          (_audioDiffers(entry.config, config) && (hearsInHalo(id) || talksThroughHalo(id)));
      final reconnect = connectionChanged && (status == EquipmentStatus.connected || status == EquipmentStatus.connecting);
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
    // HaLo's own slices close only when the operator closes them.
    if (node == null || !_isFlex(node) || deviceEntryFor(uuid) == uuid || _ownedFlexSlice(node) != null) return false;
    // Closed on the radio, and not merely kept from transmitting: a slice
    // waiting for its station's connection is open, and goes nowhere.
    final closed = switch (_runtimes[uuid]?.session) {
      final FlexRadioSession session => session.sliceClosed,
      _ => false,
    };
    if (!closed) return false;
    final radio = LocalRadio(uuid);
    if ([kSetA, kSetB].any((set) => _positions.radioOf(set) == radio) || _so2rSwitch == uuid) return false;
    if (_positions.positionOf(radio)?.slots.isNotEmpty ?? false) return false;
    if (_positions.all.any((position) => position.slots.values.contains(uuid))) return false;
    final device = _nodes[deviceEntryFor(uuid)];
    final own = {if (device != null) ..._flexFollowedKeys(device), FlexRadioDriver.sliceConfigKey};
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
        if (channel.inUse) {'key': channel.key, 'label': channel.label, 'usedBy': ?channel.usedBy, 'holder': ?channel.holder, 'holderId': ?channel.holderId},
    ];
    // Not while a slice names a station the radio has not listed yet: that
    // is the radio still opening the connection, not saying nobody holds it.
    if (channels.any((channel) => channel.inUse && channel.heldByUnknown)) return;
    if (const DeepCollectionEquality().equals(device.config[flexKnownSlicesConfigKey], open)) return;
    _nodes[deviceId] = device.copyWith(config: {...device.config, flexKnownSlicesConfigKey: open});
    unawaited(_save());
    _flexSlicesRebind(deviceId);
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
    // HaLo's own slice is named by its letter alone: it is this computer's.
    if (_ownedFlexSlice(node) case final letter?) return t.settings.station.flexSliceLabel(letter: letter);
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
    // HaLo's own station goes by this computer's name, as SmartSDR on it
    // does: beside it, another's slice says whose it is, even when theirs
    // is the only other station.
    final halosOpen = open.values.any((slice) => _isHalos(deviceId, slice));
    return switch (open[key]) {
      // HaLo's own, by its letter alone: it is this computer's.
      final slice? when _isHalos(deviceId, slice) => t.settings.station.flexSliceLabel(letter: letter),
      EquipmentChannel(:final holder?) when holders.length > 1 || halosOpen => t.settings.station.flexSliceOnStation(letter: letter, station: holder),
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
            key: EquipmentChannel(
              key: key,
              label: label,
              inUse: true,
              usedBy: slice['usedBy'] as String?,
              holder: slice['holder'] as String?,
              holderId: slice['holderId'] as String?,
            ),
    };
  }

  /// Slice [key] of the Flex [deviceId] as an entry of it, made now if it
  /// has none: picking an open slice is what adds it. Answers its id, or
  /// null when the device is gone, which leaves nothing to pick. Listed
  /// after the device's other entries, where the picker offered it, and
  /// connected when the radio is: it joins the radio's one connection, as
  /// the radio's plug opens every slice.
  ///
  /// A slice HaLo's own station holds — one the radio brought back from
  /// HaLo's last connection — is added as HaLo's, by its letter.
  Future<String?> addFlexSlice(String deviceId, String key) async {
    final open = _flexOpenSlices(deviceId)[key];
    if (open != null && _isHalos(deviceId, open) && _flexOwnedEntries(deviceId).isNotEmpty) {
      return _addFlexEntry(deviceId, '$flexOwnSlicePrefix${open.label}', {flexOwnSliceConfigKey: open.label});
    }
    return _addFlexEntry(deviceId, key, {FlexRadioDriver.sliceConfigKey: key});
  }

  Future<String?> _addFlexEntry(String deviceId, String key, Map<String, dynamic> own) async {
    final id = CapabilityAddress(deviceId, kCapabilityReceiver, key: key).toString();
    final device = _nodes[deviceId];
    if (device == null) return null;
    if (_nodes.containsKey(id)) return id;
    final after = entriesOf(deviceId).last;
    final nodes = [..._nodes.values];
    _nodes.clear();
    for (final node in nodes) {
      _nodes[node.uuid] = node;
      if (node.uuid == after) {
        _nodes[id] = EquipmentNode(
          uuid: id,
          typeKey: device.typeKey,
          name: device.name,
          // The radio's settings, not slice A's own: a set's computer voice
          // settings on slice A are not this slice's.
          config: {..._flexFollowedConfig(device), ...own},
        );
      }
    }
    await _save();
    _changed();
    if (_flexLive(deviceId)) unawaited(connect(id));
    return id;
  }

  bool _flexLive(String deviceId) =>
      entriesOf(deviceId).any((entry) => const {EquipmentStatus.connected, EquipmentStatus.connecting}.contains(stateFor(entry).status));

  List<String> _flexOwnedEntries(String deviceId) => [
    for (final id in entriesOf(deviceId))
      if (_nodes[id] case final node? when _ownedFlexSlice(node) != null) id,
  ];

  /// How many more slices the Flex [deviceId] can open, as a connected
  /// entry of it last heard the radio say; null while none is connected.
  int? flexFreeSlices(String deviceId) {
    for (final id in entriesOf(deviceId)) {
      if (_runtimes[id]?.session case final FlexRadioSession session when stateFor(id).status == EquipmentStatus.connected) {
        if (session.freeSlices case final free?) return free;
      }
    }
    return null;
  }

  /// A new slice on HaLo's own station on the Flex [deviceId], added as an
  /// entry of it, and its id: null when the radio would not open one.
  ///
  /// HaLo's first slice is the one the radio opens for its station as it
  /// registers, so it needs no panadapter of its own. That one is HaLo's
  /// "A" only on a station the radio has nothing kept for: one it brings
  /// back may have only other letters, and then a slice is opened, and the
  /// entry goes by the letter the radio gives it.
  Future<String?> openFlexSlice(String deviceId) async {
    final owned = _flexOwnedEntries(deviceId);
    if (owned.isEmpty) {
      final first = await _addFlexEntry(deviceId, '${flexOwnSlicePrefix}A', {flexOwnSliceConfigKey: 'A'});
      if (first == null) return null;
      if (await _flexSliceResolved(first)) return first;
      final letter = await _flexStationSession(first)?.openSlice();
      if (letter == 'A') return first;
      if (letter == null) {
        // Kept, it reads as a missing slice the operator cannot close, and
        // registers HaLo on the radio again at every launch.
        await _removeOne(first);
        return null;
      }
      final id = await _addFlexEntry(deviceId, '$flexOwnSlicePrefix$letter', {flexOwnSliceConfigKey: letter});
      await _removeOne(first);
      return id;
    }
    final station = owned.first;
    if (stateFor(station).status != EquipmentStatus.connected) await connect(station);
    final letter = await _flexStationSession(station)?.openSlice();
    return letter == null ? null : _addFlexEntry(deviceId, '$flexOwnSlicePrefix$letter', {flexOwnSliceConfigKey: letter});
  }

  FlexRadioSession? _flexStationSession(String id) => switch (_runtimes[id]?.session) {
    final FlexRadioSession session => session,
    _ => null,
  };

  /// Whether HaLo's own slice [id] has a number on the radio, given the
  /// time its station takes to register and hear back.
  Future<bool> _flexSliceResolved(String id) async {
    for (var waited = Duration.zero; waited < const Duration(seconds: 5); waited += const Duration(milliseconds: 100)) {
      if ((_flexStationSession(id)?.slice ?? -1) >= 0) return true;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return false;
  }

  /// Closes HaLo's own slice [id] on the radio, with the panadapter it came
  /// with, and removes its entry; false, with the entry kept, when the
  /// radio did not close it.
  ///
  /// Only over its connection: the radio keeps HaLo's slices by its
  /// station's id, so an entry removed without the radio having closed it
  /// would leave the slice open there, taking one of the few it has.
  Future<bool> closeFlexSlice(String id) async {
    if (!canCloseFlexSlice(id)) return false;
    if (!await _flexStationSession(id)!.closeSlice()) return false;
    await _removeOne(id);
    return true;
  }

  /// Whether [id] is a slice of HaLo's own station that the radio has
  /// described on a live connection, so the operator can close it there.
  bool canCloseFlexSlice(String id) => switch (_nodes[id]) {
    final node? => _ownedFlexSlice(node) != null && stateFor(id).status == EquipmentStatus.connected && (_flexStationSession(id)?.slice ?? -1) >= 0,
    null => false,
  };

  /// The slices of the Flex [deviceId] a picker can add: those open on the
  /// radio with no entry yet. Empty for anything else.
  List<EquipmentChannel> flexSlicesToAdd(String deviceId) {
    final taken = {
      for (final id in entriesOf(deviceId))
        if (_nodes[id] case final node? when _ownedFlexSlice(node) == null) '${FlexRadioDriver.sliceFromConfig(node.config)}',
    };
    final ownTaken = {for (final id in _flexOwnedEntries(deviceId)) _ownedFlexSlice(_nodes[id]!)};
    return [
      for (final channel in _flexOpenSlices(deviceId).values)
        if (!taken.contains(channel.key) && !(_isHalos(deviceId, channel) && ownTaken.contains(channel.label))) channel,
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

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A Green Heron Everyware server and the device nodes under it
// (docs/design/cat.md § Green Heron Everyware): the one node in the station
// that has others hanging off it.
//
// The server node owns the connection; each rotor or switch the operator
// ticked in its editor is a node of its own, which every panel treats like
// any other rotator or switch. A device node has no connection of its own
// and follows its server's: up when the server comes up, down when it goes,
// and its Connect and Disconnect are the server's.

part of 'cat_service.dart';

/// A device node asked to connect while its server is not — a race with the
/// server dropping, as unreachable as a switched-off radio.
class EverywareServerNotConnected implements CatUnreachable {
  const EverywareServerNotConnected();

  @override
  String toString() => t.settings.station.everywareServerOffline;
}

/// Per service, the reconcile each server's last one is waiting behind: two
/// running at once would each add the same missing device, or retype one
/// node twice.
final _everywareReconciles = Expando<Map<String, Future<void>>>();

extension _CatEveryware on CatService {
  bool _isEverywareServer(EquipmentNode node) => typeFor(node)?.transportKey == EverywareServerTransport.transportKey;

  bool _isEverywareDevice(EquipmentNode node) => typeFor(node)?.transportKey == EverywareDeviceTransport.transportKey;

  /// The server [uuid] hangs off, when it is a device node whose server is
  /// still configured.
  String? _everywareServerOf(String uuid) {
    final node = _nodes[uuid];
    if (node == null || !_isEverywareDevice(node)) return null;
    final server = node.config[everywareServerConfigKey];
    return server is String && _nodes.containsKey(server) ? server : null;
  }

  List<EquipmentNode> _everywareDevicesOf(String serverUuid) => [
    for (final node in _nodes.values)
      if (_isEverywareDevice(node) && node.config[everywareServerConfigKey] == serverUuid) node,
  ];

  /// A directional switch is a rotator here and a switch on the wire, so the
  /// kind is the node type's, not its category's.
  String _everywareDeviceKeyOf(EquipmentNode device) => everywareDeviceKey(
    device.typeKey == everywareRotorTypeKey ? EverywareDeviceKind.rotor : EverywareDeviceKind.switchBox,
    device.config[everywareDeviceConfigKey] as String? ?? '',
  );

  /// The node type for device [key] on [serverUuid] — a rotor's, a map
  /// switch's or a plain switch's — from what the server has announced on
  /// this connection, or with [orRemembered], from what it last announced.
  /// Null when neither has said.
  String? _everywareTypeKeyFor(String serverUuid, String key, EverywareDeviceKind kind, {bool orRemembered = false}) {
    if (kind == EverywareDeviceKind.rotor) return everywareRotorTypeKey;
    final live = stateFor(serverUuid).channels.where((device) => device.key == key).firstOrNull;
    Object? said = live == null ? null : live.mode ?? '';
    final known = _nodes[serverUuid]?.config[everywareKnownDevicesConfigKey];
    if (said == null && orRemembered && known is List) {
      for (final device in known.whereType<Map<Object?, Object?>>()) {
        if (device['key'] == key) said = device['kind'] ?? '';
      }
    }
    if (said == null) return null;
    return said == EverywareSwitchKind.map.name ? everywareDirectionalTypeKey : everywareSwitchTypeKey;
  }

  /// Whether server [serverUuid] is up and has announced something: what a
  /// device waits for before coming up ([_everywareDevicesAnnounced]).
  bool _everywareServerAnnounced(String serverUuid) =>
      _runtimes[serverUuid]?.session is EverywareServerSession && _runtimes[serverUuid]?.connection != null && stateFor(serverUuid).channels.isNotEmpty;

  /// A device's Connect while its server has not announced yet: the server's
  /// Connect, unless the server is already up or on its way — reconnecting it
  /// then would restart its login and drop every other device, and the device
  /// comes up with the server's first announcement anyway. Once the server
  /// announces, a device's Connect brings up that device alone.
  Future<void> _connectEverywareServer(String serverUuid) async {
    final status = stateFor(serverUuid).status;
    if (status == EquipmentStatus.connected || status == EquipmentStatus.connecting) return;
    await connect(serverUuid);
  }

  /// Server [previous] saved as [node]: what it announced is kept as the
  /// service has it now — [previous] read after the save's awaits — not as
  /// the editor read it when it opened, or an announcement since would be
  /// undone by the save.
  EquipmentNode _everywareKeepAnnounced(EquipmentNode previous, EquipmentNode node) {
    if (!_isEverywareServer(previous) || !previous.config.containsKey(everywareKnownDevicesConfigKey)) return node;
    return node.copyWith(config: {...node.config, everywareKnownDevicesConfigKey: previous.config[everywareKnownDevicesConfigKey]});
  }

  /// A device node's connection: its share of the server's.
  EquipmentConnection _everywareDeviceConnection(EquipmentNode device) {
    final server = device.config[everywareServerConfigKey];
    final runtime = server is String ? _runtimes[server] : null;
    final session = runtime?.session;
    if (session is! EverywareServerSession || runtime?.connection == null) throw const EverywareServerNotConnected();
    return session.openDevice(_everywareDeviceKeyOf(device));
  }

  /// After [uuid] is saved: a server's device nodes become what its editor
  /// ticked, and a connected device picks up its own edit — whether it
  /// follows the radio is read when its session starts, and a new session
  /// is only a new share of the server's connection.
  Future<void> _everywareNodeSaved(String uuid) async {
    final node = _nodes[uuid];
    if (node != null && _isEverywareDevice(node) && _runtimes[uuid]?.connection != null) await _connect(uuid);
    await _reconcileEverywareDevices(uuid);
  }

  /// Makes the server's device nodes what its editor ticked: a node for each
  /// ticked device without one, and none for a device unticked. One at a time
  /// per server ([_everywareReconciles]).
  ///
  /// Keyed by kind and name, so a device the server renamed is a new node
  /// and the old one goes — the server's name is the only identity a device
  /// has on the wire.
  Future<void> _reconcileEverywareDevices(String serverUuid) {
    final chains = _everywareReconciles[this] ??= {};
    final next = (chains[serverUuid] ?? Future<void>.value()).then((_) => _reconcileEverywareDevicesNow(serverUuid));
    // The next one waits for this one, however it ends; its own caller hears
    // how.
    chains[serverUuid] = next.then((_) {}, onError: (Object _) {});
    return next;
  }

  Future<void> _reconcileEverywareDevicesNow(String serverUuid) async {
    final server = _nodes[serverUuid];
    if (server == null || !_isEverywareServer(server)) return;
    final ticked = server.config[everywareDevicesConfigKey];
    final wanted = {if (ticked is List) ...ticked.whereType<String>()};
    final existing = {for (final device in _everywareDevicesOf(serverUuid)) _everywareDeviceKeyOf(device): device};
    for (final MapEntry(:key, value: device) in existing.entries.toList()) {
      if (!wanted.contains(key)) {
        existing.remove(key);
        await removeNode(device.uuid);
        continue;
      }
      // Made as a kind it turned out not to be — a map switch ticked before
      // the server said it was one — and retyped where it stands: the same
      // node, so its name, its links and every panel pointed at it stay.
      // Only once this connection has announced it: the server announces one
      // device at a time, and a device not yet announced is not a different
      // kind, only not said yet.
      final parsed = parseEverywareDeviceKey(key);
      final typeKey = parsed == null ? null : _everywareTypeKeyFor(serverUuid, key, parsed.kind);
      if (typeKey == null || device.typeKey == typeKey) continue;
      await updateNode(device.copyWith(typeKey: typeKey));
      if (_everywareServerAnnounced(serverUuid)) unawaited(_connect(device.uuid));
    }
    for (final key in wanted) {
      if (existing.containsKey(key)) continue;
      final parsed = parseEverywareDeviceKey(key);
      // A stack is listed for the operator to see, never made a node: nothing
      // here can drive several antennas at once.
      if (parsed == null || parsed.kind == EverywareDeviceKind.stack) continue;
      final device = await addNode(
        typeKey: _everywareTypeKeyFor(serverUuid, key, parsed.kind, orRemembered: true) ?? everywareSwitchTypeKey,
        name: parsed.name.trim(),
        config: {everywareServerConfigKey: serverUuid, everywareDeviceConfigKey: parsed.name},
      );
      if (_everywareServerAnnounced(serverUuid)) unawaited(_connect(device.uuid));
    }
  }

  /// Before [uuid] is removed. A server's devices go with it: nothing else
  /// could ever reach them. A device removed on its own is unticked on its
  /// server, or the server's next save would bring it straight back.
  Future<void> _everywareNodeRemoving(String uuid) async {
    for (final device in _everywareDevicesOf(uuid)) {
      await removeNode(device.uuid);
    }
    final device = _nodes[uuid];
    final serverUuid = _everywareServerOf(uuid);
    if (device == null || serverUuid == null) return;
    final server = _nodes[serverUuid]!;
    final ticked = server.config[everywareDevicesConfigKey];
    final key = _everywareDeviceKeyOf(device);
    if (ticked is! List || !ticked.contains(key)) return;
    _nodes[serverUuid] = server.copyWith(
      config: {
        ...server.config,
        everywareDevicesConfigKey: [...ticked.where((other) => other != key)],
      },
    );
  }

  /// Server [uuid] announced a device. Its device nodes come up now rather
  /// than when the socket opened: a server that refuses the login announces
  /// nothing, and a device up before that would read connected to nothing
  /// while the reason sat on the server's row.
  ///
  /// And what it announced is kept on its node, for its editor to list while
  /// it is not connected, and for a device's kind to be known before it is
  /// next announced. Merged into what was kept rather than replacing it: a
  /// connect announces one device at a time, and a list replaced at each
  /// would be written ever longer on every connect, and left short by a link
  /// dropped part-way. Only a device the server withdrew — announced, then
  /// gone from [channels] — leaves it. Called before [channels] replaces the
  /// node's live list, which is what tells a withdrawal from a device not
  /// announced yet. Only on a change, so the repeats a server sends write
  /// nothing.
  void _everywareDevicesAnnounced(String uuid, List<EquipmentChannel> channels) {
    final node = _nodes[uuid];
    if (node == null || !_isEverywareServer(node)) return;
    // Empty is the server withdrawing its last device: nothing to bring up,
    // but that device still leaves the list below.
    for (final device in channels.isEmpty ? const <EquipmentNode>[] : _everywareDevicesOf(uuid)) {
      final status = stateFor(device.uuid).status;
      if (status != EquipmentStatus.connected && status != EquipmentStatus.connecting) unawaited(_connect(device.uuid));
    }
    final announced = {for (final device in channels) device.key};
    final withdrawn = {
      for (final device in stateFor(uuid).channels)
        if (!announced.contains(device.key)) device.key,
    };
    final kept = node.config[everywareKnownDevicesConfigKey];
    final known = [
      for (final device in channels) {'key': device.key, 'kind': ?device.mode},
      if (kept is List)
        for (final device in kept.whereType<Map<Object?, Object?>>())
          if (device['key'] case final String key when !announced.contains(key) && !withdrawn.contains(key)) {'key': key, 'kind': ?device['kind']},
    ];
    if (const DeepCollectionEquality().equals(node.config[everywareKnownDevicesConfigKey], known)) return;
    _nodes[uuid] = node.copyWith(config: {...node.config, everywareKnownDevicesConfigKey: known});
    unawaited(_save());
    // What the server now says a device is can make a node made before it
    // said so the wrong kind — a map switch made a plain switch.
    unawaited(_reconcileEverywareDevices(uuid));
  }

  /// A switch moving by itself waits out a transmission, as one the operator
  /// picks does ([CatService.selectAntenna]): a relay thrown under RF is
  /// what destroys one. Not queued for after: the next band or call change
  /// asks again, and a selection made late is not worth a stale one.
  bool get _everywareHeldByTransmit => radio1IsTransmitting || _nodeTransmitting(radio2);

  /// Radio A — or SO2R's Radio B, with [radioB] — moved: every band switch
  /// that follows that radio picks the position for the new frequency.
  void _followEverywareFrequency(double freqKHz, {required bool radioB}) {
    if (_everywareHeldByTransmit) return;
    for (final runtime in _runtimes.values) {
      if (runtime.session case final FrequencyFollower follower) follower.followFrequency(freqKHz, radioB: radioB);
    }
  }
}

/// What the operation's panels can ask of the Everyware switches.
extension CatEverywareSteering on CatService {
  /// Whether [CatService.rotateTo] holds [uuid]'s turn for RF: a directional
  /// switch "turns" by throwing relays, held as an antenna switch's
  /// selection is ([CatService.selectAntenna]).
  bool rotationHeldByTransmit(String uuid) => _runtimes[uuid]?.session is EverywareDirectionalSession && _everywareHeldByTransmit;

  /// The station being worked is [bearing] true degrees from here: every map
  /// switch whose node follows it points the nearest way.
  void pointEverywareSwitchesToward(int bearing) {
    if (_everywareHeldByTransmit) return;
    for (final runtime in _runtimes.values) {
      if (runtime.session case final BearingFollower follower) follower.followBearing(bearing);
    }
  }
}

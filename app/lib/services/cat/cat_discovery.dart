// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Equipment that announces itself on the network, offered for the Add dialog
// to pick from without typing an address.

part of 'cat_service.dart';

mixin _Discovery on ChangeNotifier {
  EquipmentRegistry get registry;
  Map<String, EquipmentNode> get _nodes;

  final Map<String, DiscoveredEquipment> _discovered = {};
  final List<StreamSubscription<DiscoveredEquipment>> _discoverySubscriptions = [];

  /// Equipment that has announced itself and isn't configured yet, newest
  /// announcement wins. Already-configured equipment is filtered out — the
  /// point of the list is what you could still add.
  ///
  /// "Configured" is per CHANNEL, not per radio, for equipment that has
  /// several ([EquipmentDriver.channelKey]): a FlexRadio with only slice A
  /// set up is still something you could add, and dropping it from the list
  /// after the first add is what would make the second slice reachable only
  /// by typing the address in by hand. Each offer carries the lowest channel
  /// not yet spoken for, so accepting one twice does not produce two nodes
  /// on the same slice.
  List<DiscoveredEquipment> get discovered {
    final configured = <String>{};
    for (final node in _nodes.values) {
      final type = registry.typeFor(node.typeKey);
      if (type != null) configured.add(_targetKey(type, node.config));
    }
    return [for (final found in _discovered.values) ?_offerFor(found, configured)];
  }

  /// [found] as it should be added next, or null when every channel it
  /// offers is already configured.
  DiscoveredEquipment? _offerFor(DiscoveredEquipment found, Set<String> configured) {
    final type = registry.typeFor(found.typeKey);
    if (type == null) return configured.contains(_discoveryKey(found)) ? null : found;

    final channelKey = type.driver.channelKey;
    // Single-channel equipment: one target is one node, as it always was.
    if (channelKey == null) {
      return configured.contains(_targetKeyFor(found)) ? null : found;
    }

    // A discovered device carries only what the announcement said, so the
    // type's own prefill is what decides which channel "no channel named"
    // means — the same merge the Add form opens with.
    final base = {...type.defaultConfig, ...found.config};
    for (final value in type.driver.channelValues) {
      final config = {...base, channelKey: value};
      if (configured.contains(_targetKey(type, config))) continue;
      final suffix = type.driver.describeSuffix(config, overrides: type.variant.overrides);
      return DiscoveredEquipment(
        typeKey: found.typeKey,
        // The channel is part of what this offer IS: two rows for the same
        // radio would otherwise collapse into one in any id-keyed list, and
        // the second slice would be unofferable again.
        id: '${found.id}|$channelKey=$value',
        // Named for its channel from the SECOND one on. The first keeps the
        // radio's own name: a shack with one Flex on slice A should not have
        // its name grow a suffix it never asked for.
        name: value == type.driver.channelValues.first || suffix == null ? found.name : '${found.name}$suffix',
        detail: found.detail,
        config: config,
      );
    }
    return null;
  }

  /// What makes two nodes the same thing: where the equipment is, plus which
  /// of its channels the node tracks. [config] contributes only the driver's
  /// [EquipmentDriver.channelKey], never the rest — a node differing in baud
  /// rate or CI-V address is still the same radio on the same port.
  ///
  /// Read through [EquipmentType.driverConfig], the same merge the SESSION
  /// is built from, so a pairing that pins its channel in `overrides` keys
  /// as the channel it actually follows. Reading the node's raw config
  /// instead would key every such node as the driver's first channel: two of
  /// them would collide, and the first channel would stop being offered on a
  /// radio nobody is on.
  String _targetKey(EquipmentType type, Map<String, dynamic> config) {
    final merged = type.driverConfig(config);
    final channelKey = type.driver.channelKey;
    // A node stored before the channel setting existed names none, and is
    // tracking the driver's first — the same fallback the driver itself
    // applies when it reads the config.
    final channel = channelKey == null ? '' : '|$channelKey=${merged[channelKey] ?? type.driver.channelValues.first}';
    final target = type.targetFor(config);
    return '${type.key}|${target.entries.map((e) => '${e.key}=${e.value}').join(',')}$channel';
  }

  String? _discoveryError;

  /// Why nothing is being found, when the reason is knowable — a port
  /// already held by something else, or a sandbox refusing the bind. Silent
  /// emptiness and "your radio is off" look identical otherwise.
  String? get discoveryError => _discoveryError;

  bool get isDiscovering => _discoverySubscriptions.isNotEmpty;

  /// Starts listening on every type that announces itself. Safe to call
  /// again while running; call [stopDiscovery] when the UI that wants it
  /// goes away, since this holds a bound socket.
  void startDiscovery() {
    if (isDiscovering) return;
    _discoveryError = null;

    for (final type in registry.types) {
      final stream = type.discover();
      if (stream == null) continue;
      _discoverySubscriptions.add(
        stream.listen(
          (found) {
            _discovered[_discoveryKey(found)] = found;
            notifyListeners();
          },
          onError: (Object e, StackTrace st) {
            ErrorReportingService.report(e, st, context: 'cat:discovery:${type.key}');
            _discoveryError = '$e';
            notifyListeners();
          },
        ),
      );
    }
    notifyListeners();
  }

  void stopDiscovery() {
    if (!isDiscovering) return;
    for (final subscription in _discoverySubscriptions) {
      unawaited(subscription.cancel());
    }
    _discoverySubscriptions.clear();
    // Findings are kept: reopening the Add dialog shows what was already
    // seen instead of an empty list waiting on the next announcement, which
    // for a Flex is several seconds away.
    notifyListeners();
  }

  String _discoveryKey(DiscoveredEquipment found) => '${found.typeKey}|${found.id}';

  String _targetKeyFor(DiscoveredEquipment found) {
    final type = registry.typeFor(found.typeKey);
    if (type == null) return _discoveryKey(found);
    return _targetKey(type, {...type.defaultConfig, ...found.config});
  }
}

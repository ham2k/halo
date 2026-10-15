// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../error_reporting_service.dart';
import '../settings_service.dart';

/// A node the operator can pick by name.
@immutable
class ClusterNode {
  const ClusterNode(this.name, this.host, this.port, {this.description});

  /// The node's own callsign, as `show/configuration` names it.
  final String name;
  final String host;
  final int port;

  /// Where it is and what it runs, for the picker.
  final String? description;

  /// What a password is stored under: per host and port, so switching to
  /// another node and back keeps the first one's.
  String get address => '$host:$port';

  @override
  bool operator ==(Object other) => other is ClusterNode && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);
}

/// Well-linked nodes, each seen to forward a user's spot to the whole network
/// (docs/design/cluster.md § Choosing a node). The first is the default.
const knownClusterNodes = [
  ClusterNode('K3LR', 'dx.k3lr.com', 23, description: 'West Middlesex, PA · AR-Cluster'),
  ClusterNode('K1TTT', 'k1ttt.net', 7373, description: 'Peru, MA · AR-Cluster'),
  ClusterNode('W3LPL', 'dxc.w3lpl.net', 7373, description: 'Glenwood, MD · DXSpider'),
  ClusterNode('NC7J', 'dxc.nc7j.com', 7373, description: 'Syracuse, UT · AR-Cluster'),
  ClusterNode('VE7CC-1', 've7cc.net', 23, description: 'Whonnock, BC · CC Cluster'),
];

/// Where the cluster connection's settings live, in their own group.
abstract final class ClusterSettings {
  static const group = 'cluster';

  /// A [knownClusterNodes] name, or [custom].
  static const nodeKey = 'node';
  static const customHostKey = 'customHost';
  static const customPortKey = 'customPort';
  static const scrollbackKey = 'scrollback';

  static const custom = 'custom';

  static const scrollbackOptions = [500, 1000, 2000, 5000];
  static const defaultScrollback = 1000;

  /// The node the settings name. A custom node with no usable host falls
  /// back to the default rather than to nothing: a half-typed address must
  /// not leave the spotter with nowhere to post.
  static ClusterNode node(SettingsService settings) {
    final name = settings.settingValue(group, nodeKey);
    if (name == custom) {
      final host = '${settings.settingValue(group, customHostKey) ?? ''}'.trim();
      final raw = settings.settingValue(group, customPortKey);
      final port = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}'.trim());
      if (host.isNotEmpty) return ClusterNode(host, host, port != null && port >= 1 && port <= 65535 ? port : 23);
    }
    return knownClusterNodes.where((n) => n.name == name).firstOrNull ?? knownClusterNodes.first;
  }

  static int scrollback(SettingsService settings) {
    final raw = settings.settingValue(group, scrollbackKey);
    final size = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}');
    return scrollbackOptions.contains(size) ? size! : defaultScrollback;
  }
}

/// Each node's password, in the platform keychain, per `host:port` — so
/// switching to another node and back keeps the first one's.
class ClusterPasswords {
  ClusterPasswords([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // The FILE keychain on macOS, as SettingsService's and the extension
            // accounts' storage use: the data-protection keychain needs the
            // restricted keychain-access-groups entitlement, which a Developer
            // ID build cannot carry, and every save there fails with -34018.
            mOptions: MacOsOptions(usesDataProtectionKeychain: false, accountName: 'Ham2K Logger'),
            iOptions: IOSOptions(accountName: 'Ham2K Logger'),
          );

  final FlutterSecureStorage _storage;

  String _key(ClusterNode node) => 'cluster.${node.address}.password';

  /// Null when none is stored, or when secure storage is unavailable — which
  /// the node then reports as a password it was not given.
  Future<String?> read(ClusterNode node) async {
    try {
      return await _storage.read(key: _key(node));
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cluster:password-read');
      return null;
    }
  }

  /// Stores [value], or clears it when empty. Returns whether it landed.
  Future<bool> write(ClusterNode node, String? value) async {
    try {
      if (value == null || value.isEmpty) {
        await _storage.delete(key: _key(node));
      } else {
        await _storage.write(key: _key(node), value: value);
      }
      return true;
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cluster:password-write');
      return false;
    }
  }
}

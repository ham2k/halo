// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_extension_host/halo_extension_host.dart';

import '../cluster/cluster_service.dart';
import 'extension_info.dart';

/// The DX cluster host calls and the manifest capabilities that gate them
/// (docs/design/cluster.md). Every one of them can log the operator in to a
/// node, and the stronger ones speak there in the operator's name — a spot
/// read worldwide as theirs, or any command at all (`ANNOUNCE/FULL` reaches
/// every node; `SET/PASSWORD` changes their account there). So each level
/// is its own grant, and the consent screen names the one declared:
///
///  - `requiresClusterRead`: `clusterStatus`, `clusterLines`,
///    `clusterSubscribe`, `clusterUnsubscribe`
///  - `requiresClusterSpot`: those, and `clusterPostSpot`
///  - `requiresClusterCommand`: those, and `clusterSend`
///
/// `params['extensionKey']` is the caller's identity only because the kernel
/// stamps it (kernel.ts `IDENTITY_HOST_METHODS`).
class ClusterHostCalls {
  static const _reads = {'clusterStatus', 'clusterLines', 'clusterSubscribe', 'clusterUnsubscribe'};
  static const _spots = {'clusterPostSpot'};
  static const _commands = {'clusterSend'};

  static bool handles(String method) => _reads.contains(method) || _spots.contains(method) || _commands.contains(method);

  /// Resolved when first needed — here by a host call, or by the Settings
  /// section once an extension offers it: the service is app-wide, and a
  /// runtime that never reaches the cluster has no reason to build it.
  ClusterService Function()? cluster;

  CapabilityGrant _read = const CapabilityGrant();
  CapabilityGrant _spot = const CapabilityGrant();
  CapabilityGrant _command = const CapabilityGrant();
  bool _offered = false;

  /// Whether any loaded extension uses the cluster — what puts its section
  /// in Settings.
  bool get offered => _offered;

  /// Resolved once per runtime start, like the radio grants. Every
  /// subscription is the old runtime's: its hooks are gone, so nothing would
  /// receive what the node sends next — and one left standing, from an
  /// extension since removed, would hold the session open for good.
  void allow(Iterable<ExtensionInfo> loaded) {
    bool command(ExtensionInfo info) => info.requiresClusterCommand;
    bool spot(ExtensionInfo info) => command(info) || info.requiresClusterSpot;
    bool read(ExtensionInfo info) => spot(info) || info.requiresClusterRead;
    _read = CapabilityGrant.among(loaded, read);
    _spot = CapabilityGrant.among(loaded, spot);
    _command = CapabilityGrant.among(loaded, command);
    final wasOffered = _offered;
    _offered = loaded.any(read);
    // Only where a service can exist: one never offered was never built,
    // and building it to clear nothing is a settings listener for no one.
    if (_offered || wasOffered) cluster?.call().retainSubscribers(const {});
  }

  Future<dynamic> handle(String method, Map<String, dynamic> params) async {
    final extensionKey = params['extensionKey'] as String?;
    final (grant, name) = _commands.contains(method)
        ? (_command, 'requiresClusterCommand')
        : _spots.contains(method)
        ? (_spot, 'requiresClusterSpot')
        : (_read, 'requiresClusterRead');
    if (!grant.allows(extensionKey)) {
      throw ExtensionHostException("$method blocked: extension '${extensionKey ?? 'unknown'}' does not declare $name");
    }
    final service = cluster?.call();
    if (service == null) return method == 'clusterLines' ? const [] : const {'ok': false, 'error': 'unsupported'};
    return switch (method) {
      'clusterStatus' => service.status.toJson(),
      'clusterLines' => [for (final line in service.lines(after: (params['after'] as num?)?.toInt(), limit: (params['limit'] as num?)?.toInt())) line.toJson()],
      'clusterSubscribe' => (await service.subscribe(extensionKey!)).toJson(),
      'clusterUnsubscribe' => _unsubscribe(service, extensionKey!),
      'clusterPostSpot' => (await service.postSpot(
        freqKHz: (params['freq'] as num?)?.toDouble() ?? 0,
        call: params['call'] as String? ?? '',
        comment: params['comment'] as String?,
      )).toJson(),
      _ => (await service.send(params['command'] as String? ?? '')).toJson(),
    };
  }

  Map<String, dynamic> _unsubscribe(ClusterService service, String extensionKey) {
    service.unsubscribe(extensionKey);
    return service.status.toJson();
  }
}

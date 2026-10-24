// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../services/cluster/cluster_service.dart';
import '../services/cluster/cluster_settings.dart';
import '../services/settings_service.dart';
import 'cluster_console.dart';
import 'cluster_server_dialog.dart';
import 'settings_registry.dart';

/// The DX cluster connection: which node, its password, how much it keeps
/// (docs/design/cluster.md). Empty — so Settings leaves the section out —
/// until an extension declares a cluster capability: a node nothing posts to
/// is a setting with nothing behind it.
class ClusterSettingsGroup extends SettingsGroup {
  ClusterSettingsGroup(this.settings, {required this.passwords, required this.cluster, required this.offered, required this.changes});

  final SettingsService settings;
  final ClusterPasswords passwords;
  final ClusterService Function() cluster;

  /// Whether any loaded extension uses the cluster.
  final bool Function() offered;

  /// Notifies when [offered] may have changed.
  final Listenable Function() changes;

  static const _connectionAction = 'clusterConnection';
  static const _serverAction = 'clusterServer';
  static const _consoleAction = 'clusterConsole';

  @override
  String get key => ClusterSettings.group;

  @override
  String get title => t.settings.cluster.title;

  @override
  int get order => 16;

  /// The settings, the connection and the extensions: any of them changes
  /// what the section shows. Merged once, so a form subscribes and
  /// unsubscribes the same object.
  @override
  late final Listenable listenable = Listenable.merge([settings, cluster(), changes()]);

  @override
  Future<void> openAction(BuildContext context, String actionKey) async {
    switch (actionKey) {
      // A login and a harmless command: whether the node, the operator's call
      // and the password are right, without posting anything.
      case _connectionAction:
        unawaited(cluster().send('sh/version'));
      case _consoleAction:
        await showClusterConsole(context, cluster());
      case _serverAction:
        await showHaloDialog<void>(
          context: context,
          builder: (_) => ClusterServerDialog(settings: settings),
        );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> buildElements() async {
    if (!offered()) return const [];
    final s = t.settings.cluster;
    final node = ClusterSettings.node(settings);
    final connects = ClusterSettings.connects(settings);
    return [
      {
        'type': 'field',
        'fieldType': 'checkbox',
        'key': ClusterSettings.connectKey,
        'label': s.connect,
        'icon': 'power-plug-outline',
        'description': connects ? s.connectOn : s.connectOff,
        'value': connects,
      },
      {
        'type': 'action',
        'style': 'row',
        'key': _serverAction,
        'label': s.server,
        'description': clusterServerText(settings),
        'icon': 'access-point-network',
        'aliases': const ['node', 'host', 'port', 'server'],
      },
      // The dialog's fields, declared so SET and SHOW reach them, and off the
      // section's rows, where they would repeat the row that opens it.
      for (final el in clusterServerElements(settings)) {...el, 'listed': false},
      {
        'type': 'field',
        'fieldType': 'secret',
        'key': 'password',
        'label': s.password,
        'icon': 'key-outline',
        'description': s.passwordDescription,
        'storedText': s.passwordStored(node: node.name),
        'value': await passwords.read(node) ?? '',
      },
      {
        'type': 'field',
        'fieldType': 'select',
        'key': ClusterSettings.scrollbackKey,
        'label': s.scrollback,
        'icon': 'format-list-numbered',
        'value': '${ClusterSettings.scrollback(settings)}',
        'options': [
          for (final size in ClusterSettings.scrollbackOptions) {'label': s.scrollbackOpt(count: size), 'value': '$size'},
        ],
      },
      {
        'type': 'action',
        'style': 'row',
        'key': _connectionAction,
        'label': s.connection,
        'description': clusterStatusText(cluster().status),
        'icon': 'lan-connect',
      },
      {
        'type': 'action',
        'style': 'row',
        'key': _consoleAction,
        'label': s.console,
        'description': s.consoleDescription,
        'icon': 'console',
        'aliases': const ['console', 'terminal', 'telnet', 'commands'],
      },
    ];
  }

  @override
  Future<void> commit(String fieldKey, dynamic value) async {
    switch (fieldKey) {
      case 'password':
        await passwords.write(ClusterSettings.node(settings), value is String ? value : null);
      case ClusterSettings.connectKey:
        await settings.setSettingValue(ClusterSettings.group, fieldKey, value == true);
      case ClusterSettings.scrollbackKey:
        await settings.setSettingValue(ClusterSettings.group, fieldKey, int.tryParse('$value') ?? ClusterSettings.defaultScrollback);
      default:
        await commitClusterServerSetting(settings, fieldKey, value);
    }
  }
}

/// [status] as the Connection row says it.
String clusterStatusText(ClusterStatus status) {
  final s = t.settings.cluster;
  final node = status.node.name;
  return switch (status.state) {
    ClusterState.idle => s.statusIdle,
    ClusterState.connecting => s.statusConnecting(node: node),
    ClusterState.connected => s.statusConnected(node: node, call: status.call ?? ''),
    ClusterState.failed when status.error == 'unsupported' => s.statusUnsupported,
    ClusterState.failed when status.error == 'off' => s.statusOff,
    ClusterState.failed => s.statusFailed(node: node, reason: clusterFailureReason(status)),
  };
}

/// Why [status] failed, in a few words.
String clusterFailureReason(ClusterStatus status) {
  final e = t.settings.cluster.errors;
  return switch (status.error) {
    'noCall' => e.noCall,
    'connectFailed' => e.connectFailed,
    'needsPassword' => e.needsPassword,
    'loginFailed' => status.message ?? e.loginFailed,
    'disconnected' => e.disconnected,
    'timeout' => e.timeout,
    'off' => e.off,
    _ => status.message ?? status.error ?? '',
  };
}

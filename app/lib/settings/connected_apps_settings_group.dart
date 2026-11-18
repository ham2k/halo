// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How to set an agent app up (docs/design/agent-link.md § The command), and
// the agent apps the operator allowed (§ Grants): what each may do, and a
// way to remove it. A section of Settings ›
// Integrations (integrations_settings_group.dart), not a category of its
// own: the agent link's wiring hands it over at boot.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart' show haloSnackBar;

import '../services/agent_link/agent_link_command.dart';
import '../services/agent_link/agent_link_model.dart';
import '../services/agent_link/agent_link_service.dart';
import 'settings_registry.dart';

class ConnectedAppsSettingsGroup extends SettingsGroup {
  /// The agent link, built on first use; it listens only while [wanted].
  final AgentLinkService Function() link;

  /// Whether the experiment has the link on; the group has no rows while it
  /// does not.
  final bool Function() wanted;

  /// Notified when the experiment turns the link on or off.
  final Listenable changes;

  /// How an agent app runs halo-mcp to reach this install; null when this
  /// build carries none.
  final AgentLinkCommand? Function() command;

  ConnectedAppsSettingsGroup({required this.link, required this.wanted, required this.changes, required this.command});

  /// A row's key: its grant id, behind a prefix.
  static const _rowPrefix = 'agentApp:';

  /// The setup rows' keys, each copying one form of the command.
  static const setupPrefix = 'agentSetup:';
  static const _copyCommand = '${setupPrefix}command';
  static const _copyClaudeCode = '${setupPrefix}claudeCode';
  static const _copyJson = '${setupPrefix}json';

  @override
  String get key => 'connectedApps';
  @override
  String get title => t.settings.assistants.connectedApps;
  @override
  int get order => 24;

  /// One object for the group's life: the settings view adds its listener
  /// to what it reads at open and removes it from what it reads at close,
  /// and a merge built per read would differ between the two whenever the
  /// experiment changed in between.
  @override
  late final Listenable listenable = Listenable.merge([changes, link()]);

  @override
  Future<List<Map<String, dynamic>>> buildElements() async {
    if (!wanted()) return const [];
    final link = this.link();
    final grants = link.grants;
    final failure = link.failure;
    final command = this.command();
    final labels = t.settings.assistants;
    String accessLabel(AgentAccess access) => access == AgentAccess.change ? labels.appChange : labels.appWatch;
    return [
      {
        'type': 'markdown',
        'text': switch (failure) {
          AgentLinkFailure.portUnavailable => labels.connectedAppsPortInUse(port: '${link.wantedPort}'),
          AgentLinkFailure.other => labels.connectedAppsCannotListen(port: '${link.wantedPort}'),
          null => labels.connectedAppsHint,
        },
      },
      // Shown with or without apps allowed: an operator setting up a second
      // agent app needs it as much as one setting up the first.
      if (command == null)
        {'type': 'markdown', 'text': labels.setupNoCommand}
      else if (command.temporary)
        {'type': 'markdown', 'text': labels.setupMoveApp}
      else ...[
        {'type': 'action', 'style': 'row', 'key': _copyCommand, 'label': labels.setupCommand, 'description': command.commandLine, 'icon': 'console'},
        {
          'type': 'action',
          'style': 'row',
          'key': _copyClaudeCode,
          'label': labels.setupClaudeCode,
          'description': command.claudeCodeLine,
          'icon': 'content-copy',
        },
        {
          'type': 'action',
          'style': 'row',
          'key': _copyJson,
          'label': labels.setupOtherApps,
          'description': labels.setupOtherAppsDescription,
          'icon': 'code-json',
        },
      ],
      for (final grant in grants)
        {
          'type': 'field',
          'fieldType': 'select',
          'key': '$_rowPrefix${grant.id}',
          'label': grant.client.launcher == null ? grant.client.name : labels.appLauncher(name: grant.client.name, launcher: grant.client.launcher!),
          'icon': 'robot-outline',
          'description': link.connectionsOf(grant.id) > 0 ? labels.appConnected(access: accessLabel(grant.access)) : accessLabel(grant.access),
          'value': grant.access.name,
          'options': [
            {'label': labels.appWatch, 'value': AgentAccess.watch.name},
            {'label': labels.appChange, 'value': AgentAccess.change.name},
          ],
          'destructiveOption': {'label': labels.appRemove, 'value': 'remove'},
        },
    ];
  }

  @override
  Future<void> openAction(BuildContext context, String actionKey) async {
    final command = this.command();
    if (command == null || command.temporary) return;
    final text = switch (actionKey) {
      _copyCommand => command.commandLine,
      _copyClaudeCode => command.claudeCodeLine,
      _copyJson => command.mcpServersJson,
      _ => null,
    };
    if (text == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger?.showSnackBar(haloSnackBar(t.settings.assistants.setupCopied));
  }

  @override
  Future<void> commit(String fieldKey, dynamic value) async {
    if (!fieldKey.startsWith(_rowPrefix)) return;
    if (!wanted()) return;
    // 'remove', or anything else that is not an access, forgets the app.
    await link().setAccess(fieldKey.substring(_rowPrefix.length), AgentAccess.parse(value));
  }
}

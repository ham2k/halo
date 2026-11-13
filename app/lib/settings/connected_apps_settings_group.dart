// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The agent apps the operator allowed (docs/design/agent-link.md § Grants):
// what each may do, and a way to remove it. A section of Settings ›
// Integrations (integrations_settings_group.dart), not a category of its
// own: the agent link's wiring hands it over at boot.

import 'package:flutter/foundation.dart';
import 'package:halo_i18n/halo_i18n.dart';

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

  ConnectedAppsSettingsGroup({required this.link, required this.wanted, required this.changes});

  /// A row's key: its grant id, behind a prefix.
  static const _rowPrefix = 'agentApp:';

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
    // Nothing to list, nothing shown: an operator who never allowed an app
    // has no use for the group, and the dialog that allows one finds them
    // wherever they are. A link that cannot listen is the exception: it is
    // why no app reaches the dialog, and nothing else says so.
    if (grants.isEmpty && failure == null) return const [];
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
  Future<void> commit(String fieldKey, dynamic value) async {
    if (!fieldKey.startsWith(_rowPrefix)) return;
    if (!wanted()) return;
    // 'remove', or anything else that is not an access, forgets the app.
    await link().setAccess(fieldKey.substring(_rowPrefix.length), AgentAccess.parse(value));
  }
}

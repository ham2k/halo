// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The agent link's place among the app's services (docs/design/agent-link.md):
// built once the `mcp` experiment is on, closed at exit, and listed in
// Settings. Kept out of HaLoServices itself, which holds the app's every
// service and has no room left to grow.

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart' show realNowMillis;

import '../../config/experiments.dart';
import '../../config/version.dart' show kEdition;
import '../../settings/connected_apps_settings_group.dart';
import '../../settings/integrations_settings_group.dart';
import '../halo_services.dart';
import 'agent_link_model.dart';
import 'agent_link_prompt.dart';
import 'agent_link_service.dart';

final _links = Expando<AgentLinkService>('agentLink');

extension AgentLinkServices on HaLoServices {
  /// Whether the link is wanted: the experiment on, in a build that can
  /// listen.
  bool get agentLinkWanted => !kIsWeb && settings.experimentEnabled(kAgentLinkExperiment);

  /// The link, built on first use.
  AgentLinkService get agentLink => _links[this] ??= closedOnExit<AgentLinkService>(
    'agent-link',
    AgentLinkService(
      store: PrefsAgentGrantStore(read: settings.jsonMapPref, write: settings.setJsonMapPref),
      endpoint: extensions,
      wanted: () => agentLinkWanted,
      changes: settings,
      port: agentLinkPort(kEdition),
      // The grants persist, so their stamps are the real clock's, never a
      // travelled one.
      now: realNowMillis,
    ),
    (link) => link.closeForExit(),
  );
}

/// At boot: lists the connected apps in Settings, and starts the link and
/// its prompt once the experiment is on — now, or when it is turned on —
/// then stops watching; the link follows the setting from there. Nothing
/// listens for an operator who never turns it on.
void startAgentLinkWhenWanted(HaLoServices services) {
  services.settingsRegistry.groups.whereType<IntegrationsSettingsGroup>().single.connectedApps = ConnectedAppsSettingsGroup(
    link: () => services.agentLink,
    wanted: () => services.agentLinkWanted,
    changes: services.settings,
  );
  if (kIsWeb) return;
  void check() {
    if (!services.agentLinkWanted) return;
    services.settings.removeListener(check);
    listenForAgentLinkRequests(services.agentLink);
  }

  services.settings.addListener(check);
  check();
}

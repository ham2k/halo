// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Integrations category: what the log is carried to and from, and how
// other apps on this device reach this one. Each extension integration with
// settings of its own shows them here, in a band named after its extension,
// as it does under its switch in an operation's Integrations dialog
// (docs/extensions/integrations.md); the switch itself is the operation's.
// Connected Apps says how to set an agent app up and lists the ones the
// operator allowed, when the agent link is wired in
// (connected_apps_settings_group.dart). Links from Other
// Apps lists every sender whose `/vfo`, `/qso` and `/operation` links the
// operator allowed or denied for good (views/deep_link_approval.dart):
// either answer can be changed, or removed so the links ask again.
//
// Nothing here is an extension's to change: SET refuses the whole category
// (settings_command.dart), since an extension could otherwise allow a link
// sender or an agent app for itself — or change another's integration.

import 'package:flutter/widgets.dart';
import 'package:halo_i18n/halo_i18n.dart';

import '../services/extensions/extension_service.dart';
import '../services/integration_service.dart';
import '../services/settings_service.dart';
import '../views/deep_link_approval.dart' show unnamedLinkSender;
import 'connected_apps_settings_group.dart';
import 'settings_registry.dart';
import 'watcher_settings_rows.dart';

class IntegrationsSettingsGroup extends SettingsGroup {
  final SettingsService settings;

  /// Null where nothing offers integrations: tests of the other sections.
  final IntegrationService? integrations;
  final ExtensionService? extensions;

  IntegrationsSettingsGroup(this.settings, [this.integrations, this.extensions]);

  ConnectedAppsSettingsGroup? _connectedApps;

  /// The Connected Apps section, handed in by the agent link's wiring at
  /// boot, which keeps the link out of the services that build this group.
  set connectedApps(ConnectedAppsSettingsGroup section) {
    _connectedApps?.listenable.removeListener(_changes.notify);
    _connectedApps = section;
    section.listenable.addListener(_changes.notify);
    _changes.notify();
  }

  /// What the sections change through, as one object for the group's life:
  /// a form adds its listener to what it reads at open and removes it from
  /// what it reads at close.
  final _changes = _Relay();

  /// A sender row's key: the sender's id, behind a prefix.
  static const _senderPrefix = 'linkSender:';

  @override
  String get key => 'integrations';

  @override
  String get title => t.settings.integrations.title;

  /// After Exports: what goes out of the app, then what comes into it.
  @override
  int get order => 26;

  @override
  late final Listenable listenable = Listenable.merge([settings, _changes, ?integrations, ?extensions?.settingsGeneration]);

  String _label(String id, String label) => id == unnamedLinkSender ? t.settings.linkSenders.unknownSender : label;

  /// Each section shows only with something in it, and the category only
  /// with a section: Connected Apps while the agent link is wanted, a link
  /// sender once the operator answers its link with "Don’t ask again".
  @override
  Future<List<Map<String, dynamic>>> buildElements() async {
    final connected = await _connectedApps?.buildElements() ?? const [];
    return [
      ...await _integrationRows(),
      if (connected.isNotEmpty) ...[
        {'type': 'header', 'style': 'section', 'key': 'connectedApps', 'title': t.settings.assistants.connectedApps},
        ...connected,
      ],
      ..._linkSenderRows(),
    ];
  }

  /// A band per extension whose integrations have settings, each one's under
  /// its name. One without settings has nothing to show here.
  Future<List<Map<String, dynamic>>> _integrationRows() async {
    final integrations = this.integrations, extensions = this.extensions;
    if (integrations == null || extensions == null) return const [];
    final withForms = integrations.catalog.where((integration) => integration.formFields.isNotEmpty);
    return [
      for (final (name, offered) in watchersByExtension(withForms, extensions)) ...[
        {'type': 'header', 'style': 'section', 'key': 'integrations:$name', 'title': name},
        for (final integration in offered) ...[
          {'type': 'header', 'key': integration.id, 'title': integration.title, 'subtitle': ?integration.description},
          ...await watcherFormRows(integration, extensions),
        ],
      ],
    ];
  }

  List<Map<String, dynamic>> _linkSenderRows() {
    final s = t.settings.linkSenders;
    final decisions = settings.linkSenderDecisions;
    if (decisions.isEmpty) return const [];
    return [
      // Folded: what the operator decided once and rarely revisits.
      {'type': 'header', 'style': 'section', 'key': 'linkSenders', 'title': s.title, 'collapsed': true},
      for (final MapEntry(key: id, value: decided) in decisions.entries)
        {
          'type': 'field',
          'fieldType': 'select',
          'key': '$_senderPrefix$id',
          'label': _label(id, decided.label),
          // The id is what the OS said, and the name only what it showed:
          // two apps can share a name.
          if (id != unnamedLinkSender && id != decided.label) 'description': id,
          'icon': 'link-variant',
          'value': decided.allow ? _allow : _deny,
          'options': [
            // Nobody named stands for every app and page, so it is never
            // allowed for good (deep_link_approval.dart).
            if (id != unnamedLinkSender) {'label': s.allowed, 'value': _allow},
            {'label': s.denied, 'value': _deny},
          ],
          // Removed, its links ask again.
          'destructiveOption': {'label': s.remove, 'value': _remove},
        },
    ];
  }

  static const _allow = 'allow';
  static const _deny = 'deny';
  static const _remove = 'remove';

  @override
  Future<void> openAction(BuildContext context, String actionKey) async {
    if (actionKey.startsWith(ConnectedAppsSettingsGroup.setupPrefix)) await _connectedApps?.openAction(context, actionKey);
  }

  @override
  Future<void> commit(String fieldKey, dynamic value) async {
    final integrations = this.integrations, extensions = this.extensions;
    if (integrations != null && extensions != null) {
      if (await commitWatcherField(integrations.catalog, integrations, extensions, fieldKey, value)) return;
    }
    if (!fieldKey.startsWith(_senderPrefix)) return _connectedApps?.commit(fieldKey, value);
    final id = fieldKey.substring(_senderPrefix.length);
    final decided = settings.linkSenderDecisions[id];
    if (decided == null) return;
    switch (value) {
      case _allow when id != unnamedLinkSender:
        await settings.decideLinkSender(id, label: decided.label, allow: true);
      case _deny:
        await settings.decideLinkSender(id, label: decided.label, allow: false);
      default:
        await settings.forgetLinkSender(id);
    }
  }
}

/// A notifier anyone may ring: [ChangeNotifier.notifyListeners] is protected.
class _Relay extends ChangeNotifier {
  void notify() => notifyListeners();
}

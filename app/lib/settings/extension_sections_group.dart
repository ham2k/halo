// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/foundation.dart';
import 'package:halo_i18n/halo_i18n.dart';

import '../services/extensions/extension_service.dart';
import '../services/assistant_service.dart';
import 'watcher_settings_rows.dart';
import 'settings_registry.dart';

/// A section with no settings of the app's own, there for extensions to
/// place their panels in by their main purpose — `"settings": {"section":
/// "activities"}` in a manifest (docs/extensions/settings.md). Each placed
/// panel is one row that opens it in a dialog; with none placed, the section
/// has no rows and is not shown at all.
class ExtensionSectionGroup extends SettingsGroup {
  @override
  final String key;
  @override
  final int order;
  final String Function() _title;

  ExtensionSectionGroup._(this.key, this.order, this._title);

  /// Between Maps (17) and Exports (25), in the order an operator meets
  /// them: what they go out to do, what they work, then the tools around it.
  static List<ExtensionSectionGroup> all() => [
    ExtensionSectionGroup._('activities', 18, () => t.settings.extensionSections.activities),
    ExtensionSectionGroup._('hunting', 19, () => t.settings.extensionSections.hunting),
    ExtensionSectionGroup._('contests', 20, () => t.settings.extensionSections.contests),
    ExtensionSectionGroup._('lookups', 21, () => t.settings.extensionSections.lookups),
    ExtensionSectionGroup._('dashboard', 22, () => t.settings.extensionSections.dashboard),
  ];

  @override
  String get title => _title();

  @override
  Future<List<Map<String, dynamic>>> buildElements() async => const [];

  @override
  Future<void> commit(String fieldKey, dynamic value) async {}
}

/// The Assistants section (docs/extensions/assistants.md): a band for each
/// extension offering assistants, with a switch for each, and under one that
/// is on, its own settings. With no assistant offered it has no rows and is
/// not shown.
class AssistantsSettingsGroup extends SettingsGroup {
  final AssistantService assistants;
  final ExtensionService extensions;

  AssistantsSettingsGroup(this.assistants, this.extensions);

  @override
  String get key => 'assistants';
  @override
  String get title => t.settings.assistants.title;
  @override
  int get order => 23;

  @override
  late final Listenable listenable = Listenable.merge([assistants, extensions.settingsGeneration]);

  @override
  Future<List<Map<String, dynamic>>> buildElements() async {
    final elements = <Map<String, dynamic>>[];
    // One band per extension, holding a switch for each assistant it offers
    // and the settings of each one that is on.
    for (final (name, offered) in watchersByExtension(assistants.catalog, extensions)) {
      elements.add({'type': 'header', 'style': 'section', 'key': 'extension:$name', 'title': name});
      for (final assistant in offered) {
        final enabled = assistants.isEnabled(assistant);
        elements.add({
          'type': 'field',
          'fieldType': 'checkbox',
          'key': assistant.id,
          'label': assistant.title,
          'icon': assistant.icon ?? 'eye-outline',
          'description': assistant.description ?? (enabled ? t.settings.assistants.on : t.settings.assistants.off),
          'value': enabled,
        });
        if (enabled) elements.addAll(await watcherFormRows(assistant, extensions));
      }
    }
    return elements;
  }

  @override
  Future<void> commit(String fieldKey, dynamic value) async {
    final assistant = assistants.catalog.where((assistant) => assistant.id == fieldKey).firstOrNull;
    if (assistant != null) return assistants.setEnabled(assistant, value == true);
    if (await commitWatcherField(assistants.catalog, assistants, extensions, fieldKey, value)) return;
    debugPrint('[assistants] no assistant owns the setting "$fieldKey"');
  }
}

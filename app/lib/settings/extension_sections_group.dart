// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/foundation.dart';
import 'package:halo_i18n/halo_i18n.dart';

import '../services/extensions/extension_service.dart';
import '../services/assistant_service.dart';
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

  /// An assistant's own field, as a row of this section: its id, then the
  /// field's key. The id holds `:` but never `/`.
  static String fieldRowKey(AssistantDefinition assistant, String fieldKey) => '${assistant.id}/$fieldKey';

  @override
  String get key => 'assistants';
  @override
  String get title => t.settings.assistants.title;
  @override
  int get order => 23;

  @override
  late final Listenable listenable = Listenable.merge([assistants, extensions.settingsGeneration]);

  /// The name of the extension that offers [assistant], for the band its
  /// assistants sit under: the bundle's, when a bundle registers it under a
  /// sub-key.
  String _extensionName(AssistantDefinition assistant) {
    final owner = CapabilityGrant.among(extensions.availableExtensions, (_) => false).ownerOf(assistant.hookKey);
    final info = owner == null ? null : extensions.extensionInfo(owner);
    return info?.nameFor(LocaleSettings.currentLocale.languageCode) ?? assistant.hookKey;
  }

  /// A `visibleWhen` naming the assistant's own fields, renamed to the rows
  /// they became here: the bare name matches no value in this section.
  static Object? _ownCondition(AssistantDefinition assistant, Object? when) => switch (when) {
    List<dynamic> all => [for (final one in all) _ownCondition(assistant, one)],
    Map<dynamic, dynamic> one when one['field'] is String => {...one, 'field': fieldRowKey(assistant, one['field'] as String)},
    _ => when,
  };

  @override
  Future<List<Map<String, dynamic>>> buildElements() async {
    final elements = <Map<String, dynamic>>[];
    // One band per extension, holding a switch for each assistant it offers
    // and the settings of each one that is on: the operator reads an
    // extension's assistants as one thing, however many it registers.
    final byExtension = <String, List<AssistantDefinition>>{};
    for (final assistant in assistants.catalog) {
      byExtension.putIfAbsent(_extensionName(assistant), () => []).add(assistant);
    }
    final extensionNames = byExtension.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    for (final name in extensionNames) {
      elements.add({'type': 'header', 'style': 'section', 'key': 'extension:$name', 'title': name});
      final sorted = byExtension[name]!..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      for (final assistant in sorted) {
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
        if (!enabled || assistant.formFields.isEmpty) continue;
        final config = await extensions.readPanelConfig(panelKey: assistant.id, fields: assistant.formFields);
        for (final field in assistant.formFields) {
          final fieldKey = field['key'];
          // A header has no key and no value of its own: it is kept as
          // declared, minus any band style — a band of its own would read as
          // another extension's.
          if (fieldKey is! String) {
            elements.add({...field, if (field['visibleWhen'] != null) 'visibleWhen': _ownCondition(assistant, field['visibleWhen'])}..remove('style'));
            continue;
          }
          elements.add({
            ...field,
            'key': fieldRowKey(assistant, fieldKey),
            if (field['visibleWhen'] != null) 'visibleWhen': _ownCondition(assistant, field['visibleWhen']),
            if (config.containsKey(fieldKey)) 'value': config[fieldKey],
          });
        }
      }
    }
    return elements;
  }

  @override
  Future<void> commit(String fieldKey, dynamic value) async {
    for (final assistant in assistants.catalog) {
      if (fieldKey == assistant.id) {
        await assistants.setEnabled(assistant, value == true);
        return;
      }
      final prefix = '${assistant.id}/';
      if (!fieldKey.startsWith(prefix)) continue;
      final own = fieldKey.substring(prefix.length);
      final field = assistant.formFields.where((f) => f['key'] == own).firstOrNull;
      if (field == null) {
        debugPrint('[assistants] ${assistant.id} has no field "$own"; the setting is not kept');
        return;
      }
      await extensions.commitSettingsFieldValue(
        kind: 'simple',
        hookKey: assistant.hookKey,
        panelKey: assistant.id,
        fieldKey: own,
        value: value,
        state: const {},
        isSecret: field['fieldType'] == 'secret',
      );
      assistants.configChanged(assistant);
      return;
    }
    debugPrint('[assistants] no assistant owns the setting "$fieldKey"');
  }
}

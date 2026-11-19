// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An assistant's or an integration's own settings (its `form`), as rows of a
// Settings section: Settings › Assistants under each assistant's switch,
// Settings › Integrations under each integration's name. One row per field,
// keyed `<id>/<field key>`, stored where the hook reads them back as
// `config`.

import 'package:flutter/foundation.dart';
import 'package:halo_i18n/halo_i18n.dart';

import '../services/error_reporting_service.dart';
import '../services/extensions/extension_service.dart';
import '../services/watcher_service.dart';

/// [watcher]'s own field [fieldKey], as a row: its id, then the field's key.
/// The id holds `:` but never `/`.
String watcherFieldRowKey(WatcherDefinition watcher, String fieldKey) => '${watcher.id}/$fieldKey';

/// The name of the extension that offers [watcher], for the band it sits
/// under: the bundle's, when a bundle registers it under a sub-key.
String watcherExtensionName(WatcherDefinition watcher, ExtensionService extensions) {
  final owner = CapabilityGrant.among(extensions.availableExtensions, (_) => false).ownerOf(watcher.hookKey);
  final info = owner == null ? null : extensions.extensionInfo(owner);
  return info?.nameFor(LocaleSettings.currentLocale.languageCode) ?? watcher.hookKey;
}

/// [watchers] grouped by [watcherExtensionName], the names sorted, and each
/// group by title: the operator reads an extension's watchers as one thing,
/// however many it registers.
List<(String, List<WatcherDefinition>)> watchersByExtension(Iterable<WatcherDefinition> watchers, ExtensionService extensions) {
  final byExtension = <String, List<WatcherDefinition>>{};
  for (final watcher in watchers) {
    byExtension.putIfAbsent(watcherExtensionName(watcher, extensions), () => []).add(watcher);
  }
  final names = byExtension.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return [for (final name in names) (name, byExtension[name]!..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase())))];
}

/// A `visibleWhen` naming the watcher's own fields, renamed to the rows they
/// became: the bare name matches no value in the section.
Object? _ownCondition(WatcherDefinition watcher, Object? when) => switch (when) {
  List<dynamic> all => [for (final one in all) _ownCondition(watcher, one)],
  Map<dynamic, dynamic> one when one['field'] is String => {...one, 'field': watcherFieldRowKey(watcher, one['field'] as String)},
  _ => when,
};

/// [watcher]'s form, as rows holding the values it has — none when they
/// cannot be read (a secret behind a locked keychain, a field with no usable
/// key). Thrown, one extension's form would fail its whole section, and with
/// it every settings search and SET.
Future<List<Map<String, dynamic>>> watcherFormRows(WatcherDefinition watcher, ExtensionService extensions) async {
  if (watcher.formFields.isEmpty) return const [];
  final Map<String, dynamic> config;
  try {
    config = await extensions.readPanelConfig(panelKey: watcher.id, fields: watcher.formFields);
  } catch (error, stack) {
    // Once, not on every rebuild: Settings › Integrations reads this again on
    // each change it listens to, and so does every settings search and SET.
    debugPrint('[settings] ${watcher.id}: its settings could not be read: $error');
    ErrorReportingService.reportIfRepeated('${watcher.id}:settings', error, stack, context: '${watcher.id}:settings', threshold: 1);
    return const [];
  }
  return [
    for (final field in watcher.formFields)
      if (field['key'] case final String fieldKey)
        {
          ...field,
          'key': watcherFieldRowKey(watcher, fieldKey),
          if (field['visibleWhen'] != null) 'visibleWhen': _ownCondition(watcher, field['visibleWhen']),
          if (config.containsKey(fieldKey)) 'value': config[fieldKey],
        }
      else
        // A header has no key and no value of its own: it is kept as
        // declared, minus any band style — a band of its own would read as
        // another extension's.
        {...field, if (field['visibleWhen'] != null) 'visibleWhen': _ownCondition(watcher, field['visibleWhen'])}..remove('style'),
  ];
}

/// Stores the row [rowKey] if it is one of [watchers]' fields, and says
/// whether it was. The watcher whose field it is hears of it as `config`.
Future<bool> commitWatcherField(List<WatcherDefinition> watchers, WatcherService service, ExtensionService extensions, String rowKey, dynamic value) async {
  for (final watcher in watchers) {
    final prefix = '${watcher.id}/';
    if (!rowKey.startsWith(prefix)) continue;
    final own = rowKey.substring(prefix.length);
    final field = watcher.formFields.where((f) => f['key'] == own).firstOrNull;
    if (field == null) {
      debugPrint('[${watcher.kind}s] ${watcher.id} has no field "$own"; the setting is not kept');
      return true;
    }
    await extensions.commitSettingsFieldValue(
      kind: 'simple',
      hookKey: watcher.hookKey,
      panelKey: watcher.id,
      fieldKey: own,
      value: value,
      state: const {},
      isSecret: field['fieldType'] == 'secret',
    );
    service.configChanged(watcher);
    return true;
  }
  return false;
}

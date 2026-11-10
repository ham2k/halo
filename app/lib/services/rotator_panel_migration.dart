// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one-time move of the Rotator panel the app drew natively onto the
// pre-loaded `ham2k-rotator` (docs/design/extension-install.md).

import 'dart:convert';

import 'settings_service.dart';

/// Moves the Rotator panel the app drew natively onto `ham2k-rotator`'s,
/// which replaces it: every arrangement's placement, and each one's
/// settings under the names the extension reads. A rotator left on
/// Automatic stays unset, the extension's own "the station's first".
///
/// Runs every boot and finds nothing to do once moved: no native id is left
/// to rewrite, and a value already under the new id is the operator's own.
Future<void> moveNativeRotatorPanels(SettingsService settings) async {
  final prefs = settings.prefs;
  const native = 'rotator', replacement = 'ext:ham2k-rotator:rotator';
  final layout = _storedLayout(prefs.getString(SettingsService.layoutPrefsKey));
  // Each native placement keeps its number unless the extension's panel
  // already holds it: two placements under one id are an arrangement the
  // dock refuses whole, the operator's every other pane with it.
  final ids = <String>{};
  void collect(Object? value) => switch (value) {
    String() => ids.add(value),
    Map() => value.forEach((k, v) => [collect(k), collect(v)]),
    List() => value.forEach(collect),
    _ => null,
  };
  collect(layout.values.toList());
  for (final key in prefs.getKeys()) {
    if (key.startsWith('settingsPanel.')) ids.add(key.substring('settingsPanel.'.length).split('.').first);
  }
  final taken = {
    for (final id in ids)
      if (id.startsWith('$replacement#')) id,
  };
  final targets = <String, String>{};
  for (final id in ids.where((id) => id == native || id.startsWith('$native#')).toList()..sort()) {
    var target = '$replacement${id.substring(native.length)}';
    for (var n = 1; taken.contains(target); n++) {
      target = '$replacement#$n';
    }
    taken.add(target);
    targets[id] = target;
  }
  if (targets.isEmpty) return;
  const fields = {'rotator': 'rotator', 'beamWidth': 'beamWidth.beam', 'location': 'location', 'theme': 'theme', 'grayline': 'grayline'};
  for (final prefsKey in prefs.getKeys().toList()) {
    if (!prefsKey.startsWith('settingsPanel.')) continue;
    final rest = prefsKey.substring('settingsPanel.'.length);
    final dot = rest.indexOf('.');
    if (dot < 0) continue;
    final (id, field) = (targets[rest.substring(0, dot)], fields[rest.substring(dot + 1)]);
    final value = prefs.get(prefsKey);
    if (id == null || field == null || value is! String || value == jsonEncode('auto')) continue;
    final target = 'settingsPanel.$id.$field';
    if (prefs.get(target) == null) await prefs.setString(target, value);
  }
  Object? rename(Object? value) => switch (value) {
    String() => targets[value] ?? value,
    Map() => <String, dynamic>{for (final e in value.entries) '${rename(e.key)}': rename(e.value)},
    List() => <dynamic>[for (final item in value) rename(item)],
    _ => value,
  };
  final changed = {
    for (final e in layout.entries)
      if (rename(e.value) case final Object value when jsonEncode(value) != jsonEncode(e.value)) e.key: value,
  };
  if (changed.isNotEmpty) await settings.setLayoutValues(changed);
}

/// The layout map as stored, or empty where it is missing or unreadable —
/// as [SettingsService.layoutData] reads it, so a corrupt store costs this
/// move and never the boot.
Map<String, dynamic> _storedLayout(String? stored) {
  if (stored == null) return const {};
  try {
    return switch (jsonDecode(stored)) {
      final Map<String, dynamic> map => map,
      _ => const {},
    };
  } on FormatException {
    return const {};
  }
}

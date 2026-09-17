// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Declarative settings: every setting in the app is described by a
// [SettingsGroup] producing FormRenderer-shaped element maps — the same
// dialect extension settingsPanels already speak (docs/extensions/
// settings.md), so one renderer serves both. SettingsService hosts the
// declarations for the core groups (general/logging/privacy — see
// core_settings_groups.dart), other services declare their own (sync), and
// extensions contribute theirs through the settingsPanel hook, surfaced as
// `extension_{panelKey}` sections by the Settings panel.
//
// Three element-level attributes (docs/extensions/settings.md), settable by
// any of the above — core groups and extension settingsPanels alike — drive
// visibility instead of a central whitelist:
//
//  - `common: true` also shows the field in Settings' Common Preferences
//    section; everything else appears only under its own group's section.
//  - `environment: 'ios,android'` (or `'-web'`, or a list of tokens) hides
//    the field outside the named platform(s) — everywhere, not just
//    Common Preferences. Tokens: ios, android, macos, windows, linux, web — the
//    same vocabulary notices.dart's `_knownPlatforms` uses.
//  - `target: 'logging'` (or a list, for a setting reachable from more than
//    one target-built modal) opts the field into a target-scoped settings
//    modal (settings_target_dialog.dart's `showSettingsForTarget`) — e.g.
//    the logging panel's tune-icon dialog collects every element targeting
//    `'logging'`. A second bucket, `'<target>-extended'`, is collected too
//    but starts hidden behind that dialog's own "show more settings"
//    disclosure — for settings related to the same target but niche enough
//    they'd otherwise crowd out the common ones. Unlike `common`/
//    `environment`, absence of `target` isn't "matches everything" — a
//    field with no `target` simply never appears in a target-scoped modal,
//    only in Settings.

import 'package:flutter/widgets.dart';
import 'package:halo_widgets/halo_widgets.dart';

/// One declared group of settings: an ordered section of FormRenderer
/// elements plus the commit path for its fields.
abstract class SettingsGroup {
  String get key;

  /// Section title, already localized.
  String get title;

  int get order;

  /// Notifies when values change outside the panel (keyboard shortcuts,
  /// other views) so an open form can refresh. Null when nothing external
  /// mutates the group.
  Listenable? get listenable => null;

  /// The group's elements in the FormRenderer dialect, with current values
  /// resolved. Async because some groups need a bridge round-trip.
  Future<List<Map<String, dynamic>>> buildElements();

  Future<void> commit(String fieldKey, dynamic value);

  /// Opens a core settings action from either the settings list or a target modal.
  Future<void> openAction(BuildContext context, String actionKey) async {}
}

/// Whether [element]'s `environment` attribute admits the current platform.
/// Absent (or unrecognized shape) → visible everywhere. Every token
/// unprefixed (`'ios,android'` or `['ios', 'android']`) → visible ONLY on
/// those platforms. Every token `-`-prefixed (`'-web'`) → visible
/// everywhere EXCEPT those. Mixing the two forms is invalid; the whole
/// attribute is then treated as absent (fail open — see
/// docs/extensions/settings.md).
bool elementMatchesEnvironment(Map<String, dynamic> element) {
  final raw = element['environment'];
  // Lowercased so a miscased token ('iOS') still matches platformToken,
  // which is always lowercase — rather than silently failing open/closed.
  final tokens = switch (raw) {
    String s => s.split(',').map((t) => t.trim().toLowerCase()).where((t) => t.isNotEmpty).toList(),
    List<dynamic> l => l.whereType<String>().map((t) => t.toLowerCase()).toList(),
    _ => const <String>[],
  };
  if (tokens.isEmpty) return true;
  final excludes = tokens.where((t) => t.startsWith('-')).map((t) => t.substring(1)).toSet();
  final includes = tokens.where((t) => !t.startsWith('-')).toSet();
  if (excludes.isNotEmpty && includes.isNotEmpty) return true; // invalid mix — fail open
  if (excludes.isNotEmpty) return !excludes.contains(platformToken);
  return includes.contains(platformToken);
}

/// [elements], minus whatever [elementMatchesEnvironment] rules out for the
/// current platform. Applied once, at load time, by every settings surface
/// (the Settings panel and standalone extension panels
/// alike) — a platform-excluded field doesn't exist on this platform's
/// session at all, not just hidden from one view of it.
List<Map<String, dynamic>> filterElementsForEnvironment(List<Map<String, dynamic>> elements) => [
  for (final el in elements)
    if (elementMatchesEnvironment(el)) el,
];

/// Whether [element] declares [target] via its `target` attribute — a
/// single target key, or a list when the same setting should surface under
/// more than one target-built modal. No fail-open: an element with no
/// `target` attribute at all matches nothing here, unlike
/// [elementMatchesEnvironment].
bool elementMatchesTarget(Map<String, dynamic> element, String target) {
  final raw = element['target'];
  final targets = switch (raw) {
    String s => [s],
    List<dynamic> l => l.whereType<String>().toList(),
    _ => const <String>[],
  };
  return targets.contains(target);
}

/// Whether [element] is flagged `common: true` — shown in Settings'
/// Common Preferences section as well as its own group's. Only meaningful for the
/// element kinds a settings panel actually persists/acts on (field, link,
/// action) — headers/dividers/markdown are chrome, never individually
/// whitelisted, same restriction [FormRenderer]'s own search already
/// applies. Unrelated to a `multiselect` option's own `common`/`uncommon`
/// disclosure-tier flags (see docs/extensions/settings.md) — different
/// scope, an option inside one field vs. the field itself.
bool elementIsCommon(Map<String, dynamic> element) {
  final type = element['type'];
  if (type != 'field' && type != 'link' && type != 'action') return false;
  return element['common'] == true;
}

class SettingsRegistry {
  final _groups = <SettingsGroup>[];

  void register(SettingsGroup group) {
    _groups.add(group);
    _groups.sort((a, b) => a.order.compareTo(b.order));
  }

  List<SettingsGroup> get groups => List.unmodifiable(_groups);

  SettingsGroup? operator [](String key) {
    for (final group in _groups) {
      if (group.key == key) return group;
    }
    return null;
  }
}

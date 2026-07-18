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
// `extension_{panelKey}` sections by the All Settings panel.
//
// The Common Settings panel shows only the fields whitelisted in
// [commonSettingsFields]; the All Settings panel shows every group.

import 'package:flutter/foundation.dart';

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
}

/// `group.field` ids shown on the Common Settings panel — everything else
/// appears under All Settings (and privacy has its own top-level panel).
const commonSettingsFields = [
  'general.themeMode',
  'general.locale',
  'general.fontScale',
  'general.distanceUnits',
];

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

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_i18n/halo_i18n.dart';

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

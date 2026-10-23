// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Where an extension's settings panels may appear: the manifest's `settings`
// declaration, and the clamp that holds what the code registers to it
// (docs/extensions/settings.md, "Where an extension's settings go").
//
// The code says where a panel goes, but the manifest is what the catalog
// reviews — it reads manifests and never runs a bundle. So a placement the
// manifest does not declare is not one the code gets: an entry in the
// sidebar, Common Preferences rows, a section outside the list below. Without
// this, review would be of a promise the bundle is free to break.

/// The settings sections an extension may place its panel in without review:
/// [SettingsGroup.key]s of the app's own groups. The first six are where a
/// panel should usually go, by the extension's main purpose; the rest suit
/// one that tunes something the app already has a section for. The catalog
/// keeps the same list (its `src/config/settings-sections.ts`) and sends
/// anything else to review.
const extensionSettingsSections = {'activities', 'hunting', 'contests', 'lookups', 'spotting', 'dashboard', 'logging', 'radio', 'map', 'exports'};

/// A manifest's `settings`: where its panels go, and the two placements only
/// a reviewed manifest may claim.
class ExtensionSettingsPlacement {
  /// The settings section the extension's panels show in, as one row each
  /// that opens the panel in a dialog. Null is a category of its own.
  final String? section;

  /// Whether its panels may also have an entry in Settings' sidebar.
  final bool sidebar;

  /// Whether its fields may also show in Common Preferences.
  final bool common;

  const ExtensionSettingsPlacement({this.section, this.sidebar = false, this.common = false});

  /// Lenient: a value it cannot read is the most restrictive answer, never a
  /// refusal. Refusing at the door would tell the operator, who can do
  /// nothing about it; the packer and the catalog tell the author.
  static ExtensionSettingsPlacement? fromJson(Object? json) {
    if (json is! Map) return null;
    final section = json['section'];
    return ExtensionSettingsPlacement(
      section: section is String && section.isNotEmpty ? section : null,
      sidebar: json['sidebar'] == true,
      common: json['common'] == true,
    );
  }
}

/// Of [available], the extension that owns [extensionKey] as the kernel
/// stamped it: the extension of that key, or else the one with the LONGEST
/// key it extends (`pota-all-parks` belongs to `pota`) — the rule
/// [CapabilityGrant.allows] reads grants by.
T? owningExtension<T>(String extensionKey, Iterable<T> available, String Function(T) keyOf) {
  T? owner;
  var ownerLength = -1;
  for (final candidate in available) {
    final key = keyOf(candidate);
    if (key == extensionKey) return candidate;
    if (!extensionKey.startsWith('$key-') && !extensionKey.startsWith('${key}_')) continue;
    if (key.length > ownerLength) {
      owner = candidate;
      ownerLength = key.length;
    }
  }
  return owner;
}

/// [panel] (one `getSettingsPanels()` entry) as its extension's manifest
/// allows it, with `mayBeCommon` added for Common Preferences to read.
///
/// [trusted] is for the app's own extensions, which keep whatever they
/// registered. Anyone else's panel:
/// - goes in the section the manifest declares, else the one the code names
///   if it is in [extensionSettingsSections], else a category of its own;
/// - has a sidebar entry only if the code asks for one AND the manifest
///   declares `sidebar: true`;
/// - contributes to Common Preferences only if the manifest declares
///   `common: true`.
Map<String, dynamic> placeSettingsPanel(Map<String, dynamic> panel, {required bool trusted, ExtensionSettingsPlacement? declared}) {
  if (trusted) return {...panel, 'mayBeCommon': true};
  final requested = panel['section'];
  final section = declared?.section ?? (requested is String && extensionSettingsSections.contains(requested) ? requested : null);
  return {...panel, 'section': section, 'sidebar': panel['sidebar'] != false && (declared?.sidebar ?? false), 'mayBeCommon': declared?.common ?? false};
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

part of 'cat_service.dart';

extension _CatCredentials on CatService {
  /// Moves secret fields out of the config and into the platform keychain.
  /// The stored config is a plain SharedPreferences JSON blob — the right
  /// home for a hostname, the wrong one for a radio password.
  ///
  /// Asks the whole CATALOGUE what counts as a secret, not this node's own
  /// pairing. The editor renders every variant's fields at once, so a node
  /// bound to a transport with no secrets of its own still arrives here
  /// carrying the password belonging to the transport beside it — an IC-705
  /// switched from WiFi to USB is exactly that. Scoped to the node's pairing,
  /// this method hands that password straight to the prefs blob in clear.
  Future<EquipmentNode> _stashSecrets(EquipmentNode node) async {
    final secretKeys = registry.allSecretFields;
    if (secretKeys.isEmpty) return node;

    final cleaned = <String, dynamic>{};
    for (final entry in node.config.entries) {
      if (secretKeys.contains(entry.key)) {
        // An empty value means "unchanged" — the editor shows secrets
        // blank, so saving a form without retyping must not wipe them.
        final value = entry.value as String? ?? '';
        if (value.isNotEmpty) {
          final stored = await _settings.setEquipmentSecret(_k4Identity(node), entry.key, value);
          // The keychain refused it — a locked keyring, a headless box.
          // Neither silent option is acceptable: dropping the value loses
          // the password entirely behind a save that looked like it worked,
          // and keeping it in `cleaned` writes a password into the plain
          // prefs blob the user has every reason to think it is NOT in.
          // So fail the save out loud instead.
          if (!stored) throw const EquipmentSecretNotStored();
        }
      } else {
        cleaned[entry.key] = entry.value;
      }
    }
    return node.copyWith(config: cleaned);
  }

  /// What THIS pairing needs to open its connection — narrower than
  /// [EquipmentRegistry.allSecretFields], and deliberately so: injecting
  /// every catalogue secret into a connect-time config would hand a serial
  /// driver an empty `password` key it never asked for.
  Set<String> _secretFieldsFor(String typeKey) => registry.typeFor(typeKey)?.secretFields ?? const {};

  /// The node's config with its secrets read back in — only ever built at
  /// connect time, never stored.
  Future<Map<String, dynamic>> _configWithSecrets(EquipmentNode node) async {
    final secretKeys = _secretFieldsFor(node.typeKey);
    if (secretKeys.isEmpty) return node.config;
    final merged = <String, dynamic>{...node.config};
    for (final field in secretKeys) {
      merged[field] = await _settings.equipmentSecret(_k4Identity(node), field) ?? '';
    }
    return merged;
  }
}

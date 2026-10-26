// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The configured equipment as it is stored: read back from settings, and
// each node's secret fields kept in the keychain rather than beside the rest
// of its config.

part of 'cat_service.dart';

extension _EquipmentStore on CatService {
  void _load() {
    final stored = _settings.stationEquipment;
    final nodes = stored['nodes'];
    if (nodes is Map) {
      for (final entry in nodes.entries) {
        final node = EquipmentNode.fromJson('${entry.key}', entry.value);
        // A single corrupt record drops that node, not the whole list.
        if (node != null) _nodes[node.uuid] = node;
      }
    }
    // Read, not derived. A stored uuid whose node did not load — a corrupt
    // record, or one written by a newer build — leaves this None rather than
    // silently designating some other radio.
    //
    // There is no equivalent node check for a peer, and there cannot be one:
    // a peer radio's existence is a fact about another device, which this
    // one cannot ask about at load. An absent peer reads as an unavailable
    // selection, not as a corrupt one.
    //
    // Version 2 and older wrote the same thing as two keys, which a
    // hand-edited or newer-build blob could set both of; the local one wins,
    // as the version that stored them decided. Written back as one key, so a
    // blob only ever states one.
    // Told apart by the VERSION the blob was written under, not by whether
    // the key is there: version 3 writes an explicit null for None, which a
    // shape probe would read as a version 2 blob and answer out of whatever
    // `radio1` a future writer happened to leave behind — resurrecting a
    // pick the operator had cleared. Same rule as `designated` below.
    final storedVersion = stored['version'];
    final storedVfo = stored['mainVfo'];
    if (storedVersion is int && storedVersion >= 3) {
      if (storedVfo is Map) {
        final uuid = storedVfo['radio'];
        if (uuid is String && _nodes.containsKey(uuid)) {
          _radio1 = LocalRadio(uuid);
        } else if (PeerRadioSelection.from(storedVfo['peer']) case final selection?) {
          _radio1 = PeerRadio(selection);
        }
      }
    } else {
      final legacyRadio1 = stored['radio1'];
      if (legacyRadio1 is String && _nodes.containsKey(legacyRadio1)) {
        _radio1 = LocalRadio(legacyRadio1);
      } else if (PeerRadioSelection.from(stored['remoteRadio1']) case final selection?) {
        _radio1 = PeerRadio(selection);
      }
    }
    final storedRadio2 = stored['radio2'];
    if (storedRadio2 is String && _nodes.containsKey(storedRadio2) && storedRadio2 != _localRadio1) _radio2 = storedRadio2;
    final designated = stored['designated'];
    if (designated is Map) {
      // Two shapes, told apart by the version the blob was written under
      // rather than by the shape of its values — a probe would have to
      // assume no category value is ever a Map, which is an invariant
      // nothing enforces, and would read a half-migrated blob as whichever
      // branch its first Map happened to select.
      //
      // Version 1 is one flat category → uuid map, and it belongs to
      // whatever was selected when it was written — which is what is being
      // loaded here, a few lines up.
      //
      // A blob with no key entry at all needs no special case either way: an
      // absent category is "never decided", which is exactly what
      // [_defaultDesignation] answers, so a station that keyed through
      // radio1 goes on doing so.
      final version = stored['version'];
      final perRadio = version is int && version >= 2;
      final byRadio = perRadio ? designated : {_designationKey(): designated};
      for (final entry in byRadio.entries) {
        final picks = entry.value;
        if (picks is! Map) continue;
        for (final pick in picks.entries) {
          final uuid = pick.value;
          // A pick whose node did not load is dropped, for [radio1]'s
          // reason. An explicit null is kept: that is the operator having
          // answered None, not a missing node.
          if (uuid != null && !(uuid is String && _nodes.containsKey(uuid))) continue;
          (_designated['${entry.key}'] ??= {})['${pick.key}'] = uuid as String?;
        }
      }
    }
  }

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
          final stored = await _settings.setEquipmentSecret(node.uuid, entry.key, value);
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
      merged[field] = await _settings.equipmentSecret(node.uuid, field) ?? '';
    }
    return merged;
  }
}

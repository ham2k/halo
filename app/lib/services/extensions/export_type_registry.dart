// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_core/halo_core.dart' show Hooks;
import 'package:halo_extension_host/halo_extension_host.dart';

/// A partial registry would turn registered exports into legacy exports,
/// bypassing the operator's per-type privacy preferences. Missing methods
/// return successful null entries; failed registrations must stop the load.
Future<List<Map<String, dynamic>>> collectExportTypes(ExtensionHost host) async {
  final entries = await host.invokeAll(Hooks.exportGetExportTypes, args: const <String, dynamic>{});
  final types = <String, Map<String, dynamic>>{};
  for (final entry in entries) {
    final hookKey = entry['key'];
    if (entry['ok'] != true) {
      throw ExtensionHostException('Export type registration failed: $hookKey: ${entry['error'] ?? 'registration unavailable'}');
    }
    final value = entry['value'];
    if (value == null) continue;
    for (final item in value as List) {
      final definition = Map<String, dynamic>.from(item as Map);
      final key = definition['exportType'];
      if (key is String && key.isNotEmpty) {
        types.putIfAbsent(key, () => {...definition, 'hookKey': hookKey});
      }
    }
  }
  return types.values.toList();
}

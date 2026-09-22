// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/foundation.dart';
import 'package:ham2k_logger/services/panel_service.dart';

/// A [PanelExtensionSource] that offers no extension panels and serves panel
/// config from memory, keyed by placement.
///
/// For NATIVE panels with a `formFields` form: their config goes through the
/// same `readPanelConfig` seam an extension panel's does — that seam is
/// Dart-owned storage on both sides, with no bridge call — so a test of a
/// native pane still needs something behind it. The real
/// `ExtensionService.readPanelConfig` needs a settings service, which is a
/// much larger fixture than "what did this pane store".
///
/// Keyed by the PLACEMENT id (`clock#2`), because that is the distinction
/// worth being able to assert: two panes of one panel must not share a key.
class FakePanelExtensions implements PanelExtensionSource {
  /// The single placement's config, for the common case of one pane.
  final Map<String, Map<String, dynamic>> configs;

  FakePanelExtensions({Map<String, dynamic>? config, Map<String, Map<String, dynamic>>? configs}) : configs = configs ?? {'clock#1': ?config};

  @override
  final ValueNotifier<int> runtimeGeneration = ValueNotifier(0);

  @override
  Future<List<Map<String, dynamic>>?> getExtensionPanels() async => const [];

  @override
  Future<Map<String, dynamic>?> renderPanel({required String hookKey, required String panelKey, required Map<String, dynamic> args}) async => null;

  @override
  Future<Map<String, dynamic>> readPanelConfig({required String panelKey, required List<Map<String, dynamic>> fields}) async {
    final stored = configs[panelKey] ?? const {};
    // Only declared fields come back, exactly as the real read does — a value
    // left behind by an older form must not reappear as config.
    return {
      for (final field in fields)
        if (stored.containsKey(field['key'])) field['key'] as String: stored[field['key']],
    };
  }

  /// What was asked to be forgotten, so a test can assert the distinction
  /// between removing a placement and removing a panel.
  final forgotten = <String>[];

  @override
  Future<void> forgetPanelConfig({required String panelKey, required List<Map<String, dynamic>> fields}) async {
    forgotten.add(panelKey);
    configs.remove(panelKey);
  }
}

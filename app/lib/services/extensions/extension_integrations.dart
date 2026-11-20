// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The `integration` hooks (docs/extensions/integrations.md): what each one
// offers, a call about one open operation, and what one says of itself in
// an operation's Integrations dialog. `IntegrationService` decides when.

part of 'extension_service.dart';

mixin _ExtensionIntegrations implements IntegrationExtensionSource {
  ExtensionHost? get host;
  List<ExtensionInfo> get availableExtensions;

  @override
  Future<List<Map<String, dynamic>>?> getExtensionIntegrations() => _offeredWatchers(host, availableExtensions, Hooks.integrationGetIntegrations);

  @override
  Future<bool> observeIntegration({required String hookKey, required String integrationKey, required Map<String, dynamic> args}) async {
    final host = this.host;
    if (host == null) return false;
    await host.invoke(Hooks.integrationObserve, key: hookKey, args: {...args, 'integrationKey': integrationKey}, timeout: const Duration(seconds: 5));
    return true;
  }

  /// Two seconds: the dialog shows the descriptor's line until it answers.
  @override
  Future<({bool called, String? line})> describeIntegration({
    required String hookKey,
    required String integrationKey,
    required Map<String, dynamic> args,
  }) async {
    final host = this.host;
    if (host == null) return (called: false, line: null);
    final described = await host.invoke(
      Hooks.integrationDescribe,
      key: hookKey,
      args: {...args, 'integrationKey': integrationKey},
      timeout: const Duration(seconds: 2),
    );
    if (described is String) return (called: true, line: described.trim().isEmpty ? null : described.trim());
    if (described != null) {
      debugPrint('[integrations] $hookKey/$integrationKey: describe answered a ${described.runtimeType}, not a line; its description stays');
    }
    return (called: true, line: null);
  }
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The `integration` hooks (docs/extensions/integrations.md): what each one
// offers, and a call about one open operation. `IntegrationService` decides
// when.

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
}

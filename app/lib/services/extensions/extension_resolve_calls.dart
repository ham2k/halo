// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Settling a saved contact's guess again from what is already stored on it —
// the lookup pipeline's own rules (extensions/core/lookups/src/resolveGuess.ts),
// with no source asked anything.

part of 'extension_service.dart';

mixin _ExtensionResolveCalls on _ExtensionHookApi {
  /// The guess [qso]'s stored `their.lookups` settle into against its refs
  /// and what the operator entered, as `{guess, lookups}` — after an edit to
  /// its location or refs. Local only, so it answers offline and for an
  /// operation without assistance. Null when the runtime is not up or did not
  /// answer; the stored guess then stands until the next settling.
  Future<Map<String, dynamic>?> resolveCallInfo(Map<String, dynamic> qso) async {
    if (ExtensionService.stubLookups) return null;
    final host = this.host;
    if (host == null) return null;
    try {
      final result = await host.invoke(Hooks.lookupServiceResolveCallInfo, key: 'core', args: {'qso': qso}, timeout: const Duration(seconds: 4));
      ErrorReportingService.recordSuccess('extensions:resolve-call');
      return _normalizedLookup(result);
    } on ExtensionHostException catch (e, st) {
      debugPrint('[extensions] resolve failed: $e');
      ErrorReportingService.reportIfRepeated('extensions:resolve-call', e, st);
      return null;
    }
  }
}

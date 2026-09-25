// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Hook calls by [HookRef], so lib code names a hook through halo_core's
// catalog ([Hooks]) instead of spelling its category and method at the call.
// Extension methods rather than a change to [ExtensionHost] itself: every
// stand-in for the host keeps the one surface it already implements.

import 'package:halo_core/halo_core.dart' show HookRef;

import '../halo_extension_host.dart' show ExtensionHost;

extension HookCalls on ExtensionHost {
  /// [ExtensionHost.invokeHook] for [hook].
  Future<dynamic> invoke(HookRef hook, {String? key, Object? args, Duration timeout = const Duration(seconds: 10)}) =>
      invokeHook(hook.category, key: key, method: hook.method, args: args, timeout: timeout);

  /// [ExtensionHost.invokeHookAll] for [hook].
  Future<List<Map<String, dynamic>>> invokeAll(HookRef hook, {Object? args, Duration timeout = const Duration(seconds: 10), bool partialOnTimeout = false}) =>
      invokeHookAll(hook.category, method: hook.method, args: args, timeout: timeout, partialOnTimeout: partialOnTimeout);
}

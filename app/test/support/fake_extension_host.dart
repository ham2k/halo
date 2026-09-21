// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/extension_service.dart';

/// An [ExtensionHost] that answers hook calls from a map instead of a JS
/// runtime. Keys are `'category:key:method'` for [invokeHook] and
/// `'category:*:method'` for [invokeHookAll]; a missing key answers null
/// (or an empty list). A value that is a [Function] is called with the
/// hook's `args`; a value that is an [Exception] is thrown, which is how a
/// test stands in for a hook that fails.
///
/// Anything beyond the two hook calls throws [NoSuchMethodError] on purpose:
/// a test that reaches the KV store or the log stream through this fake is
/// testing something the fake cannot vouch for.
class FakeExtensionHost implements ExtensionHost {
  final Map<String, Object?> stubs;

  FakeExtensionHost([this.stubs = const {}]);

  /// Settable so a test can stand the host down mid-pass, which is what a
  /// runtime replacement looks like from inside a load already running.
  bool dead = false;

  @override
  bool get isDead => dead;

  /// Runs inside [dispose], before the host is marked dead — a test asserting
  /// what the world looks like at that moment (an exit's ordering) sets it.
  Future<void> Function()? onDispose;

  @override
  Future<void> dispose() async {
    await onDispose?.call();
    dead = true;
  }

  @override
  Future<dynamic> invokeHook(
    String category, {
    String? key,
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final res = stubs['$category:$key:$method'];
    if (res is Exception) throw res;
    if (res is Function) return res(args);
    return res;
  }

  @override
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
    bool partialOnTimeout = false,
  }) async {
    var res = stubs['$category:*:$method'];
    if (res is Exception) throw res;
    if (res is Function) res = res(args);
    if (res == null) return const [];
    return (res as List).cast<Map<String, dynamic>>();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// An [ExtensionService] whose public [host] is a [FakeExtensionHost] and
/// that never starts a runtime.
///
/// The fake is visible only through the PUBLIC `host` getter; the private
/// `_host` field behind it stays null. Every hook call the service makes goes
/// through the getter — `extension_hook_calls_through_getter_test.dart`
/// enforces it — so the service's own methods and every other service that
/// reaches hooks honour the stubs. Runtime management (the clock push, bundle
/// reloads, KV writes, lifecycle) stays on the field and never reaches the
/// fake, which would refuse it anyway.
///
/// **`ready` is still false** here: it reads the field, because it answers
/// whether a runtime is up, not whether a hook can be called. A caller that
/// checks it behaves as if the runtime were down, stubs or no stubs — the
/// command interpreter and the lookup queue stand down, and Settings loads its
/// panels but still raises its "extensions unavailable" notice.
///
/// To stand in for a hook that fails, stub an [ExtensionHostException]: that
/// is what the service's methods catch. A plain [Exception] escapes them, and
/// tests a failure the runtime never produces.
class ExtensionServiceWithFakeHost extends ExtensionService {
  /// Usually a [FakeExtensionHost]; a test with its own stand-in for the
  /// host passes that instead.
  final ExtensionHost fakeHost;

  ExtensionServiceWithFakeHost([ExtensionHost? host]) : fakeHost = host ?? FakeExtensionHost();

  @override
  ExtensionHost? get host => fakeHost;

  @override
  Future<void> start() async {}

  // The real one pushes into the extension host's KV store, which the fake
  // host doesn't implement.
  @override
  Future<void> setSyncCredentials({required String deviceKey, required String operatorCall}) async {}
}

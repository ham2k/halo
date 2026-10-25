// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';

/// The uuids of the contacts a scoring batch pass hands its scorer, as the
/// runtime hands them over. A tail goes over as `qsos`; a full pass names its
/// contacts in `qsoUuids`, and the runtime folds them from its copy of the log
/// (`withLoggedQsos` in the SDK kernel). A fake standing in for the runtime
/// reads both, or it sees an empty fold wherever the host sent the whole log.
List<String> scoredUuids(Object? args) {
  final map = args as Map;
  final qsos = map['qsos'];
  if (qsos is List) return [for (final qso in qsos.cast<Map<dynamic, dynamic>>()) qso['uuid'] as String];
  return (map['qsoUuids'] as List).cast<String>();
}

/// The contacts [scoredUuids] names, for a fake that folds what they hold: a
/// full pass's read from [qsos], as the runtime reads them from its copy.
Future<List<Map<String, dynamic>>> scoredQsos(Object? args, QsosRepository qsos) async {
  final map = args as Map;
  if (map['qsos'] case final List<dynamic> sent) return sent.cast<Map<String, dynamic>>();
  final byUuid = {for (final qso in await qsos.forOperation((map['operation'] as Map)['uuid'] as String)) qso.uuid: qso.data};
  return [for (final uuid in scoredUuids(args)) ?byUuid[uuid]];
}

/// An [ExtensionHost] that answers hook calls from a map instead of a JS
/// runtime. Keys are `'category:key:method'` for [invokeHook] — and for each
/// call of an [invokeHookBatch] — and `'category:*:method'` for
/// [invokeHookAll]; a missing key answers null (or an empty list) — except in a
/// batch, where it answers as the runtime answers a call nothing registers. A value
/// that is a [Function] is called with the hook's `args`; a value that is an
/// [Exception] is thrown, which is how a test stands in for a hook that fails
/// (in a batch, that call's `ok: false` entry, as the runtime answers it).
///
/// Anything beyond the three hook calls throws [NoSuchMethodError] on purpose:
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
  Future<dynamic> invokeHook(String category, {String? key, required String method, Object? args, Duration timeout = const Duration(seconds: 10)}) async {
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

  /// Every batch the service sent, so a test can count crossings. An empty
  /// batch is not one: the real host answers it without crossing.
  final List<List<HookCall>> batches = [];

  /// The calls run together, as the runtime runs them — a stub holding one
  /// call up must not hold up the rest.
  @override
  Future<List<Map<String, dynamic>>> invokeHookBatch(
    List<HookCall> calls, {
    Duration timeout = const Duration(seconds: 10),
    bool partialOnTimeout = false,
  }) async {
    if (calls.isEmpty) return const [];
    batches.add(calls);
    return Future.wait([
      for (final (i, call) in calls.indexed)
        // Unstubbed, a batched call answers as the runtime answers a call
        // nothing registers — not the null a bare [invokeHook] falls back to,
        // which would read as a program that answered.
        if (!stubs.containsKey('${call.category}:${call.key}:${call.method}'))
          Future.value(<String, dynamic>{'key': '$i', 'ok': false, 'error': 'no hook registered for ${call.category}/${call.key ?? '*'}', 'noHandler': true})
        else
          invokeHook(call.category, key: call.key, method: call.method, args: call.args).then(
            (value) => <String, dynamic>{'key': '$i', 'ok': true, 'value': value},
            onError: (Object e) => <String, dynamic>{'key': '$i', 'ok': false, 'error': '$e'},
          ),
    ]);
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

/// For a fake [ExtensionService] that scripts [ExtensionService.lookupCall]:
/// answers a batched lookup call by call through it, so a fake written for
/// single lookups answers the spot board's batches the same way.
mixin LookupCallsOneByOne on ExtensionService {
  @override
  Future<List<Map<String, dynamic>?>> lookupCalls(
    List<({String call, Map<String, dynamic> qso})> requests, {
    required Map<String, dynamic> operation,
    bool online = true,
    required String streakKey,
  }) async => [for (final request in requests) await lookupCall(request.call, qso: request.qso, operation: operation, online: online, streakKey: streakKey)];
}

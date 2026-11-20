// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

part of 'extension_service.dart';

/// One service a `transfer` hook sends to (docs/design/transfer.md §2).
/// [label] is the service's, else its hook's; [description] its hook's.
/// [pushes] says whether the hook has a `push`: a hook may only pull.
/// [extensionKey] is the extension that registered the hook, whose accounts
/// it signs in with; null when the runtime could not say.
typedef TransferServiceInfo = ({String hookKey, String? extensionKey, String key, String label, String? description, bool pushes});

/// Every declared service by key, and the `transfer` hooks that could not
/// say which they declare, each with its error.
typedef TransferServices = ({Map<String, TransferServiceInfo> byKey, Map<String, String> failed});

/// A hook's error as the operator reads it: its first line, without the
/// JavaScript stack under it, which the console keeps.
String? _headline(Object? error) => error?.toString().split('\n').first.trim();

mixin _ExtensionTransferCalls {
  // Owned by the class or by another part of this library.
  ExtensionHost? get host;

  /// Every service a `transfer` hook declares, by service key. A service two
  /// hooks claim goes to the first to answer and the other is named in the
  /// console: two records written under one key would overwrite each other.
  ///
  /// Throws when the runtime cannot answer, or is not up yet, so a busy
  /// runtime is not mistaken for one with no transfer hooks.
  Future<TransferServices> transferServices() async {
    final host = this.host;
    if (host == null) throw ExtensionHostException('Extension runtime is not ready yet');
    // Asked at once, awaited apart: a record `.wait` would wrap a throw in a
    // ParallelWaitError that ErrorPolicy cannot see through.
    final servicesFuture = host.invokeAll(Hooks.transferServices);
    final labelsFuture = host.invokeAll(Hooks.transferLabel);
    final descriptionsFuture = host.invokeAll(Hooks.transferDescription);
    final hooksFuture = host.invoke(Hooks.runtimeListHooks, key: 'kernel', timeout: const Duration(seconds: 5));
    final services = await servicesFuture;
    final labels = await labelsFuture;
    final descriptions = await descriptionsFuture;
    final hooks = await hooksFuture;
    String? valueOf(List<Map<String, dynamic>> entries, String hookKey) =>
        entries.where((e) => e['key'] == hookKey && e['ok'] == true).map((e) => asQsonString(e['value'])).firstOrNull;
    final transferHooks = [
      for (final hook in asQsonList(hooks) ?? const [])
        if (asQsonMap(hook) case final hook? when hook['category'] == Hooks.transferPush.category) hook,
    ];
    final pushing = <String>{
      for (final hook in transferHooks)
        if (asQsonList(hook['methods'])?.contains(Hooks.transferPush.method) ?? false) ?asQsonString(hook['key']),
    };
    final extensionOf = <String, String>{
      for (final hook in transferHooks)
        if ((asQsonString(hook['key']), asQsonString(hook['extensionKey'])) case (final key?, final extension?)) key: extension,
    };
    final result = <String, TransferServiceInfo>{};
    final failed = <String, String>{};
    for (final entry in services) {
      final hookKey = entry['key'] as String?;
      if (hookKey == null) continue;
      if (entry['ok'] != true) {
        debugPrint('[extensions] transfer hook "$hookKey" could not list its services: ${entry['error']}');
        failed[hookKey] = _headline(entry['error']) ?? 'It could not list its services';
        continue;
      }
      if (entry['value'] is! List) continue;
      for (final service in (entry['value'] as List).whereType<Map<dynamic, dynamic>>()) {
        final key = asQsonString(service['key']);
        if (key == null || key.isEmpty) continue;
        // Record keys are `<service>:<destination>` in lower case: a colon
        // splits one in the wrong place, and capitals never match it.
        if (key.contains(':') || key != key.toLowerCase()) {
          debugPrint('[extensions] transfer service "$key" of "$hookKey" is ignored: a service key is lower case, without ":"');
          continue;
        }
        if (result[key] case final first?) {
          debugPrint('[extensions] transfer service "$key" is claimed by both "${first.hookKey}" and "$hookKey"; "$hookKey" is ignored for it');
          continue;
        }
        result[key] = (
          hookKey: hookKey,
          extensionKey: extensionOf[hookKey],
          key: key,
          label: asQsonString(service['label']) ?? valueOf(labels, hookKey) ?? key,
          description: valueOf(descriptions, hookKey),
          pushes: pushing.contains(hookKey),
        );
      }
    }
    return (byKey: result, failed: failed);
  }

  /// Every push every `transfer` hook suggests for [args]
  /// (`PushSuggestionsRequest`), each tagged with its `hookKey`, and the
  /// hooks that failed, each with its error. Throws when the runtime cannot
  /// answer, as [transferServices] does.
  Future<({List<Map<String, dynamic>> items, Map<String, String> failed})> suggestPushes(Map<String, dynamic> args) async {
    final host = this.host;
    if (host == null) throw ExtensionHostException('Extension runtime is not ready yet');
    final parts = partitionHookEntries(await host.invokeAll(Hooks.transferSuggestPushes, args: args));
    for (final failure in parts.failed) {
      debugPrint('[extensions] suggestPushes hook "${failure.key}" failed: ${failure.error}');
    }
    return (
      items: parts.items,
      failed: {
        for (final key in parts.unreachable) key: 'It did not answer',
        for (final failure in parts.failed) failure.key: _headline(failure.error) ?? 'It could not suggest a push',
      },
    );
  }

  /// Where [hookKey] offers to send a scope's contacts on [args]' service
  /// (`TransferDestination`s): none, one, or several. Throws what the hook
  /// throws, which names why it cannot say.
  Future<List<Map<String, dynamic>>> suggestTransferDestinations(String hookKey, Map<String, dynamic> args) async {
    final host = this.host;
    if (host == null) throw ExtensionHostException('Extension runtime is not ready yet');
    final result = await host.invoke(Hooks.transferSuggestDestinations, key: hookKey, args: args, timeout: const Duration(seconds: 20));
    return [
      for (final item in asQsonList(result) ?? const [])
        if (asQsonMap(item) case final destination? when (asQsonString(destination['id']) ?? '').isNotEmpty) destination,
    ];
  }

  /// One chunk of one station callsign's records sent by [hookKey]; one
  /// `PushRecordResult` per record. Throws when the hook does, and
  /// [HookTimeoutException] after [timeout].
  Future<List<Map<String, dynamic>>> pushRecords(String hookKey, Map<String, dynamic> args, {required Duration timeout}) async {
    final host = this.host;
    if (host == null) throw ExtensionHostException('Extension runtime is not ready yet');
    final result = await host.invoke(Hooks.transferPush, key: hookKey, args: args, timeout: timeout);
    return [for (final item in asQsonList(result) ?? const []) ?asQsonMap(item)];
  }
}

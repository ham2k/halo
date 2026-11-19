// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The `assistant` hooks (docs/extensions/assistants.md): what each one offers,
// and a call about one open operation. `AssistantService` decides when.

part of 'extension_service.dart';

mixin _ExtensionAssistants implements AssistantExtensionSource {
  ExtensionHost? get host;
  RadioHostCalls get radioCalls;
  List<ExtensionInfo> get availableExtensions;
  SpotMarksService get spotMarks;
  void noteAgentLinkObserved(String hookKey);

  /// Every assistant every `assistant` hook offers, tagged with its `hookKey`.
  /// Null means "could not ask", so a failed call never reads as every
  /// assistant having gone.
  @override
  Future<List<Map<String, dynamic>>?> getExtensionAssistants() => _offeredWatchers(host, availableExtensions, Hooks.assistantGetAssistants);

  @override
  Future<bool> observe({required String hookKey, required String assistantKey, required Map<String, dynamic> args}) async {
    final host = this.host;
    if (host == null) return false;
    try {
      await host.invoke(Hooks.assistantObserve, key: hookKey, args: {...args, 'assistantKey': assistantKey}, timeout: const Duration(seconds: 5));
    } finally {
      // A call that failed part way may still have queued events.
      noteAgentLinkObserved(hookKey);
    }
    return true;
  }

  @override
  bool canReadRadio(String? hookKey) => radioCalls.canRead(hookKey);

  @override
  void releaseSpotMarks({required Set<String> offered, required Set<String> on}) {
    // Marks are held under the extension's own key; its assistants under
    // that key or a sub-key of it.
    bool owns(String source, Set<String> hookKeys) => hookKeys.any((key) => key == source || key.startsWith('${source}_'));
    final released = [
      for (final source in spotMarks.sources)
        if (owns(source, offered) && !owns(source, on)) source,
    ];
    if (released.isNotEmpty) spotMarks.forget(released);
  }
}

/// Every entry every hook in [ref]'s category answers it with, tagged with
/// its `hookKey`: what assistants and integrations each offer. Null means
/// "could not ask", so a failed call never reads as every one having gone.
Future<List<Map<String, dynamic>>?> _offeredWatchers(ExtensionHost? host, List<ExtensionInfo> availableExtensions, HookRef ref) async {
  if (host == null) return null;
  final category = ref.category;
  try {
    // Partials kept: one extension hanging costs only its own entries.
    final entries = await host.invokeAll(ref, args: const <String, dynamic>{}, timeout: const Duration(seconds: 10), partialOnTimeout: true);
    final results = <Map<String, dynamic>>[];
    for (final entry in entries) {
      // A failed call yields nothing, and its own error is the reason: a
      // timed-out entry the host fills in carries no owner to check.
      if (entry['ok'] != true) {
        debugPrint('[extensions] $category hook "${entry['key']}" ${ref.method} failed: ${entry['error']}');
        continue;
      }
      // The manifest's `hooks` is what the install screen read, and what an
      // update is compared by: one it does not declare is one the operator
      // was never told of, so it does not run. Whose it is comes from the
      // kernel's record of who registered it, never from the hook key, which
      // the extension chose; one no installed extension owns runs for nobody.
      final hookKey = entry['key'];
      final registeredBy = entry['extensionKey'];
      final owner = registeredBy is String ? owningExtension(registeredBy, availableExtensions, (ExtensionInfo info) => info.key) : null;
      if (owner == null) {
        debugPrint('[extensions] $category hook "$hookKey" ignored: "$registeredBy" is no installed extension');
        continue;
      }
      // The hook key names the entry's id, its switch, and the extension
      // whose radio grant and spot marks it acts under: its own, by the
      // kernel's namespacing rule, checked again here.
      if (hookKey is! String || registeredBy is! String || !accountKvKeyBelongsTo(registeredBy, hookKey)) {
        debugPrint('[extensions] $category hook "$hookKey" ignored: not in the namespace of "$registeredBy"');
        continue;
      }
      if (owner.source != ExtensionSource.asset && !owner.hooks.contains(category)) {
        debugPrint('[extensions] $category hook "$hookKey" ignored: "${owner.key}" does not declare "$category" in its manifest hooks');
        continue;
      }
      if (entry['value'] is! List) {
        debugPrint('[extensions] $category hook "${entry['key']}" ${ref.method} did not return a list');
        continue;
      }
      for (final item in (entry['value'] as List)) {
        if (item is Map) results.add({...item.cast<String, dynamic>(), 'hookKey': entry['key']});
      }
    }
    return results;
  } on ExtensionHostException catch (e) {
    // The whole fan-out failing — a dead runtime, or a timeout with nothing
    // settled — leaves nothing to keep; the next runtime generation asks
    // again, and the entries already known keep running meanwhile.
    debugPrint('[extensions] ${ref.method} failed: $e');
    return null;
  } catch (e, st) {
    debugPrint('[extensions] ${ref.method} failed: $e');
    ErrorReportingService.reportIfRepeated('$category-catalog', e, st, threshold: 1);
    return null;
  }
}

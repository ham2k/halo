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

  /// Every assistant every `assistant` hook offers, tagged with its `hookKey`.
  /// Null means "could not ask", so a failed call never reads as every
  /// assistant having gone.
  @override
  Future<List<Map<String, dynamic>>?> getExtensionAssistants() async {
    final host = this.host;
    if (host == null) return null;
    try {
      // Partials kept: one extension hanging costs only its own assistants.
      final entries = await host.invokeAll(
        Hooks.assistantGetAssistants,
        args: const <String, dynamic>{},
        timeout: const Duration(seconds: 10),
        partialOnTimeout: true,
      );
      final results = <Map<String, dynamic>>[];
      for (final entry in entries) {
        // The install warning, and the re-ask on an update, read the
        // manifest's `hooks`: an assistant it does not declare is one the
        // operator was never warned about, so it does not run.
        final hookKey = entry['key'];
        final owner = hookKey is String ? owningExtension(hookKey, availableExtensions, (ExtensionInfo info) => info.key) : null;
        if (owner != null && owner.source != ExtensionSource.asset && !owner.hooks.contains(HookCategories.assistant)) {
          debugPrint('[extensions] assistant hook "$hookKey" ignored: "${owner.key}" does not declare "${HookCategories.assistant}" in its manifest hooks');
          continue;
        }
        if (entry['ok'] != true) {
          debugPrint('[extensions] assistant hook "${entry['key']}" getAssistants failed: ${entry['error']}');
          continue;
        }
        if (entry['value'] is! List) {
          debugPrint('[extensions] assistant hook "${entry['key']}" getAssistants did not return a list');
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
      // again, and the assistants already known keep running meanwhile.
      debugPrint('[extensions] getExtensionAssistants failed: $e');
      return null;
    } catch (e, st) {
      debugPrint('[extensions] getExtensionAssistants failed: $e');
      ErrorReportingService.reportIfRepeated('assistant-catalog', e, st, threshold: 1);
      return null;
    }
  }

  @override
  Future<bool> observe({required String hookKey, required String assistantKey, required Map<String, dynamic> args}) async {
    final host = this.host;
    if (host == null) return false;
    await host.invoke(Hooks.assistantObserve, key: hookKey, args: {...args, 'assistantKey': assistantKey}, timeout: const Duration(seconds: 5));
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

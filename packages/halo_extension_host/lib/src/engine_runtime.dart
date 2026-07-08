// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Platform boundary for the JS engine. `flutter_js` (QuickJS via dart:ffi)
// backs native platforms; web has no dart:ffi, so it runs the same kernel +
// extension bundles in a real Web Worker instead, talking to it over
// postMessage. See engine_runtime_io.dart / engine_runtime_web.dart and
// js_engine.dart for the conditional-export wiring.

class ExtensionBundle {
  final String key;
  final String source;

  const ExtensionBundle({required this.key, required this.source});
}

abstract class EngineRuntime {
  /// False on platforms where no engine backend could be created at all.
  /// Currently always true — native uses QuickJS, web uses a Worker — but
  /// kept as an escape hatch for platforms where neither is available.
  bool get available;

  String get engineDescription;

  /// Registers the callback invoked for every message the JS side posts on
  /// the 'polo' channel: {type:'result'|'log'|'hostCall', ...}. Must be
  /// called before [load].
  void onMessage(void Function(Map<String, dynamic> message) callback);

  /// Loads the kernel bundle, then every extension bundle in order, then
  /// activates all extensions. Throws if any step fails.
  Future<void> load(String kernelSource, List<ExtensionBundle> bundles);

  void invoke(int id, String category, String? key, String method, String argsJson);
  void invokeAll(int id, String category, String method, String argsJson);
  void hostResponse(int callId, bool ok, String resultJson);

  /// Pumps the engine's job queue, for backends (QuickJS) that don't have a
  /// real event loop and need manual pumping to process microtasks/promises.
  /// A no-op for backends (Worker) with a real event loop.
  void pump();

  void dispose();
}

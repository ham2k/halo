// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter_js/flutter_js.dart' as fjs;
// The JavaScriptCore backend (macOS/iOS) isn't re-exported from the barrel.
import 'package:flutter_js/javascriptcore/jscore_runtime.dart' show JavascriptCoreRuntime;

import 'engine_runtime.dart';

class _IoEngineRuntime implements EngineRuntime {
  late final fjs.JavascriptRuntime _runtime;
  void Function(Map<String, dynamic>)? _onMessage;

  @override
  String get engineDescription => _runtime.runtimeType.toString();

  @override
  void onMessage(void Function(Map<String, dynamic> message) callback) {
    _onMessage = callback;
  }

  @override
  void onFatalError(void Function(String message) callback) {
    // QuickJS eval failures always surface synchronously from the call that
    // triggered them (see _evaluate below) — there's no separate async crash
    // mode to report here.
  }

  /// Constructs the engine with resource limits where the backend supports
  /// them. On Android/Windows/Linux that's QuickJS: a memory limit stops one
  /// runaway extension from OOMing the whole app, and the stack limit is
  /// made explicit rather than inherited. On macOS/iOS flutter_js uses
  /// JavaScriptCore, which exposes no such knobs — full interrupt/memory
  /// control on every platform is what DESIGN.md §3's direct-FFI QuickJS
  /// binding is for; this is the portion available today.
  ///
  /// The memory limit is Android-only: flutter_js compiles the QuickJS
  /// bridge from source there, but ships stale prebuilt binaries on Linux
  /// and Windows that export jsSetMaxStackSize and NOT jsSetMemoryLimit, so
  /// a non-null memoryLimit crashes engine startup on those platforms.
  fjs.JavascriptRuntime _createRuntime() {
    if (Platform.isAndroid || Platform.isWindows || Platform.isLinux) {
      final runtime = fjs.QuickJsRuntime2(
        stackSize: 2 * 1024 * 1024,
        memoryLimit: Platform.isAndroid ? 256 * 1024 * 1024 : null,
        hostPromiseRejectionHandler: (dynamic reason) {
          _onMessage?.call({'type': 'log', 'message': 'ERROR unhandled promise rejection: $reason'});
        },
      );
      runtime.enableHandlePromises();
      return runtime;
    }
    // Same construction getJavascriptRuntime(xhr: false) performs on these
    // platforms, minus the fetch polyfill.
    final runtime = JavascriptCoreRuntime();
    runtime.enableHandlePromises();
    return runtime;
  }

  @override
  Future<void> load(String kernelSource, List<ExtensionBundle> bundles) async {
    _runtime = _createRuntime();
    _runtime.onMessage('polo', (dynamic args) {
      final msg = (args is String ? jsonDecode(args) : args) as Map;
      _onMessage?.call(msg.cast<String, dynamic>());
      return null;
    });

    _evaluate(kernelSource, name: 'kernel');
    for (final bundle in bundles) {
      // The begin/end bracket is what makes extension identity
      // host-declared: the kernel only accepts defineExtension keys matching
      // the manifest key this bundle was loaded under.
      _evaluate('__polo.beginBundle(${jsonEncode(bundle.key)})', name: 'beginBundle');
      _evaluate(bundle.source, name: bundle.key);
      _evaluate('__polo.endBundle()', name: 'endBundle');
    }
    // Activation is deferred until every bundle is evaluated, so extensions
    // never depend on declaration order within their own bundle.
    _evaluate('__polo.activateAll()', name: 'activateAll');
  }

  @override
  void invoke(int id, String category, String? key, String method, String argsJson) {
    _evaluate(
      '__polo.invokeHook('
      '$id, '
      '${jsonEncode(category)}, '
      '${key == null ? 'null' : jsonEncode(key)}, '
      '${jsonEncode(method)}, '
      '${jsonEncode(argsJson)})',
      name: 'invokeHook',
    );
  }

  @override
  void invokeAll(int id, String category, String method, String argsJson) {
    _evaluate(
      '__polo.invokeHookAll('
      '$id, '
      '${jsonEncode(category)}, '
      '${jsonEncode(method)}, '
      '${jsonEncode(argsJson)})',
      name: 'invokeHookAll',
    );
  }

  @override
  void hostResponse(int callId, bool ok, String resultJson) {
    _evaluate('__polo.hostResponse($callId, $ok, ${jsonEncode(resultJson)})', name: 'hostResponse');
  }

  @override
  void invalidateContext() {
    _evaluate('__polo.invalidateContext()', name: 'invalidateContext');
  }

  void _evaluate(String code, {required String name}) {
    final result = _runtime.evaluate(code);
    if (result.isError) {
      throw ExtensionHostException('evaluating $name: ${result.stringResult}');
    }
    pump();
  }

  @override
  void pump() {
    try {
      _runtime.executePendingJob();
    } catch (_) {
      // Engines without an explicit job queue may not support this.
    }
  }

  @override
  void dispose() {}
}

EngineRuntime createEngineRuntime() => _IoEngineRuntime();

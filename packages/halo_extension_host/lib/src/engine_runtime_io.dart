// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';

import 'package:flutter_js/flutter_js.dart' as fjs;

import 'engine_runtime.dart';

class _IoEngineRuntime implements EngineRuntime {
  late final fjs.JavascriptRuntime _runtime;
  void Function(Map<String, dynamic>)? _onMessage;

  @override
  bool get available => true;

  @override
  String get engineDescription => _runtime.runtimeType.toString();

  @override
  void onMessage(void Function(Map<String, dynamic> message) callback) {
    _onMessage = callback;
  }

  @override
  Future<void> load(String kernelSource, List<ExtensionBundle> bundles) async {
    _runtime = fjs.getJavascriptRuntime(xhr: false);
    _runtime.onMessage('polo', (dynamic args) {
      final msg = (args is String ? jsonDecode(args) : args) as Map;
      _onMessage?.call(msg.cast<String, dynamic>());
      return null;
    });

    _evaluate(kernelSource, name: 'kernel');
    for (final bundle in bundles) {
      _evaluate(bundle.source, name: bundle.key);
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

  void _evaluate(String code, {required String name}) {
    final result = _runtime.evaluate(code);
    if (result.isError) {
      throw StateError('evaluating $name: ${result.stringResult}');
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

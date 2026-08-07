// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:halo_quickjs/halo_quickjs.dart';

import 'engine_runtime.dart';

/// Flutter's `kIsWeb` under another name, resolved by the same conditional
/// export that picks the engine backend (js_engine.dart). This package must
/// stay importable from a plain Dart VM — the halo-ext CLI boots the very
/// same host — and `package:flutter/foundation.dart` pulls in `dart:ui`,
/// which does not exist there.
const bool runningOnWeb = false;

class _IoEngineRuntime implements EngineRuntime {
  // Deliberately nullable rather than `late final`: if construction fails
  // (e.g. the library search cannot find the host build), the host's error
  // path calls dispose(), and a `late` field would throw
  // LateInitializationError there and BURY the real cause.
  HaloQuickJs? _js;
  void Function(Map<String, dynamic>)? _onMessage;
  bool _disposed = false;

  /// Wall-clock ceiling for one pump() call. Well under the host's 10s hook
  /// timeout so the isolate stays able to answer while jobs are still running.
  static const int _maxDrainMs = 500;

  @override
  String get engineDescription => 'halo_quickjs (${HaloQuickJs.version})';

  @override
  void onMessage(void Function(Map<String, dynamic> message) callback) {
    _onMessage = callback;
  }

  @override
  void onFatalError(void Function(String message) callback) {
    // Every failure surfaces synchronously from the call that caused it (see
    // _evaluate) — there is no separate async crash mode for an in-process
    // engine to report.
  }

  /// QuickJS-NG on every native platform, compiled into the app by
  /// packages/halo_quickjs (see docs/design/js-engine.md).
  HaloQuickJs _createRuntime() {
    final js = HaloQuickJs();

    // The guard must sit BELOW the host thread's real native stack. If it is
    // larger, QuickJS never trips its own check, the OS stack overflows first,
    // and the process dies with an uncatchable fault — no Dart error, nothing
    // on Sentry.
    //
    // 512KB on EVERY platform, deliberately. Do not raise it per platform:
    // "Linux threads default to 8MB" is the pthread default, not the stack a
    // Dart isolate thread gets, which the VM sizes itself. Measured on a
    // spawned isolate, recursing until the guard fires:
    //
    //     512KB -> caught,  527 frames
    //    1024KB -> caught, 1056 frames
    //    1536KB -> process killed, SIGBUS
    //    2048KB -> process killed, SIGBUS
    //
    // So a "generous" value is the dangerous one. 512KB is the shim's own
    // default and is safely inside the smallest plausible isolate stack; the
    // only thing a larger guard buys is ~1000 extra frames, and extension
    // hooks are shallow. A legitimately deeper call raises a catchable
    // RangeError that _evaluate turns into an ExtensionHostException.
    //
    // Measured on macOS. The isolate thread stack on Linux, Windows and
    // Android has NOT been measured — which is the reason to stay at the value
    // that is safe everywhere rather than tune per platform.
    js.maxStackSize = 512 * 1024;

    // Android-only, deliberately: Android is the platform where one runaway
    // extension OOMing the app is a real, observed risk. Extending a ceiling
    // to desktop is a behaviour change on platforms that have never had one
    // and do the largest imports (~181k SOTA summits), so it belongs with the
    // untrusted-extension work.
    if (Platform.isAndroid) js.memoryLimit = 256 * 1024 * 1024;

    // Without an interrupt handler a runaway hook wedges the extension-host
    // isolate permanently: the host's own 10s timeout reports the failed
    // hook, but the JS keeps spinning forever and every later hook queues
    // behind it. 15s sits above that timeout on
    // purpose — the host still reports first, and this only exists to make the
    // isolate usable again afterwards. The budget covers one outermost call
    // including anything nested, so a hook cannot extend it by calling out.
    js.evalBudgetMs = 15000;

    return js;
  }

  @override
  Future<void> load(String kernelSource, List<ExtensionBundle> bundles) async {
    final js = _createRuntime();
    _js = js;
    js.onSend((channel, message) {
      // The shim reports unhandled promise rejections on their own channel.
      // Without this they are utterly silent — nothing throws, no eval returns
      // non-zero, the reaction just never runs. Shaped as a log message so it
      // lands wherever every other extension diagnostic already does.
      if (channel == 'polo:unhandledRejection') {
        _onMessage?.call({'type': 'log', 'message': 'ERROR unhandled promise rejection: $message'});
        return;
      }
      if (channel != 'polo') return;
      final decoded = jsonDecode(message);
      if (decoded is Map) _onMessage?.call(decoded.cast<String, dynamic>());
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
  void invokeAll(int id, String category, String method, String argsJson, {bool wantsPartials = false}) {
    _evaluate(
      '__polo.invokeHookAll('
      '$id, '
      '${jsonEncode(category)}, '
      '${jsonEncode(method)}, '
      '${jsonEncode(argsJson)}, '
      '$wantsPartials)',
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
    final js = _js;
    if (js == null) throw ExtensionHostException('evaluating $name: engine not loaded');
    final result = js.eval(code, filename: name);
    if (!result.ok) {
      throw ExtensionHostException('evaluating $name: ${result.text}');
    }
    pump();
  }

  /// Drains the queue rather than running a single job.
  ///
  /// halo_qjs_execute_pending_job runs exactly ONE job. A hook that awaits
  /// N times needs N turns, and pump()
  /// is otherwise only driven again by the host's periodic timer — so running
  /// one job per call would add a timer interval of latency per await, and a
  /// chain long enough would not settle before the host's hook timeout.
  ///
  /// The bound is a runaway guard, not a queue limit: a job that schedules
  /// another job unconditionally would spin here forever. Anything legitimate
  /// settles in a handful of turns.
  @override
  void pump() {
    final js = _js;
    if (js == null || _disposed) return;
    final elapsed = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      // 0 means the queue is empty; NEGATIVE means the job threw, and there
      // may still be more queued behind it. Treating <0 as "done" would defer
      // the rest of the queue to the host's next 5ms tick.
      if (js.pump() == 0) return;

      // A COUNT bound is not enough. The eval budget is per outermost call and
      // every pump() is one, so each job gets a fresh 15s — 1000 of them is
      // hours of one synchronous drain, during which this isolate dispatches
      // nothing at all, including 'dispose' and 'abandon'. Cutting the drain
      // short loses nothing; the host's 5ms timer comes straight back for
      // whatever is left.
      if (elapsed.elapsedMilliseconds >= _maxDrainMs) return;
    }
  }

  /// Frees the engine's native heap (10-12MB for the kernel bundle alone) and
  /// closes the NativeCallable behind onSend, which would otherwise keep its
  /// isolate alive forever (docs/design/js-engine.md §3).
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _js?.dispose();
  }
}

EngineRuntime createEngineRuntime() => _IoEngineRuntime();

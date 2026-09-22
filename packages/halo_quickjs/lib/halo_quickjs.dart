// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// dart:ffi binding to QuickJS-NG, compiled into this plugin's own library.
//
// No QuickJS type crosses this boundary — see src/halo_qjs.h for why that is
// required rather than merely tidy (JSValue is a uint64_t on 32-bit targets
// and a 16-byte struct on 64-bit ones, and Dart FFI bindings are resolved at
// compile time).

import 'dart:convert';
import 'dart:ffi';
import 'dart:io' show Platform, File, Directory;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef _SendNative = Void Function(Pointer<Void>, Pointer<Char>, Pointer<Char>);

/// Called for every `sendMessage(channel, message)` the JS side makes.
///
/// Runs SYNCHRONOUSLY inside the engine, on the calling thread, and MAY
/// re-enter the engine (the extension host does exactly that on its
/// kvGet/kvSet path). Must not throw: a Dart exception here is swallowed
/// whole — JS sees `undefined` and nothing surfaces anywhere — so failures
/// have to be encoded in whatever the host sends back, never signalled.
typedef HaloQuickJsSend = void Function(String channel, String message);

/// Resolves the library holding the shim.
///
/// On macOS/iOS the sources are compiled into the app binary itself, so the
/// symbols are already in the process. On Linux/Windows/Android the plugin
/// is its own shared library. Under `flutter test` there is no platform
/// build at all, so a host library built by tool/build_host.sh is used.
DynamicLibrary _openLibrary() {
  const envOverride = String.fromEnvironment('HALO_QUICKJS_LIB');
  if (envOverride.isNotEmpty) return DynamicLibrary.open(envOverride);

  if (Platform.isMacOS || Platform.isIOS) {
    try {
      final p = DynamicLibrary.process();
      p.lookup<Void>('halo_qjs_new'); // present only when linked into the app
      return p;
    } on ArgumentError {
      // Not linked in — we are almost certainly under `flutter test`.
    }
  }

  for (final candidate in _hostCandidates()) {
    if (File(candidate).existsSync()) return DynamicLibrary.open(candidate);
  }

  // Normal plugin case.
  if (Platform.isLinux || Platform.isAndroid) return DynamicLibrary.open('libhalo_quickjs.so');
  if (Platform.isWindows) return DynamicLibrary.open('halo_quickjs.dll');

  // macOS/iOS with the symbols not in the process and no host build found.
  // Say what was actually looked for: the alternative is an opaque failure
  // from whatever touches the engine first.
  throw StateError(
    'halo_quickjs: could not find the engine library.\n'
    'Under `flutter test` it must be built first: packages/halo_quickjs/tool/build_host.sh\n'
    '(scripts/test.sh does this). Looked in:\n'
    '  ${_hostCandidates().join('\n  ')}',
  );
}

List<String> _hostCandidates() {
  final ext = Platform.isMacOS ? 'dylib' : (Platform.isWindows ? 'dll' : 'so');
  final name = Platform.isWindows ? 'halo_quickjs.$ext' : 'libhalo_quickjs.$ext';

  // `flutter test` runs with the cwd set to whichever package is under test,
  // and there is no platform build to provide the library — so find the one
  // tool/build_host.sh produced by walking UP to the repo root. A fixed list
  // of relative guesses only works for the depth it was written for, and a
  // miss surfaces as a LateInitializationError that names nothing useful.
  final candidates = <String>['build/host/$name'];
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    candidates.add('${dir.path}/packages/halo_quickjs/build/host/$name');
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return candidates;
}

final DynamicLibrary _lib = _openLibrary();

final _new = _lib.lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>('halo_qjs_new');
final _free = _lib.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('halo_qjs_free');
final _eval = _lib
    .lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Char>, Pointer<Char>, Pointer<Pointer<Char>>),
      int Function(Pointer<Void>, Pointer<Char>, Pointer<Char>, Pointer<Pointer<Char>>)
    >('halo_qjs_eval');
final _setHostFn = _lib
    .lookupFunction<
      Void Function(Pointer<Void>, Pointer<Char>, Pointer<NativeFunction<_SendNative>>, Pointer<Void>),
      void Function(Pointer<Void>, Pointer<Char>, Pointer<NativeFunction<_SendNative>>, Pointer<Void>)
    >('halo_qjs_set_host_fn');
final _freeString = _lib.lookupFunction<Void Function(Pointer<Char>), void Function(Pointer<Char>)>('halo_qjs_free_string');
final _pump = _lib.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>('halo_qjs_execute_pending_job');
final _setMemoryLimit = _lib.lookupFunction<Void Function(Pointer<Void>, Size), void Function(Pointer<Void>, int)>('halo_qjs_set_memory_limit');
final _setMaxStackSize = _lib.lookupFunction<Void Function(Pointer<Void>, Size), void Function(Pointer<Void>, int)>('halo_qjs_set_max_stack_size');
final _setBudget = _lib.lookupFunction<Void Function(Pointer<Void>, Int64), void Function(Pointer<Void>, int)>('halo_qjs_set_eval_budget_ms');
final _version = _lib.lookupFunction<Pointer<Char> Function(), Pointer<Char> Function()>('halo_qjs_version');

/// The name the kernel expects. `extensions/sdk/src/kernel.ts` declares
/// `sendMessage(channel, message)` and then `delete`s the global as its
/// containment boundary — so this is fixed, not configurable. A mismatch
/// fails silently: the kernel falls back to a throwing shadow and hooks
/// simply stop working.
const String kSendGlobal = 'sendMessage';

String _fromC(Pointer<Char> p) {
  if (p == nullptr) return '';
  final bytes = p.cast<Uint8>();
  var len = 0;
  while (bytes[len] != 0) {
    len++;
  }
  // Copy out rather than viewing the pointer's buffer: the view's offset is
  // not something to rely on, and C may free this the moment we return.
  return utf8.decode(Uint8List.fromList(bytes.asTypedList(len)));
}

/// The result of one evaluation. Errors are DATA, not exceptions — the host
/// treats a failing hook as a degraded hook, never a crash.
class HaloQuickJsResult {
  final bool ok;

  /// On success, the value coerced to a string. On failure, `message\nstack`.
  final String text;

  const HaloQuickJsResult(this.ok, this.text);

  @override
  String toString() => ok ? text : 'error: $text';
}

class HaloQuickJs {
  Pointer<Void> _h;
  final List<NativeCallable<_SendNative>> _callbacks = [];
  bool _disposed = false;

  HaloQuickJs() : _h = _new() {
    if (_h == nullptr) throw StateError('halo_quickjs: could not create a runtime');
  }

  static String get version => _fromC(_version());

  /// Installs [fn] as the JS-callable host bridge.
  ///
  /// Calling this more than once replaces the Dart side for every previously
  /// installed JS function too — the shim holds a single host function — so
  /// the old callable is closed here rather than leaked.
  void onSend(HaloQuickJsSend fn) {
    _checkAlive();
    final cb = NativeCallable<_SendNative>.isolateLocal((Pointer<Void> _, Pointer<Char> channel, Pointer<Char> message) {
      // Deliberately total: an exception escaping here is invisible to both
      // sides, so there is nothing useful a throw could accomplish.
      try {
        fn(_fromC(channel), _fromC(message));
      } catch (_) {}
    });
    // Close any previous one: an unclosed NativeCallable keeps its isolate
    // alive forever, which on the extension host means it never shuts down.
    for (final old in _callbacks) {
      old.close();
    }
    _callbacks
      ..clear()
      ..add(cb);

    final name = kSendGlobal.toNativeUtf8();
    try {
      _setHostFn(_h, name.cast(), cb.nativeFunction, nullptr);
    } finally {
      malloc.free(name); // Dart frees what Dart allocated; never cross heaps
    }
  }

  HaloQuickJsResult eval(String code, {String filename = '<eval>'}) {
    _checkAlive();
    final codeP = code.toNativeUtf8();
    final nameP = filename.toNativeUtf8();
    final outPP = malloc<Pointer<Char>>()..value = nullptr;
    try {
      final rc = _eval(_h, codeP.cast(), nameP.cast(), outPP);
      final text = _fromC(outPP.value);
      if (outPP.value != nullptr) _freeString(outPP.value); // C frees C's memory
      return HaloQuickJsResult(rc == 0, text);
    } finally {
      malloc.free(codeP);
      malloc.free(nameP);
      malloc.free(outPP);
    }
  }

  /// Runs one pending promise reaction. >0 a job ran, 0 none, <0 it threw.
  int pump() {
    _checkAlive();
    return _pump(_h);
  }

  set memoryLimit(int bytes) {
    _checkAlive();
    _setMemoryLimit(_h, bytes);
  }

  set maxStackSize(int bytes) {
    _checkAlive();
    _setMaxStackSize(_h, bytes);
  }

  /// Wall-clock budget for one outermost call. 0 disables. The budget covers
  /// nested re-entry too, so a hook cannot extend it by calling out.
  set evalBudgetMs(int ms) {
    _checkAlive();
    _setBudget(_h, ms);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _free(_h);
    _h = nullptr;
    for (final cb in _callbacks) {
      cb.close();
    }
    _callbacks.clear();
  }

  void _checkAlive() {
    if (_disposed) throw StateError('halo_quickjs: used after dispose()');
  }
}

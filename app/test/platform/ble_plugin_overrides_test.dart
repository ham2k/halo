// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Guards the vendored `universal_ble` copy: that Windows resolves to it rather
// than to the published package, and that the hunks inside it survive — the
// UI-thread hop's teardown gate, its atomic `hwnd_`, the Release PDB flags, and
// the asynchronous code's ownership of what it reads after it suspends.
//
// All of it is invisible to every other signal, for the same reason the
// webview override tests exist (see webview_plugin_overrides_test.dart):
// nothing in ./scripts/test.sh or in any GitHub CI job compiles C++ or
// configures CMake, so a dropped hunk stays green everywhere until a
// tag-triggered Codemagic release — and for these hunks the failure would not
// be a build error either, just a crash that comes back.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The plugin list Flutter generates at `pub get` and feeds to every build.
/// Reading it rather than the pubspec is deliberate: the pubspec states an
/// intent, this file records what resolution actually produced.
Map<String, dynamic> _resolvedPlugins() {
  final file = File('.flutter-plugins-dependencies');
  if (!file.existsSync()) {
    fail(
      'No .flutter-plugins-dependencies — run `flutter pub get` in app/ first. '
      'This file is what the build consumes, so its absence means this test '
      'cannot answer the question it exists to answer.',
    );
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

Map<String, dynamic>? _pluginFor(String platform, String name) {
  final plugins = _resolvedPlugins()['plugins'] as Map<String, dynamic>;
  for (final plugin in (plugins[platform] as List).cast<Map<String, dynamic>>()) {
    if (plugin['name'] == name) return plugin;
  }
  return null;
}

/// A resolved plugin path as posix. The Windows builders write backslashes
/// into `.flutter-plugins-dependencies`, and an un-normalised `contains`
/// would fail there claiming the package we displace had been pulled back in.
String _posixPath(Object? path) => path.toString().replaceAll(r'\', '/');

/// One file from the vendored copy, failed loudly rather than read as empty:
/// a missing file means the override points somewhere unexpected, which is a
/// different failure from the patch having been dropped.
String _vendored(String relativePath) {
  const root = '../packages/universal_ble_patched/';
  final file = File('$root$relativePath');
  if (!file.existsSync()) {
    fail(
      'No $root$relativePath — the universal_ble override points at a package '
      'without it, so this test cannot answer the question it exists to answer.',
    );
  }
  return file.readAsStringSync();
}

/// The body of [function] in [source]: from its signature to the first line
/// that closes a top-level block.
String _body(String source, String function) {
  final start = source.indexOf(function);
  if (start < 0) fail('No $function in the vendored plugin');
  final rest = source.substring(start);
  return rest.substring(0, rest.indexOf('\n}'));
}

void main() {
  test('Windows resolves to the vendored copy, not the published one', () {
    final plugin = _pluginFor('windows', 'universal_ble');
    expect(plugin, isNotNull);
    expect(_posixPath(plugin!['path']), contains('packages/universal_ble_patched'));
  });

  test('the UI-thread hop refuses work once teardown has begun', () {
    // Resolving to the vendored directory is not the same as the patch being
    // in it: PATCH.md's re-vendor procedure is "copy the new package over this
    // directory, then re-apply", and a copy that stops after the first half
    // leaves the assertion above true.
    //
    // Post() and the queue drain both check `accepting_` under the mutex, so a
    // callback queued during teardown is dropped rather than run against
    // members already reset.
    final source = _vendored('windows/src/ui_thread_handler.hpp');
    expect(source, contains('accepting_'));
    final post = source.substring(source.indexOf('void Post('));
    expect(
      post.substring(0, post.indexOf('\n    }')),
      contains('if (!accepting_)'),
      reason:
          'work queued after Shutdown() would run against a half-destroyed '
          'plugin',
    );
    final handle = source.substring(source.indexOf('HandleWindowMessage(\n'));
    expect(
      handle,
      contains('if (!accepting_)'),
      reason:
          'a window message already posted before Shutdown() still arrives '
          'afterwards; the drain has to refuse it too',
    );
  });

  test('Shutdown() is idempotent, because teardown calls it twice', () {
    // ~UniversalBlePlugin calls Shutdown() explicitly, and then the member's
    // own destructor calls it again. Without the early return the second call
    // hands the engine a window-proc id it has already retired. `accepting_`
    // is the only thing standing between those two calls, and it must be
    // cleared BEFORE the unregister: it is what makes a message already in
    // the queue harmless, so it has to be false before the delegate can stop
    // being called, not after.
    final source = _vendored('windows/src/ui_thread_handler.hpp');
    final shutdown = source.substring(source.indexOf('void Shutdown()'));
    final body = shutdown.substring(0, shutdown.indexOf('\n    }'));
    expect(
      body,
      contains('if (!accepting_)'),
      reason:
          'without the early return, teardown double-unregisters the '
          'delegate on every single shutdown',
    );
    expect(
      body.indexOf('accepting_ = false'),
      lessThan(body.indexOf('UnregisterTopLevelWindowProcDelegate')),
      reason:
          'clearing the flag after the unregister leaves a window where '
          'the delegate is gone but the queue still accepts work',
    );
  });

  test('the plugin shuts the UI-thread hop down before tearing itself down', () {
    // Members are destroyed AFTER the destructor body, so without this call
    // the delegate is still hooked and still draining while ClearServices()
    // and the channel resets run — and several queued callbacks capture
    // `this`. Ordering is the whole content of the fix: a Shutdown() placed
    // after those lines closes nothing.
    final source = _vendored('windows/src/universal_ble_plugin.cpp');
    final dtor = source.substring(source.indexOf('UniversalBlePlugin::~UniversalBlePlugin'));
    final body = dtor.substring(0, dtor.indexOf('\n}'));
    expect(body, contains('ui_thread_handler_.Shutdown()'));
    expect(
      body.indexOf('ui_thread_handler_.Shutdown()'),
      lessThan(body.indexOf('ClearServices()')),
      reason:
          'shutting the hop down after the services are cleared leaves '
          'exactly the window the crash arrives through',
    );
  });

  test('hwnd_ is atomic, which upstream has not fixed', () {
    // Written by the UI thread on the first window message, read by whichever
    // thread calls Post(). Upstream races on it on every launch, so unlike the
    // teardown gate this hunk cannot be recovered by taking their newer file:
    // a re-vendor would drop it while looking like an upgrade.
    final source = _vendored('windows/src/ui_thread_handler.hpp');
    expect(
      source,
      contains('std::atomic<HWND> hwnd_'),
      reason:
          'a plain HWND here is a data race between the UI thread and '
          'every Post() caller',
    );
  });

  test('the vendored copy still emits a Release PDB for its own code', () {
    final source = _vendored('windows/CMakeLists.txt');
    expect(
      source,
      contains(r'target_compile_options(${PLUGIN_NAME} PRIVATE $<$<CONFIG:Release>:/Zi>)'),
      reason:
          'without a PDB a crash inside this plugin resolves in Sentry to '
          'the nearest exported symbol only — which is how HALO-290 spent '
          'three rounds attributing these frames to MSVCP140',
    );
    expect(
      source,
      contains(r'target_link_options(${PLUGIN_NAME} PRIVATE $<$<CONFIG:Release>:/DEBUG>)'),
      reason:
          'MSVC emits the linked PDB only with the linker\'s /DEBUG — /Zi '
          'alone leaves compiler-side PDBs the release pipeline never uploads, '
          'so dropping just this line defeats the hunk while the /Zi check '
          'above stays green',
    );
  });

  test('no coroutine takes a string by reference', () {
    // A platform-channel handler that starts a coroutine returns at the
    // coroutine's first suspension, and the message its strings live in is
    // freed then: a reference parameter read after that reads freed memory,
    // as an error path's log line does whenever the device makes it fail.
    final header = _vendored('windows/src/universal_ble_plugin.h');
    final source = _vendored('windows/src/universal_ble_plugin.cpp');
    final declarations = RegExp(r'fire_and_forget\s+(?:UniversalBlePlugin::)?\w+\(([^)]*)\)');
    for (final match in [...declarations.allMatches(header), ...declarations.allMatches(source)]) {
      expect(match.group(1), isNot(contains(RegExp(r'std::string\s*&'))), reason: match.group(0));
    }
  });

  test('no completion handler captures by reference', () {
    // A .Completed handler runs on a thread-pool thread after the call that
    // set it up has returned, and with it the strings `[&` would refer to.
    final source = _vendored('windows/src/universal_ble_plugin.cpp');
    expect(source, isNot(contains('.Completed([&')));
  });

  test('a disconnect seen on an event thread is cleaned up on the UI thread', () {
    // The device map and its agents are the UI thread's alone. Cleaned up
    // straight from a WinRT event, an agent is destroyed while the UI thread
    // is in the middle of a write or a disconnect that is using it.
    final source = _vendored('windows/src/universal_ble_plugin.cpp');
    for (final handler in ['void UniversalBlePlugin::BluetoothLeDeviceConnectionStatusChanged(', 'void UniversalBlePlugin::NotifyConnectionException(']) {
      final body = _body(source, handler);
      expect(body, contains('CleanConnection('), reason: handler);
      expect(
        body.indexOf('ui_thread_handler_.Post('),
        allOf(greaterThanOrEqualTo(0), lessThan(body.indexOf('CleanConnection('))),
        reason: '$handler must post its cleanup to the UI thread',
      );
    }
  });

  test('a notification subscription finds its device again after the descriptor write', () {
    // The device can disconnect while the write is out, and its agent be
    // destroyed with it: a reference into the agent held across the await
    // writes the new subscription into freed memory.
    final body = _body(_vendored('windows/src/universal_ble_plugin.cpp'), 'UniversalBlePlugin::SetNotifiableAsync(');
    final firstAwait = body.indexOf('co_await');
    expect(body.substring(0, firstAwait), isNot(contains('auto &gatt_char')));
    final after = body.substring(body.indexOf('co_await ui_thread;'));
    expect(after, contains('connected_devices_.find('));
  });

  test('service discovery reads no agent once it has suspended', () {
    // The rest of the loop runs in the background, by when the agent and its
    // map may be gone: the services are copied out before the first await.
    final body = _body(_vendored('windows/src/universal_ble_plugin.cpp'), 'UniversalBlePlugin::DiscoverServicesAsync(');
    // The outermost loop the first await sits in, from its `for` line on.
    final beforeAwait = body.substring(0, body.indexOf('co_await'));
    final loop = RegExp(r'^    for \(', multiLine: true).allMatches(beforeAwait).last.start;
    expect(body.substring(loop), isNot(contains('it->second')));
  });
}

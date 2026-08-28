// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Guards the vendored `universal_ble` copy: that Windows resolves to it
// rather than to the published package, and that the four hunks inside it
// survive — the `HAM2K_BLE_MODE` header, its two call sites, and the Release
// PDB flags.
//
// All of it is invisible to every other signal, for the same reason the
// webview override tests exist (see webview_plugin_overrides_test.dart):
// nothing in ./scripts/test.sh or in any GitHub CI job compiles C++ or
// configures CMake, so a dropped hunk stays green everywhere until a
// tag-triggered Codemagic release — and for THIS patch the failure would not
// even be a build error, just a diagnostic build that silently answers the
// wrong question on the one machine that can run the experiment.
//
// Delete this file with the override it guards, once HALO-290 has its answer.

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

void main() {
  test('Windows resolves to the vendored copy, not the published one', () {
    final plugin = _pluginFor('windows', 'universal_ble');
    expect(plugin, isNotNull);
    expect(_posixPath(plugin!['path']), contains('packages/universal_ble_patched'));
  });

  test('the A/B switch header is still there', () {
    // Resolving to the vendored directory is not the same as the patch being
    // in it: PATCH.md's re-vendor procedure is "copy the new package over
    // this directory, then re-apply", and a copy that stops after the first
    // half leaves the assertion above true.
    final source = _vendored('windows/src/ham2k_ble_mode.h');
    expect(source, contains('HAM2K_BLE_MODE'));
    for (final arm in [
      'kOff',
      'kRegistrarOnly',
      'kNoChannels',
      'kNoDelegate',
      'kNoInit',
      'kNormal',
    ]) {
      expect(
        source,
        contains(arm),
        reason: 'the arms form a ladder from the known-good arm (off) to the '
            'known-bad one (noinit); losing a rung leaves a gap the bisect '
            'cannot close, and the gap is invisible until someone runs it',
      );
    }
  });

  test('each rung of the ladder is actually wired to something', () {
    // An arm that parses but gates nothing is worse than no arm: it launches,
    // reads as exonerating the step it names, and sends the next round after
    // the wrong code. Build 155 cost a release cycle per answer, so a dud rung
    // is expensive.
    expect(
      _vendored('windows/universal_ble_plugin_c_api.cpp'),
      contains('kRegistrarOnly'),
      reason: 'the registrar arm has to stop BETWEEN GetRegistrar and '
          'RegisterWithRegistrar, which only the C API can do',
    );
    expect(
      _vendored('windows/src/universal_ble_plugin.cpp'),
      contains('kNoChannels'),
      reason: 'the nochannels arm gates the four SetUp calls in '
          'RegisterWithRegistrar',
    );
    expect(
      _vendored('windows/src/ui_thread_handler.hpp'),
      contains('kNoDelegate'),
      reason: 'the nodelegate arm gates RegisterTopLevelWindowProcDelegate, '
          'the window proc hook mtx_do_lock is reached through',
    );
  });

  test('the nodelegate arm does not unregister a delegate it never registered', () {
    // Without the guard, ~UniversalBleUiThreadHandler hands the engine a
    // window-proc id that was never issued. That is its own crash, in the one
    // arm whose result we most need to trust — and it would read as "the
    // delegate IS the problem", the exact conclusion the arm exists to test.
    final source = _vendored('windows/src/ui_thread_handler.hpp');
    expect(source, contains('registered_'));
    final body = source.substring(source.indexOf('~UniversalBleUiThreadHandler'));
    expect(
      body.substring(0, body.indexOf('\n    }')),
      contains('if (registered_)'),
      reason: 'the destructor must skip UnregisterTopLevelWindowProcDelegate '
          'when the nodelegate arm skipped the registration',
    );
  });

  test('the off arm still skips registration', () {
    final source = _vendored('windows/universal_ble_plugin_c_api.cpp');
    expect(
      source,
      contains('ham2k::BleMode::kOff'),
      reason: 'returning before RegisterWithRegistrar IS the off arm; without '
          'it HAM2K_BLE_MODE=off registers the plugin anyway and the operator '
          'reads "the crash survives disabling BLE" from a build that never '
          'disabled it',
    );
    // Order is the whole content of the off arm: it must return BEFORE
    // GetRegistrar, or the arm silently stops testing the first step of the
    // ladder while still reading as "nothing ran".
    expect(
      source.indexOf('kOff'),
      lessThan(source.indexOf('GetRegistrar')),
      reason: 'the off arm must return before GetRegistrar<>(), otherwise the '
          'registrar rung below it is comparing two arms that both ran it',
    );
  });

  test('the noinit arm still skips InitializeAsync', () {
    final source = _vendored('windows/src/universal_ble_plugin.cpp');
    expect(
      source,
      contains('ham2k::Ham2kBleMode() == ham2k::BleMode::kNoInit'),
      reason: 'returning before InitializeAsync() IS the noinit arm — the one '
          'that separates "registering this plugin crashes" from "enumerating '
          'radios crashes", which the off arm alone cannot tell apart',
    );
  });

  test('the control arm is still upstream behaviour', () {
    // The experiment's control has to be untouched upstream code. The
    // temptation on a card this old is to fold in "one harmless fix" —
    // upstream main's try/catch around InitializeAsync is the specific one
    // this patch deliberately withholds (PATCH.md). Landing it here makes
    // every arm's result unattributable.
    final source = _vendored('windows/src/universal_ble_plugin.cpp');
    final initializeAsync = source.substring(source.indexOf('fire_and_forget UniversalBlePlugin::InitializeAsync'));
    expect(
      initializeAsync.substring(0, initializeAsync.indexOf('\n}')),
      isNot(contains('catch')),
      reason: 'InitializeAsync must stay exception-free for this build: it is '
          'the control arm, and a quietly improved control answers nothing. '
          'The try/catch lands in the build AFTER the A/B reports.',
    );
  });

  test('the vendored copy still emits a Release PDB for its own code', () {
    final source = _vendored('windows/CMakeLists.txt');
    expect(
      source,
      contains(r'target_compile_options(${PLUGIN_NAME} PRIVATE $<$<CONFIG:Release>:/Zi>)'),
      reason: 'without a PDB a crash inside this plugin resolves in Sentry to '
          'the nearest exported symbol only — which is how HALO-290 spent '
          'three rounds attributing these frames to MSVCP140',
    );
    expect(
      source,
      contains(r'target_link_options(${PLUGIN_NAME} PRIVATE $<$<CONFIG:Release>:/DEBUG>)'),
      reason: 'MSVC emits the linked PDB only with the linker\'s /DEBUG — /Zi '
          'alone leaves compiler-side PDBs that build-windows.ps1 never '
          'finds, so dropping just this line defeats the hunk while the /Zi '
          'check above stays green',
    );
  });
}

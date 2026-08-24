// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Guards everything `app/pubspec.yaml` says about `flutter_inappwebview`: the
// exact pin on the umbrella, the five version pins in `dependency_overrides`
// that hold the rest of the family still, the three overrides that
// displace the published Linux, macOS and Windows implementations outright,
// the one patched line inside the vendored macOS copy, and the four patched
// hunks inside the vendored Windows copy.
//
// All of it is invisible to every other signal. Delete an override and the
// whole Dart suite, `flutter analyze` and every GitHub CI job stay green,
// because all of those are Dart-only and run on ubuntu — nothing there
// compiles Swift or configures CMake. The only thing that would notice is a
// Codemagic release workflow, and every one of those is tag-triggered: the
// Linux AppImage failing at WPE's `FATAL_ERROR`, or the macOS build failing
// once Xcode reaches the plugin. So the earliest natural signal is a release,
// after the merge. These tests are the executable half of the prose warning
// in docs/quirks.md.
//
// `app_dist/pubspec.yaml` has to repeat the same overrides, and the check
// that it does lives in `app_dist/test/`, not here: `app_dist/` is stripped
// from the published open-source mirror while `app/test/` ships verbatim, so
// reading it from this file would turn `./scripts/test.sh` red for every
// outside contributor, with a message blaming their working directory.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_inappwebview_linux/flutter_inappwebview_linux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

// The files the helpers below read are each read from several tests. Every
// parse is memoised, and every memo is filled only AFTER the file's existence
// check has passed — a missing file must keep failing with its own `fail()`
// message on every call, not with a cache-shaped error on the second one.
Map<String, dynamic>? _resolvedPluginsMemo;
final _pubspecMemos = <String, YamlMap>{};
YamlMap? _lockMemo;

/// The plugin list Flutter generates at `pub get` and feeds to every build.
/// Reading it rather than the pubspec is deliberate: the pubspec states an
/// intent, this file records what resolution actually produced.
Map<String, dynamic> _resolvedPlugins() {
  final memo = _resolvedPluginsMemo;
  if (memo != null) return memo;
  final file = File('.flutter-plugins-dependencies');
  if (!file.existsSync()) {
    fail(
      'No .flutter-plugins-dependencies — run `flutter pub get` in app/ first. '
      'This file is what the build consumes, so its absence means this test '
      'cannot answer the question it exists to answer.',
    );
  }
  return _resolvedPluginsMemo = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

/// A parsed pubspec, by path.
YamlMap _pubspec(String pubspecPath) {
  final memo = _pubspecMemos[pubspecPath];
  if (memo != null) return memo;
  final file = File(pubspecPath);
  if (!file.existsSync()) fail('No $pubspecPath — this test runs from app/.');
  return _pubspecMemos[pubspecPath] = loadYaml(file.readAsStringSync()) as YamlMap;
}

Map<String, dynamic>? _pluginFor(String platform, String name) {
  final plugins = _resolvedPlugins()['plugins'] as Map<String, dynamic>;
  final forPlatform = (plugins[platform] as List).cast<Map<String, dynamic>>();
  for (final plugin in forPlatform) {
    if (plugin['name'] == name) return plugin;
  }
  return null;
}

/// The `dependency_overrides` block of a pubspec, as a plain map.
Map<String, dynamic> _overridesIn(String pubspecPath) {
  final overrides = _pubspec(pubspecPath)['dependency_overrides'];
  if (overrides == null) fail('$pubspecPath declares no dependency_overrides at all.');
  return Map<String, dynamic>.from(json.decode(json.encode(overrides)) as Map);
}

/// A pubspec's `dependencies` constraint for one package, exactly as written.
String _declaredConstraint(String pubspecPath, String package) {
  final dependencies = _pubspec(pubspecPath)['dependencies'] as YamlMap;
  final constraint = dependencies[package];
  if (constraint == null) fail('$pubspecPath does not declare $package as a dependency.');
  return constraint.toString();
}

/// What resolution actually produced, per package, from the committed lock:
/// the version, and the `dependency:` kind recording WHY it landed there.
({String version, String kind}) _locked(String package) {
  final lock = _lockMemo ??= loadYaml(File('pubspec.lock').readAsStringSync()) as YamlMap;
  final entry = (lock['packages'] as YamlMap)[package] as YamlMap?;
  if (entry == null) fail('$package is not in pubspec.lock.');
  return (version: entry['version'] as String, kind: entry['dependency'] as String);
}

/// A resolved plugin path as posix. The Windows builders write backslashes
/// into `.flutter-plugins-dependencies`, and an un-normalised `contains`
/// would fail there claiming a package we displace had been pulled back in.
String _posixPath(Object? path) => path.toString().replaceAll(r'\', '/');

void main() {
  group('the Linux web view stays absent', () {
    test('the endorsed WPE implementation is displaced by our stub', () {
      final plugin = _pluginFor('linux', 'flutter_inappwebview_linux');
      expect(
        plugin,
        isNotNull,
        reason: 'flutter_inappwebview endorses a Linux implementation; if it '
            'resolves to nothing at all the override has been replaced by '
            'something that changes how the plugin is declared',
      );
      expect(
        _posixPath(plugin!['path']),
        contains('packages/flutter_inappwebview_linux_stub'),
        reason: 'resolving to the published package pulls in WPE WebKit, whose '
            'CMakeLists is a FATAL_ERROR on every distro we build on',
      );
    });

    test('nothing native is compiled for it on the AppImage builders', () {
      // The stub declares `dartPluginClass` and NOT `pluginClass`. Adding a
      // `pluginClass` would flip this to true and hand the Linux builders a
      // CMake target to configure — the exact failure the stub prevents.
      expect(_pluginFor('linux', 'flutter_inappwebview_linux')!['native_build'], isFalse);
    });

    test('registerWith leaves the platform unset, rather than registering a stub', () {
      // The contract is absence, not a throwing placeholder. Assigning any
      // instance here would make `InAppWebViewPlatform.instance` succeed and
      // move the failure from resolution time to first use — turning a
      // build-time guarantee into a runtime crash on the operator's machine.
      //
      // Compared before/after rather than asserted null: `flutter test`
      // reports a host platform of its own choosing and may already have run
      // another implementation's registrant.
      final before = InAppWebViewPlatform.instance;
      // Restore only a non-null previous value: the setter throws on null by
      // design (`Platform interfaces can only be set to a non-null instance`),
      // so an instance registered over an empty slot CANNOT be taken back out
      // through public API — it would leak into every later test in this VM.
      // That is an argument for the no-op contract, not just for a teardown.
      if (before != null) addTearDown(() => InAppWebViewPlatform.instance = before);
      LinuxInAppWebViewPlatform.registerWith();
      expect(InAppWebViewPlatform.instance, same(before));
    });
  });

  group('the whole plugin family stays frozen together', () {
    // The vendored macOS copy is pinned to one platform-interface version by
    // its own caret constraint. The umbrella declares the rest with carets
    // too, and the interface declares the annotations package with a caret of
    // its own, so the exact pins in dependency_overrides are all that hold the
    // family still. Drop one and `pub upgrade` moves that member out from
    // under the frozen copy — which analyze and this whole suite would pass,
    // and `flutter build macos` would then fail in the kernel snapshot.
    //
    // Every member reachable by a caret belongs in this map: one left out is
    // one nothing pins and nothing here notices.
    const expected = {
      'flutter_inappwebview_platform_interface': '1.4.0-beta.3',
      'flutter_inappwebview_internal_annotations': '1.3.0',
      'flutter_inappwebview_android': '1.2.0-beta.3',
      'flutter_inappwebview_ios': '1.2.0-beta.3',
      'flutter_inappwebview_web': '1.2.0-beta.3',
    };

    for (final entry in expected.entries) {
      test('${entry.key} is pinned', () {
        // The DECLARATION is what a deleted pin fails on, and it goes first
        // for that reason. Of the two lock reads below, the version cannot see
        // a deletion — nothing re-resolves the family until the next
        // `pub upgrade`, so the locked version does not move — and the kind,
        // which WOULD see the entry fall back to `transitive`, never gets the
        // chance, because this assertion has already thrown.
        expect(
          _overridesIn('pubspec.yaml')[entry.key],
          entry.value,
          reason: 'a deleted or edited pin fails here first: of the two checks '
              'below, one cannot see a deletion and the other never runs',
        );
        // Both of the below are a consistency cross-check, not independent
        // coverage: `flutter test` re-resolves before it runs, so a lock that
        // disagreed with an exact declaration is rewritten to agree before a
        // test can read it. They earn their place by stating what the
        // declaration is FOR — keep them, but do not mistake them for a guard.
        final locked = _locked(entry.key);
        expect(
          locked.version,
          entry.value,
          reason: 'the lock is what a build resolves against, so this says the '
              'pin above is the version builds actually get',
        );
        expect(
          locked.kind,
          'direct overridden',
          reason: 'anything else means this version arrived through ordinary '
              'resolution rather than through the pin, and the next '
              '`pub upgrade` is free to move it',
        );
      });
    }

    test('the umbrella itself is pinned exact, not floated on a caret', () {
      // The pins above hold only the implementations. Put a caret back on the
      // umbrella and a future 6.3 resolves cleanly, every assertion above
      // still passes, and the app compiles against an API neither the frozen
      // implementations nor the vendored macOS copy implement. 6.2 is a beta
      // line whose upstream is dormant, so its next release is a thing to
      // inspect deliberately, not a thing to float onto.
      expect(
        _declaredConstraint('pubspec.yaml', 'flutter_inappwebview'),
        '6.2.0-beta.3',
        reason: 'must be the bare version: a caret or a range here lets '
            '`pub upgrade` move the umbrella out from under the family',
      );
      expect(
        _locked('flutter_inappwebview').version,
        '6.2.0-beta.3',
        reason: 'the lock is what a build resolves against, so a declaration '
            'the lock disagrees with is a pin nobody applied',
      );
    });
  });

  test('macOS resolves to the patched copy, not the published one', () {
    // Upstream's Package.swift declares a lower macOS minimum than its own
    // code requires, so the published package cannot compile under Swift
    // Package Manager at all — see the vendored package's PATCH.md.
    final plugin = _pluginFor('macos', 'flutter_inappwebview_macos');
    expect(plugin, isNotNull);
    expect(_posixPath(plugin!['path']), contains('packages/flutter_inappwebview_macos_patched'));
  });

  test('the vendored macOS copy still carries the patched deployment target', () {
    // Resolving to the vendored directory is not the same as the patch being
    // in it. PATCH.md's re-vendor procedure is "copy the new package over
    // this directory, re-apply the one-line change if upstream still has it",
    // and a copy that stops after the first half leaves the assertion above
    // true. Nothing in ./scripts/test.sh compiles Swift, so this one line is
    // the only part of the patch a Dart test can see at all.
    const manifestPath = '../packages/flutter_inappwebview_macos_patched/'
        'macos/flutter_inappwebview_macos/Package.swift';
    final manifest = File(manifestPath);
    if (!manifest.existsSync()) {
      fail(
        'No $manifestPath — the macOS override points at a package with no SPM '
        'manifest, so this test cannot answer the question it exists to answer.',
      );
    }
    final source = manifest.readAsStringSync();
    const failure = "protocol 'ASWebAuthenticationPresentationContextProviding' "
        "requires 'presentationAnchor(for:)' to be available in macOS 10.14 and newer";
    expect(
      source,
      contains('.macOS("10.15")'),
      reason: 'raising the SPM minimum IS the patch; without it the first '
          'signal is a tag-triggered macOS release failing with "$failure"',
    );
    expect(
      source,
      isNot(contains('.macOS("10.14")')),
      reason: 'a 10.14 minimum anywhere in this manifest is upstream\'s own '
          'value, which fails the release build with "$failure"',
    );
  });

  test('Windows resolves to the patched copy, not the published one', () {
    // The published destructor frees its texture bridge on the calling
    // thread the instant it returns, while the engine's raster thread can
    // still be mid-callback into it — see the vendored package's PATCH.md.
    final plugin = _pluginFor('windows', 'flutter_inappwebview_windows');
    expect(plugin, isNotNull);
    expect(_posixPath(plugin!['path']), contains('packages/flutter_inappwebview_windows_patched'));
  });

  test('the vendored Windows copy still carries the patched destructor', () {
    // Resolving to the vendored directory is not the same as the patch being
    // in it. PATCH.md's re-vendor procedure is "copy the new package over
    // this directory, re-apply the destructor change if upstream hasn't
    // fixed the race", and a copy that stops after the first half leaves the
    // assertion above true. Nothing in ./scripts/test.sh compiles C++, so
    // this is the only part of the patch a Dart test can see at all.
    const sourcePath = '../packages/flutter_inappwebview_windows_patched/'
        'windows/custom_platform_view/custom_platform_view.cc';
    final file = File(sourcePath);
    if (!file.existsSync()) {
      fail(
        'No $sourcePath — the Windows override points at a package with no '
        'custom_platform_view.cc, so this test cannot answer the question it '
        'exists to answer.',
      );
    }
    final source = file.readAsStringSync();
    expect(
      source,
      contains('texture_registrar_->UnregisterTexture(texture_id_, [bridge, texture]() {});'),
      reason: 'deferring texture_bridge_/flutter_texture_ destruction to the '
          'UnregisterTexture completion callback IS the patch; without it '
          'the first signal is a Windows-only native crash on window close '
          '(HALO-290/HALO-NEXT-3), not a test failure',
    );
    expect(
      source,
      contains('texture_bridge_->Stop();'),
      reason: 'deferring texture_bridge_ destruction without first stopping '
          'it re-opens a narrower use-after-free: its capture thread keeps '
          'calling a frame-available callback that captures the '
          'CustomPlatformView this destructor is in the middle of '
          'destroying. See PATCH.md.',
    );
    expect(
      source,
      isNot(contains('UnregisterTexture(texture_id_, nullptr)')),
      reason: 'a nullptr callback anywhere in this destructor is upstream\'s '
          'own unpatched line, which reintroduces the use-after-free',
    );
    expect(
      source,
      contains('event_channel_->SetStreamHandler(nullptr);'),
      reason: 'clearing the event channel\'s stream handler IS the messenger '
          'callback race patch; without it a dangling [this] capture stays '
          'registered in the messenger\'s callback map after every dispose '
          '(HALO-290/HALO-NEXT-59), not a test failure',
    );
  });

  test('the vendored Windows copy still unregisters the old view on keep-alive reuse', () {
    // Same "resolving to the vendored directory is not the same as the patch
    // being in it" caveat as the destructor test above, for the
    // in_app_webview_manager.cpp half of the messenger callback race patch
    // (PATCH.md's "The messenger callback race" section).
    const sourcePath = '../packages/flutter_inappwebview_windows_patched/'
        'windows/in_app_webview/in_app_webview_manager.cpp';
    final file = File(sourcePath);
    if (!file.existsSync()) {
      fail(
        'No $sourcePath — the Windows override points at a package with no '
        'in_app_webview_manager.cpp, so this test cannot answer the question '
        'it exists to answer.',
      );
    }
    final source = file.readAsStringSync();
    expect(
      source,
      contains('oldPlatformView->UnregisterMethodCallHandler();'),
      reason: 'unregistering the previous CustomPlatformView before erasing '
          'it on keep-alive reuse IS the patch; without it the old and new '
          'platform views race registering channels on the same messenger '
          '(HALO-290/HALO-NEXT-59), not a test failure',
    );
  });

  test('the vendored Windows copy still unregisters WebViewEnvironment on teardown', () {
    // Same "resolving to the vendored directory is not the same as the patch
    // being in it" caveat as the other two Windows-patch tests, for the
    // webview_environment.cpp third of the messenger callback race patch
    // (PATCH.md's "The messenger callback race" section).
    const sourcePath = '../packages/flutter_inappwebview_windows_patched/'
        'windows/webview_environment/webview_environment.cpp';
    final file = File(sourcePath);
    if (!file.existsSync()) {
      fail(
        'No $sourcePath — the Windows override points at a package with no '
        'webview_environment.cpp, so this test cannot answer the question '
        'it exists to answer.',
      );
    }
    final source = file.readAsStringSync();
    expect(
      source,
      contains('channelDelegate->UnregisterMethodCallHandler();'),
      reason: 'unregistering channelDelegate in ~WebViewEnvironment() IS the '
          'patch; without it a dangling channelDelegate capture stays '
          'registered in the messenger\'s callback map after the '
          'environment is destroyed (HALO-290/HALO-NEXT-59), not a test '
          'failure',
    );
  });

  test('the vendored Windows copy still emits a Release PDB for its own code', () {
    // Same "resolving to the vendored directory is not the same as the patch
    // being in it" caveat as the other Windows-patch tests, for the
    // CMakeLists.txt fourth of the messenger callback race patch (PATCH.md's
    // "The messenger callback race" section) — instrumentation, not a bugfix,
    // but dropped just as silently on a careless re-vendor.
    const sourcePath = '../packages/flutter_inappwebview_windows_patched/'
        'windows/CMakeLists.txt';
    final file = File(sourcePath);
    if (!file.existsSync()) {
      fail(
        'No $sourcePath — the Windows override points at a package with no '
        'CMakeLists.txt, so this test cannot answer the question it exists '
        'to answer.',
      );
    }
    final source = file.readAsStringSync();
    expect(
      source,
      contains(r'target_compile_options(${PLUGIN_NAME} PRIVATE $<$<CONFIG:Release>:/Zi>)'),
      reason: 'emitting a Release PDB for this plugin IS the patch; without '
          'it a native crash whose actual site is inside this plugin\'s own '
          'code resolves in Sentry the same way one inside the Flutter '
          'engine does — nearest-export only, no line, no non-exported '
          'frames (HALO-290) — not a test failure',
    );
    expect(
      source,
      contains(r'target_link_options(${PLUGIN_NAME} PRIVATE $<$<CONFIG:Release>:/DEBUG>)'),
      reason: 'MSVC emits the linked PDB only with the linker\'s /DEBUG -- '
          '/Zi alone produces compiler-side PDBs the upload step in '
          'app_dist/ci/build-windows.ps1 never finds, so dropping just this '
          'line on a re-vendor defeats the whole hunk while the /Zi check '
          'above stays green',
    );
  });
}

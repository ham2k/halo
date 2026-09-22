// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Guards the `usb_serial` override in `app/pubspec.yaml`: that it resolves to
// the vendored copy, not the published one, and that the vendored copy's
// android/build.gradle still carries the AGP-9 fix — see
// packages/usb_serial_patched/PATCH.md.
//
// This is invisible to every other signal: `flutter analyze` and the rest of
// the Dart suite never invoke Gradle, so a reverted or hand-edited
// android/build.gradle stays green here and everywhere else until an actual
// Android build runs. That first happens on a release, after the merge.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('the override points at the vendored copy', () {
    final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    final overrides = pubspec['dependency_overrides'];
    if (overrides == null) fail('pubspec.yaml declares no dependency_overrides at all.');
    final decoded = Map<String, dynamic>.from(json.decode(json.encode(overrides)) as Map);
    expect(
      decoded['usb_serial'],
      {'path': '../packages/usb_serial_patched'},
      reason:
          'without this override, resolution falls back to the published '
          '0.5.2, whose android/build.gradle fails the Android build under AGP 9',
    );

    final lock = loadYaml(File('pubspec.lock').readAsStringSync()) as YamlMap;
    final entry = (lock['packages'] as YamlMap)['usb_serial'] as YamlMap?;
    if (entry == null) fail('usb_serial is not in pubspec.lock.');
    // usb_serial is also a direct dependency (not override-only, unlike the
    // inappwebview implementations), so its `dependency:` kind stays
    // "direct main" even while overridden — `source`/`description` are what
    // distinguish a path override from ordinary hosted resolution here.
    expect(
      entry['source'],
      'path',
      reason:
          'anything else means usb_serial resolved through ordinary pub '
          'resolution rather than through the override, and the next '
          '`pub upgrade` is free to move it back to the published package',
    );
    expect((entry['description'] as YamlMap)['path'], '../packages/usb_serial_patched');
  });

  test('the vendored copy still carries the AGP-9 fix', () {
    // Resolving to the vendored directory is not the same as the patch being
    // in it. PATCH.md's re-vendor procedure is "copy the new package over
    // this directory, re-apply the android/build.gradle change if upstream
    // hasn't fixed it itself", and a copy that stops after the first half
    // leaves the test above true. Nothing in ./scripts/test.sh runs Gradle,
    // so this is the only part of the patch a Dart test can see at all.
    const gradlePath = '../packages/usb_serial_patched/android/build.gradle';
    final file = File(gradlePath);
    if (!file.existsSync()) {
      fail(
        'No $gradlePath — the usb_serial override points at a package with no '
        'android/build.gradle, so this test cannot answer the question it '
        'exists to answer.',
      );
    }
    final source = file.readAsStringSync();
    expect(
      source,
      contains("id 'com.android.library'"),
      reason:
          'applying AGP through the plugins{} block IS the fix; without '
          'it kotlin-android finds no Android plugin already applied and the '
          'Android build fails with "\'kotlin-android\' plugin requires one '
          'of the Android Gradle plugins"',
    );
    expect(
      source,
      isNot(contains('apply plugin:')),
      reason:
          'the legacy apply-plugin form anywhere in this file is '
          'upstream\'s own unpatched line, which reintroduces the AGP-9 failure',
    );
  });
}

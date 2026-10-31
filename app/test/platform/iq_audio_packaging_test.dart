// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

String _plist(String path) => File(path).readAsStringSync().replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

void main() {
  for (final platform in ['android', 'ios', 'linux', 'macos', 'windows']) {
    test('$platform I/Q capture resolves to its source-validation backend', () {
      // Hosted resolution would restore microphone fallback and mono upmixing
      // while every Dart spectrum test continued to pass.
      final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
      final overrides = pubspec['dependency_overrides'] as YamlMap?;
      expect(overrides?['record_$platform'], {
        'path': '../packages/record_${platform}_patched',
      }, reason: 'I/Q requires the backend that validates the selected device, source channels and native sample rate');

      final lock = loadYaml(File('pubspec.lock').readAsStringSync()) as YamlMap;
      final entry = (lock['packages'] as YamlMap)['record_$platform'] as YamlMap?;
      expect(entry, isNotNull, reason: 'the build must resolve the native I/Q capture backend');
      expect(entry!['source'], 'path', reason: 'a hosted package does not carry the required source validation');
      expect((entry['description'] as YamlMap)['path'], '../packages/record_${platform}_patched');
    });
  }

  for (final platform in ['macos', 'ios']) {
    test('$platform can explain the audio-input permission request', () {
      final plist = _plist('$platform/Runner/Info.plist');
      expect(
        RegExp(r'<key>NSMicrophoneUsageDescription</key>').allMatches(plist),
        hasLength(1),
        reason: 'voice recording and I/Q share one permission purpose; duplicate keys can hide one explanation',
      );
      final description = RegExp(r'<key>NSMicrophoneUsageDescription</key>\s*<string>([^<]*)</string>').firstMatch(plist)?.group(1)?.trim();
      expect(description, isNotNull, reason: '$platform requires a usage description before the selected audio input can be opened');
      expect(description, isNotEmpty, reason: 'the permission prompt must explain why the radio spectrum needs audio input');
    });
  }

  test('Windows prepares recorder sources before configuring Flutter and its plugins', () {
    // Existing generated packages hide a late bootstrap on developer machines.
    // A fresh checkout needs the sources before CMake reads plugin targets.
    final cmake = File('windows/CMakeLists.txt').readAsStringSync().replaceAll(RegExp(r'^\s*#.*$', multiLine: true), '');
    final configuration = RegExp(r'include\s*\([^)]*generated_config\.cmake[^)]*\)').firstMatch(cmake);
    final preparation = RegExp(r'include\s*\([^)]*prepare_record\.cmake[^)]*\)').firstMatch(cmake);
    final flutter = RegExp(r'\badd_subdirectory\s*\(').firstMatch(cmake);
    final plugins = RegExp(r'include\s*\([^)]*generated_plugins\.cmake[^)]*\)').firstMatch(cmake);

    expect(configuration, isNotNull, reason: 'preparation must use the Flutter SDK selected for this build');
    expect(preparation, isNotNull, reason: 'plain flutter build windows must prepare the pinned recorder packages');
    expect(flutter, isNotNull);
    expect(plugins, isNotNull);
    expect(configuration!.start, lessThan(preparation!.start));
    expect(preparation.start, lessThan(flutter!.start), reason: 'preparation must finish before Flutter build targets are configured');
    expect(preparation.start, lessThan(plugins!.start), reason: 'plugin CMake files do not exist in a fresh checkout');
  });

  test('Android declares audio permission without excluding devices lacking a built-in microphone', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android.permission.RECORD_AUDIO'));
    expect(RegExp(r'<uses-feature\s+android:name="android.hardware.microphone"\s+android:required="false"').hasMatch(manifest), isTrue);
  });

  for (final configuration in ['DebugProfile', 'Release']) {
    test('$configuration permits the selected audio input through the macOS sandbox', () {
      // A Debug-only entitlement would make bench checks succeed while the
      // signed application refused the same operator-selected interface.
      expect(
        RegExp(r'<key>com\.apple\.security\.device\.audio-input</key>\s*<true\s*/>').hasMatch(_plist('macos/Runner/$configuration.entitlements')),
        isTrue,
        reason: 'audio input must be allowed in both development and shipped builds',
      );
    });
  }
}

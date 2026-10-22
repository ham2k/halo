// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks/hooks.dart';
import '../hook/src/cache_directory.dart';
import '../hook/src/source_cache.dart';

void main() {
  test('macOS cache lives in the user Library, independent of checkout', () {
    expect(
      defaultMbedTlsCacheDirectory(operatingSystem: 'macos', environment: {'HOME': '/Users/example'}),
      Uri.parse('file:///Users/example/Library/Caches/ham2k/halo_tls_psk/mbedtls/'),
    );
  });

  test('Linux honors absolute XDG cache and ignores a relative override', () {
    expect(
      defaultMbedTlsCacheDirectory(operatingSystem: 'linux', environment: {'XDG_CACHE_HOME': '/cache'}),
      Uri.parse('file:///cache/ham2k/halo_tls_psk/mbedtls/'),
    );
    expect(
      defaultMbedTlsCacheDirectory(operatingSystem: 'linux', environment: {'HOME': '/home/example', 'XDG_CACHE_HOME': 'relative'}),
      Uri.parse('file:///home/example/.cache/ham2k/halo_tls_psk/mbedtls/'),
    );
  });

  test('Windows prefers LocalAppData and can derive it from the user profile', () {
    expect(
      defaultMbedTlsCacheDirectory(operatingSystem: 'windows', environment: {'LOCALAPPDATA': r'C:\Users\example\AppData\Local'}),
      Uri.parse('file:///C:/Users/example/AppData/Local/ham2k/halo_tls_psk/mbedtls/'),
    );
    expect(
      defaultMbedTlsCacheDirectory(operatingSystem: 'windows', environment: {'USERPROFILE': r'D:\Users\example'}),
      Uri.parse('file:///D:/Users/example/AppData/Local/ham2k/halo_tls_psk/mbedtls/'),
    );
  });

  test('missing user location requests an explicit cache instead of using the checkout', () {
    expect(() => defaultMbedTlsCacheDirectory(operatingSystem: 'linux', environment: {}), throwsA(isA<MbedTlsSourceException>()));
    expect(() => defaultMbedTlsCacheDirectory(operatingSystem: 'windows', environment: {'LOCALAPPDATA': 'relative'}), throwsA(isA<MbedTlsSourceException>()));
  });

  final consumer = Uri.directory(r'E:\consumer app\', windows: true);

  for (final path in [r'D:\a\_temp\K4 cache René', 'D:/a/_temp/K4 cache René', r'd:\cache\缓存 % #']) {
    test('Windows drive path is a file URI: $path', () {
      final result = cacheDirectoryOverride(_input(path, consumer).userDefines)!;
      expect(result.scheme, 'file');
      expect(result.hasQuery, isFalse);
      expect(result.hasFragment, isFalse);
      expect(result.toFilePath(windows: true), '${path.replaceAll('/', '\\')}\\');
      expect(result.path, isNot(contains('consumer app')));
    });
  }

  for (final path in [r'\\server\shared cache\K4 René', '//server/shared cache/K4 René']) {
    test('UNC path preserves its host and share: $path', () {
      final result = cacheDirectoryOverride(_input(path, consumer).userDefines)!;
      expect(result.scheme, 'file');
      expect(result.host, 'server');
      expect(result.toFilePath(windows: true), '\\\\server\\shared cache\\K4 René\\');
    });
  }

  test('relative path uses the consuming pubspec, not the native package root', () {
    final input = _input('../shared cache/K4 René', consumer);
    final result = cacheDirectoryOverride(input.userDefines)!;
    expect(result, input.userDefines.path('cache_dir'));
    expect(result.toFilePath(windows: true), 'E:\\shared cache\\K4 René');
    expect(result, isNot(input.packageRoot.resolve('../shared cache/K4 René')));
  });

  test('POSIX absolute and relative paths retain public hooks resolution', () {
    final base = Uri.directory('/workspace/consumer/');
    for (final (path, expected) in [('/tmp/K4 cache René', '/tmp/K4 cache René'), ('cache/K4 René', '/workspace/consumer/cache/K4 René')]) {
      final result = cacheDirectoryOverride(_input(path, base).userDefines)!;
      expect(result.toFilePath(windows: false), expected);
    }
  });

  test('absent override keeps default cache selection available', () {
    expect(cacheDirectoryOverride(_input(null, consumer).userDefines), isNull);
  });

  for (final invalid in <Object>['', false, 123]) {
    test('rejects invalid cache override $invalid', () {
      expect(() => cacheDirectoryOverride(_input(invalid, consumer).userDefines), throwsFormatException);
    });
  }
}

BuildInput _input(Object? path, Uri consumer) {
  final root = Directory.systemTemp.uri.resolve('halo-cache-path-test/');
  return (BuildInputBuilder()
        ..setupShared(
          packageRoot: root.resolve('separate-native-package/'),
          packageName: 'halo_tls_psk',
          outputDirectoryShared: root.resolve('shared/'),
          outputFile: root.resolve('output.json'),
          userDefines: PackageUserDefines(
            workspacePubspec: PackageUserDefinesSource(defines: {'cache_dir': path}, basePath: consumer),
          ),
        )
        ..setupBuildInput()
        ..config.setupBuild(linkingEnabled: false))
      .build();
}

// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0
import 'dart:convert';
import 'dart:io';
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'src/cache_directory.dart';
import 'src/msvc_build.dart';
import 'src/source_cache.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    // Web builds neither download sources nor require a native toolchain.
    if (!input.config.buildCodeAssets) return;
    final offline = input.userDefines['offline'];
    if (offline != null && offline is! bool) {
      throw const FormatException('hooks.user_defines.halo_tls_psk.offline must be a boolean');
    }
    final source = await prepareMbedTls(
      packageRoot: input.packageRoot,
      cacheDirectory: cacheDirectoryOverride(input.userDefines) ?? defaultMbedTlsCacheDirectory(),
      offline: offline == true,
    );
    final manifestFile = File.fromUri(input.packageRoot.resolve('UPSTREAM.json'));
    final manifest = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
    final files = Map<String, String>.from(manifest['files'] as Map<String, dynamic>);
    output.dependencies.add(manifestFile.uri);
    for (final entry in (manifest['patches'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      output.dependencies.add(input.packageRoot.resolve(entry['file'] as String));
    }
    final code = input.config.code;
    final windows = code.targetOS == OS.windows;
    final compiler = code.cCompiler?.compiler.pathSegments.last ?? '';
    final msvc = windows && Platform.isWindows && (compiler.isEmpty || compiler.toLowerCase() == 'cl.exe');
    final upstreamSources = [
      for (final path in files.keys)
        if (path.startsWith('library/') && path.endsWith('.c')) source.resolve(path),
    ];
    if (msvc) {
      // CBuilder 0.19.2 invokes MSVC through cmd.exe. Keep every argument out
      // of that shell, including include paths, output paths and string defines.
      // Record headers as well as sources: response files hide both from CBuilder.
      output.dependencies.addAll(files.keys.map(source.resolve));
      output.dependencies.addAll(['src/halo_tls.c', 'src/halo_tls.h', 'src/halo_tls_config.h'].map(input.packageRoot.resolve));
      await buildWithMsvc(
        input: input,
        output: output,
        sources: [input.packageRoot.resolve('src/halo_tls.c'), ...upstreamSources],
        includes: [input.packageRoot.resolve('src/'), source.resolve('include/'), source.resolve('library/')],
      );
      return;
    }
    final crossArm64 = code.targetOS == OS.linux && code.targetArchitecture == Architecture.arm64 && Architecture.current != Architecture.arm64;
    await CBuilder.library(
      name: 'halo_tls_psk',
      assetName: 'src/native_tls.dart',
      sources: ['src/halo_tls.c', ...upstreamSources.map((uri) => uri.toFilePath())],
      includes: ['src', source.resolve('include/').toFilePath(), source.resolve('library/').toFilePath()],
      defines: {'MBEDTLS_CONFIG_FILE': '"halo_tls_config.h"', if (windows) '_CRT_SECURE_NO_WARNINGS': null},
      std: 'c11',
      flags: [
        if (!windows) '-fvisibility=hidden',
        // Flutter forwards the compiler from CMakeCache, but not its target
        // flags. Keep the Debian multiarch build aligned with our toolchain.
        if (crossArm64 && compiler.contains('clang')) '--target=aarch64-linux-gnu',
        if (crossArm64 && compiler.contains('clang')) '--gcc-toolchain=/usr',
      ],
      libraries: [if (windows) 'bcrypt'],
    ).run(input: input, output: output);
  });
}

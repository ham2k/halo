// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0
import 'package:flutter_test/flutter_test.dart';

import '../hook/src/msvc_build.dart';

void main() {
  const outputDirectory = r'C:\Users\Renée Smith\项目\build output';
  const sources = [r'C:\Users\Renée Smith\项目\src\halo_tls.c', r'C:\Users\Renée Smith\缓存\library\aes.c'];
  const includes = [r'C:\Users\Renée Smith\项目\include', r'\\server\shared cache\Mbed TLS\include'];

  MsvcBuildPlan plan({bool dynamicLinking = true, String machine = 'X64', bool addressSanitizer = false}) => MsvcBuildPlan(
    outputDirectory: outputDirectory,
    sources: sources,
    includes: includes,
    machine: machine,
    dynamicLinking: dynamicLinking,
    addressSanitizer: addressSanitizer,
  );

  test('dynamic build keeps paths with spaces and Unicode intact before the linker arguments', () {
    final build = plan();
    final arguments = build.compilerArguments;
    final linkIndex = arguments.indexOf('/link');
    expect(build.libraryPath, '$outputDirectory\\halo_tls_psk.dll');
    expect(build.objectDirectory, startsWith('$outputDirectory\\'));
    expect(build.archiverArguments, isNull);
    expect(linkIndex, greaterThan(0));

    final compilerArguments = arguments.take(linkIndex).toList();
    expect(
      compilerArguments,
      containsAll([
        '/nologo',
        '/O2',
        '/std:c11',
        '/D_CRT_SECURE_NO_WARNINGS',
        '/DRELEASE',
        '/DNDEBUG',
        '/DMBEDTLS_CONFIG_FILE="halo_tls_config.h"',
        '/LD',
        '/Fo${build.objectDirectory}\\',
        '/Fe:${build.libraryPath}',
        ...includes.map((include) => '/I$include'),
        ...sources,
      ]),
    );
    expect(arguments.skip(linkIndex + 1), containsAll(['/MACHINE:X64', 'bcrypt.lib']));
    expect(arguments.where((argument) => argument == '/link'), hasLength(1));
    expect(arguments, isNot(contains('/c')));
    expect(arguments, isNot(contains('/fsanitize=address')));
  });

  test('static build archives exactly the compiled sources without collecting stale objects', () {
    final build = plan(dynamicLinking: false);
    final arguments = build.compilerArguments;
    expect(build.libraryPath, '$outputDirectory\\halo_tls_psk.lib');
    expect(arguments, containsAll(['/c', '/Fo${build.objectDirectory}\\', ...sources]));
    expect(arguments, isNot(contains('/LD')));
    expect(arguments, isNot(contains('/link')));
    expect(arguments.where((argument) => argument.startsWith('/Fe')), isEmpty);
    expect(
      build.archiverArguments,
      containsAllInOrder(['/OUT:${build.libraryPath}', '/MACHINE:X64', '${build.objectDirectory}\\halo_tls.obj', '${build.objectDirectory}\\aes.obj']),
    );
    expect(
      build.archiverArguments!.where((argument) => argument.endsWith('.obj')),
      orderedEquals(['${build.objectDirectory}\\halo_tls.obj', '${build.objectDirectory}\\aes.obj']),
    );
    expect(build.archiverArguments!.where((argument) => argument.contains('*')), isEmpty);
  });

  for (final machine in ['X64', 'X86', 'ARM64']) {
    test('uses $machine for the dynamic linker and static archiver', () {
      expect(plan(machine: machine).compilerArguments, contains('/MACHINE:$machine'));
      expect(plan(machine: machine, dynamicLinking: false).archiverArguments, contains('/MACHINE:$machine'));
    });
  }

  test('enables address sanitizer only when requested', () {
    expect(plan(addressSanitizer: true).compilerArguments, contains('/fsanitize=address'));
    expect(plan(dynamicLinking: false, addressSanitizer: true).compilerArguments, contains('/fsanitize=address'));
  });

  for (final (index, invalid) in [
    r'src\halo_tls.c',
    r'C:halo_tls.c',
    r'C:\src\halo_tls.h',
    'C:\\src\\injected\nfile.c',
    'C:\\src\\injected\rfile.c',
    'C:\\src\\injected\x00file.c',
    'C:\\src\\injected"file.c',
    r'C:\src\*.c',
    r'C:\src\file?.c',
    'C:\\src\\',
  ].indexed) {
    test('rejects non-source or argument-breaking source path $index', () {
      expect(
        () => MsvcBuildPlan(outputDirectory: outputDirectory, sources: [invalid], includes: includes, machine: 'X64', dynamicLinking: true),
        throwsArgumentError,
      );
    });
  }

  test('rejects an empty source list', () {
    expect(
      () => MsvcBuildPlan(outputDirectory: outputDirectory, sources: const [], includes: includes, machine: 'X64', dynamicLinking: true),
      throwsArgumentError,
    );
  });

  for (final (index, duplicateSources) in [
    [r'C:\first\aes.c', r'D:\second\AES.c'],
    [r'C:\first\aes.c', r'C:\first\aes.c'],
  ].indexed) {
    test('rejects colliding Windows object basenames $index', () {
      expect(
        () => MsvcBuildPlan(outputDirectory: outputDirectory, sources: duplicateSources, includes: includes, machine: 'X64', dynamicLinking: false),
        throwsArgumentError,
      );
    });
  }

  test('rejects an unsupported target machine', () {
    expect(() => plan(machine: 'ARM'), throwsArgumentError);
  });

  for (final (index, invalid) in [
    r'relative\directory',
    r'C:relative',
    'C:\\directory\nnext',
    'C:\\directory\rnext',
    'C:\\directory\x00next',
    'C:\\directory"next',
    r'C:\directory*',
    r'C:\directory?',
  ].indexed) {
    test('rejects non-absolute or argument-breaking output directory $index', () {
      expect(() => MsvcBuildPlan(outputDirectory: invalid, sources: sources, includes: includes, machine: 'X64', dynamicLinking: true), throwsArgumentError);
    });

    test('rejects non-absolute or argument-breaking include directory $index', () {
      expect(
        () => MsvcBuildPlan(outputDirectory: outputDirectory, sources: sources, includes: [invalid], machine: 'X64', dynamicLinking: true),
        throwsArgumentError,
      );
    });
  }
}

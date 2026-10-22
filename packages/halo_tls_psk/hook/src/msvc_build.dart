// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0
import 'dart:convert';
import 'dart:io';
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'msvc_response_file.dart';

/// Package-local MSVC invocation until the pinned Flutter SDK can use a
/// native_toolchain_c release whose CBuilder invokes MSVC without cmd.exe.
/// Every compiler/linker argument goes in a response file, including paths.
Future<void> buildWithMsvc({required BuildInput input, required BuildOutputBuilder output, required List<Uri> sources, required List<Uri> includes}) async {
  final code = input.config.code;
  if (code.sanitizer != null && code.sanitizer != Sanitizer.asan) {
    throw UnsupportedError('MSVC supports only the address sanitizer');
  }
  final machine = switch (code.targetArchitecture) {
    Architecture.x64 => 'X64',
    Architecture.ia32 => 'X86',
    Architecture.arm64 => 'ARM64',
    final other => throw UnsupportedError('Unsupported MSVC architecture: $other'),
  };
  final dynamicLinking = code.linkModePreference == LinkModePreference.dynamic || code.linkModePreference == LinkModePreference.preferDynamic;
  final plan = MsvcBuildPlan(
    outputDirectory: input.outputDirectory.toFilePath(),
    sources: sources.map((uri) => uri.toFilePath()).toList(),
    includes: includes.map((uri) => uri.toFilePath()).toList(),
    machine: machine,
    dynamicLinking: dynamicLinking,
    addressSanitizer: code.sanitizer == Sanitizer.asan,
  );
  final tools = await _resolveTools(code.cCompiler, machine);
  await Directory(plan.objectDirectory).create(recursive: true);
  final library = File(plan.libraryPath);
  // A failed rebuild must not leave a previous library available for publishing.
  if (await library.exists()) await library.delete();
  await _run(tools.compiler, input.outputDirectory.resolve('halo_tls_psk_compile.rsp'), plan.compilerArguments, tools.environment);
  final archiveArguments = plan.archiverArguments;
  if (archiveArguments != null) {
    await _run(tools.archiver, input.outputDirectory.resolve('halo_tls_psk_archive.rsp'), archiveArguments, tools.environment);
  }
  if (!await library.exists()) throw StateError('MSVC completed without producing ${plan.libraryPath}');
  output.assets.code.add(
    CodeAsset(package: input.packageName, name: 'src/native_tls.dart', file: library.uri, linkMode: dynamicLinking ? DynamicLoadingBundled() : StaticLinking()),
  );
}

/// Pure argument planning lets tests cover Windows paths on every host.
final class MsvcBuildPlan {
  late final String libraryPath;
  late final String objectDirectory;
  late final List<String> compilerArguments;
  late final List<String>? archiverArguments;

  MsvcBuildPlan({
    required String outputDirectory,
    required List<String> sources,
    required List<String> includes,
    required String machine,
    required bool dynamicLinking,
    bool addressSanitizer = false,
  }) {
    if (!{'X64', 'X86', 'ARM64'}.contains(machine)) throw ArgumentError.value(machine, 'machine');
    final directory = _path(outputDirectory).replaceFirst(RegExp(r'\\+$'), '');
    objectDirectory = '$directory\\objects';
    libraryPath = '$directory\\halo_tls_psk.${dynamicLinking ? 'dll' : 'lib'}';
    final basenames = <String>{};
    final sourcePaths = sources.map(_path).toList();
    if (sourcePaths.isEmpty) throw ArgumentError.value(sources, 'sources', 'At least one source is required');
    final objects = <String>[];
    for (final source in sourcePaths) {
      final basename = source.split('\\').last;
      if (!basename.toLowerCase().endsWith('.c') || !basenames.add(basename.toLowerCase())) {
        throw ArgumentError.value(source, 'sources', 'C source basenames must be unique, ignoring case');
      }
      objects.add('$objectDirectory\\${basename.substring(0, basename.length - 2)}.obj');
    }
    compilerArguments = [
      '/nologo',
      '/O2',
      '/std:c11',
      '/DRELEASE',
      '/DNDEBUG',
      '/D_CRT_SECURE_NO_WARNINGS',
      '/DMBEDTLS_CONFIG_FILE="halo_tls_config.h"',
      for (final include in includes) '/I${_path(include)}',
      '/Fo$objectDirectory\\',
      if (addressSanitizer) ...['/Zi', '/fsanitize=address'],
      if (dynamicLinking) ...['/LD', '/Fe:$libraryPath'] else '/c',
      ...sourcePaths,
      if (dynamicLinking) ...['/link', '/MACHINE:$machine', 'bcrypt.lib', if (addressSanitizer) '/DEBUG'],
    ];
    archiverArguments = dynamicLinking ? null : ['/NOLOGO', '/OUT:$libraryPath', '/MACHINE:$machine', ...objects];
  }

  static String _path(String path) {
    if (!RegExp(r'^(?:[a-zA-Z]:[/\\]|\\\\)').hasMatch(path) || RegExp(r'[\x00-\x1f\x7f"*?]').hasMatch(path)) {
      throw ArgumentError.value(path, 'path', 'Expected an absolute Windows path without wildcards, quotes or control characters');
    }
    return path.replaceAll('/', '\\');
  }
}

Future<void> _run(Uri executable, Uri responseFile, List<String> arguments, Map<String, String> environment) async {
  await writeMsvcResponseFile(responseFile, arguments);
  stdout.writeln('Running MSVC directly: ${executable.toFilePath()} @${responseFile.toFilePath()}');
  final process = await Process.start(
    executable.toFilePath(),
    ['@${responseFile.toFilePath()}'],
    runInShell: false,
    workingDirectory: responseFile.resolve('.').toFilePath(),
    environment: environment,
    includeParentEnvironment: false,
  );
  await Future.wait([stdout.addStream(process.stdout), stderr.addStream(process.stderr)]);
  final exitCode = await process.exitCode;
  if (exitCode != 0) throw ProcessException(executable.toFilePath(), ['@${responseFile.toFilePath()}'], 'MSVC native build failed', exitCode);
}

typedef _Tools = ({Uri compiler, Uri archiver, Map<String, String> environment});

Future<_Tools> _resolveTools(CCompilerConfig? supplied, String machine) async {
  if (supplied != null) {
    final prompt = supplied.windows.developerCommandPrompt;
    final environment = _environmentWith(prompt == null ? {} : await environmentFromBatchFile(prompt.script, arguments: prompt.arguments));
    if (environment['INCLUDE']?.isNotEmpty != true || environment['LIB']?.isNotEmpty != true) {
      throw StateError('The supplied MSVC toolchain needs a developer command prompt or an environment with INCLUDE and LIB configured.');
    }
    return (compiler: supplied.compiler, archiver: supplied.archiver, environment: environment);
  }
  // Standard Visual Studio installer discovery; no download or private
  // native_toolchain_c APIs. VsDevCmd supplies the Windows SDK INCLUDE/LIB.
  // https://github.com/microsoft/vswhere/wiki/Find-VC
  final parentEnvironment = _environmentWith({});
  // Hooks filter ProgramFiles out of the inherited environment. Keep standard
  // installer locations on the system drive as fallbacks, as CBuilder does.
  final systemDrive = parentEnvironment['SYSTEMDRIVE'] ?? (parentEnvironment['SYSTEMROOT']?.split('\\').first) ?? 'C:';
  final candidates = {
    if (parentEnvironment['PROGRAMFILES(X86)'] case final String path) path,
    if (parentEnvironment['PROGRAMFILES'] case final String path) path,
    '$systemDrive\\Program Files (x86)',
    '$systemDrive\\Program Files',
  };
  String? vswhere;
  for (final directory in candidates) {
    final candidate = '$directory\\Microsoft Visual Studio\\Installer\\vswhere.exe';
    if (await File(candidate).exists()) {
      vswhere = candidate;
      break;
    }
  }
  if (vswhere == null) throw StateError('Visual Studio Installer was not found. Install the Desktop development with C++ workload.');
  final result = await Process.run(
    vswhere,
    ['-latest', '-products', '*', '-requires', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', '-property', 'installationPath', '-utf8'],
    runInShell: false,
    stdoutEncoding: utf8,
  );
  final installation = (result.stdout as String).trim();
  if (result.exitCode != 0 || installation.isEmpty || installation.contains('\n')) {
    throw StateError('Visual Studio C++ tools were not found. Install its Desktop development with C++ workload.');
  }
  final target = machine.toLowerCase();
  final host = Architecture.current == Architecture.arm64
      ? 'arm64'
      : Architecture.current == Architecture.ia32
      ? 'x86'
      : 'x64';
  final prompt = File('$installation\\Common7\\Tools\\VsDevCmd.bat');
  final environment = _environmentWith(await environmentFromBatchFile(prompt.uri, arguments: ['-no_logo', '-arch=$target', '-host_arch=$host']));
  final toolRoot = environment['VCTOOLSINSTALLDIR'];
  if (toolRoot == null) throw StateError('Visual Studio did not configure the $target C++ tools. Install that target architecture.');
  final bin = '${toolRoot.replaceFirst(RegExp(r'[/\\]+$'), '')}\\bin\\Host$host\\$target';
  final compiler = File('$bin\\cl.exe');
  final archiver = File('$bin\\lib.exe');
  if (!await compiler.exists() || !await archiver.exists()) throw StateError('Visual Studio is missing the $host-to-$target compiler or librarian.');
  return (compiler: compiler.uri, archiver: archiver.uri, environment: environment);
}

// Windows names are case insensitive, and environmentFromBatchFile returns only
// changes. Merge without duplicate Path/PATH keys; an existing developer prompt
// may already have the requested VCToolsInstallDir set.
Map<String, String> _environmentWith(Map<String, String> changes) => {
  for (final entry in Platform.environment.entries) entry.key.toUpperCase(): entry.value,
  for (final entry in changes.entries) entry.key.toUpperCase(): entry.value,
};

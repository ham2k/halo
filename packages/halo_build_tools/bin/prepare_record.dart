// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:io';

import 'package:halo_build_tools/src/record_dependencies.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.any((argument) => !{'--offline', '--prefetch', '--help'}.contains(argument))) {
    stderr.writeln('Usage: dart run bin/prepare_record.dart [--offline] [--prefetch]');
    exitCode = 64;
    return;
  }
  if (arguments.contains('--help')) {
    stdout.writeln('Prepare pinned record plugin sources for native builds and tests.');
    stdout.writeln('--offline uses cached archives only; --prefetch downloads archives without preparing plugin directories.');
    stdout.writeln('HALO_RECORD_CACHE overrides the user archive cache directory.');
    return;
  }
  try {
    await prepareRecordDependencies(
      repositoryRoot: Directory.fromUri(Platform.script.resolve('../../../')),
      offline: arguments.contains('--offline'),
      prefetchOnly: arguments.contains('--prefetch'),
      log: stdout.writeln,
    );
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

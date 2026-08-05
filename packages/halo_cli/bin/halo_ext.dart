// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// halo-ext — run HaLo's extension hooks outside the app.

import 'dart:io';

import 'package:halo_cli/src/cli.dart';

Future<void> main(List<String> argv) async {
  // exitCode rather than exit(): a pending write to stdout (a large export,
  // a piped result) is still flushing when main returns, and exit() would
  // truncate it.
  exitCode = await runHaloExt(argv);
}

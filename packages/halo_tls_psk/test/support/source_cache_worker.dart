// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0
import 'dart:convert';
import 'dart:io';

import '../../hook/src/source_cache.dart';

Future<void> main(List<String> arguments) async {
  stdout.writeln('ready');
  await stdout.flush();
  await stdin.transform(utf8.decoder).transform(const LineSplitter()).first;
  try {
    final source = await prepareMbedTls(packageRoot: Uri.parse(arguments[0]), cacheDirectory: Uri.parse(arguments[1]));
    stdout.writeln(source);
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

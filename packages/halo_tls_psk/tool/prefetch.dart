// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0
import 'dart:io';

import '../hook/src/source_cache.dart';

/// Invoke with `dart tool/prefetch.dart` (not `dart run`) to warm or verify the
/// cache without invoking this package's native build hook.
Future<void> main(List<String> arguments) async {
  final packageRoot = Platform.script.resolve('../');
  Uri? cache;
  var offline = false;
  for (var i = 0; i < arguments.length; i++) {
    final argument = arguments[i];
    if (argument == '--offline') {
      offline = true;
    } else if (argument == '--cache-dir' && i + 1 < arguments.length) {
      cache = Directory(arguments[++i]).absolute.uri;
    } else if (argument == '--help' || argument == '-h') {
      stdout.writeln('Usage: dart tool/prefetch.dart [--cache-dir DIRECTORY] [--offline]');
      return;
    } else {
      stderr.writeln('Unknown or incomplete option: $argument');
      exitCode = 64;
      return;
    }
  }
  try {
    final source = await prepareMbedTls(packageRoot: packageRoot, cacheDirectory: cache ?? defaultMbedTlsCacheDirectory(), offline: offline);
    stdout.writeln('Verified Mbed TLS source: ${source.toFilePath()}');
  } on MbedTlsSourceException catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } on FileSystemException catch (error) {
    stderr.writeln('Mbed TLS source cache I/O failed: ${error.message} (${error.path})');
    exitCode = 1;
  }
}

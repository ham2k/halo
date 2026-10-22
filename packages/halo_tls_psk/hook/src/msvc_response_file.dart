// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0
import 'dart:io';
import 'dart:typed_data';

/// cl.exe and lib.exe accept UTF-16LE command files. Keep all arguments on one
/// logical line: CL passes only the rest of the /link line to the linker.
/// https://learn.microsoft.com/en-us/cpp/build/reference/cl-command-files
Future<void> writeMsvcResponseFile(Uri file, Iterable<String> arguments) async {
  await File.fromUri(file).writeAsBytes(encodeMsvcResponseFile(arguments));
}

Uint8List encodeMsvcResponseFile(Iterable<String> arguments) {
  final quoted = arguments.map(_quote).toList();
  if (quoted.isEmpty) throw ArgumentError.value(arguments, 'arguments', 'At least one argument is required');
  final units = '${quoted.join(' ')}\r\n'.codeUnits;
  final bytes = ByteData(2 + units.length * 2)..setUint16(0, 0xfeff, Endian.little);
  for (var index = 0; index < units.length; index++) {
    bytes.setUint16(2 + index * 2, units[index], Endian.little);
  }
  return bytes.buffer.asUint8List();
}

String _quote(String argument) {
  if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(argument)) {
    throw ArgumentError.value(argument, 'arguments', 'Control characters are not allowed');
  }
  // Windows argument parsing doubles backslashes only before quotes (including
  // the closing quote). This preserves literal quotes in /D string values and
  // the trailing directory separator in /Fo.
  final escaped = argument.replaceAllMapped(RegExp(r'(\\*)"'), (match) => '${'\\' * (match[1]!.length * 2 + 1)}"');
  final trailing = RegExp(r'\\+$').firstMatch(escaped)?.group(0) ?? '';
  return '"$escaped$trailing"';
}

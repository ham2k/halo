// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../hook/src/msvc_response_file.dart';

void main() {
  test('quotes source, include and output paths, preserving Unicode in UTF-16LE', () {
    final bytes = encodeMsvcResponseFile([
      r'C:\Users\Renée Smith\缓存\library\aes.c',
      r'/I\\server\source files\include',
      r'/Fe:C:\build output\halo_tls_psk.dll',
    ]);
    expect(bytes.take(2), [0xff, 0xfe]);
    expect(
      _decodeUtf16Le(bytes),
      '"C:\\Users\\Renée Smith\\缓存\\library\\aes.c" "/I\\\\server\\source files\\include" "/Fe:C:\\build output\\halo_tls_psk.dll"\r\n',
    );
  });

  test('escapes string defines and trailing directory separators for MSVC', () {
    final bytes = encodeMsvcResponseFile(['/DMBEDTLS_CONFIG_FILE="halo_tls_config.h"', '/FoC:\\build output\\objects\\', r'/DVALUE=\"quoted\"']);
    expect(
      _decodeUtf16Le(bytes),
      '"/DMBEDTLS_CONFIG_FILE=\\"halo_tls_config.h\\"" '
      '"/FoC:\\build output\\objects\\\\" '
      '"/DVALUE=\\\\\\"quoted\\\\\\""\r\n',
    );
  });

  test('keeps the linker arguments on the /link line', () {
    final text = _decodeUtf16Le(encodeMsvcResponseFile(['/LD', '/link', '/MACHINE:X64', 'bcrypt.lib']));
    expect(text, '"/LD" "/link" "/MACHINE:X64" "bcrypt.lib"\r\n');
  });

  test('writes the complete long source list under the hook output directory', () async {
    final directory = await Directory.systemTemp.createTemp('halo-msvc-response-');
    addTearDown(() => directory.delete(recursive: true));
    final sources = List.generate(
      120,
      (index) => 'C:\\Users\\A user\\AppData\\Local\\ham2k\\halo_tls_psk\\mbedtls\\${'a' * 64}\\source\\library\\unit$index.c',
    );
    expect(sources.join(' ').length, greaterThan(8191));
    final output = directory.uri.resolve('build output/');
    await Directory.fromUri(output).create();
    final response = output.resolve('compile.rsp');
    await writeMsvcResponseFile(response, sources);
    final text = _decodeUtf16Le(await File.fromUri(response).readAsBytes());
    expect(text, '${sources.map((source) => '"$source"').join(' ')}\r\n');
  });

  for (final (index, invalid) in ['C:\\source\n/injected.c', 'C:\\source\r/injected.c', 'C:\\source\x00.c', '/Icache\tpath', '/DVALUE=\x7f'].indexed) {
    test('rejects control characters in argument $index', () {
      expect(() => encodeMsvcResponseFile([invalid]), throwsArgumentError);
    });
  }

  test('rejects an empty argument list', () {
    expect(() => encodeMsvcResponseFile([]), throwsArgumentError);
  });
}

String _decodeUtf16Le(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  return String.fromCharCodes([for (var offset = 2; offset < bytes.length; offset += 2) data.getUint16(offset, Endian.little)]);
}

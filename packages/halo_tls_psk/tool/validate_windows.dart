// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:halo_tls_psk/src/native_tls.dart';

// `dart run` builds the real native asset before this program starts. This
// checks DLL loading and OS entropy without opening a socket or using a key
// from a radio. The repository's test suite remains a separate local gate.
void main() {
  if (!Platform.isWindows || Abi.current() != Abi.windowsX64) {
    throw StateError('Run this validation on Windows x64.');
  }
  final key = Uint8List.fromList(List<int>.generate(32, (index) => index));
  final tls = NativeTls(key, Uint8List(0));
  try {
    final status = tls.handshake();
    final hello = tls.drain();
    if (status != tlsWantRead || hello.length < 6 || hello[0] != 22 || hello[5] != 1) {
      throw StateError('The native TLS client did not generate a ClientHello.');
    }
    stdout.writeln(
      jsonEncode({
        'platform': Platform.operatingSystem,
        'abi': Abi.current().toString(),
        'nativeAsset': 'package:halo_tls_psk/src/native_tls.dart',
        'resolvedSymbols': 8,
        'clientHelloBytes': hello.length,
        'networkConnections': 0,
      }),
    );
  } finally {
    tls.dispose();
    key.fillRange(0, key.length, 0);
  }
}

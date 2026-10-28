// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_tls_psk/src/native_tls.dart';

void main() {
  test('every native operation rejects disposed state before touching freed memory', () {
    final tls = NativeTls(Uint8List.fromList([1, 2, 3]), Uint8List(0));
    tls.dispose();
    tls.dispose();
    expect(tls.handshake, throwsStateError);
    expect(tls.closeNotify, throwsStateError);
    expect(() => tls.feed(Uint8List(1)), throwsStateError);
    expect(() => tls.write(Uint8List(1)), throwsStateError);
    expect(tls.drain, throwsStateError);
    expect(tls.read, throwsStateError);
  });

  test('oversize input is rejected before copying into the native scratch buffer', () {
    final tls = NativeTls(Uint8List.fromList([1, 2, 3]), Uint8List(0));
    addTearDown(tls.dispose);
    expect(() => tls.feed(Uint8List(tlsChunkSize + 1)), throwsRangeError);
    expect(() => tls.write(Uint8List(tlsChunkSize + 1)), throwsRangeError);
    expect(tls.handshake(), tlsWantRead);
    expect(tls.drain(), isNotEmpty);
  });
}

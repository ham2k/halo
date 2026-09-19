// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
import 'dart:typed_data';

/// Browsers have no UDP sockets; a missing receive meter remains unavailable.
class FlexMeterSocket {
  int get port => 0;
  static Future<FlexMeterSocket?> open(
    String host,
    void Function(Uint8List) onData,
    void Function(Object, StackTrace) onError,
  ) async => null;
  void close() {}
}

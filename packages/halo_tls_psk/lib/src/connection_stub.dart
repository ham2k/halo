// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0
import 'dart:typed_data';
import 'errors.dart';

class PskTlsConnection {
  PskTlsConnection._();
  static Future<PskTlsConnection> connect({
    required String host,
    required int port,
    required Uint8List psk,
    required String identity,
    Duration timeout = const Duration(seconds: 10),
    Future<void>? cancelled,
  }) => Future.error(const PskTlsException('nativeUnavailable'));

  Stream<Uint8List> get data => const Stream.empty();
  Future<void> get closed => Future.value();
  void send(List<int> bytes) {}
  Future<void> close() => Future.value();
}

// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_tls_psk/halo_tls_psk.dart';

import '../transport.dart';
import 'k4_remote_connection.dart';
import 'k4_remote_transport_config.dart';
import 'mdns_io.dart';
import 'tcp_transport_config.dart';

class K4RemoteTransport extends EquipmentTransport with TcpTransportConfig, K4RemoteTransportConfig {
  const K4RemoteTransport();

  static const transportKey = 'k4-remote';
  @override
  String get key => transportKey;
  @override
  String get portConfigKey => 'remotePort';

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async {
    if (cancel.isCancelled) throw const CatCancelledException();
    final password = target['password'] as String? ?? '';
    if (password.isEmpty) throw _K4RemoteUnavailable(t.settings.station.k4RemotePasswordRequired);
    final key = Uint8List.fromList(utf8.encode(password));
    try {
      final host = await Future.any([
        connectTarget(target['host'] as String? ?? '').then((value) => value is InternetAddress ? value.address : value as String),
        cancel.whenCancelled.then<String>((_) => throw const CatCancelledException()),
      ]);
      if (cancel.isCancelled) throw const CatCancelledException();
      final secure = await PskTlsConnection.connect(
        host: host,
        port: (target['port'] as num?)?.toInt() ?? 9204,
        psk: key,
        identity: '',
        cancelled: cancel.whenCancelled,
      );
      if (cancel.isCancelled) {
        await secure.close();
        throw const CatCancelledException();
      }
      return K4RemoteConnection(_SecureConnection(secure));
    } on PskTlsCancelledException {
      throw const CatCancelledException();
    } on PskTlsException catch (error) {
      if (error.code == 'handshakeFailed') throw _K4RemoteUnavailable(t.settings.station.k4RemoteHandshakeFailed);
      if (const {'connectFailed', 'timeout', 'connectionFailed'}.contains(error.code)) {
        throw _K4RemoteUnavailable(t.settings.station.k4RemoteUnreachable);
      }
      rethrow;
    } on SocketException {
      throw _K4RemoteUnavailable(t.settings.station.k4RemoteUnreachable);
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }
}

class _SecureConnection implements EquipmentConnection {
  final PskTlsConnection _tls;
  _SecureConnection(this._tls);

  @override
  Stream<Uint8List> get data => _tls.data;
  @override
  Future<void> get closed => _tls.closed;
  @override
  void send(List<int> bytes) => _tls.send(bytes);
  @override
  Future<void> close() => _tls.close();
}

class _K4RemoteUnavailable implements CatUnreachable {
  final String message;
  _K4RemoteUnavailable(this.message);
  @override
  String toString() => message;
}

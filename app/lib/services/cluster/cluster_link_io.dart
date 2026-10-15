// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:io';

import 'cluster_link.dart';

/// Five seconds, as the login and the reply get — see
/// `ClusterService.loginTimeout`.
const _connectTimeout = Duration(seconds: 5);

/// Whether this platform can reach a node at all.
const clusterLinksSupported = true;

Future<ClusterLink> connectClusterLink(String host, int port) async => _SocketLink(await Socket.connect(host, port, timeout: _connectTimeout));

class _SocketLink implements ClusterLink {
  _SocketLink(this._socket);

  final Socket _socket;

  @override
  Stream<List<int>> get data => _socket;

  @override
  void write(List<int> bytes) => _socket.add(bytes);

  @override
  Future<void> close() async => _socket.destroy();
}

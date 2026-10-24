// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:io';

import 'cluster_link.dart';

/// Whether this platform can reach a node at all.
const clusterLinksSupported = true;

Future<ClusterLink> connectClusterLink(String host, int port, Duration timeout) async => _SocketLink(await Socket.connect(host, port, timeout: timeout));

class _SocketLink implements ClusterLink {
  _SocketLink(this._socket) {
    // A connection the network drops (a reset, a write that times out) ends
    // [data], which closes the session and lets it reconnect; it also fails
    // the write side's `done`, which nothing awaits — unignored, that same
    // drop escapes as an uncaught SocketException.
    _socket.done.ignore();
  }

  final Socket _socket;

  @override
  Stream<List<int>> get data => _socket;

  @override
  void write(List<int> bytes) => _socket.add(bytes);

  @override
  Future<void> close() async => _socket.destroy();
}

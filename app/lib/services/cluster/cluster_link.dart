// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The byte stream to a cluster node. The web build has no sockets, so it
// gets a stub that refuses (docs/design/cluster.md § Platforms).

import 'dart:async';

export 'cluster_link_web.dart' if (dart.library.io) 'cluster_link_io.dart';

/// One open connection to a node.
abstract class ClusterLink {
  /// Every read, until the node or [close] ends the connection.
  Stream<List<int>> get data;

  void write(List<int> bytes);

  Future<void> close();
}

typedef ClusterConnector = Future<ClusterLink> Function(String host, int port);

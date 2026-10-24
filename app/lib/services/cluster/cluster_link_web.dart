// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'cluster_link.dart';

/// Whether this platform can reach a node at all.
const clusterLinksSupported = false;

Future<ClusterLink> connectClusterLink(String host, int port, Duration timeout) =>
    Future.error(UnsupportedError('A browser cannot open a telnet connection to a DX cluster node'));

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A browser cannot listen on a socket. Throws rather than pretending: a link
// shown as listening that no command can reach looks like a broken command.

import 'agent_link_peer.dart';

Future<AgentLinkListener> bindAgentLink({required int port, required void Function(AgentLinkPeer peer) onPeer}) async =>
    throw UnsupportedError('An agent link cannot listen in a web browser');

/// Nothing binds here, so no port is ever out of reach.
bool agentLinkPortUnavailable(Object error) => false;

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The agent link's constants (docs/design/agent-link.md), held once for both
// ends: the app imports them, and so does the command.

import 'dart:convert';
import 'dart:math';

/// The link's version, in every hello and answer.
const kAgentLinkVersion = 1;

/// The most one frame may hold, either way.
const kAgentLinkMaxFrame = 8 * 1024 * 1024;

/// The shortest token a hello may carry. The command mints 32 random
/// bytes; a shorter one is a token another program could guess.
const kAgentLinkMinToken = 32;

/// A new token: 32 random bytes, base64url without padding.
String mintAgentLinkToken([Random? random]) {
  final source = random ?? Random.secure();
  return base64Url.encode(List<int>.generate(32, (_) => source.nextInt(256))).replaceAll('=', '');
}

/// The editions, as `HALO_EDITION` and `halo-mcp --edition` spell them.
const kAgentLinkEditions = ['prod', 'next', 'dev'];

/// One port per edition, so a Dev and a Regular build on one machine each
/// keep their own listener and their own grants. Null for an edition this
/// table does not know.
int? agentLinkPortFor(String edition) => switch (edition) {
  'prod' => 47380,
  'next' => 47381,
  'dev' => 47382,
  _ => null,
};
